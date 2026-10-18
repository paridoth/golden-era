#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Import a deliberately bounded, passive Thermal reference specification."""
import argparse
import json
import re
import zipfile

import reference

REVIEW = reference.ROOT / 'references/thermal-review.json'
OUTPUT = reference.ROOT / 'references/revelation-3.7.0-thermal.json'
TE = 'mods/ThermalExpansion-1.12.2-5.5.7.1-universal.jar'
CORE = 'mods/CoFHCore-1.12.2-4.6.6.1-universal.jar'
PREFIX = 'assets/thermalexpansion/content/'
SCRIPT_OUTPUTS = {
    'scripts/00_recipe_changes.zs': {'thermalfoundation:material:163', 'thermalfoundation:material:291'},
    'scripts/01_unification.zs': {'thermalfoundation:material:257'},
}
EXTRA_CONFIG = {'Dynamo.SmallStorage', 'Machine.SmallStorage', 'Dynamo.CustomScaling',
                'Machine.CustomScaling', 'Dynamo.CustomAugmentScaling', 'Machine.CustomAugmentScaling'}


def positive(value):
    if type(value) is not int or value <= 0:
        raise ValueError('Expected positive integer')
    return value


def stack(value):
    """Preserve identities; an ore group is never silently made into a native item."""
    if not isinstance(value, dict) or set(value) - {'item', 'ore', 'count', 'data'}:
        raise ValueError('Unsupported stack fields (NBT, wildcard and constants need review)')
    kinds = set(value) & {'item', 'ore'}
    if len(kinds) != 1:
        raise ValueError('Expected exactly one item or ore group')
    kind = next(iter(kinds))
    identity = value[kind]
    pattern = r'[a-z0-9_.-]+:[a-z0-9_./-]+' if kind == 'item' else r'[A-Za-z][A-Za-z0-9_]*'
    if not isinstance(identity, str) or not re.fullmatch(pattern, identity):
        raise ValueError('Unsupported item/group identity')
    result = {'kind': 'item' if kind == 'item' else 'ore_group', 'id': identity,
              'count': positive(value.get('count', 1))}
    if kind == 'item':
        data = value.get('data', 0)
        if type(data) is not int or not 0 <= data <= 32767:
            raise ValueError('Unsupported item metadata')
        result['metadata'] = data
    elif 'data' in value:
        raise ValueError('Metadata cannot be attached to an unresolved ore group')
    return result


def token(value):
    match = re.fullmatch(r'<([^<>]+)>(?:\s*\*\s*([1-9][0-9]*))?', value.strip())
    if not match:
        raise ValueError('Unsupported ZenScript token')
    parts = match[1].split(':')
    count = int(match[2] or 1)
    if len(parts) == 2 and parts[0] == 'ore':
        return stack({'ore': parts[1], 'count': count})
    if len(parts) not in (2, 3) or (len(parts) == 3 and not parts[2].isdigit()):
        raise ValueError('Unsupported ZenScript item metadata')
    return stack({'item': ':'.join(parts[:2]), 'data': int(parts[2]) if len(parts) == 3 else 0,
                  'count': count})


def crafting(output, array, shaped):
    # Translate only literal brackets, nulls and angle tokens to JSON; no eval/script engine.
    encoded = re.sub(r'<[^<>]+>', lambda m: json.dumps(m[0]), array)
    try:
        values = json.loads(encoded)
    except json.JSONDecodeError as error:
        raise ValueError('Unsupported ZenScript ingredient expression') from error
    def ingredient(value):
        if value is None:
            return None
        if not isinstance(value, str):
            raise ValueError('Unsupported ingredient expression')
        return token(value)
    if not isinstance(values, list) or not values:
        raise ValueError('Expected ingredient array')
    if shaped:
        if not 1 <= len(values) <= 3 or any(not isinstance(row, list) for row in values):
            raise ValueError('Expected shaped rows')
        width = len(values[0])
        if not 1 <= width <= 3 or any(len(row) != width for row in values):
            raise ValueError('Invalid crafting grid')
        values = [[ingredient(v) for v in row] for row in values]
        if not any(v for row in values for v in row):
            raise ValueError('Empty crafting grid')
    else:
        if len(values) > 9 or any(v is None for v in values):
            raise ValueError('Invalid shapeless ingredients')
        values = [ingredient(v) for v in values]
    return {'kind': 'shaped' if shaped else 'shapeless', 'output': token(output), 'ingredients': values}


def script_recipes(path, raw):
    expected = SCRIPT_OUTPUTS[path]
    text = raw.decode('utf8')
    pattern = r'(?m)^[ \t]*recipes\.(addShaped|addShapeless)\(\s*(<([^<>]+)>(?:\s*\*\s*[1-9][0-9]*)?)\s*,\s*(\[[^;]*?\])\s*\);'
    found = {}
    for match in re.finditer(pattern, text):
        kind, output, identity, array = match.groups()
        if identity not in expected:
            continue
        if identity in found:
            raise ValueError('Duplicate selected script recipe')
        recipe = crafting(output, array, kind == 'addShaped')
        recipe['evidence'] = {'path': path, 'sha256': reference.sha256(raw),
                              'line': text.count('\n', 0, match.start()) + 1}
        found[identity] = recipe
    if set(found) != expected:
        raise ValueError('Selected script recipe missing or unsupported: ' + path)
    return [found[key] for key in sorted(found)]


def resource(zipped, name, jar=TE):
    # No ZIP extraction. Read only one named, bounded, unambiguous entry.
    entries = [entry for entry in zipped.infolist() if entry.filename == name]
    if len(entries) != 1 or entries[0].file_size > 1024 * 1024:
        raise ValueError('Missing, duplicate or oversized JAR entry: ' + name)
    raw = zipped.read(entries[0])
    return raw, {'jar': jar, 'entry': name, 'sha256': reference.sha256(raw)}


