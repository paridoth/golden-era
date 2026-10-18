# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline tests for lossy import risks: identities, unsupported semantics and provenance."""
import io
import json
from pathlib import Path
import sys
import unittest
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import reference
import thermal_reference as thermal


class ThermalReferenceTests(unittest.TestCase):
    def test_coal_charcoal_and_groups_keep_distinct_identity(self):
        coal = thermal.stack({'item': 'minecraft:coal'})
        charcoal = thermal.stack({'item': 'minecraft:coal', 'data': 1})
        self.assertNotEqual(coal, charcoal)
        self.assertEqual(charcoal['metadata'], 1)
        self.assertEqual(thermal.stack({'ore': 'dustIron'})['kind'], 'ore_group')

    def test_unknown_nbt_wildcards_constants_and_bad_counts_fail(self):
        for value in [{'item': 'x:y', 'nbt': {}}, {'item': 'x:y', 'wildcard': True},
                      {'constant': 'cinnabar'}, {'item': 'x:y', 'count': True},
                      {'item': 'x:y', 'data': -1}, {'ore': 'dustIron', 'data': 0},
                      {'ore': 'dustIron', 'item': 'x:y'}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                thermal.stack(value)

    def test_probability_and_rf_defaults_are_preserved(self):
        row = {'input': {'ore': 'oreIron'}, 'output': {'ore': 'dustIron', 'count': 2},
               'output2': {'ore': 'dustNickel', 'chance': 10}}
        value = thermal.normalize_recipe(row, 'pulverizer', 4000)
        self.assertEqual(value['energy_rf'], 4000)
        self.assertEqual(value['output']['count'], 2)
        self.assertEqual(value['secondary']['chance_percent'], 10)
        row['output2']['chance'] = 101
        with self.assertRaises(ValueError):
            thermal.normalize_recipe(row, 'pulverizer', 4000)

    def test_fuel_explicit_energy_and_percentage_defaults(self):
        row = {'input': {'item': 'minecraft:coal'}, 'energy': 24000}
        self.assertEqual(thermal.normalize_recipe(row, 'steam_dynamo', 16000)['energy_rf'], 24000)
        row = {'input': {'item': 'minecraft:coal', 'data': 1}}
        self.assertEqual(thermal.normalize_recipe(row, 'steam_dynamo', 16000)['energy_rf'], 16000)
        row['energy_mod'] = 75
        self.assertEqual(thermal.normalize_recipe(row, 'steam_dynamo', 16000)['energy_rf'], 12000)
        row['energy'] = 20000
        with self.assertRaises(ValueError):
            thermal.normalize_recipe(row, 'steam_dynamo', 16000)

    def test_crafting_keeps_repeated_ingredients_and_empty_slots(self):
        recipe = thermal.crafting('<thermalfoundation:material:163> * 2',
                                  '[<ore:ingotCopper>, <ore:ingotCopper>, <ore:ingotCopper>, <ore:ingotTin>]', False)
        self.assertEqual(recipe['output']['count'], 2)
        self.assertEqual(recipe['output']['metadata'], 163)
        self.assertEqual([v['id'] for v in recipe['ingredients']].count('ingotCopper'), 3)
        shaped = thermal.crafting('<thermalfoundation:material:257>',
                                  '[[null,<ore:ingotTin>,null],[<ore:ingotTin>,<ore:ingotIron>,<ore:ingotTin>],[null,<ore:ingotTin>,null]]', True)
        self.assertIsNone(shaped['ingredients'][0][0])
        self.assertEqual(shaped['ingredients'][1][1]['id'], 'ingotIron')

    def test_expressions_and_invalid_grids_are_rejected(self):
        for output, array, shaped in [('<x:y>.withTag({a:1})', '[<x:z>]', False),
                                      ('<x:y>', '[ingredients]', False),
                                      ('<x:y>', '[<x:z:*>]', False),
                                      ('<x:y>', '[[null],[<x:z>,null]]', True),
                                      ('<x:y>', '[[null]]', True),
                                      ('<x:y>', '[null]', False)]:
            with self.subTest(array=array), self.assertRaises(ValueError):
                thermal.crafting(output, array, shaped)

    def test_selected_scripts_fail_on_missing_or_duplicate_recipe(self):
        path = 'scripts/01_unification.zs'
        raw = b'recipes.addShaped(<thermalfoundation:material:257>, [[<ore:ingotTin>]]);'
        result = thermal.script_recipes(path, raw)
        self.assertEqual(result[0]['evidence']['sha256'], reference.sha256(raw))
        for invalid in (b'// missing', raw + b'\n' + raw,
                        b'recipes.addShaped(<thermalfoundation:material:257>, [[aVariable]]);'):
            with self.subTest(raw=invalid), self.assertRaises(ValueError):
                thermal.script_recipes(path, invalid)

    def test_archive_entry_is_bounded_and_unambiguous(self):
        data = io.BytesIO()
        with warnings.catch_warnings(), zipfile.ZipFile(data, 'w') as zipped:
            warnings.simplefilter('ignore', UserWarning)
            zipped.writestr('entry', b'one')
            zipped.writestr('entry', b'two')
        with zipfile.ZipFile(data) as zipped:
            for name in ('entry', 'missing'):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    thermal.resource(zipped, name)

    def test_review_must_belong_to_exact_pack_lock(self):
        content = reference.read_lock()['content']
        review = json.loads(thermal.REVIEW.read_text())
        review['lock_content_sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'different pack lock'):
            thermal.build(content, review)


if __name__ == '__main__':
    unittest.main()
