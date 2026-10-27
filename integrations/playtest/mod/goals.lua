-- SPDX-License-Identifier: GPL-3.0-or-later
-- Starter goals: an ordered checklist from the first log to item routing, each
-- with a small reward. A goal completes when its item is in the inventory or
-- was just crafted, so chest loot counts too. Progress lives in player meta and
-- therefore follows the character hand-over.
local GOALS={
 {id="wood",group="tree",text="Collect a log",hint="Punch a tree trunk until it drops.",reward="mcl_core:apple 3"},
 {id="stone_pick",item="mcl_tools:pick_stone",text="Craft a stone pickaxe",hint="Sticks and cobblestone at a crafting table.",reward="mcl_torches:torch 8"},
 {id="iron",item="mcl_core:iron_ingot",text="Smelt an iron ingot",hint="Raw iron and coal in a furnace.",reward="mcl_farming:bread 4"},
 {id="copper",item="mcl_copper:copper_ingot",text="Smelt a copper ingot",hint="Copper ore is stone with orange specks.",reward="mcl_core:coal_lump 8"},
 {id="grindstone",item="elepower_machines:grindstone",text="Craft a Grindstone",hint="Place a Hand Crank on top and right-click it to grind.",reward="mcl_raw_ores:raw_iron 4"},
 {id="alloy",item="elepower_machines:coal_alloy_furnace",text="Craft a Coal-fired Alloy Furnace",hint="Bricks, two furnaces and coal; see the Metals page.",reward="mcl_copper:copper_ingot 4"},
 {id="generator",item="elepower_machines:generator",text="Craft a Coal-fired Generator",hint="See the First power page in /manual.",reward="elepower_dynamics:conduit 8"},
 {id="pulverizer",item="elepower_machines:pulverizer",text="Craft a Pulverizer",hint="Connect it to the generator with conduit.",reward="mcl_core:coal_lump 16"},
 {id="dust",item="elepower_dynamics:iron_dust",text="Pulverize raw iron into dust",hint="Power the Pulverizer and put raw iron in it.",reward="mcl_raw_ores:raw_iron 8"},
 {id="routing",item="pipeworks:mese_filter",text="Craft a filter-injector",hint="Tubes and a blinking control move items for you.",reward="pipeworks:tube_1 8"},
}
era_playtest.goals=GOALS
local PROGRESS,HIDDEN="era_playtest_goals","era_playtest_goals_hidden"
local huds={}

local function holds(inv,goal)
 if goal.item then return inv:contains_item("main",goal.item) end
 for _,stack in ipairs(inv:get_list("main") or {}) do
  if not stack:is_empty() and core.get_item_group(stack:get_name(),goal.group)>0 then return true end
 end
 return false
end

local function reward(player,item)
 local leftover=player:get_inventory():add_item("main",item)
 if not leftover:is_empty() then core.add_item(player:get_pos(),leftover) end
end

