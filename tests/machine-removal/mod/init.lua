-- SPDX-License-Identifier: GPL-3.0-or-later
-- Real node_dig, item entities and Mineclonia explosions; detached fake actor.
local baseline = core.settings:get_bool("era_removal_baseline", false)
local done = false
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function log(message) core.log("action","Machine removal: "..message) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA MACHINE REMOVAL "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Machine removal regression finished",false,0)
end
local function place(pos,name)
 assert(core.registered_nodes[name],"Registered machine "..name)
 core.set_node(pos,{name=name})
 core.get_node_timer(pos):stop()
 return core.get_meta(pos):get_inventory()
end
local function def(pos) return core.registered_nodes[core.get_node(pos).name] end
local function stacks(pos,name)
 local result={}
 for _,object in ipairs(core.get_objects_inside_radius(pos,3)) do
  local entity=object:get_luaentity()
  if entity and entity.name=="__builtin:item" then
   local stack=ItemStack(entity.itemstring)
   if not name or stack:get_name()==name then result[#result+1]=stack end
  end
 end
 return result
end
local function count(pos,name)
 local total=0
 for _,stack in ipairs(stacks(pos,name)) do total=total+stack:get_count() end
 return total
end
local wield=ItemStack("mcl_tools:pick_iron")
local inventory=core.create_detached_inventory("era_machine_removal_actor",{})
inventory:set_size("main",100);inventory:set_size("offhand",1)
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return "" end,
 get_inventory=function() return inventory end,get_player_control=function() return {} end,
 get_pos=function() return p(0) end,get_look_dir=function() return vector.new(0,0,1) end,
 get_wielded_item=function() return wield end,set_wielded_item=function(_,stack) wield=stack end}
local destroyed,after_dig=0,0
local function probe_lifecycle()
 local name="elepower_machines:pulverizer"
 local original=core.registered_nodes[name]
 local old_destruct,old_dig=original.after_destruct,original.after_dig_node
 core.override_item(name,{after_destruct=function(pos,...)
  if vector.equals(pos,p(64)) then destroyed=destroyed+1 end
  return old_destruct(pos,...)
 end,after_dig_node=function(pos,...)
  if vector.equals(pos,p(64)) then after_dig=after_dig+1 end
  return old_dig(pos,...)
 end})
end
local components=core.serialize({capacitor="elepower_machines:hardened_capacitor"})
local function stamp(stack,token,wear)
 stack:get_meta():set_string("removal_fixture",token)
 stack:set_wear(wear or 0)
 return stack
