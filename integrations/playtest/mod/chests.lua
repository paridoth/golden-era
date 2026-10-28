-- SPDX-License-Identifier: GPL-3.0-or-later
-- Larger chests in the spirit of Iron Chests: copper, iron, gold and diamond
-- tiers with the same slot counts, each made from the previous chest. They
-- reuse Mineclonia's chest model and texture, tinted per tier, and accept
-- Pipeworks tubes on every side but the front.
local TIERS={
 {id="copper",name="Copper Chest",cols=9,rows=5,tint="#c8693c:150",metal="mcl_copper:copper_ingot",from="mcl_chests:chest"},
 {id="iron",name="Iron Chest",cols=9,rows=6,tint="#d6d6d6:170",metal="mcl_core:iron_ingot",from="era_playtest:chest_copper"},
 {id="gold",name="Gold Chest",cols=9,rows=9,tint="#f2c230:160",metal="mcl_core:gold_ingot",from="era_playtest:chest_iron"},
 {id="diamond",name="Diamond Chest",cols=12,rows=9,tint="#5fe0d8:150",metal="mcl_core:diamond",from="era_playtest:chest_gold"},
}
era_playtest.chest_tiers=TIERS

local function allowed(pos,count,player)
 local name=player and player:get_player_name() or ""
 if core.is_protected(pos,name) then core.record_protection_violation(pos,name);return 0 end
 return count
end

function era_playtest.chest_formspec(pos,tier,label)
 local width=math.max(tier.cols,9)*1.25+0.5
 local list="nodemeta:"..pos.x..","..pos.y..","..pos.z
 local player_y=0.75+tier.rows*1.25+0.6
 local player_x=0.375+(math.max(tier.cols,9)-9)*1.25/2
 local slots=mcl_formspec and mcl_formspec.get_itemslot_bg_v4 or function() return "" end
 return table.concat({
  "formspec_version[4]size["..width..","..(player_y+5.3).."]",
  "label[0.375,0.375;"..core.formspec_escape(label).."]",
  slots(0.375,0.75,tier.cols,tier.rows),
  "list["..list..";main;0.375,0.75;"..tier.cols..","..tier.rows..";]",
  "label["..player_x..","..(player_y-0.25)..";Inventory]",
  slots(player_x,player_y,9,3),
  "list[current_player;main;"..player_x..","..player_y..";9,3;9]",
  slots(player_x,player_y+3.95,9,1),
  "list[current_player;main;"..player_x..","..(player_y+3.95)..";9,1;]",
  "listring["..list..";main]listring[current_player;main]",
 })
end

local drop=mcl_util and mcl_util.drop_items_from_meta_container and mcl_util.drop_items_from_meta_container({"main"})
for _,tier in ipairs(TIERS) do
 local slots=tier.cols*tier.rows
 local texture="mcl_chests_normal.png^[colorize:"..tier.tint
 core.register_node("era_playtest:chest_"..tier.id,{
  description=tier.name,
  _tt_help=slots.." inventory slots",
  _doc_items_longdesc=tier.name.." holds "..slots.." stacks. Craft it from the previous chest surrounded by its material.",
  drawtype="mesh",mesh="mcl_chests_chest.obj",tiles={texture},use_texture_alpha="clip",
  selection_box={type="fixed",fixed={-0.4375,-0.5,-0.4375,0.4375,0.375,0.4375}},
  collision_box={type="fixed",fixed={-0.4375,-0.5,-0.4375,0.4375,0.375,0.4375}},
  paramtype="light",paramtype2="facedir",is_ground_content=false,
  groups={handy=1,pickaxey=1,container=2,deco_block=1,piglin_protected=1,tubedevice=1,tubedevice_receiver=1},
  sounds=mcl_sounds and mcl_sounds.node_sound_metal_defaults() or nil,
  _mcl_hardness=3,_mcl_blast_resistance=6,
  on_construct=function(pos) core.get_meta(pos):get_inventory():set_size("main",slots) end,
  after_place_node=function(pos,_,itemstack)
   core.get_meta(pos):set_string("name",itemstack:get_meta():get_string("name"))
   pipeworks.after_place(pos)
  end,
  tube={
   insert_object=function(pos,_,stack) return core.get_meta(pos):get_inventory():add_item("main",stack) end,
   can_insert=function(pos,_,stack) return core.get_meta(pos):get_inventory():room_for_item("main",stack) end,
   input_inventory="main",
   connect_sides={left=1,right=1,back=1,top=1,bottom=1},
  },
  on_rightclick=function(pos,_,clicker)
   if not clicker or not clicker:is_player() then return end
   local label=core.get_meta(pos):get_string("name")
   core.show_formspec(clicker:get_player_name(),"era_playtest:chest",
    era_playtest.chest_formspec(pos,tier,label~="" and label or tier.name))
  end,
  allow_metadata_inventory_move=function(pos,_,_,_,_,count,player) return allowed(pos,count,player) end,
  allow_metadata_inventory_put=function(pos,_,_,stack,player) return allowed(pos,stack:get_count(),player) end,
  allow_metadata_inventory_take=function(pos,_,_,stack,player) return allowed(pos,stack:get_count(),player) end,
  after_dig_node=function(pos,oldnode,oldmetadata,digger)
   if drop then drop(pos,oldnode,oldmetadata,digger) end
   pipeworks.after_dig(pos,oldnode,oldmetadata,digger)
  end,
  on_rotate=pipeworks.on_rotate,
 })
 local m,c=tier.metal,tier.from
 if tier.id=="diamond" then
  local g="mcl_core:glass"
  core.register_craft({output="era_playtest:chest_diamond",recipe={{g,g,g},{m,c,m},{g,g,g}}})
 else
  core.register_craft({output="era_playtest:chest_"..tier.id,recipe={{m,m,m},{m,c,m},{m,m,m}}})
 end
end
