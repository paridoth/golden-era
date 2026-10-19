// SPDX-License-Identifier: LGPL-2.1-or-later
// Golden Era experimental desktop controller bridge. SDL-normalized gamepad
// events become ordinary GUI mouse/key events; inventory rules stay upstream.
void GUIModalMenu::setVisible(bool visible)
{
	// A release can be delivered to a different modal dialog. Never retain a
	// button-down latch or stick motion when a menu is hidden and restored.
	m_gamepad_cursor.suspend(m_pointer.X, m_pointer.Y);
	m_gamepad_draw_time = 0;
	IGUIElement::setVisible(visible);
}

bool GUIModalMenu::preprocessGamepadEvent(const SEvent &event)
{
	const bool axis_event = event.EventType == EET_GAMEPAD_AXIS_EVENT;
	if (!axis_event && event.EventType != EET_GAMEPAD_BUTTON_EVENT)
		return false;
	// Preserve native controller rebinding while a key field captures input.
	if (auto *key = dynamic_cast<GUIButtonKey *>(Environment->getFocus());
			key && key->isCapturing()) {
		m_gamepad_cursor.suspend(m_pointer.X, m_pointer.Y);
		return false;
	}

	irr_ptr<GUIModalMenu> holder;
	holder.grab(this); // A click or Escape can remove this menu.
	if (!RenderingEngine::get_raw_device()->isWindowFocused())
		return true;
	const v2u32 screen = Environment->getVideoDriver()->getScreenSize();
	if (axis_event) {
		const auto &pad = event.GamepadAxisEvent;
		if (pad.Axis != GamepadAxis::LEFTX && pad.Axis != GamepadAxis::LEFTY)
			return true;
		if (!m_gamepad_cursor.owns(pad.ID) &&
				std::abs(static_cast<int>(pad.Value)) <= GoldenEraMenuCursor::deadzone)
			return true; // A resting second controller must not steal the cursor.
		m_gamepad_cursor.activate(pad.ID, m_pointer.X, m_pointer.Y, screen.X, screen.Y);
		m_gamepad_cursor.axis(pad.Axis == GamepadAxis::LEFTY, pad.Value);
		return true;
	}

	const auto &pad = event.GamepadButtonEvent;
	if (!pad.PressedDown && !m_gamepad_cursor.owns(pad.ID))
		return true;
	m_gamepad_cursor.activate(pad.ID, m_pointer.X, m_pointer.Y, screen.X, screen.Y);
	const bool pressed = m_gamepad_cursor.button(static_cast<unsigned>(pad.Button), pad.PressedDown);
	switch (pad.Button) {
	case GamepadButton::DPAD_UP:
		m_gamepad_cursor.direction(GoldenEraMenuCursor::UP, pad.PressedDown);
		return true;
	case GamepadButton::DPAD_DOWN:
		m_gamepad_cursor.direction(GoldenEraMenuCursor::DOWN, pad.PressedDown);
		return true;
	case GamepadButton::DPAD_LEFT:
		m_gamepad_cursor.direction(GoldenEraMenuCursor::LEFT, pad.PressedDown);
		return true;
	case GamepadButton::DPAD_RIGHT:
		m_gamepad_cursor.direction(GoldenEraMenuCursor::RIGHT, pad.PressedDown);
		return true;
	default:
		break;
	}
	if (!pressed)
		return true;
	m_pointer = v2s32(m_gamepad_cursor.x(), m_gamepad_cursor.y());
	switch (pad.Button) {
	case GamepadButton::SOUTH:
		sendGamepadClick(false);
		return true;
	case GamepadButton::WEST:
		sendGamepadClick(true);
		return true;
	case GamepadButton::NORTH:
		sendGamepadClick(false, true); // Native Shift-click quick transfer.
		return true;
	case GamepadButton::LEFT_SHOULDER:
		sendGamepadMouse(EMIE_MOUSE_WHEEL, 1);
		return true;
	case GamepadButton::RIGHT_SHOULDER:
		sendGamepadMouse(EMIE_MOUSE_WHEEL, -1);
		return true;
	case GamepadButton::EAST:
	case GamepadButton::BACK:
	case GamepadButton::START: {
		SEvent key{};
		key.EventType = EET_KEY_INPUT_EVENT;
		key.KeyInput.Key = KEY_ESCAPE;
		key.KeyInput.SystemKeyCode = EscapeKey.getScancode();
		key.KeyInput.PressedDown = true;
		if (!preprocessEvent(key))
			Environment->postEventFromUser(key);
		return true;
	}
	default:
		return true;
	}
}

