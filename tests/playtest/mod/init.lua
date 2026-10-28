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
local function check_build_identity()
 local file=assert(io.open(core.get_game_info().path.."/build-info.json","rb"),"Assembled build identity exists")
 local text=file:read("*a");file:close()
 local expected=assert(core.parse_json(text),"Build identity is valid JSON")
 local actual=assert(era_playtest.build_info,"Runtime build identity exists")
 for _,field in ipairs({"version","revision","dirty","source"}) do
  eq(actual[field],expected[field],"Runtime uses assembled build identity: "..field)
 end
 assert(type(actual.version)=="string" and actual.version~="","Pack version exists")
 local command=assert(core.registered_chatcommands.packversion,"Version command registered")
 assert(not command.privs or next(command.privs)==nil,"Version command requires no elevated privileges")
 local ok,message=command.func(actor,"")
 assert(ok and type(message)=="string","Version command succeeds without elevated privileges")
 eq(message,era_playtest.format_packversion(),"Version command uses runtime build identity")
 assert(message:find(actual.version,1,true),"Version command contains running pack version")
 assert(message:find(core.get_version().string,1,true),"Version command contains running engine version")
 if actual.revision then assert(message:find(actual.revision,1,true),"Version command contains full source revision") end
 local show=core.show_formspec
 local captured
 core.show_formspec=function(name,formname,formspec)
  eq(name,actor,"Workshop help target");eq(formname,"era_playtest:help","Workshop help form")
  captured=formspec
 end
 era_playtest.show_workshop_help(actor)
 core.show_formspec=show
 assert(captured and captured:find(core.formspec_escape(actual.version),1,true),"Workshop help identifies running pack version")
 core.log("action","ERA PLAYTEST BUILD: "..message)
end
local function check_machine_buttons(generator)
 local sender={get_player_name=function()return actor end}
 local targets={generator,p(11,7),p(12,7)}
 core.set_node(targets[2],{name="elepower_farming:planter"})
 core.set_node(targets[3],{name="elepower_farming:harvester"})
 for _,pos in ipairs(targets) do
  local meta=core.get_meta(pos)
  local receive=assert(core.registered_nodes[core.get_node(pos).name].on_receive_fields)
  eq(meta:get_int("state"),0,"Fresh machine default remains Always on")
  for press=1,4 do
   receive(pos,"",{cyclestate=true},sender)
   eq(meta:get_int("state"),press%4,"Actual machine button reaches every native state")
  end
 end
 core.log("action","ERA PLAYTEST BUTTONS: generator/planter/harvester callbacks cycle on/off/signal modes and return to Always on")
