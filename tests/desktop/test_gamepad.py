#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Meaningful patch isolation checks plus compiled cursor behavior tests."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "integrations/desktop"))
from gamepad import PINNED, apply_gamepad_patch  # noqa: E402


class ControllerPatchTests(unittest.TestCase):
    def setUp(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="controller-test-", dir=base)
        self.stage = Path(self.temp.name)
        for name in PINNED:
            path = self.stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / "upstream/luanti" / name, path)

    def tearDown(self):
        self.temp.cleanup()

    def snapshot(self):
        return {p.relative_to(self.stage).as_posix(): p.read_bytes()
                for p in self.stage.rglob("*") if p.is_file()}

    def test_applies_once_without_changing_upstream(self):
        changed = apply_gamepad_patch(self.stage)
        self.assertEqual(len(changed), 4)
        first = self.snapshot()
        self.assertEqual(apply_gamepad_patch(self.stage), [])
        self.assertEqual(self.snapshot(), first)
        for name, digest in PINNED.items():
            self.assertEqual(hashlib.sha256((ROOT / "upstream/luanti" / name).read_bytes()).hexdigest(), digest)

    def test_dirty_last_file_rejected_before_any_write(self):
        (self.stage / "src/gui/guiButtonKey.h").write_text("unexpected version")
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Unexpected copied"):
            apply_gamepad_patch(self.stage)
        self.assertEqual(self.snapshot(), before)

    def test_upstream_and_git_checkouts_rejected(self):
        with self.assertRaisesRegex(ValueError, "copied"):
            apply_gamepad_patch(ROOT / "upstream/luanti")
        (self.stage / ".git").mkdir()
        with self.assertRaisesRegex(ValueError, "Git checkout"):
            apply_gamepad_patch(self.stage)

    def test_symlink_back_to_upstream_rejected(self):
        target = self.stage / "src/gui/modalMenu.cpp"
        target.unlink()
        target.symlink_to(ROOT / "upstream/luanti/src/gui/modalMenu.cpp")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            apply_gamepad_patch(self.stage)

    def test_modified_existing_patch_rejected(self):
        apply_gamepad_patch(self.stage)
        target = self.stage / "src/gui/goldenEraMenuCursor.h"
        target.write_text(target.read_text() + "\nunreviewed change\n")
        before = self.snapshot()
        with self.assertRaisesRegex(ValueError, "Unexpected copied"):
            apply_gamepad_patch(self.stage)
        self.assertEqual(self.snapshot(), before)

    def test_compiled_cursor_behavior(self):
        binary = self.stage / "cursor-tests"
        subprocess.run(["c++", "-std=c++17", "-Wall", "-Wextra", "-Werror", "-pedantic",
                        "-fsanitize=undefined", "-fno-sanitize-recover=all", "-g",
                        "-I", str(ROOT / "integrations/desktop"),
                        str(ROOT / "tests/desktop/test_gamepad_cursor.cpp"), "-o", str(binary)], check=True)
        subprocess.run([binary], check=True)


if __name__ == "__main__":
    unittest.main()
