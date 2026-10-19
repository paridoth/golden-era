-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native timers/globalsteps move all test packets. Never invoke an injector
-- effector, clock timer, tube on_step, or controller insertion callback manually.
local state=core.get_mod_storage()
local done=false
local function p(x,z) return vector.new(x,200,z or 0) end
local source,injector,clock,controller=p(0),p(1),p(1,1),p(4)
local a,b,c=p(6),p(8),p(10)
local iron,copper="mcl_core:iron_ingot","mcl_copper:copper_ingot"
local controls={}
local actor={get_player_name=function() return "controller_smoke" end,get_player_control=function() return controls end}
local expected_iron,expected_copper=4613,17
local function eq(actual,expected,label) assert(actual==expected,label..": "..tostring(actual).." ~= "..tostring(expected)) end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function content(pos,id) return drawers.drawer_get_content(pos,id or "") end
local function log(message) core.log("action","Controller smoke: "..message) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA CONTROLLER SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Controller smoke checkpoint",false,0)
end
local function checked(fn)
 local ok,err=xpcall(fn,debug.traceback)
 if not ok then finish(false,err) end
end
local function place(pos,name,param2)
 assert(core.registered_nodes[name],"Registered fixture node "..name)
 core.set_node(pos,{name=name,param2=param2 or 0})
 core.get_meta(pos):set_string("owner",actor:get_player_name())
end
local function east_facedir()
 for value=0,23 do
  if vector.equals(pipeworks.facedir_to_right_dir(value),vector.new(1,0,0)) then return value end
 end
 error("Missing east filter orientation")
end
local function inventory_count(pos,name)
 local total=0
 for _,stack in ipairs(inv(pos):get_list("main") or {}) do
  if stack:get_name()==name then total=total+stack:get_count() end
 end
 return total
