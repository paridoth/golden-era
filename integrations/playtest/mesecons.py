"""Checked compatibility edits for the copied, pinned Mesecons modpack."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Mesecons source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    changed = []
    compat = path / "mesecons_gamecompat/compat_mcla.lua"
    if _replace(compat, "for color, def in ipairs(mcl_dyes.colors) do",
                "for color, def in pairs(mcl_dyes.colors) do"):
        changed.append("mesecons: iterate Mineclonia's named dye color table")
    old = '''			v.groups = groups
			core.register_node(":"..k, v)
'''
    new = '''			-- Golden Era playtest: update groups without reusing a registered definition.
			core.override_item(k, {groups = groups})
'''
    if _replace(compat, old, new):
        changed.append("mesecons: update Mineclonia piston stopper groups through override_item")
    return changed
