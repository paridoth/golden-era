# Reference pack — FTB Revelation 3.7.0

On **2026-10-18**, the user selected **FTB Revelation** as Golden Era's gameplay
reference. The concrete baseline is **3.7.0**, the version inspected during the
comparison. This supersedes the original early-Direwolf20 target in HANDOFF.md;
that handoff remains unchanged as a historical migration record.

## Exact selected identity

| Component | Pinned reference |
| --- | --- |
| Pack | FTB Revelation 3.7.0 |
| FTB pack/version IDs | 35 / 12180 |
| Minecraft | 1.12.2 |
| Forge | 14.23.5.2858 |
| Original Java runtime in FTB manifest | 8.0.312+7 |

Source: [official FTB manifest](https://api.feed-the-beast.com/v1/modpacks/public/modpack/35/12180).
The complete normalized file inventory and hashes are in
[the reference lock](../references/revelation-3.7.0.lock.json). Golden Era continues
to run on its pinned Luanti/Mineclonia foundation; these Java versions describe
the reference pack and are not new runtime dependencies.

The manifest identifies Thermal Expansion **5.5.7.1**, Thermal Foundation
**2.6.7.1**, Thermal Dynamics **2.5.6.1**, Tinkers' Construct **2.13.0.183**,
Thaumcraft **6.1.BETA26**, AE2 **rv6-stable-7**, Ender IO **5.3.70**, and Botania
**r1.10-364.4**. Other selected systems include Blood Magic 2, Industrial
Foregoing, Immersive Engineering, Astral Sorcery, Refined Storage, and Extreme
Reactors. The exact full JAR inventory is in
[the mod inventory](../references/revelation-3.7.0-mods.tsv); no major-mod list
should be substituted for that versioned inventory.

## Actual inputs obtained

Fetched and verified 675 config files plus four pack scripts (679 files,
16338511 bytes). Every file matches the locked size, SHA-256 and SHA-1. Originals
remain in ignored `references/cache/revelation-3.7.0/files/`; only metadata,
factual extracts and authored documentation are tracked. See
[the workflow](../references/README.md).

The four scripts are `00_recipe_changes.zs`, `01_unification.zs`,
`02_akashic_tome.zs`, and `03_tooltip.zs`. Inspection confirms pack-specific
recipe changes and material unification. They must be considered alongside
mod defaults. They have not been executed or semantically imported.

## First sourced configuration facts

Source: `config/cofh/thermalexpansion/common.cfg`, SHA-256
`6232ee2e04483ae16872553f4af33c92a3cfcb6851b2cbc7fd718468650e3a8a`.
The [fact sheet](../references/revelation-3.7.0-facts.json) records exact key paths
and line numbers for all 15 extracted values. Examples:

| Configured value | Pack value | Evidence line |
| --- | ---: | ---: |
| Steam Dynamo base power | 40 RF/t | 128 |
| Redstone Furnace base power consumption | 20 RF/t | 308 |
| Pulverizer base power consumption | 20 RF/t | 314 |
| Pulverizer default ore-to-dust multiplier | 2 | 318 |
| Basic Energy Cell capacity | 2000000 RF | 648 |
| Basic Energy Cell receive/send rate | 1000 / 1000 RF/t | 651 / 654 |

These establish configured base values. They do not establish per-recipe RF
costs, coal energy, water consumption, tier/augment behavior, buffer-dependent
speed or the fully resolved recipe registry. The item Flux Capacitor and block
Energy Cell also have different settings; do not conflate them.

## Existing engineering values — still provisional

The current fixture uses generator 20 RF/t, coal 1600 ticks, donor/buffer transfer
80 RF/t, processor input 40 RF/t, pulverizer cost 4000 RF, furnace cost 2000 RF,
processing limit 40 RF/t, and ore multiplier 2. Capacities remain 32000 generator,
100000 buffer and 8000 processors. Crafting patterns remain provisional.

These fixture numbers have not been changed merely because a few config fields
are known. A correct native implementation must first connect the reference's
recipe costs, dynamo fuel/fluid model, power/scaling rules and side controls.
Mineclonia's modern survival behavior is not evidence of Minecraft 1.12.2 parity.

## Evidence policy

For each implemented behavior, record the exact reference input/hash and source
location, distinguish a configured override from a mod default, and mark code-
defined or unresolved behavior explicitly. Use permitted source inspection,
controlled exports or observations from the original runtime where necessary.
The end product is native Luanti behavior backed by the selected pack. Existing
JARs and assets are not automatically translated, executed or redistributed.
