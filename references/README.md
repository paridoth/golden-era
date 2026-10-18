# Revelation reference inputs

Selected by the user on 2026-10-18: **FTB Revelation 3.7.0**, pack ID **35**,
version ID **12180**, Minecraft **1.12.2**, Forge **14.23.5.2858**. The FTB
manifest also names Java **8.0.312+7** for its original runtime. These are source
reference versions, separate from Golden Era's Luanti/Lua runtime.

Primary sources:

- [Official pack](https://feed-the-beast.com/modpacks/35-ftb-revelation)
- [Official version listing](https://feed-the-beast.com/modpacks/35-ftb-revelation/versions)
- [Official version manifest](https://api.feed-the-beast.com/v1/modpacks/public/modpack/35/12180)

## Committed records

`revelation-3.7.0.lock.json` contains a normalized inventory of all 1000 manifest
file entries, exact paths, file IDs, sizes, hashes, URLs/mirrors and side flags.
Its SHA-256 content digest excludes usage counters/timestamps and other volatile
API metadata. The original observed raw-response digest is recorded separately;
`cache/revelation-3.7.0/manifest.json` retains that first response locally.

`revelation-3.7.0-mods.tsv` inventories the 199 top-level `mods/*.jar` entries.
This is a file count, not a verified count of loaded mods: one JAR may contain
multiple mods, nested library caches also exist, and side/optional flags matter.
`revelation-3.7.0-summary.json` records exact manifest type/selection counts.

`revelation-3.7.0-facts.json` contains 15 reviewed Thermal Expansion configuration
values, each with a source path, SHA-256 and line number. Facts are extracted
from the verified original config; they do not claim effective runtime parity.

## Fetch and verify

```sh
python3 scripts/reference.py fetch
python3 scripts/reference.py check
python3 scripts/reference.py report
python3 scripts/reference.py facts
```

Fetch selects **675** config files under `config/` and all **four** scripts under
`scripts/` (679 files, 16338511 bytes). The manifest labels four nested library
cache entries as `config`; they are outside these roots and are excluded.
All selected files must match byte count, SHA-256 and SHA-1 from the lock.
Existing invalid cache files fail verification and are not silently overwritten.
Failed primary downloads may use a locked mirror only when its bytes verify.

All downloaded originals stay under ignored `references/cache/`, with their
headers and bytes intact. This operation does not install or execute Java,
Minecraft, Forge, JARs, installers, script engines or pack scripts. No reference
files are copied into the Luanti runtime or claimed as our own assets.

The `pin --date YYYY-MM-DD` command created the initial lock. It refuses to
replace an existing lock. A future repin/version change needs an explicit review
of identity, content changes and affected behavior; fetching never follows an
unversioned "latest" target.

## Thermal factory specification

`revelation-3.7.0-thermal.json` combines 21 config facts, five selected
processing/fuel records, three normalized pack crafting statements and reviewed
binary rules. `thermal-review.json` records authored interpretations with exact
class hashes and method/offset anchors. Read [the specification](../docs/thermal-factory-spec.md)
for the supported subset, unknowns and migration boundary.

```sh
python3 scripts/thermal_reference.py fetch
python3 scripts/thermal_reference.py check
python3 scripts/thermal_reference.py export
```

This separate fetch obtains two hash-verified, inert JARs (TE and CoFH Core). It
never loads their classes. The importer reads selected JSON resources directly;
class interpretations remain reviewed records, not automatic Java translation.
All originals stay in ignored cache storage. The generated data has unresolved
ore groups and is explicitly not ready for native runtime use.

## What remains to extract

The reference tool inventories every file and imports original config/script
inputs. The scoped Thermal importer additionally normalizes selected embedded
recipes and three literal ZenScript statements. It does not evaluate general
ZenScript, resolve ore dictionary groups/NBT, run registration code, export the
effective recipe registry, or translate arbitrary Java logic. Follow `docs/roadmap.md`
for the scoped native implementation and parity workflow.

## Native crafting catalog

`thermal-crafting-review.json` records exact class/config evidence, source item
identities, chosen native representatives and reviewed default patterns. Three
pack overrides are taken from the Thermal intermediate specification. The
compiler produces `mods/era_materials/catalog.lua`, which the native game uses
for 14 materials and ten recipes. See [native crafting](../docs/native-crafting.md)
for evidence, generation commands and gameplay limitations. `check-generated`
runs offline; full `check` verifies originals in the ignored cache. The additional
MCP mapping used to resolve vanilla field names is hash-pinned in the review.
