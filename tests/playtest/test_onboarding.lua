-- SPDX-License-Identifier: GPL-3.0-or-later
-- Exercise first-join event order, duplicate submissions and preserved save metadata.
local root=assert(arg[1],"repository root required")
local joins,leaves,receivers,commands,timers,players,forms,config,privileges,emerges,logs={},{},{},{},{},{},{},{},{},{},{}
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function meta()
 local data={}
 return {get_int=function(_,key)return tonumber(data[key]) or 0 end,
  set_int=function(_,key,value)data[key]=value end,
  get_string=function(_,key)return data[key] or "" end,
  set_string=function(_,key,value)data[key]=value end}
end
local function player(name,previous)
 local p={name=name,pos=previous and previous.pos or "natural spawn",meta=previous and previous.meta or meta(),
  items=previous and previous.items or {},privilege_writes=0,huds={},next_hud=0,moves=0,mode_writes=0}
 function p:get_player_name()return self.name end
 function p:get_pos()return self.pos end
 function p:get_meta()return self.meta end
 function p:set_pos(pos)self.pos=pos;self.moves=self.moves+1 end
 function p:set_look_horizontal()end
 function p:set_look_vertical()end
 function p:hud_add(definition)local id=self.next_hud;self.next_hud=id+1;self.huds[id]=definition;return id end
 function p:hud_remove(id)self.huds[id]=nil end
 function p:get_inventory()
  return {room_for_item=function()return true end,
   add_item=function(_,_,item)self.items[#self.items+1]=item.raw end}
 end
 players[name]=p
 return p
end
core={registered_items={},EMERGE_CANCELLED=0,EMERGE_ERRORED=1,EMERGE_GENERATED=4}
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
function core.register_on_leaveplayer(callback)leaves[#leaves+1]=callback end
function core.register_on_player_receive_fields(callback)receivers[#receivers+1]=callback end
function core.after(_,callback)timers[#timers+1]=callback end
function core.serialize(value)return value end
function core.deserialize(value)return value~="" and value or nil end
function core.is_creative_enabled()return false end
function core.is_singleplayer()return config.singleplayer~=false end
function core.chat_send_player()end
function core.log(level,text)logs[#logs+1]={level=level,text=text} end
local world_storage=meta()
function core.get_mod_storage()return world_storage end
function core.get_modpath(name)assert(name=="era_playtest");return root.."/integrations/playtest/mod" end
local emerge_error
function core.emerge_area(a,b,callback)
 if emerge_error then error(emerge_error) end
 emerges[#emerges+1]={min=a,max=b,callback=callback}
end
vector={}
function vector.new(x,y,z)return {x=x,y=y,z=z} end
function vector.add(a,b)
 if type(b)=="number" then return {x=a.x+b,y=a.y+b,z=a.z+b} end
 return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z}
end
function vector.subtract(a,b)return vector.add(a,-b) end
mcl_spawn={get_world_spawn_pos=function()return vector.new(50,10,50) end}
mcl_gamemode={set_gamemode=function(p,mode)p.mode=mode;p.mode_writes=p.mode_writes+1;return true end}
awards={registered_awards={}}
function awards.register_achievement(id,definition)assert(not awards.registered_awards[id]);awards.registered_awards[id]=definition end
function awards.show_to(name)forms[name]={name="awards:awards"} end
dofile(root.."/integrations/playtest/mod/init.lua")
local fixture_builds,fixture_error=0,false
era_playtest.build_fixture=function()
 fixture_builds=fixture_builds+1
 if fixture_error then error("Fixture constructor failed") end
end
local function flush()
 local pending=timers;timers={}
 for _,callback in ipairs(pending) do callback() end
end
local function join(p)for _,callback in ipairs(joins) do callback(p) end;flush() end
local function leave(p)for _,callback in ipairs(leaves) do callback(p) end;players[p.name]=nil end
local function fields(p,form,value)for _,callback in ipairs(receivers) do callback(p,form,value) end end
local function finish_emerge(job)job.callback({},core.EMERGE_GENERATED,0);flush() end
local function position(p,x,y,z,label)
 assert(type(p.pos)=="table",label..": missing position")
 eq(p.pos.x,x,label.." X");eq(p.pos.y,y,label.." Y");eq(p.pos.z,z,label.." Z")
end

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
eq(workshop.pos,"natural spawn","Workshop generation does not block exploring")
eq(workshop.meta:get_int("era_playtest_workshop_pending"),1,"Workshop trip saved before terrain work")
assert(workshop.huds[0].text:find("keep exploring",1,true),"Loading HUD explains continued exploring")
assert(workshop.huds[0].text:find("/cancelworkshop",1,true),"Loading HUD makes cancellation discoverable")
eq(workshop.privilege_writes,1,"Workshop grants experiment privileges once")
local original_trip=emerges[#emerges]
local queued=#emerges
fields(workshop,"era_playtest:start",{start_workshop=true})
commands.workshop.func(workshop.name)
eq(#emerges,queued,"Repeated requests share one in-flight terrain job")
original_trip.callback({},core.EMERGE_GENERATED,1);flush()
eq(workshop.pos,"natural spawn","Intermediate callback does not teleport")
finish_emerge(original_trip)
position(workshop,3,200.5,6,"Completed workshop trip")
eq(workshop.meta:get_int("era_playtest_workshop_pending"),0,"Arrival clears pending trip")
eq(next(workshop.huds),nil,"Arrival removes loading HUD, including HUD ID zero")
eq(forms.Builder.name,"era_playtest:help","First arrival opens workshop help")
workshop.pos="saved factory";leave(workshop);players.Builder=workshop
join(workshop)
eq(#workshop.items,3,"Duplicate click and reconnect cannot duplicate tools")
eq(workshop.privilege_writes,1,"Duplicate choice does not rewrite privileges")
eq(workshop.pos,"saved factory","Completed workshop trip never resets returning position")

config.singleplayer=false
local remote=player("Server guest")
join(remote)
fields(remote,"era_playtest:start",{start_workshop=true})
eq(#remote.items,3,"Server guest may use the workshop kit")
eq(remote.privilege_writes,0,"Server guests never receive operator or give privileges")
finish_emerge(emerges[#emerges])
config.singleplayer=nil

local legacy=player("Existing 0.1.0")
legacy.meta:set_int("era_playtest_joined",1)
legacy.meta:set_string("era_playtest_start_mode","workshop")
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
leave(disconnected);flush()

-- A saved first choice resumes across sessions, without applying its kit or
-- privileges a second time. Old callbacks cannot act on the replacement player.
local interrupted=player("Interrupted workshop")
join(interrupted)
fields(interrupted,"era_playtest:start",{start_workshop=true})
local stale_trip=emerges[#emerges]
eq(#interrupted.items,3,"Interrupted first workshop gets one kit")
leave(interrupted)
eq(next(interrupted.huds),nil,"Disconnect discards the old loading HUD")
eq(interrupted.meta:get_int("era_playtest_workshop_pending"),1,"Disconnect preserves pending arrival")
local resumed=player(interrupted.name,interrupted)
resumed.pos="saved unfinished trip"
config.era_playtest_no_welcome=true
join(resumed)
config.era_playtest_no_welcome=nil
local resumed_trip=emerges[#emerges]
assert(resumed_trip~=stale_trip,"Pending arrival starts a current-session request")
eq(#resumed.items,3,"Resuming does not grant another kit")
eq(resumed.privilege_writes,0,"Resuming does not rewrite privileges")
assert(next(resumed.huds)~=nil,"Resuming shows loading status even when welcome panels are disabled")
local before_builds=fixture_builds
finish_emerge(stale_trip)
eq(resumed.pos,"saved unfinished trip","An old session cannot move its replacement")
eq(resumed.meta:get_int("era_playtest_workshop_pending"),1,"Old completion cannot clear current pending marker")
eq(fixture_builds,before_builds,"An old callback cannot build or reset the shared workshop")
finish_emerge(resumed_trip)
position(resumed,3,200.5,6,"Current session finishes saved trip")
eq(forms[resumed.name].name,"era_playtest:help","Resumed first trip retains first-arrival help")
eq(resumed.meta:get_int("era_playtest_workshop_first"),0,"First-arrival marker clears on completion")
resumed.pos="new saved base";leave(resumed)
local returning=player(resumed.name,resumed);local before_queue=#emerges
join(returning)
eq(#emerges,before_queue,"A finished trip does not queue again on reconnect")
eq(returning.pos,"new saved base","A finished trip never resets the next saved position")

-- A delayed first-join timer from an earlier session must not operate on a new
-- connection that happens to use the same name.
local early=player("Fast reconnect")
for _,callback in ipairs(joins) do callback(early) end
leave(early)
local replacement=player(early.name,early)
for _,callback in ipairs(joins) do callback(replacement) end
flush()
eq(replacement.mode_writes,1,"Only the current session's initial join timer runs")
eq(#replacement.items,0,"A stale initial timer cannot grant tools")

local canceled=player("Canceled workshop")
join(canceled);fields(canceled,"era_playtest:start",{start_workshop=true})
local canceled_trip=emerges[#emerges]
eq(commands.cancelworkshop.func(canceled.name),true,"Explicit cancellation accepts a pending trip")
eq(canceled.meta:get_int("era_playtest_workshop_pending"),0,"Cancellation clears persisted arrival")
eq(canceled.meta:get_int("era_playtest_workshop_first"),0,"Cancellation clears pending first-arrival help")
eq(next(canceled.huds),nil,"Cancellation removes loading HUD")
finish_emerge(canceled_trip)
eq(canceled.pos,"natural spawn","Canceled callback cannot warp the player later")
eq(#canceled.items,3,"Canceling never removes or duplicates existing kit")
eq(commands.cancelworkshop.func(canceled.name),false,"No phantom trip remains after cancellation")

-- The final emerge callback and its after(0) continuation are separate steps.
commands.workshop.func(canceled.name)
local canceled_after_callback=emerges[#emerges]
canceled_after_callback.callback({},core.EMERGE_GENERATED,0)
commands.cancelworkshop.func(canceled.name)
before_builds=fixture_builds;flush()
eq(canceled.pos,"natural spawn","Cancellation between callback and continuation wins")
eq(fixture_builds,before_builds,"Canceled continuation performs no shared-world writes")

for _,action in ipairs({core.EMERGE_CANCELLED,core.EMERGE_ERRORED}) do
 local failed=player("Terrain failure "..action)
 join(failed);fields(failed,"era_playtest:start",{start_workshop=true})
 local failed_trip=emerges[#emerges]
 local before_logs=#logs
 failed_trip.callback({},action,3)
 eq(next(failed.huds),nil,"An emerge failure removes loading HUD")
 eq(failed.meta:get_int("era_playtest_workshop_pending"),1,"An emerge failure keeps a retryable saved trip")
 finish_emerge(failed_trip)
 eq(failed.pos,"natural spawn","Remaining callbacks from a failed job do not teleport")
 eq(#logs,before_logs+1,"A failed job reports its failure once")
 commands.workshop.func(failed.name)
 local retry_trip=emerges[#emerges]
 finish_emerge(failed_trip)
 eq(failed.meta:get_int("era_playtest_workshop_pending"),1,"An old failed callback cannot clear a newer retry")
 assert(next(failed.huds)~=nil,"An old failed callback cannot remove the retry's loading HUD")
 finish_emerge(retry_trip)
 position(failed,3,200.5,6,"A failed terrain request can be retried")
 eq(#failed.items,3,"Retry never regrants initial kit")
end

local queue_failure=player("Queue failure")
join(queue_failure)
emerge_error="Queue unavailable"
fields(queue_failure,"era_playtest:start",{start_workshop=true})
emerge_error=nil
eq(next(queue_failure.huds),nil,"Synchronous queue failure removes loading HUD")
eq(queue_failure.meta:get_int("era_playtest_workshop_pending"),1,"Queue failure preserves saved trip")
commands.workshop.func(queue_failure.name)
finish_emerge(emerges[#emerges])
position(queue_failure,3,200.5,6,"Queue failure can be retried without restarting onboarding")
eq(#queue_failure.items,3,"Queue failure retry keeps exactly one kit")

local constructor_failure=player("Fixture failure")
join(constructor_failure)
world_storage:set_int("workshop_v1",0);fixture_error=true
fields(constructor_failure,"era_playtest:start",{start_workshop=true})
finish_emerge(emerges[#emerges])
eq(constructor_failure.pos,"natural spawn","A fixture failure never claims arrival")
eq(constructor_failure.meta:get_int("era_playtest_workshop_pending"),1,"A fixture failure remains retryable")
eq(world_storage:get_int("workshop_v1"),0,"An incomplete fixture is not marked ready")
eq(next(constructor_failure.huds),nil,"A fixture error removes loading HUD")
fixture_error=false
commands.workshop.func(constructor_failure.name)
local successful_retry=emerges[#emerges]
before_builds=fixture_builds
successful_retry.callback({},core.EMERGE_GENERATED,0)
successful_retry.callback({},core.EMERGE_GENERATED,0)
flush()
position(constructor_failure,3,200.5,6,"A fixture failure can be retried")
eq(fixture_builds,before_builds+1,"Repeated final callbacks build the fixture only once")
eq(constructor_failure.moves,1,"Repeated final callbacks move a player only once")
eq(#constructor_failure.items,3,"Fixture retry does not grant another kit")

local traveler=player("Travel intent")
traveler.meta:set_int("era_playtest_joined",1)
traveler.pos=vector.new(30,10,40)
traveler.meta:set_string("era_playtest_surface",vector.new(80,20,90))
join(traveler)
era_playtest.return_to_surface(traveler.name)
local old_surface=emerges[#emerges]
commands.workshop.func(traveler.name)
local latest_workshop=emerges[#emerges]
finish_emerge(old_surface)
position(traveler,30,10,40,"Old surface request cannot override a later workshop request")
finish_emerge(latest_workshop)
position(traveler,3,200.5,6,"Latest workshop request remains authoritative")
commands.workshop.func(traveler.name)
local old_workshop=emerges[#emerges]
era_playtest.return_to_surface(traveler.name)
local latest_surface=emerges[#emerges]
eq(traveler.meta:get_int("era_playtest_workshop_pending"),0,"Exploring cancels saved workshop arrival")
eq(next(traveler.huds),nil,"Exploring removes workshop loading HUD")
finish_emerge(old_workshop)
position(traveler,3,200.5,6,"Canceled workshop callback cannot override survival travel")
finish_emerge(latest_surface)
position(traveler,80,20,90,"Latest survival request reaches its intended surface")
era_playtest.return_to_surface(traveler.name)
local disconnected_surface=emerges[#emerges]
leave(traveler)
local new_traveler=player(traveler.name,traveler)
new_traveler.pos=vector.new(500,30,600);join(new_traveler)
finish_emerge(disconnected_surface)
position(new_traveler,500,30,600,"Old-session surface callback cannot reset a returning player's position")
era_playtest.return_to_surface(new_traveler.name)
local failed_surface=emerges[#emerges]
failed_surface.callback({},core.EMERGE_ERRORED,1)
finish_emerge(failed_surface)
position(new_traveler,500,30,600,"A failed surface job cannot teleport on later callbacks")
era_playtest.return_to_surface(new_traveler.name)
local surface_continuation=emerges[#emerges]
surface_continuation.callback({},core.EMERGE_GENERATED,0)
commands.workshop.func(new_traveler.name)
local overriding_workshop=emerges[#emerges]
flush()
position(new_traveler,500,30,600,"A scheduled surface continuation cannot override a newer workshop request")
finish_emerge(overriding_workshop)
position(new_traveler,3,200.5,6,"Newer workshop request survives the stale surface continuation")
emerge_error="Surface queue unavailable"
eq(era_playtest.return_to_surface(new_traveler.name),false,"Synchronous surface queue failure is contained")
emerge_error=nil

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
eq(count,7,"Seven native factory milestones")
print("ONBOARDING PASS: survival/legacy saves; one-time kit; visible loading; pending resume; session isolation; cancellation/error/retry; stale travel callbacks; guide and craft milestones")
