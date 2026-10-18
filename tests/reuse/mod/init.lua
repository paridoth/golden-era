-- SPDX-License-Identifier: GPL-3.0-or-later
-- Test-only integration: production machines and their saved format are unchanged.
local actor="pipeworks_probe"
local player={get_player_name=function() return actor end}
local east={x=1,y=0,z=0}
local finished=false
local routed_inserts=0
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label)
 assert(a==b,(label or "probe")..": "..tostring(a).." ~= "..tostring(b))
end
local function inventory(pos) return core.get_meta(pos):get_inventory() end
local function finish(ok,message)
 if finished then return end
 finished=true
 core.log(ok and "action" or "error","ERA REUSE PROBE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Pipeworks feasibility probe finished",false,0)
end
local function checked(callback)
 local ok,err=xpcall(callback,debug.traceback)
 if not ok then finish(false,err) end
 return ok
end
local function place(pos,name)
 core.set_node(pos,{name=name})
 local def=assert(core.registered_nodes[name],name)
 if def.on_construct then def.on_construct(pos) end
end
local function side(pos,direction,inserting)
 local offset=inserting and vector.multiply(direction,-1) or direction
 return era.face_between(pos,vector.add(pos,offset))
end
local function can_insert(pos,node,stack,direction,owner)
 if type(owner)~="string" or core.is_protected(pos,owner) or not era.machine_ready(pos,node.name) then return false end
 if not era.port_allows(pos,side(pos,direction,true),"src",true) or not era.recipe_for(pos,node.name,stack:get_name()) then return false end
 local inv=inventory(pos)
 local existing=inv:get_stack("src",1)
 if core.get_meta(pos):get_int("work")>0 and existing:get_name()~=stack:get_name() then return false end
 return inv:room_for_item("src",stack)
end
local function extraction_count(pos,node,stack,direction,list)
 if not era.machine_ready(pos,node.name) or not era.port_allows(pos,side(pos,direction,false),list,false) then return 0 end
 if list=="src" and core.get_meta(pos):get_int("work")>0 then return 0 end
 return stack:get_count()
end
local function install_adapter(name)
 local def=core.registered_nodes[name]
 local groups=table.copy(def.groups)
 groups.tubedevice=1; groups.tubedevice_receiver=1
 core.override_item(name,{groups=groups,tube={
  -- Static connection geometry; per-machine metadata remains authoritative in callbacks.
  connect_sides={left=1,right=1,front=1,back=1,top=1,bottom=1},
  can_insert=can_insert,
  insert_object=function(pos,node,stack,direction,owner)
   -- Routing preflight may precede arrival; recheck every guard at commit time.
   if not can_insert(pos,node,stack,direction,owner) then return stack end
   routed_inserts=routed_inserts+1
   return inventory(pos):add_item("src",stack)
  end,
  input_inventory={"dst","secondary","src"},
  return_input_invref=function(pos,node,direction,owner)
   if type(owner)~="string" or core.is_protected(pos,owner) or not era.machine_ready(pos,node.name) then return end
   return inventory(pos)
  end,
  can_remove=extraction_count,
 }})
end
-- Install while node registration is open, before the server begins simulation.
for _,name in ipairs({"era_thermal:pulverizer","era_thermal:furnace"}) do install_adapter(name) end
local function machine_snapshot(pos)
 local m=core.get_meta(pos)
 return {energy=m:get_int("energy"),work=m:get_int("work"),job=m:get_string("job"),input=inventory(pos):get_stack("src",1):to_string()}
end
local function same_machine(pos,before,label)
 local after=machine_snapshot(pos)
 for key,value in pairs(before) do eq(after[key],value,label.." "..key) end
