"""Lumberjack axe.  Grip origin = centre of the leather wrap."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Axe"
LOC = V(0.0, 0, 0)

M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)

# ------------------------------------------------------------- handle ---
Z0, Z1 = -0.145, 0.674          # knob bottom -> top end (protrudes over head)
L = Z1 - Z0
# (s, rx, ry) : oval, long axis along X (blade direction)
RAD = [(0.00, (0.0240, 0.0190)), (0.035, (0.0250, 0.0198)), (0.075, (0.0196, 0.0158)),
       (0.18, (0.0190, 0.0152)), (0.45, (0.0172, 0.0139)), (0.70, (0.0180, 0.0143)),
       (0.84, (0.0198, 0.0152)), (1.00, (0.0200, 0.0152))]


def hx(s):  # gentle S-curve, knob hooked back toward the poll
    return 0.011 * math.sin(math.pi * min(1, s / 0.86)) - 0.012 * (1 - s) ** 4


def frame_at(z):
    s = (z - Z0) / L
    c = V(hx(s), 0, z)
    d = 0.002
    t = (V(hx(s + d / L), 0, z + d) - V(hx(s - d / L), 0, z - d)).normalized()
    u = V(0, 1, 0).cross(t).normalized()
    v = t.cross(u)
    rx, ry = interp(RAD, s)
    return c, u, v, rx, ry


N = 12


def ring_at(z, scale=1.0, dz=0.0):
    c, u, v, rx, ry = frame_at(z)
    return [c + V(0, 0, dz) + u * math.cos(TAU * i / N) * rx * scale + v * math.sin(TAU * i / N) * ry * scale
            for i in range(N)]


Z_PAINT = -0.112                 # red "dipped" end below this height
zs_low = [Z0 + 0.004, Z0 + 0.012, Z0 + 0.026, -0.128, Z_PAINT]
zs_up = [Z_PAINT, -0.095, -0.06, 0.0, 0.06, 0.12, 0.19, 0.27, 0.35, 0.42, 0.47, 0.51, 0.56, 0.61, 0.645, Z1 - 0.003]

# painted knob (dome at the bottom)
bm = bmesh.new()
rings = [ring_at(Z0 + 0.0005, 0.55), ring_at(Z0 + 0.0015, 0.82)] + [ring_at(z) for z in zs_low[:]]
c0, *_ = frame_at(Z0)
lib.loft(bm, rings, cap0=c0 + V(0, 0, -0.0005), cap1='ngon')
ob_paint = lib.bm_to_obj("Axe_HandleEnd", bm, coll, M["M_Paint_Red"], root)

bm = bmesh.new()
rings = [ring_at(z) for z in zs_up] + [ring_at(Z1 - 0.0005, 0.9), ring_at(Z1, 0.72)]
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_handle = lib.bm_to_obj("Axe_Handle", bm, coll, M["M_Wood"], root)

# --------------------------------------------------------------- wrap ---
bm = bmesh.new()
lib.helix_strap(bm, frame_at, -0.098, 0.098, pitch=0.026, width=0.0255, thick=0.0028, seg_per_turn=12)
lib.band(bm, frame_at, -0.104, -0.090, n=12, out=0.0034)
lib.band(bm, frame_at, 0.090, 0.104, n=12, out=0.0034)
# lashing under the head
lib.helix_strap(bm, frame_at, 0.444, 0.500, pitch=0.0145, width=0.014, thick=0.0028, seg_per_turn=10, phase=1.0)
ob_wrap = lib.bm_to_obj("Axe_Wrap", bm, coll, M["M_Leather"], root)

# --------------------------------------------------------------- head ---
# sections from poll to bit: (x, z_bottom, z_top, half_thickness, edge_bulge)
SEC = [(-0.0465, 0.533, 0.637, 0.0165, 0.0),
       (-0.0440, 0.528, 0.642, 0.0215, 0.0),
       (-0.0300, 0.526, 0.644, 0.0235, 0.0),
       (-0.0100, 0.525, 0.645, 0.0245, 0.0),
       (0.0100, 0.525, 0.646, 0.0245, 0.0),
       (0.0260, 0.523, 0.647, 0.0225, 0.0),
       (0.0400, 0.510, 0.649, 0.0175, 0.0),
       (0.0560, 0.492, 0.652, 0.0140, 0.001),
       (0.0720, 0.475, 0.656, 0.0122, 0.003),
       (0.0880, 0.461, 0.661, 0.0110, 0.006),
       (0.1020, 0.452, 0.666, 0.0102, 0.009),
       (0.1080, 0.449, 0.668, 0.0098, 0.010),   # start of the honed bevel
       (0.1210, 0.445, 0.672, 0.0060, 0.0135),
       (0.1330, 0.442, 0.675, 0.0022, 0.0170),
       (0.1365, 0.441, 0.676, 0.0015, 0.0180)]
VV = [0.0, 0.035, 0.2, 0.4, 0.6, 0.8, 0.965, 1.0]
HS, HT, ZE = 1.22, 1.12, 0.585      # head scale (outline), thickness scale, eye centre
SEC = [(x * HS, ZE + (zb - ZE) * HS, ZE + (zt - ZE) * HS, t * HT, b * HS) for x, zb, zt, t, b in SEC]


def head_ring(x, zb, zt, t, b):
    pts = []
    for side in (1, -1):
        vs = VV if side == 1 else list(reversed(VV))
        for v in vs:
            edge = v in (0.0, 1.0)
            y = side * t * (0.42 if edge else 1.0)
            xx = x + b * math.sin(math.pi * v)
            # slight extra bulge on the eye around the handle
            pts.append(V(xx, y, lerp(zb, zt, v)))
    return pts


bm = bmesh.new()
rings = [head_ring(*s) for s in SEC]
# poll face: small inset ring for a chamfered striking face
r0 = [V(SEC[0][0] - 0.0025, p.y * 0.72, lerp(ZE, p.z, 0.84)) for p in rings[0]]
lib.loft(bm, [r0] + rings, cap0='ngon', cap1='ngon')
NR = len(r0)
BEV = 11 + 1   # index of the bevel-start section in [r0] + rings
bev_ring = list(range(BEV * NR, BEV * NR + NR))
poll_ring = list(range(NR, 2 * NR))
edge_ring = list(range(len(SEC) * NR, len(SEC) * NR + NR))
ob_head = lib.bm_to_obj("Axe_Head", bm, coll, M["M_Steel"], root)

# wedge driven into the top of the handle
bm = bmesh.new()
c, u, v, rx, ry = frame_at(Z1)
wed = lib.chamfer_rect(rx * 0.78, 0.0022, 0.0008)
lib.loft(bm, [lib.place(wed, V(c.x, 0, Z1 - 0.012), V(1, 0, 0), V(0, 1, 0)),
              lib.place(wed, V(c.x, 0, Z1 + 0.0022), V(1, 0, 0), V(0, 1, 0)),
              lib.place(lib.offset_poly(wed, -0.0006), V(c.x, 0, Z1 + 0.0032), V(1, 0, 0), V(0, 1, 0))],
         cap0='ngon', cap1='ngon')
ob_wedge = lib.bm_to_obj("Axe_Wedge", bm, coll, M["M_SteelDark"], root)

for o in (ob_paint, ob_handle):
    lib.finish(o, sharp=60)
lib.finish(ob_wrap, sharp=50)
lib.finish(ob_head, sharp=33, sharp_rings=(bev_ring, poll_ring, edge_ring))
lib.finish(ob_wedge, sharp=40)

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
