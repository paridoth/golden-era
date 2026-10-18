# Golden Era

A native Luanti/Mineclonia game prototype using **FTB Revelation 3.7.0 for
Minecraft Java 1.12.2** as its gameplay reference. Golden Era is a provisional
project name. This is an independent engineering prototype; it is not an
accurate or complete recreation, and is not affiliated with Mojang, Microsoft,
Feed The Beast, or the original mod authors.

The working slice generates RF from coal or charcoal and water, pulverizes iron
ore/raw iron into dust, smelts dust, and routes primary ingots into a native
Mineclonia chest. New machines use sourced basic RF/water values, persisted nickel byproducts
item-side controls and fifteen reviewed crafting patterns. Existing saves retain a legacy profile until explicitly
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
inspection but are not installed into this runtime.

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
remaining burn or items cannot be dug; there is
no discharge/wrench tool yet. Processor faces and ejectors are configurable; see [item sides](docs/item-sides.md).

## Development records

- [Graphical client and inspection demo](docs/graphical-client.md)
- [Architecture and invariants](docs/architecture.md)
- [Native crafting and its current limits](docs/native-crafting.md)
- [Survival materials and basic energy cell](docs/survival-materials.md)
- [Native RF/water operation and migration](docs/native-resources.md)
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
and the upstream notices. The inherited media audit is incomplete; no public
binary/game distribution has been prepared or cleared.
