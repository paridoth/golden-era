-- SPDX-License-Identifier: GPL-3.0-or-later
-- More to find in new terrain: structures generate closer together (see
-- worldgen.lua) and generated chests and barrels can hold a few factory parts.
-- Existing terrain keeps what it has.
local FACTORY_PARTS={
 {itemstring="elepower_dynamics:lead_ingot",weight=10,amount_min=2,amount_max=6},
 {itemstring="elepower_dynamics:tin_ingot",weight=10,amount_min=2,amount_max=6},
 {itemstring="elepower_dynamics:nickel_ingot",weight=6,amount_min=1,amount_max=4},
 {itemstring="elepower_dynamics:steel_ingot",weight=5,amount_min=1,amount_max=4},
 {itemstring="elepower_dynamics:conduit",weight=8,amount_min=4,amount_max=12},
 {itemstring="elepower_dynamics:wound_copper_coil",weight=6,amount_min=1,amount_max=3},
 {itemstring="elepower_dynamics:capacitor",weight=5,amount_min=1,amount_max=2},
 {itemstring="elepower_dynamics:chip",weight=4,amount_min=1,amount_max=2},
 {itemstring="elepower_dynamics:silicon_wafer",weight=3,amount_min=1,amount_max=2},
 {itemstring="elepower_dynamics:pcb",weight=3},
 {itemstring="elepower_dynamics:battery",weight=3},
 {itemstring="elepower_dynamics:pv_cell",weight=2,amount_min=1,amount_max=2},
 {itemstring="elepower_dynamics:servo_valve",weight=2},
 {itemstring="elepower_machines:generator",weight=1},
}

-- Every generated container (structures, villages, dungeons, mineshafts) is
-- filled through mcl_loot.fill_inventory; add up to two stacks of parts there.
function era_playtest.add_factory_loot(loot,registered_items)
 local parts={}
 for _,part in ipairs(FACTORY_PARTS) do
  if registered_items[part.itemstring] then parts[#parts+1]=part end
 end
 local pool={stacks_min=0,stacks_max=2,items=parts}
 local fill=loot.fill_inventory
 loot.fill_inventory=function(inv,listname,items,pr)
  if listname=="main" and #parts>0 then
   local random=pr or PcgRandom(math.random(0,2147483647))
   local combined={}
   for i,item in ipairs(items) do combined[i]=item end
   for _,item in ipairs(loot.get_loot(pool,random)) do combined[#combined+1]=item end
   items=combined
  end
  return fill(inv,listname,items,pr)
 end
end

core.register_on_mods_loaded(function()
 if mcl_loot and mcl_loot.fill_inventory then era_playtest.add_factory_loot(mcl_loot,core.registered_items) end
end)

if mcl_levelgen and mcl_levelgen.register_levelgen_script then
 local script=core.get_modpath("era_playtest").."/worldgen.lua"
 mcl_levelgen.register_levelgen_script(script,true)
 dofile(script)
end