end
local chest_route_source,chest_route_target,jetpack_cell,smeltery_pos,smeltery_cast_ok
local function run()
 eq(core.get_game_info().id,"golden_era_playtest","Isolated playtest game")
 assert(not core.get_modpath("era_thermal"),"Historical prototype must remain separate")
 eq(xcompat.gameid,"mineclonia","Mineclonia compatibility selected")
 eq(#era_playtest.goals,10,"Every starter goal item and reward exists in the assembled game")
 for _,goal in ipairs(era_playtest.goals) do
  assert(goal.group or core.registered_items[goal.item],"Starter goal item: "..goal.id)
 end
 assert(core.registered_chatcommands.goals,"Goals command registered")
 -- Real inventory semantics: a log counts through its group, rewards land in the inventory.
 local goal_inv=core.create_detached_inventory("era_goals_probe",{})
 goal_inv:set_size("main",32)
 goal_inv:add_item("main","mcl_trees:tree_birch")
 goal_inv:add_item("main","mcl_tools:pick_stone")
 local fields,hud={},nil
 local goal_player={get_player_name=function() return actor end,get_inventory=function() return goal_inv end,
  get_pos=function() return vector.zero() end,
  get_meta=function() return {get_int=function(_,k) return fields[k] or 0 end,set_int=function(_,k,v) fields[k]=v end} end,
  hud_add=function(_,def) hud=def.text;return 1 end,hud_change=function(_,_,_,text) hud=text end,hud_remove=function() hud=nil end}
 era_playtest.advance_goals(goal_player)
 eq(fields.era_playtest_goals,2,"A birch log and a stone pickaxe complete the first two goals")
 assert(goal_inv:contains_item("main","mcl_core:apple 3") and goal_inv:contains_item("main","mcl_torches:torch 8"),"Goal rewards reach the inventory")
 assert(hud and hud:find("Smelt an iron ingot",1,true),"The screen line shows the third goal")
 core.log("action","ERA PLAYTEST GOALS: ten starter goals registered; log group, crafted tool and rewards work with a real inventory")
 check_build_identity()
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
 check_machine_buttons(positions.generator)
 check_pcb_etching()
 local generator,pulverizer,furnace,barrel,tank=positions.generator,positions.pulverizer,positions.furnace,positions.output,positions.tank
 eq(core.get_meta(generator):get_int("storage"),0,"Generator starts without injected power")
 eq(core.get_meta(pulverizer):get_int("storage"),0,"Pulverizer starts without injected power")
 eq(core.get_meta(furnace):get_int("storage"),0,"Furnace starts without injected power")
 local machine_info=table.concat(assert(era_playtest.look_lines(generator,"en"),"Generator look-at info"),"\n")
 assert(machine_info:find("[Elepower]",1,true) and machine_info:find("Power: 0 / ",1,true),"Look-at shows the mod and stored power: "..machine_info)
 local supplies_info=table.concat(assert(era_playtest.look_lines(positions.supplies,"en")),"\n")
 assert(supplies_info:find("Slots used: %d+ / %d+") and supplies_info:find("[Mineclonia]",1,true),"Look-at shows container use: "..supplies_info)
 eq(era_playtest.look_lines(vector.new(0,202,0),"en"),nil,"Air has no look-at info")
 -- Tiered chests: slot counts, upgrade recipes and look-at use.
 local previous="mcl_chests:chest"
 for i,tier in ipairs(era_playtest.chest_tiers) do
  local name="era_playtest:chest_"..tier.id
  local pos=vector.new(-6+i,200,6)
  core.set_node(pos,{name=name})
  eq(core.get_meta(pos):get_inventory():get_size("main"),({45,54,81,108})[i],tier.name.." slot count")
  local m,g=tier.metal,"mcl_core:glass"
  local grid=tier.id=="diamond" and {g,g,g,m,previous,m,g,g,g} or {m,m,m,m,previous,m,m,m,m}
  local items={}
  for k,item in ipairs(grid) do items[k]=ItemStack(item) end
  local result=core.get_craft_result({method="normal",width=3,items=items})
  eq(result.item:get_name(),name,tier.name.." is crafted from "..previous)
  assert(era_playtest.chest_formspec(pos,tier,tier.name):find("main;0.375,0.75;"..tier.cols..","..tier.rows..";",1,true),tier.name.." screen shows every slot")
  previous=name
 end
 local diamond=vector.new(-2,200,6)
 core.get_meta(diamond):get_inventory():add_item("main","mcl_core:cobble 64")
 assert(table.concat(era_playtest.look_lines(diamond,"en"),"\n"):find("Slots used: 1 / 108",1,true),"Look-at counts diamond chest slots")
 -- Pipeworks: a pulsed filter-injector pulls the cobble out through a tube into an iron chest.
 chest_route_source=diamond
 local route_filter,route_tube,route_target=vector.new(-1,200,6),vector.new(0,200,6),vector.new(1,200,6)
 local east
 for n=0,23 do if vector.equals(pipeworks.facedir_to_right_dir(n),{x=1,y=0,z=0}) then east=n;break end end
 core.set_node(route_filter,{name="pipeworks:mese_filter",param2=east})
 core.set_node(route_tube,{name="pipeworks:tube_1"})
 core.set_node(route_target,{name="era_playtest:chest_iron"})
 for x=-2,1 do pipeworks.scan_for_tube_objects(vector.new(x,200,6)) end
 assert(core.registered_nodes["era_playtest:chest_iron"].tube.can_insert(route_target,nil,ItemStack("mcl_core:cobble 64")),"Iron chest accepts tube items")
 local filter_def=core.registered_nodes["pipeworks:mese_filter"]
 filter_def.mesecons.effector.action_on(route_filter,core.get_node(route_filter))
 chest_route_target=route_target
 -- Jetpack: crafted from Elepower parts and charged by a real power cell.
 local s,c="elepower_dynamics:steel_ingot","elepower_dynamics:wound_copper_coil"
 local jet_grid={s,"elepower_dynamics:capacitor",s,s,"elepower_dynamics:battery",s,c,"",c}
 local jet_items={}
 for k,item in ipairs(jet_grid) do jet_items[k]=ItemStack(item) end
 eq(core.get_craft_result({method="normal",width=3,items=jet_items}).item:get_name(),"era_playtest:jetpack","Jetpack recipe")
 assert(core.get_item_group("era_playtest:jetpack","ele_tool")>0,"Jetpack is an Elepower tool")
 jetpack_cell=vector.new(3,200,6)
 core.set_node(jetpack_cell,{name="elepower_machines:power_cell_0"})
 core.get_meta(jetpack_cell):set_int("storage",5000)
 core.get_meta(jetpack_cell):get_inventory():set_stack("src",1,"era_playtest:jetpack")
 ele.helpers.start_timer(jetpack_cell)
 -- Smeltery: a real 3x3 structure melts two raw iron and an ingot with lava fuel.
 local sbase=vector.new(40,200,40)
 core.emerge_area(vector.offset(sbase,-1,-2,-1),vector.offset(sbase,5,3,5),function(_,_,left)
  if left>0 then return end
  checked(function()
   for x=0,4 do for z=0,4 do for y=-1,2 do core.set_node(vector.offset(sbase,x,y,z),{name="air"}) end end end
   for x=1,3 do for z=1,3 do core.set_node(vector.offset(sbase,x,-1,z),{name="era_playtest:seared_bricks"}) end end
   for i=1,3 do
    for _,o in ipairs({{i,0},{i,4},{0,i},{4,i}}) do core.set_node(vector.offset(sbase,o[1],0,o[2]),{name="era_playtest:seared_bricks"}) end
   end
   assert(core.forceload_block(vector.offset(sbase,2,0,2),true),"Activate the smeltery mapblock without a connected player")
   smeltery_pos=vector.offset(sbase,2,0,0)
   core.set_node(smeltery_pos,{name="era_playtest:smeltery_controller",param2=0})
   local sinv=core.get_meta(smeltery_pos):get_inventory()
   eq(sinv:get_size("melt"),9,"Real smeltery has one slot per interior block")
   sinv:set_stack("melt",1,"mcl_raw_ores:raw_iron 2")
   sinv:set_stack("melt",2,"mcl_core:iron_ingot")
   sinv:set_stack("fuel",1,"mcl_buckets:bucket_lava")
   -- Casting: a drain in each side wall, faucets outside, a table (with cast) and a basin below.
   core.set_node(vector.offset(sbase,4,0,2),{name="era_playtest:seared_drain",param2=1})
   core.set_node(vector.offset(sbase,0,0,2),{name="era_playtest:seared_drain",param2=3})
   local table_faucet,basin_faucet=vector.offset(sbase,5,0,2),vector.offset(sbase,-1,0,2)
   core.set_node(table_faucet,{name="era_playtest:faucet",param2=3})
   core.set_node(basin_faucet,{name="era_playtest:faucet",param2=1})
   local cast_table,basin=vector.offset(sbase,5,-1,2),vector.offset(sbase,-1,-1,2)
   core.set_node(cast_table,{name="era_playtest:casting_table"})
   core.set_node(basin,{name="era_playtest:casting_basin"})
   core.get_meta(cast_table):get_inventory():set_stack("cast",1,"era_playtest:ingot_cast")
   eq(era_playtest.drain_controller(vector.offset(sbase,4,0,2)) and true,true,"The drain finds its smeltery")
   core.after(30,function() checked(function()
    eq(era_playtest.smeltery_molten(core.get_meta(smeltery_pos)).iron,720,"Melted before pouring")
    local ok,message=era_playtest.faucet_pour(table_faucet)
    assert(ok,"Faucet pours into the casting table: "..tostring(message))
    local no,why=era_playtest.faucet_pour(basin_faucet)
    assert(not no and why:find("needs 1296 mB",1,true),"A block needs a full 1296 mB: "..tostring(why))
    core.after(4,function() checked(function()
     eq(core.get_meta(cast_table):get_inventory():get_stack("output",1):get_name(),"mcl_core:iron_ingot","The table casts an iron ingot")
     eq(era_playtest.smeltery_molten(core.get_meta(smeltery_pos)).iron,576,"Casting used 144 mB")
     smeltery_cast_ok=true
    end) end)
   end) end)
  end)
 end)
 core.log("action","ERA PLAYTEST LOOKINFO: "..machine_info:gsub("\n"," | ").." ; "..supplies_info:gsub("\n"," | "))
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
   if stored:get_name()=="mcl_core:iron_ingot" and stored:get_count()==4 and inv(chest_route_target):contains_item("main","mcl_core:cobble 64") then
    assert(inv(chest_route_source):is_empty("main"),"The diamond chest was emptied by the filter-injector")
    assert(smeltery_cast_ok,"Smeltery melted two raw iron and an ingot, then a faucet cast an iron ingot: "..(smeltery_pos and core.get_meta(smeltery_pos):get_string("infotext") or "not built"))
    eq(inv(smeltery_pos):get_stack("fuel",1):get_name(),"mcl_buckets:bucket_empty","Smeltery used the lava bucket")
    local jet=inv(jetpack_cell):get_stack("src",1)
    assert(jet:get_name()=="era_playtest:jetpack" and jet:get_meta():get_int("storage")>0,"A power cell charges the jetpack: "..jet:to_string())
    assert(observed_power and observed_dust and observed_furnace,"Observed native power, dust and furnace processing")
    assert(inv(pulverizer):is_empty("src") and inv(pulverizer):is_empty("dst"),"Pulverizer batch is complete and extracted")
    assert(inv(furnace):is_empty("src") and inv(furnace):is_empty("dst"),"Furnace batch is complete and extracted")
    assert(inv(generator):get_stack("src",1):get_count()<8,"Stock generator consumed coal")
    finish(true,"playable workshop: stock coal generator/conduits power two raw iron into four ingots; stock Mesecons pulses, filter-injectors and tubes collect all four in barrel; a filter-injector empties a diamond chest into an iron chest; a power cell charges the jetpack; a smeltery melts raw iron into double metal and a faucet casts it into an ingot; selected recipes craft and water overflow/drain conserves volume")
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
