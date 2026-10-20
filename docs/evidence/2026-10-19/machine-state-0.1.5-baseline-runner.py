from pathlib import Path
import os,subprocess,json
root=Path(__file__).resolve().parents[3];work=Path(__file__).resolve().parent
env=os.environ.copy();env['LUANTI_GAME_PATH']=str(root/'runtime/tests/tree-native-small-0.1.5-nlg150s6/games');env['LD_LIBRARY_PATH']=str(root/'tools/root/usr/lib/x86_64-linux-gnu')
with (work/'native.stdout').open('w') as out:r=subprocess.run([str(root/'upstream/luanti/bin/luantiserver'),'--gameid','golden_era_playtest','--world',str(work/'world'),'--config',str(work/'test.conf'),'--logfile',str(work/'native.log')],cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT,timeout=85)
text=(work/'native.stdout').read_text();print(text[-18000:]);assert r.returncode==0 and 'ERA MACHINE STATE AUDIT PASS: COMPLETE:' in text
print('Retained diagnostics: '+json.dumps([x for x in text.splitlines() if 'ERROR[' in x or 'WARNING[' in x]))
