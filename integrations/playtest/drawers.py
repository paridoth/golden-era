"""Checked edits to copied Drawers 5c8aa86 sources; upstream stays untouched."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Drawers source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    """Repair native storage behavior in the pinned disposable mod copy."""
    changed = []
    visual = path / "lua/visual.lua"
    old = '''		-- drop the item stack
		core.item_drop(itemStack, nil, dropPos)
'''
    new = '''		-- Golden Era: Mineclonia's item_drop requires a real player.
		-- add_item retains the stack's count, wear and metadata without one.
		if drawers.mcl_loaded then
			core.add_item(dropPos, itemStack)
		else
			core.item_drop(itemStack, nil, dropPos)
		end
'''
    if _replace(visual, old, new):
        changed.append("drawers: drop recoverable Mineclonia overflow when removing capacity upgrades")

    api = path / "lua/api.lua"
    old = '''			-- Use the player for item_drop if they exist, otherwise use the position
			if player then
				core.item_drop(leftover, player, drawers.randomize_pos(pos))
			else
				core.add_item(drawers.randomize_pos(pos), leftover)
			end
'''
    new = '''			-- Golden Era: automatic spills must not use Mineclonia's player
			-- drop-key behavior (no-op for dummy diggers; one item when sneaking).
			if drawers.mcl_loaded then
				core.add_item(drawers.randomize_pos(pos), leftover)
			elseif player then
				core.item_drop(leftover, player, drawers.randomize_pos(pos))
			else
				core.add_item(drawers.randomize_pos(pos), leftover)
			end
'''
    if _replace(api, old, new):
        changed.append("drawers: preserve automatic dig/explosion spills with dummy or sneaking diggers")

    old = '''	def.legacy_facedir_simple = true
	def.groups = def.groups or {}
	def.is_ground_content = def.is_ground_content == true
'''
    new = '''	def.legacy_facedir_simple = true
	def.groups = def.groups or {}
	-- Golden Era: mirror the existing MVPS stopper policy for native pistons.
	-- Moving drawers restores metadata after spawning empty visual state.
	if drawers.mcl_loaded then def.groups.unmovable_by_piston = 1 end
	def.is_ground_content = def.is_ground_content == true
'''
    if _replace(api, old, new):
        changed.append("drawers: preserve native immobility under Mineclonia pistons")

    old = '''		-- don't allow items with metadata
		if #stack:get_meta():get_keys() > 0 then
'''
    new = '''		-- Golden Era: name/count storage cannot preserve metadata or wear.
		if stack:get_wear() ~= 0 or #stack:get_meta():get_keys() > 0 then
'''
    if _replace(visual, old, new):
        changed.append("drawers: refuse worn stacks rather than discarding their wear")

    controller = path / "lua/controller.lua"
    old = '''local function controller_on_blast(pos)
	local drops = {}
	default.get_inventory_drops(pos, "src", drops)
	drops[#drops+1] = "drawers:controller"
	core.remove_node(pos)
	return drops
end
'''
    new = '''local function controller_on_blast(pos, intensity, do_drop)
	-- Golden Era: Mineclonia invokes this callback directly and does not use
	-- its return value. Keep its drop-chance decision and emit real entities.
	if drawers.mcl_loaded then
		if do_drop ~= false then
			local inv = core.get_meta(pos):get_inventory()
			for _, stack in ipairs(inv:get_list("src") or {}) do
				if not stack:is_empty() then core.add_item(pos, stack) end
			end
			core.add_item(pos, "drawers:controller")
		end
		core.remove_node(pos)
		return
	end
	local drops = {}
	default.get_inventory_drops(pos, "src", drops)
	drops[#drops+1] = "drawers:controller"
	core.remove_node(pos)
	return drops
end
'''
    if _replace(controller, old, new):
        changed.append("drawers: use Mineclonia's controller explosion/drop contract without the default API")

    old = '''local function is_valid_drawer_index_slot(net_index, item_name)
	local item_index = net_index and net_index[item_name]
	if not (item_index and item_index.drawer_positions and item_index.visualid) then
		return false
	end

	for _, position in ipairs(item_index.drawer_positions) do
		if not (position.x and position.y and position.z) then
			return false
		end
	end

	return true
end
'''
    new = '''local function is_valid_drawer_index_slot(net_index, item_name)
	-- Golden Era: index_drawers emits an array of {drawer_pos, visualid}.
	local item_index = type(net_index) == "table" and net_index[item_name]
	if type(item_index) ~= "table" or #item_index == 0 then return false end
	for _, slot in ipairs(item_index) do
		if type(slot) ~= "table" or type(slot.drawer_pos) ~= "table" then return false end
		local pos = slot.drawer_pos
		if type(pos.x) ~= "number" or type(pos.y) ~= "number" or type(pos.z) ~= "number" or
				(type(slot.visualid) ~= "string" and type(slot.visualid) ~= "number") then
			return false
		end
	end
	return true
end

-- Golden Era: topology changes must invalidate cached paths, including the
-- native set_node/remove_node calls used by explosions and Mesecons pistons.
-- Scan only on these changes; repeated deposits retain the native item cache.
function drawers.invalidate_controller_caches(pos)
	for _, controller in ipairs(core.find_nodes_in_area(
			vector.subtract(pos, drawers.CONTROLLER_RANGE),
			vector.add(pos, drawers.CONTROLLER_RANGE), {"drawers:controller"})) do
		core.get_meta(controller):set_string("drawers_table_index", "")
	end
end
'''
    if _replace(controller, old, new):
        changed.append("drawers: validate the native controller cache's array of drawer slots")

    old = '''local function controller_get_drawer_index(pos, itemstring)
	local meta = core.get_meta(pos)
	local drawer_net_index = core.deserialize(meta:get_string("drawers_table_index"))
'''
    new = old + '''
	-- Golden Era: MVPS restores old metadata after running constructors.
	-- Absolute drawer positions cannot be reused from another controller origin.
	local origin = core.pos_to_string(pos)
	if meta:get_string("drawers_table_index_origin") ~= origin then
		drawer_net_index = nil
		meta:set_string("drawers_table_index_origin", origin)
	end
'''
    if _replace(controller, old, new):
        changed.append("drawers: reindex moved controllers after native metadata restoration")

    # A local closure captures each upstream callback separately, retaining its
    # arguments/return value. swap_node rotations respawn visuals below instead.
    anchor = "-- register drawer controller\nregister_controller()\n"
    hooks = '''
-- Golden Era: preserve native node callbacks while invalidating changed paths.
core.register_on_mods_loaded(function()
	for name, def in pairs(core.registered_nodes) do
		local groups = def.groups or {}
		if (groups.drawer or 0) > 0 or (groups.drawer_connector or 0) > 0 then
			local construct, destruct = def.on_construct, def.on_destruct
			core.override_item(name, {
				on_construct = function(pos)
					drawers.invalidate_controller_caches(pos)
					if construct then return construct(pos) end
				end,
				on_destruct = function(pos)
					drawers.invalidate_controller_caches(pos)
					if destruct then return destruct(pos) end
				end,
			})
		end
	end
end)
core.register_lbm({
	label = "Invalidate reloaded controller paths",
	name = "drawers:golden_era_controller_reload",
	nodenames = {"drawers:controller"}, run_at_every_load = true,
	action = function(pos)
		core.get_meta(pos):set_string("drawers_table_index", "")
	end,
})
'''
    if _replace(controller, anchor, anchor + hooks):
        changed.append("drawers: invalidate controller paths on topology changes and world reload")

    for function in ("spawn_visuals", "remove_visuals"):
        old = f"function drawers.{function}(pos)\n"
        new = old + '''	-- Golden Era: native visual respawns/rotations can change available slots.
	if drawers.invalidate_controller_caches then drawers.invalidate_controller_caches(pos) end
'''
        if _replace(visual, old, new):
            changed.append("drawers: invalidate cached paths on " + function)

    old = '''	return drawer_visuals[index]
end
'''
    new = '''	-- Golden Era: deactivated/removed objects are not available storage.
	local visual = drawer_visuals[index]
	if visual and visual.object:get_pos() then return visual end
	return nil
end
'''
    if _replace(visual, old, new):
        changed.append("drawers: refuse storage access through removed visual objects")
    return changed
