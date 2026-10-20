-- Disposable native audit; archive game files are unchanged.
local store=core.get_mod_storage()
local saved=core.deserialize(store:get_string('audit')) or {}
local phase=store:get_int('phase')
local done=false
local function eq(a,b,s) assert(a==b,s..': '..tostring(a)..' ~= '..tostring(b)) end
local function log(s) core.log('action','Tree audit: '..s) end
local function finish(ok,s)
 if done then return end;done=true
 core.log(ok and 'action' or 'error','ERA TREE AUDIT '..(ok and 'PASS: ' or 'FAIL: ')..s)
 core.request_shutdown('Tree audit checkpoint',false,0)
end
local function checked(f) local ok,e=xpcall(f,debug.traceback);if not ok then finish(false,e) end end
local function p(x,z,y) return vector.new(x,y or 200,z or 0) end
local function inv(pos) return core.get_meta(pos):get_inventory() end
local function def(pos) return assert(core.registered_nodes[core.get_node(pos).name]) end
local function place(pos,name,param2)
 assert(core.registered_nodes[name],'Registered fixture '..name)
 core.set_node(pos,{name=name,param2=param2 or 0});core.get_meta(pos):set_string('owner','')
end
local function qty(list,name) local n=0;for _,s in ipairs(list or {}) do if s:get_name()==name then n=n+s:get_count() end end;return n end
local function count(pos,list,name) return qty(inv(pos):get_list(list),name) end
local function sig(pos,list) local a={};for _,s in ipairs(inv(pos):get_list(list) or {}) do a[#a+1]=s:to_string() end;return table.concat(a,'\n') end
local oak,leaves,sapling='mcl_trees:tree_oak','mcl_trees:leaves_oak','mcl_trees:sapling_oak'
local farm={planter=p(0,-4,198),tree=p(0,-4),harvester=p(0),barrel=p(5),vacuum=p(2,-4),vault=p(8,3),seed_filter=p(5,0,201)}
local ctrl={vacuum=p(48),barrel=p(51),vault=p(54)}
local data=saved.data or {generated={},cuts=0,plantings=0,decay_nodes=0,harvest_leaf_nodes=0,bone_used=0,initial_saplings=9}
local function add_generated(list)
 for _,s in ipairs(list) do s=ItemStack(s);local n=s:get_name();data.generated[n]=(data.generated[n] or 0)+s:get_count() end
end
local function in_farm(pos) return pos.x>=-8 and pos.x<=10 and pos.z>=-12 and pos.z<=4 and pos.y>=198 and pos.y<=218 end
local owned=core.create_detached_inventory('era_tree_actor',{});owned:set_size('main',96);owned:set_size('offhand',1);owned:set_size('hand',1)
local actor={is_fake_player=true,is_player=function() return true end,get_player_name=function() return '' end,
 get_inventory=function() return owned end,get_wielded_item=function() return ItemStack('') end,
 set_wielded_item=function() end,get_player_control=function() return {} end}
local function stamp(name,n,tag,wear)
 local s=ItemStack(name..' '..n);s:get_meta():set_string('era_tree',tag);s:set_wear(wear or 0);return s
end
local copper=stamp('mcl_copper:copper_ingot',5,'vacuum owned copper',321)
local tool=stamp('mcl_tools:pick_iron',1,'vacuum owned tool',4321)
local function packet_list(center,r)
 local out={}
 for _,e in pairs(pipeworks.luaentity.entities or {}) do
  if e.name=='pipeworks:tubed_item' and vector.distance(e:get_pos(),center)<r then
   out[#out+1]=ItemStack(e.itemstring)
  end
 end
 return out
end
local function ground_list(center,r)
 local out={};for _,o in ipairs(core.get_objects_inside_radius(center,r)) do
  local e=o:get_luaentity();if e and e.name=='__builtin:item' and e.itemstring~='' then out[#out+1]=ItemStack(e.itemstring) end
 end;return out
end
local function assert_fields(list)
 local n=0
 for _,s in ipairs(list) do
  local expected=s:get_name()==copper:get_name() and copper or (s:get_name()==tool:get_name() and tool or nil)
  if expected then
   eq(s:get_wear(),expected:get_wear(),'Vacuum payload wear')
   eq(s:get_meta():get_string('era_tree'),expected:get_meta():get_string('era_tree'),'Vacuum payload metadata')
   n=n+s:get_count()
  end
 end
 return n
end
local function control_ledger()
 local a=packet_list(ctrl.vacuum,10);local b=ground_list(ctrl.vacuum,10)
 local stored=inv(ctrl.barrel):get_list('main');local all={}
 for _,ls in ipairs({a,b,stored}) do for _,s in ipairs(ls) do all[#all+1]=s end end
 eq(qty(all,copper:get_name()),5,'All5 owned copper across tube/ground/barrel')
 eq(qty(all,tool:get_name()),1,'One owned tool across tube/ground/barrel')
 eq(assert_fields(all),6,'All6 exact owned payload fields')
 return #a,#b,qty(stored,copper:get_name())+qty(stored,tool:get_name())
end
local current,decay_context
local native_drops=core.get_node_drops
core.get_node_drops=function(name,...)
 local result=native_drops(name,...)
 if name==leaves or name==leaves..'_orphan' then
  if current then data.harvest_leaf_nodes=data.harvest_leaf_nodes+1
  elseif decay_context then data.decay_nodes=data.decay_nodes+1;add_generated(result) end
 end
 return result
end
-- Instrument only callbacks reached by the engine; never invoke an ABM manually.
local decay_found=false
for _,abm in pairs(core.registered_abms) do
 if abm.label=='Leaf decay' then
  decay_found=true;local native=abm.action
  abm.action=function(pos,node,...)
   local previous=decay_context;decay_context=in_farm(pos) and true or nil
   local r=native(pos,node,...);decay_context=previous;return r
  end
 end
end
assert(decay_found,'Native Mineclonia leaf decay ABM exists')
local native_capitate=elefarm.tc.capitate_tree
local cut_during_timer=false
elefarm.tc.capitate_tree=function(pos,...)
 local drops=native_capitate(pos,...)
 if current and drops and #drops>0 then
  data.cuts=data.cuts+1;add_generated(drops);cut_during_timer=true
  log('Stock cutter actual drops='..core.write_json(drops)..'; total cut count='..data.cuts)
 end
 return drops
end
for _,name in ipairs({'elepower_farming:harvester','elepower_farming:harvester_active'}) do
 local native=assert(core.registered_nodes[name].on_timer)
 core.override_item(name,{on_timer=function(pos,elapsed)
  local selected=vector.equals(pos,farm.harvester)
  local energy=core.get_meta(pos):get_int('storage');local sludge=core.get_meta(pos):get_int('sludge_fluid_storage')
  current=selected and true or nil;cut_during_timer=false
  local result=native(pos,elapsed)
  if selected and cut_during_timer then
   eq(energy-core.get_meta(pos):get_int('storage'),128,'Actual productive tree sweep consumes128E')
   eq(core.get_meta(pos):get_int('sludge_fluid_storage')-sludge,10,'Actual tree sweep adds10mB sludge')
   -- Delimit one measured tree; stock off state, no state-button UI claim.
   core.get_meta(pos):set_int('state',1)
  end
  current=nil;return result
 end})
end
local native_planter=assert(core.registered_nodes['elepower_farming:planter'].on_timer)
core.override_item('elepower_farming:planter',{on_timer=function(pos,elapsed)
 local before=count(pos,'src',sapling);local result=native_planter(pos,elapsed)
 if vector.equals(pos,farm.planter) then
  local used=before-count(pos,'src',sapling)
  if used>0 then data.plantings=data.plantings+used;eq(used,1,'Single dirt plot consumes one physical sapling')
   core.get_meta(pos):set_int('state',1)
   log('Native planter placed one sapling; total counted plantings='..data.plantings..'; source now='..count(pos,'src',sapling))
  end
 end
 return result
end})
local function facedir(direction)
 for n=0,23 do if vector.equals(pipeworks.facedir_to_right_dir(n),direction) then return n end end;error('Filter orientation')
end
local function generator(pos)
 place(pos,'elepower_machines:generator')
 local fuel=ItemStack('mcl_core:coal_lump 4')
 eq(def(pos).allow_metadata_inventory_put(pos,'src',1,fuel,actor),4,'Generator accepts counted fixture coal')
 inv(pos):set_stack('src',1,fuel);def(pos).on_metadata_inventory_put(pos,'src',1,fuel,actor)
end
local function configure_vacuum(pos,r)
 def(pos).on_receive_fields(pos,'',{dist=tostring(r)},actor)
 eq(core.get_meta(pos):get_int('dist'),r,'Native adjustable vacuum configuration')
end
local function transfer(pos,list,to,list_to,stack)
 local s=inv(pos):remove_item(list,ItemStack(stack));eq(s:to_string(),ItemStack(stack):to_string(),'Transfer owned full stack')
 assert(inv(to):add_item(list_to,s):is_empty(),'Owned transfer target room')
end
local function tree_nodes()
 local a,b=vector.new(-6,200,-10),vector.new(6,217,2)
 return core.find_nodes_in_area(a,b,{'group:tree'}),core.find_nodes_in_area(a,b,{'group:leaves'})
end
local function fertilize()
 local bone='mcl_bone_meal:bone_meal'
 for _=1,32 do
  if core.get_node(farm.tree).name~=sapling then break end
  local s=inv(farm.vault):remove_item('main',ItemStack(bone));eq(s:get_count(),1,'Counted owned bone meal drawn')
  local leftover=core.registered_items[bone].on_place(s,actor,{type='node',under=farm.tree,above=vector.offset(farm.tree,0,1,0)})
  assert(leftover:is_empty(),'Native bone meal consumed');data.bone_used=data.bone_used+1
 end
 eq(core.get_node(farm.tree).name,oak,'Native bone meal grew ordinary oak')
 local logs,ls=tree_nodes();data.grown_logs=#logs;data.grown_leaves=#ls
 log('Native oak growth actual nodes: logs='..#logs..',leaves='..#ls..'; counted supplied bone meal used='..data.bone_used)
end
local function verify_farm_ledger()
 local packets=packet_list(p(1,-3),22);local ground=ground_list(p(1,-3),22)
 for name,n in pairs(data.generated) do
  if name~=sapling then
   eq(count(farm.barrel,'main',name)+count(farm.harvester,'dst',name)+qty(packets,name)+qty(ground,name),n,'Actual generated '..name..' conserved')
  end
 end
 local sap=count(farm.planter,'src',sapling)+count(farm.barrel,'main',sapling)+count(farm.harvester,'dst',sapling)+count(farm.vault,'main',sapling)+qty(packets,sapling)+qty(ground,sapling)
 eq(sap,data.initial_saplings+(data.generated[sapling] or 0)-data.plantings,'Physical sapling reserve ledger, excluding counted planted nodes')
 return #packets,#ground
end
local function initial()
 eq(ele.external.ing.tree,oak,'Canonical oak compatibility');eq(ele.external.ing.leaves,leaves,'Canonical oak leaves compatibility')
 for x=-10,58 do for z=-12,4 do place(p(x,z,199),'mcl_core:stone') end end
 place(p(0,-4,199),'mcl_core:dirt')
 place(farm.planter,'elepower_farming:planter');place(farm.harvester,'elepower_farming:harvester')
 place(farm.barrel,'mcl_barrels:barrel_closed');place(farm.vault,'mcl_barrels:barrel_closed')
 inv(farm.vault):add_item('main',sapling);inv(farm.vault):add_item('main','mcl_bone_meal:bone_meal 64')
 -- One owned selector is retained in the vault;8 other physical saplings are supply.
 eq(def(farm.planter).allow_metadata_inventory_put(farm.planter,'layout',5,ItemStack(sapling),actor),0,'Native logical sapling selector')
 local supply=ItemStack(sapling..' 8');eq(def(farm.planter).allow_metadata_inventory_put(farm.planter,'src',1,supply,actor),8,'Owned sapling source accepted')
 inv(farm.planter):set_stack('src',1,supply);if def(farm.planter).on_metadata_inventory_put then def(farm.planter).on_metadata_inventory_put(farm.planter,'src',1,supply,actor) end
 place(p(1),'pipeworks:mese_filter',facedir(vector.new(1,0,0)))
 for x=2,4 do place(p(x),'pipeworks:tube_1') end
 place(p(1,1),'mesecons_blinkyplant:blinky_plant_off')
 place(farm.vacuum,'pipeworks:mese_sand_tube_1');configure_vacuum(farm.vacuum,8)
 for z=-3,-1 do place(p(2,z),'pipeworks:tube_1') end
 place(farm.seed_filter,'pipeworks:mese_filter',facedir(vector.new(0,1,0)))
 eq(def(farm.seed_filter).allow_metadata_inventory_put(farm.seed_filter,'main',1,ItemStack(sapling),actor),0,'Owned native sapling filter preview')
 place(p(6,0,201),'mesecons_blinkyplant:blinky_plant_off')
 for x=-2,5 do place(p(x,0,202),'pipeworks:tube_1') end
 for y=198,201 do place(p(-2,0,y),'pipeworks:tube_1') end
 for z=-4,-1 do place(p(-2,z,198),'pipeworks:tube_1') end
 place(p(-1,-4,198),'pipeworks:tube_1')
 generator(p(0,2))
 for _,q in ipairs({p(0,1),p(1,2),p(1,2,199),p(1,2,198),p(0,2,198),p(0,1,198),p(0,0,198),p(0,-1,198),p(0,-2,198),p(0,-3,198)}) do place(q,'elepower_dynamics:conduit') end
 eq(core.get_meta(farm.planter):get_int('storage'),0,'Planter has no energy gift');eq(core.get_meta(farm.harvester):get_int('storage'),0,'Harvester has no energy gift')
 place(ctrl.vacuum,'pipeworks:sand_tube_1');place(p(49),'pipeworks:tube_1');place(p(50),'pipeworks:tube_1')
 place(ctrl.barrel,'mcl_barrels:barrel_closed');place(ctrl.vault,'mcl_barrels:barrel_closed')
 for index=1,inv(ctrl.barrel):get_size('main') do inv(ctrl.barrel):set_stack('main',index,'mcl_core:cobble 64') end
 core.add_item(vector.offset(ctrl.vacuum,0,1,0),copper);core.add_item(vector.offset(ctrl.vacuum,0,1,0),tool)
 for x=-3,54 do for z=-5,2 do for y=198,202 do pipeworks.scan_for_tube_objects(p(x,z,y)) end end end
 data.stage='plant';data.started=core.get_gametime();log('Fixture start:9 physical saplings (1 retained selector +8 supply),64 bone meal,4 coal, zero injected energy; native clocks/timers enabled')
 local began=core.get_us_time();local last=0
 local function poll()
  if done then return end
  checked(function()
   local age=(core.get_us_time()-began)/1000000
   if data.stage=='plant' and core.get_node(farm.tree).name==sapling then fertilize();data.stage='harvest' end
   if data.stage=='harvest' and data.cuts>0 then
    local logs,ls=tree_nodes();log('After actual native cutter: remaining logs='..#logs..',leaves='..#ls..'; immediate leaf rolls='..data.harvest_leaf_nodes)
    data.remaining_logs=#logs;data.stage='decay'
   end
   if data.stage=='decay' then
    local logs,ls=tree_nodes()
    if #ls==0 or (age>240 and #logs>0) then
     local n,m=verify_farm_ledger();local a,b,c=control_ledger()
     if n==0 and m==0 and inv(farm.harvester):is_empty('dst') and a>0 and b==0 and c==0 then
      eq(data.cuts,1,'One measured native tree');eq(data.plantings,1,'One initial physical planting')
      local generated=data.generated[sapling] or 0
      eq(count(farm.planter,'src',sapling),7+generated,'Generated saplings returned through vacuum/filter to physical planter reserve')
      transfer(farm.planter,'src',farm.vault,'main',sapling..' 7')
      verify_farm_ledger()
      data.remaining_leaves=#ls;data.control_packets=a;data.stage='checkpoint'
      saved={data=data,farm_barrel=sig(farm.barrel,'main'),farm_vault=sig(farm.vault,'main'),planter=sig(farm.planter,'src'),control_barrel=sig(ctrl.barrel,'main')}
      store:set_string('audit',core.serialize(saved));store:set_int('phase',1)
      core.safe_file_write(core.get_worldpath()..'/tree-audit-checkpoint.json',core.write_json(data,true))
      log('Actual generated ledger='..core.write_json(data.generated)..'; native decay nodes='..data.decay_nodes..'; physical returned sapling reserve='..generated..'; pending owned control packets='..a)
      finish(true,'CHECKPOINT: exact archived game; counted native oak/coal/timers/leaf decay; vacuum→storage/physical sapling reserve; full destination retains exact copper/tool logical payloads')
      return
     end
    end
   end
   if age-last>=20 then
    last=age;local logs,ls=tree_nodes();local a,b,c=control_ledger()
    log('Progress age='..math.floor(age)..' stage='..data.stage..' logs='..#logs..' leaves='..#ls..' generated='..core.write_json(data.generated)..' planter='..count(farm.planter,'src',sapling)..' farm packets='..#packet_list(p(1,-3),22)..' ctrl packets/ground/stored='..a..'/'..b..'/'..c)
   end
   assert(age<330,'Bounded native tree/decay probe timeout stage='..data.stage)
   core.after(0.2,poll)
  end)
 end
 core.after(0.2,poll)
end
local function resumed()
 eq(sig(farm.barrel,'main'),saved.farm_barrel,'Owned wood/byproducts saved through real process restart')
 eq(sig(farm.vault,'main'),saved.farm_vault,'Owned physical selector/reserve/bone meal saved')
 eq(sig(farm.planter,'src'),saved.planter,'Actual returned saplings saved')
 eq(sig(ctrl.barrel,'main'),saved.control_barrel,'Full control destination unchanged through restart')
 verify_farm_ledger();local a,b,c=control_ledger();assert(a>0 and b==0 and c==0,'Nonempty logical owned vacuum payloads persist across process restart')
 log('Restart recovered '..a..' logical payloads with complete metadata/wear; no new items, power or fertilizer granted')
 for index=1,2 do local s=inv(ctrl.barrel):get_stack('main',index);assert(inv(ctrl.vault):add_item('main',s):is_empty());inv(ctrl.barrel):set_stack('main',index,'') end
 local can_replant=count(farm.planter,'src',sapling)>0
 if can_replant then core.get_meta(farm.planter):set_int('state',0) end
 local began=core.get_us_time()
 local function poll()
  if done then return end
  checked(function()
   local n,m,stored=control_ledger();verify_farm_ledger()
   if n==0 and m==0 and stored==6 and (not can_replant or data.plantings==2) then
    eq(count(ctrl.vault,'main','mcl_core:cobble'),128,'Two freed filler stacks remain physically owned')
    if can_replant then eq(core.get_node(farm.tree).name,sapling,'Native restart planter uses returned sapling as new planted node') end
    data.control_recovered=true;data.returned_sapling_replant=can_replant
    core.safe_file_write(core.get_worldpath()..'/tree-audit-complete.json',core.write_json(data,true))
    log('Final ledger='..core.write_json(data.generated)..'; counted plantings='..data.plantings..'; returned sapling replant='..tostring(can_replant)..'; pending control fully delivered after native capacity recovery')
    finish(true,'COMPLETE: saved exact vacuum logical stacks recovered after full destination freed; stock replant opportunity='..tostring(can_replant)..'; source game unchanged; no universal large-oak or leaf-block claim')
    return
   end
   assert(core.get_us_time()-began<70000000,'Bounded restart/recovery timeout')
   core.after(0.2,poll)
  end)
 end
 core.after(0.2,poll)
end
local started=false
core.register_node('era_tree_audit:marker',{drawtype='airlike',walkable=false,pointable=false})
core.register_lbm({name='era_tree_audit:ready',nodenames={'era_tree_audit:marker'},run_at_every_load=true,action=function()
 if started then return end;started=true
 local began=core.get_us_time()
 local function ready()
  if done then return end
  checked(function()
   local active=true
   for x=-1,3 do for z=-1,0 do for y=12,13 do if not core.compare_block_status(vector.new(x*16,y*16,z*16),'active') then active=false end end end end
   if active and pipeworks.luaentity.entities then
    log('Native archived paths: game='..core.get_game_info().path..'; Elepower='..core.get_modpath('elepower_farming')..'; Pipeworks='..core.get_modpath('pipeworks'))
    if phase==1 then resumed() else initial() end
   else assert(core.get_us_time()-began<30000000,'Bounded active block wait');core.after(0.2,ready) end
  end)
 end
 core.after(0.2,ready)
end})
core.register_on_mods_loaded(function()
 core.after(0,function()
  core.emerge_area(p(-16,-16,196),p(63,15,219),function(_,_,remaining)
   if remaining==0 then core.after(0,function() checked(function()
    core.load_area(p(-16,-16,196),p(63,15,219))
    for x=-1,3 do for z=-1,0 do for y=12,13 do assert(core.forceload_block(vector.new(x*16,y*16,z*16),true)~=false,'Request native fixture blocks') end end end
    if phase~=1 then place(p(12,12),'era_tree_audit:marker') end
   end) end) end
  end)
 end)
end)
