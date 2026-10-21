"""Checked Mineclonia port of the copied, pinned Magicalities mod (Minetest Game original)."""
from pathlib import Path
import shutil


HERE = Path(__file__).resolve().parent / "magicalities"
# Minetest Game item names used in recipes, comparisons and world edits.
ITEMS = {
    "default:dirt_with_grass": "mcl_core:dirt_with_grass",
    "default:water_source": "mcl_core:water_source",
    "default:desert_stone": "mcl_core:redsandstone",
    "default:steel_ingot": "mcl_core:iron_ingot",
    "default:steelblock": "mcl_core:ironblock",
    "default:gold_ingot": "mcl_core:gold_ingot",
    "default:bookshelf": "mcl_books:bookshelf",
    "default:sword_wood": "mcl_tools:sword_wood",
    "default:obsidian": "mcl_core:obsidian",
    "default:stone": "mcl_core:stone",
    "default:glass": "mcl_core:glass",
    "default:stick": "mcl_core:stick",
    "default:paper": "mcl_core:paper",
    "default:book": "mcl_books:book",
    "default:dirt": "mcl_core:dirt",
    "stairs:slab_wood": "mcl_stairs:slab_wood",
    "group:color_black": "group:unicolor_black",
    "group:color_white": "group:unicolor_white",
}
HELPERS = ("gui_bg_img", "gui_bg", "gui_slots", "get_hotbar_bg",
           "node_sound_wood_defaults", "node_sound_glass_defaults")


def _replace(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Magicalities source: {path}")
    path.write_text(text.replace(old, new, 1))


def apply(path: Path) -> list[str]:
    changed = []
    _replace(path / "mod.conf", "depends = default\n",
             "depends = mcl_core, mcl_sounds, mcl_books, mcl_tools, mcl_stairs, mcl_fences\n")
    changed.append("magicalities: depend on Mineclonia mods instead of Minetest Game default")
    renamed = helpers = 0
    for source in sorted(path.glob("*.lua")):
        text = original = source.read_text()
        # Longest names first, so default:stone does not split default:steelblock-like names.
        for old in sorted(ITEMS, key=len, reverse=True):
            renamed += text.count('"' + old)
            text = text.replace('"' + old, '"' + ITEMS[old])
        for helper in HELPERS:
            helpers += text.count("default." + helper)
            text = text.replace("default." + helper, "magicalities_compat." + helper)
        # Luanti 5.4+ replaced boolean texture alpha with named modes.
        text = text.replace("use_texture_alpha = true,", 'use_texture_alpha = "blend",')
        if "default:" in text.replace("-- s: stairs:slab_wood, g: default:glass", ""):
            raise ValueError(f"Unmapped Minetest Game item in {source.name}")
        if "default." in text:
            raise ValueError(f"Unmapped Minetest Game helper in {source.name}")
        if text != original:
            source.write_text(text)
    changed.append(f"magicalities: {renamed} item names mapped to Mineclonia, {helpers} GUI/sound helpers replaced")
    for name in ("compat_pre.lua", "compat_post.lua"):
        shutil.copy2(HERE / name, path / name)
    _replace(path / "init.lua", "magicalities = {}\n",
             'magicalities = {}\ndofile(minetest.get_modpath("magicalities").."/compat_pre.lua")\n')
    _replace(path / "init.lua", 'dofile(modpath.."/register.lua")\n',
             'dofile(modpath.."/register.lua")\n\n-- Golden Era: Mineclonia digging rules\ndofile(modpath.."/compat_post.lua")\n')
    _replace(path / "mapgen.lua", '		schematic = "schems/magicalities_booktower.mts",\n',
             '		schematic = minetest.get_modpath("magicalities").."/schems/magicalities_booktower.mts",\n'
             '		replacements = magicalities_compat.schematic_replacements,\n')
    changed.append("magicalities: Mineclonia digging groups/hardness, tool dig groups and book tower node replacements")
    # Wise Bookshelves become Mineclonia bookshelves, whose inventory list is "main".
    _replace(path / "nodes.lua", 'bookinv:add_item("books", ', 'bookinv:add_item("main", ')
    # Research notes come only from tower bookshelves; upstream's 1e-8 ratio makes
    # towers effectively absent, which blocks every researched recipe.
    _replace(path / "mapgen.lua", "fill_ratio = 0.00000001,", "fill_ratio = 0.0001,")
    book = path / "book.txt"
    text = book.read_text()
    for old in sorted(ITEMS, key=len, reverse=True):
        text = text.replace('name="' + old + '"', 'name="' + ITEMS[old] + '"')
    if 'name="default:' in text or 'name="stairs:' in text:
        raise ValueError("Unmapped Minetest Game item in book.txt")
    book.write_text(text)
    changed.append("magicalities: findable research towers, Mineclonia bookshelf inventory and guide book item names")
    return changed
