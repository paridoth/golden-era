-- SPDX-License-Identifier: GPL-3.0-or-later
-- New-world schema 2 plus genuine schema-1 migration and SQLite restart.
return function(phase,storage,place,eq)
 local function p(x,z) return vector.new(x,200,z or 2) end
 local positions={generator=p(4),buffer=p(5),cable=p(4,1),pulverizer=p(4,0),furnace=p(5,0),ejector=p(6,0),chest=p(7,0)}
 local player={get_player_name=function() return "integration" end}
 local function inv(pos) return core.get_meta(pos):get_inventory() end
 local function snapshot(pos)
  local v=core.get_meta(pos):to_table()
  for _,key in ipairs({"fault","infotext","formspec"}) do v.fields[key]=nil end
  for _,list in pairs(v.inventory) do for i,stack in ipairs(list) do list[i]=ItemStack(stack):to_string() end end
  return v
 end
 local function same(a,b,path)
  path=path or "native snapshot"
  eq(type(a),type(b),path)
  if type(a)~="table" then eq(a,b,path); return end
  for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
  for k in pairs(b) do assert(a[k]~=nil,path.." gained "..tostring(k)) end
 end
 local function all()
  local result={}
  for name,pos in pairs(positions) do result[name]=snapshot(pos) end
  return result
 end
 local function legacy(pos,name,s,job)
  place(pos,name)
  local m=core.get_meta(pos)
  for _,key in ipairs({"profile","water","fuel_rf","water_rf"}) do m:set_string(key,"") end
  m:set_int("schema",1)
  for _,key in ipairs({"energy","work","burn"}) do m:set_int(key,s[key]) end
  for _,list in ipairs({"water","empty"}) do inv(pos):set_size(list,0) end
  m:set_string("job",job or "")
 end
 if phase=="native_seed" then
  for name,pos in pairs(positions) do
   local id=name=="cable" and "era_energy:cable" or name=="ejector" and "era_transport:ejector" or name=="chest" and "mcl_chests:chest_small" or "era_thermal:"..name
   place(pos,id)
  end
  local gen=positions.generator; local g=inv(gen)
  eq(era.state(gen).profile,"revelation","new machine profile")
  eq(era.state(gen).schema,2,"new state schema")
  eq(era.capacity(gen,era.machines["era_thermal:generator"]),40000,"new generator capacity")
  g:set_stack("fuel",1,era.mcl.coal)
  era.step()
  eq(g:get_stack("fuel",1):get_count(),1,"dry dynamo preserves coal")
  g:set_stack("water",1,era.mcl.water_bucket); g:set_stack("empty",1,era.mcl.ingot)
  era.step()
  eq(g:get_stack("water",1):get_count(),1,"blocked empty-bucket output preserves water bucket")
  eq(g:get_stack("fuel",1):get_count(),1,"blocked water loading preserves fuel")
  g:set_stack("empty",1,"")
  local full_tank=era.state(gen); full_tank.water=4000
  assert(not era.load_water(gen,full_tank),"full tank rejects extra bucket")
  eq(g:get_stack("water",1):get_count(),1,"full tank preserves bucket")
  local node=core.registered_nodes["era_thermal:generator"]
  eq(node.allow_metadata_inventory_put(gen,"water",1,ItemStack(era.mcl.water_bucket),player),1,"water bucket accepted")
  eq(node.allow_metadata_inventory_put(gen,"water",1,ItemStack(era.mcl.coal),player),0,"non-water bucket rejected")
  eq(node.allow_metadata_inventory_put(gen,"empty",1,ItemStack(era.mcl.empty_bucket),player),0,"empty bucket output insertion denied")
  inv(positions.pulverizer):set_stack("src",1,era.mcl.ore.." 2")
  for i=1,101 do era.step() end
  eq(era.state(gen).water,900,"one bucket, one water-credit batch")
  eq(g:get_stack("empty",1):get_name(),era.mcl.empty_bucket,"empty bucket returned")
  eq(g:get_stack("empty",1):get_count(),1,"bucket consumed exactly once")
  assert(era.state(positions.pulverizer).work>0,"native partial job required")
  local job=assert(core.deserialize(core.get_meta(positions.pulverizer):get_string("job"),true))
  eq(job.schema,3,"new job schema"); eq(job.rate_mode,"buffer","saved dynamic rate mode")
  eq(job.cost,4000,"sourced ore cost")
  -- A started legacy burn is never reinterpreted as native RF or given free water.
  local old=p(10)
  legacy(old,"era_thermal:generator",{energy=1234,work=0,burn=7})
  inv(old):set_stack("fuel",1,era.mcl.coal.." 2")
  assert(era.machine_ready(old,"era_thermal:generator"))
  eq(era.state(old).profile,"legacy","old burn profile preserved")
  eq(era.state(old).burn,7,"old burn counter preserved")
  assert(not era.upgrade(old,"era_thermal:generator",player),"burning machine upgrade must wait")
  for i=1,7 do era.step() end
  eq(era.state(old).energy,1374,"old burn produces its original 7*20 RF")
  eq(era.state(old).burn,0,"old burn completed")
  local old_protected=core.is_protected; core.is_protected=function() return true end
  assert(not era.upgrade(old,"era_thermal:generator",player),"protected upgrade denied")
  core.is_protected=old_protected
  core.registered_nodes["era_thermal:generator"].on_receive_fields(old,"",{upgrade=true},player)
  eq(era.state(old).profile,"revelation","upgrade callback switches idle machine")
  eq(era.state(old).energy,1374,"upgrade retains stored RF")
  eq(inv(old):get_stack("fuel",1):get_count(),2,"unlit coal retained")
  era.step(); eq(era.state(old).energy,1374,"upgraded dry dynamo cannot generate")
  eq(era.state(old).fuel_rf,0,"migration/upgrade grants no native fuel credit")
  local proc=p(12)
  local encoded=core.serialize({input=era.mcl.raw_iron,output="era_materials:iron_dust 2",cost=4000,rate=40})
  legacy(proc,"era_thermal:pulverizer",{energy=1000,work=3960,burn=0},encoded)
  inv(proc):set_stack("src",1,era.mcl.raw_iron)
  assert(era.machine_ready(proc,"era_thermal:pulverizer"))
  eq(core.get_meta(proc):get_string("job"),encoded,"migration leaves legacy job bytes intact")
  assert(not era.upgrade(proc,"era_thermal:pulverizer",player),"pending job upgrade denied")
  era.step(); eq(era.state(proc).energy,960,"legacy saved job spends original 40 RF")
  eq(inv(proc):get_stack("dst",1):get_count(),2,"legacy yield preserved")
  assert(era.upgrade(proc,"era_thermal:pulverizer",player))
  inv(proc):set_stack("src",1,era.mcl.raw_iron)
  era.step(); eq(era.state(proc).work,2,"next job uses native low-buffer rate")
  eq(era.state(proc).energy,958,"next job debits exact native rate")
  storage:set_string("native_snapshot",core.serialize(all()))
  storage:set_string("native_migrated",core.serialize({generator=snapshot(old),processor=snapshot(proc)}))
  core.log("action","ERA INTEGRATION NATIVE_SEED PASS: native water/fuel job saved; blocked bucket preserves inputs; schema-1 burn/job preserved; protected/busy upgrades denied; idle upgrade retains RF/items")
 elseif phase=="native_resume" then
  same(assert(core.deserialize(storage:get_string("native_snapshot"),true)),all(),"native SQLite restart")
  local migrated=assert(core.deserialize(storage:get_string("native_migrated"),true))
  same(migrated.generator,snapshot(p(10)),"migrated generator restart")
  same(migrated.processor,snapshot(p(12)),"migrated processor restart")
  for _,pos in pairs(positions) do era.track(pos) end
  for i=1,6000 do era.step() end
  eq(inv(positions.chest):get_stack("main",1):get_count(),4,"native iron primary output")
  local total=0
  for _,name in ipairs({"generator","buffer","pulverizer","furnace"}) do local s=era.state(positions[name]); total=total+s.energy+s.work end
  eq(total+14000,24000,"coal equals stored RF plus 2*4000 + 4*1500 RF")
  eq(era.state(positions.generator).fuel_rf,0,"coal fuel exhausted exactly")
  eq(era.state(positions.generator).water_rf,1000,"unused water credit persists")
  eq(era.state(positions.generator).water,900,"unconverted water retained")
  eq(inv(positions.generator):get_stack("empty",1):get_count(),1,"restart did not duplicate empty bucket")
  local c,b=p(14),p(15)
  place(c,"era_thermal:generator"); place(b,"era_thermal:buffer")
  local s=era.state(c); s.water=100; era.save(c,s)
  inv(c):set_stack("fuel",1,era.mcl.charcoal)
  for i=1,400 do era.step() end
  eq(era.state(b).energy,16000,"charcoal is distinct from coal")
  eq(era.state(c).water_rf,9000,"charcoal leaves exact water credit")
  local full=p(18)
  place(full,"era_thermal:generator")
  s=era.state(full); s.energy=40000; s.fuel_rf=4; s.water_rf=4; era.save(full,s)
  era.step(); eq(era.state(full).energy,40000,"full buffer stays capped")
  eq(era.state(full).fuel_rf,0,"full-buffer minimum generation consumes fuel")
  local debt=p(20)
  place(debt,"era_thermal:generator")
  s=era.state(debt); s.fuel_rf=1; s.water_rf=1; era.save(debt,s)
  era.step(); eq(era.state(debt).fuel_rf,-39,"fuel overshoot saved")
  eq(era.state(debt).water_rf,-39,"water overshoot saved")
  storage:set_string("native_finished",core.serialize(all()))
  storage:set_string("native_debt",core.serialize(snapshot(debt)))
  core.log("action","ERA INTEGRATION NATIVE_RESUME PASS: native SQLite continuation; four ingots cost 14000 of 24000 RF; charcoal 16000 RF; water credit, full-buffer loss and signed debt saved")
 elseif phase=="native_verify" then
  same(assert(core.deserialize(storage:get_string("native_finished"),true)),all(),"completed native restart")
  same(assert(core.deserialize(storage:get_string("native_debt"),true)),snapshot(p(20)),"negative credits survive restart")
  local debt=p(20); local s=era.state(debt); s.water=100; era.save(debt,s)
  inv(debt):set_stack("fuel",1,era.mcl.coal); era.track(debt); era.step()
  eq(era.state(debt).fuel_rf,23921,"fuel debt carried into next coal")
  eq(era.state(debt).water_rf,24921,"water debt carried into next batch")
  local bad=p(22,3); local name="era_thermal:generator"
  local cases={{"schema","3"},{"profile","future"},{"water",""},{"water","4001"},{"water","-1"},{"water","1.5"},{"fuel_rf","-40"},{"fuel_rf","24001"},{"water_rf","25001"},{"burn","1"},{"energy","40001"}}
  for _,case in ipairs(cases) do
   place(bad,name); local m=core.get_meta(bad)
   m:set_string(case[1],case[2]); local before=snapshot(bad)
   era.step(); same(before,snapshot(bad),"invalid schema-2 field "..case[1])
   assert(m:get_string("fault")~="","invalid schema-2 state must pause")
   eq(core.registered_nodes[name].allow_metadata_inventory_put(bad,"water",1,ItemStack(era.mcl.water_bucket),player),0,"paused water insertion denied")
  end
  local proc=p(21,3)
  for _,mode in ipairs({"future","buffer"}) do
   place(proc,"era_thermal:pulverizer")
   local m=core.get_meta(proc); local state=era.state(proc); state.work=1; era.save(proc,state)
   inv(proc):set_stack("src",1,era.mcl.ore)
   local job={input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=20,schema=2,rate_mode=mode}
   if mode=="buffer" then job.unrecognized=true end
   m:set_string("job",core.serialize(job)); local before=snapshot(proc)
   era.step(); same(before,snapshot(proc),"invalid native job mode/fields")
   assert(m:get_string("fault")~="","invalid native job must pause")
  end
  local donor,target=p(8,3),p(9,3)
  legacy(donor,"era_thermal:generator",{energy=500,work=0,burn=0})
  place(target,"era_thermal:buffer")
  era.step()
  eq(era.state(donor).energy,420,"mixed graph retains legacy donor pair limit")
  eq(era.state(target).energy,80,"native buffer cannot overdraw legacy donor")
  core.log("action","ERA INTEGRATION NATIVE_VERIFY PASS: second restart preserves outputs and signed credits; next batches carry debt; 11 malformed native states and two malformed native jobs pause without mutation")
 else error("Unknown native phase") end
 core.request_shutdown("Native model phase passed",false,0)
end
