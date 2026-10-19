#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Launch the existing-mod playtest in its dedicated persistent world."""
import argparse
import os
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prepare-only',action='store_true',help='Assemble the game and configuration without opening a client')
args=parser.parse_args()
subprocess.run(['python3',str(ROOT/'scripts/setup-playtest.py')],cwd=ROOT,check=True)
base=ROOT/'runtime/playtest'
world=base/'worlds/revelation-playtest'
world_file=world/'world.mt'
if world_file.exists():
 metadata=world_file.read_bytes().decode('utf-8')
 gameid=None
 for line in metadata.split('\n'):
  if re.match(r'^[ \t\r\v\f]*#',line):
   continue
  if re.match(r'^[^=]*=[ \t\r\v\f]*(?:\{|"{3})[ \t\r\v\f]*$',line):
   raise SystemExit('The playtest world uses structured world.mt settings; restore its flat Golden Era metadata before launching')
  match=re.match(r'^[ \t\r\v\f]*gameid[ \t\r\v\f]*=[ \t\r\v\f]*(.*?)[ \t\r\v\f]*$',line)
  if match: gameid=match.group(1)
 if gameid!='golden_era_playtest':
  raise SystemExit('Unexpected game ID in the playtest world; left untouched')
elif any((world/name).exists() for name in ('map.sqlite','map.db','map.sqlite-wal','map_meta.txt','players.sqlite','auth.sqlite','auth.txt','mod_storage.sqlite','players')):
 raise SystemExit('The playtest world has saved data but no world.mt; restore it before launching')
else:
 world.mkdir(parents=True,exist_ok=True)
 world_file.write_text('gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
config=base/'playtest.conf'
if not config.exists():
 config.write_text('''bind_address = 127.0.0.1
port = 30200
server_announce = false
mg_name = v7
mcl_singlenode_mapgen = false
creative_mode = false
enable_damage = false
screen_w = 1200
screen_h = 800
fullscreen = false
fps_max = 30
viewing_range = 60
''')
print('Playtest world: '+str(world),flush=True)
if not args.prepare_only:
 client=ROOT/'upstream/luanti/bin/luanti'
 if not client.is_file(): raise SystemExit('Build the local graphical client with python3 scripts/build-client.py first')
 env=os.environ.copy();env['LUANTI_GAME_PATH']=str(base/'games')
 env['LD_LIBRARY_PATH']=str(ROOT/'tools/client-root/usr/lib/x86_64-linux-gnu')+':'+str(ROOT/'tools/root/usr/lib/x86_64-linux-gnu')
 os.chdir(ROOT)
 os.execve(str(client),['luanti','--go','--gameid','golden_era_playtest','--world',str(world),
  '--port','30200','--name','Josh','--config',str(config),'--logfile',str(base/'client.log')],env)
