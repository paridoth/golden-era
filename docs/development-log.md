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
