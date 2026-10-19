-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native storage callbacks and real Mineclonia explosions in disposable worlds.
-- Detached inventories supply a fake actor; this is not a human playthrough.
local baseline=core.settings:get_bool("era_storage_baseline",false)
local state=core.get_mod_storage()
local done=false
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function log(message) core.log("action","Storage smoke: "..message) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA STORAGE SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Storage smoke checkpoint",false,0)
end
local function checked(f)
 local ok,err=xpcall(f,debug.traceback)
 if not ok then finish(false,err) end
end
local function place(pos,name)
 assert(core.registered_nodes[name],"Missing storage node "..name)
 core.set_node(pos,{name=name})
end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function content(pos,id) return drawers.drawer_get_content(pos,id or "") end
local iron="mcl_core:iron_ingot"
local copper="mcl_copper:copper_ingot"
local coal="mcl_core:coal_lump"
local gold="mcl_core:gold_ingot"
local controller=p(0)
local function measure(label,fn)
 local original=core.find_nodes_in_area
 local scans=0
 core.find_nodes_in_area=function(...) scans=scans+1;return original(...) end
 local ok,result=pcall(fn)
 core.find_nodes_in_area=original
 assert(ok,result)
 log(label.." neighborhood scans="..scans)
 return result,scans
end
local function count(invref,name)
 local total=0
 for _,stack in ipairs(invref:get_list("main") or {}) do
  if stack:get_name()==name then total=total+stack:get_count() end
 end
 return total
