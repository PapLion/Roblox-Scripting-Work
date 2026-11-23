"""Render contact sheets of the icon set.

usage: python preview_icons.py <icons_sheet.png> [glyphs_sheet.png] [small_sheet.png]

The optional third sheet shows every icon at 64/48/40 px to check readability.
"""
import io
import os
import sys

import resvg_py
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from icons import ICONS, GLYPHS, icon_svg, glyph_svg  # noqa: E402

EXPECTED_ICONS = (
    "sword dagger axe mace bow staff wand shield helm chestplate gloves boots cloak ring amulet belt "
    "potion_health potion_mana potion_stamina elixir scroll tome herb mushroom ore ingot gem_ruby "
    "gem_sapphire crystal leather thread wood feather key map bread coin_pouch chest "
    "fireball frost_shard lightning arcane_orb heal ward dash poison meteor blizzard drain haste rage "
    "stealth spirit_wolf thorns smite regen").split()
EXPECTED_GLYPHS = (
    "close check lock unlock search sort filter chevron_down chevron_up chevron_right chevron_left plus "
    "minus star star_outline gear quest hourglass coin gem trash info swap sparkle heart drop bolt skull "
    "crown sword_small shield_small eye compass scroll_small hammer bag user refresh arrow_up arrow_down "
    "pin bell flame snow").split()

missing_i = [n for n in EXPECTED_ICONS if n not in ICONS]
missing_g = [n for n in EXPECTED_GLYPHS if n not in GLYPHS]
assert not missing_i, f"missing icons: {missing_i}"
assert not missing_g, f"missing glyphs: {missing_g}"
assert len(EXPECTED_ICONS) == 56 and len(EXPECTED_GLYPHS) == 44

BG = (0x24, 0x1A, 0x14, 255)
SHEET_BG = (0x14, 0x0E, 0x0B, 255)


def render(svg, size):
    png = resvg_py.svg_to_bytes(svg_string=svg, width=size, height=size)
    return Image.open(io.BytesIO(bytes(png))).convert("RGBA")


def font(sz):
    for f in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(f, sz)
        except OSError:
            pass
    return ImageFont.load_default()


def sheet(names, make_svg, size, cols, out, tint=None):
    pad, label = 12, 22
    tile = size + 16
    rows = (len(names) + cols - 1) // cols
    W = cols * (tile + pad) + pad
    H = rows * (tile + label + pad) + pad
    img = Image.new("RGBA", (W, H), SHEET_BG)
    d = ImageDraw.Draw(img)
    f = font(13)
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        x, y = pad + c * (tile + pad), pad + r * (tile + label + pad)
        d.rounded_rectangle([x, y, x + tile, y + tile], 8, fill=BG)
        ic = render(make_svg(n, size), size)
        if tint:
            solid = Image.new("RGBA", ic.size, tint)
            solid.putalpha(ic.getchannel("A"))
            ic = solid
        img.alpha_composite(ic, (x + 8, y + 8))
        tw = d.textlength(n, font=f)
        d.text((x + (tile - tw) / 2, y + tile + 3), n, font=f, fill=(230, 214, 190, 255))
    img.save(out)
    print("wrote", out, img.size)


def small_sheet(names, out):
    sizes = (64, 48, 40)
    cols = 8
    cell = sum(sizes) + 8 * len(sizes) + 8
    rowh = sizes[0] + 16
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGBA", (cols * (cell + 8) + 8, rows * (rowh + 8) + 8), SHEET_BG)
    d = ImageDraw.Draw(img)
    for i, n in enumerate(names):
        c, r = i % cols, i // cols
        x, y = 8 + c * (cell + 8), 8 + r * (rowh + 8)
        d.rounded_rectangle([x, y, x + cell, y + rowh], 6, fill=BG)
        xx = x + 8
        for s in sizes:
            img.alpha_composite(render(icon_svg(n, s), s), (xx, y + 8 + (sizes[0] - s) // 2))
            xx += s + 8
    img.save(out)
    print("wrote", out, img.size)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sheet(EXPECTED_ICONS, icon_svg, 128, 8, sys.argv[1])
    if len(sys.argv) > 2:
        sheet(EXPECTED_GLYPHS, glyph_svg, 64, 11, sys.argv[2])
    if len(sys.argv) > 3:
        small_sheet(EXPECTED_ICONS, sys.argv[3])
