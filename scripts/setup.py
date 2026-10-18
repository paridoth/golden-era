#!/usr/bin/env python3
"""Project-local source build for Linux Mint 22 / Ubuntu noble x86_64."""
import hashlib, json, os, pathlib, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
os.chdir(ROOT)
def run(args, **kw): subprocess.run([str(a) for a in args], check=True, **kw)
lock=json.loads(pathlib.Path('upstream.lock.json').read_text())
if '--assemble-only' not in sys.argv:
 for name, spec in lock.items():
  dest=ROOT/'upstream'/name
  if not dest.exists():
   run(['git','init',dest]); run(['git','-C',dest,'remote','add','origin',spec['url']])
   run(['git','-C',dest,'fetch','--depth','1','origin',spec['commit']]); run(['git','-C',dest,'checkout','--detach','FETCH_HEAD'])
  actual=subprocess.check_output(['git','-C',dest,'rev-parse','HEAD'],text=True).strip()
  if actual!=spec['commit']: raise SystemExit('Upstream revision mismatch: '+name)
  if subprocess.check_output(['git','-C',dest,'status','--porcelain'],text=True).strip(): raise SystemExit('Dirty upstream checkout: '+name)
 debs=ROOT/'tools/debs'; debs.mkdir(parents=True,exist_ok=True)
 prefix=ROOT/'tools/root'; prefix.mkdir(parents=True,exist_ok=True)
 for pkg in json.loads(pathlib.Path('build-deps.lock.json').read_text()):
  candidates=[f for f in debs.glob('*.deb') if hashlib.sha256(f.read_bytes()).hexdigest()==pkg['sha256']]
  if not candidates:
   run(['apt-get','download',pkg['name']+'='+pkg['version']],cwd=debs)
   candidates=[f for f in debs.glob('*.deb') if hashlib.sha256(f.read_bytes()).hexdigest()==pkg['sha256']]
  if len(candidates)!=1: raise SystemExit('Missing or mismatched dependency: '+pkg['name'])
  run(['dpkg-deb','-x',candidates[0],prefix])
 env=os.environ.copy(); env['LD_LIBRARY_PATH']=str(prefix/'usr/lib/x86_64-linux-gnu')
 cmake=prefix/'usr/bin/cmake'
 options=['-DBUILD_CLIENT=OFF','-DBUILD_SERVER=ON','-DBUILD_UNITTESTS=OFF','-DBUILD_DOCUMENTATION=OFF','-DRUN_IN_PLACE=ON','-DENABLE_LTO=OFF']
 options += ['-DENABLE_'+feature+'=OFF' for feature in ['LUAJIT','CURL','GETTEXT','CURSES','POSTGRESQL','LEVELDB','REDIS','SPATIAL','OPENSSL']]
 run([cmake,'-S','upstream/luanti','-B','tools/build','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_PREFIX_PATH='+str(prefix/'usr')]+options,env=env)
 run([cmake,'--build','tools/build','-j2'],env=env)
game=ROOT/'runtime/games/golden_era'; (game/'mods').mkdir(parents=True,exist_ok=True)
# Preserve the full Mineclonia tree and notices; add custom mods beside its categories.
for source in (ROOT/'upstream/mineclonia/mods').iterdir():
 target=game/'mods'/source.name
 if not target.exists(): target.symlink_to(source,target_is_directory=source.is_dir())
for source in (ROOT/'mods').iterdir():
 target=game/'mods'/source.name
 if not target.exists(): target.symlink_to(source,target_is_directory=True)
for name in ['menu','minetest.conf','settingtypes.txt','LICENSE.txt','LEGAL.md','CREDITS.md','README.md']:
 target=game/name; source=ROOT/'upstream/mineclonia'/name
 if target.is_symlink(): target.unlink()
 if source.is_dir(): shutil.copytree(source,target,dirs_exist_ok=True)
 else: shutil.copy2(source,target)
text=(ROOT/'upstream/mineclonia/game.conf').read_text().replace('title = Mineclonia','title = Golden Era (prototype)')
(game/'game.conf').write_text(text)
print('Ready: '+str(game))
