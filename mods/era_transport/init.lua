-- SPDX-License-Identifier: GPL-3.0-or-later
-- Minimal fixed-direction transfer: output goes east (+X); ejector draws west.
core.register_node("era_transport:ejector",{description="Eastward Item Ejector (+X)",tiles={"era_ejector.png"},
 groups={cracky=2,pickaxey=1,era_ejector=1}, _mcl_hardness=2, _mcl_blast_resistance=3,
 on_construct=era.track, after_place_node=function(pos,player) core.get_meta(pos):set_string("owner",player:get_player_name()) end,
 on_destruct=function(pos) era.active[core.pos_to_string(pos)]=nil; era.invalidate() end})
function era.move_one(source,src_list,target,dst_list,actor)
 if core.is_protected(source,actor) or core.is_protected(target,actor) then return false end
 for _,pos in ipairs({source,target}) do
  local name=core.get_node(pos).name
  if era.machines[name] and not era.machine_ready(pos,name) then return false end
 end
 local a,b=core.get_meta(source):get_inventory(),core.get_meta(target):get_inventory()
 if a:get_size(src_list)==0 or b:get_size(dst_list)==0 then return false end
 local stack=a:get_stack(src_list,1); if stack:is_empty() then return false end
 local one=stack:peek_item(1)
 local targetname=core.get_node(target).name
 if era.machines[targetname] then
  if not era.recipe_for(target,targetname,one:get_name()) then return false end
  local input=b:get_stack(dst_list,1)
  if core.get_meta(target):get_int("work")>0 and input:get_name()~=one:get_name() then return false end
 end
 if not b:room_for_item(dst_list,one) then return false end
 local leftover=b:add_item(dst_list,one); assert(leftover:is_empty())
 stack:take_item(1); a:set_stack(src_list,1,stack); return true
end
function era.transport_step()
 local keys={}; for key in pairs(era.active) do keys[#keys+1]=key end; table.sort(keys)
 for _,key in ipairs(keys) do
  local pos=era.active[key]; local node=core.get_node_or_nil(pos)
  if node then
   local east=vector.add(pos,{x=1,y=0,z=0}); local target=core.get_node_or_nil(east)
   local owner=core.get_meta(pos):get_string("owner")
   if era.machines[node.name] and target and era.machines[target.name] then era.move_one(pos,"dst",east,"src",owner)
   elseif node.name=="era_transport:ejector" and target then
    -- Explicit allowlist: never bypass third-party locked inventories/callbacks.
    local west=vector.add(pos,{x=-1,y=0,z=0}); local source=core.get_node_or_nil(west)
    if source and era.machines[source.name] and (target.name=="mcl_chests:chest_small" or target.name=="mcl_chests:chest") then era.move_one(west,"dst",east,"main",owner) end
   end
  end
 end
end
core.register_craft({output="era_transport:ejector",recipe={{era.mcl.ingot,era.mcl.chest,era.mcl.redstone}}})
