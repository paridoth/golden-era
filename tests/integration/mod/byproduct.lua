-- SPDX-License-Identifier: GPL-3.0-or-later
return function(phase,storage,place,eq)
 local function p(x) return vector.new(x,200,6) end
 local name="era_thermal:pulverizer"
 local slots={win=p(0),lose=p(2),old=p(4)}
 local function inv(pos) return core.get_meta(pos):get_inventory() end
 local function drive(pos,ticks)
  for i=1,ticks do local s=era.state(pos); era.process(pos,name,s); era.save(pos,s) end
 end
 local function snapshot(pos)
  local v=core.get_meta(pos):to_table()
  for _,key in ipairs({"fault","infotext","formspec"}) do v.fields[key]=nil end
  for _,list in pairs(v.inventory) do for i,stack in ipairs(list) do list[i]=ItemStack(stack):to_string() end end
  return v
 end
 local function same(a,b,path)
  path=path or "secondary state"; eq(type(a),type(b),path)
  if type(a)~="table" then eq(a,b,path); return end
  for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
  for k in pairs(b) do assert(a[k]~=nil,path.." gained "..tostring(k)) end
 end
 local function all() local v={}; for key,pos in pairs(slots) do v[key]=snapshot(pos) end; return v end
 local function seed(pos)
  place(pos,name); local s=era.state(pos); s.energy=20000; era.save(pos,s)
  inv(pos):set_stack("src",1,era.mcl.ore)
 end
 local original=era.random_percent
 if phase=="byproduct_seed" then
  seed(slots.win); seed(slots.lose); seed(slots.old)
  local calls=0; local rolls={1,100}
  era.random_percent=function() calls=calls+1; return assert(rolls[calls],"unexpected roll") end
  inv(slots.win):set_stack("secondary",1,"era_materials:nickel_dust 99")
  local before=snapshot(slots.win)
  drive(slots.win,20); same(before,snapshot(slots.win),"blocked before work")
  eq(calls,0,"no roll before output preflight")
  inv(slots.win):set_stack("secondary",1,""); drive(slots.win,1); drive(slots.lose,1)
  eq(calls,2,"one roll per started job")
  for key,pos in pairs(slots) do
   if key~="old" then
    local job=assert(core.deserialize(core.get_meta(pos):get_string("job"),true))
    eq(job.schema,3,"secondary job schema"); eq(job.secondary_chance,10,"source secondary chance")
    eq(job.secondary_roll,key=="win" and 1 or 100,"saved chance result")
    inv(pos):set_stack("secondary",1,"era_materials:nickel_dust 99")
   end
  end
  -- Saved schema-2 jobs get no new byproduct or RNG calls after an upgrade in code.
  local s=era.state(slots.old); s.work=3980; era.save(slots.old,s)
  core.get_meta(slots.old):set_string("job",core.serialize({input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=20,schema=2,rate_mode="buffer"}))
  drive(slots.old,1); eq(calls,2,"old job cannot acquire a new chance")
  eq(inv(slots.old):get_stack("dst",1):get_count(),2,"old primary output")
  assert(inv(slots.old):is_empty("secondary"),"old job gained secondary output")
  storage:set_string("byproduct_snapshot",core.serialize(all()))
  core.log("action","ERA INTEGRATION BYPRODUCT_SEED PASS: preflight blocks RF/RNG; winning/losing decisions saved once; old schema-2 job retains primary-only semantics")
 elseif phase=="byproduct_resume" then
  same(assert(core.deserialize(storage:get_string("byproduct_snapshot"),true)),all(),"secondary SQLite restart")
  era.random_percent=function() error("pending job rerolled") end
  for _,key in ipairs({"win","lose"}) do
   local pos=slots[key]; local before=snapshot(pos)
   drive(pos,20); same(before,snapshot(pos),"blocked saved decision")
   inv(pos):set_stack("secondary",1,""); drive(pos,1000)
   eq(era.state(pos).energy,16000,"exact 4000 RF processing cost")
   eq(inv(pos):get_stack("dst",1):get_count(),2,"primary output count")
   eq(inv(pos):get_stack("secondary",1):get_count(),key=="win" and 1 or 0,"saved secondary outcome")
   local after=snapshot(pos); drive(pos,100); same(after,snapshot(pos),"no completed output duplication")
  end
  storage:set_string("byproduct_finished",core.serialize(all()))
  core.log("action","ERA INTEGRATION BYPRODUCT_RESUME PASS: blocked decisions survive restart without reroll; two primary outputs plus exact saved win/loss; no duplicated RF/items")
 elseif phase=="byproduct_verify" then
  same(assert(core.deserialize(storage:get_string("byproduct_finished"),true)),all(),"completed secondary restart")
  local test=p(6); local wins=0
  -- Exhaustive percentile outcomes, using real recipes/callbacks rather than statistical luck.
  for roll=1,100 do
   seed(test); era.random_percent=function() return roll end; drive(test,1000)
   eq(inv(test):get_stack("dst",1):get_count(),2,"enumerated primary output")
   local count=inv(test):get_stack("secondary",1):get_count()
   eq(count,roll<=10 and 1 or 0,"enumerated chance boundary")
   wins=wins+count
  end
  eq(wins,10,"exact 10 percent threshold")
  local cases={
   {secondary_roll=0},{secondary_roll=101},{secondary_roll=1.5},{secondary_chance=0},{secondary_chance=101},
   {secondary_output="unknown:item"},{secondary_output="era_materials:nickel_dust 100"},{extra=true},
  }
  era.random_percent=function() error("invalid job rerolled") end
  for _,changes in ipairs(cases) do
   seed(test); local s=era.state(test); s.work=20; era.save(test,s)
   local job={input=era.mcl.ore,output="era_materials:iron_dust 2",cost=4000,rate=20,schema=3,rate_mode="buffer",secondary_output="era_materials:nickel_dust",secondary_chance=10,secondary_roll=1}
   for k,v in pairs(changes) do job[k]=v end
   core.get_meta(test):set_string("job",core.serialize(job))
   local before=snapshot(test); era.process(test,name,era.state(test)); same(before,snapshot(test),"malformed secondary decision")
   assert(core.get_meta(test):get_string("fault")~="","invalid decision needs diagnostic")
  end
  core.log("action","ERA INTEGRATION BYPRODUCT_VERIFY PASS: second restart preserves outputs; all 100 percentile outcomes yield ten nickel; eight malformed decisions pause without mutation")
 else error("Unknown byproduct phase") end
 era.random_percent=original
 core.request_shutdown("Byproduct phase passed",false,0)
end
