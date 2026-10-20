local newly_emitted={}
local native_add=core.add_item
core.add_item=function(pos,stack,...)
 local result=native_add(pos,stack,...)
 if pos.x>=-8 and pos.x<=10 and pos.z>=-12 and pos.z<=4 and pos.y>=198 and pos.y<=218 then
  newly_emitted[#newly_emitted+1]={item=ItemStack(stack):to_string(),pos=pos,actual=result and result:get_luaentity().itemstring or "creation_failed"}
 end
 return result
end
core.register_node("era_tree_audit:marker",{drawtype="airlike",walkable=false,pointable=false})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.load_area(vector.new(-16,192,-16),vector.new(63,223,15))
  for x=-1,3 do for z=-1,0 do for y=12,13 do assert(core.forceload_block(vector.new(x*16,y*16,z*16),true)~=false) end end end
 end)
 core.after(12,function()
 local objects={}
 for _,obj in ipairs(core.get_objects_inside_radius(vector.new(0,205,-4),24)) do
  local e=obj:get_luaentity()
  if e and e.name=="__builtin:item" then objects[#objects+1]={item=e.itemstring,pos=obj:get_pos()} end
 end
 local packets={}
 for _,e in pairs(pipeworks.luaentity.entities or {}) do if e.name=="pipeworks:tubed_item" then packets[#packets+1]={item=e.itemstring,pos=e:get_pos()} end end
 local function list(pos,n) local out={};for _,s in ipairs(core.get_meta(pos):get_inventory():get_list(n) or {}) do if not s:is_empty() then out[#out+1]=s:to_string() end end;return out end
 local out={newly_emitted=newly_emitted,ground=objects,packets=packets,planter=list(vector.new(0,198,-4),"src"),harvester=list(vector.new(0,200,0),"dst"),barrel=list(vector.new(5,200,0),"main")}
 core.safe_file_write(core.get_worldpath().."/reader.json",core.write_json(out,true));core.log("action","ERA TREE READER: "..core.write_json(out));core.request_shutdown("Native saved-world reader",false,0)
 end) end)
