#!/usr/bin/env python3
"""Check pinned-source patch anchors, repeatability and upstream isolation."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("pipeworks_patch", ROOT / "integrations/playtest/pipeworks.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class PipeworksPatch(unittest.TestCase):
    def setUp(self):
        self.base = ROOT / "runtime/tests"
        self.base.mkdir(parents=True, exist_ok=True)

    def test_copy_is_repeatable_and_upstream_is_unchanged(self):
        source = ROOT / "upstream/pipeworks"
        files = [source / relative for relative in ("autocrafter.lua", "filter-injector.lua")]
        before = [path.read_bytes() for path in files]
        with tempfile.TemporaryDirectory(dir=self.base) as temporary:
            copied = Path(temporary) / "pipeworks"
            shutil.copytree(source, copied, ignore=shutil.ignore_patterns(".git"))
            self.assertTrue(PATCH.apply(copied))
            first = [(copied / path.relative_to(source)).read_bytes() for path in files]
            self.assertEqual(PATCH.apply(copied), [])
            self.assertEqual(first, [(copied / path.relative_to(source)).read_bytes() for path in files])
        self.assertEqual(before, [path.read_bytes() for path in files])

    def test_changed_anchors_require_review(self):
        for relative,old in (("autocrafter.lua", "on_destruct = invalidate_cache,"),
                             ("filter-injector.lua", 'local use_tags = pipeworks.enable_item_tags'),
                             ("filter-injector.lua", 'name = "pipeworks:give_back_old_filter_items",'),
                             ("filter-injector.lua", 'if put_to_inputinv(pos, node, meta, list) then')):
            with self.subTest(relative=relative, anchor=old), tempfile.TemporaryDirectory(dir=self.base) as temporary:
                copied = Path(temporary) / "pipeworks"
                shutil.copytree(ROOT / "upstream/pipeworks", copied, ignore=shutil.ignore_patterns(".git"))
                path = copied / relative
                self.assertEqual(path.read_text().count(old), 1)
                path.write_text(path.read_text().replace(old, old + " -- changed native contract", 1))
                with self.assertRaisesRegex(ValueError, "Unexpected Pipeworks source"):
                    PATCH.apply(copied)


if __name__ == "__main__":
    unittest.main()
