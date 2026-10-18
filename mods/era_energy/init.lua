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
   if def then
    local s=era.state(pos); s.capacity=def.capacity; states[key]=s; defs[key]=def
    if def.producer then
     local inv=core.get_meta(pos):get_inventory(); local fuel=inv:get_stack("fuel",1)
     local used=era.ledger.generate(s,era.rates.generator_rate,era.rates.coal_ticks,fuel:get_name()==era.mcl.coal)
     if used then fuel:take_item(1); inv:set_stack("fuel",1,fuel) end
    end
   end
  end
  -- Generators first fill buffers. Consumers then draw from producers/buffers.
  for _,target in ipairs(net) do
   if defs[target] and defs[target].buffer then
    for _,source in ipairs(net) do
     if defs[source] and defs[source].producer then era.ledger.transfer(states[source],states[target],era.rates.cable_rate) end
    end
   end
  end
  for _,target in ipairs(net) do
   if defs[target] and defs[target].processor then
    local budget=era.rates.machine_input
    for _,source in ipairs(net) do
     if defs[source] and (defs[source].producer or defs[source].buffer) then
      budget=budget-era.ledger.transfer(states[source],states[target],budget)
     end
    end
   end
  end
  for _,key in ipairs(net) do
   if states[key] then
    if defs[key].processor then era.process(nodes[key],core.get_node(nodes[key]).name,states[key]) end
    local old=era.state(nodes[key]); local s=states[key]
    if old.energy~=s.energy or old.work~=s.work or old.burn~=s.burn then era.save(nodes[key],s); era.refresh(nodes[key]) end
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
