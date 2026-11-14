"""Military ammo box (original design): stamped body, overlapping lid on a rear hinge,
front cam latch, folding carry handle.  Origin = bottom centre.  Long axis X.
Animatable: Lid (pivot = hinge axis), Latch (pivot = latch axis), Handle (pivot = bracket axis)."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "AmmoBox"
LOC = V(2.75, 1.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
HX, HY, R = 0.150, 0.060, 0.011
LID0, TOP = 0.146, 0.176

# ================================================================= body ===
bm = bmesh.new()
zs = [(0.000, 0.93), (0.004, 1.0), (0.036, 1.0), (0.039, 1.035), (0.049, 1.035), (0.052, 1.0),
      (0.096, 1.0), (0.099, 1.035), (0.109, 1.035), (0.112, 1.0), (0.150, 1.0), (0.152, 0.97)]
rings = []
for z, k in zs:
    ex = (k - 1) * 0.15  # rib protrudes ~5 mm on the long sides, less on the ends
    rings.append(lib.place(lib.round_rect(HX + ex * 0.6, HY + ex, R, 2), V(0, 0, z), X, Y))
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# rear hinge leaf on the body
lib.prism_xz(bm, [(-0.105, 0.128), (0.105, 0.128), (0.105, 0.150), (-0.105, 0.150)], -HY - 0.0025, -HY + 0.001, 0.0010, r=0.003)
# latch catch block on the front of the body
lib.prism_xz(bm, [(-0.022, 0.104), (0.022, 0.104), (0.022, 0.118), (-0.022, 0.118)], HY - 0.001, HY + 0.0055, 0.0012, r=0.003)
ob_body = lib.bm_to_obj("AmmoBox_Body", bm, coll, M["M_Paint_OD"], root)

# accent stripe + blank label plate
bm = bmesh.new()
lib.prism_xz(bm, [(-0.135, 0.060), (-0.040, 0.060), (-0.040, 0.088), (-0.135, 0.088)], HY - 0.0006, HY + 0.0012, 0.0006, r=0.002)
ob_stripe = lib.bm_to_obj("AmmoBox_Stripe", bm, coll, M["M_Paint_Orange"], root)
bm = bmesh.new()
lib.prism(bm, lib.fillet([(-0.040, 0.060), (0.040, 0.060), (0.040, 0.092), (-0.040, 0.092)], 0.004),
          V(HX + 0.0003, 0, 0), V(0, 1, 0), V(0, 0, 1), V(1, 0, 0), 0.0012, 0.0006)
ob_label = lib.bm_to_obj("AmmoBox_Label", bm, coll, M["M_Polymer_Tan"], root)

# ================================================================== lid ===
bm = bmesh.new()
lz = [(LID0, 1.0, 0.0), (LID0 + 0.002, 1.0, 0.0035), (TOP - 0.006, 1.0, 0.0035), (TOP - 0.002, 0.985, 0.0035),
      (TOP, 0.955, 0.0035)]
rings = [lib.place(lib.round_rect(HX * k + d, HY * k + d, R + d, 2), V(0, 0, z), X, Y) for z, k, d in lz]
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# embossed panel on the lid top
pan = lib.fillet([(-0.115, -0.038), (0.115, -0.038), (0.115, 0.038), (-0.115, 0.038)], 0.008)
lib.loft(bm, [lib.place(pan, V(0, 0, TOP - 0.001), X, Y), lib.place(pan, V(0, 0, TOP + 0.0022), X, Y),
              lib.place(lib.offset_poly(pan, -0.003), V(0, 0, TOP + 0.0034), X, Y)], cap0='ngon', cap1='ngon')
ob_lid = lib.bm_to_obj("AmmoBox_Lid", bm, coll, M["M_Paint_OD"], root)

# hinge knuckles (lid side + body side alternate) -- steel
HZ_, HYY = 0.152, -HY - 0.0065
bm = bmesh.new()
for x0, x1 in ((-0.105, -0.055), (-0.035, 0.035), (0.055, 0.105)):
    lib.lathe(bm, [(0.0, 0.0), (0.0052, 0.0), (0.0058, 0.0012), (0.0058, x1 - x0 - 0.0012), (0.0052, x1 - x0), (0.0, x1 - x0)],
              V(x0, HYY, HZ_), X, 10, ref=Z)
for x0, x1 in ((-0.054, -0.036), (0.036, 0.054)):
    lib.lathe(bm, [(0.0, 0.0), (0.0050, 0.0), (0.0050, x1 - x0), (0.0, x1 - x0)], V(x0, HYY, HZ_), X, 10, ref=Z)
ob_hinge = lib.bm_to_obj("AmmoBox_Hinge", bm, coll, M["M_SteelDark"], root)

# ================================================================ latch ===
bm = bmesh.new()
LY = HY + 0.0055
lat = [(-0.020, 0.110), (0.020, 0.110), (0.020, 0.171), (0.012, 0.1785), (-0.012, 0.1785), (-0.020, 0.171)]
lib.prism_xz(bm, lat, LY + 0.0002, LY + 0.0042, 0.0010, r=0.004)
# bent lip over the lid edge
lib.prism(bm, lib.fillet([(-0.012, -0.004), (0.012, -0.004), (0.012, 0.007), (-0.012, 0.007)], 0.002),
          V(0, LY - 0.0035, 0.1774), V(1, 0, 0), V(0, 1, 0), V(0, 0, 1), 0.0016, 0.0006)
lib.lathe(bm, [(0.0, 0.0), (0.0042, 0.0), (0.0042, 0.050), (0.0, 0.050)], V(-0.025, LY + 0.0022, 0.112), X, 10, ref=Z)
ob_latch = lib.bm_to_obj("AmmoBox_Latch", bm, coll, M["M_SteelDark"], root)

# =============================================================== handle ===
bm = bmesh.new()
for sx in (-1, 1):   # brackets riveted to the lid
    lib.prism_xz(bm, [(sx * 0.074 - 0.009, TOP), (sx * 0.074 + 0.009, TOP), (sx * 0.074 + 0.007, TOP + 0.011),
                      (sx * 0.074 - 0.007, TOP + 0.011)], -0.010, 0.010, 0.0012, r=0.003)
ob_brk = lib.bm_to_obj("AmmoBox_HandleBrackets", bm, coll, M["M_SteelDark"], root)
bm = bmesh.new()
HZZ = TOP + 0.0086
hp = [V(-0.074, -0.0005, HZZ), V(-0.072, 0.012, HZZ), V(-0.062, 0.030, HZZ + 0.001), V(-0.045, 0.034, HZZ + 0.0015),
      V(0.045, 0.034, HZZ + 0.0015), V(0.062, 0.030, HZZ + 0.001), V(0.072, 0.012, HZZ), V(0.074, -0.0005, HZZ)]
hp = [hp[0] + V(-0.006, 0, 0)] + hp + [hp[-1] + V(0.006, 0, 0)]
lib.loft(bm, [lib.place(lib.ellipse(0.0042, 0.0042, 8), p, u, v) for p, t, u, v in lib.path_frames(hp, up=Z)],
         cap0='ngon', cap1='ngon')
ob_handle = lib.bm_to_obj("AmmoBox_Handle", bm, coll, M["M_Steel"], root)

for o in (ob_body, ob_stripe, ob_label, ob_lid, ob_hinge, ob_latch, ob_brk, ob_handle):
    lib.finish(o, sharp=40)
lib.set_origin(ob_lid, V(0, HYY, HZ_))
lib.set_origin(ob_latch, V(0, LY + 0.0022, 0.112))
lib.set_origin(ob_handle, V(0, -0.0005, HZZ))
bpy.context.view_layer.update()
for child, parent in ((ob_handle, ob_lid), (ob_brk, ob_lid)):
    mw = child.matrix_world.copy(); child.parent = parent; child.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
