# SPDX-License-Identifier: GPL-3.0-or-later
"""Golden Era mod textures and the Revelation-era 1.12 mod textures that stand in for them.

Each entry maps a Golden Era texture file to a path under assets/ in a 1.12
mod resource pack. Names only; the tester supplies the packs. Elepower draws a
small transparent symbol over a plain machine side, while Thermal faces are
whole opaque images, so a Thermal face simply covers the side beneath it.
Textures Golden Era tints in code (dusts, gears, plates) cannot be replaced
per material and are left out. A tuple layers its sources in order: Refined
Storage draws a block's glowing screen as a separate cutout over a dark base.
"""

TE = "thermalexpansion/textures/blocks/"
TF = "thermalfoundation/textures/"
SD = "storagedrawers/textures/"
RS = "refinedstorage/textures/"
TC = "thaumcraft/textures/"

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

# Logistica's network blocks and the Refined Storage block that does the same
# job. Nodebox parts (cables, injectors, wireless) have no full-block match.
LOGISTICA = {
    "logistica_network_controller_front_anim.png": (RS + "blocks/controller/controller.png",
                                                    RS + "blocks/controller/cutouts/on.png"),
    "logistica_network_controller_front_off.png": RS + "blocks/controller/controller_off.png",
    "logistica_network_controller_side.png": RS + "blocks/controller/controller.png",
    "logistica_network_controller_top.png": RS + "blocks/controller/controller.png",
    # The access point is Logistica's terminal, like the Refined Storage grid.
    "logistica_access_point_front.png": (RS + "blocks/grid/front.png", RS + "blocks/grid/cutouts/front_connected.png"),
    "logistica_access_point_back.png": RS + "blocks/grid/back.png",
    "logistica_access_point_side.png": RS + "blocks/grid/right.png",
    "logistica_access_point_top.png": RS + "blocks/grid/top.png",
    "logistica_access_point_bottom.png": RS + "blocks/bottom.png",
    "logistica_basic_mass_storage_front.png": RS + "blocks/disk_drive.png",
    "logistica_basic_mass_storage.png": RS + "blocks/disk_drive_side.png",
    "logistica_basic_mass_storage_top.png": RS + "blocks/disk_drive_top.png",
    "logistica_autocrafter.png": (RS + "blocks/crafter/front.png", RS + "blocks/crafter/cutouts/front_connected.png"),
    "logistica_crafting_supplier_side.png": (RS + "blocks/crafter/side.png",
                                             RS + "blocks/crafter/cutouts/side_connected.png"),
    "logistica_crafting_supplier_top.png": (RS + "blocks/crafter/front.png",
                                            RS + "blocks/crafter/cutouts/front_connected.png"),
    "logistica_crafting_supplier_bottom.png": RS + "blocks/crafter/bottom.png",
    "logistica_item_monitor_front.png": RS + "blocks/storage_monitor_front.png",
    "logistica_item_monitor_back.png": RS + "blocks/storage_monitor_back.png",
    "logistica_item_monitor_side.png": RS + "blocks/storage_monitor_right.png",
    "logistica_item_monitor_top.png": RS + "blocks/storage_monitor_top.png",
    "logistica_wap.png": RS + "items/wireless_grid_connected.png",
}

# Magicalities and the Thaumcraft 6 counterpart of each table, item and symbol.
MAGICALITIES = {
    "magicalities_table_arcane.png": TC + "blocks/arcane_workbench_side.png",
    "magicalities_table_arcane_top.png": TC + "blocks/arcane_workbench_top.png",
    "magicalities_table_wood.png": TC + "blocks/table_wood_side.png",
    "magicalities_table_wood_top.png": TC + "blocks/table_wood_top.png",
    "magicalities_cauldron.png": TC + "blocks/crucible_side.png",
    # Crystals are tinted per element in code, so the pale Thaumcraft crystal suits them.
    "magicalities_crystal.png": TC + "blocks/crystal.png",
    "magicalities_crystal_shard.png": TC + "items/crystal_essence.png",
    "magicalities_book.png": TC + "items/thaumonomicon.png",
    "magicalities_quill.png": TC + "items/scribing_tools.png",
    "magicalities_tellium_ingot.png": TC + "items/ingot_thaumium.png",
}
for tool, thaumium in [("axe", "axe"), ("pick", "pick"), ("shovel", "shovel"), ("sword", "sword")]:
    for rage in ("", "_rage"):
        MAGICALITIES["magicalities_tellium_%s%s.png" % (tool, rage)] = TC + "items/thaumium_%s.png" % thaumium
for element, aspect in [("air", "aer"), ("water", "aqua"), ("fire", "ignis"), ("earth", "terra"),
                        ("light", "lux"), ("dark", "tenebrae")]:
    MAGICALITIES["magicalities_symbol_%s.png" % element] = TC + "aspects/%s.png" % aspect

MAPPINGS = {**ELEPOWER, **DRAWERS, **LOGISTICA, **MAGICALITIES}
