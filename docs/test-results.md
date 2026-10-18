# Test results

## Destination: 2026-10-18 (America/Chicago)

Machine: Linux Mint 22.3 / Ubuntu noble, x86_64. GCC/G++ 13.3.0
(`Ubuntu 13.3.0-6ubuntu2~24.04.1`). Paths contain spaces. Source pins and package
hashes match the migration handoff. No system installs were performed.

| Check | Result |
| --- | --- |
| Archive SHA-256 | PASS |
| Original `handoff/SOURCE-SHA256SUMS` | PASS: 37 entries, before edits |
| Full local `scripts/setup.sh` | PASS: exit 0, rebuilt local tools/engine/runtime |
| `scripts/test.sh` | PASS: 12/12 tests, exit 0 |
| `scripts/test.sh --integration` | PASS: 12 unit tests + seed/resume/automatic phases, exit 0 |
| Hosted GitHub Actions | Not executed; no project remote |

The full setup ran from the relocated source tree with no old build products,
extracted tools or runtime symlinks. All ten cached package hashes and five main
upstream revisions/cleanliness checks passed. Luanti reports 5.17.0, bundled Lua
5.1.5, Release, GCC 13.3 and RUN_IN_PLACE=1. Build warnings in bundled Lua and
other upstream C++ code did not stop compilation.

Executed commands, in order: `./scripts/setup.sh`, `./scripts/test.sh`, and
`./scripts/test.sh --integration`. All returned 0. The engine phases logged
SEED PASS, RESUME PASS and AUTOMATIC PASS. No temporary integration world
remained after completion.

Preserved destination evidence is in [evidence/2026-10-18](evidence/2026-10-18/):
`setup.log`, `unit-tests.txt`, `integration.txt`, the three phase logs,
`engine-version.txt` and `restore-summary.json`. The log timestamps are the
engine host's own timestamps; no timezone is inferred from them. The record's
date uses the user's America/Chicago date.

This validates a clean relocated rebuild **with transferred source/package
caches**. Fresh Internet downloads/package availability, a different compiler,
other platforms and hosted CI remain unverified. The workflow uses an Ubuntu
24.04 runner, source/package caching, a read-only repository token, pinned action
commits and `scripts/ci.sh`. That script's build/test commands were executed
locally as listed above; the workflow itself has not run. A cache miss must
obtain the exact locked apt versions and fails if they are unavailable.

## Expanded crafting and recipe-settings checks — 2026-10-18

`./scripts/test.sh --integration` returned **0** with all 12 unit tests and all
**six** engine phases passing. The three-process restore result above and
this six-process extension remain preserved as earlier baseline evidence.

The seed phase now calls the real engine recipe manager (`core.get_craft_result`)
for all four machines, cable (8 per craft), ejector and dust cooking (10 seconds).
It verifies each occupied ingredient slot consumes exactly one item, remaining
stacks retain the expected item, no replacement items appear, shifted single-row
recipes resolve, and an incomplete machine recipe produces no output and
preserves all inputs. This tests registered recipes against Mineclonia's item registry and
Luanti's C++ crafting implementation. It does not simulate a player clicking a
crafting-table UI or invoking player crafting callbacks.

Three additional processes use an isolated precharged pulverizer and raw iron:

1. `recipe_seed`: starts at 8000 RF with two raw iron, spends seven ticks, and
   saves a job at 280/4000 RF with rate 40 RF/tick and two-dust yield.
2. `recipe_resume`: starts a new process with cost **900 RF**, rate **75 RF/tick**
   and yield **three dust**. The saved job's serialized data and balances must
   survive exactly. Full output blocks work without losing input/RF/job data,
   and reserved input remains locked. The old job still needs 4000 RF total at
   40 RF/tick and yields two dust. The next input uses 900/75/three. Explicit
   penultimate-tick checks detect early completion for each job. Final totals:
   five dust, zero input/work, 3100 RF, and an empty job record.
