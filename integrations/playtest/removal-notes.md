# Elepower machine removal compatibility

Pinned sources: Elepower `c37fe7bc3fc52a05e03507ca35cba2c8e5b3e330`,
Mineclonia `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1`, Luanti 5.17.0.
The assembler applies checked replacements to copied Elepower files. Upstream
checkouts, recipes, frozen releases and existing player worlds remain untouched.

## Confirmed losses

Elepower's default `can_dig` in `elepower_papi/machine.lua:11–15` checks only
`src` and `dst`. The Energy Density Reconstructor actually owns a `tool` list
(`elepower_tools/ed_reconstructor.lua:120–124`), and the Wireless Control Station
owns `card` (`elepower_wireless/machines/station.lua:179–183`). Neither supplies a
custom dig guard. Actual native mining with a fixture iron-pick actor removes
both occupied machines and emits the machine itself, losing the diamond tool or
bound card. The copied default now checks every owned inventory list.

Mineclonia's real explosion loop at `mcl_explosions/init.lua:333–368` invokes
`on_blast(pos, intensity, do_drop)` when available, ignores its return value and
delegates removal to that callback. Otherwise a node with `after_dig_node` goes
through `core.dig_node`, followed by bulk removal whether digging succeeded or
not. Elepower supplies an `after_dig_node` wrapper on every registered base device
(`machine.lua:276–284`), even without a custom original callback. Its wrapper only
maintains optional Tubelib registration; no owned-item spill exists. A full
pulverizer refuses that dig, then disappears with all its contents and no machine
item. An empty one instead emits a machine even when `do_drop=false`.

The copied Mineclonia-only default `on_blast` takes owned full ItemStacks before
removal, applies Elepower's native `preserve_metadata` to the machine drops only,
removes the node and invokes the existing `after_dig_node` callback. Native
`after_destruct` still invalidates Elepower's power graph and runs any original
cleanup. Items use `core.add_item`, which preserves metadata/wear under Mineclonia;
its player drop-key API `core.item_drop` is inappropriate for automatic spills.
`do_drop=false` removes the machine without emitting machine, items or upgrades.
An explicitly supplied blast callback remains unchanged.

## Inventory and resource boundaries

Owned native node inventories are `src`, `dst`, `fuel`, `tool` and `card` in the
pinned pack. Existing coal-alloy, grindstone, power-cell, planter, harvester,
spawner and fission-core guards already cover their real lists and remain in
place. Two lists must never count as physical items:

- `dst_tmp` is the persistent copy used to preflight outputs in crafters,
  grindstones, lava coolers and tree processors. It can retain duplicate outputs
  after the visible output slots are emptied.
- `layout` is a planter/harvester ghost filter. The planter's native put/take
  callbacks copy or clear it while returning zero transferred items.

These lists neither prevent an otherwise empty machine from being mined nor
produce blast drops. No inventory format or recipe changes are introduced.

Energy and installed upgrade components retain Elepower's native item metadata
when the machine item drops. Native placement restores them; the regression
checks the resulting hardened-capacitor capacity. Fluid buffers and in-progress
work are discarded on removal, matching existing Elepower mining behavior. This
repair does not create fluid containers, duplicate processing snapshots or promise
fluid recovery. A no-drop explosion also destroys the stored charge/components.

## Upgrade UI locking

The stock soldering UI sets `drop_lock` but the stock guards ignore it. Its
components also exist temporarily in a detached inventory, so removing the machine
while that UI is open can expose both representations. Mineclonia dig guards now
retain each original guard's result and also refuse removal while a connected
player's existing `soldering` position matches the machine. The default blast
callback likewise leaves an actively edited machine placed until the UI closes.

The shared `drop_lock` bit alone is insufficient: another editor leaving can
clear it. Existing player metadata provides the live editor positions without a
new state store. Saved flags without a connected editor do not permanently lock a
machine; the copied soldering cleanup runs on join as well as leave and safely
clears malformed/stale saved positions. A returning stale editor cannot unlock
another connected editor's UI.

The upstream UI still uses one global detached inventory named `soldering`.
Simultaneous soldering sessions by multiple players are a separate upstream
concurrency limitation, not solved by these removal guards. Tests use fixture
player metadata; human GUI/multiplayer upgrade editing is not claimed.

Run `python3 tests/machine-removal/run.py` for pinned-baseline versus repaired
native evidence and `python3 tests/machine-removal/test_patch.py` for checked
source anchors, repeatability and upstream isolation.
