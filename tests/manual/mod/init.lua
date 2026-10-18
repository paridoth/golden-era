-- SPDX-License-Identifier: GPL-3.0-or-later
-- Enabled only by scripts/play-demo.py in its dedicated QA world.
local storage=core.get_mod_storage()
local locations={generator=vector.new(0,200,2),buffer=vector.new(1,200,2),pulverizer=vector.new(0,200,0),furnace=vector.new(1,200,0)}
local chest_pos=vector.new(3,200,0)
local function place(pos,name)
 core.set_node(pos,{name=name})
 local def=assert(core.registered_nodes[name]);if def.on_construct then def.on_construct(pos) end
end
core.register_chatcommand("factory_form",{
 params="generator | buffer | pulverizer | furnace",description="Inspect a fixture's native form",
 func=function(name,param)
  local pos=locations[param];if not pos then return false,"Choose generator, buffer, pulverizer or furnace" end
  era.refresh(pos)
  local form=core.get_meta(pos):get_string("formspec")
  form=form:gsub("context;","nodemeta:"..pos.x..","..pos.y..","..pos.z..";")
  core.show_formspec(name,"era_demo:"..param,form)
  return true
 end})
local function iron_count(inv,list)
 local count=0
 for _,stack in ipairs(inv:get_list(list) or {}) do
  if stack:get_name()==era.mcl.ingot then count=count+stack:get_count() end
 end
 return count
end
local function busy()
 for _,id in ipairs({"pulverizer","furnace"}) do
  local m=core.get_meta(locations[id]);local inv=m:get_inventory()
  if m:get_int("work")>0 or not inv:is_empty("src") or not inv:is_empty("dst") then return true end
 end
 return false
end
core.register_chatcommand("factory_status",{
 description="Report actual output quantities and the effective inventory mode",
 func=function(name)
  local player=core.get_player_by_name(name)
  if not player then return false,"Player is not online." end
  local chest=iron_count(core.get_meta(chest_pos):get_inventory(),"main")
  return true,(core.is_creative_enabled(name) and "CREATIVE: quantities are not a survival check" or "Survival inventory")..
   " | Output chest: "..chest.." iron ingots | Your inventory: "..iron_count(player:get_inventory(),"main")..
   " iron ingots | "..(busy() and "Processing; wait before refilling." or "Batch finished.")
 end})
core.register_chatcommand("factory_refill",{
 description="Add one checked batch: coal, water bucket and two raw iron",
 func=function(name)
  if core.is_creative_enabled(name) then return false,"Use survival mode for the quantity check." end
  for id,pos in pairs(locations) do
   local expected="era_thermal:"..id
   if core.get_node(pos).name~=expected or not era.machine_ready(pos,expected) then return false,"Restore the fixture's "..id.." and resolve any paused state first." end
  end
  if core.get_node(vector.new(0,200,1)).name~="era_energy:cable" or core.get_node(vector.new(2,200,0)).name~="era_transport:ejector" then return false,"Restore the factory cable and ejector first." end
  if busy() then return false,"A batch is still processing. /factory_status reports the current chest count." end
  if core.get_node(chest_pos).name~="mcl_chests:chest_small" or not core.get_meta(chest_pos):get_inventory():room_for_item("main",era.mcl.ingot.." 4") then return false,"Restore the ordinary output chest and leave room for four ingots." end
  local jobs={{locations.generator,"fuel",era.mcl.coal},{locations.generator,"water",era.mcl.water_bucket},{locations.pulverizer,"src",era.mcl.raw_iron.." 2"}}
  for _,job in ipairs(jobs) do
   if not era.allowed(job[1],{get_player_name=function() return name end}) or not era.machine_ready(job[1],core.get_node(job[1]).name) or not core.get_meta(job[1]):get_inventory():room_for_item(job[2],job[3]) then return false,"Clear the fixture's input slots and check its state first." end
  end
  local before=iron_count(core.get_meta(chest_pos):get_inventory(),"main")
  for _,job in ipairs(jobs) do assert(core.get_meta(job[1]):get_inventory():add_item(job[2],job[3]):is_empty()) end
  return true,"Batch started. Chest currently has "..before.." iron ingots; expect "..(before+4).." if you leave them there. Processing can take a few minutes. /factory_status shows progress."
 end})
core.register_on_player_receive_fields(function(player,form,fields)
 local param=form:match("^era_demo:(%a+)$");local pos=locations[param]
 if not pos then return end
 local def=core.registered_nodes[core.get_node(pos).name]
 def.on_receive_fields(pos,"",fields,player)
 if not fields.quit then core.registered_chatcommands.factory_form.func(player:get_player_name(),param) end
 return true
end)
core.register_on_joinplayer(function(player)
 local name=player:get_player_name()
 core.emerge_area(vector.new(-16,192,-16),vector.new(16,208,16),function(_,_,remaining)
  if remaining~=0 then return end
  core.after(0,function()
   local current=core.get_player_by_name(name);if not current then return end
   assert(mcl_gamemode.set_gamemode(current,"survival"))
   assert(not core.is_creative_enabled(name),"Factory quantity check requires survival inventory rules")
   if storage:get_int("placed")~=1 then
    for x=-8,8 do for z=-5,8 do core.set_node(vector.new(x,199,z),{name="mcl_core:stone"}) end end
    for id,pos in pairs(locations) do place(pos,"era_thermal:"..id) end
    place(vector.new(0,200,1),"era_energy:cable")
    place(vector.new(2,200,0),"era_transport:ejector")
    place(chest_pos,"mcl_chests:chest_small")
    local actor={get_player_name=function() return name end}
    assert(era.configure_side(locations.furnace,4,1,actor))
    core.get_meta(locations.generator):get_inventory():set_stack("fuel",1,era.mcl.coal)
    core.get_meta(locations.generator):get_inventory():set_stack("water",1,era.mcl.water_bucket)
    core.get_meta(locations.pulverizer):get_inventory():set_stack("src",1,era.mcl.raw_iron.." 2")
    storage:set_int("placed",1)
   end
   current:set_pos(vector.new(1,200,5));current:set_look_horizontal(math.pi);current:set_look_vertical(0.25)
   local privileges=core.get_player_privs(name);privileges.fly=true;privileges.fast=true;core.set_player_privs(name,privileges)
   core.set_timeofday(0.5)
   core.chat_send_player(name,"Survival inventory check (damage off). Factory starts with two raw iron: expect four ingots. /factory_status reports exact chest/player counts. /factory_refill starts another batch after completion. Right-click machines or use /factory_form generator|pulverizer|furnace|buffer.")
   local form=core.settings:get("era_demo_form")
   if form and locations[form] then core.after(3,function() if core.get_player_by_name(name) then core.registered_chatcommands.factory_form.func(name,form) end end) end
   if core.settings:get_bool("era_demo_cycle",false) then
    for index,id in ipairs({"pulverizer","generator","furnace","buffer"}) do
     core.after(4+(index-1)*8,function()
      if core.get_player_by_name(name) then core.registered_chatcommands.factory_form.func(name,id);core.log("action","ERA DEMO FORM: "..id) end
     end)
    end
   end
   core.log("action","ERA DEMO READY: survival inventory verified; isolated factory and player initialized")
  end)
 end)
end)
