# Stock farming overflow and next survival step

Pinned sources: Elepower `c37fe7bc3fc52a05e03507ca35cba2c8e5b3e330`,
Mineclonia `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1`, Luanti 5.17.0
`c0e6812b1a4260bb25a1f606f70f55f4962bb97d`.

## Confirmed native loss and bounded repair

The original harvester resolves mature crop drops and removes the crop in
`elepower_farming/machines/harvester.lua:70–76`. Its output loop at 142–146 only
adds a complete stack if it fits. Rejected items have no remaining inventory or
world representation. Native 0.1.4 evidence is retained at
`docs/evidence/2026-10-19/harvester-0.1.4-baseline-*`.

That actual coal-powered, normal-timer baseline observed:

| Output | Exact native harvest | Stored | Dropped | Lost |
| --- | --- | --- | --- | --- |
| Empty | 2 seeds + 1 wheat | all 3 | 0 | 0 |
| One seed space | 1 seed + 1 wheat | 1 seed | 0 | 1 wheat |
| Full |1 seed+1 wheat| 0 | 0 |both|

The copied-source repair changes only this output insertion loop. Native
`InvRef:add_item` inserts the amount that fits; only its returned nonempty full
ItemStack is emitted through `core.add_item`, one node above the still-placed
harvester. Partial insertion never spills the original stack again. Wear and
metadata remain attached to the leftover. Mineclonia's player drop-key
`item_drop` is not used for this automatic spill.

Crop selection/removal, productive sweep energy 128 E, stock work clock, sludge
production and normal successful insertion remain unchanged. A full output still
harvests and now spills visible excess above the machine; this is not output
backpressure or a pause. Route outputs into storage and collect any loose excess.
No queue, inventory format, recipe, balance adjustment or additional mod is introduced.
The original upstream checkout and frozen releases stay untouched.

The existing crop/tree harvest loop uses `get_node_drops(name)` and `remove_node`
without an owner/protection preflight. This inherited protection/original-node
metadata boundary is separate from output conservation and is not fixed or
promised here. The regression's metadata/wear contract concerns actual generated
ItemStacks, not metadata stored in arbitrary world nodes.

## Ordinary progression and native layout

This farm belongs after a Solderer and ordinary diamond mining. Both machine
recipes already exist in `elepower_farming/crafting.lua:20–38`. The Planter uses
2 nickel, 1 control circuit, 2 iron hoes, a Device Frame, 2 copper coils and a motor. The
Harvester uses2 nickel, 1 control circuit, an iron axe/hoe, Device Frame, 2 motors and a
diamond gear. One control circuit is a stock Solderer recipe using 8 chips,
2 integrated circuits and 4 capacitors (`elepower_machines/crafting.lua:324–331`).
Registered-recipe closure includes both machines from the ordinary material roots,
including diamonds. This proves recipe ordering, not a material budget or travel.

Mineclonia short grass yields seeds through native hand harvesting at 1/8 chance
(`mcl_flowers/register.lua:247–254,301–335`). Wheat seeds plant on native farmland
and mature crops yield at least 1 seed and 1 wheat (`mcl_farming/wheat.lua:7–20,93–117`).
Elepower recognizes Mineclonia seed names and mature entries in
`mcl_farming.plant_lists`; its existing soil/tool compatibility mappings are used.

Use one 3x3 planter layout sector to start. The upper layout grid is a ghost
selector; put actual seed supply in the separate physical src slots. Put the
planter beneath the field with water immediately above it and 8 farmland blocks
around that water. Its native layout slot 5 covers the central 3x3 sector. The
harvester sits at crop height just outside the field, pointing toward it.

The regression verified coordinates are planter `(80,198,-3)`, water
`(80,199,-3)`, farmland at Y199 over X79–81/Z−4–−2 except that water, crops at Y200,
and harvester `(80,200,0)` facing 0. Native front/range helpers cover the patch.
Seed-only filter/tubes return the harvester's seeds to planter src; a separate
wheat-only route leads to an ordinary barrel. Physical items used to configure
selectors remain owned separately. Neither a controller nor new farm framework
is required.

