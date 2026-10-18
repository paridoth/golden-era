# Fidelity matrix

This table tracks implementation against the intended historical experience.
Functional evidence and historical authenticity are separate requirements.

| Area | Implemented | Evidence / gap |
| --- | --- | --- |
| Foundation | Mineclonia plus six custom mods | engine integration; modern survival differs |
| RF production | integer coal generator and pause at capacity | unit + integration; water/fuel behavior provisional |
| RF transfer | six-face connected components, buffers, consumer budget | conservation/connect-disconnect and real cross-block eviction/reactivation tests; no per-edge flow or fairness guarantee |
| Pulverizer | ore/raw iron -> dust | engine fixture; 2x output and RF values provisional; no byproducts |
| Powered furnace | dust -> ingot | manual + automatic scheduler tests; RF/crafting provisional |
| Item transport | fixed +X transfers and ordinary native chest | fixture + protected-transfer denial; no orientation, tubes, filters, locked/double chests |
| Save/restart | RF/work/burn/job/inventory metadata | clean restarts, changed cost/rate/yield, and real mapblock eviction; crash atomicity/migrations untested |
| Player interaction | formspec, recipes, protected inventory callbacks | engine recipe resolution/consumption and selected inventory callbacks tested; player crafting callbacks/UI/multiplayer untested |
| Progression | provisional machine recipes | historical gates/survival playthrough absent |
| Augments/redstone | absent | exact TE build and configs unresolved |
| Tinkers-inspired tools/smeltery | absent | future milestone |
| AE2-inspired storage/autocrafting | absent | future milestone |
| Thaumcraft-inspired scanning/research/infusion | absent | future milestone |
| Other target mods | absent | launch manifest/builds unresolved |
| Media | four procedural 16x16 placeholders, no custom audio | original texture provenance recorded; inherited media audit incomplete |

Before content expansion: pin the launch-era manifest/configs; extend
chunk-lifecycle checks to player travel/broader topologies, actual player
crafting and inventory contention; validate
state schema/corrupt jobs; measure large networks and starvation; define crash
recovery. Replace provisional numbers only with version-specific evidence.
