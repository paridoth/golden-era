-- Native scheduling audit: no manually invoked timers/ABMs or forced nil table.
local state=core.get_mod_storage();local phase=state:get_int('phase')
local data=core.deserialize(state:get_string('data')) or {events={}}
local pos=vector.new(2,200,2);local barrel=vector.new(5,200,2);local anchor=vector.new(48,200,2)
local done=false
local function eq(a,b,s) assert(a==b,s..': '..tostring(a)..' ~= '..tostring(b)) end
local function log(s) core.log('action','Vacuum early audit: '..s) end
local function finish(ok,s)
 if done then return end;done=true
 core.safe_file_write(core.get_worldpath()..'/probe-'..phase..'.json',core.write_json(data,true))
 core.log(ok and 'action' or 'error','ERA VACUUM EARLY AUDIT '..(ok and 'PASS: ' or 'FAIL: ')..s)
 core.request_shutdown('Vacuum early native audit',false,0)
end
local function checked(f) local ok,e=xpcall(f,debug.traceback);if not ok then finish(false,e) end end
local function stamp(name,n,tag,wear) local s=ItemStack(name..' '..n);s:get_meta():set_string('era_vacuum_early',tag);s:set_wear(wear);return s end
local expected={stamp('mcl_copper:copper_ingot',5,'owned copper',321),stamp('mcl_tools:pick_iron',1,'owned tool',4321)}
local function loose()
 local list={};for _,o in ipairs(core.get_objects_inside_radius(pos,8)) do local e=o:get_luaentity()
  if e and e.name=='__builtin:item' and e.itemstring~='' then list[#list+1]=e.itemstring end
 end;return list
end
local function record_fields(list)
 local result={}
 for _,s in ipairs(list) do
  s=ItemStack(s)
  if not s:is_empty() then
   result[#result+1]={item=s:to_string(),name=s:get_name(),count=s:get_count(),wear=s:get_wear(),metadata=s:get_meta():get_string('era_vacuum_early')}
  end
 end;return result
end
local first_step=true
core.register_globalstep(function()
 if first_step then first_step=false;data.first_fixture_globalstep={logical_table_initialized=pipeworks.luaentity.entities~=nil,gametime=core.get_gametime()};log('First fixture globalstep after stock Pipeworks: table='..tostring(pipeworks.luaentity.entities~=nil)) end
end)
for name,d in pairs(core.registered_nodes) do
 if name:match('^pipeworks:sand_tube_') and d.on_timer then
  local native=d.on_timer
  core.override_item(name,{on_timer=function(p,elapsed)
   if not vector.equals(p,pos) then return native(p,elapsed) end
   local e={phase=phase,elapsed=elapsed,gametime=core.get_gametime(),table_initialized=pipeworks.luaentity.entities~=nil,before=record_fields(loose())}
   local result=native(p,elapsed);e.after=record_fields(loose());data.events[#data.events+1]=e
   if #e.before>0 or not e.table_initialized then log('Actual engine timer: '..core.write_json(e)) end
   return result
  end})
 end
end
local function place(p,name) core.set_node(p,{name=name}) end
local function prepare()
 for x=0,7 do for z=0,7 do place(vector.new(x,199,z),'mcl_core:stone') end end
 place(pos,'pipeworks:sand_tube_1');place(vector.new(3,200,2),'pipeworks:tube_1');place(vector.new(4,200,2),'pipeworks:tube_1');place(barrel,'mcl_barrels:barrel_closed')
 for x=2,5 do pipeworks.scan_for_tube_objects(vector.new(x,200,2)) end
 core.after(4,function() checked(function()
  assert(#data.events>0,'Native timer ran before deactivation')
  core.forceload_free_block(pos,true)
  local began=core.get_us_time()
  local function inactive()
   checked(function()
    if not core.compare_block_status(pos,'active') then
     local before={}
     for _,s in ipairs(expected) do local o=assert(core.add_item(vector.offset(pos,0,1,0),s));before[#before+1]={item=o:get_luaentity().itemstring,pos=o:get_pos()} end
     data.created_after_deactivation=before;data.created_gametime=core.get_gametime()
     log('Provided full owned stacks only after native vacuum block became inactive: '..core.write_json(before))
     core.after(6,function() checked(function()
      assert(not core.compare_block_status(pos,'active'),'Vacuum stayed inactive while game time advanced')
      local t=core.get_node_timer(pos);data.checkpoint={gametime=core.get_gametime(),timeout=t:get_timeout(),elapsed=t:get_elapsed(),active=false}
      state:set_int('phase',1);state:set_string('data',core.serialize(data))
      log('Checkpoint pending ordinary timer and inactive block: '..core.write_json(data.checkpoint))
      finish(true,'CHECKPOINT: real stacks saved in an inactive vacuum block with its ordinary timer pending; no timer callback invoked by fixture')
     end) end)
    else assert(core.get_us_time()-began<15000000,'Native block deactivation bounded wait');core.after(0.1,inactive) end
   end)
  end
  inactive()
 end) end)
end
local function resume_check()
 local all={}
 for _,s in ipairs(core.get_meta(barrel):get_inventory():get_list('main')) do all[#all+1]=s end
 for _,s in ipairs(loose()) do all[#all+1]=ItemStack(s) end
 local packet_count=0
 for _,e in pairs(pipeworks.luaentity.entities or {}) do if e.name=='pipeworks:tubed_item' then packet_count=packet_count+1;all[#all+1]=ItemStack(e.itemstring) end end
 local fields=record_fields(all);data.final_fields=fields;data.final_packets=packet_count
 for _,want in ipairs(expected) do
  local n=0
  for _,s in ipairs(all) do if s:get_name()==want:get_name() then
   eq(s:get_wear(),want:get_wear(),'Native startup payload wear');eq(s:get_meta():get_string('era_vacuum_early'),want:get_meta():get_string('era_vacuum_early'),'Native startup payload metadata');n=n+s:get_count()
  end end
  eq(n,want:get_count(),'Native restart owned '..want:get_name()..' retained')
 end
 data.retained=true
 log('Final native restart fields='..core.write_json(fields))
 finish(true,'COMPLETE: early forceload/ordinary overdue native activation retained all6 owned items; inspect actual first timer table state, conditional preinitialization edge is not assumed')
end
core.register_on_mods_loaded(function()
 core.after(0,function() checked(function()
  log('Earliest fixture after(0): logical table='..tostring(pipeworks.luaentity.entities~=nil)..'; source='..core.get_modpath('pipeworks'))
  if phase==1 then
   core.load_area(vector.new(0,192,0),vector.new(15,207,15))
   assert(core.forceload_block(pos,true)~=false)
   local t=core.get_node_timer(pos);data.earliest_resume={table_initialized=pipeworks.luaentity.entities~=nil,timeout=t:get_timeout(),elapsed=t:get_elapsed(),gametime=core.get_gametime()}
   core.after(10,function() checked(resume_check) end)
  else
   core.emerge_area(vector.new(0,192,0),vector.new(63,207,15),function(_,_,remaining)
    if remaining==0 then core.after(0,function() checked(function()
     core.load_area(vector.new(0,192,0),vector.new(63,207,15))
     assert(core.forceload_block(pos,true)~=false);assert(core.forceload_block(anchor,true)~=false)
     core.after(3,function() checked(prepare) end)
    end) end) end
   end)
  end
 end) end)
end)
