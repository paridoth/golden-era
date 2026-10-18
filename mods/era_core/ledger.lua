-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure integer ledger shared by the engine and unit tests.
local M = {}
local function integer(n) assert(type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n), "nonnegative integer required"); return n end
function M.transfer(a, b, limit)
 integer(a.energy); integer(b.energy); integer(b.capacity); integer(limit)
 assert(b.energy <= b.capacity)
 local n = math.min(a.energy, b.capacity - b.energy, limit)
 a.energy, b.energy = a.energy - n, b.energy + n
 return n
end
function M.generate(s, rate, duration, has_fuel)
 integer(s.energy); integer(s.capacity); integer(s.burn); integer(rate); integer(duration)
 if s.energy + rate > s.capacity then return false, 0 end
 local used = false
 if s.burn == 0 then
  if not has_fuel then return false, 0 end
  s.burn = duration; used = true
 end
 s.burn = s.burn - 1; s.energy = s.energy + rate
 return used, rate
end
-- Input stays reserved until completion; adapters must lock it while work > 0.
function M.process(s, recipe, input_count, output_room)
 if not recipe or input_count < 1 or not output_room then return false, 0 end
 integer(s.energy); integer(s.work); integer(recipe.cost); integer(recipe.rate)
 assert(recipe.cost > 0 and s.work < recipe.cost)
 local spent = math.min(s.energy, recipe.rate, recipe.cost - s.work)
 s.energy, s.work = s.energy - spent, s.work + spent
 if s.work == recipe.cost then s.work = 0; return true, spent end
 return false, spent
end
-- Deterministic components: sorted keys; six-face edges supplied by adapter.
function M.components(nodes, neighbors)
 local keys, seen, result = {}, {}, {}
 for k in pairs(nodes) do keys[#keys+1] = k end
 table.sort(keys)
 for _, k in ipairs(keys) do
  if not seen[k] then
   local queue, component, head = {k}, {}, 1; seen[k] = true
   while queue[head] do
    local current = queue[head]; head = head + 1; component[#component+1] = current
    for _, nextkey in ipairs(neighbors(current)) do
     if nodes[nextkey] and not seen[nextkey] then seen[nextkey] = true; queue[#queue+1] = nextkey end
    end
   end
   table.sort(component); result[#result+1] = component
  end
 end
 return result
end
return M
