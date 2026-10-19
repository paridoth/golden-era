# Native machine removal regression

Run from the repository root:

```sh
python3 tests/machine-removal/test_patch.py
python3 tests/machine-removal/run.py
```

The native runner uses repository-local Luanti 5.17 and port 30218 in disposable
SQLite worlds inside ignored `runtime/tests`. It assembles the pinned game twice;
the baseline restores only `elepower_papi/machine.lua` and
`elepower_tools/soldering.lua` to their exact upstream versions after checking
that the destination cannot escape through parent symlinks. The repaired variant
uses the copied-source helper. It creates no release package or user save.

Each variant is one server process. Both must exit successfully, emit
`ERA MACHINE REMOVAL PASS:` and emit no `ERA MACHINE REMOVAL FAIL`, `ERROR[` or
`WARNING[` diagnostics. Full output is `runtime/tests/machine-removal-smoke.log`.

The fixture checks native ordinary mining with a fake iron-pick actor, unchanged
custom guards, full ItemStack metadata/wear, actual Mineclonia explosions,
no-drop suppression, ghost/scratch exclusion, native charge/component restoration
and upgrade effect, and destruction/dig/network callbacks exactly once. Existing
player metadata fixtures exercise active soldering locks, stale joins and shared
lock interference. The baseline asserts the known losses rather than expecting
those defects to pass as repaired behavior.

For an exact distributed game, copy `tests/machine-removal/mod` into the test
world's `worldmods/era_machine_removal`. Use `era_removal_baseline = false`,
`mg_name = singlenode`, `mcl_singlenode_mapgen = false`, `creative_mode = false`
and `era_playtest_no_welcome = true`. Require the same one-process PASS marker and
zero diagnostics. The engine must load the archive's game, not a development
assembly; archive runners additionally assert that path.

This is a callback/engine conservation test, not a human playthrough, GUI test or
multiplayer concurrency test. See
[integration notes](../../integrations/playtest/removal-notes.md) for explicit
fluid/energy boundaries and the separate stock soldering concurrency limitation.
