# Licensing and asset provenance

## Original project material

Original custom code, scripts, configuration and newly authored documentation
are offered under **GPL-3.0-or-later**, matching the existing custom Lua SPDX
headers and the license intent recorded in the migration handoff. The full GPLv3
text is in root `LICENSE`; this scope statement allows version 3 or later.
Preserved upstream text, third-party legal notices and historic evidence retain
their existing terms.

The four original procedural 16x16 placeholder PNGs are dedicated under
**CC0-1.0**. Their exact filenames/hashes and origin are in
`mods/era_core/textures/NOTICE.md`, with full text in `LICENSES/CC0-1.0.txt`.
The handoff records independent flat-color/border generation without external
pixels; the generation script was not included. No custom audio exists.
These notices formalize the handoff's recorded intent without claiming a named
human created those pixels or reproducing protected mod content.

## Inherited projects (summary, not a complete media audit)

| Project | Observed declared terms | Primary local notices |
| --- | --- | --- |
| Luanti | engine LGPL-2.1-or-later; bundled libraries/media have exceptions | `upstream/luanti/README.md`, `LICENSE.txt`, `lib/` notices |
| Mineclonia | GPL-3.0-or-later code with local dual-license options | `upstream/mineclonia/LEGAL.md`, `LICENSE.txt`, mod-local notices |
| Technic | LGPL-2.0-or-later default; file/submod exceptions | `upstream/technic/README.md`, mod-local notices |
| Pipeworks | LGPL-3.0 code, CC-BY-SA-4.0 media | `upstream/pipeworks/LICENSE` |
| Mesecons | LGPL-3.0 code, CC-BY-SA-3.0 non-code | `upstream/mesecons/LICENSE.txt`, `COPYING.txt` |
| Elepower | MIT project license; retain local notices/assets | `upstream/elepower/LICENSE`, mod-local notices |
| fluid_lib | MIT project license; retain submod notices | `upstream/fluid_lib/LICENSE`, submod notices |
| Storage Drawers | MIT code/textures, CC-BY-3.0 sound files, CC0 translations | `upstream/drawers/LICENSE.txt` with per-file authors |
| Logistica (trial) | LGPL-2.1 code, CC-BY-SA-3.0 media (ContentDB) | `upstream/logistica/LICENSE` |
| Extra Structures (trial) | GPL-3.0-or-later code and media (ContentDB) | `upstream/mcl_extra_structures/LICENSE.md`, `CREDITS.md` |
| Travelnet (trial) | GPL-3.0 code, CC0 models/textures by VanessaE (README) | `upstream/travelnet/LICENSE`, `README.md` |
| Magicalities (trial) | MIT code and media declared on ContentDB by IcyDiamond (evert); the repository has no license file | none upstream; a packaged release must add the MIT text and attribution |

Mineclonia's LEGAL.md attributes Pixel Perfection textures to XSSheep and Pixel
Perfection Legacy to Nova Wostra (CC-BY-SA-4.0), glazed terracotta to
MysticTempest, menu images under CC0, specified armor-trim models to
Aeonix_Aeon (CC-BY-4.0), and other media generally under CC-BY-SA-3.0 unless
locally noted. Preserve all local attribution rather than replacing it with
this summary. Technic includes additional named authors and CC/CC0/WTFPL
exceptions. Extra fallback checkouts and cached Debian packages also retain
their own notices; they have not had a complete redistribution audit.

Setup keeps upstream source trees intact. Game-root README, LEGAL, LICENSE,
CREDITS, configuration and menu files are copied into the assembled runtime;
mod directories are symlinked. The root project license does not relicense
those upstream files or media. Upstream directories and runtime are not stored
in project Git; their source URLs/revisions are locked separately.

The existing-mod playtest retains the full Elepower/fluid_lib/Mesecons trees and
notices in its assembled copies. Checked compatibility edits are tracked under
`integrations/playtest/`; unchanged upstream mods remain linked with their own
notices. The playtest adds no new bitmap/audio assets and incorporates no original
Minecraft modpack media. The inherited file-by-file release audit remains separate.

## Distribution status and next audit

The 0.1.0 tester game pack now has a concrete distribution inventory: every
packaged file has a source/provenance record, SHA-256 and retained notice
references. The package retains upstream notices, adds full license texts and
identifies inherited Elepower/fluid_lib exceptions instead of labeling their
entire trees MIT. It includes the pinned 22i Blender source archive linked by
Mineclonia's model license. Exact correspondence to every downstream B3D/export
modification remains unverified and is stated in the package notices.
Engine binaries and DLLs are excluded; the Windows launcher fetches the official
hash-pinned engine separately. See [the release guide](itch-release.md).

No proprietary Minecraft/mod code, textures, sounds, models or jars were
incorporated into the custom slice according to the handoff and inspected
project inventory. The migration archive is a development handoff retaining
upstream notices. It is not a public release package.

The package inventory preserves file/mod-specific attributions and documents
the source limits above. Future binary bundles need their own engine/dependency
source and notice work. Cached Debian packages and development tools are excluded
from this game-pack distribution.

## Revelation reference cache

The 2026-10-18 reference acquisition keeps original FTB Revelation config/script
bytes and their existing headers under ignored `references/cache/`. The project
tracks the reviewed file inventory, hashes, factual configuration values and
our own inspection code/documentation. No downloaded pack scripts, JARs or
media are installed into the Luanti runtime or included in project Git. The
project's GPL/CC0 notices do not relicense third-party reference files. Any later
asset reuse or distribution remains subject to a separate provenance review.


The native crafting catalog reuses the existing project-authored placeholder
image; it adds no downloaded textures or sounds. The ignored MCP stable mapping
ZIP is used only to resolve source field names. Its URL/hash and factual selected
name mappings are recorded in the crafting review; the original ZIP is neither
relicensed nor bundled into the native game.