end
local function run()
 assert(core.settings:get_bool("era_test_manual"),"Probe requires the native scheduler disabled")
 assert(xcompat.gameid=="mineclonia","Temporary Golden Era game alias must select Mineclonia")
 local pulverizer,furnace=p(3),p(3,4)
 place(pulverizer,"era_thermal:pulverizer"); place(furnace,"era_thermal:furnace")
 for _,pos in ipairs({pulverizer,furnace}) do
  core.get_meta(pos):set_string("owner",actor)
  assert(era.configure_side(pos,4,1,player),"Configure west input")
 end
 local pm=core.get_meta(pulverizer)
 inventory(pulverizer):set_stack("src",1,era.mcl.ore)
 local state=era.state(pulverizer); state.energy=5000; era.save(pulverizer,state)
 state=era.state(pulverizer); era.process(pulverizer,"era_thermal:pulverizer",state); era.save(pulverizer,state)
 assert(state.work>0 and pm:get_string("job")~="","Native job must be active before tube insertion")
 local original=machine_snapshot(pulverizer)
 local node=core.get_node(pulverizer)
 local tube=core.registered_nodes[node.name].tube
 local ore=ItemStack(era.mcl.ore)
 eq(tube.can_insert(pulverizer,node,ore,east,actor),true,"valid preflight")
 assert(era.configure_side(pulverizer,4,2,player))
 eq(tube.can_insert(pulverizer,node,ore,east,actor),false,"closed receiving side")
 eq(tube.insert_object(pulverizer,node,ore,east,actor):to_string(),ore:to_string(),"arrival rechecks changed side")
 same_machine(pulverizer,original,"closed side leaves native state")
 assert(era.configure_side(pulverizer,4,1,player))
 eq(tube.can_insert(pulverizer,node,ore,east,actor),true,"preflight before protection changes")
 local old_protected=core.is_protected
 core.is_protected=function(pos,name)
  return vector.equals(pos,pulverizer) and name==actor or old_protected(pos,name)
 end
 local ok,err=xpcall(function()
  eq(tube.can_insert(pulverizer,node,ore,east,actor),false,"protected receiving side")
  eq(tube.insert_object(pulverizer,node,ore,east,actor):to_string(),ore:to_string(),"arrival rechecks changed protection")
  eq(tube.return_input_invref(pulverizer,node,east,actor),nil,"protected extraction inventory")
  same_machine(pulverizer,original,"protection leaves native state")
 end,debug.traceback)
 core.is_protected=old_protected
 assert(ok,err)
 local invalid=ItemStack(era.mcl.coal)
 eq(tube.can_insert(pulverizer,node,invalid,east,actor),false,"invalid recipe denied")
 eq(tube.insert_object(pulverizer,node,invalid,east,actor):to_string(),invalid:to_string(),"invalid recipe returned")
 assert(era.configure_side(pulverizer,4,5,player)) -- all slots, including idle input extraction
 eq(tube.can_remove(pulverizer,node,ore,{x=-1,y=0,z=0},"src",1),0,"reserved input extraction denied")
 assert(era.configure_side(pulverizer,4,1,player))
 same_machine(pulverizer,original,"callback guards preserve native RF and job")
 state=era.state(furnace); state.energy=1500; era.save(furnace,state)
 for _,z in ipairs({0,4}) do
  for x=0,2 do place(p(x,z),"pipeworks:tube_1") end
  for x=0,3 do pipeworks.scan_for_tube_objects(p(x,z)) end
 end
 local before_inserts=routed_inserts
 assert(pipeworks.tube_inject_item(p(0),p(0),east,ore,actor),"Create travelling ore packet")
 assert(pipeworks.tube_inject_item(p(0,4),p(0,4),east,ItemStack("era_materials:iron_dust"),actor),"Create travelling dust packet")
 eq(inventory(pulverizer):get_stack("src",1):get_count(),1,"ore not inserted immediately")
 eq(inventory(furnace):get_stack("src",1):get_count(),0,"dust not inserted immediately")
 local started=core.get_us_time()
 local function await_arrival()
  if finished then return end
  checked(function()
   local a=inventory(pulverizer):get_stack("src",1)
   local b=inventory(furnace):get_stack("src",1)
   if a:get_count()==2 and b:get_count()==1 then
    eq(a:get_name(),era.mcl.ore,"routed ore identity")
    eq(b:get_name(),"era_materials:iron_dust","routed dust identity")
    eq(routed_inserts-before_inserts,2,"actual arrivals use adapter")
    eq(pm:get_int("energy"),original.energy,"routing preserves pulverizer RF")
    eq(pm:get_int("work"),original.work,"routing preserves active work")
    eq(pm:get_string("job"),original.job,"routing preserves saved job and byproduct decision")
    assert(era.machine_ready(pulverizer,"era_thermal:pulverizer"),"Pulverizer remains valid")
    assert(era.machine_ready(furnace,"era_thermal:furnace"),"Furnace remains valid")
    for _=1,1000 do
     local next_state=era.state(furnace)
     era.process(furnace,"era_thermal:furnace",next_state); era.save(furnace,next_state)
     if inventory(furnace):is_empty("src") then break end
    end
    eq(inventory(furnace):get_stack("dst",1):get_name(),era.mcl.ingot,"native processing of routed dust")
    eq(inventory(furnace):get_stack("dst",1):get_count(),1,"one routed dust becomes one ingot")
    eq(era.state(furnace).energy,0,"exact native 1500 RF cost")
    eq(era.state(furnace).work,0,"completed work cleared")
    finish(true,"temporary Mineclonia alias; real Pipeworks packets reached two native machines; side/protection arrival checks, recipe rejection, reserved-input guard, saved-job preservation and 1500-RF smelting")
   elseif core.get_us_time()-started>15*1000000 then error("Timed out waiting for real Pipeworks packet routing")
   else core.after(0.1,await_arrival) end
  end)
 end
 core.after(0.1,await_arrival)
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-1,-1),p(5,5),function(_,_,remaining)
   if remaining==0 then core.after(0,function()
    checked(function() core.load_area(p(-1,-1),p(5,5)); run() end)
   end) end
  end)
 end)
end)
