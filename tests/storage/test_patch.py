#!/usr/bin/env python3
"""Check pinned-source patch anchors, repeatability and upstream isolation."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("drawers_patch", ROOT / "integrations/playtest/drawers.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class DrawersPatch(unittest.TestCase):
    def test_copy_is_repeatable_and_upstream_is_unchanged(self):
        source = ROOT / "upstream/drawers"
        files = [source / relative for relative in ("lua/api.lua", "lua/controller.lua", "lua/visual.lua")]
        before = [path.read_bytes() for path in files]
        with tempfile.TemporaryDirectory() as temporary:
            copied = Path(temporary) / "drawers"
            shutil.copytree(source, copied, ignore=shutil.ignore_patterns(".git"))
            self.assertTrue(PATCH.apply(copied))
            first = [(copied / path.relative_to(source)).read_bytes() for path in files]
            self.assertEqual(PATCH.apply(copied), [])
            self.assertEqual(first, [(copied / path.relative_to(source)).read_bytes() for path in files])
        self.assertEqual(before, [path.read_bytes() for path in files])

    def test_changed_anchor_requires_review(self):
        with tempfile.TemporaryDirectory() as temporary:
            copied = Path(temporary) / "drawers"
            shutil.copytree(ROOT / "upstream/drawers", copied, ignore=shutil.ignore_patterns(".git"))
            path = copied / "lua/visual.lua"
            old = "core.item_drop(itemStack, nil, dropPos)"
            self.assertEqual(path.read_text().count(old), 1)
            path.write_text(path.read_text().replace(old, "core.item_drop(itemStack, nil, differentPos)", 1))
            with self.assertRaisesRegex(ValueError, "Unexpected Drawers source"):
                PATCH.apply(copied)


if __name__ == "__main__":
    unittest.main()