def rows(zipped, name, key):
    raw, evidence = resource(zipped, PREFIX + name)
    value = json.loads(raw)
    if set(value) != {key} or not isinstance(value[key], list):
        raise ValueError('Unexpected Thermal JSON resource structure')
    return value[key], evidence


def normalize_recipe(row, machine, default_energy):
    allowed = {'input', 'output', 'output2', 'energy', 'energy_mod'} if machine == 'pulverizer' else {'input', 'energy', 'energy_mod'}
    if set(row) - allowed or not {'input'} <= set(row):
        raise ValueError('Unsupported recipe fields')
    if 'energy' in row and 'energy_mod' in row:
        raise ValueError('Ambiguous energy fields')
    energy = positive(row.get('energy', default_energy))
    if 'energy_mod' in row:
        energy = positive(default_energy * positive(row['energy_mod']) // 100)
    result = {'machine': machine, 'input': stack(row['input']), 'energy_rf': energy}
    if machine == 'pulverizer':
        result['output'] = stack(row['output'])
        if 'output2' in row:
            secondary = dict(row['output2'])
            chance = secondary.pop('chance', 100)
            if type(chance) is not int or not 0 <= chance <= 100:
                raise ValueError('Unsupported output probability')
            result['secondary'] = {'stack': stack(secondary), 'chance_percent': chance}
    return result


def build(content, review):
    if review.get('schema') != 1 or review['lock_content_sha256'] != reference.sha256(reference.canonical(content)):
        raise ValueError('Thermal review belongs to a different pack lock')
    entries = {entry['path']: entry for entry in content['files']}
    for path in (TE, CORE, *SCRIPT_OUTPUTS):
        reference.verify(entries[path], reference.destination(entries[path]).read_bytes())
    # Review prose/numbers are authored, not decompiled automatically. Refuse stale review anchors.
    for source in review['binary_evidence']:
        with zipfile.ZipFile(reference.destination(entries[source['jar']])) as zipped:
            raw, _ = resource(zipped, source['entry'], source['jar'])
        if reference.sha256(raw) != source['sha256']:
            raise ValueError('Reviewed class changed: ' + source['entry'])
    recipes = []
    selections = [('machine/pulverizer/pulverizer_ores.json', {'oreIron'}),
                  ('machine/pulverizer/pulverizer_tf.json', {'oreCopper', 'oreTin', 'oreSilver', 'oreLead'})]
    with zipfile.ZipFile(reference.destination(entries[TE])) as zipped:
        for name, wanted in selections:
            values, evidence = rows(zipped, name, 'pulverizer')
            chosen = [i for i, row in enumerate(values) if row.get('input', {}).get('ore') in wanted]
            if len(chosen) != len(wanted) or {values[i]['input']['ore'] for i in chosen} != wanted:
                raise ValueError('Selected processing recipe missing or duplicated')
            for index in chosen:
                recipe = normalize_recipe(values[index], 'pulverizer', review['parser_defaults']['pulverizer_rf'])
                recipe['evidence'] = dict(evidence, pointer='/pulverizer/' + str(index))
                recipes.append(recipe)
        values, evidence = rows(zipped, 'dynamo/steam.json', 'dynamo_steam')
        chosen = [i for i, row in enumerate(values) if row.get('input', {}).get('item') == 'minecraft:coal']
        if len(chosen) != 2 or {values[i]['input'].get('data', 0) for i in chosen} != {0, 1}:
            raise ValueError('Coal/charcoal input identities changed')
        for index in chosen:
            recipe = normalize_recipe(values[index], 'steam_dynamo', review['parser_defaults']['steam_rf'])
            recipe['evidence'] = dict(evidence, pointer='/dynamo_steam/' + str(index))
            recipes.append(recipe)
    crafting_recipes = []
    for path in SCRIPT_OUTPUTS:
        crafting_recipes.extend(script_recipes(path, reference.destination(entries[path]).read_bytes()))
    return {'schema': 1, 'pack': 'FTB Revelation', 'version': '3.7.0',
            'lock_content_sha256': reference.sha256(reference.canonical(content)),
            'status': 'static reference specification; unresolved registries; not a runtime export',
            'runtime_ready': False,
            'artifacts': [{'path': path, 'sha256': entries[path]['sha256']} for path in (TE, CORE)],
            'config': reference.thermal_facts(content, EXTRA_CONFIG),
            'processing_and_fuel': recipes, 'crafting': crafting_recipes,
            'review': review,
            'unresolved': ['Effective recipe/load order and inter-mod overrides',
                           'Ore dictionary membership and preferred concrete outputs',
                           'Complete machine crafting, side controls and transport behavior',
                           'Save migration, fractional water/fuel accounting and random output persistence',
                           'Native mappings and original-runtime parity observations']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('fetch', 'check', 'export'))
    args = parser.parse_args()
    content = reference.read_lock()['content']
    if args.command == 'fetch':
        for entry in content['files']:
            if entry['path'] in (TE, CORE):
                reference.fetch_one(entry)
        print('Verified two inert Thermal/Core JARs; no Java or pack code executed')
        return
    result = build(content, json.loads(REVIEW.read_text()))
    rendered = json.dumps(result, indent=2) + '\n'
    if args.command == 'export':
        print(rendered, end='')
    elif OUTPUT.read_text() != rendered:
        raise ValueError('Thermal specification is stale; regenerate and review the diff')
    else:
        print('THERMAL REFERENCE PASS: 7 processing/fuel records, 3 crafting records, 21 config facts; static evidence only')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error))
