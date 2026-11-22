"""Fantasy boar mount (v2, higher fidelity).  Faces -Y, origin = ground centre.
Body (spine-swept superellipse sections: haunch, belly, shoulder hump, jowls, wedge snout),
snout pad + nostrils, mouth line, eyes with brow ridges, cupped ears with inner ear, tusks,
bristle mane / cheek tufts / tail tuft, 4 separate legs (pivot at shoulder / hip) with cloven
hooves and dew claws (parented), blanket + trim, saddle (seat, pommel horn, cantle, fenders,
stitching, conchos), girth + buckle, breast collar + medallion, bridle, reins, stirrup
leathers, stirrups, bedroll.  Seat point stored on the root as 'seat_point'.
Also builds 'Mannequin_R6' (presentation-only seated dummy, feet on the stirrups)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler
import lib
from lib import V, lerp, TAU

NAME = "BoarMount"
LOC = V(1.6, 5.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# ------------------------------------------------------------ body sections
#        y       cz     hx     ht     hb     n (superellipse exponent)
KEYS = [(0.760, 0.620, 0.040, 0.040, 0.040, 2.2),
        (0.735, 0.620, 0.160, 0.160, 0.150, 2.4),
        (0.670, 0.615, 0.255, 0.235, 0.240, 2.5),
        (0.560, 0.610, 0.300, 0.270, 0.290, 2.6),
        (0.360, 0.615, 0.320, 0.285, 0.325, 2.6),
        (0.100, 0.630, 0.335, 0.310, 0.350, 2.6),
        (-0.140, 0.665, 0.360, 0.360, 0.345, 2.6),
        (-0.340, 0.700, 0.370, 0.400, 0.315, 2.6),
        (-0.500, 0.685, 0.330, 0.360, 0.290, 2.5),
        (-0.620, 0.640, 0.290, 0.300, 0.280, 2.4),
        (-0.720, 0.595, 0.250, 0.250, 0.250, 2.3),
        (-0.810, 0.560, 0.200, 0.190, 0.210, 2.3),
        (-0.900, 0.525, 0.155, 0.140, 0.160, 2.3),
        (-0.985, 0.495, 0.120, 0.105, 0.118, 2.4),
        (-1.050, 0.480, 0.105, 0.092, 0.097, 2.5),
        (-1.085, 0.477, 0.098, 0.087, 0.090, 2.6)]
NR = 36


def cr(p0, p1, p2, p3, t):
    t2, t3 = t * t, t * t * t
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)


def key_at(u):
    """Catmull-Rom through KEYS, u in [0, len-1]."""
    i = min(int(u), len(KEYS) - 2)
    t = u - i
    k = [KEYS[max(0, min(len(KEYS) - 1, j))] for j in (i - 1, i, i + 1, i + 2)]
    return tuple(cr(k[0][c], k[1][c], k[2][c], k[3][c], t) for c in range(6))


# dense table y -> params (for lookups by y)
TABLE = [key_at(j / 12) for j in range(12 * (len(KEYS) - 1) + 1)]


def params(y):
    for a, b in zip(TABLE, TABLE[1:]):
        if b[0] <= y <= a[0]:
            t = (y - a[0]) / (b[0] - a[0]) if b[0] != a[0] else 0
            return tuple(lerp(a[c], b[c], t) for c in range(6))
    return TABLE[0] if y > TABLE[0][0] else TABLE[-1]


def sec_pt(prm, a):
    y, cz, hx, ht, hb, n = prm
    c, s = math.cos(a), math.sin(a)
    x = hx * math.copysign(abs(c) ** (2 / n), c)
    z = (ht if s >= 0 else hb) * math.copysign(abs(s) ** (2 / n), s)
    return V(x, y, cz + z)


def surf(y, deg, off=0.0):
    """Point on the body surface at y, polar angle deg (0 = +X side, 90 = top, 270 = belly)."""
    a = math.radians(deg)
    prm = params(y)
    p = sec_pt(prm, a)
    da = 0.01
    t1 = sec_pt(prm, a + da) - sec_pt(prm, a - da)
    t2 = sec_pt(params(y + 0.01), a) - sec_pt(params(y - 0.01), a)
    nrm = t2.cross(t1).normalized()
    if nrm.dot(p - V(0, y, prm[1])) < 0:
        nrm = -nrm
    return p + nrm * off, nrm


def top_z(y):
    return surf(y, 90)[0].z


# =================================================================== body =
bm = bmesh.new()
rings = []
for j in range(4 * (len(KEYS) - 1) + 1):
    prm = key_at(j / 4)
    rings.append([sec_pt(prm, TAU * i / NR) for i in range(NR)])
lib.loft(bm, rings, cap0=V(0, rings[0][0].y + 0.012, KEYS[0][1]), cap1='ngon')
ob_body = lib.bm_to_obj("BoarMount_Body", bm, coll, M["M_Fur"], root)

# ============================================================ snout pad ===
bm = bmesh.new()
YS = -1.078
pad = []
for y, k, dz in ((YS, 1.00, 0.0), (YS - 0.022, 1.03, 0.0), (YS - 0.034, 0.98, 0.002), (YS - 0.040, 0.88, 0.003),
                 (YS - 0.043, 0.60, 0.004)):
    pad.append(lib.place(lib.ellipse(0.100 * k, 0.088 * k, 28), V(0, y, 0.482 + dz), X, Z))
lib.loft(bm, pad, cap0='ngon', cap1='ngon')
ob_snout = lib.bm_to_obj("BoarMount_Snout", bm, coll, M["M_Snout"], root)

# ===================================================== dark bits (face) ===
bm = bmesh.new()
for s in (1, -1):        # nostrils: recessed dark ovals on the pad
    c = V(s * 0.036, YS - 0.0405, 0.486)
    lib.prism(bm, lib.ellipse(0.018, 0.027, 16), c, X, Z, V(0, -1, 0), 0.003, 0.0)
for s in (1, -1):        # eyes
    p, n = surf(-0.800, 90 - s * 52, -0.004)
    p = p + V(0, 0, 0.0)
    res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.034)
    for v in res['verts']:
        v.co = p + V(v.co.x * 0.75, v.co.y * 1.05, v.co.z * 0.95)
# mouth line from the snout to below the eye
for s in (1, -1):
    pts, nn = [], []
    for k in range(9):
        t = k / 8
        y = lerp(-1.060, -0.835, t)
        p, n = surf(y, (270 + 75 * s) % 360 if s > 0 else 180 + 15 + 10 * t, 0.002)
        if s > 0:
            p, n = surf(y, -15 - 10 * t, 0.002)
        pts.append(p); nn.append(n)
    fr = lib.path_frames(pts, up=Z)
    lib.loft(bm, [lib.place(lib.ellipse(0.0055, 0.0040, 8), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')
ob_dark = lib.bm_to_obj("BoarMount_EyesNostrils", bm, coll, M["M_Face"], root)

bm = bmesh.new()
for s in (1, -1):
    p, n = surf(-0.812, 90 - s * 47, 0.020)
    res = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.0085)
    for v in res['verts']:
        v.co = p + v.co
ob_shine = lib.bm_to_obj("BoarMount_EyeShine", bm, coll, M["M_Eye_White"], root)

# ================================================================ tusks ===
bm = bmesh.new()
for s in (1, -1):
    b0, n0 = surf(-0.975, -14 if s > 0 else 194, -0.020)
    path = [b0, b0 + V(s * 0.030, -0.012, 0.004), b0 + V(s * 0.068, -0.030, 0.040), b0 + V(s * 0.090, -0.030, 0.100),
            b0 + V(s * 0.085, -0.004, 0.152), b0 + V(s * 0.062, 0.030, 0.184)]
    path = lib.chaikin(path, 2)
    fr = lib.path_frames(path, up=X)
    m = len(fr)
    lib.loft(bm, [lib.place(lib.ellipse(0.030 * (1 - 0.88 * (k / (m - 1)) ** 1.2), 0.025 * (1 - 0.88 * (k / (m - 1)) ** 1.2), 14),
                            p, u, v) for k, (p, t, u, v) in enumerate(fr)],
             cap0='ngon', cap1=path[-1] + (path[-1] - path[-2]).normalized() * 0.010)
ob_tusk = lib.bm_to_obj("BoarMount_Tusks", bm, coll, M["M_Tusk"], root)

# ================================================================= ears ===
bm_out, bm_in = bmesh.new(), bmesh.new()
for s in (1, -1):
    base, n = surf(-0.640, 90 - s * 40, -0.020)
    tipd = V(s * 0.55, 0.45, 0.70).normalized()
    path = [base + tipd * (0.19 * t) + V(0, 0, 0.03 * math.sin(math.pi * t)) for t in (0, 0.25, 0.5, 0.75, 1.0)]
    fr = lib.path_frames(path, up=V(-s * 0.3, -1, 0.2).normalized())
    W = (0.060, 0.072, 0.060, 0.036, 0.004)
    rings, rings_in = [], []
    for (p, t, u, v), w in zip(fr, W):
        # cupped section: outer arc + flatter inner face (closed)
        sec = [(w * math.cos(a), 0.022 * math.sin(a) * (1.0 if math.sin(a) > 0 else 0.45) + 0.012 * (math.cos(a) ** 2))
               for a in [TAU * i / 14 for i in range(14)]]
        rings.append([p + u * a + v * b for a, b in sec])
        if w > 0.01:
            rings_in.append([p + u * (a * 0.70) + v * (b * 0.25 - 0.004) for a, b in sec])
    lib.loft(bm_out, rings, cap0='ngon', cap1=path[-1] + tipd * 0.010)
    lib.loft(bm_in, rings_in, cap0='ngon', cap1='ngon')
ob_ears = lib.bm_to_obj("BoarMount_Ears", bm_out, coll, M["M_Fur"], root)
ob_earin = lib.bm_to_obj("BoarMount_EarsInner", bm_in, coll, M["M_Snout"], root)


# ============================================================ bristles ====
def spike(bm, base, d, length, w, bend=V(0, 0.4, 0), n=5, flat=0.45):
    d = d.normalized()
    side = d.cross(V(1, 0, 0)) if abs(d.x) < 0.9 else d.cross(V(0, 1, 0))
    side.normalize()
    up2 = d.cross(side).normalized()
    pts = [base + d * (length * t) + bend * (length * t * t) for t in (0, 0.35, 0.7, 1.0)]
    rings = []
    for k, p in enumerate(pts[:-1]):
        f = 1 - k / 3
        rings.append([p + side * (w * f) * math.cos(TAU * i / n) + up2 * (w * flat * f) * math.sin(TAU * i / n)
                      for i in range(n)])
    lib.loft(bm, rings, cap0='ngon', cap1=pts[-1])


bm = bmesh.new()
# mane: a chunky serrated crest along the spine (head -> withers -> mid back), smaller on the rump
for y0, y1, hmax, step in ((-0.830, -0.200, 0.135, 0.028), (0.300, 0.640, 0.075, 0.030)):
    rings = []
    k = 0
    y = y0
    while y <= y1 + 1e-6:
        t = (y - y0) / (y1 - y0)
        env = math.sin(math.pi * min(1.0, 0.12 + t * 1.05)) ** 0.7
        h = hmax * env * (1.0 if k % 2 else 0.50) + 0.012
        p, n = surf(y, 90, -0.018)
        lean = V(0, 0.55 * h, 0)                      # tips sweep back
        wb = 0.050 * (0.6 + 0.4 * env)
        rings.append([p + V(-wb, 0, 0), p + V(-wb * 0.55, 0, h * 0.55) + lean * 0.5, p + V(0, 0, h) + lean,
                      p + V(wb * 0.55, 0, h * 0.55) + lean * 0.5, p + V(wb, 0, 0), p + V(0, 0, -0.03)])
        y += step / 2
        k += 1
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# cheek tufts (sideburns)
for s in (1, -1):
    for y, a, L in ((-0.760, -8, 0.12), (-0.720, -22, 0.13), (-0.690, 6, 0.10), (-0.650, -12, 0.11), (-0.620, -30, 0.09)):
        p, n = surf(y, a if s > 0 else 180 - a, -0.010)
        spike(bm, p, n * 1.6 + V(0, 0.70, -0.30), L * 1.35, 0.036, bend=V(0, 0.20, -0.10), n=6, flat=0.60)
# tail tuft
TB = V(0, 0.748, 0.780)
tail_path = lib.chaikin([TB, TB + V(0, 0.050, -0.010), TB + V(0.010, 0.085, -0.070), TB + V(0.018, 0.095, -0.150)], 2)
for d in (V(0, 0.2, -1), V(0.4, 0.3, -1), V(-0.4, 0.3, -1), V(0, 0.6, -0.9), V(0.2, -0.1, -1)):
    spike(bm, tail_path[-1], d, 0.080, 0.022, bend=V(0, 0.1, 0), n=6, flat=0.7)
ob_crest = lib.bm_to_obj("BoarMount_Crest", bm, coll, M["M_Fur_Dark"], root)

# brow ridges (angry, tilted down towards the snout)
bm = bmesh.new()
for s in (1, -1):
    pts = [surf(y, 90 - s * a, 0.010)[0] for y, a in ((-0.855, 44), (-0.815, 40), (-0.775, 37), (-0.745, 36))]
    pts = [p + V(0, 0, 0.010 * k) for k, p in enumerate(pts)]
    fr = lib.path_frames(pts, up=Z)
    lib.loft(bm, [lib.place(lib.ellipse(0.030 * w, 0.020 * w, 10), p, u, v)
                  for (p, t, u, v), w in zip(fr, (0.5, 1.0, 1.0, 0.6))], cap0='ngon', cap1='ngon')
# tail
fr = lib.path_frames(tail_path, up=X)
m = len(fr)
lib.loft(bm, [lib.place(lib.ellipse(lerp(0.026, 0.013, k / (m - 1)), lerp(0.026, 0.013, k / (m - 1)), 10), p, u, v)
              for k, (p, t, u, v) in enumerate(fr)], cap0='ngon', cap1='ngon')
ob_tail = lib.bm_to_obj("BoarMount_Tail", bm, coll, M["M_Fur_Dark"], root)


# =================================================================== legs =
def cr_path(pts, n):
    out = []
    P = [pts[0]] + pts + [pts[-1]]
    segs = len(pts) - 1
    for k in range(n + 1):
        u = k / n * segs
        i = min(int(u), segs - 1)
        out.append(cr(P[i], P[i + 1], P[i + 2], P[i + 3], u - i))
    return out


LEGS = {  # tag: (x sign, joints, half sizes (along X, along Y) per joint)
    "FL": (1, [V(0.205, -0.360, 0.760), V(0.212, -0.372, 0.520), V(0.214, -0.352, 0.330), V(0.206, -0.378, 0.185),
               V(0.204, -0.398, 0.098)], [(0.118, 0.150), (0.094, 0.112), (0.064, 0.074), (0.050, 0.056), (0.054, 0.060)]),
    "RL": (1, [V(0.195, 0.430, 0.780), V(0.205, 0.470, 0.520), V(0.200, 0.555, 0.330), V(0.198, 0.515, 0.185),
               V(0.198, 0.492, 0.098)], [(0.128, 0.175), (0.106, 0.132), (0.060, 0.070), (0.050, 0.056), (0.054, 0.060)]),
}
legs = []
for tag in ("FL", "FR", "RL", "RR"):
    sx = 1 if tag.endswith("L") else -1
    src = LEGS[tag[0] + "L"]
    joints = [V(sx * p.x, p.y, p.z) for p in src[1]]
    sizes = src[2]
    path = cr_path(joints, 16)
    bm = bmesh.new()
    rings = []
    fr = lib.path_frames(path, up=V(0, -1, 0))
    for k, (p, t, u, v) in enumerate(fr):
        uu = k / (len(fr) - 1) * (len(joints) - 1)
        i = min(int(uu), len(joints) - 2)
        f = uu - i
        hx = lerp(sizes[i][0], sizes[i + 1][0], f)
        hy = lerp(sizes[i][1], sizes[i + 1][1], f)
        rings.append([p + X * (hx * math.cos(TAU * a / 20)) + V(0, hy * math.sin(TAU * a / 20), 0) for a in range(20)])
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')
    ob_l = lib.bm_to_obj(f"BoarMount_Leg_{tag}", bm, coll, M["M_Fur"], root)
    # cloven hoof + dew claws
    bm = bmesh.new()
    foot = joints[-1]
    for dx in (-0.030, 0.030):
        c = V(foot.x + dx, foot.y - 0.012, 0.050)
        rings = []
        for z, k, fwd in ((0.0, 0.96, 0.010), (0.006, 1.0, 0.012), (0.050, 0.94, 0.004), (0.090, 0.80, -0.006),
                          (0.104, 0.70, -0.010)):
            sec = lib.fillet([(-0.026, -0.060), (0.026, -0.060), (0.028, 0.030), (0.022, 0.052), (-0.022, 0.052),
                              (-0.028, 0.030)], [0.010, 0.010, 0.014, 0.012, 0.012, 0.014], 3)
            # pointed toe towards -Y
            sec = [(a * k, (b * k) - fwd) for a, b in sec]
            rings.append(lib.place([(a, -b) for a, b in sec], V(c.x, c.y, z), X, Y))
        lib.loft(bm, rings, cap0='ngon', cap1='ngon')
    for dx in (-0.026, 0.026):
        spike(bm, V(foot.x + dx, foot.y + 0.048, 0.120), V(0, 0.45, -1), 0.040, 0.016, bend=V(0, 0.1, 0), n=6)
    ob_h = lib.bm_to_obj(f"BoarMount_Leg_{tag}_Hoof", bm, coll, M["M_Hoof"], root)
    legs.append((ob_l, ob_h, V(joints[0].x, joints[0].y, 0.620)))

# ================================================================== tack ==
SY0, SY1 = -0.160, 0.260          # saddle area along the spine
SEAT_Y = 0.050


def sheet(bm, ys, a0f, a1f, off_out, off_in, n=25):
    """Thick sheet lying on the body: rows at ys, polar range a0f(y)..a1f(y) (deg)."""
    rings = []
    for i, y in enumerate(ys):
        a0, a1 = a0f(y), a1f(y)
        outer, inner = [], []
        for k in range(n):
            a = lerp(a0, a1, k / (n - 1))
            p, nrm = surf(y, a)
            oo = off_out(y, k / (n - 1)) if callable(off_out) else off_out
            outer.append(p + nrm * oo)
            inner.append(p + nrm * off_in)
        rings.append(outer + list(reversed(inner)))
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')


def edge_k(y, y0, y1, r=0.07):
    """0 inside, -> 1 at the sheet's front/back edges (for rounded corners)."""
    d = min(y - y0, y1 - y)
    return max(0.0, 1 - d / r) ** 2


