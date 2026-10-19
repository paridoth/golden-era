#!/usr/bin/env python3
"""Test current Unix launcher templates against existing saves without rebuilding releases."""
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ("packaging/linux/templates/start.sh", "packaging/playtest/templates/start.sh")
MARKERS = ("map.sqlite", "map.db", "map.sqlite-wal", "map_meta.txt", "players.sqlite", "auth.sqlite", "auth.txt", "mod_storage.sqlite", "players")


METADATA_CASES = (
    ("correct", "gameid = golden_era_playtest\n", True),
    ("CRLF and whitespace", "\tgameid\t=\tgolden_era_playtest \t\r\n", True),
    ("comments", "# gameid = another_game\ngameid = golden_era_playtest\n# gameid = another_game\n", True),
    ("commented structure", '# options = {\n# options = """\ngameid = golden_era_playtest\n', True),
    ("final correct", "gameid = another_game\ngameid = golden_era_playtest\n", True),
    ("case sensitive key ignored", "gameid = golden_era_playtest\nGAMEID = another_game\n", True),
    ("foreign", "gameid = another_game\n", False),
    ("foreign with settings", "gameid = another_game\n", False),
    ("final foreign", "gameid = golden_era_playtest\ngameid = another_game\n", False),
    ("final empty", "gameid = golden_era_playtest\ngameid =\n", False),
    ("missing key", "backend = sqlite3\n", False),
    ("empty", "", False),
    ("case sensitive value", "gameid = GOLDEN_ERA_PLAYTEST\n", False),
    ("case sensitive key", "gameid = another_game\nGAMEID = golden_era_playtest\n", False),
    ("inline comment is value", "gameid = golden_era_playtest #not-an-inline-comment\n", False),
    ("nested spoof", "gameid = another_game\noptions = {\ngameid = golden_era_playtest\n}\n", False),
    ("hash group name", "gameid = another_game\nfoo#bar = {\ngameid = golden_era_playtest\n}\n", False),
    ("empty group name", "gameid = another_game\n= {\ngameid = golden_era_playtest\n}\n", False),
    ("hash multiline name", 'gameid = another_game\nfoo#bar = """\ngameid = golden_era_playtest\n"""\n', False),
    ("empty multiline name", 'gameid = another_game\n= """\ngameid = golden_era_playtest\n"""\n', False),
    ("nonstandard group", "gameid = golden_era_playtest\noptions = {\na = 1\n}\n", False),
    ("nonstandard multiline", 'gameid = """\ngolden_era_playtest\n"""\n', False),
    ("Unicode trailing space", "gameid = golden_era_playtest\u3000\n", False),
    ("Unicode key whitespace", "gameid = another_game\n\u00a0gameid = golden_era_playtest\n", False),
    ("UTF8 BOM key", "\ufeffgameid = golden_era_playtest\n", False),
    ("bare CR is not a line break", "gameid = another_game\rgameid = golden_era_playtest\n", False),
)


def snapshot(folder):
    result = {}
    for path in [folder, *sorted(folder.rglob("*"))]:
        relative = path.relative_to(folder).as_posix()
        info = path.lstat()
        mode = stat.S_IMODE(info.st_mode)
        if path.is_symlink():
            result[relative] = ("symlink", mode, info.st_mtime_ns, os.readlink(path))
        elif path.is_dir():
            result[relative] = ("directory", mode, info.st_mtime_ns)
        else:
            result[relative] = ("file", mode, info.st_mtime_ns, path.read_bytes())
    return result


