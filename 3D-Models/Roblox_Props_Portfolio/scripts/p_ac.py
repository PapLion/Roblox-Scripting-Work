"""Outdoor air-conditioning unit (original design) on two wall brackets.
Pivot = wall plane (y = 0) at the bottom of the brackets: snap the pivot to a wall.
Front faces -Y.  Separate parts: casing, shroud, fan (pivot = fan axis, spins about Y),
grille, rear coil fins, brackets, pipes + insulation, rubber pads, badge.
Fan is simplified (hub + 3 blades); no hidden internal mechanism."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, TAU

NAME = "ACUnit"
LOC = V(7.2, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

HX, HZ, HY = 0.420, 0.290, 0.150       # casing half sizes
GAP = 0.085                             # wall -> casing back
YB = -GAP                               # casing back plane
YF = YB - 2 * HY                        # casing front plane
ZB = 0.425                              # casing bottom
ZC = ZB + HZ
RC, RE = 0.045, 0.030                   # planform corner radius / front-back edge radius
FX, FR = -0.115, 0.215                  # fan centre x (relative), hole radius
NS = 72


def sdf_rr(x, z, hx, hz, r):
    qx, qz = abs(x) - (hx - r), abs(z) - (hz - r)
    return math.hypot(max(qx, 0), max(qz, 0)) + min(max(qx, qz), 0) - r


def ray_outline(d):
    """Rounded-rect outline inset by d, sampled by rays from the fan centre (NS points)."""
    pts = []
    for i in range(NS):
        a = TAU * i / NS
        ca, sa = math.cos(a), math.sin(a)
        lo, hi = 0.0, 2.0
        for _ in range(40):
            m = (lo + hi) / 2
            if sdf_rr(FX + ca * m, sa * m, HX - d, HZ - d, max(0.005, RC - d)) < 0:
                lo = m
            else:
                hi = m
        pts.append((FX + ca * lo, lo * sa))
    return pts


def circ(r):
    return [(FX + r * math.cos(TAU * i / NS), r * math.sin(TAU * i / NS)) for i in range(NS)]


def ring_at(pts, y):
    return [V(x, y, ZC + z) for x, z in pts]


# =============================================================== casing ===
bm = bmesh.new()
rings = [ring_at(circ(FR), YF + 0.075), ring_at(circ(FR), YF + 0.006), ring_at(circ(FR + 0.007), YF)]
for k in range(4):                      # front rounded edge
    a = math.pi / 2 * k / 3
    rings.append(ring_at(ray_outline(RE * (1 - math.sin(a))), YF + RE * (1 - math.cos(a))))
for k in range(4):                      # back rounded edge
    a = math.pi / 2 * k / 3
    rings.append(ring_at(ray_outline(RE * (1 - math.cos(a))), YB - RE * (1 - math.sin(a))))
rings.append(ring_at(ray_outline(RE + 0.02), YB))
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# side louvres (right side, x = +HX)
for i in range(7):
    z = ZB + 0.085 + i * 0.062
    sec = [(0.0, -0.004), (0.020, 0.010), (0.020, 0.018), (0.0, 0.006)]       # (out, up) slanted slat
    ys = [YF + 0.060, YB - 0.060]
    lib.loft(bm, [[V(HX - 0.004 + a, y, z + b) for a, b in sec] for y in ys], cap0='ngon', cap1='ngon')
# service valve cover (front-right, lower)
lib.rounded_box(bm, V(HX - 0.002, (YF + YB) / 2 + 0.045, ZB + 0.105), 0.022, 0.080, 0.070, 0.012, seg=2)
casing = lib.bm_to_obj("ACUnit_Casing", bm, coll, M["M_AC_Shell"], root)

# ================================================================ shroud ==
bm = bmesh.new()
lib.loft(bm, [ring_at(circ(FR - 0.004), YF + 0.070), ring_at(circ(FR - 0.004), YF + 0.012),
              ring_at(circ(FR + 0.002), YF + 0.010), ring_at(circ(FR + 0.002), YF + 0.074)], cap0='ngon', cap1='ngon')
shroud = lib.bm_to_obj("ACUnit_Shroud", bm, coll, M["M_Rubber"], root)

# =================================================================== fan ==
bm = bmesh.new()
FC = V(FX, YF + 0.045, ZC)
lib.lathe(bm, [(0.0, 0.020), (0.022, 0.020), (0.048, 0.010), (0.052, -0.004), (0.050, -0.020), (0.0, -0.020)],
          FC, V(0, -1, 0), 24, ref=Z)
for b in range(3):
    secs = []
    for j in range(7):
        t = j / 6
        r = lerp(0.045, 0.188, t)
        sweep = b * TAU / 3 + 0.55 * t * t                    # scimitar sweep
        chord = lerp(0.075, 0.120, math.sin(t * math.pi * 0.85))
        pitch = math.radians(lerp(38, 22, t))
        cw = []
        for ca, th in ((-0.5, 0.0), (-0.40, 0.003), (0.0, 0.0045), (0.45, 0.0025), (0.5, 0.0),
                       (0.45, -0.0015), (0.0, -0.0025), (-0.40, -0.0015)):
            # chord direction = tangential, rotated by pitch out of the fan plane
            s_ = ca * chord
            ang = sweep + s_ * math.cos(pitch) / r
            yoff = s_ * math.sin(pitch) + th
            cw.append(FC + V(r * math.cos(ang), yoff, r * math.sin(ang)))
        secs.append(cw)
    lib.loft(bm, secs, cap0='ngon', cap1='ngon')
fan = lib.bm_to_obj("ACUnit_Fan", bm, coll, M["M_SteelDark"], root)

# ================================================================ grille ==
bm = bmesh.new()
GY = YF - 0.004
lib.loft(bm, [[V(FX, GY, ZC) + V((FR + 0.004 + 0.006 * math.cos(TAU * k / 8)) * math.cos(TAU * i / 48), 0.006 * math.sin(TAU * k / 8),
                                 (FR + 0.004 + 0.006 * math.cos(TAU * k / 8)) * math.sin(TAU * i / 48)) for k in range(8)]
              for i in range(48)], wrap=True)
for i in range(-6, 7):
    z = i * 0.031
    hw_ = math.sqrt(max(0.0, (FR + 0.004) ** 2 - z * z))
    sec = lib.round_rect(0.0035, 0.0045, 0.002, 1)
    lib.loft(bm, [[V(FX + x, GY + a, ZC + z + b) for a, b in sec] for x in (-hw_, hw_)], cap0='ngon', cap1='ngon')
for x in (-0.004, 0.004):
    pass
sec = lib.round_rect(0.003, 0.004, 0.002, 1)
lib.loft(bm, [[V(FX + a, GY - 0.006 + b, ZC + z) for a, b in sec] for z in (-FR, FR)], cap0='ngon', cap1='ngon')
lib.lathe(bm, [(0.0, 0.0), (0.040, 0.0), (0.042, -0.004), (0.036, -0.010), (0.0, -0.011)], V(FX, GY - 0.004, ZC),
          V(0, 1, 0), 24, ref=Z)
grille = lib.bm_to_obj("ACUnit_Grille", bm, coll, M["M_Vend_Dark"], root)

# ======================================================= rear coil fins ===
bm = bmesh.new()
lib.frame_xz(bm, lib.shift2(lib.round_rect(0.39, 0.25, 0.02, 2), 0, ZC), lib.shift2(lib.round_rect(0.37, 0.23, 0.012, 2), 0, ZC),
             YB - 0.004, YB + 0.008, ch=0.002)
for i in range(31):
    x = -0.36 + i * 0.024
    lib.rounded_box(bm, V(x, YB + 0.002, ZC), 0.0035, 0.005, 0.228, 0.0015, seg=1)
fins = lib.bm_to_obj("ACUnit_RearFins", bm, coll, M["M_SteelDark"], root)

# ============================================================== brackets ==
bm = bmesh.new()
BX = (-0.30, 0.30)
for bx in BX:
    def bar(p0, p1, w=0.034, t=0.030):
        d = (p1 - p0).normalized()
        n = V(0, -d.z, d.y)
        o = (p0 + p1) / 2
        L = (p1 - p0).length / 2
        out = lib.fillet([(-L, -t / 2), (L, -t / 2), (L, t / 2), (-L, t / 2)], 0.004)
        lib.prism(bm, out, V(bx, o.y, o.z), V(0, d.y, d.z), V(0, n.y, n.z), X, w / 2, 0.003)
    bar(V(0, -0.016, 0.0), V(0, -0.016, ZB - 0.004), t=0.030)                  # wall leg
    bar(V(0, -0.002, ZB - 0.035), V(0, YF - 0.035, ZB - 0.035), t=0.034)       # support arm
    bar(V(0, -0.025, 0.06), V(0, YF + 0.075, ZB - 0.040), w=0.028, t=0.026)    # diagonal brace
    for z in (0.08, ZB - 0.09):                                                 # wall screws
        lib.dome_rivet(bm, V(bx, -0.032, z), V(0, -1, 0), 0.010, 0.006, n=10, ref=Z)
br = lib.bm_to_obj("ACUnit_Brackets", bm, coll, M["M_Steel"], root)

bm = bmesh.new()
for bx in BX:                                       # anti-vibration pads
    for y in (YB - 0.050, YF + 0.050):
        lib.lathe(bm, [(0.0, 0.0), (0.024, 0.0), (0.026, 0.004), (0.026, 0.014), (0.020, 0.018), (0.0, 0.018)],
                  V(bx, y, ZB - 0.018), Z, 16)
pads = lib.bm_to_obj("ACUnit_Pads", bm, coll, M["M_Rubber"], root)

# ================================================================= pipes ==
bm_cu = bmesh.new(); bm_ins = bmesh.new()
for k, (r_cu, r_in, dz) in enumerate(((0.008, 0.019, 0.075), (0.006, 0.015, 0.135))):
    y0 = (YF + YB) / 2 + 0.045 - 0.030 + k * 0.060
    p = [V(HX + 0.020, y0, ZB + dz), V(HX + 0.075, y0, ZB + dz), V(HX + 0.105, y0 + 0.012, ZB + dz),
         V(HX + 0.115, y0 + 0.050, ZB + dz), V(HX + 0.115, -0.002, ZB + dz)]
    pts = lib.chaikin(p, 2)
    fr = lib.path_frames(pts, up=Z)
    lib.loft(bm_cu, [[q + u * r_cu * math.cos(TAU * i / 12) + v * r_cu * math.sin(TAU * i / 12) for i in range(12)]
                     for q, t, u, v in fr[:6]], cap0='ngon', cap1='ngon')
    lib.loft(bm_ins, [[q + u * r_in * math.cos(TAU * i / 16) + v * r_in * math.sin(TAU * i / 16) for i in range(16)]
                      for q, t, u, v in fr[4:]], cap0='ngon', cap1='ngon')
    # flare nut
    lib.lathe(bm_cu, [(0.0, -0.012), (r_cu + 0.006, -0.012), (r_cu + 0.006, 0.010), (0.0, 0.010)],
              V(HX + 0.022, y0, ZB + dz), X, 6)
cu = lib.bm_to_obj("ACUnit_Pipes", bm_cu, coll, M["M_Copper"], root)
ins = lib.bm_to_obj("ACUnit_PipeInsulation", bm_ins, coll, M["M_Rubber"], root)

# ================================================================= badge ==
bm = bmesh.new()
lib.plate_xz(bm, lib.shift2(lib.round_rect(0.075, 0.026, 0.010, 3), 0.285, ZC + 0.190), YF + 0.0005, YF - 0.0025, 0.0008)
badge = lib.bm_to_obj("ACUnit_Badge", bm, coll, M["M_Label"], root)
bm = bmesh.new()
for i in range(3):
    lib.plate_xz(bm, lib.shift2(lib.ellipse(0.010, 0.010, 14), 0.240 + i * 0.030, ZC + 0.190), YF - 0.002, YF - 0.004, 0.0)
lib.plate_xz(bm, lib.shift2(lib.round_rect(0.004, 0.170, 0.003, 1), 0.205 + 0.000, ZC - 0.005), YF + 0.001, YF - 0.0015, 0.0)
mark = lib.bm_to_obj("ACUnit_BadgeMark", bm, coll, M["M_Shelf_Accent"], root)

parts = [casing, shroud, fan, grille, fins, br, pads, cu, ins, badge, mark]
for o in parts:
    lib.finish(o, sharp=40)
lib.set_origin(fan, FC)
txt, tot = lib.report(coll)
print(txt)
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
