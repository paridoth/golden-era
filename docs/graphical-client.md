# Local graphical client and factory inspection

The optional graphical Luanti 5.17.0 client now builds inside the repository.
It uses the same pinned engine source, bundled Lua 5.1 and assembled Mineclonia
foundation as the server. No system packages are installed and upstream source
is not patched. Audio and network content downloads are disabled in this build.

```sh
./scripts/setup.sh
python3 scripts/build-client.py
python3 scripts/play-demo.py
# For ordinary local play:
./scripts/run-client.sh
```

`build-client.py` verifies the Luanti/Mineclonia revisions and clean tracked
sources. Six JPEG/PNG/FreeType development/runtime packages have exact versions
and SHA-256 in `client-build-deps.lock.json`; they extract into `tools/client-root`,
separate from the server's `tools/root`. Apt downloads require those exact
versions to remain available. The script handles workspace spaces and selects
shared image/font libraries explicitly.

This is a tested local bootstrap, not a hermetic graphics toolchain. It also
uses this host's existing compiler, SDL2/OpenGL/X11 development stack. Observed
versions: SDL2 dev 2.30.0+dfsg-1ubuntu3.1, GL/GLX dev 1.7.0-1build1,
X11 dev 2:1.8.7-1ubuntu0.1, Xcursor dev 1:1.2.1-1build1,
Xi dev 2:1.8.1-1build1, Xinerama dev 2:1.1.4-3build1 and
Xrandr dev 2:1.5.2-2build1. The graphical run used X11 and NVIDIA OpenGL
4.6.0, driver 595.99.02. Other graphics systems and a fresh-machine client
bootstrap remain untested. The normal headless setup/CI path is unchanged.

## Isolated demo

`play-demo.py` launches a dedicated single-node inspection world under
`runtime/worlds/graphical-demo`, using player GoldenEraQA and loopback port
30198. It does not load or modify `runtime/worlds/play`. The QA mod is installed
only in that demo world's `worldmods`; it is not part of the normal game.
A stone platform and first-factory fixture initialize once. The factory starts
with one coal, one water bucket and two raw iron, with the furnace's west face
configured for input. It should deposit four iron ingots in its ordinary chest.

- Right-click machines to use their native forms.
- `/factory_refill` supplies another batch without resetting RF/jobs/inventories.
- `/factory_form generator` (or pulverizer/furnace/buffer) opens an inspection form.
- `python3 scripts/play-demo.py --form generator` opens that form on join.
- `--cycle` renders all four forms in sequence for visual inspection.

Normal GUI quit shuts down this local game. Stop any server using the same
world before opening it through another process. To inspect a fresh survival
world, use the ordinary client/play world, which retains v7 terrain and survival
settings; the QA platform is creative and does not establish a gathering playthrough.

## Executed visual checks and remaining input

The client built and joined the QA world. Three machine forms (Pulverizer, Dynamo and furnace) were captured and
inspected. The cell form was delivered, but its window capture was occluded and
discarded; cell visual inspection remains pending. The first render exposed invisible empty slots, crowded labels/side
buttons and a player list showing only 27 of 36 slots. The revised forms draw
original code-based slot backgrounds, show all inventory rows and hotbar, separate
face names from modes, and show only each machine's relevant slots. The basic
cell has no misleading processing/fuel slots. Labels match the foundation's light
form skin. No new bitmap assets were introduced.

Idle cached forms now refresh through the real load-block modifier at mapblock
activation; the actual eviction/reactivation engine phase checks that update.
The inspection command refreshes before showing a form. These renders verify
layout, client startup and form delivery, not real mouse actions or crafting.

Screenshots in `docs/evidence/2026-10-18/graphical-*.png` show the open-source
Mineclonia foundation and our native form. Inherited game textures retain their
upstream licenses/credits described in [licenses](licenses.md); these evidence
images are not new game assets. Manual placement, inventory drags, craft actions,
full survival gathering, multiplayer contention, audio and v7 gameplay still need
hands-on validation. Filled machines still require a tested relocation/drain path.
