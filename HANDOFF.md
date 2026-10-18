# Golden Era — machine migration and Codex handoff

Prepared 2026-10-16 (user timezone America/Chicago). This document records inspected files and observed test evidence, not intended future work as though it were complete.

## Start here

The prototype source is at `/home/hermes/golden-era-luanti` on the old machine. **There is no project Git repository or remote yet.** Transferring this document alone does not transfer the code. Use the accompanying `golden-era-handoff-2026-10-16.tar.gz` archive and its `.sha256` file. The archive has one top-level `golden-era-luanti/` directory.

The archive includes project source/configuration, this handoff, test evidence, all nine downloaded upstream Git checkouts with their notices, and the ten cached `.deb` dependencies. It excludes generated runtime games, worlds, local extracted tools, CMake build products and engine executables. Those must be rebuilt at the destination. No accounts, API keys, passwords, SSH keys, personal files or system service configuration are required or included.

The original development assignment was interrupted just before documentation/CI/license-file generation. Inspection for this handoff confirms those files **do not exist**. Do not infer they were created from earlier chat narration or draft tool calls. Source code and successful three-process integration evidence do exist.

## Transfer and restore

1. Copy the archive, checksum file, and optionally a separate copy of this handoff to the other machine. A USB drive, SSH/scp or another private file-transfer method is fine. Do not delete the old workspace until validation succeeds on the destination. No transfer has been performed automatically.
2. Prefer Linux Mint 22.x or Ubuntu 24.04 on x86_64 for the first restore. Other distributions, ARM and Windows are not supported by the current dependency bootstrap; adapt it deliberately before running.
3. Use a fresh parent directory on the new machine. Example:

```sh
# Run beside the downloaded archive and checksum file.
sha256sum -c golden-era-handoff-2026-10-16.tar.gz.sha256
mkdir -p "$HOME/projects"
# Ensure $HOME/projects/golden-era-luanti does not already contain another project.
tar -xzf golden-era-handoff-2026-10-16.tar.gz -C "$HOME/projects"
cd "$HOME/projects/golden-era-luanti"
sha256sum -c handoff/SOURCE-SHA256SUMS
```

`$HOME/projects` is only an example destination. Use an existing appropriate workspace if preferred. The scripts locate the project relative to themselves and can work under a different username/path. Preserve executable permissions and upstream `.git` directories when transferring.

4. Inspect prerequisites before setup:

```sh
uname -m
cat /etc/os-release
command -v git python3 gcc g++ make apt-get dpkg-deb
```

Required: Git, Python 3, GCC/G++ plus normal system headers/toolchain, make, apt-get and dpkg-deb. The previous host supplied those. Setup does **not** install these missing prerequisites, check all of them up front, or provide a complete container environment. Ask the user before any sudo/system-wide installation. Reserve at least 1 GB free for source/tools/build/runtime, with additional space for future worlds.

5. Build and test from the project root:

```sh
./scripts/setup.sh
./scripts/test.sh
./scripts/test.sh --integration
```

Setup verifies the five main upstream commits and refuses dirty/mismatched checkouts; verifies cached Debian package hashes against `build-deps.lock.json`; extracts tools into `tools/root`; configures `tools/build`; compiles with two jobs; assembles `runtime/games/golden_era`. Cached sources/packages avoid normal dependency downloads, although platform runtime dependencies still need to exist. Without caches, setup fetches public Git commits and exact package versions using configured apt repositories. If an old package version is unavailable, do not silently update the lock or claim a reproducible setup passed.

The full `setup.sh` path has not been tested from a clean relocated environment. The old machine manually downloaded/extracted packages, compiled the engine using the same CMake options, and repeatedly exercised the assembly path through integration tests. **A complete restore/rebuild is the first destination verification task.**

6. Start the development server:

```sh
./scripts/run-server.sh
```

