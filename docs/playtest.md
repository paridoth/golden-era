# Existing-mod Golden Era playtest

The user redirected development on 2026-10-18 toward getting something playable
quickly from existing Luanti mods and forks, then testing through ordinary play.
This pack uses Revelation-style equivalents with their stock mechanics. The
earlier custom Thermal implementation remains a separate prototype and source
of reference findings; it does not dictate this pack's power or progression.

## Start playing

```sh
python3 scripts/play-playtest.py
```

The launcher assembles the pinned mods and opens the existing local graphical
client. It creates a persistent world at
`runtime/playtest/worlds/revelation-playtest`, with normal v7 survival terrain,
survival inventory quantities and damage disabled. Close the game normally to
save. Relaunch with the same command to continue. No system packages are installed.
The developer launcher creates its configuration once; later launches keep your
changes to `runtime/playtest/playtest.conf`.

New players choose once between a supplied workshop and a survival start at the
natural spawn. Survival grants no workshop tools or materials; the stock Elepower
mod still supplies its help book. The workshop choice grants the existing diamond
tools and torches and enables experiment privileges in single-player. Server
guests keep their configured privileges. Neither choice clears an
inventory. Existing 0.1.0 players keep their position, inventory and workshop.
`/startchoice` reopens an unfinished choice.
Workshop preparation shows a nonblocking status message. You can continue exploring
until automatic arrival, or use `/cancelworkshop` to stay where you are. Unfinished
trips resume after reconnecting without another starter kit. See
[workshop loading](workshop-loading.md) for cancellation and retry behavior.

Packaged launchers open the Luanti main menu with Golden Era selected and the
ready-made `playtest` world listed. Tick Host Server to play with others on a
home network; they use Join Game with the host's local address and port 30000.
Server players receive flight and fast movement by default. E opens and closes
the inventory and closes other game screens; hold Left Ctrl to sprint. Older
settings files are upgraded once: the local-only `bind_address` and port 30200
are removed, and tester choices are kept. `start.sh --server` (or `start.bat
--go`) still uses the playtest world directly.

The optional supplied workshop above the terrain contains a
coal-fired generator, power cell, Pulverizer, powered furnace, tubes, filter
injectors and blinking controls. Coal and two raw iron start the first batch.
The blinking controls pulse the injectors to move dust into the furnace and
ingots into the output barrel. Right-click machines to inspect them. The front
left barrel contains parts and materials to expand or rebuild the factory.
A crafting table, alloy furnaces, a drawer and a fluid tank are also available.
The extra alloy furnaces are ready for the player to wire into power.
Fresh 0.1.5 workshops also include a planter, harvester, seeds, eight soil blocks,
bone meal, one wheat item for filter setup and two spare blinking controls in the
supplies barrel. The Farming guide page explains a small seed-return wheat line. Existing workshop barrels are not
refilled on update; craft the parts or use the single-player workshop's creative
catalog while retaining the same world.
The first batch takes roughly two minutes with the supplied stock generator.

- `/manual` (or `/factoryguide`) opens the Golden Era Manual: progression, power, automation,
  farming, trees, Logistica storage, Travelnet, extra structures and Magicalities magic.
- `/packhelp` shows workshop instructions.
- `/packversion` prints the running pack version, build identity and engine version
  for a bug report. Development assemblies say when local source changes exist.
- `/factoryguide` explains unpowered grinding/alloying, electronics, first power,
  item routing, a small wheat farm and a controlled small-oak harvesting layout.
- `/awards` includes seven native factory crafting milestones. These do not grant free items.
- `/workshop` returns to the workshop without resetting it.
- `/explore` returns to the player's original survival spawn.
- **K** toggles flight; fast movement is available with **J**.
- The **Elepower Tome** explains the existing machines. The inventory's recipe
  guide includes machine recipes as well as ordinary crafting recipes.
- `/gamemode creative` opens the full item catalog for building experiments;
  `/gamemode survival` returns to ordinary item quantities.

Drawers accept items by right-clicking their front and dispense by left-clicking.
Sneak while retrieving to take one item; **E + left-click** toggles the item-type
lock. Connect drawers with trim to a controller for bulk deposits, including
Pipeworks input. Retrieve items from the individual drawer fronts. See the
[storage guide](../integrations/playtest/storage-notes.md) for native recipes,
capacity upgrades and controller behavior.
The workshop starts once per world; later joins preserve the player's position
and all workshop changes. In single-player, the workshop path grants local development privileges for experiments.
The survival path does not add those privileges; single-player/server ownership
may independently grant privileges through Luanti.

