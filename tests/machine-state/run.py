#!/usr/bin/env python3
"""Compare pinned state-button bug with repaired native callbacks and restart."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA MACHINE STATE PASS: "
FAIL = "ERA MACHINE STATE FAIL: "


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    report = ["Pinned Elepower c37fe7b machine state button: native stock callbacks, normal timers, explicit subset controls and real restart.",
              "Baseline PASS confirms unreachable states, not release acceptance; repaired mode requires every native ID."]
    try:
        with tempfile.TemporaryDirectory(prefix="machine-state-", dir=base) as temporary:
            for variant in ("baseline", "repaired"):
                target = Path(temporary) / variant
                game = target / "games/golden_era_playtest"
                result = subprocess.run([sys.executable, str(ROOT / "scripts/setup-playtest.py"),
                                         "--destination", str(game), "--no-fetch"], cwd=ROOT,
                                        text=True, capture_output=True, timeout=120)
                report.append(result.stdout + result.stderr)
                if result.returncode:
                    raise RuntimeError("Assembly failed: " + variant)
                if variant == "baseline":
                    machine = game / "mods/elepower/elepower_papi/machine.lua"
                    if machine.is_symlink() or not machine.resolve().is_relative_to(game.resolve()):
                        raise RuntimeError("Refusing baseline restoration through a symlink")
                    shutil.copyfile(ROOT / "upstream/elepower/elepower_papi/machine.lua", machine)
                    report.append("BASELINE: machine.lua restored to exact pinned source; no other runtime changes")
                world = target / "world"
                (world / "worldmods").mkdir(parents=True)
                (world / "worldmods/era_machine_state").symlink_to(ROOT / "tests/machine-state/mod", target_is_directory=True)
                (world / "world.mt").write_text("gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n")
                config = target / "test.conf"
                config.write_text("\n".join(["bind_address = 127.0.0.1", "port = 30238", "server_announce = false",
                    "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                    "enable_damage = false", "max_forceloaded_blocks = 16", "era_playtest_no_welcome = true",
                    "era_state_baseline = " + str(variant == "baseline").lower()]) + "\n")
                env = os.environ.copy()
                env.update(LUANTI_GAME_PATH=str(target / "games"),
                           LD_LIBRARY_PATH=str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu"))
                for phase, marker in (("checkpoint", "CHECKPOINT:"), ("resume", "COMPLETE:")):
                    result = subprocess.run([str(ROOT / "upstream/luanti/bin/luantiserver"),
                        "--gameid", "golden_era_playtest", "--world", str(world), "--config", str(config),
                        "--logfile", str(target / (phase + ".log"))], env=env, cwd=ROOT,
                        text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=100)
                    report.extend(("Variant: " + variant + "; phase: " + phase, result.stdout))
                    if result.returncode or result.stdout.count(PASS + marker) != 1 or FAIL in result.stdout:
                        raise RuntimeError("Native state test failed: " + variant + " " + phase)
                    if "ERROR[" in result.stdout or "WARNING[" in result.stdout:
                        raise RuntimeError("Unexpected diagnostics: " + variant + " " + phase)
                    print(next(line for line in result.stdout.splitlines() if PASS in line), flush=True)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        if isinstance(error, subprocess.TimeoutExpired) and error.stdout:
            report.append(error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout)
        report.append(FAIL + str(error))
        print("\n".join(report))
        (base / "machine-state-smoke.log").write_text("\n".join(report) + "\n")
        return 1
    (base / "machine-state-smoke.log").write_text("\n".join(report) + "\n")
    print("Log: " + str(base / "machine-state-smoke.log"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
