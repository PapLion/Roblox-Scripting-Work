"""Urban street lamp (original modern design): flanged base with anchor nuts and an
access hatch, tapered pole with a collar, curved arm and a slim luminaire head.
Pivot = bottom centre (floor).  The arm reaches towards -Y (the street side).
Separate parts: base, pole+arm, head housing, diffuser (emissive, separate), hardware."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, TAU

NAME = "StreetLamp"
LOC = V(6.0, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
N = 28

# ================================================================== base ===
bm = bmesh.new()
lib.lathe(bm, [(0.0, 0.0), (0.225, 0.0), (0.232, 0.008), (0.232, 0.036), (0.222, 0.044), (0.180, 0.050),
               (0.172, 0.062), (0.172, 0.300), (0.180, 0.308), (0.180, 0.330), (0.168, 0.340), (0.140, 0.400),
               (0.112, 0.460), (0.100, 0.500), (0.100, 0.520), (0.0, 0.520)], V(), Z, N)
base = lib.bm_to_obj("StreetLamp_Base", bm, coll, M["M_Iron"], root)

# ============================================================ pole + arm ===
bm = bmesh.new()
lib.lathe(bm, [(0.0, 0.50), (0.078, 0.50), (0.074, 1.6), (0.068, 2.5), (0.0, 2.5)], V(), Z, N)
lib.lathe(bm, [(0.0, 2.48), (0.068, 2.48), (0.064, 3.6), (0.058, 3.95), (0.0, 3.95)], V(), Z, N)
# smooth bend from vertical to the horizontal arm (-Y)
ctrl = [V(0, 0, 3.80), V(0, 0, 4.05), V(0, -0.02, 4.28), V(0, -0.18, 4.42), V(0, -0.45, 4.47), V(0, -0.95, 4.50)]
pts = lib.chaikin(ctrl, 3)
fr = lib.path_frames(pts, up=X)
rings = []
for i, (p, t, u, v) in enumerate(fr):
    r = lerp(0.056, 0.040, i / (len(fr) - 1))
    rings.append([p + u * r * math.cos(TAU * k / 20) + v * r * math.sin(TAU * k / 20) for k in range(20)])
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
pole = lib.bm_to_obj("StreetLamp_Pole", bm, coll, M["M_Iron"], root)

# ============================================================= hardware ===
bm = bmesh.new()
for k in range(4):                                  # anchor nuts
    a = TAU * (k + 0.5) / 4
    c = V(0.195 * math.cos(a), 0.195 * math.sin(a), 0.044)
    lib.lathe(bm, [(0.0, 0.0), (0.020, 0.0), (0.020, 0.016), (0.016, 0.022), (0.0, 0.022)], c, Z, 6, phase=a)
    lib.lathe(bm, [(0.0, 0.022), (0.009, 0.022), (0.009, 0.034), (0.006, 0.038), (0.0, 0.038)], c, Z, 10)
for z0, z1, r in ((0.505, 0.555, 0.090), (2.44, 2.54, 0.080), (3.86, 3.92, 0.068)):   # collars
    lib.lathe(bm, [(0.0, z0), (r - 0.004, z0), (r, z0 + 0.006), (r, z1 - 0.006), (r - 0.004, z1), (0.0, z1)], V(), Z, N)


def curved_panel(bm, r0, r1, a0, a1, z0, z1, n=10, ch=0.003):
    sec = [(r0, z0 + ch), (r1 - ch, z0 + ch), (r1, z0 + 2 * ch), (r1, z1 - 2 * ch), (r1 - ch, z1 - ch), (r0, z1 - ch)]
    rings = []
    for i in range(n + 1):
        a = lerp(a0, a1, i / n)
        inset = ch if i in (0, n) else 0.0
        rings.append([V((r - (inset if r > r0 else 0)) * math.cos(a), (r - (inset if r > r0 else 0)) * math.sin(a), z)
                      for r, z in sec])
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')


# access hatch on the front of the base (faces -Y) + screw
curved_panel(bm, 0.168, 0.177, -math.pi / 2 - 0.42, -math.pi / 2 + 0.42, 0.105, 0.265, n=12)
lib.dome_rivet(bm, V(0, -0.177, 0.240), V(0, -1, 0), 0.008, 0.004, n=10)
hwbm = bm

# ================================================================= head ===
bm = bmesh.new()
HZ = 4.50                     # underside of the arm end
y0, y1 = -0.90, -1.52         # head from the arm clamp to the nose
rings = []
prof = [(0.000, 0.052, 0.030), (0.015, 0.066, 0.040), (0.050, 0.090, 0.052), (0.120, 0.122, 0.060),
        (0.250, 0.145, 0.060), (0.450, 0.150, 0.056), (0.650, 0.144, 0.050), (0.800, 0.128, 0.045),
        (0.900, 0.104, 0.040), (0.955, 0.080, 0.034), (0.985, 0.055, 0.027), (1.000, 0.030, 0.018)]
for s, hx, hz in prof:
    y = lerp(y0, y1, s)
    zc = HZ - 0.010 + hz - 0.035 * s          # underside nearly level, top tapers towards the nose
    rings.append(lib.place(lib.round_rect(hx, hz, min(hx, hz) * 0.85, 5), V(0, y, zc), X, Z))
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# small photocell dome on top
lib.lathe(bm, [(0.0, 0.0), (0.030, 0.0), (0.030, 0.012), (0.024, 0.026), (0.012, 0.034), (0.0, 0.036)],
          V(0, lerp(y0, y1, 0.30), HZ - 0.010 + 0.112 - 0.006), Z, 16)
head = lib.bm_to_obj("StreetLamp_Head", bm, coll, M["M_Iron"], root)

bm = bmesh.new()
zb = HZ - 0.010 + 0.0          # head underside at s~0.35..0.65
dl = lib.round_rect(0.105, 0.17, 0.07, 4)
c = V(0, lerp(y0, y1, 0.52), HZ - 0.010 + 0.004 - 0.035 * 0.52)
vv = V(0, 1, 0.035 / 0.62).normalized()          # follow the underside slope
lib.prism(bm, dl, c, X, vv, X.cross(vv), 0.006, 0.003)
diff = lib.bm_to_obj("StreetLamp_Diffuser", bm, coll, M["M_LampGlow"], root)
# steel bezel around the diffuser + clamp sleeve where the arm enters the head
lib.prism(hwbm, lib.round_rect(0.120, 0.188, 0.08, 4), c + X.cross(vv) * 0.0015, X, vv, X.cross(vv), 0.004, 0.0015)
ad = (V(0, -0.95, 4.50) - V(0, -0.45, 4.47)).normalized()
lib.lathe(hwbm, [(0.0, -0.10), (0.046, -0.10), (0.050, -0.095), (0.050, -0.012), (0.046, -0.006), (0.0, -0.006)],
          V(0, -0.90, 4.497), ad, 20, ref=Z)
hw = lib.bm_to_obj("StreetLamp_Hardware", hwbm, coll, M["M_SteelDark"], root)

parts = [base, pole, hw, head, diff]
for o in parts:
    lib.finish(o, sharp=40)
txt, tot = lib.report(coll)
print(txt)
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
