# Golden Era: GitHub tester releases

Golden Era is shared through GitHub releases only (user direction, 2026-10-28).
Each version is a full release, marked latest, so
https://github.com/paridoth/golden-era/releases/latest always opens the newest
one. It has three files:

- `golden-era-playtest-<version>-windows.exe`, labelled
  **Windows installer (start here)**. The release notes open with a direct
  download link to it.
- `golden-era-playtest-<version>-windows-test.zip`, a fallback without the
  installer: extract it all and run `start.bat`.
- `golden-era-playtest-<version>-linux.tar.gz`; see [Linux setup](linux-release.md).

The current release is
[0.1.11](https://github.com/paridoth/golden-era/releases/tag/v0.1.11); its
hashes and executed checks are in [its record](releases/0.1.11.json).

## What testers get

The EXE extracts the game to `%LOCALAPPDATA%\GoldenEraPlaytest\app\<version>`,
adds desktop and Start Menu shortcuts and opens the main menu, showing progress
without a setup wizard. Reinstalling keeps saves, settings and the downloaded
engine in the parent data folder, and older app folders that hold no worlds or
settings are removed when the game is not running. `/S` installs silently
without launching. The EXE is unsigned: SmartScreen may ask the tester to
choose **More info → Run anyway**.

The first launch downloads the official Luanti 5.17.0 portable ZIP (about
18 MB), verifies its pinned SHA-256 and caches it. No admin rights or Java are
needed. The packages contain the game, launchers, `START-HERE.txt`, source,
credits, licenses and per-file provenance, and no developer world,
authentication data, Git checkout, original Java mods or engine binaries.

Testers report problems with the output of `/packversion`, their steps,
the expected and actual result, and a screenshot or `logs/client.log` from the
save-data folder when useful.

## Build and verify

```sh
python3 scripts/setup-playtest.py
python3 scripts/package-playtest.py --fetch-supplements
python3 scripts/package-playtest.py --verify dist/golden-era-playtest-<version>-windows-test.zip
python3 tests/package/run.py dist/golden-era-playtest-<version>-windows-test.zip
python3 scripts/package-installer.py --fetch-toolchain
python3 scripts/package-installer.py --verify dist/golden-era-playtest-<version>-windows.exe
python3 scripts/package-linux.py
python3 tests/linux/run.py dist/golden-era-playtest-<version>-linux.tar.gz --flatpak-runtime --farming-smoke
python3 tests/windows-native/run.py --installer dist/golden-era-playtest-<version>-windows.exe
python3 tests/windows/run.py
```

Build from a clean commit so `build-info.json` reports `dirty: false`. The ZIP
is built from pinned sources with symlinks dereferenced, and its manifest
records sizes, modes, hashes and provenance. The installer is built with pinned
NSIS packages extracted locally; its verification requires every extracted file
to match the ZIP, with only the enumerated installer files added. The explicit
fetch options restore missing hash-verified inputs; ordinary builds perform no
downloads and install no system packages. Build outputs are ignored under `dist/`.

Frozen outputs are protected: select a new version in
`packaging/playtest/release.json` and the `START-HERE.txt` header before
building a new release. Verification commands are read-only.

## Publishing

Publishing needs the user's go-ahead. Create the release from the built
revision, labelling the installer so it stands out:

```sh
gh release create v<version> --target <revision> --latest \
  --title "Golden Era <version>" --notes-file <notes.md> \
  "dist/golden-era-playtest-<version>-windows.exe#Windows installer (start here)" \
  "dist/golden-era-playtest-<version>-windows-test.zip#Windows ZIP fallback" \
  "dist/golden-era-playtest-<version>-linux.tar.gz#Linux"
```

Begin the notes with a download link to the EXE, then the changes, the other
downloads and the known limits. Download the published files once and compare
their SHA-256 with `dist/`, then record the release in `docs/releases/`.

Native Windows, SmartScreen and hardware graphics still need a Windows tester;
Wine checks are a compatibility check on Linux.