3. `recipe_verify`: restarts again with defaults restored and verifies those
   final totals, then steps another 100 ticks without duplication or RF loss.

The original processing, restart, overflow, protection and automatic scheduler
checks also passed. No gameplay source change was required. New output is in
`evidence/2026-10-18/expanded-integration.txt`, `expanded-summary.json`, and the
six `expanded-*.log` files. Original restore logs remain intact. The temporary
SQLite world was removed after all phases completed.

## Natural mapblock lifecycle checks — 2026-10-18

`./scripts/test.sh --integration` returned **0** with all **12 unit tests** and
**seven engine phases** passing. This result is preserved as an earlier
baseline. The additional
`lifecycle` phase uses a factory spanning x=14..20 at y=200, z=40. The generator
and cable are in one mapblock; buffer, processors, ejector and chest are in the
neighboring mapblock across x=15/16.

Transient engine forceload/release calls control activation. Only this phase
sets `server_unload_unused_data_timeout=5` and
`active_block_mgmt_interval=0.1`. Eviction itself uses Luanti's ordinary timer,
not a fabricated node result or deleted mapblock. The fixture observes real
`core.get_node_or_nil` nil results, then checks:

- The processor block actually unloads while the generator block remains
  active. Missing positions are pruned and the cached component shrinks from
  five nodes to two. After 100 explicit simulation ticks, the isolated generator
  has gained exactly 2000 RF; unloaded processors receive none.
- Reloaded processor RF/work/burn/schema/job/inventory fields match the saved
  snapshot exactly. Loading into memory alone leaves tracking pruned; subsequent
  engine activation runs the production LBM and restores the five-node network.
- Both blocks actually unload. All six tracked fixture nodes are pruned;
  another 100 explicit simulation ticks and at least one further second of
  wall time do not regenerate state or reload the factory.
- Full reload preserves the exact saved state. Engine activation automatically
  discovers machines, cable and ejector. No `era.track` call, tracking-table
  edit, or direct invocation of the production LBM is used to restore them.
- Processing resumes to exactly four ingots, with 32000 generated RF equal to
  16000 processing RF plus 16000 stored RF, and no duplicated output.

The old six phases passed too. Production gameplay code did not need a fix.
Evidence: `evidence/2026-10-18/chunks-integration.txt`, `chunks-summary.json`, and
seven `chunks-*.log` phase logs. Original and expanded evidence remain intact;
the temporary world was removed after the run.

This is actual engine-managed mapblock eviction/reactivation using a headless
activation harness and explicit `era.step()` calls. It does not establish
real-player travel/proximity, arbitrary chunk-bridge layouts, or long-duration
behavior under default timing. The automatic scheduler remains covered by its
separate phase.

## Malformed-state validation and repair — 2026-10-18

The final `./scripts/test.sh --integration` returned **0**: all **13 unit tests**
and **10 engine phases** passed. This is the current suite. Runtime guards now
pause malformed processor jobs, invalid saved integers and unsupported schemas
before RF or item mutations; valid neighboring machines continue operating.
The pure ledger also rejects non-finite RF, burn and recipe-cost values.

The new `corrupt_seed` phase checks **49** malformed job/state cases, including
missing/non-table/oversized records, missing/unknown fields, invalid or
non-finite costs/rates, work at/above cost, mismatched or missing reserved input,
unknown/oversized/malformed output counts, stale jobs, missing/future schema,
negative/fractional/nonnumeric/overflowing RF, negative work/burn, and burn stored
on a processor. Every case checks gameplay metadata and every inventory slot
before/after 60 real simulation steps, direct processing, automated transfers,
player inventory callbacks and digging. Only derived diagnostic/display fields
may change. Each case also requires a valid neighboring generator and furnace
to keep operating. The fault message is asserted in metadata, infotext and
formspec text; graphical presentation remains untested.

