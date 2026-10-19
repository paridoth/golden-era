# Development log

## 2026-10-16 — previous machine (recorded handoff)

Built a six-mod factory slice on Mineclonia using a project-local Luanti server.
The preserved evidence reports 12 passing unit tests and three real engine
processes exercising processing, clean SQLite restart and automatic scheduling.
Root documentation, license files and CI were missing at interruption. These
old-machine results are not destination verification.

## 2026-10-18 — destination restore

Verified the migration archive SHA-256 and all 37 original source-manifest
entries before changing files. Restored beneath the dedicated workspace as
`golden-era-luanti/`. Destination: Linux Mint 22.3 (noble), x86_64, GCC/G++ 13.3.
All required commands were available; no sudo, system package installs, service
changes, firewall edits or public exposure were needed.

Completed the complete unmodified `scripts/setup.sh` path with the transferred
upstream sources and ten hash-verified cached Debian packages. This regenerates
local tools, CMake build products and runtime symlinks at the relocated path,
which contains spaces. The build exited 0; all 12 unit tests and all three engine phases passed.
Exact output and scope limits are preserved in `test-results.md` and
`docs/evidence/2026-10-18/`.

Added project README, architecture/history/compatibility/fidelity/license
records, full GPL and CC0 texts, texture provenance and a CI workflow. The
historical release announcement was checked directly; no launch manifest was
recovered, and no gameplay defaults were promoted from provisional status.
The original handoff and source hashes remain unchanged as migration evidence.

The CI entrypoint repeats setup and unit/engine tests. Its hosted workflow is
prepared for a future GitHub remote; no hosted CI run has been executed. It
preserves exact dependency versions and fails when those versions cannot be
obtained. Dependencies and source caches are optional accelerators, not a
substitute for verification.

Git author supplied by the user: Josh <paridoth@gmail.com>, scoped to this
repository. Baseline staging excludes upstream checkouts, tools, runtime,
worlds and credentials. Original and destination test evidence is intentionally
tracked through narrow log exceptions.

## 2026-10-18 — crafting and changed-settings restart tests

Expanded the existing integration harness from three to six processes. Added
engine recipe-manager checks for all six shaped recipes plus dust cooking,
including shifted rows, exact ingredient consumption, no replacements and
incomplete-recipe rejection. These are engine API checks, not graphical player
crafting or player crafting-callback tests.

Added a persisted raw-iron job fixture with independently specified expected
costs, tick boundaries, yields and balances. A restart changes cost/rate/yield
from 4000/40/two to 900/75/three. The old job retains its saved semantics, the
next input uses the new settings, overflow preserves pending work, and a third
process confirms five dust and 3100 RF persist after defaults are restored.
Unknown test phases now fail explicitly rather than falling into resume logic.

Executed `./scripts/test.sh --integration`: exit 0, 12/12 unit tests, crafting
checks and all six engine phases passed. Lua 5.1 syntax and Python compilation
checks passed. No production gameplay changes were necessary. Destination
restore evidence was preserved; new logs use the `expanded-` prefix. Historical
values and recipes remain provisional. Hosted CI and graphical/multiplayer
validation remain outstanding.

## 2026-10-18 — actual mapblock eviction and reactivation

Added a seventh engine phase with a factory crossing x=15/16. Transient
forceload/release calls control activation; the normal engine timer performs
actual eviction with a five-second test-only unload timeout. The processor
block unloads while the generator block stays active, the cached network
splits, and 100 explicit ticks charge only the isolated generator. Exact
metadata/inventory snapshots survive reload. The normal production LBM restores
tracking and connectivity when the block becomes active, without manual
`era.track` calls or tracking-table changes.

The same fixture then releases both blocks, observes complete eviction and
pruning, steps the simulation while unloaded, waits another second, and checks
that reactivation preserves all saved balances and pending work. The resumed
factory produces exactly four ingots; 32000 RF generated equals 16000 RF spent
plus 16000 stored. No duplicate output or offline catch-up was observed.

Executed `./scripts/test.sh --integration`: exit 0, all 12 unit tests and seven
engine phases passed. Lua 5.1 syntax and Python compilation checks passed.
No production gameplay changes were needed. Evidence uses the `chunks-`
prefix. This covers engine eviction/activation and one real cross-block
factory topology; player-driven travel, other layouts, default-timing stress,
multiplayer, corrupt state and crash recovery remain unverified.

## 2026-10-18 — malformed saved state, pause and explicit repair

Found that saved jobs were decoded and trusted before validating their shape,
cost/rate, output or relationship to pending work. Scalars/missing fields could
raise errors, and a missing job could reuse current recipe settings for old
work. Added shared machine-state validation and a schema-1 job resolver. Invalid
machines pause before RF generation/transfer/processing and before automated or
player inventory/digging mutations. Only diagnostics/display fields change;
original gameplay metadata and inventories remain available for trusted repair.
Healthy neighbors remain active. Existing valid jobs keep their saved semantics.
Non-finite ledger inputs are rejected, and numeric setting overrides now respect
the metadata integer range.

