-- SPDX-License-Identifier: GPL-3.0-or-later
-- A one-time starter workshop; all production, routing and storage use upstream mods.
era_playtest = {}
local storage = core.get_mod_storage()
local origin = vector.new(0,200,0)
local function at(base,x,y,z) return vector.add(base,{x=x,y=y,z=z}) end
local function place(pos,name,param2,owner)
 assert(core.registered_nodes[name],"Missing workshop node: "..name)
 core.set_node(pos,{name=name,param2=param2 or 0}) -- runs the native constructor
 core.get_meta(pos):set_string("owner",owner or "")
end
local function right_facedir(direction)
 for n=0,23 do
  if vector.equals(pipeworks.facedir_to_right_dir(n),direction) then return n end
 end
 error("No filter orientation")
end
local function item_id(options)
 for _,name in ipairs(options) do if core.registered_items[name] then return name end end
 error("Missing starter item: "..table.concat(options,", "))
end
function era_playtest.build_fixture(base,owner)
 local positions={generator=at(base,-3,0,0),cell=at(base,-1,0,0),pulverizer=at(base,1,0,0),
  furnace=at(base,5,0,0),output=at(base,9,0,0),drawer=at(base,9,0,3),tank=at(base,7,0,3),
  supplies=at(base,-3,0,3),alloy=at(base,1,0,3),coal_alloy=at(base,3,0,3)}
 for x=-7,13 do for z=-4,8 do
  core.set_node(at(base,x,-1,z),{name="mcl_core:stone"})
  for y=0,3 do core.set_node(at(base,x,y,z),{name="air"}) end
  if x==-7 or x==13 or z==-4 or z==8 then core.set_node(at(base,x,0,z),{name="mcl_core:glass"}) end
 end end
 local machines={generator="generator",cell="power_cell_0",pulverizer="pulverizer",furnace="furnace",
  alloy="alloy_furnace",coal_alloy="coal_alloy_furnace"}
 for key,suffix in pairs(machines) do place(positions[key],"elepower_machines:"..suffix,0,owner) end
 for x=-3,5 do place(at(base,x,0,-1),"elepower_dynamics:conduit",0,owner) end
 place(positions.output,"mcl_barrels:barrel_closed",0,owner)
 place(positions.supplies,"mcl_barrels:barrel_closed",0,owner)
 place(positions.drawer,"drawers:oakwood1",0,owner)
 place(positions.tank,"fluid_tanks:tank",0,owner)
 place(at(base,-5,0,3),"mcl_crafting_table:crafting_table",0,owner)
 local east=right_facedir({x=1,y=0,z=0})
 for _,x in ipairs({2,6}) do
  place(at(base,x,0,0),"pipeworks:mese_filter",east,owner)
  if core.registered_nodes["mesecons_blinkyplant:blinky_plant_off"] then
   place(at(base,x,0,1),"mesecons_blinkyplant:blinky_plant_off",0,owner)
  end
 end
 for _,x in ipairs({3,4,7,8}) do place(at(base,x,0,0),"pipeworks:tube_1",0,owner) end
 for x=-3,9 do pipeworks.scan_for_tube_objects(at(base,x,0,0)) end
 local fuel=core.get_meta(positions.generator):get_inventory()
 fuel:set_stack("src",1,"mcl_core:coal_lump 8")
 core.get_meta(positions.pulverizer):get_inventory():set_stack("src",1,"mcl_raw_ores:raw_iron 2")
 ele.helpers.start_timer(positions.generator)
 ele.helpers.start_timer(positions.pulverizer)
 local supplies=core.get_meta(positions.supplies):get_inventory()
 local items={"mcl_core:coal_lump 64","mcl_raw_ores:raw_iron 32","mcl_core:iron_ingot 64",
  "mcl_copper:copper_ingot 64","elepower_dynamics:tin_ingot 32","elepower_dynamics:lead_ingot 16",
  "mcl_redstone:redstone 64","elepower_dynamics:conduit 32","pipeworks:tube_1 32",
  "pipeworks:mese_filter 4","drawers:oakwood1 4","drawers:controller 1","fluid_tanks:tank 4",
  "fluid_transfer:fluid_duct 16","fluid_transfer:fluid_transfer_pump 2","mcl_buckets:bucket_water 1",
  "elepower_machines:generator 2","elepower_machines:power_cell_0 2","elepower_tome:tome 1","mcl_farming:bread 32"}
 for _,stack in ipairs(items) do
  assert(core.registered_items[ItemStack(stack):get_name()],"Missing supply: "..stack)
  assert(supplies:add_item("main",stack):is_empty(),"Workshop supplies overflow")
 end
 ele.clear_networks(positions.generator)
 return positions
