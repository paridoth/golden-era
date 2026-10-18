-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise the engine recipe manager, not a copy of the registration table.
return function(eq)
 local m=era.mcl
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
 local function machine(center)
  return {m.ingot,m.ingot,m.ingot,m.stone,center,m.stone,m.ingot,m.redstone,m.ingot}
 end
 craft(machine(m.coal),"era_thermal:generator")
 craft(machine(m.redstone),"era_thermal:buffer")
 craft(machine(m.raw_iron),"era_thermal:pulverizer")
 craft(machine("era_materials:iron_dust"),"era_thermal:furnace")
 -- Shaped single-row recipes must also work away from the top row.
 craft({"","","","","","",m.ingot,m.redstone,m.ingot},"era_energy:cable 8")
 craft({"","","",m.ingot,m.chest,m.redstone,"","",""},"era_transport:ejector")
 craft({"era_materials:iron_dust"},m.ingot,"cooking",10)
 local invalid=machine("")
 local output,left=core.get_craft_result({method="normal",width=3,items=invalid})
 assert(output.item:is_empty(),"incomplete machine recipe must not craft")
 for index,item in ipairs(invalid) do eq(left.items[index]:to_string(),ItemStack(item):to_string(),"invalid craft preserves input") end
 core.log("action","ERA CRAFTING PASS: six shaped recipes, shifted rows, exact ingredient consumption, dust cooking, incomplete recipe denial")
end
