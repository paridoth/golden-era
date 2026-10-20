-- SPDX-License-Identifier: GPL-3.0-or-later
-- Execute the actual copied switch_state function under different table orders.
local file=assert(io.open(assert(arg[1]),"r"))
local source=file:read("*a");file:close()
local definition=assert(source:match("ele%.default%.states = (%b{})"))
local body=assert(source:match("(local function switch_state.-)\n%-%- Patch a table"))
local function eq(a,b,label)assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local meta={state=0,keepsake="unchanged"}
function meta:get_int(name)eq(name,"state","Only read state");return self.state end
function meta:set_int(name,value)eq(name,"state","Only write state");self.state=value end
local ticks=0
local sandbox={table=table,ipairs=ipairs,S=function(s)return s end,
 core={get_meta=function(pos)eq(pos,"fixture","Position unchanged");return meta end},
 ele={default={},helpers={start_timer=function(pos)eq(pos,"fixture","Timer position");ticks=ticks+1 end}}}
local read=assert(loadstring("return "..definition));setfenv(read,sandbox)
sandbox.ele.default.states=read()
local order={1,2,3,0}
sandbox.pairs=function(t)
 eq(t,sandbox.ele.default.states,"Enumerate native states")
 local index=0
 return function()index=index+1;local id=order[index];if id~=nil then return id,t[id] end end
end
local compile=assert(loadstring(body.."\nreturn switch_state"));setfenv(compile,sandbox)
local switch=compile()
local function sequence(groups,initial,expected)
 meta.state=initial;ticks=0
 for i,id in ipairs(expected) do
  switch("fixture",groups);eq(meta.state,id,"Expected state after press "..i)
  eq(ticks,i,"Exactly one native timer wake per press")
 end
 eq(meta.keepsake,"unchanged","Unrelated metadata unchanged")
end
for _,ids in ipairs({{1,2,3,0},{3,0,2,1},{0,1,2,3}}) do
 order=ids
 sequence({toggle=true,mesecons=true},0,{1,2,3,0,1})
 sequence({toggle=true,mesecons=false},0,{1,0,1,0})
 sequence({toggle=false,mesecons=true},2,{3,2,3,2})
 sequence({toggle=true},99,{0,1,0})
 sequence({mesecons=true},-7,{2,3,2})
 meta.state=99;ticks=0
 switch("fixture",{toggle=false,mesecons=false})
 eq(meta.state,99,"No eligible state preserves metadata");eq(ticks,0,"No eligible state does not wake timer")
end
print("Machine state switch tests passed")
