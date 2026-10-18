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
