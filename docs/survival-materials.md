# First-factory survival materials

Tin, silver and lead now have native ore nodes, stone-only scatter generation
and one-ore-to-one-ingot conventional cooking. This supplies tin gears and the
silver transmission coil before a powered machine exists. Mineclonia supplies
iron, copper, gold, redstone, glass and the other vanilla ingredients. Its modern
copper drops and survival rules remain foundation differences.

## Source and native terrain mapping

The exact Revelation file `config/cofh/world/01_thermalfoundation_ores.json` is
hash-verified against the pack lock. Its selected records are preserved in
[thermal-survival-review.json](../references/thermal-survival-review.json).
Thermal Foundation `BlockOre.initialize` supplies ore smelting; `ItemMaterial`
supplies dust smelting and electrum mixing. Exact class hashes and method anchors
are in [the crafting review](../references/thermal-crafting-review.json).

| Feature | Minecraft layer band | Attempts per 16×16 column | Blocks per cluster | Composition |
| --- | --- | --- | --- | --- |
| Tin | 20–55 | 7 | 8 | Tin |
| Silver | 5–30 | 4 | 8 | 80% silver, 20% lead |
| Lead | 10–35 | 4 | 8 | 90% lead, 10% silver |

Luanti scatter approximates these densities. Native bands include both endpoints;
`mcl_worlds.layer_to_y(layer, "overworld")` maps them into Mineclonia coordinates
(default old-layer origin −62). Each composition uses independent scatter
registrations, with scarcity rounded from `256 × band-height / weighted-attempts`,
eight attempted placements in a 3×3×3 cube. This preserves approximate material
availability, not Java vein topology, mixed-vein correlations, per-seed positions
or exact min/max-height boundary semantics. Nether/End do not intersect these
Overworld bands. Only `mcl_core:stone` is replaced. No duplicate native copper
feature or retrogen into explored chunks is added; explore new chunks in old
worlds. Nickel ore generation is outside this first subset.

The ore node drops itself and can be conventionally cooked in ten seconds.
Mineclonia tool groups enforce harvesting; no fortune bonus is assigned. Ore
faces use color transforms of our existing CC0 placeholder, not original mod
textures. Experience, biome/exploration parity and gameplay abundance need play
review. Engine tests validate the generator on a solid-stone VoxelManip fixture;
they do not establish accessibility or balance in a real v7 survival playthrough.

## Processing and storage path

Native Pulverizers now accept copper/tin/silver/lead ore blocks for two matching
dusts at 4000 RF, plus their pinned 10% secondary dust: gold/iron/lead/silver,
respectively. Silver and gold ingots pulverize to one matching dust at 2000 RF,
from the exact `PulverizerManager.addDefaultRecipes` rule. Modern raw copper
is not silently treated as an ore block. Existing iron/raw-iron support remains.

Gold dust plus silver dust crafts two electrum dust, each cooking to one electrum
ingot. Eight dust-to-ingot recipes use conventional ten-second cooking and
native Redstone Furnace processing at the sourced 1500 RF dust cost. This also
makes the earlier nickel byproduct usable. The explicit native representatives
do not enumerate Forge groups or prove the effective full-pack registry.

The basic cell replaces the old storage shortcut:

- Four lead ingots in an empty-center cross make a lead gear.
- Iron corners, glass edges and a lead-gear center make the basic cell frame.
- Redstone at top-left/bottom-right around an electrum ingot makes its coil.
- Redstone block above the frame, lead left/right and coil below make the cell.

The cell retains the `era_thermal:buffer` identifier and existing saved RF. Its
source-backed native capacity/transfer limits are unchanged. Crafting upgrades
require no world-state migration. Cable and ejector recipes remain provisional
native patterns. Ducts, fluid pipes, augments and safe machine relocation remain
separate work.

```sh
python3 scripts/thermal_survival.py check-sources
python3 scripts/thermal_survival.py check
# Inspect a candidate before replacing generated Lua:
python3 scripts/thermal_survival.py export > references/cache/survival-candidate.lua
```

Source checks compare original config bytes/selected records and reviewed class
hashes; ordinary checks reproduce generated definitions offline. The engine
crafting manager verifies all 15 catalog recipes and denies the old cell shortcut.
The two survival phases check actual scatter generation and host/band restrictions,
ore drops/cooking, tin/silver components, the electrum-to-cell path, exact processing
RF/secondary outputs and cell RF through SQLite restart. Gathering and player
craft actions remain a graphical playtest requirement.
