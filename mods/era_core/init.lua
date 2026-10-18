-- SPDX-License-Identifier: GPL-3.0-or-later
 era = { machines = {}, recipes = {}, active = {}, epoch = 0 }
 era.ledger = dofile(core.get_modpath("era_core") .. "/ledger.lua")
 function era.invalidate() era.epoch = era.epoch + 1 end
 function era.track(pos)
  era.active[core.pos_to_string(pos)] = vector.new(pos); era.invalidate()
 end
 function era.state(pos)
  local m = core.get_meta(pos)
  return { energy=m:get_int("energy"), work=m:get_int("work"), burn=m:get_int("burn") }
 end
 function era.save(pos, state)
  local m = core.get_meta(pos)
  for _, key in ipairs({"energy", "work", "burn"}) do m:set_int(key, state[key]) end
  m:set_int("schema", 1)
 end
 function era.register_recipe(machine, input, result, cost, rate)
  assert(cost > 0 and rate > 0 and not (era.recipes[machine] or {})[input])
  era.recipes[machine] = era.recipes[machine] or {}
  era.recipes[machine][input] = { output=result, cost=cost, rate=rate }
 end
 function era.allowed(pos, player)
  return player and not core.is_protected(pos, player:get_player_name())
 end
 function era.register_machine(name, def)
  assert(not era.machines[name]); era.machines[name] = def
  core.register_node(name, {
   description=def.description, tiles={def.texture or "era_machine.png"},
   groups={cracky=2, pickaxey=1, era_machine=1, unmovable_by_piston=1}, _mcl_hardness=3, _mcl_blast_resistance=6,
   on_construct=function(pos)
    local m=core.get_meta(pos); local inv=m:get_inventory()
    for _, list in ipairs({"src","dst","fuel"}) do inv:set_size(list, 1) end
    era.save(pos, {energy=0,work=0,burn=0}); era.track(pos)
    era.refresh(pos)
   end,
   after_place_node=function(pos, player) core.get_meta(pos):set_string("owner",player:get_player_name()); era.track(pos) end,
   on_destruct=function(pos) era.active[core.pos_to_string(pos)]=nil; era.invalidate() end,
   on_blast=function() end, -- Preserve inventories until blast drops have a tested transaction.
   can_dig=function(pos, player)
    if not era.allowed(pos,player) then return false end
    local m=core.get_meta(pos); local inv=m:get_inventory()
    return m:get_int("energy")==0 and m:get_int("work")==0 and m:get_int("burn")==0 and inv:is_empty("src") and inv:is_empty("dst") and inv:is_empty("fuel")
   end,
   allow_metadata_inventory_put=function(pos,list,index,stack,player)
    if not era.allowed(pos,player) or list=="dst" then return 0 end
    if list=="fuel" then return stack:get_name()=="mcl_core:coal_lump" and stack:get_count() or 0 end
    local recipes=era.recipes[name] or {}
    return recipes[stack:get_name()] and stack:get_count() or 0
   end,
   allow_metadata_inventory_take=function(pos,list,index,stack,player)
    if not era.allowed(pos,player) then return 0 end
    if list=="src" and core.get_meta(pos):get_int("work")>0 then return 0 end
    return stack:get_count()
   end,
   allow_metadata_inventory_move=function() return 0 end,
  })
 end
 function era.refresh(pos)
  local m=core.get_meta(pos); local def=era.machines[core.get_node(pos).name]
  if not def then return end
  m:set_string("infotext",def.description.." | RF "..m:get_int("energy").." / "..def.capacity.." | Work "..m:get_int("work"))
  m:set_string("formspec", "formspec_version[4]size[10,8]label[0.5,0.3;Golden Era - "..def.description.."]"..
   "label[0.5,0.8;RF "..m:get_int("energy").." | Work "..m:get_int("work").."]"..
   "label[0.5,1.5;Input]list[context;src;0.5,2;1,1;]label[3,1.5;Output]list[context;dst;3,2;1,1;]"..
   "label[5.5,1.5;Coal]list[context;fuel;5.5,2;1,1;]list[current_player;main;0.5,3.5;9,3;]"..
   "listring[context;src]listring[current_player;main]")
 end
 core.register_lbm({name="era_core:resume", nodenames={"group:era_machine","group:era_cable","group:era_ejector"},
  run_at_every_load=true, action=function(pos) era.track(pos) end})