end
local function ordinary(pos,name,list,stack)
 local inv=place(pos,name)
 eq(def(pos).allow_metadata_inventory_put(pos,list,1,stack,actor),stack:get_count(),"Native input callback accepts fixture")
 inv:set_stack(list,1,stack)
 local before=inv:get_stack(list,1):to_string()
 eq(def(pos).can_dig(pos,actor),baseline,"Occupied "..list.." guard")
 local result=def(pos).on_dig(pos,core.get_node(pos),actor)
 if baseline then
  eq(result,true,"Baseline native mining succeeds")
  eq(core.get_node(pos).name,"air","Baseline removes occupied machine")
  eq(count(pos,stack:get_name()),0,"Baseline destroys occupied "..list)
  eq(count(pos,name),1,"Baseline machine itself drops")
 else
  eq(result,false,"Occupied native mining refuses")
  eq(core.get_node(pos).name,name,"Occupied machine stays placed")
  eq(inv:get_stack(list,1):to_string(),before,"Refusal preserves complete ItemStack")
  eq(#stacks(pos),0,"Refusal emits no items")
  inv:set_stack(list,1,ItemStack(""))
  local native_components=name=="elepower_wireless:station" and
   core.serialize({wireless_chip="elepower_wireless:upgrade_item_transfer"}) or components
  core.get_meta(pos):set_int("storage",721)
  core.get_meta(pos):set_string("components",native_components)
  elepm.handle_machine_upgrades(pos);core.get_node_timer(pos):stop()
  eq(def(pos).on_dig(pos,core.get_node(pos),actor),true,"Empty machine mines normally")
  local machine=assert(stacks(pos,name)[1],"Machine item after emptying")
  eq(machine:get_meta():get_int("storage"),721,"Native mined energy remains")
  eq(machine:get_meta():get_string("components"),native_components,"Native mined upgrades remain")
 end
 log((baseline and "BASELINE loss" or "Owned-list mining guard")..": "..name.." / "..list)
end
local function custom_guards()
 local cases={
  {"elepower_machines:coal_alloy_furnace","fuel","mcl_core:coal_lump"},
  {"elepower_machines:power_cell_0","src","elepower_tools:soldering_iron"},
  {"elepower_nuclear:fission_core","fuel","elepower_nuclear:fuel_rod"},
  {"elepower_farming:planter","src","mcl_farming:wheat_seeds"},
  {"elepower_farming:harvester","dst","mcl_core:iron_ingot"},
  {"elepower_machines:grindstone","dst","mcl_core:iron_ingot"},
 }
 for index,case in ipairs(cases) do
  local pos=p(index*4,8)
  local inv=place(pos,case[1])
  eq(def(pos).can_dig(pos,actor),true,"Empty custom guard: "..case[1])
  assert(inv:get_size(case[2])>0,"Native owned custom list")
  inv:set_stack(case[2],1,ItemStack(case[3]))
  eq(def(pos).can_dig(pos,actor),false,"Occupied custom guard: "..case[1])
  inv:set_stack(case[2],1,ItemStack(""))
  inv:set_size("dst_tmp",1);inv:set_stack("dst_tmp",1,ItemStack("mcl_core:iron_ingot 63"))
  if inv:get_size("layout")>0 then inv:set_stack("layout",1,ItemStack("mcl_farming:wheat_seeds")) end
  eq(def(pos).can_dig(pos,actor),true,"Custom guard ignores scratch/ghost copies")
  core.remove_node(pos)
 end
 local pos=p(32,8)
 local inv=place(pos,"elepower_machines:pulverizer")
 inv:set_size("dst_tmp",1);inv:set_stack("dst_tmp",1,ItemStack("mcl_core:iron_ingot 63"))
 eq(def(pos).can_dig(pos,actor),true,"Default guard excludes stale output scratch list")
 core.remove_node(pos)
 log("Custom fuel/storage/farming/grindstone guards retained; scratch output and ghost layouts are not owned items")
end
local function explode(pos,chance)
 mcl_explosions.explode(pos,4,{drop_chance=chance,particles=false,sound=false})
end
local function blast_payload()
 local pos=p(64)
 local name="elepower_machines:pulverizer"
 local inv=place(pos,name)
 inv:set_stack("src",1,ItemStack("mcl_core:iron_ingot 7"))
 inv:set_stack("dst",1,stamp(ItemStack("mcl_tools:pick_diamond"),"worn-output",32123))
 inv:set_stack("dst",2,stamp(ItemStack("mcl_core:iron_ingot 5"),"tagged-output"))
 inv:set_size("dst_tmp",4);inv:set_list("dst_tmp",inv:get_list("dst"))
 local meta=core.get_meta(pos)
 meta:set_int("storage",1200);meta:set_string("components",components)
 elepm.handle_machine_upgrades(pos);core.get_node_timer(pos):stop()
 local cleared=0
 local old_clear=ele.clear_networks
 ele.clear_networks=function(...) cleared=cleared+1;return old_clear(...) end
 local ok,err=pcall(explode,pos,1)
 ele.clear_networks=old_clear
 assert(ok,err)
 eq(core.get_node(pos).name,"air","Actual explosion removes occupied machine")
 eq(destroyed,1,"Native after_destruct called exactly once")
 eq(cleared,1,"Native Elepower network invalidation runs exactly once")
 if baseline then
  eq(after_dig,0,"Baseline failed dig skips after_dig lifecycle")
  eq(#stacks(pos),0,"Baseline explosion destroys payload and machine")
 else
  eq(after_dig,1,"Native after_dig lifecycle runs exactly once")
  eq(count(pos,"mcl_core:iron_ingot"),12,"Seven input plus five output, excluding scratch duplicate")
  local tool=assert(stacks(pos,"mcl_tools:pick_diamond")[1],"Worn output recovered")
  eq(tool:get_wear(),32123,"Output wear is preserved")
  eq(tool:get_meta():get_string("removal_fixture"),"worn-output","Output metadata survives")
  eq(tool:get_meta():get_int("storage"),0,"Machine energy never spreads to payload")
  eq(tool:get_meta():get_string("components"),"","Machine upgrades never spread to payload")
  local tagged=0
  for _,stack in ipairs(stacks(pos,"mcl_core:iron_ingot")) do
   if stack:get_meta():get_string("removal_fixture")=="tagged-output" then tagged=tagged+stack:get_count() end
  end
  eq(tagged,5,"Five tagged output ingots retain metadata")
  eq(count(pos,name),1,"Exactly one machine emitted")
  local machine=stacks(pos,name)[1]
  eq(machine:get_meta():get_int("storage"),1200,"Machine retains native charge")
  eq(machine:get_meta():get_string("components"),components,"Machine retains native component encoding")
  local replaced=p(64,16)
  place(replaced,name)
  def(replaced).after_place_node(replaced,actor,machine,{type="node",under=replaced,above=vector.offset(replaced,0,1,0)})
  eq(core.get_meta(replaced):get_int("storage"),1200,"Native placement restores recovered energy")
  eq(core.get_meta(replaced):get_string("components"),components,"Native placement restores recovered upgrades")
  eq(ele.helpers.get_node_property(core.get_meta(replaced),replaced,"capacity"),3200,"Recovered hardened capacitor has native effect")
  core.get_node_timer(replaced):stop();core.remove_node(replaced)
 end
 log(baseline and "BASELINE: actual explosion loses 7 input, 5 tagged output, worn tool and charged modified machine" or
  "Actual explosion recovers every owned full ItemStack and charged modified machine; excludes scratch copies; native destruction/dig lifecycle runs once")
end
local function blast_ghost_and_quiet()
 local planter=p(80)
 local inv=place(planter,"elepower_farming:planter")
 inv:set_stack("layout",1,ItemStack("mcl_farming:wheat_seeds"))
 inv:set_stack("src",1,ItemStack("mcl_core:iron_ingot 3"))
 explode(planter,1)
 eq(count(planter,"mcl_farming:wheat_seeds"),0,"Ghost filter never becomes a real drop")
 eq(count(planter,"mcl_core:iron_ingot"),baseline and 0 or 3,"Owned planter inputs recover")
 for index,occupied in ipairs({false,true}) do
  local pos=p(96+(index-1)*16)
  local inv=place(pos,"elepower_machines:pulverizer")
  if occupied then inv:set_stack("src",1,ItemStack("mcl_core:iron_ingot 7")) end
  explode(pos,0)
  eq(core.get_node(pos).name,"air","No-drop explosion removes machine")
  eq(#stacks(pos),baseline and not occupied and 1 or 0,"Native do_drop=false suppresses all emissions")
 end
 log("Ghost layouts excluded; empty and occupied do_drop=false explosions remove nodes without repaired drops")
end
local function lock_checks()
 local pos=p(32,16)
 place(pos,"elepower_machines:pulverizer")
 local meta=core.get_meta(pos)
 meta:set_int("drop_lock",1)
 eq(def(pos).can_dig(pos,actor),true,"Stale saved lock without connected editor does not brick the machine")
 local editor_stack=ItemStack("mcl_core:stick")
 local editor_meta=editor_stack:get_meta()
 editor_meta:set_string("soldering",core.pos_to_string(pos))
 local editor={get_meta=function() return editor_meta end}
 local returning_stack=ItemStack("mcl_core:stick")
 local returning_meta=returning_stack:get_meta()
 local returning={get_meta=function() return returning_meta end}
 local cleanup
 for _,callback in ipairs(core.registered_on_joinplayers) do
  if debug.getinfo(callback,"S").source:match("elepower_tools/soldering.lua$") then
   assert(not cleanup,"Exactly one soldering join cleanup")
   cleanup=callback
  end
 end
 eq(cleanup~=nil,not baseline,"Join cleanup is a copied repair")
 local original=core.get_connected_players
 core.get_connected_players=function() return {editor,returning} end
 local ok,err=pcall(function()
  eq(def(pos).can_dig(pos,actor),baseline,"Active upgrade UI locks ordinary mining")
  if not baseline then
   explode(pos,1)
   eq(core.get_node(pos).name,"elepower_machines:pulverizer","Active upgrade UI also guards blast removal")
   -- A returning stale editor must not unlock another player's live upgrade UI.
   returning_meta:set_string("soldering",core.pos_to_string(pos))
   cleanup(returning)
   eq(returning_meta:get_string("soldering"),"","Returning player's stale UI position cleared")
   eq(meta:get_int("drop_lock"),0,"Native shared flag was cleared by returning stale editor")
   eq(def(pos).can_dig(pos,actor),false,"Other connected editor remains guarded despite shared flag clear")
   explode(pos,1)
   eq(core.get_node(pos).name,"elepower_machines:pulverizer","Other connected editor still prevents blast removal")
   -- A custom coal/fuel guard receives the same editor protection.
   local custom=p(40,16)
   place(custom,"elepower_machines:coal_alloy_furnace")
   editor_meta:set_string("soldering",core.pos_to_string(custom))
   eq(def(custom).can_dig(custom,actor),false,"Active editing also wraps custom guard")
   editor_meta:set_string("soldering",core.pos_to_string(pos))
   core.remove_node(custom)
   cleanup(editor)
   eq(editor_meta:get_string("soldering"),"","Join clears stale player position after restart")
   eq(def(pos).can_dig(pos,actor),true,"Reconnected editor has no live UI and no remaining lock")
   editor_meta:set_string("soldering","invalid saved position")
   cleanup(editor)
   eq(editor_meta:get_string("soldering"),"","Malformed saved UI position clears safely")
  end
 end)
 core.get_connected_players=original
 assert(ok,err)
 eq(def(pos).can_dig(pos,actor),true,"Editor leaving restores empty-machine mining")
 if not baseline then
  explode(pos,1)
  eq(core.get_node(pos).name,"air","Blast can remove machine after editor leaves")
 end
 log("Active editor protection, shared-flag interference, join cleanup and stale-lock recovery checked with fixture player metadata")
end
local function run()
 ordinary(p(0),"elepower_tools:ed_reconstructor","tool",stamp(ItemStack("mcl_tools:pick_diamond"),"owned-repair-tool",23333))
 ordinary(p(12),"elepower_wireless:station","card",stamp(ItemStack("elepower_wireless:card"),"bound-card"))
 custom_guards();blast_payload();blast_ghost_and_quiet();lock_checks()
 finish(true,baseline and "pinned ordinary-mining losses and actual explosion destruction reproduced safely" or
  "owned items protected; full blast ItemStacks/charge/upgrades/lifecycle conserved; scratch/ghost and no-drop contracts respected; active upgrade locks recover")
end
core.register_on_mods_loaded(function()
 probe_lifecycle()
 core.after(0,function()
  core.emerge_area(p(-16,-16),p(128,32),function(_,_,remaining)
   if remaining==0 then core.after(0,function()
    local ok,err=xpcall(run,debug.traceback)
    if not ok then finish(false,err) end
   end) end
  end)
 end)
end)
