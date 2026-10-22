# Using your own Minecraft 1.12 texture packs

Golden Era ships only its own and freely licensed textures. Testers who own
Minecraft 1.12 resource packs, such as PureBDcraft and its mod patches, can
convert them locally for personal use:

```sh
python3 integrations/playtest/textures/convert.py "PureBDcraft 32x MC112.zip" --output ~/Textures/converted --name golden_era_sphax
```

List the base pack first; later packs override earlier ones. The converter
reads Mineclonia's `Conversion_Table.csv` and renames 1.12 files with
`integrations/playtest/textures/mc112.py`. It refuses to write inside this
repository, and converted textures must never be committed, packaged or
uploaded. `conversion-report.txt` in the output lists every texture used and
every table entry the packs did not cover; content added after Minecraft 1.12
keeps Golden Era's own art.

To try the result, set `texture_path` in the save folder's `settings.conf` to
the output folder, or copy it into the engine's `textures` folder and choose it
under Content in the main menu.

`integrations/playtest/textures/mods112.py` maps BDcraft-style mod patches onto
Golden Era's mods: Thermal Expansion and Thermal Foundation onto Elepower
machines, ores, ingots, metal blocks and lead tools, and Storage Drawers onto
Drawers. Add the patches after the base pack, for example:

```sh
python3 integrations/playtest/textures/convert.py "PureBDcraft 32x MC112.zip" Sphax_CoFHCore_32x.zip Sphax_ThermalFoundation_32x.zip Sphax_ThermalExpansion_32x.zip "Sphax Storage Drawers 32x MC112.zip" --output ~/Textures/converted --name golden_era_sphax
```

Elepower dusts, gears and plates are tinted in code from one image, so they
keep their own look. Logistica, Pipeworks, Travelnet and Magicalities are not
mapped yet.
