-- SPDX-License-Identifier: GPL-3.0-or-later
-- Structures generate closer together and generated containers gain factory parts.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end

-- Placement: known sets get closer spacing; changed or unknown sets are left alone.
local built={}
mcl_levelgen={build_random_spread_placement=function(f,r,spacing,separation,salt,spread,offset,exclusion)
 built[#built+1]=spread;return {spacing=spacing,separation=separation,salt=salt,spread=spread} end,
 registered_structure_sets={
  ["mcl_villages:villages"]={placement={spacing=34,salt=10387312}},
  ["mcl_extra_structures:graveyards"]={placement={spacing=80,salt=451148140}},
  ["mcl_extra_structures:brick_pyramids"]={placement={spacing=90,salt=3468180871}},
  ["mcl_extra_structures:ice_towers"]={placement={spacing=70,salt=117174882}},
  ["mcl_levelgen:desert_pyramids"]={placement={spacing=32,salt=14357617}}}}
dofile(root.."/integrations/playtest/mod/worldgen.lua")
local sets=mcl_levelgen.registered_structure_sets
eq(sets["mcl_villages:villages"].placement.spacing,20,"Villages are closer together")
eq(sets["mcl_extra_structures:graveyards"].placement.spacing,28,"Graveyards are about eight times as common")
eq(sets["mcl_extra_structures:graveyards"].placement.separation,7,"Separation shrinks too")
eq(sets["mcl_extra_structures:brick_pyramids"].placement.spread,"triangular","Spread type is kept")
eq(sets["mcl_extra_structures:ice_towers"].placement.spacing,70,"A changed upstream set is left alone")
eq(sets["mcl_levelgen:desert_pyramids"].placement.spacing,32,"Unlisted structures keep their rate")

-- Loot: parts are appended without changing the caller's list.
core={register_on_mods_loaded=function() end,get_modpath=function() return root.."/integrations/playtest/mod" end}
mcl_levelgen=nil
era_playtest={}
dofile(root.."/integrations/playtest/mod/world.lua")
local filled
local loot={fill_inventory=function(_,listname,items) filled={listname=listname,items=items} end,
 get_loot=function(pool)
  eq(pool.stacks_max,1,"At most one stack of parts")
  local last=pool.items[#pool.items]
  eq(last.nothing,true,"Most containers get no parts");eq(last.weight,20,"Two in three rolls are empty")
  return {"elepower_dynamics:lead_ingot 3"} end}
era_playtest.add_factory_loot(loot,{["elepower_dynamics:lead_ingot"]={}})

-- Without any registered parts nothing is appended.
local none={fill_inventory=function(_,_,items) filled={items=items} end,get_loot=function() error("no roll without parts") end}
era_playtest.add_factory_loot(none,{})
none.fill_inventory(nil,"main",{"mcl_core:apple"},{})
eq(#filled.items,1,"No parts registered, nothing added")

local original={"mcl_core:gold_ingot 2"}
loot.fill_inventory(nil,"main",original,{})
eq(#filled.items,2,"Factory parts are added to the container")
eq(filled.items[2],"elepower_dynamics:lead_ingot 3","The rolled part is included")
eq(#original,1,"The structure's own loot list is not modified")
loot.fill_inventory(nil,"fuel",{"mcl_core:coal_lump"},{})
eq(#filled.items,1,"Only main inventories get parts")
print("WORLD PASS: villages and extra structures closer; changed sets untouched; factory parts appended to generated containers")
