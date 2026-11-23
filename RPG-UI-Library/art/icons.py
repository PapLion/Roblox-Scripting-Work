"""Hand-authored SVG icon set for the RPG UI library.

ICONS  : name -> SVG body markup for viewBox="0 0 128 128" (painted item / skill icons)
GLYPHS : name -> SVG body markup for viewBox="0 0 64 64"  (pure white UI glyphs, tinted at runtime)

Every icon is drawn from simple hand-written path data. A tiny builder keeps the
painted style consistent: base fill -> shading clipped to the shape -> dark outline
on top -> small top-left highlight. All ids are prefixed with the icon name.
"""
import math

# ----------------------------------------------------------------------------
# palette
# ----------------------------------------------------------------------------
O = "#1A110B"          # outline
SW = 4.5               # main outline width
SW2 = 2.5              # interior detail line width

STEEL_HI, STEEL, STEEL_MID, STEEL_DK = "#EEF1F5", "#C9CED6", "#8B93A1", "#4E5563"
GOLD_HI, GOLD, GOLD_MID, GOLD_DK = "#FFF0C4", "#F3D08A", "#D4A55A", "#8A6630"
LEATHER, LEATHER_DK = "#9A6A3F", "#6B4426"
WOOD, WOOD_DK = "#8B5A2B", "#5C3A1B"
PARCH, PARCH_DK = "#E9DCC0", "#C9B48A"
RUBY, RUBY_HI, RUBY_DK = "#E5484D", "#FF9A9C", "#8E2329"
SAPH, SAPH_HI, SAPH_DK = "#4E9BE0", "#A9D4FA", "#244F8C"
EMER, EMER_HI, EMER_DK = "#5DBE6A", "#B4EDB0", "#2C6E37"
AMET, AMET_HI, AMET_DK = "#B06CE8", "#E2C2FF", "#5E2E8C"
TEAL, TEAL_HI, TEAL_DK = "#4FC1B7", "#C8FFF7", "#1F6B6A"
FIRE_Y, FIRE_O, FIRE_R = "#FFE08A", "#FF9A3C", "#F25C2A"
FROST_HI, FROST, FROST_DK = "#BFE9FF", "#6FC3F2", "#2F7FB8"
POISON, POISON_DK = "#9BD94A", "#4F7D1E"


def _n(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def circ(cx, cy, r):
    return (f"M{_n(cx - r)},{_n(cy)} a{_n(r)},{_n(r)} 0 1 0 {_n(2 * r)},0 "
            f"a{_n(r)},{_n(r)} 0 1 0 {_n(-2 * r)},0 Z")


def ell(cx, cy, rx, ry):
    return (f"M{_n(cx - rx)},{_n(cy)} a{_n(rx)},{_n(ry)} 0 1 0 {_n(2 * rx)},0 "
            f"a{_n(rx)},{_n(ry)} 0 1 0 {_n(-2 * rx)},0 Z")


def rr(x, y, w, h, r):
    return (f"M{_n(x + r)},{_n(y)} H{_n(x + w - r)} Q{_n(x + w)},{_n(y)} {_n(x + w)},{_n(y + r)} "
            f"V{_n(y + h - r)} Q{_n(x + w)},{_n(y + h)} {_n(x + w - r)},{_n(y + h)} H{_n(x + r)} "
            f"Q{_n(x)},{_n(y + h)} {_n(x)},{_n(y + h - r)} V{_n(y + r)} Q{_n(x)},{_n(y)} {_n(x + r)},{_n(y)} Z")


def poly(pts, close=True):
    d = "M" + " L".join(f"{_n(x)},{_n(y)}" for x, y in pts)
    return d + (" Z" if close else "")


def star_pts(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180 / n)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def sparkle(cx, cy, r, k=0.22):
    """4-point twinkle star path."""
    i = r * k
    return (f"M{_n(cx)},{_n(cy - r)} Q{_n(cx + i)},{_n(cy - i)} {_n(cx + r)},{_n(cy)} "
            f"Q{_n(cx + i)},{_n(cy + i)} {_n(cx)},{_n(cy + r)} Q{_n(cx - i)},{_n(cy + i)} {_n(cx - r)},{_n(cy)} "
            f"Q{_n(cx - i)},{_n(cy - i)} {_n(cx)},{_n(cy - r)} Z")


def sh(d, fill, op=None):
    o = f' opacity="{op}"' if op is not None else ""
    return f'<path d="{d}" fill="{fill}"{o}/>'


def line(d, color, w=SW2, op=None, cap="round"):
    o = f' opacity="{op}"' if op is not None else ""
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
            f'stroke-linecap="{cap}" stroke-linejoin="round"{o}/>')


def hl(d, op=0.85):
    return f'<path d="{d}" fill="#FFFFFF" opacity="{op}"/>'


class B:
    def __init__(self, name):
        self.n = name
        self.k = 0
        self.defs = []
        self.body = []

    def id(self):
        self.k += 1
        return f"{self.n}_g{self.k}"

    def _stops(self, stops):
        out = []
        n = len(stops)
        for i, s in enumerate(stops):
            if isinstance(s, str):
                off, col, op = i / max(1, n - 1), s, 1
            elif len(s) == 2:
                off, col, op = s[0], s[1], 1
            else:
                off, col, op = s
            out.append(f'<stop offset="{_n(off)}" stop-color="{col}" stop-opacity="{_n(op)}"/>')
        return "".join(out)

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1, user=False):
        i = self.id()
        u = ' gradientUnits="userSpaceOnUse"' if user else ""
        self.defs.append(f'<linearGradient id="{i}" x1="{_n(x1)}" y1="{_n(y1)}" x2="{_n(x2)}" y2="{_n(y2)}"{u}>'
                         f'{self._stops(stops)}</linearGradient>')
        return f"url(#{i})"

    def rad(self, stops, cx=0.5, cy=0.5, r=0.5, fx=None, fy=None, user=False):
        i = self.id()
        f = ""
        if fx is not None:
            f = f' fx="{_n(fx)}" fy="{_n(fy)}"'
        u = ' gradientUnits="userSpaceOnUse"' if user else ""
        self.defs.append(f'<radialGradient id="{i}" cx="{_n(cx)}" cy="{_n(cy)}" r="{_n(r)}"{f}{u}>'
                         f'{self._stops(stops)}</radialGradient>')
        return f"url(#{i})"

    def part(self, d, fill, shades=(), sw=SW, rule=None, op=None):
        """Base fill, shading clipped to the shape, then the outline on top."""
        fr = f' fill-rule="{rule}"' if rule else ""
        o = f' opacity="{op}"' if op is not None else ""
        self.body.append(f'<path d="{d}" fill="{fill}"{fr}{o}/>')
        if shades:
            cid = self.id()
            cr = f' clip-rule="{rule}"' if rule else ""
            self.defs.append(f'<clipPath id="{cid}"><path d="{d}"{cr}/></clipPath>')
            self.body.append(f'<g clip-path="url(#{cid})">' + "".join(shades) + "</g>")
        if sw:
            self.body.append(f'<path d="{d}" fill="none" stroke="{O}" stroke-width="{sw}" '
                             f'stroke-linejoin="round" stroke-linecap="round"/>')

    def rod(self, pts, w, color, hi=None, sw=SW):
        """A thick outlined stroke (handles, shafts, chains)."""
        d = poly(pts, close=False) if not isinstance(pts, str) else pts
        self.body.append(line(d, O, w + 2 * sw))
        self.body.append(line(d, color, w))
        if hi:
            self.body.append(hi)

    def add(self, *m):
        self.body.extend(m)

    def glow(self, cx, cy, r, color, op=0.55):
        g = self.rad([(0, color, op), (0.55, color, op * 0.45), (1, color, 0)], user=True, cx=cx, cy=cy, r=r)
        self.body.append(f'<circle cx="{_n(cx)}" cy="{_n(cy)}" r="{_n(r)}" fill="{g}"/>')

    def svg(self):
        return ("<defs>" + "".join(self.defs) + "</defs>" if self.defs else "") + "".join(self.body)


def rot(deg, cx=64, cy=64):
    return f'<g transform="rotate({deg} {cx} {cy})">'


# ----------------------------------------------------------------------------
# weapons (drawn upright in a local frame, then rotated 45deg: tip top-right)
# ----------------------------------------------------------------------------
def i_sword():
    b = B("sword")
    b.add(rot(45))
    blade = "M64,-10 L74,8 L74,82 L54,82 L54,8 Z"
    b.part(blade, b.lin([STEEL_HI, STEEL], x2=1, y2=0), [
        sh("M64,-14 L80,6 L80,86 L64,86 Z", STEEL_MID),
        sh("M54,8 L58,8 L58,82 L54,82 Z", "#FFFFFF", 0.55),
    ])
    b.add(line("M64,8 L64,74", STEEL_DK, 3, 0.75))
    # guard
    guard = "M34,84 C44,79 84,79 94,84 L94,90 C84,94 44,94 34,90 Z"
    b.part(guard, b.lin([GOLD_HI, GOLD, GOLD_MID], x2=1, y2=0), [sh("M30,88 H98 V98 H30 Z", GOLD_DK, 0.55)])
    b.part(circ(64, 87, 5), b.rad([RUBY_HI, RUBY, RUBY_DK], fx=0.35, fy=0.3), sw=2.5)
    # grip
    grip = rr(58, 92, 12, 26, 2)
    b.part(grip, LEATHER, [sh("M64,90 H72 V120 H64 Z", LEATHER_DK),
                           line("M56,98 L72,94 M56,105 L72,101 M56,112 L72,108", O, 2, 0.6)])
    b.part(circ(64, 124, 7.5), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1),
           [sh(circ(66, 126, 7), GOLD_MID, 0.6)])
    b.add(hl(circ(61.5, 121.5, 2.2), 0.9))
    b.add("</g>")
    return b.svg()


def i_dagger():
    b = B("dagger")
    b.add(rot(45))
    blade = "M64,-4 C78,14 86,40 80,76 L48,76 C42,40 50,14 64,-4 Z"
    b.part(blade, b.lin([STEEL_HI, STEEL], x2=1, y2=0), [
        sh("M64,-8 L90,0 L90,80 L64,80 Z", STEEL_MID),
        sh("M47,10 C49,30 51,50 53,76 L48,76 C43,50 45,30 49,10 Z", "#FFFFFF", 0.5),
    ])
    b.add(line("M64,12 L64,70", STEEL_DK, 3, 0.7))
    guard = "M36,78 C44,68 54,74 64,74 C74,74 84,68 92,78 C84,86 74,86 64,86 C54,86 44,86 36,78 Z"
    b.part(guard, b.lin([GOLD_HI, GOLD, GOLD_MID], x2=1, y2=0), [sh("M32,82 H96 V92 H32 Z", GOLD_DK, 0.5)])
    grip = rr(56, 86, 16, 24, 4)
    b.part(grip, b.lin([LEATHER, LEATHER_DK], x2=1, y2=0),
           [line("M54,92 L74,89 M54,98 L74,95 M54,104 L74,101", O, 2, 0.55)])
    pom = "M64,107 L76,117 L64,130 L52,117 Z"
    b.part(pom, b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1))
    b.part(poly([(64, 111), (70, 117), (64, 124), (58, 117)]), b.lin([SAPH_HI, SAPH, SAPH_DK], x2=1, y2=1), sw=2)
    b.add("</g>")
    return b.svg()


def i_axe():
    b = B("axe")
    b.rod([(42, 120), (82, 12)], 11, WOOD, line("M39,116 L77,14", "#B07A45", 3, 0.9))
    for t in (0.07, 0.15, 0.23):
        x, y = 42 + 40 * t, 120 - 108 * t
        b.add(line(f"M{_n(x - 8)},{_n(y - 3)} L{_n(x + 8)},{_n(y + 3)}", LEATHER_DK, 6, cap="butt"))
    blade = "M76,22 C62,22 48,16 36,8 Q10,34 22,70 C38,62 54,58 70,58 Z"
    b.part(blade, b.lin([STEEL_HI, STEEL, STEEL_MID], x1=0, y1=0, x2=1, y2=1), [
        sh("M76,22 C68,24 60,24 54,22 C50,36 54,50 70,58 Z", STEEL_MID, 0.8),
        sh("M34,6 Q8,34 20,72 L30,68 Q20,36 42,12 Z", "#FFFFFF", 0.75),
        line("M42,14 Q22,38 30,66", STEEL_MID, 2, 0.6),
    ])
    poll = "M80,30 L102,36 L100,48 L76,48 Z"
    b.part(poll, b.lin([STEEL, STEEL_DK], x2=1, y2=1))
    b.part("M70,20 L86,24 L78,62 L64,58 Z", b.lin([GOLD_HI, GOLD_MID, GOLD_DK], x2=1, y2=0))
    b.add(sh(circ(76, 32, 2.6), GOLD_DK), sh(circ(72, 48, 2.6), GOLD_DK))
    b.add(hl("M71,24 L74,25 L66,54 L64,53 Z", 0.7))
    return b.svg()


