#!/usr/bin/env python3
"""Build identity uses the project's source state, including untracked inputs."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    loaded = importlib.util.module_from_spec(spec)
    sys.modules[name] = loaded
    spec.loader.exec_module(loaded)
    return loaded


assembly = module("build_info_assembly", "integrations/playtest/assembly.py")
packager = module("build_info_packager", "packaging/playtest/packager.py")


class BuildInfoTests(unittest.TestCase):
    def setUp(self):
        base = ROOT / "runtime/tests"
        base.mkdir(parents=True, exist_ok=True)
        self.work = Path(self.enterContext(tempfile.TemporaryDirectory(prefix="build-info-", dir=base)))
        self.root = self.work / "source"
        self.write("packaging/playtest/release.json", '{"version":"9.8.7"}\n')
        self.write(".gitignore", "/runtime/\n")
        self.write("source.lua", "-- committed fixture\n")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("-c", "user.name=Build Test", "-c", "user.email=build-test@example.invalid",
                 "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
                 "commit", "--quiet", "-m", "Fixture")
        self.revision = self.git("rev-parse", "HEAD")

    def write(self, relative, content, root=None):
        target = (root or self.root) / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        return target

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args],
                                       text=True, stderr=subprocess.STDOUT).strip()

    def test_clean_record_is_reproducible_and_uses_main_revision(self):
        expected = {"version": "9.8.7", "revision": self.revision, "dirty": False, "source": "git"}
        self.assertEqual(assembly._build_info(self.root), expected)
        self.assertEqual(assembly._build_info(self.root), expected)

    def test_unstaged_and_staged_edits_are_development_builds(self):
        self.write("source.lua", "-- local edit\n")
        self.assertTrue(assembly._build_info(self.root)["dirty"])
        self.git("add", "source.lua")
        self.assertTrue(assembly._build_info(self.root)["dirty"])
        self.assertEqual(assembly._build_info(self.root)["revision"], self.revision)

    def test_relevant_untracked_file_is_development_build(self):
        self.write("mod/new.lua", "-- relevant untracked source\n")
        self.assertTrue(assembly._build_info(self.root)["dirty"])

    def test_ignored_runtime_data_does_not_change_source_status(self):
        self.write("runtime/world/player-data", "saved game, not source\n")
        self.assertFalse(assembly._build_info(self.root)["dirty"])

    def test_export_inside_parent_git_does_not_borrow_revision(self):
        exported = self.root / "exported"
        self.write("packaging/playtest/release.json", '{"version":"9.8.7"}\n', root=exported)
        with mock.patch.object(assembly, "_git", side_effect=AssertionError("Do not inspect parent Git")):
            self.assertEqual(assembly._build_info(exported), {
                "version": "9.8.7", "revision": None, "dirty": None, "source": "source_snapshot"})

    def test_worktree_git_file_is_supported(self):
        worktree = self.work / "worktree"
        self.git("worktree", "add", "--quiet", "--detach", str(worktree), "HEAD")
        self.assertTrue((worktree / ".git").is_file())
        self.assertEqual(assembly._build_info(worktree), {
            "version": "9.8.7", "revision": self.revision, "dirty": False, "source": "git"})

    def test_unavailable_or_failed_git_does_not_claim_clean_source(self):
        for error in (FileNotFoundError("git unavailable"),
                      subprocess.CalledProcessError(128, ["git"])):
            with self.subTest(error=type(error).__name__):
                with mock.patch.object(assembly, "_git", side_effect=error):
                    self.assertEqual(assembly._build_info(self.root), {
                        "version": "9.8.7", "revision": None, "dirty": None, "source": "source_snapshot"})

    def test_invalid_release_version_stops_assembly(self):
        self.write("packaging/playtest/release.json", '{"version":"unreviewed;formspec]"}\n')
        with self.assertRaisesRegex(assembly.AssemblyError, "Invalid playtest release version"):
            assembly._build_info(self.root)

    def test_generated_record_is_packaged_with_project_provenance(self):
        game = self.root / "game"
        game.mkdir()
        data = json.dumps(assembly._build_info(self.root), indent=2) + "\n"
        (game / "build-info.json").write_text(data)
        payloads = {}
        with mock.patch.object(packager, "ROOT", self.root):
            packager._collect_game(game, {}, self.revision, payloads)
        record = payloads["games/golden_era_playtest/build-info.json"]
        self.assertEqual(record.data, data.encode())
        self.assertEqual(record.provenance["origin"], "golden-era-project")
        self.assertEqual(record.provenance["revision"], self.revision)
        self.assertEqual(record.provenance["source_path"], "integrations/playtest/assembly.py")
        self.assertTrue(record.provenance["generated"])


if __name__ == "__main__":
    unittest.main()
