#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin and fetch inert FTB Revelation reference inputs; never execute pack code."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter
from datetime import date
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / 'references/revelation-3.7.0.lock.json'
CACHE = ROOT / 'references/cache/revelation-3.7.0'
SOURCE = 'https://api.feed-the-beast.com/v1/modpacks/public/modpack/35/12180'
FILE_KEYS = ('id', 'type', 'size', 'url', 'mirrors', 'clientonly', 'serveronly', 'optional')


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def relative_file(entry):
    directory = PurePosixPath(entry['path'])
    name = entry['name']
    if directory.is_absolute() or '..' in directory.parts or '\\' in entry['path']:
        raise ValueError('Unsafe reference directory')
    if not isinstance(name, str) or not name or name in ('.', '..') or '/' in name or '\\' in name:
        raise ValueError('Unsafe reference filename')
    path = directory / name
    if '..' in path.parts or path.is_absolute():
        raise ValueError('Unsafe reference path')
    return path.as_posix()


def request(url, limit):
    if urllib.parse.urlsplit(url).scheme != 'https':
        raise ValueError('Reference downloads must use HTTPS')
    req = urllib.request.Request(url, headers={'User-Agent': 'GoldenEra-reference-inspection/0.1'})
    with urllib.request.urlopen(req, timeout=30) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Reference response exceeds declared size limit')
    return data


def content_from_manifest(manifest):
    if (manifest.get('parent'), manifest.get('id'), manifest.get('name')) != (35, 12180, '3.7.0'):
        raise ValueError('Unexpected pack/version identity')
    files = []
    seen = set()
    for source in manifest['files']:
        path = relative_file(source)
        if path in seen:
            raise ValueError('Duplicate reference path: ' + path)
        seen.add(path)
        digest = source.get('hashes', {}).get('sha256', '')
        if not re.fullmatch('[0-9a-f]{64}', digest):
            raise ValueError('Missing SHA-256: ' + path)
        entry = {key: source[key] for key in FILE_KEYS}
        entry.update(path=path, sha256=digest, sha1=source['sha1'])
        if not isinstance(entry['size'], int) or entry['size'] < 0:
            raise ValueError('Invalid reference size')
        files.append(entry)
    targets = sorted(
        ({key: target[key] for key in ('name', 'version', 'type')} for target in manifest['targets']),
        key=lambda target: target['name'],
    )
    return {'pack_id': 35, 'version_id': 12180, 'pack': 'FTB Revelation', 'version': '3.7.0',
            'targets': targets, 'files': sorted(files, key=lambda entry: entry['path'])}


def pin(checked_date):
    date.fromisoformat(checked_date)
    if LOCK.exists():
        raise ValueError('Reference lock already exists; repinning requires deliberate review')
    raw = request(SOURCE, 16 * 1024 * 1024)
    content = content_from_manifest(json.loads(raw))
    lock = {'schema': 1, 'selected_on': checked_date, 'manifest_url': SOURCE,
            'observed_response_sha256': sha256(raw), 'content_sha256': sha256(canonical(content)),
            'content': content}
    # Record a raw response for provenance; counters/timestamps are not content pins.
    CACHE.mkdir(parents=True, exist_ok=True)
    (CACHE / 'manifest.json').write_bytes(raw)
    LOCK.parent.mkdir(parents=True, exist_ok=True)
    LOCK.write_text(json.dumps(lock, indent=2) + '\n')
    print('Pinned Revelation 3.7.0:', len(content['files']), 'file entries')
    print('Content SHA-256:', lock['content_sha256'])


def read_lock():
    lock = json.loads(LOCK.read_text())
    if lock['schema'] != 1 or sha256(canonical(lock['content'])) != lock['content_sha256']:
        raise ValueError('Reference lock content digest mismatch')
    return lock


def selected(content):
    return [entry for entry in content['files']
            if entry['type'] in ('config', 'script')
            and PurePosixPath(entry['path']).parts[0] in ('config', 'scripts')]


def destination(entry):
    path = PurePosixPath(entry['path'])
    if path.is_absolute() or '..' in path.parts or '\\' in entry['path']:
        raise ValueError('Unsafe locked reference path')
    target = CACHE / 'files' / path
    if not target.resolve().is_relative_to((CACHE / 'files').resolve()):
        raise ValueError('Reference path escapes cache')
    return target


def verify(entry, data):
    if len(data) != entry['size'] or sha256(data) != entry['sha256'] or hashlib.sha1(data).hexdigest() != entry['sha1']:
        raise ValueError('Reference size/hash mismatch: ' + entry['path'])