## What is included

| Foundation | Gameplay supplied |
| --- | --- |
| Mineclonia 0.124.0 | Survival, terrain, mining, crafting, mobs, exploration, dimensions, enchanting and native redstone |
| Elepower `c37fe7b` | Full upstream industrial content: generation, storage, processing, alloys, farming/mining machinery, powered tools, solar/nuclear and further technology |
| Pipeworks `5dfd572` | Tubes, filters, routing, injectors and autocrafting |
| fluid_lib `9b52f6e` | Fluid buffers, tanks, pumps, ducts and bucket compatibility |
| Storage Drawers `5c8aa86` | Bulk storage, item locks, upgrades and drawer controllers |
| Mesecons `aca87db` | Clocks, controls and logic used by the workshop's existing filter-injectors |

These are available native content, not completed ports of Thermal, AE2,
Tinkers' Construct or Thaumcraft. Exact Revelation balance, custom scripts,
research/magic and missing systems remain future additions driven by play.
Original Minecraft JARs/configs remain inert reference inputs.

## Reproduce and check

```sh
python3 scripts/setup-playtest.py --no-fetch
python3 scripts/play-playtest.py --prepare-only
python3 tests/playtest/run.py
```

The setup command can fetch missing exact source commits when `--no-fetch` is
omitted. Existing dirty/mismatched source checkouts are rejected. It builds the
game at `runtime/playtest/games/golden_era_playtest`, preserving upstream notices
and producing `playtest-sources.json`. The earlier `runtime/games/golden_era`
and its worlds remain separate. The client binds only to loopback port 30200;
the smoke test uses a temporary world on 30202.

Bounded compatibility changes apply only to assembled source copies: xcompat's
game-ID mapping; Elepower's Mineclonia item/metal mappings and recipe-guide hook;
Mesecons' dye table/piston compatibility; fluid insertion remainder fixes; and
Drawers' Mineclonia spill/explosion handling and controller cache invalidation.
Elepower machines also protect their owned inventory slots during mining and
preserve full item stacks through Mineclonia's explosion callback.
Pipeworks autocrafters preserve their owned input/output stacks through native
explosions. New filter previews carry a format marker. Filter-injectors are
temporarily stationary under native and Mesecons pistons; mine and place them,
then configure their selectors to relocate them. Historical unmarked physical
selector refunds remain native; see the
[Pipeworks notes](../integrations/playtest/pipeworks-notes.md) for old-save bounds.
Source checkouts stay clean. Patch helpers reject unexpected source text.
Empty machine item slots before mining, including a reconstructor's tool and a
wireless station's card. See [machine removal](../integrations/playtest/removal-notes.md)
for inventory, upgrade-menu and fluid behavior.

See [the audited survival route](../integrations/playtest/survival-notes.md) for
material acquisition, early machine ordering, recipe reachability and test limits.
The generator can power a processor before the later Power Cell is available.

The headless smoke checks selected crafting, fluid accounting and the actual
stock industrial line using normal timers, power ABMs and tube routing. It is a
quick regression guard for the playable build. Ordinary graphical play remains
the primary way to find the next feature or compatibility issue; it does not
establish that every included upstream machine has been exercised.

## Desktop release and onboarding checks

The active package version is tracked in `packaging/playtest/release.json`.
Windows EXEs and Linux archives are built separately without replacing 0.1.0.
See [sharing instructions](itch-release.md) and [Linux setup](linux-release.md).

`python3 tests/playtest/gui.py --fetch-tools` renders and clicks both start choices
in a repository-local Xvfb desktop, then restarts each world. It checks real player
inventories and saved positions. The helper downloads only the hash-locked GUI
test packages into `tools/`; no system packages or user worlds are changed.
It requires the local graphical client, Pillow with XCB, xauth, X11 and XTest.
The isolated display is :97 and the test port is 30212.

`scripts/ci.sh` now checks the active stock-mod pack as well as the earlier custom
prototype: factory flow, survival material acquisition, autocrafting/drawer restart
and storage conservation/restart checks, plus current Unix launcher save guards.
Graphical checks and Windows bootstrap/Wine
checks remain separate because they need their respective local developer tools.