# blanket (red) with rounded lower corners
B0, B1 = SY0 - 0.090, SY1 + 0.090
ys = [B0 + (B1 - B0) * t for t in [0, 0.008, 0.03, 0.07, 0.13, 0.25, 0.4, 0.5, 0.6, 0.75, 0.87, 0.93, 0.97, 0.992, 1]]
bm = bmesh.new()
sheet(bm, ys, lambda y: 2 + 32 * edge_k(y, B0, B1), lambda y: 178 - 32 * edge_k(y, B0, B1),
      lambda y, t: 0.004 + 0.012 * (1 - edge_k(y, B0 - 0.01, B1 + 0.01)), 0.0)
ob_blanket = lib.bm_to_obj("BoarMount_Blanket", bm, coll, M["M_Paint_Red"], root)


def surf_tube(bm, pts_n, w, h, closed=False, seg_round=True):
    """Flat band following surface points [(p, n)]: section w (along the surface) x h (along n)."""
    P = [p for p, n in pts_n]
    rings = []
    m = len(P)
    for k, (p, n) in enumerate(pts_n):
        a = P[(k + 1) % m] if closed else P[min(m - 1, k + 1)]
        b = P[(k - 1) % m] if closed else P[max(0, k - 1)]
        t = (a - b).normalized()
        side = t.cross(n).normalized()
        nn = side.cross(t).normalized()
        sec = lib.round_rect(w / 2, h / 2, min(w, h) * 0.45, 1)
        rings.append([p + side * x + nn * y for x, y in sec])
    lib.loft(bm, rings, wrap=closed, cap0=None if closed else 'ngon', cap1=None if closed else 'ngon')


