-- SPDX-License-Identifier: GPL-3.0-or-later
-- Casting in the spirit of Tinkers' Construct: a Seared Drain in a smeltery
-- wall, a Faucet on the drain's outside and, below the faucet, a Casting
-- Table (with an Ingot Cast, for ingots) or a Casting Basin (for blocks).
-- Right-clicking the faucet, or powering it with redstone or Mesecons, pours
-- the metal chosen on the controller. The table and basin show what they hold.
local INGOT=144
local SEARED="default_stone_brick.png^[colorize:#3b3633:170"
-- show: where the held item sits, how big it is and whether it lies flat.
-- casts: what each cast in a table makes; tools.lua adds the tool-part casts.
local SHAPES={["era_playtest:casting_table"]={casts={["era_playtest:ingot_cast"]={shape="ingot",amount=INGOT}},seconds=3,
  show={y=0.53,size=0.3,flat=true}},
 ["era_playtest:casting_basin"]={shape="block",amount=9*INGOT,seconds=6,show={y=0.05,size=0.42}}}
local DISPLAY="era_playtest:cast_display"
-- Molten colours, laid over lava.
local COLORS={iron="#d8d8d8",gold="#ffd23c",copper="#e8783c",tin="#dfe8ee",lead="#6b6f8a",nickel="#d9d4a6",
 zinc="#c3cbc4",silver="#eef4ff",bronze="#c98f3e",invar="#b9c2b1",electrum="#f2e36e",brass="#e3b23e",steel="#8c8c8c"}
era_playtest.metal_colors=COLORS
-- Let a cast item make shape from amount mB on the casting table.
function era_playtest.register_table_cast(cast,shape,amount)
 SHAPES["era_playtest:casting_table"].casts[cast]={shape=shape,amount=amount}
end

local function objects_near(pos,radius)
 if core.objects_inside_radius then return core.objects_inside_radius(pos,radius) end
 local list,i=core.get_objects_inside_radius(pos,radius),0
 return function() i=i+1;return list[i] end
end

-- Show the casting, or else the cast, on top of a table or inside a basin.
function era_playtest.cast_display_refresh(pos)
 local node=core.get_node(pos)
 local target=SHAPES[node.name]
 local at=vector.offset(pos,0,target and target.show.y or 0.3,0)
 for obj in objects_near(at,0.3) do
  local ent=obj:get_luaentity()
  if ent and ent.name==DISPLAY then obj:remove() end
 end
 if not target then return end
 local meta=core.get_meta(pos)
 local inv=meta:get_inventory()
 local item=meta:get_string("casting")
 if item=="" then item=inv:get_stack("output",1):get_name() end
 if item=="" and target.casts then item=inv:get_stack("cast",1):get_name() end
 if item=="" or not core.registered_items[item] then return end
 local obj=core.add_entity(at,DISPLAY)
 if not obj then return end
 local size=target.show.size
 obj:set_properties({wield_item=item,visual_size={x=size,y=size}})
 if target.show.flat then obj:set_rotation({x=math.pi/2,y=0,z=0}) end
end

core.register_entity(DISPLAY,{
 initial_properties={visual="wielditem",wield_item="",visual_size={x=0.3,y=0.3},
  physical=false,pointable=false,collisionbox={0,0,0,0,0,0},static_save=false},
 on_activate=function(self) self.object:set_armor_groups({immortal=1}) end,
})

-- A falling stream of molten metal from the faucet's spout into the target below.
local function pour_stream(pos,metal,seconds,target)
 local dir=core.facedir_to_dir(core.get_node(pos).param2)
 local spout=vector.add(vector.offset(pos,0,-0.15,0),vector.multiply(dir,0.2))
 local floor=target=="era_playtest:casting_basin" and pos.y-1.25 or pos.y-0.47
 local speed=4
 core.add_particlespawner({amount=math.ceil(seconds*60),time=seconds,
  minpos=vector.offset(spout,-0.04,0,-0.04),maxpos=vector.offset(spout,0.04,0,0.04),
  minvel={x=0,y=-speed,z=0},maxvel={x=0,y=-speed,z=0},
  minexptime=(spout.y-floor)/speed,maxexptime=(spout.y-floor)/speed,minsize=2.6,maxsize=3.2,
  texture="default_lava_flowing_animated.png^[verticalframe:64:0^[colorize:"..(COLORS[metal] or "#ff8800")..":140",
  glow=13})
end

-- The controller whose wall contains this drain.
function era_playtest.drain_controller(pos)
 local r=vector.new(8,8,8)
 for _,c in ipairs(core.find_nodes_in_area(vector.subtract(pos,r),vector.add(pos,r),{"era_playtest:smeltery_controller"})) do
  local shape=era_playtest.smeltery_scan(c)
  if shape then
   local min,max=shape.min,shape.max
   local in_x=pos.x>=min.x-1 and pos.x<=max.x+1
   local in_z=pos.z>=min.z-1 and pos.z<=max.z+1
   local wall=(pos.x==min.x-1 or pos.x==max.x+1)~=(pos.z==min.z-1 or pos.z==max.z+1)
   if in_x and in_z and wall and pos.y>=min.y and pos.y<=max.y then return c end
  end
 end
