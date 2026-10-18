#!/usr/bin/env python3
import argparse, os, pathlib, subprocess, tempfile
ROOT=pathlib.Path(__file__).resolve().parents[2]
ALL_PHASES=['seed','resume','automatic','recipe_seed','recipe_resume','recipe_verify','lifecycle','corrupt_seed','corrupt_resume','corrupt_verify','native_seed','native_resume','native_verify','byproduct_seed','byproduct_resume','byproduct_verify','sides_seed','sides_resume','survival_seed','survival_resume','player_counts','relocation_seed','relocation_resume','relocation_verify']
parser=argparse.ArgumentParser()
parser.add_argument('--phases',nargs='+',choices=ALL_PHASES,help='Run a focused fresh-world sequence during development')
args=parser.parse_args()
subprocess.run(['python3',str(ROOT/'scripts/setup.py'),'--assemble-only'],check=True,cwd=ROOT)
env=os.environ.copy(); env['LUANTI_GAME_PATH']=str(ROOT/'runtime/games'); env['LD_LIBRARY_PATH']=str(ROOT/'tools/root/usr/lib/x86_64-linux-gnu')
base=ROOT/'runtime/tests'; base.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='integration-',dir=base) as temp:
 work=pathlib.Path(temp); world=work/'world'; (world/'worldmods').mkdir(parents=True)
 (world/'worldmods/era_integration').symlink_to(ROOT/'tests/integration/mod',target_is_directory=True)
 (world/'world.mt').write_text('gameid = golden_era\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
 phases = args.phases or ALL_PHASES
 for phase in phases:
  settings = [
   'bind_address = 127.0.0.1', 'port = 30199', 'server_announce = false',
   'mg_name = singlenode', 'mcl_singlenode_mapgen = false', 'creative_mode = false',
   'era_test_manual = '+('false' if phase in ('automatic','corrupt_resume') else 'true'),
   'era_test_phase = '+phase,
  ]
  if phase in ('recipe_resume','native_resume'):
   settings += ['era_pulverizer_cost = 900','era_process_rate = 75','era_ore_multiplier = 3']
  if phase=='lifecycle':
   settings += ['server_unload_unused_data_timeout = 5','active_block_mgmt_interval = 0.1']
  config=work/'test.conf'; config.write_text('\n'.join(settings)+'\n')
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
  print(next(line for line in log.splitlines() if marker in line),flush=True)
 print(f'ENGINE INTEGRATION PASS: {len(phases)} real server processes; '+', '.join(phases))
