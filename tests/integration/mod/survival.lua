-- SPDX-License-Identifier: GPL-3.0-or-later
-- Real engine ore generation and a closed material-to-cell progression fixture.
return function(phase,storage,place,eq)
 local pos=vector.new(40,200,24)
 local function craft(items,expected,method)
  local out=core.get_craft_result({method=method or "normal",width=3,items=items})
  eq(out.item:to_string(),expected,"survival craft "..expected)
  return out.item:get_name()
 end
 local function process(machine,input,output,cost)
  place(pos,machine)
  local m=core.get_meta(pos); local inv=m:get_inventory();local state=era.state(pos)
  inv:set_stack("src",1,input);state.energy=cost;era.save(pos,state)
  for i=1,3000 do era.process(pos,machine,state);era.save(pos,state) end
  eq(inv:get_stack("dst",1):to_string(),output,"survival processing "..input)
  eq(state.energy,0,"exact RF "..input);eq(state.work,0,"completed paid work")
  assert(inv:is_empty("src"),"consume exactly one material")
  eq(m:get_string("job"),"","no residual job")
  return inv:get_stack("dst",1):get_name()
 end
 if phase=="survival_seed" then
  local lo,hi=vector.new(512,-64,512),vector.new(575,15,575)
  local vm=core.get_voxel_manip();local emin,emax=vm:read_from_map(lo,hi)
  local area=VoxelArea:new({MinEdge=emin,MaxEdge=emax});local data=vm:get_data()
  local stone=core.get_content_id("mcl_core:stone")
  for i=1,#data do data[i]=stone end
  vm:set_data(data);core.generate_ores(vm,lo,hi);data=vm:get_data()
  local counts={};local bands={}
  for _,ore in ipairs(era.survival.scatters) do
   local b=bands[ore.ore] or {min=math.huge,max=-math.huge}
   b.min=math.min(b.min,mcl_worlds.layer_to_y(ore.min_layer,"overworld"))
   b.max=math.max(b.max,mcl_worlds.layer_to_y(ore.max_layer,"overworld"));bands[ore.ore]=b
  end
  for z=lo.z,hi.z do for y=lo.y,hi.y do for x=lo.x,hi.x do
   local name=core.get_name_from_content_id(data[area:index(x,y,z)])
   if bands[name] then
    assert(y>=bands[name].min and y<=bands[name].max,"ore outside native configured band")
    counts[name]=(counts[name] or 0)+1
   end
  end end end
  for _,ore in ipairs(era.survival.ores) do
   assert((counts[ore.name] or 0)>0,"real engine generated "..ore.name)
   local drops=core.get_node_drops(ore.name,"mcl_tools:pick_iron")
   eq(#drops,1,"one native ore drop");eq(drops[1],ore.name,"ore remains usable before first machine")
   craft({drops[1]},ore.ingot,"cooking")
  end
  -- A non-stone host must not acquire these ores.
  for i=1,#data do data[i]=core.get_content_id("air") end
  vm:set_data(data);core.generate_ores(vm,lo,hi)
  for _,id in ipairs(vm:get_data()) do assert(not bands[core.get_name_from_content_id(id)],"ores replace stone only") end
  -- Gathered ore can be conventionally smelted before any machine exists.
  local tin=craft({"era_materials:tin_ore"},"era_materials:tin_ingot","cooking")
  local silver=craft({"era_materials:silver_ore"},"era_materials:silver_ingot","cooking")
  local lead=craft({"era_materials:lead_ore"},"era_materials:lead_ingot","cooking")
  craft({"",tin,"",tin,era.mcl.ingot,tin,"",tin,""},"era_materials:tin_gear")
  craft({"","",era.mcl.redstone,"",silver,"",era.mcl.redstone,"",""},"era_materials:silver_coil")
  local gold_dust=process("era_thermal:pulverizer","mcl_core:gold_ingot","era_materials:gold_dust",2000)
  local silver_dust=process("era_thermal:pulverizer",silver,"era_materials:silver_dust",2000)
  local electrum_dust=craft({gold_dust,silver_dust},"era_materials:electrum_dust 2")
  local electrum=process("era_thermal:furnace",electrum_dust,"era_materials:electrum_ingot",1500)
  local coil=craft({era.mcl.redstone,"","","",electrum,"","","",era.mcl.redstone},"era_materials:electrum_coil")
  local gear=craft({"",lead,"",lead,"",lead,"",lead,""},"era_materials:lead_gear")
  local iron,glass=era.mcl.ingot,"mcl_core:glass"
  local frame=craft({iron,glass,iron,glass,gear,glass,iron,glass,iron},"era_materials:cell_frame")
  craft({"","mcl_redstone_torch:redstoneblock","",lead,frame,lead,"",coil,""},"era_thermal:buffer")
  -- New ore recipes preserve both potential outputs and the exact sourced cost.
  local old_rng=era.random_percent;era.random_percent=function() return 1 end
  for _,case in ipairs({{"tin","iron"},{"silver","lead"},{"lead","silver"}}) do
   process("era_thermal:pulverizer","era_materials:"..case[1].."_ore","era_materials:"..case[1].."_dust 2",4000)
   eq(core.get_meta(pos):get_inventory():get_stack("secondary",1):to_string(),"era_materials:"..case[2].."_dust","exact ore secondary")
  end
  era.random_percent=old_rng
  place(pos,"era_thermal:buffer")
  local state=era.state(pos);state.energy=5500;era.save(pos,state)
  storage:set_string("survival_ore_counts",core.serialize(counts))
  core.log("action","ERA INTEGRATION SURVIVAL_SEED PASS: real scatter generates three ores only in stone/bands; ore drops/cooking; tin/silver components; gold/silver dust -> electrum -> energy cell; exact RF/secondary outputs")
 elseif phase=="survival_resume" then
  eq(core.get_node(pos).name,"era_thermal:buffer","crafted cell representative persists")
  assert(era.machine_ready(pos,"era_thermal:buffer"))
  eq(era.state(pos).energy,5500,"cell RF survives SQLite")
  local counts=assert(core.deserialize(storage:get_string("survival_ore_counts"),true))
  for _,ore in ipairs(era.survival.ores) do assert(counts[ore.name]>0) end
  core.log("action","ERA INTEGRATION SURVIVAL_RESUME PASS: sourced storage representative and RF persist through SQLite restart")
 else error("Unknown survival phase") end
 core.request_shutdown("Survival phase passed",false,0)
end
