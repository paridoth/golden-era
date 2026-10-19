This is a Wine compatibility smoke test for the real Windows release, run on
Linux without installing system packages. It does not establish native Windows
support. In particular, Windows PowerShell 5.1 downloads, SmartScreen, actual
Windows file locking/security, and hardware graphics still need a Windows tester.

Run the actual frozen 0.1.1 installer and check installed payload, shortcuts and
reinstall preservation:

    python3 tests/windows-native/run.py --fetch-tools
    python3 tests/windows-native/run.py

Exercise the exact current world-creation block with real cmd.exe, independent
of PowerShell preflight/download availability:

    python3 tests/windows-native/run.py --world-creation-smoke

The frozen 0.1.1 block is also executed to record Wine's block-redirection
behavior. The current block must write all five game/backend keys, including
with spaces and `&` in the data path. Both blocks must leave an existing
world.mt byte-for-byte unchanged. This isolates CMD syntax from the full
Windows PowerShell preflight, which this Wine setup cannot execute.

Also run the official cached Windows x86-64 Luanti executable with the complete
installed game and existing stock-factory/recipe smoke, using a disposable world:

    python3 tests/windows-native/run.py --engine-smoke

To additionally run the actual installed batch launcher through Wine's cmd.exe,
click the real first-join workshop chooser, and reconnect to verify saved
choice/inventory/position, use:

    python3 tests/windows-native/run.py --engine-smoke --launcher-smoke

This GUI test reuses the existing gameplay observer in `tests/playtest/gui.py`.
It precaches the verified official engine, so it deliberately skips the
PowerShell first-download branch. All input and screenshots use the same
authenticated private Xvfb display. Screenshots and command logs are retained
under `runtime/tests/windows-wine-logs` even when the private prefix is cleaned.

The official 5.17.0 engine emits repeated builtin-file SHA256 lookup warnings in
this Windows-path environment. The corresponding confirmed upstream issue is
[Luanti #17607](https://github.com/luanti-org/luanti/issues/17607); it also has a
native Windows 10 reproduction. The test records warning counts separately and
retains the output. It does not suppress warnings or replace the stock engine.

Evidence screenshots `windows-wine-0.1.1-workshop-chooser.png` and
`windows-wine-0.1.1-workshop-selected.png` were captured from the unchanged
0.1.1 release in a private automated Wine/Xvfb session on 2026-10-19. They
depict Golden Era's forms and the bundled Mineclonia/Elepower/Pipeworks game
assets; upstream authors, source pins and asset licenses are recorded in the
release's `docs/THIRD-PARTY-NOTICES.md` and `docs/LICENSE-INVENTORY.json`.
The screenshots' capture/arrangement is CC-BY-SA-4.0; depicted upstream assets
retain their original notices and licenses. They are test evidence, not newly
authored game textures.

Wine 9's Ubuntu amd64 and i386 packages and the Windows zlib dependency are pinned
by upstream distro URL, version, size and apt metadata SHA256 in
`packaging/windows-test/wine.lock.json`. Downloads stay in the ignored reference
cache. Tools are reconstructed under `tools/wine-root`. The test uses already
available host runtime libraries for both architectures; it never enables
multiarch or invokes a system package installation.

Two developer-tool relocation adjustments are explicit in the lock: a local
wineserver dispatcher replaces Debian's hardcoded `/usr/lib/wine` path, and the
pinned native Windows zlib DLLs are seeded into the isolated prefix so Wine can
find them without its compiled system search paths. Wine and its test libraries
are not included in game distributions.

Each test creates its own prefix and XDG data/config/cache/runtime directories
under `runtime/tests`. XDG user directories are configured before wineboot, and
all Wine user special-folder symlinks are checked before installation. The user's
HOME and personal Wine prefix are never replaced. Menu integration, Mono and
Gecko are disabled. Xvfb uses private display :99, a fresh authorization cookie
and no TCP listener; an occupied display causes the test to stop. Desktop links
are created only in that test's isolated Desktop folder.

The installer must match its release manifest; frozen 0.1.1 additionally has an
explicit expected SHA256. All installed files are verified by SHA256, and actual
Windows `.lnk` files are checked for the exact versioned launcher target. The
test reinstalls and confirms existing world/settings sentinel bytes survive.
The optional engine smoke checks the original official engine ZIP against the
same SHA256 pin shipped in the installed bootstrap. It executes the real Win64
binary under Wine against the installed game, rather than a Linux rebuild.

A concise report is written to `runtime/tests/windows-wine-smoke.txt`. Use
`--keep-prefix` only when diagnosing failures; retained prefixes take roughly
1.5 GB each. Ordinary runs clean their workspace after stopping the private
Wine server and Xvfb. The test never writes or replaces a dist artifact.
