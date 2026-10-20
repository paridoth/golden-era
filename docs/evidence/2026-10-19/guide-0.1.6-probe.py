from pathlib import Path
import hashlib, importlib.util, json, sys
root=Path.cwd()
mode=sys.argv[1]
assert mode in ("trees","help")
spec=importlib.util.spec_from_file_location("guide_gui",root/"tests/playtest/gui.py")
gui=importlib.util.module_from_spec(spec);spec.loader.exec_module(gui)
anchor='     core.log("action","ONBOARDING GUI CHOICE PASS "..choice)'
assert gui.OBSERVER.count(anchor)==1
show='     era_playtest.show_factory_guide(name,7)' if mode=="trees" else '     era_playtest.show_workshop_help(name)'
gui.OBSERVER=gui.OBSERVER.replace(anchor,show+'\n     local ok,version=core.registered_chatcommands.packversion.func(name,"")\n     assert(ok);core.log("action","GUI BUILD: "..version)\n'+anchor)
evidence=root/("runtime/tests/guide-"+mode+"-0.1.6")
sys.argv=["gui.py","--inspect-guide","--engine","tests/linux/flatpak-client.sh","--evidence-dir",str(evidence)]
gui.main()
log=(evidence/"survival-choice.log").read_text()
assert "ONBOARDING GUI CHOICE PASS survival" in log
assert "Golden Era 0.1.6" in log
assert "ERROR[" not in log
record={"mode":mode,"actual_survival_chooser_click":True,"form_selected_by":"observer uses native integration API after real choice; no tab/chat click claim","guide_page":7 if mode=="trees" else None,"guide_sha256":hashlib.sha256((root/"integrations/playtest/mod/guide.lua").read_bytes()).hexdigest(),"help_sha256":hashlib.sha256((root/"integrations/playtest/mod/init.lua").read_bytes()).hexdigest(),"harness_sha256":hashlib.sha256((root/"tests/playtest/gui.py").read_bytes()).hexdigest(),"probe_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"engine":"official Flathub Luanti 5.17.0 via repo-only matching runtime, software Xvfb/null audio","warnings":sum("WARNING[" in s for s in log.splitlines()),"errors":0}
(evidence/"inspection.json").write_text(json.dumps(record,indent=2)+"\n")
print("GUI CAPTURE PASS: "+mode+"; visual inspection still required")
