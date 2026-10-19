#!/usr/bin/env python3
"""Compare pinned Pipeworks loss/duplication with copied-source repairs."""
import argparse
from contextlib import nullcontext
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA PIPEWORKS SMOKE PASS"
FAIL = "ERA PIPEWORKS SMOKE FAIL"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-world", action="store_true", help="Preserve the isolated fixture for investigation")
    args = parser.parse_args()
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "pipeworks-removal-smoke.log"
    report = ["Golden Era Pipeworks regression: pinned baseline versus copied repair; native mining/explosions, real dropped ItemStacks, inactive-block LBMs, both piston APIs and process restarts"]
    try:
        manager = (nullcontext(tempfile.mkdtemp(prefix="pipeworks-removal-debug-", dir=base)) if args.keep_world
                   else tempfile.TemporaryDirectory(prefix="pipeworks-removal-smoke-", dir=base))
        with manager as temporary:
            work = Path(temporary)
            if args.keep_world:
                print("Preserved fixture: " + str(work), flush=True)
            for variant in ("baseline", "repaired"):
                target = work / variant
                game = target / "games/golden_era_playtest"
                result = subprocess.run(
                    [sys.executable, str(ROOT / "scripts/setup-playtest.py"), "--destination", str(game), "--no-fetch"],
                    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
                )
                report.append(result.stdout)
                if result.returncode:
                    raise RuntimeError("Pipeworks game assembly failed for " + variant)
                if variant == "baseline":
                    # The reviewed assembler copies this mod, so the baseline
                    # restoration cannot write through a symlink into upstream.
                    copied = game / "mods/pipeworks"
                    if copied.is_symlink():
                        raise RuntimeError("Refusing baseline restoration into symlinked Pipeworks")
                    for relative in ("autocrafter.lua", "filter-injector.lua"):
                        shutil.copyfile(ROOT / "upstream/pipeworks" / relative, copied / relative)
                    report.append("BASELINE: only Pipeworks restored to exact pinned 5dfd572 sources; known loss/duplication contracts are asserted safely")
                world = target / "world"
                (world / "worldmods").mkdir(parents=True)
                (world / "worldmods/era_pipeworks_smoke").symlink_to(ROOT / "tests/pipeworks-removal/mod", target_is_directory=True)
                (world / "world.mt").write_text(
                    "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                    "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
                )
                config = target / "test.conf"
                config.write_text("\n".join([
                    "bind_address = 127.0.0.1", "port = 30220", "server_announce = false",
                    "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                    "enable_damage = false", "max_forceloaded_blocks = 32", "era_playtest_no_welcome = true",
                    "era_pipeworks_baseline = " + ("true" if variant == "baseline" else "false"),
                ]) + "\n")
                env = os.environ.copy()
                env["LUANTI_GAME_PATH"] = str(target / "games")
                env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
                for phase, marker in (("checkpoint", "CHECKPOINT:"), ("resume", "COMPLETE:")):
                    result = subprocess.run(
                        [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest",
                         "--world", str(world), "--config", str(config), "--logfile", str(target / (phase + ".log"))],
                        env=env, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=100,
                    )
                    report.append("Variant: " + variant + "; phase: " + phase)
                    report.append(result.stdout)
                    if result.returncode or PASS + ": " + marker not in result.stdout or FAIL in result.stdout:
                        raise RuntimeError("Native pipeworks-removal failed in " + variant + " " + phase)
                    diagnostics = [line for line in result.stdout.splitlines() if "ERROR[" in line or "WARNING[" in line]
                    if diagnostics:
                        raise RuntimeError("Unexpected diagnostics in " + variant + " " + phase + ": " + repr(diagnostics))
                    print(next(line for line in result.stdout.splitlines() if PASS in line), flush=True)
                    report.append(variant + " " + phase + ": process exited successfully")
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
