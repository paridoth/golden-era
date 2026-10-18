# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline compiler checks: reject lossy mappings and stale reference contracts."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import thermal_catalog as catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.review = json.loads(catalog.REVIEW.read_text())
        self.spec = json.loads(catalog.SPEC.read_text())

    def test_committed_catalog_reproduces_without_original_downloads(self):
        result = catalog.compile_catalog(self.review, self.spec)
        self.assertEqual(catalog.render(result), catalog.OUTPUT.read_text())
        self.assertEqual(len(result['recipes']), 10)
        self.assertEqual(len(result['items']), 14)

    def test_concrete_metadata_identity_is_preserved(self):
        for meta, expected in [(0, 'era_materials:iron_dust'), (69, 'era_materials:nickel_dust')]:
            key = catalog.identity({'kind': 'item', 'id': 'thermalfoundation:material', 'metadata': meta})
            self.assertEqual(catalog.mapped(key, self.review['mappings']), expected)
        with self.assertRaises(ValueError):
            catalog.mapped('item:thermalfoundation:material:999', self.review['mappings'])

    def test_unknown_mapping_and_unused_pattern_symbol_fail(self):
        del self.review['mappings']['ore:gearTin']
        with self.assertRaisesRegex(ValueError, 'Unmapped'):
            catalog.compile_catalog(self.review, self.spec)
        self.setUp()
        self.review['recipes'][0]['key']['Z'] = 'ore:ingotIron'
        with self.assertRaisesRegex(ValueError, 'pattern'):
            catalog.compile_catalog(self.review, self.spec)

    def test_implicit_override_conflicts_are_rejected(self):
        conflict = copy.deepcopy(self.review['recipes'][0])
        conflict['output'] = 'item:thermalfoundation:material:257'
        self.review['recipes'].append(conflict)
        with self.assertRaisesRegex(ValueError, 'pack override'):
            catalog.compile_catalog(self.review, self.spec)

    def test_changed_pack_or_native_foundation_needs_review(self):
        self.spec['lock_content_sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'lock mismatch'):
            catalog.compile_catalog(self.review, self.spec)
        self.setUp()
        self.review['native_foundation']['commit'] = '0' * 40
        with self.assertRaisesRegex(ValueError, 'foundation'):
            catalog.compile_catalog(self.review, self.spec)

    def test_counted_ingredient_cannot_be_silently_flattened(self):
        self.spec['crafting'][0]['ingredients'][0]['count'] = 3
        with self.assertRaisesRegex(ValueError, 'Counted'):
            catalog.compile_catalog(self.review, self.spec)


if __name__ == '__main__':
    unittest.main()
