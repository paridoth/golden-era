-- SPDX-License-Identifier: GPL-3.0-or-later
-- This is an iron-pick checkpoint, not a simulated human playthrough. Devices are
-- test fixtures. Ore inputs come from real terrain and item pickup. A native oak
-- is grown from a fixture sapling so a barren sample biome cannot hide leaf tests.
-- Processing uses native callbacks and normal server timers, without power gifts.
local done=false
local function finish(ok,message)
 if done then return end
 done=true
 core.log(ok and "action" or "error","ERA SURVIVAL SMOKE "..(ok and "PASS: " or "FAIL: ")..message)
 core.request_shutdown("Survival materials smoke finished",false,0)
end
local function checked(f)
 local ok,err=xpcall(f,debug.traceback)
 if not ok then finish(false,err) end
end
local function eq(a,b,label) assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local lo,hi=vector.new(-80,-128,-80),vector.new(79,63,79)
local inventory=core.create_detached_inventory("era_survival_materials",{})
inventory:set_size("main",96);inventory:set_size("offhand",1)
local wield=ItemStack("mcl_tools:pick_iron")
local actor={is_fake_player=true,is_player=function() return true end,
 get_player_name=function() return "" end,get_inventory=function() return inventory end,
 get_wielded_item=function() return wield end,set_wielded_item=function(_,stack) wield=stack end}
local function pickup(stack)
 local remaining=core.item_pickup(stack,actor,{type="nothing"},1)
 assert(remaining:is_empty(),"Acquisition inventory overflow: "..remaining:to_string())
