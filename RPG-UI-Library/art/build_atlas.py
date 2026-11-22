"""Vellum atlas builder.

Renders every 2D asset of the library from source (SVG written here and in icons.py, textures from
seeded noise), packs them and writes:

    art/out/vellum_icons.png      56 painted item / skill icons, 128 px cells (1024 x 1024)
    art/out/vellum_chrome.png     frames, ornaments, node frames, silhouette and 64 px glyphs (1024 x 1024)
    art/out/vellum_leather.png    256 px tileable leather grain (grey, tinted at runtime)
    art/out/vellum_parchment.png  256 px tileable parchment fibres
    src/ReplicatedStorage/Vellum/AtlasMap.module.luau   sprite rects and slice centres

usage: python art/build_atlas.py            (needs resvg_py and Pillow)
"""
from __future__ import annotations

import json
import math
import random
import sys
from io import BytesIO
from pathlib import Path

import resvg_py
from PIL import Image, ImageFilter

ART = Path(__file__).resolve().parent
ROOT = ART.parent
OUT = ART / "out"
sys.path.insert(0, str(ART))
try:
    from icons import GLYPHS, ICONS  # noqa: E402
except Exception as exc:  # icons not written yet: build chrome only
    print('icons unavailable:', exc)
    GLYPHS, ICONS = {}, {}

OUTLINE = "#1A110B"


def render(body: str, w: int, h: int, vw: int | None = None, vh: int | None = None) -> Image.Image:
    vw, vh = vw or w, vh or h
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {vw} {vh}">{body}</svg>'
    data = resvg_py.svg_to_bytes(svg_string=svg, width=w, height=h)
    return Image.open(BytesIO(bytes(data))).convert("RGBA")


def gold(id_: str, x1=0, y1=0, x2=0, y2=1, stops=("#FBEBC4", "#F3D08A", "#D4A55A", "#8A6630")) -> str:
    n = len(stops) - 1
    s = "".join(f'<stop offset="{i / n:.3f}" stop-color="{c}"/>' for i, c in enumerate(stops))
    return f'<linearGradient id="{id_}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{s}</linearGradient>'


# ---------------------------------------------------------------- chrome sprites
# Each entry: name -> (w, h, svg body, slice (x0, y0, x1, y1) or None)
CHROME: dict[str, tuple] = {}


def sprite(name, w, h, body, slice_=None):
    CHROME[name] = (w, h, body, slice_)


def corner_flourish(scale=1.0):
    """Gilt corner ornament for the top-left corner, in a 64 box. Mirrored at runtime."""
    return f"""<g transform="scale({scale})">
  <path d="M6 58 L6 18 Q6 6 18 6 L58 6" fill="none" stroke="{OUTLINE}" stroke-width="7" stroke-linecap="round"/>
  <path d="M6 58 L6 18 Q6 6 18 6 L58 6" fill="none" stroke="url(#cf_g)" stroke-width="3.2" stroke-linecap="round"/>
  <path d="M14 46 Q14 14 46 14" fill="none" stroke="{OUTLINE}" stroke-width="5" stroke-linecap="round"/>
  <path d="M14 46 Q14 14 46 14" fill="none" stroke="url(#cf_g)" stroke-width="2" stroke-linecap="round"/>
  <path d="M22 22 Q30 16 34 22 Q28 24 26 30 Q20 28 22 22 Z" fill="url(#cf_g)" stroke="{OUTLINE}" stroke-width="2"/>
  <circle cx="13" cy="13" r="5.5" fill="url(#cf_g)" stroke="{OUTLINE}" stroke-width="2.2"/>
  <circle cx="11.6" cy="11.6" r="1.6" fill="#FFF6DD"/>
  <path d="M46 14 q6 -4 10 0 q-4 4 -10 0Z M14 46 q-4 6 0 10 q4 -4 0 -10Z" fill="url(#cf_g)" stroke="{OUTLINE}" stroke-width="1.6"/>
</g>"""


sprite("corner", 64, 64, f"<defs>{gold('cf_g', 0, 0, 1, 1)}</defs>{corner_flourish()}")