void GUIModalMenu::sendGamepadMouse(EMOUSE_INPUT_EVENT type, float wheel, bool shift)
{
	SEvent mouse{};
	mouse.EventType = EET_MOUSE_INPUT_EVENT;
	mouse.MouseInput.X = m_pointer.X;
	mouse.MouseInput.Y = m_pointer.Y;
	mouse.MouseInput.Simulated = true;
	mouse.MouseInput.Shift = shift;
	if (type == EMIE_MOUSE_WHEEL)
		mouse.MouseInput.Wheel = wheel;
	else if (type == EMIE_LMOUSE_PRESSED_DOWN || type == EMIE_LMOUSE_LEFT_UP)
		mouse.MouseInput.Button = SDL_BUTTON_LEFT;
	else if (type == EMIE_RMOUSE_PRESSED_DOWN || type == EMIE_RMOUSE_LEFT_UP)
		mouse.MouseInput.Button = SDL_BUTTON_RIGHT;
	mouse.MouseInput.Event = type;
	if (type == EMIE_LMOUSE_PRESSED_DOWN)
		mouse.MouseInput.ButtonStates = SDL_BUTTON_MASK(SDL_BUTTON_LEFT);
	else if (type == EMIE_RMOUSE_PRESSED_DOWN)
		mouse.MouseInput.ButtonStates = SDL_BUTTON_MASK(SDL_BUTTON_RIGHT);
	if (!preprocessEvent(mouse))
		Environment->postEventFromUser(mouse);
}

void GUIModalMenu::sendGamepadClick(bool right, bool shift)
{
	// A complete click needs no held synthetic buttons and survives switching
	// between controller, mouse, and modal dialogs without a stuck drag state.
	sendGamepadMouse(right ? EMIE_RMOUSE_PRESSED_DOWN : EMIE_LMOUSE_PRESSED_DOWN, 0, shift);
	if (IsVisible && Parent)
		sendGamepadMouse(right ? EMIE_RMOUSE_LEFT_UP : EMIE_LMOUSE_LEFT_UP, 0, shift);
}

void GUIModalMenu::stepGamepadCursor(v2u32 screen)
{
	const u64 now = porting::getTimeMs();
	const float dt = m_gamepad_draw_time == 0 ? 0 :
			porting::getDeltaMs(m_gamepad_draw_time, now) / 1000.0f;
	m_gamepad_draw_time = now;
	if (!m_is_window_focused) {
		m_gamepad_cursor.suspend(m_pointer.X, m_pointer.Y);
		return;
	}
	if (m_gamepad_cursor.step(dt, screen.X, screen.Y)) {
		m_pointer = v2s32(m_gamepad_cursor.x(), m_gamepad_cursor.y());
		sendGamepadMouse(EMIE_MOUSE_MOVED);
	}
}

void GUIModalMenu::drawGamepadCursor(video::IVideoDriver *driver)
{
	if (!m_gamepad_cursor.active())
		return;
	if (auto *cursor = RenderingEngine::get_raw_device()->getCursorControl())
		cursor->setVisible(false);
	const int x = m_pointer.X, y = m_pointer.Y;
	const int r = std::max(5, static_cast<int>(6 * m_gui_scale));
	const video::SColor black(255, 0, 0, 0), white(255, 255, 255, 255);
	driver->draw2DRectangle(black, core::rect<s32>(x - r - 1, y - 2, x + r + 2, y + 3));
	driver->draw2DRectangle(black, core::rect<s32>(x - 2, y - r - 1, x + 3, y + r + 2));
	driver->draw2DRectangle(white, core::rect<s32>(x - r, y - 1, x + r + 1, y + 2));
	driver->draw2DRectangle(white, core::rect<s32>(x - 1, y - r, x + 2, y + r + 1));
}
