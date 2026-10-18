# Historical reference

Target: the initial late-2014 FTB Direwolf20 pack for Minecraft Java 1.7.10.
The primary [release announcement](https://forum.feed-the-beast.com/threads/direwolf20-1-7-10-released.53915/)
by slowpoke is dated **October 31, 2014** (checked October 18, 2026). It establishes
the pack's release and Minecraft line. It does not provide an authenticated
launch manifest, complete configs, or exact machine defaults.

No launch manifest/config snapshot has been recovered and pinned. Thermal
Expansion 4 is the intended behavioral reference, with exact build unresolved.
Exact reference builds for Tinkers' Construct, Applied Energistics 2, Ender IO,
BuildCraft, IndustrialCraft 2, Thaumcraft 4, Botania, Forestry, Twilight Forest,
Blood Magic and Witchery are also unresolved. Their presence here is a target
list from the handoff, not an authenticated launch mod list.

## Current engineering values — all provisional

| Setting | Default | Unit |
| --- | ---: | --- |
| `era_generator_rate` | 20 | RF/tick |
| `era_coal_ticks` | 1600 | ticks/coal |
| `era_cable_rate` | 80 | RF/donor-buffer pair/tick |
| `era_machine_input` | 40 | RF/processor/tick across donors |
| `era_pulverizer_cost` | 4000 | RF/input |
| `era_furnace_cost` | 2000 | RF/dust |
| `era_process_rate` | 40 | maximum RF/job/tick |
| `era_ore_multiplier` | 2 | dust/input |

A tick means the project's 20-Hz simulation tick. Positive integer settings
override `mods/era_thermal/rates.lua`. Capacities are currently hard-coded:
32000 RF generator, 100000 RF buffer, 8000 RF processor. All capacities and
crafting patterns are provisional too. Changing values may invalidate the
fixture's deliberately fixed expected totals.

The dynamo currently burns coal without water. Secondary outputs, augments,
side configuration, redstone control, authentic progression, visuals and sound
are absent. Modern Mineclonia terrain/survival cannot establish 1.7.10 fidelity.

## Evidence needed before replacing defaults

Recover a first-release pack manifest and config tree from a primary archive,
record its pack version/date, original URL and content hash, and distinguish
pack overrides from the matching mod's defaults. Record exact mod versions and
trace each mechanic to permitted source/config/documentation for that version.
Do not import proprietary jars, code or media into this repository to obtain
fidelity. Add behavior tests alongside each sourced change.