# blanket trim (gold band along the lower edges + ends)
bm = bmesh.new()
for s in (1, -1):
    pts = []
    for y in [B0 + (B1 - B0) * t for t in [i / 30 for i in range(31)]]:
        k = edge_k(y, B0, B1)
        a = (4 + 32 * k) if s > 0 else (176 - 32 * k)
        p, n = surf(y, a)
        pts.append((p + n * 0.012, n))
    surf_tube(bm, pts, 0.030, 0.012)
ob_trim = lib.bm_to_obj("BoarMount_BlanketTrim", bm, coll, M["M_Paint_Amber"], root)

# saddle seat: dished seat, front pommel, high rear cantle
bm = bmesh.new()
ys = [SY0 + (SY1 - SY0) * t for t in [0, 0.01, 0.05, 0.12, 0.25, 0.4, 0.55, 0.7, 0.82, 0.92, 0.975, 0.995, 1]]


def seat_off(y, t):
    u = (y - SY0) / (SY1 - SY0)
    centre = 1 - abs(2 * t - 1)                                   # 1 on the spine, 0 at the saddle sides
    pommel = 0.070 * max(0, 1 - u / 0.20) ** 1.5
    cantle = 0.120 * max(0, (u - 0.70) / 0.30) ** 1.7
    dish = -0.012 * math.sin(math.pi * min(1, max(0, (u - 0.15) / 0.6)))
    edge = 0.030 * (1 - edge_k(y, SY0, SY1, 0.05))
    return 0.018 + edge + (pommel + cantle) * centre ** 1.3 + dish * centre