# Ornate gilt panel border: double rule, flourished corners, transparent centre (9-slice).
_fg = []
for tx, ty, sx, sy in ((0, 0, 1, 1), (128, 0, -1, 1), (0, 128, 1, -1), (128, 128, -1, -1)):
    _fg.append(f'<g transform="translate({tx} {ty}) scale({sx} {sy})">{corner_flourish(0.78)}</g>')
sprite(
    "frame_gilt", 128, 128,
    f"""<defs>{gold('cf_g', 0, 0, 1, 1)}{gold('fg_v')}{gold('fg_h', 0, 0, 1, 0)}</defs>
<rect x="5" y="5" width="118" height="118" rx="7" fill="none" stroke="{OUTLINE}" stroke-width="6"/>
<rect x="5" y="5" width="118" height="118" rx="7" fill="none" stroke="url(#fg_v)" stroke-width="2.6"/>
<rect x="11" y="11" width="106" height="106" rx="4" fill="none" stroke="#8A6630" stroke-width="1.2" opacity="0.9"/>
{''.join(_fg)}""",
    (46, 46, 82, 82),
)

# Thin double-rule frame for cards and tooltips (9-slice).
sprite(
    "frame_thin", 64, 64,
    f"""<defs>{gold('ft_g')}</defs>
<rect x="2.5" y="2.5" width="59" height="59" rx="6" fill="none" stroke="{OUTLINE}" stroke-width="4"/>
<rect x="2.5" y="2.5" width="59" height="59" rx="6" fill="none" stroke="url(#ft_g)" stroke-width="1.6"/>
<rect x="6.5" y="6.5" width="51" height="51" rx="3" fill="none" stroke="#D4A55A" stroke-width="0.9" opacity="0.45"/>
<path d="M32 0.8 l3 2.2 l-3 2.2 l-3 -2.2Z M32 58.8 l3 2.2 l-3 2.2 l-3 -2.2Z" fill="#F3D08A" stroke="{OUTLINE}" stroke-width="0.8"/>""",
    (16, 16, 48, 48),
)

# Inset etched line, white, tinted (buttons, chips).
sprite(
    "frame_inset", 32, 32,
    '<rect x="3.5" y="3.5" width="25" height="25" rx="3" fill="none" stroke="#FFFFFF" stroke-width="1.2"/>',
    (10, 10, 22, 22),
)

# Slot frame: white bevel square, tinted by rarity (9-slice).
sprite(
    "frame_slot", 96, 96,
    f"""<defs>
<linearGradient id="fs_b" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.5" stop-color="#D8D8D8"/><stop offset="1" stop-color="#8C8C8C"/></linearGradient>
</defs>
<rect x="3" y="3" width="90" height="90" rx="9" fill="none" stroke="#000" stroke-opacity="0.85" stroke-width="5"/>
<rect x="4.5" y="4.5" width="87" height="87" rx="8" fill="none" stroke="url(#fs_b)" stroke-width="3.2"/>
<rect x="9.5" y="9.5" width="77" height="77" rx="5" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="1.2"/>
<path d="M4 18 L4 12 Q4 4 12 4 L18 4" fill="none" stroke="#FFFFFF" stroke-width="2.4" stroke-linecap="round"/>""",
    (24, 24, 72, 72),
)

# Bar frame: gilt rail for progress bars, transparent centre (9-slice).
sprite(
    "frame_bar", 128, 32,
    f"""<defs>{gold('fb_g')}</defs>
<rect x="3" y="4" width="122" height="24" rx="5" fill="none" stroke="{OUTLINE}" stroke-width="5"/>
<rect x="3" y="4" width="122" height="24" rx="5" fill="none" stroke="url(#fb_g)" stroke-width="2"/>
<path d="M3 16 l-2.6 0 M125 16 l2.6 0" stroke="#F3D08A" stroke-width="2"/>""",
    (14, 12, 114, 20),
)

