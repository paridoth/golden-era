# Thermal factory reference specification — first supported slice

Reference: FTB Revelation 3.7.0, Thermal Expansion 5.5.7.1 and CoFH Core 4.6.6.1.
The generated [intermediate specification](../references/revelation-3.7.0-thermal.json)
is a **static reference**, not an effective Minecraft registry export. It is
explicitly marked `runtime_ready: false`. A supported subset now feeds the [native RF/water model](native-resources.md),
with preserved legacy profiles for older saves. The separate
[native crafting catalog](native-crafting.md) supplies ten reviewed patterns.
The full intermediate specification remains unresolved and is not installed wholesale.

## Evidence and reproducibility

The importer verifies original JAR sizes/SHA-256/SHA-1 against the pack lock,
reads specific ZIP entries without extracting them, verifies reviewed class
hashes, and records resource hashes and JSON pointers. It also verifies original
script/config bytes before reading them. No Java, mod or ZenScript code runs.

[thermal-review.json](../references/thermal-review.json) contains authored factual
interpretations of nine exact compiled classes, with class hashes, method names,
bytecode offsets or ConstantValue fields. Those interpretations were obtained by
passive class inspection. The importer verifies their byte provenance; it does
**not** automatically prove the interpretation or decompile arbitrary Java.
The CoFH public legacy source was used as a reading aid only; its branch head
is not substituted for the pinned binary's evidence.

```sh
python3 scripts/reference.py fetch
python3 scripts/thermal_reference.py fetch
python3 scripts/thermal_reference.py check
# For an intentional regeneration, capture to a temporary file, review, then replace:
python3 scripts/thermal_reference.py export > references/cache/thermal-candidate.json
```

`fetch` downloads only the two locked JARs needed for this specification. Existing
invalid cached bytes fail rather than being overwritten. Offline `check` rebuilds
the specification and compares it with the tracked result. Normal unit tests
use synthetic inputs and require neither downloaded originals nor network access.

## Supported imported records

| Record | Static result | Evidence inside the TE JAR |
| --- | --- | --- |
| Pulverize iron ore | 2 dustIron; 10% chance of 1 dustNickel; 4000 RF | `content/machine/pulverizer/pulverizer_ores.json`, `/pulverizer/2` |
| Pulverize copper ore | 2 dustCopper; 10% chance of 1 dustGold; 4000 RF | `content/machine/pulverizer/pulverizer_tf.json`, `/pulverizer/0` |
| Pulverize tin ore | 2 dustTin; 10% chance of 1 dustIron; 4000 RF | same resource, `/pulverizer/1` |
| Coal fuel | metadata 0; 24000 RF | `content/dynamo/steam.json`, `/dynamo_steam/0` |
| Charcoal fuel | metadata 1; 16000 RF | same resource, `/dynamo_steam/1`; omitted energy uses parser default |

Resource paths in this table start at `assets/thermalexpansion/`. Missing
pulverizer energy uses the parser's 4000 RF default. A positive explicit fuel
registration wins over the furnace burn-time fallback: coal's explicit 24000 RF
must not be replaced by the generic 16000 RF default. These are unaugmented
registration values, subject to later inter-mod changes.

Three pack crafting statements are normalized separately:

- `00_recipe_changes.zs:127`: three ingotCopper plus one ingotTin produce two
  Thermal Foundation material metadata 163 (bronze ingots).
- `00_recipe_changes.zs:132`: bronze ingots in a cross around a concrete
  `minecraft:iron_ingot` produce material metadata 291 (bronze gear).
- `01_unification.zs:12`: tin ingots in a cross around **ore-group ingotIron**
  produce material metadata 257 (tin gear).

Repeated ingredients, empty grid cells, concrete metadata and group identities
are preserved. Bronze's center is a concrete item; tin's center is a group.
The importer supports only these selected literal statements. It does not apply
recipe removals, enumerate all recipes, evaluate variables, process NBT, simulate
tool damage or execute any script. Unknown fields in selected records fail
rather than being discarded. The rest of the pack remains outside this import.

