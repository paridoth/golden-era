-- SPDX-License-Identifier: GPL-3.0-or-later
-- Only native definitions are loaded here; original pack code stays outside the runtime.
era.catalog=dofile(core.get_modpath("era_materials").."/catalog.lua")
assert(era.catalog.schema==1,"Unsupported material catalog")
for _,item in ipairs(era.catalog.items) do
 core.register_craftitem(item.name,{description=item.description,inventory_image="era_dust.png"})
end
function era.register_catalog_crafts(phase)
 for _,recipe in ipairs(era.catalog.recipes) do
  if recipe.phase==phase then
   core.register_craft({type=recipe.type,output=recipe.output,recipe=recipe.recipe})
  end
 end
end
era.register_catalog_crafts("materials")
-- Retain the existing engineering cooking recipe until the processing model is migrated.
core.register_craft({type="cooking",output=era.mcl.ingot,recipe="era_materials:iron_dust",cooktime=10})
core.register_on_mods_loaded(function()
 for _,recipe in ipairs(era.catalog.recipes) do
  assert(core.registered_items[ItemStack(recipe.output):get_name()],"Missing catalog output "..recipe.id)
  local function check(name)
   assert(name=="" or core.registered_items[name],"Missing catalog ingredient "..name)
  end
  if recipe.type=="shapeless" then
   for _,name in ipairs(recipe.recipe) do check(name) end
  else
   for _,row in ipairs(recipe.recipe) do for _,name in ipairs(row) do check(name) end end
  end
 end
end)
