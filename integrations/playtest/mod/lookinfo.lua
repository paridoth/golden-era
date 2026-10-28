-- SPDX-License-Identifier: GPL-3.0-or-later
-- Look-at information, in the spirit of The One Probe: the pointed block's
-- name and mod, plus stored power for Elepower machines and how full a
-- container is. /lookinfo turns it off or on for each player.
local OFF="era_playtest_lookinfo_off"
local RANGE=6
local MODS={mcl="Mineclonia",mclx="Mineclonia",elepower="Elepower",pipeworks="Pipeworks",drawers="Storage Drawers",
 logistica="Logistica",magicalities="Magicalities",mesecons="Mesecons",travelnet="Travelnet",fluid="Fluid Lib",
 era="Golden Era"}
local huds,shown={},{}

function era_playtest.mod_title(itemname)
 local mod=itemname:match("^([^:]+):") or ""
 if mod=="mcl_extra_structures" then return "Extra Structures" end
 local title=MODS[mod] or MODS[mod:match("^([^_]+)_") or ""]
 if title then return title end
 return (mod:gsub("_"," "):gsub("^%l",string.upper))
end

local function plain(text,lang)
 if core.get_translated_string then text=core.get_translated_string(lang or "en",text) end
 return core.strip_colors(text):match("^[^\n]*")
end

-- Lines describing the node at pos; nil for air or unknown nodes.
function era_playtest.look_lines(pos,lang)
 local node=core.get_node(pos)
 local def=core.registered_nodes[node.name]
 if not def or node.name=="air" or node.name=="ignore" then return nil end
 local lines={plain(def.description or node.name,lang).."  ["..era_playtest.mod_title(node.name).."]"}
 local meta=core.get_meta(pos)
 local capacity=meta:get_int("capacity")
 if capacity==0 then capacity=def.ele_capacity or 0 end
 if capacity>0 then
  lines[#lines+1]="Power: "..meta:get_int("storage").." / "..capacity.." EpU"
 end
 local inv=meta:get_inventory()
 local size=inv:get_size("main")
 if size>0 then
  local used=0
  for _,stack in ipairs(inv:get_list("main")) do if not stack:is_empty() then used=used+1 end end
  lines[#lines+1]="Slots used: "..used.." / "..size
 end
 return lines
end

local function set_text(player,text)
 local name=player:get_player_name()
 if shown[name]==text then return end
 shown[name]=text
 if text=="" then
  if huds[name] then player:hud_remove(huds[name]);huds[name]=nil end
 elseif huds[name] then player:hud_change(huds[name],"text",text)
 else
  huds[name]=player:hud_add({type="text",position={x=0.5,y=0.16},alignment={x=0,y=1},
   number=0xFFFFFF,size={x=1,y=1},z_index=60,text=text})
 end
end

local function pointed_pos(player)
 local eye=vector.add(player:get_pos(),{x=0,y=player:get_properties().eye_height or 1.6,z=0})
 eye=vector.add(eye,vector.divide(player:get_eye_offset(),10))
 local ray=core.raycast(eye,vector.add(eye,vector.multiply(player:get_look_dir(),RANGE)),false,false)
 for hit in ray do
  if hit.type=="node" then return hit.under end
 end
end

local function update(player)
 if player:get_meta():get_int(OFF)==1 then set_text(player,"");return end
 local pos=pointed_pos(player)
 local info=core.get_player_information(player:get_player_name())
 local lines=pos and era_playtest.look_lines(pos,info and info.lang_code)
 set_text(player,lines and table.concat(lines,"\n") or "")
end

core.register_chatcommand("lookinfo",{description="Turn the look-at block information on or off",func=function(name)
 local player=core.get_player_by_name(name);if not player then return false,"Player is offline." end
 local meta=player:get_meta()
 local off=meta:get_int(OFF)==1
 meta:set_int(OFF,off and 0 or 1)
 update(player)
 return true,off and "Look-at information on." or "Look-at information off. /lookinfo turns it back on."
end})
core.register_on_leaveplayer(function(player)
 local name=player:get_player_name()
 huds[name]=nil;shown[name]=nil
end)
local elapsed=0
core.register_globalstep(function(dtime)
 elapsed=elapsed+dtime
 if elapsed<0.25 then return end
 elapsed=0
 for _,player in ipairs(core.get_connected_players()) do update(player) end
end)