def i_mace():
    b = B("mace")
    b.rod([(20, 118), (70, 60)], 11, WOOD, line("M17,114 L66,57", "#B07A45", 3, 0.9))
    for t in (0.05, 0.13, 0.21, 0.29):
        x, y = 20 + 50 * t, 118 - 58 * t
        b.add(line(f"M{_n(x - 6)},{_n(y - 5)} L{_n(x + 6)},{_n(y + 5)}", LEATHER_DK, 6, cap="butt"))
    cx, cy, r = 80, 46, 26
    for k in range(8):
        a = math.radians(k * 45 + 22.5)
        tip = (cx + (r + 14) * math.cos(a), cy + (r + 14) * math.sin(a))
        l = (cx + (r - 2) * math.cos(a - 0.3), cy + (r - 2) * math.sin(a - 0.3))
        rt = (cx + (r - 2) * math.cos(a + 0.3), cy + (r - 2) * math.sin(a + 0.3))
        b.part(poly([l, tip, rt]), b.lin([STEEL, STEEL_DK], x2=1, y2=1))
    b.part("M56,64 L66,54 L76,64 L66,74 Z", b.lin([GOLD, GOLD_DK], x2=1, y2=1))
    b.part(circ(cx, cy, r), b.rad([STEEL_HI, STEEL, STEEL_MID, STEEL_DK], fx=0.32, fy=0.3, r=0.6))
    b.add(line(f"M{cx - 25},{cy} Q{cx},{cy + 9} {cx + 25},{cy}", STEEL_DK, 2.5, 0.7))
    b.add(line(f"M{cx},{cy - 25} Q{cx - 9},{cy} {cx},{cy + 25}", STEEL_DK, 2.5, 0.7))
    b.add(hl(ell(cx - 10, cy - 11, 7, 4.5), 0.85))
    return b.svg()


def i_bow():
    b = B("bow")
    b.add(line("M106,22 L22,106", O, 5), line("M106,22 L22,106", PARCH, 2))
    limb = "M108,20 Q10,10 20,108"
    b.add(line(limb, O, 17), line(limb, WOOD, 9), line("M100,17 Q14,14 17,100", "#B07A45", 3, 0.9))
    b.part(circ(108, 20, 5.5), GOLD, sw=3.5)
    b.part(circ(20, 108, 5.5), GOLD, sw=3.5)
    b.part("M30,44 L44,30 L52,38 L38,52 Z", LEATHER, [sh("M40,48 L52,38 L56,44 L44,56 Z", LEATHER_DK)], sw=4)
    # nocked arrow lying across the grip
    b.rod([(88, 88), (26, 26)], 4, "#B07A45")
    b.part("M82,82 L94,86 L104,104 L86,94 Z", RUBY, [sh("M82,82 L104,104 L94,86 Z", RUBY_DK, 0.6)], sw=3.5)
    b.part("M14,14 L36,20 L28,28 L20,36 Z", b.lin([STEEL_HI, STEEL_MID], x2=1, y2=1), sw=3.5)
    return b.svg()


def i_staff():
    b = B("staff")
    b.glow(88, 38, 38, TEAL, 0.6)
    b.rod("M18,120 C38,98 58,76 78,54", 12, WOOD, line("M15,116 C35,94 55,73 74,52", "#B07A45", 3, 0.9))
    for t in ((28, 108), (35, 100)):
        b.add(line(f"M{t[0] - 7},{t[1] - 7} L{t[0] + 7},{t[1] + 7}", LEATHER_DK, 6, cap="butt"))
    for d in ("M78,56 C60,54 56,28 74,16", "M78,56 C82,74 108,72 114,52"):
        b.add(line(d, O, 14), line(d, WOOD, 6))
    b.part(circ(90, 38, 18), b.rad([TEAL_HI, TEAL, TEAL_DK], fx=0.35, fy=0.3, r=0.6))
    b.add(hl(ell(84, 31, 6, 4), 0.9))
    b.part("M68,58 L78,48 L88,58 L78,68 Z", b.lin([GOLD_HI, GOLD_DK], x2=1, y2=1), sw=4)
    b.add(hl(sparkle(114, 16, 6), 0.9), hl(sparkle(58, 16, 4.5), 0.7))
    return b.svg()


def i_wand():
    b = B("wand")
    b.glow(88, 40, 36, AMET, 0.6)
    b.rod([(20, 112), (78, 54)], 10, WOOD_DK, line("M18,109 L75,52", WOOD, 3, 0.9))
    for (x, y) in ((32, 100), (68, 64)):
        b.part(f"M{x - 8},{y - 2} L{x - 2},{y - 8} L{x + 8},{y + 2} L{x + 2},{y + 8} Z",
               b.lin([GOLD_HI, GOLD_DK], x2=1, y2=1), sw=3.5)
    pts = star_pts(88, 40, 30, 13, 5, -72)
    b.part(poly(pts), b.lin([AMET_HI, AMET, AMET_DK], x2=1, y2=1),
           [sh(poly([(88, 40)] + pts[2:6]), AMET_DK, 0.35)])
    b.add(hl(sparkle(82, 33, 6), 0.95), hl(sparkle(116, 74, 5), 0.8), hl(sparkle(52, 18, 5), 0.75))
    return b.svg()


# ----------------------------------------------------------------------------
# armour
# ----------------------------------------------------------------------------
def i_shield():
    b = B("shield")
    outer = "M64,8 C80,16 98,18 114,14 L114,52 C114,84 94,108 64,122 C34,108 14,84 14,52 L14,14 C30,18 48,16 64,8 Z"
    b.part(outer, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1))
    inner = "M64,18 C78,24 92,26 104,24 L104,54 C104,80 88,100 64,112 C40,100 24,80 24,54 L24,24 C36,26 50,24 64,18 Z"
    b.part(inner, b.lin([SAPH_HI, SAPH, SAPH_DK], x2=1, y2=1),
           [sh("M64,10 L120,10 L120,120 L64,120 Z", SAPH_DK, 0.35)], sw=3.5)
    # chevron emblem
    chev = "M34,58 L64,40 L94,58 L94,72 L64,54 L34,72 Z"
    b.part(chev, b.lin([GOLD_HI, GOLD, GOLD_MID], x2=1, y2=1), sw=3.5)
    b.part(circ(64, 84, 10), b.rad([STEEL_HI, STEEL, STEEL_DK], fx=0.35, fy=0.3), sw=3.5)
    b.add(hl("M22,22 C34,24 46,22 58,16 L58,20 C46,26 34,28 22,26 Z", 0.75))
    b.add(hl("M30,32 L34,32 L34,62 C34,70 36,76 38,80 L34,82 C30,74 30,68 30,60 Z", 0.4))
    return b.svg()


def i_helm():
    b = B("helm")
    plume = "M58,22 C54,10 66,4 84,6 C98,8 108,18 112,30 C102,24 92,22 82,26 C76,22 68,22 58,22 Z"
    b.part(plume, b.lin([RUBY_HI, RUBY, RUBY_DK], x2=1, y2=1), [line("M66,14 C78,10 92,14 102,22", RUBY_DK, 2.5, 0.7)])
    helm = ("M20,74 C20,40 38,18 64,18 C90,18 108,40 108,74 L108,108 C108,114 104,118 98,118 L82,118 "
            "L78,92 L72,82 L56,82 L50,92 L46,118 L30,118 C24,118 20,114 20,108 Z")
    b.part(helm, b.lin([STEEL_HI, STEEL, STEEL_MID], x2=1, y2=1), [
        sh("M64,10 L120,10 L120,124 L64,124 Z", STEEL_MID, 0.6),
        sh("M20,96 L108,96 L108,124 L20,124 Z", STEEL_DK, 0.35),
    ])
    # T visor
    visor = "M34,60 C46,56 82,56 94,60 L94,72 L74,72 L72,82 L56,82 L54,72 L34,72 Z"
    b.add(sh(visor, O))
    # ridge + brow band
    b.part("M60,18 L68,18 L68,58 L60,58 Z", b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=0), sw=3)
    b.part("M24,56 C40,50 88,50 104,56 L104,62 C88,56 40,56 24,62 Z", b.lin([GOLD_HI, GOLD_MID], x2=1, y2=0), sw=3)
    for x in (32, 96):
        b.add(sh(circ(x, 88, 2.6), STEEL_DK), sh(circ(x, 100, 2.6), STEEL_DK))
    b.add(hl("M30,52 C30,38 40,28 52,24 C42,32 36,40 34,52 Z", 0.75))
    return b.svg()


def i_chestplate():
    b = B("chestplate")
    body = ("M30,24 L48,16 C52,26 58,30 64,30 C70,30 76,26 80,16 L98,24 L100,52 L96,92 "
            "C96,106 82,116 64,118 C46,116 32,106 32,92 L28,52 Z")
    b.part(body, b.lin([STEEL_HI, STEEL, STEEL_MID], x2=1, y2=1), [
        sh("M64,20 L110,20 L110,124 L64,124 Z", STEEL_MID, 0.55),
        line("M40,66 C52,74 76,74 88,66", STEEL_DK, 3, 0.8),
        line("M44,90 C54,96 74,96 84,90", STEEL_DK, 3, 0.6),
        line("M64,34 L64,112", STEEL_DK, 2.5, 0.6),
    ])
    for side in (1, -1):
        cx = 64 + side * 44
        p = (f"M{64 + side * 30},{20} C{64 + side * 44},{16} {64 + side * 54},{24} {64 + side * 56},{40} "
             f"C{64 + side * 56},{50} {64 + side * 50},{56} {64 + side * 40},{54} "
             f"C{64 + side * 38},{42} {64 + side * 34},{30} {64 + side * 30},{20} Z")
        b.part(p, b.lin([STEEL, STEEL_MID, STEEL_DK], x2=1, y2=1),
               [line(f"M{64 + side * 38},{30} C{64 + side * 46},{30} {64 + side * 50},{36} {64 + side * 52},{44}", STEEL_DK, 2.5, 0.7)])
    neck = "M46,16 C52,28 58,32 64,32 C70,32 76,28 82,16 L86,18 C80,32 72,38 64,38 C56,38 48,32 42,18 Z"
    b.part(neck, b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=0), sw=3)
    b.part(circ(64, 50, 6), b.rad([RUBY_HI, RUBY, RUBY_DK], fx=0.35, fy=0.3), sw=3)
    b.add(hl("M36,40 C38,56 38,72 40,86 L36,86 C34,72 34,56 33,42 Z", 0.6))
    return b.svg()


def i_gloves():
    b = B("gloves")
    lg = b.lin(["#B98250", LEATHER, LEATHER_DK], x2=1, y2=1)
    fingers = [(42, 26), (56, 18), (70, 20), (84, 30)]
    parts = []
    thumb = "M44,74 C34,70 24,62 18,52 C14,46 20,40 26,44 C32,50 38,56 46,60 Z"
    palm = "M38,52 L98,52 L98,84 C98,92 92,98 84,98 L48,98 C42,98 38,92 38,86 Z"
    fds = [rr(x - 7, y, 14, 60 - y, 7) for x, y in fingers]
    shapes = [thumb] + fds + [palm]
    for d in shapes:  # union outline
        b.add(f'<path d="{d}" fill="{O}" stroke="{O}" stroke-width="{SW * 2}" stroke-linejoin="round"/>')
    for d in shapes:
        b.add(f'<path d="{d}" fill="{lg}"/>')
    b.add(line("M49,30 L49,56 M63,24 L63,56 M77,28 L77,56", O, 2.5, 0.8))
    b.add(line("M46,60 C40,58 34,54 30,50", O, 2.5, 0.6))
    b.add(sh("M88,54 L98,54 L98,86 C98,92 94,96 88,96 Z", LEATHER_DK, 0.6))
    b.add(hl("M37,32 C37,28 41,28 41,32 L41,44 L37,44 Z", 0.5), hl("M51,24 C51,20 55,20 55,24 L55,38 L51,38 Z", 0.5))
    cuff = rr(32, 96, 72, 22, 5)
    b.part(cuff, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=0, y2=1),
           [line("M32,107 H104", GOLD_DK, 2.5, 0.7)])
    b.part(circ(68, 107, 4.5), b.rad([SAPH_HI, SAPH, SAPH_DK], fx=0.35, fy=0.3), sw=2.5)
    return b.svg()


def i_boots():
    b = B("boots")
    boot = ("M32,14 L76,14 L76,68 C76,74 82,78 92,80 C108,84 116,92 116,104 L116,112 L28,112 L28,100 "
            "C32,88 32,70 32,14 Z")
    b.part(boot, b.lin(["#B98250", LEATHER, LEATHER_DK], x2=1, y2=1), [
        sh("M62,10 L80,10 L80,70 C80,78 88,82 98,84 L120,90 L120,120 L60,120 Z", LEATHER_DK, 0.45),
        line("M40,40 C46,44 56,44 62,40", LEATHER_DK, 2.5, 0.7),
    ])
    sole = "M24,104 L120,104 L120,112 C120,116 116,118 112,118 L28,118 C24,118 22,116 22,112 Z"
    b.part(sole, b.lin([WOOD, WOOD_DK], x2=0, y2=1))
    b.part(rr(26, 10, 54, 18, 4), b.lin(["#C08A55", LEATHER], x2=0, y2=1), [sh("M26,22 H82 V30 H26 Z", LEATHER_DK, 0.6)])
    strap = "M32,56 L76,52 L76,62 L32,66 Z"
    b.part(strap, WOOD_DK, sw=3)
    b.add(f'<path d="{rr(48, 52, 14, 13, 2)}" fill="none" stroke="{O}" stroke-width="7"/>',
          f'<path d="{rr(48, 52, 14, 13, 2)}" fill="none" stroke="{GOLD}" stroke-width="3"/>')
    b.add(hl("M36,32 L40,32 L40,96 C40,98 38,100 36,100 Z", 0.4))
    return b.svg()


