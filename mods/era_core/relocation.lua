-- SPDX-License-Identifier: GPL-3.0-or-later
-- Packages are world-local, one-use claims on server-side machine snapshots.
-- Inventory/mapblock/mod-storage writes do not form a forced-crash journal.
local storage=core.get_mod_storage()
era.package_storage=storage -- Trusted repair/integration access; never client data.
local ITEM="era_core:packed_machine"
local LIMIT=256*1024
local MAX_ID=2147483647
local PREFIX="relocation_packet:"
local busy,packing={},{}

local function integer(value,low,high)
 return type(value)=="number" and value==value and value>=low and value<=high and value==math.floor(value)
end
local function player_name(player)
 if not player or type(player.is_player)~="function" or not player:is_player() then return end
 local name=player:get_player_name()
 if type(name)=="string" and name~="" then return name end
end
local function interaction_actor(player,pos)
 local name=player_name(player)
 if not name then return nil,"A player must move the machine." end
 if not core.check_player_privs(name,{interact=true}) then return nil,"You need the interact privilege to move machines." end
 if type(pos)~="table" then return nil,"Choose a valid machine position." end
 for _,axis in ipairs({"x","y","z"}) do
  if not integer(pos[axis],-32768,32767) then return nil,"Choose a valid machine position." end
 end
 local location=type(player.get_pos)=="function" and player:get_pos()
 if type(location)~="table" then return nil,"Your position is unavailable; try again." end
 local distance=0
 for _,axis in ipairs({"x","y","z"}) do
  local coordinate=location[axis]
  if type(coordinate)~="number" or coordinate~=coordinate or coordinate<=-math.huge or coordinate>=math.huge then return nil,"Your position is unavailable; try again." end
  distance=distance+(coordinate-pos[axis])^2
 end
 if distance>36 then return nil,"Move closer; the target must be within 6 blocks." end
 return name
end
local function issuer()
 local nonce=storage:get_string("relocation_nonce")
 local raw=storage:get_string("relocation_next")
 if nonce=="" and raw=="" then
  local bytes=SecureRandom():next_bytes(16)
  nonce=bytes:gsub(".",function(char) return string.format("%02x",string.byte(char)) end)
  storage:set_string("relocation_nonce",nonce)
  storage:set_string("relocation_next","0")
  raw="0"
 end
 if #nonce~=32 or not nonce:match("^[0-9a-f]+$") or not (raw=="0" or raw:match("^[1-9]%d*$")) then return end
 local id=tonumber(raw)
 if not integer(id,0,MAX_ID) then return end
 return nonce,id
end
local function keys_only(value,allowed)
 for key in pairs(value) do if not allowed[key] then return false end end
 return true
end
local function validate_packet(packet)
 if type(packet)~="table" or not keys_only(packet,{schema=true,name=true,param1=true,param2=true,metadata=true}) or packet.schema~=1 then return false end
 if type(packet.name)~="string" or not era.machines[packet.name] or not core.registered_nodes[packet.name] then return false end
 if not integer(packet.param1,0,255) or not integer(packet.param2,0,255) then return false end
 local metadata=packet.metadata
 if type(metadata)~="table" or not keys_only(metadata,{fields=true,inventory=true}) or type(metadata.fields)~="table" or type(metadata.inventory)~="table" then return false end
 for key,value in pairs(metadata.fields) do
  if type(key)~="string" or type(value)~="string" then return false end
 end
 if metadata.fields.schema~="1" and metadata.fields.schema~="2" then return false end
 for list,items in pairs(metadata.inventory) do
  if type(list)~="string" or list=="" or type(items)~="table" then return false end
  local size=#items
  if size>32767 then return false end
  for index,value in pairs(items) do
   if not integer(index,1,size) or type(value)~="string" then return false end
   -- Reject parser truncation rather than silently changing a stored stack.
   if ItemStack(value):to_string()~=value then return false end
  end
  for index=1,size do if items[index]==nil then return false end end
 end
 return true