# Liquid bar fill: white with a glossy top band and darker floor (tinted, 9-slice).
sprite(
    "bar_fill", 64, 16,
    """<defs><linearGradient id="bf" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.38" stop-color="#E6E6E6"/><stop offset="0.62" stop-color="#C4C4C4"/><stop offset="1" stop-color="#8E8E8E"/></linearGradient></defs>
<rect x="0" y="0" width="64" height="16" rx="3" fill="url(#bf)"/>
<rect x="2" y="2" width="60" height="3" rx="1.5" fill="#FFFFFF" opacity="0.65"/>""",
    (6, 6, 58, 10),
)

# Leather plaque for panel titles (9-slice): dark fill, gilt edge, notched ends.
sprite(
    "plaque", 160, 48,
    f"""<defs>{gold('pq_g')}<linearGradient id="pq_f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3C2C21"/><stop offset="1" stop-color="#1E150F"/></linearGradient></defs>
<path d="M14 4 H146 L156 24 L146 44 H14 L4 24 Z" fill="url(#pq_f)" stroke="{OUTLINE}" stroke-width="5" stroke-linejoin="round"/>
<path d="M14 4 H146 L156 24 L146 44 H14 L4 24 Z" fill="none" stroke="url(#pq_g)" stroke-width="2" stroke-linejoin="round"/>
<path d="M18 9 H142 L149 24 L142 39 H18 L11 24 Z" fill="none" stroke="#8A6630" stroke-width="1" opacity="0.8"/>""",
    (30, 14, 130, 34),
)

# Crimson ribbon banner with folded tails (3-slice horizontally).
sprite(
    "ribbon", 256, 72,
    f"""<defs>{gold('rb_g')}<linearGradient id="rb_f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C2403A"/><stop offset="0.55" stop-color="#8E2622"/><stop offset="1" stop-color="#5E1714"/></linearGradient>
<linearGradient id="rb_t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7A201C"/><stop offset="1" stop-color="#3E0E0C"/></linearGradient></defs>
<path d="M4 22 H40 V62 H4 L16 42 Z" fill="url(#rb_t)" stroke="{OUTLINE}" stroke-width="4" stroke-linejoin="round"/>
<path d="M252 22 H216 V62 H252 L240 42 Z" fill="url(#rb_t)" stroke="{OUTLINE}" stroke-width="4" stroke-linejoin="round"/>
<path d="M40 62 L28 54 V22 L40 22Z M216 62 L228 54 V22 L216 22Z" fill="#2C0807" stroke="{OUTLINE}" stroke-width="3" stroke-linejoin="round"/>
<rect x="28" y="8" width="200" height="46" rx="3" fill="url(#rb_f)" stroke="{OUTLINE}" stroke-width="4"/>
<path d="M28 13 H228 M28 49 H228" stroke="url(#rb_g)" stroke-width="2"/>
<rect x="28" y="8" width="200" height="46" rx="3" fill="none" stroke="#F3D08A" stroke-opacity="0.35" stroke-width="1"/>""",
    (60, 8, 196, 54),
)

# Bookmark tab (white, tinted) with a swallow-tail bottom; stretches horizontally.
sprite(
    "tab", 96, 64,
    """<path d="M6 2 H90 Q94 2 94 6 V62 L48 52 L2 62 V6 Q2 2 6 2 Z" fill="#FFFFFF"/>""",
    (16, 12, 80, 40),
)

# Circular gilt medallion with studs; transparent centre.
_studs = "".join(
    f'<circle cx="{64 + 55 * math.cos(a):.2f}" cy="{64 + 55 * math.sin(a):.2f}" r="4.2" fill="url(#md_g)" stroke="{OUTLINE}" stroke-width="1.8"/>'
    for a in (math.pi * k / 2 - math.pi / 2 for k in range(4))
)
sprite(
    "medallion", 128, 128,
    f"""<defs>{gold('md_g', 0, 0, 1, 1)}</defs>
<circle cx="64" cy="64" r="55" fill="none" stroke="{OUTLINE}" stroke-width="12"/>
<circle cx="64" cy="64" r="55" fill="none" stroke="url(#md_g)" stroke-width="7"/>
<circle cx="64" cy="64" r="49" fill="none" stroke="#8A6630" stroke-width="1.4"/>
<circle cx="64" cy="64" r="60.5" fill="none" stroke="#F3D08A" stroke-opacity="0.5" stroke-width="1"/>
{_studs}""",
)

