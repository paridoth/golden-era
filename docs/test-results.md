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
**six** engine phases passing. This is the current suite; the three-process
restore result above remains preserved as its original baseline.

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

## Scope of the suite

The 12 pure Lua tests cover integer conservation/capacity, fuel exhaustion and
full-capacity pause, no-input/no-energy/overflow behavior, exact completion
cost, no duplicates with caller inventory accounting, two consumers, graph
connect/disconnect, copied ledger save boundary and invalid RF inputs.

Engine integration creates one temporary SQLite world and runs six separate
headless server processes, each with a 120-second timeout on loopback port
30199. Seed saves partly processed work after a cable disconnection/reconnection.
Resume compares saved RF/work/burn/job/inventories exactly and processes two
iron ore into four ingots in a native chest, with 32000 RF generated and 16000 RF
spent processing. It checks no duplicates, full output, input locks, denied
output insertion and a mocked protected transfer. Automatic confirms ingots
survive another restart and an isolated precharged furnace processes dust
through normal globalstep. Worlds are removed automatically; phase logs remain
in `runtime/tests`.

Seed/resume and recipe phases manually invoke `era.step()` against real engine
objects. Resume explicitly re-tracks fixture nodes. Protection testing temporarily overrides
`core.is_protected`. These boundaries matter when interpreting a passing suite.

## Not established

Graphical player placement/UI and crafting callbacks, survival progression,
v7 terrain play, real multi-client contention, third-party protection,
natural mapblock eviction/reactivation, chunk-boundary networks, very large
networks, fairness/performance/stress, corrupt job metadata, save migrations and forced-crash atomicity remain untested.
The Mineclonia custom singlenode mapgen remains disabled after an old-machine
timeout. There is no graphical client build or optional modpack comparison.

## Preserved old-machine evidence

`handoff/evidence/` retains the original unit output and seed/resume/automatic
logs from the previous machine. They support the historical handoff only.
The original source manifest remains an immutable archive record; it is not a
manifest for new documentation or future code edits.
