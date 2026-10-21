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
    machines = path / "registration/machines_api_reg.lua"
    renamed = 0
    for texture in ("logistica_network_controller_front_anim.png", "logistica_lava_furnace_front_on_anim.png",
                    "logistica_pump_side_on.png"):
        # Luanti deprecated the TileDef "image" alias in favour of "name".
        renamed += _replace(machines, 'image = "' + texture + '"', 'name = "' + texture + '"')
    if renamed:
        changed.append(f"logistica: {renamed} animated tiles use TileDef name instead of the deprecated image field")
    return changed
