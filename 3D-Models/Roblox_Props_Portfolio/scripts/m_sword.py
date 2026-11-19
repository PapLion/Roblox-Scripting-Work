"""Adventurer sword.  Grip origin = centre of the leather grip."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Sword"
LOC = V(0.7, 0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# ---------------------------------------------------------------- grip ---
G0, G1 = -0.078, 0.078
GR = [(G0, (0.0162, 0.0138)), (-0.04, (0.0176, 0.0148)), (0.0, (0.0182, 0.0153)),
      (0.04, (0.0176, 0.0148)), (G1, (0.0160, 0.0136))]


def gframe(z):
    rx, ry = interp(GR, z)
    return V(0, 0, z), X, Y, rx, ry


N = 12
bm = bmesh.new()
rings = []
for z in (G0, -0.05, -0.02, 0.02, 0.05, G1):
    c, u, v, rx, ry = gframe(z)
    rings.append([c + u * math.cos(TAU * i / N) * rx + v * math.sin(TAU * i / N) * ry for i in range(N)])
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
lib.helix_strap(bm, gframe, G0 + 0.004, G1 - 0.004, pitch=0.0185, width=0.018, thick=0.0024, seg_per_turn=12)
ob_grip = lib.bm_to_obj("Sword_Grip", bm, coll, M["M_Leather"], root)

# ferrules (steel) at both ends of the grip
bm = bmesh.new()
lib.band(bm, gframe, G0 - 0.006, G0 + 0.006, n=12, out=0.0042, ch=0.0012)
lib.band(bm, gframe, G1 - 0.006, G1 + 0.008, n=12, out=0.0042, ch=0.0012)
ob_ferr = lib.bm_to_obj("Sword_Ferrules", bm, coll, M["M_Steel"], root)

# --------------------------------------------------------------- guard ---
GZ = G1 + 0.017            # guard centre height
GL = 0.112                 # half length


def guard_sec(x):
    a = abs(x) / GL
    zc = GZ + 0.014 * a ** 2.2             # tips sweep toward the blade
    hy = lerp(0.0135, 0.0090, a)           # half depth (Y)
    hz = lerp(0.0105, 0.0068, a)           # half height (Z)
    if a > 0.86:                           # rounded finial
        k = (a - 0.86) / 0.14
        bulb = math.sin(min(1, k * 1.25) * math.pi * 0.5)
        hy = lerp(0.0090, 0.0120, bulb) * math.sqrt(max(0.0, 1 - max(0, k - 0.55) ** 2 / 0.2025))
        hz = lerp(0.0068, 0.0108, bulb) * math.sqrt(max(0.0, 1 - max(0, k - 0.55) ** 2 / 0.2025))
    return zc, max(hy, 0.0012), max(hz, 0.0012)


_h = [i / 6 * 0.80 for i in range(6)] + [0.80 + 0.2 * math.sin(math.pi / 2 * i / 7) for i in range(8)]
xs = sorted(set([-GL * a for a in _h] + [GL * a for a in _h]))
pts = [V(x, 0, guard_sec(x)[0]) for x in xs]
frames = lib.path_frames(pts, up=Y)
bm = bmesh.new()
rings = []
for x, (p, t, u, v) in zip(xs, frames):
    zc, hy, hz = guard_sec(x)
    sec = lib.round_rect(hz, hy, min(hz, hy) * (0.55 if abs(x) < GL * 0.86 else 0.92), seg=2)
    rings.append(lib.place(sec, p, u, v))
lib.loft(bm, rings, cap0=V(-GL - 0.0008, 0, guard_sec(-GL)[0]), cap1=V(GL + 0.0008, 0, guard_sec(GL)[0]))
# diamond quillon block (collection motif)
dia = [(0.034, 0.0), (0.0, 0.028), (-0.034, 0.0), (0.0, -0.028)]
dia = lib.offset_poly(dia, 0) if False else dia
nv0 = len(bm.verts)
lib.prism(bm, [(x, y) for x, y in dia], V(0, 0, GZ), X, Z, Y, 0.0160, 0.0038)
dia_rings = [list(range(nv0 + 4 * k, nv0 + 4 * k + 4)) for k in range(4)]
ob_guard = lib.bm_to_obj("Sword_Guard", bm, coll, M["M_Steel"], root)

# --------------------------------------------------------------- blade ---
B0, TIP = GZ + 0.006, GZ + 0.745
BL = TIP - B0
# (fraction, half width, half thickness, fuller depth)
BT = [(0.00, 0.0250, 0.0058, 0.0), (0.04, 0.0250, 0.0056, 0.0010), (0.10, 0.0246, 0.0054, 0.0018),
      (0.30, 0.0240, 0.0050, 0.0018), (0.50, 0.0232, 0.0045, 0.0016), (0.66, 0.0222, 0.0040, 0.0010),
      (0.76, 0.0206, 0.0036, 0.0004), (0.84, 0.0180, 0.0032, 0.0), (0.90, 0.0145, 0.0028, 0.0),
      (0.945, 0.0098, 0.0023, 0.0), (0.975, 0.0055, 0.0017, 0.0), (0.993, 0.0020, 0.0010, 0.0)]


WS = 1.30   # stylised width


def blade_ring(f):
    w, h, d, _ = (*interp([(a, (b, c, e)) for a, b, c, e in BT], f), 0)
    w *= WS
    h *= 1.12
    d *= 1.2
    bev = min(0.0095, w * 0.40)
    fo = min(0.0090, (w - bev) * 0.8)
    fi = fo * 0.45
    half = [(w, 0), (w - bev, h), (fo, h), (fi, h - d * 0.8), (0, h - d), (-fi, h - d * 0.8), (-fo, h),
            (-(w - bev), h), (-w, 0)]
    low = [(x, -y) for x, y in reversed(half[1:-1])]
    return half + low


fs = [0.0, 0.04, 0.10, 0.20, 0.30, 0.40, 0.50, 0.58, 0.66, 0.72, 0.78, 0.84, 0.90, 0.945, 0.975, 0.993]
bm = bmesh.new()
rings = [lib.place(blade_ring(f), V(0, 0, B0 + BL * f), X, Y) for f in fs]
lib.loft(bm, rings, cap0='ngon', cap1=V(0, 0, TIP))
ob_blade = lib.bm_to_obj("Sword_Blade", bm, coll, M["M_Steel"], root)
NB = len(rings[0])
blade_edges = [[r * NB + 0, r * NB + 8] for r in range(len(fs))]
edge_line = [set(r * NB for r in range(len(fs))) | {len(fs) * NB}, set(r * NB + 8 for r in range(len(fs))) | {len(fs) * NB}]

# -------------------------------------------------------------- pommel ---
PK = 1.1
PZ = G0 - 0.006 - 0.0225 * PK
prof = [(0.0, 0.0078), (0.0085, 0.0078), (0.0100, 0.0108), (0.0185, 0.0112), (0.0222, 0.0090),
        (0.0245, 0.0045), (0.0245, -0.0045), (0.0222, -0.0090), (0.0185, -0.0112), (0.0100, -0.0108),
        (0.0085, -0.0078), (0.0, -0.0078)]
prof = [(r * PK, h * PK) for r, h in prof]
bm = bmesh.new()
lib.lathe(bm, prof, V(0, 0, PZ), Y, 20, ref=Z)
# neck between pommel and ferrule
lib.loft(bm, [lib.place(lib.ellipse(0.0090, 0.0075, 10), V(0, 0, PZ + 0.016), X, Y),
              lib.place(lib.ellipse(0.0110, 0.0092, 10), V(0, 0, G0 - 0.003), X, Y)], cap0='ngon', cap1='ngon')
ob_pom = lib.bm_to_obj("Sword_Pommel", bm, coll, M["M_Steel"], root)

# ---------------------------------------------------------------- gems ---
bm = bmesh.new()
for s in (1, -1):
    gp = [(r * PK, h * PK) for r, h in [(0.0084, -0.0006), (0.0084, 0.0008), (0.0068, 0.0028), (0.0038, 0.0040), (0.0, 0.0044)]]
    rows = lib.lathe(bm, gp, V(0, s * 0.0074 * PK, PZ), Y * s, 10, ref=Z)
    bm.faces.new(list(reversed(rows[0])))
    # rhombus gem on the quillon block
    g = [(0.0105, 0), (0, 0.0095), (-0.0105, 0), (0, -0.0095)]
    base = V(0, s * 0.0158, GZ)
    r1 = lib.place(g, base - Y * s * 0.001, X, Z)
    r2 = lib.place(g, base + Y * s * 0.0012, X, Z)
    r3 = lib.place([(x * 0.55, y * 0.55) for x, y in g], base + Y * s * 0.0032, X, Z)
    lib.loft(bm, [r1, r2, r3], cap0='ngon', cap1='ngon')
ob_gem = lib.bm_to_obj("Sword_Gems", bm, coll, M["M_Gem_Blue"], root)

lib.finish(ob_grip, sharp=50)
lib.finish(ob_ferr, sharp=40)
lib.finish(ob_guard, sharp=62, sharp_rings=dia_rings)
lib.finish(ob_blade, sharp=30, sharp_rings=edge_line)
lib.finish(ob_pom, sharp=40)
lib.finish(ob_gem, sharp=30)

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