def i_cloak():
    b = B("cloak")
    cloak = ("M64,10 C84,10 96,24 96,42 C102,62 110,90 116,116 C98,110 82,118 64,112 "
             "C46,118 30,110 12,116 C18,90 26,62 32,42 C32,24 44,10 64,10 Z")
    b.part(cloak, b.lin(["#E46A6E", "#B8343A", "#6E1E24"], x2=1, y2=1), [
        sh("M64,40 C80,60 96,90 104,124 L128,124 L128,0 L90,0 C96,20 96,40 96,42 Z", "#5A161C", 0.6),
        line("M48,62 C44,80 40,96 36,112", "#5A161C", 3, 0.8),
        line("M64,64 C64,82 64,98 64,110", "#5A161C", 3, 0.8),
        line("M80,62 C84,80 88,96 92,112", "#5A161C", 3, 0.6),
    ])
    hood_in = "M64,22 C76,22 84,32 84,46 C76,52 52,52 44,46 C44,32 52,22 64,22 Z"
    b.part(hood_in, b.lin(["#120B07", "#3A1A14"], x2=0, y2=1), sw=3)
    b.part(circ(64, 58, 7), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1), sw=3.5)
    b.add(hl("M38,30 C42,20 50,14 58,13 C50,18 44,26 42,36 Z", 0.6))
    b.add(hl("M28,70 L32,70 C30,84 26,98 22,110 L18,110 C22,98 26,84 28,70 Z", 0.25))
    return b.svg()


def i_ring():
    b = B("ring")
    band = ell(64, 80, 40, 34) + " " + ell(64, 80, 27, 22)
    b.part(band, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1),
           [sh(ell(70, 86, 40, 34), GOLD_DK, 0.35)], rule="evenodd")
    b.add(hl("M30,74 C32,62 40,54 50,50 C42,58 38,66 36,76 Z", 0.75))
    # setting + gem
    b.part("M44,52 L52,32 L76,32 L84,52 Z", b.lin([GOLD, GOLD_DK], x2=0, y2=1))
    gem = "M50,30 L58,14 L70,14 L78,30 L64,48 Z"
    b.part(gem, b.lin([RUBY_HI, RUBY, RUBY_DK], x2=1, y2=1), [
        sh("M64,14 L78,30 L64,48 Z", RUBY_DK, 0.45),
        line("M50,30 H78 M58,14 L64,30 L70,14", RUBY_DK, 2, 0.7),
    ], sw=4)
    b.add(hl("M57,18 L61,18 L58,26 Z", 0.9))
    b.add(hl(sparkle(92, 20, 7), 0.9))
    return b.svg()


def i_amulet():
    b = B("amulet")
    chain = "M18,10 C22,40 40,58 56,64 M110,10 C106,40 88,58 72,64"
    b.add(line(chain, O, 8), line(chain, GOLD, 4))
    b.add(f'<path d="{chain}" fill="none" stroke="{GOLD_DK}" stroke-width="4" stroke-dasharray="3 5" stroke-linecap="round"/>')
    b.part(rr(57, 58, 14, 12, 4), b.lin([GOLD_HI, GOLD_DK], x2=1, y2=1), sw=3.5)
    frame = "M64,66 C86,66 100,80 100,96 C100,112 84,122 64,122 C44,122 28,112 28,96 C28,80 42,66 64,66 Z"
    b.part(frame, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1))
    b.part(ell(64, 94, 22, 19), b.rad([TEAL_HI, TEAL, TEAL_DK], fx=0.35, fy=0.3, r=0.6), sw=3.5)
    b.add(sh("M64,80 L72,94 L64,108 L56,94 Z", "#FFFFFF", 0.35))
    b.add(hl(ell(56, 86, 5, 3.5), 0.9))
    for a in range(0, 360, 45):
        x, y = 64 + 30 * math.cos(math.radians(a)), 94 + 24 * math.sin(math.radians(a))
        b.add(sh(circ(x, y, 1.8), GOLD_DK))
    b.add(hl("M33,92 C34,82 42,74 52,71 C44,77 38,84 37,92 Z", 0.7))
    return b.svg()


def i_belt():
    b = B("belt")
    band = ell(64, 70, 56, 36) + " " + ell(64, 66, 42, 22)
    b.part(band, b.lin(["#B98250", LEATHER, LEATHER_DK], x2=0, y2=1),
           [sh(ell(64, 40, 70, 20), LEATHER_DK, 0.6),
            f'<path d="{ell(64, 69, 49, 29)}" fill="none" stroke="{PARCH_DK}" stroke-width="1.6" stroke-dasharray="4 4" opacity="0.8"/>'],
           rule="evenodd")
    # strap tail hanging
    tail = "M74,98 L90,96 L94,122 L84,118 L78,122 Z"
    b.part(tail, b.lin([LEATHER, LEATHER_DK], x2=1, y2=0))
    buckle = rr(44, 80, 40, 30, 6) + " " + rr(52, 87, 24, 16, 2)
    b.part(buckle, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1), rule="evenodd")
    b.add(line("M64,88 L64,102", O, 7), line("M64,88 L64,102", STEEL, 3))
    b.add(hl("M18,58 C24,46 38,38 54,35 C40,42 28,50 22,62 Z", 0.55))
    b.add(hl(circ(49, 85, 2), 0.9))
    return b.svg()


# ----------------------------------------------------------------------------
# consumables
# ----------------------------------------------------------------------------
GLASS = ("#EAF6FA", "#A8C2CC")


def _potion(name, body, rim, cork, level, liq, hi_d, extra=None):
    b = B(name)
    b.part(cork, b.lin(["#B07A45", WOOD, WOOD_DK], x2=1, y2=0), [line("M50,16 H80", WOOD_DK, 2, 0.6)])
    lq = b.lin(liq, x1=0, y1=0, x2=1, y2=1)
    shades = [
        sh(f"M0,{level} H128 V128 H0 Z", lq),
        sh(ell(64, level, 60, 4), liq[0], 0.9),
        sh(ell(96, level + 40, 30, 46), liq[-1], 0.45),
        sh(circ(52, level + 26, 3), "#FFFFFF", 0.45),
        sh(circ(62, level + 14, 2), "#FFFFFF", 0.45),
        sh(circ(74, level + 34, 2.5), "#FFFFFF", 0.35),
    ]
    if extra:
        shades += extra(b)
    b.part(body, b.lin(GLASS, x2=1, y2=1), shades)
    b.part(rim, b.lin(GLASS, x2=0, y2=1))
    b.add(line(hi_d, "#FFFFFF", 5, 0.85))
    return b


def i_potion_health():
    body = ("M54,30 L74,30 L74,48 C90,53 102,66 102,82 C102,103 85,118 64,118 C43,118 26,103 26,82 "
            "C26,66 38,53 54,48 Z")
    b = _potion("potion_health", body, rr(50, 24, 28, 9, 4), rr(55, 8, 18, 20, 4), 70,
                ["#FF9A9C", RUBY, RUBY_DK], "M36,82 C36,72 42,64 50,60")
    b.add(hl(circ(38, 92, 2.6), 0.85))
    return b.svg()


def i_potion_mana():
    body = ("M55,30 L73,30 L73,50 L102,104 C106,112 102,118 94,118 L34,118 C26,118 22,112 26,104 "
            "L55,50 Z")
    b = _potion("potion_mana", body, rr(51, 24, 26, 9, 4), rr(56, 8, 16, 20, 4), 78,
                [SAPH_HI, SAPH, SAPH_DK], "M52,58 L38,86")
    b.add(hl(circ(34, 98, 2.4), 0.85))
    return b.svg()


def i_potion_stamina():
    body = ("M56,30 L72,30 L72,40 C72,46 94,46 94,60 L94,108 C94,114 90,118 84,118 L44,118 "
            "C38,118 34,114 34,108 L34,60 C34,46 56,46 56,40 Z")

    def label(b):
        return [sh("M30,80 H98 V100 H30 Z", PARCH),
                sh("M30,96 H98 V100 H30 Z", PARCH_DK),
                line("M30,80 H98 M30,100 H98", O, 2.5),
                sh(poly(star_pts(64, 90, 7, 3, 5)), EMER_DK)]
    b = _potion("potion_stamina", body, rr(52, 24, 24, 9, 4), rr(57, 8, 14, 20, 4), 62,
                [EMER_HI, EMER, EMER_DK], "M42,64 L42,74", label)
    b.add(line("M42,106 L42,108", "#FFFFFF", 5, 0.7))
    return b.svg()


def i_elixir():
    b = B("elixir")
    b.glow(64, 80, 50, AMET, 0.35)
    body = "M64,40 L100,80 L64,120 L28,80 Z"
    lq = b.lin([AMET_HI, AMET, AMET_DK], x2=1, y2=1)
    b.part(body, b.lin(GLASS, x2=1, y2=1), [
        sh("M0,72 H128 V128 H0 Z", lq),
        sh("M0,72 H128 V75 H0 Z", AMET_HI, 0.9),
        sh("M64,40 L100,80 L64,120 Z", AMET_DK, 0.3),
        hl(sparkle(56, 92, 6), 0.9), hl(sparkle(72, 104, 4), 0.8), hl(sparkle(76, 84, 3), 0.7),
    ])
    b.part(rr(58, 26, 12, 16, 2), b.lin(GLASS, x2=1, y2=0))
    b.part(rr(50, 36, 28, 9, 4), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=0, y2=1))
    for s in (1, -1):
        d = f"M{64 + s * 12},45 L{64 + s * 36},80 L{64 + s * 12},115"
        b.add(line(d, O, 8), line(d, GOLD, 3.5))
    b.part(poly([(64, 6), (75, 18), (64, 30), (53, 18)]), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1),
           [sh("M64,6 L75,18 L64,30 Z", GOLD_DK, 0.4)])
    b.add(line("M42,76 L58,56", "#FFFFFF", 4.5, 0.8))
    return b.svg()


def i_scroll():
    b = B("scroll")
    sheet = "M30,24 L98,24 L98,104 L30,104 Z"
    b.part(sheet, b.lin([PARCH, PARCH_DK], x2=1, y2=1), [
        line("M42,42 H86 M42,54 H80 M42,66 H86 M42,78 H70", "#9C8458", 3, 0.8),
        sh("M84,24 H98 V104 H84 Z", PARCH_DK, 0.6),
    ])
    for y in (14, 98):
        roll = rr(22, y, 84, 16, 8)
        b.part(roll, b.lin([PARCH, PARCH_DK, "#A8915F"], x2=0, y2=1))
        b.part(ell(22, y + 8, 5, 8), b.lin([PARCH_DK, "#8A7448"], x2=1, y2=1), sw=3.5)
        b.part(ell(106, y + 8, 5, 8), b.lin([PARCH_DK, "#8A7448"], x2=1, y2=1), sw=3.5)
        b.add(hl(rr(30, y + 3, 50, 3, 1.5), 0.7))
    # ribbon + wax seal
    b.part("M78,96 L84,124 L90,118 L96,124 L92,96 Z", RUBY_DK, sw=3.5)
    b.part(circ(86, 92, 11), b.rad(["#FF7A7E", RUBY, RUBY_DK], fx=0.35, fy=0.3, r=0.6))
    b.add(sh(poly(star_pts(86, 92, 5.5, 2.4, 5)), RUBY_DK, 0.8))
    return b.svg()


def i_tome():
    b = B("tome")
    pages = "M30,18 L104,18 C108,18 110,20 110,24 L110,112 C110,116 108,118 104,118 L30,118 Z"
    b.part(pages, b.lin([PARCH, PARCH_DK], x2=1, y2=0),
           [line("M102,24 V112 M106,24 V112", "#A8915F", 1.6, 0.8),
            line("M34,114 H104", "#A8915F", 1.6, 0.8)])
    cover = rr(18, 10, 82, 102, 6)
    b.part(cover, b.lin(["#7E4FB8", "#5A3290", "#341B5A"], x2=1, y2=1), [
        sh("M18,10 H34 V112 H18 Z", "#25123F", 0.6),
        line("M34,10 V112", O, 2.5, 0.8),
        line("M24,26 H32 M24,96 H32", GOLD_MID, 3, 0.9),
    ])
    for (x, y, sx, sy) in ((100, 10, -1, 1), (100, 112, -1, -1), (18, 10, 1, 1), (18, 112, 1, -1)):
        d = f"M{x},{y} L{x + sx * 16},{y} L{x},{y + sy * 16} Z"
        b.part(d, b.lin([GOLD_HI, GOLD_MID], x2=1, y2=1), sw=3)
    # rune emblem
    b.add(line(circ(67, 61, 20), O, 8), line(circ(67, 61, 20), GOLD, 3.5))
    b.part(poly([(67, 44), (79, 61), (67, 78), (55, 61)]), b.lin([SAPH_HI, SAPH, SAPH_DK], x2=1, y2=1), sw=3.5)
    b.add(hl("M64,50 L67,46 L71,52 Z", 0.8))
    for a in (0, 90, 180, 270):
        x, y = 67 + 20 * math.cos(math.radians(a + 45)), 61 + 20 * math.sin(math.radians(a + 45))
        b.add(sh(circ(x, y, 3), GOLD_HI))
    b.add(hl("M38,16 H92 V19 H38 Z", 0.35))
    return b.svg()