end
local function inventory_signature(pos)
 local lists=inv(pos):get_lists();local names={};local parts={}
 for name in pairs(lists) do names[#names+1]=name end
 table.sort(names)
 for _,name in ipairs(names) do
  parts[#parts+1]=name..":"..#lists[name]
  for _,stack in ipairs(lists[name]) do parts[#parts+1]=stack:to_string() end
 end
 return table.concat(parts,"\n")
end
local function moving()
 local totals={};local packets=0;local signs={}
 for _,entity in pairs(pipeworks.luaentity.entities or {}) do
  if entity.name=="pipeworks:tubed_item" then
   local stack=ItemStack(entity.itemstring)
   assert(not stack:is_empty(),"Native tube packet has physical payload")
   totals[stack:get_name()]=(totals[stack:get_name()] or 0)+stack:get_count()
   packets=packets+1
   if stack:get_name()==iron then
    local velocity=entity:get_velocity().x
    if velocity>0 then signs.east=true elseif velocity<0 then signs.west=true end
   end
  end
 end
 return totals,packets,signs
end
local function drawer_count(name)
 local total=0
 for _,pos in ipairs({a,b}) do
  local stored=content(pos)
  if stored.name==name then total=total+stored.count end
 end
 for slot=1,4 do
  local stored=content(c,tostring(slot))
  if stored.name==name then total=total+stored.count end
 end
 return total
end
local function invariant()
 local in_tubes,packets,signs=moving()
 eq(drawer_count(iron)+inventory_count(source,iron)+(in_tubes[iron] or 0),expected_iron,"Every iron accounted for in source, drawers and native tube packets")
 eq(drawer_count(copper)+inventory_count(source,copper)+(in_tubes[copper] or 0),expected_copper,"Every copper accounted for in source, drawers and native tube packets")
 for name in pairs(in_tubes) do assert(name==iron or name==copper,"No unexpected native packet payload "..name) end
 for _,object in ipairs(core.get_objects_inside_radius(p(5,4),24)) do
  local entity=object:get_luaentity()
  assert(not entity or entity.name~="__builtin:item" or ItemStack(entity.itemstring):is_empty(),"No injected materials may escape as loose world items")
 end
 eq(content(a).name,iron,"Upgraded drawer keeps iron identity")
 eq(content(a).maxCount,4608,"Native iron upgrade retains doubled capacity")
 eq(core.get_meta(a):get_int("locked"),1,"Iron drawer remains type-locked")
 eq(content(b).name,copper,"Other locked drawer retains copper identity")
 eq(core.get_meta(b):get_int("locked"),1,"Copper drawer remains type-locked")
 eq(inv(a):get_stack("upgrades",1):get_name(),"drawers:upgrade_iron","Capacity upgrade remains installed")
 assert(inv(controller):is_empty("src"),"Native tube deposits do not strand items in controller UI input")
 return in_tubes,packets,signs
end
local function diagnostic()
 local in_tubes,packets=moving()
 local compartments={}
 for slot=1,4 do compartments[slot]=content(c,tostring(slot)) end
 return core.write_json({source_iron=inventory_count(source,iron),source_copper=inventory_count(source,copper),
  iron=content(a),copper=content(b),compartments=compartments,moving=in_tubes,packets=packets,
  distribution=core.get_meta(controller):get_string("distribute"),clock=core.get_node(clock).name})
end
local function clock_enabled(enabled)
 local timer=core.get_node_timer(clock)
 if timer:is_started()~=enabled then def(clock).on_rightclick(clock,core.get_node(clock),actor) end
 eq(timer:is_started(),enabled,"Native clock right-click sets desired timer state")
end
local function distribution(enabled)
 def(controller).on_receive_fields(controller,"",{distribute=enabled and "true" or "false"},actor)
 eq(core.get_meta(controller):get_string("distribute"),enabled and "true" or "false","Native controller distribution checkbox")
end
local function supply(name,amount)
 assert(inv(source):add_item("main",name.." "..amount):is_empty(),"Fixture source barrel accepts native supply")
end
local function snapshot()
 return {source=inventory_signature(source),injector=inventory_signature(injector),upgrade=inventory_signature(a),
  a=content(a),b=content(b),c1=content(c,"1"),c2=content(c,"2"),c3=content(c,"3"),c4=content(c,"4"),
  lock_a=core.get_meta(a):get_int("locked"),lock_b=core.get_meta(b):get_int("locked"),
  distribution=core.get_meta(controller):get_string("distribute"),clock=core.get_node(clock).name,
  clock_running=core.get_node_timer(clock):is_started()}
end
local function assert_snapshot(expected)
 local actual=snapshot()
 for key,value in pairs(expected) do
  if type(value)=="table" then
   for field,number in pairs(value) do eq(actual[key][field],number,"Restart preserves "..key.."."..field) end
  else eq(actual[key],value,"Restart preserves "..key) end
 end
end
local function poll_states(step,timeout)
 local started=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   local totals,packets,signs=invariant()
   step(core.get_us_time(),totals,packets,signs)
   if not done then
    assert(core.get_us_time()-started<timeout*1000000,"Controller state timeout: "..diagnostic())
    core.after(0.2,poll)
   end
  end)
 end
 core.after(0.2,poll)
end
local function initial()
 assert(pipeworks.drop_on_routing_fail==false,"Fixture uses native default bounce behavior")
 for x=-1,12 do for z=-2,12 do
  core.set_node(p(x,z)-vector.new(0,1,0),{name="mcl_core:stone"})
  for y=0,2 do core.set_node(p(x,z)+vector.new(0,y,0),{name="air"}) end
 end end
 place(source,"mcl_barrels:barrel_closed")
 place(injector,"pipeworks:mese_filter",east_facedir())
 for _,x in ipairs({2,3}) do place(p(x),"pipeworks:tube_1") end
 place(controller,"drawers:controller")
 for _,x in ipairs({5,7,9}) do place(p(x),"drawers:trim") end
 place(a,"drawers:oakwood1");place(b,"drawers:oakwood1");place(c,"drawers:oakwood4")
 local upgrade=ItemStack("drawers:upgrade_iron")
 eq(def(a).allow_metadata_inventory_put(a,"upgrades",1,upgrade,actor),1,"Native upgrade permission")
 inv(a):set_stack("upgrades",1,upgrade);def(a).on_metadata_inventory_put(a,"upgrades",1,upgrade,actor)
 assert(drawers.drawer_insert_object(a,ItemStack(iron.." 4605"),""):is_empty(),"Fixture fills upgraded iron drawer to three below capacity")
 assert(drawers.drawer_insert_object(b,ItemStack(copper.." 11"),""):is_empty(),"Fixture seeds copper type")
 controls={aux1=true};drawers.get_visual(a,""):on_punch(actor);drawers.get_visual(b,""):on_punch(actor);controls={}
 for x=0,10 do pipeworks.scan_for_tube_objects(p(x)) end
 for slot,name in ipairs({iron,copper}) do
  eq(def(injector).allow_metadata_inventory_put(injector,"main",slot,ItemStack(name),actor),0,"Native injector ghost filter consumes no material")
 end
 supply(iron,8);supply(copper,6)
 place(clock,"mesecons_blinkyplant:blinky_plant_off")
 eq(core.get_meta(controller):get_string("distribute"),"","Controller uses native distribution-off default")
 local stage="partial_block";local stable;local saw_east,saw_west=false,false
 local clock_states={};local saw_packet=false
 poll_states(function(now,totals,packets,signs)
  if packets>0 then saw_packet=true end
  clock_states[core.get_node(clock).name]=true
  saw_east=saw_east or signs.east;saw_west=saw_west or signs.west
  if stage=="partial_block" then
   eq(content(c,"1").count,0,"Distribution-off does not overflow iron into an empty compartment")
   if inv(source):is_empty("main") and content(a).count==4608 and content(b).count==17 and (totals[iron] or 0)==5 and packets==1 then
    if not stable then stable=now end
    if now-stable>3500000 then
     assert(saw_packet and saw_east and saw_west,"Actual tube packet travels both ways while blocked")
     assert(clock_states["mesecons_blinkyplant:blinky_plant_off"] and clock_states["mesecons_blinkyplant:blinky_plant_on"],"Real native timer toggles the clock")
     log("Real clock/injector/tubes: 8 iron partially insert 3, retain 5 bouncing; unrelated 6 copper route into their locked drawer; no empty-drawer overflow with distribution off")
     distribution(true);stage="first_recovery";stable=nil
    end
   else stable=nil end
  elseif stage=="first_recovery" and content(c,"1").count==5 and packets==0 then
   eq(content(c,"1").name,iron,"Native distribution claims first empty compartment")
   if not stable then stable=now end
   if now-stable>2000000 then
    assert(drawers.drawer_insert_object(c,ItemStack(iron.." 571"),"1"):is_empty(),"Fixture fills the second matching iron destination")
    eq(content(c,"1").count,576,"Four-compartment native capacity is full")
    expected_iron=5193;expected_copper=20
    distribution(false);supply(iron,9);supply(copper,3)
    stage="restart_block";stable=nil;saw_east=false;saw_west=false
   end
  elseif stage=="restart_block" then
   eq(content(c,"2").count,0,"Distribution-off keeps next empty compartment unused")
   if inv(source):is_empty("main") and content(b).count==20 and (totals[iron] or 0)==9 and packets==1 then
    if not stable then stable=now end
    if now-stable>3500000 then
     assert(saw_east and saw_west,"Second full-capacity packet bounces natively")
     clock_enabled(false)
     state:set_string("snapshot",core.serialize(snapshot()))
     state:set_string("phase","resume")
     log(diagnostic())
     finish(true,"CHECKPOINT: native timer/filter/tube delivery honors locked upgraded drawers; partial leftovers bounce without loss; distribution recovers into a four-slot drawer; 9 blocked iron saved in a real in-flight packet with source empty and clock stopped")
    end
   else stable=nil end
  end
 end,90)
end
local function resume()
 expected_iron=5193;expected_copper=20
 assert_snapshot(assert(core.deserialize(state:get_string("snapshot")),"Saved controller fixture snapshot"))
 local totals,packets=invariant()
 eq(totals[iron],9,"All blocked iron survives as native in-flight payload")
 eq(packets,1,"Exactly one native blocked packet survives engine restart")
 assert(not core.get_node_timer(clock):is_started(),"Stopped native clock stays stopped after restart")
 local stage="resume_block";local since=core.get_us_time();local stable
 local saw_east,saw_west=false,false
 poll_states(function(now,current,moving_count,signs)
  saw_east=saw_east or signs.east;saw_west=saw_west or signs.west
  if stage=="resume_block" then
   eq(current[iron],9,"Restarted native packet retains all blocked iron")
   eq(content(c,"2").count,0,"Reloaded distribution-off still refuses empty compartment")
   if now-since>3500000 then
    assert(saw_east and saw_west,"Restarted packet resumes native motion rather than becoming inert")
    distribution(true);stage="resume_recovery"
   end
  elseif stage=="resume_recovery" and content(c,"2").count==9 and moving_count==0 then
   eq(content(c,"2").name,iron,"Restarted packet enters next empty compartment after distribution is enabled")
   expected_iron=5200;expected_copper=24
   supply(iron,7);supply(copper,4);clock_enabled(true);stage="final_delivery"
  elseif stage=="final_delivery" and inv(source):is_empty("main") and moving_count==0 and content(c,"2").count==16 and content(b).count==24 then
   eq(content(a).count,4608,"Upgraded primary iron drawer stays full")
   eq(content(c,"1").count,576,"First iron compartment stays full")
   eq(content(c,"3").count,0,"No unintended third iron compartment allocated")
   eq(content(c,"4").count,0,"No unintended fourth iron compartment allocated")
   if not stable then stable=now end
   if now-stable>3500000 then
    clock_enabled(false);state:set_string("phase","complete")
    log(diagnostic())
    finish(true,"COMPLETE: restart preserves 9 in-flight iron, locks, upgrade, ghost filters and distribution state; native bounce resumes, checkbox releases the packet, restarted clock delivers 7 more iron and 4 copper; all 5200 iron and 24 copper conserved with no loose items or hidden packets")
   end
  end
 end,70)
end
-- Wait for initial native LBMs before configuring ghost filters, matching a
-- normal player's placement order and avoiding old-inventory conversion LBMs.
local started=false
local marker=p(13,11)
core.register_node("era_controller_smoke:activation_marker",{description="Test activation marker",drawtype="airlike",walkable=false,pointable=false})
core.register_lbm({name="era_controller_smoke:await_activation",nodenames={"era_controller_smoke:activation_marker"},run_at_every_load=true,
 action=function()
  if started then return end
  started=true
  core.after(0,function() checked(function() if state:get_string("phase")=="resume" then resume() else initial() end end) end)
 end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-2,-3)-vector.new(0,3,0),p(13,12)+vector.new(0,5,0),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-2,-3)-vector.new(0,3,0),p(13,12)+vector.new(0,5,0))
    if core.get_node(marker).name~="era_controller_smoke:activation_marker" then place(marker,"era_controller_smoke:activation_marker") end
    for _,x in ipairs({-1,0}) do for _,z in ipairs({-1,0}) do assert(core.forceload_block(p(x,z),true),"Activate fixture nodes and drawer fronts") end end
    core.after(15,function() checked(function() assert(started,"Native block activation timeout") end) end)
   end) end) end
  end)
 end)
end)
