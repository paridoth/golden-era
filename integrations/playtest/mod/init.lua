-- SPDX-License-Identifier: GPL-3.0-or-later
-- A one-time starter workshop; all production, routing and storage use upstream mods.
era_playtest = {}
dofile(core.get_modpath("era_playtest").."/build.lua")
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
  "elepower_machines:generator 2","elepower_machines:power_cell_0 2","elepower_tome:tome 1","mcl_farming:bread 32",
  "elepower_farming:planter 1","elepower_farming:harvester 1","mcl_farming:wheat_seeds 32",
  "mcl_core:dirt 8","mcl_bone_meal:bone_meal 32","mcl_farming:wheat_item 1"}
 if core.registered_nodes["mesecons_blinkyplant:blinky_plant_off"] then
  items[#items+1]="mesecons_blinkyplant:blinky_plant_off 2"
 end
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
  "left-click their front to take items out. Extra alloy furnaces and a fluid tank are ready to experiment with. "..
  "New workshops include farming parts in the supplies barrel; /factoryguide explains a small seed-return wheat farm.\n\n"..
  "/workshop returns here. /explore takes you to the survival spawn. "..
  "This world uses survival item quantities with damage disabled. In the single-player workshop, "..
  "K toggles flight and /gamemode creative enables the full item catalog. Server players need the appropriate privileges.\n\n"..
  "This first pack uses existing Luanti equivalents for Revelation-style technology, logistics and storage. "..
  "Build, explore and report what gets in your way; we will tune recipes and add systems as we play."
 core.show_formspec(name,"era_playtest:help","formspec_version[4]size[12,9]"..
  "label[0.5,0.5;"..core.formspec_escape("Golden Era "..era_playtest.build_info.version.." — Playtest Workshop")..
  "]textarea[0.5,1.1;11,6.6;;;"..
  core.formspec_escape(text).."]button[0.5,8;3.6,0.7;factory_guide;First factory guide]"..
  "button_exit[8,8;3.5,0.7;close;Let's play]")
end
era_playtest.show_workshop_help = help
core.register_chatcommand("packhelp",{description="Show playtest workshop instructions",func=function(name) help(name);return true end})
-- Session/request identities prevent old mapgen callbacks from moving a newly
-- connected player, or overriding a more recent travel/cancel request.
local sessions,travel={},{}
function era_playtest.player_session(name) return sessions[name] end
local function current_player(name,request)
 if travel[name]~=request or sessions[name]~=request.session then return end
 return core.get_player_by_name(name)
end
local function remove_loading(player,request)
 if request and request.hud~=nil then player:hud_remove(request.hud);request.hud=nil end
end
core.register_on_joinplayer(function(player)
 sessions[player:get_player_name()]={}
end)
core.register_on_leaveplayer(function(player)
 local name=player:get_player_name()
 remove_loading(player,travel[name])
 sessions[name]=nil;travel[name]=nil
 -- Pending metadata stays saved; the next session resumes without another kit.
end)
local function clear_pending(player)
 local meta=player:get_meta()
 meta:set_int("era_playtest_workshop_pending",0)
 meta:set_int("era_playtest_workshop_first",0)
end
local function cancel_workshop(name)
 local player=core.get_player_by_name(name);if not player then return false,"Player is offline." end
 local request=travel[name]
 local pending=player:get_meta():get_int("era_playtest_workshop_pending")==1
 if request and request.kind=="workshop" then
  remove_loading(player,request);travel[name]=nil;pending=true
 end
 clear_pending(player)
 if not pending then return false,"No workshop trip is waiting." end
 return true,"Workshop trip canceled. /workshop starts another trip whenever you are ready."
end
era_playtest.cancel_workshop=cancel_workshop
core.register_chatcommand("cancelworkshop",{description="Cancel a waiting workshop trip and stay where you are",func=cancel_workshop})
local function workshop_failed(name,request,reason)
 local player=current_player(name,request);if not player then return end
 remove_loading(player,request);travel[name]=nil
 core.log("warning","ERA PLAYTEST WORKSHOP RETRY: "..tostring(reason))
 core.chat_send_player(name,"The workshop could not finish loading. Your trip is saved. /workshop retries; /cancelworkshop cancels it.")
end
local function workshop(name,first)
 local player=core.get_player_by_name(name);if not player then return false,"Player is offline." end
 local session=sessions[name];if not session then return false,"Player is not ready." end
 local previous=travel[name]
 if previous and previous.kind=="workshop" and previous.session==session then
  return true,"Your workshop trip is already loading. Keep exploring; /cancelworkshop cancels the trip."
 end
 local meta=player:get_meta()
 meta:set_int("era_playtest_workshop_pending",1)
 if first then meta:set_int("era_playtest_workshop_first",1) end
 local request={kind="workshop",session=session,first=meta:get_int("era_playtest_workshop_first")==1}
 travel[name]=request
 request.hud=player:hud_add({type="text",position={x=0.5,y=0.2},alignment={x=0,y=0},
  number=0xFFE7A0,style=1,size={x=1,y=1},z_index=100,
  text="Preparing workshop terrain. You can keep exploring.\nYou will be moved when it is ready. /cancelworkshop cancels."})
 core.chat_send_player(name,"Preparing workshop terrain. You can keep exploring and will be moved when it is ready. /cancelworkshop cancels this trip.")
 local queued,err=pcall(core.emerge_area,at(origin,-8,-2,-5),at(origin,14,5,9),function(_,action,remaining)
  if not current_player(name,request) then return end
  if action==core.EMERGE_CANCELLED or action==core.EMERGE_ERRORED then
   workshop_failed(name,request,"terrain generation action "..tostring(action));return
  end
  if remaining~=0 then return end
  core.after(0,function()
   local current=current_player(name,request);if not current then return end
   local ok,failure=xpcall(function()
    if storage:get_int("workshop_v1")~=1 then
     era_playtest.build_fixture(origin,name);storage:set_int("workshop_v1",1)
    end
    current:set_pos(at(origin,3,0.5,6));current:set_look_horizontal(math.pi);current:set_look_vertical(0.2)
   end,debug.traceback)
   if not ok then workshop_failed(name,request,failure);return end
   clear_pending(current);remove_loading(current,request);travel[name]=nil
   if request.first then help(name) end
   core.chat_send_player(name,"Workshop ready. /packhelp for instructions; /explore for survival terrain; /workshop to return.")
   core.log("action","ERA PLAYTEST READY: workshop and existing-mod factory available for "..name)
  end)
 end)
 if not queued then workshop_failed(name,request,err);return false,"Could not queue the workshop trip." end
 return true
end
era_playtest.visit_workshop = workshop
core.register_chatcommand("workshop",{description="Return to the playtest workshop",func=function(name) return workshop(name,false) end})
local function explore(name)
 local player=core.get_player_by_name(name);if not player then return false,"Player is offline." end
 local session=sessions[name];if not session then return false,"Player is not ready." end
 cancel_workshop(name)
 local request={kind="surface",session=session};travel[name]=request
 local target=core.deserialize(player:get_meta():get_string("era_playtest_surface")) or mcl_spawn.get_world_spawn_pos(player)
 local queued,err=pcall(core.emerge_area,vector.subtract(target,16),vector.add(target,16),function(_,action,remaining)
  if not current_player(name,request) then return end
  if action==core.EMERGE_CANCELLED or action==core.EMERGE_ERRORED then
   travel[name]=nil;core.chat_send_player(name,"The survival terrain could not load. /explore retries the trip.");return
  end
  if remaining~=0 then return end
  core.after(0,function()
   local current=current_player(name,request)
   if current then current:set_pos(target);travel[name]=nil end
  end)
 end)
 if not queued then
  if current_player(name,request) then travel[name]=nil end
  core.log("warning","ERA PLAYTEST SURFACE RETRY: "..tostring(err))
  return false,"Could not queue the survival trip. /explore retries it."
 end
 return true,"Returning to survival terrain. /workshop brings you back."
end
era_playtest.return_to_surface = explore
core.register_chatcommand("explore",{description="Travel to the survival spawn",func=explore})

dofile(core.get_modpath("era_playtest").."/guide.lua")
dofile(core.get_modpath("era_playtest").."/character.lua")
dofile(core.get_modpath("era_playtest").."/onboarding.lua")
dofile(core.get_modpath("era_playtest").."/animals.lua")
