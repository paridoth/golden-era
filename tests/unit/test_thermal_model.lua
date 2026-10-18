-- SPDX-License-Identifier: GPL-3.0-or-later
local M=dofile("mods/era_thermal/model.lua")
local R=dofile("mods/era_thermal/reference.lua")
local n=0
local function test(name,fn) fn(); n=n+1; print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function state(energy,fuel,water,credit) return {energy=energy or 0,fuel_rf=fuel or 0,water=water or 0,water_rf=credit or 0} end
test("machine rate thresholds use integer ramp",function()
 for _,v in ipairs({{0,0},{1,1},{1999,2},{2000,2},{2699,2},{2700,3},{17999,19},{18000,20},{20000,20}}) do eq(M.rate(v[1],R.machine,false),v[2]) end
end)
test("dynamo rate thresholds and full-buffer minimum",function()
 for _,v in ipairs({{0,40},{4000,40},{4001,39},{36000,4},{36001,4},{40000,4}}) do eq(M.rate(v[1],R.generator,true),v[2]) end
end)
test("no water preserves unconsumed coal",function()
 local s=state(); local used,generated=M.generate(s,R.generator,24000); eq(used,false); eq(generated,0); eq(s.fuel_rf,0)
end)
test("no fuel preserves unconverted water",function()
 local s=state(0,0,100); local used,generated=M.generate(s,R.generator,0); eq(used,false); eq(generated,0); eq(s.water,100); eq(s.water_rf,0)
end)
test("coal and water become separate persistent credits",function()
 local s=state(0,0,1000); local used,generated,wasted=M.generate(s,R.generator,24000)
 eq(used,true); eq(generated,40); eq(wasted,0); eq(s.water,900); eq(s.fuel_rf,23960); eq(s.water_rf,24960)
end)
test("one coal drains to 24000 RF and carries water credit",function()
 local s=state(0,0,100); local total,fuels=0,0
 for i=1,601 do
  local used,generated=M.generate(s,R.generator,fuels==0 and 24000 or 0)
  if used then fuels=fuels+1 end
  total=total+generated; s.energy=0
 end
 eq(fuels,1); eq(total,24000); eq(s.fuel_rf,0); eq(s.water_rf,1000); eq(s.water,0)
end)
test("charcoal uses 16000 RF",function()
 local s=state(0,0,100); local total=0
 for i=1,401 do local _,generated=M.generate(s,R.generator,i==1 and 16000 or 0); total=total+generated; s.energy=0 end
 eq(total,16000); eq(s.water_rf,9000)
end)
test("signed overshoot is carried into both next batches",function()
 local s=state(0,1,100,1); M.generate(s,R.generator,0)
 eq(s.fuel_rf,-39); eq(s.water_rf,-39)
 M.generate(s,R.generator,24000)
 eq(s.fuel_rf,23921); eq(s.water_rf,24921); eq(s.water,0)
end)
test("full storage dissipates minimum generation and debits credits",function()
 local s=state(40000,100,0,100); local used,generated,wasted=M.generate(s,R.generator,0)
 eq(used,false); eq(generated,4); eq(wasted,4); eq(s.energy,40000); eq(s.fuel_rf,96); eq(s.water_rf,96)
end)
test("copying persisted credits preserves exact continuation",function()
 local a=state(9123,777,200,1234); local b=state(a.energy,a.fuel_rf,a.water,a.water_rf)
 for i=1,40 do M.generate(a,R.generator,0); M.generate(b,R.generator,0) end
 for key,v in pairs(a) do eq(b[key],v) end
end)
test("invalid resource bounds fail before mutation",function()
 for _,s in ipairs({state(-1),state(40001),state(0,-40),state(0,0,4001),state(0,0,0,25001)}) do assert(not pcall(M.generate,s,R.generator,0)) end
end)
print("THERMAL MODEL UNIT PASS: "..n.." tests")
