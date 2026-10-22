# SPDX-License-Identifier: GPL-3.0-or-later
"""Minecraft 1.12 texture names under their 1.13+ names, for Mineclonia's table.

Minecraft 1.13 renamed most textures ("the Flattening"). Mineclonia's
Conversion_Table.csv names 1.20 files, so a 1.12 resource pack is matched by
renaming its files first. This module holds names only, never textures.
"""
import re

COLORS = ["white", "orange", "magenta", "light_blue", "yellow", "lime", "pink", "gray",
          "silver", "cyan", "purple", "blue", "brown", "green", "red", "black"]
WOODS = {"oak": "oak", "spruce": "spruce", "birch": "birch", "jungle": "jungle",
         "acacia": "acacia", "big_oak": "dark_oak", "dark_oak": "dark_oak", "roofed_oak": "dark_oak"}


def color(name):
    return "light_gray" if name == "silver" else name


# Exact block renames that no pattern below covers.
BLOCKS = {
    "anvil_base": "anvil", "anvil_top_damaged_0": "anvil_top", "anvil_top_damaged_1": "chipped_anvil_top",
    "anvil_top_damaged_2": "damaged_anvil_top", "brick": "bricks", "nether_brick": "nether_bricks",
    "red_nether_brick": "red_nether_bricks", "end_bricks": "end_stone_bricks",
    "cobblestone_mossy": "mossy_cobblestone", "stonebrick": "stone_bricks",
    "stonebrick_mossy": "mossy_stone_bricks", "stonebrick_cracked": "cracked_stone_bricks",
    "stonebrick_carved": "chiseled_stone_bricks", "stone_andesite": "andesite",
    "stone_andesite_smooth": "polished_andesite", "stone_diorite": "diorite",
    "stone_diorite_smooth": "polished_diorite", "stone_granite": "granite",
    "stone_granite_smooth": "polished_granite", "stone_slab_top": "smooth_stone",
    "stone_slab_side": "smooth_stone_slab_side", "sandstone_normal": "sandstone",
    "sandstone_carved": "chiseled_sandstone", "sandstone_smooth": "cut_sandstone",
    "red_sandstone_normal": "red_sandstone", "red_sandstone_carved": "chiseled_red_sandstone",
    "red_sandstone_smooth": "cut_red_sandstone", "quartz_block_chiseled": "chiseled_quartz_block",
    "quartz_block_chiseled_top": "chiseled_quartz_block_top", "quartz_block_lines": "quartz_pillar",
    "quartz_block_lines_top": "quartz_pillar_top", "quartz_ore": "nether_quartz_ore",
    "prismarine_rough": "prismarine", "prismarine_dark": "dark_prismarine",
    "hardened_clay": "terracotta", "ice_packed": "packed_ice", "slime": "slime_block",
    "sponge_wet": "wet_sponge", "mob_spawner": "spawner", "web": "cobweb", "reeds": "sugar_cane",
    "waterlily": "lily_pad", "deadbush": "dead_bush", "tallgrass": "short_grass",
    "mushroom_red": "red_mushroom", "mushroom_brown": "brown_mushroom",
    "mushroom_block_skin_red": "red_mushroom_block", "mushroom_block_skin_brown": "brown_mushroom_block",
    "mushroom_block_skin_stem": "mushroom_stem", "mushroom_block_inside": "mushroom_block_inside",
    "grass_top": "grass_block_top", "grass_side": "grass_block_side",
    "grass_side_overlay": "grass_block_side_overlay", "grass_side_snowed": "grass_block_snow",
    "dirt_podzol_top": "podzol_top", "dirt_podzol_side": "podzol_side",
    "grass_path_top": "dirt_path_top", "grass_path_side": "dirt_path_side",
    "farmland_wet": "farmland_moist", "farmland_dry": "farmland",
    "melon_stem_disconnected": "melon_stem", "melon_stem_connected": "attached_melon_stem",
    "pumpkin_stem_disconnected": "pumpkin_stem", "pumpkin_stem_connected": "attached_pumpkin_stem",
    "pumpkin_face_off": "carved_pumpkin", "pumpkin_face_on": "jack_o_lantern",
    "torch_on": "torch", "redstone_torch_on": "redstone_torch",
    "rail_normal": "rail", "rail_normal_turned": "rail_corner", "rail_golden": "powered_rail",
    "rail_golden_powered": "powered_rail_on", "rail_detector": "detector_rail",
    "rail_detector_powered": "detector_rail_on", "rail_activator": "activator_rail",
    "rail_activator_powered": "activator_rail_on", "repeater_off": "repeater",
    "comparator_off": "comparator", "piston_top_normal": "piston_top",
    "dispenser_front_horizontal": "dispenser_front", "dropper_front_horizontal": "dropper_front",
    "furnace_front_off": "furnace_front", "noteblock": "note_block", "portal": "nether_portal",
    "endframe_top": "end_portal_frame_top", "endframe_side": "end_portal_frame_side",
    "endframe_eye": "end_portal_frame_eye", "trip_wire": "tripwire", "trip_wire_source": "tripwire_hook",
    "redstone_lamp_off": "redstone_lamp", "itemframe_background": "item_frame",
    "fire_layer_0": "fire_0", "fire_layer_1": "fire_1", "door_wood_lower": "oak_door_bottom",
    "door_wood_upper": "oak_door_top", "door_iron_lower": "iron_door_bottom",
    "door_iron_upper": "iron_door_top", "trapdoor": "oak_trapdoor", "magma": "magma",
    "flower_dandelion": "dandelion", "flower_rose": "poppy", "flower_blue_orchid": "blue_orchid",
    "flower_allium": "allium", "flower_houstonia": "azure_bluet", "flower_tulip_red": "red_tulip",
    "flower_tulip_orange": "orange_tulip", "flower_tulip_white": "white_tulip",
    "flower_tulip_pink": "pink_tulip", "flower_oxeye_daisy": "oxeye_daisy",
    "double_plant_sunflower_bottom": "sunflower_bottom", "double_plant_sunflower_top": "sunflower_top",
    "double_plant_sunflower_front": "sunflower_front", "double_plant_sunflower_back": "sunflower_back",
    "double_plant_syringa_bottom": "lilac_bottom", "double_plant_syringa_top": "lilac_top",
    "double_plant_grass_bottom": "tall_grass_bottom", "double_plant_grass_top": "tall_grass_top",
    "double_plant_fern_bottom": "large_fern_bottom", "double_plant_fern_top": "large_fern_top",
    "double_plant_rose_bottom": "rose_bush_bottom", "double_plant_rose_top": "rose_bush_top",
    "double_plant_paeonia_bottom": "peony_bottom", "double_plant_paeonia_top": "peony_top",
    "chorus_flower": "chorus_flower", "structure_block": "structure_block",
    "glass_pane_top": "glass_pane_top", "water_flow": "water_flow", "lava_flow": "lava_flow",
}

