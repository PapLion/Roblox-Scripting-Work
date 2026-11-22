"""Slime boss (v2): a clean, readable jelly droplet -- smooth blue body with a soft tip that
leans back, simple oval eyes with highlights, a small open mouth, and a broken gold crown
sunk into the tip.  Faces -Y.  Origin = floor centre.  Original design."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree
import lib
from lib import V, lerp, TAU

NAME = "SlimeBoss"
LOC = V(1.2, 2.6, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# droplet profile: t (0 bottom pole .. 1 tip) -> (radius, height)
PROF = [(0.00, 0.000, 0.000), (0.04, 0.560, 0.004), (0.10, 0.690, 0.040), (0.20, 0.730, 0.150), (0.35, 0.700, 0.330),
        (0.50, 0.625, 0.510), (0.65, 0.505, 0.690), (0.78, 0.355, 0.850), (0.88, 0.205, 0.975), (0.95, 0.090, 1.055),
        (1.00, 0.000, 1.090)]


def prof(t):
    for a, b in zip(PROF, PROF[1:]):
        if a[0] <= t <= b[0]:
            f = (t - a[0]) / (b[0] - a[0])
            f = f * f * (3 - 2 * f) if a[0] > 0.0 else f
            return lerp(a[1], b[1], f), lerp(a[2], b[2], f)
    return PROF[-1][1:]


# ================================================================== body ===
bm = bmesh.new()
NU, NV = 56, 34
rows = []
for j in range(NV + 1):
    t = j / NV
    r, h = prof(t)
    lean = V(-0.025, 0.11, 0) * (t ** 3)                          # tip leans back and a little to one side
    if j in (0, NV):
        rows.append([bm.verts.new(V(0, 0, h) + lean)])
        continue
    row = []
    for i in range(NU):
        a = TAU * i / NU
        sag = 1 + 0.035 * math.sin(2 * a + 0.6) * (1 - t) + 0.02 * math.cos(a - 1.2) * (1 - t)  # soft, settled bulge
        row.append(bm.verts.new(V(r * sag * math.cos(a), r * sag * math.sin(a) * 0.94, h) + lean))
    rows.append(row)
for a, b in zip(rows, rows[1:]):
    for i in range(NU):
        k = (i + 1) % NU
        if len(a) == 1:
            bm.faces.new((a[0], b[k], b[i]))
        elif len(b) == 1:
            bm.faces.new((a[i], a[k], b[0]))
        else:
            bm.faces.new((a[i], a[k], b[k], b[i]))
# two small droplets beside the body
for c, r in ((V(0.86, -0.38, 0.0), 0.070), (V(-0.74, -0.52, 0.0), 0.050)):
    res = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=r)
    for v in res['verts']:
        v.co = c + V(v.co.x, v.co.y, max(0.0, v.co.z + r * 0.35) * 0.75)
ob_body = lib.bm_to_obj("SlimeBoss_Body", bm, coll, M["M_SlimeBlue"], root)
lib.finish(ob_body, sharp=80, weighted=False)
bpy.context.view_layer.update()

bmb = bmesh.new(); bmb.from_mesh(ob_body.data)
bvh = BVHTree.FromBMesh(bmb)


def surf(x, z):
    hit, nrm, idx, dist = bvh.ray_cast(V(x, -3.0, z), V(0, 1, 0))
    return hit, nrm.normalized()


def decal(bm, outline, cx, cz, lift, depth=0.02, rim=0.0):
    """Surface-projected decal: outline in (x, z) offsets around (cx, cz)."""
    rings = []
    for k in (0.35, 0.7, 1.0):
        rings.append([surf(cx + ox * k, cz + oz * k)[0] + surf(cx + ox * k, cz + oz * k)[1] * lift for ox, oz in outline])
    if rim:
        rings.append([surf(cx + ox, cz + oz)[0] + surf(cx + ox, cz + oz)[1] * (lift + rim) for ox, oz in outline])
    rings.append([surf(cx + ox * 1.04, cz + oz * 1.04)[0] - surf(cx + ox * 1.04, cz + oz * 1.04)[1] * depth for ox, oz in outline])
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')


# ================================================================== face ===
EY = 0.640
bme, bmh, bmm = bmesh.new(), bmesh.new(), bmesh.new()
for s, sq in ((-1, 1.0), (1, 0.94)):
    decal(bme, lib.ellipse(0.056, 0.092 * sq, 32), s * 0.205, EY, 0.004)
    decal(bmh, lib.ellipse(0.019, 0.026, 16), s * 0.205 - 0.016, EY + 0.042 * sq, 0.008)
    decal(bmh, lib.ellipse(0.009, 0.010, 12), s * 0.205 + 0.020, EY - 0.030, 0.008)
ob_eye = lib.bm_to_obj("SlimeBoss_Eyes", bme, coll, M["M_Face"], root)
ob_hi = lib.bm_to_obj("SlimeBoss_EyeShine", bmh, coll, M["M_Eye_White"], root)
# small open mouth: soft rounded "D", flat top
mouth = []
for i in range(24):
    a = math.pi + math.pi * i / 23
    mouth.append((0.085 * math.cos(a), 0.062 * math.sin(a)))
for i in range(1, 6):
    t = i / 6
    mouth.append((lerp(0.085, -0.085, t), 0.010 * math.sin(math.pi * t)))
decal(bmm, mouth, 0.0, 0.470, 0.004, rim=0.004)
ob_mouth = lib.bm_to_obj("SlimeBoss_Mouth", bmm, coll, M["M_SlimeMouth"], root)

# ================================================================= crown ===
hit, nrm, _, _ = bvh.ray_cast(V(-0.015, 0.075, 3.0), V(0, 0, -1))
CR, CH, NS = 0.165, 0.100, 32
tilt = Euler((math.radians(-14), math.radians(15), math.radians(10)), 'XYZ').to_matrix().to_4x4()
CM = Matrix.Translation(hit + V(0, 0, -0.085)) @ tilt
bmc = bmesh.new()
prof_c = [(CR - 0.010, -0.02), (CR + 0.007, -0.02), (CR + 0.012, 0.0), (CR + 0.009, 0.012), (CR + 0.009, CH - 0.016),
          (CR + 0.016, CH - 0.009), (CR + 0.012, CH), (CR - 0.010, CH)]
rws = [[bmc.verts.new(CM @ V(r * math.cos(TAU * i / NS), r * math.sin(TAU * i / NS), h)) for i in range(NS)] for r, h in prof_c]
for k in range(len(rws)):
    a, b2 = rws[k], rws[(k + 1) % len(rws)]
    for i in range(NS):
        j = (i + 1) % NS
        bmc.faces.new((a[i], a[j], b2[j], b2[i]))
for k in range(5):
    ang = TAU * k / 5 + 0.35
    broken = (k == 2)
    ht = 0.070 if broken else 0.125
    o = V(CR * math.cos(ang), CR * math.sin(ang), CH - 0.004)
    u = V(-math.sin(ang), math.cos(ang), 0)
    w = V(math.cos(ang), math.sin(ang), 0.0)
    vv = (V(0, 0, 1) + w * 0.12).normalized()
    if broken:
        sp = [(-0.044, 0.0), (0.044, 0.0), (0.034, ht * 0.70), (0.010, ht), (-0.005, ht * 0.62), (-0.026, ht * 0.86)]
    else:
        sp = [(-0.044, 0.0), (0.044, 0.0), (0.005, ht), (-0.005, ht)]
    lib.prism(bmc, lib.ccw(lib.fillet(sp, 0.005, 3)), CM @ o, (CM.to_3x3() @ u), (CM.to_3x3() @ vv), (CM.to_3x3() @ w), 0.008,
              0.0025)
    if not broken:
        res = bmesh.ops.create_uvsphere(bmc, u_segments=12, v_segments=6, radius=0.014)
        bmesh.ops.transform(bmc, matrix=Matrix.Translation(CM @ (o + vv * (ht + 0.008))), verts=res['verts'])
ob_crown = lib.bm_to_obj("SlimeBoss_Crown", bmc, coll, M["M_Gold"], root)
bmg = bmesh.new()
for k in range(5):
    ang = TAU * k / 5 + 0.35 + TAU / 10
    o = CM @ V((CR + 0.010) * math.cos(ang), (CR + 0.010) * math.sin(ang), CH * 0.48)
    n = (CM.to_3x3() @ V(math.cos(ang), math.sin(ang), 0)).normalized()
    lib.lathe(bmg, [(0.0, -0.004), (0.019, -0.004), (0.021, 0.003), (0.014, 0.010), (0.0, 0.013)], o, n, 12)
ob_gem = lib.bm_to_obj("SlimeBoss_CrownGems", bmg, coll, M["M_Gem_Red"], root)

for o in (ob_eye, ob_hi, ob_mouth, ob_crown, ob_gem):
    lib.finish(o, sharp=60 if o in (ob_eye, ob_hi, ob_mouth) else 40)
bmb.free()

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        st = lib.check_mesh(o)
        if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
            print("CHECK", o.name, st)
