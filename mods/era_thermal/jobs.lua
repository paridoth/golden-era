-- SPDX-License-Identifier: GPL-3.0-or-later
-- Accept existing schema-1 jobs without reinterpreting them with current rates.
local fields={input=true,output=true,cost=true,rate=true}
local secondary_fields={secondary_output=true,secondary_chance=true,secondary_roll=true}
function era.valid_output(value)
 if type(value)~="string" or #value>256 then return false,"Saved output is invalid" end
 local item,count=value:match("^([^%s]+) (%d+)$")
 if not item then item=value:match("^([^%s]+)$"); count="1" end
 count=tonumber(count)
 if not item or not era.valid_integer(count,1) then return false,"Saved output count is invalid" end
 local output=ItemStack(value)
 if output:is_empty() or not core.registered_items[output:get_name()] or output:get_count()~=count or count>output:get_stack_max() then
  return false,"Saved output is unknown or oversized"
 end
 return true
end
function era.random_percent() return math.random(1,100) end
function era.resolve_recipe(pos,name,state)
 local meta=core.get_meta(pos)
 local input=meta:get_inventory():get_stack("src",1):get_name()
 local encoded=meta:get_string("job")
 if encoded=="" then
  if state.work>0 then return nil,"Pending work has no saved job" end
  return era.recipe_for(pos,name,input)
 end
 if state.work==0 then return nil,"Saved job has no pending work" end
 if #encoded>4096 then return nil,"Saved job exceeds size limit" end
 local job=core.deserialize(encoded,true)
 if type(job)~="table" then return nil,"Saved job is not a table" end
 local v2=job.schema==2 or job.schema==3
 if job.schema~=nil and not v2 then return nil,"Unsupported saved job schema" end
 if v2 and state.profile~="revelation" then return nil,"Saved job profile mismatch" end
 if v2 and job.rate_mode~="buffer" then return nil,"Invalid saved rate mode" end
 for key in pairs(job) do
  if not fields[key] and not (v2 and (key=="schema" or key=="rate_mode")) and not (job.schema==3 and secondary_fields[key]) then return nil,"Saved job has unknown fields" end
 end
 if type(job.input)~="string" or job.input=="" or job.input~=input then
  return nil,"Saved job input does not match inventory"
 end
 if not era.valid_integer(job.cost,1) or not era.valid_integer(job.rate,1) then
  return nil,"Saved job cost/rate is invalid"
 end
 if state.work>=job.cost then return nil,"Saved work meets or exceeds job cost" end
 if not era.valid_output(job.output) then return nil,"Saved output is invalid" end
 if job.schema==3 then
  if not era.valid_output(job.secondary_output) or not era.valid_integer(job.secondary_chance,1) or job.secondary_chance>100 or not era.valid_integer(job.secondary_roll,1) or job.secondary_roll>100 then
   return nil,"Saved secondary decision is invalid"
  end
  if meta:get_inventory():get_size("secondary")~=1 then return nil,"Saved secondary slot is missing" end
 end
 return job
end
