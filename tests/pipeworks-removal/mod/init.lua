-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native Mineclonia removals, inactive-block activation and process restart.
-- Detached actor supplies fixtures; no human client playthrough is claimed.
local baseline=core.settings:get_bool("era_pipeworks_baseline",false)
local state=core.get_mod_storage()
local marker="golden_era_filter_preview"
local done=false
local function p(x,z) return vector.new(x or 0,200,z or 0) end
local center=p()
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function log(message) core.log("action","Pipeworks smoke: "..message) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA PIPEWORKS SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Pipeworks smoke checkpoint",false,0)
end
local function checked(fn)
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then finish(false,err) end
end
local inventory=core.create_detached_inventory("pw_audit_actor",{})
inventory:set_size("main",100);inventory:set_size("offhand",1)
local wield=ItemStack("mcl_tools:pick_iron")
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return "" end,
 get_inventory=function() return inventory end,get_player_control=function() return {} end,
 get_pos=function() return center end,get_look_dir=function() return vector.new(0,0,1) end,
 get_wielded_item=function() return wield end,set_wielded_item=function(_,stack) wield=stack end}
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function item_list(pos,radius)
 local stacks={}
 for _,object in ipairs(core.get_objects_inside_radius(pos or center,radius or 3)) do
  local entity=object:get_luaentity()
  if entity and entity.name=="__builtin:item" and entity.itemstring~="" then
   stacks[#stacks+1]=ItemStack(entity.itemstring)
  end
 end
 return stacks
end
local function count(name,pos,radius)
 local total=0
 for _,stack in ipairs(item_list(pos,radius)) do if stack:get_name()==name then total=total+stack:get_count() end end
 if not pos then for _,stack in ipairs(inventory:get_list("main")) do if stack:get_name()==name then total=total+stack:get_count() end end end
 return total
end
local function cleanup()
 core.remove_node(center)
 for _,object in ipairs(core.get_objects_inside_radius(center,12)) do
  local entity=object:get_luaentity()
  if entity and entity.name=="__builtin:item" then object:remove() end
 end
 for index=1,inventory:get_size("main") do inventory:set_stack("main",index,ItemStack()) end
end
local function place(name,pos)
 pos=pos or center
 core.set_node(pos,{name=name})
 core.get_meta(pos):set_string("owner","")
 return inv(pos)
end
local function stamp(name,count,token,wear)
 local stack=ItemStack(name.." "..count)
 assert(core.registered_items[stack:get_name()],"Registered fixture payload "..name)
 stack:get_meta():set_string("pw_audit",token)
 stack:set_wear(wear or 0)
 return stack
end
local function blast(drop_chance)
 mcl_explosions.explode(center,4,{drop_chance=drop_chance or 1,sound=false,particles=false})
 eq(core.get_node(center).name,"air","Native explosion removes fixture node")
end
local function ghost_crafter()
 local inventory=place("pipeworks:autocrafter")
 eq(def(center).allow_metadata_inventory_put(center,"output",1,ItemStack("mcl_core:stick"),actor),0,"Native autocrafter output is a ghost")
 eq(inventory:get_stack("output",1):get_name(),"mcl_core:stick","Native ghost output preview configured")
 assert(not inventory:is_empty("recipe"),"Native ghost input recipe exists")
 assert(inventory:is_empty("src") and inventory:is_empty("dst"),"Configuring ghosts grants no physical inputs or outputs")
 return inventory
end
local function ordinary_mine()
 return core.node_dig(center,core.get_node(center),actor)
end
-- Install transparent counters before startup; overriding definitions after
-- startup is unsupported and would also invalidate the diagnostics contract.
local measure_cleanup=false
local destructs,afters=0,0
local crafter_def=assert(core.registered_nodes["pipeworks:autocrafter"])
local original_destruct,original_after=crafter_def.on_destruct,crafter_def.after_dig_node
core.override_item("pipeworks:autocrafter",{
 on_destruct=function(...)
  if measure_cleanup then destructs=destructs+1 end
  return original_destruct(...)
 end,
 after_dig_node=function(...)
  if measure_cleanup then afters=afters+1 end
  return original_after(...)
 end})
local function verify_stack(stack,pos,radius)
 local total=0
 for _,dropped in ipairs(item_list(pos,radius)) do if dropped:get_name()==stack:get_name() then
  eq(dropped:get_meta():get_string("pw_audit"),stack:get_meta():get_string("pw_audit"),"Recoverable stack metadata")
  eq(dropped:get_wear(),stack:get_wear(),"Recoverable stack wear")
  total=total+dropped:get_count()
 end end
 eq(total,stack:get_count(),"Recoverable full stack count")
end
local function autocrafter_checks()
 cleanup()
 local inventory=ghost_crafter()
 local payloads={stamp("mcl_core:iron_ingot",7,"autocrafter src",100),
  stamp("mcl_core:gold_ingot",5,"autocrafter dst",0),
  stamp("mcl_tools:pick_iron",1,"last input slot",4321),
  stamp("mcl_copper:copper_ingot",18,"last output slot",79)}
 inventory:set_stack("src",1,payloads[1]);inventory:set_stack("dst",1,payloads[2])
 inventory:set_stack("src",24,payloads[3]);inventory:set_stack("dst",12,payloads[4])
 eq(def(center).can_dig(center,actor),false,"Occupied autocrafter mining guard")
 eq(ordinary_mine(),false,"Ordinary mining refuses occupied autocrafter")
 eq(inventory:get_stack("src",1):to_string(),payloads[1]:to_string(),"Refused mining preserves complete input")
 eq(inventory:get_stack("dst",1):to_string(),payloads[2]:to_string(),"Refused mining preserves complete output")
 eq(inventory:get_stack("src",24):to_string(),payloads[3]:to_string(),"Refused mining preserves last input slot")
 eq(inventory:get_stack("dst",12):to_string(),payloads[4]:to_string(),"Refused mining preserves last output slot")
 measure_cleanup=true
 blast()
 measure_cleanup=false
 eq(destructs,1,"Actual blast invokes native recipe-cache cleanup once")
 eq(afters,baseline and 0 or 1,"Actual blast invokes native tube-connectivity cleanup exactly once after successful removal")
 for _,stack in ipairs(payloads) do
  if baseline then eq(count(stack:get_name()),0,"Baseline loses occupied physical payload")
  else verify_stack(stack) end
 end
 eq(count("pipeworks:autocrafter"),baseline and 0 or 1,"Actual blast returns canonical device only when repaired")
 eq(count("mcl_core:stick"),0,"Blast never materializes ghost output")
 eq(count("mcl_trees:wood_oak"),0,"Blast never materializes ghost recipe")
 log(baseline and "BASELINE: occupied autocrafter explosion loses device and four complete physical stacks" or
  "Actual explosion returns device and all src/dst stacks including last slots, wear/metadata; cache cleanup and tube rescan each run once; previews never drop")
 for _,mode in ipairs({"mine","blast","no-drop blast"}) do
  cleanup();ghost_crafter()
  if mode=="mine" then assert(ordinary_mine(),"Ghost-only autocrafter mines")
  elseif mode=="blast" then blast() else blast(0) end
  eq(count("pipeworks:autocrafter"),mode=="no-drop blast" and not baseline and 0 or 1,"Ghost-only device respects native drop chance")
  eq(count("mcl_core:stick"),0,"Ghost output never materializes")
  eq(count("mcl_trees:wood_oak"),0,"Ghost recipe never materializes")
 end
 cleanup();local full=ghost_crafter();full:set_stack("src",1,payloads[1]);full:set_stack("dst",1,payloads[2]);blast(0)
 eq(count("pipeworks:autocrafter"),0,"No-drop occupied blast emits no device")
 eq(count(payloads[1]:get_name()),0,"No-drop occupied blast emits no input")
 eq(count(payloads[2]:get_name()),0,"No-drop occupied blast emits no output")
 log("Ordinary occupied mining remains refused; actual no-drop blasts emit no previews or physical payloads")
end
local function filter_checks()
 for _,name in ipairs({"pipeworks:filter","pipeworks:mese_filter","pipeworks:digiline_filter"}) do
  for _,mode in ipairs({"mine","blast"}) do
   cleanup();local inventory=place(name)
   eq(def(center).allow_metadata_inventory_put(center,"main",1,ItemStack("mcl_core:diamond"),actor),0,"Native filter configuration is a ghost")
   eq(inventory:get_stack("main",1):get_name(),"mcl_core:diamond","Native filter ghost exists")
   if mode=="mine" then assert(ordinary_mine(),"Filter mines") else blast() end
   eq(count(name),1,"Filter returns one device")
   eq(count("mcl_core:diamond"),0,"Filter ghost never materializes during removal")
   log("PASS "..name.." "..mode.." preserves no physical payload and creates no ghost items")
  end
 end
end
local function wielder_checks()
 for _,base in ipairs({"deployer","dispenser","nodebreaker"}) do
  for _,variant in ipairs({"off","on"}) do
   for _,mode in ipairs({"mine","blast"}) do
    cleanup()
    local name="pipeworks:"..base.."_"..variant
    local inventory=place(name)
    local list=base=="nodebreaker" and "pick" or "main"
    local stack=base=="nodebreaker" and stamp("mcl_tools:pick_iron",1,name..mode,4321)
     or stamp("mcl_copper:copper_ingot",9,name..mode,100)
    -- Resolve aliases through ItemStack, preserving full metadata and wear.
    eq(def(center).allow_metadata_inventory_put(center,list,1,stack,actor),stack:get_count(),"Native wielder accepts physical fixture stack")
    inventory:set_stack(list,1,stack)
    if mode=="mine" then assert(ordinary_mine(),"Occupied wielder mines") else blast() end
    eq(count(stack:get_name()),stack:get_count(),"Wielder retains full physical quantity")
    eq(count("pipeworks:"..base.."_off"),1,"Wielder returns one canonical device")
    local found=false
    for _,dropped in ipairs(item_list()) do if dropped:get_name()==stack:get_name() then
     eq(dropped:get_meta():get_string("pw_audit"),stack:get_meta():get_string("pw_audit"),"Wielder keeps metadata")
     eq(dropped:get_wear(),stack:get_wear(),"Wielder keeps wear")
     found=true
    end end
    assert(found,"Wielder emits recoverable stored stack entity")
    log("PASS "..name.." "..mode.." preserves physical count, wear and metadata")
   end
  end
 end
end
local names={"pipeworks:filter","pipeworks:mese_filter","pipeworks:digiline_filter"}
local function immobility_checks()
 cleanup()
 for _,name in ipairs(names) do for _,modern in ipairs({true,false}) do
  local from,to=p(6,7),p(7,7)
  core.remove_node(from);core.remove_node(to)
  place("mcl_pistons:piston_off",p(5,7))
  place(name,from)
  if not modern then core.get_meta(from):set_string(marker,"") end
  eq(def(from).allow_metadata_inventory_put(from,"main",1,ItemStack("mcl_core:diamond"),actor),0,"Ghost selector configuration consumes no item")
  eq(core.get_meta(from):get_int(marker),modern and not baseline and 1 or 0,"Editing one slot does not classify an old unmarked list")
  eq(core.get_item_group(name,"unmovable_by_piston"),baseline and 0 or 1,"Explicit temporary native piston policy")
  local moved=mcl_pistons.push(from,vector.new(1,0,0),1,"",p(5,7))
  eq(not not moved,baseline,"Native piston movement follows selected policy")
  if baseline then core.remove_node(to);place(name,from);inv(from):set_stack("main",1,ItemStack("mcl_core:diamond")) end
  local result=mesecon.mvps_push(from,vector.new(1,0,0),1,"")
  eq(not not result,baseline,"Native MVPS movement follows selected policy")
  if baseline then core.remove_node(to) else
   eq(core.get_node(from).name,name,"Blocked native movers preserve original filter")
   eq(inv(from):get_stack("main",1):get_name(),"mcl_core:diamond","Blocked movers preserve preview")
  end
  core.remove_node(from);core.remove_node(to)
 end end
 log(baseline and "BASELINE: all three filter variants move under both native piston APIs" or
  "All three filter variants, fresh and old unmarked, refuse native Mineclonia and Mesecons piston movement without changing previews")
end
local targets={p(16,4),p(32,4),p(48,4),p(64,4),p(80,4)}
local expected_stage
local function floor(pos)
 for x=-3,3 do for z=-3,3 do core.set_node(vector.add(pos,vector.new(x,-2,z)),{name="mcl_core:stone"}) end end
end
local function activate(stage)
 expected_stage=stage
 local pos=targets[stage]
 core.set_node(vector.add(pos,vector.new(1,0,1)),{name="era_pipeworks_smoke:activation_marker"})
 assert(core.forceload_block(pos,true),"Activate native fixture block "..stage)
end
local function legacy_stack()
 return stamp("mcl_core:gold_ingot",3,"historical owned fallback",79)
end
local function legacy_tool()
 return stamp("mcl_tools:pick_iron",1,"historical owned input overflow",4321)
end
local function transfer_legacy(pos,stacks)
 local filter=place("pipeworks:mese_filter",pos)
 -- Deliberately represent source-documented historical physical ownership;
 -- remove the new-construction marker and transfer owned fixture items.
 core.get_meta(pos):set_string(marker,"")
 for index,stack in ipairs(stacks) do
  inventory:set_stack("main",index+10,stack)
  local owned=inventory:remove_item("main",stack)
  eq(owned:to_string(),stack:to_string(),"Historical fixture transfer owns full source stack")
  filter:set_stack("main",index,owned)
 end
 return filter
end
local function checkpoint()
 state:set_int("phase",1)
 finish(true,"CHECKPOINT: native removals and inactive-block preview/legacy conversions checked; persistent markers saved for restart")
end
local function stage_result(stage)
 local pos=targets[stage]
 eq(core.compare_block_status(pos,"active"),true,"Destination activated through engine")
 if stage==1 then
  local result_pos=baseline and pos or p(15,4)
  eq(inv(result_pos):get_stack("main",1):get_count(),1,"Boundary selector remains logical")
  eq(count("mcl_core:diamondblock",pos,3),baseline and 1 or 0,"Piston inactive-boundary ghost materialization")
  eq(inventory:get_stack("main",1):get_count(),1,"Actor keeps original physical selector")
  log(baseline and "BASELINE: native piston into inactive block changes owned diamondblock total 1 to 2" or
   "Temporary native piston stopper prevents old unclassified boundary movement and duplicate selector")
  local fresh=targets[2];floor(fresh)
  eq(core.compare_block_status(fresh,"loaded"),true,"Fresh modern block initially inactive")
  place("pipeworks:mese_filter",fresh)
  eq(def(fresh).allow_metadata_inventory_put(fresh,"main",1,ItemStack("mcl_copper:copper_ingot 3"),actor),0,"Fresh preview consumes no payload")
  activate(2)
 elseif stage==2 then
  eq(count("mcl_copper:copper_ingot",pos,3),baseline and 3 or 0,"Fresh modern filter first activation never refunds a preview")
  eq(inv(pos):get_stack("main",1):get_count(),3,"Fresh modern preview quantity retained")
  eq(core.get_meta(pos):get_int(marker),baseline and 0 or 1,"Fresh modern marker persists through activation")
  log(baseline and "BASELINE: fresh configured inactive-block filter also refunds its modern preview" or
   "Fresh modern filter first activation keeps preview without emitting physical items")
  local legacy=targets[3];floor(legacy)
  eq(core.compare_block_status(legacy,"loaded"),true,"Historical fallback block initially inactive")
  transfer_legacy(legacy,{legacy_stack()})
  activate(3)
 elseif stage==3 then
  verify_stack(legacy_stack(),pos,3)
  eq(inv(pos):get_stack("main",1):to_string(),legacy_stack():to_string(),"Converted legacy preview remains")
  eq(core.get_meta(pos):get_int(marker),baseline and 0 or 1,"Fallback conversion marked only after refund")
  log("Historical owned fallback: exactly 3 recoverable gold retain wear/metadata; preview remains logical")
  local legacy=targets[4];floor(legacy)
  eq(core.compare_block_status(legacy,"loaded"),true,"Historical input block initially inactive")
  local dir=pipeworks.facedir_to_right_dir(0)
  local input=vector.subtract(legacy,dir)
  local barrel=place("mcl_barrels:barrel_closed",input)
  assert(def(input).tube,"Native barrel exposes the pinned input-inventory contract")
  for index=1,barrel:get_size("main") do barrel:set_stack("main",index,ItemStack("mcl_core:stone 64")) end
  barrel:set_stack("main",1,ItemStack("mcl_core:gold_ingot 62"))
  transfer_legacy(legacy,{ItemStack("mcl_core:gold_ingot 3"),legacy_tool()})
  activate(4)
 elseif stage==4 then
  local input=vector.subtract(pos,pipeworks.facedir_to_right_dir(0))
  eq(inv(input):get_stack("main",1):get_count(),64,"Native input refund fills exactly two free spaces")
  eq(count("mcl_core:gold_ingot",pos,3),1,"Native input refund drops exactly one leftover gold")
  verify_stack(legacy_tool(),pos,3)
  eq(core.get_meta(pos):get_int(marker),baseline and 0 or 1,"Successful input conversion marked after refunds")
  log("Historical owned input refund: 2 gold fit barrel, 1 excess gold and full worn metadata tool recover as entities")
  local again=targets[5];floor(again)
  eq(core.compare_block_status(again,"loaded"),true,"Repeated-conversion target initially inactive")
  local converted=core.get_meta(targets[3]):to_table()
  place("pipeworks:mese_filter",again)
  core.get_meta(again):from_table(converted)
  -- A saved converted metadata snapshot is deliberately restored in a new block;
  -- no production movement exemption or manual LBM action is used.
  activate(5)
 elseif stage==5 then
  eq(count("mcl_core:gold_ingot",pos,3),baseline and 3 or 0,"Completed conversion metadata prevents a second native refund")
  eq(inv(pos):get_stack("main",1):to_string(),legacy_stack():to_string(),"Repeated activation retains converted logical preview")
  checkpoint()
 end
end
local function boundary_check()
 cleanup()
 local from,to=p(15,4),targets[1]
 floor(to)
 eq(core.compare_block_status(to,"loaded"),true,"Boundary target loaded but inactive")
 place("mcl_pistons:piston_off",p(14,4));place("pipeworks:mese_filter",from)
 -- Old unclassified modern save: deliberately no new marker or ownership guess.
 core.get_meta(from):set_string(marker,"")
 inventory:set_stack("main",1,ItemStack("mcl_core:diamondblock"))
 eq(def(from).allow_metadata_inventory_put(from,"main",1,inventory:get_stack("main",1),actor),0,"Boundary ghost consumes no item")
 eq(core.get_meta(from):get_int(marker),0,"Editing an old unclassified selector does not tag other slots")
 local moved=mcl_pistons.push(from,vector.new(1,0,0),1,"",p(14,4))
 eq(not not moved,baseline,"Old unclassified boundary movement follows explicit piston policy")
 eq(core.compare_block_status(to,"loaded"),true,"Move/rejection leaves target inactive")
 activate(1)
end
local function run()
 autocrafter_checks();filter_checks();wielder_checks();immobility_checks();boundary_check()
end
local function resume()
 for _,pos in ipairs(targets) do assert(core.forceload_block(pos,true),"Reload saved native fixture block") end
 local function when_active()
  for _,pos in ipairs(targets) do
   if not core.compare_block_status(pos,"active") then core.after(0.25,when_active);return end
  end
  checked(function()
  for index=2,5 do
   eq(core.get_meta(targets[index]):get_int(marker),baseline and 0 or 1,"Saved modern/conversion marker survives actual process restart")
  end
  eq(inv(targets[2]):get_stack("main",1):get_count(),3,"Modern selector persists across restart")
  verify_stack(legacy_stack(),targets[3],3)
  local input=vector.subtract(targets[4],pipeworks.facedir_to_right_dir(0))
  eq(inv(input):get_stack("main",1):get_count(),64,"Saved refunded input inventory unchanged after restart")
  eq(count("mcl_core:gold_ingot",targets[4],3),1,"Saved legacy leftover not duplicated on reload")
  verify_stack(legacy_tool(),targets[4],3)
  eq(count("mcl_core:gold_ingot",targets[5],3),baseline and 3 or 0,"Completed conversion remains one-time across restart")
  log("Native process restart preserves marker, converted previews, full input refund and recoverable leftovers without another refund")
  finish(true,"COMPLETE: baseline/repaired contracts retained across native engine restart; no saved player worlds touched")
  end)
 end
 core.after(0.25,when_active)
end
local started=false
core.register_node("era_pipeworks_smoke:activation_marker",{description="Disposable audit marker",drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_pipeworks_smoke:await_activation",nodenames={"era_pipeworks_smoke:activation_marker"},run_at_every_load=true,
 action=function(pos)
  local stage=math.floor(pos.x/16)
  if stage>0 then
   if expected_stage==stage then expected_stage=nil;core.after(0,function() checked(function() stage_result(stage) end) end) end
   return
  end
  if started then return end
  started=true;core.after(0,function() checked(state:get_int("phase")==1 and resume or run) end)
 end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-8,-8),p(84,12)+vector.new(0,3,0),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-8,-8),p(84,12)+vector.new(0,3,0))
    core.set_node(p(12,11),{name="era_pipeworks_smoke:activation_marker"})
    assert(core.forceload_block(center,true),"Activate only source block initially")
   end) end) end
  end)
 end)
 core.after(35,function() if not done then finish(false,"Native fixture timeout") end end)
end)
