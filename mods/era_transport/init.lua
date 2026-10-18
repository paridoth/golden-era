-- SPDX-License-Identifier: GPL-3.0-or-later
-- Guarded native item-side transfer and configurable chest ejector.
local names={dst="Primary",secondary="Byproduct",src="Unreserved input"}
local function ejector_config(pos)
 local m=core.get_meta(pos); local raw=m:get_string("eject_face"); local list=m:get_string("eject_list")
 if raw=="" and list=="" then return 5,"dst" end -- old eastward node
 local face=tonumber(raw)
 if not era.valid_integer(face,0) or face>5 or not names[list] then return end
 return face,list
end
local function refresh_ejector(pos)
 local face,list=ejector_config(pos); local m=core.get_meta(pos)
 if not face then m:set_string("infotext","Item Ejector | Paused: invalid configuration"); return end
 local directions={"Down","Up","North","South","West","East"}
 m:set_string("infotext","Item Ejector | "..directions[face+1].." | "..names[list])
 m:set_string("formspec","formspec_version[4]size[6,3]button[0.5,0.5;5,0.7;direction;Direction: "..directions[face+1].."]button[0.5,1.5;5,0.7;output;Source: "..names[list].."]")
end
core.register_node("era_transport:ejector",{description="Configurable Item Ejector",tiles={"era_ejector.png"},
 groups={cracky=2,pickaxey=1,era_ejector=1}, _mcl_hardness=2, _mcl_blast_resistance=3,
 on_construct=function(pos)
  local m=core.get_meta(pos); m:set_int("eject_face",5); m:set_string("eject_list","dst"); refresh_ejector(pos); era.track(pos)
 end,
 after_place_node=function(pos,player) core.get_meta(pos):set_string("owner",player:get_player_name()) end,
 on_receive_fields=function(pos,form,fields,player)
  if not era.allowed(pos,player) then return end
  local face,list=ejector_config(pos); if not face then return end
  local m=core.get_meta(pos)
  if fields.direction then m:set_int("eject_face",(face+1)%6) end
  if fields.output then m:set_string("eject_list",({dst="secondary",secondary="src",src="dst"})[list]) end
  refresh_ejector(pos)
 end,
 on_destruct=function(pos) era.active[core.pos_to_string(pos)]=nil; era.invalidate() end})
function era.move_one(source,src_list,target,dst_list,actor)
 if core.is_protected(source,actor) or core.is_protected(target,actor) then return false end
 for _,pos in ipairs({source,target}) do
  local name=core.get_node(pos).name
  if era.machines[name] and not era.machine_ready(pos,name) then return false end
 end
 local source_name=core.get_node(source).name
 if era.machines[source_name] then
  if src_list=="src" and core.get_meta(source):get_int("work")>0 then return false end
  if not era.port_allows(source,era.face_between(source,target),src_list,false) then return false end
 end
 local a,b=core.get_meta(source):get_inventory(),core.get_meta(target):get_inventory()
 if a:get_size(src_list)==0 or b:get_size(dst_list)==0 then return false end
 local stack=a:get_stack(src_list,1); if stack:is_empty() then return false end
 local one=stack:peek_item(1)
 local targetname=core.get_node(target).name
 if era.machines[targetname] then
  if dst_list~="src" or not era.port_allows(target,era.face_between(target,source),dst_list,true) then return false end
  if not era.recipe_for(target,targetname,one:get_name()) then return false end
  local input=b:get_stack(dst_list,1)
  if core.get_meta(target):get_int("work")>0 and input:get_name()~=one:get_name() then return false end
 end
 if not b:room_for_item(dst_list,one) then return false end
 local leftover=b:add_item(dst_list,one); assert(leftover:is_empty())
 stack:take_item(1); a:set_stack(src_list,1,stack); return true
end
local function chest(node)
 return node and (node.name=="mcl_chests:chest_small" or node.name=="mcl_chests:chest")
end
function era.transport_step()
 local keys={}; for key in pairs(era.active) do keys[#keys+1]=key end; table.sort(keys)
 for _,key in ipairs(keys) do
  local pos=era.active[key]; local node=core.get_node_or_nil(pos)
  if node then
   local meta=core.get_meta(pos); local owner=meta:get_string("owner")
   if era.machines[node.name] then
    if meta:get_string("profile")=="revelation" and meta:get_string("item_ports_version")=="1" then
     if meta:get_string("auto_output")=="1" then
      for _,direction in ipairs(era.faces) do
       local target_pos=vector.add(pos,direction); local target=core.get_node_or_nil(target_pos)
       if target and (era.machines[target.name] or chest(target)) then
        for _,list in ipairs({"dst","secondary"}) do era.move_one(pos,list,target_pos,chest(target) and "main" or "src",owner) end
       end
      end
     end
    else
     local east=vector.add(pos,era.faces[6]); local target=core.get_node_or_nil(east)
     if target and era.machines[target.name] then era.move_one(pos,"dst",east,"src",owner) end
    end
   elseif node.name=="era_transport:ejector" then
    local face,list=ejector_config(pos)
    if face then
     local direction=era.faces[face+1]; local target_pos=vector.add(pos,direction); local target=core.get_node_or_nil(target_pos)
     local source_pos=vector.subtract(pos,direction); local source=core.get_node_or_nil(source_pos)
     if source and era.machines[source.name] and chest(target) then era.move_one(source_pos,list,target_pos,"main",owner) end
    else refresh_ejector(pos) end
   end
  end
 end
end

core.register_craft({output="era_transport:ejector",recipe={{era.mcl.ingot,era.mcl.chest,era.mcl.redstone}}})