def _leaf(cx, cy, ang, ln, w):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)

    def T(x, y):  # local (x along leaf, y across)
        return (cx + x * ca - y * sa, cy + x * sa + y * ca)
    p0, p1 = T(0, 0), T(ln, 0)
    c1, c2 = T(ln * 0.3, -w), T(ln * 0.8, -w * 0.6)
    c3, c4 = T(ln * 0.8, w * 0.6), T(ln * 0.3, w)
    d = (f"M{_n(p0[0])},{_n(p0[1])} C{_n(c1[0])},{_n(c1[1])} {_n(c2[0])},{_n(c2[1])} {_n(p1[0])},{_n(p1[1])} "
         f"C{_n(c3[0])},{_n(c3[1])} {_n(c4[0])},{_n(c4[1])} {_n(p0[0])},{_n(p0[1])} Z")
    half = (f"M{_n(p0[0])},{_n(p0[1])} C{_n(c1[0])},{_n(c1[1])} {_n(c2[0])},{_n(c2[1])} {_n(p1[0])},{_n(p1[1])} Z")
    vein = f"M{_n(p0[0])},{_n(p0[1])} L{_n(T(ln * 0.85, 0)[0])},{_n(T(ln * 0.85, 0)[1])}"
    return d, half, vein


def i_herb():
    b = B("herb")
    stems = ["M58,116 C56,90 48,62 30,34", "M64,116 C64,84 66,52 70,18", "M70,116 C74,92 84,68 102,46"]
    for s in stems:
        b.add(line(s, O, 10), line(s, "#4E8A3A", 4))
    lg = b.lin([EMER_HI, EMER, EMER_DK], x2=1, y2=1)
    leaves = [(30, 34, -125, 30, 12), (44, 60, -165, 28, 11), (70, 18, -80, 30, 12),
              (66, 52, -15, 28, 11), (66, 66, -165, 26, 10), (102, 46, -40, 30, 12), (82, 76, -5, 26, 10)]
    for (x, y, a, ln, w) in leaves:
        d, half, vein = _leaf(x, y, a, ln, w)
        b.part(d, lg, [sh(half, "#FFFFFF", 0.3)], sw=4)
        b.add(line(vein, EMER_DK, 2, 0.9))
    b.part(rr(50, 94, 28, 13, 4), b.lin([PARCH, PARCH_DK], x2=0, y2=1),
           [line("M48,98 L80,102 M48,103 L80,107", "#A8915F", 1.6)], sw=4)
    b.add(line("M56,106 C52,114 48,116 42,118", O, 7), line("M56,106 C52,114 48,116 42,118", PARCH_DK, 3))
    return b.svg()


def i_mushroom():
    b = B("mushroom")
    stem = "M48,64 C46,88 42,106 40,114 C52,122 76,122 88,114 C86,106 82,88 80,64 Z"
    b.part(stem, b.lin([PARCH, PARCH_DK], x2=1, y2=0), [
        sh("M72,60 L90,60 L92,120 L72,124 Z", PARCH_DK, 0.7),
        line("M42,82 C56,88 74,88 86,82", "#A8915F", 2, 0.6)])
    b.add(hl("M52,74 L56,74 L52,108 L48,108 Z", 0.5))
    cap = "M12,66 C12,30 38,10 64,10 C90,10 116,30 116,66 C100,76 28,76 12,66 Z"
    b.part(cap, b.lin(["#FF7A7E", RUBY, RUBY_DK], x2=1, y2=1), [
        sh("M12,62 C30,72 98,72 116,62 L116,80 L12,80 Z", "#6E1A20", 0.8),
        sh(ell(40, 36, 9, 7), PARCH), sh(ell(70, 24, 8, 6), PARCH), sh(ell(92, 46, 9, 7), PARCH),
        sh(ell(60, 52, 6, 5), PARCH), sh(ell(24, 56, 5, 4), PARCH),
        sh(ell(104, 30, 4, 3), PARCH),
    ])
    b.add(hl("M24,40 C30,26 42,18 54,15 C44,22 34,32 30,44 Z", 0.6))
    return b.svg()


def i_ore():
    b = B("ore")
    rock = "M18,80 L28,42 L56,22 L92,26 L112,56 L108,92 L76,112 L34,106 Z"
    b.part(rock, "#6A6372", [
        sh("M28,42 L56,22 L92,26 L80,48 L44,54 Z", "#9A93A3"),
        sh("M80,48 L92,26 L112,56 L108,92 L86,74 Z", "#4A4352"),
        sh("M18,80 L28,42 L44,54 L40,84 Z", "#7D7686"),
        sh("M40,84 L86,74 L108,92 L76,112 L34,106 Z", "#3E3846"),
        line("M44,54 L80,48 L86,74 L40,84 Z", O, 2.5, 0.7),
    ])
    for (pts) in ([(50, 60), (60, 52), (70, 60), (62, 72)], [(76, 82), (86, 76), (92, 88), (82, 94)],
                  [(30, 66), (38, 60), (40, 72)], [(60, 34), (70, 30), (74, 38), (64, 42)]):
        b.part(poly(pts), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1), sw=3)
    b.add(hl("M32,44 L54,28 L58,30 L36,48 Z", 0.5))
    b.add(hl(sparkle(96, 30, 7), 0.9))
    return b.svg()


def _ingot(b, ox, oy, s=1.0):
    def P(pts):
        return poly([(ox + x * s, oy + y * s) for x, y in pts])
    front = P([(0, 30), (48, 30), (40, 8), (8, 8)])
    side = P([(48, 30), (60, 22), (52, 0), (40, 8)])
    top = P([(8, 8), (40, 8), (52, 0), (20, 0)])
    whole = P([(0, 30), (48, 30), (60, 22), (52, 0), (20, 0), (8, 8)])
    b.part(whole, GOLD, [
        sh(front, b.lin([GOLD, GOLD_MID], x2=0, y2=1)),
        sh(side, GOLD_DK),
        sh(top, GOLD_HI),
        line(poly([(ox + 8 * s, oy + 8 * s), (ox + 40 * s, oy + 8 * s), (ox + 48 * s, oy + 30 * s)], close=False),
             GOLD_DK, 2, 0.8),
        line(f"M{_n(ox + 40 * s)},{_n(oy + 8 * s)} L{_n(ox + 52 * s)},{_n(oy)}", GOLD_DK, 2, 0.8),
        sh(P([(14, 3), (36, 3), (34, 5), (14, 5)]), "#FFFFFF", 0.7),
    ])


def i_ingot():
    b = B("ingot")
    _ingot(b, 6, 80, 1.08)
    _ingot(b, 56, 80, 1.08)
    _ingot(b, 30, 46, 1.08)
    b.add(hl(sparkle(100, 36, 8), 0.95))
    return b.svg()


def i_gem_ruby():
    b = B("gem_ruby")
    gem = "M34,22 L94,22 L118,48 L64,118 L10,48 Z"
    b.part(gem, RUBY, [
        sh("M34,22 L94,22 L80,48 L48,48 Z", "#FF7A7E"),
        sh("M10,48 L34,22 L48,48 Z", RUBY_HI),
        sh("M94,22 L118,48 L80,48 Z", "#C2353B"),
        sh("M10,48 L48,48 L64,118 Z", "#F06A6E"),
        sh("M80,48 L118,48 L64,118 Z", RUBY_DK),
        sh("M48,48 L80,48 L64,118 Z", "#C93A40"),
        line("M10,48 H118 M34,22 L48,48 L64,118 L80,48 L94,22", "#6E1A20", 2, 0.7),
    ])
    b.add(hl("M38,26 L56,26 L46,40 Z", 0.75), hl(sparkle(30, 34, 6), 0.95))
    return b.svg()


def i_gem_sapphire():
    b = B("gem_sapphire")
    outer = poly([(42, 12), (86, 12), (114, 40), (114, 88), (86, 116), (42, 116), (14, 88), (14, 40)])
    inner = poly([(50, 32), (78, 32), (94, 48), (94, 80), (78, 96), (50, 96), (34, 80), (34, 48)])
    b.part(outer, SAPH, [
        sh("M14,40 L42,12 L86,12 L78,32 L50,32 L34,48 Z", SAPH_HI),
        sh("M86,12 L114,40 L94,48 L78,32 Z", "#7AB6EC"),
        sh("M14,40 L34,48 L34,80 L14,88 Z", "#6FAEEA"),
        sh("M114,40 L114,88 L94,80 L94,48 Z", "#2F6DB0"),
        sh("M14,88 L34,80 L50,96 L42,116 Z", "#3A7CC4"),
        sh("M114,88 L86,116 L42,116 L50,96 L78,96 L94,80 Z", SAPH_DK),
        sh(inner, b.lin(["#8CC4F5", SAPH, "#2F6DB0"], x2=1, y2=1)),
        line(inner + " M14,40 L34,48 M42,12 L50,32 M86,12 L78,32 M114,40 L94,48 M114,88 L94,80 "
             "M86,116 L78,96 M42,116 L50,96 M14,88 L34,80", "#163563", 2, 0.6),
    ])
    b.add(hl("M52,36 L72,36 L58,50 Z", 0.6), hl(sparkle(30, 28, 7), 0.95))
    return b.svg()


def i_crystal():
    b = B("crystal")
    b.glow(64, 60, 56, TEAL, 0.35)
    shards = [
        ("M64,116 L50,40 L66,8 L82,40 L76,116 Z", "M66,8 L82,40 L76,116 L66,116 Z", 66),
        ("M40,116 L22,64 L28,40 L44,56 L54,116 Z", "M28,40 L44,56 L54,116 L38,116 Z", None),
        ("M82,116 L94,70 L108,52 L112,78 L96,116 Z", "M108,52 L112,78 L96,116 L100,80 Z", None),
    ]
    for d, dark, _ in shards[1:] + shards[:1]:
        b.part(d, b.lin([TEAL_HI, TEAL, TEAL_DK], x2=1, y2=1), [sh(dark, TEAL_DK, 0.6)])
    b.add(line("M66,10 L66,112", TEAL_DK, 2, 0.6))
    b.add(hl("M54,42 L64,18 L60,44 L62,100 L58,100 Z", 0.55))
    # rock base
    base = "M20,110 C30,104 50,106 64,108 C80,104 100,104 110,110 L112,120 L16,120 Z"
    b.part(base, b.lin(["#7D7686", "#4A4352"], x2=0, y2=1))
    b.add(hl(sparkle(100, 30, 7), 0.95), hl(sparkle(30, 26, 5), 0.8))
    return b.svg()


# ----------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------
def i_leather():
    b = B("leather")
    hide = ("M28,18 C40,26 52,18 64,22 C76,18 88,26 100,18 C108,32 98,44 106,56 C114,70 100,82 108,98 "
            "C96,100 92,112 80,110 C72,118 56,118 48,110 C36,112 32,100 20,98 C28,82 14,70 22,56 "
            "C30,44 20,32 28,18 Z")
    b.part(hide, b.lin(["#C08A55", LEATHER, LEATHER_DK], x2=1, y2=1), [
        sh("M64,40 C90,50 112,80 112,120 L128,120 L128,0 L104,0 C104,30 90,40 64,40 Z", LEATHER_DK, 0.5),
        sh(ell(52, 48, 18, 12), "#C99464", 0.6),
    ])
    inner = ("M34,28 C44,34 54,28 64,32 C74,28 84,34 94,28 C98,38 90,46 96,56 C102,68 92,80 98,92 "
             "C88,94 86,102 78,102 C70,108 58,108 50,102 C42,102 38,94 30,92 C36,80 26,68 32,56 C38,46 30,38 34,28 Z")
    b.add(f'<path d="{inner}" fill="none" stroke="{PARCH}" stroke-width="2.2" stroke-dasharray="5 4" '
          f'stroke-linecap="round" opacity="0.85"/>')
    b.add(hl("M30,24 C38,30 46,28 54,26 C46,32 38,34 32,32 Z", 0.55))
    return b.svg()


