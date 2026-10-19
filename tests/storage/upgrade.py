#!/usr/bin/env python3
"""Prove one real 0.1.2 SQLite storage save continues under the exact 0.1.3 ZIP."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("storage_upgrade_package", ROOT / "packaging/playtest/packager.py")
PACKAGE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = PACKAGE
SPEC.loader.exec_module(PACKAGE)
PASS = "ERA STORAGE SMOKE PASS: "

# These additions observe the existing fixture before its first resumed deposit.
# The original archive's game Lua and all archived source files remain unchanged.
BEFORE = '''
 eq(content(a).name,"mcl_core:iron_ingot","Upgrade retained iron identity")
 eq(content(a).count,4,"Upgrade retains four saved iron before new deposits")
 eq(content(b).name,"mcl_copper:copper_ingot","Upgrade retained copper identity")
 eq(content(b).count,11,"Upgrade retains eleven saved copper before new deposits")
 eq(core.get_node(p(6)).name,"drawers:oakwood4","Upgrade retains native four-compartment drawer")
 eq(content(p(6),"1").name,"mcl_redstone:redstone","Upgrade retained four-slot redstone identity")
 eq(content(p(6),"1").count,1,"Upgrade retains saved redstone before new deposits")
 eq(core.get_node(p(24,24)).name,"drawers:controller","Old caught blast failure left its controller placed")
 local saved_tool=inv(p(24,24)):get_stack("src",1)
 eq(saved_tool:get_name(),"mcl_tools:pick_iron","Upgrade retains saved controller tool identity")
 eq(saved_tool:get_count(),1,"Upgrade retains exactly one saved controller tool")
 eq(saved_tool:get_wear(),3210,"Upgrade retains full saved tool wear")
 eq(saved_tool:get_meta():get_string("storage_smoke"),"preserve full stack","Upgrade retains full saved tool metadata")
 log("UPGRADE BEFORE DEPOSITS: retained 4 iron, 11 copper, one redstone in native four-slot drawer and one iron pick with wear=3210 and full metadata")
'''
AFTER = '''
 eq(content(p(6),"1").count,1,"Upgrade retains four-slot redstone after resumed deposits")
 eq(inv(p(24,24)):get_stack("src",1):to_string(),saved_tool:to_string(),"Resumed deposits preserve the full saved controller tool")
 log("UPGRADE COMPLETE: same closed SQLite world retains all pre-existing checked payloads; native reconnection adds only three new iron")
'''


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_archive(path, version):
    sidecar = path.with_suffix(".manifest.json")
    PACKAGE.verify_package(path, sidecar)
    digest = sha(path)
    if path.with_suffix(".zip.sha256").read_text() != digest + "  " + path.name + "\n":
        raise RuntimeError("ZIP checksum sidecar mismatch: " + path.name)
    with zipfile.ZipFile(path) as archive:
        manifest = json.loads(archive.read(PACKAGE.BUNDLE + "/" + PACKAGE.MANIFEST))
    if manifest["version"] != version:
        raise RuntimeError("Expected exact source release " + version)
    registry = json.loads((ROOT / "docs/releases" / (version + ".json")).read_text())
    if registry.get("version") != version or registry.get("frozen") is not True:
        raise RuntimeError("Expected frozen release registry for " + version)
    entry = registry["artifacts"]["game_zip"]
    registered = entry.get("artifact")
    if not isinstance(registered, str):
        raise RuntimeError("Missing frozen game ZIP path for " + version)
    registered = Path(registered)
    resolved = (ROOT / registered).resolve()
    if registered.is_absolute() or not resolved.is_relative_to(ROOT.resolve()) or resolved != path.resolve():
        raise RuntimeError("ZIP path differs from frozen release registry for " + version)
    if entry.get("size_bytes") != path.stat().st_size or entry.get("sha256") != digest:
        raise RuntimeError("ZIP size/SHA256 differs from frozen release registry for " + version)
    return {"archive": path.relative_to(ROOT).as_posix(), "sha256": digest, "bytes": path.stat().st_size,
            "files": len(manifest["files"]) + 1}


def observe_fixture(destination, game, resume):
    shutil.copytree(ROOT / "tests/storage/mod", destination)
    source = destination / "init.lua"
    text = source.read_text()
    expected = json.dumps(str(game) + "/")
    text = 'core.register_on_mods_loaded(function() local p=core.get_modpath("drawers"); assert(p:sub(1, #' + expected + ') == ' + expected + ', "Storage upgrade must load exact selected archive game") end)\n' + text
    if resume:
        before = ' local b=assert(core.deserialize(state:get_string("copper_pos")))\n'
        after = ' state:set_string("phase","complete")\n'
        if text.count(before) != 1 or text.count(after) != 1:
            raise RuntimeError("Storage observer resume anchors changed; review the upgrade assertions")
        text = text.replace(before, before + BEFORE, 1).replace(after, AFTER + after, 1)
    source.write_text(text)


def integrity(world):
    checked = []
    for path in sorted(world.glob("*.sqlite")):
        # Read-only connections verify that each engine process closed a valid DB.
        with sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) as database:
            rows = database.execute("PRAGMA integrity_check").fetchall()
            if rows != [("ok",)]:
                raise RuntimeError("Invalid closed SQLite database " + path.name + ": " + repr(rows))
        checked.append(path.name)
    if not {"map.sqlite", "mod_storage.sqlite"}.issubset(checked):
        raise RuntimeError("Missing saved node or mod-storage SQLite database")
    return checked


def main():
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    log = base / "storage-upgrade-0.1.2-to-0.1.3.log"
    report = ["Bounded exact release ZIP storage upgrade: 0.1.2 CHECKPOINT -> same closed SQLite world -> 0.1.3 COMPLETE"]
    inputs = [(ROOT / ("dist/golden-era-playtest-" + version + "-windows-test.zip"), version)
              for version in ("0.1.2", "0.1.3")]
    immutable = {path: sha(path) for archive, _ in inputs for path in
                 (archive, archive.with_suffix(".manifest.json"), archive.with_suffix(".zip.sha256"))}
    try:
        records = [verify_archive(path, version) for path, version in inputs]
        report.append(json.dumps({"inputs": records}, indent=2))
        with tempfile.TemporaryDirectory(prefix="storage-release-upgrade-", dir=base) as temporary:
            work = Path(temporary)
            games = []
            for archive, version in inputs:
                extracted = work / version
                with zipfile.ZipFile(archive) as bundle:
                    bundle.extractall(extracted)
                games.append(extracted / PACKAGE.BUNDLE / "games/golden_era_playtest")
            world = work / "same SQLite world"
            observer = world / "worldmods/era_storage_smoke"
            observer.parent.mkdir(parents=True)
            metadata = "gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n"
            (world / "world.mt").write_text(metadata)
            for index, (version, marker) in enumerate((("0.1.2", "CHECKPOINT:"), ("0.1.3", "COMPLETE:"))):
                if observer.exists():
                    shutil.rmtree(observer)
                observe_fixture(observer, games[index], resume=bool(index))
                config = work / (version + ".conf")
                config.write_text("\n".join([
                    "bind_address = 127.0.0.1", "port = 30218", "server_announce = false",
                    "mg_name = singlenode", "mcl_singlenode_mapgen = false", "creative_mode = false",
                    "enable_damage = false", "max_forceloaded_blocks = 32", "era_playtest_no_welcome = true",
                    "era_storage_baseline = " + ("true" if index == 0 else "false"),
                ]) + "\n")
                env = os.environ.copy()
                env.update(LUANTI_GAME_PATH=str(games[index].parent), LUANTI_USER_PATH=str(work / "engine-user"),
                           LD_LIBRARY_PATH=str(ROOT / "tools/root/usr/lib/x86_64-linux-gnu"))
                result = subprocess.run(
                    [str(ROOT / "upstream/luanti/bin/luantiserver"), "--gameid", "golden_era_playtest", "--world", str(world),
                     "--config", str(config), "--logfile", str(work / (version + ".log"))],
                    cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120,
                )
                report.extend(("Release phase: " + version, result.stdout))
                if result.returncode or result.stdout.count(PASS + marker) != 1 or "ERA STORAGE SMOKE FAIL" in result.stdout:
                    raise RuntimeError("Exact archive storage upgrade failed in " + version)
                diagnostics = [line for line in result.stdout.splitlines() if "WARNING[" in line or "ERROR[" in line]
                if index == 0:
                    if len(diagnostics) != 1 or 'WARNING[' not in diagnostics[0] or 'Undeclared global variable "default"' not in diagnostics[0]:
                        raise RuntimeError("Expected only the pinned old controller's missing-default warning: " + repr(diagnostics))
                elif diagnostics:
                    raise RuntimeError("Unexpected upgraded engine diagnostics: " + repr(diagnostics))
                if index == 1 and ("UPGRADE BEFORE DEPOSITS:" not in result.stdout or "UPGRADE COMPLETE:" not in result.stdout):
                    raise RuntimeError("Upgrade payload observations did not execute")
                if (world / "world.mt").read_text() != metadata:
                    raise RuntimeError("Upgrade changed world metadata")
                checked = integrity(world)
                report.append("Closed SQLite integrity PASS after " + version + ": " + ", ".join(checked))
                print(next(line for line in result.stdout.splitlines() if PASS in line), flush=True)
        for path, digest in immutable.items():
            if sha(path) != digest:
                raise RuntimeError("Release input changed: " + path.name)
        report.append("STORAGE UPGRADE PASS: exact immutable ZIPs and six archive/sidecar files; same SQLite save; retained 4 iron/11 copper/redstone/tool before new deposits, then exactly 7 iron/11 copper and unchanged other payloads")
        report.append("Scope: no lost 0.1.2 overflow is restored; no player-world migration, player-inventory, GUI or whole-game compatibility claim")
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError, PACKAGE.PackageError, sqlite3.Error) as error:
        if isinstance(error, subprocess.TimeoutExpired) and error.stdout:
            report.append(error.stdout.decode(errors="replace") if isinstance(error.stdout, bytes) else error.stdout)
        report.append("STORAGE UPGRADE FAIL: " + str(error))
        log.write_text("\n".join(report) + "\n")
        print("\n".join(report))
        print("Log: " + str(log))
        return 1
    log.write_text("\n".join(report) + "\n")
    print(report[-2])
    print("Log: " + str(log))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