local function refresh_hud(player)
 local name=player:get_player_name()
 local done=player:get_meta():get_int(PROGRESS)
 local goal=GOALS[done+1]
 local text=goal and player:get_meta():get_int(HIDDEN)~=1 and
  ("Goal "..(done+1).."/"..#GOALS..": "..goal.text.."\n"..goal.hint.."  (/goals)") or nil
 if huds[name] and not text then player:hud_remove(huds[name]);huds[name]=nil
 elseif huds[name] then player:hud_change(huds[name],"text",text)
 elseif text then
  huds[name]=player:hud_add({type="text",position={x=1,y=0.3},alignment={x=-1,y=1},offset={x=-12,y=0},
   number=0xFFE7A0,size={x=1,y=1},z_index=50,text=text})
 end
end

-- Complete every satisfied goal in order; crafted names count before they reach the inventory.
function era_playtest.advance_goals(player,crafted)
 local meta=player:get_meta()
 local done=meta:get_int(PROGRESS)
 local name=player:get_player_name()
 local inv=player:get_inventory()
 local before=done
 while GOALS[done+1] do
  local goal=GOALS[done+1]
  local made=crafted and (crafted==goal.item or (goal.group and core.get_item_group(crafted,goal.group)>0))
  if not (made or holds(inv,goal)) then break end
  done=done+1
  meta:set_int(PROGRESS,done)
  reward(player,goal.reward)
  local stack=ItemStack(goal.reward)
  local def=core.registered_items[stack:get_name()]
  core.chat_send_player(name,"Goal complete: "..goal.text..". Reward: "..stack:get_count().." "..
   core.strip_colors((def and def.description or stack:get_name()):match("^[^\n]*")))
 end
 if done~=before then
  if not GOALS[done+1] then core.chat_send_player(name,"All starter goals complete. /manual has more to build next.") end
  refresh_hud(player)
 end
end

function era_playtest.show_goals(name)
 local player=core.get_player_by_name(name);if not player then return end
 local done=player:get_meta():get_int(PROGRESS)
 local rows={}
 for i,goal in ipairs(GOALS) do
  local mark=i<=done and "[done] " or (i==done+1 and "[now]  " or "       ")
  rows[#rows+1]=core.formspec_escape(mark..i..". "..goal.text)
 end
 local current=GOALS[done+1]
 local hidden=player:get_meta():get_int(HIDDEN)==1
 core.show_formspec(name,"era_playtest:goals","formspec_version[4]size[11,9]label[0.5,0.5;Starter goals]"..
  "textlist[0.5,1;10,5.6;list;"..table.concat(rows,",")..";"..math.min(done+1,#GOALS)..";false]"..
  "textarea[0.5,6.8;10,1;;;"..core.formspec_escape(current and current.hint or "All starter goals complete.").."]"..
  "button[0.5,8;4,0.7;toggle;"..(hidden and "Show goal on screen" or "Hide goal on screen").."]"..
  "button_exit[7,8;3.5,0.7;close;Continue]")
end

core.register_chatcommand("goals",{description="Show the starter goals and rewards",func=function(name)
 era_playtest.show_goals(name);return true
end})

core.register_on_player_receive_fields(function(player,formname,fields)
 if formname~="era_playtest:goals" then return false end
 if fields.toggle then
  local meta=player:get_meta()
  meta:set_int(HIDDEN,meta:get_int(HIDDEN)==1 and 0 or 1)
  refresh_hud(player)
  era_playtest.show_goals(player:get_player_name())
 end
 return true
end)

core.register_on_mods_loaded(function()
 -- Drop goals whose items another mod set does not provide, keeping the order.
 for i=#GOALS,1,-1 do
  local goal=GOALS[i]
  if (goal.item and not core.registered_items[goal.item]) or not core.registered_items[ItemStack(goal.reward):get_name()] then
   core.log("warning","[era_playtest] Starter goal skipped: "..goal.id)
   table.remove(GOALS,i)
  end
 end
end)

core.register_on_joinplayer(function(player)
 -- After the character hand-over, which can replace meta and inventory.
 core.after(1,function()
  local current=core.get_player_by_name(player:get_player_name())
  if current then refresh_hud(current);era_playtest.advance_goals(current) end
 end)
end)
core.register_on_leaveplayer(function(player) huds[player:get_player_name()]=nil end)
core.register_on_craft(function(itemstack,player)
 if player and player:is_player() then
  local name,crafted=player:get_player_name(),itemstack:get_name()
  core.after(0,function()
   local current=core.get_player_by_name(name)
   if current then era_playtest.advance_goals(current,crafted) end
  end)
 end
end)
local elapsed=0
core.register_globalstep(function(dtime)
 elapsed=elapsed+dtime
 if elapsed<3 then return end
 elapsed=0
 for _,player in ipairs(core.get_connected_players()) do era_playtest.advance_goals(player) end
end)
