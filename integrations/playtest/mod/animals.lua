-- SPDX-License-Identifier: GPL-3.0-or-later
-- Mineclonia only spawns farm animals slowly near players; Minecraft also places
-- herds when land first generates. Herds use the stock mobs and never despawn.
local HERDS={"mobs_mc:cow","mobs_mc:sheep","mobs_mc:pig","mobs_mc:chicken"}
local CHANCE=70 -- percent of surface chunks with suitable grass that get one herd
-- Grass already limits herds to farm-animal land; Minecraft's Pale Garden has none.
local NO_HERDS={PaleGarden=true}

local function place_herd(spots,mob,count)
 local placed=0
 for _,pos in ipairs(spots) do
  if placed>=count then break end
  if core.get_node(pos).name=="mcl_core:dirt_with_grass" and core.get_node(vector.offset(pos,0,1,0)).name=="air" then
   core.add_entity(vector.offset(pos,0,1,0),mob)
   placed=placed+1
  end
 end
end

core.register_on_generated(function(minp,maxp,blockseed)
 if maxp.y<0 or minp.y>160 then return end
 local random=PcgRandom(blockseed)
 if random:next(1,100)>CHANCE then return end
 local grass=core.find_nodes_in_area_under_air(minp,maxp,{"mcl_core:dirt_with_grass"})
 if #grass==0 then return end
 local center=grass[random:next(1,#grass)]
 local biome=core.get_biome_name(core.get_biome_data(center).biome)
 -- Shore and ocean variants share a base name, such as Plains_beach.
 if NO_HERDS[biome:match("^[^_]+")] then return end
 local nearby={}
 for _,pos in ipairs(grass) do
  if vector.distance(pos,center)<=6 then nearby[#nearby+1]=pos end
 end
 table.shuffle(nearby)
 local mob,count=HERDS[random:next(1,#HERDS)],random:next(2,4)
 -- Add after the generated chunk is written so the entities stay with it.
 core.after(0,place_herd,nearby,mob,count)
end)
