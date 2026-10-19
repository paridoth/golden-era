#!/usr/bin/env python3
"""Run clocked native Pipeworks delivery/backpressure through drawer controllers."""
import argparse
from contextlib import nullcontext
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA CONTROLLER SMOKE PASS"
FAIL = "ERA CONTROLLER SMOKE FAIL"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-world", action="store_true", help="Keep the isolated controller fixture for investigation")
    args = parser.parse_args()
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "storage-controller-smoke.log"
    report = ["Golden Era controller automation smoke: native clock timers, injectors, moving tube payloads, distribution, full capacity, in-flight restart"]
    try:
        manager = (nullcontext(tempfile.mkdtemp(prefix="controller-debug-", dir=base)) if args.keep_world
                   else tempfile.TemporaryDirectory(prefix="controller-smoke-", dir=base))
        with manager as temporary:
            work = Path(temporary)
            if args.keep_world:
                print("Preserved fixture: " + str(work), flush=True)
            game = work / "games/golden_era_playtest"
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts/setup-playtest.py"), "--destination", str(game), "--no-fetch"],
                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
            )
            report.append(result.stdout)
            if result.returncode:
                raise RuntimeError("Controller fixture assembly failed")
            world = work / "world"
            (world / "worldmods").mkdir(parents=True)
            (world / "worldmods/era_controller_smoke").symlink_to(ROOT / "tests/storage-controller/mod", target_is_directory=True)
            (world / "world.mt").write_text(
                "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
            )
            config = work / "test.conf"
            config.write_text("\n".join([
                "bind_address = 127.0.0.1", "port = 30219", "server_announce = false",
                "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                "enable_damage = false", "max_forceloaded_blocks = 32", "era_playtest_no_welcome = true",
            ]) + "\n")
            env = os.environ.copy()
            env["LUANTI_GAME_PATH"] = str(work / "games")
            env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
            for phase, marker in (("checkpoint", "CHECKPOINT:"), ("resume", "COMPLETE:")):
                result = subprocess.run(
                    [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest",
                     "--world", str(world), "--config", str(config), "--logfile", str(work / (phase + ".log"))],
                    env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=130,
                )
                report.append("Phase: " + phase)
                report.append(result.stdout)
                if result.returncode or PASS + ": " + marker not in result.stdout or FAIL in result.stdout:
                    raise RuntimeError("Native controller automation failed in " + phase)
                if "ERROR[" in result.stdout or "WARNING[" in result.stdout:
                    raise RuntimeError("Unexpected diagnostics in " + phase)
                report.append(phase + ": process exited successfully")
                print(next(line for line in result.stdout.splitlines() if PASS in line), flush=True)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.TimeoutExpired) and error.stdout:
            output = error.stdout
            report.append(output.decode(errors="replace") if isinstance(output, bytes) else output)
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
