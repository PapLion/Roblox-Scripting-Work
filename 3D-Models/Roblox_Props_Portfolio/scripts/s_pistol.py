"""Modern semi-automatic pistol (original design, striker-fired look).
Axes: muzzle +X, up +Z, left side +Y (camera at -Y sees the right side / ejection port).
Origin = grip centre (hand).  Animatable parts: Slide, Barrel, Magazine, Trigger."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Pistol"
LOC = V(0.0, 1.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
GRIP = V(-0.072, 0, -0.004)          # hand centre (local); everything is built around this

def P(x, z):  # author in "gun space", shifted so the grip is the origin
    return (x - GRIP.x, z - GRIP.z)

# ================================================================ slide ===
W, ZB = 0.0130, 0.050
PORT = (0.004, 0.041)
def zt(x):     # top line with a sloped nose
    return 0.083 if x < 0.093 else lerp(0.083, 0.075, (x - 0.093) / 0.011)

def slide_ring(x, port):
    t = zt(x); c = 0.0045
    if port:
        pts = [(-W, ZB), (-W, 0.059), (0.0050, 0.059), (0.0050, t), (W - c, t), (W, t - c), (W, ZB + 0.002)]
    else:
        pts = [(-W, ZB), (-W, t - c), (-W + c, t), (-W + c + 0.006, t), (W - c, t), (W, t - c), (W, ZB + 0.002)]
    # tiny chamfer on the bottom right corner via the last point; ring in (y, z)
    return [V(x - GRIP.x, y, z - GRIP.z) for y, z in pts]

xs = [(-0.0885, False), (-0.088, False), (-0.060, False), (-0.020, False), (PORT[0], False), (PORT[0] + 0.0005, True),
      (0.022, True), (PORT[1] - 0.0005, True), (PORT[1], False), (0.070, False), (0.093, False), (0.1035, False), (0.104, False)]
bm = bmesh.new()
rings = []
for i, (x, port) in enumerate(xs):
    r = slide_ring(x, port)
    if i in (0, len(xs) - 1):           # chamfered end faces
        cy = sum(p.y for p in r) / len(r); cz = sum(p.z for p in r) / len(r)
        r = [V(p.x, lerp(cy, p.y, 0.9), lerp(cz, p.z, 0.9)) for p in r]
    rings.append(r)
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
# serrations (raised ribs) at the rear, both sides
for i in range(6):
    x0 = -0.080 + i * 0.0048
    for s in (1, -1):
        y0 = s * (W - 0.0004); y1 = s * (W + 0.0009)
        lib.prism_xz(bm, [P(x0, 0.055), P(x0 + 0.0022, 0.055), P(x0 + 0.0022, 0.0775), P(x0, 0.0775)], y0, y1, 0.0004)
for i in range(4):                     # front cocking serrations
    x0 = 0.050 + i * 0.0048
    for s in (1, -1):
        y0 = s * (W - 0.0004); y1 = s * (W + 0.0009)
        lib.prism_xz(bm, [P(x0, 0.058), P(x0 + 0.0022, 0.058), P(x0 + 0.0022, 0.0760), P(x0, 0.0760)], y0, y1, 0.0004)
# rear sight (two posts) and front sight
lib.prism_xz(bm, [P(-0.083, 0.082), P(-0.071, 0.082), P(-0.072, 0.0865), P(-0.082, 0.0865)], -0.0088, 0.0088, 0.0008)
for s in (1, -1):
    lib.prism_xz(bm, [P(-0.083, 0.085), P(-0.072, 0.085), P(-0.0735, 0.0915), P(-0.082, 0.0915)],
                 s * 0.0026, s * 0.0088, 0.0007)
lib.prism_xz(bm, [P(0.084, 0.082), P(0.094, 0.082), P(0.0925, 0.0905), P(0.0865, 0.0905)], -0.0022, 0.0022, 0.0006)
ob_slide = lib.bm_to_obj("Pistol_Slide", bm, coll, M["M_Gunmetal"], root)

bm = bmesh.new()
dot = lib.lathe(bm, [(0.0, 0.0006), (0.0016, 0.0004), (0.0018, -0.0004)], V(0.0858 - GRIP.x, 0, 0.0874 - GRIP.z), V(-1, 0, 0), 8, ref=Z)
bm.faces.new(dot[-1])
ob_dot = lib.bm_to_obj("Pistol_SightDot", bm, coll, M["M_Paint_Orange"], root)

# =============================================================== barrel ===
bm = bmesh.new()
# hood visible in the ejection port
lib.prism_xz(bm, [P(0.003, 0.058), P(0.0425, 0.058), P(0.0425, 0.0805), P(0.003, 0.0805)], -0.0108, 0.0062, 0.0012)
# muzzle tube with bore
mz = V(0.1068 - GRIP.x, 0, 0.0640 - GRIP.z)
prof = [(0.0060, -0.012), (0.0062, -0.0004), (0.0056, 0.0), (0.0040, 0.0), (0.0038, -0.0030), (0.0, -0.0032)]
rows = lib.lathe(bm, prof, mz, X, 12, ref=Z)
bm.faces.new(list(reversed(rows[0])))
ob_barrel = lib.bm_to_obj("Pistol_Barrel", bm, coll, M["M_Steel"], root)

# ================================================================ frame ===
bm = bmesh.new()
upper = [P(-0.091, 0.041), P(-0.030, 0.0335), P(0.100, 0.0355), P(0.100, 0.053), P(-0.093, 0.053)]
lib.prism_xz(bm, upper, -0.0112, 0.0112, 0.0016, r=0.0025)
# accessory rail grooves under the dust cover (3 cross slots as raised lugs)
for i in range(3):
    x0 = 0.058 + i * 0.012
    lib.prism_xz(bm, [P(x0, 0.0325), P(x0 + 0.0065, 0.0325), P(x0 + 0.0065, 0.037), P(x0, 0.037)], -0.0095, 0.0095, 0.0008)
grip = [P(-0.0575, -0.052), P(-0.0480, -0.016), P(-0.0345, 0.016), P(-0.030, 0.041), P(-0.082, 0.046), P(-0.0985, 0.0475),
        P(-0.090, 0.036), P(-0.0990, 0.006), P(-0.1085, -0.030), P(-0.1095, -0.052)]
lib.pillow_xz(bm, grip, -0.0148, 0.0148, 0.0070, seg=4, fil=[0.004, 0.012, 0.004, 0.002, 0.004, 0.003, 0.006, 0.012, 0.012, 0.004])
# raised grip panels
panel = [P(-0.061, -0.043), P(-0.044, 0.008), P(-0.083, 0.016), P(-0.101, -0.043)]
panel = lib.offset_poly(lib.ccw(panel), -0.0045)          # keep the texture panel on the flat of the pillowed grip
for s in (1, -1):
    lib.prism_xz(bm, panel, s * 0.0144, s * 0.0156, 0.0005, r=0.004)
ob_frame_tmp = None
bm_st = bmesh.new()


def inside(poly, x, z):
    c = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / (z2 - z1) + x1:
            c = not c
    return c


for s in (1, -1):                       # stippling dots
    for i in range(14):
        for j in range(20):
            x = -0.112 + i * 0.0045 + (j % 2) * 0.00225 - GRIP.x
            z = -0.052 + j * 0.0036 - GRIP.z
            if not inside(lib.offset_poly(panel, -0.002), x, z):
                continue
            c = V(x, s * 0.0156, z)
            lib.lathe(bm_st, [(0.0, 0.0), (0.0013, 0.0), (0.0, 0.0010)], c - V(0, s * 0.0002, 0), V(0, s, 0), 4, ref=X)
# trigger guard (loop) -- lofted bar
gp = [(0.036, 0.0360), (0.0415, 0.0250), (0.0425, 0.0110), (0.0345, 0.0045), (0.012, 0.0030), (-0.016, 0.0040), (-0.034, 0.0120), (-0.0405, 0.0185)]
pts = [V(x - GRIP.x, 0, z - GRIP.z) for x, z in gp]
rings = [lib.place(lib.round_rect(0.0030, 0.0058, 0.0022, 1), p, u, v) for p, t, u, v in lib.path_frames(pts, up=Y)]
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_frame = lib.bm_to_obj("Pistol_Frame", bm, coll, M["M_Polymer"], root)
ob_stip = lib.bm_to_obj("Pistol_GripTexture", bm_st, coll, M["M_Polymer"], root)
lib.finish(ob_stip, sharp=30, weighted=False)
ob_stip.parent = ob_frame if False else ob_stip.parent

# ============================================================== trigger ===
bm = bmesh.new()
trig = [(0.0035, 0.0355), (0.0105, 0.0355), (0.0125, 0.026), (0.0155, 0.0150), (0.0125, 0.0115), (0.0085, 0.0165), (0.0055, 0.026)]
lib.prism_xz(bm, [P(x, z) for x, z in trig], -0.0034, 0.0034, 0.0010, r=0.0015)
ob_trig = lib.bm_to_obj("Pistol_Trigger", bm, coll, M["M_Gunmetal"], root)

# ============================================================= magazine ===
bm = bmesh.new()
mag = [P(-0.0625, -0.050), P(-0.0420, 0.012), P(-0.0435, 0.036), P(-0.0835, 0.036), P(-0.1025, -0.050)]
lib.prism_xz(bm, mag, -0.0104, 0.0104, 0.0012, r=0.002)
base = [P(-0.0590, -0.0585), P(-0.0560, -0.0490), P(-0.1110, -0.0490), P(-0.1135, -0.0585)]
lib.prism_xz(bm, base, -0.0157, 0.0157, 0.0018, r=0.002)
ob_mag = lib.bm_to_obj("Pistol_Magazine", bm, coll, M["M_Polymer"], root)

for o, a in ((ob_slide, 40), (ob_dot, 40), (ob_barrel, 40), (ob_frame, 40), (ob_trig, 40), (ob_mag, 40)):
    lib.finish(o, sharp=a)

# pivots for animation
lib.set_origin(ob_slide, V(0.0 - GRIP.x, 0, 0.066 - GRIP.z))       # slide travels along -X
lib.set_origin(ob_barrel, V(0.040 - GRIP.x, 0, 0.066 - GRIP.z))
lib.set_origin(ob_trig, V(0.0070 - GRIP.x, 0, 0.0350 - GRIP.z))    # trigger hinge
lib.set_origin(ob_mag, V(-0.063 - GRIP.x, 0, 0.036 - GRIP.z))      # magazine top
lib.set_origin(ob_dot, V(0.0858 - GRIP.x, 0, 0.0874 - GRIP.z))
bpy.context.view_layer.update()
mw = ob_dot.matrix_world.copy()
ob_dot.parent = ob_slide
ob_dot.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
