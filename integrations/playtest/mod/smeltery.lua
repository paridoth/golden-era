-- SPDX-License-Identifier: GPL-3.0-or-later
-- A smeltery in the spirit of Tinkers' Construct. Grout bakes into seared
-- bricks; a ring of seared bricks around an air interior, on a seared floor,
-- with a controller in the wall forms the smeltery. Lava buckets fuel it and
-- it melts ores (double), ingots, nuggets and blocks into stored molten metal
-- measured in mB, 144 per ingot. Casting the metal back out comes separately.
local INGOT,MAX_SIDE,MAX_LAYERS=144,7,8
local PER_BLOCK=8*INGOT -- molten capacity per interior block
local LAVA_SECONDS=150
local SEARED="default_stone_brick.png^[colorize:#3b3633:170"

-- item -> {metal, mB}; entries for items the game lacks are dropped on load.
local MELTS={}
local function metal(name,label,items) for item,amount in pairs(items) do MELTS[item]={metal=name,label=label,amount=amount} end end
metal("iron","Iron",{["mcl_core:iron_ingot"]=INGOT,["mcl_core:iron_nugget"]=16,["mcl_core:ironblock"]=9*INGOT,
 ["mcl_raw_ores:raw_iron"]=2*INGOT,["mcl_core:stone_with_iron"]=2*INGOT,["mcl_deepslate:deepslate_with_iron"]=2*INGOT,
 ["elepower_dynamics:iron_dust"]=INGOT})
metal("gold","Gold",{["mcl_core:gold_ingot"]=INGOT,["mcl_core:gold_nugget"]=16,["mcl_core:goldblock"]=9*INGOT,
 ["mcl_raw_ores:raw_gold"]=2*INGOT,["mcl_core:stone_with_gold"]=2*INGOT,["mcl_deepslate:deepslate_with_gold"]=2*INGOT})
metal("copper","Copper",{["mcl_copper:copper_ingot"]=INGOT,["mcl_copper:block"]=9*INGOT,["mcl_copper:raw_copper"]=2*INGOT,
 ["mcl_copper:stone_with_copper"]=2*INGOT,["mcl_deepslate:deepslate_with_copper"]=2*INGOT})
for _,m in ipairs({"tin","lead","nickel","zinc"}) do
 metal(m,m:gsub("^%l",string.upper),{["elepower_dynamics:"..m.."_ingot"]=INGOT,["elepower_dynamics:"..m.."_lump"]=2*INGOT})
end
metal("silver","Silver",{["moreores:silver_ingot"]=INGOT,["moreores:silver_lump"]=2*INGOT})
era_playtest.smeltery_melts=MELTS

local function seared(pos) return core.get_item_group(core.get_node(pos).name,"seared")>0 end
local function air(pos) return core.get_node(pos).name=="air" end

-- The structure behind a controller: interior width, depth, layers and volume, or nil and a reason.
function era_playtest.smeltery_scan(pos)
 local inside=vector.add(pos,core.facedir_to_dir(core.get_node(pos).param2))
 if not air(inside) then return nil,"The block behind the controller must be air." end
 local min,max=vector.copy(inside),vector.copy(inside)
 for _,axis in ipairs({"x","z"}) do
  while air(vector.offset(min,axis=="x" and -1 or 0,0,axis=="z" and -1 or 0)) and max[axis]-min[axis]<MAX_SIDE do min[axis]=min[axis]-1 end
  while air(vector.offset(max,axis=="x" and 1 or 0,0,axis=="z" and 1 or 0)) and max[axis]-min[axis]<MAX_SIDE do max[axis]=max[axis]+1 end
 end
 if max.x-min.x+1>MAX_SIDE or max.z-min.z+1>MAX_SIDE then return nil,"The inside can be at most "..MAX_SIDE.." blocks across." end
 local function layer_ok(y)
  for x=min.x-1,max.x+1 do for z=min.z-1,max.z+1 do
   local edge_x,edge_z=x<min.x or x>max.x,z<min.z or z>max.z
   local p={x=x,y=y,z=z}
   if edge_x and edge_z then -- corners are not part of the wall
   elseif edge_x or edge_z then if not seared(p) then return false end
   elseif not air(p) then return false end
  end end
  return true
 end
 for x=min.x,max.x do for z=min.z,max.z do
  if not seared({x=x,y=inside.y-1,z=z}) then return nil,"The floor under the inside must be seared bricks." end
 end end
 if not layer_ok(inside.y) then return nil,"The walls must be seared bricks all the way around." end
 local layers=1
 while layers<MAX_LAYERS and layer_ok(inside.y+layers) do layers=layers+1 end
 local w,d=max.x-min.x+1,max.z-min.z+1
 return {width=w,depth=d,layers=layers,volume=w*d*layers}
