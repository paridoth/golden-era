#!/usr/bin/env python3
"""Exercise the exact Windows bootstrap PowerShell command using real .NET filesystem operations.

Runs the checked-in command unmodified under pinned PowerShell 7 on Linux.
This does not execute cmd.exe or establish native Windows PowerShell 5.1 support.
"""
from concurrent.futures import ThreadPoolExecutor
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import threading
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "packaging/windows-test/powershell.lock.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def powershell(fetch=False):
    lock = json.loads(LOCK.read_text())
    cache = ROOT / lock["cache"]
    target = ROOT / lock["tool_root"]
    for path in (cache, target):
        if not path.resolve().is_relative_to(ROOT):
            raise ValueError("PowerShell cache/tool paths must remain inside this repository")
    if not cache.is_file():
        if not fetch:
            raise ValueError("Pinned PowerShell archive missing; restore it with --fetch-tool")
        cache.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(lock["url"], timeout=60) as response:
            data = response.read()
        if len(data) != lock["size"] or sha(data) != lock["sha256"]:
            raise ValueError("PowerShell download differs from its official release SHA256")
        cache.write_bytes(data)
    if cache.stat().st_size != lock["size"] or sha(cache.read_bytes()) != lock["sha256"]:
        raise ValueError("Cached PowerShell archive differs from the official release SHA256")
    if not (target / "pwsh").is_file():
        target.mkdir(parents=True, exist_ok=True)
        with tarfile.open(cache) as archive:
            archive.extractall(target, filter="data")
        (target / "pwsh").chmod(0o755)
    return target / "pwsh", lock


def payload(executable=True):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("luanti-fixture/README.txt", "Harmless bootstrap fixture; never executed.\n")
        archive.writestr("luanti-fixture/bin/" + ("luanti.exe" if executable else "wrong.exe"), b"fixture-not-a-real-executable\n")
    return output.getvalue()


