#!/usr/bin/env python3
"""Isolate the historical upgrade verifier's frozen-release pin check."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("storage_upgrade", ROOT / "tests/storage/upgrade.py")
UPGRADE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(UPGRADE)


class FrozenUpgradeInput(unittest.TestCase):
    def setUp(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        temporary = tempfile.TemporaryDirectory(prefix="upgrade-input-pin-", dir=base)
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.archive = self.root / "dist/game.zip"
        self.archive.parent.mkdir()
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr(UPGRADE.PACKAGE.BUNDLE + "/" + UPGRADE.PACKAGE.MANIFEST,
                             json.dumps({"version": "0.1.3", "files": []}))
        self.record = {"version": "0.1.3", "frozen": True, "artifacts": {"game_zip": {
            "artifact": "dist/game.zip", "size_bytes": self.archive.stat().st_size,
            "sha256": UPGRADE.sha(self.archive),
        }}}
        (self.root / "docs/releases").mkdir(parents=True)
        self.save_registry()
        self.save_checksum()
        root_patch = mock.patch.object(UPGRADE, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        # These tiny fixtures isolate the new pin; real archive manifests/CRCs
        # are independently exercised by verify_archive on both release inputs.
        payload_patch = mock.patch.object(UPGRADE.PACKAGE, "verify_package", return_value={})
        payload_patch.start()
        self.addCleanup(payload_patch.stop)

    def save_registry(self):
        (self.root / "docs/releases/0.1.3.json").write_text(json.dumps(self.record))

    def save_checksum(self):
        self.archive.with_suffix(".zip.sha256").write_text(UPGRADE.sha(self.archive) + "  game.zip\n")

    def test_matching_frozen_registry_accepts(self):
        self.assertEqual(UPGRADE.verify_archive(self.archive, "0.1.3")["sha256"], self.record["artifacts"]["game_zip"]["sha256"])

    def test_tampered_registry_rejects_path_size_hash_and_unfrozen_release(self):
        for field, value in (("artifact", "dist/other.zip"), ("size_bytes", 1), ("sha256", "0" * 64)):
            with self.subTest(field=field):
                original = self.record["artifacts"]["game_zip"][field]
                self.record["artifacts"]["game_zip"][field] = value
                self.save_registry()
                with self.assertRaisesRegex(RuntimeError, "frozen release registry"):
                    UPGRADE.verify_archive(self.archive, "0.1.3")
                self.record["artifacts"]["game_zip"][field] = original
        self.record["frozen"] = False
        self.save_registry()
        with self.assertRaisesRegex(RuntimeError, "Expected frozen release registry"):
            UPGRADE.verify_archive(self.archive, "0.1.3")

    def test_changed_archive_with_refreshed_sidecar_still_rejects_frozen_hash(self):
        with self.archive.open("ab") as archive:
            archive.write(b"changed archive")
        self.save_checksum()
        self.record["artifacts"]["game_zip"]["size_bytes"] = self.archive.stat().st_size
        self.save_registry()
        with self.assertRaisesRegex(RuntimeError, "size/SHA256 differs from frozen release registry"):
            UPGRADE.verify_archive(self.archive, "0.1.3")


if __name__ == "__main__":
    unittest.main()
