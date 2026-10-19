#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build an optional Linux controller client without changing pinned upstream.

Requires the existing local development dependencies from scripts/build-client.py.
This prototype is deliberately separate from the normal Windows/Linux launchers.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

from gamepad import PINNED, apply_gamepad_patch

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "runtime/desktop-controller/engine"
BUILD = ROOT / "tools/build-controller"


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--parallel", type=int, default=2)
    args = parser.parse_args()
    if args.parallel < 1:
        parser.error("--parallel must be positive")
    source = ROOT / "upstream/luanti"
    pin = json.loads((ROOT / "upstream.lock.json").read_text())["luanti"]["commit"]
    actual = subprocess.check_output(["git", "-C", source, "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", source, "status", "--porcelain"], text=True).strip()
    if actual != pin or dirty:
        raise SystemExit("Unexpected or dirty pinned Luanti source")
    tracked = [name for name in subprocess.check_output(
        ["git", "-C", source, "ls-files", "-z"]).decode().split("\0") if name]
    marker = STAGE / ".golden-era-controller-source.json"
    provenance = {"source_commit": pin, "variant": "experimental-desktop-controller"}
    if STAGE.exists():
        if not marker.is_file() or json.loads(marker.read_text()) != provenance:
            raise SystemExit("Refusing an unrecognized controller source tree")
    else:
        STAGE.mkdir(parents=True)
        # Copy tracked source/assets only, never the upstream checkout's ignored
        # client databases, downloads, configuration, built binaries or worlds.
        for name in tracked:
            target = STAGE / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, target)
        marker.write_text(json.dumps(provenance, indent=2) + "\n")
    for name in tracked:
        target = STAGE / name
        if target.is_symlink() or not target.resolve().is_relative_to(STAGE):
            raise SystemExit("Unsafe controller source target: " + name)
        if name not in PINNED and (not target.is_file() or target.read_bytes() != (source / name).read_bytes()):
            raise SystemExit("Unexpected copied controller source: " + name)
    allowed = set(tracked) | {".golden-era-controller-source.json", "src/gui/goldenEraMenuCursor.h"}
    for target in STAGE.rglob("*"):
        if not target.is_file():
            continue
        name = target.relative_to(STAGE).as_posix()
        # Run-in-place output/user data may be created after a development run.
        runtime_file = (name.startswith(("bin/", "cache/", "worlds/", "mod_data/")) or
                        name.startswith("client/mod_storage.sqlite"))
        if name not in allowed and not runtime_file:
            raise SystemExit("Unrecognized file in controller source tree: " + name)
    changed = apply_gamepad_patch(STAGE)
    print("Controller source prepared:", STAGE, "changed files:", len(changed), flush=True)
    if args.prepare_only:
        return
    base = ROOT / "tools/root"
    prefix = ROOT / "tools/client-root"
    cmake = base / "usr/bin/cmake"
    for required in (cmake, prefix / "usr/include/freetype2/ft2build.h"):
        if not required.is_file():
            raise SystemExit("Prepare local graphical build dependencies with scripts/build-client.py first")
    env = os.environ.copy()
    env["LD_LIBRARY_PATH"] = (str(prefix / "usr/lib/x86_64-linux-gnu") + ":" +
                              str(base / "usr/lib/x86_64-linux-gnu"))
    include = '-I"' + str(prefix / "usr/include/x86_64-linux-gnu") + '"'
    options = ["-DCMAKE_BUILD_TYPE=Release",
               "-DCMAKE_PREFIX_PATH=" + str(prefix / "usr") + ";" + str(base / "usr"),
               "-DCMAKE_CXX_FLAGS=" + include, "-DCMAKE_C_FLAGS=" + include,
               "-DBUILD_CLIENT=ON", "-DBUILD_SERVER=OFF", "-DBUILD_UNITTESTS=OFF",
               "-DBUILD_DOCUMENTATION=OFF", "-DRUN_IN_PLACE=ON", "-DENABLE_LTO=OFF"]
    for key, library in (("JPEG_LIBRARY", "jpeg"), ("PNG_LIBRARY_RELEASE", "png"),
                         ("FREETYPE_LIBRARY_RELEASE", "freetype")):
        options.append("-D" + key + "=" + str(prefix / ("usr/lib/x86_64-linux-gnu/lib" + library + ".so")))
    options.extend("-DENABLE_" + feature + "=OFF" for feature in
                   ("LUAJIT", "CURL", "GETTEXT", "SOUND", "CURSES", "POSTGRESQL", "LEVELDB",
                    "REDIS", "SPATIAL", "OPENSSL"))
    run([cmake, "-S", STAGE, "-B", BUILD] + options, env=env)
    run([cmake, "--build", BUILD, "--parallel", args.parallel], env=env)
    print("Optional controller prototype ready:", STAGE / "bin/luanti")


if __name__ == "__main__":
    main()