end
local function entities(pos,radius)
 local result={}
 for _,object in ipairs(core.get_objects_inside_radius(pos,radius or 2)) do
  local lua=object:get_luaentity()
  if lua and lua.name=="__builtin:item" and lua.itemstring~="" then
   result[#result+1]={object=object,stack=ItemStack(lua.itemstring)}
  end
 end
 return result
end
local function dropped(pos,name,radius)
 local result=0
 for _,entity in ipairs(entities(pos,radius)) do
  if entity.stack:get_name()==name then
   assert(entity.stack:get_count()<=entity.stack:get_stack_max(),"World item splits respect native stack_max")
   result=result+entity.stack:get_count()
  end
 end
 return result
end
local recovery=core.create_detached_inventory("era_storage_recovery",{})
recovery:set_size("main",200);recovery:set_size("offhand",1)
local controls={}
local actor={get_player_name=function() return "" end,is_player=function() return true end,
 get_player_control=function() return controls end,get_inventory=function() return recovery end}
local function recover(pos,radius)
 for _,entity in ipairs(entities(pos,radius)) do
  assert(core.item_pickup(entity.stack,actor,{type="nothing"},1):is_empty(),"Native item pickup fits recovery inventory")
  entity.object:remove()
 end
end
local function craft_checks()
 local groups={wood="mcl_core:wood",stick="mcl_core:stick",drawer="drawers:oakwood1"}
 local tested=0
 for name in pairs(core.registered_items) do
  if name:match("^drawers:") then
   if core.get_item_group(name,"drawer")>0 then
    eq(core.get_item_group(name,"unmovable_by_piston"),baseline and 0 or 1,"Native piston stopper matches upstream drawer immobility")
   end
   local recipes=core.get_all_craft_recipes(name)
   assert(recipes and #recipes>0,"Every registered Drawers item has a native recipe: "..name)
   for _,recipe in ipairs(recipes) do
    if recipe.method=="normal" then
     local items={}
     -- Engine recipe arrays use nil for empty grid slots; preserve those holes.
     for i=1,#recipe.items do
      local ingredient=recipe.items[i] or ""
      local group=ingredient:match("^group:(.+)$")
      if group then
       ingredient=assert(groups[group],"Unexpected Drawers recipe group "..group)
       assert(core.get_item_group(ItemStack(ingredient):get_name(),group)>0,"Concrete survival material matches "..group)
      end
      items[i]=ItemStack(ingredient)
      if ingredient~="" then assert(core.registered_items[items[i]:get_name()],"Registered native recipe ingredient "..ingredient) end
     end
     local result=core.get_craft_result({method="normal",width=recipe.width,items=items})
     eq(result.item:get_name(),ItemStack(recipe.output):get_name(),"Concrete native recipe output for "..name)
     eq(result.item:get_count(),ItemStack(recipe.output):get_count(),"Native recipe output quantity for "..name)
     tested=tested+1
    end
   end
  end
 end
 assert(tested>=26,"All bundled drawer, controller, trim and upgrade recipes checked")
 assert(not core.registered_items["drawers:upgrade_mithril"],"Absent optional Moreores mod does not advertise a mithril upgrade")
 log("Concrete native recipes verified: "..tested.." (wood/stick/drawer groups use real pinned Mineclonia items)")
end
local function deposit(name,amount,label,expected_pre,expected_commit)
 local stack=ItemStack(name.." "..amount)
 local tube=def(controller).tube
 local accepted,pre=measure(label.." preflight",function() return tube.can_insert(controller,core.get_node(controller),stack,vector.new(1,0,0)) end)
 assert(accepted,"Native controller preflight accepts "..label)
 local leftover,commit=measure(label.." commit",function() return tube.insert_object(controller,core.get_node(controller),ItemStack(stack),vector.new(1,0,0)) end)
 eq(leftover:get_count(),0,"No leftover for "..label)
 eq(pre,expected_pre,"Controller preflight scan count for "..label)
 eq(commit,expected_commit,"Controller insertion scan count for "..label)
end
local function explode(pos,drop_chance)
 return pcall(mcl_explosions.explode,pos,16,{drop_chance=drop_chance,particles=false,sound=false})
end
local function spill_fixture(pos,amount)
 place(pos,"drawers:oakwood1")
 assert(drawers.drawer_insert_object(pos,ItemStack(coal.." "..amount),""):is_empty(),"Native dig fixture coal supply")
 inv(pos):set_stack("upgrades",1,ItemStack("drawers:upgrade_gold"))
 def(pos).on_metadata_inventory_put(pos,"upgrades",1,ItemStack("drawers:upgrade_gold"),actor)
 assert(def(pos).after_dig_node,"Active Pipeworks supplies the after_dig_node hook used by Mineclonia explosions")
end
local function checkpoint(a,b)
 eq(content(b).count,11,"Unrelated copper drawer survives all probes")
 eq(content(p(6),"1").count,1,"Unrelated redstone drawer survives all probes")
 deposit(iron,4,"saved cache seed",7,7)
 -- Simulate a stale saved cache from an older version. swap_node deliberately
 -- skips constructors/destructors; the native reload LBM must clear it.
 core.swap_node(p(1),{name="air"})
 assert(core.get_meta(controller):get_string("drawers_table_index")~="","Fixture saves a stale nonempty controller cache")
 state:set_string("phase","resume")
 state:set_string("iron_pos",core.serialize(a));state:set_string("copper_pos",core.serialize(b))
 finish(true,"CHECKPOINT: "..(baseline and
  "native baseline reproduced repeated scans, 2696 lost overflow iron, native piston/dig losses, wear loss and actual explosion crash" or
  "all 5000 iron recovered; native dig/explosion spills preserved; controller explosion preserves worn metadata stack and adjacent barrel; warm deposits avoid rescans; disconnect/reconnect and visual invalidation work"))
end
local function blast_checks(a,b)
 local ordinary=p(24,24)
 spill_fixture(ordinary,130)
 local ordinary_ok,ordinary_error=explode(ordinary,1)
 assert(ordinary_ok,ordinary_error)
 eq(core.get_node(ordinary).name,"air","Actual explosion removes ordinary drawer")
 eq(dropped(ordinary,coal),baseline and 0 or 130,"Actual explosion preserves ordinary drawer payload")
 eq(dropped(ordinary,"drawers:upgrade_gold"),baseline and 0 or 1,"Actual explosion preserves ordinary drawer upgrade")
 eq(dropped(ordinary,"drawers:oakwood1"),1,"Actual explosion emits the ordinary drawer itself")
 recover(ordinary,3)
 place(ordinary,"drawers:controller")
 local worn=ItemStack("mcl_tools:pick_iron");worn:set_wear(3210);worn:get_meta():set_string("storage_smoke","preserve full stack")
 inv(ordinary):set_stack("src",1,worn)
 local neighbor=p(25,24)
 place(neighbor,"mcl_barrels:barrel_closed")
 inv(neighbor):set_stack("main",1,ItemStack(gold.." 13"))
 local ok,err=explode(ordinary,1)
 if baseline then
  assert(not ok and tostring(err):match("default"),"Native baseline real explosion reaches missing default API")
  eq(core.get_node(ordinary).name,"drawers:controller","Baseline callback fails before removal")
  eq(inv(ordinary):get_stack("src",1):get_wear(),3210,"Safe pcall baseline retains controller payload")
  log("BASELINE expected real explosion error caught: "..tostring(err))
 else
  assert(ok,err)
  eq(core.get_node(ordinary).name,"air","Actual explosion removes controller without crashing")
  eq(dropped(ordinary,"drawers:controller",3),1,"Actual explosion drops exactly one controller")
  local found=0
  for _,entity in ipairs(entities(ordinary,3)) do if entity.stack:get_name()==worn:get_name() then
   eq(entity.stack:get_wear(),3210,"Controller explosion preserves worn tool")
   eq(entity.stack:get_meta():get_string("storage_smoke"),"preserve full stack","Controller explosion preserves metadata")
   found=found+entity.stack:get_count()
  end end
  eq(found,1,"Exactly one controller source tool emitted")
  local remaining=core.get_node(neighbor).name=="air" and 0 or count(inv(neighbor),gold)
  eq(dropped(ordinary,gold,3)+remaining,13,"Adjacent native barrel inventory remains accounted for")
  recover(ordinary,3)
  place(ordinary,"drawers:controller")
  inv(ordinary):set_stack("src",1,ItemStack("mcl_core:diamond 9"))
  local quiet,quiet_error=explode(ordinary,0)
  assert(quiet,quiet_error)
  eq(core.get_node(ordinary).name,"air","Mineclonia no-drop explosion still removes controller")
  eq(dropped(ordinary,"drawers:controller",3),0,"No-drop explosion emits no controller")
  eq(dropped(ordinary,"mcl_core:diamond",3),0,"No-drop explosion emits no source items")
  log("Actual Mineclonia blasts preserve ordinary drawer contents/upgrades, controller metadata/wear and neighboring barrel inventory; do_drop=false honored")
 end
 checkpoint(a,b)
end
local function piston_check()
 local source,target=p(10,4),p(11,4)
 spill_fixture(source,130)
 local moved=mcl_pistons.push(source,vector.new(1,0,0),1,"",p(9,4))
 local actual
 if baseline then
  eq(moved,true,"Pinned native piston moves drawer despite upstream MVPS stopper")
  eq(core.get_node(source).name,"air","Native piston removes old drawer position")
  eq(content(target).count,130,"Native piston initially restores full node metadata")
  eq(drawers.get_visual(target,"").count,0,"Native piston leaves new empty visual over restored full metadata")
  actual=target
 else
  assert(not moved,"Native piston cannot move a drawer, matching upstream MVPS policy")
  eq(core.get_node(target).name,"air","Blocked piston leaves destination untouched")
  eq(content(source).count,130,"Blocked native piston preserves drawer metadata")
  eq(drawers.get_visual(source,"").count,130,"Blocked native piston preserves live visual state")
  actual=source
 end
 assert(drawers.drawer_insert_object(actual,ItemStack(coal),""):is_empty(),"One normal post-push input offered")
 eq(content(actual).count,baseline and 1 or 131,"Post-push insertion cannot erase existing drawer contents")
 local recovered=0
 while content(actual).count>0 do
  local stack=drawers.drawer_take_item(actual,ItemStack(coal.." 64"))
  assert(not stack:is_empty(),"Piston probe contents remain retrievable")
  recovered=recovered+stack:get_count()
  assert(core.item_pickup(stack,actor,{type="nothing"},1):is_empty(),"Piston probe native retrieval fits inventory")
 end
 eq(recovered,baseline and 1 or 131,"Piston probe exact retrieved quantity")
 log(baseline and "BASELINE: native piston restores 130 coal into metadata over an empty visual; next insertion erases that 130" or
  "Native Mineclonia piston respects drawer immobility and preserves all 130 stored + 1 offered coal")
end
local function dig_checks(a,b)
 local automatic=p(10,8)
 spill_fixture(automatic,130)
 assert(core.dig_node(automatic),"Actual engine dig_node invokes native dummy-digger path")
 eq(core.get_node(automatic).name,"air","Automatic dig removes drawer")
 eq(dropped(automatic,coal),baseline and 0 or 130,"Automatic dummy digger conserves coal")
 eq(dropped(automatic,"drawers:upgrade_gold"),baseline and 0 or 1,"Automatic dummy digger conserves upgrade")
 eq(dropped(automatic,"drawers:oakwood1"),1,"Automatic dig emits drawer")
 recover(automatic,3)
 local sneaked=p(10,12)
 spill_fixture(sneaked,130)
 local full=core.create_detached_inventory("era_storage_full",{});full:set_size("main",1);full:set_size("offhand",1)
 full:set_stack("main",1,ItemStack("mcl_core:cobble 64"))
 local wield=ItemStack("mcl_tools:axe_iron")
 local digger={is_fake_player=true,is_player=function() return true end,get_player_name=function() return "" end,
  get_inventory=function() return full end,get_player_control=function() return {sneak=true} end,
  get_pos=function() return sneaked end,get_look_dir=function() return vector.new(0,0,1) end,
  get_wielded_item=function() return wield end,set_wielded_item=function(_,stack) wield=stack end}
 def(sneaked).on_dig(sneaked,core.get_node(sneaked),digger)
 eq(core.get_node(sneaked).name,"air","Full-inventory sneaking dig removes drawer")
 eq(dropped(sneaked,coal,3),baseline and 3 or 130,"Sneaking spill preserves all three native coal batches")
 eq(dropped(sneaked,"drawers:upgrade_gold",3),1,"Sneaking spill preserves upgrade")
 eq(count(full,"mcl_core:cobble"),64,"Full digger inventory remains intact")
 recover(sneaked,3)
 log(baseline and "BASELINE: dummy dig loses 130 coal and upgrade; sneaking full-inventory dig drops only 3/130 coal" or
  "Automatic dummy dig and sneaking full-inventory dig each recover all 130 coal, upgrade and drawer")
 blast_checks(a,b)
end
local function initial()
 craft_checks()
 place(controller,"drawers:controller")
 for _,x in ipairs({1,3}) do place(p(x),"drawers:trim") end
 for _,x in ipairs({2,4}) do place(p(x),"drawers:oakwood1") end
 deposit(iron,10,"first iron",5,5)
 local index=assert(core.deserialize(core.get_meta(controller):get_string("drawers_table_index")))
 assert(index[iron][1].drawer_pos and index[iron][1].visualid~=nil,"Native cached array shape")
 for _,amount in ipairs({3,5,7}) do deposit(iron,amount,"warm iron "..amount,baseline and 5 or 0,baseline and 5 or 0) end
 -- Native MVPS restores old metadata after set_node runs on_construct. Moving
 -- one step remains diagonally connected; the second must invalidate that warm
 -- cache and disconnect. Neither offered stack is consumed during preflight.
 local direction=vector.new(0,0,1)
 assert(mesecon.mvps_push(controller,direction,1,""),"Native MVPS moves the controller")
 controller=controller+direction
 local moved,moved_scans=measure("moved connected controller",function()
  return def(controller).tube.can_insert(controller,core.get_node(controller),ItemStack(iron.." 2"),direction)
 end)
 eq(moved,true,"Once-moved controller remains diagonally connected");eq(moved_scans,5,"Moved cache origin forces native reindex")
 assert(mesecon.mvps_push(controller,direction,1,""),"Native MVPS moves warm controller beyond trim")
 controller=controller+direction
 local disconnected,movement_scans=measure("moved disconnected controller",function()
  return def(controller).tube.can_insert(controller,core.get_node(controller),ItemStack(iron.." 2"),direction)
 end)
 eq(disconnected,false,"Moved controller cannot access formerly connected cached drawers");eq(movement_scans,1,"Moved disconnected scan visits only controller")
 eq(def(controller).tube.insert_object(controller,core.get_node(controller),ItemStack(iron.." 2"),direction):get_count(),2,"Moved disconnected commit returns every input")
 for _=1,2 do
  assert(mesecon.mvps_push(controller,-direction,1,""),"Native MVPS returns controller toward original path")
  controller=controller-direction
 end
 eq(core.get_node(p(0)).name,"drawers:controller","Native controller movement restores starting position")
 deposit(copper,11,"new copper",5,5)
 local a,b
 for _,x in ipairs({2,4}) do if content(p(x)).name==iron then a=p(x) else b=p(x) end end
 assert(a and b,"Native controller assigns two distinct drawers")
 eq(content(a).count,25,"Repeated controller deposits conserve all iron")
 eq(content(b).count,11,"Controller conserves copper")
 core.remove_node(p(1))
 if not baseline then eq(core.get_meta(controller):get_string("drawers_table_index"),"","Removing trim invalidates cached paths") end
 local accepted,scans=measure("disconnected preflight",function() return def(controller).tube.can_insert(controller,core.get_node(controller),ItemStack(iron.." 2"),vector.new(1,0,0)) end)
 eq(accepted,false,"Disconnected controller refuses iron");eq(scans,1,"Disconnected scan visits only controller")
 local left=def(controller).tube.insert_object(controller,core.get_node(controller),ItemStack(iron.." 2"),vector.new(1,0,0))
 eq(left:get_count(),2,"Disconnected insertion returns every item");eq(content(a).count,25,"Disconnected cached drawer unchanged")
 place(p(1),"drawers:trim")
 deposit(iron,2,"reconnected iron",5,baseline and 5 or 0)
 drawers.remove_visuals(a)
 if not baseline then
  eq(drawers.get_visual(a,""),nil,"Removed drawer visual is unavailable")
  eq(def(controller).tube.can_insert(controller,core.get_node(controller),ItemStack(iron),vector.new(1,0,0)),false,"Inactive visual cannot accept a cached deposit")
  eq(def(controller).tube.insert_object(controller,core.get_node(controller),ItemStack(iron),vector.new(1,0,0)):get_count(),1,"Inactive visual returns the entire offered stack")
  eq(content(a).count,27,"Unavailable visual leaves drawer quantity unchanged")
 end
 drawers.spawn_visuals(a)
 if not baseline then eq(core.get_meta(controller):get_string("drawers_table_index"),"","Respawning visuals invalidates cached paths") end
 deposit(iron,1,"respawned visual iron",5,baseline and 5 or 0)
 place(p(5),"drawers:trim");place(p(6),"drawers:oakwood4")
 deposit("mcl_redstone:redstone",1,"new four-compartment drawer",7,7)
 eq(content(p(6),"1").count,1,"Controller allocates first native four-compartment slot")
 local tagged=ItemStack(iron);tagged:get_meta():set_string("storage_smoke","do not erase")
 eq(drawers.drawer_can_insert_stack(a,tagged,""),0,"Native drawers refuse metadata-bearing payloads")
 local worn=ItemStack(iron);worn:set_wear(100)
 eq(worn:get_wear(),100,"Engine supports nonzero wear on a stackable item")
 eq(drawers.drawer_can_insert_stack(a,worn,""),baseline and 1 or 0,"Worn payload cannot silently lose wear")
 if baseline then
  assert(drawers.drawer_insert_object(a,worn,""):is_empty(),"Baseline accepts worn iron")
  eq(drawers.drawer_take_item(a,ItemStack(iron)):get_wear(),0,"Baseline silently discards stackable-item wear")
 end
 place(p(8),"drawers:oakwood1")
 eq(drawers.drawer_can_insert_stack(p(8),ItemStack("mcl_tools:pick_iron"),""),0,"Native drawers refuse unstackable tools")
 eq(content(a).maxCount,2304,"Single drawer base capacity")
 local function upgrade(slot,name,capacity)
  local stack=ItemStack(name)
  eq(def(a).allow_metadata_inventory_put(a,"upgrades",slot,stack,actor),1,"Native upgrade permission")
  inv(a):set_stack("upgrades",slot,stack);def(a).on_metadata_inventory_put(a,"upgrades",slot,stack,actor)
  eq(content(a).maxCount,capacity,"Native additive upgrade capacity")
 end
 upgrade(1,"drawers:upgrade_iron",4608);upgrade(2,"drawers:upgrade_iron",6912);upgrade(3,"drawers:upgrade_gold",11520)
 assert(drawers.drawer_insert_object(a,ItemStack(iron.." "..(5000-content(a).count)),""):is_empty(),"Upgraded drawer holds all 5000 iron")
 for _,slot in ipairs({3,2,1}) do
  local stack=inv(a):get_stack("upgrades",slot)
  eq(def(a).allow_metadata_inventory_take(a,"upgrades",slot,stack,actor),1,"Native upgrade removal permission")
  inv(a):set_stack("upgrades",slot,ItemStack());def(a).on_metadata_inventory_take(a,"upgrades",slot,stack,actor)
 end
 eq(content(a).count,2304,"Upgrade removal retains base-capacity iron")
 eq(content(a).maxCount,2304,"Upgrade removal restores base capacity")
 core.after(0.2,function() checked(function()
  eq(dropped(a,iron,14),baseline and 0 or 2696,"Actual overflow item entities account for excess iron")
  recover(a,14)
  eq(count(recovery,iron),baseline and 0 or 2696,"Actual overflow entities are recoverable through native item_pickup")
  local visual=assert(drawers.get_visual(a,""))
  local protection=core.is_protected
  core.is_protected=function(pos,name) return vector.equals(pos,a) or protection(pos,name) end
  local protected_ok,protected_error=pcall(function()
   eq(def(a).allow_metadata_inventory_put(a,"upgrades",1,ItemStack("drawers:upgrade_iron"),actor),0,"Protected upgrade insertion refused")
   controls={aux1=true};visual:on_punch(actor)
   eq(core.get_meta(a):get_int("locked"),0,"Protected front interaction does not change lock")
  end)
  core.is_protected=protection;assert(protected_ok,protected_error)
  controls={aux1=true};visual:on_punch(actor)
  eq(core.get_meta(a):get_int("locked"),1,"Native Aux1 front punch locks item identity")
  controls={sneak=true};visual:on_punch(actor)
  eq(content(a).count,2303,"Sneak front punch retrieves exactly one")
  controls={};visual:on_punch(actor)
  eq(content(a).count,2239,"Ordinary front punch retrieves one stack")
  while content(a).count>0 do visual:on_punch(actor) end
  eq(content(a).name,iron,"Locked empty drawer retains iron identity")
  eq(drawers.drawer_insert_object(a,ItemStack(copper.." 3"),""):get_count(),3,"Locked empty drawer refuses different material")
  controls={aux1=true};visual:on_punch(actor);controls={}
  eq(content(a).name,"","Unlocking empty drawer clears identity")
  eq(count(recovery,iron),baseline and 2304 or 5000,"All 5000 iron accounted for after overflow recovery and manual front retrieval")
  log(baseline and "BASELINE: exactly 2696 overflow iron lost; retained 2304 manually recovered" or
   "All 5000 iron conserved: 2304 retained plus 2696 recoverable overflow in bounded stacks; upgrades and item locks retain native behavior")
  piston_check();dig_checks(a,b)
 end) end)
end
local function resume()
 local a=assert(core.deserialize(state:get_string("iron_pos")))
 local b=assert(core.deserialize(state:get_string("copper_pos")))
 eq(content(a).count,4,"Saved drawer quantity survives process restart")
 eq(content(b).count,11,"Saved copper survives process restart")
 local accepted,scans=measure("reloaded stale disconnected cache",function()
  return def(controller).tube.can_insert(controller,core.get_node(controller),ItemStack(iron.." 3"),vector.new(1,0,0))
 end)
 eq(accepted,false,"Reloaded stale cache cannot reach disconnected drawer");eq(scans,1,"Reloaded disconnected scan visits only controller")
 place(p(1),"drawers:trim")
 deposit(iron,3,"reconnected after restart",7,baseline and 7 or 0)
 eq(content(a).count,7,"Resumed insertion preserves saved plus new iron")
 eq(content(b).count,11,"Resumed insertion preserves unrelated copper")
 state:set_string("phase","complete")
 finish(true,"COMPLETE: process restart rejects stale disconnected cache; reconnect resumes native deposits and preserves 7 iron, 11 copper and the four-compartment drawer")
end
local started=false
local marker=p(8,11)
core.register_node("era_storage_smoke:activation_marker",{description="Test activation marker",drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_storage_smoke:await_activation",nodenames={"era_storage_smoke:activation_marker"},run_at_every_load=true,
 action=function()
  if started then return end
  started=true
  core.after(0,function() checked(function() if state:get_string("phase")=="resume" then resume() else initial() end end) end)
 end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-2,-2)-vector.new(0,3,0),p(29,29)+vector.new(0,5,0),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-2,-2)-vector.new(0,3,0),p(29,29)+vector.new(0,5,0))
    if core.get_node(marker).name~="era_storage_smoke:activation_marker" then place(marker,"era_storage_smoke:activation_marker") end
    for _,x in ipairs({-1,0,16}) do for _,z in ipairs({-1,0,16}) do assert(core.forceload_block(p(x,z),true),"Activate test blocks and front visuals") end end
    core.after(15,function() checked(function() assert(started,"Native block activation timeout") end) end)
   end) end) end
  end)
 end)
end)
