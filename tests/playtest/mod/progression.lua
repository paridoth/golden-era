-- SPDX-License-Identifier: GPL-3.0-or-later
-- Recipe reachability, not a material budget or a simulated player playthrough.
-- Begin with ordinary gathered Mineclonia materials, never machines/components.
return function()
 local available={}
 local function add(name)
  name=ItemStack(name):get_name()
  assert(core.registered_items[name],"Unknown progression material: "..name)
  if available[name] then return false end
  available[name]=true;return true
 end
 local roots={"mcl_trees:tree_oak","mcl_trees:leaves_oak","mcl_core:cobble","mcl_core:sand",
  "mcl_core:clay_lump","mcl_core:flint","mcl_core:coal_lump","mcl_core:water_source",
  "mcl_raw_ores:raw_iron","mcl_copper:raw_copper","mcl_raw_ores:raw_gold","mcl_core:diamond",
  "mcl_redstone:redstone","mcl_farming:wheat_seeds","mcl_dyes:black","mcl_dyes:red","mcl_dyes:blue",
  "elepower_dynamics:lead_lump","elepower_dynamics:tin_lump","moreores:silver_lump",
  "elepower_dynamics:zinc_lump","elepower_dynamics:nickel_lump"}
 for _,name in ipairs(roots) do add(name) end
 local recipes={}
 for name in pairs(core.registered_items) do
  for _,recipe in ipairs(core.get_all_craft_recipes(name) or {}) do
   if recipe.method=="normal" or recipe.method=="cooking" then
    recipes[#recipes+1]={type=recipe.method,inputs=recipe.items,output={recipe.output}}
   end
  end
 end
 for kind,list in pairs(elepm.craft) do
  if kind~="types" then
   for _,recipe in ipairs(list) do
    local inputs={}
    for _,slot in ipairs(recipe.recipe) do for name in pairs(slot) do inputs[#inputs+1]=name end end
    local outputs=type(recipe.output)=="table" and recipe.output or {recipe.output:to_string()}
    recipes[#recipes+1]={type=kind,inputs=inputs,output=outputs}
   end
  end
 end
 local function has(ingredient)
  if not ingredient or ingredient=="" then return true end
  if ingredient:sub(1,6)~="group:" then return available[ItemStack(ingredient):get_name()] end
  local groups=ingredient:sub(7):split(",")
  for name in pairs(available) do
   local matches=true
   for _,group in ipairs(groups) do if core.get_item_group(name,group)==0 then matches=false;break end end
   if matches then return true end
  end
  return false
 end
 local function machine_available(kind)
  if kind=="normal" then return true end
  if kind=="cooking" then return has("mcl_furnaces:furnace") end
  if kind=="grind" then return has("elepower_machines:grindstone") and has("elepower_machines:crank") end
  if kind=="alloy" then return has("elepower_machines:coal_alloy_furnace") end
  if kind=="compress" or kind=="solder" then
   return has("elepower_machines:generator") and has("elepower_dynamics:conduit") and
    has(kind=="compress" and "elepower_machines:compressor" or "elepower_machines:solderer")
  end
  return false
 end
 for _=1,40 do
  local changed=false
  for _,recipe in ipairs(recipes) do
   if machine_available(recipe.type) then
    local ready=true
    for _,ingredient in pairs(recipe.inputs) do if not has(ingredient) then ready=false;break end end
    if ready then for _,output in ipairs(recipe.output) do changed=add(output) or changed end end
   end
  end
  -- These are the upstream right-click acid/PCB transformations, not recipes.
  if has("elepower_dynamics:acidic_compound") and has("mcl_core:water_source") and has("elepower_dynamics:pcb_blank") then
   changed=add("elepower_dynamics:pcb") or changed
  end
  if not changed then break end
 end
 local targets={"elepower_machines:grindstone","elepower_machines:crank","elepower_machines:coal_alloy_furnace",
  "elepower_machines:generator","elepower_dynamics:conduit","elepower_machines:pulverizer","elepower_machines:furnace",
  "elepower_machines:solderer","elepower_machines:compressor","elepower_machines:power_cell_0",
  "pipeworks:tube_1","pipeworks:mese_filter","pipeworks:autocrafter","drawers:oakwood1","fluid_tanks:tank",
  "elepower_farming:planter","elepower_farming:harvester"}
 for _,name in ipairs(targets) do assert(has(name),"Survival recipe dependency cycle or missing source: "..name) end
 core.log("action","Survival recipe reachability: "..#targets.." factory targets derive from gathered vanilla materials and generated Elepower ores; stock grind/alloy steps unlock powered solder/compress and the later cell. Counts and travel are not modeled.")
end
