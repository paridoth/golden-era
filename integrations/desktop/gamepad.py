# SPDX-License-Identifier: GPL-3.0-or-later
"""Optional controller cursor patch for a clean copied Luanti 5.17.0 engine.

The official Windows download is deliberately unaffected. Apply only in an
isolated build tree under runtime/ or tools/; never modify upstream/ in place.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PINNED = {
    "src/gui/modalMenu.h": "0e8deeed5942722ec7e95eddd1a9093a74eabd155e5d3c84dbfca8ba9b69f203",
    "src/gui/modalMenu.cpp": "6536c767a0962830d79e7f12ab0b2aa7837de3c703f1e64283b6533d948f21a2",
    "src/gui/guiButtonKey.h": "abdb05c5475b5f8a2ba3d4173e7e430f74c1f066aae0293b8e4eb7dc682f4415",
}


def _replace(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError("Unexpected pinned controller patch anchor")
    return text.replace(old, new, 1)


def _render(original: dict[str, str]) -> dict[str, str]:
    header = _replace(original["src/gui/modalMenu.h"],
                      '#include "irr_ptr.h"',
                      '#include "irr_ptr.h"\n#include "goldenEraMenuCursor.h"')
    header = _replace(header, "\tvoid allowFocusRemoval(bool allow);",
                      "\tvoid setVisible(bool visible) override;\n\tvoid allowFocusRemoval(bool allow);")
    header = _replace(header, "\nstruct PointerAction {", "\nnamespace video { class IVideoDriver; }\n\nstruct PointerAction {")
    header = _replace(header, "private:\n\tIMenuManager *m_menumgr;", """private:
	bool preprocessGamepadEvent(const SEvent &event);
	void sendGamepadMouse(EMOUSE_INPUT_EVENT type, float wheel = 0, bool shift = false);
	void sendGamepadClick(bool right, bool shift = false);
	void stepGamepadCursor(v2u32 screen);
	void drawGamepadCursor(video::IVideoDriver *driver);
	GoldenEraMenuCursor m_gamepad_cursor;
	u64 m_gamepad_draw_time = 0;
	IMenuManager *m_menumgr;""")
    impl = _replace(original["src/gui/modalMenu.cpp"],
                    '#include "gui/guiInventoryList.h"',
                    '#include "gui/guiInventoryList.h"\n#include "gui/guiButtonKey.h"')
    impl = _replace(impl, """	drawMenu();
}
""", """	// An injected movement can regenerate or remove a formspec downstream.
	irr_ptr<GUIModalMenu> holder;
	holder.grab(this);
	stepGamepadCursor(screensize);
	if (!IsVisible || !Parent)
		return;
	drawMenu();
	drawGamepadCursor(driver);
}
""")
    impl = _replace(impl,
                    "bool GUIModalMenu::preprocessEvent(const SEvent &event)\n{\n",
                    """bool GUIModalMenu::preprocessEvent(const SEvent &event)
{
	if (preprocessGamepadEvent(event))
		return true;
""")
    impl = _replace(impl, """			m_pointer = v2s32(event.MouseInput.X, event.MouseInput.Y);
			m_touch_hovered.reset();
""", """			m_pointer = v2s32(event.MouseInput.X, event.MouseInput.Y);
			m_gamepad_cursor.suspend(m_pointer.X, m_pointer.Y);
			if (auto *cursor = RenderingEngine::get_raw_device()->getCursorControl())
				cursor->setVisible(true);
			m_touch_hovered.reset();
""")
    # Keep ordinary touches authoritative too, including on desktop touchscreens.
    impl = _replace(impl, """	if (event.EventType == EET_TOUCH_INPUT_EVENT) {
		irr_ptr<GUIModalMenu> holder;
""", """	if (event.EventType == EET_TOUCH_INPUT_EVENT) {
		m_gamepad_cursor.suspend(event.TouchInput.X, event.TouchInput.Y);
		irr_ptr<GUIModalMenu> holder;
""")
    impl += "\n" + (HERE / "gamepad_bridge.cpp.inc").read_text()
    key = _replace(original["src/gui/guiButtonKey.h"],
                   "\nprivate:\n\tvoid sendKey();", """
	// Golden Era: cursor translation must not consume raw rebinding events.
	bool isCapturing() const { return capturing; }

private:
	void sendKey();""")
    return {
        "src/gui/modalMenu.h": header,
        "src/gui/modalMenu.cpp": impl,
        "src/gui/guiButtonKey.h": key,
        "src/gui/goldenEraMenuCursor.h": (HERE / "gamepad_cursor.h").read_text(),
    }


def apply_gamepad_patch(stage: Path) -> list[str]:
    """Apply exact, idempotent source edits after validating every destination."""
    stage = stage.resolve()
    if not any(stage.is_relative_to(ROOT / part) for part in ("runtime", "tools")):
        raise ValueError("Controller patch requires a copied runtime/ or tools/ tree")
    if (stage / ".git").exists():
        raise ValueError("Controller patch refuses a Git checkout")
    original = {}
    for name, digest in PINNED.items():
        source = ROOT / "upstream/luanti" / name
        data = source.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError(f"Unexpected pinned Luanti controller source: {name}")
        original[name] = data.decode()
    rendered = _render(original)
    # Preflight the complete patch so a dirty file cannot leave partial changes.
    changed = []
    for name, desired in rendered.items():
        path = stage / name
        if path.is_symlink() or not path.resolve().is_relative_to(stage):
            raise ValueError(f"Unsafe controller patch target: {name}")
        actual = path.read_text() if path.exists() else None
        if actual == desired:
            continue
        if actual != original.get(name):
            raise ValueError(f"Unexpected copied Luanti controller source: {name}")
        changed.append(name)
    for name in changed:
        (stage / name).write_text(rendered[name])
    return changed
