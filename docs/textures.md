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

To switch Golden Era to the result, start the game once, close it, then run:

```sh
python3 integrations/playtest/textures/install.py ~/Textures/converted/golden_era_sphax
```

It copies the pack into the save folder's `textures` folder and points
`texture_path` in `settings.conf` at it; `--remove` goes back to Golden Era's own
textures. For a Windows PC, add `--windows-zip ~/Textures/golden_era_sphax-windows.zip`
instead: unzip that on the PC and double-click `install-textures.bat`
(`use-default-textures.bat` undoes it). The installer refuses to replace a
folder it did not make, and refuses to write the ZIP inside this repository.

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