def i_thread():
    b = B("thread")
    body = rr(36, 26, 56, 78, 4)
    b.part(body, b.lin([AMET_HI, AMET, AMET_DK], x2=1, y2=0), [
        line("M30,36 L98,28 M30,48 L98,40 M30,60 L98,52 M30,72 L98,64 M30,84 L98,76 M30,96 L98,88 M30,108 L98,100",
             AMET_DK, 2, 0.6),
        sh("M76,20 H96 V110 H76 Z", AMET_DK, 0.4),
    ])
    for y in (12, 100):
        b.part(rr(24, y, 80, 16, 6), b.lin(["#B07A45", WOOD, WOOD_DK], x2=0, y2=1),
               [sh(f"M24,{y + 10} H104 V{y + 16} H24 Z", WOOD_DK, 0.6)])
        b.add(hl(rr(32, y + 3, 40, 3, 1.5), 0.5))
    loose = "M92,70 C108,72 114,86 104,96 C96,104 106,114 118,112"
    b.add(line(loose, O, 8), line(loose, AMET, 3.5))
    # needle
    b.add(line("M14,118 L50,40", O, 8), line("M14,118 L50,40", STEEL, 3.5))
    b.add(f'<path d="{ell(47, 47, 1.6, 3.6)}" fill="{O}" transform="rotate(25 47 47)"/>')
    b.add(hl("M44,36 L46,36 L48,46 Z", 0.9))
    b.add(hl("M42,34 L60,32 L60,38 L42,40 Z", 0.4))
    return b.svg()


def i_wood():
    b = B("wood")
    b.add(rot(-30))
    log = "M16,46 L96,46 L96,88 L16,88 C8,88 4,78 4,67 C4,56 8,46 16,46 Z"
    b.part(log, b.lin(["#A8723D", WOOD, WOOD_DK], x2=0, y2=1), [
        line("M20,56 C40,54 56,58 76,55 M14,68 C34,70 52,66 80,70 M22,80 C42,78 60,82 84,79",
             WOOD_DK, 2.5, 0.8),
        sh("M0,80 H100 V92 H0 Z", WOOD_DK, 0.5),
    ])
    # branch stub
    b.part("M40,46 L46,32 L56,32 L54,46 Z", b.lin([WOOD, WOOD_DK], x2=1, y2=0), sw=4)
    b.part(ell(51, 32, 5, 2.6), PARCH_DK, sw=3)
    endf = ell(98, 67, 14, 21)
    b.part(endf, b.rad([PARCH, "#D9BF8C", "#B58F58"], r=0.6), [
        line(ell(98, 67, 9, 14), "#9A7444", 2, 0.9),
        line(ell(98, 67, 4.5, 7), "#9A7444", 2, 0.9),
        line("M98,67 L106,52", "#7A5230", 1.8, 0.8),
    ])
    b.add(hl("M18,50 H70 V53 H18 Z", 0.35))
    b.add("</g>")
    # leaf sprout
    d, half, vein = _leaf(42, 46, -110, 20, 8)
    b.part(d, b.lin([EMER_HI, EMER, EMER_DK], x2=1, y2=1), [sh(half, "#FFFFFF", 0.3)], sw=3.5)
    b.add(line(vein, EMER_DK, 1.8))
    return b.svg()


def i_feather():
    b = B("feather")
    vane = ("M26,106 C26,80 36,48 62,26 C78,14 96,10 112,8 C110,24 104,42 90,58 "
            "C74,78 52,96 26,106 Z")
    b.part(vane, b.lin(["#FFFFFF", PARCH, PARCH_DK], x2=1, y2=1), [
        sh("M20,112 C46,70 80,36 116,6 L128,40 L128,128 L20,128 Z", PARCH_DK, 0.7),
        sh("M92,6 L120,4 L118,30 C110,22 100,14 92,6 Z", "#8A6630", 0.9),
        line("M40,84 L30,82 M52,70 L40,64 M66,56 L58,46 M80,42 L76,30 M60,80 L70,86 M74,66 L86,70 M88,50 L100,52",
             "#A8915F", 2, 0.9),
    ])
    # notch cuts
    b.add(line("M44,58 L52,62", O, 3), line("M88,64 L80,62", O, 3))
    shaft = "M18,116 C38,88 70,46 108,12"
    b.add(line(shaft, O, 7), line(shaft, "#F7EEDA", 3))
    b.add(hl("M40,74 C46,56 56,42 70,30 C60,44 52,58 46,74 Z", 0.6))
    return b.svg()


def i_key():
    b = B("key")
    b.add(rot(45))
    bow = circ(64, 108, 20) + " " + circ(64, 108, 9)
    shaft = rr(58, 6, 12, 84, 3)
    b.part(shaft, b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=0))
    teeth = "M68,8 L86,8 L86,20 L80,20 L80,26 L86,26 L86,36 L68,36 Z"
    b.part(teeth, b.lin([GOLD, GOLD_MID, GOLD_DK], x2=1, y2=0))
    b.part(rr(52, 80, 24, 10, 3), b.lin([GOLD_HI, GOLD_MID], x2=1, y2=0))
    b.part(bow, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1),
           [sh(circ(70, 114, 20), GOLD_DK, 0.35)], rule="evenodd")
    for a in (0, 90, 180, 270):
        x, y = 64 + 14.5 * math.cos(math.radians(a)), 108 + 14.5 * math.sin(math.radians(a))
        b.add(sh(circ(x, y, 2.2), GOLD_DK))
    b.add(hl("M60,10 L62,10 L62,78 L60,78 Z", 0.8))
    b.add(hl("M50,100 C52,94 56,90 62,89 C58,93 55,97 54,102 Z", 0.8))
    b.add("</g>")
    return b.svg()


def i_map():
    b = B("map")
    p1 = "M12,26 L46,14 L46,104 L12,116 Z"
    p2 = "M46,14 L82,26 L82,116 L46,104 Z"
    p3 = "M82,26 L116,14 L116,104 L82,116 Z"
    b.part(p1, PARCH, [sh(ell(26, 50, 14, 10), "#9CC48A", 0.9), sh(ell(40, 90, 10, 8), "#9CC48A", 0.9),
                       sh("M12,66 C22,62 32,70 46,64 L46,76 C32,82 22,74 12,78 Z", "#8FC1E3", 0.9)])
    b.part(p2, PARCH_DK, [sh(ell(64, 44, 14, 10), "#86AE73", 0.9),
                          sh("M46,64 C56,60 70,72 82,66 L82,78 C70,84 56,72 46,76 Z", "#76A8CC", 0.9)])
    b.part(p3, PARCH, [sh(ell(100, 80, 14, 12), "#9CC48A", 0.9),
                       sh("M82,66 C92,60 104,64 116,56 L116,68 C104,76 92,72 82,78 Z", "#8FC1E3", 0.9)])
    b.add(f'<path d="M24,100 C34,84 52,90 60,72 C66,58 84,60 96,44" fill="none" stroke="{RUBY_DK}" '
          f'stroke-width="3" stroke-dasharray="5 4" stroke-linecap="round"/>')
    b.add(line("M90,32 L102,44 M102,32 L90,44", O, 8), line("M90,32 L102,44 M102,32 L90,44", RUBY, 4))
    # triangle mountains
    b.part("M52,36 L58,26 L64,36 Z", "#A8915F", sw=2.5)
    b.part("M62,38 L70,24 L78,38 Z", "#A8915F", sw=2.5)
    b.add(hl("M16,30 L42,20 L42,23 L16,33 Z", 0.6))
    return b.svg()


def i_bread():
    b = B("bread")
    loaf = "M12,82 C10,52 36,30 68,30 C100,30 118,52 116,78 C114,96 98,104 64,104 C30,104 13,98 12,82 Z"
    b.part(loaf, b.lin(["#F2C27A", "#D08C42", "#8A5226"], x2=0.6, y2=1), [
        sh("M0,84 C30,98 100,98 128,80 L128,128 L0,128 Z", "#7A4620", 0.65),
        sh(ell(50, 46, 26, 10), "#FFE3A8", 0.55),
    ])
    for x in (38, 62, 86):
        cut = f"M{x - 10},{78} C{x - 6},{62} {x + 2},{50} {x + 10},{44} C{x + 6},{56} {x},{68} {x - 4},{80} Z"
        b.part(cut, b.lin(["#FFF0C8", "#F0D29A"], x2=1, y2=0), sw=3)
    b.add(hl("M26,58 C32,46 44,38 56,36 C46,42 36,50 30,60 Z", 0.6))
    b.add(sh(circ(98, 60, 1.5), "#FFF6DD", 0.9), sh(circ(92, 76, 1.5), "#FFF6DD", 0.9), sh(circ(28, 80, 1.5), "#FFF6DD", 0.9))
    return b.svg()


def i_coin_pouch():
    b = B("coin_pouch")
    sack = "M40,46 C24,58 14,80 20,98 C26,116 96,116 102,98 C108,80 98,58 82,46 Z"
    b.part(sack, b.lin(["#C08A55", LEATHER, LEATHER_DK], x2=1, y2=1), [
        sh("M70,40 C96,56 108,84 102,124 L128,124 L128,40 Z", LEATHER_DK, 0.6),
        line("M44,60 C40,72 38,86 40,100 M60,58 C58,72 58,88 60,104", LEATHER_DK, 2.5, 0.7),
    ])
    neck = "M44,48 L80,48 L90,22 C80,28 72,16 62,22 C52,16 44,28 34,22 Z"
    b.part(neck, b.lin(["#C08A55", LEATHER], x2=0, y2=1), [line("M50,30 L54,46 M62,26 L62,46 M74,28 L70,46", LEATHER_DK, 2, 0.7)])
    b.add(line("M38,48 C52,54 72,54 86,48", O, 10), line("M38,48 C52,54 72,54 86,48", GOLD_MID, 5))
    b.add(line("M44,52 C40,62 34,66 28,66", O, 7), line("M44,52 C40,62 34,66 28,66", GOLD_MID, 3))
    # emblem
    b.part(circ(62, 84, 13), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1), sw=3.5)
    b.add(sh(poly(star_pts(62, 84, 7, 3, 5)), GOLD_DK))
    # spilled coins
    for (cx, cy) in ((100, 110), (114, 100)):
        b.part(ell(cx, cy, 10, 6), b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1), [sh(ell(cx, cy + 3, 10, 6), GOLD_DK, 0.5)], sw=3.5)
    b.add(hl("M28,74 C32,64 38,56 46,52 C40,60 36,68 34,78 Z", 0.5))
    return b.svg()


def i_chest():
    b = B("chest")
    lid = "M14,58 L14,44 C14,28 34,18 64,18 C94,18 114,28 114,44 L114,58 Z"
    body = rr(14, 58, 100, 56, 3)
    wood = b.lin(["#A8723D", WOOD, WOOD_DK], x2=0, y2=1)
    b.part(lid, wood, [line("M14,36 C40,28 88,28 114,36", WOOD_DK, 2.5, 0.8),
                       sh("M90,10 H120 V60 H90 Z", WOOD_DK, 0.4)])
    b.part(body, wood, [line("M14,76 H114 M14,94 H114", WOOD_DK, 2.5, 0.8),
                        sh("M90,58 H120 V118 H90 Z", WOOD_DK, 0.4)])
    gold = b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1)
    for x in (24, 92):
        b.part(rr(x, 20, 12, 94, 2), gold, sw=3.5)
    b.part(rr(12, 54, 104, 8, 3), gold, sw=3.5)
    lock = "M52,54 L76,54 L76,76 L64,84 L52,76 Z"
    b.part(lock, b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1))
    b.add(sh("M64,62 a3.5,3.5 0 1 1 -0.01,0 Z M62,65 H66 L67,74 H61 Z", O))
    b.add(hl("M30,24 L34,24 L34,50 L30,50 Z", 0.7), hl("M20,40 C24,30 36,24 50,22 C38,28 28,34 24,44 Z", 0.5))
    return b.svg()


# ----------------------------------------------------------------------------
# skills / abilities (emblems with inner glow)
# ----------------------------------------------------------------------------
def i_fireball():
    b = B("fireball")
    b.glow(78, 50, 46, FIRE_O, 0.45)
    outer = ("M80,18 C100,18 112,34 110,54 C108,74 92,84 76,82 C64,94 44,106 14,114 C28,100 34,92 38,86 "
             "C28,88 22,90 14,90 C26,78 38,68 46,62 C40,56 42,50 48,42 C54,28 66,18 80,18 Z")
    b.part(outer, b.lin([FIRE_O, FIRE_R, "#A8321A"], x1=1, y1=0, x2=0, y2=1))
    mid = ("M80,28 C94,28 102,40 100,54 C98,68 88,74 76,72 C64,82 50,92 32,98 C42,88 46,82 50,76 "
           "C44,76 38,78 32,78 C42,70 52,62 56,58 C52,52 54,46 58,40 C62,32 70,28 80,28 Z")
    b.add(sh(mid, FIRE_O))
    b.add(sh(circ(80, 50, 15), b.rad(["#FFFBEA", FIRE_Y, (1, FIRE_O, 0.0)], r=0.5)))
    b.add(sh(circ(80, 50, 12), FIRE_Y, 0.9))
    b.add(hl(ell(76, 44, 5, 4), 0.9))
    b.add(hl(sparkle(110, 22, 6), 0.8))
    return b.svg()


