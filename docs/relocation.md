# Relocating filled machines

A Factory Wrench can pack a validated machine without discarding its RF, water,
fuel credits, items or partially paid job. Hold the wrench and sneak-right-click
the machine, or open its form and press **Pack machine** while holding it. An empty
player inventory slot is required. The machine becomes one nonstackable package.
Select that package and place it into loaded, unprotected air above the pointed
block. The machine restores its saved facing and configuration. Placement assigns
the current player as owner, matching ordinary placement and avoiding reuse of
another player's automation authorization.

Ordinary digging still requires an empty machine. Packing is also subject to
protection, the interact privilege, a six-node interaction limit and saved-state
validation. Invalid/future state is not reset to make
it portable. Pack and placement do not yield between preflight and commit.
The package is consumed even in creative mode. Copying a package does not create
a second usable machine.

## Reference and explicit native differences

The wrench pattern comes from the exact Thermal Foundation 2.6.7.1
`ItemWrench.initialize`: iron at top-left, top-right and bottom-center; tin in the
center. Three iron ingots and one tin ingot produce one wrench. The original is
named Crescent Hammer; this game uses its native Factory Wrench identity and
an existing original placeholder image.

Exact hashes/method anchors are in the crafting and runtime reviews. Passive
inspection found that baseline Thermal dismantling retains RF in a dropped
machine item, spills inventories as separate world items, and does not include
water/fuel credits or partially paid work in that item. Processor side cache and
facing are included, with placement-dependent orientation behavior. Complete
inter-mod event/augment behavior has not been traced.

Native relocation deliberately retains the complete validated snapshot instead:
RF, work, burn, profile/schema, water/credits, saved job bytes and byproduct roll,
all inventory lists/item metadata, facing and side/output configuration. It inserts
the package into the player inventory and preserves its saved orientation. The
Pack form control is a native interface. This is a usability decision, not a claim
of original dismantling parity. The actual factory processing/crafting reference
remains Revelation 3.7.0.

## Package storage and recovery

A package contains a version and opaque token. Its authoritative snapshot stays
in this world's `era_core` mod storage, bounded to 256 KiB. Tokens use a persisted
random world nonce and monotonically issued counter. Successful placement deletes
its outstanding record; replayed, copied, unknown and foreign-world tokens cannot
restore another machine. The item cannot be used as a material or ordinary
stackable node. Administrative mods/privileged storage edits are outside this
integrity boundary.

Packing validates the source and checks player space before removing it.
Air with existing metadata, inventory lists or an active timer is treated as
occupied, so placement cannot erase that data. Placement validates the record,
restores the node, then revalidates its machine
state before consuming the record/item. Ordinary Lua failures attempt synchronous
rollback; failed validation leaves the package available and restores the target.
If rollback itself fails, the original snapshot is quarantined and its active
token disabled rather than made usable beside a possibly restored machine.
Recovery requires examining both world state and that snapshot. Malformed records
require trusted repair from known-good state.

Keep the whole world together when backing up or moving it: packed state is
not contained entirely in the player inventory database. A package copied into
another world is not portable. Item inventory, mapblock and mod-storage writes
are not an atomic forced-crash transaction. Clean restart behavior is covered by
the engine suite; power-loss recovery still requires the separate journal work
identified in the roadmap.

## Validation boundary

Three engine phases pack a native partial job with a saved winning byproduct,
a generator with water/negative credit remainders, a genuine schema-1 legacy fixed job (migrated without changing job bytes) and a
charged cell. They preserve packages/registry through SQLite restart, restore
resources/items/facing/owner and complete exact remaining work without reroll.
A second restart checks output persistence and spent-token rejection.

Other cases include missing wrench, protection, full inventory, invalid source,
future/unknown/foreign/overcount packets, occupied/unloaded/protected targets,
invalid restored-state rollback, injected packing failure, failed rollback
quarantine and creative consumption. These use real
inventories, metadata and registry storage with fixture players; they do not
claim player-network mouse events, forced-crash atomicity or arbitrary third-party
callback compatibility. The QA world offers `/factory_wrench` for hands-on testing.