end
local function snapshot(pos,node)
 local metadata=core.get_meta(pos):to_table()
 for _,key in ipairs({"formspec","infotext","fault"}) do metadata.fields[key]=nil end
 for _,items in pairs(metadata.inventory) do
  for index,stack in ipairs(items) do items[index]=stack:to_string() end
 end
 local packet={schema=1,name=node.name,param1=node.param1 or 0,param2=node.param2 or 0,metadata=metadata}
 if not validate_packet(packet) then return nil,"Machine inventory cannot be preserved safely." end
 local encoded=core.serialize(packet)
 if #encoded>LIMIT then return nil,"Machine contents exceed the package size limit." end
 return encoded
end
local function log_failure(action,err)
 core.log("error","[Golden Era] Machine "..action.." failed: "..tostring(err))
end
local function set_record(key,value)
 storage:set_string(key,value)
 assert(storage:get_string(key)==value,"Could not update machine package record")
end
local function quarantine(token,encoded)
 -- Save recovery data before disabling any possibly duplicated live claim.
 local saved,save_err=pcall(set_record,"relocation_quarantine:"..token,encoded)
 local disabled,disable_err=pcall(set_record,PREFIX..token,"")
 if not saved then log_failure("snapshot quarantine",save_err) end
 if not disabled then log_failure("package disabling",disable_err) end
 return disabled
end
local function restore_node(pos,node,metadata,timer)
 core.set_node(pos,node)
 assert(core.get_meta(pos):from_table(metadata),"Could not restore node metadata")
 if timer and timer.started then core.get_node_timer(pos):set(timer.timeout,timer.elapsed) end
 if era.machines[node.name] then era.track(pos);era.refresh(pos) end
end

function era.pack_machine(pos,player)
 local name,denied=interaction_actor(player,pos)
 if not name then return false,denied end
 if player:get_wielded_item():get_name()~="era_core:wrench" then return false,"Hold the wrench to pack this machine." end
 if not era.allowed(pos,player) then return false,"This machine is protected." end
 local node=core.get_node_or_nil(pos)
 if not node or not era.machines[node.name] then return false,"There is no machine to pack here." end
 local position=core.pos_to_string(pos)
 if packing[position] then return false,"This machine is already being packed." end
 local inv=player:get_inventory()
 local slot
 for index=1,inv:get_size("main") do if inv:get_stack("main",index):is_empty() then slot=index;break end end
 if not slot then return false,"Make an empty inventory slot before packing the machine." end
 if not era.machine_ready(pos,node.name) then return false,"Repair the paused machine before packing it." end
 local ok,encoded,message=pcall(snapshot,pos,node)
 if not ok then log_failure("snapshot",encoded);return false,"Machine contents could not be read safely." end
 if not encoded then return false,message end
 local nonce,id=issuer()
 if not nonce or id>=MAX_ID then return false,"Machine package records require trusted repair." end
 id=id+1
 local token=nonce..":"..id
 local key=PREFIX..token
 if storage:get_string(key)~="" or busy[token] then return false,"Machine package identity is already in use." end
 local package=ItemStack(ITEM)
 local meta=package:get_meta()
 meta:set_string("era_package_version","1")
 meta:set_string("era_package_token",token)
 meta:set_string("description","Packed "..era.machines[node.name].description.."\nPlace to restore its contents and energy.")
 local original=core.get_meta(pos):to_table()
 local oldslot=inv:get_stack("main",slot)
 packing[position]=true;busy[token]=true
 local committed,err=xpcall(function()
  -- IDs are never rolled back, so a failed attempt cannot reuse an old token.
  storage:set_string("relocation_next",tostring(id))
  storage:set_string(key,encoded)
  inv:set_stack("main",slot,package)
  assert(inv:get_stack("main",slot):to_string()==package:to_string(),"Could not insert machine package")
  core.remove_node(pos)
  assert(core.get_node(pos).name=="air","Could not remove packed machine")
 end,debug.traceback)
 if not committed then
  log_failure("packing",err)
  local restored,restore_err=pcall(restore_node,pos,node,original)
  local inventory_ok,inventory_err=pcall(function()
   assert(inv:set_stack("main",slot,oldslot),"Could not restore player inventory")
   assert(inv:get_stack("main",slot):to_string()==oldslot:to_string(),"Player inventory rollback does not match")
  end)
  local registry_ok,registry_err
  if restored and inventory_ok then registry_ok,registry_err=pcall(set_record,key,"") end
  packing[position]=nil
  if not restored or not inventory_ok or not registry_ok then
   local disabled=quarantine(token,encoded)
   busy[token]=not disabled and true or nil
   log_failure("packing rollback",restore_err or inventory_err or registry_err)
   return false,"Packing failed; keep the world backed up for trusted repair."
  end
  busy[token]=nil
  return false,"Packing failed; the machine was restored."
 end
 packing[position]=nil;busy[token]=nil
 return true,"Packed "..era.machines[node.name].description.."."
