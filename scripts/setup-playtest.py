#!/usr/bin/env python3
"""Prepare an isolated stock-mod game; never build or install system packages."""
import argparse
import importlib.util
import pathlib
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("playtest_assembly", ROOT / "integrations/playtest/assembly.py")
assembly = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = assembly
spec.loader.exec_module(assembly)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=pathlib.Path, default=assembly.DEFAULT_DESTINATION,
                        help="Game directory beneath runtime/playtest or runtime/tests, named golden_era_playtest")
    parser.add_argument("--no-fetch", action="store_true", help="Require all pinned sources already present")
    parser.add_argument("--verify-only", action="store_true", help="Only verify existing source pins and clean checkouts")
    args = parser.parse_args()
    try:
        if args.verify_only:
            sources = assembly.verify_sources(fetch=False)
            for name, source in sources.items():
                print(name + " " + source["commit"] + " clean")
            return 0
        manifest = assembly.build_game(args.destination, fetch=not args.no_fetch)
    except (assembly.AssemblyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print("PLAYTEST ASSEMBLY FAILED: " + str(error), file=sys.stderr)
        return 1
    for patch in manifest["runtime_copy_patches"]:
        print("Runtime-copy patch: " + patch)
    print("Ready: " + str(args.destination.resolve()))
    print("Sources and patches: " + str(args.destination.resolve() / "playtest-sources.json"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
