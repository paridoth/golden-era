-- SPDX-License-Identifier: GPL-3.0-or-later
-- Reports whether candidate mods' items are craftable from registered items,
-- then generates terrain around spawn and shuts down.
local CANDIDATES = {logistica=true, travelnet=true, mcl_extra_structures=true}
local function out(text) core.log("action", "ERA MOD TRIAL: "..text) end

local function group_exists(group)
 for _, def in pairs(core.registered_items) do
  local ok = true
  for g in group:gmatch("[^,]+") do
   if (def.groups or {})[g] == nil or def.groups[g] == 0 then ok = false break end
  end
  if ok then return true end
 end
 return false
end

local function ingredient_ok(item)
 if item == "" then return true end
 item = ItemStack(item):get_name()
 if item:sub(1, 6) == "group:" then return group_exists(item:sub(7)) end
 item = core.registered_aliases[item] or item
 return core.registered_items[item] ~= nil
end

core.register_on_mods_loaded(function()
 for mod in pairs(CANDIDATES) do
  local items, craftable, no_recipe, broken = 0, 0, {}, {}
  for name, def in pairs(core.registered_items) do
   if def.mod_origin == mod and not (def.groups or {}).not_in_creative_inventory then
    items = items + 1
    local recipes = core.get_all_craft_recipes(name) or {}
    local good = false
    local missing = {}
    for _, recipe in ipairs(recipes) do
     local ok = true
     for _, item in pairs(recipe.items or {}) do
      if not ingredient_ok(item) then ok = false missing[item] = true end
     end
     good = good or ok
    end
    if good then craftable = craftable + 1
    elseif #recipes == 0 then no_recipe[#no_recipe + 1] = name
    else
     local list = {}
     for item in pairs(missing) do list[#list + 1] = item end
     table.sort(list)
     broken[#broken + 1] = name.." needs "..table.concat(list, " ")
    end
   end
  end
  table.sort(no_recipe) table.sort(broken)
  out(mod..": "..items.." items, "..craftable.." craftable, "..#no_recipe.." without recipe, "..#broken.." with missing ingredients")
  for _, line in ipairs(broken) do out(mod.." BROKEN "..line) end
  for _, name in ipairs(no_recipe) do out(mod.." NORECIPE "..name) end
 end
end)

core.after(2, function()
 local radius = tonumber(core.settings:get("era_mod_trial_radius")) or 192
 local started = core.get_us_time()
 out("emerging terrain radius "..radius)
 core.emerge_area({x=-radius, y=-32, z=-radius}, {x=radius, y=96, z=radius}, function(_, _, remaining)
  if remaining > 0 then return end
  out(string.format("terrain emerged in %.1fs", (core.get_us_time() - started) / 1e6))
  out("COMPLETE")
  core.request_shutdown("mod trial complete")
 end)
end)
