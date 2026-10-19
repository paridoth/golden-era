#!/usr/bin/env python3
"""Verify Linux archive, launch isolation, upgrades, and the full stock factory."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import tomllib

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("linux_release_verify", ROOT / "packaging/linux/packager.py")
packager = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = packager
spec.loader.exec_module(packager)


def mock_engine(path, version="5.17.0"):
    path.write_text("#!/usr/bin/python3\nimport json,os,sys\n"
                    "if '--version' in sys.argv:\n print('Luanti " + version + " (test stub)');sys.exit(0)\n"
                    "open(os.environ['GE_CAPTURE'],'w').write(json.dumps({'args':sys.argv[1:],'game':os.environ.get('LUANTI_GAME_PATH'),'user':os.environ.get('LUANTI_USER_PATH')}))\n")
    path.chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--engine", type=Path, default=ROOT / "upstream/luanti/bin/luanti")
    parser.add_argument("--flatpak-runtime", action="store_true", help="Run official engine in repo-isolated Flatpak runtime")
    parser.add_argument("--launcher-only", action="store_true", help="Skip the 114-second real factory simulation")
    parser.add_argument("--storage-smoke", action="store_true", help="Also run repaired native storage callbacks and restart against the extracted game")
    parser.add_argument("--removal-smoke", action="store_true", help="Also check machine mining/blast inventory preservation against the extracted game")
    args = parser.parse_args()
    if (args.storage_smoke or args.removal_smoke) and args.launcher_only:
        parser.error("--storage-smoke/--removal-smoke require the real engine; omit --launcher-only")
    checked = packager.verify_package(args.archive)
    report = ["Golden Era Linux archive validation", "SHA256: " + checked["sha256"], "Files: " + str(checked["files"])]
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="linux tester with spaces ", dir=base) as temporary:
        work = Path(temporary)
        with tarfile.open(args.archive) as archive:
            archive.extractall(work, filter="data")
        bundle = work / packager.BUNDLE
        launcher = bundle / "start.sh"
        assert launcher.stat().st_mode & 0o111
        assert not any(path.is_symlink() for path in bundle.rglob("*"))
        assert not (bundle / "start.bat").exists()
        action = tomllib.loads((bundle / ".itch.toml").read_text())["actions"][0]
        assert action["path"] == "start.sh" and (bundle / action["path"]).is_file()
        subprocess.run(["sh", "-n", str(launcher)], check=True)
        if shutil.which("desktop-file-validate"):
            subprocess.run(["desktop-file-validate", str(bundle / "Play Golden Era.desktop")], check=True)
        capture = work / "launch.json"
        data = work / "new tester data"
        engine = work / "engine with spaces"
        mock_engine(engine)
        env = os.environ.copy()
        env.update(GOLDEN_ERA_DATA_DIR=str(data), GOLDEN_ERA_ENGINE=str(engine), GE_CAPTURE=str(capture), DISPLAY="", WAYLAND_DISPLAY="")
        subprocess.run([str(launcher), "--check"], env=env, check=True, capture_output=True)
        assert not data.exists(), "--check must not create a save"
        subprocess.run([str(launcher), "--server"], env=env, check=True, capture_output=True)
        record = json.loads(capture.read_text())
        assert record["game"] == str(bundle / "games")
        assert record["user"] == str(data / "engine-user")
        assert record["args"][-1] == "--server"
        settings = data / "settings.conf"
        world = data / "worlds/playtest/world.mt"
        settings.write_text(settings.read_text() + "\n# Tester preference\nviewing_range = 44\n")
        world.write_text(world.read_text() + "\n# Existing world\n")
        preserved = settings.read_bytes(), world.read_bytes()
        subprocess.run([str(launcher)], env=env, check=True, capture_output=True)
        assert (settings.read_bytes(), world.read_bytes()) == preserved, "Relaunch must preserve saves/settings"
        try:
            from gi.repository import Gio
        except ImportError:
            report.append("Desktop-file syntax checked; Gio dispatch unavailable on this host")
        else:
            capture.unlink()
            desktop = Gio.DesktopAppInfo.new_from_filename(str(bundle / "Play Golden Era.desktop"))
            context = Gio.AppLaunchContext()
            for key, value in env.items():
                context.setenv(key, value)
            assert desktop.launch([], context)
            for _ in range(100):
                if capture.exists():
                    break
                time.sleep(0.02)
            assert json.loads(capture.read_text())["game"] == str(bundle / "games")
            report.append("PASS: actual Gio desktop launcher dispatch from a folder containing spaces")
        mock_engine(engine, "5.16.0")
        old = subprocess.run([str(launcher), "--check"], env=env, capture_output=True, text=True)
        assert old.returncode != 0 and "too old" in old.stderr
        mock_engine(engine)
        world.write_text("gameid = a_different_game\n")
        wrong = subprocess.run([str(launcher)], env=env, capture_output=True, text=True)
        assert wrong.returncode != 0 and "another game" in wrong.stderr
        assert world.read_text() == "gameid = a_different_game\n"
        world.write_bytes(preserved[1])
        report.append("PASS: path quoting, engine version checks, first save, settings preservation, and wrong-game refusal")

        mocks = work / "mock bin"
        mocks.mkdir()
        mock_engine(mocks / "luanti", "5.16.0")
        mock_engine(mocks / "minetest", "5.16.0")
        flatpak = mocks / "flatpak"
        flatpak.write_text("#!/usr/bin/python3\nimport json,os,sys\n"
                           "a=sys.argv[1:]\n"
                           "if a[0]=='info':sys.exit(0)\n"
                           "if a[-1]=='--version':print('Luanti 5.17.0 (Flatpak test stub)');sys.exit(0)\n"
                           "open(os.environ['GE_CAPTURE'],'w').write(json.dumps(a))\n")
        flatpak.chmod(0o755)
        flat_env = env.copy()
        flat_env.pop("GOLDEN_ERA_ENGINE")
        flat_env["PATH"] = str(mocks) + os.pathsep + env["PATH"]
        subprocess.run([str(launcher), "--server"], env=flat_env, check=True, capture_output=True)
        recorded = json.loads(capture.read_text())
        assert "org.luanti.luanti" in recorded
        assert "--filesystem=" + str(bundle) + ":ro" in recorded
        assert "--filesystem=" + str(data) in recorded
        assert "--env=LUANTI_GAME_PATH=" + str(bundle / "games") in recorded
        assert "--env=LUANTI_USER_PATH=" + str(data / "engine-user") in recorded
        assert "--filesystem=home" not in recorded and "--filesystem=host" not in recorded
        report.append("PASS: Flatpak backend selects current app ID and grants only game read/save write paths (stub transport)")

        if not args.launcher_only:
            actual_data = work / "real factory save"
            mods = actual_data / "worlds/playtest/worldmods"
            mods.mkdir(parents=True)
            shutil.copytree(ROOT / "tests/playtest/mod", mods / "era_playtest_smoke")
            smoke = mods / "era_playtest_smoke/init.lua"
            expected = json.dumps(str(bundle / "games/golden_era_playtest") + "/")
            smoke.write_text('core.register_on_mods_loaded(function() local p=core.get_modpath("mcl_core"); assert(p:sub(1, #'
                             + expected + ') == ' + expected + ', "Game must load from extracted Linux archive") end)\n' + smoke.read_text())
            (actual_data / "settings.conf").write_text((bundle / "defaults/playtest.conf").read_text() +
                "\nport = 30216\nmg_name = singlenode\nera_playtest_no_welcome = true\nmax_forceloaded_blocks = 32\n")
            real_env = env.copy()
            real_env["GOLDEN_ERA_DATA_DIR"] = str(actual_data)
            if args.flatpak_runtime:
                # Standard app runs create ~/.var/app even when XDG is overridden.
                # Run its exact official binary inside its runtime without an app ID,
                # keeping all test writes inside the repository as AGENTS requires.
                fp = base / "linux-flatpak"
                real_env.update(FLATPAK_USER_DIR=str(fp / "installation"), XDG_CACHE_HOME=str(fp / "cache"),
                                XDG_DATA_HOME=str(fp / "data"), XDG_CONFIG_HOME=str(fp / "config"))
                location = subprocess.check_output(["flatpak", "info", "--user", "--show-location", "org.luanti.luanti"], env=real_env, text=True).strip()
                app = Path(location) / "files"
                shim = work / "official Flatpak engine"
                arguments = ["flatpak", "run", "--app-path=" + str(app), "--command=/app/bin/luanti.bin",
                             "--filesystem=" + str(bundle) + ":ro", "--filesystem=" + str(actual_data),
                             "--env=LUANTI_GAME_PATH=" + str(bundle / "games"),
                             "--env=LUANTI_USER_PATH=" + str(actual_data / "engine-user"),
                             "--env=XDG_CACHE_HOME=" + str(actual_data / "engine-cache"), "org.freedesktop.Platform//26.08"]
                import shlex
                shim.write_text("#!/bin/sh\nexec " + " ".join(shlex.quote(value) for value in arguments) + ' "$@"\n')
                shim.chmod(0o755)
                real_env["GOLDEN_ERA_ENGINE"] = str(shim)
                report.append("Actual engine: official Flathub application binary inside Freedesktop 26.08 runtime; ordinary app-data/portal launch not tested")
            else:
                real_env["GOLDEN_ERA_ENGINE"] = str(args.engine.resolve())
                real_env["LD_LIBRARY_PATH"] = str(ROOT / "tools/client-root/usr/lib/x86_64-linux-gnu") + ":" + str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
            result = subprocess.run([str(launcher), "--server"], env=real_env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=190)
            report.append(result.stdout)
            (base / "linux-package-smoke.txt").write_text("\n".join(report) + "\n")
            if result.returncode or "ERA PLAYTEST SMOKE PASS" not in result.stdout:
                print(result.stdout, file=sys.stderr)
            assert result.returncode == 0, "Linux launcher/engine failed"
            assert "ERA PLAYTEST SMOKE PASS" in result.stdout
            assert "ERA PLAYTEST SMOKE FAIL" not in result.stdout
            assert not any(message in result.stdout for message in ("ERROR[", "WARNING["))
            report.append("PASS: complete real 2 raw iron -> 4 ingots stock factory via Linux launcher, with extracted game and fresh external save")
            if args.storage_smoke:
                # Nest the independent save within the existing narrow Flatpak
                # data grant. Keep the factory world and its observer separate.
                storage_data = actual_data / "storage-regression"
                storage_world = storage_data / "worlds/playtest"
                observer = storage_world / "worldmods/era_storage_smoke"
                shutil.copytree(ROOT / "tests/storage/mod", observer)
                storage_source = observer / "init.lua"
                storage_source.write_text('core.register_on_mods_loaded(function() local p=core.get_modpath("drawers"); assert(p:sub(1, #'
                    + expected + ') == ' + expected + ', "Drawers must load from extracted Linux archive") end)\n' + storage_source.read_text())
                (storage_data / "settings.conf").write_text((bundle / "defaults/playtest.conf").read_text() +
                    "\nport = 30216\nmg_name = singlenode\nmcl_singlenode_mapgen = false\n"
                    "era_playtest_no_welcome = true\nmax_forceloaded_blocks = 32\nera_storage_baseline = false\n")
                storage_env = real_env.copy()
                storage_env["GOLDEN_ERA_DATA_DIR"] = str(storage_data)
                for phase, marker in (("checkpoint", "CHECKPOINT:"), ("resume", "COMPLETE:")):
                    result = subprocess.run([str(launcher), "--server"], env=storage_env, text=True,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
                    report.append("Storage phase: " + phase)
                    report.append(result.stdout)
                    (base / "linux-package-smoke.txt").write_text("\n".join(report) + "\n")
                    if result.returncode or "ERA STORAGE SMOKE PASS: " + marker not in result.stdout:
                        print(result.stdout, file=sys.stderr)
                    assert result.returncode == 0, "Linux storage engine failed"
                    assert "ERA STORAGE SMOKE PASS: " + marker in result.stdout, "Missing storage checkpoint"
                    assert "ERA STORAGE SMOKE FAIL" not in result.stdout
                    assert not any(message in result.stdout for message in ("ERROR[", "WARNING["))
                report.append("PASS: extracted Linux game storage conservation, real blasts, controller cache changes and process restart through its launcher")
            if args.removal_smoke:
                removal_data = actual_data / "machine-removal-regression"
                observer = removal_data / "worlds/playtest/worldmods/era_machine_removal"
                shutil.copytree(ROOT / "tests/machine-removal/mod", observer)
                removal_source = observer / "init.lua"
                removal_source.write_text('core.register_on_mods_loaded(function() local p=core.get_modpath("elepower_papi"); assert(p:sub(1, #'
                    + expected + ') == ' + expected + ', "Elepower must load from extracted Linux archive") end)\n' + removal_source.read_text())
                (removal_data / "settings.conf").write_text((bundle / "defaults/playtest.conf").read_text() +
                    "\nport = 30216\nmg_name = singlenode\nmcl_singlenode_mapgen = false\n"
                    "era_playtest_no_welcome = true\nmax_forceloaded_blocks = 32\nera_removal_baseline = false\n")
                removal_env = real_env.copy()
                removal_env["GOLDEN_ERA_DATA_DIR"] = str(removal_data)
                result = subprocess.run([str(launcher), "--server"], env=removal_env, text=True,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
                report.append("Machine removal regression")
                report.append(result.stdout)
                (base / "linux-package-smoke.txt").write_text("\n".join(report) + "\n")
                if result.returncode or "ERA MACHINE REMOVAL PASS:" not in result.stdout:
                    print(result.stdout, file=sys.stderr)
                assert result.returncode == 0, "Linux machine removal engine failed"
                assert result.stdout.count("ERA MACHINE REMOVAL PASS:") == 1, "Missing/duplicate machine removal completion"
                assert "ERA MACHINE REMOVAL FAIL" not in result.stdout
                assert not any(message in result.stdout for message in ("ERROR[", "WARNING["))
                report.append("PASS: extracted Linux game protects occupied machine slots and preserves native blast items without scratch/ghost duplicates")
    evidence = base / "linux-package-smoke.txt"
    evidence.write_text("\n".join(report) + "\n")
    print("\n".join(report))
    print("Evidence: " + str(evidence))


if __name__ == "__main__":
    main()
