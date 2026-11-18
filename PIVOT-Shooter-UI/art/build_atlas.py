#!/usr/bin/env python3
"""PIVOT UI atlas: original icons, emblems, 9-slice shapes and FX in one 1024x1024 white-on-transparent PNG.

Everything is tinted in Roblox with ImageColor3, so one upload covers the whole UI.
Outputs:
  art/pivot_atlas.svg / art/pivot_atlas.png  (the sheet)
  art/atlas_map.lua                         (Luau table: name -> {x, y, w, h}, pasted into PivotUI.Icons)
Run: python3 art/build_atlas.py
"""
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024
CELL = 64  # icon cell, 24-unit design grid drawn at 64 px with 4 px padding
STROKE = 'fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'
FILL = 'fill="#fff"'


def s(d):
    return f'<path d="{d}" {STROKE}/>'


def f(d, rule="nonzero"):
    return f'<path d="{d}" {FILL} fill-rule="{rule}"/>'


def circ(cx, cy, r, filled=False):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" {FILL if filled else STROKE}/>'


def rect(x, y, w, h, rx=0, filled=False):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" {FILL if filled else STROKE}/>'


# 24x24 design grid, 2 px strokes with round ends. One consistent line style for the whole set.
ICONS = {
    "home": s("M3.5 10.5 12 3.5l8.5 7") + s("M5.5 9.2V20h13V9.2") + s("M10 20v-5.5h4V20"),
    "play": f("M8 4.8v14.4L19.5 12z"),
    "armory": circ(12, 12, 7) + s("M12 2v4M12 18v4M2 12h4M18 12h4") + circ(12, 12, 1.3, True),
    "shop": s("M5 8.5h14l-1.2 11.5H6.2z") + s("M9 8.5V6.8a3 3 0 0 1 6 0v1.7"),
    "missions": s("M10 6.5h10M10 12h10M10 17.5h10") + s("M3.8 6.4l1.4 1.4 2.4-2.6M3.8 11.9l1.4 1.4 2.4-2.6M3.8 17.4l1.4 1.4 2.4-2.6"),
    "profile": circ(12, 8, 4) + s("M4 20.5c1.4-4 4.4-6 8-6s6.6 2 8 6"),
    "settings": s("M18.80 10.34 L21.49 10.57 L21.49 13.43 L18.80 13.66 L17.98 15.63 L19.73 17.70 L17.70 19.73 L15.63 17.98 L13.66 18.80 L13.43 21.49 L10.57 21.49 L10.34 18.80 L8.37 17.98 L6.30 19.73 L4.27 17.70 L6.02 15.63 L5.20 13.66 L2.51 13.43 L2.51 10.57 L5.20 10.34 L6.02 8.37 L4.27 6.30 L6.30 4.27 L8.37 6.02 L10.34 5.20 L10.57 2.51 L13.43 2.51 L13.66 5.20 L15.63 6.02 L17.70 4.27 L19.73 6.30 L17.98 8.37Z") + circ(12, 12, 3),
    "credits": f("M12 2 22 12 12 22 2 12zM12 7.2 16.8 12 12 16.8 7.2 12z", "evenodd"),
    "xp": s("M6 12.5l6-6 6 6") + s("M6 18.5l6-6 6 6"),
    "lock": rect(5, 10.5, 14, 10, 2) + s("M8.5 10.5V7.5a3.5 3.5 0 0 1 7 0v3") + circ(12, 15.5, 1.2, True),
    "check": s("M4.5 12.5 9.5 17.5 19.5 6.5"),
    "close": s("M6.5 6.5l11 11M17.5 6.5l-11 11"),
    "plus": s("M12 5v14M5 12h14"),
    "minus": s("M5 12h14"),
    "chevronLeft": s("M14.5 5.5 8 12l6.5 6.5"),
    "chevronRight": s("M9.5 5.5 16 12l-6.5 6.5"),
    "chevronDown": s("M5.5 9.5 12 16l6.5-6.5"),
    "chevronUp": s("M5.5 14.5 12 8l6.5 6.5"),
    "arrowLeft": s("M19 12H5M11 6l-6 6 6 6"),
    "arrowRight": s("M5 12h14M13 6l6 6-6 6"),
    "search": circ(10.8, 10.8, 6.3) + s("M15.6 15.6l4.6 4.6"),
    "filter": s("M4 6.5h16M7 12h10M10 17.5h4"),
    "star": f("M12 2.8l2.8 5.7 6.3.9-4.6 4.4 1.1 6.2L12 17l-5.6 3 1.1-6.2-4.6-4.4 6.3-.9z"),
    "info": circ(12, 12, 9) + s("M12 11v5.5") + circ(12, 7.6, 1.2, True),
    "warning": s("M12 3.5 21.5 20h-19z") + s("M12 10v4") + circ(12, 17, 1.2, True),
    "wifi": s("M2.8 9.2a13.5 13.5 0 0 1 18.4 0M5.8 12.6a9 9 0 0 1 12.4 0M8.8 16a4.6 4.6 0 0 1 6.4 0") + circ(12, 19.3, 1.3, True),
    "wifiOff": s("M2.8 9.2a13.5 13.5 0 0 1 18.4 0M5.8 12.6a9 9 0 0 1 12.4 0M8.8 16a4.6 4.6 0 0 1 6.4 0") + s("M3.5 3.5l17 17"),
    "refresh": s("M19.5 11.5a7.5 7.5 0 1 1-2.2-5.3") + s("M19.5 4.5v5h-5"),
    "clock": circ(12, 12, 9) + s("M12 7v5l3.2 2"),
    "users": circ(9, 8, 3.4) + s("M2.6 19.5c.8-3.4 3.2-5.3 6.4-5.3s5.6 1.9 6.4 5.3") + circ(17, 8.6, 2.6) + s("M17.2 13.8c2.3.1 3.8 1.8 4.3 4.3"),
    "userPlus": circ(10, 8, 3.8) + s("M3 20.5c1.2-3.9 3.8-5.8 7-5.8 1.2 0 2.4.3 3.4.9") + s("M18.5 13.5v6M15.5 16.5h6"),
    "logout": s("M14 4H6v16h8") + s("M10 12h10.5M16.5 8l4 4-4 4"),
    "crown": s("M3.5 17.5 2.5 7.5l5 3.8L12 4.5l4.5 6.8 5-3.8-1 10z") + s("M3.5 20.5h17"),
    "skull": s("M12 3c-4.4 0-8 3.1-8 7.3 0 2.6 1.3 4.4 3 5.4v3.3h10v-3.3c1.7-1 3-2.8 3-5.4C20 6.1 16.4 3 12 3z")
    + circ(9, 11, 1.7, True) + circ(15, 11, 1.7, True) + s("M10.3 19v2M13.7 19v2"),
    "eye": s("M2.5 12s3.5-6.2 9.5-6.2 9.5 6.2 9.5 6.2-3.5 6.2-9.5 6.2S2.5 12 2.5 12z") + circ(12, 12, 2.8),
    "pause": rect(6, 5, 4, 14, 1, True) + rect(14, 5, 4, 14, 1, True),
    "trophy": s("M7.5 4h9v5a4.5 4.5 0 0 1-9 0z") + s("M7.5 6H4.5a3 3 0 0 0 3 4M16.5 6h3a3 3 0 0 1-3 4") + s("M12 13.5v4M8.5 20.5h7M9.5 17.5h5"),
    "shield": s("M12 3 19.5 6v5.8c0 4.4-3.2 7.9-7.5 9.2-4.3-1.3-7.5-4.8-7.5-9.2V6z"),
    "health": f("M9.2 3.5h5.6v5.7h5.7v5.6h-5.7v5.7H9.2v-5.7H3.5V9.2h5.7z"),
    "bullet": s("M9 20.5V10c0-2.8 1.2-5.2 3-6.6 1.8 1.4 3 3.8 3 6.6v10.5z") + s("M9 16.5h6"),
    "reload": s("M4.5 11a7.5 7.5 0 0 1 13.2-4.2L19.5 9M19.5 4v5h-5") + s("M19.5 13a7.5 7.5 0 0 1-13.2 4.2L4.5 15M4.5 20v-5h5"),
    "swap": s("M7.5 3.5 3.5 7.5l4 4M3.5 7.5h13") + s("M16.5 12.5l4 4-4 4M20.5 16.5h-13"),
    "crate": s("M3.5 7.8 12 3.2l8.5 4.6v8.4L12 20.8l-8.5-4.6z") + s("M3.5 7.8 12 12.4l8.5-4.6M12 12.4v8.4"),
    "medkit": rect(3, 7, 18, 13, 2) + s("M9 7V4.5h6V7") + s("M12 10.5v6M9 13.5h6"),
    "aim": circ(12, 12, 4.2) + s("M12 2.5v5M12 16.5v5M2.5 12h5M16.5 12h5"),
    "fire": circ(12, 12, 2.6, True) + s("M12 2.8v3.4M12 17.8v3.4M2.8 12h3.4M17.8 12h3.4M5.5 5.5l2.4 2.4M16.1 16.1l2.4 2.4M5.5 18.5l2.4-2.4M16.1 7.9l2.4-2.4"),
    "scoreboard": rect(3, 4, 18, 16, 1.5) + s("M3 9h18M9 9v11"),
    "map": s("M9 4.5 3.5 6.5v13l5.5-2 6 2 5.5-2v-13l-5.5 2z") + s("M9 4.5v13M15 6.5v13"),
    "compare": s("M7.5 20V5M4 8.5l3.5-3.5L11 8.5") + s("M16.5 4v15M13 15.5l3.5 3.5 3.5-3.5"),
    "receipt": s("M6 3h12v18l-3-2-3 2-3-2-3 2z") + s("M9 8h6M9 12h6M9 16h3"),
    "gift": rect(3.5, 8, 17, 4.5, 1) + s("M5.5 12.5v8h13v-8M12 8v12.5") + s("M12 8C11 5 7 4.2 7 6.4S12 8 12 8zM12 8c1-3 5-3.8 5-1.6S12 8 12 8z"),
    "sound": s("M4 9.5h3.5L12.5 5.5v13l-5-4H4z") + s("M16 9a4.5 4.5 0 0 1 0 6M18.6 6.5a8 8 0 0 1 0 11"),
    "monitor": rect(3, 4, 18, 12, 1.5) + s("M8 20h8M12 16v4"),
    "mouse": rect(7, 3, 10, 18, 5) + s("M12 7v3"),
    "layout": rect(3, 4, 18, 16, 2) + s("M3 9h18M8.5 9v11"),
    "accessibility": circ(12, 4.6, 1.8, True) + s("M5 8.6l7 1.6 7-1.6M12 10.2v5M12 15.2 8.6 21M12 15.2l3.4 5.8"),
    "keyboard": rect(2.5, 6, 19, 12, 2) + s("M6.5 10h.01M10 10h.01M13.5 10h.01M17 10h.01M7 14h10"),
    "touch": s("M9 11V4.8a1.5 1.5 0 0 1 3 0V11M12 10.5V9a1.5 1.5 0 0 1 3 0v2M15 10.6a1.5 1.5 0 0 1 3 0V15c0 3.4-2.5 6-6 6h-.8c-2.3 0-3.7-1-4.9-2.9L4 14.3c-.6-1 .7-2.1 1.6-1.4L9 15.5"),
    "flag": s("M5.5 21V3.8") + s("M5.5 4h12l-3 4.5 3 4.5h-12"),
    "bolt": f("M13.5 2 4.5 13.5h6.5L10 22l9.5-11.5H13z"),
    "duel": s("M4 4l10 10M20 4 10 14") + s("M12 16.5l4.5-4.5M7.5 12l4.5 4.5") + s("M14 14l4.5 4.5M10 14l-4.5 4.5"),
    "target": circ(12, 12, 9) + circ(12, 12, 5) + circ(12, 12, 1.4, True),
    "dot": circ(12, 12, 5, True),
    "menu": s("M4 6.5h16M4 12h16M4 17.5h16"),
    "history": s("M3.5 12a8.5 8.5 0 1 0 2.6-6.1") + s("M3.5 4v4.5H8") + s("M12 8v4.2l3 1.8"),
    "external": s("M14 4h6v6M20 4l-9 9M18 14v6H4V6h6"),
    "palette": s("M12 3a9 9 0 1 0 0 18c1.4 0 2-1 1.5-2.2-.6-1.4.3-2.8 1.8-2.8H18a3 3 0 0 0 3-3C21 7 17 3 12 3z") + circ(7.5, 11, 1.2, True) + circ(10, 7, 1.2, True) + circ(15, 7.5, 1.2, True),
    "tag": s("M3.5 12.5V4h8.5l8.5 8.5-8 8z") + circ(8, 8.5, 1.4, True),
    "sparkle": f("M12 2.5c.8 4.6 2.9 6.7 7.5 7.5-4.6.8-6.7 2.9-7.5 7.5-.8-4.6-2.9-6.7-7.5-7.5 4.6-.8 6.7-2.9 7.5-7.5z"),
    "ready": circ(12, 12, 9) + s("M7.5 12.3l3 3 6-6.5"),
    "notReady": circ(12, 12, 9) + s("M12 7.5v5.2") + circ(12, 16.3, 1.2, True),
    "hourglass": s("M6.5 3.5h11M6.5 20.5h11M7.5 3.5c0 5 9 5.5 9 8.5s-9 3.5-9 8.5M16.5 3.5c0 5-9 5.5-9 8.5s9 3.5 9 8.5"),
    "gamepadOff": s("M3 3l18 18"),
    "kick": s("M4 20.5c1.2-3.9 3.8-5.8 7-5.8") + circ(11, 8, 3.8) + s("M16 14.5l5 5M21 14.5l-5 5"),
    "scope": circ(12, 12, 8) + s("M12 4v5M12 15v5M4 12h5M15 12h5"),
    "rotate": s("M4 12a8 8 0 0 1 14-5.3M20 12a8 8 0 0 1-14 5.3") + s("M18 3v4h-4M6 21v-4h4"),
    # rank insignia for the best player of the match: two chevrons under a star
    "mvp": f("M12 1.8l1.6 3.3 3.6.5-2.6 2.5.6 3.6L12 10l-3.2 1.7.6-3.6-2.6-2.5 3.6-.5z") + s("M4.5 14l7.5 4 7.5-4M4.5 19l7.5 4 7.5-4"),
}

