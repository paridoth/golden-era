-- SPDX-License-Identifier: GPL-3.0-or-later
-- Test the actual command module without invoking Git or touching saved worlds.
local root=assert(arg[1],"Repository root argument required")
local original_open=io.open
local revision=string.rep("a",40)
local function eq(a,b,label)assert(a==b,label..": "..tostring(a).." ~= "..tostring(b)) end
local function contains(text,part,label)assert(text:find(part,1,true),label..": "..text) end
local function load_record(parsed,missing)
 local commands,reads={},0
 era_playtest={}
 core={
  get_game_info=function()return {path="assembled-game"} end,
  get_version=function()return {project="Test Luanti",string="5.17.0-fixture"} end,
  parse_json=function(raw,nullvalue,return_error)
   eq(raw,"record","Read record content");eq(nullvalue,nil,"JSON null remains unknown")
   eq(return_error,true,"Malformed records use fallback without engine error output")
   return parsed
  end,
  register_chatcommand=function(name,definition)commands[name]=definition end,
 }
 io.open=function(path,mode)
  eq(path,"assembled-game/build-info.json","Identity comes from game root")
  eq(mode,"r","Identity is read only")
  reads=reads+1
  if missing then return nil,"No record" end
  return {read=function(_,size)eq(size,"*a","Read full JSON");return "record" end,close=function()end}
 end
 local ok,error_message=pcall(dofile,root.."/integrations/playtest/mod/build.lua")
 io.open=original_open
 assert(ok,error_message)
 local command=assert(commands.packversion,"Register /packversion")
 eq(command.privs,nil,"Anyone may report the build")
 local success,text=command.func()
 eq(success,true,"Command succeeds without a player")
 eq(text,era_playtest.format_packversion(),"Public formatter matches command")
 contains(text,"Test Luanti 5.17.0-fixture","Include engine project and version")
 eq(reads,1,"Read immutable record once at startup")
 return text
end

local parsed={version="9.8.7",revision=revision,dirty=false,source="git"}
local text=load_record(parsed)
contains(text,"Golden Era 9.8.7","Include game version")
contains(text,revision.." (clean source)","Include full clean revision")
eq(era_playtest.build_info.revision,revision,"Expose source revision")
eq(era_playtest.build_info.dirty,false,"Preserve false, not unknown")
parsed.version="changed";parsed.revision="changed"
eq(era_playtest.build_info.version,"9.8.7","Snapshot copies version at load")
contains(era_playtest.format_packversion(),revision,"Command retains loaded revision")

text=load_record({version="9.8.7",revision=revision,dirty=true,source="git"})
contains(text,revision.." (development; local changes)","Identify dirty builds honestly")
eq(era_playtest.build_info.dirty,true,"Expose development status")

text=load_record({version="9.8.7",source="source_snapshot"})
contains(text,"Golden Era 9.8.7","Source snapshot retains release version")
contains(text,"source snapshot; revision unknown","Do not fabricate source revision")
eq(era_playtest.build_info.revision,nil,"Snapshot revision unknown")
eq(era_playtest.build_info.dirty,nil,"Snapshot cleanliness unknown")

for _,invalid in ipairs({false,{version="unsafe;form]"},
 {version="9.8.7",revision=revision,source="git"},
 {version="9.8.7",revision="not-a-commit",dirty=false,source="git"}}) do
 text=load_record(invalid)
 contains(text,"source snapshot; revision unknown","Malformed record cannot claim a clean revision")
end
text=load_record(nil,true)
contains(text,"Golden Era unknown","Missing record does not invent release version")
contains(text,"source snapshot; revision unknown","Missing record remains usable")
print("Build identity command tests passed")