This builds no graphical client. Connect a separately installed compatible Luanti client to **127.0.0.1:30099**. It is intentionally bound only to loopback and not advertised publicly. A client on a separate computer cannot connect with this configuration; ask before changing hosting/network exposure. No firewall or service edits are necessary for a local client. Stop cleanly with Ctrl-C.

Normal play worlds will be created at `runtime/worlds/play`. No such directory was present at handoff inspection, so there is **no persistent personal play world to migrate**. Integration worlds are temporary and automatically removed; saved evidence logs are included separately. If a later play world exists, stop its server cleanly and copy the whole world directory, including databases, before migration; do not transplant a live SQLite file alone.

### Relocation pitfalls

- Do not copy old `tools/build/CMakeCache.txt`, generated runtime symlinks or the compiled server into a new path and expect them to work. They embed absolute old-machine paths.
- `setup.py` creates fresh mod symlinks from the new project root. Engine mod security stays enabled.
- Game-root README/LEGAL/LICENSE/CREDITS/menu files are copied, not symlinked outside the runtime game. Mineclonia's version command reads the root README, and an external symlink was rejected by mod security.
- `--assemble-only` skips dependency/build/revision checks. Use it only after a correct engine build, not as proof of reproducible setup.
- `tools/root/usr/bin/lua5.1` is the unit-test runner. The engine itself uses bundled Lua 5.1.5; LuaJIT is disabled in this build.
- Engine dynamic linking needs the project-local JsonCpp library. Run the provided wrapper (sets `LD_LIBRARY_PATH`) rather than invoking the engine directly without the appropriate environment.
- Default integration port is localhost **30199**; each process has a 120-second timeout. Check for port conflicts if startup fails.

## Instructions to the new Codex instance

Paste this as your opening prompt after extracting the archive:

> Continue the Golden Era Luanti project in the extracted `golden-era-luanti` directory. Read HANDOFF.md and AGENTS.md completely, inspect the actual files, verify handoff/SOURCE-SHA256SUMS, and treat the handoff's completed/unverified distinction as authoritative session context. First inspect this machine, then rebuild with scripts/setup.sh and execute scripts/test.sh --integration. Do not assume the old engine binary, runtime symlinks, package availability, or old test results establish success on this machine. Work only inside the dedicated workspace; do not change unrelated installations, Hermes/Plex, services, firewall rules, personal files, or use sudo/install system-wide packages without approval. Retain pinned versions unless a documented failure requires a deliberate migration. All historical gameplay numbers remain provisional until sourced to the initial late-2014 Direwolf20 pack. Preserve source/assets/licenses; do not copy protected Minecraft/mod content. After restore validation, resume the original milestone: complete documentation/license/CI records, initialize Git and commit the verified baseline, then resolve remaining fidelity/testing gaps. Continue autonomously through ordinary reversible work, and ask only for genuine permission/dependency blockers. Never claim unexecuted tests passed.

The original user explicitly requested real working source and real engine tests, not just design documents. Priorities: historical accuracy; interoperability; maintainable modular code; multiplayer correctness; automated tests; performance/save compatibility; legally reusable visuals/sound. Provisional name: Golden Era, distinct public identity required. Foundation preference: Mineclonia if feasible. Do not blindly install Technic/Pipeworks into it or create a wholesale `default` shim.

## Current verified prototype

- Six custom Lua mods with dependency declarations and Lua 5.1-compatible code.
- Server-authoritative 20-Hz simulation, integer RF ledger, deterministic ordered network members, cached six-face connectivity and invalidation.
- Coal dynamo, power cable, energy buffer, pulverizer, powered furnace.
- Input/output/fuel slots, basic formspec/status, craft registrations, iron dust, dust cooking.
- Iron ore **or modern Mineclonia raw iron** -> dust -> ingot.
- Direct eastward machine-to-machine output transfer and a minimal ejector into a native ordinary Mineclonia chest.
- Node metadata persistence of RF, recipe work, remaining burn and schema; in-flight job input/cost/rate/output is serialized to protect it against future recipe configuration changes.
- Inventory preflight and synchronous commits; input removal locked while work is pending; output insertion denied; internal inventory moves denied; protection checks for player callbacks and transfer endpoints.
- Unloaded tracked positions are pruned; LBM re-registers machines/cables/ejectors after load. No offline energy generation.
- Four original procedural 16×16 placeholder PNGs, no third-party pixels or custom audio.

