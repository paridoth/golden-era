-- SPDX-License-Identifier: GPL-3.0-or-later
-- Look-at information names the mod and shows power and container use.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local nodes,metas={},{}
local function stack(name) return {is_empty=function() return name==nil end} end
core={registered_nodes={
 ["elepower_machines:generator"]={description="Coal-fired Generator\nPower source",ele_capacity=8000},
 ["mcl_barrels:barrel_closed"]={description="\27(T@mcl_barrels)Barrel\27E"},
 ["air"]={description="Air"}}}
function core.get_node(pos) return {name=nodes[pos] or "air"} end
function core.get_meta(pos)
 local m=metas[pos] or {ints={},list={}}
 return {get_int=function(_,k) return m.ints[k] or 0 end,
  get_inventory=function() return {get_size=function() return #m.list end,get_list=function() return m.list end} end}
end
function core.get_translated_string(_,text) return (text:gsub("\27%(T@[^)]*%)",""):gsub("\27E","")) end
function core.strip_colors(text) return text end
function core.register_chatcommand() end
function core.register_on_leaveplayer() end
function core.register_globalstep() end
era_playtest={}
dofile(root.."/integrations/playtest/mod/lookinfo.lua")
eq(era_playtest.mod_title("elepower_machines:pulverizer"),"Elepower","Elepower mods share one title")
eq(era_playtest.mod_title("mcl_core:stone"),"Mineclonia","Mineclonia mods share one title")
eq(era_playtest.mod_title("mcl_extra_structures:x"),"Extra Structures","Extra structures are not Mineclonia")
eq(era_playtest.mod_title("some_new_mod:thing"),"Some new mod","Unknown mods get a readable name")
nodes.gen="elepower_machines:generator";metas.gen={ints={storage=1200},list={}}
local lines=era_playtest.look_lines("gen")
eq(lines[1],"Coal-fired Generator  [Elepower]","First description line and mod")
eq(lines[2],"Power: 1200 / 8000 EpU","Stored power from the node's capacity")
metas.gen.ints.capacity=16000
eq(era_playtest.look_lines("gen")[2],"Power: 1200 / 16000 EpU","Upgraded capacity in metadata wins")
nodes.barrel="mcl_barrels:barrel_closed";metas.barrel={ints={},list={stack("a"),stack(nil),stack("b")}}
lines=era_playtest.look_lines("barrel")
eq(lines[1],"Barrel  [Mineclonia]","Translation markers are removed")
eq(lines[2],"Slots used: 2 / 3","Container use")
eq(#lines,2,"No power line for unpowered blocks")
eq(era_playtest.look_lines("nothing"),nil,"Air shows nothing")
print("LOOKINFO PASS: mod titles, stored power, container use, translated names, air ignored")