`corrupt_resume` loads an invalid serialized boolean job from SQLite, re-tracks
the fixture, and runs the normal scheduler for four seconds. The paused machine
remains unchanged while a valid furnace completes. An explicit test-operator
repair restores the known saved job at 200/4000 work with 3800 RF. Normal ticks
finish exactly once, clear the fault and resume item routing. Across the source,
repaired processor and furnace, exactly one raw iron is consumed and two dust
are added: two raw iron remain, five dust are routed to the furnace input, and
the already completed healthy ingot remains. Stored RF and work on the repaired
processor become zero. `corrupt_verify` starts another process and compares all
three machines' gameplay metadata/inventories before and after 100 more steps;
no repaired output is duplicated.

The previous seven phases also passed, including old saved jobs across changed
recipe settings and natural mapblock eviction/reactivation. New evidence uses
the `validation-` prefix under `evidence/2026-10-18/`, with a final run transcript,
ten phase logs and JSON summary. Temporary worlds were cleaned up.

Two earlier runs failed in the new test fixture: its snapshot initially tried
to serialize ItemStack userdata, then its repair assertions omitted automatic
neighbor input/output transfers. The snapshot conversion and assertions were
corrected; both failure transcripts are retained as
`validation-initial-failure.txt` and `validation-repair-fixture-failure.txt`.
Neither failed run is counted as a successful full-suite run.

See [saved-state validation and repair](save-state.md) for supported schema
bounds, pause behavior and recovery limits. Unknown-schema migration, arbitrary
hostile-Lua sandboxing and forced-crash transactions remain separate work.

## Revelation reference selection and acquisition — 2026-10-18

The user selected Revelation 3.7.0. This change pins and inspects reference data;
production simulation values, behavior, saves and native dependency pins were
not changed. The TE4 comment on fixture rates was corrected to describe the new
TE5 reference. The prior 10-process engine run remains the latest engine run;
it was not rerun or claimed anew for this acquisition/docs/tooling change.

Executed `python3 scripts/reference.py pin --date 2026-10-18`, `fetch`, `check`,
`report`, and `facts`. All selected 675 configs plus four scripts (16338511 bytes)
match locked size, SHA-256 and SHA-1. Fifteen Thermal config facts were extracted
with source paths/hashes/line numbers. No pack installer, Java, mod JAR or script
was executed. These checks establish reference-input integrity, not native
behavioral parity or a complete recipe import.

`./scripts/test.sh` passed **13 Lua tests and eight Python tests** (21 total).
The Python tests cover unsafe paths, incorrect identity/duplicate entries/
missing hashes, stable content pins despite usage-counter changes, changed
artifact hashes, exclusion of mislabeled nested mod caches, corrupted/truncated
files, refusal to trust or overwrite invalid cached content, and verified-mirror
fallback/cache reuse. Tests run offline against temporary fixtures.

Evidence is in `evidence/2026-10-18/revelation-reference-fetch.txt`,
`revelation-reference-check.txt`, `revelation-unit-tests.txt` and
`revelation-reference-summary.json`. Downloaded originals stay ignored.

## Thermal static specification and bounded import — 2026-10-18

Inspected the exact TE 5.5.7.1, CoFH Core 4.6.6.1, Thermal Foundation 2.6.7.1
and Redstone Flux 2.1.1.1 JARs as inert ZIPs. The reproducible importer needs only
TE/Core and verifies both against the pack lock. No original classes or scripts
were executed. Reviewed behavioral records bind to nine exact class hashes;
JSON records include entry hashes/pointers and script records include hashes/lines.

The generated specification contains 21 config facts, three pulverizer recipes,
coal/charcoal fuel records and three literal crafting statements. It is explicitly
not a resolved registry export or native runtime definition. Source inspection
established defaults/rules, not complete effective pack behavior or parity.

`./scripts/test.sh` passed **13 Lua + 8 reference + 9 Thermal importer tests**
(30 total). The new tests cover coal/charcoal identity, unresolved groups,
metadata/count preservation, unsupported NBT/wildcards/constants/expressions,
probabilities, explicit/default/percentage RF, repeated crafting ingredients,
grid holes, missing/duplicate selected statements, ambiguous ZIP entries and
rejection of a review for a different pack lock.

