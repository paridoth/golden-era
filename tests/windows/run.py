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
    assert len(matches) == 1, "Expected one exact inline PowerShell bootstrap command"
    command = matches[0]
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
              "Official tool archive SHA256: " + lock["sha256"], "Inline command SHA256: " + sha(command.encode())]
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