### Code map / exact source files

The complete handoff source manifest is `handoff/SOURCE-SHA256SUMS` (all project files except the manifest itself; upstreams/caches excluded from this inner manifest). Original code/configuration:

```text
.gitignore
AGENTS.md
build-deps.lock.json
upstream.lock.json
server.conf
scripts/setup.sh
scripts/setup.py
scripts/run-server.sh
scripts/test.sh
mods/era_core/{mod.conf,init.lua,ledger.lua}
mods/era_core/textures/{era_machine.png,era_cable.png,era_dust.png,era_ejector.png}
mods/era_compat_mcl/{mod.conf,init.lua}
mods/era_energy/{mod.conf,init.lua}
mods/era_materials/{mod.conf,init.lua}
mods/era_thermal/{mod.conf,init.lua,rates.lua}
mods/era_transport/{mod.conf,init.lua}
tests/unit/test_ledger.lua
tests/integration/run.py
tests/integration/mod/{mod.conf,init.lua}
```

`era_core/ledger.lua`: pure transfer/generation/processing/components functions, used directly by unit tests and engine adapter. `era_core/init.lua`: machine registration, tracking, metadata, formspecs, inventory callbacks. `era_compat_mcl`: native item identifiers and assertions. `era_materials`: dust/cooking. `era_energy`: graph cache, producer/buffer/consumer tick phases. `era_thermal`: data, machines, processing/crafting. `era_transport`: guarded one-item transfer and eastward routing.

Shared interfaces: `era.register_machine`, `era.register_recipe`, `era.track`, `era.invalidate`, `era.state`, `era.save`, `era.networks`, `era.step`, `era.process`, `era.move_one`; pure functions under `era.ledger`.

### Factory fixture / manual layout

At a fixed y-level, use relative (x,z):

| Position | Node |
|---|---|
| (0,2) | era_thermal:generator |
| (1,2) | era_thermal:buffer |
| (0,1) | era_energy:cable |
| (0,0) | era_thermal:pulverizer |
| (1,0) | era_thermal:furnace |
| (2,0) | era_transport:ejector |
| (3,0) | ordinary native Mineclonia chest |

Add one coal to generator fuel and two iron ore items to pulverizer input. East is +X. The touching processors share power; removing cable (0,1) disconnects them from generator/buffer, though stored RF/work remains usable. Integration runs this at y=200 and expects exactly four ingots in the chest.

## Exact upstream state

Main pins are enforced by `upstream.lock.json`:

| Upstream | Version / commit |
|---|---|
| Luanti | stable 5.17.0, c0e6812b1a4260bb25a1f606f70f55f4962bb97d |
| Mineclonia | stable 0.124.0, 20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1 |
| Technic | b00a5653012c21ba1f73f02820440e7d5e0fefad |
| Pipeworks | 5dfd572eacee4c3c1ed8b827f4a67c46b022b242 |
| Mesecons | aca87dbd448637d2dc80e59e909425932acd6c84 |

Additional fallback-comparison downloads completed, but **were not added to the setup lock or runtime, audited fully, or tested**. Their URLs and observed commits are recorded in `handoff/observed-upstreams.json`:

| Extra checkout | Observed commit |
|---|---|
| minetest_game | c42e4d0c0ff9d27ff7b9b308c3cfc14098dd3a0f |
| basic_materials | f626da067a39206b7d60c1122843cd951ffb7081 |
| xcompat | 758684dac8875d06d8c1565e323ee52c9d4daf7f |
| fakelib | 562dc359f00227daf0ee56dbba9c36a240c59d4c |

