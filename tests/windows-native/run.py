#!/usr/bin/env python3
"""Run the actual x86 NSIS release under isolated, repository-local Wine.

This is a compatibility smoke test on Linux, not native Windows validation.
It never installs system packages or opens the user's desktop/Wine prefix.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / 'packaging/windows-test/wine.lock.json'
RELEASE = 'golden-era-playtest-0.1.1-windows.exe'
FROZEN_SHA = 'cb7955373f0bf3d2d0101b4186fe2eeb38ab1b67fb6b0e0daf34d073dc1cdeb5'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(path):
    path = path.resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError('Test paths must remain inside the repository: ' + str(path))
    return path


def tools(fetch):
    lock = json.loads(LOCK.read_text())
    cache, target = inside(ROOT / lock['cache']), inside(ROOT / lock['tool_root'])
    if target != ROOT / 'tools/wine-root':
        raise ValueError('Wine developer tools must use the dedicated tools/wine-root directory')
    cache.mkdir(parents=True, exist_ok=True)
    for item in lock['packages']:
        archive = cache / item['filename']
        if not archive.is_file():
            if not fetch:
                raise ValueError('Wine tool archive missing; use --fetch-tools: ' + item['filename'])
            with urllib.request.urlopen(item['url'], timeout=60) as stream, archive.open('wb') as output:
                shutil.copyfileobj(stream, output)
        if archive.stat().st_size != item['size'] or sha(archive) != item['sha256']:
            raise ValueError('Wine archive differs from its apt metadata SHA256: ' + item['filename'])
    # Always reconstruct the test-only tools from checked archives, never trust stale binaries.
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)
    for item in lock['packages']:
        subprocess.run(['dpkg-deb', '-x', str(cache / item['filename']), str(target)], check=True)
    # Debian's tiny dispatcher hardcodes /usr/lib/wine. Keep its replacement
    # inside this extracted developer tool directory; system files stay untouched.
    dispatcher = target / 'usr/lib/wine/wineserver'
    dispatcher.write_text('#!/bin/sh\nexec "$(dirname "$0")/wineserver64" -p0 "$@"\n')
    dispatcher.chmod(0o755)
    return target


def launcher_smoke(work, env, wine64, data, app, localappdata, version, report):
    """Launch the installed batch twice and click only the private Xvfb surface."""
    from PIL import ImageGrab
    spec = importlib.util.spec_from_file_location('golden_era_gui_observer', ROOT / 'tests/playtest/gui.py')
    gui = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gui)
    gui.DISPLAY = ':99'
    # Retain the installer preservation fixtures, then use a different real world.
    world = data / 'worlds/playtest'
    world.rename(data / 'worlds/installer-preserved-fixture')
    observer = world / 'worldmods/gui_observer'
    observer.mkdir(parents=True)
    (observer / 'mod.conf').write_text('name = gui_observer\ndepends = era_playtest\n')
    (observer / 'init.lua').write_text(gui.OBSERVER)
    config = (app / 'defaults/playtest.conf').read_text()
    config += '\nbind_address = 127.0.0.1\nport = 30223\nserver_announce = false\nscreen_w = 1280\nscreen_h = 900\nviewing_range = 20\nfps_max = 15\ngui_smoke_choice = workshop\n'
    (data / 'settings.conf').write_text(config)
    log = data / 'logs/client.log'
    batch = localappdata + '\\GoldenEraPlaytest\\app\\' + version + '\\start.bat'
    evidence = work / 'gui'
    evidence.mkdir(exist_ok=True)
    previous_auth = os.environ.get('XAUTHORITY')
    os.environ['XAUTHORITY'] = env['XAUTHORITY']
    try:
        for phase in ('choice', 'reconnect'):
            log.unlink(missing_ok=True)
            output = (evidence / (phase + '.log')).open('w')
            client = subprocess.Popen([str(wine64), 'cmd.exe', '/d', '/c', batch], env=env, cwd=work,
                                      stdout=output, stderr=subprocess.STDOUT)
            try:
                if phase == 'choice':
                    gui.wait_text(log, 'ONBOARDING GUI CHOOSER READY workshop', client, seconds=120)
                    time.sleep(.5)
                    ImageGrab.grab(xdisplay=':99').save(evidence / 'workshop-chooser.png')
                    gui.click(400, 425)
                    gui.wait_text(log, 'ONBOARDING GUI CHOICE PASS workshop', client, seconds=90)
                    ImageGrab.grab(xdisplay=':99').save(evidence / 'workshop-selected.png')
                else:
                    gui.wait_text(log, 'ONBOARDING GUI RECONNECT PASS workshop', client, seconds=120)
                result = client.wait(timeout=30)
                if result:
                    raise RuntimeError('Installed batch GUI session returned ' + str(result))
                report.append('PASS: actual installed start.bat via Wine cmd.exe, GUI ' + phase + ' observer assertions')
                content = log.read_text(errors='replace')
                warnings = [line for line in content.splitlines() if 'WARNING[' in line]
                errors = [line for line in content.splitlines() if 'ERROR[' in line]
                other = [line for line in warnings if 'No SHA256 known for builtin file' not in line]
                report.append('GUI ' + phase + ' engine diagnostics: ' + str(len(warnings)) + ' warnings, ' + str(len(errors)) + ' errors; ' + str(len(other)) + ' warnings outside known builtin-path category')
                shutil.copy2(world / 'world.mt', evidence / (phase + '-world.mt'))
            finally:
                if client.poll() is None:
                    client.terminate()
                    client.wait(timeout=10)
                output.close()
    finally:
        if previous_auth is None:
            os.environ.pop('XAUTHORITY', None)
        else:
            os.environ['XAUTHORITY'] = previous_auth


def world_creation_smoke(work, env, wine64, app, report):
    """Execute exact release/development world creation through the real cmd.exe."""
    expected = ['gameid = golden_era_playtest', 'backend = sqlite3', 'player_backend = sqlite3',
                'auth_backend = sqlite3', 'mod_storage_backend = sqlite3']
    scripts = work / 'prefix/drive_c/GoldenEraShellSmoke'
    scripts.mkdir(exist_ok=True)
    logs = work / 'shell'
    logs.mkdir(exist_ok=True)
    for label, source, required in [('frozen-0.1.1', app / 'start.bat', False),
                                     ('current', ROOT / 'packaging/playtest/templates/start.bat', True)]:
        batch = source.read_text()
        begin = batch.index('if not exist "%GE_DATA%\\worlds\\playtest\\world.mt" (')
        end = batch.index('if not exist "%GE_DATA%\\engine-', begin)
        block = batch[begin:end].strip()
        if 'powershell.exe' in block or 'luanti.exe' in block:
            raise RuntimeError('World creation regression unexpectedly includes engine/preflight execution')
        script = scripts / (label + '.cmd')
        script.write_bytes(('@echo off\r\n' + block.replace('\n', '\r\n') + '\r\n').encode())
        folder = scripts / (label + " data [qa] & spaces")
        world = folder / 'worlds/playtest'
        world.mkdir(parents=True, exist_ok=True)
        config = world / 'world.mt'
        config.unlink(missing_ok=True)
        local = env.copy()
        local['GE_DATA'] = 'C:\\GoldenEraShellSmoke\\' + folder.name
        command = [str(wine64), 'cmd.exe', '/d', '/c', 'C:\\GoldenEraShellSmoke\\' + script.name]
        result = subprocess.run(command, env=local, cwd=work, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=60)
        (logs / (label + '.log')).write_text(result.stdout)
        shutil.copy2(script, logs / script.name)
        if result.returncode or not config.is_file():
            raise RuntimeError('World creation cmd regression failed: ' + result.stdout[-3000:])
        actual = [line.strip() for line in config.read_text().splitlines() if line.strip()]
        shutil.copy2(config, logs / (label + '-world.mt'))
        if required and actual != expected:
            raise RuntimeError('Current exact world block did not write all five SQLite configuration keys: ' + repr(actual))
        if required:
            report.append('PASS: current exact world creation block writes all five SQLite keys through Wine cmd.exe with spaces/& in GE_DATA')
        else:
            report.append('OBSERVED: frozen 0.1.1 block redirection under Wine cmd.exe writes ' + str(len(actual)) + '/5 world.mt keys; native CMD behavior is not inferred')
        existing = b'# retained tester world settings\r\ngameid = golden_era_playtest\r\nbackend = sqlite3\r\nmarker = preserve exact bytes\r\n'
        config.write_bytes(existing)
        again = subprocess.run(command, env=local, cwd=work, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=60)
        if again.returncode or config.read_bytes() != existing:
            raise RuntimeError('World creation block changed an existing world.mt: ' + label)
    report.append('PASS: both world creation blocks preserve existing world.mt bytes')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch-tools', action='store_true')
    parser.add_argument('--installer', type=Path, default=ROOT / 'dist' / RELEASE)
    parser.add_argument('--keep-prefix', action='store_true', help='Retain the isolated developer test prefix for investigation')
    parser.add_argument('--reuse-workspace', type=Path, help=argparse.SUPPRESS)
    parser.add_argument('--engine-smoke', action='store_true', help='Run the official Win64 engine and stock factory smoke in a separate disposable world')
    parser.add_argument('--launcher-smoke', action='store_true', help='Also run the installed batch/GUI first-join and reconnect tests; requires --engine-smoke')
    parser.add_argument('--world-creation-smoke', action='store_true', help='Run exact frozen/current world creation blocks through Wine cmd.exe')
    args = parser.parse_args()
    if args.launcher_smoke and not args.engine_smoke:
        parser.error('--launcher-smoke requires --engine-smoke to prepare the verified Windows engine')
    installer = inside(args.installer)
    record = json.loads(installer.with_suffix('.exe.manifest.json').read_text())
    if sha(installer) != record['sha256']:
        raise ValueError('Installer hash differs from release manifest')
    if installer.name == RELEASE and sha(installer) != FROZEN_SHA:
        raise ValueError('Frozen 0.1.1 installer changed unexpectedly')
    target = tools(args.fetch_tools)
    wine = target / 'usr/lib/wine/wine'
    wine64 = target / 'usr/lib/wine/wine64'
    server = target / 'usr/lib/wine/wineserver64'
    base = ROOT / 'runtime/tests'
    base.mkdir(parents=True, exist_ok=True)
    work = inside(args.reuse_workspace) if args.reuse_workspace else Path(tempfile.mkdtemp(prefix='windows-wine-', dir=base))
    # Debian Wine searches a compiled system location for these native DLLs.
    # Seed only the isolated Windows prefix from the separately pinned package.
    for windows_dir, triple in [('system32', 'x86_64'), ('syswow64', 'i686')]:
        dll_dir = work / 'prefix/drive_c/windows' / windows_dir
        dll_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target / ('usr/' + triple + '-w64-mingw32/lib/zlib1.dll'), dll_dir / 'zlib1.dll')
    report = ['Actual Windows installer compatibility smoke under Wine 9 / Linux',
              'This does not establish native Windows, Windows PowerShell 5.1, SmartScreen, or real GPU behavior.',
              'Installer SHA256: ' + sha(installer),
              'Workspace: ' + ('reused developer workspace' if args.reuse_workspace else 'fresh isolated prefix')]
    env = os.environ.copy()
    # Never inherit a developer's alternate game data directory into the real batch.
    env.pop('GOLDEN_ERA_DATA_DIR', None)
    for name in ('data', 'config', 'cache', 'runtime', 'user-folders'):
        (work / name).mkdir(mode=0o700, exist_ok=True)
    for name in ('Desktop', 'Documents', 'Downloads', 'Music', 'Pictures', 'Videos', 'Templates', 'Public'):
        (work / 'user-folders' / name).mkdir(exist_ok=True)
    folder_map = {'DESKTOP': 'Desktop', 'DOCUMENTS': 'Documents', 'DOWNLOAD': 'Downloads', 'MUSIC': 'Music',
                  'PICTURES': 'Pictures', 'VIDEOS': 'Videos', 'TEMPLATES': 'Templates', 'PUBLICSHARE': 'Public'}
    (work / 'config/user-dirs.dirs').write_text(''.join('XDG_' + key + '_DIR="' + str(work / 'user-folders' / name) + '"\n' for key, name in folder_map.items()))
    env.update(WINEPREFIX=str(work / 'prefix'), WINEARCH='win64', WINEDEBUG='-all,err+all',
               WINEDLLPATH=':'.join(str(target / ('usr/lib/' + arch + '-linux-gnu/wine')) for arch in ('x86_64', 'i386')),
               WINESERVER=str(server), WINEDLLOVERRIDES='winemenubuilder.exe=d;mscoree=d;mshtml=d',
               XDG_DATA_HOME=str(work / 'data'), XDG_CONFIG_HOME=str(work / 'config'),
               XDG_CACHE_HOME=str(work / 'cache'), XDG_RUNTIME_DIR=str(work / 'runtime'),
               TMPDIR=str(work / 'runtime'),
               LIBGL_ALWAYS_SOFTWARE='1', DISPLAY=':99', XAUTHORITY=str(work / 'Xauthority'))
    env['LD_LIBRARY_PATH'] = ':'.join(str(target / ('usr/lib/' + arch + '-linux-gnu/wine/' + bits + '-unix')) for arch, bits in (('x86_64', 'x86_64'), ('i386', 'i386')))
    gui = ROOT / 'tools/gui-root'
    env['LD_LIBRARY_PATH'] += ':' + str(gui / 'usr/lib/x86_64-linux-gnu')
    if Path('/tmp/.X11-unix/X99').exists():
        raise RuntimeError('Private Xvfb display :99 is already occupied; no existing display was accessed')
    subprocess.run(['xauth', '-f', env['XAUTHORITY'], 'add', env['DISPLAY'], '.', secrets.token_hex(16)], check=True, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    xlog = (work / 'xvfb.log').open('w')
    process = subprocess.Popen([str(gui / 'usr/bin/Xvfb'), ':99', '-screen', '0', '1280x900x24', '-nolisten', 'tcp', '-auth', env['XAUTHORITY']], env=env, stdout=xlog, stderr=subprocess.STDOUT)
    def run(command, name, timeout=90):
        result = subprocess.run(command, env=env, cwd=work, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        (work / (name + '.log')).write_text(result.stdout)
        if result.returncode:
            raise RuntimeError(name + ' failed (' + str(result.returncode) + '): ' + result.stdout[-3000:])
        return result.stdout
    try:
        for unused in range(50):
            if process.poll() is not None:
                raise RuntimeError('Private Xvfb exited: ' + (work / 'xvfb.log').read_text())
            if Path('/tmp/.X11-unix/X99').exists():
                break
            time.sleep(.1)
        run([str(wine64), 'wineboot.exe', '-u'], 'wineboot', timeout=120)
        # Reject external home-folder links before any installer writes shortcuts.
        users = work / 'prefix/drive_c/users'
        for path in users.rglob('*'):
            if path.is_symlink() and not path.resolve().is_relative_to(work):
                raise RuntimeError('Wine special folder points outside isolated test: ' + str(path) + ' -> ' + str(path.resolve()))
        report.append('PASS: isolated 64-bit Wine prefix; all user special folders remain inside repository test directory')
        run([str(wine64), 'cmd.exe', '/d', '/c', 'echo %LOCALAPPDATA%'], 'localappdata')
        localappdata = (work / 'localappdata.log').read_text().strip().splitlines()[-1]
        if not localappdata.lower().startswith('c:\\users\\'):
            raise RuntimeError('Unexpected Windows local app data: ' + localappdata)
        env['LOCALAPPDATA'] = localappdata
        relative = Path(localappdata[3:].replace('\\', '/'))
        data = inside(work / 'prefix/drive_c' / relative / 'GoldenEraPlaytest')
        data.mkdir(parents=True, exist_ok=True)
        (data / 'worlds/playtest').mkdir(parents=True, exist_ok=True)
        sentinel = {data / 'settings.conf': b'# tester settings, retained\nviewing_range = 44\n',
                    data / 'worlds/playtest/map.sqlite': b'tester world fixture; do not open as sqlite\n'}
        for path, content in sentinel.items():
            path.write_bytes(content)
        run([str(wine), str(installer), '/S'], 'install', timeout=120)
        app = data / 'app' / record['version']
        for name, info in record['files'].items():
            path = app / name
            if not path.is_file() or path.stat().st_size != info['size'] or sha(path) != info['sha256']:
                raise RuntimeError('Installed payload differs from release manifest: ' + name)
        report.append('PASS: actual x86 NSIS release installed silently under WoW64; ' + str(len(record['files'])) + ' installed files match release SHA256 manifest')
        for path, content in sentinel.items():
            if path.read_bytes() != content:
                raise RuntimeError('Installer changed tester data: ' + str(path))
        desktop = work / 'user-folders/Desktop/Golden Era Playtest.lnk'
        menus = list(users.glob('*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Golden Era Playtest.lnk'))
        if not desktop.is_file() or len(menus) != 1 or not menus[0].is_file():
            raise RuntimeError('Per-user desktop/Start Menu shortcuts were not created inside isolated prefix')
        for shortcut in (desktop, menus[0]):
            expected_target = localappdata + '\\GoldenEraPlaytest\\app\\' + record['version'] + '\\start.bat'
            if not any(expected_target.encode(encoding) in shortcut.read_bytes() for encoding in ('utf-16le', 'utf-8')):
                raise RuntimeError('Shortcut target differs from versioned launcher: ' + str(shortcut))
        report.append('PASS: desktop and Start Menu shortcuts target the installed batch launcher; no Linux menu builder used')
        run([str(wine), str(installer), '/S'], 'reinstall', timeout=120)
        for path, content in sentinel.items():
            if path.read_bytes() != content:
                raise RuntimeError('Reinstall changed tester data: ' + str(path))
        report.append('PASS: silent reinstall preserves existing world/settings bytes')
        if args.world_creation_smoke:
            world_creation_smoke(work, env, wine64, app, report)
        if args.engine_smoke:
            spec = json.loads((app / 'engine-downloads.json').read_text())['windows_x86_64']
            archive = ROOT / 'references/cache/release/luanti-5.17.0-win64.zip'
            if sha(archive) != spec['sha256']:
                raise RuntimeError('Cached official Windows engine ZIP differs from release bootstrap pin')
            engine = data / 'engine-5.17.0'
            if not (engine / 'bin/luanti.exe').is_file():
                staging = work / 'engine-staging'
                with zipfile.ZipFile(archive) as zipped:
                    for info in zipped.infolist():
                        if not (staging / info.filename).resolve().is_relative_to(staging.resolve()):
                            raise RuntimeError('Unsafe engine ZIP entry')
                    zipped.extractall(staging)
                (staging / spec['archive_root']).rename(engine)
            test_data = work / 'prefix/drive_c/GoldenEraWineSmoke'
            world = test_data / 'world'
            observer = world / 'worldmods/era_playtest_smoke'
            shutil.copytree(ROOT / 'tests/playtest/mod', observer, dirs_exist_ok=True)
            (world / 'world.mt').write_text('gameid = golden_era_playtest\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
            config = test_data / 'server.conf'
            config.write_text('\n'.join(['bind_address = 127.0.0.1', 'port = 30222', 'server_announce = false',
                                         'mg_name = singlenode', 'mcl_singlenode_mapgen = false', 'creative_mode = false',
                                         'max_forceloaded_blocks = 32', 'era_playtest_no_welcome = true']) + '\n')
            env['LUANTI_GAME_PATH'] = localappdata + '\\GoldenEraPlaytest\\app\\' + record['version'] + '\\games'
            env['LUANTI_USER_PATH'] = 'C:\\GoldenEraWineSmoke\\engine-user'
            output = run([str(wine64), str(engine / 'bin/luanti.exe'), '--server', '--gameid', 'golden_era_playtest',
                          '--world', 'C:\\GoldenEraWineSmoke\\world', '--config', 'C:\\GoldenEraWineSmoke\\server.conf',
                          '--logfile', 'C:\\GoldenEraWineSmoke\\server.log'], 'engine-factory', timeout=210)
            if 'ERA PLAYTEST SMOKE PASS' not in output or 'ERA PLAYTEST SMOKE FAIL' in output:
                raise RuntimeError('Official Win64 engine did not complete the stock factory smoke: ' + output[-3000:])
            report.append('PASS: official hash-pinned Win64 Luanti 5.17.0 / LuaJIT completed the installed stock factory smoke under Wine')
            report.append(next(line for line in output.splitlines() if 'ERA PLAYTEST SMOKE PASS' in line))
            warnings = [line for line in output.splitlines() if 'WARNING[' in line]
            errors = [line for line in output.splitlines() if 'ERROR[' in line]
            report.append('Official engine diagnostics: ' + str(len(warnings)) + ' warning lines; ' + str(len(errors)) + ' error lines. Full output is retained in runtime/tests/windows-wine-logs/engine-factory.log.')
            if warnings:
                report.append('First warning: ' + warnings[0])
            if args.launcher_smoke:
                launcher_smoke(work, env, wine64, data, app, localappdata, record['version'], report)
    except Exception as error:
        report.append('FAIL: ' + str(error))
        raise
    finally:
        subprocess.run([str(server), '-k'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        xlog.close()
        evidence = base / 'windows-wine-logs'
        evidence.mkdir(exist_ok=True)
        for log in work.glob('*.log'):
            shutil.copy2(log, evidence / log.name)
        if (work / 'gui').is_dir():
            shutil.copytree(work / 'gui', evidence / 'gui', dirs_exist_ok=True)
        if (work / 'shell').is_dir():
            shutil.copytree(work / 'shell', evidence / 'shell', dirs_exist_ok=True)
        report.append('Test workspace: ' + str(work))
        (base / 'windows-wine-smoke.txt').write_text('\n'.join(report) + '\n')
        print('\n'.join(report), flush=True)
        if not args.keep_prefix:
            shutil.rmtree(work)


if __name__ == '__main__':
    main()
