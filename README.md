# Golden Era

The current priority is a **playable pack built from existing Luanti mods**,
using FTB Revelation as the experience to work toward. Launch the new playtest:

```sh
python3 scripts/play-playtest.py
```

It combines Mineclonia, the full Elepower technology pack, Pipeworks, fluid
tanks/ducts, Storage Drawers and Mesecons. Version 0.1.7 development adds the
Logistica storage network, Travelnet, Extra Structures and a Mineclonia port of
the Magicalities magic mod; `/manual` opens the in-game Golden Era Manual. Version 0.1.8 opens a main menu with LAN hosting, uses E for the inventory and Left Ctrl to sprint, and places farm animal herds in new terrain. Version 0.1.9 shows loading progress in the Windows launcher window, and testers who own Minecraft 1.12 texture packs can convert them locally (see docs/textures.md). A supplied workshop lets you operate
and expand a factory immediately; `/packhelp`, `/workshop` and `/explore` are
available in-game. See [playtest instructions](docs/playtest.md) for controls,
the persistent world location and current coverage. This uses native equivalents
and stock progression; exact Revelation recipes/systems will be added as play
reveals the priorities. The earlier custom factory remains available separately.

**Testers on Windows:** download the installer (`golden-era-playtest-<version>-windows.exe`,
labelled "Windows installer (start here)") from the
[latest release](https://github.com/paridoth/golden-era/releases) and open it.
For building and publishing releases, see [the release guide](docs/github-release.md).
The Windows EXE installs and launches automatically. A separate Linux archive
uses an installed Luanti engine or the official Flatpak. Both include source,
credits and license notices. New players can choose a supplied workshop or
survival progression; `/factoryguide` explains the early machinery.
Use `/packversion` to identify the running build when reporting a problem.
Windows and Linux are the active delivery targets. Release hashes, source
revisions and executed checks are retained under [release records](docs/releases/).
The optional custom-engine controller experiment is separate from these builds.

## Earlier native factory and reference work

A native Luanti/Mineclonia game prototype using **FTB Revelation 3.7.0 for
Minecraft Java 1.12.2** as its gameplay reference. Golden Era is a provisional
project name. This is an independent engineering prototype; it is not an
accurate or complete recreation, and is not affiliated with Mojang, Microsoft,
Feed The Beast, or the original mod authors.

The working slice generates RF from coal or charcoal and water, pulverizes iron
ore/raw iron into dust, smelts dust, and routes primary ingots into a native
Mineclonia chest. New machines use sourced basic RF/water values, persisted nickel byproducts
item-side controls and sixteen reviewed crafting patterns. Existing saves retain a legacy profile until explicitly
upgraded. Tin, silver and lead generate in new terrain and support the first
factory/storage crafting path. Ducts and a complete survival playthrough remain
pending. See [native resources](docs/native-resources.md)
and [native crafting](docs/native-crafting.md) for the supported boundaries.

The user selected Revelation on October 18, 2026, superseding the earlier
Direwolf20 1.7.10 target in the preserved migration handoff. The Luanti engine,
Mineclonia foundation and tested factory infrastructure remain in use. Our goal
is native implementations grounded in the actual pack's data and observed
behavior. The Java mods are reference inputs; this game does not execute them.

## Reference inputs and development pathway

The exact pack identity, targets, 1000 manifest file entries and content digest
are pinned in [references/revelation-3.7.0.lock.json](references/revelation-3.7.0.lock.json).
All 675 selected config files and four scripts were downloaded and hash-verified
into an ignored local cache. A reviewed
[configuration fact sheet](references/revelation-3.7.0-facts.json) records source
hashes and line numbers. These are configuration facts, not completed runtime
parity or a complete recipe export.

```sh
python3 scripts/reference.py fetch
python3 scripts/reference.py check
python3 scripts/reference.py report
python3 scripts/reference.py facts
```

The [first Thermal behavior specification](docs/thermal-factory-spec.md) now
includes selected recipes, fuel values, water/buffer rules and upgrade factors
from the exact JARs. Its bounded importer preserves metadata and unresolved
material groups. Run `python3 scripts/thermal_reference.py fetch` followed by
`python3 scripts/thermal_reference.py check` to verify it locally.

Reference import downloads inert config/script files and selected JARs; it never
runs an installer, Java, Forge, mod code or recipe scripts. See the
[reference workflow](references/README.md) and [roadmap](docs/roadmap.md).

## Build and test

The active existing-mod pack is assembled and checked separately from the earlier
custom factory. After the local bootstrap below, run:

```sh
python3 scripts/setup-playtest.py
python3 tests/playtest/run.py
```

`./scripts/ci.sh` also runs the survival material, native automation, storage and
machine-removal regressions. These use disposable worlds. See
[playtest instructions](docs/playtest.md) for the active game and
[the release guide](docs/github-release.md) for packaging.

The following bootstrap and custom-factory commands preserve the original
prototype and its independent worlds.

Supported bootstrap: Linux Mint 22.x / Ubuntu 24.04, x86_64. Have Git, Python 3,
GCC/G++, normal development headers, make, apt-get, dpkg-deb, and at least 1 GB
free space (more for worlds). The scripts extract locked Debian packages into
`tools/root`; they do not install system packages. Do not run them with sudo.

```sh
./scripts/setup.sh
./scripts/test.sh
./scripts/test.sh --integration
```

The main source revisions are in [upstream.lock.json](upstream.lock.json);
exact package versions and SHA-256 hashes are in
[build-deps.lock.json](build-deps.lock.json). The migration archive includes
source checkouts and cached packages. A Git-only checkout must fetch those
sources and download the exact packages from configured apt repositories.
Unavailable versions fail the build; do not silently replace them.

The build creates a headless Luanti 5.17.0 server with bundled Lua 5.1.5, using
two compiler jobs. It assembles Mineclonia 0.124.0 and the custom mods under
`runtime/games/golden_era`. Technic, Pipeworks and Mesecons are downloaded for
comparison but are not installed into this runtime. Pipeworks' three dependencies
are also pinned. The active existing-mod pack already uses native transport,
power/fluid, storage and tooling; this earlier runtime remains available for
reference-driven experiments. See [compatibility findings](docs/mod-compatibility.md).

An isolated Pipeworks feasibility probe already routes items into our native
machines with guarded callbacks. Run `python3 tests/reuse/run.py` after setup;
see [its scope and instructions](tests/reuse/README.md). It uses a disposable
game/world and does not enable Pipeworks in normal play.

The relocated build, unit tests, engine crafting checks, and
restart/configuration/chunk-lifecycle suite are recorded in
[docs/test-results.md](docs/test-results.md). That document distinguishes executed
checks from remaining validation. Original migration evidence remains under
`handoff/`; its source manifest describes the original archive, not later edits.

## Run locally

```sh
./scripts/run-server.sh
```

Connect a separately installed compatible Luanti graphical client to
**127.0.0.1:30099**. An optional [local graphical build](docs/graphical-client.md)
and isolated factory demo are available:

```sh
python3 scripts/build-client.py
python3 scripts/play-demo.py
```

The server
binds only to loopback, does not announce itself, and uses engine v7 terrain.
Stop with Ctrl-C. Keep network exposure changes deliberate.

Your world lives at `runtime/worlds/play`. To back it up, stop the server cleanly
and copy that whole directory. Do not copy a live SQLite file on its own. Worlds,
downloads, extracted tools, generated runtime files and binaries are untracked.

## Factory fixture

At a common y-level, use these relative coordinates. East is +X.

| (x,z) | Node |
| --- | --- |
| (0,2) | `era_thermal:generator` |
| (1,2) | `era_thermal:buffer` |
| (0,1) | `era_energy:cable` |
| (0,0) | `era_thermal:pulverizer` |
| (1,0) | `era_thermal:furnace` |
| (2,0) | `era_transport:ejector` |
| (3,0) | ordinary Mineclonia chest |

For new machines, put one coal in the generator's fuel slot, a water bucket in
its Water slot, leave Empty free, and put two iron ore or raw iron items in the
pulverizer's input. Configure the furnace's west face as In. The intended result is four ingots in the chest. The
integration harness constructs this fixture at y=200 using engine APIs. Manual
placement, formspec use and survival progression still need graphical testing.
Machines with invalid saved state pause with a diagnostic and retain their
contents; see the saved-state repair notes. Machines containing RF, work,
remaining burn or items cannot be dug normally. A Factory Wrench can
[pack and relocate them](docs/relocation.md) while retaining their state. Processor faces and ejectors are configurable; see [item sides](docs/item-sides.md).

## Development records

- [Graphical client and inspection demo](docs/graphical-client.md)
- [Architecture and invariants](docs/architecture.md)
- [Native crafting and its current limits](docs/native-crafting.md)
- [Survival materials and basic energy cell](docs/survival-materials.md)
- [Native RF/water operation and migration](docs/native-resources.md)
- [Filled-machine relocation](docs/relocation.md)
- [Saved-state validation and repair](docs/save-state.md)
- [Historical reference and provisional values](docs/historical-reference.md)
- [Compatibility findings](docs/mod-compatibility.md)
- [Fidelity matrix](docs/fidelity-matrix.md)
- [License and provenance records](docs/licenses.md)
- [Development log](docs/development-log.md)
- [Executed test results and limits](docs/test-results.md)
- [Original migration handoff](HANDOFF.md)

Original project code and documentation use GPL-3.0-or-later, except for preserved
third-party notices and evidence. The four original placeholder textures use
CC0-1.0. See [LICENSE](LICENSE), [texture NOTICE](mods/era_core/textures/NOTICE.md)
and the upstream notices. The inherited media audit has limits documented in the packaged notices.
Local tester packages retain source, credits and licenses; their validation and
distribution limits are recorded in the release guide.
