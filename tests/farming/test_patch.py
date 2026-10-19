#!/usr/bin/env python3
"""Check farming copy-only source anchors, repeatability and upstream isolation."""
import hashlib
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("elepower_farming_patch", ROOT / "integrations/playtest/elepower.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class FarmingPatch(unittest.TestCase):
    def fixture(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="farming-patch-", dir=base)
        self.addCleanup(temporary.cleanup)
        copied = Path(temporary.name) / "elepower"
        shutil.copytree(ROOT / "upstream/elepower", copied, ignore=shutil.ignore_patterns(".git"))
        return copied

    def test_repeatable_copy_leaves_upstream_unchanged(self):
        source = ROOT / "upstream/elepower"
        before = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in source.rglob("*.lua") if ".git" not in p.parts}
        copied = self.fixture()
        changes = PATCH.apply(copied)
        self.assertTrue(any("harvester overflow" in item for item in changes))
        path = copied / "elepower_farming/machines/harvester.lua"
        first = path.read_bytes()
        self.assertEqual(PATCH.apply(copied), [])
        self.assertEqual(path.read_bytes(), first)
        self.assertEqual(before, {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in source.rglob("*.lua") if ".git" not in p.parts})

    def test_changed_native_output_contract_requires_review(self):
        copied = self.fixture()
        path = copied / "elepower_farming/machines/harvester.lua"
        old = 'if inv:room_for_item("dst", stack) then'
        self.assertEqual(path.read_text().count(old), 1)
        path.write_text(path.read_text().replace(old, 'if inv:room_for_item("different", stack) then', 1))
        with self.assertRaisesRegex(ValueError, "Unexpected Elepower source"):
            PATCH.apply(copied)


if __name__ == "__main__":
    unittest.main()
