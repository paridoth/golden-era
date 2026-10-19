#!/usr/bin/env python3
"""Protect frozen release paths using tiny fixtures, without building real releases."""
from contextlib import ExitStack
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import zipfile

PROJECT = Path(__file__).resolve().parents[2]


def module(name, relative):
    spec = importlib.util.spec_from_file_location(name, PROJECT / relative)
    loaded = importlib.util.module_from_spec(spec)
    sys.modules[name] = loaded
    spec.loader.exec_module(loaded)
    return loaded


game = module("guard_game_packager", "packaging/playtest/packager.py")
installer = module("guard_windows_packager", "packaging/playtest/installer.py")
linux = module("guard_linux_packager", "packaging/linux/packager.py")


class ReachedPipeline(Exception):
    pass


class ReleaseGuardTests(unittest.TestCase):
    def setUp(self):
        temporary = PROJECT / "runtime/tests"
        temporary.mkdir(parents=True, exist_ok=True)
        self.work = Path(self.enterContext(tempfile.TemporaryDirectory(prefix="release-guard-", dir=temporary)))
        self.root = self.work / "repo"
        self.root.mkdir()
        for loaded in (game, installer, linux, linux.base):
            self.enterContext(mock.patch.object(loaded, "ROOT", self.root))

    def write(self, relative, data=b"previous release bytes"):
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return target

    def freeze(self, output, legacy=False):
        entry = {"artifact": output.relative_to(self.root).as_posix(), "sha256": "a" * 64}
        record = {"version": "fixture", **entry} if legacy else {"version": "fixture", "artifacts": {"fixture": entry}}
        self.write("docs/releases/fixture.json", json.dumps(record).encode())

    def old_outputs(self, relative):
        output = self.root / relative
        before = {}
        for path in game._artifact_outputs(output):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(("preserved " + path.name).encode())
            before[path] = path.read_bytes()
        return output, before

    def assert_preserved(self, before):
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data, str(path))

    def tiny_game_build(self, output, before_promotion=None):
        supplement = self.root / "empty-supplement"
        supplement.mkdir(exist_ok=True)
        assembly = SimpleNamespace(AssemblyError=RuntimeError, verify_sources=lambda fetch: {},
                                   build_game=lambda destination, fetch: {"fixture": True})

        def collect_game(destination, sources, revision, payloads):
            game._add(payloads, "games/golden_era_playtest/init.lua", b"-- tiny release guard fixture\n", {"origin": "fixture"})

        def collect_project(revision, payloads):
            if before_promotion:
                before_promotion()

        with ExitStack() as patches:
            patches.enter_context(mock.patch.object(game, "_module", return_value=assembly))
            patches.enter_context(mock.patch.object(game, "_collect_game", side_effect=collect_game))
            patches.enter_context(mock.patch.object(game, "_collect_project", side_effect=collect_project))
            patches.enter_context(mock.patch.object(game, "_supplement", return_value=(supplement, {})))
            patches.enter_context(mock.patch.object(game.subprocess, "check_output", return_value="fixture-revision\n"))
            return game.build_package(output)

    def linux_inputs(self):
        reference = b"local test reference\n"
        self.write("packaging/linux/templates/Install Luanti.flatpakref", reference)
        self.write("packaging/linux/engine-reference.json", json.dumps({"flatpakref_sha256": hashlib.sha256(reference).hexdigest()}).encode())
        self.write("scripts/package-linux.py", b"# fixture source\n")
        self.write("docs/linux-release.md", b"Fixture build instructions\n")

    def test_all_three_formats_and_companions_are_reserved(self):
        for name in ("frozen.zip", "frozen.exe", "frozen.tar.gz"):
            with self.subTest(name=name):
                output, before = self.old_outputs("dist/" + name)
                self.freeze(output)
                for destination in game._artifact_outputs(output):
                    with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
                        game.check_release_output(destination)
                self.assert_preserved(before)

    def test_legacy_nested_and_list_records(self):
        names = ("dist/legacy.exe", "dist/fallback.zip", "dist/additional.tar.gz")
        record = {"version": "0.1.0", "artifact": names[0], "zip_fallback": {"artifact": names[1]},
                  "additional": [{"artifact": names[2]}]}
        self.write("docs/releases/legacy.json", json.dumps(record).encode())
        for name in names:
            with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
                game.check_release_output(self.root / name)

    def test_missing_registered_file_is_still_reserved(self):
        output = self.root / "dist/missing.zip"
        self.freeze(output, legacy=True)
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            game.check_release_output(output)
        self.assertFalse(output.parent.exists())

    def test_alternate_output_with_existing_unregistered_files_remains_allowed(self):
        frozen = self.root / "dist/frozen.zip"
        self.freeze(frozen)
        alternate, before = self.old_outputs("runtime/tests/repro.zip")
        game.check_release_output(alternate)
        self.assert_preserved(before)

    def test_zip_manifest_collision_with_frozen_linux_and_exe(self):
        for name in ("frozen.tar.gz", "frozen.exe"):
            with self.subTest(name=name):
                frozen, before = self.old_outputs("dist/" + name)
                self.freeze(frozen)
                alternate = self.root / ("dist/" + name + ".zip")
                with self.assertRaisesRegex(game.PackageError, "manifest.json"):
                    game.check_release_output(alternate)
                self.assert_preserved(before)
                self.assertFalse(alternate.exists())

    def test_parent_directory_and_symlink_aliases(self):
        frozen, before = self.old_outputs("dist/frozen.zip")
        self.freeze(frozen)
        (self.root / "alias").mkdir()
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            game.check_release_output(self.root / "alias/../dist/frozen.zip")
        alias = self.root / "alias/output.zip"
        alias.symlink_to(frozen)
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            game.check_release_output(alias)
        alias.unlink()
        alias_manifest = alias.with_suffix(".manifest.json")
        alias_manifest.symlink_to(frozen.with_suffix(".manifest.json"))
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            game.check_release_output(alias)
        self.assert_preserved(before)

    def test_hardlinked_sidecar_alias_is_refused(self):
        frozen, before = self.old_outputs("dist/frozen.zip")
        self.freeze(frozen)
        alias = self.root / "alternate.zip"
        alias.with_suffix(".manifest.json").hardlink_to(frozen.with_suffix(".manifest.json"))
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            game.check_release_output(alias)
        self.assert_preserved(before)

    def test_malformed_or_escaping_registry_fails_closed(self):
        values = (b"{", b"{}", b'{"artifact": 3}', b'{"artifact": "."}',
                  b'{"artifact": "../outside.zip"}', b'{"artifact": "/outside.zip"}')
        for value in values:
            with self.subTest(value=value):
                self.write("docs/releases/broken.json", value)
                with self.assertRaisesRegex(game.PackageError, "Cannot read frozen release record"):
                    game.check_release_output(self.root / "alternate.zip")
        (self.root / "docs/releases/broken.json").unlink()
        with self.assertRaisesRegex(game.PackageError, "inside the repository"):
            game.check_release_output(self.work / "outside.zip")

    def test_zip_api_rejects_default_before_assembly_or_download(self):
        output, before = self.old_outputs("dist/golden-era-playtest-" + game.VERSION + "-windows-test.zip")
        self.freeze(output)
        with mock.patch.object(game, "_module", side_effect=AssertionError("assembly reached")), \
                mock.patch.object(game, "_supplement", side_effect=AssertionError("download reached")):
            with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
                game.build_package(fetch_supplements=True)
        self.assert_preserved(before)
        self.assertFalse((self.root / "runtime").exists())

    def test_exe_api_rejects_default_before_input_verification_or_toolchain(self):
        output, before = self.old_outputs("dist/frozen.exe")
        self.freeze(output)
        with mock.patch.object(installer, "packager", return_value=game), \
                mock.patch.object(installer.build, "__defaults__", (self.root / "missing.zip", output, False)), \
                mock.patch.object(game, "verify_package", side_effect=AssertionError("input reached")), \
                mock.patch.object(installer, "toolchain", side_effect=AssertionError("toolchain reached")):
            with self.assertRaisesRegex(installer.InstallerError, "Frozen release output"):
                installer.build(fetch=True)
        self.assert_preserved(before)
        self.assertFalse((self.root / "runtime").exists())

    def test_linux_api_rejects_default_from_input_version_before_assembly(self):
        output, before = self.old_outputs("dist/golden-era-playtest-old-version-linux.tar.gz")
        self.freeze(output)
        archive = self.root / "tiny-input.zip"
        with zipfile.ZipFile(archive, "w") as zipped:
            zipped.writestr(linux.BUNDLE + "/" + linux.MANIFEST, json.dumps({"version": "old-version", "files": []}))
        with mock.patch.object(linux.base, "verify_package", side_effect=AssertionError("input verification reached")):
            with self.assertRaisesRegex(linux.PackageError, "Frozen release output"):
                linux.build_package(archive)
        self.assert_preserved(before)
        self.assertFalse((self.root / "runtime").exists())

    def test_explicit_sidecar_collision_is_rejected_by_zip_api_before_assembly(self):
        frozen, before = self.old_outputs("dist/frozen.tar.gz")
        self.freeze(frozen)
        with mock.patch.object(game, "_module", side_effect=AssertionError("assembly reached")):
            with self.assertRaisesRegex(game.PackageError, "manifest.json"):
                game.build_package(self.root / "dist/frozen.tar.gz.zip")
        self.assert_preserved(before)

    def test_alternate_apis_reach_their_normal_pipeline(self):
        self.freeze(self.root / "dist/frozen.zip")
        with mock.patch.object(game, "_module", side_effect=ReachedPipeline):
            with self.assertRaises(ReachedPipeline):
                game.build_package(self.root / "alternate.zip")
        with mock.patch.object(installer, "packager", return_value=game), \
                mock.patch.object(game, "verify_package", side_effect=ReachedPipeline):
            with self.assertRaises(ReachedPipeline):
                installer.build(self.root / "input.zip", self.root / "alternate.exe")
        self.linux_inputs()
        with mock.patch.object(linux.base, "verify_package", side_effect=ReachedPipeline):
            with self.assertRaises(ReachedPipeline):
                linux.build_package(self.root / "input.zip", self.root / "alternate.tar.gz")

    def test_tiny_alternate_zip_build_and_verification_succeed(self):
        self.freeze(self.root / "dist/frozen.zip")
        output, _ = self.old_outputs("runtime/tests/repro.zip")
        result = self.tiny_game_build(output)
        self.assertEqual(result["archive"], output)
        self.assertGreater(result["files"], 1)
        self.freeze(output)
        self.assertGreater(game.verify_package(output, result["manifest"])["files"], 1)

    def test_zip_registration_during_build_blocks_promotion(self):
        output, before = self.old_outputs("dist/inflight.zip")
        with self.assertRaisesRegex(game.PackageError, "Frozen release output"):
            self.tiny_game_build(output, lambda: self.freeze(output))
        self.assert_preserved(before)
        self.assertFalse(list(output.parent.glob(".package-playtest-*")))

    def test_linux_registration_during_build_blocks_promotion(self):
        archive = self.root / "tiny-input.zip"
        self.tiny_game_build(archive)
        self.linux_inputs()
        output, before = self.old_outputs("dist/inflight.tar.gz")

        def revision(*args, **kwargs):
            self.freeze(output)
            return "fixture-revision\n"

        with mock.patch.object(linux.subprocess, "check_output", side_effect=revision):
            with self.assertRaisesRegex(linux.PackageError, "Frozen release output"):
                linux.build_package(archive, output)
        self.assert_preserved(before)
        self.assertFalse(list(output.parent.glob(".linux-package-*")))

    def test_exe_registration_during_compile_blocks_promotion(self):
        archive = self.root / "tiny-input.zip"
        self.tiny_game_build(archive)
        output, before = self.old_outputs("dist/inflight.exe")
        plugin = {"size": 1, "sha256": "plugin-fixture"}
        lock = {"files": {"usr/share/nsis/Plugins/x86-unicode/System.dll": plugin}}

        def support(destination, archive):
            source = destination / "source/packaging/playtest/installer.nsi"
            source.parent.mkdir(parents=True)
            source.write_bytes(b"fixture compiler input\n")

        def compile_fixture(command, **kwargs):
            staged = Path(next(value[len("-DGE_OUTPUT="):] for value in command if value.startswith("-DGE_OUTPUT=")))
            staged.write_bytes(b"not a real installer; guard fixture only")
            self.freeze(output)

        def extracted(executable, directory):
            work = executable.parent
            expected = installer.file_records(work / "payload" / game.BUNDLE)
            expected.update({installer.SUPPORT + "/" + name: value for name, value in installer.file_records(work / "support").items()})
            return expected | {"$PLUGINSDIR/System.dll": plugin}

        with ExitStack() as patches:
            patches.enter_context(mock.patch.object(installer, "packager", return_value=game))
            patches.enter_context(mock.patch.object(installer, "toolchain", return_value=("fixture-compiler", {}, lock)))
            patches.enter_context(mock.patch.object(installer, "support_files", side_effect=support))
            patches.enter_context(mock.patch.object(installer.subprocess, "run", side_effect=compile_fixture))
            patches.enter_context(mock.patch.object(installer, "verify_pe"))
            patches.enter_context(mock.patch.object(installer, "extracted_records", side_effect=extracted))
            with self.assertRaisesRegex(installer.InstallerError, "Frozen release output"):
                installer.build(archive, output)
        self.assert_preserved(before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