Added 49 engine corruption cases plus SQLite restart, normal-scheduler pause,
explicit repair, restored item routing and another restart without duplication.
The first new fixture run failed because its snapshot contained unserializable
ItemStack userdata. The next failed because repair assertions omitted ordinary
neighbor transfers. Corrected item-string snapshots and inventory accounting;
retained both failure transcripts. The final complete run passed: 13/13 unit
tests and all ten engine phases, exit 0. Lua syntax and Python compilation checks
passed. Evidence uses the `validation-` prefix and does not replace prior logs.

Documented schema 1 and its repair boundary in `docs/save-state.md`. No reset
button, implicit schema migration, privileged-metadata authentication or forced-
crash transaction journal was added. Graphical/multiplayer tests, historical
reference recovery and scale/fairness measurements remain outstanding.

## 2026-10-18 — user selects Revelation as the gameplay reference

After reviewing the differences, the user selected FTB Revelation. Established
3.7.0 (pack 35, version 12180) as the concrete reference discussed in that
comparison, using Minecraft 1.12.2 / Forge 14.23.5.2858. This supersedes the
initial Direwolf20 target; the migration HANDOFF remains immutable. Updated
AGENTS, README, reference/fidelity/compatibility/architecture records and a
current roadmap so later transitions retain the user's decision.

Pinned a normalized 1000-entry official manifest with SHA-256/SHA-1, byte sizes,
side flags, paths, URLs and mirrors. The content digest excludes volatile API
usage counters/timestamps; the observed raw response hash is retained separately.
Fetched 675 config files and four scripts (16338511 bytes) into ignored local
reference storage; every selected file passed all size/hash checks. Four nested
library-cache entries labeled as config were excluded by root-path selection.
No installer, Java runtime, JAR or pack script was executed.

Added an inert reference acquisition/verification tool, a top-level JAR inventory
and 15 Thermal config facts with source hashes and line numbers. The Steam
Dynamo base is configured to 40 RF/t; furnace/pulverizer bases to 20 RF/t; the
default ore-to-dust multiplier to 2. Those facts do not establish recipe costs,
fuel/fluid consumption or effective tier/buffer/augment behavior. Existing Lua
simulation values and engine/foundation pins were retained; only the old TE4
comment was corrected. The next deliverable is a reference-driven Thermal
behavior specification and supported import, followed by graphical play.

Executed acquisition plus offline verification, fact extraction and unit checks.
The test entrypoint now includes eight Python reference-provenance/cache tests
alongside the 13 Lua tests. Final verification evidence is recorded separately.
Runtime behavior was unchanged, so the earlier ten engine phases remain the
latest engine run rather than being reported as a new run for this reference
selection. Hosted CI remains unexecuted.

## 2026-10-18 — first Thermal static contract and supported import

Downloaded/hash-verified the exact TE, Thermal Foundation, CoFH Core and Redstone
Flux JARs to ignored reference storage and inspected them without loading Java
classes. Found recipe resources under assets/thermalexpansion/content, alongside
code-defined defaults. Reviewed nine class hashes with method/offset/field
anchors; public legacy source was only a reading aid, not an exact-build pin.

Added a bounded importer for iron/copper/tin pulverizer records, coal/charcoal
fuel records and three literal pack crafting statements. It preserves metadata,
material-group identities, repeated ingredients, grid holes and secondary output
chances. Unknown selected stack/recipe fields fail. No general ZenScript engine,
NBT translation or effective ore-dictionary/recipe registry is claimed. Class
interpretations are authored review data whose byte provenance is checked, not
an automatic bytecode translator. Twenty-one config facts include relevant
storage/scaling flags. The generated contract is explicitly runtime_ready=false.

Important findings: coal has an explicit 24000-RF registration while charcoal
uses the 16000-RF parser default; iron pulverizing specifies two dust and a 10%
nickel secondary; the default non-food dust-to-ingot furnace scan uses 1500 RF;
Steam Dynamo water is batch-credit accounting (100 mB adds 25000 RF of credit).
Machine and dynamo rates depend on their buffers. Recorded the full supported
boundary, provisional native differences, conditional parity arithmetic and
migration requirements in docs/thermal-factory-spec.md. Existing gameplay remains
unchanged pending effective mapping and a coupled resource/state migration.

All 30 unit tests, cached config/script integrity, Thermal regeneration comparison,
Python compilation and whitespace checks passed. Original code/scripts were never
executed; downloaded originals remain untracked. Runtime was unchanged and the
prior ten engine phases were not rerun for this acquisition/import/specification
change. Graphical play and effective original-runtime observations remain pending.

## 2026-10-18 — source-backed native crafting and material representatives

Traced first-machine recipes through the exact TE/TF/Core compiled classes and
pack scripts. Confirmed TF metadata 0 for iron dust and 69 for nickel dust;
Foundation AlternateGears=false uses an empty-center copper gear, while the pack
explicitly adds an iron-center tin gear. Recorded seven class hashes with
locations, config hashes and source-to-native choices. Pinned MCP stable 39-1.12
from Forge Maven (size/SHA-256 and field rows) to resolve piston, brick block and
flint names. Reviewed normal side index arrays separately; orientation/access
semantics remain incomplete and are not installed as native side controls.

