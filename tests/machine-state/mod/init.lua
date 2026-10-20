-- SPDX-License-Identifier: GPL-3.0-or-later
-- Actual registered fields callbacks and normal timer refreshes, plus explicit
-- stock registration-API controls. Baseline PASS means the known bug reproduced.
local baseline=core.settings:get_bool("era_state_baseline",false)
local storage=core.get_mod_storage()
local done=false
local function eq(a,b,label)assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function p(x)return vector.new(x,200,0) end
local function finish(ok,message)
 if done then return end;done=true
 core.log(ok and "action" or "error","ERA MACHINE STATE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Machine state regression finished",false,0)
end
local function checked(f)
 local ok,err=xpcall(f,debug.traceback);if not ok then finish(false,err) end
end
local actor={get_player_name=function()return "era_machine_state" end}
local names={"elepower_farming:planter","elepower_farming:harvester","elepower_machines:generator"}
local function click(pos,sender,fields)
 local def=core.registered_nodes[core.get_node(pos).name]
 return assert(def.on_receive_fields)(pos,"",fields or {cyclestate=true},sender or actor)
end
local function label(pos,id)
 local text=core.get_meta(pos):get_string("formspec")
 assert(text:find(ele.default.states[id].d,1,true),"Normal timer refreshed the selected state tooltip")
end
for suffix,groups in pairs({toggle={toggle=true,mesecons=false},signal={toggle=false,mesecons=true},
 empty={toggle=false,mesecons=false}}) do
 ele.register_machine("era_machine_state:"..suffix,{
  description="Disposable state API control",tiles={"default_stone.png"},states=groups,
  on_timer=function()return false end,
  on_receive_fields=function(pos,formname,fields,sender)
   eq(formname,"","Original callback formname");assert(sender,"Original callback sender")
   local meta=core.get_meta(pos);meta:set_int("delegations",meta:get_int("delegations")+1)
  end,
 })
end
local function controls()
 for i,case in ipairs({{name="toggle",initial=0,ids={1,0,1}},
  {name="signal",initial=2,ids={3,2,3}}, {name="toggle",initial=99,ids={0,1}},
  {name="signal",initial=-7,ids={2,3}}, {name="empty",initial=99,ids={99,99}}}) do
  local pos=p(20+i);core.set_node(pos,{name="era_machine_state:"..case.name})
  local meta=core.get_meta(pos);meta:set_int("state",case.initial)
  for _,id in ipairs(case.ids) do
   core.get_node_timer(pos):stop();click(pos);eq(meta:get_int("state"),id,"Subset/unknown-ID control")
   eq(core.get_node_timer(pos):is_started(),case.name~="empty","Timer wakes only for eligible states")
   core.get_node_timer(pos):stop()
  end
  eq(meta:get_int("delegations"),#case.ids,"Original callback receives state presses")
  click(pos,actor,{probe=true});eq(meta:get_int("delegations"),#case.ids+1,"Other fields still delegate")
  local before=meta:to_table();local old=core.is_protected
  core.is_protected=function(target,name)return name=="blocked" or old(target,name) end
  local ok,err=pcall(click,pos,{get_player_name=function()return "blocked" end})
  core.is_protected=old;assert(ok,err)
  eq(meta:get_int("state"),tonumber(before.fields.state),"Protected state unchanged")
  eq(meta:get_int("delegations"),#case.ids+1,"Protected fields do not delegate")
  eq(core.get_node_timer(pos):is_started(),false,"Protected fields do not wake timer")
 end
end
local function observe(id)
 for i in ipairs(names) do
  local pos=p(i*3);local meta=core.get_meta(pos)
  eq(meta:get_int("state"),id,"Actual stock machine selected native ID")
  label(pos,id)
  for _,signal in ipairs({0,1}) do
   meta:set_int("signal_interrupt",signal)
   local expected=id==0 or (id==2 and signal==1) or (id==3 and signal==0)
   eq(ele.helpers.state_enabled(meta,pos),expected,"Native state enable semantics retained")
  end
  meta:set_int("signal_interrupt",0)
 end
end
local function press_all()
 for i in ipairs(names) do
  local pos=p(i*3);click(pos)
  assert(core.get_node_timer(pos):is_started(),"State button wakes the normal machine timer")
 end
end
local function cycle(press)
 checked(function()
  local id=baseline and (press%2==0 and 0 or 2) or press%4
  observe(id)
  if press==3 then
   if not baseline then controls() end
   storage:set_string("phase","checkpoint")
   finish(true,"CHECKPOINT: "..(baseline and "known unreachable-off baseline" or "all states reachable; subsets/protection/delegation").."; native IDs and tooltips saved")
  else
   press_all();core.after(1.3,function()cycle(press+1) end)
  end
 end)
end
local function ready()
 if done then return end
 for _,pos in ipairs({p(3),p(6),p(9),p(24)}) do
  if not core.compare_block_status(pos,"active") then core.after(0.1,ready);return end
 end
 checked(function()
  if storage:get_string("phase")=="checkpoint" then
   observe(baseline and 2 or 3)
   press_all()
   core.after(1.3,function()checked(function()
    observe(0);finish(true,"COMPLETE: native selected IDs/tooltips persisted across real restart and wrap to Always on")
   end) end)
  else
   for i,name in ipairs(names) do
    core.set_node(p(i*3),{name=name})
    eq(core.get_meta(p(i*3)):get_int("state"),0,"Fresh default remains Always on")
    ele.helpers.start_timer(p(i*3))
   end
   core.after(1.3,function()cycle(0) end)
  end
 end)
end
core.register_on_mods_loaded(function()
 core.after(0,function()core.emerge_area(p(0),p(31),function(_,_,remaining)
  if remaining==0 then checked(function()
   for _,pos in ipairs({p(3),p(24)}) do assert(core.forceload_block(pos,true)~=false,"Load disposable state area") end
   core.after(0.1,ready)
  end) end
 end) end)
 core.after(70,function()if not done then finish(false,"Timed out waiting for native callbacks/timers") end end)
end)
