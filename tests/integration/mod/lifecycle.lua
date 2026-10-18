-- SPDX-License-Identifier: GPL-3.0-or-later
-- Engine-managed eviction/activation; never edit era.active or call era.track.
return function(place,eq)
 local function p(x) return vector.new(x,200,40) end
 local positions={generator=p(14),cable=p(15),buffer=p(16),pulverizer=p(17),furnace=p(18),ejector=p(19),chest=p(20)}
 local left,right=positions.generator,positions.buffer
 local tracked={"generator","cable","buffer","pulverizer","furnace","ejector"}
 local function later(callback)
  core.after(0.1,function()
   local ok,err=xpcall(callback,debug.traceback)
   if not ok then
    core.log("error","ERA INTEGRATION FAIL: "..err)
    core.request_shutdown("Lifecycle test failed",false,0)
   end
  end)
 end
 local function wait_for(label,predicate,callback)
  local started=core.get_us_time()
  local function poll()
   if predicate() then callback(); return end
   assert(core.get_us_time()-started<25000000,"lifecycle timeout: "..label)
   later(poll)
  end
  later(poll)
 end
 local function inv(name) return core.get_meta(positions[name]):get_inventory() end
 local function snapshot(names)
  local result={}
  for _,name in ipairs(names) do
   local meta=core.get_meta(positions[name]); local inventory=meta:get_inventory()
   local fields={energy=meta:get_int("energy"),work=meta:get_int("work"),burn=meta:get_int("burn"),schema=meta:get_int("schema"),job=meta:get_string("job")}
   for _,list in ipairs({"src","dst","fuel","main"}) do
    if inventory:get_size(list)>0 then fields[list]=inventory:get_stack(list,1):to_string() end
   end
   result[name]=fields
  end
  return result
 end
 local function same(expected)
  local names={}; for name in pairs(expected) do names[#names+1]=name end
  local current=snapshot(names)
  for name,fields in pairs(expected) do
   for key,value in pairs(fields) do eq(current[name][key],value,"lifecycle "..name.."."..key) end
  end
 end
 local function known(names)
  for _,name in ipairs(names) do
   if not era.active[core.pos_to_string(positions[name])] then return false end
  end
  return true
 end
 local function pruned(names)
  for _,name in ipairs(names) do
   eq(era.active[core.pos_to_string(positions[name])],nil,"unloaded position pruned: "..name)
  end
 end
 local function connected(size)
  local nets=era.networks(); local key=core.pos_to_string(left)
  for _,net in ipairs(nets) do
   for _,member in ipairs(net) do
    if member==key then eq(#net,size,"cross-boundary component size"); return end
   end
  end
  error("generator network missing")
 end
 local function finish()
  connected(5)
  for _=1,2000 do era.step() end
  eq(inv("chest"):get_stack("main",1):get_name(),era.mcl.ingot,"lifecycle result item")
  eq(inv("chest"):get_stack("main",1):get_count(),4,"lifecycle result count")
  assert(inv("pulverizer"):is_empty("src") and inv("pulverizer"):is_empty("dst"),"pulverizer left items")
  assert(inv("furnace"):is_empty("src") and inv("furnace"):is_empty("dst"),"furnace left items")
  local stored=0
  for _,name in ipairs({"generator","buffer","pulverizer","furnace"}) do
   local state=era.state(positions[name]); stored=stored+state.energy+state.work
  end
  eq(stored+16000,32000,"lifecycle exact RF conservation")
  eq(era.state(left).burn,0,"one coal fully consumed")
  for _=1,100 do era.step() end
  eq(inv("chest"):get_stack("main",1):get_count(),4,"lifecycle no duplicate output")
  core.forceload_free_block(left,true); core.forceload_free_block(right,true)
  core.log("action","ERA INTEGRATION LIFECYCLE PASS: partial/full natural eviction, no offline work, automatic LBM discovery, cross-block reconnection, four ingots and RF conservation")
  core.request_shutdown("Lifecycle integration passed",false,0)
 end
 local function unload_all()
  core.get_meta(positions.buffer):set_string("formspec","obsolete idle form")
  local saved=snapshot({"generator","cable","buffer","pulverizer","furnace","ejector","chest"})
  core.forceload_free_block(left,true); core.forceload_free_block(right,true)
  wait_for("both mapblocks evicted",function()
   return core.get_node_or_nil(left)==nil and core.get_node_or_nil(right)==nil
  end,function()
   for _=1,100 do era.step() end
   pruned(tracked)
   core.log("action","ERA LIFECYCLE: both mapblocks naturally evicted; all tracked positions pruned")
   -- Stay genuinely unloaded for a further second, without reading metadata.
   core.after(1,function() later(function()
    eq(core.get_node_or_nil(left),nil,"left remains unloaded")
    eq(core.get_node_or_nil(right),nil,"right remains unloaded")
    core.load_area(left,positions.chest)
    same(saved); pruned(tracked)
    assert(core.forceload_block(left,true),"reactivate left block")
    assert(core.forceload_block(right,true),"reactivate right block")
    wait_for("LBMs rediscover whole factory",function() return known(tracked) end,function()
     same(saved)
     assert(core.get_meta(positions.buffer):get_string("formspec")~="obsolete idle form","LBM refreshes cached UI at actual activation")
     core.log("action","ERA LIFECYCLE: full reload preserved RF/work/burn/job/inventories; engine activation rediscovered every node")
     finish()
    end)
   end) end)
  end)
 end
 local function partial_unload()
  local names={"buffer","pulverizer","furnace","ejector","chest"}
  local saved=snapshot(names)
  core.forceload_free_block(right,true)
  wait_for("processor mapblock evicted",function() return core.get_node_or_nil(right)==nil end,function()
   assert(core.compare_block_status(left,"active"),"generator block must remain active")
   for _=1,100 do era.step() end
   pruned({"buffer","pulverizer","furnace","ejector"})
   connected(2)
   eq(era.state(left).energy,2000,"isolated generator stores new RF")
   eq(era.state(left).burn,1460,"only explicit loaded ticks consume burn")
   eq(core.get_node_or_nil(right),nil,"simulation must not reload neighbors")
   core.log("action","ERA LIFECYCLE: processor block evicted; generator stayed active, network split, unloaded processors received no RF")
   core.load_area(right,positions.chest)
   same(saved)
   pruned({"buffer","pulverizer","furnace","ejector"})
   assert(core.forceload_block(right,true),"reactivate processor block")
   wait_for("LBMs rediscover processor block",function() return known(tracked) end,function()
    same(saved); connected(5)
    core.log("action","ERA LIFECYCLE: processor block reactivated; LBM restored network without manual tracking")
    unload_all()
   end)
  end)
 end
 core.emerge_area(left,positions.chest,function(_,action,remaining)
  if action==core.EMERGE_ERRORED or action==core.EMERGE_CANCELLED then
   core.log("error","ERA INTEGRATION FAIL: lifecycle fixture emergence failed")
   core.request_shutdown("Lifecycle emergence failed",false,0); return
  end
  if remaining~=0 then return end
  later(function()
   assert(core.forceload_block(left,true),"activate generator block")
   assert(core.forceload_block(right,true),"activate processor block")
   wait_for("initial factory activation",function()
    return core.compare_block_status(left,"active") and core.compare_block_status(right,"active")
   end,function()
    for name,pos in pairs(positions) do
     local id=name=="cable" and "era_energy:cable" or name=="ejector" and "era_transport:ejector" or name=="chest" and "mcl_chests:chest_small" or "era_thermal:"..name
     place(pos,id)
    end
    inv("generator"):set_stack("fuel",1,era.mcl.coal)
    inv("pulverizer"):set_stack("src",1,era.mcl.ore.." 2")
    for _=1,40 do era.step() end
    eq(era.state(left).energy,0,"initial RF sent across block boundary")
    eq(era.state(left).burn,1560,"initial burn")
    eq(era.state(positions.pulverizer).work,800,"initial pending work")
    assert(known(tracked),"placed nodes tracked")
    connected(5)
    partial_unload()
   end)
  end)
 end)
end