All nine checkouts were clean at handoff inspection. Public remotes are in the observed JSON. No project remote, Git commits or branch exists yet.

Build dependencies are exactly versioned with SHA-256 hashes in `build-deps.lock.json`: cmake 3.28.3-1build7, cmake-data same, libgmp-dev 2:6.3.0+dfsg-2ubuntu6.1, libjsoncpp-dev/libjsoncpp25 1.9.5-6build1, librhash0 1.4.3-3build1, libsqlite3-dev 3.45.1-1ubuntu2.8, libzstd-dev 1.5.5+dfsg2-2build1.1, lua5.1 5.1.5-9build2, zlib1g-dev 1:1.3.dfsg-3.1ubuntu2.2. Cached originals are included at `tools/debs/`; local extraction is regenerated. The original host was Linux Mint 22.3 x86_64 with GCC 13.3. Archive-provided tools target amd64/noble, not arbitrary Linux.

## Test evidence and its limits

Latest unit run was executed again while creating this handoff: **12/12 passed**. Exact stdout: `handoff/evidence/unit-tests.txt`.

1. Energy conservation/capacity (integer-state sweep).
2. Producer consumes one fuel and pauses at full capacity.
3. No production without fuel.
4. Insufficient energy preserves pending work.
5. Overflow consumes no RF/input.
6. Empty input consumes nothing.
7. Exact recipe completion cost.
8. No duplicate results with caller inventory accounting.
9. Two consumers share producer without creating RF.
10. Network connect/disconnect/reconnect.
11. Copied ledger save boundary resumes work (unit-only, not engine persistence).
12. Negative/fractional RF rejection.

Real engine integration was executed successfully on the old machine **before the interruption**, across three separate headless processes and the same temporary SQLite world. Preserved original logs:

- `handoff/evidence/seed.log`: custom mods load, server listens, RF generation, cable disconnection and partly processed input saved.
- `handoff/evidence/resume.log`: exact energy/work/burn/job/inventory restart assertions; 2 ores -> 4 ingots in native chest; 32000 RF generated = stored/work + 16000 processing RF; no duplicates; overflow, input locks and denied protected transfer checks.
- `handoff/evidence/automatic.log`: completed ingots survive another restart; isolated precharged furnace processes dust under normal globalstep, not manual test stepping.

All three contain `ERA INTEGRATION ... PASS`. Log host timestamps are retained as written; do not assume their timezone is the user's timezone. The integration suite was not rerun during handoff preparation because no gameplay implementation changed. These results **do not** validate the destination machine.

The seed/resume phases call the real simulation through `era.step()` with actual engine nodes/inventories/SQLite; automatic phase enables normal scheduling. The test re-tracks fixture positions explicitly on resume. It does not establish natural mapblock eviction/reactivation behavior or real player placement/UI interactions. Protection denial uses a temporary overridden protection function; no third-party protection system/multi-client session was exercised.

Earlier failures were observed and corrected: missing `mesecons` dependency, missing README, mod-security rejection of external README symlink, custom singlenode mapgen startup timeout, plain-table fixture positions incompatible with vector methods. Final three-process logs pass. No fallback comparison result exists.

## Compatibility conclusions already supported by inspection

