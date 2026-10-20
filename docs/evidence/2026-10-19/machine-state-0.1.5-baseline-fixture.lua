-- Native configuration callbacks only; normal engine timers refresh formspecs.
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return 'era_state_audit' end}
local data={actor='era_state_audit',devices={},default_iteration={},manual_state_writes=0,manual_timer_calls=0}
local done=false
local function log(s) core.log('action','Machine state audit: '..s) end
local function finish(ok,s)
 if done then return end;done=true
 core.safe_file_write(core.get_worldpath()..'/state-audit.json',core.write_json(data,true))
 core.log(ok and 'action' or 'error','ERA MACHINE STATE AUDIT '..(ok and 'PASS: ' or 'FAIL: ')..s)
 core.request_shutdown('Native machine-state audit',false,0)
end
local function checked(f) local ok,e=xpcall(f,debug.traceback);if not ok then finish(false,e) end end
for id,entry in pairs(ele.default.states) do data.default_iteration[#data.default_iteration+1]={id=id,group=entry.e,label=entry.d} end
-- Two-state API control; bundled real machines have Mesecons support enabled.
elepm.register_fuel_generator('era_state_audit:toggle_generator',{description='Disposable toggle-only API control',
 tiles={'elepower_machine_top.png'},ele_capacity=6400,ele_usage=16,groups={oddly_breakable_by_hand=1},states={toggle=true,mesecons=false}})
local names={'elepower_farming:planter','elepower_farming:harvester','elepower_machines:generator','era_state_audit:toggle_generator'}
local function snapshot(i,press)
 local entry=data.devices[i];local pos=entry.pos;local meta=core.get_meta(pos);local id=meta:get_int('state')
 local formspec=meta:get_string('formspec')
 local label=formspec:match('tooltip%[cyclestate;([^%]]*)%]')
 entry.sequence[#entry.sequence+1]={press=press,state=id,default_label=ele.default.states[id].d,formspec_tooltip=label or 'missing',timer_started=core.get_node_timer(pos):is_started()}
end
local function run()
 for i,name in ipairs(names) do
  local pos=vector.new(i*3,200,0);core.set_node(pos,{name=name})
  assert(not core.is_protected(pos,actor:get_player_name()),'Named configuration actor is allowed by actual native protection')
  local def=assert(core.registered_nodes[name]);assert(def.on_receive_fields,'Registered native configuration callback')
  assert(core.get_meta(pos):get_int('state')==0,'Fresh construct default0 without override')
  data.devices[i]={name=name,pos=pos,supported_groups=def.states,sequence={},api_control=name:match('^era_state_audit:')~=nil}
  snapshot(i,0)
 end
 local press=0
 local function next_press()
  checked(function()
   press=press+1
   if press>8 then
    for _,d in ipairs(data.devices) do log(core.write_json(d)) end
    log('Actual default pairs iteration='..core.write_json(data.default_iteration))
    finish(true,'COMPLETE: actual native cyclestate sequences/tooltips recorded from fresh0; inspect unreachable states, no manufactured state or timer inputs')
    return
   end
   for i,name in ipairs(names) do
    local pos=data.devices[i].pos
    core.registered_nodes[name].on_receive_fields(pos,'',{cyclestate=true},actor)
   end
   -- switch_state schedules stock timers; let the engine refresh formspecs.
   core.after(1.3,function() checked(function()
    for i=1,#names do snapshot(i,press) end
    next_press()
   end) end)
  end)
 end
 next_press()
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(vector.new(0,192,0),vector.new(15,207,15),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(vector.new(0,192,0),vector.new(15,207,15));assert(core.forceload_block(vector.new(0,200,0),true)~=false)
    local began=core.get_us_time()
    local function ready()
     if core.compare_block_status(vector.new(0,200,0),'active') then checked(run)
     else assert(core.get_us_time()-began<15000000,'Bounded activation wait');core.after(0.1,ready) end
    end
    core.after(0.1,ready)
   end) end) end
  end)
 end)
end)
