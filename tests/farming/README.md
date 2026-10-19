# Native farming overflow and renewable crop regression

Run `python3 tests/farming/test_patch.py`, then
`python3 tests/farming/run.py` (`--keep-world` preserves disposable worlds).
Port 30228 is reserved while this runner executes. It never opens a player save.

Separate baseline/repaired games run checkpoint and resume in four native server
processes. Baseline restores only the copied pinned harvester source; it asserts
known losses and must never be accepted as a release test. Repaired mode is
`era_farming_baseline=false`. All phases reject warnings/errors.

The stock-timer benchmark uses four harvester fixtures powered by actual coal
and conduits, starting with zero stored energy:

- Empty, one-free-seed-space and full output resolve actual native mature-wheat
  drops once and check exact stored/leftover counts. Immature wheat remains.
- A separately registered fixture crop has full metadata/wear drops. Its output
  has room for 2 of 5 matching copper items; only 3 copper plus the complete worn
  tool may spill. This is a drop contract fixture, not a native wheat property.
- Native item pickup recovers spills into owned inventory, then a real barrel
  preserves those complete stacks across actual process restart.
- Transparent startup observers invoke the original registered timer and assert
  each productive sweep still uses 128 E, produces 10 mB sludge and preserves normal
  timing. No production timer, growth ABM, power ABM or filter effector is manually
  invoked. Bench machines receive the stock off-state configuration afterward;
  UI state-cycle ordering is outside this regression.

The repaired scenario then uses one native 3x3 farm: a planter under central water,
8 surrounding farmland cells, a harvester, actual coal power, normal Mesecons
clock timers, filter-injectors and moving Pipeworks tube items. Gathered seed
items enter physical planter src; layout/filter selectors stay logical and their
original physical items remain owned. Generated seeds return to the planter;
wheat enters a real barrel. The first harvest/replant cycle checkpoints, then a
real restart preserves the ledger and a second cycle reaches 16 stored wheat.
No seed, machine or power gifts occur on resume.

A detached actor receives the same hidden survival-hand capability a native
player gets at join. Seeds come from actual hand-dug fixture grass and native
pickup. Machines, coal and 128 bone-meal items are supplied test inputs. Fertilizer
is consumed through the native bone-meal placement API and counted; this avoids
claiming a human survival playthrough or natural growth timing. No workshop or
custom factory framework is used. Inherited crop/tree protection and original
node-metadata behavior are not changed or broadly validated here.

Archive contract: install `mod/` as `era_farming_smoke`, expose the original actual
harvester callback synchronously as `era_farming_smoke.harvester_timer`, and run
the same SQLite world twice with these settings:

```
era_farming_baseline = false
mg_name = singlenode
mcl_singlenode_mapgen = false
creative_mode = false
enable_damage = false
max_forceloaded_blocks = 32
era_playtest_no_welcome = true
mesecon.blinky_plant_interval = 1
```

Require exactly `ERA FARMING SMOKE PASS: CHECKPOINT:` then
`ERA FARMING SMOKE PASS: COMPLETE:`. The fixture logs its actual Elepower farming
mod/game paths. Allow 180–220 seconds for checkpoint and 120 seconds for resume,
including native startup, without claiming a pass on a timeout or baseline run.
