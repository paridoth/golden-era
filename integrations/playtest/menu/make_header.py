#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Draw the original Golden Era main menu header from an in-file pixel font.

No external font or image pixels are used. Run from anywhere; writes header.png
beside this script. The output image is dedicated under CC0 (see NOTICE.md).
"""
from pathlib import Path

from PIL import Image, ImageFilter

GLYPHS = {
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    " ": ["...", "...", "...", "...", "...", "...", "..."],
}
TEXT = "GOLDEN ERA"
WIDTH, HEIGHT = 960, 120  # Luanti's menu header size, as used by Mineclonia
SCALE = 13
OUTLINE = (52, 31, 6, 255)
# Bright top rows fading to deep gold, one colour per font row.
ROWS = [(255, 236, 140), (255, 222, 98), (250, 204, 64), (240, 186, 40),
        (226, 166, 26), (208, 146, 16), (186, 126, 10)]


def cells():
    x = 0
    for char in TEXT:
        glyph = GLYPHS[char]
        for row, line in enumerate(glyph):
            for column, bit in enumerate(line):
                if bit == "#":
                    yield x + column, row
        x += len(glyph[0]) + 1


def shade(colour, amount):
    return tuple(max(0, min(255, round(channel * amount))) for channel in colour) + (255,)


def main():
    blocks = list(cells())
    columns = max(x for x, _ in blocks) + 1
    left = (WIDTH - columns * SCALE) // 2
    top = (HEIGHT - 7 * SCALE) // 2 - 2
    letters = Image.new("RGBA", (WIDTH, HEIGHT))
    pixels = letters.load()
    for cx, cy in blocks:
        base = ROWS[cy]
        for dx in range(SCALE):
            for dy in range(SCALE):
                # Bevel each block like an ingot: lit top/left, shaded bottom/right.
                if dx < 2 or dy < 2:
                    colour = shade(base, 1.12)
                elif dx >= SCALE - 2 or dy >= SCALE - 2:
                    colour = shade(base, 0.72)
                else:
                    # Fixed dither keeps the face from looking flat.
                    colour = shade(base, 0.96 if (dx * 7 + dy * 3 + cx + cy) % 5 == 0 else 1.0)
                pixels[left + cx * SCALE + dx, top + cy * SCALE + dy] = colour
    alpha = letters.getchannel("A")
    outline = Image.new("RGBA", (WIDTH, HEIGHT), OUTLINE)
    outline.putalpha(alpha.filter(ImageFilter.MaxFilter(7)))
    shadow = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 110)), (5, 5), outline)
    header = Image.alpha_composite(Image.alpha_composite(shadow, outline), letters)
    header.save(Path(__file__).with_name("header.png"), optimize=True)


if __name__ == "__main__":
    main()
