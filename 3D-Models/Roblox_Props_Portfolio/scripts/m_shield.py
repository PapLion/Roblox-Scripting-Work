"""Round wooden shield: 5 domed planks, steel rim with rivets, teal star emblem,
brass boss; back: two battens, leather-wrapped centre grip on steel brackets and an
arm strap.  Built in a disk frame (front = +Z), then rotated so the front faces -Y.
Origin = centre of the hand grip (behind the boss)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
import lib
from lib import V, lerp, interp, TAU

NAME = "Shield"
LOC = V(2.75, 0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)

R, H, TH = 0.300, 0.034, 0.022        # outer radius, dome height, wood thickness
RW = 0.293                            # plank radius (hidden in the rim channel)


def zf(x, y=0.0):
    r2 = (x * x + y * y) / (R * R)
    return H * (1 - r2)


def zb(x, y=0.0):
    return zf(x, y) - TH


def nrm_front(x, y):
    g = -2 * H / (R * R)
    return V(-g * x, -g * y, 1).normalized()


GRIP = V(0, 0, zb(0, 0) - 0.032)
XF = Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Translation(-GRIP)


def out(name, bm, mat, sharp=40, rings=()):
    bmesh.ops.transform(bm, matrix=XF, verts=bm.verts)
    ob = lib.bm_to_obj(name, bm, coll, mat, root)
    lib.finish(ob, sharp=sharp, sharp_rings=rings)
    return ob


# --------------------------------------------------------------- planks ---
NP = 5
edges = [-RW + 2 * RW * i / NP for i in range(NP + 1)]
G, CH = -0.0004, 0.0030      # G<0: planks overlap slightly inside (no see-through seams)
bm = bmesh.new()
for a, b in zip(edges, edges[1:]):
    m = 0.0 if a < 0 < b else min(abs(a), abs(b))
    ymax = math.sqrt(RW * RW - m * m)
    # stop where the plank gets narrower than 14 mm
    lo, hi = 0.0, ymax
    for _ in range(30):
        mid = (lo + hi) / 2
        c = math.sqrt(max(0, RW * RW - mid * mid))
        w = min(b, c) - max(a, -c)
        lo, hi = (mid, hi) if w > 0.014 else (lo, mid)
    ymax = lo
    nsec = 8
    ys = [ymax * math.sin(math.pi / 2 * (2 * i / nsec - 1)) for i in range(nsec + 1)]
    rings = []
    for y in ys:
        c = math.sqrt(max(0, RW * RW - y * y))
        xa, xb = max(a, -c) + G, min(b, c) - G
        ch = min(CH, (xb - xa) * 0.2)
        xm = (xa + xb) / 2
        top = [(xa, -ch), (xa + ch, 0.0), (xm, 0.0), (xb - ch, 0.0), (xb, -ch)]
        bot = [(xb, ch * 0.6), (xb - ch * 0.6, 0.0), (xa + ch * 0.6, 0.0), (xa, ch * 0.6)]
        ring = [V(x, y, zf(x, y) + dz) for x, dz in top] + [V(x, y, zb(x, y) + dz) for x, dz in bot]
        rings.append(ring)
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')

# battens on the back (horizontal)
for yc in (-0.088, 0.088):
    y0, y1 = yc - 0.027, yc + 0.027
    xe = math.sqrt(0.268 ** 2 - max(abs(y0), abs(y1)) ** 2)
    rings = []
    T, C = 0.016, 0.003
    for i in range(11):
        x = lerp(-xe, xe, i / 10)
        pts = [(y0, 0.0012), (y1, 0.0012), (y1, -T + C), (y1 - C, -T), (y0 + C, -T), (y0, -T + C)]
        rings.append([V(x, y, zb(x, y) + dz) for y, dz in pts])
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')

# grip core (wood) : staple-shaped bar across the centre
GX = 0.112


def goff(x):
    a = abs(x) / GX
    return lerp(0.032, 0.002, lib.smooth((a - 0.45) / 0.55))


def gframe(x):
    d = 0.001
    p = lambda xx: V(xx, 0, zb(xx, 0) - goff(xx))
    c = p(x)
    t = (p(x + d) - p(x - d)).normalized()
    u = V(0, 1, 0)
    v = t.cross(u).normalized()
    return c, u, v, 0.0125, 0.0095


gx = [lerp(-GX, GX, i / 12) for i in range(13)]
lib.loft(bm, [lib.place(lib.ellipse(1, 1, 8), gframe(x)[0], gframe(x)[1] * 0.0125, gframe(x)[2] * 0.0095)
              for x in gx], cap0='ngon', cap1='ngon')
ob_wood = out("Shield_Wood", bm, M["M_Wood"], sharp=40)

# ---------------------------------------------------------------- rim -----
mid = (zf(R) + zb(R)) / 2
prof = [(0.2785, zf(0.2785) - 0.0018), (0.2800, zf(0.280) + 0.0040),
        (0.2965, zf(0.2965) + 0.0040), (0.3040, mid + 0.0075), (0.3060, mid), (0.3040, mid - 0.0075),
        (0.2965, zb(0.2965) - 0.0040), (0.2800, zb(0.280) - 0.0040),
        (0.2785, zb(0.2785) + 0.0018)]
NS = 32
bm = bmesh.new()
rows = [[bm.verts.new(V(r * math.cos(TAU * i / NS), r * math.sin(TAU * i / NS), z)) for i in range(NS)] for r, z in prof]
for k in range(len(rows)):
    a, b = rows[k], rows[(k + 1) % len(rows)]
    for i in range(NS):
        j = (i + 1) % NS
        bm.faces.new((a[i], a[j], b[j], b[i]))
# rim rivets (front lip)
for i in range(8):
    ang = TAU * (i + 0.5) / 8
    rr = 0.2905
    x, y = rr * math.cos(ang), rr * math.sin(ang)
    lib.dome_rivet(bm, V(x, y, zf(x, y) + 0.0038), nrm_front(x, y), 0.0058, 0.0034, n=5)
ob_rim = out("Shield_Rim", bm, M["M_Steel"], sharp=40)

# -------------------------------------------------------------- emblem ----
# four-point star + four diamonds (original geometric emblem)
star = []
for k in range(8):
    ang = math.radians(45 * k)
    r = (0.150, 0.052, 0.212, 0.052)[k % 4]
    star.append((r * math.cos(ang), r * math.sin(ang)))


def subdiv(poly, n):
    res = []
    for i in range(len(poly)):
        p, q = Vector(poly[i]), Vector(poly[(i + 1) % len(poly)])
        for k in range(n):
            r = p.lerp(q, k / n)
            res.append((r.x, r.y))
    return res


def area2(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))


if area2(star) < 0:
    star.reverse()
S3 = subdiv(star, 3)
inset = subdiv(lib.offset_poly(star, -0.0032), 3)


def surf(pts, dz, k=1.0):
    return [V(x * k, y * k, zf(x * k, y * k) + dz) for x, y in pts]


bm = bmesh.new()
lib.loft(bm, [surf(inset, 0.0050, 0.30), surf(inset, 0.0050, 0.65), surf(inset, 0.0050),
              surf(S3, 0.0026), surf(S3, -0.0025)], cap0='ngon', cap1='ngon')
for k in range(4):
    ang = math.radians(45 + 90 * k)
    cx, cy = 0.150 * math.cos(ang), 0.150 * math.sin(ang)
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux
    dm = [(0.024, 0.0), (0.0, 0.0145), (-0.024, 0.0), (0.0, -0.0145)]
    dmo = [(cx + ux * a + vx * b, cy + uy * a + vy * b) for a, b in dm]
    dmi = [(cx + ux * a + vx * b, cy + uy * a + vy * b) for a, b in lib.offset_poly(dm, -0.0028)]
    lib.loft(bm, [surf(dmi, 0.0050), surf(dmo, 0.0026), surf(dmo, -0.0025)], cap0='ngon', cap1='ngon')
ob_emb = out("Shield_Emblem", bm, M["M_Paint_Teal"], sharp=35)

# ---------------------------------------------------------------- boss ----
z0 = zf(0, 0)
bp = [(0.0745, zf(0.0745) - 0.002), (0.0745, zf(0.0745) + 0.0064), (0.0705, zf(0.0705) + 0.0080),
      (0.0560, zf(0.056) + 0.0084), (0.0500, z0 + 0.0150), (0.0390, z0 + 0.0232), (0.0220, z0 + 0.0280),
      (0.0, z0 + 0.0294)]
bm = bmesh.new()
rows = lib.lathe(bm, bp, V(0, 0, 0), V(0, 0, 1), 18, ref=V(1, 0, 0))
bm.faces.new(list(reversed(rows[0])))
for i in range(6):
    ang = TAU * i / 6 + math.pi / 6
    x, y = 0.0635 * math.cos(ang), 0.0635 * math.sin(ang)
    lib.dome_rivet(bm, V(x, y, zf(x, y) + 0.0081), nrm_front(x, y), 0.0042, 0.0026, n=5)
ob_boss = out("Shield_Boss", bm, M["M_Brass"], sharp=38)

# ------------------------------------------------------- back: leather ----
bm = bmesh.new()
# leather sleeve over the grip (rolled edges)
sl = []
for x, k in ((-0.054, 1.0), (-0.052, 1.22), (-0.046, 1.26), (-0.02, 1.30), (0.02, 1.30), (0.046, 1.26), (0.052, 1.22), (0.054, 1.0)):
    c, u, v, rx, ry = gframe(x)
    sl.append(lib.place(lib.ellipse(rx * k, ry * k, 8), c, u, v))
lib.loft(bm, sl, cap0='ngon', cap1='ngon')
# arm strap: flat loop at y = +0.165
SY = 0.168
sx = [lerp(-0.095, 0.095, i / 14) for i in range(15)]
rings = []
for x in sx:
    a = abs(x) / 0.095
    off = lerp(0.026, 0.0015, lib.smooth((a - 0.35) / 0.65))
    zc = zb(x, SY) - off
    w, t = 0.017, 0.0022
    rings.append([V(x, SY - w, zc + t), V(x, SY + w, zc + t), V(x, SY + w, zc - t), V(x, SY - w, zc - t)])
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_lea = out("Shield_Leather", bm, M["M_Leather"], sharp=45)

# --------------------------------------------- back: brackets + strap pins -
bm = bmesh.new()
for sx_ in (-1, 1):
    # grip brackets
    x0 = sx_ * (GX - 0.006)
    pl = lib.chamfer_rect(0.020, 0.024, 0.006)
    o = V(x0, 0, zb(x0, 0))
    lib.loft(bm, [lib.place(pl, o + V(0, 0, 0.0012), V(1, 0, 0), V(0, 1, 0)),
                  lib.place(pl, o + V(0, 0, -0.0040), V(1, 0, 0), V(0, 1, 0)),
                  lib.place(lib.offset_poly(pl, -0.0018), o + V(0, 0, -0.0058), V(1, 0, 0), V(0, 1, 0))],
             cap0='ngon', cap1='ngon')
    # strap anchor plates
    x1 = sx_ * 0.088
    pl2 = lib.chamfer_rect(0.012, 0.022, 0.004)
    o2 = V(x1, SY, zb(x1, SY))
    lib.loft(bm, [lib.place(pl2, o2 + V(0, 0, 0.0010), V(1, 0, 0), V(0, 1, 0)),
                  lib.place(pl2, o2 + V(0, 0, -0.0060), V(1, 0, 0), V(0, 1, 0)),
                  lib.place(lib.offset_poly(pl2, -0.0016), o2 + V(0, 0, -0.0074), V(1, 0, 0), V(0, 1, 0))],
             cap0='ngon', cap1='ngon')
ob_br = out("Shield_Brackets", bm, M["M_SteelDark"], sharp=40)

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
