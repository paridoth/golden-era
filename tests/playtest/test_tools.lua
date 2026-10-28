-- SPDX-License-Identifier: GPL-3.0-or-later
-- Area tools: the 3x3 square a hammer or excavator digs, the logs a lumber
-- axe fells, and the casts and tool kinds behind them.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local crafts,casts={},{}
core={}
function core.register_craftitem()end
function core.register_craft(def) crafts[#crafts+1]=def end
function core.register_craft_predict()end
function core.register_on_craft()end
function core.register_on_dignode()end
function core.hash_node_position(p) return p.x..","..p.y..","..p.z end
vector={new=function(x,y,z) return {x=x,y=y,z=z} end}
mcl_tools={register_set=function() end,tool_place_funcs={pick="P",shovel="S",axe="A"},
 commondefs={pick={groups={pickaxe=1}},shovel={groups={shovel=1},usagehelp="paths"},axe={groups={axe=1}}}}
era_playtest={metal_colors={},metal_label=function(m) return m end,smeltery_product=function() end,
 register_table_cast=function(cast,shape,amount) casts[cast]={shape=shape,amount=amount} end}
dofile(root.."/integrations/playtest/mod/tools.lua")

-- Tool kinds and casts.
eq(mcl_tools.commondefs.hammer.diggroups.pickaxey~=nil,true,"A hammer digs like a pickaxe")
eq(mcl_tools.tool_place_funcs.excavator,"S","An excavator makes paths like a shovel")
eq(mcl_tools.tool_place_funcs.lumberaxe,"A","A lumber axe strips logs like an axe")
eq(casts["era_playtest:cast_hammer_head"].amount,864,"A hammer head takes six ingots")
eq(casts["era_playtest:cast_excavator_head"].amount,576,"An excavator head takes four ingots")
local widened=false
for _,c in ipairs(crafts) do
 if c.output=="era_playtest:cast_hammer_head" then
  widened=c.recipe[1]=="era_playtest:cast_pick_head" and #c.recipe==5
 end
end
eq(widened,true,"A pickaxe head cast and four seared bricks make a hammer head cast")

-- The square lies across the direction the player looks.
local function key(p) return p.x..","..p.y..","..p.z end
local function set(list) local s={} for _,p in ipairs(list) do s[key(p)]=true end return s end
local all=function() return true end
local o={x=0,y=10,z=0}
local down=set(era_playtest.plane_targets(o,{x=0.1,y=-0.9,z=0.2},all))
eq(down["1,10,1"] and down["-1,10,-1"] and not down["0,11,0"],true,"Digging down clears a flat square")
local east=set(era_playtest.plane_targets(o,{x=0.9,y=0.3,z=0.1},all))
eq(east["0,11,1"] and east["0,9,-1"] and not east["1,10,0"],true,"Digging east clears a wall facing east")
local north=set(era_playtest.plane_targets(o,{x=0.2,y=0.1,z=-0.9},all))
eq(north["1,11,0"] and not north["0,10,1"],true,"Digging north clears a wall facing north")
eq(#era_playtest.plane_targets(o,{x=0,y=-1,z=0},all),8,"The other eight blocks of the square")
eq(#era_playtest.plane_targets(o,{x=0,y=-1,z=0},function(p) return p.x==1 end),3,"Blocks the tool cannot dig stay")

-- A trunk with a branch and leaves on top is felled; nothing below the cut.
local logs,leaves={},{}
for y=0,5 do logs["0,"..y..",0"]=true end
logs["1,4,0"]=true logs["2,5,1"]=true logs["0,-1,0"]=true
leaves["0,6,0"]=true
local is_log=function(p) return logs[key(p)] end
local is_leaves=function(p) return leaves[key(p)] end
local felled=set(era_playtest.tree_targets({x=0,y=1,z=0},is_log,is_leaves))
eq(felled["0,5,0"] and felled["2,5,1"] and felled["1,4,0"],true,"The trunk and its branches fall")
eq(felled["0,-1,0"] or felled["0,0,0"],nil,"Logs below the cut stay")
leaves={}
eq(#era_playtest.tree_targets({x=0,y=1,z=0},is_log,is_leaves),0,"Logs without leaves are building, not a tree")
print("TOOLS PASS: 3x3 squares follow the view, blocks the tool cannot dig stay, trees fell above the cut, log walls stay, large-head casts")
