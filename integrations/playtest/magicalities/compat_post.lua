-- SPDX-License-Identifier: GPL-3.0-or-later
-- Golden Era: give Magicalities nodes and tools Mineclonia digging rules.
-- Runs before _mcl_autogroup derives capabilities in on_mods_loaded.
local NODE_GROUPS = {cracky = "pickaxey", choppy = "axey", crumbly = "shovely",
 snappy = "swordy", oddly_breakable_by_hand = "handy"}
local TOOL_GROUPS = {cracky = "pickaxey", choppy = "axey", crumbly = "shovely", snappy = "swordy"}

for name, def in pairs(core.registered_nodes) do
 if def.mod_origin == "magicalities" then
  local groups = table.copy(def.groups or {})
  for old, new in pairs(NODE_GROUPS) do
   if groups[old] then groups[new] = 1 end
  end
  local hardness = groups.cracky and 1.5 or (groups.choppy and 2 or 0.5)
  if groups.crystal_cluster then hardness = 0.3 end
  core.override_item(name, {groups = groups, _mcl_hardness = hardness, _mcl_blast_resistance = hardness * 2})
 end
end

for name, def in pairs(core.registered_tools) do
 local caps = def.tool_capabilities and def.tool_capabilities.groupcaps
 if def.mod_origin == "magicalities" and caps then
  local diggroups = {}
  for old, new in pairs(TOOL_GROUPS) do
   if caps[old] then
    -- Diamond tier; empowered variants dig faster and wear sooner, as upstream.
    local empowered = name:sub(-5) == "_rage"
    diggroups[new] = {speed = empowered and 12 or 8, level = 5, uses = empowered and 200 or 1000}
   end
  end
  core.override_item(name, {_mcl_diggroups = diggroups})
 end
end

for old, new in pairs(magicalities_compat.schematic_replacements) do
 if not core.registered_nodes[new] then
  core.log("warning", "[magicalities compat] missing schematic replacement "..old.." -> "..new)
 end
end