# Skill node frames: round (passive), diamond (active), star keystone. Gilt, transparent centre.
sprite(
    "node_round", 112, 112,
    f"""<defs>{gold('nr_g', 0, 0, 1, 1)}</defs>
<circle cx="56" cy="56" r="47" fill="none" stroke="{OUTLINE}" stroke-width="11"/>
<circle cx="56" cy="56" r="47" fill="none" stroke="url(#nr_g)" stroke-width="5.5"/>
<circle cx="56" cy="56" r="42" fill="none" stroke="#5E4630" stroke-width="1.2"/>""",
)
sprite(
    "node_diamond", 112, 112,
    f"""<defs>{gold('nd_g', 0, 0, 1, 1)}</defs>
<path d="M56 5 L107 56 L56 107 L5 56 Z" fill="none" stroke="{OUTLINE}" stroke-width="11" stroke-linejoin="round"/>
<path d="M56 5 L107 56 L56 107 L5 56 Z" fill="none" stroke="url(#nd_g)" stroke-width="5.5" stroke-linejoin="round"/>
<path d="M56 13 L99 56 L56 99 L13 56 Z" fill="none" stroke="#5E4630" stroke-width="1.2"/>
<circle cx="56" cy="5" r="4" fill="#F3D08A" stroke="{OUTLINE}" stroke-width="1.6"/><circle cx="56" cy="107" r="4" fill="#F3D08A" stroke="{OUTLINE}" stroke-width="1.6"/>""",
)
_star = " ".join(
    f"{64 + (58 if k % 2 == 0 else 46) * math.cos(math.pi * k / 8 - math.pi / 2):.2f},{64 + (58 if k % 2 == 0 else 46) * math.sin(math.pi * k / 8 - math.pi / 2):.2f}"
    for k in range(16)
)
sprite(
    "node_keystone", 128, 128,
    f"""<defs>{gold('nk_g', 0, 0, 1, 1)}</defs>
<polygon points="{_star}" fill="none" stroke="{OUTLINE}" stroke-width="10" stroke-linejoin="round"/>
<polygon points="{_star}" fill="none" stroke="url(#nk_g)" stroke-width="4.6" stroke-linejoin="round"/>
<circle cx="64" cy="64" r="41" fill="none" stroke="url(#nk_g)" stroke-width="2.4"/>""",
)

# Plain shapes (white, tinted): ring for progress / cooldown, disc, diamond fill, soft glow, rays.
sprite("ring", 128, 128, '<circle cx="64" cy="64" r="56" fill="none" stroke="#FFFFFF" stroke-width="12"/>')
sprite("ring_thin", 128, 128, '<circle cx="64" cy="64" r="59" fill="none" stroke="#FFFFFF" stroke-width="5"/>')
sprite("disc", 128, 128, '<circle cx="64" cy="64" r="63" fill="#FFFFFF"/>')
sprite("diamond", 112, 112, '<path d="M56 4 L108 56 L56 108 L4 56 Z" fill="#FFFFFF"/>')
sprite(
    "glow", 128, 128,
    """<defs><radialGradient id="gl" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF" stop-opacity="1"/>
<stop offset="0.35" stop-color="#FFF" stop-opacity="0.55"/><stop offset="0.7" stop-color="#FFF" stop-opacity="0.14"/><stop offset="1" stop-color="#FFF" stop-opacity="0"/></radialGradient></defs>
<rect width="128" height="128" fill="url(#gl)"/>""",
)
_rays = "".join(
    f'<path d="M128 128 L{128 + 128 * math.cos(a - 0.07):.1f} {128 + 128 * math.sin(a - 0.07):.1f} L{128 + 128 * math.cos(a + 0.07):.1f} {128 + 128 * math.sin(a + 0.07):.1f} Z" fill="url(#ry)"/>'
    for a in (math.pi * 2 * k / 16 for k in range(16))
)
sprite(
    "rays", 256, 256,
    f"""<defs><radialGradient id="ry" cx="128" cy="128" r="128" gradientUnits="userSpaceOnUse"><stop offset="0.1" stop-color="#FFF" stop-opacity="0.9"/><stop offset="1" stop-color="#FFF" stop-opacity="0"/></radialGradient></defs>{_rays}""",
)