- Mineclonia game.conf requires engine >=5.10. The old host's apt Minetest Server candidate was 5.6.1, so it was not installed. Luanti 5.17.0 was compiled project-locally.
- Mineclonia is the preferred foundation because the independent factory loads, runs and persists on it. This establishes prototype feasibility, not complete 1.7.10 fidelity.
- Current Mineclonia uses `mcl_redstone:redstone`, not the older `mesecons:redstone` assumption. Mining iron drops `mcl_raw_ores:raw_iron`; both raw iron and ore blocks are accepted by the prototype.
- Technic currently requires pipeworks, technic_worldgen and basic_materials; `default` is optional alongside Mineclonia mods. Its sound selection supports mcl_sounds. Older README descriptions are not proof of a hard `default` dependency today.
- Pipeworks requires basic_materials, xcompat, fakelib; engine minimum 5.10; default optional; Mineclonia chest/furnace adapter code exists.
- Mesecons core makes default optional; gamecompat can select compat_mcla with mcl_redstone present. Do not assume installing a second redstone implementation is automatically correct.
- No global default compatibility shim was created. No Technic/Pipeworks/Mesecons modpack was added to the default custom-game runtime. Runtime compatibility and full gameplay/protection checks for those optional projects are still outstanding.
- Latest custom Mineclonia singlenode mapgen initialization exceeded a 120-second test budget under bundled Lua. Tests explicitly set `mcl_singlenode_mapgen=false`; play selects engine v7. Full custom-mapgen performance remains unverified. Graphical play and v7 terrain gameplay were not visually validated.

## Historical fidelity and legal status

Historical anchor: Minecraft Java 1.7.10, initial late-2014 FTB Direwolf20. Primary announcement:
https://forum.feed-the-beast.com/threads/direwolf20-1-7-10-released.53915/

The announcement is dated October 31, 2014. It does not authenticate exact build numbers or machine defaults. No launch manifest/config snapshot has been pinned. Thermal Expansion 4 is the intended behavioral reference, **not** a verified exact TE build. Exact reference builds for Tinkers' Construct, Applied Energistics 2, Ender IO, BuildCraft, IndustrialCraft 2, Thaumcraft 4, Botania, Forestry, Twilight Forest, Blood Magic and Witchery remain unresolved. Do not infer them from later wiki pages or guess release numbers.

Every current numeric mechanic in `mods/era_thermal/rates.lua` is PROVISIONAL: generator 20 RF/tick; coal 1600 ticks; cable donor transfer 80 RF/tick; consumer input 40 RF/tick; pulverizer 4000 RF/ore; furnace 2000 RF/dust; process limit 40 RF/tick; ore multiplier 2. Capacities (32000 generator, 100000 buffer, 8000 processors) and crafting patterns are also provisional. Server settings `era_<table_key>` override positive integer values. No historical accuracy claim has been earned for these numbers.

Generator uses coal without water; secondary outputs, augments, side modes, redstone modes, authentic progression/art/audio are missing. Current Mineclonia has modern survival differences. This is a working engineering slice, not a finished accurate recreation.

Legal inspection found:

- Luanti declares LGPL-2.1-or-later engine licensing; bundled libraries have their own notices.
- Mineclonia source declares GPL-3.0-or-later with local dual-license options. Its LEGAL.md describes Pixel Perfection/Legacy textures under CC-BY-SA-4.0, main-menu CC0, specified trim models CC-BY-4.0, other media generally CC-BY-SA-3.0 except local notices. Preserve local attribution files.
- Technic declares LGPL-2.0-or-later default with submod/file exceptions; textures include CC-BY-SA/CC0/WTFPL and named author notices. Pipeworks declares LGPL-3.0 code and CC-BY-SA-4.0 media. Mesecons declares LGPL-3.0 code and CC-BY-SA-3.0 non-code.
- Custom Lua includes GPL-3.0-or-later SPDX headers. Four placeholder PNGs were generated independently from flat colors/borders, with no external assets. The intended project code license was GPL-3.0-or-later and intended original texture dedication CC0, but root LICENSE and texture NOTICE were **not written** before interruption. The next agent must formalize those notices before publishing.
- No proprietary Minecraft/mod source, textures, sounds, models or jars were incorporated into the custom slice. Upstream projects were downloaded as public repositories with their notices intact.
- A complete file-by-file inherited media exception/attribution audit has NOT been completed. No asset-provenance inventory exists. Do not describe public binary/game redistribution as cleared. The archive is a development handoff retaining upstream source/notices, not a polished distribution.

## Known engineering limitations / review targets

