#!/usr/bin/env python3
"""Build or verify the single-file Windows tester setup; no system installation."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("playtest_installer", ROOT / "packaging/playtest/installer.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, default=installer.DEFAULT_ARCHIVE)
    parser.add_argument("--output", type=Path, default=installer.DEFAULT_OUTPUT)
    parser.add_argument("--fetch-toolchain", action="store_true", help="Restore exact hash-locked NSIS packages into the repo cache")
    parser.add_argument("--verify", type=Path, help="Verify an existing EXE and its .exe.manifest.json by extracting with 7-Zip")
    args = parser.parse_args()
    try:
        result = installer.verify(args.verify) if args.verify else installer.build(args.archive, args.output, args.fetch_toolchain)
    except (installer.InstallerError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("WINDOWS SETUP FAILED: " + str(error), file=sys.stderr)
        return 1
    print(("Verified: " if args.verify else "Ready: ") + str((args.verify or args.output).resolve()))
    print("SHA256: " + result["sha256"])
    print("EXE bytes: " + str(result["size_bytes"]) + "; installed files: " + str(len(result["files"])))
    print("Every extracted file matches; ordinary-user PE manifest checked. Native Windows startup pending.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
