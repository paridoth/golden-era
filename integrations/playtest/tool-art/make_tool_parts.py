#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Draw the greyscale 16x16 tool-part sprites used by era_playtest's
Tinkers-style tools. Each part is drawn where it sits on an assembled tool, so
a tool icon is its parts tinted per material and layered. No external pixels
are used; rerunning this script reproduces the files exactly."""
import math, sys
from pathlib import Path
from PIL import Image

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "mod/textures"
DARK, MID, LIGHT, SHINE = 96, 150, 200, 240

def image(pixels):
    img = Image.new("LA", (16, 16), (0, 0))
    for (x, y), v in pixels.items():
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((x, y), (v, 255))
    return img.convert("RGBA")

def outline(fill):
    """Give a filled shape a dark rim and a lit upper-left edge."""
    out = {}
    for (x, y) in fill:
        edge = any((x + dx, y + dy) not in fill for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        lit = (x - 1, y) not in fill or (x, y - 1) not in fill
        out[(x, y)] = DARK if edge and not lit else (LIGHT if lit else MID)
    return out

def rod():
    # A two-pixel diagonal handle from the bottom-left corner up to the centre.
    px = {}
    for i in range(10):
        x, y = 1 + i, 14 - i
        px[(x, y)] = LIGHT
        px[(x + 1, y)] = DARK
    return px

def binding():
    # A wrap across the handle where the head meets it.
    px = {}
    for (x, y) in ((6, 8), (7, 7), (8, 8), (9, 7), (7, 9), (8, 6)):
        px[(x, y)] = DARK
    for (x, y) in ((7, 8), (8, 7)):
        px[(x, y)] = SHINE
    return px

def arc(cx, cy, r, a0, a1, width):
    fill = set()
    for x in range(16):
        for y in range(16):
            d = math.hypot(x - cx, y - cy)
            a = math.degrees(math.atan2(cy - y, x - cx))
            if abs(d - r) <= width / 2 and a0 <= a <= a1:
                fill.add((x, y))
    return fill

def pick_head():
    return outline(arc(3.5, 11.5, 8.6, -12, 102, 2.4))

def axe_head():
    fill = set()
    for x in range(16):
        for y in range(16):
            blade = (x - 7) ** 2 / 10 + (y - 4) ** 2 / 14 <= 1 and x <= 9
            neck = 9 <= x <= 12 and 2 <= y <= 5 and x + y <= 15
            if blade or neck:
                fill.add((x, y))
    return outline(fill)

def shovel_head():
    fill = set()
    for x in range(8, 16):
        for y in range(0, 8):
            if math.hypot(x - 12, y - 3.5) <= 3.4 or (x - y == 4 and 8 <= x <= 10):
                fill.add((x, y))
    return outline(fill)

def sword_blade():
    fill = set()
    for i in range(10):
        x, y = 5 + i, 9 - i
        fill |= {(x, y), (x + 1, y), (x, y - 1)}
    fill.discard((15, 0))
    px = outline(fill)
    for i in range(1, 9):
        px[(5 + i, 9 - i)] = SHINE
    return px

PARTS = {"pick_head": pick_head, "axe_head": axe_head, "shovel_head": shovel_head,
         "sword_blade": sword_blade, "binding": binding, "rod": rod}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in PARTS.items():
        image(draw()).save(OUT / f"era_playtest_part_{name}.png", optimize=True)