end

local function molten(meta) return core.deserialize(meta:get_string("molten")) or {} end
local function total(pool) local sum=0 for _,amount in pairs(pool) do sum=sum+amount end return sum end
era_playtest.smeltery_molten=molten

local function formspec(pos,shape,reason,pool,fuel)
 local meta=core.get_meta(pos)
 local slots=meta:get_inventory():get_size("melt")
 local lines={}
 if shape then
  lines[1]="Smeltery "..shape.width.."x"..shape.depth..", "..shape.layers.." layer"..(shape.layers>1 and "s" or "")
  lines[2]="Molten metal "..total(pool).." / "..shape.volume*PER_BLOCK.." mB"
 else
  lines[1]="Not a complete smeltery"
  lines[2]=reason
 end
 local names={}
 for name in pairs(pool) do names[#names+1]=name end
 table.sort(names)
 for _,name in ipairs(names) do
  local label=name
  for _,melt in pairs(MELTS) do if melt.metal==name then label=melt.label;break end end
  lines[#lines+1]=label..": "..string.format("%.1f",pool[name]/INGOT).." ingots ("..pool[name].." mB)"
 end
 lines[#lines+1]="Heat: "..math.ceil(fuel).." s of lava left"
 local rows=math.max(1,math.ceil(slots/8))
 local slot_bg=mcl_formspec and mcl_formspec.get_itemslot_bg_v4 or function() return "" end
 local y=0.75+rows*1.25+0.3
 return table.concat({
  "formspec_version[4]size[11.75,"..(y+7.75).."]",
  "label[0.375,0.375;Smeltery Controller]",
  slots>0 and slot_bg(0.375,0.75,math.min(slots,8),rows) or "",
  slots>0 and "list[context;melt;0.375,0.75;8,"..rows..";]" or "",
  "label[10.4,0.375;Lava]",slot_bg(10.4,0.75,1,1),"list[context;fuel;10.4,0.75;1,1;]",
  "textarea[0.375,"..y..";11,2.3;;;"..core.formspec_escape(table.concat(lines,"\n")).."]",
  slot_bg(0.375,y+2.6,9,3),"list[current_player;main;0.375,"..(y+2.6)..";9,3;9]",
  slot_bg(0.375,y+6.55,9,1),"list[current_player;main;0.375,"..(y+6.55)..";9,1;]",
  "listring[context;melt]listring[current_player;main]",
 })
end

local function resize(inv,size)
 local items=inv:get_list("melt") or {}
 local spill={}
 for i=size+1,#items do if not items[i]:is_empty() then spill[#spill+1]=items[i] end end
 inv:set_size("melt",size)
 return spill
end

-- One second of smeltery work; also used by tests.
function era_playtest.smeltery_tick(pos,dtime)
 local meta=core.get_meta(pos)
 local inv=meta:get_inventory()
 local shape,reason=era_playtest.smeltery_scan(pos)
 local slots=shape and math.min(shape.volume,32) or 0
 if inv:get_size("melt")~=slots then
  for _,stack in ipairs(resize(inv,slots)) do core.add_item(vector.offset(pos,0,1,0),stack) end
 end
 local pool,fuel=molten(meta),meta:get_float("fuel")
 local busy=false
 for i=1,slots do if MELTS[inv:get_stack("melt",i):get_name()] then busy=true;break end end
 if shape and busy and fuel<=0 and inv:get_stack("fuel",1):get_name()=="mcl_buckets:bucket_lava" then
  inv:set_stack("fuel",1,"mcl_buckets:bucket_empty")
  fuel=LAVA_SECONDS
 end
 if shape and busy and fuel>0 then
  fuel=math.max(0,fuel-dtime)
  local capacity=shape.volume*PER_BLOCK
  for i=1,slots do
   local stack=inv:get_stack("melt",i)
   local melt=MELTS[stack:get_name()]
   if melt then
    local key="heat"..i
    local heat=meta:get_float(key)+dtime
    -- 4 s per ingot's worth, so ores take 8 s and blocks 36 s.
    if heat>=melt.amount/INGOT*4 and total(pool)+melt.amount<=capacity then
     pool[melt.metal]=(pool[melt.metal] or 0)+melt.amount
     stack:take_item(1)
     inv:set_stack("melt",i,stack)
     heat=0
    end
    meta:set_float(key,heat)
   else
    meta:set_float("heat"..i,0)
   end
  end
 end
 meta:set_float("fuel",fuel)
 meta:set_string("molten",core.serialize(pool))
 meta:set_string("formspec",formspec(pos,shape,reason,pool,fuel))
 meta:set_string("infotext",shape and ("Smeltery: "..total(pool).." mB molten") or ("Smeltery incomplete: "..reason))
 return shape
end

local function allow_put(pos,listname,_,stack,player)
 local name=player and player:get_player_name() or ""
 if core.is_protected(pos,name) then core.record_protection_violation(pos,name);return 0 end
 if listname=="melt" then return MELTS[stack:get_name()] and stack:get_count() or 0 end
 if listname=="fuel" then return stack:get_name()=="mcl_buckets:bucket_lava" and 1 or 0 end
 return 0
end

local drop=mcl_util and mcl_util.drop_items_from_meta_container and mcl_util.drop_items_from_meta_container({"melt","fuel"})
core.register_craftitem("era_playtest:grout",{description="Grout",
 _tt_help="Bake in a furnace into seared bricks.",inventory_image="default_clay_lump.png^[colorize:#9a9590:150"})
core.register_craftitem("era_playtest:seared_brick",{description="Seared Brick",
 inventory_image="default_clay_brick.png^[colorize:#3b3633:170"})
core.register_node("era_playtest:seared_bricks",{description="Seared Bricks",
 _tt_help="Walls and floor of a smeltery.",tiles={SEARED},is_ground_content=false,
 groups={pickaxey=1,seared=1,building_block=1},sounds=mcl_sounds and mcl_sounds.node_sound_stone_defaults() or nil,
 _mcl_hardness=3,_mcl_blast_resistance=9})
core.register_node("era_playtest:smeltery_controller",{description="Smeltery Controller",
 _tt_help="Place in a seared brick wall facing out. Melts ores into double metal.\nMolten metal is lost if the controller is broken.",
 tiles={SEARED,SEARED,SEARED,SEARED,SEARED,"blast_furnace_front.png^[colorize:#3b3633:120"},
 paramtype2="facedir",is_ground_content=false,
 groups={pickaxey=1,seared=1,container=4},sounds=mcl_sounds and mcl_sounds.node_sound_stone_defaults() or nil,
 _mcl_hardness=3,_mcl_blast_resistance=9,
 on_construct=function(pos)
  local inv=core.get_meta(pos):get_inventory()
  inv:set_size("fuel",1);inv:set_size("melt",0)
  era_playtest.smeltery_tick(pos,0)
  core.get_node_timer(pos):start(1)
 end,
 on_timer=function(pos,elapsed) era_playtest.smeltery_tick(pos,math.min(elapsed,5));return true end,
 on_punch=function(pos) era_playtest.smeltery_tick(pos,0) end,
 allow_metadata_inventory_put=allow_put,
 allow_metadata_inventory_move=function(pos,from_list,_,to_list,_,count,player)
  if from_list~=to_list then return 0 end
  return core.is_protected(pos,player:get_player_name()) and 0 or count
 end,
 allow_metadata_inventory_take=function(pos,_,_,stack,player)
  return core.is_protected(pos,player:get_player_name()) and 0 or stack:get_count()
 end,
 after_dig_node=drop,
})

core.register_craft({type="shapeless",output="era_playtest:grout 2",recipe={"mcl_core:sand","mcl_core:gravel","mcl_core:clay_lump"}})
core.register_craft({type="cooking",output="era_playtest:seared_brick",recipe="era_playtest:grout",cooktime=10})
local b="era_playtest:seared_brick"
core.register_craft({output="era_playtest:seared_bricks",recipe={{b,b},{b,b}}})
core.register_craft({output="era_playtest:smeltery_controller",recipe={{b,b,b},{b,"",b},{b,b,b}}})

core.register_on_mods_loaded(function()
 for item in pairs(MELTS) do
  if not core.registered_items[item] then MELTS[item]=nil end
 end
end)
