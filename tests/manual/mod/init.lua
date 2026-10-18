-- SPDX-License-Identifier: GPL-3.0-or-later
-- Enabled only by scripts/play-demo.py in its dedicated QA world.
local storage=core.get_mod_storage()
local locations={generator=vector.new(0,200,2),buffer=vector.new(1,200,2),pulverizer=vector.new(0,200,0),furnace=vector.new(1,200,0)}
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
core.register_chatcommand("factory_refill",{
 description="Add coal, a water bucket and two raw iron to the QA fixture",
 func=function(name)
  local jobs={{locations.generator,"fuel",era.mcl.coal},{locations.generator,"water",era.mcl.water_bucket},{locations.pulverizer,"src",era.mcl.raw_iron.." 2"}}
  for _,job in ipairs(jobs) do
   if not era.allowed(job[1],{get_player_name=function() return name end}) or not core.get_meta(job[1]):get_inventory():room_for_item(job[2],job[3]) then return false,"Clear the fixture's input slots first." end
  end
  for _,job in ipairs(jobs) do assert(core.get_meta(job[1]):get_inventory():add_item(job[2],job[3]):is_empty()) end
  return true,"Added inputs. Check the ordinary chest for four more iron ingots."
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
   if storage:get_int("placed")~=1 then
    for x=-8,8 do for z=-5,8 do core.set_node(vector.new(x,199,z),{name="mcl_core:stone"}) end end
    for id,pos in pairs(locations) do place(pos,"era_thermal:"..id) end
    place(vector.new(0,200,1),"era_energy:cable")
    place(vector.new(2,200,0),"era_transport:ejector")
    place(vector.new(3,200,0),"mcl_chests:chest_small")
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
   core.chat_send_player(name,"Golden Era inspection fixture. Right-click machines. /factory_form generator|pulverizer|furnace|buffer opens a form. /factory_refill adds another batch. Factory starts with coal, water and two raw iron.")
   local form=core.settings:get("era_demo_form")
   if form and locations[form] then core.after(3,function() if core.get_player_by_name(name) then core.registered_chatcommands.factory_form.func(name,form) end end) end
   if core.settings:get_bool("era_demo_cycle",false) then
    for index,id in ipairs({"pulverizer","generator","furnace","buffer"}) do
     core.after(4+(index-1)*8,function()
      if core.get_player_by_name(name) then core.registered_chatcommands.factory_form.func(name,id);core.log("action","ERA DEMO FORM: "..id) end
     end)
    end
   end
   core.log("action","ERA DEMO READY: isolated factory and player initialized")
  end)
 end)
end)
