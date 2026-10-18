-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native tool/interaction; its reviewed crafting pattern lives in the catalog.
core.register_tool("era_core:wrench",{
 description="Factory Wrench",inventory_image="era_ejector.png",
 groups={tool=1},_mcl_toollike_wield=true,
 on_place=function(itemstack,player,pointed)
  if not player or not pointed or pointed.type~="node" then return itemstack end
  if not era.machines[core.get_node(pointed.under).name] then return itemstack end
  if not player:get_player_control().sneak then
   core.chat_send_player(player:get_player_name(),"Sneak and right-click to pack this machine, or use its Pack machine button.")
   return itemstack
  end
  local ok,message=era.pack_machine(pointed.under,player)
  if message then core.chat_send_player(player:get_player_name(),message) end
  return itemstack
 end,
})
