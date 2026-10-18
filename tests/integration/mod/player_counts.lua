-- SPDX-License-Identifier: GPL-3.0-or-later
-- Real chest/ItemStacks and the registered game callbacks; no network mouse event.
return function(_,place,eq)
 local pos=vector.new(48,200,24)
 local playername="era_inventory_count_regression"
 local detached_name="era_integration_player_counts"
 local inventory=assert(core.create_detached_inventory(detached_name,{}))
 inventory:set_size("main",36)
 local meta_stack=ItemStack(era.mcl.ingot)
 local player_meta=meta_stack:get_meta()
 player_meta:set_int("mcl_inventory:switch_stack",64)
 local player={
  get_player_name=function() return playername end,
  get_inventory=function() return inventory end,
  get_meta=function() return player_meta end,
 }
 local old_creative=core.is_creative_enabled
 local creative=false
 -- Change the mode only for this fake player and restore it even after failure.
 core.is_creative_enabled=function(name)
  if name==playername then return creative end
  return old_creative(name)
 end
 -- The documentation callback expects its join-initialized player record.
 local old_doc_player=doc.data.players[playername]
 doc.data.players[playername]={stored_data={revealed={},revealed_count={},notify_on_reveal=false}}
 local ok,err=xpcall(function()
  eq(core.settings:get_bool("creative_mode",false),false,"count regression world uses survival mode")
  place(pos,"mcl_chests:chest_small")
  local chest=core.get_meta(pos):get_inventory()
  local definition=core.registered_nodes[core.get_node(pos).name]
  assert(#core.registered_on_player_inventory_actions>0,"real game inventory callbacks registered")
  eq(ItemStack(era.mcl.ingot):get_stack_max(),64,"Mineclonia iron stack limit")
  for _,mode in ipairs({true,false}) do
   creative=mode
   for _,count in ipairs({1,4}) do
    inventory:set_list("main",{})
    chest:set_list("main",{})
    local source=ItemStack(era.mcl.ingot.." "..count)
    chest:set_stack("main",1,source)
    eq(definition.allow_metadata_inventory_take(pos,"main",1,source,player),count,"ordinary chest permits actual count")
    local withdrawn=chest:remove_item("main",source)
    eq(withdrawn:get_count(),count,"real chest withdrawal count")
    assert(chest:is_empty("main"),"withdrawal empties its source without duplication")
    inventory:set_stack("main",1,withdrawn)
    -- Simulate the engine's post-transfer callback arguments. The detached
    -- inventory supplies a genuine InvRef without creating a network player.
    for _,callback in ipairs(core.registered_on_player_inventory_actions) do
     callback(player,"put",inventory,{listname="main",index=1,stack=ItemStack(withdrawn)})
    end
    eq(inventory:get_stack("main",1):get_name(),era.mcl.ingot,"withdrawal item identity")
    eq(inventory:get_stack("main",1):get_count(),mode and 64 or count,
     mode and "reproduce creative callback expansion" or "survival callback preserves actual count")
    assert(chest:is_empty("main"),"callbacks do not refill ordinary chest")
   end
  end
 end,debug.traceback)
 core.is_creative_enabled=old_creative
 doc.data.players[playername]=old_doc_player
 core.remove_detached_inventory(detached_name)
 if not ok then error(err) end
 core.log("action","ERA INTEGRATION PLAYER_COUNTS PASS: real ordinary chest withdraws 1/4; registered Mineclonia callbacks reproduce creative expansion to 64 and preserve survival counts (callback-level fixture)")
 core.request_shutdown("Player inventory count phase passed",false,0)
end
