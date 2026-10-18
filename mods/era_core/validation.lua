-- SPDX-License-Identifier: GPL-3.0-or-later
-- Metadata integers use the engine's signed 32-bit storage representation.
local MAX_INT=2147483647
function era.valid_integer(value,minimum)
 return type(value)=="number" and value==value and value>=minimum and value<=MAX_INT and value==math.floor(value)
end
function era.machine_ready(pos,name,state)
 local def=era.machines[name]
 if not def then return false end
 local meta=core.get_meta(pos)
 state=state or era.state(pos)
 local fault
 if tonumber(meta:get_string("schema"))~=1 then
  fault="Unsupported or missing state schema"
 else
  for _,key in ipairs({"energy","work","burn"}) do
   local raw=tonumber(meta:get_string(key))
   if not era.valid_integer(raw,0) or raw~=meta:get_int(key) or not era.valid_integer(state[key],0) then
    fault="Invalid saved "..key; break
   end
  end
 end
 if not fault and state.energy>def.capacity then fault="RF exceeds machine capacity" end
 if not fault and not def.producer and state.burn~=0 then fault="Burn stored on a non-generator" end
 if not fault and not def.processor and state.work~=0 then fault="Work stored on a non-processor" end
 if not fault and def.processor then
  local _,reason=era.resolve_recipe(pos,name,state)
  fault=reason
 end
 local message=fault or ""
 if meta:get_string("fault")~=message then
  meta:set_string("fault",message)
  era.refresh(pos)
 end
 return not fault
end
