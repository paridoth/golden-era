# Fidelity matrix — Revelation 3.7.0

The user selected FTB Revelation 3.7.0 (Minecraft 1.12.2) on 2026-10-18.
Implementation reliability and fidelity to this reference are separate criteria.
The [reference lock](../references/revelation-3.7.0.lock.json) supplies exact builds;
[the roadmap](roadmap.md) defines the staged native implementation pathway.

| Area | Current implementation | Reference evidence / remaining gap |
| --- | --- | --- |
| Reference inputs | 1000-entry file inventory; 675 configs + four scripts cached | all selected files hash-verified; resolved runtime recipe registry not exported |
| Foundation | Mineclonia plus six custom mods | functional engine slice; survival/terrain differ from Minecraft 1.12.2 |
| RF production | integer coal generator, pauses at capacity | TE5 config has Steam Dynamo base 40 RF/t; static water/fuel/rate rules now specified; native model provisional |
| RF transfer/storage | six-face components, buffers, consumer budget | real unload/reload and conservation tested; TE Energy Cell config known; actual duct/network rules not mapped |
| Pulverizer | ore/raw iron -> dust | TE5 config base 20 RF/t and default ore multiplier 2; selected recipe costs/byproducts imported; effective groups unresolved |
| Powered furnace | dust -> ingot | TE5 config base 20 RF/t; default dust-smelting and buffer/rate rules specified; native parity pending |
| Item transport | fixed +X moves and ordinary native chest | protected-transfer checks; reference side modes, ducts, filters and broader storage unsupported |
| Save/restart | RF/work/burn/job/inventory metadata | restarts, changed recipe settings, eviction and invalid-state pause/repair tested; migrations/crash atomicity unresolved |
| Player interaction | formspec, recipes and protected callbacks | engine recipe checks; actual player crafting/UI/multiplayer untested |
| Progression | provisional machine recipes | four original pack scripts obtained; three literal crafting records imported; effective registry/groups/NBT unresolved |
| Upgrades/redstone | absent | reference config confirms upgrades enabled; detailed behavior not implemented |
| Tinkers' Construct 2 | absent | exact 2.13.0.183 build pinned; native smeltery/tools are a future branch |
| AE2 rv6 | absent | exact rv6-stable-7 build pinned; storage/autocrafting are a future branch |
| Thaumcraft 6 | absent | exact 6.1.BETA26 build pinned; knowledge/research/casting/infusion are a future branch |
| Other pack systems | absent | full inventory available; first-release coverage priorities not yet assigned |
| Media | four original placeholders, no custom audio | inherited media audit and independently authored final media outstanding |

The [initial sourced specification and supported import](thermal-factory-spec.md)
are recorded. Next resolve remaining first-loop mappings and migrate the native
state model, then perform graphical survival/multiplayer validation.
Grow performance, migration and crash-recovery checks around those concrete
systems. Never infer full-mod compatibility or runtime fidelity from config
extraction alone.
