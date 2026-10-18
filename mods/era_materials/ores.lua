-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native representative ores. Placement is deliberately separate from Java vein topology.
local colors={tin="#a5bac0",silver="#dddded",lead="#626f9e"}
for _,ore in ipairs(era.survival.ores) do
 local metal=ore.name:match(':([a-z]+)_ore$')
 core.register_node(ore.name,{
  description=ore.description, tiles={"era_machine.png^[colorize:"..colors[metal]..":110"},
  groups={pickaxey=3,building_block=1,material_stone=1,blast_furnace_smeltable=1},
  _mcl_hardness=3, _mcl_blast_resistance=3, _mcl_cooking_output=ore.ingot,
  drop=ore.name,
 })
 core.register_craft({type="cooking",recipe=ore.name,output=ore.ingot,cooktime=10})
end
for _,ore in ipairs(era.survival.scatters) do
 core.register_ore({ore_type="scatter",ore=ore.ore,wherein="mcl_core:stone",
  clust_scarcity=ore.scarcity,clust_num_ores=ore.count,clust_size=ore.size,
  y_min=mcl_worlds.layer_to_y(ore.min_layer,"overworld"),
  y_max=mcl_worlds.layer_to_y(ore.max_layer,"overworld")})
end
