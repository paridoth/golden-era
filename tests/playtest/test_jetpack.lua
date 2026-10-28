-- SPDX-License-Identifier: GPL-3.0-or-later
-- Jetpack flight modes, charge drain and the safety reset.
local root=assert(arg[1],"repository root required")
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local tool,steps,joins,leaves,crafts,chats=nil,{},{},{},{},{}
local factors={}
ele={tools={}}
function ele.register_tool(name,def) tool={name=name,def=def} end
function ele.tools.get_tool_property(stack,key) return stack.meta[key] or (key=="capacity" and 16000 or 0) end
function ele.tools.update_tool_wear(stack) return stack end
playerphysics={add_physics_factor=function(_,attr,id,v) factors[attr..id]=v end,
 remove_physics_factor=function(_,attr,id) factors[attr..id]=nil end}
core={}
function core.register_globalstep(f) steps[#steps+1]=f end
function core.register_on_joinplayer(f) joins[#joins+1]=f end
function core.register_on_leaveplayer(f) leaves[#leaves+1]=f end
function core.register_craft(def) crafts[#crafts+1]=def end
function core.chat_send_player(_,text) chats[#chats+1]=text end
local players={}
function core.get_connected_players() return players end
era_playtest={}
dofile(root.."/integrations/playtest/mod/jetpack.lua")
eq(tool.name,"era_playtest:jetpack","Jetpack is an Elepower tool, so power cells charge it")
eq(#crafts,1,"Jetpack has a recipe")

local m=era_playtest.jetpack_mode
eq(m({jump=true},0),"lift","Jump lifts")
eq(m({jump=true},6),"coast","Lift stops accelerating at top speed")
eq(m({sneak=true},-5),"brake","Sneak during a fast fall brakes")
eq(m({sneak=true},-2),"glide","Sneak while falling slowly glides")
eq(m({sneak=true},0),nil,"Sneak on the ground is ordinary sneaking")
eq(m({},-5),nil,"No controls, no flight")

local function stack(name,storage)
 local s={name=name,meta={storage=storage}}
 function s:get_name() return self.name end
 function s:get_meta() return {set_int=function(_,k,v) s.meta[k]=v end} end
 return s
end
local jet=stack("era_playtest:jetpack",100)
local list={stack("mcl_core:dirt",0),jet}
local control,vy={jump=true},0
local p={}
function p:get_player_name() return "alpha" end
function p:get_inventory() return {get_list=function() return list end,set_stack=function(_,_,i,s) list[i]=s end} end
function p:get_player_control() return control end
function p:get_velocity() return {x=0,y=vy,z=0} end
players={p}
local function run(seconds) for _=1,seconds*10 do for _,f in ipairs(steps) do f(0.1) end end end

run(1)
eq(factors["gravityera_playtest:jetpack"],-0.6,"Holding jump reverses gravity")
-- 40 per second, written once at least 10 is owed: 36 written, 4 pending.
eq(jet.meta.storage,64,"Lift uses 40 per second")
control={};run(0.2)
eq(factors["gravityera_playtest:jetpack"],nil,"Releasing jump restores gravity")
control={jump=true};run(2)
eq(jet.meta.storage,0,"Charge runs out")
eq(factors["gravityera_playtest:jetpack"],nil,"An empty jetpack stops lifting")
assert(chats[#chats]:find("out of charge",1,true),"The player is told to recharge")
run(1)
eq(factors["gravityera_playtest:jetpack"],nil,"An empty jetpack does not restart")

-- A gravity factor left by a crash is cleared on join.
factors["gravityera_playtest:jetpack"]=-0.6
for _,f in ipairs(joins) do f(p) end
eq(factors["gravityera_playtest:jetpack"],nil,"Joining clears a stale lift")
print("JETPACK PASS: lift, coast, brake, glide, charge drain, empty stop, stale lift cleared")