end

function era.unpack_machine(stack,placer,pointed)
 local original=ItemStack(stack)
 if original:get_name()~=ITEM or original:get_count()~=1 then return original end
 if type(pointed)~="table" or pointed.type~="node" or type(pointed.above)~="table" then return original end
 local pos=pointed.above
 local name,denied=interaction_actor(placer,pos)
 if not name then
  local actor=player_name(placer)
  if actor then core.chat_send_player(actor,denied) end
  return original
 end
 local meta=original:get_meta()
 if meta:get_string("era_package_version")~="1" then return original end
 local token=meta:get_string("era_package_token")
 if #token>64 then return original end
 local nonce,raw=token:match("^([0-9a-f]+):([1-9]%d*)$")
 local world,last=issuer()
 local id=tonumber(raw)
 if not nonce or nonce~=world or not integer(id,1,last or 0) or busy[token] then return original end
 local oldnode=core.get_node_or_nil(pos)
 if not oldnode or oldnode.name~="air" or not era.allowed(pos,placer) then return original end
 local key=PREFIX..token
 local encoded=storage:get_string(key)
 if encoded=="" or #encoded>LIMIT then return original end
 local decoded,packet=pcall(core.deserialize,encoded,true)
 if not decoded then return original end
 local valid,accepted=pcall(validate_packet,packet)
 if not valid or not accepted then return original end
 local oldmetadata=core.get_meta(pos):to_table()
 local timer=core.get_node_timer(pos)
 local oldtimer={started=timer:is_started(),timeout=timer:get_timeout(),elapsed=timer:get_elapsed()}
 if next(oldmetadata.fields) or next(oldmetadata.inventory) or oldtimer.started then return original end
 busy[token]=true
 local committed,err=xpcall(function()
  core.set_node(pos,{name=packet.name,param1=packet.param1,param2=packet.param2})
  assert(core.get_meta(pos):from_table(packet.metadata),"Could not restore machine contents")
  core.get_meta(pos):set_string("owner",name)
  assert(era.machine_ready(pos,packet.name),"Saved machine state is invalid")
  era.track(pos);era.refresh(pos)
  storage:set_string(key,"")
 end,debug.traceback)
 if not committed then
  log_failure("placement",err)
  local restored,restore_err=pcall(restore_node,pos,oldnode,oldmetadata,oldtimer)
  local registry_ok,registry_err
  if restored then registry_ok,registry_err=pcall(set_record,key,encoded) end
  if not restored or not registry_ok then
   local disabled=quarantine(token,encoded)
   busy[token]=not disabled and true or nil
   log_failure("placement rollback",restore_err or registry_err)
  else busy[token]=nil end
  return original
 end
 busy[token]=nil
 original:take_item(1) -- Packages are consumed in creative as well as survival.
 return original
end

core.register_craftitem(ITEM,{
 description="Packed Machine",inventory_image="era_machine.png",stack_max=1,
 groups={not_in_creative_inventory=1},_doc_items_create_entry=false,
 on_place=era.unpack_machine,
})
