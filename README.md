# Golden Era

A Luanti/Mineclonia factory prototype inspired by the initial late-2014
Direwolf20 experience on Minecraft Java 1.7.10. Golden Era is a provisional
project name. This is an independent engineering prototype; it is not an
accurate or complete recreation, and is not affiliated with Mojang, Microsoft,
Feed The Beast, or the original mod authors.

The working slice generates integer RF from coal, moves it through adjacent
machines/cables, pulverizes iron ore or raw iron into dust, smelts dust, and
routes ingots east into an ordinary native Mineclonia chest. Six custom mods
provide the implementation. Machine values, capacities and recipes are
**provisional** pending a pinned launch-era reference.

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
**127.0.0.1:30099**. This build does not provide a graphical client. The server
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

Put one coal in the generator's fuel slot and two iron ore or raw iron items in
the pulverizer's input. The intended result is four ingots in the chest. The
integration harness constructs this fixture at y=200 using engine APIs. Manual
placement, formspec use and survival progression still need graphical testing.
Machines with invalid saved state pause with a diagnostic and retain their
contents; see the saved-state repair notes. Machines containing RF, work,
remaining burn or items cannot be dug; there is
no discharge/wrench tool yet. Transport only supports fixed eastward routing.

## Development records

- [Architecture and invariants](docs/architecture.md)
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