def snapshot(path):
    return {file.relative_to(path).as_posix(): file.read_bytes() for file in path.rglob("*") if file.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-tool", action="store_true", help="Explicitly download the hash-pinned developer test tool")
    parser.add_argument("--batch", type=Path, default=ROOT / "packaging/playtest/templates/start.bat")
    args = parser.parse_args()
    tool, lock = powershell(args.fetch_tool)
    batch = args.batch.read_text()
    matches = re.findall(r'^\s*powershell\.exe\s+-NoProfile\s+-Command\s+"(.*)"\s*$', batch, re.M)
    assert len(matches) == 3, "Expected exact save preflight, settings upgrade and engine bootstrap commands"
    preflight, upgrade, command = matches
    assert batch.index(preflight) < batch.index('mkdir'), "Save validation must precede every launcher write"
    assert "[IO.Directory]::Move" in command and "finally" in command
    fixtures = {"/valid.zip": payload(), "/missing.zip": payload(False)}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            data = fixtures.get(self.path)
            if data is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *unused):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    report = ["Exact Windows bootstrap PowerShell/.NET filesystem regression", "PowerShell " + lock["version"] + " / Linux; cmd.exe and native Windows PowerShell 5.1 are not executed",
              "Official tool archive SHA256: " + lock["sha256"], "Bootstrap command SHA256: " + sha(command.encode()),
              "Save preflight SHA256: " + sha(preflight.encode())]
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="windows bootstrap with spaces ", dir=base) as temporary:
            work = Path(temporary)
            env = os.environ.copy()
            env.update(XDG_DATA_HOME=str(work / "ps-data"), XDG_CACHE_HOME=str(work / "ps-cache"),
                       XDG_CONFIG_HOME=str(work / "ps-config"), DOTNET_CLI_HOME=str(work / "dotnet"),
                       POWERSHELL_TELEMETRY_OPTOUT="1", DOTNET_CLI_TELEMETRY_OPTOUT="1",
                       DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1")

            def case(name, partial=False, valid=True, bad_hash=False):
                folder = work / name
                game = folder / "game directory"
                data = folder / "tester saves [qa] ' $"
                game.mkdir(parents=True)
                data.mkdir()
                (data / "worlds/playtest").mkdir(parents=True)
                (data / "settings.conf").write_bytes(b"# personal settings\nviewing_range = 44\n")
                (data / "worlds/playtest/map.sqlite").write_bytes(b"unchanged user world database fixture")
                if partial:
                    (data / "engine-5.17.0/bin").mkdir(parents=True)
                    (data / "engine-5.17.0/player-kept.txt").write_bytes(b"preserve incomplete engine contents")
                url = "/valid.zip" if valid else "/missing.zip"
                spec = {"windows_x86_64": {"url": "http://127.0.0.1:" + str(server.server_port) + url,
                                            "sha256": "0" * 64 if bad_hash else sha(fixtures[url]),
                                            "archive_root": "luanti-fixture"}}
                (game / "engine-downloads.json").write_text(json.dumps(spec))
                initial = snapshot(data)
                local = env.copy()
                local.update(GE_ROOT=str(game) + "/", GE_DATA=str(data))
                return data, initial, local

            def run(local):
                return subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", command], env=local,
                                      text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)

            def preserved(data, initial):
                for name in ("settings.conf", "worlds/playtest/map.sqlite"):
                    assert (data / name).read_bytes() == initial[name], "Bootstrap changed tester saves/settings"
                assert not list(data.glob("download-*")), "Temporary download staging was not cleaned"

            # Execute the shipped read-only preflight with actual .NET filesystem
            # semantics. Luanti settings use the final occurrence of a key.
            guard = work / "save preflight [qa] ' $"
            guard.mkdir()
            guard_env = env.copy()
            guard_env["GE_DATA"] = str(guard / "absent data")
            result = subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", preflight],
                                    env=guard_env, text=True, capture_output=True, timeout=30)
            assert result.returncode == 0 and not (guard / "absent data").exists(), result.stderr
            for name, metadata, accepted in (
                ("correct", "gameid = golden_era_playtest\n", True),
                ("whitespace", "\tgameid\t=\tgolden_era_playtest \t\r\n", True),
                ("comment", "# gameid = other_game\ngameid = golden_era_playtest\n", True),
                ("commented structure", '# example = {\n# example = """\ngameid = golden_era_playtest\n', True),
                ("final correct", "gameid = other_game\ngameid = golden_era_playtest\n", True),
                ("foreign", "gameid = other_game\n", False),
                ("final foreign", "gameid = golden_era_playtest\ngameid = other_game\n", False),
                ("missing key", "backend = sqlite3\n", False),
                ("empty", "", False),
                ("case sensitive", "gameid = GOLDEN_ERA_PLAYTEST\n", False),
                ("case sensitive key", "gameid = other_game\nGAMEID = golden_era_playtest\n", False),
                ("nested key", "gameid = other_game\nexample = {\ngameid = golden_era_playtest\n}\n", False),
                ("hash group name", "gameid = other_game\nfoo#bar = {\ngameid = golden_era_playtest\n}\n", False),
                ("empty group name", "gameid = other_game\n= {\ngameid = golden_era_playtest\n}\n", False),
                ("multiline key", 'gameid = other_game\nexample = """\ngameid = golden_era_playtest\n"""\n', False),
                ("hash multiline name", 'gameid = other_game\nfoo#bar = """\ngameid = golden_era_playtest\n"""\n', False),
                ("empty multiline name", 'gameid = other_game\n= """\ngameid = golden_era_playtest\n"""\n', False),
                ("unicode whitespace", "gameid = other_game\n\u00a0gameid = golden_era_playtest\n", False),
                ("byte order mark", "\ufeffgameid = golden_era_playtest\n", False),
                ("bare CR is not a line break", "gameid = other_game\rgameid = golden_era_playtest\n", False),
            ):
                folder = guard / name
                world = folder / "worlds/playtest"
                world.mkdir(parents=True)
                (world / "world.mt").write_bytes(metadata.encode())
                (world / "map.sqlite").write_bytes(b"untouched saved map")
                initial = snapshot(folder)
                guard_env["GE_DATA"] = str(folder)
                result = subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", preflight],
                                        env=guard_env, text=True, capture_output=True, timeout=30)
                assert (result.returncode == 0) == accepted, name + ": " + result.stderr
                assert snapshot(folder) == initial, "Save preflight wrote existing files: " + name
                assert {p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_dir()} == {"worlds", "worlds/playtest"}
            for marker in ("map.sqlite", "map.db", "map.sqlite-wal", "map_meta.txt", "players.sqlite", "auth.sqlite", "auth.txt", "mod_storage.sqlite", "players"):
                orphan = guard / ("orphan " + marker)
                world = orphan / "worlds/playtest"
                world.mkdir(parents=True)
                if marker in ("players", "map.db"):
                    (world / marker).mkdir()
                    (world / marker / "saved-data").write_bytes(b"existing world directory contents")
                else:
                    (world / marker).write_bytes(b"existing world without metadata")
                guard_env["GE_DATA"] = str(orphan)
                initial = snapshot(orphan)
                directories = {path.relative_to(orphan).as_posix() for path in orphan.rglob('*') if path.is_dir()}
                result = subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", preflight],
                                        env=guard_env, text=True, capture_output=True, timeout=30)
                assert result.returncode != 0 and "no world.mt" in result.stderr, marker + ": " + result.stderr
                assert snapshot(orphan) == initial
                assert {path.relative_to(orphan).as_posix() for path in orphan.rglob('*') if path.is_dir()} == directories
            report.append("PASS: read-only save preflight accepts new/correct saves and final game ID; comments stay comments; grouped/multiline names containing # or empty names refuse without writes")
            report.append("PASS: foreign/missing/case-mismatched IDs and all nine orphan markers, including a saved LevelDB map.db directory, refuse without creating or changing files/directories")

            # The one-time 0.1.8 settings upgrade keeps tester lines and their own key choices.
            settings_root = work / "settings upgrade [qa] ' $"
            (settings_root / "game/defaults").mkdir(parents=True)
            (settings_root / "data").mkdir()
            (settings_root / "game/defaults/playtest.conf").write_bytes(
                (ROOT / "packaging/playtest/templates/defaults/playtest.conf").read_bytes())
            settings = settings_root / "data/settings.conf"
            settings.write_bytes(b"# personal settings\r\nviewing_range = 44\r\nbind_address = 127.0.0.1\r\n"
                                 b"port = 30200\r\nkeymap_aux1 = SYSTEM_SCANCODE_9\r\n")
            upgrade_env = env.copy()
            upgrade_env.update(GE_ROOT=str(settings_root / "game") + "/", GE_DATA=str(settings_root / "data"))
            for attempt in ("first", "repeat"):
                result = subprocess.run([str(tool), "-NoProfile", "-NonInteractive", "-Command", upgrade],
                                        env=upgrade_env, text=True, capture_output=True, timeout=30)
                assert result.returncode == 0, result.stderr
                lines = settings.read_text().splitlines()
                assert lines == ["# personal settings", "viewing_range = 44", "keymap_aux1 = SYSTEM_SCANCODE_9",
                                 "menu_last_game = golden_era_playtest", "keymap_inventory = SYSTEM_SCANCODE_8|GAMEPAD_BUTTON_3",
                                 "default_privs = interact, shout, fly, fast", "golden_era_settings = 2"], attempt + ": " + repr(lines)
                assert not (settings_root / "data/settings.conf.new").exists()
            report.append("PASS: settings upgrade removes local-only binding, adds menu/key/LAN defaults once, and keeps tester choices")

            data, initial, local = case("fresh")
            result = run(local)
            assert result.returncode == 0, result.stdout
            assert (data / "engine-5.17.0/bin/luanti.exe").read_bytes() == b"fixture-not-a-real-executable\n"
            assert not (data / "engine-5.17.0/luanti-fixture").exists(), "Promotion nested the engine directory"
            preserved(data, initial)
            report.append("PASS: fresh verified download, extraction, direct engine promotion, special characters/spaces in paths, and staging cleanup")

            data, initial, local = case("partial", partial=True)
            result = run(local)
            assert result.returncode == 0, result.stdout
            assert (data / "engine-5.17.0/bin/luanti.exe").is_file()
            backups = list(data.glob("engine-5.17.0-incomplete-*"))
            assert len(backups) == 1 and (backups[0] / "player-kept.txt").read_bytes() == b"preserve incomplete engine contents"
            assert not (data / "engine-5.17.0/luanti-fixture").exists()
            preserved(data, initial)
            report.append("PASS: incomplete cache quarantined intact and replaced without nesting; tester saves/settings preserved")

            data, initial, local = case("bad hash", partial=True, bad_hash=True)
            result = run(local)
            assert result.returncode != 0 and "checksum mismatch" in result.stdout, result.stdout
            assert snapshot(data) == initial, "Failed checksum replaced existing data/cache"
            report.append("PASS: wrong checksum fails before cache replacement; no engine executable promoted")

            data, initial, local = case("missing executable", partial=True, valid=False)
            result = run(local)
            assert result.returncode != 0 and "executable is missing" in result.stdout, result.stdout
            assert snapshot(data) == initial, "Malformed engine archive replaced existing data/cache"
            report.append("PASS: archive with missing engine executable fails before replacement and cleans staging")

            data, initial, local = case("fresh concurrent")
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(run, (local, local)))
            assert all(result.returncode == 0 for result in results), "\n".join(result.stdout for result in results)
            assert (data / "engine-5.17.0/bin/luanti.exe").is_file()
            assert not (data / "engine-5.17.0/luanti-fixture").exists()
            preserved(data, initial)
            report.append("PASS: two concurrent fresh promotions complete without nesting, corruption, or leftover staging")
    except Exception as error:
        report.append("FAIL: " + str(error))
        raise
    finally:
        server.shutdown()
        server.server_close()
        evidence = base / "windows-bootstrap-smoke.txt"
        evidence.write_text("\n".join(report) + "\n")
        print("\n".join(report))
        print("Evidence: " + str(evidence))


if __name__ == "__main__":
    main()