sheet(bm, ys, lambda y: 40 + 10 * edge_k(y, SY0, SY1, 0.08), lambda y: 140 - 10 * edge_k(y, SY0, SY1, 0.08), seat_off, 0.010,
      n=27)
# fenders (side flaps) hanging over the blanket
for s in (1, -1):
    F0, F1 = -0.060, 0.170
    fys = [F0 + (F1 - F0) * t for t in [0, 0.03, 0.12, 0.3, 0.5, 0.7, 0.88, 0.97, 1]]
    if s > 0:
        sheet(bm, fys, lambda y: 8 + 18 * edge_k(y, F0, F1, 0.06), lambda y: 44, 0.034, 0.024, n=9)
    else:
        sheet(bm, fys, lambda y: 136, lambda y: 172 - 18 * edge_k(y, F0, F1, 0.06), 0.034, 0.024, n=9)
# pommel horn
ph, pn = surf(SY0 + 0.040, 90, 0.080)
lib.lathe(bm, [(0.0, -0.03), (0.020, -0.03), (0.018, 0.040), (0.022, 0.058), (0.034, 0.068), (0.034, 0.078),
               (0.024, 0.084), (0.0, 0.086)], ph, V(0, -0.35, 1).normalized(), 18)
ob_saddle = lib.bm_to_obj("BoarMount_Saddle", bm, coll, M["M_Leather"], root)
SEAT = surf(SEAT_Y, 90)[0] + V(0, 0, seat_off(SEAT_Y, 0.5))

