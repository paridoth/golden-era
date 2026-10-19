"""Wrap the verified tester ZIP in a per-user Windows self-extracting installer."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import struct
import subprocess
import sys
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = json.loads((ROOT / "packaging/playtest/release.json").read_text())["version"]
DEFAULT_ARCHIVE = ROOT / f"dist/golden-era-playtest-{VERSION}-windows-test.zip"
DEFAULT_OUTPUT = ROOT / f"dist/golden-era-playtest-{VERSION}-windows.exe"
LOCK = ROOT / "packaging/playtest/nsis-toolchain.lock.json"
CACHE = ROOT / "references/cache/release/nsis-debs"
SUPPORT = "installer-support"
EPOCH = 315532800  # Same fixed 1980 timestamp as the source ZIP.


class InstallerError(Exception):
    pass


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def inside(path):
    path = Path(path).resolve()
    if not path.is_relative_to(ROOT):
        raise InstallerError("Build paths must stay inside this repository")
    return path


def packager():
    spec = importlib.util.spec_from_file_location("installer_game_packager", ROOT / "packaging/playtest/packager.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def toolchain(destination, fetch=False):
    lock = json.loads(LOCK.read_text())
    for entry in lock["packages"]:
        name = entry["filename"]
        if Path(name).name != name:
            raise InstallerError("Invalid toolchain cache filename")
        cached = CACHE / name
        if not cached.is_file() or cached.stat().st_size != entry["size"] or sha(cached) != entry["sha256"]:
            if not fetch:
                raise InstallerError("Missing/mismatched NSIS package; restore with --fetch-toolchain: " + name)
            CACHE.mkdir(parents=True, exist_ok=True)
            temporary = cached.with_suffix(".download")
            try:
                urllib.request.urlretrieve(entry["url"], temporary)
                if temporary.stat().st_size != entry["size"] or sha(temporary) != entry["sha256"]:
                    raise InstallerError("NSIS download checksum mismatch: " + name)
                temporary.replace(cached)
            finally:
                temporary.unlink(missing_ok=True)
        subprocess.run(["dpkg-deb", "-x", str(cached), str(destination)], check=True)
    # Check the exact extracted compiler, stubs, includes and plugins, too.
    for relative, entry in lock["files"].items():
        file = destination / relative
        if not file.is_file() or file.is_symlink() or file.stat().st_size != entry["size"] or sha(file) != entry["sha256"]:
            raise InstallerError("Extracted NSIS file mismatch: " + relative)
    compiler = destination / lock["compiler"]
    env = os.environ.copy()
    env["NSISDIR"] = str(destination / lock["nsisdir"])
    env["SOURCE_DATE_EPOCH"] = str(EPOCH)
    if subprocess.check_output([str(compiler), "-VERSION"], env=env, text=True).strip() != lock["compiler_version"]:
        raise InstallerError("Unexpected NSIS compiler version")
    return compiler, env, lock


def file_records(directory):
    return {path.relative_to(directory).as_posix(): {"size": path.stat().st_size, "sha256": sha(path)}
            for path in sorted(directory.rglob("*")) if path.is_file()}


def support_files(destination, archive):
    destination.mkdir()
    sources = ["scripts/package-installer.py", "packaging/playtest/installer.py", "packaging/playtest/installer.nsi",
               "packaging/playtest/nsis-toolchain.lock.json", "packaging/playtest/nsis-LICENSE.txt",
               "packaging/playtest/release.json"]
    for relative in sources:
        target = destination / "source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
    shutil.copyfile(ROOT / "packaging/playtest/nsis-LICENSE.txt", destination / "NSIS-LICENSE.txt")
    (destination / "READ-ME.txt").write_text(
        "GOLDEN ERA FACTORY PLAYTEST " + VERSION + " - WINDOWS SETUP\n\n"
        "Setup installs the game automatically and launches it. Use the Golden Era\n"
        "Playtest desktop or Start menu shortcut for later launches. No admin or Java\n"
        "is needed. First launch needs internet for a hash-checked official Luanti\n"
        "engine download (about 18 MB). Close the welcome panel to play.\n\n"
        "Saves, settings and logs: %LOCALAPPDATA%\\GoldenEraPlaytest\n"
        "Game files: %LOCALAPPDATA%\\GoldenEraPlaytest\\app\\" + VERSION + "\n"
        "Reinstalling replaces only the game files and shortcuts, keeping saves.\n"
        "Close the game before rerunning setup. No uninstaller removes your saves.\n\n"
        "The original game START-HERE.txt also covers the optional ZIP distribution.\n"
        "Its extraction step is already handled by this installer. /packhelp shows\n"
        "workshop instructions. Game credits/licenses are under docs and game mods.\n\n"
        "This setup is unsigned. Native Windows startup still needs tester confirmation.\n"
        "Installer built with unmodified NSIS (zlib stub and System plugin). Full\n"
        "NSIS copyright/license and the installer/build source are included here.\n"
        "Game docs/FILE-MANIFEST.json covers the unchanged ZIP payload;\n"
        "EXTRA-FILES.json covers these additional installer files except itself.\n")
    write_json(destination / "BUILD.json", {
        "version": VERSION,
        "game_archive": {"name": archive.name, "sha256": sha(archive)},
        "project_base_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "revision_scope": "Base Git revision; the included exact source files identify this build.",
        "toolchain_lock_sha256": sha(LOCK),
        "engine_bundled": False,
        "native_windows_test": "Pending; build and extracted payload are checked on Linux.",
    })
    write_json(destination / "EXTRA-FILES.json", {"files": file_records(destination), "excludes": ["EXTRA-FILES.json"]})


def verify_pe(path):
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise InstallerError("Installer is not a Windows executable")
    offset = struct.unpack_from("<I", data, 0x3c)[0]
    if data[offset:offset + 4] != b"PE\0\0" or struct.unpack_from("<H", data, offset + 4)[0] != 0x14c:
        raise InstallerError("Unexpected installer PE header/machine")
    if struct.unpack_from("<H", data, offset + 24 + 68)[0] != 2:
        raise InstallerError("Expected a Windows GUI installer")
    if b'requestedExecutionLevel level="asInvoker"' not in data:
        raise InstallerError("Installer must request ordinary-user privileges")


def extracted_records(executable, directory):
    # Validate every listed member before letting 7-Zip write anything.
    listing = subprocess.check_output(["7z", "l", "-slt", str(executable)], text=True)
    if "Type = Nsis" not in listing or "SubType = NSIS-3 Unicode" not in listing:
        raise InstallerError("Not the expected Unicode NSIS archive")
    members = []
    for line in listing.split("----------\n", 1)[1].splitlines():
        if line.startswith("Path = "):
            name = line[len("Path = "):].replace("\\", "/")
            if not name or PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts or ":" in name:
                raise InstallerError("Unsafe installer member: " + name)
            members.append(name)
    if len(members) != len(set(name.casefold() for name in members)):
        raise InstallerError("Duplicate installer member")
    subprocess.run(["7z", "x", "-y", "-bd", "-o" + str(directory), str(executable)],
                   check=True, stdout=subprocess.DEVNULL)
    return file_records(directory)


def verify(executable, manifest=None):
    executable = inside(executable)
    manifest = inside(manifest or executable.with_suffix(".exe.manifest.json"))
    record = json.loads(manifest.read_text())
    if executable.stat().st_size != record["size_bytes"] or sha(executable) != record["sha256"]:
        raise InstallerError("Installer checksum/size differs from its manifest")
    verify_pe(executable)
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="installer-verify-", dir=base) as temporary:
        actual = extracted_records(executable, Path(temporary))
    expected = record["files"] | record["installer_plugins"]
    if actual != expected:
        differences = sorted(name for name in actual.keys() | expected.keys() if actual.get(name) != expected.get(name))
        raise InstallerError("Installer extracted files differ: " + ", ".join(differences[:10]))
    return record


def build(archive=DEFAULT_ARCHIVE, output=DEFAULT_OUTPUT, fetch=False):
    archive, output = inside(archive), inside(output)
    if output.suffix.lower() != ".exe":
        raise InstallerError("Installer output must be an .exe")
    game_packager = packager()
    try:
        game_packager.verify_package(archive, archive.with_suffix(".manifest.json"))
    except game_packager.PackageError as error:
        raise InstallerError(str(error)) from error
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="installer-build-", dir=base) as temporary:
        work = Path(temporary)
        compiler, env, lock = toolchain(work / "toolchain", fetch)
        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(work / "payload")
        payload = work / "payload" / game_packager.BUNDLE
        support = work / "support"
        support_files(support, archive)
        expected = file_records(payload)
        expected.update({SUPPORT + "/" + name: item for name, item in file_records(support).items()})
        for tree in (payload, support):
            for file in tree.rglob("*"):
                os.utime(file, (EPOCH, EPOCH))
        staged = work / output.name
        command = [str(compiler), "-NOCONFIG", "-V2", "-WX", "-DGE_VERSION=" + VERSION,
                   "-DGE_PAYLOAD_DIR=" + str(payload), "-DGE_INSTALLER_SUPPORT=" + str(support),
                   "-DGE_OUTPUT=" + str(staged), str(support / "source/packaging/playtest/installer.nsi")]
        subprocess.run(command, env=env, check=True)
        verify_pe(staged)
        plugin = "usr/share/nsis/Plugins/x86-unicode/System.dll"
        plugins = {"$PLUGINSDIR/System.dll": lock["files"][plugin]}
        actual = extracted_records(staged, work / "verify")
        if actual != expected | plugins:
            differences = sorted(name for name in actual.keys() | expected.keys() | plugins.keys()
                                 if actual.get(name) != (expected | plugins).get(name))
            raise InstallerError("Compiled installer payload mismatch: " + ", ".join(differences[:10]))
        staged.replace(output)
    record = {"format": 1, "version": VERSION, "artifact": output.name,
              "size_bytes": output.stat().st_size, "sha256": sha(output),
              "game_archive": {"name": archive.name, "sha256": sha(archive)},
              "files": expected, "installer_plugins": plugins,
              "native_windows_test": "Pending", "engine_bundled": False}
    write_json(output.with_suffix(".exe.manifest.json"), record)
    output.with_suffix(".exe.sha256").write_text(record["sha256"] + "  " + output.name + "\n")
    return record
