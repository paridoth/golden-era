-- SPDX-License-Identifier: GPL-3.0-or-later
return function(phase,storage,place,eq)
 local function p(x) return vector.new(x,200,1) end
 local source,bad,healthy=p(23),p(24),p(25)
 local name="era_thermal:pulverizer"
 local function job(changes)
  local value={input=era.mcl.raw_iron,output="era_materials:iron_dust 2",cost=4000,rate=40}
  for key,v in pairs(changes or {}) do value[key]=v end
  return value
 end
 local function snapshot(pos)
  local value=core.get_meta(pos):to_table()
  for _,items in pairs(value.inventory) do
   for index,stack in ipairs(items) do items[index]=ItemStack(stack):to_string() end
  end
  for _,key in ipairs({"fault","formspec","infotext"}) do value.fields[key]=nil end
  return value
 end
 local function same(a,b,path)
  path=path or "saved state"
  eq(type(a),type(b),path.." type")
  if type(a)~="table" then eq(a,b,path); return end
  for key,value in pairs(a) do same(value,b[key],path.."."..tostring(key)) end
  for key in pairs(b) do assert(a[key]~=nil,path.." unexpected key "..tostring(key)) end
 end
 local function setup(energy)
  place(source,"era_thermal:generator"); place(bad,name); place(healthy,"era_thermal:furnace")
  local meta=core.get_meta(bad); local inv=meta:get_inventory()
  inv:set_stack("src",1,era.mcl.raw_iron.." 2")
  inv:set_stack("dst",1,"era_materials:iron_dust 3")
  era.save(bad,{energy=energy or 1000,work=200,burn=0})
  meta:set_string("job",core.serialize(job()))
  local generator=core.get_meta(source):get_inventory()
  generator:set_stack("fuel",1,era.mcl.coal)
  generator:set_stack("dst",1,era.mcl.raw_iron)
  core.get_meta(healthy):get_inventory():set_stack("src",1,"era_materials:iron_dust")
  era.save(healthy,{energy=2000,work=0,burn=0})
  return meta,inv
 end
 local function paused(meta)
  assert(meta:get_string("fault")~="","invalid machine has no diagnostic")
  assert(meta:get_string("infotext"):find("Paused:",1,true),"fault absent from infotext")
  assert(meta:get_string("formspec"):find("Paused:",1,true),"fault absent from formspec")
 end
 local function guarded(callback)
  return function()
   local ok,err=xpcall(callback,debug.traceback)
   if not ok then
    core.log("error","ERA INTEGRATION FAIL: "..err)
    core.request_shutdown("Corrupt-state test failed",false,0)
   end
  end
 end
 if phase=="corrupt_seed" then
  local cases={}
  local function encoded(label,text) cases[#cases+1]={label=label,apply=function(meta) meta:set_string("job",text) end} end
  local function fields(label,changes) encoded(label,core.serialize(job(changes))) end
  local function metadata(label,key,value) cases[#cases+1]={label=label,apply=function(meta) meta:set_string(key,value) end} end
  encoded("missing job","")
  encoded("malformed serialization","not serialized Lua")
  encoded("number job","return 7")
  encoded("boolean job","return true")
  encoded("string job",'return "job"')
  encoded("nil job","return nil")
  encoded("empty table","return {}")
  encoded("missing cost",core.serialize({input=era.mcl.raw_iron,output="era_materials:iron_dust 2",rate=40}))
  encoded("missing output",core.serialize({input=era.mcl.raw_iron,cost=4000,rate=40}))
  encoded("oversized record",string.rep(" ",4097))
  fields("unknown fields",{version=2})
  for _,key in ipairs({"cost","rate"}) do
   for _,entry in ipairs({{"zero",0},{"negative",-1},{"fraction",0.5},{"text","40"},{"infinity",math.huge},{"NaN",0/0},{"overflow",2147483648}}) do
    fields(key.." "..entry[1],{[key]=entry[2]})
   end
  end
  fields("cost equals work",{cost=200})
  fields("cost below work",{cost=100})
  fields("wrong input",{input=era.mcl.coal})
  fields("empty input identity",{input=""})
  fields("output number",{output=2})
  for _,output in ipairs({"","unknown:item 2","era_materials:iron_dust 0","era_materials:iron_dust 1.5","era_materials:iron_dust 100","era_materials:iron_dust 65536","era_materials:iron_dust 2 0"}) do
   fields("bad output "..output,{output=output})
  end
  metadata("stale job at zero work","work","0")
  metadata("future schema","schema","3")
  metadata("missing schema","schema","")
  metadata("negative RF","energy","-1")
  metadata("over-capacity RF","energy","8001")
  metadata("fractional RF","energy","1.5")
  metadata("nonnumeric RF","energy","broken")
  metadata("overflow RF","energy","2147483648")
  metadata("negative work","work","-1")
  metadata("negative burn","burn","-1")
  metadata("burn on processor","burn","1")
  cases[#cases+1]={label="missing reserved inventory",apply=function(meta) meta:get_inventory():set_stack("src",1,"") end}
  local player={get_player_name=function() return "integration" end}
  for _,case in ipairs(cases) do
   local meta,inv=setup()
   case.apply(meta)
   local before=snapshot(bad)
   era.process(bad,name,era.state(bad))
   for _=1,60 do era.step() end
   same(before,snapshot(bad),case.label)
   paused(meta)
   eq(era.move_one(source,"dst",bad,"src","integration"),false,"deny transfer into paused machine")
   eq(era.move_one(bad,"dst",healthy,"src","integration"),false,"deny transfer out of paused machine")
   local def=core.registered_nodes[name]
   for _,list in ipairs({"src","dst","fuel"}) do
    eq(def.allow_metadata_inventory_put(bad,list,1,ItemStack(era.mcl.raw_iron),player),0,"paused player put")
    eq(def.allow_metadata_inventory_take(bad,list,1,inv:get_stack(list,1),player),0,"paused player take")
   end
   eq(def.can_dig(bad,player),false,"paused machine cannot be dug")
   same(before,snapshot(bad),case.label.." after callbacks")
   eq(core.get_meta(source):get_inventory():get_stack("dst",1):get_count(),1,"source item retained")
   assert(era.state(source).burn<1600,"healthy generator stopped")
   local output=core.get_meta(healthy):get_inventory():get_stack("dst",1)
   eq(output:get_name(),era.mcl.ingot,"healthy neighbor continues processing")
   eq(output:get_count(),1,"healthy output count")
   assert(core.get_meta(healthy):get_inventory():is_empty("src"),"paused output leaked to healthy neighbor")
  end
  -- Persist an invalid job for an automatic-scheduler restart and later repair.
  local meta=setup(3800)
  meta:set_string("job","return true")
  core.get_meta(source):get_inventory():set_stack("fuel",1,"")
  storage:set_string("corrupt_snapshot",core.serialize(snapshot(bad)))
  storage:set_int("corrupt_cases",#cases)
  core.log("action","ERA INTEGRATION CORRUPT_SEED PASS: "..#cases.." malformed job/state cases paused without mutation; healthy neighbors continued; corrupt job saved")
  core.request_shutdown("Corrupt-state seed passed",false,0)
 elseif phase=="corrupt_resume" then
  local saved=assert(core.deserialize(storage:get_string("corrupt_snapshot"),true))
  same(saved,snapshot(bad),"corrupt state restart")
  for _,pos in ipairs({source,bad,healthy}) do era.track(pos) end
  core.after(4,guarded(function()
   local meta=core.get_meta(bad)
   same(saved,snapshot(bad),"normal scheduler preserves corrupt state")
   paused(meta)
   eq(core.get_meta(healthy):get_inventory():get_stack("dst",1):get_count(),1,"healthy scheduler output")
   -- Only this explicit test-operator repair changes the saved job.
   meta:set_string("job",core.serialize(job()))
   core.after(6,guarded(function()
    local inv=meta:get_inventory()
    eq(meta:get_string("fault"),"","diagnostic clears after valid repair")
    assert(not meta:get_string("infotext"):find("Paused:",1,true),"stale paused infotext")
    eq(era.state(bad).energy,0,"repaired old job spends exactly 3800 remaining RF")
    eq(era.state(bad).work,0,"repaired job completes")
    eq(inv:get_stack("src",1):get_count(),2,"one input consumed after neighbor refills one")
    assert(core.get_meta(source):get_inventory():is_empty("dst"),"repaired input transport did not resume")
    assert(inv:is_empty("dst"),"repaired output transport did not resume")
    eq(core.get_meta(healthy):get_inventory():get_stack("src",1):get_count(),5,"three existing plus two newly produced dust routed to neighbor")
    eq(core.get_meta(healthy):get_inventory():get_stack("dst",1):get_count(),1,"healthy ingot retained")
    eq(meta:get_string("job"),"","completed repaired job cleared")
    storage:set_string("repaired_snapshot",core.serialize({bad=snapshot(bad),source=snapshot(source),healthy=snapshot(healthy)}))
    core.log("action","ERA INTEGRATION CORRUPT_RESUME PASS: normal scheduler preserved corrupt job, healthy neighbor ran, explicit repair resumed exactly once")
    core.request_shutdown("Corrupt-state resume passed",false,0)
   end))
  end))
 elseif phase=="corrupt_verify" then
  local saved=assert(core.deserialize(storage:get_string("repaired_snapshot"),true))
  local function all() return {bad=snapshot(bad),source=snapshot(source),healthy=snapshot(healthy)} end
  same(saved,all(),"repaired state restart")
  for _,pos in ipairs({source,bad,healthy}) do era.track(pos) end
  for _=1,100 do era.step() end
  same(saved,all(),"repaired state no duplicate after restart")
  eq(core.get_meta(bad):get_string("fault"),"","cleared fault persisted")
  core.log("action","ERA INTEGRATION CORRUPT_VERIFY PASS: repaired balances and outputs persisted without duplication")
  core.request_shutdown("Corrupt-state verification passed",false,0)
 else
  error("Unknown corrupt-state phase: "..tostring(phase))
 end
end