Added a fail-closed compiler producing a native Lua 5.1 catalog: 14 material/
component declarations and ten recipes, including the three machine patterns.
Removed their older shortcuts. Kept the existing iron-dust identity and all
placed-machine/job state semantics. Explicitly require the pinned foundation's
copper and piston mods and validate all catalog ingredients/outputs at startup.
No original assets or executable pack code enter the runtime. Existing original
placeholder art is reused; tin/silver acquisition is still a creative/test input
rather than a completed survival path. RF/water/rate and storage/transport remain
engineering fixtures, with their coupled model/migration still pending.

Added six offline compiler tests and a committed-output regeneration check.
Expanded independent engine crafting examples to verify every catalog recipe,
exact consumption, shuffled bronze inputs, empty grid cells and six rejected
shortcut/substitution cases. The first engine attempt failed on registration
`type=normal`; corrected it to `shaped` (normal is the query method), regenerated
and retained the failed transcript. The next full run passed 36 unit tests and
all ten engine phases. Full source verification, Lua syntax, Python compilation
and whitespace checks passed. Evidence is under the crafting- prefix.

## 2026-10-18 — native basic RF/water and preserved legacy migration

Compiled basic parameters from the pinned static spec into native Lua. New
machines now use coal/charcoal 24000/16000 RF, 100 mB -> 25000 RF water-credit
batches, sourced buffers/rates and 4000/1500 RF ore/dust costs. Added native bucket
loading with tank/empty-bucket preflight, water/fuel UI and signed credit storage.
Reviewed exact TE update/debit and RedstoneFlux clamp classes separately; no
original Java or scripts execute. Startup/refill timing, side/duct behavior and
probabilistic secondary outputs remain explicit gaps.

Added schema 2 with legacy/revelation profiles. Valid old states migrate only
after original validation, retain RF/work/burn/job bytes/items and receive zero
native credits. Old ticks are not guessed into new RF. Legacy rules/settings
continue until an allowed idle upgrade; busy/protected/invalid machines cannot
switch, and upgrades preserve RF/items/unlit fuel without granting water/fuel.
New jobs save the schema-2 buffer mode; old jobs keep their fixed semantics.
Invalid schema-1 originals still pause without migration or normalization.

The first ten-phase legacy regression run passed. Added three native-world
phases; the first combined run exposed greedy dispatch stranding all fuel RF in
the first larger processor buffer. Native donor budgets/shared processor dispatch
fixed that, while legacy allocation stays preserved. A focused native sequence
passed, followed by the final complete run: 47 unit tests, 13 real server phases.
Native processing/restart totals match 24000 = 14000 spent + 10000 stored; water,
charcoal, negative debt, saturation, bucket preflight, old job/burn upgrades and
13 new malformed-state/job cases pass. Existing 49 malformed legacy cases,
settings restarts, natural eviction and scheduler recovery still pass.

Recorded failure/focused/final evidence under resources- and updated operational,
state, architecture and fidelity documentation. Lua syntax, Python compilation,
generated data consistency, source hashes and whitespace checks passed. No
forced-crash journal, native random-output persistence, original tick/duct parity,
resource acquisition or graphical-client result is claimed.

## 2026-10-18 — persisted nickel byproducts

Added job schema 3 with a saved secondary output/chance/percentile, compiled from
the pinned iron recipe and explicit material map. Both potential slots must fit
before paid work or RNG. New jobs choose once at paid-work start and preserve the
result across blocking/restarts; primary/secondary/input commit without yielding.
Old fixed/schema-2 jobs stay primary-only. Original TE rolls at completion; this
native timing difference is explicit. Added a secondary slot and deny player
insertion into it. Malformed decisions pause before mutation.

Focused three-phase tests and then the full 16-phase suite passed with 47 unit
tests. Coverage includes preflight/no RNG, saved winning/losing jobs, old job
semantics, exact RF/output/no duplication, all 100 percentile values (ten wins)
and eight malformed decision cases. Source class hashes, regeneration, syntax
and whitespace checks pass. Evidence uses byproducts-. Continuing with sides,
transport and survival acquisition under the user's instruction to keep working.

## Native item sides and ejection — 2026-10-18

The full suite passed 47 unit tests and all 18 engine processes. Two new phases
check source-backed processor mode groups, protected settings, split output,
destination input denial, automatic-output toggle, panel rotation, reserved-input
locks, directional byproduct ejection, SQLite persistence, old-layout opt-in and
six malformed configurations. Source class integrity, catalog/model regeneration,
Lua 5.1 syntax and whitespace checks passed. Evidence uses sides-.

