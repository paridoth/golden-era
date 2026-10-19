// SPDX-License-Identifier: GPL-3.0-or-later
#include "gamepad_cursor.h"
#include <cassert>
#include <iostream>

int main()
{
	GoldenEraMenuCursor cursor;
	assert(!cursor.active());
	assert(!cursor.step(1, 1920, 1080));
	cursor.activate(7, 960, 540, 1920, 1080);
	assert(cursor.owns(7));
	assert(!cursor.owns(8));
	for (int raw : {-7999, 0, 7999}) {
		cursor.axis(false, raw);
		assert(!cursor.step(0.05f, 1920, 1080));
	}

	// The raw signed-axis extremes produce symmetric, bounded motion.
	cursor.axis(false, 32767);
	assert(cursor.step(0.05f, 1920, 1080));
	assert(cursor.x() == 1005);
	cursor.axis(false, -32768);
	assert(cursor.step(0.05f, 1920, 1080));
	assert(cursor.x() == 960);

	// Cursor speed is independent of frame rate and scales with resolution.
	cursor.axis(false, 32767);
	for (int i = 0; i < 60; ++i)
		cursor.step(1.0f / 60, 1920, 1080);
	assert(cursor.x() == 1860);
	cursor.suspend(480, 270);
	cursor.activate(7, 480, 270, 960, 540);
	cursor.axis(false, 32767);
	for (int i = 0; i < 30; ++i)
		cursor.step(1.0f / 30, 960, 540);
	assert(cursor.x() == 930);

	// A one-second stall advances at most one 50 ms step.
	cursor.suspend(300, 300);
	cursor.activate(7, 300, 300, 1920, 1080);
	cursor.axis(false, 32767);
	cursor.step(1, 1920, 1080);
	assert(cursor.x() == 345);
	cursor.axis(true, 32767);
	const int old_x = cursor.x(), old_y = cursor.y();
	cursor.step(0.05f, 1920, 1080);
	assert(std::hypot(cursor.x() - old_x, cursor.y() - old_y) <= 46);

	// D-pad offers slower targeting and opposing directions cancel.
	cursor.suspend(500, 500);
	cursor.activate(7, 500, 500, 1920, 1080);
	cursor.direction(GoldenEraMenuCursor::RIGHT, true);
	cursor.step(0.05f, 1920, 1080);
	assert(cursor.x() == 516);
	cursor.direction(GoldenEraMenuCursor::LEFT, true);
	assert(!cursor.step(0.05f, 1920, 1080));

	// A duplicate down is not another click; release/repress is another click.
	assert(cursor.button(0, true));
	assert(!cursor.button(0, true));
	assert(!cursor.button(0, false));
	assert(cursor.button(0, true));
	assert(!cursor.button(999, true));

	// Mouse handoff / modal hide clears stick, D-pad and click latches.
	cursor.suspend(200, 250);
	assert(!cursor.active());
	cursor.activate(7, 200, 250, 1920, 1080);
	assert(!cursor.step(0.05f, 1920, 1080));
	assert(cursor.x() == 200 && cursor.y() == 250);
	assert(cursor.button(0, true));

	// A different SDL gamepad ID cannot inherit the previous pad's held input.
	cursor.axis(false, 32767);
	cursor.activate(42, 200, 250, 1920, 1080);
	assert(cursor.owns(42) && !cursor.owns(7));
	assert(!cursor.step(0.05f, 1920, 1080));
	assert(cursor.button(0, true));

	// Resize and movement never escape the screen, including tiny viewports.
	cursor.axis(false, 32767);
	cursor.axis(true, 32767);
	for (int i = 0; i < 200; ++i)
		cursor.step(0.05f, 320, 200);
	assert(cursor.x() == 319 && cursor.y() == 199);
	cursor.step(0, 1, 1);
	assert(cursor.x() == 0 && cursor.y() == 0);
	std::cout << "PASS: cursor deadzone, rates, precision, bounds, transitions and handoff\n";
}
