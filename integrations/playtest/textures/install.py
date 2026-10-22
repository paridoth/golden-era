#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Switch Golden Era to a texture pack made by convert.py, here or on a Windows PC.

Installing copies the pack into the save folder's textures folder and points
texture_path in settings.conf at it; --remove goes back to Golden Era's own
textures. --windows-zip instead writes a ZIP to carry to a Windows PC: unzip it
and double-click install-textures.bat. The ZIP holds the tester's converted art,
so it is refused inside this repository and must never be shared.

  python3 integrations/playtest/textures/install.py ~/Textures/converted/golden_era_sphax
  python3 integrations/playtest/textures/install.py ~/Textures/converted/golden_era_sphax --windows-zip ~/Textures/golden_era_sphax-windows.zip
  python3 integrations/playtest/textures/install.py --remove
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[3]
MARKER = "Converted locally"
SETTING = re.compile(r"^[ \t]*texture_path[ \t]*=")

# Shared by both Windows scripts: drop any texture_path line and add one for
# GE_TARGET when it is set. Batch passes it to PowerShell, so it has no double
# quotes or percent signs.
WINDOWS_SETTINGS = ("$ErrorActionPreference='Stop'; try { $path=Join-Path $env:GE_DATA 'settings.conf'; "
                    "$kept=@([IO.File]::ReadAllLines($path) | Where-Object { $_ -cnotmatch '^[ \\t]*texture_path[ \\t]*=' }); "
                    "if ($env:GE_TARGET) { $kept += 'texture_path = ' + $env:GE_TARGET }; $temp=$path + '.new'; "
                    "[IO.File]::WriteAllLines($temp, [string[]]$kept); [IO.File]::Copy($temp, $path, $true); "
                    "[IO.File]::Delete($temp) } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }")

WINDOWS_START = r"""@echo off
setlocal
if defined GOLDEN_ERA_DATA_DIR (
  set "GE_DATA=%GOLDEN_ERA_DATA_DIR%"
) else (
  set "GE_DATA=%LOCALAPPDATA%\GoldenEraPlaytest"
)
if not exist "%GE_DATA%\settings.conf" (
  echo Golden Era has not been started on this PC yet. Start it once with start.bat, close it, then run this again.
  goto failed
)
"""

WINDOWS_INSTALL = WINDOWS_START + r"""set "GE_TARGET=%GE_DATA%\textures\{name}"
if exist "%GE_TARGET%" if not exist "%GE_TARGET%\description.txt" (
  rem No path in the message: a save folder name with ^& would split the echo.
  echo The Golden Era textures folder already has a {name} folder that is not a converted pack; it was left unchanged.
  goto failed
)
echo Copying the {name} textures...
if exist "%GE_TARGET%" rmdir /s /q "%GE_TARGET%"
xcopy "%~dp0{name}" "%GE_TARGET%\" /e /i /q /y >nul
if errorlevel 1 goto failed
powershell.exe -NoProfile -Command "{settings}"
if errorlevel 1 goto failed
echo Done. Golden Era will use the {name} textures the next time it starts.
echo To go back to the normal textures, run use-default-textures.bat.
pause
exit /b 0
:failed
echo The textures were not switched.
pause
exit /b 1
"""

WINDOWS_REMOVE = WINDOWS_START + r"""set "GE_TARGET="
powershell.exe -NoProfile -Command "{settings}"
if errorlevel 1 goto failed
echo Done. Golden Era will use its normal textures the next time it starts.
pause
exit /b 0
:failed
echo The textures were not switched.
pause
exit /b 1
"""

WINDOWS_README = """Converted textures for Golden Era: {name}

These were converted from texture packs the owner bought or downloaded for their
own use. Keep them to yourself; do not share or upload them.

1. Start Golden Era once with start.bat and close it, if you have not already.
2. Double-click install-textures.bat.
3. Start Golden Era again.

To go back to the normal textures, double-click use-default-textures.bat.
"""


def data_dir():
    """The save folder start.sh uses."""
    if os.environ.get("GOLDEN_ERA_DATA_DIR"):
        return Path(os.environ["GOLDEN_ERA_DATA_DIR"]).resolve()
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/GoldenEraPlaytest"
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "golden-era-playtest"


def set_texture_path(settings, value):
    lines = [line for line in settings.read_text().splitlines() if not SETTING.match(line)]
    if value:
        lines.append("texture_path = " + str(value))
    temp = settings.with_name(settings.name + ".new")
    temp.write_text("\n".join(lines) + "\n")
    temp.replace(settings)


def converted(pack):
    description = pack / "description.txt"
    return description.is_file() and MARKER in description.read_text()


def install(pack, data):
    target = data / "textures" / pack.name
    if target.exists() and not converted(target):
        sys.exit(str(target) + " already exists and is not a converted texture pack; it was left unchanged.")
    shutil.rmtree(target, ignore_errors=True)
    shutil.copytree(pack, target)
    set_texture_path(data / "settings.conf", target)
    print("Golden Era will use", pack.name, "the next time it starts:", target)


def windows_zip(pack, output):
    def bat(text):
        return text.replace("{name}", pack.name).replace("{settings}", WINDOWS_SETTINGS).replace("\n", "\r\n")
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(pack.rglob("*")):
            if path.is_file():
                archive.write(path, pack.name + "/" + path.relative_to(pack).as_posix())
        archive.writestr("install-textures.bat", bat(WINDOWS_INSTALL))
        archive.writestr("use-default-textures.bat", bat(WINDOWS_REMOVE))
        archive.writestr("README.txt", WINDOWS_README.replace("{name}", pack.name).replace("\n", "\r\n"))
    print("Windows ZIP:", output)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("pack", nargs="?", type=Path, help="Texture pack folder made by convert.py")
    parser.add_argument("--remove", action="store_true", help="Go back to Golden Era's own textures")
    parser.add_argument("--windows-zip", type=Path, help="Write a ZIP for a Windows PC instead of installing here")
    args = parser.parse_args()
    if args.remove == bool(args.pack):
        parser.error("give a texture pack folder or --remove")
    if args.pack:
        pack = args.pack.expanduser().resolve()
        if not converted(pack):
            sys.exit(str(pack) + " is not a texture pack made by convert.py.")
        if args.windows_zip:
            output = args.windows_zip.expanduser().resolve()
            if ROOT in output.parents:
                sys.exit("Refusing to write converted textures inside the repository: " + str(output))
            return windows_zip(pack, output)
    data = data_dir()
    if not (data / "settings.conf").is_file():
        sys.exit("Golden Era has not been started yet; start it once with start.sh, close it, then run this again.")
    if args.pack:
        install(pack, data)
    else:
        set_texture_path(data / "settings.conf", None)
        print("Golden Era will use its own textures the next time it starts.")


if __name__ == "__main__":
    main()
