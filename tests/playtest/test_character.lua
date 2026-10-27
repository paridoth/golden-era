-- SPDX-License-Identifier: GPL-3.0-or-later
-- The single-player character and the menu host's name share one inventory.
local root=assert(arg[1],"repository root required")
local joins,leaves,config,chats,logs={},{},{},{},{}
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function stack(text) return {to_string=function()return text end} end
local function player(name,items,pos,fields)
 local lists={main={}}
 for i,item in ipairs(items) do lists.main[i]=stack(item) end
 local meta_fields=fields or {}
 local p={name=name,pos=pos,hp=20,breath=10,look_h=0,look_v=0}
 local inv={}
 function inv:get_lists() return lists end
 function inv:get_size(listname) return #(lists[listname] or {}) end
 function inv:set_size() end
 function inv:set_list(listname,items)
  lists[listname]={}
  for i,item in ipairs(items) do lists[listname][i]=stack(item) end
 end
 function p:items() local out={} for i,s in ipairs(lists.main) do out[i]=s:to_string() end return table.concat(out,",") end
 function p:give(list) inv:set_list("main",list) end
 function p:get_player_name() return self.name end
 function p:get_inventory() return inv end
 function p:get_pos() return self.pos end
 function p:set_pos(value) self.pos=value end
 function p:get_hp() return self.hp end
 function p:set_hp(value) self.hp=value end
 function p:get_breath() return self.breath end
 function p:set_breath(value) self.breath=value end
 function p:get_look_horizontal() return self.look_h end
 function p:set_look_horizontal(value) self.look_h=value end
 function p:get_look_vertical() return self.look_v end
 function p:set_look_vertical(value) self.look_v=value end
 function p:get_meta()
  return {to_table=function() local copy={} for k,v in pairs(meta_fields) do copy[k]=v end return {fields=copy} end,
   from_table=function(_,data) meta_fields={} for k,v in pairs(data.fields) do meta_fields[k]=v end end,
   field=function(_,key) return meta_fields[key] end}
 end
 return p
end
local stored={}
core={settings={get=function(_,key) return config[key] end}}
function core.get_mod_storage()
 return {get_string=function(_,key) return stored[key] or "" end,set_string=function(_,key,value) stored[key]=value end}
end
function core.is_singleplayer() return config.singleplayer end
function core.serialize(value) return value end
function core.deserialize(value) return value end
function core.register_on_joinplayer(callback) joins[#joins+1]=callback end
function core.register_on_leaveplayer(callback) leaves[#leaves+1]=callback end
function core.register_on_shutdown() end
function core.register_globalstep() end
function core.get_connected_players() return {} end
function core.chat_send_player(name,text) chats[#chats+1]={name=name,text=text} end
function core.log(_,text) logs[#logs+1]=text end
era_playtest={}
dofile(root.."/integrations/playtest/mod/character.lua")
local function join(p) for _,callback in ipairs(joins) do callback(p) end end
local function leave(p) for _,callback in ipairs(leaves) do callback(p) end end

-- Hosting before the world was played alone with this version: nothing to bring yet.
config.singleplayer=false;config.name="alpha"
local early=player("alpha",{},"host spawn",{})
join(early)
eq(#chats,1,"Host is told how to bring single-player items");eq(chats[1].name,"alpha","Hint goes to the host")
eq(early:items(),"","Nothing is invented for the host")
stored={};chats={}

-- Playing alone saves the character.
config.singleplayer=true;config.name="alpha"
local solo=player("singleplayer",{"mcl_tools:pick_iron","mcl_core:cobble 30"},"mine",{xp="120",era_playtest_joined="1"})
join(solo);solo:give({"mcl_tools:pick_iron","mcl_core:cobble 45"});solo.pos="base";leave(solo)
eq(#chats,0,"No hint in single player")

-- Hosting the same world: the host continues as that character.
config.singleplayer=false
local host=player("alpha",{"mcl_core:dirt 1"},"host spawn",{})
join(host)
eq(host:items(),"mcl_tools:pick_iron,mcl_core:cobble 45","Host receives the single-player inventory")
eq(host.pos,"base","Host starts where the character was")
eq(host:get_meta():field("xp"),"120","Host keeps experience")
eq(host:get_meta():field("era_playtest_joined"),"1","Host is not offered the first-join choice again")
eq(#chats,0,"No hint once the character was handed over")

-- A friend on the LAN keeps their own character and does not overwrite the host's.
local friend=player("beta",{"mcl_core:apple 3"},"friend spawn",{})
join(friend);leave(friend)
eq(friend:items(),"mcl_core:apple 3","Friend keeps their own items")

-- Progress made while hosting comes back to single player, with no duplicate.
host:give({"mcl_tools:pick_diamond"});host.pos="far away";leave(host)
config.singleplayer=true
local again=player("singleplayer",{"mcl_tools:pick_iron","mcl_core:cobble 45"},"base",{xp="120"})
join(again)
eq(again:items(),"mcl_tools:pick_diamond","Single player continues with the hosted progress")
eq(again.pos,"far away","Single player resumes where the host stopped")

-- Rejoining as the same character changes nothing.
again:give({"mcl_tools:pick_diamond","mcl_core:torch 4"});leave(again);join(again)
eq(again:items(),"mcl_tools:pick_diamond,mcl_core:torch 4","The latest owner keeps its own state")

-- A LAN player who calls themselves "singleplayer" is not the host.
config.singleplayer=false
local impostor=player("singleplayer",{},"spawn",{})
join(impostor)
eq(impostor:items(),"","Only the host name is linked on a server")
print("CHARACTER PASS: single-player items follow the host and back; friends and impostors unaffected; hint before first hand-over")