The first full run found test factories close enough for new all-face output to
send dust into another fixture's chest. Separated the native fixture and reran
the complete suite successfully. Transfer cadence/default auto-output, RF faces
and Thermal Dynamics ducts remain native gaps; see [item sides](item-sides.md).
Continuing with survival materials and storage crafting.

## Survival materials and basic cell — 2026-10-18

Passed 50 unit tests and all 20 engine phases. Three compiler tests reject
unsupported dimension/distribution/band/vein rules, unresolved secondary outputs,
missing selected recipes and a stale pack. The native catalog now has 23 materials
and 15 patterns. Added tin/silver/lead ores, stone-only scatter from locked bands
and approximate weighted densities, ore/dust cooking, six Pulverizer recipes,
electrum mixing and the reviewed basic cell recipe. Old cell shortcuts reject;
existing node IDs/saves are retained. The first startup caught a wrong native
redstone-block ID; corrected the map and declared the actual supplying mod.

The focused four-phase run and then full 20-phase suite passed. Actual engine
scatter in a solid-stone VoxelManip produces all three ores within native bands
and none in air. Checks cover drops/cooking, tin/silver components, ingot dust,
electrum-to-cell crafting, exact RF/secondary outputs and cell SQLite persistence.
This is an engine fixture, not a v7 survival gathering/playthrough claim. All
source hashes, regeneration, Lua syntax and whitespace checks passed. Evidence
uses survival-. [Survival materials](survival-materials.md) details terrain and
registry limitations. Continuing with the graphical client and inspection demo.

## Graphical client and machine forms — 2026-10-18

Optional local client build succeeded on the pinned engine with six hash-locked
JPEG/PNG/FreeType packages extracted inside the repo and the existing system
SDL2/OpenGL stack. No system packages or upstream source were changed. The first
compile needed multiarch JPEG headers; an initial link selected static FreeType
without its transitive libraries. The reusable builder quotes workspace paths and
selects local shared libraries. Audio/download support is disabled. This is a
local executed bootstrap, not a clean-machine graphics portability claim.

The isolated demo joined on loopback and delivered all four machine forms.
Captured and inspected Pulverizer, Dynamo and furnace forms. The cell capture
was occluded and discarded; its visual inspection remains pending. Corrected
invisible empty slots, crowded labels, irrelevant slots and a player inventory
that exposed only 27 of 36 slots. New backgrounds are code-drawn, with no bitmap
assets added. All 36 inventory slots and machine-specific controls now render.

Idle cached forms refresh on actual mapblock activation. The first regression
attempt incorrectly expected inactive core.load_area to execute LBMs; moved
the assertion into the existing genuine eviction/reactivation phase, which
passed. The final full suite passed 50 unit tests and all 20 engine phases.
Lua syntax, Python compilation, shell syntax, source hashes and whitespace checks
passed. Evidence uses graphical-. [Client/demo instructions](graphical-client.md)
record commands, dependencies and validation boundaries. The demo remains open
for the user's requested hands-on inventory/output check; no mouse/crafting
actions or survival playthrough have been claimed.

## Corrected graphical quantity check — 2026-10-18

The user reported a chest item with no number that became 64 when dragged into
the player inventory. The inspection demo had incorrectly enabled creative mode.
The pinned Mineclonia creative inventory callback expands every player-main put
to its item maximum when the creative stack selector is 64, including genuine
ordinary-chest withdrawals. Engine drawing normally omits a number for a singleton;
that display alone was not evidence of four completed ingots.

The demo now defaults to a separate factory-check world with global creative off
and an explicit verified survival player mode, while retaining disabled damage.
The earlier creative world/inventory is preserved. Added /factory_status for exact
chest/player quantities and processing status. Refill rejects overlapping batches,
creative mode, invalid/missing fixtures and blocked input/capacity preflight, and
prints the current/expected output count before adding inputs without yielding.
No upstream creative behavior or production item definitions were changed.

A new real-engine callback regression withdraws one/four ingots from an ordinary
chest, reproduces the creative expansion to 64 through all registered inventory
action callbacks, and confirms exact one/four counts in survival. It uses a fake
player backed by real inventories/ItemStacks; it is not a mouse/network test.
The focused phase passed and the corrected graphical demo joined with verified
survival mode. Real mouse withdrawal in the corrected demo remains for the user.
Evidence uses player-counts-.

The complete suite passed **50 unit tests and all 21 engine processes** after
the correction. Lua syntax, Python compilation and whitespace checks passed.
The corrected demo remains open for a real survival-mode withdrawal check.

## User-confirmed output withdrawal — 2026-10-18

The user confirmed **four ingots** after collecting the corrected demo output.
This establishes the observed completed-batch/chest-to-player count check. It does
not claim machine-input drags, actual crafting, multiplayer or survival gathering.
Continuing with safe relocation for filled machines.

## Complete-state machine relocation — 2026-10-18

The Factory Wrench uses the exact three-iron/one-tin recipe from the pinned
Thermal Foundation ItemWrench class. The catalog now has 23 material declarations
and 16 recipes, with the native tool registered separately. Additional exact
Core/TE class hashes establish the baseline dismantle behavior. Native packing
deliberately retains complete state instead of spilling inventory/discarding
fluid and partial work; see [relocation](relocation.md). No original code ran.

