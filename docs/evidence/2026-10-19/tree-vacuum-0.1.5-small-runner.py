from pathlib import Path
import os,subprocess,json,hashlib,sys
root=Path(__file__).resolve().parents[3];work=Path(__file__).resolve().parent
inputs=json.loads((work/'archive-inputs.json').read_text())
env=os.environ.copy();env['LUANTI_GAME_PATH']=str(work/'games');env['LD_LIBRARY_PATH']=str(root/'tools/root/usr/lib/x86_64-linux-gnu')
for phase in (['resume'] if '--resume' in sys.argv else ['checkpoint','resume']):
 cmd=[str(root/'upstream/luanti/bin/luantiserver'),'--gameid','golden_era_playtest','--world',str(work/'world'),'--config',str(work/'test.conf'),'--logfile',str(work/(phase+'.log'))]
 print('Starting '+phase,flush=True)
 with (work/(phase+'.stdout')).open('w') as out:
  result=subprocess.run(cmd,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=390)
 text=(work/(phase+'.stdout')).read_text();print(text[-12000:],flush=True)
 assert result.returncode==0 and 'ERA TREE AUDIT PASS: '+('CHECKPOINT:' if phase=='checkpoint' else 'COMPLETE:') in text
 assert 'ERA TREE AUDIT FAIL:' not in text
 diagnostics=[l for l in text.splitlines() if 'ERROR[' in l or 'WARNING[' in l]
 print('All native diagnostics retained: '+json.dumps(diagnostics),flush=True)
 assert not [l for l in diagnostics if 'ERROR[' in l]
for rel,sha in inputs['files'].items():assert hashlib.sha256((work/'games'/rel).read_bytes()).hexdigest()==sha,'Game file changed: '+rel
print('UNCHANGED GAME FILE HASHES PASS',flush=True)
