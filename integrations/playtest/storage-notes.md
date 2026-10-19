# Stock storage route and compatibility evidence

Reference: Storage Drawers `5c8aa86f481852cc59b678023193135d5ab9963d`
with Mineclonia `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1` and the pinned
Pipeworks. No Java mods are executed, no recipe costs are invented, and upstream
checkouts stay unchanged. `drawers.py` edits a disposable mod copy during assembly.

## Reachable native recipes

The one-compartment drawer costs six planks and one native chest. Two-compartment
drawers cost seven planks and two chests for two blocks; four-compartment drawers
cost five planks and four chests for four blocks. Oak uses `group:wood`; the other
five variants use their native Mineclonia wood aliases. Specific wood recipes take
precedence over the generic recipe when that wood is supplied.

Trim costs five planks and four sticks for six connectors. A controller costs four
ordinary iron ingots, two gold, two diamonds and any drawer. It does not need
Elepower steel, tin, or a new machine. Eight sticks around any spare drawer make
four upgrade templates. Each capacity upgrade uses one template, four sticks and
four of its material: ordinary iron, gold, obsidian, diamond, or emerald. Mithril
upgrades are not registered because the optional Moreores mod is absent.

Those materials have stock survival routes. Mineclonia provides the normal wood,
chests, sticks and ores; emerald ore generation is in `mcl_biomes/ores.lua` and
villager trading is another native route. The engine regression resolves every
registered Drawers craft with concrete ingredients. It checks recipes and aliases,
not the time or travel needed to gather every ingredient.

## Player behavior

Right-click the drawer's item picture to deposit the held stack. Empty-hand
right-click deposits matching inventory stacks. Left-click retrieves a stack;
sneak retrieves one item. Aux1 + left-click toggles the item-type lock; Aux1's
default desktop key is **E**. Type locking reserves that item when emptied and
does not replace world protection. Use a drawer's ordinary node face to open its
five capacity-upgrade slots.

For a 64-stack item, unupgraded per-compartment capacity is 2,304 for a single
drawer, 1,152 for a two-compartment block, and 576 for a four-compartment block.
Smaller item stack limits reduce these values. Capacity bonuses add: one iron
upgrade gives x2 total, two iron upgrades x3 total, and iron plus gold x4 total.
Native drawers store plain stackable items by name/count. They cannot preserve
tool wear or arbitrary item metadata.

Connect drawers with drawers or trim within the controller's 14-block range on
each axis. The controller accepts deposits through its interface or Pipeworks.
Its default distribution setting keeps a material in one drawer; enabling
**Drawer Distribution** allows it to spread into additional matching/empty slots.
Retrieve items from individual drawer fronts. The bundled controller is not a
search/crafting terminal, and the current native Pipeworks integration supplies
deposit hooks, not extraction hooks. Optional Digilines/Techage extraction exists
upstream but those mods are not bundled.

## Confirmed pinned defects and bounded repairs

- `lua/visual.lua:564–583` removes capacity overflow, then calls
  `core.item_drop(stack, nil, pos)`. Mineclonia's override in
  `mcl_item_entity/init.lua:257–278` does nothing without a player. Removing
  upgrades from 5,000 iron loses exactly 2,696 in the pinned baseline. A
  Mineclonia-only `core.add_item` branch makes each native bounded batch an actual
  recoverable entity.
- `lua/api.lua:109–125` uses the same player drop-key function for automatic dig
  spills. The engine's dummy digger is truthy but not a player; a sneaking real
  player drops only one item per batch and returned leftovers are ignored.
  Mineclonia automatic spills now use `core.add_item` after the existing inventory
  transfer. Other games retain their upstream branch.
- `lua/controller.lua:372–378` calls `default.get_inventory_drops`, unavailable in
  Mineclonia. Its real explosion loop invokes that callback at
  `mcl_explosions/init.lua:338–340`, ignores returned drops and delegates removal.
  The Mineclonia branch explicitly emits full source ItemStacks and the controller,
  honors `do_drop=false`, then removes the node. The original branch is retained.
- `lua/visual.lua:440–462` refuses metadata and unstackable tools, but accepts
  stackable items with nonzero wear even though name/count storage discards it.
  The copy refuses wear too, preserving the native storage format.
- `lua/api.lua:345–391` already makes drawers immovable under Mesecons MVPS to
  avoid visual state corruption. Mineclonia's separate native pistons only honor
  their own `unmovable_by_piston` group. Their push path restores full metadata
  after spawning empty visuals; the next insert can erase the old contents.
  The copy marks drawer blocks with that native group, matching the existing
  upstream immobility policy. Controllers remain movable and reindex by origin.
- `lua/controller.lua:32–44` validates nonexistent `drawer_positions` and direct
  `visualid` fields. The indexer actually emits arrays of `{drawer_pos, visualid}`
  at lines 112–115. A five-node network consequently scans all five nodes for
  every preflight and deposit. The copy validates the real array shape and
  invalidates nearby controller paths on drawer/trim construction/destruction,
  visual removal/respawn and controller reload. Native explosions and Mesecons
  moves use those node callbacks. Controllers also check the saved cache's origin
  position, because MVPS restores old metadata after construction when moving a
  controller. Repeated warm deposits scan zero neighborhoods;
  broken trim paths still refuse every incoming item. Removed visual objects are
  unavailable until restored.

Run `python3 tests/storage/run.py` for pinned-baseline comparison and repaired
conservation/restart evidence. See `tests/storage/README.md` for exact scope and
limitations. No saved player worlds or frozen 0.1.2 artifacts are changed.
