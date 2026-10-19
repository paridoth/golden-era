#!/usr/bin/env python3
"""Exercise stock pre-electric materials with ore from a fresh v7 world."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA SURVIVAL SMOKE PASS"
FAIL = "ERA SURVIVAL SMOKE FAIL"


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "survival-smoke.log"
    report = ["Golden Era v7 material acquisition smoke: detached survival actor at iron-pick checkpoint; provided stock device fixtures; real node timers"]
    try:
        with tempfile.TemporaryDirectory(prefix="survival-smoke-", dir=base) as temporary:
            work = Path(temporary)
            game = work / "games/golden_era_playtest"
            assembled = subprocess.run(
                [sys.executable, str(ROOT / "scripts/setup-playtest.py"), "--destination", str(game), "--no-fetch"],
                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
            )
            report.append(assembled.stdout)
            if assembled.returncode:
                raise RuntimeError("Playtest assembly failed")
            world = work / "world"
            (world / "worldmods").mkdir(parents=True)
            (world / "worldmods/era_survival_smoke").symlink_to(ROOT / "tests/survival/mod", target_is_directory=True)
            (world / "world.mt").write_text(
                "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
            )
            config = work / "test.conf"
            config.write_text("\n".join([
                "bind_address = 127.0.0.1", "port = 30208", "server_announce = false",
                "mg_name = v7", "fixed_map_seed = 8675309", "creative_mode = false",
                "enable_damage = false", "mobs_spawn = false", "max_forceloaded_blocks = 32",
                "era_playtest_no_welcome = true",
            ]) + "\n")
            env = os.environ.copy()
            env["LUANTI_GAME_PATH"] = str(work / "games")
            env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
            result = subprocess.run(
                [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest",
                 "--world", str(world), "--config", str(config), "--logfile", str(work / "server.log")],
                env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240,
            )
            report.append(result.stdout)
            if result.returncode or PASS not in result.stdout or FAIL in result.stdout:
                raise RuntimeError("Server failed or did not complete survival material processing")
            success = next(line for line in result.stdout.splitlines() if PASS in line)
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
    print(success)
    print("Log: " + str(log))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