# 48-unit grid, drawn in 128 px cells.
EMBLEMS = {
    "emblem_pivot": f("M24 3 45 24 24 45 3 24zM24 9.5 38.5 24 24 38.5 9.5 24z", "evenodd") + f("M24 15 33 24 24 33z"),
    "emblem_hawk": f("M3 12 24 24 45 12 39.5 29 24 42 8.5 29zM24 30.5 31.5 26.5 24 35.5 16.5 26.5z", "evenodd") + f("M20 6h8l-4 7z"),
    "emblem_bolt": f("M24 3 42 13.5v21L24 45 6 34.5v-21zM24 8.6 10.8 16.3v15.4L24 39.4l13.2-7.7V16.3z", "evenodd") + f("M26.5 12 16 26.5h7L21 36l11-14.5h-7z"),
    "emblem_crown": f("M7 35 5 15l10 8 9-13 9 13 10-8-2 20z") + f("M7 38h34v4H7z"),
    "logo": f("M24 2 46 24 24 46 2 24zM24 9 39 24 24 39 9 24z", "evenodd") + f("M24 17 31 24 24 31 17 24z"),
}


def cell_svg(x, y, size, body, grid):
    k = (size - 8) / grid
    return f'<g transform="translate({x + 4},{y + 4}) scale({k})">{body}</g>'


