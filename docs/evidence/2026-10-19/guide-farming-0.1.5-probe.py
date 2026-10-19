from pathlib import Path
import hashlib, importlib.util, json, sys
root=Path.cwd()
spec=importlib.util.spec_from_file_location('guide_gui',root/'tests/playtest/gui.py')
gui=importlib.util.module_from_spec(spec);spec.loader.exec_module(gui)
anchor='     core.log("action","ONBOARDING GUI CHOICE PASS "..choice)'
assert gui.OBSERVER.count(anchor)==1
gui.OBSERVER=gui.OBSERVER.replace(anchor,'     era_playtest.show_factory_guide(name,6)\n'+anchor)
evidence=root/'runtime/tests/guide-farming-0.1.5-final'
sys.argv=['gui.py','--inspect-guide','--engine','tests/linux/flatpak-client.sh','--evidence-dir',str(evidence)]
gui.main()
log=(evidence/'survival-choice.log').read_text()
assert 'ONBOARDING GUI CHOICE PASS survival' in log
assert 'ERROR[' not in log
assert (evidence/'survival-selected.png').is_file()
record={'mode':'final Farming guide layout inspection; exact source hash recorded','actual_survival_chooser_click':True,'guide_page':6,'page_selected_by':'test observer calls native era_playtest.show_factory_guide; no claim of clicking a guide tab','guide_sha256':hashlib.sha256((root/'integrations/playtest/mod/guide.lua').read_bytes()).hexdigest(),'harness_sha256':hashlib.sha256((root/'tests/playtest/gui.py').read_bytes()).hexdigest(),'probe_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'engine':'official Flathub Luanti 5.17.0 via repository wrapper; software Xvfb, null audio','warnings':sum('WARNING[' in s for s in log.splitlines()),'errors':0}
(evidence/'inspection.json').write_text(json.dumps(record,indent=2)+'\n')
print('FARMING GUIDE RENDER PASS; inspect survival-selected.png before accepting layout')
