# SPDX-License-Identifier: GPL-3.0-or-later
"""Reference provenance and cache integrity checks; no network or pack execution."""
import copy
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('reference', ROOT / 'scripts/reference.py')
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


def manifest():
    data = b'example config'
    return {'parent': 35, 'id': 12180, 'name': '3.7.0', 'targets': [
        {'name': 'minecraft', 'version': '1.12.2', 'type': 'game', 'updated': 0}], 'files': [{
            'id': 1, 'type': 'config', 'size': len(data), 'url': 'https://example.test/config',
            'mirrors': ['https://example.test/mirror'], 'clientonly': False, 'serveronly': False,
            'optional': False, 'path': './config/', 'name': 'example.cfg',
            'sha1': hashlib.sha1(data).hexdigest(), 'hashes': {'sha256': hashlib.sha256(data).hexdigest()},
        }]}


class ReferenceTests(unittest.TestCase):
    def test_reject_unsafe_archive_paths(self):
        for directory, name in [('../outside/', 'x'), ('/absolute/', 'x'), ('./config/', '../x'),
                                ('./config/', '/x'), ('./config/', 'x\\y'), ('..\\outside', 'x')]:
            with self.subTest(directory=directory, name=name), self.assertRaises(ValueError):
                reference.relative_file({'path': directory, 'name': name})

    def test_pin_rejects_wrong_identity_duplicates_and_missing_hashes(self):
        for mutation in ('identity', 'duplicate', 'hash'):
            value = manifest()
            if mutation == 'identity':
                value['id'] = 123
            elif mutation == 'duplicate':
                value['files'].append(copy.deepcopy(value['files'][0]))
            else:
                value['files'][0]['hashes'] = {}
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                reference.content_from_manifest(value)

    def test_usage_counters_do_not_change_content_pin(self):
        value = manifest()
        before = reference.content_from_manifest(value)
        value.update(plays=100, installs=200, updated=123, refreshed=456)
        value['targets'][0]['updated'] = 789
        self.assertEqual(before, reference.content_from_manifest(value))

    def test_changed_artifact_bytes_change_content_pin(self):
        value = manifest()
        before = reference.sha256(reference.canonical(reference.content_from_manifest(value)))
        value['files'][0]['hashes']['sha256'] = 'f' * 64
        after = reference.sha256(reference.canonical(reference.content_from_manifest(value)))
        self.assertNotEqual(before, after)

    def test_selection_excludes_mislabeled_mod_cache(self):
        entries = [{'path': 'config/example.cfg', 'type': 'config'},
                   {'path': 'scripts/recipe.zs', 'type': 'script'},
                   {'path': 'mods/memory_repo/example.jar', 'type': 'config'},
                   {'path': 'resources/example.png', 'type': 'resource'}]
        self.assertEqual(reference.selected({'files': entries}), entries[:2])

    def test_hash_checks_reject_changed_or_truncated_file(self):
        entry = reference.content_from_manifest(manifest())['files'][0]
        for data in (b'wrong', b'example confiG'):
            with self.subTest(data=data), self.assertRaises(ValueError):
                reference.verify(entry, data)
        reference.verify(entry, b'example config')

    def test_corrupt_cache_is_not_overwritten_or_trusted(self):
        entry = reference.content_from_manifest(manifest())['files'][0]
        with tempfile.TemporaryDirectory() as temp, patch.object(reference, 'CACHE', Path(temp)):
            target = reference.destination(entry)
            target.parent.mkdir(parents=True)
            target.write_bytes(b'broken')
            with patch.object(reference, 'request', side_effect=AssertionError('unexpected download')):
                with self.assertRaises(ValueError):
                    reference.fetch_one(entry)
            self.assertEqual(target.read_bytes(), b'broken')

    def test_download_accepts_only_verified_mirror_and_rechecks_cache(self):
        entry = reference.content_from_manifest(manifest())['files'][0]
        with tempfile.TemporaryDirectory() as temp, patch.object(reference, 'CACHE', Path(temp)):
            with patch.object(reference, 'request', side_effect=[b'wrong', b'example config']) as request:
                reference.fetch_one(entry)
                self.assertEqual(request.call_count, 2)
            self.assertEqual(reference.destination(entry).read_bytes(), b'example config')
            with patch.object(reference, 'request', side_effect=AssertionError('unexpected download')):
                reference.fetch_one(entry)


if __name__ == '__main__':
    unittest.main()