# Small gem (tinted) and gold pip used as selection indicators.
sprite(
    "gem", 48, 48,
    f"""<path d="M24 3 L44 20 L24 45 L4 20 Z" fill="#E8E8E8" stroke="{OUTLINE}" stroke-width="3" stroke-linejoin="round"/>
<path d="M4 20 H44 M14 20 L24 3 L34 20 L24 45 Z" fill="none" stroke="#7A7A7A" stroke-width="1.4" stroke-linejoin="round"/>
<path d="M14 20 L24 3 L34 20 Z" fill="#FFFFFF"/><path d="M24 45 L34 20 H44 Z" fill="#9E9E9E"/>""",
)
sprite(
    "pip", 24, 24,
    f"""<defs>{gold('pp_g', 0, 0, 1, 1)}</defs><path d="M12 2 L22 12 L12 22 L2 12 Z" fill="url(#pp_g)" stroke="{OUTLINE}" stroke-width="2" stroke-linejoin="round"/>""",
)

# Ornament for the centre of a divider rule.
sprite(
    "divider_mark", 96, 24,
    f"""<defs>{gold('dv_g', 0, 0, 1, 0, ("#8A6630", "#F3D08A", "#FBEBC4", "#F3D08A", "#8A6630"))}</defs>
<path d="M4 12 Q24 4 38 12 Q24 20 4 12Z M92 12 Q72 4 58 12 Q72 20 92 12Z" fill="url(#dv_g)" stroke="{OUTLINE}" stroke-width="1.6"/>
<path d="M48 2 L58 12 L48 22 L38 12Z" fill="url(#dv_g)" stroke="{OUTLINE}" stroke-width="2" stroke-linejoin="round"/>
<path d="M48 7 L53 12 L48 17 L43 12Z" fill="#E5484D" stroke="{OUTLINE}" stroke-width="1"/>""",
)

# Tooltip caret (white, tinted).
sprite("caret", 32, 16, '<path d="M0 0 H32 L16 16 Z" fill="#FFFFFF"/>')

# Wax seal (crimson, blank centre for a glyph).
_seal = " ".join(
    f"{64 + (58 if k % 2 == 0 else 52) * math.cos(math.pi * k / 12):.2f},{64 + (58 if k % 2 == 0 else 52) * math.sin(math.pi * k / 12):.2f}"
    for k in range(24)
)
sprite(
    "seal", 128, 128,
    f"""<defs><radialGradient id="sl" cx="0.38" cy="0.32" r="0.75"><stop offset="0" stop-color="#E2564F"/><stop offset="0.55" stop-color="#A52A25"/><stop offset="1" stop-color="#5E1310"/></radialGradient></defs>
<polygon points="{_seal}" fill="url(#sl)" stroke="{OUTLINE}" stroke-width="4" stroke-linejoin="round"/>
<circle cx="64" cy="64" r="38" fill="none" stroke="#5E1310" stroke-width="5"/>
<circle cx="64" cy="64" r="38" fill="none" stroke="#F08A80" stroke-opacity="0.45" stroke-width="1.5"/>""",
)

# Heraldic shield for class crests (white, tinted).
sprite(
    "crest", 128, 144,
    f"""<path d="M64 6 L118 22 V66 Q118 112 64 138 Q10 112 10 66 V22 Z" fill="#FFFFFF" stroke="{OUTLINE}" stroke-width="5" stroke-linejoin="round"/>
<path d="M64 16 L108 29 V66 Q108 104 64 127 Q20 104 20 66 V29 Z" fill="none" stroke="#000" stroke-opacity="0.25" stroke-width="2"/>""",
)

