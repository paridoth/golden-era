"""Deterministic Linux archive derived from a fully verified game-only ZIP."""
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import tarfile
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("linux_base_packager", ROOT / "packaging/playtest/packager.py")
base = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = base
spec.loader.exec_module(base)
PackageError = base.PackageError
BUNDLE = base.BUNDLE
MANIFEST = base.MANIFEST


def _json(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def _sha(data):
    return hashlib.sha256(data).hexdigest()


def _entry(name, data, mode, provenance):
    return {"path": name, "size": len(data), "sha256": _sha(data), "mode": format(mode, "04o"),
            "provenance": provenance}


def verify_package(path):
    path = Path(path)
    actual = {}
    manifest = None
    with tarfile.open(path, "r:gz") as archive:
        entries = archive.getmembers()
        names = [entry.name for entry in entries]
        if names != sorted(set(names)):
            raise PackageError("Linux archive members must be unique and sorted")
        for entry in entries:
            if not entry.name.startswith(BUNDLE + "/"):
                raise PackageError("Linux archive member outside bundle root")
            relative = entry.name[len(BUNDLE) + 1:]
            base._safe_name(relative)
            if not entry.isfile() or entry.mode not in {0o644, 0o755}:
                raise PackageError("Linux archive links or unexpected permissions: " + relative)
            if entry.uid or entry.gid or entry.uname or entry.gname or entry.mtime:
                raise PackageError("Linux archive metadata is not normalized: " + relative)
            data = archive.extractfile(entry).read()
            actual[relative] = _entry(relative, data, entry.mode, {})
            if relative == MANIFEST:
                manifest = json.loads(data)
    if manifest is None:
        raise PackageError("Linux archive has no internal file manifest")
    expected = {entry["path"]: entry for entry in manifest["files"]}
    if set(actual) != set(expected) | {MANIFEST}:
        raise PackageError("Linux archive differs from its internal manifest")
    for name, entry in expected.items():
        if any(actual[name][key] != entry[key] for key in ("size", "sha256", "mode")):
            raise PackageError("Linux archive member mismatch: " + name)
    sidecar = path.with_suffix(path.suffix + ".manifest.json")
    external = json.loads(sidecar.read_text())
    digest = _sha(path.read_bytes())
    if external["archive_sha256"] != digest:
        raise PackageError("Linux archive checksum differs from external manifest")
    expected_external = {entry["path"]: entry for entry in external["files"]}
    if set(expected_external) != set(actual):
        raise PackageError("Linux external manifest member mismatch")
    for name, entry in expected_external.items():
        if any(actual[name][key] != entry[key] for key in ("size", "sha256", "mode")):
            raise PackageError("Linux external manifest digest mismatch: " + name)
    return {"archive": path.resolve(), "sha256": digest, "files": len(actual), "bytes": path.stat().st_size}


def build_package(game_zip=None, output=None):
    engine_reference = json.loads((ROOT / "packaging/linux/engine-reference.json").read_text())
    install_reference = ROOT / "packaging/linux/templates/Install Luanti.flatpakref"
    if _sha(install_reference.read_bytes()) != engine_reference["flatpakref_sha256"]:
        raise PackageError("Bundled official Flatpak installation reference differs from its recorded SHA256")
    game_zip = Path(game_zip or ROOT / "dist" / ("golden-era-playtest-" + base.VERSION + "-windows-test.zip")).resolve()
    base.verify_package(game_zip, game_zip.with_suffix(".manifest.json"))
    digest = _sha(game_zip.read_bytes())
    payloads = {}
    with zipfile.ZipFile(game_zip) as archive:
        original_manifest = json.loads(archive.read(BUNDLE + "/" + MANIFEST))
        original = {entry["path"]: entry for entry in original_manifest["files"]}
        for info in archive.infolist():
            relative = info.filename[len(BUNDLE) + 1:]
            if relative in {MANIFEST, "start.bat", "start.command", "engine-downloads.json"}:
                continue
            entry = original[relative]
            payloads[relative] = base.Payload(archive.read(info), stat.S_IMODE(info.external_attr >> 16), entry["provenance"])
    version = original_manifest["version"]
    output = Path(output or ROOT / "dist" / ("golden-era-playtest-" + version + "-linux.tar.gz")).absolute()
    if not output.name.endswith(".tar.gz") or not output.resolve().is_relative_to(ROOT.resolve()):
        raise PackageError("Linux output must be a .tar.gz inside the repository")
    revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()

    def add(name, source, executable=False):
        payloads[name] = base.Payload(source.read_bytes(), 0o755 if executable else 0o644,
                                      {"origin": "golden-era-linux-packaging", "revision": revision,
                                       "revision_scope": "base Git commit; SHA256 identifies exact file",
                                       "source_path": source.relative_to(ROOT).as_posix()})

    templates = ROOT / "packaging/linux/templates"
    for source in sorted(templates.rglob("*")):
        if source.is_file():
            name = source.relative_to(templates).as_posix()
            add(name, source, name.endswith((".sh", ".desktop")))
    for directory in (ROOT / "packaging/linux",):
        for source in sorted(directory.rglob("*")):
            if source.is_file() and "__pycache__" not in source.parts:
                add("source/project/" + source.relative_to(ROOT).as_posix(), source)
    for source in (ROOT / "scripts/package-linux.py", ROOT / "docs/linux-release.md"):
        add("source/project/" + source.relative_to(ROOT).as_posix(), source)
    add("docs/LINUX-ENGINE-REFERENCE.json", ROOT / "packaging/linux/engine-reference.json")
    provenance = {"origin": "generated-linux-package-metadata", "revision": revision,
                  "source_path": "packaging/linux/packager.py"}
    entries = base._entries(payloads)
    manifest = {"format": 1, "bundle": BUNDLE, "version": version, "platform": "linux",
                "base_game_zip": {"name": game_zip.name, "sha256": digest},
                "manifest_excludes": [MANIFEST], "files": entries}
    payloads[MANIFEST] = base.Payload(_json(manifest), 0o644, provenance)
    base._validate_payloads(payloads)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(prefix=".linux-package-", dir=output.parent, delete=False) as temporary:
        staged = Path(temporary.name)
    try:
        with staged.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0, compresslevel=9) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for name, payload in sorted(payloads.items()):
                    entry = tarfile.TarInfo(BUNDLE + "/" + name)
                    entry.mode = payload.mode
                    entry.size = len(payload.data)
                    archive.addfile(entry, io.BytesIO(payload.data))
        staged.replace(output)
    finally:
        staged.unlink(missing_ok=True)
    archive_hash = _sha(output.read_bytes())
    sidecar = output.with_suffix(output.suffix + ".manifest.json")
    sidecar.write_bytes(_json({"format": 1, "archive": output.name, "archive_sha256": archive_hash,
                              "base_game_zip_sha256": digest, "files": base._entries(payloads)}))
    output.with_suffix(output.suffix + ".sha256").write_text(archive_hash + "  " + output.name + "\n")
    return verify_package(output)
