# Native autocrafting and drawer scenario

Run from the repository root:

```sh
python3 tests/automation/run.py
```

The scenario assembles the existing pinned playtest game into a disposable copy,
uses loopback port 30214 and starts the engine twice against the same temporary
world. It does not alter production mods, compatibility patches, player saves or
the supplied workshop. Its fixtures use stock node constructors, inventory/UI
callbacks, actual node timers, Mesecons blinking controls, filter-injectors,
moving tube entities and Storage Drawers.

A test-only activation marker waits until the fresh mapblock's native loading
modifiers finish before placing machines. This matches player placement and
prevents Pipeworks' legacy filter-inventory migration from treating newly scripted
ghost examples as old physical items. Adjacent mapblocks remain active for drawer
visuals that cross a block edge.

The first line runs from a supplied input barrel through an injector and tube to
an Autocrafter, then through another injector and tube into a drawer. The native
conduit recipe consumes six lead ingots and three copper wires for eight conduits
and three empty-spool byproducts.

The output injector has a conduit ghost filter. This sends the conduits into the
drawer while leaving empty spools in the autocrafter's crafted-items inventory.
The default “Keep non-consumables” mode does not move these changed-item
byproducts back into the input inventory; collect or route the spools separately.

## Acceptance checks

1. Native controls configure the conduit recipe and enable the machine.
2. Real blinking controls and injectors transfer the two input stacks from the
   barrel through a tube into the autocrafter.
3. Twelve full output slots stop crafting without consuming either ingredient or
   changing unrelated output stacks.
4. One free output slot still stops crafting: the product and all three spools
   need space. No partial craft is committed.
5. Freeing a second output slot through the normal inventory callback restarts
   crafting. The drawer receives exactly eight conduits; all three spools remain.
6. A second input batch arrives while the machine is disabled. The server exits
   normally, saving its real inventories, ghost recipe and drawer contents.
7. A new engine process loads the same world. Canonical stack metadata, inventory
   contents, recipe, enable state and drawer contents match the checkpoint.
8. Native controls reenable the machine. Production ends with sixteen conduits in
   storage and six empty spools retained. No extra batch appears after the inputs
   exhaust.
9. A separate tube-fed autocrafter uses a native `group:wood` stick recipe with
   acacia wood, rebuilding group/cache state after restart. Its drawer receives
   exactly four sticks and its physical inputs and outputs empty completely.

Fixture materials and devices are provided explicitly. This checks stock
automation behavior and conservation, not survival gathering, human interface
comfort, performance under a large factory, or remote multiplayer protection.
No production timer or Mesecons effector is invoked manually.

The runner writes `runtime/tests/automation-smoke.log`. Test worlds are removed
after the two phases finish; `--keep-world` preserves the isolated copy for
investigation. ItemStack metadata is compared by sorted fields;
the engine may reorder its binary serialization across a process restart.
