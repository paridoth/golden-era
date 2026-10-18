-- SPDX-License-Identifier: GPL-3.0-or-later
local MAX_INT=2147483647
function era.valid_integer(value,minimum)
 return type(value)=="number" and value==value and value>=minimum and value<=MAX_INT and value==math.floor(value)
end
function era.machine_ready(pos,name,state)
 local def=era.machines[name]
 if not def then return false end
 local meta=core.get_meta(pos); state=state or era.state(pos)
 local schema=tonumber(meta:get_string("schema")); local fault
 if schema~=1 and schema~=2 then fault="Unsupported or missing state schema"
 elseif schema==2 and (state.profile~=meta:get_string("profile") or state.profile~="legacy" and state.profile~="revelation") then fault="Invalid saved profile"
 else
  local keys=schema==1 and {"energy","work","burn"} or era.state_fields
  for _,key in ipairs(keys) do
   local minimum=(key=="fuel_rf" or key=="water_rf") and -39 or 0
   local raw=tonumber(meta:get_string(key))
   if not era.valid_integer(raw,minimum) or raw~=meta:get_int(key) or not era.valid_integer(state[key],minimum) then
    fault="Invalid saved "..key; break
   end
  end
 end
 if not fault and state.energy>era.capacity(pos,def,state) then fault="RF exceeds machine capacity" end
 if not fault and not def.producer and state.burn~=0 then fault="Burn stored on a non-generator" end
 if not fault and not def.processor and state.work~=0 then fault="Work stored on a non-processor" end
 if not fault and schema==2 then
  if state.profile=="legacy" or not def.producer then
   if state.water~=0 or state.fuel_rf~=0 or state.water_rf~=0 then fault="Fluid/fuel credit on unsupported machine" end
  elseif state.burn~=0 then fault="Legacy burn on Revelation generator"
  elseif state.water>era.reference.generator.tank_mb or state.fuel_rf>era.reference.generator.coal_rf or state.water_rf>era.reference.generator.water_credit_rf then
   fault="Fluid/fuel credit exceeds capacity"
  end
 end
 if not fault then fault=era.validate_ports(pos,name) end
 if not fault and def.processor then local _,reason=era.resolve_recipe(pos,name,state); fault=reason end
 if not fault and schema==1 then era.migrate(pos,state) end
 local message=fault or ""
 if meta:get_string("fault")~=message then meta:set_string("fault",message); era.refresh(pos) end
 return not fault
end
