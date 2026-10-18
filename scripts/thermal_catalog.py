#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compile the reviewed crafting subset into native Lua; never execute pack code."""
import argparse
import csv
import io
import json
import re
import zipfile

import reference
import thermal_reference as thermal

REVIEW = reference.ROOT / 'references/thermal-crafting-review.json'
SPEC = reference.ROOT / 'references/revelation-3.7.0-thermal.json'
OUTPUT = reference.ROOT / 'mods/era_materials/catalog.lua'
MCP = reference.ROOT / 'references/cache/mcp_stable-39-1.12.zip'
TF = 'mods/ThermalFoundation-1.12.2-2.6.7.1-universal.jar'
NATIVE = re.compile(r'[a-z0-9_]+:[a-z0-9_]+')


def identity(stack):
    if stack['kind'] == 'ore_group':
        return 'ore:' + stack['id']
    if stack['kind'] == 'item':
        return 'item:' + stack['id'] + ':' + str(stack['metadata'])
    raise ValueError('Unknown identity kind')


def mapped(key, mappings):
    if key not in mappings or not NATIVE.fullmatch(mappings[key]):
        raise ValueError('Unmapped or unsafe native identity: ' + key)
    return mappings[key]


def compile_catalog(review, spec):
    lock = reference.read_lock()
    if review['schema'] != 1 or spec['schema'] != 1 or not (
            review['lock_content_sha256'] == spec['lock_content_sha256'] == lock['content_sha256']):
        raise ValueError('Crafting review/specification/pack lock mismatch')
    foundation = json.loads((reference.ROOT / 'upstream.lock.json').read_text())['mineclonia']
    if review['native_foundation'] != foundation:
        raise ValueError('Native mapping needs review for the changed foundation')
    mappings = review['mappings']
    items, recipes, outputs = [], [], set()
    for item in review['items']:
        native = mapped(item['source'], mappings)
        if native != item['native']:
            raise ValueError('Item declaration and identity map disagree')
        if 'description' in item:
            if not native.startswith('era_materials:') or not re.fullmatch('[A-Za-z ]+', item['description']):
                raise ValueError('Invalid native material declaration')
            if native in {i['name'] for i in items}:
                raise ValueError('Duplicate native material declaration')
            items.append({'name': native, 'description': item['description']})
    for recipe in review['recipes']:
        output = mapped(recipe['output'], mappings)
        if output in outputs:
            raise ValueError('Duplicate selected crafting output')
        outputs.add(output)
        kind = recipe.get('kind', 'shaped')
        count = thermal.positive(recipe.get('count', 1))
        if kind == 'shaped':
            pattern, keys = recipe['pattern'], recipe['key']
            if (len(pattern) != 3 or any(len(row) != 3 for row in pattern)
                    or set(''.join(pattern)) - {' '} != set(keys)):
                raise ValueError('Invalid reviewed crafting pattern')
            grid = [[mapped(keys[c], mappings) if c != ' ' else '' for c in row] for row in pattern]
        elif kind == 'shapeless':
            if not 1 <= len(recipe['ingredients']) <= 9:
                raise ValueError('Invalid reviewed shapeless ingredients')
            grid = [mapped(key, mappings) for key in recipe['ingredients']]
        else:
            raise ValueError('Unsupported reviewed crafting kind')
        recipes.append({'id': recipe['id'], 'type': kind,
                        'output': output + (' ' + str(count) if count != 1 else ''),
                        'recipe': grid, 'phase': 'thermal' if output.startswith('era_thermal:') else 'materials'})
    for source in spec['crafting']:
        output = mapped(identity(source['output']), mappings)
        count = source['output']['count']
        thermal.positive(count)
        if output in outputs:
            raise ValueError('Reviewed default conflicts with imported pack override')
        outputs.add(output)
        def ingredient(value):
            if value is None:
                return ''
            if value['count'] != 1:
                raise ValueError('Counted crafting ingredient needs explicit support')
            return mapped(identity(value), mappings)
        kind = source['kind']
        if kind == 'shaped':
            grid = [[ingredient(v) for v in row] for row in source['ingredients']]
        elif kind == 'shapeless':
            grid = [ingredient(v) for v in source['ingredients']]
        else:
            raise ValueError('Unsupported crafting kind')
        recipes.append({'id': output.split(':')[1], 'type': 'shaped' if kind == 'shaped' else 'shapeless',
                        'output': output + (' ' + str(count) if count != 1 else ''), 'recipe': grid,
                        'phase': 'materials'})
    return {'schema': 1, 'pack_content_sha256': lock['content_sha256'],
            'review_sha256': reference.sha256(reference.canonical(review)),
            'spec_sha256': reference.sha256(reference.canonical(spec)),
            'items': items, 'recipes': recipes}


