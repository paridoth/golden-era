-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise stock machinery and callbacks; never manually invoke the power ABM or machine timers.
local finished=false
local actor="playtest_smoke"
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function finish(ok,message)
 if finished then return end
 finished=true
 core.log(ok and "action" or "error","ERA PLAYTEST SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Existing-mod playtest smoke finished",false,0)
end
local function checked(callback)
 local ok,err=xpcall(callback,debug.traceback)
 if not ok then finish(false,err) end
end
local function resolve(name)
 for _=1,10 do
  if not core.registered_aliases[name] then break end
  name=core.registered_aliases[name]
 end
 return name
end
local function concrete_item(name)
 if name=="" then return "" end
 if name:sub(1,6)~="group:" then
  local result=resolve(ItemStack(name):get_name())
  assert(core.registered_items[result],"Unknown selected recipe ingredient: "..name)
  return name
 end
 local groups=name:sub(7):split(",")
 local candidates={}
 for item in pairs(core.registered_items) do
  local matches=true
  for _,group in ipairs(groups) do if core.get_item_group(item,group)==0 then matches=false;break end end
  if matches then candidates[#candidates+1]=item end
 end
 table.sort(candidates)
 return assert(candidates[1],"Empty selected ingredient group: "..name)
end
local function check_craft(name)
 local recipes=assert(core.get_all_craft_recipes(name),"No selected recipe registered: "..name)
 local tested=false
 for _,recipe in ipairs(recipes) do
  if recipe.method=="normal" then
   local items={}
   local slots=recipe.width>0 and recipe.width*3 or #recipe.items
   for index=1,math.max(slots,#recipe.items) do items[index]=concrete_item(recipe.items[index] or "") end
   local result=core.get_craft_result({method="normal",width=recipe.width,items=items})
   eq(resolve(result.item:get_name()),resolve(name),"Actual crafting result for "..name)
   tested=true;break
  end
 end
 assert(tested,"No normal selected recipe: "..name)
end
local function check_pcb_etching()
 -- A consumable fixture checks the upstream right-click transformation and its
 -- ten-use acid limit. This does not claim these boards were gathered in play.
 local pos=p(13,8)
 local inventory=core.create_detached_inventory("era_etching_smoke",{})
 inventory:set_size("main",4)
 local player={get_player_name=function() return actor end,get_inventory=function() return inventory end}
 local pointed={type="node",under=pos,above=vector.offset(pos,0,1,0)}
 core.set_node(pos,{name="mcl_core:water_source"})
 local acid=core.registered_items["elepower_dynamics:acidic_compound"].on_place(ItemStack("elepower_dynamics:acidic_compound"),player,pointed)
 assert(acid:is_empty(),"Etching consumes one acidic compound")
 eq(core.get_node(pos).name,"elepower_dynamics:etching_acid_source","Water becomes stock etching acid")
 local blank=ItemStack("elepower_dynamics:pcb_blank 11")
 for _=1,10 do blank=core.registered_items["elepower_dynamics:pcb_blank"].on_place(blank,player,pointed) end
 eq(blank:get_count(),1,"Ten etches consume ten blank boards")
 assert(inventory:contains_item("main","elepower_dynamics:pcb 10"),"Ten etched PCB enter player inventory")
 eq(core.get_node(pos).name,"mcl_core:water_source","Acid reverts to water after ten etches")
 local before=blank:to_string()
 blank=core.registered_items["elepower_dynamics:pcb_blank"].on_place(blank,player,pointed)
 eq(blank:to_string(),before,"Water cannot etch an eleventh PCB")
 core.remove_node(pos)
end
local function run()
 eq(core.get_game_info().id,"golden_era_playtest","Isolated playtest game")
 assert(not core.get_modpath("era_thermal"),"Historical prototype must remain separate")
 eq(xcompat.gameid,"mineclonia","Mineclonia compatibility selected")
 dofile(core.get_modpath("era_playtest_smoke").."/progression.lua")()
 for _,name in ipairs({"elepower_machines:generator","elepower_machines:power_cell_0","elepower_machines:pulverizer","elepower_machines:furnace",
  "elepower_dynamics:conduit","pipeworks:tube_1","pipeworks:mese_filter","fluid_tanks:tank","drawers:oakwood1",
  "elepower_machines:grindstone","elepower_machines:crank","elepower_machines:coal_alloy_furnace",
  "elepower_machines:machine_block","elepower_dynamics:steel_block",
  "elepower_farming:planter","elepower_farming:harvester"}) do
  assert(core.registered_nodes[name],"Missing selected playable node: "..name)
  check_craft(name)
 end
 for _,name in ipairs({"basic_materials:motor","basic_materials:empty_spool","basic_materials:copper_wire",
  "elepower_dynamics:brass_gear","elepower_dynamics:lead_gear","elepower_dynamics:wound_copper_coil",
  "elepower_dynamics:pcb_blank","elepower_dynamics:chip","elepower_dynamics:capacitor",
  "elepower_dynamics:acidic_compound","elepower_dynamics:integrated_circuit","elepower_wireless:card"}) do check_craft(name) end
 eq(ele.external.ing.steel_block,"elepower_dynamics:steel_block","Native steel block mapping")
 local miner=assert(core.get_all_craft_recipes("elepower_mining:miner_core"),"Miner core recipe exists")[1]
 local steel_blocks=0
 for _,name in ipairs(miner.items) do if name=="elepower_dynamics:steel_block" then steel_blocks=steel_blocks+1 end end
 eq(steel_blocks,4,"Mining recipe retains its four stock steel blocks")
 for _,name in ipairs({"mcl_core:coal_lump","mcl_raw_ores:raw_iron","elepower_dynamics:iron_dust"}) do
  assert(core.registered_items[name],"Missing industrial input/output: "..name)
 end
 for _,x in ipairs({-1,0}) do for _,z in ipairs({-1,0}) do
  assert(core.forceload_block(p(x,z),true),"Activate workshop mapblocks without a connected player")
 end end
 local positions=era_playtest.build_fixture(p(0),actor)
 check_pcb_etching()
 local generator,pulverizer,furnace,barrel,tank=positions.generator,positions.pulverizer,positions.furnace,positions.output,positions.tank
 eq(core.get_meta(generator):get_int("storage"),0,"Generator starts without injected power")
 eq(core.get_meta(pulverizer):get_int("storage"),0,"Pulverizer starts without injected power")
 eq(core.get_meta(furnace):get_int("storage"),0,"Furnace starts without injected power")
 eq(inv(pulverizer):get_stack("src",1):get_count(),2,"Workshop starts with two raw iron")
 eq(fluid_lib.insert_into_buffer(tank,"buffer","mcl_core:water_source",1000),0,"Full water insertion")
 eq(fluid_lib.get_buffer_data(tank,"buffer").amount,1000,"Stored 1000mB")
 local fluid,amount=fluid_lib.take_from_buffer(tank,"buffer",250)
 eq(fluid,"mcl_core:water_source","Drained water identity"); eq(amount,250,"Drained amount")
 eq(fluid_lib.get_buffer_data(tank,"buffer").amount,750,"Fluid balance after drain")
 eq(fluid_lib.insert_into_buffer(tank,"buffer","mcl_core:water_source",7500),250,"Nearly full tank returns exact overflow")
 eq(fluid_lib.get_buffer_data(tank,"buffer").amount,8000,"Nearly full tank fills to its capacity")
 local recipe=elepm.get_recipe("grind",{ItemStack("mcl_raw_ores:raw_iron")})
 assert(recipe.time>0,"Raw iron must have a stock grinding recipe")
 local output=type(recipe.output)=="table" and recipe.output[1] or recipe.output
 eq(ItemStack(output):get_name(),"elepower_dynamics:iron_dust","Stock grinding result")
 eq(ItemStack(output):get_count(),2,"Stock raw-iron doubling")
 local started=core.get_us_time()
 local observed_power=false
 local observed_dust=false
 local observed_furnace=false
 local function poll()
  if finished then return end
  checked(function()
   if core.get_meta(pulverizer):get_int("storage")>0 or core.get_meta(pulverizer):get_int("src_time")>0 then observed_power=true end
   if not inv(pulverizer):is_empty("dst") then observed_dust=true end
   if not inv(furnace):is_empty("src") or core.get_meta(furnace):get_int("src_time")>0 then observed_furnace=true end
   local stored=inv(barrel):get_stack("main",1)
   if stored:get_name()=="mcl_core:iron_ingot" and stored:get_count()==4 then
    assert(observed_power and observed_dust and observed_furnace,"Observed native power, dust and furnace processing")
    assert(inv(pulverizer):is_empty("src") and inv(pulverizer):is_empty("dst"),"Pulverizer batch is complete and extracted")
    assert(inv(furnace):is_empty("src") and inv(furnace):is_empty("dst"),"Furnace batch is complete and extracted")
    assert(inv(generator):get_stack("src",1):get_count()<8,"Stock generator consumed coal")
    finish(true,"playable workshop: stock coal generator/conduits power two raw iron into four ingots; stock Mesecons pulses, filter-injectors and tubes collect all four in barrel; selected recipes craft and water overflow/drain conserves volume")
   elseif core.get_us_time()-started>150*1000000 then
    error("Workshop timeout: generator="..core.get_meta(generator):get_string("infotext").."; pulverizer="..core.get_meta(pulverizer):get_string("infotext").."; furnace="..core.get_meta(furnace):get_string("infotext").."; output="..stored:to_string())
   else core.after(0.2,poll) end
  end)
 end
 core.after(0.2,poll)
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-8,-5),p(14,9),function(_,_,remaining)
   if remaining==0 then core.after(0,function()
    checked(function() core.load_area(p(-8,-5),p(14,9));run() end)
   end) end
  end)
 end)
end)
