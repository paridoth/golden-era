"""Checked compatibility edits for the copied, pinned Logistica mod."""
from pathlib import Path


def _replace(path: Path, old: str, new: str) -> bool:
    text = path.read_text()
    if new in text:
        return False
    if text.count(old) != 1:
        raise ValueError(f"Unexpected Logistica source: {path}")
    path.write_text(text.replace(old, new, 1))
    return True


def apply(path: Path) -> list[str]:
    changed = []
    if _replace(path / "util/liquids.lua",
                'local mcla = minetest.get_game_info().id == "mineclonia"\n',
                '-- Golden Era playtest: this Mineclonia-based game has its own game ID.\n'
                'local mcla = minetest.get_game_info().id == "mineclonia" or minetest.get_game_info().id == "golden_era_playtest"\n'):
        changed.append("logistica: use Mineclonia liquid textures under the golden_era_playtest game ID")
    return changed
