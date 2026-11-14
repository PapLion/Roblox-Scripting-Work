"""Dagger with leaf-shaped blade, up-swept crescent guard, banded grip, faceted brass
pommel, green gem; plus a leather sheath (separate root, same pivot: snapping the
Dagger_Sheath root onto the Dagger root = sheathed)."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Dagger"
LOC = V(3.35, 0, 0)
M = lib.mats()
top = lib.get_coll(NAME)
lib.clear_coll(top)
top.instance_offset = LOC
coll = lib.get_coll("Dagger_Knife", top)
lib.clear_coll(coll)
coll.instance_offset = LOC
scoll = lib.get_coll("Dagger_Sheath", top)
lib.clear_coll(scoll)
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# ---------------------------------------------------------------- grip ---
G0, G1 = -0.046, 0.046
GR = [(G0, (0.0128, 0.0110)), (-0.02, (0.0140, 0.0120)), (0.0, (0.0146, 0.0124)),
      (0.02, (0.0140, 0.0120)), (G1, (0.0124, 0.0106))]


def gframe(z):
    rx, ry = interp(GR, z)
    return V(0, 0, z), X, Y, rx, ry


N = 12
bm = bmesh.new()
lib.loft(bm, [[gframe(z)[0] + X * math.cos(TAU * i / N) * gframe(z)[3] + Y * math.sin(TAU * i / N) * gframe(z)[4]
               for i in range(N)] for z in (G0, -0.03, -0.012, 0.012, 0.03, G1)], cap0='ngon', cap1='ngon')
# leather wrap between the brass rings
lib.helix_strap(bm, gframe, -0.034, -0.004, pitch=0.0105, width=0.010, thick=0.0020, seg_per_turn=12)
lib.helix_strap(bm, gframe, 0.004, 0.034, pitch=0.0105, width=0.010, thick=0.0020, seg_per_turn=12, phase=2.0)
ob_grip = lib.bm_to_obj("Dagger_Grip", bm, coll, M["M_Leather"], root)

bm = bmesh.new()
for z0, z1 in ((G0 - 0.004, -0.034), (-0.0045, 0.0045), (0.034, G1 + 0.004)):
    lib.band(bm, gframe, z0, z1, n=12, out=0.0030, ch=0.0010)
ob_rings = lib.bm_to_obj("Dagger_Rings", bm, coll, M["M_Brass"], root)

# -------------------------------------------------------------- guard ----
GZ, GL = G1 + 0.011, 0.046


def gsec(x):
    a = abs(x) / GL
    zc = GZ + 0.018 * a ** 1.8            # crescent sweeping toward the blade
    hy = lerp(0.0110, 0.0040, a ** 1.2)
    hz = lerp(0.0078, 0.0034, a)
    return zc, hy, hz


xs = sorted(set([GL * (i / 9) ** 0.8 for i in range(10)] + [-GL * (i / 9) ** 0.8 for i in range(10)]))
pts = [V(x, 0, gsec(x)[0]) for x in xs]
bm = bmesh.new()
rings = []
for x, (p, t, u, v) in zip(xs, lib.path_frames(pts, up=Y)):
    zc, hy, hz = gsec(x)
    rings.append(lib.place(lib.round_rect(hz, hy, min(hz, hy) * 0.6, seg=2), p, u, v))
e0 = pts[0] + (pts[0] - pts[1]).normalized() * 0.003
e1 = pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.003
lib.loft(bm, rings, cap0=e0, cap1=e1)
# ricasso collar under the blade
lib.loft(bm, [lib.place(lib.chamfer_rect(0.0150, 0.0072, 0.0025), V(0, 0, z), X, Y) for z in (GZ, GZ + 0.012, GZ + 0.016)]
         + [lib.place(lib.chamfer_rect(0.0136, 0.0060, 0.0020), V(0, 0, GZ + 0.0175), X, Y)], cap0='ngon', cap1='ngon')
ob_guard = lib.bm_to_obj("Dagger_Guard", bm, coll, M["M_Steel"], root)

# -------------------------------------------------------------- blade ----
B0, TIP = GZ + 0.014, GZ + 0.205
BL = TIP - B0
# leaf profile: (fraction, half width, half thickness)
BT = [(0.00, 0.0118, 0.0042), (0.10, 0.0150, 0.0040), (0.28, 0.0186, 0.0038), (0.42, 0.0194, 0.0036),
      (0.56, 0.0180, 0.0033), (0.70, 0.0146, 0.0029), (0.82, 0.0102, 0.0024), (0.91, 0.0060, 0.0018),
      (0.97, 0.0025, 0.0011)]


def bring(f):
    w, h = interp([(a, (b, c)) for a, b, c in BT], f)
    bev = w * 0.42
    return [(w, 0), (w - bev, h * 0.92), (0, h), (-(w - bev), h * 0.92), (-w, 0),
            (-(w - bev), -h * 0.92), (0, -h), (w - bev, -h * 0.92)]


fs = [0.0, 0.05, 0.10, 0.18, 0.28, 0.36, 0.42, 0.49, 0.56, 0.63, 0.70, 0.76, 0.82, 0.87, 0.91, 0.945, 0.97]
bm = bmesh.new()
rings = [lib.place(bring(f), V(0, 0, B0 + BL * f), X, Y) for f in fs]
lib.loft(bm, rings, cap0='ngon', cap1=V(0, 0, TIP))
ob_blade = lib.bm_to_obj("Dagger_Blade", bm, coll, M["M_Steel"], root)
NB = 8
tipv = len(fs) * NB
edge_sets = [set(r * NB + k for r in range(len(fs))) | {tipv} for k in (0, 4)]
ridge_sets = [set(r * NB + k for r in range(len(fs))) | {tipv} for k in (2, 6)]

# -------------------------------------------------------------- pommel ---
PZ = G0 - 0.004 - 0.016
bm = bmesh.new()
# faceted octagonal bipyramid
prof = [(0.0, -0.0175), (0.0060, -0.0150), (0.0128, -0.0040), (0.0128, 0.0040), (0.0080, 0.0115), (0.0072, 0.0175)]
rows = lib.lathe(bm, prof, V(0, 0, PZ), Z, 8, ref=X, phase=math.pi / 8)
bm.faces.new(rows[-1])
ob_pom = lib.bm_to_obj("Dagger_Pommel", bm, coll, M["M_Brass"], root)

# ----------------------------------------------------------------- gem ---
bm = bmesh.new()
for s in (1, -1):
    gp = [(0.0055, -0.0005), (0.0055, 0.0007), (0.0042, 0.0020), (0.0022, 0.0028), (0.0, 0.0030)]
    rows = lib.lathe(bm, gp, V(0, s * 0.0104, GZ + 0.0005), Y * s, 8, ref=Z)
    bm.faces.new(list(reversed(rows[0])))
ob_gem = lib.bm_to_obj("Dagger_Gem", bm, coll, M["M_Gem_Green"], root)

lib.finish(ob_grip, sharp=50)
lib.finish(ob_rings, sharp=40)
lib.finish(ob_guard, sharp=40)
lib.finish(ob_blade, sharp=28, sharp_rings=edge_sets + ridge_sets)
lib.finish(ob_pom, sharp=30)
lib.finish(ob_gem, sharp=30)

# ============================================================== sheath ===
sroot = lib.make_root("Dagger_Sheath", scoll, LOC + V(0.075, 0, 0))
scoll.instance_offset = LOC + V(0.075, 0, 0)
S0, S1 = GZ + 0.010, TIP + 0.010


def sw(z):           # sheath half width follows the blade + leather allowance
    f = (z - B0) / BL
    w, h = interp([(a, (b, c)) for a, b, c in BT], max(0.0, min(0.97, f)))
    return max(w + 0.0050, 0.0075), 0.0080


NS = 12


def sring(z, k=1.0, dt=0.0):
    w, t = sw(z)
    return [V(math.cos(TAU * i / NS) * w * k, math.sin(TAU * i / NS) * (t + dt) * k, z) for i in range(NS)]


bm = bmesh.new()
zs = [S0 + 0.008, B0 + BL * 0.10, B0 + BL * 0.28, B0 + BL * 0.42, B0 + BL * 0.56, B0 + BL * 0.70, B0 + BL * 0.80]
lib.loft(bm, [sring(z) for z in zs], cap0='ngon', cap1='ngon')
# stitched seam ridge along both edges
for sx in (1, -1):
    rings = []
    for z in [S0 + 0.012] + zs[1:]:
        w, t = sw(z)
        rings.append([V(sx * (w - 0.0010), -0.0024, z), V(sx * (w + 0.0018), 0, z), V(sx * (w - 0.0010), 0.0024, z)])
    lib.loft(bm, rings, closed=True, cap0='ngon', cap1='ngon')
ob_sh = lib.bm_to_obj("Dagger_Sheath_Leather", bm, scoll, M["M_Leather"], sroot)

bm = bmesh.new()
# throat locket
lib.loft(bm, [sring(S0 - 0.0005, 0.96, -0.0006), sring(S0, 1.0, 0.0015), sring(S0 + 0.016, 1.0, 0.0015),
              sring(S0 + 0.019, 0.96, 0.0003), sring(S0 + 0.019, 0.90)], cap0='ngon', cap1='ngon')
# chape (tip guard) with a small ball finial
zc0 = B0 + BL * 0.78
zt = S1
chz = [zc0, zc0 + 0.004] + [lerp(zc0 + 0.008, zt - 0.004, i / 4) for i in range(5)]
rings = []
for i, z in enumerate(chz):
    w, t = sw(min(z, B0 + BL * 0.80))
    k = 0.97 if i == 0 else lerp(1.06, 0.30, max(0.0, (z - zc0 - 0.008) / (zt - 0.004 - zc0 - 0.008)) ** 1.6)
    rings.append([V(math.cos(TAU * j / NS) * w * k, math.sin(TAU * j / NS) * (t + 0.0012) * min(1, k * 1.3), z)
                  for j in range(NS)])
lib.loft(bm, rings, cap0='ngon', cap1=V(0, 0, zt + 0.001))
lib.lathe(bm, [(0.0, -0.0040), (0.0034, -0.0030), (0.0042, 0.0), (0.0034, 0.0030), (0.0, 0.0040)],
          V(0, 0, zt + 0.0042), Z, 8, ref=X)
ob_shm = lib.bm_to_obj("Dagger_Sheath_Metal", bm, scoll, M["M_Steel"], sroot)
lib.finish(ob_sh, sharp=50)
lib.finish(ob_shm, sharp=40)

for c in (coll, scoll):
    print(lib.report(c)[0])
for o in list(coll.objects) + list(scoll.objects):
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