- RF simulation is lossless abstract adjacency, not per-edge cable flow. Cable rate applies per donor/buffer pair; total processor input budget applies across donors. Buffers do not exchange directly. No fairness guarantee; sorted first consumers can starve others until buffers fill.
- Maximum scheduler backlog is 0.25 seconds; lag can slow production instead of catching up indefinitely.
- Clean server restart is verified. Forced-crash atomicity across mapblocks/inventories is not: no custom write-ahead transaction journal exists.
- Unload/load behavior is implemented but actual mapblock eviction tests, large-network benchmarks and long-running stress remain unexecuted.
- Item transport is fixed +X, one item per step; only explicit ordinary Mineclonia chest IDs are allowed. No filters, tubes, configurable orientation, double/locked-chest support or arbitrary external inventory callbacks.
- Player-side callback/protection behavior is partial validation, not proof against all multiplayer races or malicious/third-party metadata mutation. RF networks do not enforce ownership isolation.
- Stored energy/fuel/work or inventory contents block digging. No wrench/discharge mechanism yet. Machines provisionally ignore explosions and are marked piston-immovable to avoid unsafe state drops; behavior needs gameplay review/testing.
- Formspects and crafting are registered but no graphical client session, actual craft action or survival playthrough was executed. All machines currently show input/output/fuel slots even if some are unused.
- Review state schema/migrations, corrupted/externally edited jobs and dependency API stability before expanding save compatibility claims. Tests preserve serialized jobs but do not explicitly change configured costs across a restart.
- Scripts need more prerequisite/error handling, packaging portability checks and a clean relocated build test. `setup.py --assemble-only` does not check upstream revisions.

## Remaining work in priority order

1. Verify source hashes and rebuild/test on the destination. Keep the old workspace/archive until all tests pass there. Record exact new OS/compiler/engine results.
2. Create missing README.md, root LICENSE, texture NOTICE, docs/architecture.md, historical-reference.md, mod-compatibility.md, licenses.md, fidelity-matrix.md, development-log.md, test-results.md and CI workflow. These were planned but not saved. Include exact pins, commands, executed results and honest limits. Do not re-create future draft references as though their scripts exist.
3. Initialize project Git inside this directory, inspect the staged file list, exclude upstream downloads/tools/runtime/worlds/logs/credentials, then commit a verified baseline. The handoff evidence `.log` files are currently matched by global `*.log` in .gitignore; add a narrow exception or rename evidence if intentionally committing it. No Git identity/remote is configured by the handoff; ask only if needed rather than inventing user identity.
4. Complete the isolated Minetest Game + Technic comparison, if still useful; inspect/audit additional dependencies first, pin them, and add a reproducible smoke harness. No `compare.py` exists now. Keep those mods out of normal Mineclonia play until interoperability is tested.
5. Recover/pin the launch-era pack manifest/configs and exact reference version per target mod; replace provisional rates/recipes with sourced data. Add actual craft/progression tests and graphical factory smoke testing.
6. Test loaded/unloaded chunk bridges, real multiplayer inventory contention, output overflow during transfer, fairness/performance, upgrade/downgrade/save migration and crash recovery. Address transactional risks before content expansion.
7. Finish media license audit and independently authored final visuals/audio before public distribution.

Future milestones only (do not implement all during restore):

- Tinkers-inspired: integer molten-material ledger -> multiblock smeltery membership/validation -> casting -> tool materials -> modifiers and item save schemas.
- AE2-inspired: network identity/provider API -> cells -> terminal transactions -> channels -> persisted crafting plans/reservations -> autocrafting/cancellation/restart recovery.
- Thaumcraft-4-inspired: item/aspect registry -> scanning -> research persistence -> infusion structure/ingredient/essentia reservations -> deterministic instability and recovery.

Definition of the initial milestone still requires reproducible destination setup, Mineclonia/custom-mod startup, actual powered item processing and restart persistence, automated executed tests and documented limitations. The old-machine working slice satisfies the processing evidence; documentation, clean setup verification and wider fidelity/legal work remain incomplete.
