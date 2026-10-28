-- SPDX-License-Identifier: GPL-3.0-or-later
-- An Elepower-charged jetpack in the spirit of Simply Jetpacks. Carried
-- anywhere in the inventory, holding jump lifts the player and holding sneak
-- while falling slows the fall; both drain charge. Lift uses a negative
-- gravity factor, so the client moves smoothly between server steps. It
-- charges in a power cell like the other Elepower tools.
local NAME="era_playtest:jetpack"
local ID="era_playtest:jetpack"
local LIFT,GLIDE,BRAKE,COAST=-0.6,0.15,-0.8,0 -- gravity factors: rise, slow fall, slowing a fast fall, top speed
local MAX_RISE=6
local USE_PER_SECOND={lift=40,coast=40,brake=20,glide=10}
local active,drain={},{}

ele.register_tool(NAME,{
 description="Jetpack",
 _tt_help="Hold jump to fly up; hold sneak while falling to glide.\nKeep it anywhere in your inventory. Charge it in a power cell.",
 inventory_image="elepower_armor_inv_chestplate.png^[colorize:#3a6fd8:110",
 ele_capacity=16000,ele_usage=40,
 groups={tool=1},
 stack_max=1,
})

-- The first charged jetpack in the main inventory, with its slot.
local function find_jetpack(inv)
 for i,stack in ipairs(inv:get_list("main") or {}) do
  if stack:get_name()==NAME and ele.tools.get_tool_property(stack,"storage")>0 then return i,stack end
 end
end

local function set_mode(player,mode)
 local name=player:get_player_name()
 if active[name]==mode then return end
 active[name]=mode
 if mode then
  local factor=({lift=LIFT,coast=COAST,brake=BRAKE,glide=GLIDE})[mode]
  playerphysics.add_physics_factor(player,"gravity",ID,factor)
 else
  playerphysics.remove_physics_factor(player,"gravity",ID)
 end
end

-- Choose the flight mode from the controls and vertical speed.
function era_playtest.jetpack_mode(control,vy)
 if control.jump then return vy>=MAX_RISE and "coast" or "lift" end
 -- A fast fall is braked down to a gentle glide.
 if control.sneak and vy<-3 then return "brake" end
 if control.sneak and vy<-1 then return "glide" end
end

local function spend(player,slot,stack,amount)
 local storage=math.max(0,ele.tools.get_tool_property(stack,"storage")-amount)
 stack:get_meta():set_int("storage",storage)
 player:get_inventory():set_stack("main",slot,ele.tools.update_tool_wear(stack))
 return storage
end

local function step(player,dtime)
 local name=player:get_player_name()
 local slot,stack=find_jetpack(player:get_inventory())
 local mode=slot and era_playtest.jetpack_mode(player:get_player_control(),player:get_velocity().y)
 set_mode(player,mode)
 if not mode then return end
 -- Charge is written a few times a second rather than every server step.
 drain[name]=(drain[name] or 0)+USE_PER_SECOND[mode]*dtime
 if drain[name]>=10 then
  local left=spend(player,slot,stack,math.floor(drain[name]))
  drain[name]=drain[name]-math.floor(drain[name])
  if left==0 then
   set_mode(player,nil)
   core.chat_send_player(name,"Your jetpack is out of charge. Recharge it in a power cell.")
  end
 end
end

core.register_globalstep(function(dtime)
 for _,player in ipairs(core.get_connected_players()) do step(player,dtime) end
end)
core.register_on_joinplayer(function(player)
 -- A factor saved by a crash or shutdown mid-flight must not keep the player floating.
 playerphysics.remove_physics_factor(player,"gravity",ID)
end)
core.register_on_leaveplayer(function(player)
 local name=player:get_player_name()
 set_mode(player,nil);active[name]=nil;drain[name]=nil
end)

local steel,coil="elepower_dynamics:steel_ingot","elepower_dynamics:wound_copper_coil"
core.register_craft({output=NAME,recipe={
 {steel,"elepower_dynamics:capacitor",steel},
 {steel,"elepower_dynamics:battery",steel},
 {coil,"",coil},
}})
