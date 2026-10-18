#!/usr/bin/env python3
"""Probe pinned Pipeworks in an isolated Golden Era game and temporary world."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCES = ("luanti", "mineclonia", "pipeworks", "basic_materials", "fakelib", "xcompat")
ALIAS_BEFORE = 'local game_alias = {\n    mineclone2 = "mineclonia",\n}\n'
ALIAS_AFTER = 'local game_alias = {\n    mineclone2 = "mineclonia",\n    golden_era = "mineclonia",\n}\n'
PASS = "ERA REUSE PROBE PASS"
FAIL = "ERA REUSE PROBE FAIL"


class ProbeError(Exception):
    pass


def git_output(source, *args):
    return subprocess.check_output(
        ["git", "-C", str(source), *args], text=True, stderr=subprocess.STDOUT
    ).strip()


def verify_sources(report):
    """Refuse edited or mismatched references, including untracked source files."""
    locked = json.loads((ROOT / "upstream.lock.json").read_text())
    for name in SOURCES:
        spec = locked.get(name)
        if not spec:
            raise ProbeError("Missing source pin: " + name)
        source = ROOT / "upstream" / name
        if not source.is_dir() or not (source / ".git").exists():
            raise ProbeError("Missing local Git checkout (no fetch attempted): " + name)
        if pathlib.Path(git_output(source, "rev-parse", "--show-toplevel")).resolve() != source.resolve():
            raise ProbeError("Unexpected Git checkout root: " + name)
        if git_output(source, "rev-parse", "HEAD") != spec["commit"]:
            raise ProbeError("Source revision mismatch: " + name)
        if git_output(source, "status", "--porcelain", "--untracked-files=all"):
            raise ProbeError("Dirty upstream checkout: " + name)
        report.append("SOURCE " + name + " " + spec["commit"] + " clean")


def assemble_game(work, report):
    game = work / "games/golden_era"
    mods = game / "mods"
    mods.mkdir(parents=True)
    for source in (ROOT / "upstream/mineclonia/mods").iterdir():
        (mods / source.name).symlink_to(source, target_is_directory=source.is_dir())
    for source in (ROOT / "mods").iterdir():
        target = mods / source.name
        if target.exists():
            raise ProbeError("Duplicate assembled mod name: " + source.name)
        target.symlink_to(source, target_is_directory=source.is_dir())
    for name in ("pipeworks", "basic_materials", "fakelib"):
        (mods / name).symlink_to(ROOT / "upstream" / name, target_is_directory=True)
    # Only this disposable copy is patched. Never edit the pinned upstream tree.
    xcompat = mods / "xcompat"
    shutil.copytree(ROOT / "upstream/xcompat", xcompat, ignore=shutil.ignore_patterns(".git"))
    alias_file = xcompat / "src/gameid.lua"
    original = alias_file.read_text()
    if original.count(ALIAS_BEFORE) != 1:
        raise ProbeError("Pinned xcompat alias source changed; review the temporary patch")
    alias_file.write_text(original.replace(ALIAS_BEFORE, ALIAS_AFTER, 1))
    report.append('TEMPORARY PATCH xcompat/src/gameid.lua: golden_era = "mineclonia"')
    report.append("PATCH SCOPE temporary game copy only; upstream and normal runtime game untouched")
    # Mineclonia's settings and game load-order declarations remain the baseline.
    for name in ("game.conf", "minetest.conf", "settingtypes.txt", "LICENSE.txt", "LEGAL.md", "CREDITS.md", "README.md"):
        shutil.copy2(ROOT / "upstream/mineclonia" / name, game / name)
    return game


def run_probe(report):
    verify_sources(report)
    server = ROOT / "upstream/luanti/bin/luantiserver"
    if not server.is_file():
        raise ProbeError("Missing local server binary; run the normal project setup first")
    if not (ROOT / "tests/reuse/mod/mod.conf").is_file():
        raise ProbeError("Missing era_reuse_probe test mod")
    base = ROOT / "runtime/tests"
    with tempfile.TemporaryDirectory(prefix="reuse-probe-", dir=base) as temporary:
        work = pathlib.Path(temporary)
        assemble_game(work, report)
        world = work / "world"
        (world / "worldmods").mkdir(parents=True)
        (world / "worldmods/era_reuse_probe").symlink_to(
            ROOT / "tests/reuse/mod", target_is_directory=True
        )
        (world / "world.mt").write_text(
            "gameid = golden_era\nbackend = sqlite3\nplayer_backend = sqlite3\n"
            "auth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
        )
        config = work / "test.conf"
        config.write_text("\n".join([
            "bind_address = 127.0.0.1", "port = 30201", "server_announce = false",
            "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
            "era_test_manual = true",
        ]) + "\n")
        env = os.environ.copy()
        env["LUANTI_GAME_PATH"] = str(work / "games")
        env["LD_LIBRARY_PATH"] = str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu")
        command = [str(server), "--gameid", "golden_era", "--world", str(world),
                   "--config", str(config), "--logfile", str(work / "server.log")]
        report.append("CONFIG temporary golden_era game/world; loopback 30201; manual era simulation; 120s timeout")
        try:
            result = subprocess.run(command, env=env, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or ""
            if isinstance(output, bytes):
                output = output.decode(errors="replace")
            report.append(output)
            raise ProbeError("Server exceeded 120-second timeout") from error
        report.append(result.stdout)
        if result.returncode or PASS not in result.stdout or FAIL in result.stdout:
            raise ProbeError("Server failed or did not report the success marker")
        return next(line for line in result.stdout.splitlines() if PASS in line)


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    logfile = base / "reuse-probe.log"
    report = ["Golden Era isolated pinned Pipeworks reuse probe"]
    try:
        success = run_probe(report)
    except (ProbeError, OSError, subprocess.CalledProcessError, ValueError) as error:
        report.append(FAIL + ": " + str(error))
        logfile.write_text("\n".join(report) + "\n")
        print("\n".join(report))
        print("Log: " + str(logfile))
        return 1
    logfile.write_text("\n".join(report) + "\n")
    print(success)
    print('Temporary xcompat alias applied: golden_era = "mineclonia"')
    print("Log: " + str(logfile))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
