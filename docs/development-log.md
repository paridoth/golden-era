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
