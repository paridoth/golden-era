#!/usr/bin/env python3
import os, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
subprocess.run(['python3',str(ROOT/'scripts/setup.py'),'--assemble-only'],check=True,cwd=ROOT)
env=os.environ.copy(); env['LUANTI_GAME_PATH']=str(ROOT/'runtime/games'); env['LD_LIBRARY_PATH']=str(ROOT/'tools/root/usr/lib/x86_64-linux-gnu')
base=ROOT/'runtime/tests'; base.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='integration-',dir=base) as temp:
 work=pathlib.Path(temp); world=work/'world'; (world/'worldmods').mkdir(parents=True)
 (world/'worldmods/era_integration').symlink_to(ROOT/'tests/integration/mod',target_is_directory=True)
 (world/'world.mt').write_text('gameid = golden_era\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 phases = ['seed','resume','automatic','recipe_seed','recipe_resume','recipe_verify','lifecycle']
 for phase in phases:
  config=work/'test.conf'; config.write_text('bind_address = 127.0.0.1\nport = 30199\nserver_announce = false\nmg_name = singlenode\nmcl_singlenode_mapgen = false\nera_test_manual = '+('false' if phase=='automatic' else 'true')+'\nera_test_phase = '+phase+'\n'+('era_pulverizer_cost = 900\nera_process_rate = 75\nera_ore_multiplier = 3\n' if phase=='recipe_resume' else '')+('server_unload_unused_data_timeout = 5\nactive_block_mgmt_interval = 0.1\n' if phase=='lifecycle' else ''))
  try:
   result=subprocess.run([str(ROOT/'upstream/luanti/bin/luantiserver'),'--gameid','golden_era','--world',str(world),'--config',str(config),'--logfile',str(work/(phase+'.log'))],env=env,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
  except subprocess.TimeoutExpired as error:
   output=error.stdout or b''
   if isinstance(output,bytes): output=output.decode(errors='replace')
   (base/(phase+'.log')).write_text(output)
   print(output); raise SystemExit('ENGINE INTEGRATION TIMEOUT: '+phase)
  log=result.stdout; (base/(phase+'.log')).write_text(log)
  marker='ERA INTEGRATION '+phase.upper()+' PASS'
  if result.returncode or marker not in log or 'ERA INTEGRATION FAIL' in log:
   print(log); raise SystemExit('ENGINE INTEGRATION FAILED: '+phase)
  print(next(line for line in log.splitlines() if marker in line))
 print('ENGINE INTEGRATION PASS: seven real server processes, crafting, SQLite persistence, automatic scheduler, changed recipe settings and natural block lifecycle')