def i_frost_shard():
    b = B("frost_shard")
    b.glow(64, 64, 54, FROST, 0.4)
    fg = b.lin(["#FFFFFF", FROST_HI, FROST], x2=1, y2=0)
    b.add(rot(40))
    b.part("M64,-2 L80,58 L64,130 L48,58 Z", fg, [sh("M64,-2 L80,58 L64,130 Z", FROST_DK, 0.55),
                                                  line("M48,58 L64,62 L80,58", FROST_DK, 2, 0.7)])
    b.add(hl("M62,8 L64,8 L52,58 L50,58 Z", 0.8))
    b.add("</g>")
    for (cx, cy, r, a) in ((30, 34, 15, -40), (100, 96, 13, -40)):
        b.add(rot(a, cx, cy))
        b.part(poly([(cx, cy - r), (cx + r * 0.42, cy), (cx, cy + r), (cx - r * 0.42, cy)]), fg,
               [sh(poly([(cx, cy - r), (cx + r * 0.42, cy), (cx, cy + r)]), FROST_DK, 0.55)], sw=4)
        b.add("</g>")
    b.add(hl(sparkle(104, 26, 7), 0.95), hl(sparkle(22, 96, 5), 0.85))
    return b.svg()


def i_lightning():
    b = B("lightning")
    b.glow(64, 64, 58, "#FFE680", 0.4)
    bolt = "M80,6 L28,70 L58,70 L42,122 L102,50 L70,50 L92,6 Z"
    b.part(bolt, b.lin(["#FFFBE0", FIRE_Y, "#F2B23A"], x2=1, y2=1),
           [sh("M92,6 L70,50 L102,50 L42,122 L120,122 L120,6 Z", "#E89B2C", 0.55)])
    b.add(hl("M76,14 L84,14 L44,64 L38,64 Z", 0.75))
    for d in ("M24,34 L16,28", "M104,82 L114,88", "M22,96 L14,100", "M108,30 L116,24"):
        b.add(line(d, O, 7), line(d, FIRE_Y, 3))
    return b.svg()


def i_arcane_orb():
    b = B("arcane_orb")
    b.glow(64, 64, 60, TEAL, 0.5)
    ring = ell(64, 64, 56, 15)
    # back half of the ring
    b.add(f'<g transform="rotate(-25 64 64)">', line("M8,64 A56,15 0 0 1 120,64", O, 9),
          line("M8,64 A56,15 0 0 1 120,64", GOLD_MID, 4), "</g>")
    b.part(circ(64, 64, 36), b.rad(["#FFFFFF", TEAL_HI, TEAL, "#1F5F7A", "#2A2050"], fx=0.38, fy=0.32, r=0.62))
    b.add(line("M44,74 C50,58 70,52 82,62 C88,68 80,80 70,76", "#FFFFFF", 3, 0.55))
    b.add(line("M50,48 C58,42 72,42 80,48", "#FFFFFF", 2.5, 0.4))
    b.add(hl(ell(52, 50, 8, 5.5), 0.85))
    b.add(f'<g transform="rotate(-25 64 64)">', line("M8,64 A56,15 0 0 0 120,64", O, 9),
          line("M8,64 A56,15 0 0 0 120,64", GOLD, 4), "</g>")
    _ = ring
    b.add(hl(sparkle(104, 22, 7), 0.95), hl(sparkle(22, 104, 5), 0.85), hl(sparkle(26, 26, 4), 0.7))
    return b.svg()


def i_heal():
    b = B("heal")
    b.glow(64, 64, 60, EMER, 0.5)
    cross = ("M52,16 L76,16 Q82,16 82,22 L82,46 L106,46 Q112,46 112,52 L112,76 Q112,82 106,82 L82,82 "
             "L82,106 Q82,112 76,112 L52,112 Q46,112 46,106 L46,82 L22,82 Q16,82 16,76 L16,52 Q16,46 22,46 "
             "L46,46 L46,22 Q46,16 52,16 Z")
    b.part(cross, b.lin(["#E6FFD9", EMER_HI, EMER, EMER_DK], x2=1, y2=1),
           [sh("M64,64 L112,64 L112,112 L64,112 Z", EMER_DK, 0.35),
            sh(circ(64, 64, 20), b.rad([(0, "#FFFFFF", 0.8), (1, "#FFFFFF", 0)]))])
    b.add(hl("M52,22 L56,22 L56,50 L52,50 Z", 0.7), hl("M22,52 L50,52 L50,56 L22,56 Z", 0.7))
    b.add(hl(sparkle(104, 22, 8), 0.95), hl(sparkle(22, 104, 6), 0.85), hl(sparkle(110, 108, 4), 0.7))
    return b.svg()


def i_ward():
    b = B("ward")
    b.glow(64, 64, 60, SAPH, 0.45)
    hexo = poly([(64 + 54 * math.cos(math.radians(a)), 64 + 54 * math.sin(math.radians(a))) for a in range(-90, 270, 60)])
    hexi = poly([(64 + 40 * math.cos(math.radians(a)), 64 + 40 * math.sin(math.radians(a))) for a in range(-90, 270, 60)])
    b.part(hexo, b.rad([(0, SAPH_HI, 0.9), (0.6, SAPH, 0.85), (1, SAPH_DK, 0.95)], r=0.6))
    b.part(hexi, b.rad([(0, "#FFFFFF", 0.9), (0.5, SAPH_HI, 0.8), (1, SAPH, 0.8)], r=0.6), sw=3)
    for a in range(-90, 270, 60):
        x1, y1 = 64 + 40 * math.cos(math.radians(a)), 64 + 40 * math.sin(math.radians(a))
        x2, y2 = 64 + 54 * math.cos(math.radians(a)), 64 + 54 * math.sin(math.radians(a))
        b.add(line(f"M{_n(x1)},{_n(y1)} L{_n(x2)},{_n(y2)}", O, 2.5))
    # rune
    rune = "M64,40 L64,88 M50,52 L64,40 L78,52 M50,72 L78,72"
    b.add(line(rune, O, 10), line(rune, GOLD, 5))
    b.add(hl("M26,42 L62,20 L62,26 L30,46 Z", 0.5))
    return b.svg()


def i_dash():
    b = B("dash")
    for (dx, op) in ((-36, 0.45), (-18, 0.7)):
        d = f"M{50 + dx},18 L{104 + dx},64 L{50 + dx},110 L{36 + dx},96 L{74 + dx},64 L{36 + dx},32 Z"
        b.part(d, b.lin([FROST_HI, SAPH], x2=1, y2=1), sw=4, op=op)
    main = "M54,16 L112,64 L54,112 L38,96 L78,64 L38,32 Z"
    b.part(main, b.lin(["#FFFFFF", FROST_HI, SAPH], x2=1, y2=1),
           [sh("M78,64 L112,64 L54,112 L38,96 Z", SAPH_DK, 0.45)])
    b.add(hl("M54,22 L100,62 L94,62 L50,26 Z", 0.6))
    for (y, x0, x1) in ((40, 8, 24), (64, 4, 30), (88, 8, 24)):
        b.add(line(f"M{x0},{y} L{x1},{y}", O, 9), line(f"M{x0},{y} L{x1},{y}", FROST_HI, 4))
    return b.svg()


def i_poison():
    b = B("poison")
    b.glow(64, 70, 56, POISON, 0.4)
    drop = "M64,8 C76,30 102,54 102,80 C102,102 86,118 64,118 C42,118 26,102 26,80 C26,54 52,30 64,8 Z"
    b.part(drop, b.lin(["#E2FFAE", POISON, POISON_DK], x2=1, y2=1),
           [sh("M64,8 L128,8 L128,128 L72,128 C92,112 100,96 100,80 C100,56 76,30 64,8 Z", POISON_DK, 0.45)])
    skull = ("M64,58 C76,58 84,66 84,76 C84,82 81,86 78,88 L78,96 L50,96 L50,88 C47,86 44,82 44,76 "
             "C44,66 52,58 64,58 Z")
    b.add(sh(skull, "#2F4A12", 0.9))
    b.add(sh(circ(56, 76, 5), POISON), sh(circ(72, 76, 5), POISON), sh("M64,82 L67,88 L61,88 Z", POISON))
    b.add(line("M58,92 V96 M64,92 V96 M70,92 V96", POISON, 2))
    b.add(hl("M44,58 C48,46 56,34 62,24 C60,38 54,50 50,62 Z", 0.7))
    for (x, y, r) in ((98, 28, 6), (110, 46, 4), (22, 40, 4.5)):
        b.part(circ(x, y, r), b.rad(["#E2FFAE", POISON], fx=0.35, fy=0.3), sw=3)
    return b.svg()


def i_meteor():
    b = B("meteor")
    b.glow(76, 52, 50, FIRE_O, 0.4)
    trail = ("M24,74 C40,52 70,30 114,8 C98,28 90,36 84,42 C98,36 110,34 120,34 C102,48 92,56 86,62 "
             "C96,60 106,60 114,62 C94,74 78,88 64,106 Z")
    b.part(trail, b.lin([FIRE_Y, FIRE_O, FIRE_R], x1=1, y1=0, x2=0, y2=1))
    b.add(sh("M38,74 C54,58 74,42 100,26 C88,40 80,46 74,52 C86,48 96,46 104,46 C88,58 80,64 74,70 "
             "C82,70 90,70 96,72 C80,80 70,88 62,98 Z", FIRE_Y, 0.95))
    rock = "M44,60 C58,58 70,68 70,82 C70,98 58,110 42,110 C26,110 16,98 18,84 C20,70 30,62 44,60 Z"
    b.part(rock, b.rad(["#8A7F86", "#5A4F58", "#2E2630"], fx=0.4, fy=0.35, r=0.65), [
        line("M30,78 L42,86 L38,98 M42,86 L56,80 M48,100 L56,92", FIRE_O, 3),
        sh(circ(56, 74, 5), "#3A3038"), sh(circ(30, 96, 4), "#3A3038"),
        sh("M60,62 C74,70 76,90 66,104 L80,104 L80,60 Z", FIRE_R, 0.45),
    ])
    b.add(hl(ell(36, 72, 6, 4), 0.6))
    b.add(hl(sparkle(24, 30, 5), 0.8))
    return b.svg()


def i_blizzard():
    b = B("blizzard")
    b.glow(64, 64, 58, FROST, 0.45)
    swirl = "M14,44 C30,20 70,16 92,30 M114,84 C98,108 58,112 36,98"
    b.add(line(swirl, O, 9, 0.9), line(swirl, FROST_HI, 4, 0.9))
    arms = []
    for k in range(6):
        a = math.radians(k * 60 - 90)
        ca, sa = math.cos(a), math.sin(a)

        def P(r, off):
            return (64 + r * ca - off * sa, 64 + r * sa + off * ca)
        arms.append(f"M64,64 L{_n(P(46, 0)[0])},{_n(P(46, 0)[1])}")
        for (r, s) in ((24, 10), (36, 8)):
            p, q, c = P(r + s, s), P(r + s, -s), P(r, 0)
            arms.append(f"M{_n(p[0])},{_n(p[1])} L{_n(c[0])},{_n(c[1])} L{_n(q[0])},{_n(q[1])}")
    d = " ".join(arms)
    fg = b.lin(["#FFFFFF", FROST_HI, FROST], x1=20, y1=20, x2=108, y2=108, user=True)
    b.add(line(d, O, 15), line(d, fg, 6.5))
    hexa = poly([(64 + 11 * math.cos(math.radians(a)), 64 + 11 * math.sin(math.radians(a))) for a in range(-90, 270, 60)])
    b.part(hexa, b.lin(["#FFFFFF", FROST], x2=1, y2=1), sw=3.5)
    b.add(hl(sparkle(106, 18, 6), 0.9), hl(sparkle(20, 110, 5), 0.85))
    return b.svg()


def i_drain():
    b = B("drain")
    b.glow(64, 64, 60, AMET, 0.5)
    sg = b.lin([AMET_HI, AMET, AMET_DK], x1=10, y1=10, x2=118, y2=118, user=True)
    for k in range(2):
        pts = []
        for i in range(31):
            t = i / 30
            a = math.radians(k * 180 + 200 + t * 280)
            r = 52 - 34 * t
            pts.append((64 + r * math.cos(a), 64 + r * math.sin(a)))
        d = poly(pts, close=False)
        b.add(line(d, O, 14), line(d, sg, 5.5))
        b.add(line(poly(pts[:12], close=False), "#FFFFFF", 1.8, 0.45))
        # blood drops being pulled in along the arm
        for j, s in ((4, 6), (14, 4.5)):
            x, y = pts[j]
            b.part(circ(x, y, s), b.rad(["#FF9A9C", RUBY, RUBY_DK], fx=0.35, fy=0.3), sw=3)
    heart = ("M64,80 C52,72 46,66 46,58 C46,52 50,48 55,48 C59,48 62,50 64,53 C66,50 69,48 73,48 "
             "C78,48 82,52 82,58 C82,66 76,72 64,80 Z")
    b.part(heart, b.lin(["#FF9A9C", RUBY, RUBY_DK], x2=1, y2=1))
    b.add(hl(ell(55, 55, 3.5, 2.5), 0.9))
    return b.svg()


