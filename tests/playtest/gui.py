#!/usr/bin/env python3
"""Render and click the real first-join chooser in an isolated Xvfb desktop."""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
DISPLAY = ":97"

OBSERVER = r'''
local choice=assert(core.settings:get("gui_smoke_choice"))
assert(core.registered_items["mcl_copper:copper_ingot"],"Persistence fixture must be a registered item")
local state=core.get_mod_storage()
core.register_on_joinplayer(function(player)
 local name=player:get_player_name()
 core.after(3,function()
  local current=assert(core.get_player_by_name(name))
  local meta=current:get_meta()
  if state:get_int("phase")==1 then
   assert(meta:get_int("era_playtest_joined")==1,"Existing first-join marker survives restart")
   assert(meta:get_string("era_playtest_start_mode")==choice,"Starting choice survives restart")
   assert(current:get_inventory():contains_item("main","mcl_copper:copper_ingot 7"),"Saved player inventory survives restart")
   local previous=core.deserialize(state:get_string("position"))
   assert(vector.distance(current:get_pos(),previous)<4,"Saved position survives restart")
   core.log("action","ONBOARDING GUI RECONNECT PASS "..choice)
   core.request_shutdown("GUI reconnect test complete",false,1)
  else
   assert(meta:get_int("era_playtest_joined")==0,"Fresh player must choose before any workshop kit")
   for _,stack in ipairs(current:get_inventory():get_list("main")) do
    assert(stack:is_empty() or (stack:get_name()=="elepower_tome:tome" and stack:get_count()==1),"Chooser grants no tools or materials; stock help book only")
   end
   core.log("action","ONBOARDING GUI CHOOSER READY "..choice)
   local function watch()
    local p=core.get_player_by_name(name)
    if not p then return end
    if p:get_meta():get_int("era_playtest_joined")~=1 then core.after(0.2,watch);return end
    assert(p:get_meta():get_string("era_playtest_start_mode")==choice,"Real click chose expected path")
    local inv=p:get_inventory()
    if choice=="survival" then
     for _,stack in ipairs(inv:get_list("main")) do
      assert(stack:is_empty() or stack:get_name()=="elepower_tome:tome","Real survival choice grants no tools or materials")
     end
    else
     assert(inv:contains_item("main","mcl_tools:pick_diamond"),"Real workshop choice grants a pick")
     assert(inv:contains_item("main","mcl_tools:axe_diamond"),"Real workshop choice grants an axe")
     assert(inv:contains_item("main","mcl_torches:torch 32"),"Real workshop choice grants torches")
    end
    local began=core.get_us_time()
    local function verify_destination()
     local selected=assert(core.get_player_by_name(name))
     if choice=="workshop" and vector.distance(selected:get_pos(),{x=3,y=200.5,z=6})>=4 then
      assert(core.get_us_time()-began<45*1000000,"Workshop destination timeout: "..core.pos_to_string(selected:get_pos()).."; platform="..core.get_node({x=3,y=199,z=6}).name)
      core.after(0.2,verify_destination);return
     end
     if choice=="workshop" then
      assert(vector.distance(selected:get_pos(),{x=3,y=200.5,z=6})<4,"Workshop choice reaches the supplied platform")
     else
      local surface=assert(core.deserialize(selected:get_meta():get_string("era_playtest_surface")))
      assert(vector.distance(selected:get_pos(),surface)<16,"Survival choice stays near the natural spawn")
     end
     selected:get_inventory():add_item("main","mcl_copper:copper_ingot 7")
     state:set_int("phase",1)
     state:set_string("position",core.serialize(selected:get_pos()))
     core.log("action","ONBOARDING GUI CHOICE PASS "..choice)
     core.request_shutdown("GUI choice test complete",false,3)
    end
    core.after(3,verify_destination)
   end
   watch()
  end
 end)
end)
'''


