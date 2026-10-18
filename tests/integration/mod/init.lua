-- Actual engine nodes, metadata, ItemStacks, inventories and SQLite restart.
local storage=core.get_mod_storage()
local modpath=core.get_modpath("era_integration")
local crafting=dofile(modpath.."/crafting.lua")
local recipe_restart=dofile(modpath.."/recipe_restart.lua")
local lifecycle=dofile(modpath.."/lifecycle.lua")
local corruption=dofile(modpath.."/corruption.lua")
local native=dofile(modpath.."/native.lua")
local byproduct=dofile(modpath.."/byproduct.lua")
local sides=dofile(modpath.."/sides.lua")
local function p(x,z) return vector.new(x,200,z or 0) end
local positions={generator=p(0,2),buffer=p(1,2),cable=p(0,1),pulverizer=p(0),furnace=p(1),ejector=p(2),chest=p(3)}
local function inv(name) return core.get_meta(positions[name]):get_inventory() end
local function eq(a,b,label) assert(a==b,(label or "")..": "..tostring(a).." ~= "..tostring(b)) end
local function place(pos,name)
 core.set_node(pos,{name=name}); local def=core.registered_nodes[name]; assert(def,name)
 if def.on_construct then def.on_construct(pos) end
 local legacy={seed=true,resume=true,automatic=true,recipe_seed=true,recipe_resume=true,recipe_verify=true,lifecycle=true,corrupt_seed=true,corrupt_resume=true,corrupt_verify=true}
 if era.machines[name] and legacy[core.settings:get("era_test_phase")] then
  local m=core.get_meta(pos)
  for _,key in ipairs({"profile","water","fuel_rf","water_rf","item_ports","item_ports_version","item_front"}) do m:set_string(key,"") end
  m:set_int("schema",1) -- reproduce the old world format, then let production validation migrate it
 end
end
local function snapshot()
 local result={}
 for name,pos in pairs(positions) do
  local m=core.get_meta(pos); local i=m:get_inventory()
  result[name]={energy=m:get_int("energy"),work=m:get_int("work"),burn=m:get_int("burn"),job=m:get_string("job")}
  for _,list in ipairs({"src","dst","fuel","main"}) do
   if i:get_size(list)>0 then result[name][list]=i:get_stack(list,1):to_string() end
  end
 end
 return result