def lua(value):
    # Constrained compiler inputs are ASCII, so JSON quoting is valid Lua 5.1 quoting.
    if isinstance(value, str):
        if not value.isascii():
            raise ValueError('Non-ASCII catalog text needs explicit Lua quoting')
        return json.dumps(value)
    if type(value) is int:
        return str(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    raise ValueError('Unsupported Lua value')


def render(catalog):
    lines = ['-- SPDX-License-Identifier: GPL-3.0-or-later',
             '-- Generated by scripts/thermal_catalog.py; edit the reviewed source, then regenerate.',
             '-- Explicit native representatives; full Forge group/registry parity is unverified.',
             'return {']
    for key, value in catalog.items():
        if key in ('items', 'recipes'):
            lines.append(' [' + lua(key) + ']={')
            lines.extend('  ' + lua(row) + ',' for row in value)
            lines.append(' },')
        else:
            lines.append(' [' + lua(key) + ']=' + lua(value) + ',')
    return '\n'.join([*lines, '}', ''])


def verify_sources(review):
    content = reference.read_lock()['content']
    entries = {e['path']: e for e in content['files']}
    for path in (thermal.TE, thermal.CORE, TF):
        reference.verify(entries[path], reference.destination(entries[path]).read_bytes())
    for source in review['binary_evidence']:
        with zipfile.ZipFile(reference.destination(entries[source['jar']])) as zipped:
            raw, _ = thermal.resource(zipped, source['entry'], source['jar'])
        if reference.sha256(raw) != source['sha256']:
            raise ValueError('Stale crafting class review: ' + source['entry'])
    for source in review['config_evidence']:
        entry = entries[source['path']]
        if source['sha256'] != entry['sha256']:
            raise ValueError('Stale crafting config review')
        reference.verify(entry, reference.destination(entry).read_bytes())
    mapping = review['mcp_mapping']
    raw = MCP.read_bytes()
    if len(raw) != mapping['size'] or reference.sha256(raw) != mapping['sha256']:
        raise ValueError('MCP mapping size/hash mismatch')
    with zipfile.ZipFile(io.BytesIO(raw)) as zipped:
        fields = {row['searge']: row['name'] for row in csv.DictReader(io.StringIO(zipped.read('fields.csv').decode()))}
    if any(fields.get(k) != v for k, v in mapping['fields'].items()):
        raise ValueError('MCP field mapping changed')
    # Rebuild the selected script/config specification before trusting its tracked extract.
    expected = thermal.build(content, json.loads(thermal.REVIEW.read_text()))
    if expected != json.loads(SPEC.read_text()):
        raise ValueError('Tracked Thermal specification is stale')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('fetch', 'check', 'check-generated', 'export'))
    args = parser.parse_args()
    review = json.loads(REVIEW.read_text())
    spec = json.loads(SPEC.read_text())
    if args.command == 'fetch':
        for entry in reference.read_lock()['content']['files']:
            if entry['path'] in (thermal.TE, thermal.CORE, TF):
                reference.fetch_one(entry)
        if not MCP.exists():
            raw = reference.request(review['mcp_mapping']['url'], review['mcp_mapping']['size'])
            if reference.sha256(raw) != review['mcp_mapping']['sha256']:
                raise ValueError('Downloaded MCP mapping hash mismatch')
            MCP.parent.mkdir(parents=True, exist_ok=True)
            MCP.write_bytes(raw)
        verify_sources(review)
        print('CRAFTING SOURCE PASS: three inert JARs, configs/scripts and MCP mapping verified')
        return
    if args.command in ('check', 'export'):
        verify_sources(review)
    result = render(compile_catalog(review, spec))
    if args.command == 'export':
        print(result, end='')
    elif OUTPUT.read_text() != result:
        raise ValueError('Native catalog is stale; regenerate and review the diff')
    else:
        print('CRAFTING CATALOG PASS: 23 material declarations and 15 recipes match reviewed source inputs')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error))
