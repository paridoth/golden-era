-- Checks the patched upstream recipe registration against the real guide API shape.
local path = assert(arg[1], "usage: lua5.1 test_elepower.lua PATCHED_ELEPOWER")
core={get_modpath=function(name) return name=="mcl_craftguide" and name or nil end}
minetest={get_modpath=core.get_modpath}
ele={translator=function(text) return text end}
elepm={}
local types,recipes={},{}
mcl_craftguide={
 register_craft_type=function(name,def)
  assert(def.description and def.icon);types[name]=def
 end,
 register_craft=function(def)
  assert(types[def.type] and def.width and def.output and def.items)
  recipes[#recipes+1]=def
 end,
}
function ItemStack(value)
 if type(value)=="userdata" then value=value:to_string() end
 local name,count=(value or ""):match("^(%S+)%s*(%d*)$")
 name=name or "";count=tonumber(count) or 1
 local stack=newproxy(true)
 getmetatable(stack).__index={
  get_name=function() return name end,
  get_count=function() return count end,
  set_count=function(_,n) count=n end,
  is_empty=function() return name=="" or count==0 end,
  to_string=function() return name..(count~=1 and " "..count or "") end,
 }
 return stack
end
dofile(path.."/elepower_machines/craft.lua")
elepm.register_craft_type("grind",{description="Grinding",inputs=1})
elepm.register_craft({type="grind",recipe={"test:ore"},output={"test:dust 2","test:gravel"}})
assert(#recipes==2 and recipes[1].output=="test:dust 2" and recipes[2].output=="test:gravel")
assert(recipes[1].items[1]=="test:ore" and recipes[1].width==1)
elepm.register_craft({type="grind",recipe={"test:raw 3"},output="test:dust 6"})
assert(#recipes==3 and recipes[3].output=="test:dust 6" and recipes[3].items[1]=="test:raw 3")
print("Mineclonia guide registration passed for single and multiple machine outputs")
