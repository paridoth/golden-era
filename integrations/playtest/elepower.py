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
  ele.external.ing.steel_block = "elepower_dynamics:steel_block"
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

    wireless = path / "elepower_wireless/crafting.lua"
    if _replace(wireless, '"group:color_red"', 'epi.group_color_red'):
        changed.append("elepower: use the game-specific dye group for wireless cards")

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

    machine = path / "elepower_papi/machine.lua"
    old = '''local function switch_state(pos, state_def)
    local meta = core.get_meta(pos)
    local state = meta:get_int("state")
    local states = {}
    for id, state in pairs(ele.default.states) do
        if state_def[state.e] then states[#states + 1] = id end
    end

    if #states == 0 then return end

    state = state + 1
    if state >= #states then state = 0 end
    state = states[state + 1]
    meta:set_int("state", state)

    ele.helpers.start_timer(pos)
end
'''
    new = '''local function switch_state(pos, state_def)
    local meta = core.get_meta(pos)
    local state = meta:get_int("state")
    local states = {}
    for id, state in pairs(ele.default.states) do
        if state_def[state.e] then states[#states + 1] = id end
    end

    if #states == 0 then return end

    -- Golden Era: stored IDs are not indexes into an unordered subset.
    table.sort(states)
    local next_state = states[1]
    for index, id in ipairs(states) do
        if id == state then
            next_state = states[index % #states + 1]
            break
        end
    end
    meta:set_int("state", next_state)

    ele.helpers.start_timer(pos)
end
'''
    if _replace(machine, old, new):
        changed.append("elepower: cycle every supported machine state in native ID order")
    old = '''local function can_dig(pos, player)
    local meta = core.get_meta(pos)
    local inv = meta:get_inventory()
    return inv:is_empty("dst") and inv:is_empty("src")
end
'''
    new = '''-- Golden Era: scratch output snapshots and ghost filters are not items.
local function owned_inventory_list(name)
    return name ~= "dst_tmp" and name ~= "layout"
end

local function can_dig(pos, player)
    local inv = core.get_meta(pos):get_inventory()
    for name in pairs(inv:get_lists()) do
        if owned_inventory_list(name) and not inv:is_empty(name) then
            return false
        end
    end
    return true
end

-- The upgrade UI owns a detached copy until it closes. Its shared drop_lock flag
-- can be cleared by another editor leaving; use connected players' UI positions.
local function being_modified(pos)
    for _, player in ipairs(core.get_connected_players()) do
        local target = core.string_to_pos(player:get_meta():get_string("soldering"))
        if target and vector.equals(target, pos) then return true end
    end
    return false
end

-- Mineclonia delegates node removal to on_blast and ignores its return value.
-- Its fallback dig_node refuses occupied machines, then bulk deletion loses them.
local function mineclonia_on_blast(pos, intensity, do_drop)
    if being_modified(pos) then return end
    local node = core.get_node(pos)
    local def = core.registered_nodes[node.name]
    local meta = core.get_meta(pos)
    local oldmetadata = meta:to_table()
    local drops = {}
    if do_drop ~= false then
        for _, item in ipairs(core.get_node_drops(node, "")) do
            drops[#drops + 1] = ItemStack(item)
        end
        -- Keep the native charge/components representation on the machine only.
        if def.preserve_metadata then
            def.preserve_metadata(pos, node, oldmetadata.fields, drops)
        end
        for name, list in pairs(oldmetadata.inventory) do
            if owned_inventory_list(name) then
                for _, item in ipairs(list) do
                    local stack = ItemStack(item)
                    if not stack:is_empty() then drops[#drops + 1] = stack end
                end
            end
        end
    end
    -- remove_node runs Elepower's after_destruct network invalidation.
    core.remove_node(pos)
    if def.after_dig_node then
        def.after_dig_node(pos, node, oldmetadata, nil)
    end
    for _, stack in ipairs(drops) do core.add_item(pos, stack) end
end
'''
    if _replace(machine, old, new):
        changed.append("elepower: protect every owned machine inventory and preserve native Mineclonia blast drops")
    old = '''    -- Prevent digging when there's items inside
    if not nodedef.can_dig then nodedef.can_dig = can_dig end
'''
    new = old + '''
    if mcl then
        local original_can_dig = nodedef.can_dig
        nodedef.can_dig = function(pos, player)
            return not being_modified(pos) and original_can_dig(pos, player)
        end
    end

    -- Preserve explicit callbacks and other games' native explosion behavior.
    if mcl and not nodedef.on_blast then
        nodedef.on_blast = mineclonia_on_blast
    end
'''
    if _replace(machine, old, new):
        changed.append("elepower: register Mineclonia-only blast lifecycle without replacing custom callbacks")

    soldering = path / "elepower_tools/soldering.lua"
    old = '''minetest.register_on_leaveplayer(function(player)
    local umeta = player:get_meta()
    local soldering = umeta:get_string("soldering")
    if soldering == "" then return end
    local pos = minetest.string_to_pos(soldering)
    local meta = minetest.get_meta(pos)
    if meta:get_int("drop_lock") == 1 then meta:set_int("drop_lock", 0) end
    umeta:set_string("soldering", "")
end)
'''
    new = '''-- Golden Era: a reconnected player has no surviving upgrade formspec.
local function clear_soldering(player)
    local umeta = player:get_meta()
    local soldering = umeta:get_string("soldering")
    if soldering == "" then return end
    local pos = minetest.string_to_pos(soldering)
    if pos then
        local meta = minetest.get_meta(pos)
        if meta:get_int("drop_lock") == 1 then meta:set_int("drop_lock", 0) end
    end
    umeta:set_string("soldering", "")
end
minetest.register_on_leaveplayer(clear_soldering)
minetest.register_on_joinplayer(clear_soldering)
'''
    if _replace(soldering, old, new):
        changed.append("elepower: clear stale soldering locks when their editor reconnects")
    harvester = path / "elepower_farming/machines/harvester.lua"
    old = '''                for _, itm in ipairs(harvested) do
                    local stack = ItemStack(itm)
                    if inv:room_for_item("dst", stack) then
                        inv:add_item("dst", stack)
                    end
                end
'''
    new = '''                for _, itm in ipairs(harvested) do
                    -- Golden Era: harvesting already removed the crop/tree.
                    -- Keep partial insertion and spill only its real leftover.
                    local leftover = inv:add_item("dst", ItemStack(itm))
                    if not leftover:is_empty() then
                        core.add_item(vector.offset(pos, 0, 1, 0), leftover)
                    end
                end
'''
    if _replace(harvester, old, new):
        changed.append("elepower: preserve harvester overflow as recoverable full stacks above the machine")
    return changed