def build():
    parts = []
    mapping = {}
    # icons: rows of 16 starting at y=0
    for i, (name, body) in enumerate(ICONS.items()):
        x, y = (i % 16) * CELL, (i // 16) * CELL
        assert y < 384, "too many icons"
        parts.append(cell_svg(x, y, CELL, body, 24))
        mapping[name] = (x, y, CELL, CELL)
    # emblems + logo, 128 px cells at y=384
    for i, (name, body) in enumerate(EMBLEMS.items()):
        x, y = i * 128, 384
        parts.append(cell_svg(x, y, 128, body, 48))
        mapping[name] = (x, y, 128, 128)
    # FX at y=384 after the emblems
    x0 = len(EMBLEMS) * 128
    # hitmarker: four diagonal ticks
    hm = "".join(
        f'<line x1="{a}" y1="{b}" x2="{c}" y2="{d}" stroke="#fff" stroke-width="9" stroke-linecap="round"/>'
        for a, b, c, d in [(30, 30, 50, 50), (98, 30, 78, 50), (30, 98, 50, 78), (98, 98, 78, 78)]
    )
    parts.append(f'<g transform="translate({x0},384)">{hm}</g>')
    mapping["hitmarker"] = (x0, 384, 128, 128)
    # damage direction arc at the top of a 128 cell (rotated around the cell centre in Roblox)
    parts.append(
        f'<g transform="translate({x0 + 128},384)"><path d="M33.1 21.4 A52 52 0 0 1 94.9 21.4 L88.6 30.9 A40.5 40.5 0 0 0 39.4 30.9 Z" fill="#fff"/></g>'
    )
    mapping["damageArc"] = (x0 + 128, 384, 128, 128)
    # ring and spinner arc
    parts.append(f'<g transform="translate({x0 + 256},384)"><circle cx="64" cy="64" r="54" fill="none" stroke="#fff" stroke-width="7"/></g>')
    mapping["ring"] = (x0 + 256, 384, 128, 128)
    # spinner: 270 degree arc
    parts.append(
        f'<g transform="translate(0,512)"><path d="M64 14 A50 50 0 1 1 14 64" fill="none" stroke="#fff" stroke-width="11" stroke-linecap="round"/></g>'
    )
    mapping["spinner"] = (0, 512, 128, 128)
    # 9-slice shapes, 128 px cells at y=512 (SliceCenter 32..96)
    # "Dock manifest" plate: square corners, a small notch top-left and a long chamfer bottom-right,
    # so every panel leans forward the same way (read direction -> action).
    r = 8
    panel = "M14 4 H122 Q124 4 124 6 V100 L100 124 H6 Q4 124 4 122 V14 Z"
    # secondary buttons: two opposite square chamfers, no rounding
    btn = "M20 4 H124 V108 L108 124 H4 V20 Z"
    shapes = [
        ("panelCut", f'<path d="{panel}" fill="#fff"/>'),
        ("panelCutStroke", f'<path d="{panel}" fill="none" stroke="#fff" stroke-width="3" transform="translate(64 64) scale(0.976) translate(-64 -64)"/>'),
        ("btnCut", f'<path d="{btn}" fill="#fff"/>'),
        ("btnCutStroke", f'<path d="{btn}" fill="none" stroke="#fff" stroke-width="3" transform="translate(64 64) scale(0.976) translate(-64 -64)"/>'),
        ("pill", '<rect x="4" y="4" width="120" height="120" rx="60" fill="#fff"/>'),
        ("rounded", f'<rect x="4" y="4" width="120" height="120" rx="{r * 2}" fill="#fff"/>'),
        ("roundedStroke", f'<rect x="5.5" y="5.5" width="117" height="117" rx="{r * 2}" fill="none" stroke="#fff" stroke-width="3"/>'),
    ]
    for i, (name, body) in enumerate(shapes):
        x = 128 + i * 128
        parts.append(f'<g transform="translate({x},512)">{body}</g>')
        mapping[name] = (x, 512, 128, 128)
    # two-tone shapes: fill at 62% grey + white border, so one tinted image gives a panel whose
    # border is lighter than its fill (tint = border colour, fill = tint x 0.62).
    tone_fill = "#9E9E9E"
    for name, d, x in (("panelTone", panel, 768), ("btnTone", btn, 896)):
        # plus a light rail just under the top edge: the bevel that makes the plate read as metal
        rail = '<path d="M16 10.5 H118" stroke="#D2D2D2" stroke-width="2.2"/>' if name == "panelTone" else ""
        parts.append(
            f'<g transform="translate({x},640)"><path d="{d}" fill="#fff"/>'
            f'<path d="{d}" fill="{tone_fill}" transform="translate(64 64) scale(0.953) translate(-64 -64)"/>{rail}</g>'
        )
        mapping[name] = (x, 640, 128, 128)
    # soft glow + vignette (radial gradients)
    parts.append(
        '<defs>'
        '<radialGradient id="glow"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
        '<radialGradient id="vig" r="0.72"><stop offset="0.45" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="1"/></radialGradient>'
        '<linearGradient id="fadeR"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
        '</defs>'
    )
    parts.append('<rect x="0" y="640" width="128" height="128" fill="url(#glow)"/>')
    mapping["glow"] = (0, 640, 128, 128)
    parts.append('<rect x="0" y="768" width="256" height="256" fill="url(#vig)"/>')
    mapping["vignette"] = (0, 768, 256, 256)
    # card patterns for banners, 256x128 each, light lines (drawn at low opacity in Roblox)
    pats = {}
    pats["pattern_grid"] = "".join(f'<path d="M{x} 0V128" stroke="#fff" stroke-width="1.5"/>' for x in range(8, 256, 16)) + "".join(
        f'<path d="M0 {y}H256" stroke="#fff" stroke-width="1.5"/>' for y in range(8, 128, 16)
    )
    pats["pattern_tape"] = "".join(f'<path d="M{x} 128 L{x + 128} 0" stroke="#fff" stroke-width="10"/>' for x in range(-128, 256, 36))
    pats["pattern_contour"] = "".join(
        f'<path d="M-10 {y} C40 {y - 22} 80 {y + 22} 128 {y} S216 {y - 20} 266 {y}" fill="none" stroke="#fff" stroke-width="2"/>'
        for y in range(6, 140, 14)
    )
    pats["pattern_ember"] = "".join(
        f'<circle cx="{(i * 7919 * 13) % 251}" cy="{(i * 104729 * 7) % 127}" r="{1.2 + (i * 31 % 5) * 0.6}" fill="#fff"/>' for i in range(1, 80)
    )
    for i, (name, body) in enumerate(pats.items()):
        x, y = 256 + (i % 2) * 256, 640 + (i // 2) * 128
        parts.append(f'<svg x="{x}" y="{y}" width="256" height="128" viewBox="0 0 256 128" overflow="hidden">{body}</svg>')
        mapping[name] = (x, y, 256, 128)
    # horizontal fade strip (for panel highlights, kill feed rows)
    parts.append('<rect x="256" y="896" width="512" height="32" fill="url(#fadeR)"/>')
    mapping["fadeRight"] = (256, 896, 512, 32)
    # diagonal hatch for locked / disabled states, 128 px (stretched, not tiled)
    hatch = "".join(f'<path d="M{x} 128 L{x + 128} 0" stroke="#fff" stroke-width="5"/>' for x in range(-128, 128, 14))
    parts.append(f'<svg x="128" y="640" width="128" height="128" viewBox="0 0 128 128" overflow="hidden">{hatch}</svg>')
    mapping["hatch"] = (128, 640, 128, 128)

    # ---- "dock manifest" pieces (free 128 cells at 768..1024 x 768..1024, strip below fadeRight)
    # scope brackets: four L corners, transparent middle (9-slice 40..88), framed around hero panels
    br = "M6 34V6H34M94 6H122V34M122 94V122H94M34 122H6V94"
    parts.append(f'<g transform="translate(768,768)"><path d="{br}" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="square"/></g>')
    mapping["brackets"] = (768, 768, 128, 128)
    # primary button: parallelogram leaning forward (leading edge in the 9-slice side columns)
    slant = "M28 4H124L100 124H4Z"
    parts.append(f'<g transform="translate(896,768)"><path d="{slant}" fill="#fff"/></g>')
    mapping["btnSlant"] = (896, 768, 128, 128)
    parts.append(f'<g transform="translate(768,896)"><path d="M29.2 5.5H122.2L98.8 122.5H5.8Z" fill="none" stroke="#fff" stroke-width="3" stroke-linejoin="miter"/></g>')
    mapping["btnSlantStroke"] = (768, 896, 128, 128)
    # cargo tag: pointed left end with a punched eyelet
    tag = "M4 64L30 4H118Q124 4 124 10V118Q124 124 118 124H30Z M41 64a9 9 0 1 0-18 0a9 9 0 1 0 18 0Z"
    parts.append(f'<g transform="translate(896,896)"><path d="{tag}" fill="#fff" fill-rule="evenodd"/></g>')
    mapping["tagCargo"] = (896, 896, 128, 128)
    # rubber stamp: heavy outer ring + thin inner ring, eroded by a fixed speckle mask (128x96, 9-slice)
    specks = "".join(
        f'<circle cx="{(i * 7907) % 128}" cy="{(i * 3571) % 96}" r="{0.7 + (i * 17 % 7) * 0.32:.2f}" fill="#000"/>' for i in range(1, 140)
    )
    parts.append(
        '<defs><mask id="erode" maskUnits="userSpaceOnUse" x="0" y="0" width="128" height="96">'
        f'<rect width="128" height="96" fill="#fff"/>{specks}</mask></defs>'
        '<g transform="translate(256,928)"><g mask="url(#erode)">'
        '<rect x="6" y="6" width="116" height="84" rx="9" fill="none" stroke="#fff" stroke-width="7"/>'
        '<rect x="15.5" y="15.5" width="97" height="65" rx="4" fill="none" stroke="#fff" stroke-width="2.4"/>'
        '</g></g>'
    )
    mapping["stamp"] = (256, 928, 128, 96)
    # tear-off edge for paper: 32x16 tile, paper on top with round bites along the bottom (tiled in X)
    parts.append('<g transform="translate(384,928)"><path d="M0 0H32V16H29A5 5 0 0 0 19 16H13A5 5 0 0 0 3 16H0Z" fill="#fff"/></g>')
    mapping["perforation"] = (384, 928, 32, 16)
    # hazard block clipped to the same forward slant as the primary button (64x96)
    stripes = "".join(f'<path d="M{x} 96 L{x + 96} 0" stroke="#fff" stroke-width="7"/>' for x in range(-96, 96, 16))
    parts.append(
        '<defs><clipPath id="slantClip"><path d="M18 0H64L46 96H0Z"/></clipPath></defs>'
        f'<g transform="translate(416,928)"><g clip-path="url(#slantClip)">{stripes}</g></g>'
    )
    mapping["hatchSlant"] = (416, 928, 64, 96)
    # corrugated container ribs, 64x96 tile in X (drawn at low opacity behind panel headers)
    ribs = "".join(
        f'<rect x="{x}" y="0" width="{w}" height="96" fill="#fff" fill-opacity="{o}"/>'
        for x, w, o in ((0, 4, 0.35), (4, 10, 1.0), (14, 4, 0.55), (18, 14, 0.12), (32, 4, 0.35), (36, 10, 1.0), (46, 4, 0.55), (50, 14, 0.12))
    )
    parts.append(f'<g transform="translate(480,928)">{ribs}</g>')
    mapping["ribs"] = (480, 928, 64, 96)

    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">' + "".join(parts) + "</svg>"
    svg_path = os.path.join(HERE, "pivot_atlas.svg")
    png_path = os.path.join(HERE, "pivot_atlas.png")
    with open(svg_path, "w") as fh:
        fh.write(svg)
    if shutil.which("rsvg-convert"):
        subprocess.run(["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE), "-o", png_path, svg_path], check=True)
    else:  # Windows / no librsvg: pip install resvg-py
        import resvg_py

        with open(png_path, "wb") as fh:
            fh.write(bytes(resvg_py.svg_to_bytes(svg_string=svg, width=SIZE, height=SIZE)))
    lines = ["-- generated by art/build_atlas.py: name = {x, y, w, h} in the 1024x1024 atlas", "return {"]
    for name, (x, y, w, h) in mapping.items():
        lines.append(f"\t{name} = {{ {x}, {y}, {w}, {h} }},")
    lines.append("}")
    with open(os.path.join(HERE, "atlas_map.lua"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    # preview on dark background for review
    prev = os.path.join(HERE, "atlas_preview.png")
    if shutil.which("ffmpeg"):
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", f"color=c=0x1E252D:s={SIZE}x{SIZE}", "-i", png_path,
             "-filter_complex", "[0][1]overlay", "-frames:v", "1", prev],
            check=True,
        )
    else:  # pip install pillow
        from PIL import Image

        sheet = Image.open(png_path).convert("RGBA")
        bg = Image.new("RGBA", sheet.size, (0x1E, 0x25, 0x2D, 255))
        Image.alpha_composite(bg, sheet).convert("RGB").save(prev)
    print("icons:", len(ICONS), "entries:", len(mapping))


if __name__ == "__main__":
    build()
