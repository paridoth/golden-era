#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check 1.12 texture names and that converted art never lands in the repository."""
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CONVERT = ROOT / "integrations/playtest/textures/convert.py"
sys.path.insert(0, str(CONVERT.parent))
import mc112  # noqa: E402
import mods112  # noqa: E402


def png(color):
    data = io.BytesIO()
    Image.new("P", (32, 32), color).save(data, "PNG")
    return data.getvalue()


class Names(unittest.TestCase):
    def test_flattening_renames(self):
        cases = {"blocks/wool_colored_silver.png": "block/light_gray_wool.png",
                 "blocks/planks_big_oak.png": "block/dark_oak_planks.png",
                 "blocks/log_birch_top.png": "block/birch_log_top.png",
                 "blocks/stonebrick_mossy.png": "block/mossy_stone_bricks.png",
                 "blocks/glass_pane_top_red.png": "block/red_stained_glass_pane_top.png",
                 "blocks/wheat_stage_7.png": "block/wheat_stage7.png",
                 "items/gold_pickaxe.png": "item/golden_pickaxe.png",
                 "items/dye_powder_silver.png": "item/light_gray_dye.png",
                 "items/record_cat.png": "item/music_disc_cat.png",
                 "entity/llama/llama_brown.png": "entity/llama/brown.png",
                 "blocks/water_still.png.mcmeta": "block/water_still.png.mcmeta"}
        for old, new in cases.items():
            self.assertEqual(mc112.modern(old)[0], new, old)

    def test_aliases_and_left_out_skins(self):
        self.assertEqual(mc112.modern("items/dye_powder_black.png"), ["item/ink_sac.png", "item/black_dye.png"])
        self.assertEqual(mc112.modern("blocks/carrots.png"), ["block/carrots.png", "block/carrots_stage3.png"])
        self.assertEqual(mc112.modern("entity/zombie_pigman.png"), ["entity/zombie_pigman.png"])


class ModMappings(unittest.TestCase):
    def test_every_target_is_a_golden_era_texture(self):
        names = {path.name for path in (ROOT / "upstream").rglob("*.png")}
        self.assertEqual([texture for texture in mods112.MAPPINGS if texture not in names], [])

    def test_tinted_textures_are_left_out(self):
        for tinted in ["elepower_dust.png", "elepower_gear.png", "elepower_plate.png"]:
            self.assertNotIn(tinted, mods112.MAPPINGS)


class Convert(unittest.TestCase):
    def pack(self, folder):
        path = folder / "pack.zip"
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("pack.mcmeta", "{}")
            archive.writestr("assets/minecraft/textures/blocks/stonebrick_mossy.png", png(5))
            archive.writestr("assets/minecraft/textures/items/bucket_empty.png", png(9))
            strip = io.BytesIO()
            Image.new("RGBA", (32, 128), (1, 2, 3, 255)).save(strip, "PNG")
            archive.writestr("assets/" + mods112.ELEPOWER["elepower_furnace_active.png"], strip.getvalue())
        return path

    def test_converts_outside_and_refuses_repository(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            pack = self.pack(temp)
            result = subprocess.run([sys.executable, str(CONVERT), str(pack), "--output", str(temp / "out")],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            made = temp / "out/golden_era_converted"
            self.assertEqual(Image.open(made / "mcl_core_stonebrick_mossy.png").mode, "RGBA")
            self.assertTrue((made / "bucket.png").is_file())
            self.assertEqual(Image.open(made / "elepower_furnace_active.png").size, (32, 32))
            self.assertIn("Do not redistribute", (made / "description.txt").read_text())
            refused = subprocess.run([sys.executable, str(CONVERT), str(pack), "--output", str(ROOT / "runtime")],
                                     capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("Refusing", refused.stderr)
            self.assertFalse((ROOT / "runtime/golden_era_converted").exists())


if __name__ == "__main__":
    unittest.main()
