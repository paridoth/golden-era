-- SPDX-License-Identifier: GPL-3.0-or-later
-- A real persisted job must retain old semantics across configuration changes.
return function(phase,storage,pos,place,eq)
 local name="era_thermal:pulverizer"
 local meta=core.get_meta(pos)
 local inv=meta:get_inventory()
 local function state(energy,work)
  eq(era.state(pos).energy,energy,"recipe fixture energy")
  eq(era.state(pos).work,work,"recipe fixture work")
 end
 local function job(cost,rate,count)
  local pending=assert(core.deserialize(meta:get_string("job")),"pending job missing")
  eq(pending.input,era.mcl.raw_iron,"reserved raw iron")
  eq(pending.cost,cost,"reserved cost")
  eq(pending.rate,rate,"reserved rate")
  eq(pending.output,"era_materials:iron_dust "..count,"reserved output")
 end
 if phase=="recipe_seed" then
  eq(era.rates.pulverizer_cost,4000,"initial cost")
  eq(era.rates.process_rate,40,"initial rate")
  eq(era.rates.ore_multiplier,2,"initial yield")
  place(pos,name)
  inv:set_stack("src",1,era.mcl.raw_iron.." 2")
  era.save(pos,{energy=8000,work=0,burn=0})
  for _=1,7 do era.step() end
  state(7720,280); job(4000,40,2)
  eq(inv:get_stack("src",1):get_count(),2,"input remains reserved")
  assert(inv:is_empty("dst"),"unfinished recipe emitted output")
  storage:set_string("recipe_job",meta:get_string("job"))
  core.log("action","ERA INTEGRATION RECIPE_SEED PASS: raw-iron job saved at 280/4000 RF, 40 RF/tick, two-dust yield")
 elseif phase=="recipe_resume" then
  eq(era.rates.pulverizer_cost,900,"changed cost loaded")
  eq(era.rates.process_rate,75,"changed rate loaded")
  eq(era.rates.ore_multiplier,3,"changed yield loaded")
  state(7720,280); job(4000,40,2)
  eq(meta:get_string("job"),storage:get_string("recipe_job"),"exact saved job after restart")
  eq(inv:get_stack("src",1):get_count(),2,"reserved inputs after restart")
  assert(inv:is_empty("dst"),"saved output must be empty")
  era.track(pos)
  local player={get_player_name=function() return "integration" end}
  eq(core.registered_nodes[name].allow_metadata_inventory_take(pos,"src",1,inv:get_stack("src",1),player),0,"resumed job locks input")
  -- Overflow must preserve the old job, including its already-spent RF.
  inv:set_stack("dst",1,"era_materials:iron_dust 98")
  era.step(); state(7720,280); job(4000,40,2)
  eq(inv:get_stack("src",1):get_count(),2,"blocked job preserves input")
  eq(inv:get_stack("dst",1):get_count(),98,"blocked job preserves output")
  inv:set_stack("dst",1,"")
  era.step(); state(7680,320); job(4000,40,2)
  -- The old recipe takes exactly 100 ticks total, despite the cheaper new one.
  for _=1,91 do era.step() end
  state(4040,3960)
  eq(inv:get_stack("src",1):get_count(),2,"no early old-job completion")
  assert(inv:is_empty("dst"),"old job output before full cost")
  era.step(); state(4000,0)
  eq(inv:get_stack("src",1):get_count(),1,"old job consumes one input")
  eq(inv:get_stack("dst",1):get_count(),2,"old job retains two-dust yield")
  eq(meta:get_string("job"),"","completed old job cleared")
  -- The very next input must use all three changed settings.
  era.step(); state(3925,75); job(900,75,3)
  for _=1,10 do era.step() end
  state(3175,825)
  eq(inv:get_stack("src",1):get_count(),1,"new input still reserved")
  eq(inv:get_stack("dst",1):get_count(),2,"no early new-job completion")
  era.step(); state(3100,0)
  assert(inv:is_empty("src"),"new recipe input not consumed")
  eq(inv:get_stack("dst",1):get_name(),"era_materials:iron_dust","result identity")
  eq(inv:get_stack("dst",1):get_count(),5,"old plus new yields")
  eq(meta:get_string("job"),"","completed new job cleared")
  for _=1,20 do era.step() end
  state(3100,0)
  eq(inv:get_stack("dst",1):get_count(),5,"no duplicate completed recipes")
  core.log("action","ERA INTEGRATION RECIPE_RESUME PASS: saved 4000/40/x2 job unchanged; next job uses 900/75/x3; overflow and locks preserve state")
 elseif phase=="recipe_verify" then
  -- Return to defaults for a second restart after both jobs have completed.
  eq(era.rates.pulverizer_cost,4000,"default cost restored")
  state(3100,0)
  assert(inv:is_empty("src"),"consumed inputs reappeared on restart")
  eq(inv:get_stack("dst",1):get_count(),5,"five dust persisted")
  eq(inv:get_stack("dst",1):get_name(),"era_materials:iron_dust","persisted output identity")
  eq(meta:get_string("job"),"","cleared job persisted")
  era.track(pos)
  for _=1,100 do era.step() end
  state(3100,0)
  eq(inv:get_stack("dst",1):get_count(),5,"no duplication after second restart")
  core.log("action","ERA INTEGRATION RECIPE_VERIFY PASS: changed/default settings restart preserved five dust and 3100 RF without duplication")
 else
  error("Unknown recipe phase: "..tostring(phase))
 end
end