Three added engine phases passed, followed by the complete run: **50 unit tests
and all 24 engine processes**. Native saved work/RNG, generator water and negative
credits, genuine schema-1 migration with unchanged job bytes, charged cell RF,
item metadata, facing/ports and new placer ownership survive packing, SQLite
restart, replacement and a second restart. Continued jobs spend the exact
remaining RF and emit only their saved outputs.

Guards cover source protection, wrong wrench, full player inventory, invalid
state, missing interact privilege and distant actors; future/unknown/foreign/
overcount/copied/spent packages; occupied/protected/unloaded destinations and
air with metadata/inventory/timers. Injected inventory-write failure restores the
source and clears its claim. Invalid restored state rolls back; injected rollback
failure quarantines its snapshot and disables replay through restart. Expected
error diagnostics in the raw logs are from those deliberate fault injections.
The tests use real inventories/metadata/registry with fixture players, not player
network mouse actions or forced-crash transactions.

Full source/class hashes, catalog/model regeneration, Lua syntax, Python
compilation and whitespace checks passed. Evidence uses relocation-. Ordinary
digging remains empty-only; Pack requires a wielded wrench, interact privilege
and an actor within six nodes. The carrier consumes exactly one even in creative
mode and references world-local server storage. The QA command /factory_wrench
supplies a tool. The user closed Luanti normally; actual wrench interaction is
the next hands-on check, and the graphical client has not been reopened.

## User-confirmed relocation and reuse review — 2026-10-18

The graphical client was reopened for the wrench check. The user subsequently
confirmed all requested interactions worked, including packing/replacing machines
with preserved contents and RF. This is user-reported hands-on evidence; actual
crafting, survival gathering and multiplayer remain separate checks.

The user questioned how much generic infrastructure we were recreating. The
reuse comparison had been deferred too long. Pinned-source inspection identifies
Pipeworks as the first item-network candidate, with concrete game-ID, chest,
side/protection, reserved-input and relocation integration work. Elepower's
standalone power API and fluid_lib are the closer power/fluid candidates;
Technic offers selected utilities but different EU/progression semantics. Existing
Storage Drawers and Wrench are additional reuse candidates. See the exact audit
revisions and limitations in [mod compatibility](mod-compatibility.md).

The roadmap now puts an isolated compatibility trial before further custom
infrastructure. No runtime dependency or existing world changed in this review.
The existing unit/source-model checks passed (50 tests), and `git diff --check`
passed. Engine integration was not repeated for these documentation-only changes.

## First real Pipeworks reuse probe — 2026-10-18

Added an isolated temporary Mineclonia/Golden Era assembly with pinned Pipeworks
and dependencies, plus a test-only machine adapter. Promoted basic_materials,
xcompat and fakelib's existing observed revisions to the enforced upstream lock.
The runner verifies clean source pins and patches the game-ID alias only in a
temporary xcompat copy. It does not edit the normal game or existing worlds.

The headless engine passed real Pipeworks item routing into the Pulverizer and
furnace. Guards reject invalid recipes, changed sides/protection at arrival and
reserved-input extraction. An active job's stored output/chance, work and RF stay
unchanged when another ore arrives. Routed dust produces one ingot for 1500 RF.
The native scheduler is disabled and processing is explicitly stepped; graphical
attachments, actual extraction and persistence in transit remain future checks.

The first assembly lacked Mineclonia's required root README and was corrected.
The first routing pass also revealed unsupported late node overrides; adapter
registration moved to mod loading before the final run. See the captured
[probe evidence](evidence/2026-10-18/reuse-probe.log). Unit/source-model checks,
Lua/Python syntax and whitespace checks passed. The next adoption milestone is
the filtered factory line, restart/lifecycle and relocation coverage documented
in [mod compatibility](mod-compatibility.md).

## Playable existing-mod pack — 2026-10-18

The user explicitly changed the delivery priority: use available Luanti mods and
forks to obtain a playable Revelation-style pack quickly, then play, fix issues
and add features. Built the separate `golden_era_playtest` assembly with full
Elepower, fluid_lib, Pipeworks, Storage Drawers and Mesecons on Mineclonia. Native
equivalents and stock balance are accepted for this first build. The earlier
custom Thermal modules/worlds remain available through their previous launchers.

The assembly enforces ten clean source pins, preserves upstream notices and
records ten bounded copy-only compatibility edits. They handle game-ID/material
mappings, native Elepower tin/bronze/silver, Mineclonia's recipe guide, Mesecons
dye/piston compatibility, a missing documentation declaration, and fluid remainder
accounting. Added focused checks for single/multiple guide outputs and partial,
full, mixed and multiple-buffer fluid insertion. No upstream checkout was edited.