end

-- Pour from the faucet at pos; returns true or false and a message.
function era_playtest.faucet_pour(pos)
 local drain=vector.add(pos,core.facedir_to_dir(core.get_node(pos).param2))
 if core.get_node(drain).name~="era_playtest:seared_drain" then return false,"Place the faucet on the outside of a Seared Drain." end
 local controller=era_playtest.drain_controller(drain)
 if not controller then return false,"The drain is not part of a complete smeltery wall." end
 local below=vector.offset(pos,0,-1,0)
 local target=SHAPES[core.get_node(below).name]
 if not target then return false,"Put a Casting Table or Casting Basin under the faucet." end
 local meta=core.get_meta(below)
 local inv=meta:get_inventory()
 if meta:get_string("casting")~="" or not inv:is_empty("output") then return false,"Take the finished casting out first." end
 local shape,amount=target.shape,target.amount
 if target.casts then
  local cast=target.casts[inv:get_stack("cast",1):get_name()]
  if not cast then return false,"The Casting Table needs a cast, such as an Ingot Cast." end
  shape,amount=cast.shape,cast.amount
 end
 local label=shape:gsub("_"," ")
 local cmeta=core.get_meta(controller)
 local metal=era_playtest.smeltery_selected(cmeta)
 if not metal then return false,"The smeltery has no molten metal." end
 local product=era_playtest.smeltery_product(metal,shape)
 if not product then return false,"Molten "..era_playtest.metal_label(metal).." cannot be cast as a "..label.."." end
 if not era_playtest.smeltery_drain(controller,amount) then
  return false,"Not enough molten "..era_playtest.metal_label(metal)..": a "..label.." needs "..amount.." mB."
 end
 meta:set_string("casting",product)
 meta:set_string("infotext","Cooling: "..core.registered_items[product].description:match("^[^\n]*"))
 core.get_node_timer(below):start(target.seconds)
 -- The stream runs for most of the cooling time; the casting appears when it ends.
 pour_stream(pos,metal,target.seconds*0.6,core.get_node(below).name)
 core.after(target.seconds*0.6,era_playtest.cast_display_refresh,below)
 return true
end

local function protected(pos,player)
 local name=player and player:get_player_name() or ""
 if core.is_protected(pos,name) then core.record_protection_violation(pos,name);return true end
end

local slot_bg=mcl_formspec and mcl_formspec.get_itemslot_bg_v4 or function() return "" end
local function caster_formspec(label,cast)
 return table.concat({"formspec_version[4]size[11.75,8.6]label[0.375,0.375;"..label.."]",
  cast and ("label[3,1.2;Cast]"..slot_bg(3,1.5,1,1).."list[context;cast;3,1.5;1,1;]") or "",
  "label[6.5,1.2;Casting]",slot_bg(6.5,1.5,1,1),"list[context;output;6.5,1.5;1,1;]",
  slot_bg(0.375,3.3,9,3),"list[current_player;main;0.375,3.3;9,3;9]",
  slot_bg(0.375,7.25,9,1),"list[current_player;main;0.375,7.25;9,1;]",
  "listring[context;output]listring[current_player;main]"})
end

local function register_caster(name,def,box)
 local target=SHAPES[name]
 core.register_node(name,{
  description=def.description,_tt_help=def.help,
  drawtype="nodebox",node_box={type="fixed",fixed=box},tiles={SEARED},
  paramtype="light",is_ground_content=false,
  groups={pickaxey=1,container=4},sounds=mcl_sounds and mcl_sounds.node_sound_stone_defaults() or nil,
  _mcl_hardness=3,_mcl_blast_resistance=9,
  on_construct=function(pos)
   local meta=core.get_meta(pos)
   local inv=meta:get_inventory()
   inv:set_size("output",1)
   if target.casts then inv:set_size("cast",1) end
   meta:set_string("formspec",caster_formspec(def.description,target.casts))
  end,
  on_destruct=function(pos) core.after(0,era_playtest.cast_display_refresh,pos) end,
  on_timer=function(pos)
   local meta=core.get_meta(pos)
   meta:get_inventory():set_stack("output",1,meta:get_string("casting"))
   meta:set_string("casting","");meta:set_string("infotext","")
   era_playtest.cast_display_refresh(pos)
  end,
  on_metadata_inventory_put=function(pos) era_playtest.cast_display_refresh(pos) end,
  on_metadata_inventory_take=function(pos) era_playtest.cast_display_refresh(pos) end,
  allow_metadata_inventory_put=function(pos,listname,_,stack,player)
   if protected(pos,player) or listname~="cast" or core.get_meta(pos):get_string("casting")~="" then return 0 end
   return target.casts and target.casts[stack:get_name()] and 1 or 0
  end,
  allow_metadata_inventory_take=function(pos,listname,_,stack,player)
   if protected(pos,player) or (listname=="cast" and core.get_meta(pos):get_string("casting")~="") then return 0 end
   return stack:get_count()
  end,
  allow_metadata_inventory_move=function() return 0 end,
  after_dig_node=mcl_util and mcl_util.drop_items_from_meta_container and mcl_util.drop_items_from_meta_container({"cast","output"}),
 })
