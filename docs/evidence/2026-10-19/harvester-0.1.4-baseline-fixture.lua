-- Read-only production audit. This ignored fixture uses normal machine timers.
local done=false
local cases={}
local active_case
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function log(s) core.log("action","HARVESTER AUDIT: "..s) end
local function finish(ok,s)
 if done then return end
 done=true;core.log(ok and "action" or "error","HARVESTER AUDIT "..(ok and "PASS: " or "FAIL: ")..s)
 core.request_shutdown("Read-only native harvester audit complete",false,0)
end
local function checked(fn) local ok,e=xpcall(fn,debug.traceback);if not ok then finish(false,e) end end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function items(pos,radius)
 local result={}
 for _,o in ipairs(core.get_objects_inside_radius(pos,radius or 3)) do
  local le=o:get_luaentity()
  if le and le.name=="__builtin:item" and le.itemstring~="" then result[#result+1]={object=o,stack=ItemStack(le.itemstring)} end
 end
 return result
end
local function amount(list,name)
 local n=0;for _,s in ipairs(list) do if s:get_name()==name then n=n+s:get_count() end end;return n
end
local original_drops=core.get_node_drops
core.get_node_drops=function(node,...)
 local result=original_drops(node,...)
 if active_case and node=="mcl_farming:wheat" then
  assert(not active_case.expected,"Only one mature fixture crop per farm")
  active_case.expected={}
  for _,s in ipairs(result) do active_case.expected[#active_case.expected+1]=ItemStack(s) end
 end
 return result
end
for _,name in ipairs({"elepower_farming:harvester","elepower_farming:harvester_active"}) do
 local timer=assert(core.registered_nodes[name].on_timer)
 core.override_item(name,{on_timer=function(pos,elapsed)
  active_case=cases[core.hash_node_position(pos)]
  local result=timer(pos,elapsed)
  active_case=nil
  return result
 end})
end
local owned=core.create_detached_inventory("harvester_audit_actor",{})
owned:set_size("main",50);owned:set_size("offhand",1);owned:set_size("hand",1)
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return "" end,
 get_inventory=function() return owned end,get_wielded_item=function() return ItemStack("") end,set_wielded_item=function() end,
 get_player_control=function() return {} end}
local function pickup(stack)
 assert(core.item_pickup(stack,actor,{type="nothing"},1):is_empty(),"Native seed pickup fits")
end
local function device(pos,name)
 core.set_node(pos,{name=name});core.get_meta(pos):set_string("owner","")
end
local function seed(pos,mature)
 core.set_node(vector.offset(pos,0,-1,0),{name="mcl_farming:soil_wet"})
 local source=owned:remove_item("main","mcl_farming:wheat_seeds")
 eq(source:get_count(),1,"Plant source came from actual grass-drop pickup")
 local remaining=core.registered_items["mcl_farming:wheat_seeds"].on_place(source,actor,
  {type="node",under=vector.offset(pos,0,-1,0),above=pos})
 assert(remaining:is_empty(),"Native seed placement consumes one owned seed")
 eq(core.get_node(pos).name,"mcl_farming:wheat_1","Native seed placement creates wheat")
 if mature then
  for _=1,10 do
   local node=core.get_node(pos)
   if node.name=="mcl_farming:wheat" then break end
   assert(core.registered_nodes[node.name]._on_bone_meal(ItemStack("mcl_bone_meal:bone_meal"),actor,
    {type="node",under=pos,above=vector.offset(pos,0,1,0)},pos,node),"Native crop bone-meal callback grows wheat")
  end
  eq(core.get_node(pos).name,"mcl_farming:wheat","Native crop growth reaches registered mature wheat")
 end
end
local function run()
 core.set_timeofday(0.5)
 -- Real players receive a hidden native mesh-hand inventory on join. Detached
 -- actors must supply the same hand capability before claiming hand harvests.
 for name,definition in pairs(core.registered_items) do
  if name:match("^mcl_meshhand:") and definition._mcl_diggroups and core.get_item_group(name,"dig_speed_class")==1 then
   owned:set_stack("hand",1,ItemStack(name));break
  end
 end
 assert(not owned:is_empty("hand"),"Native survival hand selected for detached actor")
 assert(mcl_autogroup.can_harvest("mcl_flowers:tallgrass","",actor),"Native survival hand can harvest grass")
 -- Existing graph only lacks a diamond root because its original15 targets do
 -- not need a diamond gear. Ordinary Mineclonia diamond mining is this checkpoint.
 local file=assert(io.open(core.get_modpath("era_harvester_audit").."/progression.lua"));local source=file:read("*a");file:close()
 source=source:gsub('local roots={','local roots={"mcl_core:diamond",',1)
 source=source:gsub('local targets={','local targets={"elepower_farming:planter","elepower_farming:harvester",',1)
 assert(loadstring(source))()()
 log("Recipe dependency closure includes native planter+harvester after ordinary diamond mining; counts/travel are not modeled")
 local grass=p(0,12)
 core.set_node(vector.offset(grass,0,-1,0),{name="mcl_core:dirt_with_grass"})
 local digs=0
 while not owned:contains_item("main","mcl_farming:wheat_seeds 6") do
  digs=digs+1;assert(digs<=256,"Native grass drop sample supplies six seeds")
  core.set_node(grass,{name="mcl_flowers:tallgrass"})
  assert(core.node_dig(grass,core.get_node(grass),actor),"Native hand digging grass")
  for _,item in ipairs(items(grass,2)) do pickup(item.stack);item.object:remove() end
 end
 log("Six seeds acquired through native hand-dug fixture grass drops and pickup in "..digs.." grass digs; supplied bone-meal growth callbacks used below")
 for index,mode in ipairs({"full","partial","empty"}) do
  local pos=p((index-1)*16)
  local crop=vector.offset(ele.helpers.face_front(pos,0),0,0,-1)
  local young=vector.offset(crop,1,0,0)
  local item={mode=mode,pos=pos,crop=crop,young=young}
  cases[core.hash_node_position(pos)]=item
  device(pos,"elepower_farming:harvester")
  for slot=1,15 do inv(pos):set_stack("dst",slot,mode=="empty" and ItemStack() or ItemStack("mcl_core:cobble 64")) end
  if mode=="partial" then inv(pos):set_stack("dst",15,ItemStack("mcl_farming:wheat_seeds 63")) end
  seed(crop,true);seed(young,false)
  local generator=vector.offset(pos,-2,0,0)
  device(generator,"elepower_machines:generator")
  device(vector.offset(pos,-1,0,0),"elepower_dynamics:conduit")
  local fuel=ItemStack("mcl_core:coal_lump")
  eq(def(generator).allow_metadata_inventory_put(generator,"src",1,fuel,actor),1,"Native generator accepts supplied coal")
  inv(generator):set_stack("src",1,fuel)
  def(generator).on_metadata_inventory_put(generator,"src",1,fuel,actor)
  eq(core.get_meta(pos):get_int("storage"),0,"No injected harvester power")
 end
 local began=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   local complete=0
   for _,case in pairs(cases) do
    if not case.reported and core.get_node(case.crop).name=="air" then
     assert(case.expected,"Capture exact stock drops from actual timer's native get_node_drops call")
     assert(core.get_node(case.young).name:match("^mcl_farming:wheat_[1-7]$"),"Harvester ignores immature wheat while normal growth remains enabled")
     local expected_seeds=amount(case.expected,"mcl_farming:wheat_seeds")
     local expected_wheat=amount(case.expected,"mcl_farming:wheat_item")
     assert(expected_seeds>=1 and expected_seeds<=3,"Native mature wheat gives1–3 seeds")
     eq(expected_wheat,1,"Native mature wheat always gives one wheat")
     local seeds=amount(inv(case.pos):get_list("dst"),"mcl_farming:wheat_seeds")-(case.mode=="partial" and 63 or 0)
     local wheat=amount(inv(case.pos):get_list("dst"),"mcl_farming:wheat_item")
     local ground={};for _,e in ipairs(items(case.crop,4)) do ground[#ground+1]=e.stack end
     local loose=amount(ground,"mcl_farming:wheat_seeds")+amount(ground,"mcl_farming:wheat_item")
     eq(loose,0,"Stock harvester emits no overflow entities")
     local loss=expected_seeds+expected_wheat-seeds-wheat
     if case.mode=="full" then eq(seeds+wheat,0,"Full output stores no harvest");eq(loss,expected_seeds+expected_wheat,"Full output loses entire harvest")
     elseif case.mode=="partial" then eq(seeds,1,"Partial output fills only one available seed space");eq(wheat,0,"Partial output silently loses wheat");eq(loss,expected_seeds,"Partial output loses wheat and any excess seeds")
     else eq(seeds,expected_seeds,"Empty output conserves seeds");eq(wheat,expected_wheat,"Empty output conserves wheat");eq(loss,0,"Empty output no loss") end
     eq(core.get_meta(case.pos):get_int("sludge_fluid_storage"),10,"One harvest sweep generates ten mB sludge")
     case.reported=true
     log(case.mode.." output: exact native drops seeds="..expected_seeds..",wheat="..expected_wheat.."; stored delta seeds="..seeds..",wheat="..wheat.."; loose="..loose.."; LOST="..loss.."; crop removed, immature control stays, sludge=10mB")
    end
    if case.reported then complete=complete+1 end
   end
   if complete==3 then finish(true,"native stock timer and real coal-generated power confirm full/partial output harvest loss; ordinary seed planting/maturity, native recipes and empty-output control pass; no production edits")
   elseif core.get_us_time()-began>90000000 then error("Native harvester timeout")
   else core.after(0.2,poll) end
  end)
 end
 core.after(0.2,poll)
end
local started=false
core.register_node("era_harvester_audit:marker",{drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_harvester_audit:ready",nodenames={"era_harvester_audit:marker"},run_at_every_load=true,action=function()
 if started then return end;started=true;core.after(0,function() checked(run) end)
end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-8,-16),p(40,15)+vector.new(0,2,0),function(_,_,left)
   if left==0 then core.after(0,function() checked(function()
    core.load_area(p(-8,-16),p(40,15)+vector.new(0,2,0))
    for x=-1,2 do for z=-1,0 do assert(core.forceload_block(p(x*16,z*16),true),"Activate native farm fixture") end end
    core.set_node(p(12,12),{name="era_harvester_audit:marker"})
   end) end) end
  end)
 end)
end)
