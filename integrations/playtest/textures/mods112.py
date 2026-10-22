# SPDX-License-Identifier: GPL-3.0-or-later
"""Golden Era mod textures and the Revelation-era 1.12 mod textures that stand in for them.

Each entry maps a Golden Era texture file to a path under assets/ in a 1.12
mod resource pack. Names only; the tester supplies the packs. Elepower draws a
small transparent symbol over a plain machine side, while Thermal faces are
whole opaque images, so a Thermal face simply covers the side beneath it.
Textures Golden Era tints in code (dusts, gears, plates) cannot be replaced
per material and are left out.
"""

TE = "thermalexpansion/textures/blocks/"
TF = "thermalfoundation/textures/"
SD = "storagedrawers/textures/"

ELEPOWER = {
    # Machine casing shared by every Elepower machine.
    "elepower_machine_side.png": TE + "machine/machine_side.png",
    "elepower_machine_top.png": TE + "machine/machine_top.png",
    "elepower_machine_base.png": TE + "machine/machine_bottom.png",
    "elepower_grinder_side.png": TE + "machine/machine_side.png",
    "elepower_grinder_top.png": TE + "machine/machine_top.png",
    # Machine fronts with their closest Thermal Expansion counterpart.
    "elepower_furnace.png": TE + "machine/machine_face_furnace.png",
    "elepower_furnace_active.png": TE + "machine/machine_active_furnace.png",
    "elepower_grinder.png": TE + "machine/machine_face_pulverizer.png",
    "elepower_grinder_active.png": TE + "machine/machine_active_pulverizer.png",
    "elepower_alloy_furnace.png": TE + "machine/machine_face_smelter.png",
    "elepower_alloy_furnace_active.png": TE + "machine/machine_active_smelter.png",
    "elepower_sawmill.png": TE + "machine/machine_face_sawmill.png",
    "elepower_compressor.png": TE + "machine/machine_face_compactor.png",
    "elepower_canning_machine.png": TE + "machine/machine_face_transposer.png",
    "elepower_electrolyzer.png": TE + "machine/machine_face_centrifuge.png",
    "elepower_pcb_plant.png": TE + "machine/machine_face_crafter.png",
    "elepower_pcb_plant_active.png": TE + "machine/machine_active_crafter.png",
    # Power cells and their tier overlays match Thermal energy cells.
    "elepower_power_cell.png": TE + "storage/cell_side_0.png",
    "elepower_overlay_hardened.png": TE + "machine/machine_overlay_1.png",
    "elepower_overlay_reinforced.png": TE + "machine/machine_overlay_2.png",
    "elepower_overlay_resonant.png": TE + "machine/machine_overlay_3.png",
    "elepower_overlay_super.png": TE + "machine/machine_overlay_4.png",
    # Farming machines use Thermal's smaller device casing.
    "elefarming_machine_side.png": TE + "device/device_side.png",
    "elefarming_machine_top.png": TE + "device/device_top.png",
    "elefarming_machine_base.png": TE + "device/device_bottom.png",
    "elefarming_machine_planter.png": TE + "machine/machine_face_insolator.png",
    "elefarming_machine_tree_extractor.png": TE + "device/device_face_tapper.png",
    "elepower_silver_coil.png": TF + "items/material/power_coil_silver.png",
}
for metal in ["lead", "nickel", "silver", "tin", "bronze", "invar", "electrum", "steel"]:
    ELEPOWER["elepower_%s_ingot.png" % metal] = TF + "items/material/ingot_%s.png" % metal
for metal in ["lead", "nickel", "silver", "tin", "bronze", "invar", "steel"]:
    ELEPOWER["elepower_%s_block.png" % metal] = TF + "blocks/storage/block_%s.png" % metal
for metal in ["lead", "nickel", "silver", "tin"]:
    ELEPOWER["elepower_mineral_%s.png" % metal] = TF + "blocks/ore/ore_%s.png" % metal
for tool, thermal in [("pick", "pickaxe"), ("axe", "axe"), ("shovel", "shovel"), ("sword", "sword")]:
    ELEPOWER["elepower_tool_lead%s.png" % tool] = TF + "items/tool/%s_lead.png" % thermal

DRAWERS = {"drawers_controller_front.png": SD + "blocks/drawers_controller_front.png"}
# Golden Era drawer woods and the Storage Drawers wood drawn for each.
for ours, theirs in [("wood", "oak"), ("oak_wood", "oak"), ("acacia_wood", "acacia"),
                     ("acacia_wood_mcl", "acacia"), ("birch_wood", "birch"), ("dark_oak_wood", "big_oak"),
                     ("junglewood", "jungle"), ("junglewood_mcl", "jungle"), ("spruce_wood", "spruce")]:
    DRAWERS["drawers_%s.png" % ours] = SD + "blocks/drawers_%s_side.png" % theirs
    for size in ("1", "2", "4"):
        DRAWERS["drawers_%s_front_%s.png" % (ours, size)] = SD + "blocks/drawers_%s_front_%s.png" % (theirs, size)
DRAWERS["drawers_trim.png"] = SD + "blocks/drawers_oak_trim.png"
for upgrade in ["diamond", "emerald", "gold", "iron", "obsidian", "template"]:
    DRAWERS["drawers_upgrade_%s.png" % upgrade] = SD + "items/upgrade_%s.png" % upgrade

MAPPINGS = {**ELEPOWER, **DRAWERS}
