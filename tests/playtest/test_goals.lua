-- SPDX-License-Identifier: GPL-3.0-or-later
-- Starter goals complete in order, reward once and survive missing items.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local chats,hud,dropped,loaded,crafts={},{},{},{},{}
local groups={["mcl_trees:tree_oak"]={tree=1}}
local registered={}
ItemStack=function(text)
 local name,count=text:match("^(%S+)%s*(%d*)$")
 return {get_name=function() return name end,get_count=function() return tonumber(count) or 1 end,
  is_empty=function() return name==nil end,text=text}
end
core={registered_items=registered}
function core.get_item_group(name,group) return (groups[name] or {})[group] or 0 end
function core.chat_send_player(name,text) chats[#chats+1]=text end
function core.strip_colors(text) return text end
function core.log() end
function core.add_item(_,stack) dropped[#dropped+1]=stack.text end
function core.register_chatcommand() end
function core.register_on_player_receive_fields() end
function core.register_on_mods_loaded(callback) loaded[#loaded+1]=callback end
function core.register_on_joinplayer() end
function core.register_on_leaveplayer() end
function core.register_on_craft(callback) crafts[#crafts+1]=callback end
function core.register_globalstep() end
function core.formspec_escape(text) return text end
era_playtest={}
dofile(root.."/integrations/playtest/mod/goals.lua")
local goals=era_playtest.goals
for _,goal in ipairs(goals) do
 if goal.item then registered[goal.item]={description=goal.item} end
 registered[ItemStack(goal.reward):get_name()]={description="Reward "..ItemStack(goal.reward):get_name()}
end
-- A goal whose item is missing is skipped without breaking the order.
registered["elepower_machines:grindstone"]=nil
for _,callback in ipairs(loaded) do callback() end
eq(#goals,9,"Missing grindstone goal is dropped")
for _,goal in ipairs(goals) do assert(goal.id~="grindstone","Grindstone goal removed") end

local function player(items,full)
 local meta,list={},{}
 for i,item in ipairs(items) do list[i]=ItemStack(item) end
 local inv={}
 function inv:contains_item(_,item) for _,s in ipairs(list) do if s:get_name()==item then return true end end return false end
 function inv:get_list() return list end
 function inv:add_item(_,stack)
  if type(stack)=="string" then stack=ItemStack(stack) end
  if full then return stack end
  list[#list+1]=stack;return ItemStack("")
 end
 local p={list=list}
 function p:get_player_name() return "alpha" end
 function p:get_inventory() return inv end
 function p:get_pos() return {x=0,y=0,z=0} end
 function p:get_meta() return {get_int=function(_,k) return meta[k] or 0 end,set_int=function(_,k,v) meta[k]=v end} end
 function p:hud_add(def) hud.text=def.text;return 1 end
 function p:hud_change(_,_,text) hud.text=text end
 function p:hud_remove() hud.text=nil end
 return p
end

-- Nothing held: no progress, no rewards.
local p=player({"mcl_core:dirt"})
era_playtest.advance_goals(p)
eq(p:get_meta():get_int("era_playtest_goals"),0,"No goal without its item")
eq(#chats,0,"No message without progress")

-- A log completes the first goal; the reward arrives once.
p.list[#p.list+1]=ItemStack("mcl_trees:tree_oak")
era_playtest.advance_goals(p)
eq(p:get_meta():get_int("era_playtest_goals"),1,"Holding a log completes the first goal")
eq(p.list[#p.list].text,"mcl_core:apple 3","Apples are rewarded")
assert(hud.text:find("Goal 2/9: Craft a stone pickaxe",1,true),"Screen shows the next goal: "..tostring(hud.text))
era_playtest.advance_goals(p)
eq(#chats,1,"A completed goal is not rewarded twice")

-- A crafted item counts even before it reaches the inventory.
era_playtest.advance_goals(p,"mcl_tools:pick_stone")
eq(p:get_meta():get_int("era_playtest_goals"),2,"Crafting the stone pickaxe completes it")

-- Holding later items does not skip the current goal.
p.list[#p.list+1]=ItemStack("elepower_machines:generator")
era_playtest.advance_goals(p)
eq(p:get_meta():get_int("era_playtest_goals"),2,"Goals complete in order")

-- Several satisfied goals complete together; a full inventory drops rewards.
local q=player({"mcl_trees:tree_oak","mcl_tools:pick_stone","mcl_core:iron_ingot","mcl_copper:copper_ingot"},true)
chats={}
era_playtest.advance_goals(q)
eq(q:get_meta():get_int("era_playtest_goals"),4,"Every satisfied goal completes in order")
eq(#dropped,4,"Rewards that do not fit are dropped at the player")

-- Finishing everything clears the screen line.
local all={"mcl_trees:tree_oak"}
for _,goal in ipairs(goals) do if goal.item then all[#all+1]=goal.item end end
local r=player(all);chats={}
era_playtest.advance_goals(r)
eq(r:get_meta():get_int("era_playtest_goals"),#goals,"All goals complete")
eq(hud.text,nil,"The screen line is removed when done")
assert(chats[#chats]:find("All starter goals complete",1,true),"Completion is announced")
print("GOALS PASS: ordered goals, one reward each, crafted items count, missing items skipped, full inventory drops rewards")