end
local function harvest(name,count,tool,from,to)
 wield=ItemStack(tool or "mcl_tools:pick_iron")
 local positions=core.find_nodes_in_area(from or lo,to or hi,{name})
 assert(#positions>=count,"Generated sample does not contain enough "..name)
 for i=1,count do
  local pos=positions[i];local node=core.get_node(pos)
  assert(mcl_autogroup.can_harvest(node.name,wield:get_name(),actor),"Checkpoint tool cannot harvest "..node.name)
  assert(core.node_dig(pos,node,actor),"Native dig rejected "..node.name)
  eq(core.get_node(pos).name,"air","Harvest removes the node")
  local found=false
  for _,obj in ipairs(core.get_objects_inside_radius(pos,1.8)) do
   local entity=obj:get_luaentity()
   if entity and entity.name=="__builtin:item" and entity.itemstring~="" then
    pickup(ItemStack(entity.itemstring));obj:remove();found=true
   end
  end
  assert(found,"Dig did not produce a harvestable item: "..node.name)
 end
end
local function take_input(stack)
 stack=ItemStack(stack)
 assert(inventory:contains_item("main",stack),"Missing gathered input: "..stack:to_string())
 eq(inventory:remove_item("main",stack):get_count(),stack:get_count(),"Consume gathered input")
 return stack
end
local function craft(items,width,expected)
 local input={}
 for i,name in ipairs(items) do input[i]=name=="" and ItemStack("") or take_input(name) end
 local result,after=core.get_craft_result({method="normal",width=width,items=input})
 eq(result.item:get_name(),expected,"Native crafting output")
 pickup(result.item)
 for _,stack in ipairs(after.items) do if not stack:is_empty() then pickup(stack) end end
 for _,stack in ipairs(result.replacements or {}) do pickup(stack) end
end
local function pos(index) return vector.new(index*2,200,0) end
local function inv(p) return core.get_meta(p):get_inventory() end
local function device(p,name)
 core.set_node(p,{name=name})
 local def=assert(core.registered_nodes[name]);if def.on_construct then def.on_construct(p) end
end
local function put(p,list,index,stack)
 stack=take_input(stack)
 local def=core.registered_nodes[core.get_node(p).name]
 if def.allow_metadata_inventory_put then
  eq(def.allow_metadata_inventory_put(p,list,index,stack,actor),stack:get_count(),"Native inventory put permission")
 end
 assert(inv(p):get_stack(list,index):is_empty(),"Target fixture slot must start empty")
 inv(p):set_stack(list,index,stack)
 if def.on_metadata_inventory_put then def.on_metadata_inventory_put(p,list,index,stack,actor) end
end
local function collect(p,expected,count)
 local stack=inv(p):get_stack("dst",1)
 if stack:get_name()~=expected or stack:get_count()<count then return false end
 eq(stack:get_count(),count,"Exact native processed quantity")
 inv(p):set_stack("dst",1,"");pickup(stack)
 return true
end
local function run()
 eq(core.settings:get("mg_name"),"v7","Normal terrain generator")
 assert(not core.settings:get_bool("creative_mode"),"Survival quantities")
 assert(not core.get_modpath("era_thermal"),"Historical custom machines are separate")
 assert(not core.is_creative_enabled(""),"Checkpoint actor has no creative exemption")
 for _,name in ipairs({"elepower_dynamics:stone_with_lead","elepower_dynamics:stone_with_tin",
  "moreores:mineral_silver","elepower_dynamics:stone_with_zinc","elepower_dynamics:stone_with_nickel",
  "mcl_core:stone_with_iron","mcl_copper:stone_with_copper","mcl_core:stone_with_redstone"}) do
  local nodes=core.find_nodes_in_area(lo,hi,{name})
  assert(#nodes>0,"World generates required ore: "..name)
  core.log("action","Survival generated ore "..name..": "..#nodes)
  harvest(name,1)
 end
 harvest("mcl_core:stone_with_iron",1)
 harvest("mcl_copper:stone_with_copper",1)
 harvest("mcl_core:stone_with_coal",18)
 local tree=vector.new(0,200,12)
 core.set_node(vector.offset(tree,0,-1,0),{name="mcl_core:dirt"})
 core.set_node(tree,{name="mcl_trees:sapling_oak"})
 mcl_trees.grow_tree(tree,core.get_node(tree))
 harvest("group:leaves",6,"mcl_tools:shears",vector.new(-8,199,4),vector.new(8,220,20))
 -- Mineclonia's sample tree leaves share one item. Select six actual gathered
 -- leaves without assuming which biome the fixed seed places in this region.
 local leaves={}
 for _,stack in ipairs(inventory:get_list("main")) do
  if core.get_item_group(stack:get_name(),"leaves")>0 then
   for _=1,stack:get_count() do if #leaves<6 then leaves[#leaves+1]=stack:get_name() end end
  end
 end
 eq(#leaves,6,"Gathered six leaves with native shears")
 craft(leaves,0,"basic_materials:oil_extract")
 core.load_area(vector.new(-8,196,-5),vector.new(24,204,5))
 assert(core.forceload_block(pos(0),true),"Activate native processing fixture")
 assert(core.forceload_block(pos(8),true),"Activate second processing mapblock")
 local inputs={"mcl_raw_ores:raw_iron","mcl_copper:raw_copper 2","moreores:silver_lump",
  "basic_materials:oil_extract 2","elepower_dynamics:tin_lump","elepower_dynamics:lead_lump"}
 for index,stack in ipairs(inputs) do
  local p=pos(index-1);device(p,"mcl_furnaces:furnace")
  put(p,"fuel",1,"mcl_core:coal_lump 2");put(p,"src",1,stack)
 end
 local grinder,crank,alloy,dust_furnace=pos(6),vector.offset(pos(6),0,1,0),pos(7),pos(8)
 device(grinder,"elepower_machines:grindstone");device(crank,"elepower_machines:crank")
 put(grinder,"src",1,"mcl_raw_ores:raw_iron")
 device(alloy,"elepower_machines:coal_alloy_furnace");put(alloy,"fuel",1,"mcl_core:coal_lump 2")
 device(dust_furnace,"mcl_furnaces:furnace");put(dust_furnace,"fuel",1,"mcl_core:coal_lump 2")
 local stage={};local started=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   if not stage.iron and collect(pos(0),"mcl_core:iron_ingot",1) then
    stage.iron=true;put(pos(0),"src",1,"mcl_core:iron_ingot")
   end
   if not stage.steel and collect(pos(0),"elepower_dynamics:steel_ingot",1) then stage.steel=true end
   if not stage.copper and collect(pos(1),"mcl_copper:copper_ingot",2) then stage.copper=true end
   if not stage.silver and collect(pos(2),"moreores:silver_ingot",1) then stage.silver=true end
   if not stage.paraffin and collect(pos(3),"basic_materials:paraffin",2) then
    stage.paraffin=true;put(pos(3),"src",1,"basic_materials:paraffin 2")
   end
   if not stage.plastic and collect(pos(3),"basic_materials:plastic_sheet",2) then stage.plastic=true end
   if not stage.tin and collect(pos(4),"elepower_dynamics:tin_ingot",1) then stage.tin=true end
   if not stage.lead and collect(pos(5),"elepower_dynamics:lead_ingot",1) then stage.lead=true end
   if not stage.dust then
    core.registered_nodes["elepower_machines:crank"].on_rightclick(crank,core.get_node(crank),actor,ItemStack(""),{type="node",under=crank,above=vector.offset(crank,0,1,0)})
    if collect(grinder,"elepower_dynamics:iron_dust",2) then
     stage.dust=true;put(dust_furnace,"src",1,"elepower_dynamics:iron_dust 2")
    end
   end
   if stage.dust and not stage.doubled and collect(dust_furnace,"mcl_core:iron_ingot",2) then stage.doubled=true end
   if stage.copper and stage.silver and not stage.alloy_started then
    put(alloy,"src",1,"mcl_copper:copper_ingot 2");put(alloy,"src",2,"moreores:silver_ingot");stage.alloy_started=true
   end
   if not stage.brass and collect(alloy,"basic_materials:brass_ingot",3) then stage.brass=true end
   if stage.steel and stage.plastic and stage.tin and stage.lead and stage.doubled and stage.brass then
    assert(inv(grinder):is_empty("src"),"Hand grinder consumed raw iron")
    assert(inv(alloy):is_empty("src"),"Coal alloy furnace consumed copper and silver")
    assert(inv(pos(0)):is_empty("src"),"Ordinary furnace completed second iron smelt")
    finish(true,"v7 lead/tin/silver/zinc/nickel/iron/copper/redstone mined with iron pick and collected via item pickup; native oak grown from fixture sapling supplies sheared leaves, oil and two plastic smelts; native furnace creates low-carbon steel; hand-cranked raw iron yields two smelted ingots; coal alloy furnace consumes 2 copper + 1 silver into 3 brass. Detached actor and provided device fixtures; no workshop build or injected power.")
   elseif core.get_us_time()-started>120000000 then
    error("Material processing timed out: "..core.write_json(stage))
   else core.after(0.2,poll) end
  end)
 end
 core.after(0.2,poll)
end
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(lo,hi,function(_,_,left)
   if left==0 then core.after(0,function()
    checked(function() core.load_area(lo,hi)
     core.emerge_area(vector.new(-8,196,-8),vector.new(24,224,24),function(_,_,remaining)
      if remaining==0 then core.after(0,function() checked(run) end) end
     end)
    end)
   end) end
  end)
 end)
end)