end

register_caster("era_playtest:casting_table",{description="Casting Table",
 help="Under a faucet with an Ingot Cast, casts ingots from 144 mB."},
 {{-0.5,0.25,-0.5,0.5,0.5,0.5},{-0.5,-0.5,-0.5,-0.25,0.25,-0.25},{0.25,-0.5,-0.5,0.5,0.25,-0.25},
  {-0.5,-0.5,0.25,-0.25,0.25,0.5},{0.25,-0.5,0.25,0.5,0.25,0.5}})
register_caster("era_playtest:casting_basin",{description="Casting Basin",
 help="Under a faucet, casts metal blocks from 1296 mB."},
 {{-0.5,-0.5,-0.5,0.5,-0.25,0.5},{-0.5,-0.25,-0.5,-0.375,0.5,0.5},{0.375,-0.25,-0.5,0.5,0.5,0.5},
  {-0.375,-0.25,-0.5,0.375,0.5,-0.375},{-0.375,-0.25,0.375,0.375,0.5,0.5}})

core.register_node("era_playtest:seared_drain",{description="Seared Drain",
 _tt_help="Part of a smeltery wall. A faucet on its outside pours molten metal.",
 tiles={SEARED,SEARED,SEARED,SEARED,SEARED,SEARED.."^(default_clay_lump.png^[colorize:#111111:230)"},
 paramtype2="facedir",is_ground_content=false,
 groups={pickaxey=1,seared=1},sounds=mcl_sounds and mcl_sounds.node_sound_stone_defaults() or nil,
 _mcl_hardness=3,_mcl_blast_resistance=9})

-- Pour on a rising redstone or Mesecons signal; the result goes to nobody, so failures stay quiet.
local function powered_pour(pos) era_playtest.faucet_pour(pos) end
core.register_node("era_playtest:faucet",{description="Faucet",
 _tt_help="Place on the outside of a Seared Drain, above a casting table or basin.\nRight-click or power it with redstone to pour.",
 drawtype="nodebox",node_box={type="fixed",fixed={{-0.25,-0.125,0.125,0.25,0.125,0.5},{-0.25,-0.125,0.125,-0.125,0.25,0.5},{0.125,-0.125,0.125,0.25,0.25,0.5}}},
 tiles={SEARED},paramtype="light",paramtype2="facedir",is_ground_content=false,sunlight_propagates=true,
 groups={pickaxey=1},sounds=mcl_sounds and mcl_sounds.node_sound_stone_defaults() or nil,
 _mcl_hardness=1,_mcl_blast_resistance=3,
 on_rightclick=function(pos,_,clicker,itemstack)
  if not clicker or not clicker:is_player() or protected(pos,clicker) then return itemstack end
  local ok,message=era_playtest.faucet_pour(pos)
  if not ok then core.chat_send_player(clicker:get_player_name(),message) end
  return itemstack
 end,
 _mcl_redstone={connects_to=function() return true end,update=function(pos)
  local meta=core.get_meta(pos)
  local on=mcl_redstone.get_power(pos)~=0
  if on and meta:get_int("powered")==0 then powered_pour(pos) end
  meta:set_int("powered",on and 1 or 0)
 end},
 mesecons={effector={action_on=powered_pour}},
})

-- Displays are not saved with the map, so put them back when a block loads.
core.register_lbm({name="era_playtest:cast_displays",nodenames={"era_playtest:casting_table","era_playtest:casting_basin"},
 run_at_every_load=true,action=function(pos) era_playtest.cast_display_refresh(pos) end})

core.register_craftitem("era_playtest:ingot_cast",{description="Ingot Cast",
 _tt_help="Goes in a Casting Table to cast ingots.",inventory_image="default_clay_brick.png^[colorize:#c9a227:150"})

local b="era_playtest:seared_brick"
core.register_craft({output="era_playtest:seared_drain",recipe={{b,"",b},{b,"",b},{b,"",b}}})
core.register_craft({output="era_playtest:faucet",recipe={{b,"",b},{"",b,""}}})
core.register_craft({output="era_playtest:casting_table",recipe={{b,b,b},{b,"",b},{b,"",b}}})
core.register_craft({output="era_playtest:casting_basin",recipe={{b,"",b},{b,"",b},{b,b,b}}})
core.register_craft({type="shapeless",output="era_playtest:ingot_cast",recipe={b,b,"mcl_core:iron_ingot"},
 replacements={{"mcl_core:iron_ingot","mcl_core:iron_ingot"}}})