def fetch_one(entry):
    target = destination(entry)
    if target.exists():
        verify(entry, target.read_bytes())
        return
    errors = []
    for url in [entry['url'], *entry['mirrors']]:
        try:
            data = request(url, entry['size'])
            verify(entry, data)
            target.parent.mkdir(parents=True, exist_ok=True)
            partial = target.with_name(target.name + '.part')
            partial.write_bytes(data)
            partial.replace(target)
            return
        except Exception as error:
            errors.append(str(error))
    raise ValueError(entry['path'] + ': ' + '; '.join(errors))


def fetch(content):
    entries = selected(content)
    failures = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(fetch_one, entry): entry for entry in entries}
        for index, future in enumerate(as_completed(futures), 1):
            try:
                future.result()
            except Exception as error:
                failures.append(str(error))
            if index % 50 == 0 or index == len(entries):
                print(f'Checked/downloaded {index}/{len(entries)} reference configs/scripts', flush=True)
    if failures:
        raise ValueError('\n'.join(failures))


def check(content):
    entries = selected(content)
    for entry in entries:
        verify(entry, destination(entry).read_bytes())
    print(f'REFERENCE PASS: {len(entries)} config/script files match locked size, SHA-256 and SHA-1')


def report(content):
    counts = Counter(entry['type'] for entry in content['files'])
    top_level_jars = [entry for entry in content['files']
                      if PurePosixPath(entry['path']).parent == PurePosixPath('mods')
                      and entry['path'].endswith('.jar')]
    print(json.dumps({'pack': content['pack'], 'version': content['version'], 'targets': content['targets'],
                      'manifest_entries': len(content['files']), 'file_types': dict(sorted(counts.items())),
                      'top_level_mod_jar_entries': len(top_level_jars),
                      'reference_config_script_files': len(selected(content)),
                      'reference_config_script_bytes': sum(entry['size'] for entry in selected(content))}, indent=2))


def thermal_facts(content, additional_keys=()):
    path = 'config/cofh/thermalexpansion/common.cfg'
    entry = next(entry for entry in content['files'] if entry['path'] == path)
    raw = destination(entry).read_bytes()
    verify(entry, raw)
    wanted = {
        'Dynamo.Steam.BasePower', 'Dynamo.Upgradable', 'Dynamo.CustomPowerScaling',
        'Machine.Furnace.BasePower', 'Machine.Pulverizer.BasePower',
        'Machine.Pulverizer.Ore -> Dust Multiplier', 'Machine.Upgradable',
        'Machine.DisableAutoInput', 'Machine.DisableAutoOutput',
        'Machine.CustomPowerScaling', 'Machine.CustomEnergyScaling',
        'Storage.Cell.BaseCapacity', 'Storage.Cell.BaseReceive', 'Storage.Cell.BaseSend',
        'Item.Capacitor.BaseSend',
    }
    wanted.update(additional_keys)
    scopes, facts = [], {}
    for number, original in enumerate(raw.decode('utf-8').splitlines(), 1):
        line = original.strip()
        if not line or line.startswith('#'):
            continue
        if line.endswith(' {'):
            scopes.append(line[:-2].strip().strip('"'))
        elif line == '}':
            if not scopes:
                raise ValueError('Unbalanced Thermal config scopes')
            scopes.pop()
        else:
            match = re.fullmatch(r'([BI]):(.+?)=(.*)', line)
            if not match:
                continue
            kind, key, value = match.groups()
            key = '.'.join([*scopes, key.strip('"')])
            if key not in wanted:
                continue
            if key in facts:
                raise ValueError('Duplicate Thermal config key: ' + key)
            if kind == 'B':
                if value not in ('true', 'false'):
                    raise ValueError('Invalid config boolean')
                parsed = value == 'true'
            else:
                parsed = int(value)
            facts[key] = {'key': key, 'value': parsed, 'line': number}
    if scopes or set(facts) != wanted:
        raise ValueError('Thermal config structure/required keys changed')
    return {'pack': content['pack'], 'version': content['version'], 'source_path': path,
            'source_url': entry['url'], 'source_sha256': entry['sha256'],
            'evidence_kind': 'configured values; effective runtime behavior not yet verified',
            'facts': [facts[key] for key in sorted(facts)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('pin', 'fetch', 'check', 'report', 'facts'))
    parser.add_argument('--date', help='User-local YYYY-MM-DD selection date, required for pin')
    args = parser.parse_args()
    if args.command == 'pin':
        if not args.date:
            parser.error('pin requires --date YYYY-MM-DD')
        pin(args.date)
    else:
        content = read_lock()['content']
        if args.command == 'fetch':
            fetch(content)
            check(content)
        elif args.command == 'check':
            check(content)
        elif args.command == 'facts':
            print(json.dumps(thermal_facts(content), indent=2))
        else:
            report(content)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        raise SystemExit(str(error))
