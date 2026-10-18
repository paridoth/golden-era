"""Conservation fixes for copied fluid_lib 9b52f6e sources only."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected fluid_lib source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    """Apply bounded transfer-accounting fixes to a disposable modpack copy."""
    changed = []
    buffer = path / "fluid_lib/buffer.lua"
    old = '''	meta:set_string(buffer .. "_fluid", fluid)

	return 0
end
'''
    new = '''	meta:set_string(buffer .. "_fluid", fluid)

	-- Golden Era playtest: return the amount that did not fit.
	return count - can_put
end
'''
    if _replace(buffer, old, new):
        changed.append("fluid_lib: report partial-insertion leftovers without losing fluid")

    nodeio = path / "fluid_lib/nodeio.lua"
    old = '''		local leftovers = 0
		for buffer,data in pairs(buffers) do
			if millibuckets == 0 then break end
			local didnt_fit = fluid_lib.insert_into_buffer(pos, buffer, liquid, millibuckets)
			millibuckets = millibuckets - (millibuckets - didnt_fit)
			leftovers = leftovers + didnt_fit
		end
		return leftovers
'''
    new = '''		-- Golden Era playtest: carry the remainder across buffers exactly once.
		for buffer,data in pairs(buffers) do
			if millibuckets == 0 then break end
			millibuckets = fluid_lib.insert_into_buffer(pos, buffer, liquid, millibuckets)
		end
		return millibuckets
'''
    if _replace(nodeio, old, new):
        changed.append("fluid_lib: conserve multi-buffer liquid insertion")
    return changed
