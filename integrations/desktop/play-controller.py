#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Launch the optional Linux controller engine in its own persistent test world."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
client = ROOT / "runtime/desktop-controller/engine/bin/luanti"
if not sys.platform.startswith("linux"):
    raise SystemExit("This development controller variant is built for Linux only")
if not client.is_file():
    raise SystemExit("Build the opt-in engine with python3 integrations/desktop/build-client.py first")
subprocess.run([sys.executable, ROOT / "scripts/setup-playtest.py", "--no-fetch"], cwd=ROOT, check=True)
base = ROOT / "runtime/desktop-controller"
world = base / "worlds/controller-playtest"
world.mkdir(parents=True, exist_ok=True)
metadata = world / "world.mt"
if not metadata.exists():
    metadata.write_text("gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                        "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
elif "gameid = golden_era_playtest" not in metadata.read_text().splitlines():
    raise SystemExit("Unexpected controller test world; left untouched")
config = base / "playtest.conf"
if not config.exists():
    config.write_text("bind_address = 127.0.0.1\nport = 30202\nserver_announce = false\n"
                      "mg_name = v7\nmcl_singlenode_mapgen = false\ncreative_mode = false\n"
                      "enable_damage = false\nscreen_w = 1200\nscreen_h = 800\nfullscreen = false\n"
                      "fps_max = 30\nviewing_range = 60\n")
env = os.environ.copy()
env["LUANTI_GAME_PATH"] = str(ROOT / "runtime/playtest/games")
env["LD_LIBRARY_PATH"] = (str(ROOT / "tools/client-root/usr/lib/x86_64-linux-gnu") + ":" +
                          str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu"))
print("Experimental controller world:", world, flush=True)
print("Menus: left stick / D-pad cursor; A click; X split/place one; Y quick transfer; B back.", flush=True)
os.chdir(ROOT)
os.execve(client, [str(client), "--go", "--gameid", "golden_era_playtest", "--world", str(world),
                  "--name", "ControllerTester", "--port", "30202", "--config", str(config),
                  "--logfile", str(base / "client.log")], env)