def developer_guard(work, report):
    # Execute the developer launcher's actual guard AST in disposable folders.
    # The surrounding pack assembly/client launch never runs in this test.
    source = ROOT / "scripts/play-playtest.py"
    tree = ast.parse(source.read_text())
    guard = next(node for node in tree.body if isinstance(node, ast.If)
                 and ast.unparse(node.test) == "world_file.exists()")
    code = compile(ast.Module(body=[guard], type_ignores=[]), str(source), "exec")
    group = work / "developer launcher"

    def check(folder, accepted):
        before = snapshot(folder)
        refused = False
        try:
            exec(code, {"world": folder / "worlds/playtest", "world_file": folder / "worlds/playtest/world.mt", "re": re})
        except SystemExit:
            refused = True
        assert refused != accepted, "Developer guard result differs: " + str(folder)
        assert snapshot(folder) == before, "Developer guard changed existing save data: " + str(folder)

    for name, metadata, accepted in METADATA_CASES:
        folder = group / name
        world = folder / "worlds/playtest"
        world.mkdir(parents=True)
        (world / "world.mt").write_bytes(metadata.encode())
        (world / "map.sqlite").write_bytes(b"saved developer world")
        check(folder, accepted)
    for marker in MARKERS:
        folder = group / ("orphan " + marker)
        world = folder / "worlds/playtest"
        world.mkdir(parents=True)
        if marker in ("players", "map.db"):
            (world / marker).mkdir()
            (world / marker / "saved-data").write_bytes(b"retained directory contents")
        else:
            (world / marker).write_bytes(b"retained database bytes")
        check(folder, False)
    report.append("scripts/play-playtest.py SHA256 " + hashlib.sha256(source.read_bytes()).hexdigest())
    report.append("PASS: actual developer guard preserves UTF8 BOM/bare-CR semantics, rejects #/empty structured names and all nine orphan markers without changing saves")


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    report = ["Current Unix launcher save/config preflight", "Source-template fixtures only; frozen 0.1.1 release artifacts are unchanged."]
    with tempfile.TemporaryDirectory(prefix="save guard with spaces ", dir=base) as temporary:
        work = Path(temporary)
        engine = work / "engine stub"
        engine.write_text("#!/usr/bin/python3\nimport json,os,sys\n"
                          "with open(os.environ['GE_CAPTURE'],'a') as f:f.write(json.dumps(sys.argv[1:])+'\\n')\n"
                          "if '--version' in sys.argv:print('Luanti 5.17.0 (save-guard test)')\n")
        engine.chmod(0o755)
        for template in TEMPLATES:
            group = work / ("linux" if "/linux/" in template else "shared unix")
            bundle = group / "game with spaces [qa] ' $"
            (bundle / "defaults").mkdir(parents=True)
            (bundle / "defaults/playtest.conf").write_bytes(b"# packaged defaults\nviewing_range = 60\n")
            launcher = bundle / "start.sh"
            shutil.copyfile(ROOT / template, launcher)
            launcher.chmod(0o755)
            subprocess.run(["sh", "-n", str(launcher)], check=True)
            digest = hashlib.sha256(launcher.read_bytes()).hexdigest()
            report.append(template + " SHA256 " + digest)
            capture = group / "engine invocations.jsonl"
            env = os.environ.copy()
            env.update(GOLDEN_ERA_ENGINE=str(engine), GE_CAPTURE=str(capture), DISPLAY="", WAYLAND_DISPLAY="")

            def launch(folder, accepted):
                capture.unlink(missing_ok=True)
                local = env.copy()
                local["GOLDEN_ERA_DATA_DIR"] = str(folder)
                before = snapshot(folder) if folder.exists() else None
                result = subprocess.run([str(launcher)], env=local, text=True, capture_output=True, timeout=10)
                assert (result.returncode == 0) == accepted, str(folder) + ": " + result.stderr
                if not accepted:
                    assert snapshot(folder) == before, "Refusal changed files/directories: " + str(folder)
                    assert not capture.exists(), "Refused world reached engine selection/launch"
                else:
                    assert capture.exists(), "Accepted world did not reach the selected engine"
                return result

            # A new save and a pre-existing benign worldmods directory remain valid.
            fresh = group / "fresh data"
            launch(fresh, True)
            assert "gameid = golden_era_playtest" in (fresh / "worlds/playtest/world.mt").read_text()
            assert (fresh / "settings.conf").read_bytes() == (bundle / "defaults/playtest.conf").read_bytes()
            benign = group / "worldmods only"
            (benign / "worlds/playtest/worldmods/test_mod").mkdir(parents=True)
            (benign / "worlds/playtest/worldmods/test_mod/init.lua").write_bytes(b"-- preinstalled test mod\n")
            launch(benign, True)
            report.append("PASS: fresh saves and preinstalled worldmods initialize normally")


            for name, metadata, accepted in METADATA_CASES:
                folder = group / name
                world = folder / "worlds/playtest"
                world.mkdir(parents=True)
                (world / "world.mt").write_bytes(metadata.encode())
                (world / "map.sqlite").write_bytes(b"saved map database bytes\x00\xff")
                if name == "foreign with settings":
                    (folder / "settings.conf").write_bytes(b"# existing developer configuration\nviewing_range = 44\n")
                    (folder / "logs").mkdir()
                    (folder / "logs/client.log").write_bytes(b"keep existing diagnostic log\n")
                    (folder / "engine-user").mkdir()
                    (folder / "engine-user/engine-state").write_bytes(b"keep engine state\n")
                if accepted:
                    (folder / "settings.conf").write_bytes(b"# tester preferences\nviewing_range = 44\n")
                    expected = (folder / "settings.conf").read_bytes(), (world / "world.mt").read_bytes(), (world / "map.sqlite").read_bytes()
                launch(folder, accepted)
                if accepted:
                    assert expected == ((folder / "settings.conf").read_bytes(), (world / "world.mt").read_bytes(), (world / "map.sqlite").read_bytes())
            report.append("PASS: final case-sensitive game ID honored; foreign/missing/empty/conflicting IDs refuse before all writes or engine calls")
            report.append("PASS: comments/CRLF work, existing config/map/metadata bytes survive; grouped/multiline metadata including #/empty names is conservatively refused")
            if "/linux/" in template:
                folder = group / "check existing valid world"
                world = folder / "worlds/playtest"
                world.mkdir(parents=True)
                (world / "world.mt").write_bytes(b"gameid = golden_era_playtest\n")
                initial = snapshot(folder)
                local = env.copy()
                local["GOLDEN_ERA_DATA_DIR"] = str(folder)
                result = subprocess.run([str(launcher), "--check"], env=local, text=True, capture_output=True, timeout=10)
                assert result.returncode == 0, result.stderr
                assert snapshot(folder) == initial, "--check created settings, directories, or changed metadata"
                report.append("PASS: --check validates an existing world without writing settings/logs/cache")

            for name in MARKERS:
                folder = group / ("orphan " + name)
                world = folder / "worlds/playtest"
                world.mkdir(parents=True)
                if name in ("players", "map.db"):
                    (world / name).mkdir()
                    (world / name / "Tester").write_bytes(b"legacy player save")
                else:
                    (world / name).write_bytes(b"orphaned world data")
                result = launch(folder, False)
                assert "no world.mt" in result.stderr
            folder = group / "dangling orphan database"
            world = folder / "worlds/playtest"
            world.mkdir(parents=True)
            (world / "map.sqlite").symlink_to("missing-database")
            launch(folder, False)
            folder = group / "metadata directory"
            (folder / "worlds/playtest/world.mt").mkdir(parents=True)
            launch(folder, False)
            folder = group / "dangling metadata"
            world = folder / "worlds/playtest"
            world.mkdir(parents=True)
            (world / "world.mt").symlink_to("missing-metadata")
            launch(folder, False)
            report.append("PASS: all nine orphan save markers, metadata directories and dangling metadata/database links refuse without creating settings/log/cache files")
        developer_guard(work, report)
    evidence = base / "unix-save-preflight.txt"
    evidence.write_text("\n".join(report) + "\n")
    print("\n".join(report))
    print("Evidence: " + str(evidence))


if __name__ == "__main__":
    main()
