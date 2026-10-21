-- SPDX-License-Identifier: GPL-3.0-or-later
-- Golden Era: Mineclonia stand-ins for the Minetest Game helpers Magicalities used.
magicalities_compat = {
 gui_bg = "", gui_bg_img = "", gui_slots = "",
 get_hotbar_bg = function() return "" end,
 node_sound_wood_defaults = mcl_sounds.node_sound_wood_defaults,
 node_sound_glass_defaults = mcl_sounds.node_sound_glass_defaults,
 schematic_replacements = {
  ["default:dirt_with_grass"] = "mcl_core:dirt_with_grass",
  ["default:junglewood"] = "mcl_core:junglewood",
  ["default:fence_junglewood"] = "mcl_fences:jungle_fence",
  ["stairs:slab_junglewood"] = "mcl_stairs:slab_junglewood",
  ["stairs:stair_junglewood"] = "mcl_stairs:stair_junglewood",
  ["default:bookshelf"] = "mcl_books:bookshelf",
 },
}