The supplied workshop uses stock machines, power ABMs, timers, Mesecons clocks
and Pipeworks filter-injectors. The real engine processed two raw iron into four
ingots and collected all four in a native barrel without manually advancing work.
Selected machine/storage/transport crafts and fluid fill/drain/overflow passed.
The first complete workshop run took about 113 seconds. Starter supply IDs and
spawn/help handling were corrected during integration.

Launched the graphical client into the new persistent v7 playtest world as Josh;
it joined and reached `ERA PLAYTEST READY` at 13:37:49 local time. First terrain
generation emitted upstream craft-width/structure/metadata warnings, with no
error before workshop readiness. This confirms startup/join/bootstrap, not user
mouse interaction or a complete survival playthrough. See [playtest](playtest.md)
for commands, included content and remaining coverage. Current development now
follows play feedback instead of further custom framework expansion.
The final patched-assembly workshop smoke passed at 13:40:03 in roughly 114
seconds with zero warnings/errors. Captured evidence is in
[playtest-smoke.log](evidence/2026-10-18/playtest-smoke.log).

## Shareable Windows tester package — 2026-10-18

The user requested an itch.io-shareable package and confirmed the tester uses
Windows. Added a deterministic source/game ZIP builder that assembles a fresh
game, dereferences all links, excludes developer worlds/auth/Git/Java/build
files, and records per-file provenance, SHA-256, modes and retained notices.
Two fresh builds matched byte-for-byte. The versioned artifact/checksum are
recorded in [release metadata](releases/0.1.0.json).

The Windows batch launcher creates external tester data and downloads the
official Luanti5.17.0 portable engine only on first use, checking its release
SHA-256 before extraction/launch. Engine binaries/DLLs are not redistributed.
Unix launchers use an installed engine. The package includes instructions, itch
launch actions, source/patch/build inputs, all upstream notices and supplemental
license texts. A hash-pinned original Blender source archive supplements the
exported Mineclonia models; its exact downstream correspondence limit is noted.

The final ZIP passed actual entry/CRC/hash/manifest checks, case/path/privacy
checks and a clean-extraction runtime test through its launcher. The stock
workshop again produced all four ingots using normal timers/power/tube routing.
Fresh external world creation and loading every game module from the extracted
package were asserted. Existing unit/source checks and syntax/whitespace checks
passed. Native Windows/PowerShell and itch app execution remain for the tester;
only the game runtime was executed on Linux. No itch project/upload/publication
was performed. [Upload guide and page text](itch-release.md) are ready.

## Desktop playtest 0.1.1 — 2026-10-19

The user authorized autonomous work and then explicitly restricted the platform
scope to Windows and Linux. Shield/Android work stopped before any toolchain
installation; only ignored download metadata remained. Current scope is also
recorded in AGENTS.md.

Added a first-join choice between the supplied workshop and gathering materials
at the natural spawn. The survival path adds no tools/materials or development
privileges; Elepower still supplies its own help book. The workshop kit is issued
once, and its operator privileges are limited to single-player. Returning 0.1.0
players retain their position and inventory. A five-page first-factory guide and
six crafting milestones reuse the existing recipe guide, Tome and awards system.
The guide starts with unpowered grinding/alloying; a Power Cell comes later.

Pinned-source and real-engine checks found two compatibility gaps: native Steel
Block was absent from Elepower's material mapping, weakening later recipes, and
Wireless Control Chip used an empty Mineclonia dye group. Bounded assembled-copy
patches restore upstream ingredient semantics. Expanded stock tests check 26
craft outputs, fifteen-target recipe reachability, ten PCB etches per acid source,
fluid conservation and the ordinary two-raw-iron-to-four-ingot factory. Separate
v7 tests harvest generated ores through native dig/pickup callbacks and process
steel, plastic, manual ore doubling and brass. Those tests use a detached actor
and supplied device fixtures; they do not establish human progression pacing.

Actual Linux client tests use authenticated repository-local Xvfb displays and
real X11 mouse events. Both choices, initial destinations, kit rules, inventory
persistence and reconnect positions passed. A strengthened destination assertion
initially failed because it assumed terrain preparation would finish in three
seconds. Waiting for readiness passed; one measured workshop generation took
22 seconds. This exposed a useful next UX change. Existing inherited first-join
Mineclonia craft-width warnings remain distinct from zero-warning headless
factory/resource runs.

The Windows bootstrap now quarantines an incomplete engine cache and promotes a
verified download with Directory.Move, preventing nested cache directories.
Actual PowerShell 7/.NET tests on Linux exercise the exact batch inline command:
fresh/partial cache, checksum and missing-executable rejection, special path
characters, concurrent promotion and unchanged saves/settings. This does not
replace native Windows PowerShell/cmd/desktop testing.

Linux releases include a native/Flatpak launcher, version checks, a relocatable
desktop entry and the official installation reference. The current app identifier
is org.luanti.luanti. The official Flathub 5.17.0 engine ran the stock factory
under its matching runtime with LuaJIT, while final artifact manifests/launcher
checks passed separately. The Linux archive bundles no host-dependent engine.
Windows and Linux 0.1.1 candidates, hashes and exact validation limits are in
[release metadata](releases/0.1.1.json). The final game ZIP passed its own clean
extraction/real-launcher factory test. Original 0.1.0 EXE/ZIP hashes are unchanged.

