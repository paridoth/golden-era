// SPDX-License-Identifier: LGPL-2.1-or-later
// Golden Era optional desktop controller prototype. No engine or GUI dependencies.
#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>

class GoldenEraMenuCursor
{
public:
	static constexpr int deadzone = 8000;
	enum Direction { UP, DOWN, LEFT, RIGHT };

	void activate(std::uint32_t id, int x, int y, int width, int height)
	{
		if (!m_active || m_owner != id) {
			resetInput();
			m_owner = id;
		}
		if (!m_initialized) {
			m_x = x >= 0 && x < width ? x : width / 2.0f;
			m_y = y >= 0 && y < height ? y : height / 2.0f;
			m_initialized = true;
		}
		m_active = true;
		clamp(width, height);
	}

	void suspend(int x, int y)
	{
		m_active = false;
		m_x = x;
		m_y = y;
		m_initialized = true;
		resetInput();
	}

	bool active() const { return m_active; }
	bool owns(std::uint32_t id) const { return m_active && m_owner == id; }
	int x() const { return static_cast<int>(std::lround(m_x)); }
	int y() const { return static_cast<int>(std::lround(m_y)); }

	void axis(bool vertical, int raw)
	{
		const float magnitude = std::min(std::abs(raw), 32767);
		float value = std::max(0.0f, (magnitude - deadzone) / (32767 - deadzone));
		value *= value; // Fine control near the deadzone, fast traversal at the edge.
		(vertical ? m_axis_y : m_axis_x) = raw < 0 ? -value : value;
	}

	void direction(Direction direction, bool pressed) { m_dpad[direction] = pressed; }

	// SDL normally supplies transitions only. Guard against duplicate button-down
	// events so one physical press cannot cause multiple inventory actions.
	bool button(unsigned button, bool pressed)
	{
		if (button >= m_buttons.size())
			return false;
		const bool rising = pressed && !m_buttons[button];
		m_buttons[button] = pressed;
		return rising;
	}

	bool step(float seconds, int width, int height)
	{
		if (!m_active)
			return false;
		const int old_x = x(), old_y = y();
		float vx = m_axis_x, vy = m_axis_y;
		// D-pad is deliberately slower for selecting a single inventory slot.
		if (m_dpad[LEFT] || m_dpad[RIGHT])
			vx = (static_cast<int>(m_dpad[RIGHT]) - m_dpad[LEFT]) * 0.35f;
		if (m_dpad[UP] || m_dpad[DOWN])
			vy = (static_cast<int>(m_dpad[DOWN]) - m_dpad[UP]) * 0.35f;
		const float length = std::hypot(vx, vy);
		if (length > 1.0f) {
			vx /= length;
			vy /= length;
		}
		// Frame stalls and focus changes must not fling the cursor across a form.
		const float dt = std::clamp(seconds, 0.0f, 0.05f);
		const float speed = std::max(height, 1) * (900.0f / 1080.0f);
		m_x += vx * speed * dt;
		m_y += vy * speed * dt;
		clamp(width, height);
		return x() != old_x || y() != old_y;
	}

private:
	void resetInput()
	{
		m_axis_x = m_axis_y = 0;
		m_dpad.fill(false);
		m_buttons.fill(false);
	}
	void clamp(int width, int height)
	{
		m_x = std::clamp(m_x, 0.0f, static_cast<float>(std::max(width - 1, 0)));
		m_y = std::clamp(m_y, 0.0f, static_cast<float>(std::max(height - 1, 0)));
	}
	bool m_active = false, m_initialized = false;
	std::uint32_t m_owner = 0;
	float m_x = 0, m_y = 0, m_axis_x = 0, m_axis_y = 0;
	std::array<bool, 4> m_dpad{};
	std::array<bool, 32> m_buttons{};
};