# Loading rune ring (white): twelve dashes with decreasing opacity.
_dash = "".join(
    f'<rect x="60" y="6" width="8" height="26" rx="4" fill="#FFF" opacity="{0.15 + 0.85 * (k / 11):.2f}" transform="rotate({k * 30} 64 64)"/>'
    for k in range(12)
)
sprite("spinner", 128, 128, _dash)

# Paperdoll silhouette for the equipment panel: a front-facing figure, dark with a gilt rim.
sprite(
    "silhouette", 256, 448,
    f"""<defs><linearGradient id="sh_f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4A3628"/><stop offset="1" stop-color="#241912"/></linearGradient>
<linearGradient id="sh_r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D4A55A" stop-opacity="0.9"/><stop offset="1" stop-color="#8A6630" stop-opacity="0.35"/></linearGradient></defs>
<path d="M128 18 C150 18 162 36 160 58 C158 78 148 90 128 92 C108 90 98 78 96 58 C94 36 106 18 128 18 Z
M84 104 C100 96 114 100 128 104 C142 100 156 96 172 104 C196 112 206 128 210 150 L224 236 C226 250 218 256 210 250 L184 168 L178 224 C182 250 186 282 184 306
L178 420 C178 432 166 436 158 430 L140 316 L128 300 L116 316 L98 430 C90 436 78 432 78 420 L72 306 C70 282 74 250 78 224 L72 168 L46 250 C38 256 30 250 32 236 L46 150 C50 128 60 112 84 104 Z"
fill="url(#sh_f)" stroke="url(#sh_r)" stroke-width="3" stroke-linejoin="round"/>
<path d="M128 112 V290 M96 140 Q128 150 160 140" fill="none" stroke="#D4A55A" stroke-opacity="0.18" stroke-width="2"/>""",
)

# Hatched stripes for disabled / locked overlays (white, tinted, tiles via slice).
sprite(
    "hatch", 32, 32,
    "".join(f'<path d="M{x} 32 L{x + 32} 0" stroke="#FFFFFF" stroke-width="3"/>' for x in range(-32, 33, 8)),
)


# ---------------------------------------------------------------- textures
def leather(size=256, seed=7) -> Image.Image:
    rnd = random.Random(seed)
    base = Image.new("L", (size, size), 128)
    px = base.load()
    for y in range(size):
        for x in range(size):
            px[x, y] = 128 + int(rnd.gauss(0, 18))
    # tile-safe blur: blur a 3x3 tiling and crop the centre
    big = Image.new("L", (size * 3, size * 3))
    for i in range(3):
        for j in range(3):
            big.paste(base, (i * size, j * size))
    grain = big.filter(ImageFilter.GaussianBlur(1.6)).crop((size, size, size * 2, size * 2))
    pores = big.filter(ImageFilter.GaussianBlur(5)).crop((size, size, size * 2, size * 2))
    out = Image.new("RGBA", (size, size))
    op = out.load()
    gp, pp = grain.load(), pores.load()
    for y in range(size):
        for x in range(size):
            v = (gp[x, y] - 128) * 1.6 + (pp[x, y] - 128) * 3.0
            a = max(0, min(255, int(abs(v) * 2.2)))
            c = 255 if v > 0 else 0
            op[x, y] = (c, c, c, a)
    return out


def parchment(size=256, seed=11) -> Image.Image:
    rnd = random.Random(seed)
    img = Image.new("RGBA", (size * 3, size * 3), (0, 0, 0, 0))
    from PIL import ImageDraw

    d = ImageDraw.Draw(img)
    for _ in range(220):
        x, y = rnd.uniform(0, size), rnd.uniform(0, size)
        ang = rnd.uniform(-0.5, 0.5)
        ln = rnd.uniform(8, 40)
        a = rnd.randint(14, 40)
        for ox in (0, size, size * 2):
            for oy in (0, size, size * 2):
                d.line([(x + ox, y + oy), (x + ox + ln * math.cos(ang), y + oy + ln * math.sin(ang))], fill=(90, 60, 30, a), width=1)
    for _ in range(60):
        x, y, r = rnd.uniform(0, size), rnd.uniform(0, size), rnd.uniform(6, 26)
        for ox in (0, size, size * 2):
            for oy in (0, size, size * 2):
                d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=(120, 80, 40, rnd.randint(4, 10)))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    return img.crop((size, size, size * 2, size * 2))


