-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure basic resource model. Scheduling/graph topology are separate native adapters.
local M={}
local function integer(n,min,max)
 assert(type(n)=="number" and n==math.floor(n) and n>=min and n<=max,"invalid resource integer")
end
function M.rate(energy,p,generator)
 integer(energy,0,p.capacity_rf)
 if generator then
  if energy<=p.low_threshold_rf then return p.max_rf_per_tick end
  if energy>p.high_threshold_rf then return p.min_rf_per_tick end
  return math.floor((p.capacity_rf-energy)/p.ramp)
 end
 if energy>=p.high_threshold_rf then return p.max_rf_per_tick end
 if energy<p.low_threshold_rf then return math.min(p.min_rf_per_tick,energy) end
 return math.floor(energy/p.ramp)
end
function M.generate(s,p,fuel_value)
 integer(s.energy,0,p.capacity_rf); integer(s.water,0,p.tank_mb)
 integer(s.fuel_rf,1-p.max_rf_per_tick,p.coal_rf)
 integer(s.water_rf,1-p.max_rf_per_tick,p.water_credit_rf)
 integer(fuel_value,0,p.coal_rf)
 if (s.fuel_rf<=0 and fuel_value==0) or (s.water_rf<=0 and s.water<p.batch_mb) then return false,0,0 end
 local used=false
 if s.fuel_rf<=0 then s.fuel_rf=s.fuel_rf+fuel_value; used=true end
 if s.water_rf<=0 then s.water_rf=s.water_rf+p.water_credit_rf; s.water=s.water-p.batch_mb end
 local generated=M.rate(s.energy,p,true)
 local stored=math.min(generated,p.capacity_rf-s.energy)
 s.energy=s.energy+stored
 s.fuel_rf=s.fuel_rf-generated; s.water_rf=s.water_rf-generated
 return used,generated,generated-stored -- full-buffer idle consumption is dissipated, not free RF
end
return M
