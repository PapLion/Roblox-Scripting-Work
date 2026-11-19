"""Compact assault rifle (original design).  Muzzle +X, up +Z, left +Y.
Origin = pistol-grip centre.  Animatable: Magazine, Trigger, Bolt (+ charging knob), Selector."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Rifle"
LOC = V(0.55, 1.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
GRIP = V(-0.033, 0, -0.040)


def P(x, z):
    return (x - GRIP.x, z - GRIP.z)


def G(x, y, z):
    return V(x - GRIP.x, y, z - GRIP.z)


# ======================================================== upper receiver ==
W, ZB, ZT, C, D = 0.0165, 0.020, 0.066, 0.004, 0.0068
PORT = (0.010, 0.068)


def rec_ring(x, port, k=1.0):
    if port:
        right = [(-W, ZB), (-W, 0.033), (-W + D, 0.033), (-W + D, 0.057), (-W, 0.057)]
    else:
        right = [(-W, ZB), (-W, 0.033), (-W, 0.039), (-W, 0.051), (-W, 0.057)]
    pts = right + [(-W, ZT - C), (-W + C, ZT), (W - C, ZT), (W, ZT - C), (W, ZB)]
    cz = (ZB + ZT) / 2
    return [G(x, y * k, lerp(cz, z, k)) for y, z in pts]


xs = [(-0.100, False, 0.92), (-0.098, False, 1.0), (-0.04, False, 1.0), (PORT[0], False, 1.0), (PORT[0] + 0.0005, True, 1.0),
      (0.040, True, 1.0), (PORT[1] - 0.0005, True, 1.0), (PORT[1], False, 1.0), (0.138, False, 1.0)]
bm = bmesh.new()
lib.loft(bm, [rec_ring(x, p, k) for x, p, k in xs], cap0='ngon', cap1='ngon')
# integrated top rail
lib.prism_xz(bm, [P(-0.092, 0.0645), P(0.132, 0.0645), P(0.132, 0.0685), P(-0.092, 0.0685)], -0.0108, 0.0108, 0.0010)
for i in range(9):
    x0 = -0.070 + i * 0.022
    lib.prism_xz(bm, [P(x0, 0.0675), P(x0 + 0.011, 0.0675), P(x0 + 0.011, 0.0728), P(x0, 0.0728)], -0.0108, 0.0108, 0.0010)
# rear sight (notch)
lib.prism_xz(bm, [P(-0.090, 0.068), P(-0.072, 0.068), P(-0.074, 0.075), P(-0.088, 0.075)], -0.0100, 0.0100, 0.0010)
for s in (1, -1):
    lib.prism_xz(bm, [P(-0.090, 0.074), P(-0.074, 0.074), P(-0.076, 0.0835), P(-0.087, 0.0835)], s * 0.0028, s * 0.0100, 0.0008)
ob_up = lib.bm_to_obj("Rifle_Upper", bm, coll, M["M_Gunmetal"], root)

# ================================================================ bolt ====
bm = bmesh.new()
lib.prism_xz(bm, [P(0.016, 0.0345), P(0.062, 0.0345), P(0.062, 0.0555), P(0.016, 0.0555)], -W + D + 0.002, -W + 0.0030, 0.0010)
lib.loft(bm, [lib.place(lib.ellipse(0.0034, 0.0034, 8), G(0.054, -W + 0.004, 0.045), X, Z),
              lib.place(lib.ellipse(0.0034, 0.0034, 8), G(0.054, -W - 0.008, 0.045), X, Z)], cap0='ngon', cap1='ngon')
lib.loft(bm, [lib.place(lib.round_rect(0.0060, 0.0052, 0.0022, 1), G(0.054, y, 0.045), X, Z)
              for y in (-W - 0.0075, -W - 0.0095, -W - 0.0150)], cap0='ngon', cap1='ngon')
ob_bolt = lib.bm_to_obj("Rifle_Bolt", bm, coll, M["M_Steel"], root)
bm = bmesh.new()
lib.loft(bm, [lib.place(lib.round_rect(0.0062, 0.0054, 0.0024, 1), G(0.054, y, 0.045), X, Z)
              for y in (-W - 0.0148, -W - 0.0160, -W - 0.0185)] +
         [lib.place(lib.round_rect(0.0048, 0.0040, 0.0018, 1), G(0.054, -W - 0.0192, 0.045), X, Z)], cap0='ngon', cap1='ngon')
ob_knob = lib.bm_to_obj("Rifle_BoltKnob", bm, coll, M["M_Paint_Orange"], root)

# ======================================================== lower receiver ==
WL = 0.0157
bm = bmesh.new()
lower = [(-0.100, 0.024), (0.136, 0.024), (0.136, 0.006), (0.090, 0.002), (0.088, -0.040), (0.033, -0.040),
         (0.031, 0.000), (-0.028, 0.002), (-0.062, 0.012), (-0.100, 0.014)]
lib.prism_xz(bm, [P(*p) for p in lower], -WL, WL, 0.0016, r=0.003)
lib.prism_xz(bm, [P(0.030, -0.047), P(0.092, -0.047), P(0.091, -0.036), P(0.031, -0.036)], -0.0172, 0.0172, 0.0016, r=0.002)
gp = [(0.034, -0.004), (0.0315, -0.020), (0.018, -0.0275), (0.000, -0.0265), (-0.016, -0.0145)]
pts = [G(x, 0, z) for x, z in gp]
lib.loft(bm, [lib.place(lib.round_rect(0.0030, 0.0062, 0.0022, 1), p, u, v) for p, t, u, v in lib.path_frames(pts, up=Y)],
         cap0='ngon', cap1='ngon')
ob_low = lib.bm_to_obj("Rifle_Lower", bm, coll, M["M_Polymer"], root)

# ========================================================== furniture =====
bm = bmesh.new()
grip = [(-0.003, 0.008), (-0.010, -0.020), (-0.028, -0.084), (-0.060, -0.089), (-0.066, -0.080), (-0.050, -0.030), (-0.045, 0.010)]
lib.pillow_xz(bm, [P(*p) for p in grip], -0.0145, 0.0145, 0.0080, seg=4, fil=[0.003, 0.010, 0.006, 0.006, 0.006, 0.010, 0.003])
# handguard
HZ = 0.043
hg = []
for x, k in ((0.135, 0.93), (0.139, 1.0), (0.316, 1.0), (0.322, 0.86)):
    hg.append(lib.place(lib.round_rect(0.0205 * k, 0.0235 * k, 0.0085 * k, 4), G(x, 0, HZ), Y, Z))
lib.loft(bm, hg, cap0='ngon', cap1='ngon')
for i in range(3):
    x0 = 0.160 + i * 0.052
    for s in (1, -1):
        lib.prism_xz(bm, [P(x0, 0.034), P(x0 + 0.036, 0.034), P(x0 + 0.036, 0.052), P(x0, 0.052)],
                     s * 0.0195, s * 0.0216, 0.0007, r=0.0065)
# stock body + buffer tube cover
stock = [(-0.290, -0.032), (-0.258, -0.030), (-0.222, -0.010), (-0.198, 0.019), (-0.172, 0.029), (-0.166, 0.058),
         (-0.236, 0.0625), (-0.252, 0.0665), (-0.290, 0.0675)]
lib.pillow_xz(bm, [P(*p) for p in stock], -0.0185, 0.0185, 0.0105, seg=4,
              fil=[0.006, 0.012, 0.020, 0.012, 0.008, 0.006, 0.006, 0.004, 0.006])
# cheek riser on top of the stock + QD sling cup
lib.pillow_xz(bm, [P(-0.286, 0.060), P(-0.236, 0.058), P(-0.226, 0.070), P(-0.286, 0.074)], -0.0150, 0.0150, 0.006, seg=3, fil=0.006)
lib.lathe(bm, [(0.0, 0.0), (0.0075, 0.0), (0.0075, 0.004), (0.0060, 0.006), (0.0, 0.006)], G(-0.255, 0.0175, 0.012), Y, 14)
ob_furn = lib.bm_to_obj("Rifle_Furniture", bm, coll, M["M_Polymer_Tan"], root)

bm = bmesh.new()
lib.prism_xz(bm, [P(-0.303, -0.034), P(-0.288, -0.034), P(-0.288, 0.0685), P(-0.303, 0.0685)], -0.0195, 0.0195, 0.0025, r=0.004)
ob_pad = lib.bm_to_obj("Rifle_ButtPad", bm, coll, M["M_Rubber"], root)

# ================================================ barrel / gas block / tube
bm = bmesh.new()
BZ = 0.044
lib.lathe(bm, [(0.0, 0.0), (0.0135, 0.0), (0.0135, 0.110), (0.0150, 0.112), (0.0150, 0.118), (0.0, 0.118)],
          G(-0.214, 0, 0.046), X, 12, ref=Z)
lib.lathe(bm, [(0.0, 0.0), (0.0086, 0.0), (0.0086, 0.106), (0.0, 0.106)], G(0.300, 0, BZ), X, 12, ref=Z)
mz = [(0.0, 0.0), (0.0118, 0.0), (0.0123, 0.002), (0.0123, 0.010), (0.0104, 0.012), (0.0104, 0.016), (0.0123, 0.018),
      (0.0123, 0.026), (0.0104, 0.028), (0.0104, 0.032), (0.0123, 0.034), (0.0123, 0.041), (0.0110, 0.044),
      (0.0058, 0.044), (0.0056, 0.039), (0.0, 0.039)]
lib.lathe(bm, mz, G(0.402, 0, BZ), X, 12, ref=Z)
# gas block + front sight
lib.loft(bm, [lib.place(lib.round_rect(0.0125, 0.0125, 0.004, 1), G(x, 0, BZ), Y, Z) for x in (0.321, 0.323, 0.340, 0.342)],
         cap0='ngon', cap1='ngon')
lib.prism_xz(bm, [P(0.322, 0.052), P(0.341, 0.052), P(0.339, 0.060), P(0.324, 0.060)], -0.0085, 0.0085, 0.0012)
lib.prism_xz(bm, [P(0.327, 0.058), P(0.337, 0.058), P(0.3345, 0.0745), P(0.3335, 0.0815), P(0.3305, 0.0815), P(0.3295, 0.0745)],
             -0.0026, 0.0026, 0.0007)
for s in (1, -1):   # protective ears
    lib.prism_xz(bm, [P(0.324, 0.058), P(0.340, 0.058), P(0.338, 0.0790), P(0.326, 0.0790)], s * 0.0060, s * 0.0085, 0.0008)
ob_bar = lib.bm_to_obj("Rifle_Barrel", bm, coll, M["M_Gunmetal"], root)

bm = bmesh.new()
dot = lib.lathe(bm, [(0.0, 0.0006), (0.0016, 0.0004), (0.0018, -0.0004)], G(0.3292, 0, 0.0790), V(-1, 0, 0), 8, ref=Z)
bm.faces.new(dot[-1])
ob_dot = lib.bm_to_obj("Rifle_SightDot", bm, coll, M["M_Paint_Orange"], root)

# =========================================================== trigger etc ==
bm = bmesh.new()
trig = [(0.010, 0.003), (0.017, 0.003), (0.019, -0.006), (0.021, -0.0165), (0.0172, -0.0195), (0.0142, -0.012), (0.0122, -0.004)]
lib.prism_xz(bm, [P(*p) for p in trig], -0.0034, 0.0034, 0.0010, r=0.0011)
ob_trig = lib.bm_to_obj("Rifle_Trigger", bm, coll, M["M_Gunmetal"], root)

bm = bmesh.new()
sel = [(-0.006, 0.017), (-0.016, 0.0185), (-0.033, 0.012), (-0.033, 0.0065), (-0.016, 0.0095), (-0.006, 0.0105)]
lib.prism_xz(bm, [P(*p) for p in sel], WL - 0.0004, WL + 0.0026, 0.0007, r=0.0018)
lib.loft(bm, [lib.place(lib.ellipse(0.0048, 0.0048, 10), G(-0.011, y, 0.0138), X, Z) for y in (WL - 0.0004, WL + 0.0030)],
         cap0='ngon', cap1='ngon')
ob_sel = lib.bm_to_obj("Rifle_Selector", bm, coll, M["M_Steel"], root)

# ============================================================ magazine ====
bm = bmesh.new()
ms = [i / 10 for i in range(11)]
mpts = [G(0.0605 + 0.040 * s * s, 0, 0.006 - 0.160 * s) for s in ms]
fr = lib.path_frames(mpts, up=Y)
rings = []
for s, (p, t, u, v) in zip(ms, fr):
    rib = 1.0 + (0.035 if (s > 0.45 and int(round(s * 10)) % 2 == 1) else 0.0)
    rings.append(lib.place(lib.round_rect(0.0225 * rib, 0.0112 * rib, 0.004, 1), p, u, v))
p, t, u, v = fr[-1]
rings.append(lib.place(lib.round_rect(0.0250, 0.0132, 0.004, 1), p + t * 0.001, u, v))
rings.append(lib.place(lib.round_rect(0.0250, 0.0132, 0.004, 1), p + t * 0.009, u, v))
rings.append(lib.place(lib.round_rect(0.0225, 0.0110, 0.004, 1), p + t * 0.0105, u, v))
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_mag = lib.bm_to_obj("Rifle_Magazine", bm, coll, M["M_Polymer"], root)
# small hardware: takedown pins (both sides), mag release (right), bolt catch (left), receiver panel line
bm = bmesh.new()
for x in (-0.085, 0.112):
    for s in (1, -1):
        lib.lathe(bm, [(0.0, 0.0), (0.0042, 0.0), (0.0042, 0.0012), (0.0032, 0.0020), (0.0, 0.0021)],
                  G(x, s * (WL - 0.0004), 0.010), V(0, s, 0), 14, ref=X)
lib.lathe(bm, [(0.0, 0.0), (0.0055, 0.0), (0.0055, 0.0025), (0.0045, 0.0035), (0.0, 0.0036)],
          G(0.084, -(WL - 0.0004), -0.012), V(0, -1, 0), 16, ref=X)
lib.prism_xz(bm, [P(0.022, 0.006), P(0.034, 0.006), P(0.036, 0.020), P(0.022, 0.020)], WL - 0.0004, WL + 0.0022, 0.0006, r=0.002)
ob_hw = lib.bm_to_obj("Rifle_Hardware", bm, coll, M["M_Steel"], root)

for o in (ob_up, ob_bolt, ob_knob, ob_low, ob_furn, ob_pad, ob_bar, ob_dot, ob_trig, ob_sel, ob_mag, ob_hw):
    lib.finish(o, sharp=40)

lib.set_origin(ob_bolt, G(0.040, -W + 0.003, 0.045))
lib.set_origin(ob_knob, G(0.054, -W - 0.016, 0.045))
lib.set_origin(ob_trig, G(0.0135, 0, 0.003))
lib.set_origin(ob_sel, G(-0.011, WL, 0.0138))
lib.set_origin(ob_mag, G(0.0605, 0, 0.006))
lib.set_origin(ob_dot, G(0.3292, 0, 0.0790))
bpy.context.view_layer.update()
for child, parent in ((ob_knob, ob_bolt), (ob_dot, ob_bar)):
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
