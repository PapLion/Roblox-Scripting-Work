"""Skeleton enemy (Roblox proportions, chunky bones), faces -Y, origin between the feet.
Collection 'Skeleton' = Skeleton_Body (15 R15 parts + children) + Skeleton_Sword + Skeleton_Buckler
(weapons are separate assets with their own grip pivots, posed in the hands).  NO armature."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler
import lib
from lib import V, lerp, TAU

NAME = "Skeleton"
LOC = V(2.6, 2.6, 0)
M = lib.mats()
top = lib.get_coll(NAME)
lib.clear_coll(top)
top.instance_offset = LOC
cb = lib.get_coll("Skeleton_Body", top); lib.clear_coll(cb); cb.instance_offset = LOC
cs = lib.get_coll("Skeleton_Sword", top); lib.clear_coll(cs)
cl = lib.get_coll("Skeleton_Buckler", top); lib.clear_coll(cl)
root = lib.make_root(NAME, cb, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
parts = {}


def bone(bm, p0, p1, re, rm, n=10):
    ax = (p1 - p0); L = ax.length
    if n <= 8:     # small bones (fingers / toes): lighter profile
        prof = [(0.0, -re * 0.9), (re * 0.8, -re * 0.5), (re, 0.0), (rm, re * 1.2), (rm, L - re * 1.2), (re, L),
                (re * 0.8, L + re * 0.5), (0.0, L + re * 0.9)]
        lib.lathe(bm, prof, p0, ax.normalized(), n, ref=V(1, 0, 0) if abs(ax.normalized().x) < 0.9 else V(0, 0, 1))
        return
    n = max(n, 16)
    prof = [(0.0, -re * 0.80), (re * 0.55, -re * 0.70), (re * 0.88, -re * 0.30), (re * 0.92, 0.0), (re * 0.82, re * 0.60),
            (rm * 1.06, re * 1.25), (rm, re * 1.9), (rm * 0.90, L / 2), (rm, L - re * 1.9), (rm * 1.06, L - re * 1.25),
            (re * 0.82, L - re * 0.60), (re * 0.92, L), (re * 0.88, L + re * 0.30), (re * 0.55, L + re * 0.70),
            (0.0, L + re * 0.80)]
    d = ax.normalized()
    ref = V(1, 0, 0) if abs(d.x) < 0.9 else V(0, 0, 1)
    lib.lathe(bm, prof, p0, d, n, ref=ref)
    side = (ref - d * ref.dot(d)).normalized()
    for end, sgn in ((p0, -1), (p1, 1)):          # twin condyles give the joint a real bone read
        for k in (-1, 1):
            ball(bm, end + side * (k * re * 0.48) + d * (sgn * re * 0.30), re * 0.62, n=12)


def ball(bm, c, r, n=12, sz=1.0):
    res = bmesh.ops.create_uvsphere(bm, u_segments=n, v_segments=max(4, n // 2), radius=r)
    for v in res['verts']:
        v.co = c + V(v.co.x, v.co.y, v.co.z * sz)


def part(name, mat, pivot, builder, parent=None, sharp=55, coll=cb, rt=None):
    bm = bmesh.new()
    builder(bm)
    ob = lib.bm_to_obj(f"{NAME}_{name}", bm, coll, M[mat], rt or root)
    lib.finish(ob, sharp=sharp)
    lib.set_origin(ob, pivot)
    parts[name] = (ob, parent)
    return ob


def bar(bm, pts, hw, hh, up=Y):
    fr = lib.path_frames(pts, up=up)
    lib.loft(bm, [lib.place(lib.round_rect(hw, hh, min(hw, hh) * 0.9, 1), p, u, v) for p, t, u, v in fr],
             cap0='ngon', cap1='ngon')


SX, LX = 0.226, 0.076
# ---------------------------------------------------------------- limbs --
for side, s in (("Left", 1), ("Right", -1)):
    xa, xl = s * SX, s * LX
    part(f"{side}UpperArm", "M_Bone", V(xa, 0, 1.030), lambda bm, xa=xa: bone(bm, V(xa, 0, 1.020), V(xa, 0, 0.840), 0.044, 0.032))
    part(f"{side}LowerArm", "M_Bone", V(xa, 0, 0.815), lambda bm, xa=xa: bone(bm, V(xa, 0, 0.800), V(xa, 0, 0.640), 0.040, 0.029))

    def hand(bm, xa=xa, s=s):
        lib.rounded_box(bm, V(xa, -0.004, 0.585), 0.046, 0.050, 0.030, 0.018, seg=1)
        for k, fx in enumerate((-0.026, 0.0, 0.026)):
            bone(bm, V(xa + fx, -0.012, 0.560), V(xa + fx, -0.020, 0.505 + 0.006 * (k == 1)), 0.0145, 0.0115, n=8)
        bone(bm, V(xa - s * 0.040, -0.030, 0.585), V(xa - s * 0.050, -0.055, 0.550), 0.014, 0.011, n=8)   # thumb
    part(f"{side}Hand", "M_Bone", V(xa, 0, 0.615), hand)
    part(f"{side}UpperLeg", "M_Bone", V(xl, 0, 0.570), lambda bm, xl=xl: bone(bm, V(xl, 0, 0.555), V(xl, 0, 0.335), 0.046, 0.035))
    part(f"{side}LowerLeg", "M_Bone", V(xl, 0, 0.315), lambda bm, xl=xl: bone(bm, V(xl, 0, 0.300), V(xl, 0, 0.095), 0.043, 0.032))

    def foot(bm, xl=xl):
        lib.rounded_box(bm, V(xl, -0.010, 0.046), 0.050, 0.062, 0.026, 0.020, seg=1)
        for fx in (-0.028, 0.0, 0.028):
            bone(bm, V(xl + fx, -0.060, 0.032), V(xl + fx, -0.108, 0.026), 0.0165, 0.013, n=8)
    part(f"{side}Foot", "M_Bone", V(xl, 0, 0.075), foot)


# ---------------------------------------------------------------- torso --
def pelvis(bm):
    lib.rounded_box(bm, V(0, 0.010, 0.600), 0.110, 0.066, 0.040, 0.026, taper=(0.82, 1.0), seg=3)
    for sx in (1, -1):                       # iliac wings
        wing = lib.fillet([(0.00, 0.000), (0.085, 0.010), (0.112, 0.070), (0.080, 0.108), (0.020, 0.090)], 0.016, 3)
        u = V(sx * math.cos(math.radians(22)), -math.sin(math.radians(22)), 0)
        w = u.cross(Z)
        lib.prism(bm, lib.ccw([(x * 1.0, y) for x, y in wing]) if sx > 0 else lib.ccw([(x, y) for x, y in wing]),
                  V(sx * 0.030, 0.030, 0.585), u, Z, w, 0.012, 0.005)
    for s in (1, -1):
        ball(bm, V(s * 0.080, 0.0, 0.572), 0.040, n=8)
    for z in (0.662,):
        lib.rounded_box(bm, V(0, 0.070, z), 0.034, 0.030, 0.020, 0.012)
part("LowerTorso", "M_Bone", V(0, 0, 0.570), pelvis)


def ribcage(bm):
    for z, k in ((0.800, 0.84), (0.862, 0.94), (0.926, 1.0), (0.990, 0.97), (1.040, 0.86)):
        for sx in (1, -1):
            pts, ws = [], []
            for i in range(19):
                t = i / 18
                a = math.radians(lerp(78, -72, t))
                ca, sa = math.cos(a), math.sin(a)
                pts.append(V(sx * 0.140 * k * ca, 0.012 + 0.092 * k * sa, z + 0.010 * sa - 0.030 * max(0.0, -sa) ** 1.4))
                ws.append(lerp(1.0, 0.70, t))
            fr = lib.path_frames(pts, up=Z)
            lib.loft(bm, [lib.place(lib.round_rect(0.0125 * w, 0.0185 * w, 0.010 * w, 1), p, u, v)
                          for (p, t_, u, v), w in zip(fr, ws)], cap0='ngon', cap1='ngon')
    lib.rounded_box(bm, V(0, -0.083, 0.905), 0.023, 0.014, 0.112, 0.012)              # sternum
    for i in range(8):                                                                 # spine + spinous processes
        zc = 0.700 + i * 0.054
        lib.rounded_box(bm, V(0, 0.092, zc), 0.030, 0.026, 0.021, 0.012, seg=2)
        lib.prism(bm, lib.ccw(lib.fillet([(0.0, -0.012), (0.040, -0.026), (0.044, -0.014), (0.0, 0.014)], 0.005, 2)),
                  V(0, 0.112, zc), V(0, 1, 0), V(0, 0, 1), V(1, 0, 0), 0.008, 0.003)
    bar(bm, [V(-0.205, 0.004, 1.048), V(-0.100, -0.012, 1.060), V(0.0, -0.020, 1.058), V(0.100, -0.012, 1.060),
             V(0.205, 0.004, 1.048)], 0.017, 0.019)                                    # clavicles
    for s in (1, -1):
        ball(bm, V(s * 0.212, 0.0, 1.040), 0.046, n=8)                                      # shoulder joints
    for z in (1.085, 1.120):                                                           # neck vertebrae
        lib.rounded_box(bm, V(0, 0.020, z), 0.032, 0.030, 0.016, 0.011, seg=1)
part("UpperTorso", "M_Bone", V(0, 0, 0.680), ribcage)
part("UpperTorso_Core", "M_Glow", V(0, 0, 0.680), lambda bm: ball(bm, V(0, 0.020, 0.905), 0.040, n=12), parent="UpperTorso")


# ----------------------------------------------------------------- skull --
def skull(bm):
    lib.rounded_box(bm, V(0, 0.004, 1.300), 0.148, 0.140, 0.122, 0.064, seg=3)        # cranium
    lib.rounded_box(bm, V(0, -0.018, 1.178), 0.116, 0.112, 0.056, 0.040, seg=2)       # maxilla / cheeks
    bar(bm, [V(-0.105, -0.141, 1.300), V(-0.050, -0.146, 1.322), V(-0.010, -0.144, 1.300)], 0.016, 0.012)  # brow L(angry)
    bar(bm, [V(0.010, -0.144, 1.306), V(0.055, -0.146, 1.330), V(0.105, -0.141, 1.318)], 0.016, 0.012)     # brow R
    for sx in (1, -1):                                                                 # cheekbones
        bar(bm, [V(sx * 0.030, -0.128, 1.218), V(sx * 0.080, -0.126, 1.214), V(sx * 0.118, -0.098, 1.226)], 0.016, 0.013)
    for k in range(6):                                                                 # upper teeth
        x = -0.065 + k * 0.026
        lib.rounded_box(bm, V(x, -0.128, 1.136), 0.0105, 0.012, 0.015, 0.005, seg=1)
part("Head", "M_Bone", V(0, 0, 1.100), skull)


def skull_dark(bm):
    FY = -0.1385
    lib.rounded_box(bm, V(-0.054, FY, 1.262), 0.038, 0.006, 0.033, 0.020, seg=2)       # round socket
    lib.rounded_box(bm, V(0.056, FY, 1.270), 0.036, 0.006, 0.024, 0.016, seg=2)        # squinting socket
    nose = [(0.0, 1.222), (-0.018, 1.188), (0.0, 1.196), (0.018, 1.188)]
    lib.prism(bm, lib.ccw(lib.fillet(nose, 0.004)), V(0, -0.132, 0), V(1, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.006, 0.0015)
part("Head_Sockets", "M_Bone_Dark", V(0, 0, 1.100), skull_dark, parent="Head")


def crack(bm):
    pts = [V(0.022, -0.1368, 1.356), V(0.040, -0.1368, 1.340), V(0.033, -0.1368, 1.326), V(0.055, -0.1368, 1.312),
           V(0.050, -0.1368, 1.302)]
    for a_, b_ in zip(pts, pts[1:]):
        d = (b_ - a_); L = d.length; d.normalize()
        n = V(0, -1, 0); side = d.cross(n)
        w0, w1 = 0.0035 * (1.2 - 0.2 * pts.index(a_)), 0.0035 * (1.0 - 0.2 * pts.index(a_))
        lib.prism(bm, lib.ccw([(-w0, 0.0), (w0, 0.0), (w1, L), (-w1, L)]), a_, side, d, n.cross(side) * -1 if False else n,
                  0.0012, 0.0)
part("Head_Crack", "M_Bone_Dark", V(0, 0, 1.100), crack, parent="Head")
part("Head_Eyes", "M_Glow", V(0, 0, 1.100),
     lambda bm: (ball(bm, V(-0.052, -0.142, 1.258), 0.014, n=8, sz=0.8), ball(bm, V(0.058, -0.142, 1.266), 0.011, n=8, sz=0.7)),
     parent="Head")


def jaw(bm):
    lib.rounded_box(bm, V(0, -0.020, 1.088), 0.104, 0.100, 0.030, 0.026, taper=(0.86, 1.0))
    for k in range(5):
        x = -0.052 + k * 0.026
        lib.rounded_box(bm, V(x, -0.112, 1.120), 0.0105, 0.011, 0.012, 0.005, seg=1)
part("Head_Jaw", "M_Bone", V(0, 0.050, 1.110), jaw, parent="Head")

# ------------------------------------------------------------- tatters ---
part("LowerTorso_Belt", "M_Leather", V(0, 0, 0.570),
     lambda bm: lib.rounded_box(bm, V(0, 0.010, 0.650), 0.134, 0.078, 0.016, 0.026, rz=0.006), parent="LowerTorso")


def loincloth(bm):
    o = [(-0.070, 0.650), (0.070, 0.650), (0.064, 0.505), (0.040, 0.540), (0.022, 0.470), (0.000, 0.520),
         (-0.026, 0.480), (-0.046, 0.530), (-0.066, 0.495)]
    lib.prism(bm, lib.ccw(lib.fillet(o, 0.004)), V(0, -0.076, 0), V(1, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.0035, 0.0012)
part("LowerTorso_Cloth", "M_Cloth_Gray", V(0, 0, 0.570), loincloth, parent="LowerTorso")
def pauldron(bm):
    cx, top = SX, 1.080
    for dz, sc in ((0.0, 1.0), (-0.026, 0.975), (-0.050, 0.95)):
        rows = []
        for k in range(9):
            a = math.radians(lerp(-18, 98, k / 8))
            pts = []
            for j in range(9):
                yy = lerp(-0.105, 0.105, j / 8) * sc
                bulge = 0.012 * (1 - (2 * j / 8 - 1) ** 2)
                r = 0.100 * sc + bulge
                pts.append(V(cx + r * math.sin(a), yy, top + dz - 0.04 + r * math.cos(a) * 0.55))
            rows.append(pts)
        th = 0.008
        inner = [[p - (p - V(cx, p.y, top + dz - 0.04)).normalized() * th for p in r] for r in rows]
        vo = [[bm.verts.new(p) for p in r] for r in rows]
        vi = [[bm.verts.new(p) for p in r] for r in inner]
        n1, n2 = len(rows), len(rows[0])
        for i in range(n1 - 1):
            for j in range(n2 - 1):
                bm.faces.new((vo[i][j], vo[i + 1][j], vo[i + 1][j + 1], vo[i][j + 1]))
                bm.faces.new((vi[i][j], vi[i][j + 1], vi[i + 1][j + 1], vi[i + 1][j]))
        for i in range(n1 - 1):
            for j in (0, n2 - 1):
                bm.faces.new((vo[i][j], vi[i][j], vi[i + 1][j], vo[i + 1][j]))
        for j in range(n2 - 1):
            for i in (0, n1 - 1):
                bm.faces.new((vo[i][j], vo[i][j + 1], vi[i][j + 1], vi[i][j]))
    for yy in (-0.07, 0.0, 0.07):                                                   # rivets on the top lame
        a = math.radians(55)
        p = V(cx + 0.104 * math.sin(a), yy, top - 0.04 + 0.104 * math.cos(a) * 0.55)
        lib.dome_rivet(bm, p, V(math.sin(a), 0, math.cos(a) * 0.55).normalized(), 0.008, 0.005, n=10)
part("LeftUpperArm_Pauldron", "M_Rust", V(SX, 0, 1.030), pauldron, parent="LeftUpperArm", sharp=40)

bpy.context.view_layer.update()
for name, (ob, par) in parts.items():
    if par:
        pob = parts[par][0]
        mw = ob.matrix_world.copy(); ob.parent = pob; ob.matrix_world = mw

# =========================================================== rusty sword ==
sroot = lib.make_root("Skeleton_Sword", cs, LOC)
bm = bmesh.new()
# notched blade outline (X = width, Z = length), extruded thin across Y with a bevel
bl = [(-0.026, 0.060), (0.026, 0.060), (0.025, 0.250), (0.017, 0.262), (0.024, 0.278), (0.022, 0.420), (0.015, 0.470),
      (0.0, 0.535), (-0.016, 0.468), (-0.022, 0.360), (-0.014, 0.346), (-0.022, 0.330), (-0.025, 0.180)]
lib.prism(bm, lib.ccw(bl), V(0, 0, 0), V(1, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.0055, 0.0040)
bar(bm, [V(-0.070, 0, 0.050), V(-0.035, 0, 0.054), V(0.035, 0, 0.054), V(0.072, 0, 0.046)], 0.011, 0.013, up=Y)   # crossguard
ball(bm, V(0, 0, -0.072), 0.022, n=10)                                                                           # pommel
ob_sb = lib.bm_to_obj("Skeleton_Sword_Blade", bm, cs, M["M_Rust"], sroot)
bm = bmesh.new()
lib.loft(bm, [lib.place(lib.ellipse(rx, rx * 0.86, 10), V(0, 0, z), X, Y) for z, rx in
              ((-0.058, 0.015), (-0.040, 0.0175), (0.0, 0.0165), (0.030, 0.018), (0.044, 0.0155))], cap0='ngon', cap1='ngon')
lib.prism(bm, lib.ccw([(0.012, 0.010), (0.034, -0.020), (0.030, -0.060), (0.018, -0.030)]), V(0, 0.016, 0),
          V(1, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.0012, 0.0005)                                                     # frayed strip
ob_sg = lib.bm_to_obj("Skeleton_Sword_Grip", bm, cs, M["M_Leather"], sroot)
for o in (ob_sb, ob_sg):
    lib.finish(o, sharp=38)
# pose in the right hand: blade pointing forward / down
sroot.matrix_world = Matrix.Translation(LOC + V(-SX, -0.010, 0.570)) @ Euler((math.radians(118), 0, math.radians(-8)), 'XYZ').to_matrix().to_4x4()
cs.instance_offset = LOC

# ============================================================ buckler ====
broot = lib.make_root("Skeleton_Buckler", cl, LOC)
R, TH = 0.165, 0.022
GAP = (math.radians(35), math.radians(68))            # broken bite in the rim
XF = Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Translation(V(0, 0, 0.030))
def circ_pts(r, a0, a1, n):
    return [(r * math.cos(lerp(a0, a1, i / (n - 1))), r * math.sin(lerp(a0, a1, i / (n - 1)))) for i in range(n)]
wood = circ_pts(R, GAP[1], GAP[0] + TAU, 26) + [(0.118 * math.cos(GAP[0] + 0.12), 0.118 * math.sin(GAP[0] + 0.12)),
                                                 (0.104 * math.cos((GAP[0] + GAP[1]) / 2), 0.104 * math.sin((GAP[0] + GAP[1]) / 2)),
                                                 (0.124 * math.cos(GAP[1] - 0.10), 0.124 * math.sin(GAP[1] - 0.10))]
bm = bmesh.new()
lib.prism(bm, lib.ccw(wood), V(0, 0, 0), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1), TH / 2, 0.003)
lib.rounded_box(bm, V(0, 0, -TH / 2 - 0.010), 0.060, 0.018, 0.010, 0.008)            # grip bar (behind)
bmesh.ops.transform(bm, matrix=XF, verts=bm.verts)
ob_bw = lib.bm_to_obj("Skeleton_Buckler_Wood", bm, cl, M["M_Wood"], broot)
bm = bmesh.new()
rim_pts = [V(R * math.cos(a), R * math.sin(a), 0) for a in [lerp(GAP[1] + 0.04, GAP[0] + TAU - 0.04, i / 29) for i in range(30)]]
fr = lib.path_frames(rim_pts, up=Z)
lib.loft(bm, [lib.place(lib.round_rect(0.010, TH / 2 + 0.005, 0.006, 1), p, u, v) for p, t, u, v in fr], cap0='ngon', cap1='ngon')
lib.lathe(bm, [(0.0, TH / 2 + 0.030), (0.026, TH / 2 + 0.026), (0.042, TH / 2 + 0.012), (0.050, TH / 2 + 0.002),
               (0.050, TH / 2 - 0.002), (0.0, TH / 2 - 0.002)], V(0, 0, 0), Z, 14, ref=X)                         # boss
for k in range(9):                                                                  # rim rivets
    a = lerp(GAP[1] + 0.25, GAP[0] + TAU - 0.25, k / 8)
    lib.dome_rivet(bm, V((R - 0.022) * math.cos(a), (R - 0.022) * math.sin(a), TH / 2), V(0, 0, 1), 0.008, 0.005, n=10)
bmesh.ops.transform(bm, matrix=XF, verts=bm.verts)
ob_br = lib.bm_to_obj("Skeleton_Buckler_Metal", bm, cl, M["M_Rust"], broot)
bm = bmesh.new()
for xs in (-0.075, 0.0, 0.075):                                                     # plank seams (dark inlays)
    if abs(xs) < 1e-6:
        continue
    h = math.sqrt(max(0.0, (R - 0.012) ** 2 - xs * xs))
    ht = h if xs < 0 else 0.045                     # stop short of the broken bite
    lib.prism(bm, [(xs - 0.0025, -h), (xs + 0.0025, -h), (xs + 0.0025, ht), (xs - 0.0025, ht)], V(0, 0, TH / 2 + 0.0002),
              V(1, 0, 0), V(0, 1, 0), V(0, 0, 1), 0.0008, 0.0)
bmesh.ops.transform(bm, matrix=XF, verts=bm.verts)
ob_bs = lib.bm_to_obj("Skeleton_Buckler_Seams", bm, cl, M["M_Leather"], broot)
lib.finish(ob_bs, sharp=40)
for o in (ob_bw, ob_br):
    lib.finish(o, sharp=40)
broot.matrix_world = Matrix.Translation(LOC + V(SX + 0.072, -0.010, 0.735)) @ Euler((0, 0, math.radians(72)), 'XYZ').to_matrix().to_4x4()
cl.instance_offset = LOC

for c in (cb, cs, cl):
    print(lib.report(c)[0])
for o in list(cb.objects) + list(cs.objects) + list(cl.objects):
    if o.type == 'MESH':
        st = lib.check_mesh(o)
        if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
            print("CHECK", o.name, st)