An optional copied-engine controller prototype translates normalized SDL gamepad
input into native modal-menu mouse/key events. A real SDL virtual controller
moved/split/quick-transferred server inventory stacks, activated a GUI button,
rebound a controller key and reopened inventory. The unmodified engine failed
the same first transfer as expected. This separately built Linux development
engine is optional, lacks development-build audio/HTTP, and is not part of the
Windows/Linux stock-engine packages. See controller-support.md for scope.

## Desktop 0.1.2 — 2026-10-19

Workshop preparation now shows a readable status while the player keeps exploring.
Pending trips survive disconnects, resume without another kit, and can be canceled
or retried. Session/request identities prevent old terrain callbacks from moving
a reconnected player or overriding a newer trip. Returning players without a
pending trip keep their saved positions. The actual native three-session test
confirmed pending metadata, one pick/axe, 32 torches and seven saved test ingots
through interruption, arrival and a later reconnect at a different position.

All desktop launchers now validate existing world metadata before writing files.
They respect final case-sensitive IDs, conservatively refuse structured metadata,
and preserve orphaned SQLite/LevelDB/legacy data. The developer launcher also
preserves its configuration. Windows writes the five fresh world settings on
separate lines, resolving the block-redirection behavior observed under Wine.
Stock autocrafting-to-drawer tests cover blocked outputs, returned spools and
restart conservation; the guide explains keeping output room for byproducts.

The expanded CI passed unit/reference checks, 24 legacy engine processes, the
active factory/survival/automation scenarios and Unix save guards. Both native
Linux and official Flathub client GUI checks passed choices and saved state.
Windows has actual installer/Win64/batch/GUI compatibility evidence under Wine;
native Windows and PowerShell 5.1 remain pending. The optional controller engine
remains separate, and frozen 0.1.0/0.1.1 artifacts are preserved.

## Desktop 0.1.3 storage repairs — 2026-10-19

Native storage checks reproduced item loss when capacity upgrades were removed
from an overfilled drawer and when a dummy or sneaking full-inventory digger
caused automatic spills. Drawers called Mineclonia's player drop-key function,
whose behavior does not match an automatic spill. A copied-source patch uses
bounded world item entities for those paths. The regression recovers every one
of 5,000 iron through actual entities and native pickup/front callbacks.

An actual Mineclonia explosion also reproduced a controller crash at the missing
`default` API. The compatibility branch emits full ItemStacks, honors the native
no-drop flag and removes its own node. Worn or metadata-bearing controller source
stacks survive; native name/count drawers refuse worn stackable payloads.

The controller's cache validator expected a shape its own indexer never produced.
Repairing it eliminates repeated warm neighborhood scans. Construction,
destruction, visual changes and controller reload invalidate cached paths, with
disconnect/reconnect and stale-cache restart assertions. Upstream checkouts and
player worlds remain unchanged. The storage regression joins normal CI; the
existing real-tube/autocrafting restart scenario passes with the new hooks.
Native piston tests also reproduce a separate visual/metadata overwrite that
loses drawer contents; the copy mirrors Drawers' existing immobility rule for
Mineclonia pistons. Movable controllers track the origin of their absolute cache
so Mesecons metadata restoration cannot keep a route from an old position.

All package builders now refuse registered frozen artifact and sidecar paths,
including aliases, before work and again before promotion. Seventeen fast checks
cover each builder and collision behavior. Version 0.1.3 is selected for the next
build; previous artifacts retain their recorded bytes.

Elepower removal checks found that the default mining guard omitted the Energy
Density Reconstructor's tool and Wireless Control Station's card. It now checks
owned item lists while excluding internal output snapshots and ghost filters.
Mineclonia explosions previously erased a full processor after ordinary digging
was refused. A native blast callback preserves full payload ItemStacks and the
existing charged/upgraded machine item, while honoring no-drop blasts and normal
network cleanup. The native drop/place round-trip restores 1,200 charge and the
hardened capacitor's 3,200 capacity.

Machines cannot be removed while a connected player edits their upgrades. Join
cleanup clears stale editor state, and one editor's shared flag cleanup cannot
unlock another active editor. Source-based fixtures cover this lock behavior;
the upstream shared detached upgrade inventory remains a multiplayer review
limit. These changes preserve the stock fluid behavior: drain fluids before
ordinary relocation. No fluid-state item format was added.

The final 0.1.3 ZIP, Windows EXE and Linux archive are frozen from
`b0031d1689ae5036ebfe995c51901b990d150a71`; exact hashes and limits are in
`docs/releases/0.1.3.json`. The ZIP and Linux archive pass the extracted factory;
the official Linux and Windows engines additionally pass storage restart and
machine-removal tests against those exact distributions. Windows installation/
reinstallation retains saved sentinel data. Wine's known builtin SHA warnings
remain visible; native Windows testing remains pending. A test-only warning
classifier correction is recorded separately from the frozen game source.

