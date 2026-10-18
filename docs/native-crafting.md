# Native Thermal crafting subset

The native game now uses fifteen reviewed crafting patterns: copper/tin/bronze
gears, bronze ingots, gold/silver coils, a basic machine frame, the coal generator,
Pulverizer and powered furnace. The former generator/pulverizer/furnace shortcuts
have been removed. Existing placed machines and their inventories/jobs retain
the same identifiers and state semantics; the crafting change itself requires no save schema migration. The later
[RF/water implementation](native-resources.md) now supplies a separate known-state
migration.

## Source and generation

[thermal-crafting-review.json](../references/thermal-crafting-review.json) records
ten exact class hashes and method/offset anchors from Thermal Expansion
5.5.7.1, Thermal Foundation 2.6.7.1 and CoFH Core 4.6.6.1. It records the relevant
Foundation and UniDict config hashes/locations, plus explicit source-to-native
identity mappings and reviewed patterns. Three pack crafting overrides come from
the existing hash-verified Thermal intermediate specification.

Obfuscated vanilla field names for piston, brick block and flint were resolved
with MCP stable 39 for 1.12, obtained from the Forge Maven repository. The ZIP's
URL, byte count, SHA-256 and relevant CSV entries are pinned in the review; the
original stays ignored. MCP is a name-reading aid, not a new game dependency.
No original Java classes or pack scripts execute in this pipeline.

```sh
python3 scripts/reference.py fetch
python3 scripts/thermal_catalog.py fetch
python3 scripts/thermal_catalog.py check
python3 scripts/thermal_catalog.py check-generated
# Intentional regeneration, followed by review before replacing the tracked file:
python3 scripts/thermal_catalog.py export > references/cache/catalog-candidate.lua
```

`check` validates original artifacts/class/config/script evidence and generated
Lua. `check-generated` is an offline compiler consistency check against committed
review/specification inputs; it does not revalidate missing downloaded originals.
The ordinary unit-test entrypoint runs this offline check. A changed pack lock,
Mineclonia foundation pin, missing identity, ambiguous override or unsupported
counted ingredient requires a deliberate review rather than silent conversion.

[The generated catalog](../mods/era_materials/catalog.lua) is native Lua 5.1,
containing 23 material declarations and fifteen recipes. Runtime startup registers
those definitions and confirms every ingredient/output is registered. Material
recipes load in era_materials; machine recipes load in era_thermal. The runtime
never reads a JAR, ZenScript or ignored reference cache.

## Supported identities

Thermal Foundation material metadata is preserved in the source map, including
iron dust **0**, gold dust **1**, copper/tin dust **64/65**, nickel dust **69**,
copper/tin/silver ingots **128/129/130**, bronze ingot **163**, copper/tin/bronze
gears **256/257/291**, and gold/silver coils **513/514**. The basic machine frame
is Thermal Expansion frame metadata **0**. Metadata 0 and metadata 69 are distinct
items; their identities must never be merged by stripping metadata.

Mineclonia supplies the chosen native iron, gold, copper, redstone, glass,
piston, brick block and flint representatives. Golden Era defines missing
materials/components using the existing original placeholder image. No new
third-party assets have been copied. The foundation pin and explicit mod
requirements make these item-name choices reviewable.

These are deliberate native representatives for this supported slice. They do
not enumerate every item in a Forge ore group, prove effective UniDict order,
or promise compatibility with other Luanti mods. Original pack semantics retain
the distinction between concrete items and groups in the source records.

## Patterns now used by the game

Each slash separates a row; a dot means an empty slot.

| Result | Pattern | Ingredients |
| --- | --- | --- |
| Copper gear | `.C./C.C/.C.` | C = copper ingot; center empty |
| Tin gear | `.T./TIT/.T.` | T = tin ingot, I = iron ingot |
| Bronze gear | `.B./BIB/.B.` | B = bronze ingot, I = iron ingot |
| Two bronze ingots | shapeless | three copper ingots and one tin ingot |
| Reception coil | `..R/.G./R..` | R = redstone, G = gold ingot |
| Transmission coil | `..R/.S./R..` | R = redstone, S = silver ingot |
| Machine frame | `IGI/GTG/IGI` | I = iron ingot, G = glass, T = tin gear |
| Coal generator | `.C./IGI/URU` | C = transmission coil, I = iron ingot, G = copper gear, U = copper ingot, R = redstone |
| Pulverizer | `.P./FMF/CRC` | P = piston, F = flint, M = frame, C = copper gear, R = reception coil |
| Powered furnace | `.R./BMB/CPC` | R = redstone, B = brick block, M = frame, C = copper gear, P = reception coil |

Foundation's `AlternateGears=false` selects an empty-center default copper gear.
Revelation explicitly adds the iron-center tin recipe. Treating all gears alike
would lose that pack-specific distinction. The native subset includes the
selected tin override; it does not implement every alternative recipe or Forge
mirroring rule. Only the documented orientation is guaranteed for the coils.

## Current gameplay and validation boundary

The [basic RF/water model](native-resources.md) now operates new machines, while
legacy machines retain their old profile until explicitly upgraded. Persisted nickel byproducts and [item-side controls](item-sides.md) are implemented;
the basic cell recipe is implemented; augments and cable/ejector recipe parity
remain incomplete.
These crafting patterns do not establish complete Steam Dynamo or pack parity.

Tin, silver and lead now have [native survival acquisition](survival-materials.md),
and the cell has a reviewed lead frame/electrum coil path. Ore placement is a
native approximation; gathering/crafting through a real player remains untested.
New material/component visuals remain placeholders.

Engine checks query Luanti's real crafting manager against independent reference
examples, including exact ingredient counts, shuffled shapeless bronze inputs,
the tin/copper gear distinction and wrong-coil denial. They also reject all
three old machine shortcuts and preserve denied inputs. The extended twenty-process restart,
job, unload/reload and malformed-state suite remains required after runtime edits.
Actual player inventory/crafting callbacks, graphical usability and effective
original-pack parity remain separate validation work.

The later [survival materials](survival-materials.md) milestone adds lead gear,
cell frame, electrum dust/coil and the basic cell pattern, replacing the old cell
shortcut. Electrum coil uses the opposite diagonal from gold/silver coils.
