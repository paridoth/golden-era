-- SPDX-License-Identifier: GPL-3.0-or-later
-- Closer structure spacing for Mineclonia's structure generator. This file runs
-- in the game and again in the world-generation environment, which has no
-- game API, so it only replaces placements of known structure sets. Each entry
-- is the upstream spacing, separation, salt and spread, then Golden Era's
-- spacing and separation. Extra structures end up about eight times as common
-- and villages about three times.
local R=mcl_levelgen.build_random_spread_placement
local CLOSER={
 ["mcl_villages:villages"]={34,8,10387312,"linear",20,5},
 ["mcl_extra_structures:graveyards"]={80,20,451148140,"linear",28,7},
 ["mcl_extra_structures:sandstone_obelisk"]={80,20,1728818693,"linear",28,7},
 ["mcl_extra_structures:loggers_camps"]={80,20,3941881656,"linear",28,7},
 ["mcl_extra_structures:birch_forest_ruins"]={40,20,1109598614,"linear",14,5},
 ["mcl_extra_structures:desert_oases"]={60,20,2990390720,"linear",21,7},
 ["mcl_extra_structures:ice_towers"]={85,20,117174882,"linear",30,7},
 ["mcl_extra_structures:brick_pyramids"]={90,20,3468180871,"triangular",32,7},
}
for name,c in pairs(CLOSER) do
 local set=mcl_levelgen.registered_structure_sets[name]
 -- Leave a set alone if upstream changed it; the game then keeps its own rate.
 if set and set.placement.spacing==c[1] and set.placement.salt==c[3] then
  set.placement=R(1.0,"default",c[5],c[6],c[3],c[4],nil,nil)
 end
end
