#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Optional project-local graphical build on Mint 22 / Ubuntu noble amd64.

Run the normal setup first. Uses system SDL2/OpenGL development files, recorded
in docs/graphical-client.md, plus hash-locked local JPEG/PNG/FreeType packages.
No system installation or upstream modifications. Audio/download support off.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
def run(args,**kwargs):
    subprocess.run([str(a) for a in args],check=True,**kwargs)
for name in ('luanti','mineclonia'):
    spec=json.loads((ROOT/'upstream.lock.json').read_text())[name]
    dest=ROOT/'upstream'/name
    actual=subprocess.check_output(['git','-C',dest,'rev-parse','HEAD'],text=True).strip()
    dirty=subprocess.check_output(['git','-C',dest,'status','--porcelain'],text=True).strip()
    if actual!=spec['commit'] or dirty:
        raise SystemExit('Unexpected or dirty upstream: '+name)
prefix=ROOT/'tools/client-root';debs=ROOT/'tools/client-debs'
prefix.mkdir(parents=True,exist_ok=True);debs.mkdir(parents=True,exist_ok=True)
for pkg in json.loads((ROOT/'client-build-deps.lock.json').read_text()):
    def candidates():
        return [p for p in debs.glob('*.deb') if hashlib.sha256(p.read_bytes()).hexdigest()==pkg['sha256']]
    files=candidates()
    if not files:
        run(['apt-get','download',pkg['name']+'='+pkg['version']],cwd=debs)
        files=candidates()
    if len(files)!=1:
        raise SystemExit('Missing or mismatched client dependency: '+pkg['name'])
    run(['dpkg-deb','-x',files[0],prefix])
base=ROOT/'tools/root'
env=os.environ.copy()
env['LD_LIBRARY_PATH']=str(prefix/'usr/lib/x86_64-linux-gnu')+':'+str(base/'usr/lib/x86_64-linux-gnu')
# CMake flag strings require embedded quoting for this workspace's spaces.
include='-I"'+str(prefix/'usr/include/x86_64-linux-gnu')+'"'
options=['-DCMAKE_BUILD_TYPE=Release','-DCMAKE_PREFIX_PATH='+str(prefix/'usr')+';'+str(base/'usr'),
         '-DCMAKE_CXX_FLAGS='+include,'-DCMAKE_C_FLAGS='+include,
         '-DBUILD_CLIENT=ON','-DBUILD_SERVER=OFF','-DBUILD_UNITTESTS=OFF',
         '-DBUILD_DOCUMENTATION=OFF','-DRUN_IN_PLACE=ON','-DENABLE_LTO=OFF']
for key,lib in [('JPEG_LIBRARY','jpeg'),('PNG_LIBRARY_RELEASE','png'),('FREETYPE_LIBRARY_RELEASE','freetype')]:
    options.append('-D'+key+'='+str(prefix/('usr/lib/x86_64-linux-gnu/lib'+lib+'.so')))
options += ['-DENABLE_'+feature+'=OFF' for feature in ['LUAJIT','CURL','GETTEXT','SOUND','CURSES','POSTGRESQL','LEVELDB','REDIS','SPATIAL','OPENSSL']]
cmake=base/'usr/bin/cmake'
run([cmake,'-S','upstream/luanti','-B','tools/build-client']+options,env=env)
run([cmake,'--build','tools/build-client','--parallel','2'],env=env)
run(['python3','scripts/setup.py','--assemble-only'])
print('Graphical client ready: run scripts/run-client.sh')
