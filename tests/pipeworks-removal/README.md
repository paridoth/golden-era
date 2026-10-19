# Native Pipeworks removal and filter regression

Run `python3 tests/pipeworks-removal/run.py` (`--keep-world` retains the disposable
worlds), then `python3 tests/pipeworks-removal/test_patch.py` for copy-only patch
contracts. Port 30220 is used only during the test. No player save is opened.

The runner assembles separate baseline and repaired games. Baseline restores only
the two changed Pipeworks files from the exact pinned checkout; upstream and other
compatibility repairs stay untouched. Both variants run checkpoint and resume in
separate native server processes and reject all warnings/errors.

The baseline deliberately asserts the confirmed occupied-autocrafter blast loss
and inactive-block modern-preview duplication. The repaired variant checks:

- Actual Mineclonia explosion preserves all physical src/dst slots, wear and
  metadata, emits one device, and performs native cache/tube cleanup once.
- Normal occupied mining stays refused; recipe/output previews never drop;
  no-drop blasts emit nothing.
- All registered filter variants and deployer/dispenser/nodebreaker on/off
  variants retain their native mining/explosion behavior without ghost emissions.
- Both Mineclonia and Mesecons mover APIs refuse all fresh/old-unmarked filter
  variants under the explicit temporary immobility policy.
- A fresh modern filter's real first block activation emits no preview item.
- Modeled unmarked historical physical inventories refund complete owned stacks
  through native input-container and fallback-drop paths, including overflow.
- A converted metadata snapshot restored into a new inactive block does not refund
  a second time, and real process restart preserves converted markers, inventories
  and recoverable world entities.

Fixtures transfer known owned items into modeled historical physical lists; they
do not execute a historical mod version. Configuration/mining uses a detached
inventory actor. Movers use native API functions; legacy LBMs run only through
real engine block activation. See
`integrations/playtest/pipeworks-notes.md` for exact pinned source contracts and
the intentionally unresolved ambiguity of old already-moved unmarked previews.

Archive runners can use `mod/` as `era_pipeworks_smoke`, with
`era_pipeworks_baseline=false`, singlenode mapgen, `mcl_singlenode_mapgen=false`,
`creative_mode=false`, `enable_damage=false`, `max_forceloaded_blocks=32`, and
`era_playtest_no_welcome=true`. They must launch the same world twice and require
`ERA PIPEWORKS SMOKE PASS: CHECKPOINT:` followed by
`ERA PIPEWORKS SMOKE PASS: COMPLETE:`. A pass in baseline mode does not validate a
release artifact.
