# Isolated Pipeworks reuse probe

Run `python3 tests/reuse/run.py` from the repository. It uses existing local
checkouts and the existing local server binary; it does not fetch or build.
Each source must match its Git commit in `upstream.lock.json` and have a clean
checkout. The historical handoff manifest is not an active source lock.

The runner assembles a disposable game named `golden_era` from the Mineclonia
categories, our mods, Pipeworks, basic_materials, fakelib, and xcompat. Pinned
xcompat recognizes `mineclonia` by game ID, so the runner copies it into this
temporary assembly and adds exactly one alias in `src/gameid.lua`:

```lua
golden_era = "mineclonia",
```

It first checks the expected original alias table. This compatibility patch is
explicit test scaffolding; the upstream checkout and normal runtime game are
never edited. A production integration would need its own reviewed solution.

The headless server uses a temporary singlenode world, loopback port 30201,
`mcl_singlenode_mapgen = false`, `era_test_manual = true`, and Pipeworks default
settings. With no connected players, Pipeworks routes its Lua item entities
without attaching their visual entities. The process has a 120-second timeout.
The Lua test mod reports `ERA REUSE PROBE PASS` or `ERA REUSE PROBE FAIL`.
The temporary game and world are removed on exit; captured output and source pins remain in
ignored `runtime/tests/reuse-probe.log`.

This probe establishes actual startup and the explicitly tested item-routing
and inventory callback behavior. It does not establish complete Pipeworks
compatibility, fluid accounting, persistence after a restart, multiplayer
permissions, or a decision to adopt the project in the normal game.
