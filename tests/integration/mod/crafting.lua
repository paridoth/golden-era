-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise the engine recipe manager against independent reference examples.
return function(eq)
 local m=era.mcl
 local copper="mcl_copper:copper_ingot"
 local tin="era_materials:tin_ingot"
 local silver="era_materials:silver_ingot"
 local bronze="era_materials:bronze_ingot"
 local cg="era_materials:copper_gear"
 local tg="era_materials:tin_gear"
 local frame="era_materials:machine_frame"
 local gc="era_materials:gold_coil"
 local sc="era_materials:silver_coil"
 local function craft(items,expected,method,time)
  local stacks={}
  for index,name in ipairs(items) do stacks[index]=ItemStack(name=="" and "" or name.." 2") end
  local output,left=core.get_craft_result({method=method or "normal",width=3,items=stacks})
  eq(output.item:to_string(),ItemStack(expected):to_string(),"craft result "..expected)
  eq(#output.replacements,0,"no unexpected replacements")
  for index,stack in ipairs(stacks) do
   local remaining=left.items[index]
   eq(remaining:get_name(),stack:get_name(),"craft remaining ingredient "..index)
   eq(remaining:get_count(),stack:is_empty() and 0 or 1,"craft consumes one per occupied slot "..index)
   eq(stack:get_count(),stack:is_empty() and 0 or 2,"API leaves caller stack unchanged "..index)
  end
  if time then eq(output.time,time,"dust cooking time") end
 end
 local function deny(items,label)
  local output,left=core.get_craft_result({method="normal",width=3,items=items})
  assert(output.item:is_empty(),label)
  for index,item in ipairs(items) do eq(left.items[index]:to_string(),ItemStack(item):to_string(),"denied craft preserves input "..label) end
 end
 -- Thermal Foundation default gear vs Revelation's explicit tin/bronze overrides.
 craft({"",copper,"",copper,"",copper,"",copper,""},cg)
 craft({"",tin,"",tin,m.ingot,tin,"",tin,""},tg)
 craft({"",bronze,"",bronze,m.ingot,bronze,"",bronze,""},"era_materials:bronze_gear")
 craft({tin,copper,copper,copper},bronze.." 2") -- shuffled shapeless order, four ingots in -> two out
 craft({"","",m.redstone,"","mcl_core:gold_ingot","",m.redstone,"",""},gc)
 craft({"","",m.redstone,"",silver,"",m.redstone,"",""},sc)
 craft({m.ingot,"mcl_core:glass",m.ingot,"mcl_core:glass",tg,"mcl_core:glass",m.ingot,"mcl_core:glass",m.ingot},frame)
 craft({"",sc,"",m.ingot,cg,m.ingot,copper,m.redstone,copper},"era_thermal:generator")
 craft({"","mcl_pistons:piston_off","","mcl_core:flint",frame,"mcl_core:flint",cg,gc,cg},"era_thermal:pulverizer")
 craft({"",m.redstone,"","mcl_core:brick_block",frame,"mcl_core:brick_block",cg,gc,cg},"era_thermal:furnace")
 -- Keep the still-provisional storage/transport fixture checks.
 local function old_machine(center)
  return {m.ingot,m.ingot,m.ingot,m.stone,center,m.stone,m.ingot,m.redstone,m.ingot}
 end
 craft(old_machine(m.redstone),"era_thermal:buffer")
 craft({"","","","","","",m.ingot,m.redstone,m.ingot},"era_energy:cable 8")
 craft({"","","",m.ingot,m.chest,m.redstone,"","",""},"era_transport:ejector")
 craft({"era_materials:iron_dust"},m.ingot,"cooking",10)
 deny({"",tin,"",tin,"",tin,"",tin,""},"tin gear must include iron center")
 deny({"",copper,"",copper,m.ingot,copper,"",copper,""},"copper gear must have empty center")
 deny(old_machine(m.coal),"old generator shortcut removed")
 deny(old_machine(m.raw_iron),"old pulverizer shortcut removed")
 deny(old_machine("era_materials:iron_dust"),"old furnace shortcut removed")
 deny({"","mcl_pistons:piston_off","","mcl_core:flint",frame,"mcl_core:flint",cg,sc,cg},"wrong coil cannot craft pulverizer")
 core.log("action","ERA CRAFTING PASS: ten reference catalog recipes, exact consumption, pack overrides, six denied shortcuts/substitutions, provisional storage/transport and dust cooking")
end
