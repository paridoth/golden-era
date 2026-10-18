-- SPDX-License-Identifier: GPL-3.0-or-later
-- Faces use Minecraft's fixed order: down, up, north, south, west, east.
era.faces={{x=0,y=-1,z=0},{x=0,y=1,z=0},{x=0,y=0,z=-1},{x=0,y=0,z=1},{x=-1,y=0,z=0},{x=1,y=0,z=0}}
local labels={"Down","Up","North","South","West","East"}
local short={[0]="Off",[1]="Input",[2]="Primary",[3]="Byproduct",[4]="Outputs",[7]="All slots",[8]="I/O"}
local insertion={[1]=true,[5]=true,[6]=true,[7]=true,[8]=true}
local slot_ids={src=0,dst=1,secondary=2}
local function config(name)
 return era.reference and era.reference.ports[name=="era_thermal:pulverizer" and "pulverizer" or name=="era_thermal:furnace" and "furnace" or ""]
end
function era.face_between(a,b)
 local dx,dy,dz=b.x-a.x,b.y-a.y,b.z-a.z
 if dx~=0 and dy==0 and dz==0 then return dx>0 and 5 or 4 end
 if dy~=0 and dx==0 and dz==0 then return dy>0 and 1 or 0 end
 if dz~=0 and dx==0 and dy==0 then return dz>0 and 3 or 2 end
end
function era.init_ports(pos,name)
 local c=config(name); if not c then return end
 local front=({3,5,2,4})[(core.get_node(pos).param2 or 0)%4+1]
 local values={}
 for i,v in ipairs(c.default_sides) do values[i]=tostring(i-1==front and 0 or v) end
 local m=core.get_meta(pos); m:set_string("item_ports",table.concat(values)); m:set_int("item_front",front); m:set_int("item_ports_version",1); m:set_string("auto_output","1")
end
function era.validate_ports(pos,name)
 local m=core.get_meta(pos)
 if m:get_int("schema")~=2 or m:get_string("profile")~="revelation" or not config(name) then return end
 if m:get_string("item_ports_version")=="" and m:get_string("item_ports")=="" then return end -- pre-port schema-2 layout
 local c=config(name); local encoded=m:get_string("item_ports"); local front=tonumber(m:get_string("item_front"))
 if m:get_string("auto_output")~="0" and m:get_string("auto_output")~="1" then return "Invalid item-output toggle" end
 if m:get_string("item_ports_version")~="1" or not encoded:match("^%d%d%d%d%d%d$") or not era.valid_integer(front,2) or front>5 then return "Invalid item-side configuration" end
 for i=1,6 do
  local mode=tonumber(encoded:sub(i,i))
  if not c.slot_groups[mode+1] or i-1==front and mode~=0 then return "Invalid item-side mode" end
 end
end
function era.port_allows(pos,face,list,insert)
 local m=core.get_meta(pos); local c=config(core.get_node(pos).name)
 if not c or m:get_string("profile")~="revelation" or m:get_string("item_ports_version")=="" then return true end
 if face==nil then return false end
 local mode=tonumber(m:get_string("item_ports"):sub(face+1,face+1)); if not mode then return false end
 local type_id=c.side_types[mode+1]; local id=slot_ids[list]
 if id==nil or insert and (not insertion[type_id] or list~="src") then return false end
 if not insert and (type_id==0 or list=="src" and type_id~=7) then return false end
 for _,slot in ipairs(c.slot_groups[mode+1]) do if slot==id then return true end end
 return false
end
function era.configure_side(pos,face,mode,player)
 local name=core.get_node(pos).name; local c=config(name)
 if not c or not era.allowed(pos,player) or not era.machine_ready(pos,name) or era.state(pos).profile~="revelation" then return false end
 if not era.valid_integer(face,0) or face>5 or not era.valid_integer(mode,0) or not c.slot_groups[mode+1] then return false end
 local m=core.get_meta(pos)
 if m:get_string("item_ports_version")=="" then era.init_ports(pos,name) end
 if face==m:get_int("item_front") then return false end
 local encoded=m:get_string("item_ports")
 m:set_string("item_ports",encoded:sub(1,face)..mode..encoded:sub(face+2))
 era.refresh(pos); return true
end
function era.ports_fields(pos,fields,player)
 local name=core.get_node(pos).name; local c=config(name)
 if not c or not era.allowed(pos,player) or not era.machine_ready(pos,name) or era.state(pos).profile~="revelation" then return end
 local m=core.get_meta(pos)
 if fields.enable_ports and m:get_string("item_ports_version")=="" then era.init_ports(pos,name); era.refresh(pos); return end
 if fields.auto_output then m:set_string("auto_output",m:get_string("auto_output")=="1" and "0" or "1"); era.refresh(pos); return end
 if fields.rotate_panel and m:get_string("item_ports_version")~="" then
  local front=m:get_int("item_front"); front=({[2]=5,[5]=3,[3]=4,[4]=2})[front]
  local encoded=m:get_string("item_ports"); m:set_string("item_ports",encoded:sub(1,front).."0"..encoded:sub(front+2)); m:set_int("item_front",front)
  local node=core.get_node(pos); node.param2=({[3]=0,[5]=1,[2]=2,[4]=3})[front]; core.swap_node(pos,node)
  era.refresh(pos); return
 end
 for face=0,5 do
  if fields["side_"..face] then
   local mode=tonumber(m:get_string("item_ports"):sub(face+1,face+1))
   if mode then era.configure_side(pos,face,(mode+1)%#c.slot_groups,player) end
  end
 end
end
function era.ports_formspec(pos,name)
 local m=core.get_meta(pos); local c=config(name)
 if not c or m:get_string("profile")~="revelation" then return "" end
 if m:get_string("item_ports_version")=="" then return "button[0.5,3.5;11,0.7;enable_ports;Enable item-side rules for this existing layout]" end
 local result={}
 for face=0,5 do
  local mode=tonumber(m:get_string("item_ports"):sub(face+1,face+1))
  local text=face==m:get_int("item_front") and "Panel" or short[c.side_types[(mode or 0)+1]] or "?"
  local x=0.5+face*1.85
  result[#result+1]="button["..x..",3.5;1.75,0.6;side_"..face..";"..labels[face+1].."]"
  result[#result+1]="label["..x..",4.25;"..core.formspec_escape(core.colorize("#313131",text)).."]"
 end
 result[#result+1]="button[5.7,10.6;2.8,0.7;auto_output;Auto output: "..(m:get_string("auto_output")=="1" and "On" or "Off").."]"
 result[#result+1]="button[8.7,10.6;2.8,0.7;rotate_panel;Rotate panel]"
 return table.concat(result)
end
