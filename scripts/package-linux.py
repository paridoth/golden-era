#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package a verified Golden Era game ZIP with Linux launchers, without host binaries."""
import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("linux_packager", ROOT / "packaging/linux/packager.py")
packager = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = packager
spec.loader.exec_module(packager)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-zip", type=Path, help="Existing verified game ZIP; no game assembly or downloads")
    parser.add_argument("--output", type=Path, help="Destination .tar.gz inside the repository")
    parser.add_argument("--verify", type=Path, help="Verify an existing Linux .tar.gz and manifest")
    args = parser.parse_args()
    if args.verify and (args.game_zip or args.output):
        parser.error("--verify cannot be combined with build arguments")
    try:
        if args.verify:
            result = packager.verify_package(args.verify)
        else:
            result = packager.build_package(args.game_zip, args.output)
    except (OSError, ValueError, packager.PackageError) as error:
        print("LINUX PACKAGE FAILED: " + str(error), file=sys.stderr)
        return 1
    for key, value in result.items():
        print(str(key) + ": " + str(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
