"""Pump-action shotgun (original design).  Muzzle +X, up +Z, left +Y.
Origin = stock wrist (hand).  Animatable: Pump (forend), Bolt, Trigger."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Shotgun"
LOC = V(1.45, 1.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
GRIP = V(-0.125, 0, -0.010)
def P(x, z): return (x - GRIP.x, z - GRIP.z)
def G(x, y, z): return V(x - GRIP.x, y, z - GRIP.z)

# ============================================================ receiver ====
W, ZB, ZT, C, D = 0.0180, 0.000, 0.062, 0.0068, 0.0065
PORT = (0.004, 0.056)
def rec_ring(x, port, k=1.0, zt=ZT):
    if port:
        right = [(-W, ZB), (-W, 0.020), (-W + D, 0.020), (-W + D, 0.044), (-W, 0.044)]
    else:
        right = [(-W, ZB), (-W, 0.020), (-W, 0.026), (-W, 0.038), (-W, 0.044)]
    pts = right + [(-W, zt - C), (-W + C * 0.6, zt - C * 0.15), (-W + C, zt), (W - C, zt), (W - C * 0.6, zt - C * 0.15), (W, zt - C), (W, ZB)]
    cz = (ZB + zt) / 2
    return [G(x, y * k, lerp(cz, z, k)) for y, z in pts]
xs = [(-0.086, False, 0.94, 0.054), (-0.084, False, 1.0, 0.054), (-0.050, False, 1.0, ZT), (PORT[0], False, 1.0, ZT),
      (PORT[0] + 0.0005, True, 1.0, ZT), (0.030, True, 1.0, ZT), (PORT[1] - 0.0005, True, 1.0, ZT), (PORT[1], False, 1.0, ZT),
      (0.104, False, 1.0, ZT), (0.106, False, 0.94, ZT)]
bm = bmesh.new()
lib.loft(bm, [rec_ring(x, p, k, zt) for x, p, k, zt in xs], cap0='ngon', cap1='ngon')
ob_rec = lib.bm_to_obj("Shotgun_Receiver", bm, coll, M["M_Gunmetal"], root)

bm = bmesh.new()
lib.prism_xz(bm, [P(0.008, 0.0215), P(0.048, 0.0215), P(0.048, 0.0425), P(0.008, 0.0425)], -W + D + 0.002, -W + 0.003, 0.0010)
ob_bolt = lib.bm_to_obj("Shotgun_Bolt", bm, coll, M["M_Steel"], root)

# ================================================ barrel, rib, tube, clamp
BZ, TZ = 0.0425, 0.0110
bm = bmesh.new()
BL = 0.445
lib.lathe(bm, [(0.0, 0.0), (0.0134, 0.0), (0.0134, BL - 0.013), (0.0141, BL - 0.011), (0.0141, BL - 0.003), (0.0134, BL),
               (0.0090, BL), (0.0088, BL - 0.005), (0.0, BL - 0.005)], G(0.103, 0, BZ), X, 24, ref=Z)
lib.prism_xz(bm, [P(0.108, 0.0570), P(0.103 + BL - 0.003, 0.0570), P(0.103 + BL - 0.003, 0.0612), P(0.108, 0.0612)], -0.0038, 0.0038, 0.0008)
for i in range(8):
    x0 = 0.140 + i * 0.054
    lib.prism_xz(bm, [P(x0, 0.0540), P(x0 + 0.006, 0.0540), P(x0 + 0.006, 0.0575), P(x0, 0.0575)], -0.0026, 0.0026, 0.0006)
lib.lathe(bm, [(0.0, 0.0), (0.0116, 0.0), (0.0116, 0.398), (0.0128, 0.400), (0.0128, 0.413), (0.0098, 0.417), (0.0, 0.418)],
          G(0.100, 0, TZ), X, 20, ref=Z)
clamp = [(0.468, -0.0025), (0.488, -0.0025), (0.488, 0.0575), (0.468, 0.0575)]
lib.prism_xz(bm, [P(*p) for p in clamp], -0.0150, 0.0150, 0.0025, r=0.007)
ob_bar = lib.bm_to_obj("Shotgun_Barrel", bm, coll, M["M_Gunmetal"], root)

bm = bmesh.new()
lib.lathe(bm, [(0.0, -0.0005), (0.0024, 0.0), (0.0026, 0.0022), (0.0016, 0.0038), (0.0, 0.0044)], G(0.103 + BL - 0.008, 0, 0.0610), Z, 8, ref=X)
ob_bead = lib.bm_to_obj("Shotgun_Bead", bm, coll, M["M_Paint_Orange"], root)

# ================================================================ pump ====
bm = bmesh.new()
rings = []
xs = [0.185, 0.189, 0.204]
for i in range(6):
    x0 = 0.220 + i * 0.024
    xs += [x0, x0 + 0.004, x0 + 0.010, x0 + 0.014]
xs += [0.364, 0.386, 0.390]
for x in xs:
    k = 1.0
    if x in (0.185, 0.390): k = 0.88
    elif x in (0.189, 0.386): k = 0.97
    rel = (x - 0.220) % 0.024 if 0.220 <= x < 0.364 else None
    if rel is not None and 0.0035 < rel < 0.0145: k = 0.94     # grooves
    rings.append(lib.place(lib.round_rect(0.0245 * k, 0.0152 * k, 0.0090 * k, 4), G(x, 0, TZ), Y, Z))
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_pump = lib.bm_to_obj("Shotgun_Pump", bm, coll, M["M_Polymer"], root)

# =============================================================== stock ====
bm = bmesh.new()
stock = [(-0.080, 0.056), (-0.080, 0.004), (-0.104, -0.010), (-0.126, -0.036), (-0.150, -0.040), (-0.172, -0.022),
         (-0.215, -0.027), (-0.432, -0.080), (-0.436, 0.062), (-0.300, 0.0545), (-0.228, 0.0500), (-0.152, 0.0420),
         (-0.110, 0.0500)]
lib.pillow_xz(bm, [P(*p) for p in stock], -0.0182, 0.0182, 0.0110, seg=4,
              fil=[0.004, 0.010, 0.012, 0.012, 0.010, 0.015, 0.040, 0.006, 0.006, 0.030, 0.030, 0.015, 0.008])
# raised cheek comb on the left side + sling stud under the toe
lib.pillow_xz(bm, [P(-0.330, 0.030), P(-0.205, 0.034), P(-0.190, 0.052), P(-0.330, 0.055)], 0.010, 0.0215, 0.005, seg=3,
              fil=0.010)
lib.lathe(bm, [(0.0, 0.0), (0.0055, 0.0), (0.0055, 0.006), (0.0045, 0.009), (0.0, 0.009)], G(-0.390, 0, -0.064), V(0.17, 0, -1).normalized(), 10)
ob_stock = lib.bm_to_obj("Shotgun_Stock", bm, coll, M["M_Polymer"], root)
# checkering panels on the wrist (both sides): small raised diamonds
bm = bmesh.new()
for side in (-1, 1):
    for i in range(7):
        for j in range(4):
            x = -0.118 - i * 0.0105 - (j % 2) * 0.0052
            z = -0.004 + j * 0.0088 + i * 0.0006
            d = [(x, z - 0.0040), (x + 0.0042, z), (x, z + 0.0040), (x - 0.0042, z)]
            yy = side * 0.0165
            lib.prism_xz(bm, [P(*q) for q in d], yy - 0.0012 * side, yy + 0.0018 * side, 0.0006)
ob_check = lib.bm_to_obj("Shotgun_Checkering", bm, coll, M["M_Rubber"], root)
bm = bmesh.new()
lib.pillow_xz(bm, [P(-0.450, -0.084), P(-0.430, -0.081), P(-0.434, 0.063), P(-0.450, 0.063)], -0.0192, 0.0192, 0.008, seg=3,
              fil=0.005)
ob_pad = lib.bm_to_obj("Shotgun_ButtPad", bm, coll, M["M_Rubber"], root)

# ======================================================= trigger group ====
bm = bmesh.new()
lib.prism_xz(bm, [P(-0.066, 0.004), P(0.036, 0.004), P(0.036, -0.006), P(-0.060, -0.006)], -0.0140, 0.0140, 0.0016, r=0.003)
gp = [(0.030, -0.004), (0.028, -0.020), (0.014, -0.0275), (-0.010, -0.0265), (-0.034, -0.016), (-0.046, -0.004)]
pts = [G(x, 0, z) for x, z in gp]
lib.loft(bm, [lib.place(lib.round_rect(0.0030, 0.0062, 0.0022, 1), p, u, v) for p, t, u, v in lib.path_frames(pts, up=Y)],
         cap0='ngon', cap1='ngon')
# side saddle on the left (+Y)
lib.prism_xz(bm, [P(-0.050, 0.008), P(0.050, 0.008), P(0.050, 0.052), P(-0.050, 0.052)], W - 0.0005, W + 0.0040, 0.0012, r=0.004)
ob_tg = lib.bm_to_obj("Shotgun_TriggerGroup", bm, coll, M["M_Polymer"], root)

bm = bmesh.new()
trig = [(0.000, -0.005), (0.007, -0.005), (0.009, -0.012), (0.011, -0.021), (0.0072, -0.0235), (0.0045, -0.016), (0.0022, -0.009)]
lib.prism_xz(bm, [P(*p) for p in trig], -0.0034, 0.0034, 0.0010, r=0.0011)
ob_trig = lib.bm_to_obj("Shotgun_Trigger", bm, coll, M["M_Gunmetal"], root)

# shells in the saddle (hull + brass head)
bmh = bmesh.new(); bmb = bmesh.new()
for i in range(4):
    x = -0.036 + i * 0.024
    c = G(x, W + 0.0040 + 0.0098, 0.002)
    lib.lathe(bmh, [(0.0, 0.054), (0.0080, 0.0535), (0.0098, 0.051), (0.0098, 0.010), (0.0, 0.010)], c, Z, 10, ref=X)
    lib.lathe(bmb, [(0.0, 0.0), (0.0104, 0.0), (0.0106, 0.0018), (0.0101, 0.0026), (0.0101, 0.0110), (0.0, 0.0110)], c, Z, 10, ref=X)
ob_sh = lib.bm_to_obj("Shotgun_Shells", bmh, coll, M["M_Shell_Red"], root)
ob_br = lib.bm_to_obj("Shotgun_ShellBrass", bmb, coll, M["M_Brass"], root)

for o in (ob_rec, ob_bolt, ob_bar, ob_bead, ob_pump, ob_stock, ob_check, ob_pad, ob_tg, ob_trig, ob_sh, ob_br):
    lib.finish(o, sharp=40)
lib.set_origin(ob_pump, G(0.2875, 0, TZ))
lib.set_origin(ob_bolt, G(0.028, -W + 0.003, 0.032))
lib.set_origin(ob_trig, G(0.0035, 0, -0.005))
lib.set_origin(ob_bead, G(0.103 + BL - 0.008, 0, 0.0610))
bpy.context.view_layer.update()
for child, parent in ((ob_bead, ob_bar), (ob_br, ob_sh)):
    mw = child.matrix_world.copy(); child.parent = parent; child.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
