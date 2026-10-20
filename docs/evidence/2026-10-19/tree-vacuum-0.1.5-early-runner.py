from pathlib import Path
import os,subprocess,json,hashlib
root=Path(__file__).resolve().parents[3];work=Path(__file__).resolve().parent
archive_game=root/'runtime/tests/tree-native-small-0.1.5-nlg150s6/games'
env=os.environ.copy();env['LUANTI_GAME_PATH']=str(archive_game);env['LD_LIBRARY_PATH']=str(root/'tools/root/usr/lib/x86_64-linux-gnu')
for phase in ['checkpoint','resume']:
 print('Starting early '+phase,flush=True)
 with (work/(phase+'.stdout')).open('w') as out:
  r=subprocess.run([str(root/'upstream/luanti/bin/luantiserver'),'--gameid','golden_era_playtest','--world',str(work/'world'),'--config',str(work/'test.conf'),'--logfile',str(work/(phase+'.log'))],cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=100)
 text=(work/(phase+'.stdout')).read_text();print(text[-12000:],flush=True)
 assert r.returncode==0 and ('ERA VACUUM EARLY AUDIT PASS: '+('CHECKPOINT:' if phase=='checkpoint' else 'COMPLETE:')) in text
 assert 'ERA VACUUM EARLY AUDIT FAIL:' not in text
 print('Retained native diagnostics: '+json.dumps([x for x in text.splitlines() if 'ERROR[' in x or 'WARNING[' in x]),flush=True)
