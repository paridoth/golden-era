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

## Distribution status and next audit

No proprietary Minecraft/mod code, textures, sounds, models or jars were
incorporated into the custom slice according to the handoff and inspected
project inventory. The migration archive is a development handoff retaining
upstream notices. It is not a public release package.

A file-by-file inventory of inherited media, exceptions, authors and required
notices remains incomplete. Before preparing public binaries/game bundles,
record every shipped file's source/revision/license/attribution, retain
corresponding source and license texts as applicable, audit bundled libraries
and Debian-package contents, and review the final assembled distribution.
No claim of completed redistribution clearance is made here.
