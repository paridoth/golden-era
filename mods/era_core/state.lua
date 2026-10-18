-- SPDX-License-Identifier: GPL-3.0-or-later
-- Schema 1 remains readable until validation commits an idempotent migration.
era.state_fields={"energy","work","burn","water","fuel_rf","water_rf"}
function era.state(pos)
 local m=core.get_meta(pos)
 local s={schema=m:get_int("schema"),profile=m:get_int("schema")==1 and "legacy" or m:get_string("profile")}
 for _,key in ipairs(era.state_fields) do s[key]=m:get_int(key) end
 return s
end
function era.save(pos,s)
 local m=core.get_meta(pos)
 for _,key in ipairs({"energy","work","burn"}) do m:set_int(key,s[key]) end
 local profile=s.profile or (m:get_int("schema")==2 and m:get_string("profile"))
 if profile then
  for _,key in ipairs({"water","fuel_rf","water_rf"}) do m:set_int(key,s[key] or m:get_int(key)) end
  m:set_string("profile",profile)
  m:set_int("schema",2) -- commit marker last; schema-1 originals stay intact during preparation
 else m:set_int("schema",1) end
end
function era.capacity(pos,def,state)
 state=state or era.state(pos)
 return state.profile=="revelation" and def.capacity or def.legacy_capacity
end
function era.recipe_for(pos,name,input)
 local recipes=era.state(pos).profile=="revelation" and era.native_recipes or era.recipes
 return (recipes[name] or {})[input]
end
function era.migrate(pos,state)
 if state.schema~=1 then return end
 state.schema=2; state.profile="legacy"
 state.water=0; state.fuel_rf=0; state.water_rf=0
 local m=core.get_meta(pos)
 local inv=m:get_inventory()
 for _,list in ipairs({"water","empty"}) do if inv:get_size(list)==0 then inv:set_size(list,1) end end
 era.save(pos,state)
 m:set_string("migration","schema1-preserved-as-legacy")
 era.refresh(pos)
end
function era.upgrade(pos,name,player)
 if not era.allowed(pos,player) or not era.machine_ready(pos,name) then return false end
 local s=era.state(pos); local m=core.get_meta(pos)
 if s.profile~="legacy" or s.burn~=0 or s.work~=0 or m:get_string("job")~="" then return false end
 -- All target capacities are larger. Inventories and stored RF are preserved.
 s.profile="revelation"; era.save(pos,s); era.refresh(pos); era.invalidate()
 return true
end
