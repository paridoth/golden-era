"""Small, checked edits to copied Elepower c37fe7b sources; never edit upstream."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Elepower source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    """Patch a disposable modpack copy for the pinned Mineclonia playtest."""
    changed = []
    documentation = path / "elepower_documentation"
    if (documentation / "init.lua").read_text() != "":
        raise ValueError("Unexpected Elepower documentation init.lua")
    modconf = documentation / "mod.conf"
    declaration = "name = elepower_documentation\ndescription = Upstream Elepower diagrams and documentation.\n"
    if modconf.exists():
        if modconf.read_text() != declaration:
            raise ValueError("Unexpected Elepower documentation mod.conf")
    else:
        modconf.write_text(declaration)
        changed.append("elepower: declare the upstream documentation mod name")
    init = path / "elepower_compat/init.lua"
    anchor = 'dofile(modpath.."/mods/xcompat.lua")\n'
    repairs = '''
-- Golden Era playtest: use Mineclonia items and retain Elepower's own metals.
-- xcompat's generic tin fallback is iron, which would skip Elepower tin ore.
if core.get_modpath("mcl_core") then
  ele.external.ing.tin_ingot = ""
  ele.external.ing.bronze_ingot = ""
  ele.external.ing.silver_ingot = ""
  ele.external.ing.mese = "mcl_redstone_torch:redstoneblock"
  ele.external.ing.mese_crystal = "mcl_redstone:redstone"
  ele.external.ing.mese_crystal_fragment = "mcl_redstone:redstone"
  ele.external.ing.mese_lamp = "mcl_redstone_lamp:lamp_off"
  ele.external.ing.wheat = "mcl_farming:wheat_item"
  ele.external.ing.brick = "mcl_core:brick_block"
  ele.external.ing.clay_brick = "mcl_core:brick"
  ele.external.ing.hoe_steel = "mcl_farming:hoe_iron"
  ele.external.ing.axe_steel = "mcl_tools:axe_iron"
  ele.external.ing.slab_glass = "mcl_panes:pane_natural_flat"
end
'''
    if _replace(init, anchor, anchor + repairs):
        changed.append("elepower: Mineclonia material mappings and native tin/bronze/silver")

    modconf = path / "elepower_machines/mod.conf"
    if _replace(modconf, "optional_depends = unified_inventory,craftguide\n",
                "optional_depends = unified_inventory,craftguide,mcl_craftguide\n"):
        changed.append("elepower: load Mineclonia craft guide before machine recipes")

    craft = path / "elepower_machines/craft.lua"
    old = '''local have_cg = minetest.get_modpath("craftguide") and craftguide and
                    craftguide.register_craft
'''
    new = '''-- Golden Era playtest: both guides accept these custom recipe definitions.
local craftguide = core.get_modpath("mcl_craftguide") and mcl_craftguide or
                       rawget(_G, "craftguide")
local have_cg = craftguide and craftguide.register_craft
'''
    if _replace(craft, old, new):
        changed.append("elepower: expose machine recipes in Mineclonia craft guide")

    fusion = path / "elepower_nuclear/machines/fusion_reactor.lua"
    old = '''        local leftovers = 0
        for buffer, data in pairs(buffers) do
            if millibuckets == 0 then break end
            local didnt_fit = fluid_lib.insert_into_buffer(ctrl, buffer, liquid,
                                                           millibuckets)
            millibuckets = millibuckets - (millibuckets - didnt_fit)
            leftovers = leftovers + didnt_fit
        end
        return leftovers
'''
    new = '''        -- Golden Era playtest: return the final remainder across buffers.
        for buffer, data in pairs(buffers) do
            if millibuckets == 0 then break end
            millibuckets = fluid_lib.insert_into_buffer(ctrl, buffer, liquid,
                                                        millibuckets)
        end
        return millibuckets
'''
    if _replace(fusion, old, new):
        changed.append("elepower: conserve multi-buffer fusion fluid input")
    return changed