end
local function help(name)
 local text="Start with the coal generator, power cell, Pulverizer and powered furnace. "..
  "The two blinking controls pulse the filter-injectors to move dust and ingots through the tubes. "..
  "The barrel on the right collects ingots. The barrel at the front left holds building supplies.\n\n"..
  "Right-click machines to see their inventories. Use the Elepower Tome for machine help, "..
  "and the inventory recipe guide to find crafts. Drawers accept items by right-clicking; "..
  "left-click their front to take items out. Extra alloy furnaces and a fluid tank are ready to experiment with.\n\n"..
  "/workshop returns here. /explore takes you to the survival spawn. Press K to toggle flight. "..
  "This world uses survival item quantities with damage disabled. /gamemode creative enables the full item catalog.\n\n"..
  "This first pack uses existing Luanti equivalents for Revelation-style technology, logistics and storage. "..
  "Build, explore and report what gets in your way; we will tune recipes and add systems as we play."
 core.show_formspec(name,"era_playtest:help","formspec_version[4]size[12,9]"..
  "label[0.5,0.5;Golden Era — Playtest Workshop]textarea[0.5,1.1;11,6.6;;;"..
  core.formspec_escape(text).."]button_exit[4,8;4,0.7;close;Let's play]")
end
core.register_chatcommand("packhelp",{description="Show playtest workshop instructions",func=function(name) help(name);return true end})
local function workshop(name,first)
 core.emerge_area(at(origin,-8,-2,-5),at(origin,14,5,9),function(_,_,remaining)
  if remaining~=0 then return end
  core.after(0,function()
   local player=core.get_player_by_name(name);if not player then return end
   local ok,err=xpcall(function()
    if storage:get_int("workshop_v1")~=1 then
     era_playtest.build_fixture(origin,name);storage:set_int("workshop_v1",1)
    end
    player:set_pos(at(origin,3,0.5,6));player:set_look_horizontal(math.pi);player:set_look_vertical(0.2)
    if first then help(name) end
    core.chat_send_player(name,"Workshop ready. /packhelp for instructions; /explore for survival terrain; /workshop to return.")
    core.log("action","ERA PLAYTEST READY: workshop and existing-mod factory available for "..name)
   end,debug.traceback)
   if not ok then core.log("error","ERA PLAYTEST WORKSHOP FAIL: "..err);core.chat_send_player(name,"Workshop setup failed; see the game log.") end
  end)
 end)
end
core.register_chatcommand("workshop",{description="Return to the playtest workshop",func=function(name) workshop(name,false);return true,"Loading workshop..." end})
core.register_chatcommand("explore",{description="Travel to the survival spawn",func=function(name)
 local player=core.get_player_by_name(name);if not player then return false,"Player is offline." end
 local target=core.deserialize(player:get_meta():get_string("era_playtest_surface")) or mcl_spawn.get_world_spawn_pos(player)
 core.emerge_area(vector.subtract(target,16),vector.add(target,16),function(_,_,remaining)
  if remaining~=0 then return end
  core.after(0,function()
   local current=core.get_player_by_name(name);if current then current:set_pos(target) end
  end)
 end)
 return true,"Returning to survival terrain. /workshop brings you back."
end})
core.register_on_joinplayer(function(player)
 if core.settings:get_bool("era_playtest_no_welcome",false) then return end
 local name=player:get_player_name()
 core.after(1,function()
  local current=core.get_player_by_name(name);if not current then return end
  local meta=current:get_meta()
  local first=meta:get_int("era_playtest_joined")~=1
  if first then
   meta:set_string("era_playtest_surface",core.serialize(current:get_pos()))
   assert(mcl_gamemode.set_gamemode(current,"survival"))
   assert(not core.is_creative_enabled(name),"Playtest starts with survival inventory quantities")
   local inv=current:get_inventory()
   for _,item in ipairs({item_id({"mcl_tools:pick_diamond","mcl_core:pick_diamond"}),
    item_id({"mcl_tools:axe_diamond","mcl_core:axe_diamond"}),"mcl_torches:torch 32"}) do
    local stack=ItemStack(item)
    if core.registered_items[stack:get_name()] and inv:room_for_item("main",stack) then inv:add_item("main",stack) end
   end
   local privs=core.get_player_privs(name);privs.fly=true;privs.fast=true;privs.server=true;privs.give=true
   core.set_player_privs(name,privs);meta:set_int("era_playtest_joined",1)
  end
  if first then workshop(name,true) end
 end)
end)
