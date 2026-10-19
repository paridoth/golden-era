-- SPDX-License-Identifier: GPL-3.0-or-later
-- First-join choices never reset inventories, worlds or returning-player positions.
local function workshop_kit(player)
 local inv=player:get_inventory()
 for _,item in ipairs({"mcl_tools:pick_diamond","mcl_tools:axe_diamond","mcl_torches:torch 32"}) do
  local stack=ItemStack(item)
  if core.registered_items[stack:get_name()] and inv:room_for_item("main",stack) then inv:add_item("main",stack) end
 end
 if core.is_singleplayer() then
  local name=player:get_player_name()
  local privs=core.get_player_privs(name)
  privs.fly=true;privs.fast=true;privs.server=true;privs.give=true
  core.set_player_privs(name,privs)
 end
end

function era_playtest.show_start_choice(name)
 local player=core.get_player_by_name(name)
 if not player or player:get_meta():get_int("era_playtest_joined")==1 then return end
 local permissions=core.is_singleplayer() and "Flight and testing commands are enabled." or "Your server privileges stay as configured."
 core.show_formspec(name,"era_playtest:start",
  "formspec_version[4]size[12,7]label[0.6,0.6;Welcome to Golden Era]"..
  "textarea[0.6,1.2;10.8,1.4;;;Choose where to begin. Both options use the same world. Your choice never clears your inventory.]"..
  "button[0.7,2.8;4.9,0.9;start_workshop;Try the supplied workshop]"..
  "textarea[0.7,3.8;4.9,2.1;;;A ready-to-run factory plus tools and spare materials. "..permissions.."]"..
  "button[6.3,2.8;4.9,0.9;start_survival;Start in survival]"..
  "textarea[6.3,3.8;4.9,2.1;;;Stay at the natural spawn and gather your own materials. No tools or materials are granted. Damage stays disabled in this playtest.]"..
  "label[0.7,6.3;Use /startchoice to reopen this choice. /factoryguide explains the first machines.]")
end

local function choose(player,mode)
 local meta=player:get_meta()
 if meta:get_int("era_playtest_joined")==1 then return end
 -- Record once before any asynchronous terrain work or another button event.
 meta:set_int("era_playtest_joined",1)
 meta:set_string("era_playtest_start_mode",mode)
 local name=player:get_player_name()
 core.close_formspec(name,"era_playtest:start")
 if mode=="workshop" then
  workshop_kit(player)
  era_playtest.visit_workshop(name,true)
 else
  core.chat_send_player(name,"Gather your own materials. /factoryguide explains the first factory; /workshop visits the optional demonstration.")
  era_playtest.show_factory_guide(name,1)
 end
end

core.register_chatcommand("startchoice",{description="Choose a starting path before your first playtest session",func=function(name)
 local player=core.get_player_by_name(name)
 if not player then return false,"Player is offline." end
 if player:get_meta():get_int("era_playtest_joined")==1 then
  return false,"Your start is already saved. Use /explore, /workshop or /factoryguide to continue."
 end
 era_playtest.show_start_choice(name)
 return true
end})

core.register_on_player_receive_fields(function(player,formname,fields)
 if formname~="era_playtest:start" then return false end
 if fields.quit then return true end
 if fields.start_workshop then choose(player,"workshop")
 elseif fields.start_survival then choose(player,"survival") end
 return true
end)

core.register_on_joinplayer(function(player)
 if core.settings:get_bool("era_playtest_no_welcome",false) then return end
 local name=player:get_player_name()
 core.after(1,function()
  local current=core.get_player_by_name(name)
  if not current then return end
  local meta=current:get_meta()
  if meta:get_int("era_playtest_joined")==1 then return end
  -- Capture the natural spawn once, including when a player dismisses the chooser.
  if meta:get_string("era_playtest_surface")=="" then
   meta:set_string("era_playtest_surface",core.serialize(current:get_pos()))
  end
  assert(mcl_gamemode.set_gamemode(current,"survival"))
  assert(not core.is_creative_enabled(name),"Playtest starts with survival inventory quantities")
  local mode=core.settings:get("era_playtest_start_mode") or "ask"
  if mode=="workshop" or mode=="survival" then choose(current,mode)
  else era_playtest.show_start_choice(name) end
 end)
end)
