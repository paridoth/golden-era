#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Interrupt a real workshop click, resume its saved trip, then preserve arrival.

Runs on an authenticated :98 display and explicit loopback port 30216. All three
client sessions share one disposable test world; ordinary saves stay untouched.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
DISPLAY = ":98"
PORT = "30216"

OBSERVER = r'''
local state=core.get_mod_storage()
local function count(player,item)
 local total=0
 for _,stack in ipairs(player:get_inventory():get_list("main")) do
  if stack:get_name()==item then total=total+stack:get_count() end
 end
 return total
end
local function kit(player)
 assert(count(player,"mcl_tools:pick_diamond")==1,"Exactly one starter pick")
 assert(count(player,"mcl_tools:axe_diamond")==1,"Exactly one starter axe")
 assert(count(player,"mcl_torches:torch")==32,"Exactly 32 starter torches")
end
local function loading_huds(player)
 local count=0
 for _,hud in pairs(player:hud_get_all()) do
  if type(hud.text)=="string" and hud.text:find("Preparing workshop terrain",1,true) then count=count+1 end
 end
 return count
end
local function copper(player)
 assert(count(player,"mcl_copper:copper_ingot")==7,"Exactly seven saved copper ingots")
end
local function snapshot(player,phase)
 local record={phase=phase,position=player:get_pos(),pending=player:get_meta():get_int("era_playtest_workshop_pending"),
  loading_huds=loading_huds(player),pick=count(player,"mcl_tools:pick_diamond"),axe=count(player,"mcl_tools:axe_diamond"),
  torches=count(player,"mcl_torches:torch"),copper=count(player,"mcl_copper:copper_ingot")}
 local file=assert(io.open(core.get_worldpath().."/"..phase..".json","w"))
 file:write(core.write_json(record,true));file:close()
end
core.register_on_joinplayer(function(player)
 local name=player:get_player_name()
 local phase=state:get_int("phase")
 if phase==0 then
  core.after(3,function()
   local current=assert(core.get_player_by_name(name))
   assert(current:get_meta():get_int("era_playtest_joined")==0,"Fresh player has not chosen yet")
   core.log("action","TRIP GUI CHOOSER READY")
   local function watch()
    local p=assert(core.get_player_by_name(name))
    local meta=p:get_meta()
    if meta:get_int("era_playtest_joined")~=1 then core.after(0.05,watch);return end
    assert(meta:get_string("era_playtest_start_mode")=="workshop","Actual click chose workshop")
    if meta:get_int("era_playtest_workshop_pending")~=1 then
     core.log("warning","TRIP GUI INCONCLUSIVE: workshop completed before the interruption window")
     core.request_shutdown("No pending interruption window",false,0);return
    end
    assert(loading_huds(p)==1,"Pending native trip has one visible loading HUD")
    kit(p)
    local leftover=p:get_inventory():add_item("main","mcl_copper:copper_ingot 7")
    assert(leftover:is_empty(),"Saved copper fits the real player inventory")
    copper(p);snapshot(p,"interrupted")
    state:set_int("phase",1)
    core.log("action","TRIP GUI PENDING INTERRUPT PASS")
    core.request_shutdown("Interrupt pending workshop trip immediately",false,0)
   end
   watch()
  end)
 elseif phase==1 then
  -- This check deliberately precedes onboarding's one-second resume timer.
  local meta=player:get_meta()
  assert(meta:get_int("era_playtest_joined")==1,"Starting choice survived shutdown")
  assert(meta:get_string("era_playtest_start_mode")=="workshop","Saved start mode survived")
  assert(meta:get_int("era_playtest_workshop_pending")==1,"Pending trip persisted before resume")
  kit(player);copper(player);snapshot(player,"rejoined-pending")
  core.log("action","TRIP GUI PENDING SAVED PASS")
  local began=core.get_us_time()
  local function arrived()
   local p=assert(core.get_player_by_name(name))
   if p:get_meta():get_int("era_playtest_workshop_pending")==1 then
    assert(core.get_us_time()-began<90*1000000,"Pending workshop resume timeout: "..core.pos_to_string(p:get_pos()))
    core.after(0.2,arrived);return
   end
   assert(vector.distance(p:get_pos(),{x=3,y=200.5,z=6})<4,"Resumed trip reaches actual workshop")
   assert(core.get_node({x=3,y=199,z=6}).name=="mcl_core:stone","Actual workshop platform exists")
   assert(loading_huds(p)==0,"Arrival removes loading HUD")
   assert(p:get_meta():get_int("era_playtest_workshop_first")==0,"Arrival clears first-help pending marker")
   kit(p);copper(p);snapshot(p,"arrived")
   -- Move far enough from the arrival point to catch an unwanted repeat warp.
   local saved={x=11,y=199.5,z=6}
   p:set_pos(saved)
   state:set_string("saved_position",core.serialize(saved))
   state:set_int("phase",2)
   core.log("action","TRIP GUI RESUMED ARRIVAL PASS")
   core.request_shutdown("Save a completed trip away from its arrival point",false,0)
  end
  core.after(1.2,arrived)
 elseif phase==2 then
  core.after(3,function()
   local p=assert(core.get_player_by_name(name))
   assert(p:get_meta():get_int("era_playtest_workshop_pending")==0,"Finished trip stays finished on third login")
   assert(loading_huds(p)==0,"Finished trip has no loading HUD")
   local saved=assert(core.deserialize(state:get_string("saved_position")))
   assert(vector.distance(p:get_pos(),saved)<2,"Completed trip keeps saved position after third login")
   assert(vector.distance(p:get_pos(),{x=3,y=200.5,z=6})>4,"Third login does not repeat workshop warp")
   kit(p);copper(p);snapshot(p,"completed-reconnect")
   state:set_int("phase",3)
   core.log("action","TRIP GUI COMPLETED RECONNECT PASS")
   core.request_shutdown("Completed workshop trip remains completed",false,0)
  end)
 else
  error("Unexpected disposable trip-test phase")
 end
end)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-tools", action="store_true")
    parser.add_argument("--keep-world", action="store_true", help="Retain the disposable world and game for diagnosis")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("golden_era_gui_helpers", ROOT / "tests/playtest/gui.py")
    gui = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gui)
    gui.DISPLAY = DISPLAY
    xvfb = gui.setup_tools(args.fetch_tools)
    if Path("/tmp/.X11-unix/X98").exists():
        raise RuntimeError("Refusing to connect to an existing :98 display")
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    evidence = base / "workshop-trip"
    evidence.mkdir(parents=True, exist_ok=True)
    if evidence.is_symlink():
        raise RuntimeError("Refusing a linked trip-test evidence directory")
    records = ("interrupted", "rejoined-pending", "arrived", "completed-reconnect")
    outputs = {"summary.json", "actual-chooser.png", "client.log", "xvfb.log",
               "interrupt.log", "resume.log", "completed-reconnect.log"}
    outputs.update(phase + ".json" for phase in records)
    for name in outputs:
        (evidence / name).unlink(missing_ok=True)
    temporary = None if args.keep_world else tempfile.TemporaryDirectory(prefix="trip-gui-", dir=base)
    work = Path(tempfile.mkdtemp(prefix="trip-gui-", dir=base) if temporary is None else temporary.name)
    print("Interrupted-trip GUI evidence:", evidence, flush=True)
    if args.keep_world:
        print("Retained diagnostic world:", work, flush=True)
    game = work / "games/golden_era_playtest"
    subprocess.run(["python3", ROOT / "scripts/setup-playtest.py", "--no-fetch", "--destination", game],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    world = work / "world"
    observer = world / "worldmods/trip_observer"
    observer.mkdir(parents=True)
    (observer / "mod.conf").write_text("name = trip_observer\ndepends = era_playtest\n")
    (observer / "init.lua").write_text(OBSERVER)
    (world / "world.mt").write_text("gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
    config = work / "client.conf"
    config.write_text((ROOT / "packaging/playtest/templates/defaults/playtest.conf").read_text() +
                      "\nport = 30216\nscreen_w = 1280\nscreen_h = 900\nviewing_range = 20\nfps_max = 15\n")
    auth = work / "Xauthority"
    auth.touch()
    subprocess.run(["xauth", "-f", auth, "add", DISPLAY, ".", secrets.token_hex(16)], check=True)
    env = os.environ.copy()
    env.update(DISPLAY=DISPLAY, XAUTHORITY=str(auth), LIBGL_ALWAYS_SOFTWARE="1", SDL_VIDEODRIVER="x11",
               LUANTI_GAME_PATH=str(work / "games"))
    env["LD_LIBRARY_PATH"] = ":".join(str(ROOT / path) for path in
        ("tools/client-root/usr/lib/x86_64-linux-gnu", "tools/root/usr/lib/x86_64-linux-gnu",
         "tools/gui-root/usr/lib/x86_64-linux-gnu"))
    os.environ["DISPLAY"] = DISPLAY
    os.environ["XAUTHORITY"] = str(auth)
    report = {"result": "incomplete", "display": DISPLAY, "port": PORT, "phases": [],
              "world_retained": args.keep_world,
              "world_directory": str(work.relative_to(ROOT)) if args.keep_world else None}
    server = client = None
    xlog = (work / "xvfb.log").open("w")
    try:
        server = subprocess.Popen([xvfb, DISPLAY, "-screen", "0", "1280x900x24", "-nolisten", "tcp", "-auth", auth],
                                  env=env, stdout=xlog, stderr=subprocess.STDOUT)
        time.sleep(0.5)
        if server.poll() is not None:
            raise RuntimeError("Isolated Xvfb failed to start")
        from PIL import ImageGrab
        phases = (("interrupt", "TRIP GUI PENDING INTERRUPT PASS"),
                  ("resume", "TRIP GUI RESUMED ARRIVAL PASS"),
                  ("completed-reconnect", "TRIP GUI COMPLETED RECONNECT PASS"))
        for phase, marker in phases:
            log = work / (phase + ".log")
            with log.open("w") as output:
                client = subprocess.Popen([ROOT / "upstream/luanti/bin/luanti", "--go", "--port", PORT,
                    "--gameid", "golden_era_playtest", "--world", world, "--name", "TripGUITester",
                    "--config", config, "--logfile", work / "client.log"],
                    cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
                if phase == "interrupt":
                    gui.wait_text(log, "TRIP GUI CHOOSER READY", client)
                    ImageGrab.grab(xdisplay=DISPLAY).save(work / "actual-chooser.png")
                    gui.click(400, 425)
                if phase == "resume":
                    gui.wait_text(log, "TRIP GUI PENDING SAVED PASS", client)
                gui.wait_text(log, marker, client, 110)
                code = client.wait(timeout=20)
                if code != 0:
                    raise RuntimeError("Native client exited with " + str(code))
                report["phases"].append({"phase": phase, "result": "pass", "marker": marker})
                print(phase + ": PASS", flush=True)
        report["result"] = "pass"
        report["scope"] = ("Actual X11 workshop click, real PlayerRef metadata/HUD and inventories, "
                           "normal immediate shutdown and two restarts in a disposable world; ordinary saves untouched.")
    except Exception as error:
        report["result"] = "inconclusive" if any("TRIP GUI INCONCLUSIVE" in p.read_text(errors="replace")
            for p in work.glob("*.log")) else "fail"
        report["error"] = str(error)
        raise
    finally:
        for process in (client, server):
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        xlog.close()
        (work / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
        for name in outputs:
            source = (world if name in {phase + ".json" for phase in records} else work) / name
            if source.is_file():
                shutil.copyfile(source, evidence / name)
        if temporary is not None:
            temporary.cleanup()


if __name__ == "__main__":
    main()
