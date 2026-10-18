-- SPDX-License-Identifier: GPL-3.0-or-later
local dirs={{x=1,y=0,z=0},{x=-1,y=0,z=0},{x=0,y=1,z=0},{x=0,y=-1,z=0},{x=0,y=0,z=1},{x=0,y=0,z=-1}}
local cached_epoch, cached_signature, networks = -1, "", {}
core.register_node("era_energy:cable", {description="RF Cable", tiles={"era_cable.png"},
 groups={cracky=2,pickaxey=1,era_cable=1}, _mcl_hardness=1, _mcl_blast_resistance=3,
 on_construct=era.track, on_destruct=function(pos) era.active[core.pos_to_string(pos)]=nil; era.invalidate() end})
function era.networks()
 local nodes, keys = {}, {}
 for key,pos in pairs(era.active) do
  local node=core.get_node_or_nil(pos)
  if not node or node.name=="ignore" then era.active[key]=nil; era.invalidate() end
  if node and (era.machines[node.name] or node.name=="era_energy:cable") then nodes[key]=pos; keys[#keys+1]=key end
 end
 table.sort(keys); local signature=table.concat(keys,";")
 if cached_epoch~=era.epoch or cached_signature~=signature then
  networks=era.ledger.components(nodes,function(key)
   local result={}; for _,dir in ipairs(dirs) do result[#result+1]=core.pos_to_string(vector.add(nodes[key],dir)) end
   return result
  end)
  cached_epoch, cached_signature=era.epoch,signature
 end
 return networks,nodes
end
-- Fixed 20 Hz, capped backlog. Unloaded nodes pause, never offline-generate.
function era.step()
 local nets,nodes=era.networks()
 for _,net in ipairs(nets) do
  local states, defs = {}, {}
  for _,key in ipairs(net) do
   local pos=nodes[key]; local def=era.machines[core.get_node(pos).name]
   if def and era.machine_ready(pos,core.get_node(pos).name) then
    local s=era.state(pos); s.capacity=era.capacity(pos,def,s); states[key]=s; defs[key]=def
    if def.producer then
     local inv=core.get_meta(pos):get_inventory(); local fuel=inv:get_stack("fuel",1)
     local used
     if s.profile=="legacy" then
      used=era.ledger.generate(s,era.rates.generator_rate,era.rates.coal_ticks,fuel:get_name()==era.mcl.coal)
     else
      era.load_water(pos,s)
      local value=fuel:get_name()==era.mcl.coal and era.reference.generator.coal_rf or fuel:get_name()==era.mcl.charcoal and era.reference.generator.charcoal_rf or 0
      used=era.model.generate(s,era.reference.generator,value)
     end
     if used then fuel:take_item(1); inv:set_stack("fuel",1,fuel) end
    end
   end
  end
  -- Graph topology/order remain native. Shared source budgets prevent repeated donor sends.
  local budgets={}
  for key,s in pairs(states) do
   if s.profile=="revelation" then budgets[key]=defs[key].buffer and era.reference.buffer.send_rf or 80 end
  end
  local function transfer(source,target,limit)
   local n=era.ledger.transfer(states[source],states[target],math.min(limit,budgets[source] or limit))
   if budgets[source] then budgets[source]=budgets[source]-n end
   return n
  end
  for _,target in ipairs(net) do
   if defs[target] and defs[target].buffer then
    local budget=states[target].profile=="revelation" and era.reference.buffer.receive_rf or era.rates.cable_rate
    for _,source in ipairs(net) do
     if defs[source] and defs[source].producer then
      local limit=states[target].profile=="legacy" and era.rates.cable_rate or budget
      if states[source].profile=="legacy" then limit=math.min(limit,era.rates.cable_rate) end
      local n=transfer(source,target,limit); budget=budget-n
     end
    end
   end
  end
  local remaining=0
  for key,s in pairs(states) do
   if defs[key].processor and s.profile=="revelation" and s.energy<s.capacity then remaining=remaining+1 end
  end
  for _,target in ipairs(net) do
   if defs[target] and defs[target].processor then
    local native=states[target].profile=="revelation"
    local budget=era.rates.machine_input
    if native then
     local available=0
     for source,s in pairs(states) do
      if defs[source].producer or defs[source].buffer then available=available+math.min(s.energy,budgets[source] or s.energy) end
     end
     budget=remaining>0 and math.min(80,math.ceil(available/remaining)) or 0
     if states[target].energy<states[target].capacity then remaining=remaining-1 else budget=0 end
    end
    for _,source in ipairs(net) do
     if defs[source] and (defs[source].producer or defs[source].buffer) then
      budget=budget-transfer(source,target,budget)
     end
    end
   end
  end
  for _,key in ipairs(net) do
   if states[key] then
    if defs[key].processor then era.process(nodes[key],core.get_node(nodes[key]).name,states[key]) end
    local old=era.state(nodes[key]); local s=states[key]
    local changed=false
    for _,field in ipairs(era.state_fields) do if old[field]~=s[field] then changed=true end end
    if changed then era.save(nodes[key],s); era.refresh(nodes[key]) end
   end
  end
 end
 if era.transport_step then era.transport_step() end
end
local elapsed=0
core.register_globalstep(function(dt)
 if core.settings:get_bool("era_test_manual",false) then return end
 elapsed=math.min(elapsed+dt,0.25)
 while elapsed>=0.05 do elapsed=elapsed-0.05; era.step() end
end)
