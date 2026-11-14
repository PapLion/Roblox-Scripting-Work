"""Mining pickaxe: curved two-ended head (pick + chisel), forged socket with skirt.
Grip origin = lower grip area."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Pickaxe"
LOC = V(2.0, 0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# --------------------------------------------------------------- handle ---
H0, H1 = -0.140, 0.671
EYE = 0.605
HR = [(H0, (0.0232, 0.0200)), (H0 + 0.014, (0.0240, 0.0207)), (H0 + 0.05, (0.0192, 0.0166)),
      (0.10, (0.0182, 0.0158)), (0.35, (0.0170, 0.0150)), (0.50, (0.0182, 0.0160)),
      (0.58, (0.0192, 0.0166)), (H1, (0.0192, 0.0166))]


def hx(z):           # very slight forward bow (much straighter than the axe)
    s = (z - H0) / (H1 - H0)
    return 0.006 * math.sin(math.pi * min(1.0, s / 0.8))


def frame_at(z):
    d = 0.002
    t = (V(hx(z + d), 0, z + d) - V(hx(z - d), 0, z - d)).normalized()
    u = Y.cross(t).normalized()
    v = t.cross(u)
    rx, ry = interp(HR, z)
    return V(hx(z), 0, z), u, v, rx, ry


N = 12


def ring(z, k=1.0):
    c, u, v, rx, ry = frame_at(z)
    return [c + u * math.cos(TAU * i / N) * rx * k + v * math.sin(TAU * i / N) * ry * k for i in range(N)]


ZP = H0 + 0.048     # amber dipped end
bm = bmesh.new()
lib.loft(bm, [ring(H0, 0.55), ring(H0 + 0.0015, 0.84)] + [ring(z) for z in (H0 + 0.004, H0 + 0.012, H0 + 0.024, H0 + 0.036, ZP)],
         cap0=V(hx(H0), 0, H0 - 0.0006), cap1='ngon')
ob_end = lib.bm_to_obj("Pickaxe_HandleEnd", bm, coll, M["M_Paint_Amber"], root)
bm = bmesh.new()
zs = [ZP, -0.06, 0.0, 0.08, 0.17, 0.26, 0.35, 0.43, 0.50, 0.55, 0.60, 0.64, H1 - 0.003]
lib.loft(bm, [ring(z) for z in zs] + [ring(H1 - 0.0005, 0.9), ring(H1, 0.72)], cap0='ngon', cap1='ngon')
ob_handle = lib.bm_to_obj("Pickaxe_Handle", bm, coll, M["M_Wood"], root)

# grip: two leather bindings so the hand position reads at small size
bm = bmesh.new()
lib.band(bm, frame_at, ZP + 0.004, ZP + 0.018, n=12, out=0.0030)
lib.band(bm, frame_at, 0.125, 0.139, n=12, out=0.0030)
lib.helix_strap(bm, frame_at, ZP + 0.018, 0.125, pitch=0.0215, width=0.021, thick=0.0026, seg_per_turn=12)
ob_wrap = lib.bm_to_obj("Pickaxe_Wrap", bm, coll, M["M_Leather"], root)

# ----------------------------------------------------------------- head ---
SPAN = 0.245


def zc(x):
    return EYE + 0.010 - 0.085 * (x / SPAN) ** 2


# (x, half_y, half_n, chamfer)   chisel at -X, pick at +X
HS = [(-0.245, 0.0205, 0.0016, 0.0008), (-0.236, 0.0212, 0.0040, 0.0016), (-0.215, 0.0198, 0.0068, 0.0028),
      (-0.180, 0.0175, 0.0098, 0.0040), (-0.130, 0.0156, 0.0132, 0.0050), (-0.080, 0.0160, 0.0165, 0.0058),
      (-0.040, 0.0190, 0.0210, 0.0066), (0.000, 0.0200, 0.0225, 0.0068), (0.040, 0.0190, 0.0210, 0.0066),
      (0.080, 0.0150, 0.0160, 0.0062), (0.130, 0.0122, 0.0128, 0.0056), (0.175, 0.0094, 0.0096, 0.0046),
      (0.210, 0.0066, 0.0066, 0.0032), (0.232, 0.0036, 0.0036, 0.0017), (0.243, 0.0013, 0.0013, 0.0006)]
HS = [(x, hy * (1.35 if x > -0.2 else 1.22), hn * 1.45, c * 1.4) for x, hy, hn, c in HS]
pts = [V(x, 0, zc(x)) for x, *_ in HS] + [V(0.249, 0, zc(0.249))]
fr = lib.path_frames(pts, up=Y)
bm = bmesh.new()
rings = []
for (x, hy, hn, c), (p, t, u, v) in zip(HS, fr):
    rings.append(lib.place(lib.chamfer_rect(hn, hy, c), p, u, v))
lib.loft(bm, rings, cap0='ngon', cap1=pts[-1])
ob_head = lib.bm_to_obj("Pickaxe_Head", bm, coll, M["M_Steel"], root)
NR = 8
chisel_ring = list(range(1 * NR, 2 * NR))

# ------------------------------------------------------- socket (reinforcement)
# vertical forged socket with a skirt running down the handle
SK = [(0.484, 0.0214, 0.0188, 0.0060), (0.490, 0.0236, 0.0208, 0.0068), (0.528, 0.0256, 0.0224, 0.0074),
      (0.555, 0.0332, 0.0294, 0.0095), (0.569, 0.0354, 0.0312, 0.0100), (0.651, 0.0354, 0.0312, 0.0100),
      (0.660, 0.0334, 0.0292, 0.0095), (0.664, 0.0292, 0.0254, 0.0080)]
bm = bmesh.new()
lib.loft(bm, [lib.place(lib.chamfer_rect(hx_, hy_, c), V(hx(z), 0, z), X, Y) for z, hx_, hy_, c in SK],
         cap0='ngon', cap1='ngon')
ob_sock = lib.bm_to_obj("Pickaxe_Socket", bm, coll, M["M_SteelDark"], root)
sock_rings = [list(range(3 * 8, 4 * 8)), list(range(5 * 8, 6 * 8))]

bm = bmesh.new()
for s in (1, -1):
    for z in (0.508,):
        c, u, v, rx, ry = frame_at(z)
        yy = interp([(a, b) for a, _, b, _ in SK], z)
        lib.dome_rivet(bm, V(hx(z), s * (yy - 0.0004), z), V(0, s, 0), 0.0048, 0.0028, n=8, ref=Z)
# wedge
wed = lib.chamfer_rect(0.015, 0.0025, 0.0008)
cx = hx(H1)
lib.loft(bm, [lib.place(wed, V(cx, 0, H1 - 0.012), X, Y), lib.place(wed, V(cx, 0, H1 + 0.0024), X, Y),
              lib.place(lib.offset_poly(wed, -0.0006), V(cx, 0, H1 + 0.0034), X, Y)], cap0='ngon', cap1='ngon')
ob_riv = lib.bm_to_obj("Pickaxe_Rivets", bm, coll, M["M_Steel"], root)

lib.finish(ob_end, sharp=60)
lib.finish(ob_handle, sharp=60)
lib.finish(ob_wrap, sharp=50)
lib.finish(ob_head, sharp=36, sharp_rings=(chisel_ring,))
lib.finish(ob_sock, sharp=36, sharp_rings=sock_rings)
lib.finish(ob_riv, sharp=40)

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
