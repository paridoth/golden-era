-- SPDX-License-Identifier: GPL-3.0-or-later
era.reference=dofile(core.get_modpath("era_thermal").."/reference.lua")
era.model=dofile(core.get_modpath("era_thermal").."/model.lua")
era.rates=dofile(core.get_modpath("era_thermal").."/rates.lua")
-- Server operators may override positive integer fixture values in minetest.conf.
for key,value in pairs(era.rates) do
 local setting=tonumber(core.settings:get("era_"..key))
 if setting then assert(era.valid_integer(setting,1),"Invalid setting era_"..key); era.rates[key]=setting end
end
era.register_machine("era_thermal:generator",{description="Steam Dynamo",capacity=era.reference.generator.capacity_rf,legacy_capacity=32000,producer=true})
era.register_machine("era_thermal:buffer",{description="RF Buffer",capacity=era.reference.buffer.capacity_rf,legacy_capacity=100000,buffer=true})
era.register_machine("era_thermal:pulverizer",{description="Pulverizer",capacity=era.reference.machine.capacity_rf,legacy_capacity=8000,processor=true})
era.register_machine("era_thermal:furnace",{description="Redstone Furnace",capacity=era.reference.machine.capacity_rf,legacy_capacity=8000,processor=true})
era.register_recipe("era_thermal:pulverizer",era.mcl.ore,"era_materials:iron_dust "..era.rates.ore_multiplier,era.rates.pulverizer_cost,era.rates.process_rate)
era.register_recipe("era_thermal:furnace","era_materials:iron_dust",era.mcl.ingot,era.rates.furnace_cost,era.rates.process_rate)
era.register_recipe("era_thermal:pulverizer",era.mcl.raw_iron,"era_materials:iron_dust "..era.rates.ore_multiplier,era.rates.pulverizer_cost,era.rates.process_rate)
-- Source-backed recipes for new/explicitly upgraded machines; raw iron is a native compatibility choice.
for _,input in ipairs({era.mcl.ore,era.mcl.raw_iron}) do
 era.native_recipes["era_thermal:pulverizer"]=era.native_recipes["era_thermal:pulverizer"] or {}
 era.native_recipes["era_thermal:pulverizer"][input]={output="era_materials:iron_dust "..era.reference.ore_multiplier,cost=era.reference.pulverizer_cost,rate=era.reference.machine.max_rf_per_tick,schema=3,rate_mode="buffer",secondary_output=era.reference.secondary_output,secondary_chance=era.reference.secondary_chance}
end
era.native_recipes["era_thermal:furnace"]={["era_materials:iron_dust"]={output=era.mcl.ingot,cost=era.reference.furnace_cost,rate=era.reference.machine.max_rf_per_tick,schema=2,rate_mode="buffer"}}
dofile(core.get_modpath("era_thermal").."/jobs.lua")
function era.process(pos,name,state)
 if not era.machine_ready(pos,name,state) then return end
 local meta=core.get_meta(pos); local inv=meta:get_inventory(); local stack=inv:get_stack("src",1)
 local recipe=era.resolve_recipe(pos,name,state)
 local pending=meta:get_string("job")~=""
 if not recipe then return end
 if recipe.secondary_output and inv:get_size("secondary")==0 then inv:set_size("secondary",1) end
 local room=inv:room_for_item("dst",recipe.output) and (not recipe.secondary_output or inv:room_for_item("secondary",recipe.secondary_output))
 if not room or state.energy<=0 then return end
 -- Decide once when paid work starts. This saved decision is never rerolled on block/restart.
 local job=recipe
 if not pending then
  job={input=stack:get_name(),output=recipe.output,cost=recipe.cost,rate=recipe.rate,schema=recipe.schema,rate_mode=recipe.rate_mode}
  if recipe.secondary_output then
   job.secondary_output=recipe.secondary_output; job.secondary_chance=recipe.secondary_chance
   job.secondary_roll=era.random_percent()
   assert(era.valid_integer(job.secondary_roll,1) and job.secondary_roll<=100,"Invalid random percent")
  end
 end
 local operation=job
 if job.rate_mode=="buffer" then
  operation={output=job.output,cost=job.cost,rate=era.model.rate(state.energy,era.reference.machine,false)}
 end
 local done,spent=era.ledger.process(state,operation,stack:get_count(),room)
 if done then
  local output=inv:get_stack("dst",1); local leftover=output:add_item(job.output)
  assert(leftover:is_empty(),"preflight/commit mismatch")
  if job.secondary_output and job.secondary_roll<=job.secondary_chance then
   local secondary=inv:get_stack("secondary",1); local left=secondary:add_item(job.secondary_output)
   assert(left:is_empty(),"secondary preflight/commit mismatch"); inv:set_stack("secondary",1,secondary)
  end
  stack:take_item(1); inv:set_stack("src",1,stack); inv:set_stack("dst",1,output)
  meta:set_string("job", "")
 elseif spent>0 and not pending then meta:set_string("job",core.serialize(job)) end
end

function era.load_water(pos,state)
 local inv=core.get_meta(pos):get_inventory()
 local bucket=inv:get_stack("water",1)
 if bucket:get_name()~=era.mcl.water_bucket or state.water+1000>era.reference.generator.tank_mb or not inv:room_for_item("empty",era.mcl.empty_bucket) then return false end
 local left=inv:add_item("empty",era.mcl.empty_bucket); assert(left:is_empty(),"bucket preflight/commit mismatch")
 bucket:take_item(1); inv:set_stack("water",1,bucket); state.water=state.water+1000
 return true
end
-- Three reviewed machine crafting patterns. Side controls and ducts remain native fixtures.
era.register_catalog_crafts("thermal")
-- Storage and cable progression are still engineering fixtures.
core.register_craft({output="era_thermal:buffer",recipe={{era.mcl.ingot,era.mcl.ingot,era.mcl.ingot},{era.mcl.stone,era.mcl.redstone,era.mcl.stone},{era.mcl.ingot,era.mcl.redstone,era.mcl.ingot}}})
core.register_craft({output="era_energy:cable 8",recipe={{era.mcl.ingot,era.mcl.redstone,era.mcl.ingot}}})
