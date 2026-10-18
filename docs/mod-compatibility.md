# Mod compatibility

## Pinned foundation and comparison sources

| Project | Revision | Role |
| --- | --- | --- |
| Luanti 5.17.0 | `c0e6812b1a4260bb25a1f606f70f55f4962bb97d` | headless engine |
| Mineclonia 0.124.0 | `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1` | active game foundation |
| Technic | `b00a5653012c21ba1f73f02820440e7d5e0fefad` | inspection only |
| Pipeworks | `5dfd572eacee4c3c1ed8b827f4a67c46b022b242` | inspection only |
| Mesecons | `aca87dbd448637d2dc80e59e909425932acd6c84` | inspection only |

URLs and enforced revisions live in `upstream.lock.json`. Four extra cached
checkouts (minetest_game, basic_materials, xcompat, fakelib) are recorded in
`handoff/observed-upstreams.json`; setup does not enforce or assemble them.
There is no `compare.py` or completed fallback comparison harness.

Mineclonia is feasible for the independent factory slice based on real engine
startup/processing/persistence. This does not prove optional modpacks work or
establish historical fidelity. Its game metadata requires engine >=5.10.

## Adapter assumptions confirmed in source

- Redstone is `mcl_redstone:redstone`.
- Mining iron produces `mcl_raw_ores:raw_iron`; both raw iron and
  `mcl_core:stone_with_iron` are accepted by the pulverizer.
- Native ordinary chest IDs are `mcl_chests:chest_small` and `mcl_chests:chest`.
- Startup asserts all native item identifiers. No wholesale `default` shim exists.

Technic's `technic/mod.conf` requires pipeworks, technic_worldgen and
basic_materials; `default` is optional alongside Mineclonia support. Pipeworks
requires basic_materials, xcompat and fakelib, declares engine >=5.10, and has
Mineclonia inventory adapters. Mesecons core makes `default` optional and its
gamecompat can select Mineclonia support. These are source-inspection findings,
not runtime interoperability results.

## Outstanding checks

An isolated Minetest Game + Technic comparison could inform future choices.
Audit dependency licenses/APIs, lock all revisions, assemble a separate game
and run a reproducible startup/inventory/protection smoke test before drawing
conclusions. Do not install comparison modpacks into the normal game without
this work. A second redstone implementation also needs deliberate review.

Custom Mineclonia singlenode mapgen previously exceeded the test budget under
bundled Lua. Integration uses engine singlenode with
`mcl_singlenode_mapgen=false`; play uses engine v7. Engine recipe resolution/ingredient consumption is covered by integration.
Graphical terrain, player crafting callbacks, formspec behavior and survival
progression remain unvalidated.
