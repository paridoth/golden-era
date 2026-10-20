#!/usr/bin/env python3
"""Check pinned state-button repair, behavior, repeatability and copy isolation."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("state_patch", ROOT / "integrations/playtest/elepower.py")
PATCH = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATCH)


class MachineStatePatch(unittest.TestCase):
    def fixture(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="state-patch-", dir=base)
        self.addCleanup(temporary.cleanup)
        copied = Path(temporary.name) / "elepower"
        shutil.copytree(ROOT / "upstream/elepower", copied, ignore=shutil.ignore_patterns(".git"))
        return copied

    def test_actual_helper_reaches_every_state_independent_of_table_order(self):
        copied = self.fixture()
        source = ROOT / "upstream/elepower/elepower_papi/machine.lua"
        before = source.read_bytes()
        changes = PATCH.apply(copied)
        self.assertTrue(any("every supported machine state" in item for item in changes))
        path = copied / "elepower_papi/machine.lua"
        result = subprocess.run([str(ROOT / "tools/root/usr/bin/lua5.1"),
                                 str(ROOT / "tests/machine-state/test_switch.lua"), str(path)],
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Machine state switch tests passed", result.stdout)
        patched = path.read_bytes()
        self.assertEqual(PATCH.apply(copied), [])
        self.assertEqual(path.read_bytes(), patched)
        self.assertEqual(source.read_bytes(), before)

    def test_changed_switch_contract_requires_review(self):
        copied = self.fixture()
        path = copied / "elepower_papi/machine.lua"
        old = "state = state + 1"
        self.assertEqual(path.read_text().count(old), 1)
        path.write_text(path.read_text().replace(old, "state = state + 2", 1))
        with self.assertRaisesRegex(ValueError, "Unexpected Elepower source"):
            PATCH.apply(copied)


if __name__ == "__main__":
    unittest.main()
