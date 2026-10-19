#!/usr/bin/env python3
"""Compare pinned Elepower removal losses with checked source-copy repairs."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA MACHINE REMOVAL PASS"
FAIL = "ERA MACHINE REMOVAL FAIL"


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "machine-removal-smoke.log"
    report = ["Elepower c37fe7b / Mineclonia 20d5bbc native mining and explosions; baseline vs copied repair"]
    try:
        with tempfile.TemporaryDirectory(prefix="machine-removal-", dir=base) as temporary:
            work = Path(temporary)
            for variant in ("baseline", "repaired"):
                target = work / variant
                game = target / "games/golden_era_playtest"
                assembled = subprocess.run(
                    [sys.executable, str(ROOT / "scripts/setup-playtest.py"), "--destination", str(game), "--no-fetch"],
                    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
                )
                report.append(assembled.stdout)
                if assembled.returncode:
                    raise RuntimeError("Machine removal assembly failed for " + variant)
                if variant == "baseline":
                    copied_mod = game / "mods/elepower"
                    files = ("elepower_papi/machine.lua", "elepower_tools/soldering.lua")
                    copied_files = [copied_mod / relative for relative in files]
                    if copied_mod.is_symlink() or any(path.is_symlink() or not path.resolve().is_relative_to(game.resolve())
                                                       for path in copied_files):
                        raise RuntimeError("Refusing to restore baseline through a symlink")
                    for relative, copied in zip(files, copied_files):
                        shutil.copyfile(ROOT / "upstream/elepower" / relative, copied)
                    report.append("BASELINE: machine.lua and soldering.lua restored to exact pinned Elepower sources")
                world = target / "world"
                (world / "worldmods").mkdir(parents=True)
                (world / "worldmods/era_machine_removal").symlink_to(ROOT / "tests/machine-removal/mod", target_is_directory=True)
                (world / "world.mt").write_text(
                    "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                    "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
                )
                config = target / "test.conf"
                config.write_text("\n".join([
                    "bind_address = 127.0.0.1", "port = 30218", "server_announce = false",
                    "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                    "era_playtest_no_welcome = true", "enable_damage = false",
                    "era_removal_baseline = " + ("true" if variant == "baseline" else "false"),
                ]) + "\n")
                env = os.environ.copy()
                env["LUANTI_GAME_PATH"] = str(target / "games")
                env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
                result = subprocess.run(
                    [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest", "--world", str(world),
                     "--config", str(config), "--logfile", str(target / "server.log")],
                    env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=100,
                )
                report.extend(("Variant: " + variant, result.stdout))
                if result.returncode or PASS not in result.stdout or FAIL in result.stdout:
                    raise RuntimeError("Native machine removal failed for " + variant)
                if any(message in result.stdout for message in ("ERROR[", "WARNING[")):
                    raise RuntimeError("Unexpected engine diagnostics for " + variant)
                print(next(line for line in result.stdout.splitlines() if PASS in line), flush=True)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.TimeoutExpired) and error.stdout:
            report.append(error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout)
        report.append(FAIL + ": " + str(error))
        log.write_text("\n".join(report) + "\n")
        print("\n".join(report))
        print("Log: " + str(log))
        return 1
    log.write_text("\n".join(report) + "\n")
    print("Log: " + str(log))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
