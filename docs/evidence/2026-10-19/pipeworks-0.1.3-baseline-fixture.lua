-- Read-only pinned Pipeworks audit; only this ignored fixture is authored.
local done=false
local function p(x,z) return vector.new(x or 0,200,z or 0) end
local center=p()
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function log(message) core.log("action","PIPEWORKS AUDIT: "..message) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","PIPEWORKS AUDIT "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Read-only Pipeworks audit complete",false,0)
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
local function blast()
 mcl_explosions.explode(center,4,{drop_chance=1,sound=false,particles=false})
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
local function autocrafter_checks()
 cleanup()
 local inventory=ghost_crafter()
 local incoming=stamp("mcl_core:iron_ingot",7,"autocrafter src",100)
 local output=stamp("mcl_core:gold_ingot",5,"autocrafter dst",0)
 inventory:set_stack("src",1,incoming);inventory:set_stack("dst",1,output)
 eq(def(center).can_dig(center,actor),false,"Occupied native autocrafter mining guard")
 eq(ordinary_mine(),false,"Ordinary mining refuses occupied autocrafter")
 eq(inventory:get_stack("src",1):to_string(),incoming:to_string(),"Mining refusal preserves input metadata/wear")
 eq(inventory:get_stack("dst",1):to_string(),output:to_string(),"Mining refusal preserves output metadata")
 log("PASS ordinary autocrafter mining refuses occupied src/dst without changing either complete stack")
 blast()
 eq(count(incoming:get_name()),0,"Confirmed occupied autocrafter loses all 7 physical inputs in real explosion")
 eq(count(output:get_name()),0,"Confirmed occupied autocrafter loses all 5 physical outputs in real explosion")
 eq(count("pipeworks:autocrafter"),0,"Refused explosion fallback also loses device")
 eq(count("mcl_core:stick"),0,"Autocrafter ghosts do not duplicate")
 log("CONFIRMED: actual Mineclonia explosion loses autocrafter + 7 physical src iron + 5 physical dst gold after its mining guard refuses")
 for _,mode in ipairs({"mine","blast"}) do
  cleanup();ghost_crafter()
  if mode=="mine" then assert(ordinary_mine(),"Empty autocrafter mines") else blast() end
  eq(count("pipeworks:autocrafter"),1,"Empty autocrafter returns one device")
  eq(count("mcl_core:stick"),0,"Ghost output never materializes during "..mode)
  eq(count("mcl_trees:wood_oak"),0,"Ghost recipe never materializes during "..mode)
  log("PASS ghost-only autocrafter "..mode.." returns only device")
 end
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
 cleanup();local inventory=place("pipeworks:nodebreaker_off")
 inventory:set_stack("pick",1,stamp("mcl_tools:pick_iron",1,"tool",4321))
 inventory:set_stack("main",1,stamp("mcl_core:gold_ingot",9,"internal buffer",0))
 assert(ordinary_mine(),"Nodebreaker with pre-existing internal buffer mines")
 eq(count("mcl_core:gold_ingot"),0,"Nodebreaker after_dig ignores its secondary main drop buffer")
 eq(count("mcl_tools:pick_iron"),1,"Nodebreaker still drops its tool")
 log("LIMITED REACHABILITY: synthetic saved-state nodebreaker main buffer loses 9 gold on mining; normal actions eject that internal buffer synchronously")
end
local boundary_from,boundary_to=p(15,4),p(16,4)
local legacy_to=p(32,4)
local function legacy_result()
 eq(core.compare_block_status(legacy_to,"active"),true,"Legacy target activated natively")
 local selector=inv(legacy_to):get_stack("main",1)
 eq(selector:get_name(),"mcl_core:gold_ingot","Legacy refund keeps converted preview")
 eq(selector:get_count(),3,"Legacy refund keeps selector quantity")
 local refunded=count("mcl_core:gold_ingot",legacy_to,3)
 eq(refunded,3,"Native legacy migration refunds exactly three owned items")
 eq(inventory:contains_item("main","mcl_core:gold_ingot"),false,"Transferred owned legacy items are absent from actor inventory")
 log("LEGACY CONTROL: 3 owned fixture gold ingots transferred into an unmarked historical physical-list state; native activation refunds exactly 3 recoverable ingots and keeps the logical preview; physical total remains 3; historical old-mod execution was not performed")
 finish(true,"autocrafter blast loss and modern ghost boundary duplication confirmed; legitimate legacy owned-item refund conserved; standard removal controls pass; no production edits")