Sludge is an output, not a required input. Each productive sweep adds 10 mB,
regardless of crop count, to an 8000 mB buffer. The stock condition is strictly
`amount + 10 < capacity`; drain before the buffer fills. Small farm cycles make
little sludge. Full-buffer drainage is a separate bounded fluid-capacity concern.

## Verification boundaries

`tests/farming/` compares pinned baseline and copied repair across native
checkpoint/restart processes. It tests empty/partial/full outputs, a full
ItemStack drop contract, native pickup and saved ownership, plus a repaired
3x3 planter/harvester/clocked seed-return/wheat-storage cycle and another cycle
after restart. Original timer observers are installed before startup, retain and
invoke the registered callback, and never manually advance production ticks.

Machines, coal and 128 bone-meal items are fixture supplies. Seeds are acquired
through native digging/pickup from fixture grass; actual bone-meal placement
consumes counted fertilizer to bound test duration. A detached inventory actor
supplies configuration/placement actions. This does not claim a human graphical
survival playthrough, full machine material gathering, natural crop growth time
or broad multiplayer protection validation.

The completed run is retained at
`docs/evidence/2026-10-19/farming-0.1.5-smoke.log` (SHA-256
`199efd0327083960618762049fde5c4a4595290c692057e1086067ccabc797c8`).
All four baseline/repaired checkpoint and restart processes pass with zero
warnings or errors. The repaired partial metadata case stores 2 of 5 copper and
emits exactly 3 copper plus the complete worn tool. The first farm cycle stores
8 wheat, replants 8 crops and retains 5 excess seeds. After restart it reaches
16 stored wheat, replants again and accounts for all excess seeds; total sludge
is 20 mB and 35 of the original 128 fertilizer items have been consumed.

## Stock oak harvesting and vacuum collection

A separate audit runs the exact frozen 0.1.5 game ZIP, without changing its
extracted files. The planter, cutter, power timers, leaf decay and vacuum tubes
remain native. This checks a small layout and clean restart, not long unattended
farm operation or a guaranteed sapling yield.

For sapling space S, put dirt at S+(0,-1,0), the planter at S+(0,-2,0), and the
harvester at S+(0,0,4), facing the tree. Only one planting site is dirt; nearby
ground is stone. The planter's center layout slot selects oak; its physical src
holds the real saplings. One glass block at S+(0,8,0) constrains the tested oak
height. An Adjustable Vacuum Tube at S+(2,0,0), radius 8, joins the cutter's
barrel route. A clocked sapling-only filter returns items to the planter src.

One native growth uses three supplied bone meal and produces six logs and 52
leaves. The cutter takes all six logs and rolls 33 leaves, yielding one actual
sapling. The remaining 19 leaves decay through the real ABM; this particular
sample yields no additional drops. The sapling reaches the physical planter
inventory. Seven original spares are moved into a separate saved reserve;
after process restart the planter consumes only the returned sapling and plants
again. There are no remaining loose farm items or in-flight farm packets at
checkpoint. This delimits one controlled cycle with the planter paused during
decay; it does not measure a second tree's yield or natural growth duration.

An unrestricted large-oak sample shows why the small layout matters. Native
growth produces 16 logs and 271 leaves. The cutter takes ten logs and rolls 76
leaves, returning four saplings and five sticks; six branch logs remain. Twelve
orphan leaves decay, rolling two more saplings. Those real entities rest above
the ground vacuum's reach on the remaining canopy. The full inventory/world
ledger accounts for them; this is partial tree harvesting, not item loss.
Keep spare saplings because drops are random. The cutter's ordinary leaf rolls
do not produce leaf blocks; gather those separately with shears for plastic.

The same audit gives an adjustable vacuum five copper with wear 321 and custom
metadata, plus a pick with wear 4321 and metadata. With its barrel full, both
complete logical Pipeworks packets persist across clean process restart. After
two filler stacks are moved into another barrel, all six items arrive with
their exact fields and counts. Logical packets, inventories and world items
are counted independently of visual tube entities.

A further native overdue-timer restart probe does not reproduce the conditional
preinitialization risk suggested by Pipeworks' source. The logical transport
table is absent in the earliest after(0), then initialized by the first stock
globalstep before block activation. The engine-fired overdue vacuum timer
captures and delivers both complete test stacks. No vacuum repair is introduced.
Clean shutdown/restart evidence does not establish crash-atomic persistence.
