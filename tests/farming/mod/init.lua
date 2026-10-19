-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native timers/coal, crop drops, actual item pickup, routing and process restart.
-- Provided machines/fertilizer and a detached actor are fixtures, not human play.
local baseline=core.settings:get_bool("era_farming_baseline",false)
local state=core.get_mod_storage()
local done=false
local function p(x,z,y) return vector.new(x,y or 200,z or 0) end
local function eq(a,b,s) assert(a==b,s..": "..tostring(a).." ~= "..tostring(b)) end
local function log(s) core.log("action","Farming smoke: "..s) end
local function finish(ok,s)
 if done then return end;done=true
 core.log(ok and "action" or "error","ERA FARMING SMOKE "..(ok and "PASS: " or "FAIL: ")..s)
 core.request_shutdown("Farming smoke checkpoint",false,0)
end
local function checked(f) local ok,e=xpcall(f,debug.traceback);if not ok then finish(false,e) end end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function place(pos,name,param2)
 assert(core.registered_nodes[name],"Registered fixture node "..name)
 core.set_node(pos,{name=name,param2=param2 or 0});core.get_meta(pos):set_string("owner","")
end
local function quantity(list,name)
 local n=0;for _,s in ipairs(list or {}) do if s:get_name()==name then n=n+s:get_count() end end;return n
