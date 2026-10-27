# Golden Era 0.1.10: itch.io tester release

Version 0.1.10 makes new terrain richer: villages appear about twice as often,
graveyards, oases, logger camps, obelisks, ice towers and brick pyramids far
more often, and about one in three generated chests holds a few factory parts.
Hosting a world on the LAN now continues as the single-player character, with
its inventory, armor, experience and position. The Windows installer removes
older Golden Era app folders it can safely identify. Everything from 0.1.9
remains. Keep your save-data folder when updating; the existing world appears in
the menu, and only terrain explored after updating gets the new structures.
The installer is also attached to the GitHub pre-release
https://github.com/paridoth/golden-era/releases/tag/v0.1.10.

Shareable artifact: `dist/golden-era-playtest-0.1.10-windows.exe`.
ZIP fallback: `dist/golden-era-playtest-0.1.10-windows-test.zip`.
Linux: `dist/golden-era-playtest-0.1.10-linux.tar.gz`; see [Linux setup](linux-release.md).

The EXE automatically extracts the game to
`%LOCALAPPDATA%\GoldenEraPlaytest\app\0.1.10`, adds desktop and Start Menu
shortcuts, and launches the game. It shows extraction progress without a setup
wizard. No manual ZIP extraction is needed. Reopen the shortcut to play again.
Reinstalling keeps saves, settings and the downloaded engine in the parent data
folder. Close the game before rerunning setup. The EXE is unsigned; Windows may
show an unknown-publisher warning.

The ZIP contains the complete game pack, fresh-save launchers, instructions,
source, credits/licenses and per-file provenance. It contains no developer
world, authentication data, Git checkout, original Java mods or engine binaries.
The Windows launcher downloads the official Luanti 5.17.0 portable ZIP on first
use, verifies its pinned SHA-256, then starts the supplied game. Later launches
use that cached engine. No admin installation or Java is needed.

## Upload and share

1. Create a downloadable itch.io project. Suggested title:
   **Golden Era — Factory Playtest**. Set it free and in development.
2. Upload the EXE above. The ZIP can be offered as an optional fallback.
   Manifest sidecars are for our verification; `.sha256` files are checksums.
