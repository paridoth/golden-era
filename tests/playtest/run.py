#!/usr/bin/env python3
"""Run the existing-mod playtest pack in a disposable headless world."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA PLAYTEST SMOKE PASS"
FAIL = "ERA PLAYTEST SMOKE FAIL"


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "playtest-smoke.log"
    report = ["Golden Era existing-mod pack smoke; stock power ABMs, node timers and Pipeworks routing"]
    try:
        with tempfile.TemporaryDirectory(prefix="playtest-smoke-", dir=base) as temporary:
            work = Path(temporary)
            game = work / "games/golden_era_playtest"
            assembled = subprocess.run(
                [sys.executable, str(ROOT / "scripts/setup-playtest.py"),
                 "--destination", str(game), "--no-fetch"],
                cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=120,
            )
            report.append(assembled.stdout)
            if assembled.returncode:
                raise RuntimeError("Playtest assembly failed")
            world = work / "world"
            (world / "worldmods").mkdir(parents=True)
            (world / "worldmods/era_playtest_smoke").symlink_to(ROOT / "tests/playtest/mod", target_is_directory=True)
            (world / "world.mt").write_text(
                "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
            )
            config = work / "test.conf"
            config.write_text("\n".join([
                "bind_address = 127.0.0.1", "port = 30202", "server_announce = false",
                "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                "max_forceloaded_blocks = 32", "era_playtest_no_welcome = true",
            ]) + "\n")
            env = os.environ.copy()
            env["LUANTI_GAME_PATH"] = str(work / "games")
            env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
            result = subprocess.run(
                [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest",
                 "--world", str(world), "--config", str(config), "--logfile", str(work / "server.log")],
                env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=180,
            )
            report.append(result.stdout)
            if result.returncode or PASS not in result.stdout or FAIL in result.stdout:
                raise RuntimeError("Server failed or did not complete the stock industrial flow")
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
