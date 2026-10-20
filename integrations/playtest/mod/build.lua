-- SPDX-License-Identifier: GPL-3.0-or-later
-- Assembly captures this record once. Never inspect Git or saved worlds here.
local info = {version="unknown", source="source_snapshot"}
local game = core.get_game_info()
local file = io.open(game.path.."/build-info.json", "r")
if file then
 local raw = file:read("*a");file:close()
 local parsed = core.parse_json(raw,nil,true)
 if type(parsed)=="table" and type(parsed.version)=="string" and
  parsed.version:match("^[%w.+-]+$") then
  info.version=parsed.version
  local revision=parsed.revision
  if parsed.source=="git" and type(revision)=="string" and
   (#revision==40 or #revision==64) and revision:match("^[0-9a-f]+$") and
   type(parsed.dirty)=="boolean" then
   info.revision=revision;info.dirty=parsed.dirty;info.source="git"
  end
 end
end
era_playtest.build_info=info
function era_playtest.format_packversion()
 local build="source snapshot; revision unknown"
 if info.source=="git" then
  build=info.revision..(info.dirty and " (development; local changes)" or " (clean source)")
 end
 local engine=core.get_version()
 return "Golden Era "..info.version.." | Build: "..build..
  " | Engine: "..engine.project.." "..engine.string
end
core.register_chatcommand("packversion",{
 description="Show Golden Era version, source build and engine for bug reports",
 func=function()return true,era_playtest.format_packversion() end,
})