# stitching along the fender edges + brass conchos
bm_st, bm_br = bmesh.new(), bmesh.new()
for s in (1, -1):
    F0, F1 = -0.060, 0.170
    pts = []
    for t in [i / 24 for i in range(25)]:
        y = lerp(F0 + 0.02, F1 - 0.02, t)
        a = 12 + 18 * edge_k(y, F0 + 0.02, F1 - 0.02, 0.05) + 3
        a = a if s > 0 else 180 - a
        p, n = surf(y, a)
        pts.append((p + n * 0.035, n))
    surf_tube(bm_st, pts, 0.004, 0.003)
    for y, a in ((SY0 + 0.015, 46), (SY1 - 0.015, 46), (F0 + 0.03, 38), (F1 - 0.03, 38)):
        p, n = surf(y, a if s > 0 else 180 - a, seat_off(y, 0.0) if a == 46 else 0.034)
        lib.dome_rivet(bm_br, p, n, 0.017, 0.008, n=14)
ob_stitch = lib.bm_to_obj("BoarMount_Stitching", bm_st, coll, M["M_Cloth_Cream"], root)

# girth strap + breast collar + bridle (leather)
bm = bmesh.new()
pts = [surf(SEAT_Y + 0.030, a, 0.016) for a in range(-150, 151, 8)][::-1]
pts = [surf(SEAT_Y + 0.030, a, 0.016) for a in list(range(200, 359, 8)) + list(range(-1, -21, -8))]
girth = [surf(SEAT_Y + 0.030, 210 + k * 6, 0.018) for k in range(21)]          # under the belly
surf_tube(bm, girth, 0.055, 0.008)
for s in (1, -1):                                                                # girth to saddle
    pts = [surf(SEAT_Y + 0.030, (a if s > 0 else 180 - a), 0.024) for a in (-30, -15, 0, 12)]
    surf_tube(bm, pts, 0.050, 0.008)
