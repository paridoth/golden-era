#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Launch an isolated graphical QA factory; never edits the normal play world."""
import argparse
import os
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--form',choices=('generator','pulverizer','furnace','buffer'))
parser.add_argument("--cycle",action="store_true",help="Render each machine form for visual inspection")
args=parser.parse_args()
subprocess.run(['python3',ROOT/'scripts/setup.py','--assemble-only'],cwd=ROOT,check=True)
world=ROOT/'runtime/worlds/graphical-demo';(world/'worldmods').mkdir(parents=True,exist_ok=True)
link=world/'worldmods/era_demo'
if not link.exists(): link.symlink_to(ROOT/'tests/manual/mod',target_is_directory=True)
(world/'world.mt').write_text('gameid = golden_era\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
config=ROOT/'runtime/demo.conf'
config.write_text('''bind_address = 127.0.0.1
port = 30198
server_announce = false
mg_name = singlenode
mcl_singlenode_mapgen = false
creative_mode = true
enable_damage = false
screen_w = 1200
screen_h = 800
fullscreen = false
fps_max = 30
viewing_range = 40
'''+('era_demo_form = '+args.form+'\n' if args.form else '')+('era_demo_cycle = true\n' if args.cycle else ''))
env=os.environ.copy();env['LUANTI_GAME_PATH']=str(ROOT/'runtime/games')
env['LD_LIBRARY_PATH']=str(ROOT/'tools/client-root/usr/lib/x86_64-linux-gnu')+':'+str(ROOT/'tools/root/usr/lib/x86_64-linux-gnu')
os.chdir(ROOT)
os.execve(str(ROOT/'upstream/luanti/bin/luanti'),['luanti','--go','--gameid','golden_era','--world',str(world),'--port','30198','--name','GoldenEraQA','--config',str(config),'--logfile',str(ROOT/'runtime/demo-client.log')],env)
