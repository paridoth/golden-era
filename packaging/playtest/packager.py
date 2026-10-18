"""Deterministic, dereferenced game packaging; never include local worlds or Git data."""
from dataclasses import dataclass
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import tempfile
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parents[2]
BUNDLE = "GoldenEra-Playtest"
VERSION = "0.1.0"
GAME_ID = "golden_era_playtest"
MANIFEST = "docs/FILE-MANIFEST.json"
ZIP_TIME = (1980, 1, 1, 0, 0, 0)
EXCLUDED = {".git", "__pycache__"}
PRIVATE_NAMES = {"world.mt", "auth.txt", "auth.sqlite", "players.sqlite", "map.sqlite",
                 "mod_storage.sqlite", "env_meta.txt", "ipban.txt"}
FORBIDDEN_GAME_SUFFIXES = {".jar", ".class", ".pyc", ".pyo", ".log", ".o", ".a", ".so", ".dll", ".exe", ".deb"}


class PackageError(Exception):
    pass


@dataclass
class Payload:
    data: bytes
    mode: int
    provenance: dict


def _json(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _files(directory, ancestors=frozenset()):
    """Follow source links, rejecting cycles and files outside the repository."""
    directory = Path(directory)
    real = directory.resolve(strict=True)
    if not real.is_relative_to(ROOT.resolve()):
        raise PackageError("Package input resolves outside the repository")
    if real in ancestors:
        raise PackageError("Cycle in package source tree")
    ancestors = ancestors | {real}
    for source in sorted(directory.iterdir(), key=lambda item: item.name):
        if source.name in EXCLUDED or source.suffix in {".pyc", ".pyo"}:
            continue
        if source.is_dir():
            yield from _files(source, ancestors)
        elif source.is_file():
            if not source.resolve(strict=True).is_relative_to(ROOT.resolve()):
                raise PackageError("Package file resolves outside the repository")
            yield source
        else:
            raise PackageError("Unsupported package input: " + source.name)


def _safe_name(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name:
        raise PackageError("Unsafe archive path: " + name)
    if any(part in EXCLUDED for part in path.parts):
        raise PackageError("Forbidden archive path: " + name)
    return path.as_posix()


def _add(payloads, name, data, provenance, mode=0o644):
    name = _safe_name(name)
    if name in payloads:
        raise PackageError("Duplicate package path: " + name)
    payloads[name] = Payload(data, mode, provenance)


def _source_record(project_revision, source_path):
    return {"origin": "golden-era-project", "revision": project_revision,
            "revision_scope": "base Git commit; SHA256 identifies the exact packaged file",
            "source_path": source_path}


def _upstream_origin(relative):
    parts = PurePosixPath(relative).parts
    if len(parts) >= 3 and parts[0] == "mods":
        if parts[1] == "era_playtest":
            return "project", "integrations/playtest/mod/" + "/".join(parts[2:])
        names = {"pipeworks", "basic_materials", "fakelib", "xcompat", "elepower", "fluid_lib", "mesecons", "drawers"}
        if parts[1] in names:
            return parts[1], "/".join(parts[2:])
    if relative == "playtest-sources.json":
        return "generated", "integrations/playtest/assembly.py"
    return "mineclonia", relative


def _notice(name):
    path = PurePosixPath(name)
    base = path.name.lower()
    return (base.startswith(("license", "copying", "copyright", "notice", "credits", "authors", "legal", "readme"))
            or "notice" in base or base == "dep5"
            or any(part.lower() in {"licenses", "notices"} for part in path.parts[:-1]))


def _collect_game(game, sources, project_revision, payloads):
    tracked = {}
    for name in sources:
        tracked[name] = set(subprocess.check_output(
            ["git", "-C", str(ROOT / "upstream" / name), "ls-files", "-z"]
        ).decode().split("\0"))
    for source in _files(game):
        relative = source.relative_to(game).as_posix()
        if source.name in PRIVATE_NAMES or source.suffix.lower() in FORBIDDEN_GAME_SUFFIXES:
            raise PackageError("Unexpected private/build/Java file in assembled game: " + relative)
        origin, original_path = _upstream_origin(relative)
        data = source.read_bytes()
        if origin in {"project", "generated"}:
            record = _source_record(project_revision, original_path)
            if origin == "generated":
                record["generated"] = True
        else:
            original = ROOT / "upstream" / origin / original_path
            if original.exists() and original_path not in tracked[origin]:
                # Ignored local artifacts must not be pulled through assembly links.
                continue
            original_hash = _sha(original.read_bytes()) if original.is_file() else None
            record = {"origin": origin, "revision": sources[origin]["commit"],
                      "source_url": sources[origin]["url"], "source_path": original_path,
                      "source_sha256": original_hash, "modified": original_hash != _sha(data)}
            if original_hash is None:
                record["generated_by_project_patch"] = True
        _add(payloads, "games/" + GAME_ID + "/" + relative, data, record,
             0o755 if source.stat().st_mode & 0o111 else 0o644)


def _collect_project(project_revision, payloads):
    paths = ["LICENSE", "upstream.lock.json", "scripts/setup-playtest.py", "scripts/package-playtest.py",
             "integrations/playtest", "packaging/playtest/packager.py", "packaging/playtest/source-supplements.lock.json",
             "packaging/playtest/source-supplements", "packaging/playtest/templates"]
    for relative in paths:
        source = ROOT / relative
        files = _files(source) if source.is_dir() else [source]
        for file in files:
            name = file.relative_to(ROOT).as_posix()
            _add(payloads, "source/project/" + name, file.read_bytes(), _source_record(project_revision, name),
                 0o755 if file.stat().st_mode & 0o111 else 0o644)
    _add(payloads, "LICENSE-GOLDEN-ERA.txt", (ROOT / "LICENSE").read_bytes(), _source_record(project_revision, "LICENSE"))


def _overlay(directory, payloads, project_revision, origin):
    directory = Path(directory).resolve(strict=True)
    if not directory.is_dir() or not directory.is_relative_to(ROOT.resolve()):
        raise PackageError("Overlay must be a directory inside the repository")
    for source in _files(directory):
        relative = source.relative_to(directory).as_posix()
        if source.name in PRIVATE_NAMES or source.suffix.lower() in {".jar", ".class", ".log"}:
            raise PackageError("Unexpected private/Java/log file in overlay: " + relative)
        record = _source_record(project_revision, source.relative_to(ROOT).as_posix())
        record["origin"] = origin
        _add(payloads, relative, source.read_bytes(), record,
             0o755 if source.stat().st_mode & 0o111 else 0o644)


def _inventory(payloads, sources):
    inventory = {}
    for name, payload in payloads.items():
        if _notice(name):
            origin = payload.provenance["origin"]
            inventory.setdefault(origin, []).append(name)
    return {"scope": "Retained upstream notices and README files; consult the per-file and per-mod texts for license terms.",
            "upstream_sources": sources,
            "notices_by_origin": {name: sorted(paths) for name, paths in sorted(inventory.items())}}


def _entries(payloads):
    notices_by_directory = {}
    for name in payloads:
        if _notice(name):
            notices_by_directory.setdefault(PurePosixPath(name).parent, []).append(name)
    result = []
    for name, payload in sorted(payloads.items()):
        path = PurePosixPath(name)
        references = [notice for ancestor in path.parents for notice in notices_by_directory.get(ancestor, ())]
        result.append({"path": name, "size": len(payload.data), "sha256": _sha(payload.data),
                       "mode": format(payload.mode, "04o"), "provenance": payload.provenance,
                       "notice_references": sorted(references)})
    return result


def _validate_payloads(payloads):
    forbidden_bytes = {str(ROOT).encode(), str(Path.home()).encode()}
    casefolded = {}
    for name, payload in payloads.items():
        _safe_name(name)
        if name.casefold() in casefolded:
            raise PackageError("Case-insensitive archive path collision: " + name)
        casefolded[name.casefold()] = name
        if any(marker and marker in payload.data for marker in forbidden_bytes):
            raise PackageError("Local host path found in package content: " + name)


def _supplement(fetch=False):
    """Require the exact corresponding-source supplement in every release build."""
    location = ROOT / "packaging/playtest/source-supplements.lock.json"
    if not location.is_file():
        raise PackageError("Missing tracked source-supplements.lock.json")
    lock = json.loads(location.read_text())
    directory = (ROOT / lock["overlay"]).resolve()
    if not directory.is_relative_to(ROOT.resolve()):
        raise PackageError("Source supplement cache must be inside the repository")
    expected = {}
    for entry in lock["files"]:
        relative = _safe_name(entry["path"])
        if relative in expected:
            raise PackageError("Duplicate source supplement path: " + relative)
        expected[relative] = entry
        target = directory / relative
        if target.is_file() and _sha(target.read_bytes()) == entry["sha256"]:
            continue
        if not fetch:
            raise PackageError("Missing or mismatched source supplement: " + relative +
                               ". Restore it with: python3 scripts/package-playtest.py --fetch-supplements")
        if "project_source" in entry:
            original = (ROOT / entry["project_source"]).resolve()
            if not original.is_relative_to(ROOT.resolve()):
                raise PackageError("Supplement project source must be inside the repository")
            data = original.read_bytes()
        elif entry.get("url", "").startswith("https://"):
            with urllib.request.urlopen(entry["url"], timeout=60) as response:
                data = response.read()
        else:
            raise PackageError("Supplement has no HTTPS URL or tracked project_source: " + relative)
        if _sha(data) != entry["sha256"]:
            raise PackageError("Downloaded/copied supplement SHA256 mismatch: " + relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    actual = {file.relative_to(directory).as_posix() for file in _files(directory)}
    if actual != set(expected):
        raise PackageError("Source supplement cache has unexpected files; retain only the locked overlay entries")
    return directory, lock


def verify_package(path, sidecar=None):
    """Read actual ZIP members and verify paths, modes, CRC and manifest digests."""
    path = Path(path)
    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        names = [item.filename for item in infos]
        if len(names) != len(set(names)) or names != sorted(names):
            raise PackageError("ZIP entries must be unique and sorted")
        actual = {}
        for info in infos:
            if not info.filename.startswith(BUNDLE + "/"):
                raise PackageError("ZIP entry outside the bundle root")
            relative = info.filename[len(BUNDLE) + 1:]
            _safe_name(relative)
            mode = info.external_attr >> 16
            if not stat.S_ISREG(mode) or stat.S_IMODE(mode) not in {0o644, 0o755}:
                raise PackageError("ZIP member is a symlink or has unexpected mode: " + relative)
            if info.date_time != ZIP_TIME:
                raise PackageError("ZIP member timestamp is not normalized: " + relative)
            data = archive.read(info)  # Reading also verifies the ZIP CRC.
            actual[relative] = {"size": len(data), "sha256": _sha(data), "mode": format(stat.S_IMODE(mode), "04o")}
        manifest = json.loads(archive.read(BUNDLE + "/" + MANIFEST))
    expected = {item["path"]: item for item in manifest["files"]}
    if set(actual) != set(expected) | {MANIFEST}:
        raise PackageError("ZIP payload differs from the internal file manifest")
    for name, item in expected.items():
        if any(actual[name][key] != item[key] for key in ("size", "sha256", "mode")):
            raise PackageError("ZIP payload hash/size/mode mismatch: " + name)
    if sidecar is not None:
        external = json.loads(Path(sidecar).read_text())
        external_files = {item["path"]: item for item in external["files"]}
        if set(external_files) != set(actual) or external["archive_sha256"] != _sha(path.read_bytes()):
            raise PackageError("External manifest differs from the ZIP")
        for name, item in actual.items():
            if any(external_files[name][key] != item[key] for key in ("size", "sha256", "mode")):
                raise PackageError("External file manifest mismatch: " + name)
    return {"files": len(actual), "bytes": sum(item["size"] for item in actual.values())}


def build_package(output=None, overlays=(), fetch_supplements=False):
    """Return package paths/metadata; overlays add self-contained engine trees later."""
    output = Path(output or ROOT / "dist" / ("golden-era-playtest-" + VERSION + "-windows-test.zip")).absolute()
    if output.suffix.lower() != ".zip" or not output.resolve().is_relative_to(ROOT.resolve()):
        raise PackageError("ZIP output must be inside the repository")
    assembly = _module("playtest_package_assembly", ROOT / "integrations/playtest/assembly.py")
    try:
        sources = assembly.verify_sources(fetch=False)
    except assembly.AssemblyError as error:
        raise PackageError(str(error)) from error
    project_revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    supplement_directory, supplement_lock = _supplement(fetch=fetch_supplements)
    payloads = {}
    base = ROOT / "runtime/tests"
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="package-playtest-", dir=base) as temporary:
        game = Path(temporary) / "games" / GAME_ID
        try:
            assembled = assembly.build_game(game, fetch=False)
        except assembly.AssemblyError as error:
            raise PackageError(str(error)) from error
        _collect_game(game, sources, project_revision, payloads)
        _collect_project(project_revision, payloads)
        templates = ROOT / "packaging/playtest/templates"
        if templates.is_dir():
            _overlay(templates, payloads, project_revision, "golden-era-package-template")
        _overlay(supplement_directory, payloads, project_revision, "locked-source-supplement")
        for directory in overlays:
            if Path(directory).resolve() == supplement_directory:
                continue
            _overlay(directory, payloads, project_revision, "additional-package-input")
    generated = {"origin": "generated-package-metadata", "revision": project_revision,
                 "source_path": "packaging/playtest/packager.py"}
    _add(payloads, "docs/UPSTREAM-SOURCES.json", _json({"game": assembled, "project_base_revision": project_revision,
                                                      "source_supplements": supplement_lock}), generated)
    _add(payloads, "docs/LICENSE-INVENTORY.json", _json(_inventory(payloads, sources)), generated)
    reproducing = """# Package contents and reproduction

This package contains source Lua and media for the isolated Golden Era stock-mod
playtest. The game folder is self-contained and has no links to the build machine.
Existing worlds, player/auth databases, Java modpack originals and Git internals
are excluded. Save files are created on the tester's machine when playing.

Upstream source URLs and exact revisions are recorded in UPSTREAM-SOURCES.json.
The game includes its upstream Lua source and notices. The project integration,
compatibility patches, assembly and packaging scripts are under source/project.
Those scripts expect the pinned source checkouts under upstream/ in a project
checkout, and can rebuild this game-only archive without an engine build:

    python3 scripts/package-playtest.py

The tracked packaging/playtest/source-supplements.lock.json makes the pinned
original model-source supplement mandatory in every build. If its ignored cache
is missing, explicitly restore its hash-verified downloads/project files first:

    python3 scripts/package-playtest.py --fetch-supplements

The ordinary command performs no downloads and fails on missing, changed or
unexpected supplement files. Additional platform overlays are explicit inputs.

No binary engine is included in the game-only archive. Platform releases may add
an engine and launchers through explicit packaging overlays; inspect their own
notices and source records as well. FILE-MANIFEST.json identifies every payload
file except itself. The external manifest sidecar also identifies that manifest.
Archive entries use a fixed timestamp and normalized executable modes.
"""
    _add(payloads, "docs/REPRODUCING.md", reproducing.encode(), generated)
    manifest = {"format": 1, "bundle": BUNDLE, "version": VERSION,
                "manifest_excludes": [MANIFEST], "reason": "A file cannot contain its own SHA256.",
                "files": _entries(payloads)}
    _add(payloads, MANIFEST, _json(manifest), generated)
    _validate_payloads(payloads)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix=".package-playtest-", suffix=".zip", dir=output.parent, delete=False) as temporary:
        staged = Path(temporary.name)
    try:
        with zipfile.ZipFile(staged, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, payload in sorted(payloads.items()):
                info = zipfile.ZipInfo(BUNDLE + "/" + name, ZIP_TIME)
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | payload.mode) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, payload.data, compresslevel=9)
        verify_package(staged)
        staged.replace(output)
    finally:
        if staged.exists():
            staged.unlink()
    archive_hash = _sha(output.read_bytes())
    sidecar = output.with_suffix(".manifest.json")
    sidecar.write_bytes(_json({"format": 1, "archive": output.name, "archive_sha256": archive_hash,
                               "bundle": BUNDLE, "files": _entries(payloads)}))
    checksum = output.with_suffix(".zip.sha256")
    checksum.write_text(archive_hash + "  " + output.name + "\n")
    return {"archive": output, "manifest": sidecar, "checksum": checksum,
            "sha256": archive_hash, "files": len(payloads), "bytes": output.stat().st_size}