end
local function run()
 local phase=core.settings:get("era_test_phase")
 if phase:sub(1,6)=="sides_" then
  sides(phase,storage,place,eq)
  return
 elseif phase:sub(1,10)=="byproduct_" then
  byproduct(phase,storage,place,eq)
  return
 elseif phase:sub(1,7)=="native_" then
  native(phase,storage,place,eq)
  return
 elseif phase:sub(1,8)=="corrupt_" then
  corruption(phase,storage,place,eq)
  return
 elseif phase:sub(1,7)=="recipe_" then
  recipe_restart(phase,storage,p(12),place,eq)
 elseif phase=="automatic" then
  eq(inv("chest"):get_stack("main",1):get_count(),4,"completed outputs survived restart")
  local pos=p(8); place(pos,"era_thermal:furnace")
  local i=core.get_meta(pos):get_inventory(); i:set_stack("src",1,"era_materials:iron_dust")
  era.save(pos,{energy=2000,work=0,burn=0})
  core.after(4,function()
   local ok,err=xpcall(function()
    eq(i:get_stack("dst",1):get_name(),era.mcl.ingot,"normal globalstep recipe")
    eq(era.state(pos).energy,0,"normal globalstep energy")
   end,debug.traceback)
   if ok then core.log("action","ERA INTEGRATION AUTOMATIC PASS: completed outputs persisted; normal 20-Hz scheduler processed dust")
   else core.log("error","ERA INTEGRATION FAIL: "..err) end
   core.request_shutdown("Automatic test finished",false,0)
  end)
  return
 elseif phase=="seed" then
  crafting(eq)
  for name,pos in pairs(positions) do
   local id=name=="cable" and "era_energy:cable" or name=="ejector" and "era_transport:ejector" or name=="chest" and "mcl_chests:chest_small" or "era_thermal:"..name
   place(pos,id)
  end
  eq(inv("chest"):get_size("main"),27,"native chest initialized")
  inv("generator"):set_stack("fuel",1,era.mcl.coal)
  inv("pulverizer"):set_stack("src",1,era.mcl.ore.." 2")
  for i=1,40 do era.step() end
  assert(core.get_meta(positions.pulverizer):get_int("work")>0,"must persist partially processed input")
  eq(inv("pulverizer"):get_stack("src",1):get_count(),2,"reserved input")
  -- Test disconnection: generator and buffer isolated from both processors.
  core.remove_node(positions.cable)
  local before=era.state(positions.pulverizer).energy+era.state(positions.pulverizer).work
  era.step()
  eq(era.state(positions.pulverizer).energy+era.state(positions.pulverizer).work,before,"disconnected no incoming RF")
  place(positions.cable,"era_energy:cable")
  storage:set_string("snapshot",core.serialize(snapshot()))
  core.log("action","ERA INTEGRATION SEED PASS: connected, disconnected, generation, pending recipe saved")
 elseif phase=="resume" then
  local old=assert(core.deserialize(storage:get_string("snapshot")))
  local current=snapshot()
  for name,fields in pairs(old) do for key,value in pairs(fields) do eq(current[name][key],value,"restart "..name.."."..key) end end
  -- Resume discovery explicitly; natural LBM/mapblock reactivation is not tested.
  for _,pos in pairs(positions) do era.track(pos) end
  for i=1,2000 do era.step() end
  eq(inv("chest"):get_stack("main",1):get_name(),era.mcl.ingot,"result item")
  eq(inv("chest"):get_stack("main",1):get_count(),4,"ore doubling and chest transfer")
  assert(inv("pulverizer"):is_empty("src") and inv("pulverizer"):is_empty("dst"))
  assert(inv("furnace"):is_empty("src") and inv("furnace"):is_empty("dst"))
  local total=0
  for name,pos in pairs(positions) do if era.machines[core.get_node(pos).name] then local s=era.state(pos); total=total+s.energy+s.work end end
  eq(total+16000,32000,"exact generated RF equals stored plus recipe costs")
  for i=1,100 do era.step() end
  eq(inv("chest"):get_stack("main",1):get_count(),4,"no duplicate output")
  -- Real ItemStack overflow: process blocked output without consuming RF.
  inv("pulverizer"):set_stack("src",1,era.mcl.ore)
  inv("pulverizer"):set_stack("dst",1,"era_materials:iron_dust 99")
  local state={energy=8000,work=0,burn=0}; era.process(positions.pulverizer,"era_thermal:pulverizer",state)
  eq(state.energy,8000,"overflow preserves RF"); eq(inv("pulverizer"):get_stack("src",1):get_count(),1,"overflow preserves input")
  -- Engine permission callbacks lock in-progress input and deny output insertion.
  local def=core.registered_nodes["era_thermal:pulverizer"]
  core.get_meta(positions.pulverizer):set_int("work",20)
  local player={get_player_name=function() return "integration" end}
  eq(def.allow_metadata_inventory_take(positions.pulverizer,"src",1,inv("pulverizer"):get_stack("src",1),player),0,"reserved input locked")
  eq(def.allow_metadata_inventory_put(positions.pulverizer,"dst",1,ItemStack(era.mcl.ingot),player),0,"output insertion denied")
  -- Protection checks must block automated inventory writes.
  local old_protected=core.is_protected
  core.is_protected=function() return true end
  eq(era.move_one(positions.pulverizer,"dst",positions.furnace,"src","intruder"),false,"protected transfer denied")
  core.is_protected=old_protected
  inv("pulverizer"):set_stack("src",1,""); inv("pulverizer"):set_stack("dst",1,"")
  core.get_meta(positions.pulverizer):set_int("work",0)
  core.log("action","ERA INTEGRATION RESUME PASS: exact restart, 2 ores -> 4 ingots, RF conservation, overflow, locks, no duplication")
 else
  error("Unknown integration phase: "..tostring(phase))
 end
 core.request_shutdown("Integration passed",false,0)
end
core.register_on_mods_loaded(function()
 if core.settings:get("era_test_phase")=="lifecycle" then
  core.after(0,function() lifecycle(place,eq) end)
  return
 end
 core.after(0,function()
  core.emerge_area(p(-1,-1),p(26,26),function(_,_,remaining)
   if remaining==0 then core.after(0,function()
    core.load_area(p(-1,-1),p(26,26))
    local ok,err=xpcall(run,debug.traceback)
    if not ok then core.log("error","ERA INTEGRATION FAIL: "..err); core.request_shutdown("Integration failed",false,0) end
   end) end
  end)
 end)
end)