# ---------------------------------------------------------------- packing
def pack_icons():
    names = list(ICONS)
    cols = 8
    sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    rects = {}
    for i, name in enumerate(names):
        x, y = (i % cols) * 128, (i // cols) * 128
        sheet.alpha_composite(render(ICONS[name], 128, 128), (x, y))
        rects[name] = (x, y, 128, 128)
    return sheet, rects


def pack_chrome():
    sheet = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    rects, slices = {}, {}
    pad = 2
    items = sorted(CHROME.items(), key=lambda kv: -kv[1][1])
    x = y = shelf = 0
    for name, (w, h, body, sl) in items:
        if x + w > 1024:
            x, y, shelf = 0, y + shelf + pad, 0
        img = render(body, w, h)
        sheet.alpha_composite(img, (x, y))
        rects[name] = (x, y, w, h)
        if sl:
            slices[name] = sl
        x += w + pad
        shelf = max(shelf, h)
    # glyphs in a 64 px grid below
    y += shelf + pad
    x = 0
    for name, body in GLYPHS.items():
        if x + 64 > 1024:
            x, y = 0, y + 64 + pad
        sheet.alpha_composite(render(body, 64, 64), (x, y))
        rects["g_" + name] = (x, y, 64, 64)
        x += 64 + pad
    assert y + 64 <= 1024, f"chrome atlas overflow ({y + 64})"
    return sheet, rects, slices


def luau_map(icon_rects, chrome_rects, slices, ids):
    def rect_tbl(rects):
        lines = []
        for k, (x, y, w, h) in sorted(rects.items()):
            sl = slices.get(k)
            s = f", slice = Rect.new({sl[0]}, {sl[1]}, {sl[2]}, {sl[3]})" if sl else ""
            lines.append(f'\t\t["{k}"] = {{ x = {x}, y = {y}, w = {w}, h = {h}{s} }},')
        return "\n".join(lines)

    return f"""--!strict
-- GENERATED by art/build_atlas.py. Do not edit by hand.
-- Image ids: rbxasset:// paths work inside Studio after art/install_local.py; rbxassetid:// after upload.
return {{
	images = {{ {", ".join(f'{k} = "{v}"' for k, v in ids.items())} }},
	icons = {{
{rect_tbl(icon_rects)}
	}},
	chrome = {{
{rect_tbl(chrome_rects)}
	}},
}}
"""


def main():
    OUT.mkdir(exist_ok=True)
    icons, icon_rects = pack_icons()
    icons.save(OUT / "vellum_icons.png")
    chrome, chrome_rects, slices = pack_chrome()
    chrome.save(OUT / "vellum_chrome.png")
    leather().save(OUT / "vellum_leather.png")
    parchment().save(OUT / "vellum_parchment.png")
    ids_file = ART / "asset_ids.json"
    ids = json.loads(ids_file.read_text()) if ids_file.exists() else {}
    # Local copies carry a content hash in their name: Studio caches rbxasset textures by path.
    import hashlib
    import shutil

    local_dir = OUT / "local"
    shutil.rmtree(local_dir, ignore_errors=True)
    local_dir.mkdir()
    local = {}
    for k in ("icons", "chrome", "leather", "parchment"):
        src = OUT / f"vellum_{k}.png"
        h = hashlib.sha1(src.read_bytes()).hexdigest()[:8]
        shutil.copy2(src, local_dir / f"vellum_{k}_{h}.png")
        local[k] = f"rbxasset://textures/vellum/vellum_{k}_{h}.png"
    ids = {k: ids.get(k, local[k]) for k in local}
    (ROOT / "src/ReplicatedStorage/Vellum/AtlasMap.module.luau").write_text(luau_map(icon_rects, chrome_rects, slices, ids), encoding="utf-8")
    print(f"icons {len(icon_rects)}, chrome {len(chrome_rects)} ({len(GLYPHS)} glyphs), ids: {ids}")


if __name__ == "__main__":
    main()
