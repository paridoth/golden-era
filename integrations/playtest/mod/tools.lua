-- SPDX-License-Identifier: GPL-3.0-or-later
-- Tools built from parts, in the spirit of Tinkers' Construct. Casts made
-- from stone tools, string and sticks shape molten metal into heads,
-- bindings and tool rods on a casting table. A head over a binding over a
-- rod (or a stick) in a crafting grid makes the tool: the head metal sets
-- mining level, speed and base durability, and the binding and handle
-- metals multiply durability. Each head metal is a Mineclonia tool set, so
-- enchanting, harvesting and anvil repair work as for stock tools.
local INGOT=144
local STATS={ -- level and speed follow Mineclonia's sets: stone 3, iron 4, diamond 5
 copper={level=3,speed=5,uses=191},iron={level=4,speed=6,uses=251},gold={level=2,speed=12,uses=33},
 tin={level=3,speed=4.5,uses=150},lead={level=3,speed=4,uses=220},nickel={level=4,speed=6.5,uses=300},
 zinc={level=3,speed=5,uses=170},silver={level=3,speed=7.5,uses=130},bronze={level=4,speed=6.5,uses=400},
 invar={level=4,speed=6.5,uses=500},electrum={level=3,speed=10,uses=180},brass={level=3,speed=7,uses=260},
 steel={level=5,speed=7,uses=900},
}
era_playtest.tool_stats=STATS
local STICK="mcl_core:stick"
local WOOD="#8a5a2b"
-- part -> mB, the cast's template item and the cast's name
local PARTS={
 {id="pick_head",name="Pickaxe Head",amount=2*INGOT,template="mcl_tools:pick_stone"},
 {id="axe_head",name="Axe Head",amount=2*INGOT,template="mcl_tools:axe_stone"},
 {id="shovel_head",name="Shovel Head",amount=2*INGOT,template="mcl_tools:shovel_stone"},
 {id="sword_blade",name="Sword Blade",amount=2*INGOT,template="mcl_tools:sword_stone"},
 {id="binding",name="Binding",amount=INGOT,template="mcl_mobitems:string"},
 {id="rod",name="Tool Rod",amount=INGOT,template=STICK},
}
local TOOLS={pick={head="pick_head",name="Pickaxe",damage=0},axe={head="axe_head",name="Axe",damage=5},
 shovel={head="shovel_head",name="Shovel",damage=0},sword={head="sword_blade",name="Sword",damage=2}}
local INTERVAL={pick=0.83333333,axe=1.11111111,shovel=1,sword=0.625}

-- Durability multipliers: a handle around 1 for iron, a binding adding up to a third.
local function handle_factor(metal) return metal and math.min(2,0.6+STATS[metal].uses/600) or 1 end
local function binding_factor(metal) return 1+math.min(0.35,STATS[metal].uses/2500) end
function era_playtest.tool_durability(binding,handle) return handle_factor(handle)*binding_factor(binding) end

local function color(metal) return era_playtest.metal_colors[metal] or "#ffffff" end
local function layer(part,tint) return "(era_playtest_part_"..part..".png^[multiply:"..tint..")" end
local function tool_image(tool,head,binding,handle)
 return layer("rod",handle and color(handle) or WOOD).."^"..layer(TOOLS[tool].head,color(head)).."^"..layer("binding",color(binding))
end

local function after_use(itemstack,user,node,digparams)
 local name=user and user:is_player() and user:get_player_name() or ""
 if core.is_creative_enabled(name) then return itemstack end
 local factor=itemstack:get_meta():get_float("era_durability")
 if factor<=0 then factor=1 end
 itemstack:add_wear(math.ceil((digparams.wear or 0)/factor))
 if itemstack:is_empty() and user then
  core.sound_play("default_tool_breaks",{pos=user:get_pos(),gain=0.5},true)
 end
 return itemstack
end