collar = []
for k in range(17):
    t = k / 16
    a = lerp(165, 375, t)
    y = -0.150 - 0.430 * math.sin(math.pi * t) ** 0.8
    collar.append(surf(y, a % 360, 0.014))
surf_tube(bm, collar, 0.040, 0.008)
# noseband + headstall over the poll
surf_tube(bm, [surf(-0.990, a, 0.012) for a in range(0, 360, 12)], 0.026, 0.007, closed=True)
for s in (1, -1):
    path = [surf(y, (a if s > 0 else 180 - a), 0.012) for y, a in ((-0.990, 10), (-0.900, 20), (-0.800, 18), (-0.700, 30),
                                                                   (-0.640, 60), (-0.620, 90))]
    surf_tube(bm, path, 0.024, 0.007)
ob_tack = lib.bm_to_obj("BoarMount_Harness", bm, coll, M["M_Leather"], root)

# reins (thin leather, free hanging) from the bit rings to the rider's hands / pommel
bm = bmesh.new()
for s in (1, -1):
    ring_c = surf(-0.990, -2 if s > 0 else 182, 0.020)[0]
    pts = lib.chaikin([ring_c, ring_c + V(s * 0.06, 0.10, 0.10), V(s * 0.30, -0.66, 0.86), V(s * 0.22, -0.42, 1.06),
                       V(s * 0.14, -0.26, 1.17), V(s * 0.05, -0.16, 1.09)], 2)
    fr = lib.path_frames(pts, up=Z)
    lib.loft(bm, [lib.place(lib.round_rect(0.009, 0.004, 0.003, 1), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')
# stirrup leathers: saddle side -> stirrup top (stirrups placed under the mannequin's feet)
FOOT = [V(s * 0.414, SEAT.y - 0.020, SEAT.z - 0.602 - 0.032) for s in (1, -1)]
for s, f in zip((1, -1), FOOT):
    top = surf(SEAT_Y, 34 if s > 0 else 146, 0.030)[0]
    pts = lib.chaikin([top, top + V(s * 0.05, 0, -0.10), f + V(0, 0, 0.140), f + V(0, 0, 0.105)], 2)
    fr = lib.path_frames(pts, up=Y)
    lib.loft(bm, [lib.place(lib.round_rect(0.020, 0.0045, 0.003, 1), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')
# bedroll behind the cantle with two straps
ob_reins = lib.bm_to_obj("BoarMount_Reins", bm, coll, M["M_Leather"], root)

bm = bmesh.new()
rb = surf(SY1 + 0.075, 90, 0.070)[0]
lib.lathe(bm, [(0.0, -0.22), (0.056, -0.22), (0.064, -0.205), (0.066, -0.10), (0.064, 0.0), (0.066, 0.10),
               (0.064, 0.205), (0.056, 0.22), (0.0, 0.22)], rb, X, 20, ref=Z)
ob_roll = lib.bm_to_obj("BoarMount_Bedroll", bm, coll, M["M_Cloth_Cream"], root)
bm = bmesh.new()
for x in (-0.12, 0.12):
    lib.loft(bm, [[rb + V(x + a, 0.071 * math.cos(TAU * i / 20), 0.071 * math.sin(TAU * i / 20)) for i in range(20)]
                  for a in (-0.012, 0.012)], cap0=None, cap1=None)
bm.free()
bm = bmesh.new()
for x in (-0.12, 0.12):
    prof = [(0.064, -0.013), (0.072, -0.012), (0.072, 0.012), (0.064, 0.013)]
    rings = [[rb + V(x + h, r * math.cos(TAU * i / 24), r * math.sin(TAU * i / 24)) for i in range(24)] for r, h in prof]
    lib.loft(bm, rings, wrap=True)
ob_rollstrap = lib.bm_to_obj("BoarMount_BedrollStraps", bm, coll, M["M_Leather"], root)

# metal: bit rings, girth buckle, collar medallion, stirrups (steel) / conchos (brass)
bm = bmesh.new()
for s in (1, -1):
    rc, n = surf(-0.990, -2 if s > 0 else 182, 0.020)
    pts = [rc + V(0, 0.030 * math.cos(TAU * i / 20), 0.030 * math.sin(TAU * i / 20)) for i in range(20)]
    fr = lib.path_frames([pts[-1]] + pts + [pts[0]], up=X)[1:-1]
    lib.loft(bm, [lib.place(lib.ellipse(0.0065, 0.0065, 8), p, u, v) for p, t, u, v in fr], wrap=True)
    # buckle on the girth (right side only looks deliberate; do both for symmetry of silhouette)
    bc, bn = surf(SEAT_Y + 0.030, -22 if s > 0 else 202, 0.024)
    side = bn.cross(Y).normalized()
    frame = [bc + Y * (0.032 * math.cos(TAU * i / 16)) * 1.0 + side * (0.024 * math.sin(TAU * i / 16)) for i in range(16)]
    fr = lib.path_frames([frame[-1]] + frame + [frame[0]], up=bn)[1:-1]
    lib.loft(bm, [lib.place(lib.round_rect(0.005, 0.004, 0.002, 1), p, u, v) for p, t, u, v in fr], wrap=True)
for s, f in zip((1, -1), FOOT):      # D-stirrups, arch in the XZ plane around the foot
    c = f + V(0, 0, 0.050)
    arch = [c + V(0.072 * math.cos(math.pi * k / 14), 0, 0.070 * math.sin(math.pi * k / 14)) for k in range(15)]
    arch = [c + V(0.072, 0, -0.040)] + arch + [c + V(-0.072, 0, -0.040)]
    fr = lib.path_frames(arch, up=Y)
    lib.loft(bm, [lib.place(lib.round_rect(0.010, 0.016, 0.006, 1), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')
    lib.rounded_box(bm, c + V(0, 0, -0.046), 0.074, 0.040, 0.008, 0.006, seg=2)          # tread
    lib.rounded_box(bm, c + V(0, 0, 0.078), 0.024, 0.010, 0.012, 0.004, seg=1)           # eye for the leather
ob_steel = lib.bm_to_obj("BoarMount_Stirrups", bm, coll, M["M_Steel"], root)

mp, mn = collar[8]
lib.dome_rivet(bm_br, mp + mn * 0.004, mn, 0.042, 0.016, n=24)
ob_brass = lib.bm_to_obj("BoarMount_Conchos", bm_br, coll, M["M_Brass"], root)

parts = [ob_body, ob_snout, ob_dark, ob_shine, ob_tusk, ob_ears, ob_earin, ob_crest, ob_tail, ob_blanket, ob_trim,
         ob_saddle, ob_stitch, ob_tack, ob_reins, ob_roll, ob_rollstrap, ob_steel, ob_brass]
for o in parts:
    lib.finish(o, sharp=60 if o in (ob_body, ob_snout, ob_shine, ob_tusk, ob_ears, ob_earin, ob_tail, ob_roll) else 45)
for ob_l, ob_h, piv in legs:
    lib.finish(ob_l, sharp=60); lib.finish(ob_h, sharp=45)
    lib.set_origin(ob_l, piv); lib.set_origin(ob_h, piv)
bpy.context.view_layer.update()
for ob_l, ob_h, piv in legs:
    mw = ob_h.matrix_world.copy(); ob_h.parent = ob_l; ob_h.matrix_world = mw
root["seat_point"] = [round(v, 4) for v in SEAT]

# =================================================== mannequin (presentation)
mc = lib.get_coll("Mannequin_R6")
lib.clear_coll(mc)
mroot = lib.make_root("Mannequin_R6", mc, LOC + V(0, 0, 2.5))
mc.instance_offset = LOC + V(0, 0, 2.5)
bm = bmesh.new()


def limb(p0, p1, hw, hd):
    fr = lib.path_frames([p0, p1], up=X)
    lib.loft(bm, [lib.place(lib.round_rect(hw, hd, 0.02, 2), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')


lib.rounded_box(bm, V(0, 0, 0.215), 0.150, 0.078, 0.200, 0.025, seg=2)       # torso (hip at origin)
lib.rounded_box(bm, V(0, 0, 0.590), 0.140, 0.130, 0.145, 0.055, seg=3)      # head
for s in (1, -1):
    limb(V(s * 0.215, 0.0, 0.390), V(s * 0.205, -0.180, 0.200), 0.058, 0.058)   # upper arm forward
    limb(V(s * 0.205, -0.180, 0.200), V(s * 0.150, -0.300, 0.230), 0.054, 0.054) # forearm to the reins
    limb(V(s * 0.075, -0.010, 0.020), V(s * 0.335, -0.170, -0.160), 0.064, 0.064) # thigh (straddling)
    limb(V(s * 0.335, -0.170, -0.160), V(s * 0.412, 0.020, -0.565), 0.060, 0.060)  # shin down to the stirrup
    lib.rounded_box(bm, V(s * 0.414, -0.020, -0.602), 0.062, 0.090, 0.032, 0.020, seg=2)  # foot on the stirrup tread
ob_m = lib.bm_to_obj("Mannequin_R6_Body", bm, mc, M["M_Mannequin"], mroot)
lib.finish(ob_m, sharp=50)

txt, tot = lib.report(coll)
print(txt)
print("seat point (local):", [round(v, 3) for v in SEAT])
for o in coll.objects:
    if o.type == 'MESH':
        st = lib.check_mesh(o)
        if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
            print("CHECK", o.name, st)