def setup_tools(fetch):
    directory = ROOT / "tools/gui-root"
    for entry in json.loads((ROOT / "gui-test-deps.lock.json").read_text()):
        cache = ROOT / "tools/gui-debs"
        cache.mkdir(parents=True, exist_ok=True)
        matches = [path for path in cache.glob("*.deb") if path.stat().st_size == entry["size"]
                   and hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]]
        if not matches and fetch:
            subprocess.run(["apt-get", "download", entry["name"] + "=" + entry["version"]], cwd=cache, check=True)
            matches = [path for path in cache.glob("*.deb") if hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"]]
        if len(matches) != 1:
            raise RuntimeError("Missing/mismatched GUI dependency; use --fetch-tools: " + entry["name"])
        subprocess.run(["dpkg-deb", "-x", str(matches[0]), str(directory)], check=True)
    return directory / "usr/bin/Xvfb"


def wait_text(log, marker, process, seconds=90):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        content = log.read_text(errors="replace") if log.exists() else ""
        if marker in content:
            return
        if "ERROR[Main]: ServerError" in content:
            raise RuntimeError("Server error during GUI run\n" + content[-5000:])
        if process.poll() is not None:
            raise RuntimeError("Client exited before " + marker + "\n" + content[-5000:])
        time.sleep(0.1)
    raise RuntimeError("Timeout waiting for " + marker)


def click(x, y):
    x11 = ctypes.CDLL("libX11.so.6")
    xtest = ctypes.CDLL("libXtst.so.6")
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(DISPLAY.encode())
    if not display:
        raise RuntimeError("Could not connect to isolated GUI display")
    xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
    xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    xtest.XTestFakeMotionEvent(display, -1, x, y, 0)
    xtest.XTestFakeButtonEvent(display, 1, 1, 0)
    x11.XSync(display, 0)
    time.sleep(0.12)
    xtest.XTestFakeButtonEvent(display, 1, 0, 0)
    x11.XSync(display, 0)
    x11.XCloseDisplay(display)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-tools", action="store_true")
    parser.add_argument("--inspect", action="store_true", help="Capture the first chooser without clicking, for layout inspection")
    parser.add_argument("--inspect-guide", action="store_true", help="Capture the first actual guide after choosing survival, then stop")
    args = parser.parse_args()
    from PIL import ImageGrab
    xvfb = setup_tools(args.fetch_tools)
    evidence = ROOT / "runtime/tests/onboarding-gui"
    evidence.mkdir(parents=True, exist_ok=True)
    base = ROOT / "runtime/tests"
    report = []
    (evidence / "summary.log").unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="onboarding-gui-", dir=base) as temporary:
        work = Path(temporary)
        env = os.environ.copy()
        env.update(DISPLAY=DISPLAY, XAUTHORITY=str(work / "Xauthority"), LIBGL_ALWAYS_SOFTWARE="1")
        env["LD_LIBRARY_PATH"] = ":".join(str(ROOT / location) for location in
                                         ("tools/client-root/usr/lib/x86_64-linux-gnu", "tools/root/usr/lib/x86_64-linux-gnu", "tools/gui-root/usr/lib/x86_64-linux-gnu"))
        subprocess.run(["xauth", "-f", env["XAUTHORITY"], "add", DISPLAY, ".", secrets.token_hex(16)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Xauthority and Xlib are also used in this Python process for screenshots/input.
        os.environ["DISPLAY"] = DISPLAY
        os.environ["XAUTHORITY"] = env["XAUTHORITY"]
        server_log = (evidence / "xvfb.log").open("w")
        server = subprocess.Popen([str(xvfb), DISPLAY, "-screen", "0", "1280x900x24", "-nolisten", "tcp", "-auth", env["XAUTHORITY"]], env=env, stdout=server_log, stderr=subprocess.STDOUT)
        try:
            time.sleep(0.5)
            if server.poll() is not None:
                raise RuntimeError("Isolated Xvfb could not start")
            game = work / "games/golden_era_playtest"
            subprocess.run(["python3", str(ROOT / "scripts/setup-playtest.py"), "--no-fetch", "--destination", str(game)], check=True, stdout=subprocess.DEVNULL)
            env["LUANTI_GAME_PATH"] = str(work / "games")
            for choice in ("survival", "workshop"):
                world = work / choice
                observer = world / "worldmods/gui_observer"
                observer.mkdir(parents=True)
                (observer / "mod.conf").write_text("name = gui_observer\ndepends = era_playtest\n")
                (observer / "init.lua").write_text(OBSERVER)
                (world / "world.mt").write_text("gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
                config = work / (choice + ".conf")
                config.write_text("\n".join((ROOT / "packaging/playtest/templates/defaults/playtest.conf").read_text().splitlines() +
                                            ["port = 30212", "screen_w = 1280", "screen_h = 900", "viewing_range = 20", "fps_max = 15", "gui_smoke_choice = " + choice]) + "\n")
                for phase in ("choice", "reconnect"):
                    log = evidence / (choice + "-" + phase + ".log")
                    with log.open("w") as output:
                        client = subprocess.Popen([str(ROOT / "upstream/luanti/bin/luanti"), "--go", "--port", "30212", "--gameid", "golden_era_playtest", "--world", str(world), "--name", "GUITester", "--config", str(config), "--logfile", str(work / "client.log")], cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
                        try:
                            if phase == "choice":
                                wait_text(log, "ONBOARDING GUI CHOOSER READY " + choice, client)
                                time.sleep(0.3)
                                ImageGrab.grab(xdisplay=DISPLAY).save(evidence / (choice + "-chooser.png"))
                                if args.inspect:
                                    return
                                # The real 12x7 form is centered on the fixed 1280x900 test display.
                                click(850 if choice == "survival" else 400, 425)
                                wait_text(log, "ONBOARDING GUI CHOICE PASS " + choice, client, 60)
                                time.sleep(0.4)
                                ImageGrab.grab(xdisplay=DISPLAY).save(evidence / (choice + "-selected.png"))
                                if args.inspect_guide:
                                    return
                            else:
                                wait_text(log, "ONBOARDING GUI RECONNECT PASS " + choice, client)
                            code = client.wait(timeout=15)
                            if code != 0:
                                raise RuntimeError("Client exited unsuccessfully: " + str(code))
                            report.append(choice + " " + phase + ": PASS")
                        finally:
                            if client.poll() is None:
                                client.terminate()
                                client.wait(timeout=10)
        finally:
            server.terminate()
            server.wait(timeout=10)
            server_log.close()
    report.append("Actual client rendering, X11 mouse clicks, real PlayerRef inventory and restart persistence checked; no user world modified.")
    (evidence / "summary.log").write_text("\n".join(report) + "\n")
    print("\n".join(report))


if __name__ == "__main__":
    main()
