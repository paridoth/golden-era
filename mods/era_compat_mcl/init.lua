-- SPDX-License-Identifier: GPL-3.0-or-later
-- All Mineclonia item-name assumptions live here; fail early on upstream changes.
era.mcl = {ore="mcl_core:stone_with_iron", ingot="mcl_core:iron_ingot", coal="mcl_core:coal_lump",
 stone="mcl_core:cobble", raw_iron="mcl_raw_ores:raw_iron", redstone="mcl_redstone:redstone", chest="mcl_chests:chest", charcoal="mcl_core:charcoal_lump", water_bucket="mcl_buckets:bucket_water", empty_bucket="mcl_buckets:bucket_empty"}
core.register_on_mods_loaded(function()
 for key, name in pairs(era.mcl) do assert(core.registered_items[name], "Missing Mineclonia item "..key..": "..name) end
end)