def i_haste():
    b = B("haste")
    b.glow(72, 68, 52, FIRE_Y, 0.35)
    for (y, x0, x1) in ((50, 6, 26), (70, 4, 22), (90, 8, 28)):
        b.add(line(f"M{x0},{y} L{x1},{y}", O, 9), line(f"M{x0},{y} L{x1},{y}", TEAL_HI, 4))
    b.part(rr(64, 6, 16, 12, 3), b.lin([GOLD_HI, GOLD_DK], x2=1, y2=1), sw=4)
    b.part("M68,16 L76,16 L76,28 L68,28 Z", GOLD_MID, sw=4)
    b.part(rr(98, 22, 12, 10, 3), GOLD_MID, sw=4)
    b.part(circ(72, 72, 44), b.lin([GOLD_HI, GOLD, GOLD_MID, GOLD_DK], x2=1, y2=1))
    b.part(circ(72, 72, 34), b.rad(["#FFFFFF", PARCH, PARCH_DK], fx=0.4, fy=0.35, r=0.6), sw=3.5)
    for k in range(12):
        a = math.radians(k * 30)
        r0 = 27 if k % 3 == 0 else 30
        b.add(line(f"M{_n(72 + r0 * math.cos(a))},{_n(72 + r0 * math.sin(a))} L{_n(72 + 33 * math.cos(a))},{_n(72 + 33 * math.sin(a))}",
                   "#7A6440", 2.5 if k % 3 == 0 else 1.8))
    b.add(line("M72,72 L72,48", O, 5), line("M72,72 L90,82", RUBY, 4))
    b.part(circ(72, 72, 4), GOLD_DK, sw=2.5)
    b.add(f'<path d="M72,38 A34,34 0 0 1 106,72 L72,72 Z" fill="{TEAL}" opacity="0.3"/>')
    b.add(hl("M38,58 C42,46 50,38 60,34 C52,42 46,50 42,60 Z", 0.75))
    return b.svg()


def i_rage():
    b = B("rage")
    b.glow(64, 64, 60, FIRE_R, 0.5)
    burst = poly(star_pts(64, 64, 58, 34, 10, -90))
    b.part(burst, b.rad([FIRE_Y, FIRE_O, FIRE_R, "#8E2329"], r=0.55),
           [sh(poly(star_pts(64, 64, 42, 26, 10, -72)), FIRE_O, 0.6)])
    # anger vein symbol
    vein = ("M52,38 C52,48 50,52 40,52 M76,38 C76,48 78,52 88,52 M52,90 C52,80 50,76 40,76 "
            "M76,90 C76,80 78,76 88,76")
    b.add(line(vein, O, 13), line(vein, "#B3171E", 6))
    b.add(line("M50,40 C50,46 48,48 44,50", "#FF8A8A", 2, 0.8))
    b.add(hl(sparkle(106, 22, 6), 0.8))
    return b.svg()


def i_stealth():
    b = B("stealth")
    b.glow(64, 64, 58, AMET, 0.4)
    # smoke wisps
    smoke = "M14,104 C26,94 38,110 50,100 M78,100 C90,110 102,94 114,104 M24,118 C40,110 52,122 64,114 C76,122 88,110 104,118"
    b.add(line(smoke, AMET_HI, 5, 0.6))
    hood = ("M64,10 C88,10 104,30 106,54 C108,74 112,92 118,108 C98,104 82,110 64,106 "
            "C46,110 30,104 10,108 C16,92 20,74 22,54 C24,30 40,10 64,10 Z")
    b.part(hood, b.lin(["#6E4A9E", "#3B2660", "#1E1233"], x2=1, y2=1), [
        sh("M64,10 C88,10 104,30 106,54 L128,54 L128,128 L80,128 Z", "#140B24", 0.5),
        line("M30,70 C28,84 26,96 22,104 M98,70 C100,84 102,96 106,104", "#140B24", 3, 0.8),
    ])
    face = "M64,26 C80,26 90,38 90,54 C90,70 80,82 64,84 C48,82 38,70 38,54 C38,38 48,26 64,26 Z"
    b.part(face, "#0C0612", sw=3)
    for x, s in ((53, 1), (75, -1)):
        eye = f"M{x - 8 * s},{52} C{x - 4 * s},{48} {x + 4 * s},{48} {x + 8 * s},{56} C{x + 2 * s},{58} {x - 4 * s},{56} {x - 8 * s},{52} Z"
        b.add(sh(eye, TEAL), sh(eye, "#FFFFFF", 0.4))
    b.add(hl("M30,36 C36,22 48,14 58,13 C48,20 40,30 36,42 Z", 0.45))
    return b.svg()


def i_spirit_wolf():
    b = B("spirit_wolf")
    b.glow(64, 64, 60, TEAL, 0.5)
    head = ("M64,116 L48,98 L30,90 L22,70 L14,64 L22,54 L18,14 L44,36 L64,32 L84,36 L110,14 "
            "L106,54 L114,64 L106,70 L98,90 L80,98 Z")
    b.part(head, b.lin(["#E6FFFB", TEAL_HI, TEAL, TEAL_DK], x2=0.6, y2=1), [
        sh("M64,30 L128,0 L128,128 L64,128 Z", TEAL_DK, 0.3),
        sh("M22,20 L40,36 L28,50 Z", TEAL_DK, 0.7), sh("M106,20 L88,36 L100,50 Z", TEAL_DK, 0.7),
        sh("M64,40 L74,58 L64,104 L54,58 Z", "#FFFFFF", 0.35),
    ])
    for x, s in ((46, 1), (82, -1)):
        eye = f"M{x - 10 * s},56 L{x + 6 * s},60 L{x - 4 * s},64 Z"
        b.add(sh(eye, O), sh(f"M{x - 6 * s},58 L{x + 2 * s},60 L{x - 3 * s},62 Z", "#FFFFFF"))
    b.add(sh("M56,92 L72,92 L64,102 Z", O))
    b.add(line("M64,102 L64,108 M56,108 C60,112 68,112 72,108", O, 2.5, 0.8))
    b.add(line("M22,70 L34,78 M106,70 L94,78", TEAL_DK, 2.5, 0.8))
    b.add(hl(sparkle(18, 104, 5), 0.85), hl(sparkle(112, 102, 6), 0.9))
    return b.svg()


def i_thorns():
    b = B("thorns")
    b.glow(64, 64, 46, EMER, 0.4)
    tg = b.lin(["#F0E2B0", "#C9A86A", "#6B4426"], x2=1, y2=1)
    for k in range(8):
        a = math.radians(k * 45 + 8)
        for (r0, r1, wid, bend) in ((38, 60, 0.2, 0.22), (30, 16, 0.24, -0.3)):
            b1 = (64 + r0 * math.cos(a - wid), 64 + r0 * math.sin(a - wid))
            b2 = (64 + r0 * math.cos(a + wid), 64 + r0 * math.sin(a + wid))
            tip = (64 + r1 * math.cos(a + bend), 64 + r1 * math.sin(a + bend))
            mid = (64 + (r0 + r1) / 2 * math.cos(a + bend * 0.2), 64 + (r0 + r1) / 2 * math.sin(a + bend * 0.2))
            d = (f"M{_n(b1[0])},{_n(b1[1])} Q{_n(mid[0])},{_n(mid[1])} {_n(tip[0])},{_n(tip[1])} "
                 f"L{_n(b2[0])},{_n(b2[1])} Z")
            if r1 > r0 or k % 2 == 0:
                b.part(d, tg, sw=3.5)
    vine = circ(64, 64, 34)
    b.add(line(vine, O, 17), line(vine, "#4E8A3A", 9))
    b.add(f'<path d="{vine}" fill="none" stroke="#2C5A22" stroke-width="3" stroke-dasharray="7 9" '
          f'stroke-linecap="round" transform="rotate(10 64 64)"/>')
    b.add(line("M34,48 C40,38 48,33 56,31", "#B4EDB0", 3, 0.8))
    for (x, y, a) in ((92, 36, -70), (36, 92, 110)):
        d, half, vein = _leaf(x, y, a, 26, 10)
        b.part(d, b.lin([EMER_HI, EMER, EMER_DK], x2=1, y2=1), [sh(half, "#FFFFFF", 0.3)], sw=4)
        b.add(line(vein, EMER_DK, 2))
    return b.svg()


def i_smite():
    b = B("smite")
    b.glow(64, 52, 60, FIRE_Y, 0.55)
    rays = []
    for k in range(12):
        a = math.radians(k * 30 - 90)
        rays.append(poly([(64 + 14 * math.cos(a - 0.2), 44 + 14 * math.sin(a - 0.2)),
                          (64 + 56 * math.cos(a), 44 + 50 * math.sin(a)),
                          (64 + 14 * math.cos(a + 0.2), 44 + 14 * math.sin(a + 0.2))]))
    b.add(sh(" ".join(rays), "#FFF0B0", 0.6))
    # sword pointing down
    blade = "M64,124 L54,104 L54,40 L74,40 L74,104 Z"
    b.part(blade, b.lin(["#FFFFFF", "#FFF6DA", GOLD], x2=1, y2=0),
           [sh("M64,124 L74,104 L74,40 L64,40 Z", GOLD_MID, 0.6)])
    b.add(line("M64,48 L64,104", GOLD_DK, 2.5, 0.7))
    b.part("M30,32 C40,38 88,38 98,32 L100,42 C88,46 40,46 28,42 Z", b.lin([GOLD_HI, GOLD, GOLD_DK], x2=1, y2=1))
    b.part(rr(58, 14, 12, 20, 2), b.lin([GOLD_MID, GOLD_DK], x2=1, y2=0))
    b.part(circ(64, 11, 6), b.lin([GOLD_HI, GOLD], x2=1, y2=1), sw=4)
    b.part(circ(64, 38, 5), b.rad([SAPH_HI, SAPH, SAPH_DK], fx=0.35, fy=0.3), sw=2.5)
    b.add(hl("M56,46 L58,46 L58,100 L56,100 Z", 0.8))
    b.add(hl(sparkle(20, 24, 7), 0.95), hl(sparkle(108, 20, 6), 0.9), hl(sparkle(100, 96, 5), 0.8))
    return b.svg()


def _arc_arrow(b, cx, cy, r, a0, a1, w, color):
    p0 = (cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0)))
    a = math.radians(a1)
    p1 = (cx + r * math.cos(a), cy + r * math.sin(a))
    large = 1 if (a1 - a0) % 360 > 180 else 0
    arc = f"M{_n(p0[0])},{_n(p0[1])} A{r},{r} 0 {large} 1 {_n(p1[0])},{_n(p1[1])}"
    t = (-math.sin(a), math.cos(a))
    n = (math.cos(a), math.sin(a))
    tip = (p1[0] + t[0] * 16, p1[1] + t[1] * 16)
    l = (p1[0] + n[0] * 13 - t[0] * 2, p1[1] + n[1] * 13 - t[1] * 2)
    rt = (p1[0] - n[0] * 13 - t[0] * 2, p1[1] - n[1] * 13 - t[1] * 2)
    b.add(line(arc, O, w + 2 * SW), line(arc, color, w))
    b.part(poly([tip, l, rt]), color, sw=SW)
    b.add(line(arc, "#FFFFFF", 2.2, 0.45))


def i_regen():
    b = B("regen")
    b.glow(64, 64, 58, EMER, 0.45)
    eg = b.lin(["#E6FFD9", EMER_HI, EMER, EMER_DK], x2=1, y2=1)
    _arc_arrow(b, 64, 64, 42, 190, 300, 10, EMER)
    _arc_arrow(b, 64, 64, 42, 10, 120, 10, EMER)
    d, half, vein = _leaf(42, 86, -45, 62, 22)
    b.part(d, eg, [sh(half, "#FFFFFF", 0.35)], sw=4)
    b.add(line(vein, EMER_DK, 2.5))
    b.add(hl(sparkle(108, 106, 6), 0.9), hl(sparkle(20, 22, 5), 0.85))
    return b.svg()


# ----------------------------------------------------------------------------
# GLYPHS (64x64, white only)
# ----------------------------------------------------------------------------
W = "#FFFFFF"


def gs(d, w=5.5, op=None):
    o = f' opacity="{op}"' if op is not None else ""
    return (f'<path d="{d}" fill="none" stroke="{W}" stroke-width="{w}" stroke-linecap="round" '
            f'stroke-linejoin="round"{o}/>')


def gf(d, op=None, rule=None, round_=0):
    o = f' opacity="{op}"' if op is not None else ""
    r = f' fill-rule="{rule}"' if rule else ""
    s = f' stroke="{W}" stroke-width="{round_}" stroke-linejoin="round"' if round_ else ""
    return f'<path d="{d}" fill="{W}"{r}{s}{o}/>'


