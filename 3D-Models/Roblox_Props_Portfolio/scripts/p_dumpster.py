"""Wheeled street waste container (original design, 4 casters, domed hinged lid).
Pivot = bottom centre (floor).  Front faces -Y.  Separate parts: body, lid (pivot = rear
hinge axis), hardware (handles, hinges, caster forks), 4 wheels (pivot = axle) with hub
caps parented, label.  Wear is light: subtle presentation-only AO / fading in the material."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
import lib
from lib import V, lerp, TAU

NAME = "Dumpster"
LOC = V(1.8, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

Z0, Z1 = 0.185, 1.105          # tub bottom / under-rim
B0 = (0.555, 0.425)            # half sizes at the bottom
B1 = (0.615, 0.485)            # half sizes under the rim
RC = 0.11                      # vertical corner radius


def half(z):
    t = (z - Z0) / (Z1 - Z0)
    return lerp(B0[0], B1[0], t), lerp(B0[1], B1[1], t)


def ring(z, d=0.0, r=RC, seg=4):
    hx, hy = half(min(max(z, Z0), Z1))
    return lib.place(lib.round_rect(hx + d, hy + d, max(0.01, r + d), seg), V(0, 0, z), X, Y)


# ================================================================= body ===
bm = bmesh.new()
rings = [ring(Z0, -0.045, seg=4), ring(Z0 + 0.008, -0.022), ring(Z0 + 0.030, -0.004), ring(Z0 + 0.06), ring(0.62),
         ring(Z1 - 0.06), ring(Z1 - 0.040, 0.010), ring(Z1 - 0.034, 0.030), ring(Z1 - 0.010, 0.036),
         ring(Z1 + 0.012, 0.036), ring(Z1 + 0.024, 0.026), ring(Z1 + 0.024, -0.004)]
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# stacking ribs on front / back walls (follow the taper)
for sy in (-1, 1):
    for x in (-0.30, 0.0, 0.30):
        rr = []
        for z in (0.27, 0.30, 0.95, 1.00):
            hx, hy = half(z)
            k = 1.0 if 0.29 < z < 0.96 else 0.35
            sec = lib.round_rect(0.032 * (0.6 + 0.4 * k), 0.016 * k + 0.002, 0.012, 2)
            rr.append([V(x + p[0], sy * (hy - 0.004 + p[1] + 0.016 * k), z) for p in sec])
        lib.loft(bm, rr, cap0='ngon', cap1='ngon')
# side trunnion bosses (lifting pins)
for sx in (-1, 1):
    hx, hy = half(0.88)
    lib.lathe(bm, [(0.0, -0.02), (0.075, -0.02), (0.078, 0.0), (0.072, 0.03), (0.060, 0.045), (0.050, 0.055),
                   (0.050, 0.095), (0.058, 0.100), (0.058, 0.118), (0.050, 0.124), (0.0, 0.124)],
              V(sx * (hx - 0.005), 0, 0.88), V(sx, 0, 0), 20, ref=Z)
# reinforced bottom skid / caster mounting plates
for sx in (-1, 1):
    for sy in (-1, 1):
        lib.rounded_box(bm, V(sx * 0.43, sy * 0.30, Z0 - 0.008), 0.085, 0.085, 0.012, 0.012, seg=2)
body = lib.bm_to_obj("Dumpster_Body", bm, coll, M["M_Bin_Green"], root)

# ================================================================== lid ===
bm = bmesh.new()
LZ = Z1 + 0.026
hx, hy = B1[0] + 0.050, B1[1] + 0.050
lid_rings = []
prof = [(0.0, -0.050, -0.006), (0.0, -0.046, 0.0), (0.0, 0.0, 0.0), (0.0, 0.012, -0.006), (0.0, 0.020, -0.030),
        (0.0, 0.050, -0.10), (0.0, 0.085, -0.24), (0.0, 0.104, -0.42), (0.0, 0.110, -0.52)]
for _, dz, d in prof:
    k = 1 + d                       # d < 0 shrinks towards the dome top
    lid_rings.append(lib.place(lib.round_rect(hx * k if d > -0.5 else hx * 0.48, hy * k if d > -0.5 else hy * 0.48,
                                              max(0.03, (RC + 0.05) * (1 + d)), 4), V(0, 0, LZ + dz), X, Y))
inner = lib.place(lib.round_rect(hx - 0.012, hy - 0.012, RC + 0.038, 4), V(0, 0, LZ - 0.050), X, Y)
lid_rings.insert(0, inner)
lib.loft(bm, lid_rings, cap0='ngon', cap1='ngon')
# moulded grip handles on the front skirt
for x in (-0.33, 0.33):
    hp = [V(x - 0.13, -hy + 0.004, LZ - 0.030), V(x - 0.11, -hy - 0.035, LZ - 0.034), V(x + 0.11, -hy - 0.035, LZ - 0.034),
          V(x + 0.13, -hy + 0.004, LZ - 0.030)]
    hp = [hp[0] + V(0, 0.02, 0)] + hp + [hp[-1] + V(0, 0.02, 0)]
    lib.loft(bm, [lib.place(lib.round_rect(0.012, 0.016, 0.010, 2), p, u, v) for p, t, u, v in lib.path_frames(hp, up=Z)],
             cap0='ngon', cap1='ngon')
lid = lib.bm_to_obj("Dumpster_Lid", bm, coll, M["M_Bin_Lid"], root)

# ============================================================= hardware ===
bm = bmesh.new()
HY_ = B1[1] + 0.060
for x in (-0.42, 0.42):                       # rear hinges
    lib.lathe(bm, [(0.0, 0.0), (0.020, 0.0), (0.022, 0.004), (0.022, 0.116), (0.020, 0.120), (0.0, 0.120)],
              V(x - 0.06, HY_, LZ - 0.010), X, 16, ref=Z)
    lib.prism(bm, lib.fillet([(-0.05, -0.06), (0.05, -0.06), (0.05, 0.0), (-0.05, 0.0)], 0.01),
              V(x, B1[1] + 0.006, Z1 - 0.025), X, Z, Y, 0.008, 0.002)
for sx in (-1, 1):                            # side tube handles
    hx_, _ = half(1.0)
    pts = [V(sx * (hx_ - 0.02), -0.26, 1.02), V(sx * (hx_ + 0.035), -0.25, 1.02), V(sx * (hx_ + 0.06), -0.20, 1.02),
           V(sx * (hx_ + 0.06), 0.20, 1.02), V(sx * (hx_ + 0.035), 0.25, 1.02), V(sx * (hx_ - 0.02), 0.26, 1.02)]
    sm = []
    for i in range(len(pts) - 1):
        for k in range(4 if i in (1, 3) else 1):
            sm.append(pts[i].lerp(pts[i + 1], k / (4 if i in (1, 3) else 1)))
    sm.append(pts[-1])
    lib.loft(bm, [lib.place(lib.ellipse(0.017, 0.017, 12), p, u, v) for p, t, u, v in lib.path_frames(sm, up=Z)],
             cap0='ngon', cap1='ngon')
    for y in (-0.26, 0.26):                   # bolted feet of the handle
        lib.rounded_box(bm, V(sx * (hx_ - 0.004), y, 1.02), 0.012, 0.035, 0.035, 0.008, seg=1)
# caster forks (swivel top plate + yoke)
WR, WW = 0.095, 0.050
casters = []
for sx in (-1, 1):
    for sy in (-1, 1):
        c = V(sx * 0.43, sy * 0.30, 0)
        lib.lathe(bm, [(0.0, 0.150), (0.060, 0.150), (0.062, 0.156), (0.062, 0.170), (0.0, 0.170)], c, Z, 20)
        lib.lathe(bm, [(0.0, 0.130), (0.030, 0.130), (0.030, 0.152), (0.0, 0.152)], c, Z, 16)
        ax = c + V(0, sy * 0.040, WR)
        for s in (-1, 1):
            lib.prism(bm, lib.fillet([(-0.040, 0.0), (0.040, 0.0), (0.030, -0.055), (0.018, -0.085 - 0.005),
                                      (-0.018, -0.090), (-0.030, -0.055)], [0.004, 0.004, 0.02, 0.02, 0.02, 0.02], 3),
                      c + V(s * (WW / 2 + 0.010), sy * 0.040, 0.134), V(0, 1, 0), Z, X, 0.004, 0.0012)
        lib.lathe(bm, [(0.0, -WW / 2 - 0.020), (0.012, -WW / 2 - 0.020), (0.012, WW / 2 + 0.020),
                       (0.0, WW / 2 + 0.020)], ax, X, 10, ref=Z)
        casters.append((sx, sy, ax))
hw = lib.bm_to_obj("Dumpster_Hardware", bm, coll, M["M_SteelDark"], root)

# brake pedals on the two front casters
bm = bmesh.new()
for sx, sy, ax in casters:
    if sy < 0:
        lib.rounded_box(bm, ax + V(0, -0.055, 0.055), 0.030, 0.026, 0.008, 0.006, seg=2)
pedal = lib.bm_to_obj("Dumpster_BrakePedals", bm, coll, M["M_Paint_Orange"], root)

# ================================================================ wheels ==
wheels = []
for sx, sy, ax in casters:
    tag = ("F" if sy < 0 else "B") + ("L" if sx < 0 else "R")
    bm = bmesh.new()
    prof = [(0.050, -WW / 2), (0.080, -WW / 2), (0.090, -WW / 2 + 0.004), (WR, -WW / 2 + 0.014), (WR, WW / 2 - 0.014),
            (0.090, WW / 2 - 0.004), (0.080, WW / 2), (0.050, WW / 2), (0.050, WW / 2 - 0.006),
            (0.050, -WW / 2 + 0.006)]
    lib.loft(bm, [[ax + V(h, math.cos(TAU * i / 28) * r, math.sin(TAU * i / 28) * r) for i in range(28)] for r, h in prof],
             wrap=True)
    w = lib.bm_to_obj(f"Dumpster_Wheel_{tag}", bm, coll, M["M_Rubber"], root)
    bm = bmesh.new()
    lib.lathe(bm, [(0.0, -WW / 2 + 0.004), (0.046, -WW / 2 + 0.004), (0.052, -WW / 2 + 0.010), (0.052, WW / 2 - 0.010),
                   (0.046, WW / 2 - 0.004), (0.0, WW / 2 - 0.004)], ax, X, 20, ref=Z)
    for s in (-1, 1):
        lib.lathe(bm, [(0.0, s * (WW / 2 + 0.002)), (0.020, s * (WW / 2 + 0.002)), (0.024, s * (WW / 2 - 0.004)),
                       (0.0, s * (WW / 2 - 0.004))], ax, X, 12, ref=Z)
    hub = lib.bm_to_obj(f"Dumpster_Wheel_{tag}_Hub", bm, coll, M["M_Vend_Inner"], root)
    wheels.append((w, hub, ax))

# ================================================================= label ==
bm = bmesh.new()
hx_, hy_ = half(0.70)
FY = -hy_ - 0.003
# label plate leans with the front wall: build in a tilted frame
tilt = math.atan2(B1[1] - B0[1], Z1 - Z0)
u, v = X, (Z + V(0, -math.tan(tilt), 0)).normalized()
nrm = u.cross(v)
o = V(-0.15, 0, 0.70)
o.y = -half(0.70)[1] - 0.0012
pl = lib.round_rect(0.10, 0.075, 0.016, 3)
lib.prism(bm, pl, o, u, v, nrm, 0.0015, 0.0006)
label = lib.bm_to_obj("Dumpster_Label", bm, coll, M["M_Label"], root)
bm = bmesh.new()
lib.text_bm(bm, "04", 0.085, o + v * 0.005 + nrm * 0.0022, u, v, extrude=0.0012, font_res=3)
lib.prism(bm, lib.shift2(lib.round_rect(0.085, 0.008, 0.006, 2), 0, -0.055), o + nrm * 0.0018, u, v, nrm, 0.0008, 0.0)
num = lib.bm_to_obj("Dumpster_LabelText", bm, coll, M["M_Polymer"], root)

parts = [body, lid, hw, pedal, label, num] + [w for w, h, a in wheels] + [h for w, h, a in wheels]
for o in parts:
    lib.finish(o, sharp=40)
lib.set_origin(lid, V(0, HY_, LZ - 0.010 + 0.0))
for w, hub, ax in wheels:
    lib.set_origin(w, ax)
    lib.set_origin(hub, ax)
    bpy.context.view_layer.update()
    mw = hub.matrix_world.copy(); hub.parent = w; hub.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
