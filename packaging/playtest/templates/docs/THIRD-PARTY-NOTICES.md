# Golden Era Playtest: third-party notices

Prepared 2026-10-18; packaging text reviewed 2026-10-19.
Paths below are relative to the extracted
`GoldenEra-Playtest/` directory.

This is a native Luanti game assembled from existing free-software projects.
It is not developed or endorsed by Mojang, Microsoft, Feed The Beast, or the
authors of the Java mods in FTB Revelation. Minecraft, FTB Revelation, Java mod
JARs, original modpack scripts, and the project's reference-download cache are
not included. The pack's name and inspiration do not grant rights in any
third-party trademark.

The game and its Lua source are in `games/golden_era_playtest/`. Original
copyright, author, attribution, README, media-license, and license files remain
in that tree. **Keep those notices with any redistribution.** This summary does
not replace the more specific notices or apply one license to every file.
Supplemental full license texts are in `licenses/`; their source URLs and hashes
are in `licenses/SOURCES.json`.

The game files are supplied in their editable form. Source for the assembly
and packaging changes is included under `source/project/`. Exact upstream
revisions and the list of runtime-copy patches are also recorded in
`games/golden_era_playtest/playtest-sources.json`. Modified copies must be
identified as modified and distributed under the applicable upstream terms.

## Included projects