Full config/script cache verification and Thermal regeneration comparison passed;
Python compilation and Git whitespace checks passed. Evidence is in
`evidence/2026-10-18/thermal-reference-check.txt` and `thermal-unit-tests.txt`.
There were no Lua runtime/state changes, so engine integration was not rerun;
the earlier ten-phase validation run remains the latest engine evidence.

## Native crafting catalog — 2026-10-18

The runtime now registers 14 material/component items from a generated native
catalog and ten reviewed recipes. It replaces the generator/pulverizer/furnace
shortcuts with mapped Thermal patterns. Source review pins seven class hashes,
config evidence, three pack-script overrides, the native foundation and a Forge
Maven MCP mapping ZIP used for three vanilla field names. Full source integrity
and catalog regeneration checks passed. The offline consistency check requires
only committed review/specification inputs, not the downloaded originals.

The first engine attempt failed at startup: the adapter used the craft-query
method name `normal` as the registration type, which must be `shaped`. Fixed the
compiler and retained that failure transcript. The next complete run passed
**36 unit tests** (13 Lua, 8 reference, 9 importer, 6 catalog) and **all ten engine
processes**. Lua 5.1 syntax, Python compilation and whitespace checks also passed.

The engine crafting manager verifies ten catalog patterns with exact ingredient
consumption, bronze's two-ingot output from shuffled shapeless inputs, coils,
frames and all three machines. Six negative cases reject missing tin-gear iron,
unwanted copper-gear iron, each old machine shortcut and a wrong pulverizer coil.
Denied crafting preserves every input. The older buffer/cable/ejector/cooking
fixture checks remain alongside the new source-driven checks. The other nine
phases retain their earlier save/state and scheduling coverage.

Evidence: `evidence/2026-10-18/crafting-source-check.txt`,
`crafting-engine-failed.txt`, `crafting-engine-suite.txt` and ten `crafting-*.log`
phase logs. This demonstrates native recipe registration and existing-state
regression checks, not effective full-pack parity or survival progression.
Tin/silver acquisition, resource-model migration and graphical/player callback
validation remain pending; see [native crafting](native-crafting.md).

## Basic RF/water model and schema migration — 2026-10-18

The latest complete run passed **47 unit tests and all 13 engine processes**.
Eleven new pure Lua model tests check machine/dynamo ramp boundaries, coal vs
charcoal, dry/no-fuel preflight, independent water/fuel credits, one-coal balances,
signed refill debt, full-buffer dissipation, copied-state continuation and invalid
resource bounds. The normal test entrypoint also regenerates/compares native RF
parameters against the pinned static specification.

The original ten engine phases now explicitly construct pre-change schema-1
fixtures and let production validation migrate them into schema-2 legacy profiles.
Their old RF totals and fixed jobs remain meaningful legacy assertions, not
claims about the new model. Their restart, scheduler, changed-setting, genuine
mapblock eviction/LBM and 49 malformed-state checks still pass.

Three new phases construct default native machines. They exercise water buckets
with blocked return/full tank, player insertion callbacks, dry-fuel preservation,
partial native-job SQLite restart, exact primary processing balances (24000 RF
coal = 14000 processing + 10000 stored), water-credit persistence, charcoal
16000 RF, full-buffer loss and saved negative credits. Schema-1 burn/job migration
keeps original values/serialized job bytes; protected/busy upgrades reject, and
idle upgrades preserve RF/unlit fuel/items without granting native credits.
The native-resume phase deliberately changes legacy cost/rate/yield settings;
the pinned native behavior remains unchanged. Eleven malformed schema-2 states
and two malformed native jobs pause without mutating original fields/inventories.
A mixed legacy/native graph also retains the old donor pair limit.

