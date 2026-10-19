"""Checked edits to copied Pipeworks 5dfd572 sources; upstream stays untouched."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Pipeworks source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    """Preserve owned items and distinguish new previews in the Mineclonia copy."""
    changed = []
    crafter = path / "autocrafter.lua"
    old = '''	after_place_node = pipeworks.scan_for_tube_objects,
	after_dig_node = pipeworks.scan_for_tube_objects,
	on_receive_fields = receive_fields,
	on_destruct = invalidate_cache,
'''
    new = old + '''	-- Golden Era: Mineclonia ignores returned blast drops and delegates
	-- removal here. Only src/dst own items; recipe/output are previews.
	on_blast = core.get_modpath("mcl_core") and function(pos, intensity, do_drop)
		local node = core.get_node(pos)
		local meta = core.get_meta(pos)
		local oldmetadata = meta:to_table()
		local drops = {}
		if do_drop ~= false then
			for _, item in ipairs(core.get_node_drops(node, "")) do
				drops[#drops + 1] = ItemStack(item)
			end
			local inv = meta:get_inventory()
			for _, list in ipairs({"src", "dst"}) do
				for _, stack in ipairs(inv:get_list(list) or {}) do
					if not stack:is_empty() then drops[#drops + 1] = stack end
				end
			end
		end
		-- Native on_destruct invalidates the recipe cache; after_dig updates
		-- neighboring tubes once after removal, without invoking can_dig.
		core.remove_node(pos)
		local def = core.registered_nodes[node.name]
		if def.after_dig_node then def.after_dig_node(pos, node, oldmetadata, nil) end
		for _, stack in ipairs(drops) do core.add_item(pos, stack) end
	end or nil,
'''
    if _replace(crafter, old, new):
        changed.append("pipeworks: preserve owned autocrafter src/dst under Mineclonia explosions without dropping previews")

    filters = path / "filter-injector.lua"
    old = 'local use_tags = pipeworks.enable_item_tags\n'
    new = old + '''
-- Golden Era: old filters owned physical main-list items; modern filters only
-- show previews. An absent marker is deliberately left to the native migration.
local golden_era_mineclonia = core.get_modpath("mcl_core") ~= nil
local function mark_modern_filter(meta)
	if golden_era_mineclonia then meta:set_int("golden_era_filter_preview", 1) end
end
'''
    if _replace(filters, old, new):
        changed.append("pipeworks: distinguish newly constructed modern Mineclonia filter previews")

    old = '''		on_construct = function(pos)
			local meta = core.get_meta(pos)
			set_filter_formspec(data, meta)
'''
    new = '''		on_construct = function(pos)
			local meta = core.get_meta(pos)
			mark_modern_filter(meta)
			set_filter_formspec(data, meta)
'''
    if _replace(filters, old, new):
        changed.append("pipeworks: mark fresh filter previews before their first block activation")

    # Hook after the complete native definition, before registration, so both
    # piston systems see the policy and Mineclonia's definition caches see it.
    old = '\tcore.register_node("pipeworks:"..data.name, node)\n'
    new = '''	-- Golden Era temporary policy: unmarked old preview/physical lists are
	-- ambiguous. Prevent piston movement into an unactivated legacy block.
	if golden_era_mineclonia then
		node.groups.unmovable_by_piston = 1
		if core.get_modpath("mesecons_mvps") then
			mesecon.register_mvps_stopper("pipeworks:"..data.name)
		end
	end
''' + old
    if _replace(filters, old, new):
        changed.append("pipeworks: temporarily keep all filter variants stationary under native and Mesecons pistons")

    old = '''core.register_lbm({
	label = "Give back items of old filters that had real inventories",
	name = "pipeworks:give_back_old_filter_items",
	nodenames = {"pipeworks:filter", "pipeworks:mese_filter"},
	run_at_every_load = false,
	action = function(pos, node)
		local meta = core.get_meta(pos)
		local list = meta:get_inventory():get_list("main")
'''
    new = '''core.register_lbm({
	label = "Give back items of old filters that had real inventories",
	name = "pipeworks:give_back_old_filter_items",
	nodenames = {"pipeworks:filter", "pipeworks:mese_filter"},
	run_at_every_load = false,
	action = function(pos, node)
		local meta = core.get_meta(pos)
		if golden_era_mineclonia then
			if meta:get_int("golden_era_filter_preview") == 1 then return end
		end
		local list = meta:get_inventory():get_list("main")
'''
    if _replace(filters, old, new):
        changed.append("pipeworks: skip modern previews while retaining native legacy owned-item refunds")
    old = '''		if not list then
			return
		end

		if put_to_inputinv(pos, node, meta, list) then
			return
		end
'''
    new = '''		if not list then
			mark_modern_filter(meta)
			return
		end

		if put_to_inputinv(pos, node, meta, list) then
			mark_modern_filter(meta)
			return
		end
'''
    if _replace(filters, old, new):
        changed.append("pipeworks: mark only completed legacy input refunds or empty-list conversions")
    old = '''		pos.y = pos.y + 1
		for i = 1, #list do
			local item = list[i]
			if not item:is_empty() then
				core.add_item(pos, item)
			end
		end
	end,
})
'''
    new = '''		pos.y = pos.y + 1
		for i = 1, #list do
			local item = list[i]
			if not item:is_empty() then
				core.add_item(pos, item)
			end
		end
		-- Captured meta still references the filter below the drop position.
		-- Keep old unclassified lists untouched unless native conversion finishes.
		mark_modern_filter(meta)
	end,
})
'''
    if _replace(filters, old, new):
        changed.append("pipeworks: mark fallback legacy conversion only after successful refund drops")
    return changed
