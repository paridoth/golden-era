#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check 1.12 texture names and that converted art never lands in the repository."""
import io
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
import zipfile

try:
    from PIL import Image
except ImportError:  # CI has no Pillow; the converter checks then skip, the rest still run.
    Image = None

ROOT = Path(__file__).resolve().parents[2]
CONVERT = ROOT / "integrations/playtest/textures/convert.py"
INSTALL = CONVERT.with_name("install.py")
PWSH = ROOT / "tools/powershell-7.6.7/pwsh"
sys.path.insert(0, str(CONVERT.parent))
import mc112  # noqa: E402
import install  # noqa: E402
import mods112  # noqa: E402


def png(color):
    if Image is None:
        return b"\x89PNG stand-in %d" % color
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


@unittest.skipIf(Image is None, "Pillow is not installed")
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
            base, cutout = mods112.LOGISTICA["logistica_access_point_front.png"]
            archive.writestr("assets/" + base, png(4))
            light = io.BytesIO()
            Image.new("RGBA", (16, 16), (0, 0, 0, 0)).save(light, "PNG")
            archive.writestr("assets/" + cutout, light.getvalue())
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
            with Image.open(made / "logistica_access_point_front.png") as layered:
                self.assertEqual(layered.size, (32, 32), "Cutouts are scaled onto their base")
            self.assertIn(" + ", (made / "conversion-report.txt").read_text())
            self.assertIn("Do not redistribute", (made / "description.txt").read_text())
            refused = subprocess.run([sys.executable, str(CONVERT), str(pack), "--output", str(ROOT / "runtime")],
                                     capture_output=True, text=True)
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn("Refusing", refused.stderr)
            self.assertFalse((ROOT / "runtime/golden_era_converted").exists())


class Install(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.temp = Path(temp.name)
        self.pack = self.temp / "converted/golden_era_test"
        self.pack.mkdir(parents=True)
        (self.pack / "description.txt").write_text(install.MARKER + " for personal use.\n")
        (self.pack / "default_stone.png").write_bytes(png(3))
        self.data = self.temp / "save"
        self.data.mkdir()
        self.settings = self.data / "settings.conf"
        self.settings.write_text("golden_era_settings = 2\ntexture_path = /old/pack\nfps_max = 60\n")

    def run_install(self, *args):
        env = dict(os.environ, GOLDEN_ERA_DATA_DIR=str(self.data))
        return subprocess.run([sys.executable, str(INSTALL), *args], capture_output=True, text=True, env=env)

    def test_install_and_remove(self):
        result = self.run_install(str(self.pack))
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.data / "textures/golden_era_test"
        self.assertTrue((target / "default_stone.png").is_file())
        self.assertEqual(self.settings.read_text(),
                         "golden_era_settings = 2\nfps_max = 60\ntexture_path = " + str(target) + "\n")
        self.assertEqual(self.run_install(str(self.pack)).returncode, 0, "Reinstalling replaces the old copy")
        result = self.run_install("--remove")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.settings.read_text(), "golden_era_settings = 2\nfps_max = 60\n")

    def test_refusals(self):
        other = self.data / "textures/golden_era_test"
        other.mkdir(parents=True)
        (other / "mine.png").write_bytes(png(1))
        self.assertNotEqual(self.run_install(str(self.pack)).returncode, 0, "Never replace a folder we did not make")
        self.assertTrue((other / "mine.png").is_file())
        self.assertNotEqual(self.run_install(str(self.temp)).returncode, 0, "Only converted packs install")
        result = self.run_install(str(self.pack), "--windows-zip", str(ROOT / "runtime/textures.zip"))
        self.assertIn("Refusing", result.stderr)
        self.assertFalse((ROOT / "runtime/textures.zip").exists())
        self.settings.unlink()
        self.assertIn("not been started", self.run_install("--remove").stderr)

    def test_windows_zip(self):
        output = self.temp / "windows.zip"
        result = self.run_install(str(self.pack), "--windows-zip", str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        with zipfile.ZipFile(output) as archive:
            self.assertEqual(sorted(archive.namelist()),
                             ["README.txt", "golden_era_test/default_stone.png", "golden_era_test/description.txt",
                              "install-textures.bat", "use-default-textures.bat"])
            batch = archive.read("install-textures.bat").decode()
        self.assertNotIn("{", batch.split("powershell.exe")[0], "Every placeholder is filled")
        self.assertIn("\r\n", batch)
        self.assertIn('xcopy "%~dp0golden_era_test" "%GE_TARGET%\\"', batch)
        command = re.search(r'powershell\.exe -NoProfile -Command "(.*)"\r\nif errorlevel 1 goto failed', batch).group(1)
        self.assertEqual(command, install.WINDOWS_SETTINGS)
        self.assertNotIn('"', command)
        self.assertNotIn("%", command)

    @unittest.skipUnless(PWSH.is_file(), "pinned PowerShell not extracted")
    def test_windows_settings_edit(self):
        env = dict(os.environ, GE_DATA=str(self.data), GE_TARGET="C:\\Users\\me\\golden_era_test")
        subprocess.run([str(PWSH), "-NoProfile", "-Command", install.WINDOWS_SETTINGS], env=env, check=True)
        self.assertEqual(self.settings.read_text().splitlines(),
                         ["golden_era_settings = 2", "fps_max = 60", "texture_path = C:\\Users\\me\\golden_era_test"])
        del env["GE_TARGET"]
        subprocess.run([str(PWSH), "-NoProfile", "-Command", install.WINDOWS_SETTINGS], env=env, check=True)
        self.assertEqual(self.settings.read_text().splitlines(), ["golden_era_settings = 2", "fps_max = 60"])


if __name__ == "__main__":
    unittest.main()