ITEMS = {
    "apple_golden": "golden_apple", "bucket_empty": "bucket", "bucket_water": "water_bucket",
    "bucket_lava": "lava_bucket", "bucket_milk": "milk_bucket", "fish_cod_raw": "cod",
    "fish_cod_cooked": "cooked_cod", "fish_salmon_raw": "salmon", "fish_salmon_cooked": "cooked_salmon",
    "fish_clownfish_raw": "tropical_fish", "fish_pufferfish_raw": "pufferfish",
    "porkchop_raw": "porkchop", "porkchop_cooked": "cooked_porkchop", "beef_raw": "beef",
    "beef_cooked": "cooked_beef", "chicken_raw": "chicken", "chicken_cooked": "cooked_chicken",
    "mutton_raw": "mutton", "mutton_cooked": "cooked_mutton", "rabbit_raw": "rabbit",
    "rabbit_cooked": "cooked_rabbit", "potato_baked": "baked_potato", "potato_poisonous": "poisonous_potato",
    "melon": "melon_slice", "melon_speckled": "glistering_melon_slice", "seeds_wheat": "wheat_seeds",
    "seeds_pumpkin": "pumpkin_seeds", "seeds_melon": "melon_seeds", "book_normal": "book",
    "book_writable": "writable_book", "book_written": "written_book", "book_enchanted": "enchanted_book",
    "map_empty": "map", "map_filled": "filled_map", "map_filled_markings": "filled_map_markings",
    "fireworks": "firework_rocket", "fireworks_charge": "firework_star",
    "fireworks_charge_overlay": "firework_star_overlay", "potion_bottle_drinkable": "potion",
    "potion_bottle_splash": "splash_potion", "potion_bottle_lingering": "lingering_potion",
    "potion_bottle_empty": "glass_bottle", "reeds": "sugar_cane", "sign": "oak_sign",
    "door_wood": "oak_door", "door_iron": "iron_door", "minecart_normal": "minecart",
    "minecart_chest": "chest_minecart", "minecart_furnace": "furnace_minecart",
    "minecart_hopper": "hopper_minecart", "minecart_tnt": "tnt_minecart",
    "minecart_command_block": "command_block_minecart", "slimeball": "slime_ball",
    "netherbrick": "nether_brick", "spider_eye_fermented": "fermented_spider_eye",
    "fireball": "fire_charge", "carrot_golden": "golden_carrot", "fishing_rod_uncast": "fishing_rod",
    "bow_standby": "bow", "chorus_fruit_popped": "popped_chorus_fruit", "totem": "totem_of_undying",
    "redstone_dust": "redstone", "wooden_armorstand": "armor_stand", "dye_powder_black": "ink_sac",
    "dye_powder_brown": "cocoa_beans", "dye_powder_blue": "lapis_lazuli", "dye_powder_white": "bone_meal",
    "gold_horse_armor": "golden_horse_armor", "boat_oak": "oak_boat", "boat_spruce": "spruce_boat",
    "boat_birch": "birch_boat", "boat_jungle": "jungle_boat", "boat_acacia": "acacia_boat",
    "boat_darkoak": "dark_oak_boat", "seeds_beetroot": "beetroot_seeds",
}

