# Mod compatibility

## Gameplay reference versus native runtime

The selected gameplay reference is **FTB Revelation 3.7.0 / Minecraft 1.12.2**.
Its exact Forge/Java/mod builds and file hashes are in
`references/revelation-3.7.0.lock.json`. Those are inert reference inputs, not
Luanti dependencies. The native foundation and comparison checkouts below keep
their existing pins. Java JAR execution/Forge runtime compatibility is not part
of this native implementation pathway; see `docs/roadmap.md`.

## Pinned foundation and comparison sources

| Project | Revision | Role |
| --- | --- | --- |
| Luanti 5.17.0 | `c0e6812b1a4260bb25a1f606f70f55f4962bb97d` | headless engine |
| Mineclonia 0.124.0 | `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1` | active game foundation |
| Technic | `b00a5653012c21ba1f73f02820440e7d5e0fefad` | inspection only |
| Pipeworks | `5dfd572eacee4c3c1ed8b827f4a67c46b022b242` | isolated item-routing probe; not normal play |
| Mesecons | `aca87dbd448637d2dc80e59e909425932acd6c84` | inspection only |
| basic_materials | `f626da067a39206b7d60c1122843cd951ffb7081` | Pipeworks comparison dependency |
| xcompat | `758684dac8875d06d8c1565e323ee52c9d4daf7f` | Pipeworks comparison dependency |
| fakelib | `562dc359f00227daf0ee56dbba9c36a240c59d4c` | Pipeworks comparison dependency |

URLs and enforced revisions live in `upstream.lock.json`. The three Pipeworks
dependencies were promoted from the handoff's observed pins for the isolated
reuse probe. The cached Minetest Game checkout remains recorded only in
`handoff/observed-upstreams.json`. Normal setup assembles the Mineclonia/custom
game without these comparison mods.

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

## Reuse review — 2026-10-18

The user questioned the amount of custom implementation after confirming the
factory and wrench interactions. The engine and survival game are already
reused, but the optional-mod comparison was deferred too long. Before extending
custom transport, power infrastructure, bulk storage or machine tooling, test
existing implementations behind adapters. The reference specification,
saved-state rules and regression tests define the behavior an adapter must keep.

