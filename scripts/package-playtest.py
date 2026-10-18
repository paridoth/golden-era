#!/usr/bin/env python3
"""Build a portable game-only tester ZIP from verified local pinned sources."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("playtest_packager", ROOT / "packaging/playtest/packager.py")
packager = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = packager
spec.loader.exec_module(packager)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="ZIP destination inside this repository (default: dist game-only archive)")
    parser.add_argument("--overlay", type=Path, action="append", default=[],
                        help="Additional self-contained bundle-root files, such as a platform engine tree; repeatable")
    parser.add_argument("--verify", type=Path, help="Verify an existing ZIP and its external manifest instead of rebuilding")
    parser.add_argument("--fetch-supplements", action="store_true",
                        help="Explicitly restore hash-locked model-source downloads/project files before packaging")
    args = parser.parse_args()
    try:
        if args.verify:
            if args.output or args.overlay or args.fetch_supplements:
                parser.error("--verify cannot be combined with build options")
            sidecar = args.verify.with_suffix(".manifest.json")
            result = packager.verify_package(args.verify, sidecar if sidecar.is_file() else None)
            print("Verified: " + str(args.verify.resolve()))
            print("Files: " + str(result["files"]) + "; unpacked bytes: " + str(result["bytes"]))
            return 0
        result = packager.build_package(args.output, overlays=args.overlay, fetch_supplements=args.fetch_supplements)
    except (packager.PackageError, OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print("PLAYTEST PACKAGE FAILED: " + str(error), file=sys.stderr)
        return 1
    print("Ready: " + str(result["archive"]))
    print("SHA256: " + result["sha256"])
    print("Files: " + str(result["files"]) + "; ZIP bytes: " + str(result["bytes"]))
    print("File manifest: " + str(result["manifest"]))
    print("Checksum: " + str(result["checksum"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
