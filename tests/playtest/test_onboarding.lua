-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise first-join event order, duplicate submissions and preserved save metadata.
local root=assert(arg[1],"repository root required")
local joins,receivers,commands,timers,players,forms,config,privileges={},{},{},{},{},{},{},{}
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function meta()
 local data={}
 return {get_int=function(_,key)return tonumber(data[key]) or 0 end,
  set_int=function(_,key,value)data[key]=value end,
  get_string=function(_,key)return data[key] or "" end,
  set_string=function(_,key,value)data[key]=value end}
end
local function player(name)
 local p={name=name,pos="natural spawn",meta=meta(),items={},privilege_writes=0}
 function p:get_player_name()return self.name end
 function p:get_pos()return self.pos end
 function p:get_meta()return self.meta end
 function p:get_inventory()
  return {room_for_item=function()return true end,
   add_item=function(_,_,item)self.items[#self.items+1]=item.raw end}
 end
 players[name]=p
 return p
end
core={registered_items={}}
for _,item in ipairs({"mcl_tools:pick_diamond","mcl_tools:axe_diamond","mcl_torches:torch"}) do core.registered_items[item]={} end
function ItemStack(raw)return {raw=raw,get_name=function()return raw:match("^%S+") end} end
core.settings={get=function(_,key)return config[key] end,get_bool=function(_,key,fallback)if config[key]==nil then return fallback end;return config[key] end}
function core.get_player_by_name(name)return players[name] end
function core.get_player_privs(name)return privileges[name] or {interact=true,shout=true} end
function core.set_player_privs(name,privs)privileges[name]=privs;players[name].privilege_writes=players[name].privilege_writes+1 end
function core.show_formspec(name,form,body)forms[name]={name=form,body=body} end
function core.close_formspec(name,form)if forms[name] and forms[name].name==form then forms[name]=nil end end
function core.formspec_escape(text)return text end
function core.register_chatcommand(name,definition)commands[name]=definition end
function core.register_on_joinplayer(callback)joins[#joins+1]=callback end
function core.register_on_player_receive_fields(callback)receivers[#receivers+1]=callback end
function core.after(_,callback)timers[#timers+1]=callback end
function core.serialize(value)return value end
function core.is_creative_enabled()return false end
function core.is_singleplayer()return config.singleplayer~=false end
function core.chat_send_player()end
mcl_gamemode={set_gamemode=function(p,mode)p.mode=mode;return true end}
awards={registered_awards={}}
function awards.register_achievement(id,definition)assert(not awards.registered_awards[id]);awards.registered_awards[id]=definition end
function awards.show_to(name)forms[name]={name="awards:awards"} end
era_playtest={visit_workshop=function(name)players[name].pos="workshop" end,
 show_workshop_help=function(name)forms[name]={name="era_playtest:help"} end}
dofile(root.."/integrations/playtest/mod/guide.lua")
dofile(root.."/integrations/playtest/mod/onboarding.lua")
local function flush()
 local pending=timers;timers={}
 for _,callback in ipairs(pending) do callback() end
end
local function join(p)for _,callback in ipairs(joins) do callback(p) end;flush() end
local function fields(p,form,value)for _,callback in ipairs(receivers) do callback(p,form,value) end end

local survival=player("Survivor")
survival.items={"existing keepsake"}
join(survival)
eq(forms.Survivor.name,"era_playtest:start","New player sees choice")
eq(#survival.items,1,"Choice grants no supplies")
eq(survival.privilege_writes,0,"Choice grants no privileges")
eq(survival.meta:get_string("era_playtest_surface"),"natural spawn","Natural spawn saved")
fields(survival,"era_playtest:start",{quit=true})
eq(survival.meta:get_int("era_playtest_joined"),0,"Dismissal leaves choice pending")
survival.pos="walked away"
join(survival)
eq(survival.meta:get_string("era_playtest_surface"),"natural spawn","Reopening keeps original spawn")
fields(survival,"era_playtest:start",{start_survival=true})
eq(survival.meta:get_int("era_playtest_joined"),1,"Survival choice persisted")
eq(survival.meta:get_string("era_playtest_start_mode"),"survival","Survival mode saved")
eq(survival.pos,"walked away","Survival choice never teleports")
eq(#survival.items,1,"Survival preserves inventory without gifts")
eq(survival.items[1],"existing keepsake","Survival never clears inventory")
eq(survival.privilege_writes,0,"Survival grants no development privileges")
fields(survival,"era_playtest:start",{start_workshop=true})
eq(#survival.items,1,"Stale button cannot grant a second starting path")
eq(survival.pos,"walked away","Stale button cannot teleport")
forms.Survivor=nil;survival.pos="saved base"
join(survival)
eq(forms.Survivor,nil,"Returning player gets no chooser")
eq(survival.pos,"saved base","Returning position preserved")

local workshop=player("Builder")
join(workshop)
fields(workshop,"era_playtest:start",{start_workshop=true})
eq(#workshop.items,3,"Workshop kit granted once")
eq(workshop.pos,"workshop","Workshop path visits supplied factory")
eq(workshop.privilege_writes,1,"Workshop grants experiment privileges once")
fields(workshop,"era_playtest:start",{start_workshop=true})
join(workshop)
eq(#workshop.items,3,"Duplicate click and reconnect cannot duplicate tools")
eq(workshop.privilege_writes,1,"Duplicate choice does not rewrite privileges")

config.singleplayer=false
local remote=player("Server guest")
join(remote)
fields(remote,"era_playtest:start",{start_workshop=true})
eq(#remote.items,3,"Server guest may use the workshop kit")
eq(remote.privilege_writes,0,"Server guests never receive operator or give privileges")
config.singleplayer=nil

local legacy=player("Existing 0.1.0")
legacy.meta:set_int("era_playtest_joined",1)
legacy.items={"saved machinery"};legacy.pos="old factory"
join(legacy)
eq(legacy.pos,"old factory","Legacy position preserved")
eq(legacy.items[1],"saved machinery","Legacy inventory preserved")
eq(forms[legacy.name],nil,"Legacy player is not asked to restart")
eq(commands.startchoice.func(legacy.name),false,"Legacy player cannot claim starter kit again")

config.era_playtest_start_mode="survival"
local automatic=player("Configured survival");join(automatic)
eq(automatic.meta:get_string("era_playtest_start_mode"),"survival","Configured start works")
eq(#automatic.items,0,"Configured survival starts with no granted items")
config.era_playtest_start_mode=nil
local disconnected=player("Disconnected")
for _,callback in ipairs(joins) do callback(disconnected) end
players.Disconnected=nil;flush()

era_playtest.show_factory_guide("Survivor",999)
assert(forms.Survivor.body:find("Gather materials",1,true),"Invalid page falls back safely")
fields(survival,"era_playtest:factory_guide",{factory_page="4"})
assert(forms.Survivor.body:find("Power cells are a later",1,true),"Power page explains optional cell")
fields(survival,"era_playtest:factory_guide",{advancements=true})
eq(forms.Survivor.name,"awards:awards","Guide opens existing advancement UI")
local count=0
for id,definition in pairs(awards.registered_awards) do
 count=count+1
 assert(id:sub(1,13)=="era_playtest:","Milestone namespace")
 eq(definition.trigger.type,"craft","Use stock craft trigger")
 eq(definition.trigger.target,1,"One craft milestone")
 assert(not definition.prizes,"Guidance does not mint free items")
end
eq(count,6,"Six native factory milestones")
print("ONBOARDING PASS: optional survival; no gifts or resets; one-time workshop kit; legacy saves; guide navigation; native craft milestones")
