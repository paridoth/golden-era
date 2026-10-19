# Pipeworks item ownership and removal compatibility

Pinned sources: Pipeworks `5dfd572eacee4c3c1ed8b827f4a67c46b022b242`,
Mineclonia `20d5bbca48ffbeeb7cc6b008bdcebc9ab595b3d1`, Luanti 5.17.0
`c0e6812b1a4260bb25a1f606f70f55f4962bb97d`. The assembler copies Pipeworks and
applies checked replacements. Upstream sources, recipes and frozen releases stay
unchanged.

## Autocrafter explosions

The pinned autocrafter owns `src` and `dst`; `recipe` and `output` are previews
(`autocrafter.lua:653–684`). Its normal `can_dig` refuses an occupied machine.
Mineclonia's explosion fallback invokes `core.dig_node` for nodes with an
`after_dig_node`, then bulk-deletes them even when `can_dig` refused
(`mods/CORE/mcl_explosions/init.lua:333–366`). A real explosion therefore destroys
an occupied autocrafter, its device item and both physical inventories without
emitting them. An empty autocrafter also emits its device when the explosion's
native `do_drop` decision was false.

The Mineclonia-only copied definition now supplies `on_blast` before native
explosion definitions are cached. It snapshots complete physical ItemStacks from
`src`/`dst`, removes the node, calls the original `after_dig_node` once and emits
the device and owned payloads through `core.add_item`. Native `on_destruct` still
invalidates the recipe cache; the separate after-dig callback still updates tube
connectivity. A no-drop explosion removes the machine without emitting items.
Neither preview list is spilled, and ordinary occupied mining stays refused.

## Modern filter previews and historical owned inventories

Modern filter configuration copies a stack into `main` while returning zero
transferred items (`filter-injector.lua:419–435`). The original item remains owned
by the player; the list is a logical selector. The native one-shot LBM
`pipeworks:give_back_old_filter_items` instead refunds historical physical
inventories to the input container or to world item entities
(`filter-injector.lua:526–592`). It deliberately keeps the converted preview.

The native baseline reproduction moves a configured filter from `(15,200,4)` to
`(16,200,4)` through `mcl_pistons.push`. The destination is loaded but inactive.
Mineclonia restores metadata after constructing the moved node
(`mods/ITEMS/REDSTONE/mcl_pistons/api.lua:149–155`). On the destination's first
activation, the genuine native legacy LBM refunds a modern preview as a real item:
one owned diamond block becomes two, while the preview also remains. A fresh
configured filter constructed directly in an inactive block has the same missing
format distinction.

New filter construction now records a persistent `golden_era_filter_preview`
marker. The existing legacy LBM retains its name, one-shot history and refund
behavior for unmarked nodes, skips marked previews, and marks a conversion only
after its native refund path completes. An absent list can be marked complete.
The captured metadata reference is used after the fallback changes the drop
position's Y coordinate. Editing one slot on an old unclassified filter does not
tag its other slots or infer ownership from names/counts.

**Temporary gameplay restriction in 0.1.4:** all three registered filter-injector
variants are stationary under both Mineclonia pistons (`unmovable_by_piston=1`)
and Mesecons MVPS (`register_mvps_stopper`). This applies to new and existing
filters, including the registered digiline variant. Mine and place a filter again
to relocate it, then configure its selectors. Rotation and normal injection remain
native. The restriction prevents repeated movement of old unclassified selectors
into unactivated legacy blocks; it is not a saved-inventory migration heuristic.

Unmarked modern 0.1.3 previews and genuine historical physical inventories can be
indistinguishable. The patch does not bulk-tag old nodes, delete legitimate
refunds, or claim to recover ownership from the list. An old modern filter already
moved into an inactive block before this repair remains ambiguous on that block's
first activation. Frozen 0.1.3 artifacts retain their original behavior.

## Evidence and boundaries

The initial read-only 0.1.3 audit is retained as
`docs/evidence/2026-10-19/pipeworks-0.1.3-baseline-audit.log` with its exact fixture
beside it. It confirms both defects and verifies normal ghost-only autocrafter and
all filter removal paths do not materialize previews. Deployer, dispenser and
nodebreaker on/off variants preserve their visible owned inventories, count, wear
and metadata under normal mining and actual Mineclonia explosions.

The audit also found a limited defensive gap: a synthetic saved nodebreaker
`main` buffer is omitted from `wielder.lua:191–197`, which spills only `pick`.
Normal actions synchronously eject that internal buffer before returning
(`wielder.lua:64–70`); an ordinary gameplay path leaving it pending was not
established. This repair leaves that separate case unchanged.

Run `python3 tests/pipeworks-removal/test_patch.py` for checked anchors,
repeatability and upstream isolation, and `python3 tests/pipeworks-removal/run.py`
for baseline versus repaired native behavior and process restart. The regression
uses real Mineclonia explosions, both native mover APIs, normal engine block
activation and actual world item entities. Its historical fixture transfers owned
items into an explicitly modeled old saved-list representation; no old mod binary
is executed. Actors use detached inventories, so a human client playthrough or
powered in-game piston construction is not claimed. No production LBM callback is
manually invoked.

The completed baseline/repaired checkpoint and restart run is retained at
`docs/evidence/2026-10-19/pipeworks-0.1.4-smoke.log` (SHA-256
`d61081ba6ff93afd2fccb79dd8392cd8450cec89f0a0cf30a80ece709f86d376`).
All four native processes pass with zero warnings or errors. Restart verification
waits for every requested forceloaded block to become active before inspecting its
item entities; a forceload request alone does not activate entities immediately.