local registered={}
local function register_metal(metal)
 local label=era_playtest.metal_label(metal)
 local stats=STATS[metal]
 for _,part in ipairs(PARTS) do
  core.register_craftitem("era_playtest:part_"..part.id.."_"..metal,{
   description=label.." "..part.name,
   _tt_help="A tool part. Assemble it in a crafting grid: head, then binding, then rod or stick.",
   inventory_image=layer(part.id,color(metal)),
   groups={["era_part_"..part.id]=1,craftitem=1},
  })
 end
 local tools={}
 for id,tool in pairs(TOOLS) do
  local damage=stats.level+tool.damage
  tools[id]={description=label.." "..tool.name,inventory_image=tool_image(id,metal,metal,nil),
   tool_capabilities={full_punch_interval=INTERVAL[id],damage_groups={fleshy=damage}}}
 end
 mcl_tools.register_set("cast_"..metal,{
  craftable=false,material=era_playtest.smeltery_product(metal,"ingot"),
  uses=stats.uses,level=stats.level,speed=stats.speed,max_drop_level=stats.level,
  groups={dig_speed_class=stats.level,enchantability=14,not_in_creative_inventory=1},
 },tools,{after_use=after_use})
 registered[metal]=true
end

-- The tool a crafting grid of parts makes, or nil.
function era_playtest.assemble_tool(tool,grid)
 local head,binding,handle,stick
 for _,stack in ipairs(grid) do
  local name=type(stack)=="string" and stack or stack:get_name()
  local part,metal=name:match("^era_playtest:part_(.+)_(%a+)$")
  if part==TOOLS[tool].head then head=metal
  elseif part=="binding" then binding=metal
  elseif part=="rod" then handle=metal
  elseif name==STICK then stick=true end
 end
 if not (head and binding and (handle or stick)) or not registered[head] then return nil end
 local result=ItemStack("era_playtest:"..tool.."_cast_"..head)
 local meta=result:get_meta()
 local factor=era_playtest.tool_durability(binding,handle)
 meta:set_string("era_parts",core.serialize({head=head,binding=binding,handle=handle or "wood"}))
 meta:set_float("era_durability",factor)
 local image=tool_image(tool,head,binding,handle)
 meta:set_string("inventory_image",image)
 meta:set_string("wield_image",image)
 local label=era_playtest.metal_label
 meta:set_string("description",label(head).." "..TOOLS[tool].name..
  core.colorize("#a0a0a0","\nHead: "..label(head).."\nBinding: "..label(binding).."\nHandle: "..(handle and label(handle) or "Wood")..
  "\nDurability: "..math.floor(STATS[head].uses*factor+0.5).." uses"))
 return result
end

local function craft_result(itemstack,old_grid)
 local tool=itemstack:get_name():match("^era_playtest:(%a+)_cast_%a+$")
 if not tool or not TOOLS[tool] then return nil end
 return era_playtest.assemble_tool(tool,old_grid) or ItemStack("")
end
core.register_craft_predict(function(itemstack,_,old_grid) return craft_result(itemstack,old_grid) end)
core.register_on_craft(function(itemstack,_,old_grid) return craft_result(itemstack,old_grid) end)

for metal in pairs(STATS) do
 if era_playtest.smeltery_product(metal,"ingot") then register_metal(metal) end
end

-- Casts: two seared bricks and the template, which the molten gold of a
-- real cast would have burned away, so it is used up.
local b="era_playtest:seared_brick"
for _,part in ipairs(PARTS) do
 local cast="era_playtest:cast_"..part.id
 core.register_craftitem(cast,{description=part.name.." Cast",
  _tt_help="Goes in a Casting Table to cast a "..part.name:lower().." from "..part.amount.." mB.",
  inventory_image="[fill:16x16:#00000000^[fill:14x14:1,1:#b8901f^"..layer(part.id,"#4a3608")})
 core.register_craft({type="shapeless",output=cast,recipe={b,b,part.template}})
 era_playtest.register_table_cast(cast,part.id,part.amount)
end

-- One recipe per tool and handle kind; the placeholder output is replaced by the assembled tool.
local any_metal=next(registered)
if any_metal then
 for tool,def in pairs(TOOLS) do
  for _,rod in ipairs({"group:era_part_rod",STICK}) do
   core.register_craft({output="era_playtest:"..tool.."_cast_"..any_metal,
    recipe={{"group:era_part_"..def.head},{"group:era_part_binding"},{rod}}})
  end
 end
end
