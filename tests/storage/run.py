#!/usr/bin/env python3
"""Compare pinned native storage failures with copied-source conservation repairs."""
import argparse
from contextlib import nullcontext
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PASS = "ERA STORAGE SMOKE PASS"
FAIL = "ERA STORAGE SMOKE FAIL"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep-world", action="store_true", help="Preserve the isolated fixture for investigation")
    args = parser.parse_args()
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "storage-smoke.log"
    report = ["Golden Era storage regression: pinned baseline vs copied repairs; native callbacks, world item entities, real Mineclonia explosions and process restarts"]
    try:
        manager = (nullcontext(tempfile.mkdtemp(prefix="storage-debug-", dir=base)) if args.keep_world
                   else tempfile.TemporaryDirectory(prefix="storage-smoke-", dir=base))
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
                    raise RuntimeError("Storage game assembly failed for " + variant)
                if variant == "baseline":
                    # The reviewed assembler copies this mod, so the baseline
                    # restoration cannot write through a symlink into upstream.
                    copied = game / "mods/drawers"
                    if copied.is_symlink():
                        raise RuntimeError("Refusing baseline restoration into symlinked Drawers")
                    for relative in ("lua/api.lua", "lua/controller.lua", "lua/visual.lua"):
                        shutil.copyfile(ROOT / "upstream/drawers" / relative, copied / relative)
                    report.append("BASELINE: only Drawers restored to exact pinned 5c8aa86 sources; known losses/crash are asserted and caught safely")
                world = target / "world"
                (world / "worldmods").mkdir(parents=True)
                (world / "worldmods/era_storage_smoke").symlink_to(ROOT / "tests/storage/mod", target_is_directory=True)
                (world / "world.mt").write_text(
                    "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\n"
                    "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
                )
                config = target / "test.conf"
                config.write_text("\n".join([
                    "bind_address = 127.0.0.1", "port = 30214", "server_announce = false",
                    "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                    "enable_damage = false", "max_forceloaded_blocks = 32", "era_playtest_no_welcome = true",
                    "era_storage_baseline = " + ("true" if variant == "baseline" else "false"),
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
                        raise RuntimeError("Native storage failed in " + variant + " " + phase)
                    diagnostics = [line for line in result.stdout.splitlines() if "ERROR[" in line or "WARNING[" in line]
                    expected = variant == "baseline" and phase == "checkpoint"
                    if expected:
                        if len(diagnostics) != 1 or 'Undeclared global variable "default"' not in diagnostics[0]:
                            raise RuntimeError("Unexpected baseline diagnostics: " + repr(diagnostics))
                    elif diagnostics:
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
