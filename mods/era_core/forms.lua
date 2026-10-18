-- SPDX-License-Identifier: GPL-3.0-or-later
-- Code-drawn slot backgrounds keep empty inventories visible under the game skin.
local function label(x,y,text)
 return "label["..x..","..y..";"..core.formspec_escape(core.colorize("#313131",text)).."]"
end
local function slots(x,y,w,h,where,list,start)
 local result={}
 for col=0,w-1 do for row=0,h-1 do
  local sx,sy=x+col*1.25,y+row*1.25
  result[#result+1]="box["..(sx-0.025)..","..(sy-0.025)..";1.05,1.05;#697586]box["..sx..","..sy..";1,1;#111a25]"
 end end
 result[#result+1]="list["..where..";"..list..";"..x..","..y..";"..w..","..h..";"..(start or 0).."]"
 return table.concat(result)
end
function era.machine_form(pos,def,fault,profile)
 local m=core.get_meta(pos);local name=core.get_node(pos).name
 local result={"formspec_version[4]size[12,11.8]bgcolor[#202a36;false]",
  label(0.5,0.4,def.description),
  label(0.5,0.9,(profile=="legacy" and "Legacy model" or "Revelation basic").." | RF "..m:get_int("energy").." / "..era.capacity(pos,def).." | Work "..m:get_int("work"))}
 if fault~="" then result[#result+1]=label(0.5,1.35,"Paused: "..fault) end
 local function slot(x,title,list)
  result[#result+1]=label(x,1.85,title);result[#result+1]=slots(x,2.2,1,1,"context",list)
 end
 if def.processor then
  slot(0.5,"Input","src");slot(4,"Output","dst")
  if name=="era_thermal:pulverizer" then slot(6,"Byproduct","secondary") end
  result[#result+1]=era.ports_formspec(pos,name)
 elseif def.producer then
  slot(0.5,"Fuel","fuel")
  if profile=="revelation" then
   slot(3.5,"Water bucket","water");slot(6.5,"Empty bucket","empty")
   result[#result+1]=label(0.5,3.6,"Water: "..m:get_int("water").." / 4000 mB")
   result[#result+1]=label(0.5,4.15,"Fuel credit: "..m:get_int("fuel_rf").." RF | Water credit: "..m:get_int("water_rf").." RF")
  end
 else
  result[#result+1]=label(0.5,2.2,"Stores and transfers RF through the connected network.")
  result[#result+1]=label(0.5,3,"Empty stored RF before digging.")
 end
 result[#result+1]=label(0.5,4.8,"Inventory")
 result[#result+1]=slots(0.5,5.2,9,3,"current_player","main",9)
 result[#result+1]=slots(0.5,9.1,9,1,"current_player","main",0)
 if profile=="legacy" then result[#result+1]="button[0.5,10.6;11,0.7;upgrade;Use Revelation model after current burn/job finishes]" end
 if def.processor then result[#result+1]="listring[context;dst]listring[current_player;main]listring[context;src]listring[current_player;main]"
 elseif def.producer then
  result[#result+1]="listring[context;fuel]listring[current_player;main]"
  if profile=="revelation" then result[#result+1]="listring[context;water]listring[current_player;main]listring[context;empty]listring[current_player;main]" end
 end
 return table.concat(result)
end
