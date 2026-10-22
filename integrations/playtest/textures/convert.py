#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Convert a tester's own Minecraft 1.12 resource packs into a Luanti texture pack.

Mineclonia's Conversion_Table.csv says which Minecraft file becomes which game
texture; mc112.py supplies the 1.12 names and mods112.py maps mod patches such
as Thermal Expansion onto Golden Era's own mods. Packs are read in place, later packs
override earlier ones, and the result is written outside this repository: the
converted art belongs to the tester and is never committed or packaged.

  python3 integrations/playtest/textures/convert.py PACK.zip [PACK2.zip ...] --output ~/Textures/out
"""
import argparse
import csv
import io
from pathlib import Path
import sys
import zipfile

from PIL import Image

import mc112
import mods112

ROOT = Path(__file__).resolve().parents[3]
TABLE = ROOT / "upstream/mineclonia/tools/Conversion_Table.csv"
PREFIX = "assets/minecraft/textures/"


class Pack:
    """A resource pack as a zip file or an extracted folder."""

    def __init__(self, path):
        self.path = path
        if path.is_dir():
            self.names = [p.relative_to(path).as_posix() for p in path.rglob("*") if p.is_file()]
        else:
            self.zip = zipfile.ZipFile(path)
            self.names = self.zip.namelist()

    def read(self, name):
        return (self.path / name).read_bytes() if self.path.is_dir() else self.zip.read(name)


def sources(packs):
    """Map each 1.13+ texture path to the pack and 1.12 file that supplies it."""
    found = {}
    for pack in packs:
        for name in pack.names:
            if name.startswith(PREFIX) and name.endswith(".png"):
                for modern in mc112.modern(name[len(PREFIX):]):
                    found[modern] = (pack, name)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("packs", nargs="+", type=Path, help="Minecraft 1.12 resource packs, base pack first")
    parser.add_argument("--output", type=Path, required=True, help="Folder to create the texture pack in")
    parser.add_argument("--name", default="golden_era_converted", help="Texture pack folder name")
    args = parser.parse_args()
    target = (args.output.expanduser() / args.name).resolve()
    if target == ROOT or ROOT in target.parents:
        sys.exit("Refusing to write converted textures inside the repository: " + str(target))
    packs = [Pack(path.expanduser()) for path in args.packs]
    found = sources(packs)
    target.mkdir(parents=True, exist_ok=True)
    written, missing = {}, []
    with TABLE.open(newline="") as handle:
        for row in csv.DictReader(handle):
            if row["Blacklisted?"] == "y" or not row["Target file"]:
                continue
            source = (row["Source path"].strip("/") + "/" + row["Source file"])[len(PREFIX):]
            if source not in found:
                missing.append(source)
                continue
            pack, name = found[source]
            # Palette and RGB files load inconsistently between drivers; store RGBA.
            image = Image.open(io.BytesIO(pack.read(name))).convert("RGBA")
            image.save(target / row["Target file"])
            written[row["Target file"]] = name
    files = {}
    for pack in packs:
        files.update({name: pack for name in pack.names})
    for texture, source in sorted(mods112.MAPPINGS.items()):
        name = "assets/" + source
        if name not in files:
            missing.append(name)
            continue
        image = Image.open(io.BytesIO(files[name].read(name))).convert("RGBA")
        if image.height > image.width:
            # Animated 1.12 textures are vertical strips; Golden Era's are still images.
            image = image.crop((0, 0, image.width, image.width))
        image.save(target / texture)
        written[texture] = name
    (target / "description.txt").write_text(
        "Converted locally from the tester's own Minecraft 1.12 resource packs for personal use. "
        "Do not redistribute.\n")
    report = ["# target <- 1.12 source"] + [k + " <- " + v for k, v in sorted(written.items())]
    report += ["", "# sources not found in the packs"] + sorted(set(missing))
    (target / "conversion-report.txt").write_text("\n".join(report) + "\n")
    print("Texture pack:", target)
    print("Textures written:", len(written), "; sources not found in the packs:", len(set(missing)))


if __name__ == "__main__":
    main()
