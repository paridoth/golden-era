local M=dofile("mods/era_core/ledger.lua")
local count=0
local function test(name,fn) fn(); count=count+1; print("PASS "..name) end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local recipe={cost=100,rate=40}
test("energy conservation and capacity",function()
 for a=0,200 do for b=0,100 do local x,y={energy=a},{energy=b,capacity=100}; local n=M.transfer(x,y,40); eq(x.energy+y.energy,a+b); assert(n<=40 and y.energy<=100 and x.energy>=0) end end
end)
test("producer consumes exactly one fuel and pauses when full",function()
 local s={energy=0,capacity=40,burn=0}; local used,n=M.generate(s,20,2,true); eq(used,true); eq(n,20)
 used,n=M.generate(s,20,2,false); eq(used,false); eq(n,20); eq(s.burn,0)
 used,n=M.generate(s,20,2,true); eq(used,false); eq(n,0); eq(s.burn,0)
end)
test("producer without fuel",function() local s={energy=0,capacity=100,burn=0}; local _,n=M.generate(s,20,2,false); eq(n,0); eq(s.energy,0) end)
test("insufficient energy preserves pending work",function() local s={energy=10,work=0}; local done,n=M.process(s,recipe,1,true); eq(done,false); eq(n,10); eq(s.work,10); eq(s.energy,0) end)
test("output overflow consumes no energy or input",function() local s={energy=100,work=40}; local done,n=M.process(s,recipe,1,false); eq(done,false); eq(n,0); eq(s.energy,100); eq(s.work,40) end)
test("empty input consumes nothing",function() local s={energy=100,work=0}; local _,n=M.process(s,recipe,0,true); eq(n,0) end)
test("recipe completion spends exact cost",function() local s={energy=150,work=0}; local done; for i=1,3 do done=M.process(s,recipe,1,true) end; eq(done,true); eq(s.energy,50); eq(s.work,0) end)
test("no duplicate results with caller inventory accounting",function() local s={energy=500,work=0}; local input,output=2,0; for i=1,100 do if M.process(s,recipe,input,true) then input=input-1; output=output+2 end end; eq(output,4); eq(input,0); eq(s.energy,300) end)
test("two consumers share producer without creating energy",function() local p={energy=50}; local a,b={energy=0,capacity=100},{energy=0,capacity=100}; M.transfer(p,a,40); M.transfer(p,b,40); eq(a.energy,40); eq(b.energy,10); eq(p.energy+a.energy+b.energy,50) end)
test("network connect disconnect reconnect",function()
 local edges={a={"c"},b={"c"},c={"a","b"}}
 local function neighbors(k) return edges[k] end
 eq(#M.components({a=true,b=true,c=true},neighbors),1)
 eq(#M.components({a=true,b=true},neighbors),2)
 eq(#M.components({a=true,b=true,c=true},neighbors),1)
end)
test("ledger copied at save boundary resumes exact work",function() local s={energy=100,work=0}; M.process(s,recipe,1,true); local loaded={energy=s.energy,work=s.work}; M.process(loaded,recipe,1,true); local done=M.process(loaded,recipe,1,true); eq(done,true); eq(loaded.energy,0) end)
test("reject fractional and negative RF",function() assert(not pcall(M.transfer,{energy=-1},{energy=0,capacity=10},1)); assert(not pcall(M.transfer,{energy=1},{energy=0,capacity=10},0.5)) end)
test("reject non-finite RF and recipe values",function()
 assert(not pcall(M.transfer,{energy=math.huge},{energy=0,capacity=10},1))
 assert(not pcall(M.transfer,{energy=1},{energy=0,capacity=10},0/0))
 assert(not pcall(M.process,{energy=100,work=0},{cost=math.huge,rate=40},1,true))
 assert(not pcall(M.generate,{energy=0,capacity=100,burn=math.huge},20,1600,true))
end)
print("UNIT PASS: "..count.." tests")