end
local function legacy_check()
 eq(core.compare_block_status(legacy_to,"loaded"),true,"Fresh legacy target loaded but inactive")
 inventory:set_stack("main",2,ItemStack("mcl_core:gold_ingot 3"))
 local owned=inventory:remove_item("main","mcl_core:gold_ingot 3")
 eq(owned:get_count(),3,"Transfer owned fixture items into legacy saved-state representation")
 eq(inventory:contains_item("main","mcl_core:gold_ingot"),false,"Legacy fixture transfer consumes original inventory ownership")
 local legacy=place("pipeworks:mese_filter",legacy_to)
 -- This models source-documented historical physical main-list ownership;
 -- modern allow_metadata_inventory_put is intentionally not called.
 legacy:set_stack("main",1,owned)
 eq(count("mcl_core:gold_ingot",legacy_to,3),0,"Legacy input has no prior loose item copies")
 core.set_node(p(33,5),{name="era_pw_removal_audit:activation_marker"})
 assert(core.forceload_block(legacy_to,true),"Activate legacy representation normally")
 core.after(12,function() if not done then finish(false,"Legacy activation timeout") end end)
end
local function boundary_result()
 eq(core.compare_block_status(boundary_to,"active"),true,"Target block activated natively")
 local ghost=inv(boundary_to):get_stack("main",1)
 eq(ghost:get_name(),"mcl_core:diamondblock","Moved filter keeps ghost selector")
 local duplicates=count("mcl_core:diamondblock",boundary_to,3)
 eq(duplicates,1,"Legacy activation emits one duplicate physical ghost item")
 eq(inventory:get_stack("main",1):get_count(),1,"Player retains the physical selector item because ghost insertion returned zero")
 eq(duplicates+inventory:get_stack("main",1):get_count(),2,"One original physical selector item has become two")
 log("BOUNDARY RESULT: native piston moved a configured ghost filter into a previously inactive block; activation emits "..duplicates.." actual duplicate diamondblock item(s), original physical item remains in actor inventory; preview still holds "..ghost:get_count())
 legacy_check()
end
local function boundary_check()
 cleanup()
 eq(core.compare_block_status(boundary_to,"loaded"),true,"Fresh target block is loaded but inactive")
 place("mcl_pistons:piston_off",p(14,4))
 place("pipeworks:mese_filter",boundary_from)
 inventory:set_stack("main",1,ItemStack("mcl_core:diamondblock"))
 eq(def(boundary_from).allow_metadata_inventory_put(boundary_from,"main",1,inventory:get_stack("main",1),actor),0,"Boundary filter ghost consumes no real item")
 eq(count("mcl_core:diamondblock",boundary_to,4),0,"No physical diamondblock exists before movement")
 assert(mcl_pistons.push(boundary_from,vector.new(1,0,0),1,"",p(14,4)),"Native piston pushes configured filter across block boundary")
 eq(core.get_node(boundary_to).name,"pipeworks:mese_filter","Native target filter after metadata restoration")
 eq(core.compare_block_status(boundary_to,"loaded"),true,"Native move did not activate target block")
 eq(inv(boundary_to):get_stack("main",1):get_name(),"mcl_core:diamondblock","Native movement preserves ghost selector")
 core.set_node(p(17,5),{name="era_pw_removal_audit:activation_marker"})
 assert(core.forceload_block(boundary_to,true),"Activate moved filter target normally")
 core.after(12,function() if not done then finish(false,"Target activation timeout") end end)
end
local function run()
 autocrafter_checks();filter_checks();wielder_checks();boundary_check()
end
local started=false
core.register_node("era_pw_removal_audit:activation_marker",{description="Ignored audit marker",drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_pw_removal_audit:await_activation",nodenames={"era_pw_removal_audit:activation_marker"},run_at_every_load=true,
 action=function(pos)
  if pos.x>=32 then core.after(0,function() checked(legacy_result) end);return end
  if pos.x>=16 then core.after(0,function() checked(boundary_result) end);return end
  if started then return end
  started=true;core.after(0,function() checked(run) end)
 end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-8,-8),p(35,12)+vector.new(0,3,0),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-8,-8),p(35,12)+vector.new(0,3,0))
    core.set_node(p(12,11),{name="era_pw_removal_audit:activation_marker"})
    assert(core.forceload_block(center,true),"Activate only source block initially")
    core.after(15,function() if not started then finish(false,"Source activation timeout") end end)
   end) end) end
  end)
 end)
end)
