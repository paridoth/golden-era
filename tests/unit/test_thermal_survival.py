# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject unsupported reference semantics before they silently become native terrain."""
import copy
import json
from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'))
import thermal_survival as survival
import thermal_catalog as catalog

class SurvivalTests(unittest.TestCase):
    def setUp(self):
        self.review=json.loads(survival.REVIEW.read_text())
        self.spec=json.loads(catalog.SPEC.read_text())
        self.mapping=json.loads(catalog.REVIEW.read_text())

    def test_dimension_and_distribution_changes_require_review(self):
        for change in ({'dimension': {'restriction':'whitelist','value':[-1]}},
                       {'distribution':'normal'}, {'min-height':-1}):
            review=copy.deepcopy(self.review)
            review['ore_features']['tin'].update(change)
            with self.assertRaises(ValueError):
                survival.compile_survival(review,self.spec,self.mapping)

    def test_unresolved_secondary_and_missing_recipe_cannot_disappear(self):
        del self.mapping['mappings']['ore:dustLead']
        with self.assertRaisesRegex(ValueError,'Unmapped'):
            survival.compile_survival(self.review,self.spec,self.mapping)
        self.setUp()
        self.spec['processing_and_fuel']=[r for r in self.spec['processing_and_fuel'] if r['input']['id']!='oreSilver']
        with self.assertRaisesRegex(ValueError,'Missing selected'):
            survival.compile_survival(self.review,self.spec,self.mapping)

    def test_stale_pack_and_unsupported_vein_size_fail(self):
        self.review['pack_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'lock'):
            survival.compile_survival(self.review,self.spec,self.mapping)
        self.setUp()
        self.review['ore_features']['tin']['generator']['cluster-size']=28
        with self.assertRaisesRegex(ValueError,'cube'):
            survival.compile_survival(self.review,self.spec,self.mapping)

if __name__=='__main__': unittest.main()
