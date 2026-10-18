-- SPDX-License-Identifier: GPL-3.0-or-later
return function(phase,storage,place,eq)
 local function p(x,z,y) return vector.new(x,y or 200,z or 8) end
 local player={get_player_name=function() return "integration" end}
 local function inv(pos) return core.get_meta(pos):get_inventory() end
 local function fields(pos,value) core.registered_nodes[core.get_node(pos).name].on_receive_fields(pos,"",value,player) end
 local source,target,ejector=p(14),p(15),p(20,8,201)
 local function snapshot(pos)
  local v=core.get_meta(pos):to_table()
  for _,key in ipairs({"fault","formspec","infotext"}) do v.fields[key]=nil end
  for _,list in pairs(v.inventory) do for i,stack in ipairs(list) do list[i]=ItemStack(stack):to_string() end end
  return v
 end
 local function same(a,b,path)
  path=path or "item sides"; eq(type(a),type(b),path)
  if type(a)~="table" then eq(a,b,path); return end
  for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
  for k in pairs(b) do assert(a[k]~=nil,path.." gained "..tostring(k)) end
 end
 if phase=="sides_seed" then
  local pos=p(10); place(pos,"era_thermal:pulverizer")
  local m=core.get_meta(pos)
  eq(m:get_string("item_ports"),"312022","source default face modes")
  assert(not era.configure_side(pos,3,1,player),"front panel must stay closed")
  local old=core.is_protected; core.is_protected=function() return true end
  local encoded=m:get_string("item_ports")
  assert(not era.configure_side(pos,5,3,player)); fields(pos,{side_4=true,rotate_panel=true})
  eq(m:get_string("item_ports"),encoded,"protected side changes denied")
  core.is_protected=old
  local expected={{false,false,false,false},{true,false,false,false},{false,false,true,false},{false,false,false,true},{false,false,true,true},{true,true,true,true},{true,false,true,true}}
  for mode=0,6 do
   assert(era.configure_side(pos,2,mode,player))
   local checks={era.port_allows(pos,2,"src",true),era.port_allows(pos,2,"src",false),era.port_allows(pos,2,"dst",false),era.port_allows(pos,2,"secondary",false)}
   for i,v in ipairs(expected[mode+1]) do eq(checks[i],v,"mode access "..mode.."."..i) end
  end
  place(p(11),"mcl_chests:chest_small"); place(p(10,8,199),"mcl_chests:chest_small")
  inv(pos):set_stack("dst",1,"era_materials:iron_dust 2"); inv(pos):set_stack("secondary",1,"era_materials:nickel_dust")
  era.transport_step()
  eq(inv(p(11)):get_stack("main",1):get_count(),1,"east primary output")
  eq(inv(p(10,8,199)):get_stack("main",1):get_name(),"era_materials:nickel_dust","downward secondary output")
  place(source,"era_thermal:pulverizer"); place(target,"era_thermal:furnace")
  inv(source):set_stack("dst",1,"era_materials:iron_dust 2")
  assert(not era.move_one(source,"dst",target,"src","integration"),"default furnace output face cannot accept input")
  assert(era.configure_side(target,4,1,player)); assert(era.move_one(source,"dst",target,"src","integration"))
  fields(source,{auto_output=true})
  era.transport_step(); eq(inv(target):get_stack("src",1):get_count(),1,"disabled automatic output")
  local s=era.state(source); s.energy=1234; era.save(source,s)
  fields(source,{rotate_panel=true})
  eq(core.get_meta(source):get_int("item_front"),4,"rotated panel faces west")
  eq(era.state(source).energy,1234,"rotation preserves RF")
  eq(inv(source):get_stack("dst",1):get_count(),1,"rotation preserves output")
  assert(era.configure_side(source,2,5,player))
  place(p(14,7),"mcl_chests:chest_small")
  inv(source):set_stack("src",1,era.mcl.ore)
  s=era.state(source); s.work=1; era.save(source,s)
  core.get_meta(source):set_string("job",core.serialize({input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=20,schema=2,rate_mode="buffer"}))
  assert(not era.move_one(source,"src",p(14,7),"main","integration"),"all-slot side cannot extract reserved input")
  s=era.state(source); s.work=0; era.save(source,s); core.get_meta(source):set_string("job","")
  assert(era.move_one(source,"src",p(14,7),"main","integration"),"all-slot side can extract idle input")
  place(p(20),"era_thermal:pulverizer"); place(ejector,"era_transport:ejector"); place(p(20,8,202),"mcl_chests:chest_small")
  assert(era.configure_side(p(20),1,3,player))
  inv(p(20)):set_stack("secondary",1,"era_materials:nickel_dust")
  fields(ejector,{direction=true}); fields(ejector,{direction=true}); fields(ejector,{output=true})
  eq(core.get_meta(ejector):get_int("eject_face"),1,"ejector points up")
  core.is_protected=function() return true end
  era.transport_step(); eq(inv(p(20)):get_stack("secondary",1):get_count(),1,"protected secondary transfer denied")
  fields(ejector,{direction=true}); eq(core.get_meta(ejector):get_int("eject_face"),1,"protected ejector control denied")
  core.is_protected=old
  era.transport_step(); eq(inv(p(20,8,202)):get_stack("main",1):get_count(),1,"vertical byproduct extraction")
  storage:set_string("sides_snapshot",core.serialize({source=snapshot(source),target=snapshot(target),ejector=snapshot(ejector)}))
  core.log("action","ERA INTEGRATION SIDES_SEED PASS: seven source mode groups, panel/protection, split primary/byproduct outputs, configured furnace input, disabled auto-output, reserved-input lock and vertical ejector")
 elseif phase=="sides_resume" then
  local saved=assert(core.deserialize(storage:get_string("sides_snapshot"),true))
  same(saved.source,snapshot(source)); same(saved.target,snapshot(target)); same(saved.ejector,snapshot(ejector))
  inv(p(20)):set_stack("secondary",1,"era_materials:nickel_dust"); era.track(ejector); era.transport_step()
  eq(inv(p(20,8,202)):get_stack("main",1):get_count(),2,"saved vertical byproduct selection continues")
  local a,b=p(0,9),p(1,9)
  place(a,"era_thermal:pulverizer"); place(b,"era_thermal:furnace")
  for _,pos in ipairs({a,b}) do for _,key in ipairs({"item_ports_version","item_ports","item_front"}) do core.get_meta(pos):set_string(key,"") end end
  inv(a):set_stack("dst",1,"era_materials:iron_dust")
  assert(era.move_one(a,"dst",b,"src","integration"),"existing schema-2 layout keeps old routing")
  fields(b,{enable_ports=true}); inv(a):set_stack("dst",1,"era_materials:iron_dust")
  assert(not era.move_one(a,"dst",b,"src","integration"),"opt-in enables source face rules")
  assert(era.configure_side(b,4,1,player)); assert(era.move_one(a,"dst",b,"src","integration"))
  local bad=p(24)
  for _,pair in ipairs({{"item_ports","999999"},{"item_ports","123"},{"item_ports_version","2"},{"item_front","6"},{"item_ports","312222"},{"auto_output","yes"}}) do
   place(bad,"era_thermal:pulverizer"); local m=core.get_meta(bad); m:set_string(pair[1],pair[2]); local before=snapshot(bad)
   era.process(bad,"era_thermal:pulverizer",era.state(bad)); fields(bad,{side_1=true}); same(before,snapshot(bad),"malformed port state")
   assert(m:get_string("fault")~="","malformed ports pause")
  end
  core.log("action","ERA INTEGRATION SIDES_RESUME PASS: side/rotation/toggle/ejector state survives SQLite; older layouts retain routing until explicit opt-in; six malformed port records pause")
 else error("Unknown sides phase") end
 core.request_shutdown("Side control test passed",false,0)
end