Ore dictionary names are unresolved identities, not Luanti item names or lists
of every accepted item. Importing `oreIron` therefore does not assert that a
Mineclonia raw iron item is valid. Preferred concrete outputs and group membership
must be established before generating native recipes.

## Reviewed behavioral rules

Twenty-one sourced config values accompany the records: the earlier 15 plus
small-storage, custom-scaling and custom-augment flags for machines/dynamos.
All six additional flags are false in the selected pack.

| Basic, unaugmented component | Static rule |
| --- | --- |
| Steam Dynamo | maximum 40 RF/t; 40000 RF buffer; 4000 mB water tank |
| Dynamo water batch | debit 100 mB and add 25000 RF of water credit when credit is nonpositive |
| Dynamo fuel and water | generated RF debits separate fuel and water credits; refill adds credit, preserving a negative remainder |
| Pulverizer / Redstone Furnace | maximum 20 RF/t; each has a 20000 RF buffer |
| Default dust-to-ingot smelting | 1500 RF when found by the normal furnace registry scan and not already registered |
| Basic Energy Cell | 2000000 RF capacity; configured receive/send 1000 RF/t |

The 1500 RF rule derives from the furnace default 2000 multiplied by 3/4 for
non-food dust-to-ingot smelting. A matching smelting registration must exist;
this rule is not itself a resolved iron recipe. Existing registrations and later
overrides can change which rule applies.

With ordinary storage, speed depends on internal RF `E`, using integer division:

- Basic machine: `E >= 18000` consumes 20 RF/t; `E < 2000` consumes `min(2,E)`;
  otherwise `floor(E/900)`.
- Basic Dynamo: `E <= 4000` generates 40 RF/t; `E > 36000` generates 4 RF/t;
  otherwise `floor((40000-E)/900)`.

These specify rate selection, not a complete tick: processing completion,
redstone, fuel availability, output space and energy transfer ordering matter.
Saturation and idle-loss behavior still need dedicated parity cases. A fixed
40 RF/t native processor would not reproduce this rule.

Default level 0–4 power factors are 100/150/200/250/300 percent. Default machine
operation-energy factors are all 100 percent. Energy Cell capacity and transfer
factors are 1/4/9/16/25. These arrays do not establish complete upgrade behavior;
augment effects, upgrade items/crafting, side defaults and transitions remain
unmapped.

## Native implementation boundary and next work

Current implementation boundary:

1. The native crafting subset now has explicit material representatives and
   three first-machine patterns. Resolve effective original registrations,
   processing outputs and remaining storage crafting; provide tin/silver
   survival acquisition before claiming a playable progression.
2. Map side configuration, fuel/water loading, redstone and transfer order. Obtain
   controlled original-runtime observations or exports for uncertain behavior.
3. Basic native definitions and schema-1 -> 2 legacy preservation now exist.
   Explicit idle upgrades preserve stored RF/items; old jobs keep their semantics.
4. Basic water tanks/credits, fuel RF, dynamic rates and primary processing are
   implemented. Persisted probabilistic secondary outputs remain pending. A
   blocked output must not reroll or duplicate byproducts when that feature lands.
5. Thirteen engine phases cover native resources, migration and older regressions.
   Graphical survival/player callbacks and original-runtime parity remain pending.

Static arithmetic for a later parity fixture: one ore to two dust at 4000 RF,
then two dust-to-ingot operations at 1500 RF each, totals **7000 RF per ore**.
Three such operations total 21000 RF and six primary ingots, with three independent
10% secondary opportunities. This is a conditional test oracle, not an observed
runtime result. Water must be accounted in batches: do not round a per-coal water
estimate and discard carried credit.

Unresolved behavior remains explicit in the generated specification. The older
32000/8000/100000-RF capacities persist only in the legacy profile. New machines
use sourced basic capacities/resource rules; fixed routing, graph dispatch and
unsupported content do not establish complete reference parity.