end
local function count(pos,list,name) return quantity(inv(pos):get_list(list),name) end
local function signature(pos,list)
 local out={};for _,stack in ipairs(inv(pos):get_list(list) or {}) do out[#out+1]=stack:to_string() end
 return table.concat(out,"\n")
end
local function entities(pos,radius)
 local out={};for _,o in ipairs(core.get_objects_inside_radius(pos,radius or 4)) do
  local le=o:get_luaentity()
  if le and le.name=="__builtin:item" and le.itemstring~="" then out[#out+1]={object=o,stack=ItemStack(le.itemstring)} end
 end;return out
end
local owned=core.create_detached_inventory("era_farming_actor",{})
owned:set_size("main",96);owned:set_size("offhand",1);owned:set_size("hand",1)
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return "" end,
 get_inventory=function() return owned end,get_wielded_item=function() return ItemStack("") end,set_wielded_item=function() end,
 get_player_control=function() return {} end}
local seed_name,wheat="mcl_farming:wheat_seeds","mcl_farming:wheat_item"
local bone="mcl_bone_meal:bone_meal"
local recovery,vault=p(56,8),p(86,4)
local farm={planter=p(80,-3,198),harvester=p(80),barrel=p(84),seed_clock=p(79,1),wheat_clock=p(81,1),
 seed_filter=p(79),wheat_filter=p(81),generated={seeds=0,wheat=0,sweeps=0}}
local bone_used=0
local cases={}
for index,mode in ipairs({"full","partial","empty","contract"}) do
 local pos=p((index-1)*16)
 cases[core.hash_node_position(pos)]={mode=mode,pos=pos,crop=vector.offset(ele.helpers.face_front(pos,0),0,0,-1)}
end
local function stamp(name,n,tag,wear)
 local s=ItemStack(name.." "..n);s:get_meta():set_string("era_farming",tag);s:set_wear(wear or 0);return s
end
local metal=stamp("mcl_copper:copper_ingot",5,"owned metadata crop",321)
local tool=stamp("mcl_tools:pick_iron",1,"owned worn tool crop",4321)
core.register_node("era_farming_smoke:contract_crop",{description="Disposable drop contract crop",drawtype="plantlike",walkable=false,
 tiles={"mcl_farming_wheat_stage_7.png"},groups={plant=1,dig_immediate=3},
 drop={max_items=2,items={{items={metal:to_string()}},{items={tool:to_string()}}}}})
mcl_farming.plant_lists.era_farming_contract={full_grown="era_farming_smoke:contract_crop",names={}}
-- Capture the actual native drop roll once, inside normal machine timer calls.
-- Archive observers inspect the original callback, which this observer invokes.
era_farming_smoke={harvester_timer=assert(core.registered_nodes["elepower_farming:harvester"].on_timer)}
local current
local original_drops=core.get_node_drops
core.get_node_drops=function(node,...)
 local drops=original_drops(node,...)
 if current and (node=="mcl_farming:wheat" or node=="era_farming_smoke:contract_crop") then
  current.drops=current.drops or {}
  for _,s in ipairs(drops) do current.drops[#current.drops+1]=ItemStack(s) end
 end
 return drops
end
for _,name in ipairs({"elepower_farming:harvester","elepower_farming:harvester_active"}) do
 local timer=assert(core.registered_nodes[name].on_timer)
 core.override_item(name,{on_timer=function(pos,elapsed)
  local case=cases[core.hash_node_position(pos)]
  local measure=case or (vector.equals(pos,farm.harvester) and {farm=true})
  current=measure
  local energy=core.get_meta(pos):get_int("storage")
  local sludge=core.get_meta(pos):get_int("sludge_fluid_storage")
  local previous=measure and #(measure.drops or {}) or 0
  local result=timer(pos,elapsed)
  current=nil
  if measure and #(measure.drops or {})>previous then
   eq(energy-core.get_meta(pos):get_int("storage"),128,"Productive stock sweep consumes128E")
   eq(core.get_meta(pos):get_int("sludge_fluid_storage")-sludge,10,"Productive stock sweep adds10mB sludge")
   if measure.farm then
    farm.generated.seeds=farm.generated.seeds+quantity(measure.drops,seed_name)
    farm.generated.wheat=farm.generated.wheat+quantity(measure.drops,wheat)
    farm.generated.sweeps=farm.generated.sweeps+1
   else case.energy_checked=true end
  end
  return result
 end})
end
local function pickup_all(pos,radius)
 local total=0
 for _,e in ipairs(entities(pos,radius)) do
  assert(core.item_pickup(e.stack,actor,{type="nothing"},1):is_empty(),"Native item pickup retains complete spill")
  total=total+e.stack:get_count();e.object:remove()
 end;return total
end
local function deposit_owned(pos)
 for index,stack in ipairs(owned:get_list("main")) do if not stack:is_empty() then
  local left=inv(pos):add_item("main",stack);assert(left:is_empty(),"Saved recovery container has room")
  owned:set_stack("main",index,"")
 end end
end
local function take_node(pos,list,name,n)
 local stack=inv(pos):remove_item(list,ItemStack(name.." "..n));eq(stack:get_count(),n,"Transfer owned saved input")
 if def(pos).on_metadata_inventory_take then def(pos).on_metadata_inventory_take(pos,list,1,stack,actor) end
 assert(owned:add_item("main",stack):is_empty(),"Actor has input room")
end
local function give_machine(pos,list,stack)
 stack=ItemStack(stack);local actual=owned:remove_item("main",stack)
 eq(actual:to_string(),stack:to_string(),"Machine input comes from owned inventory")
 eq(def(pos).allow_metadata_inventory_put(pos,list,1,actual,actor),actual:get_count(),"Native input permission")
 assert(inv(pos):add_item(list,actual):is_empty(),"Native input fits")
 if def(pos).on_metadata_inventory_put then def(pos).on_metadata_inventory_put(pos,list,1,actual,actor) end
end
local function switch_off(pos)
 eq(core.get_meta(pos):get_int("state"),0,"Stock fixture starts enabled")
 -- Configure the stock off state after this fixture's one measured harvest.
 -- State-button ordering is outside this output conservation regression.
 core.get_meta(pos):set_int("state",1)
end
local function generator(pos)
 place(pos,"elepower_machines:generator")
 local fuel=ItemStack("mcl_core:coal_lump 2")
 eq(def(pos).allow_metadata_inventory_put(pos,"src",1,fuel,actor),2,"Stock generator accepts supplied coal")
 inv(pos):set_stack("src",1,fuel);def(pos).on_metadata_inventory_put(pos,"src",1,fuel,actor)
end
local function acquire_seeds(n)
 local grass=p(0,12);place(vector.offset(grass,0,-1,0),"mcl_core:dirt_with_grass")
 local digs=0
 while not owned:contains_item("main",seed_name.." "..n) do
  digs=digs+1;assert(digs<=384,"Native grass sample supplies requested seeds")
  place(grass,"mcl_flowers:tallgrass")
  assert(mcl_autogroup.can_harvest("mcl_flowers:tallgrass","",actor),"Native survival hand harvests grass")
  assert(core.node_dig(grass,core.get_node(grass),actor),"Native hand digs fixture grass")
  pickup_all(grass,2)
 end
 log("Native grass digging/pickup supplied "..n.." owned seeds in "..digs.." fixture grass digs")
end
local function fertilize(pos)
 for _=1,12 do
  local node=core.get_node(pos);if node.name=="mcl_farming:wheat" then return end
  assert(node.name:match("^mcl_farming:wheat_[1-7]$"),"Only a planted native wheat crop is fertilized")
  local stack=owned:remove_item("main",ItemStack(bone))
  eq(stack:get_count(),1,"Fertilizer drawn from counted supplied bone meal")
  local after=core.registered_items[bone].on_place(stack,actor,{type="node",under=pos,above=vector.offset(pos,0,1,0)})
  assert(after:is_empty(),"Native bone-meal placement consumes one item")
  bone_used=bone_used+1
 end
 error("Native bone meal failed to mature wheat")
end
local function plant_seed(pos,mature)
 place(vector.offset(pos,0,-1,0),"mcl_farming:soil_wet")
 local stack=owned:remove_item("main",ItemStack(seed_name));eq(stack:get_count(),1,"Plant an owned grass seed")
 local after=core.registered_items[seed_name].on_place(stack,actor,{type="node",under=vector.offset(pos,0,-1,0),above=pos})
 assert(after:is_empty(),"Native seed placement consumes seed")
 if mature then fertilize(pos) end
end
local function verify_same(stack,other,label)
 eq(other:get_name(),stack:get_name(),label.." identity")
 eq(other:get_wear(),stack:get_wear(),label.." wear")
 eq(other:get_meta():get_string("era_farming"),stack:get_meta():get_string("era_farming"),label.." metadata")
end
local function bench_start()
 place(recovery,"mcl_barrels:barrel_closed")
 acquire_seeds(6);assert(owned:add_item("main",bone.." 128"):is_empty(),"Counted fertilizer fixture fits")
 for _,case in pairs(cases) do
  local pos=case.pos
  for x=-4,4 do for z=-4,4 do place(vector.offset(pos,x,-2,z),"mcl_core:stone") end end
  place(pos,"elepower_farming:harvester")
  for slot=1,15 do inv(pos):set_stack("dst",slot,case.mode=="empty" and ItemStack() or ItemStack("mcl_core:cobble 64")) end
  if case.mode=="partial" then inv(pos):set_stack("dst",15,ItemStack(seed_name.." 63"))
  elseif case.mode=="contract" then
   local s=ItemStack(metal);s:set_count(62);inv(pos):set_stack("dst",15,s)
  end
  if case.mode=="contract" then place(vector.offset(case.crop,0,-1,0),"mcl_farming:soil_wet");place(case.crop,"era_farming_smoke:contract_crop")
  else plant_seed(case.crop,true);case.young=vector.offset(case.crop,1,0,0);plant_seed(case.young,false) end
  generator(vector.offset(pos,-2,0,0));place(vector.offset(pos,-1,0,0),"elepower_dynamics:conduit")
  eq(core.get_meta(pos):get_int("storage"),0,"Harvester starts without injected energy")
 end
end
local function bench_poll()
 local complete=0
 for _,case in pairs(cases) do
  if not case.checked and core.get_node(case.crop).name=="air" then
   assert(case.drops and case.energy_checked,"Observe exact native drop roll and productive energy/sludge timing")
   if case.young then assert(core.get_node(case.young).name:match("^mcl_farming:wheat_[1-7]$"),"Immature crop remains") end
   local ground={};for _,e in ipairs(entities(case.pos,4)) do ground[#ground+1]=e.stack end
   if case.mode=="contract" then
    eq(quantity(case.drops,metal:get_name()),5,"Native metadata crop yields5 copper")
    eq(quantity(case.drops,tool:get_name()),1,"Native metadata crop yields one worn tool")
    eq(count(case.pos,"dst",metal:get_name())-62,baseline and 0 or 2,"Partial native metadata stack insertion")
    eq(quantity(ground,metal:get_name()),baseline and 0 or 3,"Only three remaining metal spill")
    eq(quantity(ground,tool:get_name()),baseline and 0 or 1,"Full worn tool spills")
    verify_same(metal,inv(case.pos):get_stack("dst",15),"Retained partial stack")
    for _,s in ipairs(ground) do if s:get_name()==metal:get_name() then verify_same(metal,s,"Spilled partial stack")
     elseif s:get_name()==tool:get_name() then verify_same(tool,s,"Spilled tool") end end
    log("Full ItemStack contract: generated 5 metadata copper and 1 worn tool; stored copper delta="..(count(case.pos,"dst",metal:get_name())-62).."; world copper="..quantity(ground,metal:get_name())..",tool="..quantity(ground,tool:get_name()).."; wear/metadata retained")
   else
    local seeds=quantity(case.drops,seed_name);local grain=quantity(case.drops,wheat)
    assert(seeds>=1 and seeds<=3,"Actual native wheat seed roll");eq(grain,1,"Actual native wheat yield")
    local gained_seed=count(case.pos,"dst",seed_name)-(case.mode=="partial" and 63 or 0)
    local gained_wheat=count(case.pos,"dst",wheat)
    eq(gained_seed,case.mode=="empty" and seeds or (case.mode=="partial" and 1 or 0),"Native stored seed delta")
    eq(gained_wheat,case.mode=="empty" and 1 or 0,"Native stored wheat delta")
    local dropped_seed=quantity(ground,seed_name);local dropped_wheat=quantity(ground,wheat)
    eq(dropped_seed,baseline and 0 or seeds-gained_seed,"Only leftover seed count spills")
    eq(dropped_wheat,baseline and 0 or 1-gained_wheat,"Only leftover wheat count spills")
    log(case.mode.." output generated seeds="..seeds..",wheat=1; stored="..gained_seed..","..gained_wheat.."; world="..dropped_seed..","..dropped_wheat)
   end
   if baseline then eq(#ground,0,"Baseline silently discards rejected items") end
   local recovered=pickup_all(case.pos,4)
   eq(recovered,quantity(ground,seed_name)+quantity(ground,wheat)+quantity(ground,metal:get_name())+quantity(ground,tool:get_name()),"Native pickup accounts for every spill")
   deposit_owned(recovery)
   switch_off(case.pos);case.checked=true
  end
  if case.checked then complete=complete+1 end
 end
 return complete==4
end
local function pipe_count(name)
 local n=0;for _,entity in pairs(pipeworks.luaentity.entities or {}) do
  if entity.name=="pipeworks:tubed_item" then local s=ItemStack(entity.itemstring);if not name or s:get_name()==name then n=n+s:get_count() end end
 end;return n
end
local function field()
 local out={};for x=79,81 do for z=-4,-2 do if x~=80 or z~=-3 then out[#out+1]=p(x,z) end end end;return out
end
local function field_count()
 local n=0;for _,pos in ipairs(field()) do if core.get_node(pos).name:match("^mcl_farming:wheat") then n=n+1 end end;return n
end
local function facedir(direction)
 for n=0,23 do if vector.equals(pipeworks.facedir_to_right_dir(n),direction) then return n end end;error("Native filter orientation")
end
local function configure(pos,name)
 local stack=owned:get_stack("main",1)
 for _,s in ipairs(owned:get_list("main")) do if s:get_name()==name then stack=ItemStack(s);stack:set_count(1);break end end
 eq(stack:get_name(),name,"Own real selector before configuring preview")
 eq(def(pos).allow_metadata_inventory_put(pos,"main",1,stack,actor),0,"Native filter preview consumes no selector")
end
local function farm_start()
 log("Starting stock3x3 farm; machines/fertilizer supplied, seeds gathered; no power injection")
 place(vault,"mcl_barrels:barrel_closed")
 acquire_seeds(9)
 local empty=p(32);take_node(empty,"dst",wheat,1)
 take_node(recovery,"main",bone,count(recovery,"main",bone))
 for x=79,81 do for z=-4,-2 do place(p(x,z,199),"mcl_core:dirt") end end
 place(farm.planter,"elepower_farming:planter");place(p(80,-3,199),"mcl_core:water_source")
 place(farm.harvester,"elepower_farming:harvester");place(farm.barrel,"mcl_barrels:barrel_closed")
 local selector=ItemStack(seed_name)
 eq(def(farm.planter).allow_metadata_inventory_put(farm.planter,"layout",5,selector,actor),0,"Planter layout is a logical selector")
 give_machine(farm.planter,"src",seed_name.." 8")
 place(farm.seed_filter,"pipeworks:mese_filter",facedir(vector.new(-1,0,0)))
 place(farm.wheat_filter,"pipeworks:mese_filter",facedir(vector.new(1,0,0)))
 configure(farm.seed_filter,seed_name);configure(farm.wheat_filter,wheat)
 for _,pos in ipairs({p(78),p(78,0,199),p(78,0,198),p(78,-1,198),p(78,-2,198),p(78,-3,198),p(79,-3,198),p(82),p(83)}) do place(pos,"pipeworks:tube_1") end
 for _,pos in ipairs({farm.seed_clock,farm.wheat_clock}) do place(pos,"mesecons_blinkyplant:blinky_plant_off") end
 generator(p(80,2))
 for _,pos in ipairs({p(80,1),p(81,2),p(81,2,199),p(81,2,198),p(80,2,198),p(80,1,198),p(80,0,198),p(80,-1,198),p(80,-2,198)}) do place(pos,"elepower_dynamics:conduit") end
 for x=78,84 do for z=-4,2 do for y=198,200 do pipeworks.scan_for_tube_objects(p(x,z,y)) end end end
 eq(core.get_meta(farm.planter):get_int("storage"),0,"Planter starts without energy gift")
 eq(core.get_meta(farm.harvester):get_int("storage"),0,"Farm harvester starts without energy gift")
 deposit_owned(vault)
end
local function fertilize_field()
 local n=count(vault,"main",bone);take_node(vault,"main",bone,n)
 for _,pos in ipairs(field()) do fertilize(pos) end
 deposit_owned(vault)
end
local function farm_cycle_ready(cycle)
 if field_count()~=8 or farm.generated.wheat~=8*cycle or count(farm.barrel,"main",wheat)~=8*cycle or pipe_count()~=0 or not inv(farm.harvester):is_empty("dst") then return false end
 for _,pos in ipairs(field()) do if not core.get_node(pos).name:match("^mcl_farming:wheat_[1-7]$") then return false end end
 eq(count(farm.planter,"src",seed_name),farm.generated.seeds-8*cycle,"All generated seeds minus replanted seeds accounted in physical supply")
 eq(inv(farm.planter):get_stack("layout",5):get_name(),seed_name,"Logical planter layout remains")
 eq(count(vault,"main",seed_name),1,"Original physical seed selector remains owned")
 eq(count(vault,"main",wheat),1,"Original physical wheat selector remains owned")
 eq(#entities(p(80,-2),12),0,"Farm has no hidden dropped seed/wheat overflow")
 return true
end
local function snapshot()
 local s={recovery=signature(recovery,"main"),bone_used=bone_used}
 for _,case in pairs(cases) do s[case.mode]=signature(case.pos,"dst") end
 if not baseline then
  s.farm_src=signature(farm.planter,"src");s.farm_layout=signature(farm.planter,"layout")
  s.farm_dst=signature(farm.harvester,"dst");s.farm_product=signature(farm.barrel,"main");s.vault=signature(vault,"main")
 end
 return s
end
local function checkpoint()
 state:set_int("phase",1);state:set_string("snapshot",core.serialize(snapshot()))
 state:set_string("farm_generated",core.serialize(farm.generated));state:set_int("bone_used",bone_used)
 log("Counted supplied bone meal consumed="..bone_used.." of128; no fertilizer is granted on restart")
 finish(true,"CHECKPOINT: "..(baseline and "native full/partial losses reproduced; empty output and exact drop contracts observed; saved recovery ownership" or
  "all overflow recovered with full wear/metadata; native3x3 farm harvested8 wheat into storage and replanted8 crops through real seed-return tubes"))
end
local function initial()
 log("Runtime farm source="..core.get_modpath("elepower_farming").."; game="..core.get_game_info().path)
 for name,definition in pairs(core.registered_items) do
  if name:match("^mcl_meshhand:") and definition._mcl_diggroups and core.get_item_group(name,"dig_speed_class")==1 then owned:set_stack("hand",1,ItemStack(name));break end
 end
 assert(not owned:is_empty("hand"),"Detached actor receives native survival hand capability")
 core.set_timeofday(0.5);bench_start()
 local stage="bench"
 local began=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   if stage=="bench" and bench_poll() then
    if baseline then checkpoint();return end
    farm_start();stage="first planting"
   elseif stage=="first planting" and field_count()==8 then
    eq(count(farm.planter,"src",seed_name),0,"Native planter consumes exactly8 gathered seeds")
    log("Native center-layout planter placed 8 crops using 8 seeds: buried planter, central water and surrounding farmland geometry accepted")
    fertilize_field();stage="first harvest/replant"
   elseif stage=="first harvest/replant" and farm_cycle_ready(1) then
    log("First native harvest/return/storage cycle: 8 wheat stored, 8 replanted crops, "..count(farm.planter,"src",seed_name).." excess seeds, no tube payloads or loose items")
    checkpoint();return
   end
   if core.get_us_time()-began>170000000 then error("Native farm checkpoint timeout stage="..stage.." yields="..core.write_json(farm.generated).." field="..field_count().." seeds="..count(farm.planter,"src",seed_name).." wheat="..count(farm.barrel,"main",wheat).." packets="..pipe_count()) end
   core.after(0.2,poll)
  end)
 end
 core.after(0.2,poll)
end
local function resumed()
 bone_used=state:get_int("bone_used")
 farm.generated=assert(core.deserialize(state:get_string("farm_generated")))
 local expected=assert(core.deserialize(state:get_string("snapshot")))
 local actual=snapshot();for key,value in pairs(expected) do eq(actual[key],value,"Process restart preserves "..key) end
 for _,case in pairs(cases) do eq(core.get_meta(case.pos):get_int("state"),1,"Saved bench machines remain off") end
 if baseline then finish(true,"COMPLETE: pinned loss baseline and saved ownership remain unchanged across process restart");return end
 assert(farm_cycle_ready(1),"Saved first farm cycle and seed ownership intact")
 fertilize_field()
 local began=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   if farm_cycle_ready(2) then
    log("After restart, native farm produced16 total wheat, replanted8 crops again, retained all excess seeds; sludge="..core.get_meta(farm.harvester):get_int("sludge_fluid_storage").."mB, bone meal used="..bone_used)
    finish(true,"COMPLETE: physical spill recovery saved; stock planter/harvester/clocked seed return/wheat storage completed another cycle without seed or power gifts")
   elseif core.get_us_time()-began>100000000 then error("Native resumed farm timeout: "..core.write_json(farm.generated).." field="..field_count().." packets="..pipe_count())
   else core.after(0.2,poll) end
  end)
 end
 core.after(0.2,poll)
end
local started=false
core.register_node("era_farming_smoke:marker",{drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_farming_smoke:ready",nodenames={"era_farming_smoke:marker"},run_at_every_load=true,action=function()
 if started then return end;started=true
 local function ready()
  for x=-1,6 do for z=-1,0 do if not core.compare_block_status(p(x*16,z*16),"active") then core.after(0.25,ready);return end end end
  checked(state:get_int("phase")==1 and resumed or initial)
 end
 core.after(0.25,ready)
end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-8,-16,196),p(96,15,203),function(_,_,left)
   if left==0 then core.after(0,function() checked(function()
    core.load_area(p(-8,-16,196),p(96,15,203))
    -- Native powered networks persist their own forceloads. Luanti's Lua
    -- cross-type reference branch returns nil after adding a transient reference;
    -- only false rejects the request. ready() still requires actual activation.
    for x=-1,6 do for z=-1,0 do assert(core.forceload_block(p(x*16,z*16),true)~=false,"Request native fixture blocks") end end
    place(p(12,12),"era_farming_smoke:marker")
   end) end) end
  end)
 end)
end)
