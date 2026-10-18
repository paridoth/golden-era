-- Runs the patched upstream buffer and Node IO functions with in-memory nodes.
local path = assert(arg[1], "usage: lua5.1 test_fluid.lua PATCHED_FLUID_LIB")
local fields = {}
local meta = {
 get_string=function(_,key) return fields[key] or "" end,
 get_int=function(_,key) return fields[key] or 0 end,
 set_string=function(_,key,value) fields[key]=value end,
 set_int=function(_,key,value) fields[key]=value end,
}
local node={name="test:tank"}
minetest = {
 registered_nodes={["test:tank"]={groups={fluid_container=1},fluid_buffers={
  first={capacity=1100,accepts=true},second={capacity=600,accepts=true},
 }}},
 get_node_or_nil=function() return node end,
 get_meta=function() return meta end,
 get_item_group=function(name,group)
  local def=minetest.registered_nodes[name]
  return def and def.groups[group] or 0
 end,
 override_item=function(name,def)
  for key,value in pairs(def) do minetest.registered_nodes[name][key]=value end
 end,
}
fluid_lib={}
dofile(path.."/fluid_lib/buffer.lua")
dofile(path.."/fluid_lib/nodeio.lua")
fluid_lib.register_node("test:tank")
local pos={x=0,y=0,z=0}
local water="test:water_source"
fields.first_fluid=water; fields.first_fluid_storage=900
assert(fluid_lib.insert_into_buffer(pos,"first",water,1000)==800)
assert(fields.first_fluid_storage==1100)
local tank=minetest.registered_nodes[node.name]
-- Empty buffers accept in any table iteration order; total + remainder conserved.
local left=tank.node_io_put_liquid(pos,node,"N",nil,water,1000)
assert(left==400)
assert(fields.first_fluid_storage+fields.second_fluid_storage==1700)
assert(tank.node_io_put_liquid(pos,node,"N",nil,water,1000)==1000)
local fluid,taken=fluid_lib.take_from_buffer(pos,"first",500)
assert(fluid==water and taken==500 and fields.first_fluid_storage==600)
-- A rejected buffer must not cause the same remainder to be counted twice.
fields.second_fluid="test:lava_source"; fields.second_fluid_storage=600
left=tank.node_io_put_liquid(pos,node,"N",nil,water,1000)
assert(left==500 and fields.first_fluid_storage==1100)
assert(fields.second_fluid=="test:lava_source" and fields.second_fluid_storage==600)
print("fluid buffer partial, full, mixed-fluid and multi-buffer conservation passed")
