#!/usr/bin/env python3
"""Check Elepower copy-only removal patches, pin rejection and repeatability."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("elepower_patch", ROOT / "integrations/playtest/elepower.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class ElepowerPatch(unittest.TestCase):
    def fixture(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="elepower-patch-", dir=base)
        self.addCleanup(temporary.cleanup)
        copied = Path(temporary.name) / "elepower"
        shutil.copytree(ROOT / "upstream/elepower", copied, ignore=shutil.ignore_patterns(".git"))
        return copied

    def test_repeatable_copy_does_not_mutate_upstream(self):
        source = ROOT / "upstream/elepower"
        files = ("elepower_papi/machine.lua", "elepower_tools/soldering.lua")
        before = [(source / relative).read_bytes() for relative in files]
        copied = self.fixture()
        descriptions = PATCH.apply(copied)
        self.assertTrue(any("owned machine inventory" in text for text in descriptions))
        patched = [(copied / relative).read_bytes() for relative in files]
        self.assertEqual(PATCH.apply(copied), [])
        self.assertEqual([(copied / relative).read_bytes() for relative in files], patched)
        self.assertEqual([(source / relative).read_bytes() for relative in files], before)

    def test_changed_guard_contract_requires_pin_review(self):
        copied = self.fixture()
        machine = copied / "elepower_papi/machine.lua"
        old = 'return inv:is_empty("dst") and inv:is_empty("src")'
        self.assertEqual(machine.read_text().count(old), 1)
        machine.write_text(machine.read_text().replace(old, "return true", 1))
        with self.assertRaisesRegex(ValueError, "Unexpected Elepower source"):
            PATCH.apply(copied)

    def test_changed_registration_contract_requires_pin_review(self):
        copied = self.fixture()
        machine = copied / "elepower_papi/machine.lua"
        old = "if not nodedef.can_dig then nodedef.can_dig = can_dig end"
        self.assertEqual(machine.read_text().count(old), 1)
        machine.write_text(machine.read_text().replace(old, "nodedef.can_dig = can_dig", 1))
        with self.assertRaisesRegex(ValueError, "Unexpected Elepower source"):
            PATCH.apply(copied)

    def test_changed_soldering_cleanup_requires_pin_review(self):
        copied = self.fixture()
        soldering = copied / "elepower_tools/soldering.lua"
        old = "minetest.register_on_leaveplayer(function(player)"
        self.assertEqual(soldering.read_text().count(old), 1)
        soldering.write_text(soldering.read_text().replace(old, "minetest.register_on_leaveplayer(function(actor)", 1))
        with self.assertRaisesRegex(ValueError, "Unexpected Elepower source"):
            PATCH.apply(copied)


if __name__ == "__main__":
    unittest.main()