3. Use **Restricted** visibility with a password or tester download key.
   Draft mode is intended for editing and does not give ordinary visitors
   downloads. See the [access-control documentation](https://itch.io/docs/creators/access-control).
4. Send the project link and password/key to the tester yourself. No account,
   project page, upload or publication has been created by this packaging work.

This is a Luanti game pack with a Windows installer and bootstrap launcher. For
the first test, have the tester download through the browser and open the EXE.
Native Windows startup and the itch app launch action still need
confirmation. Until those pass, describe it as a Windows test candidate rather
than a verified Windows release, and use a game-pack/Other classification.
itch.io asks creators to [select only platforms they have tested](https://itch.io/docs/creators/quality-guidelines).
The `.itch.toml` selects the relevant launcher on each operating system; its
format follows the [manifest guide](https://itch.io/docs/itch/integrating/manifest-actions.html).

## Suggested page text

Golden Era is an early voxel survival and factory-building playtest built from
existing open-source Luanti mods. Start with a supplied workshop, experiment
with power generation and ore processing, route items through tubes, and expand
your storage and machinery into a survival world.

The pack includes Mineclonia, Elepower, Pipeworks, fluid tanks and ducts,
Storage Drawers and Mesecons. It is inspired by classic modded Minecraft
automation. It is an independent community game pack and is not Minecraft or
the original FTB Revelation pack. Exact Revelation recipes and additional
systems remain future work.

**Windows test instructions:** open `golden-era-playtest-0.1.10-windows.exe`.
It installs automatically, creates a shortcut and opens the main menu; select
the playtest world and choose Play Game. New players
choose the supplied workshop or a survival start without workshop tools/materials.
Existing players retain their position and inventory. Workshop preparation shows
a loading message and resumes an unfinished trip after reconnecting;
`/cancelworkshop` cancels it. First launch
needs internet to download the official Luanti engine
(about 18MB), with a checksum check.
`/factoryguide` explains early progression, `/packhelp` shows workshop instructions, `/workshop` returns to the factory, and `/explore`
returns to survival terrain. Saves are kept in
`%LOCALAPPDATA%\GoldenEraPlaytest`, outside the installed game folder.

The starter line turns two raw iron into four ingots in about two minutes.
Damage is disabled. The optional workshop provides spare parts and enables flight
in single-player; the survival start grants no workshop materials. Please
report broken or confusing interactions with the build number, steps,
expected/actual result, and a screenshot or log when useful.

## Checks and limits

The ZIP is built from clean pinned sources with symlinks dereferenced. Its
manifests record sizes, modes, hashes and provenance. Two fresh builds produced
identical bytes. The package retains local notices/credits, eight supplemental
license texts and the model authoring sources identified by Mineclonia. The
bundle notices record the exact source-correspondence limit and inherited
license exceptions.

The packaged game is checked from a clean extraction through its Unix launcher
using the existing Luanti engine. The final 0.1.5 installer and official Win64
factory plus farming checkpoint/restart are checked separately under Wine. The
unchanged storage, machine-removal and Pipeworks runtime files retain their
executed 0.1.4 evidence; they were compared byte for byte before reusing it.
The earlier frozen 0.1.1 batch also passed a graphical workshop choice and
save/reconnect under Wine. The unchanged current batch/preflight commands have
separate PowerShell 7/Linux evidence. Wine is a compatibility check on Linux.
The three final Windows engine processes each retained 107 documented builtin
SHA warnings, with zero other engine warnings or errors. The three official Linux
engine processes had zero warnings or errors. Their raw evidence is retained in
[the 0.1.5 release record](releases/0.1.5.json); 0.1.10 checks are in [its record](releases/0.1.10.json).
Native Windows, Windows PowerShell 5.1, SmartScreen and hardware graphics remain
for a Windows tester. Exact bootstrap/save-preflight commands run separately under
PowerShell 7 on Linux; their scope and hashes are retained in the evidence.

The EXE is built with pinned NSIS packages extracted locally, using its zlib
stub and System plugin. Its ordinary-user PE manifest and every extracted file
are checked: all original ZIP files must match byte for byte, with only the
enumerated installer source, metadata and NSIS notices added. The installed
`installer-support/EXTRA-FILES.json` identifies these additions; the original
game file manifest remains valid. `/S` installs without launching the game.

## Build and verify

```sh
python3 scripts/setup-playtest.py
python3 scripts/package-playtest.py --fetch-supplements
python3 scripts/package-playtest.py --verify dist/golden-era-playtest-0.1.10-windows-test.zip
python3 tests/package/run.py dist/golden-era-playtest-0.1.10-windows-test.zip
python3 scripts/package-installer.py --fetch-toolchain
python3 scripts/package-installer.py --verify dist/golden-era-playtest-0.1.10-windows.exe
python3 scripts/package-linux.py
python3 tests/linux/run.py dist/golden-era-playtest-0.1.10-linux.tar.gz --flatpak-runtime --farming-smoke
```

Frozen outputs are protected: select a new version in
`packaging/playtest/release.json` and the instruction header before creating a
new release. The build commands above use that active version. To reproduce a
frozen source snapshot for diagnostics, use a separate explicit output path;
verification commands remain read-only.

The explicit fetch option restores missing hash-verified model-source inputs.
Ordinary builds perform no downloads and fail if those inputs are missing,
modified or unexpected. Build outputs are ignored under `dist/`.
The installer command similarly downloads its pinned compiler packages only
when `--fetch-toolchain` is supplied, and installs no system packages. It needs
Linux amd64 with Python 3, `dpkg-deb`, `7z` and the compiler's host libraries.
The original validated ZIP can be wrapped directly without rebuilding the game.
