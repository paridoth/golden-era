#!/usr/bin/env python3
"""Boot the playtest pack with candidate mods in a disposable v7 world and report."""
import collections
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
TAG = "ERA MOD TRIAL: "


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mod-trial-", dir=base) as temporary:
        work = Path(temporary)
        game = work / "games/golden_era_playtest"
        subprocess.run(
            [sys.executable, str(ROOT / "scripts/setup-playtest.py"), "--destination", str(game), "--no-fetch"],
            cwd=ROOT, check=True, stdout=subprocess.DEVNULL, timeout=120,
        )
        world = work / "world"
        (world / "worldmods").mkdir(parents=True)
        (world / "worldmods/era_mod_trial").symlink_to(ROOT / "tests/mod-trial/mod", target_is_directory=True)
        (world / "world.mt").write_text(
            "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
            "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
        )
        config = work / "test.conf"
        config.write_text("\n".join([
            "bind_address = 127.0.0.1", "port = 30203", "server_announce = false",
            "mg_name = v7", "fixed_map_seed = 42", "era_playtest_no_welcome = true",
        ]) + "\n")
        env = os.environ.copy()
        env["LUANTI_GAME_PATH"] = str(work / "games")
        env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
        log = work / "server.log"
        result = subprocess.run(
            [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest",
             "--world", str(world), "--config", str(config), "--logfile", str(log)],
            env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=900,
        )
        text = log.read_text(errors="replace") if log.exists() else result.stdout
        (base / "mod-trial.log").write_text(text)
    report = [line.split(TAG, 1)[1] for line in text.splitlines() if TAG in line]
    problems = collections.Counter()
    for line in text.splitlines():
        match = re.search(r"(WARNING|ERROR)\[[^\]]*\]: (.*)", line)
        if match:
            problems[match.group(1) + ": " + re.sub(r"\d+", "N", match.group(2))[:200]] += 1
    print("\n".join(report))
    print("--- warnings/errors (grouped) ---")
    for message, count in problems.most_common(40):
        print(f"{count:5d}  {message}")
    print("exit", result.returncode, "| full log: runtime/tests/mod-trial.log")
    return 0 if result.returncode == 0 and "COMPLETE" in report else 1


if __name__ == "__main__":
    raise SystemExit(main())
