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

## Scope of the suite

The 13 pure Lua ledger tests cover integer conservation/capacity, fuel exhaustion and
full-capacity pause, no-input/no-energy/overflow behavior, exact completion
cost, no duplicates with caller inventory accounting, two consumers, graph
connect/disconnect, copied ledger save boundary, invalid RF inputs and non-finite RF/burn/cost rejection.
Eight Python tests cover reference acquisition/provenance/cache integrity; nine
more cover the bounded Thermal data import.

Engine integration creates one temporary SQLite world and runs ten separate
headless server processes, each with a 120-second timeout on loopback port
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
large networks, fairness/performance/stress, unknown-schema migrations and
forced-crash atomicity remain untested. Malformed-state validation does not
authenticate privileged edits or provide arbitrary hostile-Lua sandboxing.
The Mineclonia custom singlenode mapgen remains disabled after an old-machine
timeout. There is no graphical client build or optional modpack comparison.

## Preserved old-machine evidence

`handoff/evidence/` retains the original unit output and seed/resume/automatic
logs from the previous machine. They support the historical handoff only.
The original source manifest remains an immutable archive record; it is not a
manifest for new documentation or future code edits.
