# Fidelity matrix — Revelation 3.7.0

The user selected FTB Revelation 3.7.0 (Minecraft 1.12.2) on 2026-10-18.
Implementation reliability and fidelity to this reference are separate criteria.
The [reference lock](../references/revelation-3.7.0.lock.json) supplies exact builds;
[the roadmap](roadmap.md) defines the staged native implementation pathway.

| Area | Current implementation | Reference evidence / remaining gap |
| --- | --- | --- |
| Reference inputs | 1000-entry file inventory; 675 configs + four scripts cached | all selected files hash-verified; resolved runtime recipe registry not exported |
| Foundation | Mineclonia plus six custom mods | functional engine slice; survival/terrain differ from Minecraft 1.12.2 |
| RF production | native coal/charcoal and water credits; full-buffer minimum loss; preserved legacy profile | TE5 config has Steam Dynamo base 40 RF/t; native basic coal/charcoal/water model and rates implemented; startup/side/augment parity pending |
| RF transfer/storage | six-face components, buffers, consumer budget | native capacities and buffer limits sourced; shared graph allocation is provisional; legacy lifecycle tested |
| Pulverizer | ore/raw iron -> dust | TE5 config base 20 RF/t and default ore multiplier 2; 4000 RF primary processing implemented; persisted 10% nickel byproduct implemented; effective groups unresolved |
| Powered furnace | dust -> ingot | TE5 config base 20 RF/t; 1500 RF dust smelting and buffer-dependent rates implemented; effective registry parity pending |
| Item transport | configured processor faces, separate primary/byproduct output and directional ejector | protected-transfer checks; normal item-side tables sourced; ducts, filters, RF side controls and broader storage unsupported |
| Save/restart | RF/work/burn/profile/water/credits/jobs/inventories | restarts, changed recipe settings, eviction and invalid-state pause/repair tested; schema-1 -> 2 legacy preservation and explicit upgrade tested; forced-crash atomicity unresolved |
| Player interaction | formspec, recipes and protected callbacks | engine verifies new crafting and denial of old shortcuts; three graphical machine forms inspected; actual player crafting/dragging/multiplayer untested |
| Progression | fifteen native material/component/machine/cell patterns | exact class/config/script evidence; explicit native representatives; tin/silver survival acquisition and effective full registry unresolved |
| Upgrades/redstone | absent | reference config confirms upgrades enabled; detailed behavior not implemented |
| Tinkers' Construct 2 | absent | exact 2.13.0.183 build pinned; native smeltery/tools are a future branch |
| AE2 rv6 | absent | exact rv6-stable-7 build pinned; storage/autocrafting are a future branch |
| Thaumcraft 6 | absent | exact 6.1.BETA26 build pinned; knowledge/research/casting/infusion are a future branch |
| Other pack systems | absent | full inventory available; first-release coverage priorities not yet assigned |
| Media | four original placeholders, no custom audio | inherited media audit and independently authored final media outstanding |

The [initial sourced specification and supported import](thermal-factory-spec.md)
are recorded. The basic resource model and known-state migration are implemented. Next resolve
secondary outputs, sides/transport and survival acquisition, then perform graphical
survival/multiplayer validation.
Grow performance, migration and crash-recovery checks around those concrete
systems. Never infer full-mod compatibility or runtime fidelity from config
extraction alone.
