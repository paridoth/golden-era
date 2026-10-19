-- SPDX-License-Identifier: GPL-3.0-or-later
-- Stock device fixtures and UI callbacks, real node timers and tube entities.
-- Never call the autocrafter's timer or filter's Mesecons effector manually.
local state=core.get_mod_storage()
local done=false
local actor={get_player_name=function() return "automation_smoke" end}
local function p(x,z) return vector.new(x,200,z or 0) end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA AUTOMATION SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Automation smoke checkpoint",false,0)
end
local function checked(f)
 local ok,err=xpcall(f,debug.traceback)
 if not ok then finish(false,err) end
end
local function place(pos,name,param2)
 assert(core.registered_nodes[name],"Missing automation node "..name)
 core.set_node(pos,{name=name,param2=param2 or 0})
 core.get_meta(pos):set_string("owner",actor:get_player_name())
end
local function east_facedir()
 for n=0,23 do if vector.equals(pipeworks.facedir_to_right_dir(n),vector.new(1,0,0)) then return n end end
 error("No east filter orientation")
end
local function count(pos,list,name)
 local total=0
 for _,stack in ipairs(inv(pos):get_list(list) or {}) do
  if stack:get_name()==name then total=total+stack:get_count() end
 end
 return total
end
local function signature(pos)
 local lists=inv(pos):get_lists();local names={};local parts={}
 for name in pairs(lists) do names[#names+1]=name end
 table.sort(names)
 for _,name in ipairs(names) do
  parts[#parts+1]=name..":"..#lists[name]
  for _,stack in ipairs(lists[name]) do
   local fields=(stack:get_meta():to_table() or {}).fields or {}
   local keys={};for key in pairs(fields) do keys[#keys+1]=key end;table.sort(keys)
   local item={stack:get_name(),tostring(stack:get_count()),tostring(stack:get_wear())}
   for _,key in ipairs(keys) do item[#item+1]=key.."="..string.format("%q",fields[key]) end
   parts[#parts+1]=table.concat(item,"|")
  end
 end
 return table.concat(parts,"\n")
end
local function drawer(pos,name,amount)
 local content=drawers.drawer_get_content(pos,"")
 eq(content.count,amount,"Drawer's exact stored quantity")
 if amount>0 then eq(content.name,name,"Drawer item identity") end
end
local function enabled(crafter,value)
 def(crafter).on_receive_fields(crafter,"",value and {off=true} or {on=true},actor)
 eq(core.get_meta(crafter):get_int("enabled"),value and 1 or 0,"Native enable control")
end
local function configure(crafter,output)
 eq(def(crafter).allow_metadata_inventory_put(crafter,"output",1,ItemStack(output),actor),0,"Ghost output configuration consumes no physical stack")
 eq(inv(crafter):get_stack("output",1):get_name(),output,"Native output preview")
end
local function line(z,output)
 local fixture={source=p(0,z),crafter=p(3,z),drawer=p(6,z),input=p(1,z),output=p(4,z)}
 place(fixture.source,"mcl_barrels:barrel_closed")
 place(fixture.crafter,"pipeworks:autocrafter")
 place(fixture.drawer,"drawers:oakwood1")
 for _,x in ipairs({1,4}) do
  place(p(x,z),"pipeworks:mese_filter",east_facedir())
  place(p(x,z+1),"mesecons_blinkyplant:blinky_plant_off")
 end
 for _,x in ipairs({2,5}) do place(p(x,z),"pipeworks:tube_1") end
 for x=0,6 do pipeworks.scan_for_tube_objects(p(x,z)) end
 -- Configure the output injector's native ghost filter so spools stay in the
 -- autocrafter's crafted-items inventory while only the product enters storage.
 eq(def(fixture.output).allow_metadata_inventory_put(fixture.output,"main",1,ItemStack(output),actor),0,"Native injector ghost filter")
 configure(fixture.crafter,output)
 return fixture
end
local conduit={source=p(0),crafter=p(3),drawer=p(6),input=p(1),output=p(4)}
local wood={source=p(0,8),crafter=p(3,8),drawer=p(6,8),input=p(1,8),output=p(4,8)}
local function supply(fixture,items)
 for _,stack in ipairs(items) do assert(inv(fixture.source):add_item("main",stack):is_empty(),"Fixture supply overflow") end
end
local function empty_source(fixture)
 return inv(fixture.source):is_empty("main")
end
local function expect_inputs(fixture,lead,wire)
 eq(count(fixture.crafter,"src","elepower_dynamics:lead_ingot"),lead,"Physical lead input")
 eq(count(fixture.crafter,"src","basic_materials:copper_wire"),wire,"Physical copper wire input")
end
local function snapshot()
 return {conduit_source=signature(conduit.source),conduit_crafter=signature(conduit.crafter),
  wood_source=signature(wood.source),wood_crafter=signature(wood.crafter),
  conduit_name=drawers.drawer_get_content(conduit.drawer,"").name,
  conduit_count=drawers.drawer_get_content(conduit.drawer,"").count,
  wood_count=drawers.drawer_get_content(wood.drawer,"").count,
  enabled=core.get_meta(conduit.crafter):get_int("enabled"),
  keep_items=core.get_meta(conduit.crafter):get_int("keep_items")}
end
local function assert_snapshot(expected)
 local actual=snapshot()
 for key,value in pairs(expected) do eq(actual[key],value,"Restart preserves "..key) end
end
local function assert_no_loose_items()
 for _,entity in pairs(pipeworks.luaentity.entities or {}) do
  assert(entity.name~="pipeworks:tubed_item" or ItemStack(entity.itemstring):is_empty(),"No material may remain hidden in transit at a checkpoint")
 end
 for _,object in ipairs(core.get_objects_inside_radius(p(3,4),30)) do
  local entity=object:get_luaentity()
  assert(not entity or entity.name~="__builtin:item" or ItemStack(entity.itemstring):is_empty(),"No duplicate or lost batch may hide as a dropped item")
 end
end
local function diagnostic()
 local moving={}
 for _,entity in pairs(pipeworks.luaentity.entities or {}) do
  if entity.name=="pipeworks:tubed_item" then moving[#moving+1]=entity.itemstring end
 end
 return core.write_json({conduit_drawer=drawers.drawer_get_content(conduit.drawer,""),
  wood_drawer=drawers.drawer_get_content(wood.drawer,""),moving=moving,
  conduit_src_lead=count(conduit.crafter,"src","elepower_dynamics:lead_ingot"),
  conduit_src_wire=count(conduit.crafter,"src","basic_materials:copper_wire"),
  conduit_dst_product=count(conduit.crafter,"dst","elepower_dynamics:conduit"),
  conduit_spools=count(conduit.crafter,"dst","basic_materials:empty_spool"),
  wood_src_sticks=count(wood.crafter,"src","mcl_core:stick"),
  wood_dst_sticks=count(wood.crafter,"dst","mcl_core:stick")})
end
local function initial()
 for x=-1,7 do for z=-1,10 do
  core.set_node(p(x,z)-vector.new(0,1,0),{name="mcl_core:stone"})
  for y=0,2 do core.set_node(p(x,z)+vector.new(0,y,0),{name="air"}) end
 end end
 conduit=line(0,"elepower_dynamics:conduit")
 wood=line(8,"mcl_core:stick")
 local ingredients={}
 for _,stack in ipairs(inv(conduit.crafter):get_list("recipe")) do
  ingredients[stack:get_name()]=(ingredients[stack:get_name()] or 0)+stack:get_count()
 end
 eq(ingredients["elepower_dynamics:lead_ingot"],6,"Stock conduit pattern uses six lead")
 eq(ingredients["basic_materials:copper_wire"],3,"Stock conduit pattern uses three wires")
 eq(inv(conduit.crafter):get_stack("output",1):get_count(),8,"Stock conduit batch yields eight")
 -- A full destination tests the machine's own transaction preflight. It must
 -- also reserve room for all three empty-spool byproducts before committing.
 for index=1,inv(conduit.crafter):get_size("dst") do
  inv(conduit.crafter):set_stack("dst",index,"mcl_core:cobble 64")
 end
 supply(conduit,{"elepower_dynamics:lead_ingot 6","basic_materials:copper_wire 3"})
 enabled(conduit.crafter,true)
 local stage="feeding";local since=core.get_us_time();local started=since;local before
 local function poll()
  if done then return end
  checked(function()
   local now=core.get_us_time()
   if stage=="feeding" and empty_source(conduit) and
    count(conduit.crafter,"src","elepower_dynamics:lead_ingot")==6 and count(conduit.crafter,"src","basic_materials:copper_wire")==3 then
    before=signature(conduit.crafter);stage="full";since=now
   elseif stage=="full" and now-since>3500000 then
    eq(signature(conduit.crafter),before,"Full output does not consume inputs or partially add outputs")
    drawer(conduit.drawer,"",0)
    local removed=inv(conduit.crafter):get_stack("dst",1)
    inv(conduit.crafter):set_stack("dst",1,"")
    def(conduit.crafter).on_metadata_inventory_take(conduit.crafter,"dst",1,removed,actor)
    before=signature(conduit.crafter);stage="one_slot";since=now
   elseif stage=="one_slot" and now-since>3500000 then
    eq(signature(conduit.crafter),before,"One free slot cannot discard empty-spool byproducts")
    expect_inputs(conduit,6,3);drawer(conduit.drawer,"",0)
    local removed=inv(conduit.crafter):get_stack("dst",2)
    inv(conduit.crafter):set_stack("dst",2,"")
    def(conduit.crafter).on_metadata_inventory_take(conduit.crafter,"dst",2,removed,actor)
    stage="recovery";since=now
   elseif stage=="recovery" and drawers.drawer_get_content(conduit.drawer,"").count==8 then
    drawer(conduit.drawer,"elepower_dynamics:conduit",8);expect_inputs(conduit,0,0)
    eq(count(conduit.crafter,"dst","basic_materials:empty_spool"),3,"All three empty spools survive crafting and filtered extraction")
    eq(count(conduit.crafter,"dst","mcl_core:cobble"),640,"Unrelated output stacks are unchanged")
    enabled(conduit.crafter,false)
    supply(conduit,{"elepower_dynamics:lead_ingot 6","basic_materials:copper_wire 3"})
    stage="restart_feed";since=now
   elseif stage=="restart_feed" and empty_source(conduit) and count(conduit.crafter,"src","elepower_dynamics:lead_ingot")==6 and count(conduit.crafter,"src","basic_materials:copper_wire")==3 then
    expect_inputs(conduit,6,3);drawer(conduit.drawer,"elepower_dynamics:conduit",8)
    drawer(wood.drawer,"",0)
    assert_no_loose_items()
    state:set_string("snapshot",core.serialize(snapshot()))
    state:set_string("phase","resume")
    finish(true,"CHECKPOINT: native input injectors/tubes supply 6 lead + 3 wire; full output and one free slot preserve every input; two slots recover to 8 drawer conduits + 3 empty spools; second batch saved while disabled for process restart")
   end
   if not done then
    assert(now-started<60000000,"Automation checkpoint timeout at "..stage..": "..signature(conduit.crafter))
    core.after(0.2,poll)
   end
  end)
 end
 core.after(0.2,poll)
end
local function resume()
 eq(state:get_string("phase"),"resume","Checkpoint exists")
 assert_snapshot(assert(core.deserialize(state:get_string("snapshot")),"Saved snapshot"))
 expect_inputs(conduit,6,3);drawer(conduit.drawer,"elepower_dynamics:conduit",8)
 eq(count(conduit.crafter,"dst","basic_materials:empty_spool"),3,"Saved replacement count")
 local groups=0
 for _,stack in ipairs(inv(wood.crafter):get_list("recipe")) do
  if stack:get_meta():get_string("group")=="group:wood" then groups=groups+1 end
 end
 eq(groups,2,"Native stick recipe uses two interchangeable wood ingredients")
 enabled(conduit.crafter,true)
 enabled(wood.crafter,true)
 local actual_wood=ItemStack("mcl_core:acaciawood"):get_name()
 assert(core.get_item_group(actual_wood,"wood")>0,"Alternate Mineclonia wood belongs to group:wood")
 supply(wood,{actual_wood.." 2"})
 local started=core.get_us_time();local stable;local observed=false
 local function poll()
  if done then return end
  checked(function()
   local now=core.get_us_time()
   if not observed and now-started>15000000 then
    observed=true;core.log("action","Automation resumed material counts: "..diagnostic())
   end
   if drawers.drawer_get_content(conduit.drawer,"").count==16 and drawers.drawer_get_content(wood.drawer,"").count==4 then
    drawer(conduit.drawer,"elepower_dynamics:conduit",16);drawer(wood.drawer,"mcl_core:stick",4)
    expect_inputs(conduit,0,0)
    assert(empty_source(conduit) and empty_source(wood),"Both input barrels fully extracted")
    assert(inv(wood.crafter):is_empty("src") and inv(wood.crafter):is_empty("dst"),"Group wood input and crafted sticks fully routed")
    eq(count(conduit.crafter,"dst","elepower_dynamics:conduit"),0,"All conduit products routed to storage")
    eq(count(conduit.crafter,"dst","basic_materials:empty_spool"),6,"Two crafts retain all six empty spools")
    eq(count(conduit.crafter,"dst","mcl_core:cobble"),640,"Restart and resumed craft preserve unrelated stacks")
    if not stable then stable=now end
    if now-stable>3500000 then
     assert_no_loose_items()
     state:set_string("phase","complete")
     finish(true,"COMPLETE: process restart preserves physical inputs, recipe and drawer contents; native timers craft second conduit batch; real blinking controls, injectors and tubes deliver all 16 conduits and 4 group-wood sticks to drawers; all 6 empty spools retained with no duplicate production after inputs exhaust")
    end
   end
   if not done then
    assert(now-started<45000000,"Resumed automation timeout: "..diagnostic())
    core.after(0.2,poll)
   end
  end)
 end
 core.after(0.2,poll)
end
-- Place machines after initial block activation, as a real player would. If
-- ghost filters are created in an inactive fresh block, Pipeworks' historical
-- real-inventory conversion LBM can mistake their examples for legacy items.
local started_run=false
local marker=p(8,11)
core.register_node("era_automation_smoke:activation_marker",{description="Test activation marker",drawtype="airlike",
 walkable=false,pointable=false,groups={not_in_creative_inventory=1}})
core.register_lbm({name="era_automation_smoke:await_activation",nodenames={"era_automation_smoke:activation_marker"},
 run_at_every_load=true,action=function()
  if started_run then return end
  started_run=true
  core.after(0,function() checked(function()
   if state:get_string("phase")=="resume" then resume() else initial() end
  end) end)
 end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-2,-2)-vector.new(0,3,0),p(8,12)+vector.new(0,5,0),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-2,-2)-vector.new(0,3,0),p(8,12)+vector.new(0,5,0))
    if core.get_node(marker).name~="era_automation_smoke:activation_marker" then
     place(marker,"era_automation_smoke:activation_marker")
    end
    for _,x in ipairs({-1,0}) do for _,z in ipairs({-1,0}) do
     assert(core.forceload_block(p(x,z),true),"Activate fixture machines and drawer visuals crossing block edges")
    end end
    core.after(12,function() checked(function() assert(started_run,"Test marker's native block activation never ran") end) end)
   end) end) end
  end)
 end)
end)