The first combined native run exposed RF stranded in the first large processor
buffer under the old greedy allocator. Replaced that native allocation with shared
available RF while retaining legacy dispatch. A focused three-process run passed,
then the final full 13-process run passed. Retained the failed and focused
transcripts. This allocation is an explicit native policy, not Thermal Dynamics
routing parity. Exact start/post-tick refill delays, sides and random byproducts
are still outside this supported resource slice.

Source/class integrity, generated catalog/model consistency, Lua 5.1 syntax,
Python compilation and whitespace checks passed. Evidence uses the `resources-`
prefix: combined suite, failed/focused attempts, source checks and 13 raw phase
logs. No original Java code or scripts ran. Real graphical/player interactions,
new-model mapblock travel at scale, forced-crash recovery and full-pack parity
remain unestablished.

## Persisted secondary outputs — 2026-10-18

The full suite passed 47 unit tests and all 16 server phases. Three added phases
verify blocked preflight consumes no RNG/RF, winning and losing schema-3 jobs
survive blocked outputs and SQLite restart without reroll, and completed outputs
survive a second restart without duplication. They enumerate all 100 percentile
outcomes through real processing (exactly ten nickel outputs), preserve an older
schema-2 primary-only job, and pause eight malformed secondary records. The prior
13 phases remain passing. Evidence uses the `byproducts-` prefix. Original TE
roll timing is deliberately changed to a saved job-start decision; effective
full-pack RNG sequence or forced-crash atomicity is not claimed.

## Scope of the suite

The 13 original pure Lua ledger tests cover integer conservation/capacity, fuel exhaustion and
full-capacity pause, no-input/no-energy/overflow behavior, exact completion
cost, no duplicates with caller inventory accounting, two consumers, graph
connect/disconnect, copied ledger save boundary, invalid RF inputs and non-finite RF/burn/cost rejection.
Eight Python tests cover reference acquisition/provenance/cache integrity; nine
more cover the bounded Thermal data import. Six catalog tests cover offline
regeneration, concrete metadata, missing mappings/pattern keys, explicit override
conflicts, stale pack/foundation pins and unsupported counted ingredients.

Engine integration creates one temporary SQLite world and runs twenty-one separate
headless server processes (the original ten legacy regression phases plus three
native model/migration and three secondary-output phases plus two item-side, two survival and one player-inventory callback phase), each with a 120-second timeout on loopback port
30199. Seed saves partly processed work after a cable disconnection/reconnection.
Resume compares saved RF/work/burn/job/inventories exactly and processes two
iron ore into four ingots in a native chest, with 32000 RF generated and 16000 RF
spent processing. It checks no duplicates, full output, input locks, denied
output insertion and a mocked protected transfer. Automatic confirms ingots
survive another restart and an isolated precharged furnace processes dust
through normal globalstep. Worlds are removed automatically; phase logs remain
in `runtime/tests`.

Seed/resume, recipe, lifecycle and corruption matrix phases manually invoke `era.step()` against real engine
objects. Resume explicitly re-tracks fixture nodes. Protection testing temporarily overrides
`core.is_protected`. These boundaries matter when interpreting a passing suite.

## Not established

Graphical player placement/UI and crafting callbacks, survival progression,
v7 terrain play, real multi-client contention, third-party protection,
player-driven mapblock activation and broader chunk-boundary topologies, very
large networks, long-run fairness/performance/stress, unknown-schema migrations and
forced-crash atomicity remain untested. Known schema-1 preservation/upgrade
is covered; unknown-schema recovery is not. Malformed-state validation does not
authenticate privileged edits or provide arbitrary hostile-Lua sandboxing.
The Mineclonia custom singlenode mapgen remains disabled after an old-machine
timeout. A local graphical client now builds and three forms have visual inspection; actual
player interaction and optional modpack comparison remain untested.

## Preserved old-machine evidence

`handoff/evidence/` retains the original unit output and seed/resume/automatic
logs from the previous machine. They support the historical handoff only.
The original source manifest remains an immutable archive record; it is not a
manifest for new documentation or future code edits.

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