def masked(name, shapes, holes):
    mid = f"{name}_mask"
    return (f'<defs><mask id="{mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="64" height="64">'
            f'<rect width="64" height="64" fill="#FFFFFF"/>{holes}</mask></defs>'
            f'<g mask="url(#{mid})">{shapes}</g>')


def _gear():
    pts = []
    n = 8
    for k in range(n):
        a0 = math.radians(k * 360 / n)
        for da, r in ((-0.30, 20), (-0.17, 27), (0.17, 27), (0.30, 20)):
            pts.append((32 + r * math.cos(a0 + da), 32 + r * math.sin(a0 + da)))
    return poly(pts) + " " + circ(32, 32, 8)


def _refresh():
    cx, cy, r = 32, 32, 19
    a0, a1 = math.radians(20), math.radians(290)
    p0 = (cx + r * math.cos(a0), cy + r * math.sin(a0))
    p1 = (cx + r * math.cos(a1), cy + r * math.sin(a1))
    arc = f"M{_n(p0[0])},{_n(p0[1])} A{r},{r} 0 1 1 {_n(p1[0])},{_n(p1[1])}"
    t = (-math.sin(a1), math.cos(a1))      # direction of travel at end
    nrm = (math.cos(a1), math.sin(a1))
    tip = (p1[0] + t[0] * 9, p1[1] + t[1] * 9)
    l = (p1[0] + nrm[0] * 8 - t[0] * 2, p1[1] + nrm[1] * 8 - t[1] * 2)
    rt = (p1[0] - nrm[0] * 8 - t[0] * 2, p1[1] - nrm[1] * 8 - t[1] * 2)
    return gs(arc) + gf(poly([tip, l, rt]), round_=2.5)


def _snow():
    d = []
    for k in range(3):
        a = math.radians(k * 60 + 90)
        ca, sa = math.cos(a), math.sin(a)
        d.append(f"M{_n(32 - 25 * ca)},{_n(32 - 25 * sa)} L{_n(32 + 25 * ca)},{_n(32 + 25 * sa)}")
    for k in range(6):
        a = math.radians(k * 60 + 90)
        ca, sa = math.cos(a), math.sin(a)

        def P(r, o):
            return (32 + r * ca - o * sa, 32 + r * sa + o * ca)
        p, c, q = P(24, 6), P(16, 0), P(24, -6)
        d.append(f"M{_n(p[0])},{_n(p[1])} L{_n(c[0])},{_n(c[1])} L{_n(q[0])},{_n(q[1])}")
    return gs(" ".join(d), 4.5)


GLYPHS = {
    "close": gs("M18,18 L46,46 M46,18 L18,46", 6.5),
    "check": gs("M13,34 L26,47 L51,20", 6.5),
    "lock": gs("M22,29 V22 C22,10 42,10 42,22 V29", 5.5) + gf(
        rr(13, 27, 38, 30, 6) + " M32,35 a5,5 0 0 1 2.6,9.3 L36,50 H28 L29.4,44.3 A5,5 0 0 1 32,35 Z", rule="evenodd"),
    "unlock": gs("M22,29 V19 C22,8 41,7 42,17", 5.5) + gf(
        rr(13, 27, 38, 30, 6) + " M32,35 a5,5 0 0 1 2.6,9.3 L36,50 H28 L29.4,44.3 A5,5 0 0 1 32,35 Z", rule="evenodd"),
    "search": gs(circ(27, 27, 15), 5.5) + gs("M38,38 L53,53", 7.5),
    "sort": gs("M21,52 V12 M11,22 L21,12 L31,22 M43,12 V52 M33,42 L43,52 L53,42", 5.5),
    "filter": gf("M9,12 H55 L37,33 V50 L27,56 V33 Z", round_=4),
    "chevron_down": gs("M14,24 L32,42 L50,24", 7),
    "chevron_up": gs("M14,40 L32,22 L50,40", 7),
    "chevron_right": gs("M24,14 L42,32 L24,50", 7),
    "chevron_left": gs("M40,14 L22,32 L40,50", 7),
    "plus": gs("M32,12 V52 M12,32 H52", 7),
    "minus": gs("M12,32 H52", 7),
    "star": gf(poly(star_pts(32, 33.5, 27, 11.5, 5)), round_=3),
    "star_outline": gs(poly(star_pts(32, 34, 25, 11, 5)), 4.5),
    "gear": gf(_gear(), rule="evenodd", round_=2),
    "quest": gf("M26,8 H38 L35,40 H29 Z", round_=4) + gf(circ(32, 52, 5.5)),
    "hourglass": gs("M12,8 H52 M12,56 H52", 5.5) + gs(
        "M18,9 C18,24 29,27 29,32 C29,37 18,40 18,55 M46,9 C46,24 35,27 35,32 C35,37 46,40 46,55", 4.5)
        + gf("M23,52 H41 C41,46 36,42 32,40 C28,42 23,46 23,52 Z") + gf("M24,15 H40 C38,20 34,23 32,25 C30,23 26,20 24,15 Z", op=0.55),
    "coin": gf(circ(32, 32, 26) + " " + circ(32, 32, 21) + " " + circ(32, 32, 17.5) + " "
               + poly([(32, 21), (40, 32), (32, 43), (24, 32)]), rule="evenodd"),
    "gem": gf("M20,9 H44 L56,23 H8 Z", round_=2) + gf("M8,28 H56 L32,57 Z", round_=2, op=0.75),
    "trash": gs("M10,15 H54", 5.5) + gs("M25,14 V9 H39 V14", 4.5) + gf(
        "M14,20 H50 L47,53 C46.5,56 44.5,58 41.5,58 H22.5 C19.5,58 17.5,56 17,53 Z "
        + rr(24.5, 27, 4.5, 23, 2.2) + " " + rr(35, 27, 4.5, 23, 2.2), rule="evenodd"),
    "info": gf(circ(32, 32, 26) + " " + circ(32, 19, 4) + " " + rr(28.5, 27, 7, 21, 3), rule="evenodd"),
    "swap": gs("M10,22 H50 M40,12 L50,22 L40,32 M54,42 H14 M24,32 L14,42 L24,52", 5.5),
    "sparkle": gf(sparkle(28, 34, 24, 0.2)) + gf(sparkle(50, 13, 8, 0.25), op=0.8),
    "heart": gf("M32,55 C14,43 6,33 6,23 C6,14 13,8 20,8 C26,8 30,12 32,16 C34,12 38,8 44,8 C51,8 58,14 58,23 "
                "C58,33 50,43 32,55 Z"),
    "drop": gf("M32,6 C40,20 50,30 50,40 C50,50 42,58 32,58 C22,58 14,50 14,40 C14,30 24,20 32,6 Z")
            + "",
    "bolt": gf("M37,5 L14,37 H30 L26,59 L50,26 H34 Z", round_=3),
    "skull": gf("M32,6 C46,6 55,16 55,29 C55,37 51,42 46,44 V51 C46,54 44,57 41,57 H23 C20,57 18,54 18,51 "
                "V44 C13,42 9,37 9,29 C9,16 18,6 32,6 Z " + circ(22.5, 29, 6) + " " + circ(41.5, 29, 6)
                + " M32,36 L36,43 H28 Z " + rr(26.5, 47, 3.5, 7, 1.5) + " " + rr(34, 47, 3.5, 7, 1.5), rule="evenodd"),
    "crown": gf("M8,20 L21,33 L32,10 L43,33 L56,20 L51,47 H13 Z", round_=4) + gf(rr(12, 51, 40, 6, 2.5))
             + gf(circ(8, 18, 3.5)) + gf(circ(56, 18, 3.5)) + gf(circ(32, 8, 3.5)),
    "sword_small": '<g transform="rotate(45 32 32)">' + gf("M32,3 L37.5,10 V40 H26.5 V10 Z", round_=1.5)
                   + gf(rr(19, 41, 26, 5.5, 2.5)) + gf(rr(29.5, 46, 5, 9, 1.5)) + gf(circ(32, 58, 4)) + "</g>",
    "shield_small": gf("M32,5 C40,9 48,10 55,9 V28 C55,42 45,52 32,59 C19,52 9,42 9,28 V9 C16,10 24,9 32,5 Z "
                       "M32,13 C38,16 43,17 47,16.5 V28 C47,38 41,45 32,50 Z", rule="evenodd"),
    "eye": gs("M5,32 C13,18 23,13 32,13 C41,13 51,18 59,32 C51,46 41,51 32,51 C23,51 13,46 5,32 Z", 5)
           + gf(circ(32, 32, 9.5)),
    "compass": gs(circ(32, 32, 24), 5) + '<g transform="rotate(40 32 32)">'
               + gf("M32,12 L39,32 H25 Z", round_=1.5) + gf("M25,32 H39 L32,52 Z", op=0.55, round_=1.5) + "</g>",
    "scroll_small": masked("scroll_small",
                           gf(rr(15, 13, 34, 39, 2)) + gf(rr(10, 7, 44, 11, 5.5)) + gf(rr(10, 47, 44, 11, 5.5)),
                           f'<path d="M22,26 H42 M22,33 H42 M22,40 H35" stroke="#000" stroke-width="3.5" stroke-linecap="round"/>'
                           f'<path d="M15,19.5 H49 M15,45.5 H49" stroke="#000" stroke-width="2.5"/>'),
    "hammer": '<g transform="rotate(45 32 32)">' + gf(rr(14, 12, 36, 16, 4)) + gf(rr(28.5, 30, 7, 30, 3.5)) + "</g>",
    "bag": gf("M21,24 C11,33 7,44 9,51 C11,57 53,57 55,51 C57,44 53,33 43,24 Z")
           + gf("M22,19 L17,8 C23,10 27,6 32,9 C37,6 41,10 47,8 L42,19 Z", round_=2),
    "user": gf(circ(32, 19, 11.5)) + gf("M9,57 C9,43 19,36 32,36 C45,36 55,43 55,57 Z", round_=2),
    "refresh": _refresh(),
    "arrow_up": gs("M32,53 V12 M15,29 L32,12 L49,29", 6.5),
    "arrow_down": gs("M32,11 V52 M15,35 L32,52 L49,35", 6.5),
    "pin": gf("M32,59 C22,45 12,35 12,24 C12,13 21,5 32,5 C43,5 52,13 52,24 C52,35 42,45 32,59 Z "
              + circ(32, 24, 7.5), rule="evenodd"),
    "bell": gf("M32,8 C42,8 48,16 48,26 V37 L54,45 C55,47 54,48 52,48 H12 C10,48 9,47 10,45 L16,37 V26 "
               "C16,16 22,8 32,8 Z") + gf(circ(32, 54, 5)) + gf(circ(32, 7, 3.5)),
    "flame": gf("M32,4 C37,16 49,22 49,38 C49,50 41,59 32,59 C23,59 15,50 15,40 C15,32 19,26 24,21 "
                "C24,29 27,34 30,35 C29,25 28,14 32,4 Z M32,58 C27,58 24,54 24,49 C24,44 28,40 31,36 "
                "C33,40 40,44 40,50 C40,55 36,58 32,58 Z", rule="evenodd"),
    "snow": _snow(),
}

ICONS = {
    "sword": i_sword(), "dagger": i_dagger(), "axe": i_axe(), "mace": i_mace(), "bow": i_bow(),
    "staff": i_staff(), "wand": i_wand(), "shield": i_shield(), "helm": i_helm(),
    "chestplate": i_chestplate(), "gloves": i_gloves(), "boots": i_boots(), "cloak": i_cloak(),
    "ring": i_ring(), "amulet": i_amulet(), "belt": i_belt(),
    "potion_health": i_potion_health(), "potion_mana": i_potion_mana(),
    "potion_stamina": i_potion_stamina(), "elixir": i_elixir(), "scroll": i_scroll(), "tome": i_tome(),
    "herb": i_herb(), "mushroom": i_mushroom(), "ore": i_ore(), "ingot": i_ingot(),
    "gem_ruby": i_gem_ruby(), "gem_sapphire": i_gem_sapphire(), "crystal": i_crystal(),
    "leather": i_leather(), "thread": i_thread(), "wood": i_wood(), "feather": i_feather(),
    "key": i_key(), "map": i_map(), "bread": i_bread(), "coin_pouch": i_coin_pouch(), "chest": i_chest(),
    # skills
    "fireball": i_fireball(), "frost_shard": i_frost_shard(), "lightning": i_lightning(),
    "arcane_orb": i_arcane_orb(), "heal": i_heal(), "ward": i_ward(), "dash": i_dash(),
    "poison": i_poison(), "meteor": i_meteor(), "blizzard": i_blizzard(), "drain": i_drain(),
    "haste": i_haste(), "rage": i_rage(), "stealth": i_stealth(), "spirit_wolf": i_spirit_wolf(),
    "thorns": i_thorns(), "smite": i_smite(), "regen": i_regen(),
}

ICON_NAMES = list(ICONS)
GLYPH_NAMES = list(GLYPHS)


def icon_svg(name, size=128):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 128 128">'
            f'{ICONS[name]}</svg>')


def glyph_svg(name, size=64):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 64 64">'
            f'{GLYPHS[name]}</svg>')