| Candidate | Reuse opportunity | Decision and evidence |
| --- | --- | --- |
| [Pipeworks](https://github.com/mt-mods/pipeworks) | Item tubes, filtering, routing, injectors and autocrafting | First item-network candidate. Isolated startup, input routing and guarded machine adapter probe passed; adoption checks remain. |
| [Elepower](https://github.com/LunaSquee/elepower) / [fluid_lib](https://github.com/LunaSquee/fluid_lib) | Standalone buffered energy API and named fluid buffers | First power/fluid API comparison, ahead of Technic. Source inspected at `c37fe7bc3fc52a05e03507ca35cba2c8e5b3e330` / `9b52f6eb7b6fd7fa81f2e923e1d3bd5950ec9762`; not assembled here. |
| [Technic](https://github.com/mt-mods/technic) | Machine utilities, inventory helpers, network discovery, recipe-guide integration and future powered tools | Selective reuse candidate. Tiered EU and switching-station timing differ from Thermal RF; default machines/worldgen would change progression. |
| [Storage Drawers](https://github.com/minetest-mods/drawers) | Bulk storage, item locks, controllers and Pipeworks integration | Evaluate before writing bulk storage. Current upstream documents Mineclonia support; not pinned or tested here. |
| [Wrench](https://github.com/mt-mods/wrench) | Pickup with metadata/inventories, callbacks and network reconnection | Direct overlap with our latest feature. Inspected at `df2607f57608ddde3cac9740726e6313cdbb02d5`; evaluate before extending relocation. |
| [Mesecons](https://github.com/minetest-mods/mesecons) | Logic components and automation signals | Selective candidate; Mineclonia already supplies redstone. Cross-system signals need an explicit bridge. |

### Pinned-source integration findings

These are source findings, not interoperability results:

- `xcompat/src/gameid.lua` uses the actual game ID on this engine. `golden_era`
  has no alias, so `src/materials.lua` falls back to Minetest Game mappings even
  though `mcl_core` is loaded. Add explicit derivative detection in the isolated
  integration; do not introduce a wholesale `default` shim.
- Pipeworks' `compat-chests.lua` Mineclonia branch adapts barrels, not our ordinary
  small/double chests. Our adapters must enforce protection, configured sides,
  valid inputs and reserved job inputs. Direct inventory insertion does not
  invoke player inventory callbacks.
- `tube.can_insert`/`insert_object`, multi-list `input_inventory`,
  `return_input_invref`, `can_remove`/`remove_items` and `tube_inject_item` are
  suitable extension hooks. Receiving directions point toward the machine;
  our face checks need the opposite vector. Gate extraction ownership in
  `return_input_invref`, because `can_remove` receives no owner argument.
- Machine packing, replacement and rotation must refresh tube adjacency.
  In-flight items use Pipeworks entity persistence, which our machine restart
  tests do not establish. Pipeworks water pressure is not a typed integer-mB
  fluid system; adopting item tubes does not decide fluid transport.
- Elepower's `elepower_papi` is explicitly standalone with optional dependencies.
  `ele.register_machine`/`register_base_device`/`register_conduit` provide useful
  hooks. Its normal power ABM runs once per second and automatically forceloads;
  evaluate timing, lifecycle and configured sides. Its `storage` energy field
  differs from our `energy` field: use one authoritative balance.
- `fluid_lib` has named buffers and insertion/removal APIs, but its default
  node_io callbacks do not enforce our side/protection policy. Its partial-insert
  return behavior in `buffer.lua` also needs a conservation regression before
  adoption. Stock Elepower drops preserve only selected metadata, not our full
  pending jobs, fluids and inventories. Retain our relocation contract.
- Technic core genuinely supports Mineclonia. However, its material mappings
  substitute iron for tin, gold for silver, and use Mesecons redstone IDs.
  `technic_chests` still requires `default`. Its defaults conflict with our
  reference materials/progression. Its adaptive one-to-five-second network and
  current-recipe processor differ from our persisted paid RF jobs and outputs.
- Technic already uses Mineclonia's craft-guide API. Use that game API for our
  machine recipes instead of writing a separate recipe browser.
- Wrench can preserve declared job bytes, RF, fluid metadata and inventories,
  and reconnects Pipeworks/Mesecons/Digilines. It has no hard game dependency,
  but lacks Mineclonia registrations/crafting. State travels in item metadata;
  original orientation, one-use claims, our state validation and failure
  rollback are not provided. Evaluate an adapter against our existing tests
  before replacing the working path. Preservation itself is not unique to ours.

### Executed first feasibility probe

`python3 tests/reuse/run.py` builds a disposable game with the actual
`golden_era` ID and pinned Mineclonia, our mods, Pipeworks and its dependencies.
It verifies source revisions and clean checkouts, patches only the disposable
xcompat copy with the explicit Mineclonia alias, and uses a new temporary world.
The normal game and player worlds do not receive the probe adapter.

The real headless server passed: two Pipeworks packets travelled through tubes
into a Pulverizer and furnace. Arrival rechecks reject changed sides/protection
and invalid recipes; reserved-input extraction callbacks refuse access. Adding
ore preserves an existing paid job, its chance decision, RF and work. Delivered
dust smelts into one ingot using exactly 1500 RF through our native processor.
The native scheduler is disabled for this probe and processing is stepped
explicitly. With no connected players, Pipeworks routes its item state without
visual entity attachments. This establishes a feasible API integration, not
complete player, extraction, network persistence or progression compatibility.
See [probe instructions](../tests/reuse/README.md) and
[captured evidence](evidence/2026-10-18/reuse-probe.log).

### Remaining adoption checks

1. Extend the isolated adapter with ordinary chests, actual filter extraction and
   machine auto-output. Exercise a filtered chest → Pulverizer → furnace → chest
   line with secondary outputs, full outputs and reserved inputs.
2. Test protection, in-flight items across restart/chunk eviction, rotation and
   wrench relocation, then real player visuals/interactions.
3. Compare standalone Elepower/fluid_lib APIs and selected Technic utilities
   against our existing RF/job tests before expanding a custom framework.
4. Adopt passing components with reviewed recipes/features and license notices.
   Preserve current worlds and keep the early simple ejector where useful.

Audit licenses and enforce source pins before importing code or media. New
audit checkouts are ignored reference inputs, not runtime dependencies. No
comparison modpack has been added to the normal game by this review.

Custom Mineclonia singlenode mapgen previously exceeded the test budget under
bundled Lua. Integration uses engine singlenode with
`mcl_singlenode_mapgen=false`; play uses engine v7. Engine recipe resolution/ingredient consumption is covered by integration.
The user has confirmed demo output withdrawal and wrench interactions. Actual
crafting, a complete survival playthrough and multiplayer remain unvalidated.
See `docs/test-results.md` for automated/hands-on validation boundaries.
