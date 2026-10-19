Golden Era Linux releases contain the complete game, Lua source, model source
supplement, licenses and Linux launchers. No local engine binary or host libraries
are redistributed. The locally built engine requires a recent glibc; wrapping it
in an archive or AppImage would not make it portable to older distributions.

The recommended engine is the official Luanti Flatpak, `org.luanti.luanti`.
The previous Flatpak identifier `net.minetest.Minetest` is obsolete for this
release. The [official download page](https://www.luanti.org/en/downloads/)
recommends Flatpak for Linux. [Flathub](https://flathub.org/apps/org.luanti.luanti)
publishes the application for x86_64 and aarch64. The package is game data and
scripts, so the engine determines the CPU/platform support.

For a new version, build a verified base game ZIP first, then derive the Linux
archive. Registered frozen releases cannot be replaced; bump the active version
before a new release, or choose a separate explicit diagnostic output path:

    python3 scripts/package-playtest.py
    python3 scripts/package-linux.py --game-zip dist/golden-era-playtest-0.1.5-windows-test.zip
    python3 scripts/package-linux.py --verify dist/golden-era-playtest-0.1.5-linux.tar.gz

The Linux archive uses sorted files, fixed timestamps, normalized permissions,
and normalized archive ownership. It carries an internal SHA256 file manifest,
an external manifest and a whole-archive checksum. Its Linux additions include
their source. The base game ZIP is verified before packaging; original world
databases and private developer files stay excluded.

Tester instructions: extract the complete archive, open `Install Luanti.flatpakref`
if a compatible engine is absent, and then open `Play Golden Era.desktop`.
The desktop may require “Allow Launching”. A terminal fallback is `sh ./start.sh`.
The itch desktop app can install `.tar.gz` archives and invoke the included
`.itch.toml` play action; its engine prerequisite still applies. This integration
follows itch.io's [archive compatibility guidance](https://itch.io/docs/itch/integrating/compatibility-policy.html)
and [launcher action format](https://itch.io/docs/itch/integrating/manifest-actions.html).
`sh ./start.sh --install-engine` explicitly installs the official Flatpak into
the tester's user installation; normal startup never changes installed software.
Flatpak must already be supported by the distribution, and its first installation
can download a large shared runtime. The package does not need administrator
permissions when a compatible engine/Flatpak installation is already available.

The launcher accepts installed Luanti 5.17.0 or newer, including a compatible
native `minetest` command or an explicit `GOLDEN_ERA_ENGINE` executable. Engine
5.17.0 is the tested reference; newer versions remain unverified. `--check`
checks engine selection without creating a save. Engine installation follows
signed Flathub stable; it does not pin or automatically downgrade a tester's
installed engine. Observed engine/manifest commits and the bundled installation
reference hash are recorded in `packaging/linux/engine-reference.json`.

Game data is read-only inside the Flatpak sandbox. Only the selected Golden Era
data directory is writable through the launcher's additional filesystem grants.
No broad `home` or `host` filesystem grant is added. Saves, settings and logs
default to `$XDG_DATA_HOME/golden-era-playtest` or
`~/.local/share/golden-era-playtest`, separate from the extracted release.
`GOLDEN_ERA_DATA_DIR` overrides this path. Existing settings/world metadata are
kept on subsequent launches. Back up that data directory before updating.
Before creating settings, logs or save files, both Unix launchers check the
existing world's final case-sensitive `gameid`. Foreign, missing or ambiguous
IDs are refused with existing files untouched. Known world databases without
`world.mt` are also refused: restore the original metadata or choose a different
data directory. Nonstandard grouped/multiline metadata is conservatively
refused; ordinary flat Luanti metadata, comments, CRLF and repeated keys work.

Actual Flatpak sandbox execution and graphical launch depend on host namespace,
display, driver and portal support; native headless tests are documented
separately from Flatpak checks. Do not claim graphical/Linux distribution-wide
verification from a source-only or simulated launcher check.

Developer validation:

    python3 tests/linux/test_save_guard.py
    python3 tests/linux/run.py dist/golden-era-playtest-0.1.5-linux.tar.gz --launcher-only
    python3 tests/linux/run.py dist/golden-era-playtest-0.1.5-linux.tar.gz --flatpak-runtime --farming-smoke

The `--flatpak-runtime` command expects the official app in the repository-only installation
at `runtime/tests/linux-flatpak/installation` and Freedesktop runtime 26.08.
For this test installation, set `FLATPAK_USER_DIR` to that absolute directory and
`XDG_CACHE_HOME`, `XDG_DATA_HOME`, and `XDG_CONFIG_HOME` to sibling `cache`, `data`,
and `config` paths under `runtime/tests/linux-flatpak`, then run
`flatpak install --user --no-related --from packaging/linux/templates/Install\ Luanti.flatpakref`.
These environment variables keep installation/cache work inside the repository;
they are test setup and are not needed by players. The host's installed system
runtime can be reused. A runtime download is needed if it is absent.

Ordinary `flatpak run org.luanti.luanti` creates `~/.var/app` even with these XDG
variables changed. To honor repository-only work, the test executes the exact
official application binary using `flatpak run --app-path` inside its matching
runtime, with game read-only and save writable. The ordinary app backend's
argument/permission transport is tested with a stub separately. The test also
uses Gio to dispatch the real desktop entry when available, with a stub engine.
Its evidence distinguishes these checks from an actual graphical game run.

The graphical onboarding test can also use the exact installed official client:

    python3 tests/playtest/gui.py --engine tests/linux/flatpak-client.sh --evidence-dir runtime/tests/onboarding-flatpak-0.1.5-final

The complete 0.1.4 run passed both real start choices, workshop arrival/loading
HUD and saved inventory/position through restart. The 0.1.5 Farming page has a
separate actual-client layout capture: its observer opens page 6 after a real
survival-choice click. This is not a repeated full onboarding/reconnect run.
The helper uses a self-contained game copy,
the repository-only installation and matching Freedesktop runtime, authenticated
Xvfb and software graphics. OpenAL uses its null backend because the test has no
audio device. It validates the official client binary, not ordinary app/portal
startup, hardware graphics or audible sound. Initial fresh joins retain the two
known Mineclonia craft-width warnings; reconnects had no warnings or errors.

The optional `--storage-smoke`, `--removal-smoke`, `--pipeworks-smoke` and
`--farming-smoke` checks
use separate fresh saves within the existing sandbox data grant. They load the
archive's Drawers, Elepower and Pipeworks code, exercise real native spills/blasts,
full item metadata and both filter piston policies, and restart the storage and
Pipeworks worlds. The Pipeworks check also exercises native historical refunds
and preview markers through actual block activation. These callbacks use detached
fixture actors; human mining, multiplayer upgrade editing and a full survival
playthrough remain separate checks. `--launcher-only` cannot be combined with
these repair checks.

The 0.1.5 archive check runs the factory and farming checkpoint/restart. The farm
uses the archived harvester timer, real coal, crop callbacks, seeds returned by
clocked tubes and saved ownership. Supplied bone meal bounds test duration; this
does not establish natural crop-growth timing or a complete human survival run.
Unchanged storage/removal/Pipeworks sources retain their separately recorded
0.1.4 native evidence.
