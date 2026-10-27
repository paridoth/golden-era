-- SPDX-License-Identifier: GPL-3.0-or-later
-- Single player always names the character "singleplayer", while hosting the
-- same world from the menu uses the host's chosen name. Treat the two as one
-- character: whichever saved last hands its inventory, place and progress to
-- the other when it next joins. Mods cannot read an offline player, so the
-- hand-over starts once the world has been played with this version.
local storage=core.get_mod_storage()
local KEY="era_playtest_character"

local function linked(name)
 if core.is_singleplayer() then return name=="singleplayer" end
 local host=core.settings:get("name")
 return host~=nil and host~="" and host~="singleplayer" and name==host
end

local function snapshot(player)
 local inv=player:get_inventory()
 local lists={}
 for listname,list in pairs(inv:get_lists()) do
  local items={}
  for i,stack in ipairs(list) do items[i]=stack:to_string() end
  lists[listname]={size=inv:get_size(listname),items=items}
 end
 return {lists=lists,pos=player:get_pos(),hp=player:get_hp(),breath=player:get_breath(),
  look_h=player:get_look_horizontal(),look_v=player:get_look_vertical(),
  meta=player:get_meta():to_table()}
end

local function apply(player,data)
 local inv=player:get_inventory()
 for listname in pairs(inv:get_lists()) do
  if not data.lists[listname] then inv:set_list(listname,{}) end
 end
 for listname,list in pairs(data.lists) do
  inv:set_size(listname,list.size)
  inv:set_list(listname,list.items)
 end
 player:get_meta():from_table(data.meta)
 player:set_pos(data.pos)
 player:set_look_horizontal(data.look_h)
 player:set_look_vertical(data.look_v)
 player:set_hp(data.hp)
 player:set_breath(data.breath)
 -- Refresh HUDs and worn armor that were drawn from the previous values.
 if mcl_armor and mcl_armor.update then mcl_armor.update(player) end
 if mcl_experience and mcl_experience.update then mcl_experience.update(player) end
 if mcl_hunger and mcl_hunger.get_hunger and mcl_hunger.set_hunger then
  mcl_hunger.set_hunger(player,mcl_hunger.get_hunger(player))
 end
end

local function save(player)
 local name=player:get_player_name()
 if not linked(name) then return end
 storage:set_string(KEY,core.serialize({owner=name,data=snapshot(player)}))
end

local function read_record()
 local text=storage:get_string(KEY)
 return text~="" and core.deserialize(text) or nil
end

function era_playtest.join_character(player)
 local name=player:get_player_name()
 if not linked(name) then return end
 local record=read_record()
 if record and record.owner~=name then
  apply(player,record.data)
  core.log("action","[era_playtest] "..name.." continues as the character last saved by "..record.owner)
 elseif not record and not core.is_singleplayer() then
  core.chat_send_player(name,"To bring your single-player items here, open this world alone once, then host it again.")
 end
 save(player)
end

core.register_on_joinplayer(era_playtest.join_character)
core.register_on_leaveplayer(save)
core.register_on_shutdown(function()
 for _,player in ipairs(core.get_connected_players()) do save(player) end
end)
-- Keep the hand-over current if the game closes without a clean shutdown.
local elapsed=0
core.register_globalstep(function(dtime)
 elapsed=elapsed+dtime
 if elapsed<30 then return end
 elapsed=0
 for _,player in ipairs(core.get_connected_players()) do save(player) end
end)
