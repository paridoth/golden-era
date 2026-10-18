-- SPDX-License-Identifier: GPL-3.0-or-later
-- Real ItemStacks/InvRefs and registry/world SQLite restarts. This fixture calls
-- the public transaction APIs; it does not simulate player network packets.
return function(phase,storage,place,eq)
 local function p(x) return vector.new(x,200,24) end
 local inventory_name="era_integration_relocation"
 local inventory=assert(core.create_detached_inventory(inventory_name,{}))
 inventory:set_size("main",8)
 local wield="era_core:wrench"
 local player_position=p(61)
 local allow_interact=true
 local check_player_privs=core.check_player_privs
 core.check_player_privs=function(subject,...)
  local name=type(subject)=="string" and subject or subject:get_player_name()
  if name=="relocation_original" or name=="relocation_new_owner" then return allow_interact end
  return check_player_privs(subject,...)
 end
 local player_meta=ItemStack("mcl_core:stick"):get_meta()
 local function player(name)
  return {is_player=function() return true end,get_player_name=function() return name end,
   get_inventory=function() return inventory end,get_wielded_item=function() return ItemStack(wield) end,
   get_player_control=function() return {sneak=true} end,get_meta=function() return player_meta end,
   get_pos=function() return vector.new(player_position) end}
 end
 local packer,placer=player("relocation_original"),player("relocation_new_owner")
 local fixtures={
  {key="native",source=p(56),target=p(57),name="era_thermal:pulverizer"},
  {key="generator",source=p(58),target=p(59),name="era_thermal:generator"},
  {key="legacy",source=p(60),target=p(61),name="era_thermal:pulverizer"},
  {key="cell",source=p(62),target=p(63),name="era_thermal:buffer"},
 }
 local function inv(pos) return core.get_meta(pos):get_inventory() end
 local function same(a,b,path)
  path=path or "relocation"; eq(type(a),type(b),path)
  if type(a)~="table" then eq(a,b,path); return end
  for key,value in pairs(a) do same(value,b[key],path.."."..tostring(key)) end
  for key in pairs(b) do assert(a[key]~=nil,path.." gained "..tostring(key)) end
 end
 local function snapshot(pos)
  local node=core.get_node(pos); local metadata=core.get_meta(pos):to_table()
  for _,key in ipairs({"formspec","infotext","fault"}) do metadata.fields[key]=nil end
  for _,list in pairs(metadata.inventory) do
   for index,stack in ipairs(list) do list[index]=ItemStack(stack):to_string() end
  end
  return {name=node.name,param2=node.param2,metadata=metadata}
 end
 local function pointed(pos) return {type="node",under=p(70),above=pos} end
 local function token(stack) return stack:get_meta():get_string("era_package_token") end
 local function record_key(stack) return "relocation_packet:"..token(stack) end
 local function failed_place(stack,pos,label)
  local before=stack:to_string(); local world=snapshot(pos)
  local result=era.unpack_machine(stack,placer,pointed(pos))
  eq(result:to_string(),before,label.." packet unchanged"); same(world,snapshot(pos),label.." destination unchanged")
 end
 local function store_inventory(key)
  local values={}
  for index=1,inventory:get_size("main") do values[index]=inventory:get_stack("main",index):to_string() end
  storage:set_string(key,core.serialize(values))
 end
 local function load_inventory(key)
  inventory:set_list("main",assert(core.deserialize(storage:get_string(key),true)))
 end
 local function drive(pos,ticks)
  for _=1,ticks do local state=era.state(pos); era.process(pos,core.get_node(pos).name,state); era.save(pos,state) end
 end
 local function source_tests()
  local pos=p(64); place(pos,"era_thermal:pulverizer")
  local state=era.state(pos); state.energy=1234; era.save(pos,state)
  inv(pos):set_stack("src",1,era.mcl.ore)
  local before=snapshot(pos); local protected=core.is_protected
  allow_interact=false
  local ok=era.pack_machine(pos,packer); allow_interact=true
  eq(ok,false,"source interact privilege required"); same(before,snapshot(pos),"missing privilege preserves source")
  player_position=p(0); ok=era.pack_machine(pos,packer); player_position=p(61)
  eq(ok,false,"distant source denied"); same(before,snapshot(pos),"distant packing preserves source")
  assert(inventory:is_empty("main"),"actor refusals create no package")
  core.is_protected=function() return true end
  ok=era.pack_machine(pos,packer); core.is_protected=protected
  eq(ok,false,"protected source denied"); same(before,snapshot(pos),"protected source unchanged")
  wield="mcl_core:stick"; ok=era.pack_machine(pos,packer); wield="era_core:wrench"
  eq(ok,false,"wrench required"); same(before,snapshot(pos),"wrong tool preserves source")
  for index=1,inventory:get_size("main") do inventory:set_stack("main",index,era.mcl.ingot.." 64") end
  ok=era.pack_machine(pos,packer)
  eq(ok,false,"full player inventory denied"); same(before,snapshot(pos),"full inventory preserves source")
  for index=1,inventory:get_size("main") do eq(inventory:get_stack("main",index):get_count(),64,"full inventory unchanged") end
  inventory:set_list("main",{})
  -- Fail after a genuine InvRef write, once. The rollback must remove that
  -- inserted package and its registry claim while restoring the source.
  local fail_once=true; local failed_token; local writes=0
  local wrapped={
   get_size=function(_,list) return inventory:get_size(list) end,
   get_stack=function(_,list,index) return inventory:get_stack(list,index) end,
   set_stack=function(_,list,index,stack)
    writes=writes+1; local result=inventory:set_stack(list,index,stack)
    if fail_once then
     fail_once=false; failed_token=token(ItemStack(stack))
     assert(failed_token~="","packing reached unique package insertion")
     assert(era.package_storage:get_string("relocation_packet:"..failed_token)~="","claim exists before injected insertion failure")
     error("Intentional relocation inventory insertion failure")
    end
    return result
   end,
  }
  local failing_player=player("relocation_original")
  failing_player.get_inventory=function() return wrapped end
  ok=era.pack_machine(pos,failing_player)
  eq(ok,false,"injected package insertion failure denied")
  eq(writes,2,"insertion failure invokes one inventory rollback write")
  same(before,snapshot(pos),"insertion rollback preserves source RF/items")
  assert(inventory:is_empty("main"),"insertion rollback removes the inserted package")
  eq(era.package_storage:get_string("relocation_packet:"..assert(failed_token)),"","insertion rollback removes registry claim")
  core.get_meta(pos):set_string("energy","broken")
  before=snapshot(pos); ok=era.pack_machine(pos,packer)
  eq(ok,false,"malformed source denied"); same(before,snapshot(pos),"malformed source preserved")
  core.remove_node(pos)
 end
 local ok,err=xpcall(function()
  assert(era.package_storage,"authoritative package registry exposed to fixture")
  if phase=="relocation_seed" then
   source_tests()
   local snapshots={}
   for _,fixture in ipairs(fixtures) do
    place(fixture.source,fixture.name)
    local meta=core.get_meta(fixture.source)
    local legacy_job
    meta:set_string("owner","relocation_original")
    meta:set_string("relocation_annotation","preserve this custom field")
    if fixture.key=="native" then
     core.swap_node(fixture.source,{name=fixture.name,param2=1})
     meta:set_int("item_front",5); meta:set_string("item_ports","312220"); meta:set_string("auto_output","0")
     local ore=ItemStack(era.mcl.ore); ore:get_meta():set_string("batch","saved native input")
     inv(fixture.source):set_stack("src",1,ore)
     local bucket=ItemStack(era.mcl.empty_bucket); bucket:get_meta():set_string("batch","metadata survives relocation")
     inv(fixture.source):set_stack("empty",1,bucket)
     local state=era.state(fixture.source); state.energy=3063; state.work=937; era.save(fixture.source,state)
     meta:set_string("job",core.serialize({input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=20,
      schema=3,rate_mode="buffer",secondary_output="era_materials:nickel_dust",secondary_chance=10,secondary_roll=1}))
    elseif fixture.key=="generator" then
     local state=era.state(fixture.source)
     state.energy=1234; state.water=2700; state.fuel_rf=-17; state.water_rf=-13; era.save(fixture.source,state)
     inv(fixture.source):set_stack("fuel",1,era.mcl.coal.." 2")
    elseif fixture.key=="legacy" then
     -- Reproduce a genuine schema-1 save, including its absent bucket lists.
     for _,key in ipairs({"profile","water","fuel_rf","water_rf","item_ports_version","item_ports","item_front"}) do meta:set_string(key,"") end
     inv(fixture.source):set_size("water",0); inv(fixture.source):set_size("empty",0)
     meta:set_int("energy",3500); meta:set_int("work",500); meta:set_int("burn",0)
     inv(fixture.source):set_stack("src",1,era.mcl.ore)
     legacy_job=core.serialize({input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=40})
     meta:set_string("job",legacy_job); meta:set_int("schema",1)
     eq(meta:get_int("schema"),1,"legacy fixture begins at schema 1")
     eq(meta:get_string("profile"),"","schema-1 profile is absent")
     eq(inv(fixture.source):get_size("water"),0,"schema-1 bucket slot is absent")
    else
     local state=era.state(fixture.source); state.energy=1234567; era.save(fixture.source,state)
    end
    assert(era.machine_ready(fixture.source,fixture.name),"valid relocation fixture "..fixture.key)
    if legacy_job then
     eq(meta:get_int("schema"),2,"known legacy migration commits schema 2")
     eq(meta:get_string("profile"),"legacy","known legacy migration keeps its profile")
     eq(meta:get_string("job"),legacy_job,"known legacy migration preserves saved job bytes")
     eq(meta:get_int("energy"),3500,"known legacy migration preserves RF")
     eq(meta:get_int("work"),500,"known legacy migration preserves paid work")
     eq(inv(fixture.source):get_size("water"),1,"known legacy migration adds water slot")
     eq(inv(fixture.source):get_size("empty"),1,"known legacy migration adds empty bucket slot")
    end
    snapshots[fixture.key]=snapshot(fixture.source)
    local packed,message=era.pack_machine(fixture.source,packer); assert(packed,message)
    eq(core.get_node(fixture.source).name,"air","packed source removed exactly once")
   end
   for index=1,#fixtures do
    local stack=inventory:get_stack("main",index)
    eq(stack:get_name(),"era_core:packed_machine","dedicated relocation item")
    eq(stack:get_count(),1,"one packet per source")
    eq(stack:get_meta():get_string("era_package_version"),"1","packet version")
    assert(era.package_storage:get_string(record_key(stack))~="","authoritative record stored")
   end
   store_inventory("relocation_packets"); storage:set_string("relocation_snapshots",core.serialize(snapshots))
   core.log("action","ERA INTEGRATION RELOCATION_SEED PASS: protected/full-inventory/wrong-tool/malformed-source refusals and injected insertion rollback; native saved decision, generator water/debts, genuine schema-1 migration/job preservation and cell RF packed into registry")
  elseif phase=="relocation_resume" then
   load_inventory("relocation_packets")
   local snapshots=assert(core.deserialize(storage:get_string("relocation_snapshots"),true))
   for _,fixture in ipairs(fixtures) do eq(core.get_node(fixture.source).name,"air","packed source remains absent after SQLite restart") end
   local packet=inventory:get_stack("main",1); local destination=p(64)
   local raw=era.package_storage:get_string(record_key(packet)); assert(raw~="","packed registry survives SQLite")
   allow_interact=false
   failed_place(ItemStack(packet),destination,"destination interact privilege required"); allow_interact=true
   player_position=p(0)
   failed_place(ItemStack(packet),destination,"distant destination denied"); player_position=p(61)
   eq(era.package_storage:get_string(record_key(packet)),raw,"actor refusals preserve authoritative packet")
   local future=ItemStack(packet); future:get_meta():set_string("era_package_version","2")
   failed_place(future,destination,"future packet")
   local nonce=assert(token(packet):match("^([0-9a-f]+):"))
   local unknown=ItemStack(packet); unknown:get_meta():set_string("era_package_token",nonce..":999999999")
   failed_place(unknown,destination,"unknown packet")
   local foreign=ItemStack(packet)
   foreign:get_meta():set_string("era_package_token",(nonce:sub(1,1)=="0" and "1" or "0")..nonce:sub(2)..":1")
   failed_place(foreign,destination,"cross-world packet")
   local doubled=ItemStack(packet); doubled:set_count(2); failed_place(doubled,destination,"duplicated count")
   place(destination,"era_energy:cable"); failed_place(ItemStack(packet),destination,"occupied destination"); core.remove_node(destination)
   local protected=core.is_protected
   core.is_protected=function(pos,name) return vector.equals(pos,destination) or protected(pos,name) end
   failed_place(ItemStack(packet),destination,"protected destination"); core.is_protected=protected
   local node_or_nil=core.get_node_or_nil
   core.get_node_or_nil=function(pos) if vector.equals(pos,destination) then return nil end; return node_or_nil(pos) end
   failed_place(ItemStack(packet),destination,"unloaded destination guard"); core.get_node_or_nil=node_or_nil
   local air_meta=core.get_meta(destination)
   air_meta:set_string("relocation_air_note","preserve existing air metadata")
   failed_place(ItemStack(packet),destination,"air with metadata")
   air_meta:set_string("relocation_air_note","")
   air_meta:get_inventory():set_size("main",1)
   failed_place(ItemStack(packet),destination,"air with an empty inventory list")
   air_meta:get_inventory():set_size("main",0)
   local air_timer=core.get_node_timer(destination); air_timer:start(60)
   local timeout,elapsed=air_timer:get_timeout(),air_timer:get_elapsed()
   failed_place(ItemStack(packet),destination,"air with an active timer")
   assert(air_timer:is_started(),"refused placement preserves existing air timer")
   eq(air_timer:get_timeout(),timeout,"refused placement preserves timer timeout")
   eq(air_timer:get_elapsed(),elapsed,"refused placement preserves timer elapsed time")
   air_timer:stop()
   eq(era.package_storage:get_string(record_key(packet)),raw,"refusals preserve authoritative packet")
   local damaged=assert(core.deserialize(raw,true)); damaged.metadata.fields.energy="2147483647"
   local damaged_raw=core.serialize(damaged); era.package_storage:set_string(record_key(packet),damaged_raw)
   failed_place(ItemStack(packet),destination,"restored-state revalidation rollback")
   eq(era.package_storage:get_string(record_key(packet)),damaged_raw,"rollback retains authoritative record")
   era.package_storage:set_string(record_key(packet),raw)
   -- Use an independent packet to make the rollback itself fail. The saved
   -- snapshot must remain repairable, but no copied claim may place it again.
   local quarantine_source,quarantine_target,quarantine_replay=p(66),p(65),p(67)
   place(quarantine_source,"era_thermal:buffer")
   local cell=era.state(quarantine_source); cell.energy=54321; era.save(quarantine_source,cell)
   local packed,message=era.pack_machine(quarantine_source,packer); assert(packed,message)
   local quarantined=inventory:get_stack("main",5)
   eq(quarantined:get_name(),"era_core:packed_machine","independent quarantine packet")
   local quarantine_key=record_key(quarantined)
   local invalid=assert(core.deserialize(era.package_storage:get_string(quarantine_key),true))
   invalid.metadata.fields.energy="2147483647"
   local invalid_raw=core.serialize(invalid); era.package_storage:set_string(quarantine_key,invalid_raw)
   local set_node=core.set_node; local restore_failures=0
   core.set_node=function(pos,node)
    if vector.equals(pos,quarantine_target) and node.name=="air" then
     restore_failures=restore_failures+1; error("Intentional relocation destination rollback failure")
    end
    return set_node(pos,node)
   end
   local restored=era.unpack_machine(ItemStack(quarantined),placer,pointed(quarantine_target))
   core.set_node=set_node
   eq(restore_failures,1,"destination rollback failure was injected")
   eq(restored:to_string(),quarantined:to_string(),"quarantine keeps the original package item")
   eq(era.package_storage:get_string("relocation_quarantine:"..token(quarantined)),invalid_raw,"quarantine retains exact encoded snapshot")
   eq(era.package_storage:get_string(quarantine_key),"","quarantine disables active token")
   failed_place(ItemStack(quarantined),quarantine_replay,"quarantined copied packet cannot restore")
   storage:set_string("relocation_quarantine_packet",quarantined:to_string())
   storage:set_string("relocation_quarantine_expected",invalid_raw)
   core.remove_node(quarantine_target); inventory:set_stack("main",5,"")
   local used={}; local replay
   local creative=core.is_creative_enabled
   core.is_creative_enabled=function(name) if name==placer:get_player_name() then return true end; return creative(name) end
   for index,fixture in ipairs(fixtures) do
    local stack=inventory:get_stack("main",index); used[index]=token(stack)
    if index==1 then replay=ItemStack(stack) end
    local result=era.unpack_machine(stack,placer,pointed(fixture.target))
    assert(result:is_empty(),"creative placement must consume one unique packet")
    inventory:set_stack("main",index,result)
    local expected=snapshots[fixture.key]; expected.metadata.fields.owner=placer:get_player_name()
    same(expected,snapshot(fixture.target),fixture.key.." restored metadata/inventory/facing")
    eq(era.package_storage:get_string("relocation_packet:"..used[index]),"","placed packet consumed in registry")
   end
   core.is_creative_enabled=creative
   failed_place(replay,destination,"copied token can place only once")
   local random=era.random_percent; era.random_percent=function() error("relocated job rerolled") end
   drive(fixtures[1].target,3000); drive(fixtures[3].target,3000); era.random_percent=random
   for _,index in ipairs({1,3}) do
    local pos=fixtures[index].target
    eq(era.state(pos).energy,0,"relocated job exact remaining RF cost")
    eq(era.state(pos).work,0,"relocated job completes")
    eq(inv(pos):get_stack("dst",1):get_count(),2,"relocated primary count")
    assert(inv(pos):is_empty("src"),"relocated input consumed once")
   end
   eq(inv(fixtures[1].target):get_stack("secondary",1):get_count(),1,"relocated saved byproduct decision")
   assert(inv(fixtures[3].target):is_empty("secondary"),"legacy job gains no byproduct")
   era.step()
   local generator=era.state(fixtures[2].target)
   eq(generator.energy,1274,"relocated generator stores 40 RF")
   eq(generator.water,2600,"relocated generator refills one water batch")
   eq(generator.fuel_rf,23943,"relocated fuel debt carries into refill")
   eq(generator.water_rf,24947,"relocated water debt carries into refill")
   eq(inv(fixtures[2].target):get_stack("fuel",1):get_count(),1,"relocated generator consumes one coal")
   eq(era.state(fixtures[4].target).energy,1234567,"relocated cell retains RF")
   local finished={}; for _,fixture in ipairs(fixtures) do finished[fixture.key]=snapshot(fixture.target) end
   storage:set_string("relocation_finished",core.serialize(finished))
   storage:set_string("relocation_used",core.serialize(used)); storage:set_string("relocation_replay",replay:to_string())
   core.log("action","ERA INTEGRATION RELOCATION_RESUME PASS: packed SQLite state restores metadata/facing/items/owner; invalid/occupied/protected/unloaded/replayed packets, occupied air and invalid restored state denied; failed rollback quarantines its snapshot and disables replay; unique creative consumption, exact jobs/byproduct and generator debts")
  elseif phase=="relocation_verify" then
   local finished=assert(core.deserialize(storage:get_string("relocation_finished"),true))
   for _,fixture in ipairs(fixtures) do same(finished[fixture.key],snapshot(fixture.target),fixture.key.." placed SQLite restart") end
   for _,value in ipairs(assert(core.deserialize(storage:get_string("relocation_used"),true))) do
    eq(era.package_storage:get_string("relocation_packet:"..value),"","spent token remains spent after restart")
   end
   failed_place(ItemStack(storage:get_string("relocation_replay")),p(64),"spent token after restart")
   local quarantined=ItemStack(storage:get_string("relocation_quarantine_packet"))
   eq(era.package_storage:get_string("relocation_quarantine:"..token(quarantined)),storage:get_string("relocation_quarantine_expected"),"quarantine snapshot survives SQLite restart")
   eq(era.package_storage:get_string(record_key(quarantined)),"","quarantined token remains disabled after restart")
   failed_place(quarantined,p(67),"quarantined token after restart")
   for _,index in ipairs({1,3}) do
    local before=snapshot(fixtures[index].target); drive(fixtures[index].target,100)
    same(before,snapshot(fixtures[index].target),"finished relocated job does not duplicate")
   end
   core.log("action","ERA INTEGRATION RELOCATION_VERIFY PASS: placed resources/items/owner survive second SQLite restart; quarantined snapshot remains recoverable with its token disabled; consumed tokens stay spent and completed outputs do not duplicate")
  else error("Unknown relocation phase") end
 end,debug.traceback)
 core.check_player_privs=check_player_privs
 core.remove_detached_inventory(inventory_name)
 if not ok then error(err) end
 core.request_shutdown("Relocation phase passed",false,0)
end
