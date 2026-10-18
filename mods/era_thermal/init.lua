-- SPDX-License-Identifier: GPL-3.0-or-later
era.rates=dofile(core.get_modpath("era_thermal").."/rates.lua")
-- Server operators may override positive integer fixture values in minetest.conf.
for key,value in pairs(era.rates) do
 local setting=tonumber(core.settings:get("era_"..key))
 if setting then assert(era.valid_integer(setting,1),"Invalid setting era_"..key); era.rates[key]=setting end
end
era.register_machine("era_thermal:generator",{description="Coal Dynamo",capacity=32000,producer=true})
era.register_machine("era_thermal:buffer",{description="RF Buffer",capacity=100000,buffer=true})
era.register_machine("era_thermal:pulverizer",{description="Pulverizer",capacity=8000,processor=true})
era.register_machine("era_thermal:furnace",{description="Powered Furnace",capacity=8000,processor=true})
era.register_recipe("era_thermal:pulverizer",era.mcl.ore,"era_materials:iron_dust "..era.rates.ore_multiplier,era.rates.pulverizer_cost,era.rates.process_rate)
era.register_recipe("era_thermal:furnace","era_materials:iron_dust",era.mcl.ingot,era.rates.furnace_cost,era.rates.process_rate)
era.register_recipe("era_thermal:pulverizer",era.mcl.raw_iron,"era_materials:iron_dust "..era.rates.ore_multiplier,era.rates.pulverizer_cost,era.rates.process_rate)
dofile(core.get_modpath("era_thermal").."/jobs.lua")
function era.process(pos,name,state)
 if not era.machine_ready(pos,name,state) then return end
 local meta=core.get_meta(pos); local inv=meta:get_inventory(); local stack=inv:get_stack("src",1)
 local recipe=era.resolve_recipe(pos,name,state)
 local pending=meta:get_string("job")~=""
 if not recipe then return end
 local done,spent=era.ledger.process(state,recipe,stack:get_count(),inv:room_for_item("dst",recipe.output))
 if done then
  local output=inv:get_stack("dst",1); local leftover=output:add_item(recipe.output)
  assert(leftover:is_empty(),"preflight/commit mismatch")
  stack:take_item(1); inv:set_stack("src",1,stack); inv:set_stack("dst",1,output)
  meta:set_string("job", "")
 elseif spent>0 and not pending then
  meta:set_string("job",core.serialize({input=stack:get_name(),output=recipe.output,cost=recipe.cost,rate=recipe.rate}))
 end
end

-- Three reviewed machine crafting patterns; RF/fluid behavior is still the fixture model.
era.register_catalog_crafts("thermal")
-- Storage and cable progression are still engineering fixtures.
core.register_craft({output="era_thermal:buffer",recipe={{era.mcl.ingot,era.mcl.ingot,era.mcl.ingot},{era.mcl.stone,era.mcl.redstone,era.mcl.stone},{era.mcl.ingot,era.mcl.redstone,era.mcl.ingot}}})
core.register_craft({output="era_energy:cable 8",recipe={{era.mcl.ingot,era.mcl.redstone,era.mcl.ingot}}})
