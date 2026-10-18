-- SPDX-License-Identifier: GPL-3.0-or-later
 era = { machines = {}, recipes = {}, native_recipes = {}, active = {}, epoch = 0 }
 era.ledger = dofile(core.get_modpath("era_core") .. "/ledger.lua")
 dofile(core.get_modpath("era_core") .. "/validation.lua")
 function era.invalidate() era.epoch = era.epoch + 1 end
 function era.track(pos)
  era.active[core.pos_to_string(pos)] = vector.new(pos); era.invalidate()
 end
 dofile(core.get_modpath("era_core").."/state.lua")
 dofile(core.get_modpath("era_core").."/ports.lua")
 dofile(core.get_modpath("era_core").."/forms.lua")
 dofile(core.get_modpath("era_core").."/relocation.lua")
 dofile(core.get_modpath("era_core").."/wrench.lua")
 function era.register_recipe(machine, input, result, cost, rate)
  assert(cost > 0 and rate > 0 and not (era.recipes[machine] or {})[input])
  era.recipes[machine] = era.recipes[machine] or {}
  era.recipes[machine][input] = { output=result, cost=cost, rate=rate }
 end
 function era.allowed(pos, player)
  return player and not core.is_protected(pos, player:get_player_name())
 end
 function era.register_machine(name, def)
  assert(not era.machines[name]); def.legacy_capacity=def.legacy_capacity or def.capacity; era.machines[name] = def
  core.register_node(name, {
   description=def.description, paramtype2="facedir", tiles={def.texture or "era_machine.png"},
   groups={cracky=2, pickaxey=1, era_machine=1, unmovable_by_piston=1}, _mcl_hardness=3, _mcl_blast_resistance=6,
   on_construct=function(pos)
    local m=core.get_meta(pos); local inv=m:get_inventory()
    for _, list in ipairs({"src","dst","secondary","fuel","water","empty"}) do inv:set_size(list, 1) end
    era.save(pos, {energy=0,work=0,burn=0,water=0,fuel_rf=0,water_rf=0,profile="revelation"}); era.track(pos)
    era.init_ports(pos,name); era.refresh(pos)
   end,
   after_place_node=function(pos, player) core.get_meta(pos):set_string("owner",player:get_player_name()); era.track(pos) end,
   on_destruct=function(pos) era.active[core.pos_to_string(pos)]=nil; era.invalidate() end,
   on_blast=function() end, -- Preserve inventories until blast drops have a tested transaction.
   can_dig=function(pos, player)
    if not era.allowed(pos,player) or not era.machine_ready(pos,name) then return false end
    local m=core.get_meta(pos); local inv=m:get_inventory()
    return m:get_int("energy")==0 and m:get_int("work")==0 and m:get_int("burn")==0 and m:get_int("water")==0 and m:get_int("fuel_rf")==0 and m:get_int("water_rf")==0 and inv:is_empty("src") and inv:is_empty("dst") and inv:is_empty("secondary") and inv:is_empty("fuel") and inv:is_empty("water") and inv:is_empty("empty")
   end,
   allow_metadata_inventory_put=function(pos,list,index,stack,player)
    if not era.allowed(pos,player) or not era.machine_ready(pos,name) or list=="dst" or list=="secondary" or list=="empty" then return 0 end
    if list=="water" then return def.producer and era.state(pos).profile=="revelation" and stack:get_name()==era.mcl.water_bucket and stack:get_count() or 0 end
    if list=="fuel" then
     local native=era.state(pos).profile=="revelation"
     return def.producer and (stack:get_name()==era.mcl.coal or native and stack:get_name()==era.mcl.charcoal) and stack:get_count() or 0
    end
    return era.recipe_for(pos,name,stack:get_name()) and stack:get_count() or 0
   end,
   allow_metadata_inventory_take=function(pos,list,index,stack,player)
    if not era.allowed(pos,player) or not era.machine_ready(pos,name) then return 0 end
    if list=="src" and core.get_meta(pos):get_int("work")>0 then return 0 end
    return stack:get_count()
   end,
   allow_metadata_inventory_move=function() return 0 end,
   on_receive_fields=function(pos,formname,fields,player)
    if fields.pack_machine then
     local ok,message=era.pack_machine(pos,player)
     if player and message then core.chat_send_player(player:get_player_name(),message) end
     if ok then core.close_formspec(player:get_player_name(),"") end
     return
    end
    if fields.upgrade then era.upgrade(pos,name,player) end
    era.ports_fields(pos,fields,player)
   end,
  })
 end
 function era.refresh(pos)
  local m=core.get_meta(pos); local def=era.machines[core.get_node(pos).name]
  if not def then return end
  local fault=m:get_string("fault")
  local profile=m:get_int("schema")==1 and "legacy" or m:get_string("profile")
  local diagnostic=fault~="" and (" | Paused: "..fault) or ""
  m:set_string("infotext",def.description.." | RF "..m:get_int("energy").." / "..era.capacity(pos,def).." | Work "..m:get_int("work")..diagnostic)
  m:set_string("formspec",era.machine_form(pos,def,fault,profile))
 end
 core.register_lbm({name="era_core:resume", nodenames={"group:era_machine","group:era_cable","group:era_ejector"},
  run_at_every_load=true, action=function(pos,node)
   era.track(pos)
   if era.machines[node.name] then era.refresh(pos) end
  end})
