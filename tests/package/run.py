#!/usr/bin/env python3
"""Verify the actual tester ZIP and run its launcher from a clean extracted copy."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
version = json.loads((ROOT/'packaging/playtest/release.json').read_text())['version']
parser.add_argument('archive', nargs='?', type=Path,
                    default=ROOT/'dist'/('golden-era-playtest-'+version+'-windows-test.zip'))
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('package_verify', ROOT/'packaging/playtest/packager.py')
packager = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = packager
spec.loader.exec_module(packager)


def main():
    checked = packager.verify_package(args.archive, args.archive.with_suffix('.manifest.json'))
    base = ROOT/'runtime/tests'
    base.mkdir(parents=True, exist_ok=True)
    evidence = base/'package-smoke.log'
    report = ['Golden Era release ZIP: clean extraction and real launcher/engine smoke',
              'Archive SHA256: '+hashlib.sha256(args.archive.read_bytes()).hexdigest(),
              'Verified files: '+str(checked['files'])]
    try:
        with tempfile.TemporaryDirectory(prefix='tester copy with spaces ', dir=base) as temporary:
            work = Path(temporary)
            with zipfile.ZipFile(args.archive) as archive:
                archive.extractall(work)
                for entry in archive.infolist():
                    (work/entry.filename).chmod(stat.S_IMODE(entry.external_attr >> 16))
            bundle = work/'GoldenEra-Playtest'
            game = bundle/'games/golden_era_playtest'
            assert not any(path.is_symlink() for path in bundle.rglob('*')), 'Distribution must have no symlinks'
            assert not list(game.rglob('*.jar')), 'No Java modpack originals'
            assert not list(game.rglob('world.mt')), 'No developer world'
            engine = json.loads((bundle/'engine-downloads.json').read_text())['windows_x86_64']
            pinned = json.loads((ROOT/'packaging/playtest/templates/engine-downloads.json').read_text())['windows_x86_64']
            assert engine == pinned, 'Packaged Windows engine metadata matches the release pin'
            official = ROOT/'references/cache/release/luanti-5.17.0-win64.zip'
            if official.is_file():
                assert hashlib.sha256(official.read_bytes()).hexdigest() == engine['sha256'], 'Official Windows engine pin'
                report.append('Cached official Windows download matches its pinned SHA256')
            else:
                report.append('Official Windows binary cache absent; pinned metadata checked without downloading')
            batch = (bundle/'start.bat').read_text()
            assert 'Get-FileHash' in batch and 'checksum mismatch' in batch, 'Windows download must be checked'
            assert 'ExecutionPolicy' not in batch, 'No execution-policy override'
            assert '--name' not in batch and '--go' not in batch, 'Double-click opens the main menu'
            data = work/'new tester data'
            world = data/'worlds/playtest'
            mods = world/'worldmods'
            mods.mkdir(parents=True)
            shutil.copytree(ROOT/'tests/playtest/mod', mods/'era_playtest_smoke')
            smoke = mods/'era_playtest_smoke/init.lua'
            expected = json.dumps(str(game)+'/')
            smoke.write_text('core.register_on_mods_loaded(function()\n'
                             ' local p=core.get_modpath("mcl_core")\n'
                             ' assert(p:sub(1, #'+expected+') == '+expected+', "Game must load from the extracted package")\n'
                             'end)\n'+smoke.read_text())
            settings = (bundle/'defaults/playtest.conf').read_text()
            (data/'settings.conf').write_text(settings+'\nport = 30206\nmg_name = singlenode\n'
                                            'era_playtest_no_welcome = true\nmax_forceloaded_blocks = 32\n')
            env = os.environ.copy()
            env['GOLDEN_ERA_DATA_DIR'] = str(data)
            env['GOLDEN_ERA_ENGINE'] = str(ROOT/'upstream/luanti/bin/luanti')
            env['LD_LIBRARY_PATH'] = str(ROOT/'tools/client-root/usr/lib/x86_64-linux-gnu')+':'+str(ROOT/'tools/root/usr/lib/x86_64-linux-gnu')
            env['LUANTI_GAME_PATH'] = '/nonexistent/developer-game'
            result = subprocess.run([str(bundle/'start.sh'), '--server'], cwd=work,
                                    env=env, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=180)
            report.append(result.stdout)
            assert result.returncode == 0, 'Extracted launcher/engine failed'
            assert 'ERA PLAYTEST SMOKE PASS' in result.stdout, 'Packaged factory did not complete'
            assert 'ERA PLAYTEST SMOKE FAIL' not in result.stdout, 'Packaged factory failed'
            assert not any(word in result.stdout for word in ('ERROR[', 'WARNING[')), 'Unexpected packaged-run diagnostics'
            assert 'gameid = golden_era_playtest' in (world/'world.mt').read_text(), 'Launcher creates tester world'
            report.append('PACKAGE SMOKE PASS: full factory through the extracted launcher; fresh external save; source paths isolated')
            report.append('Windows: pinned official ZIP and bootstrap checked structurally; native Windows execution still requires tester confirmation')
    except Exception as error:
        if isinstance(error, subprocess.TimeoutExpired) and error.stdout:
            output = error.stdout
            report.append(output.decode(errors='replace') if isinstance(output, bytes) else output)
        report.append('PACKAGE SMOKE FAIL: '+str(error))
        evidence.write_text('\n'.join(report)+'\n')
        print('\n'.join(report))
        raise
    evidence.write_text('\n'.join(report)+'\n')
    print(report[-2])
    print('Log: '+str(evidence))


if __name__ == '__main__':
    main()