Additional native controller delivery checks use real timers and in-flight tube
entities through capacity stalls, distribution and restart, with exact final
totals and no production changes. The actual 0.1.2 storage save continues under
the exact 0.1.3 ZIP while preserving the checked quantities and full tool
metadata. All thirty older artifacts and companions retain their bytes.
The continuing Pipeworks audit has confirmed a separate full-autocrafter blast
loss; that is recorded as a 0.1.3 known issue for the next version.

## Desktop 0.1.4 Pipeworks repairs — 2026-10-19

Real explosions reproduced loss of an autocrafter and its occupied src/dst lists.
The Mineclonia-specific copied definition now emits the owned full ItemStacks
and device once, excludes both preview lists, honors no-drop decisions and keeps
native recipe-cache/tube cleanup. Ordinary mining still refuses occupied devices.

Actual piston movement into an inactive block also reproduced a legacy filter
refund creating a real item from a modern preview. Fresh filters now carry a
persistent format marker. Native historical refunds remain intact and mark only
completed conversions; editing one old slot never classifies other slots. All
three filter variants temporarily resist both piston systems. The guide explains
mining, placing and reconfiguring filters to relocate them. Old unmarked previews
with a pending first legacy activation remain an explicit ownership ambiguity.

Four native baseline/repaired checkpoint/restart processes pass with zero
diagnostics. The exact frozen ZIP has two byte-identical builds and passes its
extracted launcher/factory. Its first run completed the factory but a strict
warning check rejected startup lag under concurrent test load; the unchanged
archive then passed without relaxing that policy. The official Linux archive
passes six gameplay processes with zero diagnostics. The exact Windows installer
passes all 11,873 installed file hashes, reinstall/save preservation and six
official Win64 gameplay processes under Wine, retaining the known builtin SHA
warnings. Native Windows and PowerShell 5.1 remain pending.

The final production source also passes real graphical Linux start choices,
loading/arrival and reconnect with unchanged inventories. All 39 earlier artifact
and sidecar files retain their bytes; three registered builders refuse the new
frozen paths, preserving all 48 current/historical files. Source revision and
hashes are recorded in `docs/releases/0.1.4.json`.

A separate powered-timer farming audit confirms that a full or partial Automatic
Harvester output silently discards native wheat/seed drops after removing the
crop. The next bounded repair will emit insertion leftovers using native world
items, then check the existing planter/harvester/seed-return path. It does not
require a new mod or an automation framework.

The full desktop CI also passes: 24 legacy and 16 active-pack native engine
processes, fast/reference checks and Unix save guards. Its before/after hash
record identifies two early guide/fixture edits; all eleven final observed source
hashes match the frozen 0.1.4 commit. Targeted native stages ran the final fixture.

## Desktop 0.1.5 renewable farming — 2026-10-19

The stock Automatic Harvester removed mature crops before checking output room,
discarding items that did not fit. Its copied-source output loop now inserts
normally and emits only the returned leftover above the machine. Native partial
insertion keeps two of five metadata-bearing copper and emits exactly three,
plus the complete worn tool. Timing, crop selection, energy and sludge stay
native. Output overflow remains ordinary loose items; harvesting does not stall.

The native acceptance line uses a buried planter, central water, eight soil
cells, coal power, native crop/fertilizer callbacks and clocked seed-return tubes.
It stores eight wheat and replants eight crops, then repeats after a real restart
to sixteen wheat without new seed or power gifts. All four baseline/repaired
processes pass with zero diagnostics. Supplied fertilizer bounds test duration;
this is not a complete human survival run or a natural-growth timing claim.

Fresh workshops include the farm parts and two controls in the existing barrel;
all 27 native slots fit. Existing barrels remain unchanged. The Farming guide
explains physical seed supply versus previews, and a seventh craft advancement
uses the stock awards API without free rewards. The exact registered farm recipes
and seventeen-target dependency closure pass. An official-client layout capture
shows all six tabs, text and buttons after a real survival-choice click; its
observer opens the Farming page through the native API.

Source `cb50e704ce5ba77af79da003bd9fe224941534dc` produces byte-identical game ZIPs.
The extracted launcher/factory and three official Linux engine processes pass
without warnings/errors. The exact Windows installer passes every installed hash
and save/settings preservation, then three official Win64 factory/farming
processes under Wine, retaining only the documented builtin SHA warnings.
Native Windows and PowerShell 5.1 remain pending.

All 11,783 game files and 58 project-source files match their recorded inputs.
Exactly five runtime paths differ from 0.1.4; unchanged storage, removal and
Pipeworks paths retain that release's executed evidence. Targeted factory,
automation, farming and archive checks cover this update; the broader CI remains
recorded separately for 0.1.4, with farming wired into future runs. All 48 older
artifact/sidecar files are unchanged, and default builders refuse the newly
registered paths while preserving all 57 current/historical files. Exact hashes
and limitations are recorded in `docs/releases/0.1.5.json`.