# Only skins whose model layout survived 1.13 are renamed; the 1.12 zombie
# pigman does not fit the later piglin model and is left out.
ENTITIES = {"cow/mooshroom": "cow/red_mooshroom", "boat/boat_oak": "boat/oak",
            "boat/boat_spruce": "boat/spruce", "boat/boat_birch": "boat/birch",
            "boat/boat_jungle": "boat/jungle", "boat/boat_acacia": "boat/acacia",
            "boat/boat_darkoak": "boat/dark_oak", "iron_golem": "iron_golem/iron_golem",
            "snowman": "snow_golem", "squid": "squid/squid", "sign": "signs/oak",
            "sheep/sheep_fur": "sheep/sheep_wool", "llama/llama_brown": "llama/brown",
            "llama/llama_creamy": "llama/creamy", "llama/llama_gray": "llama/gray",
            "llama/llama_white": "llama/white", "endercrystal/endercrystal": "end_crystal/end_crystal",
            "endercrystal/endercrystal_beam": "end_crystal/end_crystal_beam"}

# One 1.12 texture can also stand for later names that reuse its picture.
# BDcraft draws each crop once, grown; earlier stages keep the game's own art.
ALSO = {"blocks/carrots": ["block/carrots_stage3"], "blocks/potatoes": ["block/potatoes_stage3"],
        "blocks/beetroots": ["block/beetroots_stage3"], "items/dye_powder_black": ["item/black_dye"],
        "items/dye_powder_blue": ["item/blue_dye"], "items/dye_powder_brown": ["item/brown_dye"],
        "items/dye_powder_white": ["item/white_dye"], "entity/chicken": ["entity/chicken/temperate_chicken"],
        "entity/cow/cow": ["entity/cow/temperate_cow"], "entity/pig/pig": ["entity/pig/temperate_pig"]}


def block(name):
    if name in BLOCKS:
        return BLOCKS[name]
    match = re.fullmatch(r"(wheat|nether_wart|cocoa)_stage_(\d)", name)
    if match:
        return match.group(1) + "_stage" + match.group(2)
    for pattern, template in [
            (r"wool_colored_(\w+)", "{}_wool"), (r"glass_pane_top_(\w+)", "{}_stained_glass_pane_top"),
            (r"glass_(\w+)", "{}_stained_glass"), (r"hardened_clay_stained_(\w+)", "{}_terracotta"),
            (r"concrete_powder_(\w+)", "{}_concrete_powder"), (r"concrete_(\w+)", "{}_concrete"),
            (r"glazed_terracotta_(\w+)", "{}_glazed_terracotta"), (r"shulker_top_(\w+)", "{}_shulker_box")]:
        match = re.fullmatch(pattern, name)
        if match and match.group(1) in COLORS:
            return template.format(color(match.group(1)))
    for pattern, template in [
            (r"planks_(\w+)", "{}_planks"), (r"log_(\w+)_top", "{}_log_top"), (r"log_(\w+)", "{}_log"),
            (r"leaves_(\w+)", "{}_leaves"), (r"sapling_(\w+)", "{}_sapling"),
            (r"door_(\w+)_lower", "{}_door_bottom"), (r"door_(\w+)_upper", "{}_door_top")]:
        match = re.fullmatch(pattern, name)
        if match and match.group(1) in WOODS:
            return template.format(WOODS[match.group(1)])
    return name


def item(name):
    if name in ITEMS:
        return ITEMS[name]
    match = re.fullmatch(r"dye_powder_(\w+)", name)
    if match and match.group(1) in COLORS:
        return color(match.group(1)) + "_dye"
    match = re.fullmatch(r"(wood|gold)_(sword|pickaxe|axe|shovel|hoe|helmet|chestplate|leggings|boots)", name)
    if match:
        return {"wood": "wooden", "gold": "golden"}[match.group(1)] + "_" + match.group(2)
    match = re.fullmatch(r"door_(\w+)", name)
    if match and match.group(1) in WOODS:
        return WOODS[match.group(1)] + "_door"
    match = re.fullmatch(r"record_(\w+)", name)
    if match:
        return "music_disc_" + match.group(1)
    return name


def modern(path):
    """Return the 1.13+ paths a 1.12 path under assets/minecraft/textures/ supplies."""
    folder, _, file = path.rpartition("/")
    stem, dot, extension = file.partition(".")
    base = path[:-len(dot + extension)] if dot else path
    if folder == "blocks":
        name = "block/" + block(stem)
    elif folder == "items":
        name = "item/" + item(stem)
    elif folder.startswith("entity"):
        entity = base[len("entity/"):]
        name = "entity/" + ENTITIES.get(entity, entity)
    else:
        name = base
    return [new + dot + extension for new in [name] + ALSO.get(base, [])]
