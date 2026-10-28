-- SPDX-License-Identifier: GPL-3.0-or-later
-- Smeltery structure checks and melting, on a simulated block grid.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local world,metas={},{}
local function key(p) return p.x..","..p.y..","..p.z end
vector={}
function vector.add(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
function vector.offset(a,x,y,z) return {x=a.x+x,y=a.y+y,z=a.z+z} end
function vector.copy(a) return {x=a.x,y=a.y,z=a.z} end
local function stack(name,count)
 local s={name=name,count=count or (name and 1 or 0)}
 function s:get_name() return self.count>0 and self.name or "" end
 function s:is_empty() return self.count==0 end
 function s:take_item(n) self.count=self.count-n end
 return s
end
ItemStack=function(t) local n,c=t:match("^(%S+)%s*(%d*)$");return stack(n,tonumber(c) or 1) end
core={registered_items={}}
function core.get_node(p) return world[key(p)] or {name="air",param2=0} end
function core.get_item_group(name,group) return (group=="seared" and (name=="era_playtest:seared_bricks" or name=="era_playtest:smeltery_controller")) and 1 or 0 end
function core.facedir_to_dir(p2) return ({[0]={x=0,y=0,z=1},{x=1,y=0,z=0},{x=0,y=0,z=-1},{x=-1,y=0,z=0}})[p2] end
function core.serialize(t) local parts={} for k,v in pairs(t) do parts[#parts+1]=k.."="..v end return table.concat(parts,";") end
function core.deserialize(s) if s=="" then return nil end local t={} for k,v in s:gmatch("(%w+)=(%d+)") do t[k]=tonumber(v) end return t end
function core.formspec_escape(s) return s end
function core.get_meta(p)
 local k=key(p)
 local m=metas[k] or {fields={},lists={melt={},fuel={stack(nil)}}}
 metas[k]=m
 local inv={}
 function inv:get_size(l) return #m.lists[l] end
 function inv:set_size(l,n) local old=m.lists[l] or {} m.lists[l]={} for i=1,n do m.lists[l][i]=old[i] or stack(nil) end end
 function inv:get_list(l) return m.lists[l] end
 function inv:get_stack(l,i) return m.lists[l][i] end
 function inv:set_stack(l,i,s) if type(s)=="string" then s=ItemStack(s) end m.lists[l][i]=s end
 return {get_string=function(_,f) return m.fields[f] or "" end,set_string=function(_,f,v) m.fields[f]=v end,
  get_float=function(_,f) return tonumber(m.fields[f]) or 0 end,set_float=function(_,f,v) m.fields[f]=v end,
  get_inventory=function() return inv end}
end
function core.add_item() end
for _,f in ipairs({"register_craftitem","register_node","register_craft","register_on_mods_loaded"}) do core[f]=function() end end
era_playtest={}
dofile(root.."/integrations/playtest/mod/smeltery.lua")

local function set(x,y,z,name,p2) world[key({x=x,y=y,z=z})]={name=name,param2=p2 or 0} end
-- A 3x3 interior from x=1..3, z=1..3, one layer, controller in the south wall facing out (+z into the room).
local function build(layers)
 world={}
 for x=1,3 do for z=1,3 do set(x,0,z,"era_playtest:seared_bricks") end end
 for y=1,layers do
  for i=1,3 do
   set(i,y,0,"era_playtest:seared_bricks");set(i,y,4,"era_playtest:seared_bricks")
   set(0,y,i,"era_playtest:seared_bricks");set(4,y,i,"era_playtest:seared_bricks")
  end
 end
 set(2,1,0,"era_playtest:smeltery_controller",0)
end
local controller={x=2,y=1,z=0}
build(1)
local shape=era_playtest.smeltery_scan(controller)
eq(shape and shape.volume,9,"A 3x3 one-layer smeltery")
build(2)
eq(era_playtest.smeltery_scan(controller).layers,2,"A second wall layer adds capacity")
set(3,0,3,"air")
local none,reason=era_playtest.smeltery_scan(controller)
eq(none,nil,"A hole in the floor breaks the structure");assert(reason:find("floor"),reason)
build(1);set(4,1,2,"mcl_core:cobble")
none,reason=era_playtest.smeltery_scan(controller)
eq(none,nil,"A non-seared wall breaks the structure");assert(reason:find("walls"),reason)
build(1);set(2,1,1,"mcl_core:cobble")
eq(era_playtest.smeltery_scan(controller),nil,"The block behind the controller must be air")

-- Melting: raw iron doubles, lava is consumed once, an ingot adds 144 mB.
build(1)
core.registered_items={}
era_playtest.smeltery_tick(controller,0)
local meta=core.get_meta(controller)
local inv=meta:get_inventory()
eq(inv:get_size("melt"),9,"One melting slot per interior block")
inv:set_stack("melt",1,stack("mcl_raw_ores:raw_iron",2))
inv:set_stack("melt",2,stack("mcl_core:iron_ingot",1))
for _=1,7 do era_playtest.smeltery_tick(controller,1) end
eq(era_playtest.smeltery_molten(meta).iron,nil,"Nothing melts without fuel")
inv:set_stack("fuel",1,stack("mcl_buckets:bucket_lava"))
for _=1,4 do era_playtest.smeltery_tick(controller,1) end
eq(inv:get_stack("fuel",1):get_name(),"mcl_buckets:bucket_empty","The lava bucket is emptied")
eq(era_playtest.smeltery_molten(meta).iron,144,"An ingot melts in 4 s")
for _=1,12 do era_playtest.smeltery_tick(controller,1) end
eq(era_playtest.smeltery_molten(meta).iron,144+2*288,"Two raw iron melt into four ingots of metal")
eq(inv:get_stack("melt",1):is_empty(),true,"Melted items are used up")
eq(meta:get_float("fuel"),150-16,"Fuel burns only while melting")
for _=1,5 do era_playtest.smeltery_tick(controller,1) end
eq(meta:get_float("fuel"),150-16,"Idle smeltery keeps its fuel")

-- A full smeltery waits instead of losing metal.
meta:set_string("molten","iron="..(9*8*144-100))
inv:set_stack("melt",3,stack("mcl_core:iron_ingot",1))
for _=1,6 do era_playtest.smeltery_tick(controller,1) end
eq(inv:get_stack("melt",3):is_empty(),false,"No melting past capacity")

-- Alloys mix in Elepower's ratios and keep the total volume.
local pool={copper=288,tin=144}
eq(era_playtest.smeltery_alloy(pool),true,"Copper and tin mix")
eq(pool.bronze,432,"Two copper and one tin make three bronze");eq(pool.copper,nil,"Copper used up");eq(pool.tin,nil,"Tin used up")
pool={copper=144,tin=144}
era_playtest.smeltery_alloy(pool)
eq(pool.bronze,216,"Copper limits the bronze");eq(pool.tin,72,"Spare tin stays molten")
pool={iron=432,nickel=144,gold=576}
era_playtest.smeltery_alloy(pool)
eq(pool.electrum,864,"Invar made in the same step mixes into electrum");eq(pool.invar,288,"Spare invar stays");eq(pool.gold,nil,"Gold used up")
pool={copper=144,iron=144}
eq(era_playtest.smeltery_alloy(pool),false,"Unrelated metals do not mix")
pool={copper=8,tin=4}
eq(era_playtest.smeltery_alloy(pool),false,"Less than one part does not mix")
-- The controller mixes on its tick, even without fuel.
meta:set_string("molten","copper=288;tin=144")
meta:set_float("fuel",0)
inv:set_stack("melt",3,stack(nil))
era_playtest.smeltery_tick(controller,1)
eq(era_playtest.smeltery_molten(meta).bronze,432,"The smeltery mixes bronze")
print("SMELTERY PASS: structure size/layers/holes/walls, lava fuel, ore doubling, idle fuel kept, capacity respected, alloys")