| Project and pinned revision | Declared terms and attribution location |
| --- | --- |
| [Mineclonia 0.124.0](https://codeberg.org/mineclonia/mineclonia), `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1` | GPL-3.0-or-later code, with mod-local alternatives. See game-root `LEGAL.md`, `LICENSE.txt`, `CREDITS.md`, and individual mod notices. |
| [Pipeworks](https://github.com/mt-mods/pipeworks), `5dfd572eacee4c3c1ed8b827f4a67c46b022b242` | LGPL-3.0 code; CC-BY-SA-4.0 media and other assets. See `mods/pipeworks/LICENSE` and README. |
| [Basic Materials](https://github.com/mt-mods/basic_materials), `f626da067a39206b7d60c1122843cd951ffb7081` | LGPL-3.0 code; CC-BY-SA-4.0 media and other assets. See `mods/basic_materials/LICENSE` and README. |
| [Mesecons](https://github.com/minetest-mods/mesecons), `aca87dbd448637d2dc80e59e909425932acd6c84` | LGPL-3.0 code; CC-BY-SA-3.0 non-code content. Copyright Mesecons Mod Developer Team and contributors. See `mods/mesecons/COPYING.txt`, `LICENSE.txt`, README credits, and local notices. |
| [Elepower](https://github.com/LunaSquee/elepower), `c37fe7bc3fc52a05e03507ca35cba2c8e5b3e330` | MIT default. Copyright Evert "Diamond" Prants and sirrobzeroone. See `mods/elepower/LICENSE`, local notices, and the borrowed-code exception below. |
| [Universal Fluid API / fluid_lib](https://github.com/LunaSquee/fluid_lib), `9b52f6eb7b6fd7fa81f2e923e1d3bd5950ec9762` | MIT default. Copyright Evert "Diamond" Prants. See `mods/fluid_lib/LICENSE`, README, and the inherited-code/media exceptions below. |
| [Storage Drawers](https://github.com/minetest-mods/drawers), `5c8aa86f481852cc59b678023193135d5ab9963d` | MIT code and most media; CC0 translations; CC-BY-3.0 sounds. Copyright and per-file credits in `mods/drawers/LICENSE.txt`, including Linus Jahn, Mango Tango, Justin Aquadro, Pandorabox, and AbbyRead. |
| [fakelib](https://github.com/OgelGames/fakelib), `562dc359f00227daf0ee56dbba9c36a240c59d4c` | MIT. Copyright 2024 OgelGames. See `mods/fakelib/LICENSE`. |
| [xcompat](https://github.com/mt-mods/xcompat), `758684dac8875d06d8c1565e323ee52c9d4daf7f` | MIT. Copyright 2021–2025 wsor4035, mt-mods and contributors. See `mods/xcompat/LICENSE`. |

All `mods/...` paths in this document are beneath
`games/golden_era_playtest/`.

## Mineclonia media and model sources

Mineclonia's `LEGAL.md` attributes its default textures to Pixel Perfection by
XSSheep and Pixel Perfection Legacy by Nova Wostra under CC-BY-SA-4.0. It also
credits MysticTempest for glazed terracotta, Aeonix_Aeon for specified armor trim
models under CC-BY-4.0, menu images under CC0, and other media generally under
CC-BY-SA-3.0 unless a local notice says otherwise. Its mod directories contain
additional author and file-specific notices. Preserve those attributions and
the applicable share-alike terms when modifying media.

`mods/ENTITIES/mobs_mc/LICENSE-media.md` credits 22i's models under GPLv3 and
links the [Blender source project](https://github.com/22i/minecraft-voxel-blender-models).
This package includes that project's source archive, pinned to
`51527b4b5bceeb7a6de7e1f89edcccc87d904662`, at
`source/upstream/22i-model-sources.zip`. The adjacent provenance JSON records
the download URL, commit, size, and SHA-256. The archive contains 222 Blender
files and its original GPLv3 license.

This is a supplement to the models shipped in Mineclonia. Exact correspondence
between every exported B3D, these Blender files, and any later downstream
modifications has not been established. Both the shipped model files and the
available authoring sources are provided; the supplement must not be described
as a verified reconstruction of all downstream exports.

## Elepower borrowed-code exception

Elepower's top-level MIT license is not the only notice relevant to its files.
`mods/elepower/elepower_mining/miner.lua`, immediately before
`PROBABILITY_FACTOR`, explicitly credits code borrowed from **gravelsieve by
Joachim Stolberg**, licensed under **LGPL-2.1-or-later**:

<https://github.com/joe7575/techpack/tree/master/gravelsieve>

That attribution remains in the shipped Lua file. Retain it and the LGPL terms
for the borrowed portion. The full LGPL-2.1 text is supplied in
`licenses/LGPL-2.1.txt`. Do not describe this portion as exclusively MIT.

## Fluid API inherited-code and image exceptions

The fluid_lib README explicitly identifies assets and code snippets from
Minetest Game and VoxeLibre in `bucket_compat`:

- [Pinned fluid_lib README](https://github.com/LunaSquee/fluid_lib/blob/9b52f6eb7b6fd7fa81f2e923e1d3bd5950ec9762/README.md)
- [VoxeLibre bucket module](https://github.com/VoxeLibre/VoxeLibre/tree/master/mods/ITEMS/mcl_buckets)
- [Minetest Game bucket module](https://github.com/luanti-org/minetest_game/tree/master/mods/bucket)

`mods/fluid_lib/bucket_compat/init.lua` identifies functions copied from
VoxeLibre's `mcl_buckets`. The bucket-module notices credit **Kahrl** and
**celeron55 / Perttu Ahola**, copyright 2011–2012. VoxeLibre and the bundled
Mineclonia bucket README specify GNU Lesser GPL version 2 or later and link
the LGPL-2.1 text; the Minetest Game bucket notice identifies LGPL-2.1-or-later
code and CC-BY-SA-3.0 textures by ElementW. Preserve these inherited notices
alongside fluid_lib's own MIT notice. The corresponding Mineclonia bucket
README is included at `mods/ITEMS/mcl_buckets/README.md`.

The shipped image
`mods/fluid_lib/bucket_compat/textures/mcl_buckets_bucket_compat.png` is
byte-identical to the pinned Mineclonia image
`mods/ITEMS/mcl_buckets/textures/bucket.png`:

```text
SHA-256: 93410c2e34bd63112858f2c394429f85be64e8476785d56573e95e5186d643fa
```

Preserve Mineclonia's media attributions and applicable share-alike terms for
this inherited image. It is not relicensed as MIT by this package. The two mask
images remain accompanied by fluid_lib's original license and inherited-assets
notice; this summary does not claim that a checksum match was established for
those masks.

## Storage Drawers sounds

`drawers_interact.1.ogg` through `drawers_interact.4.ogg` are credited to
**ultradust**, copyright 2012, under **CC-BY-3.0**, with edits by
**tacotexmex and AbbyRead**. The full per-file attribution is preserved in
`mods/drawers/LICENSE.txt` and identifies the creator at
<https://www.freesound.org/people/ultradust/>. Drawers' MIT declaration for its
other files does not replace these sound-license terms.

## Golden Era changes and the engine

The project-authored `era_playtest` mod, compatibility changes, launchers, and
packaging source are GPL-3.0-or-later. Upstream code and media retain their
individual terms. Compatibility changes are identified in the game source
manifest and their editable implementation is included in `source/project/`.

This game pack does not redistribute a Luanti executable or system DLLs.
Launchers use an installed engine or retrieve an official engine distribution
as described in the launch instructions. Any separately downloaded engine
retains its own licenses and bundled dependency notices. The game's source pin
records the development engine revision; it does not relicense that engine.

All components retain their applicable warranty disclaimers. Nothing in this
summary restricts the copying, modification, source access, or redistribution
rights granted by their licenses.
