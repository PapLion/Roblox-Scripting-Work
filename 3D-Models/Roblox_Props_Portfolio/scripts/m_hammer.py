"""Blacksmith hammer (cross-peen).  Grip origin = lower third of the handle."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, interp, TAU

NAME = "Hammer"
LOC = V(1.3, 0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# --------------------------------------------------------------- handle ---
H0, H1 = -0.105, 0.305
HC = 0.264                                   # head centre height
HR = [(H0, (0.0205, 0.0172)), (H0 + 0.012, (0.0212, 0.0178)), (H0 + 0.04, (0.0176, 0.0148)),
      (0.0, (0.0168, 0.0142)), (0.12, (0.0152, 0.0130)), (0.20, (0.0162, 0.0136)),
      (0.230, (0.0170, 0.0140)), (H1, (0.0170, 0.0140))]


def frame_at(z):
    rx, ry = interp(HR, z)
    return V(0, 0, z), X, Y, rx, ry


N = 12


def ring(z, k=1.0):
    c, u, v, rx, ry = frame_at(z)
    return [c + u * math.cos(TAU * i / N) * rx * k + v * math.sin(TAU * i / N) * ry * k for i in range(N)]


bm = bmesh.new()
zs = [H0 + 0.003, H0 + 0.010, H0 + 0.02, H0 + 0.04, -0.05, 0.0, 0.06, 0.12, 0.17, 0.205, 0.230, 0.264, H1 - 0.003]
rings = [ring(H0, 0.6), ring(H0 + 0.0012, 0.86)] + [ring(z) for z in zs] + [ring(H1 - 0.0005, 0.9), ring(H1, 0.72)]
lib.loft(bm, rings, cap0=V(0, 0, H0 - 0.0006), cap1='ngon')
ob_handle = lib.bm_to_obj("Hammer_Handle", bm, coll, M["M_Wood"], root)

# ----------------------------------------------------------------- head ---
# (x, half_y, half_z, chamfer) ; face at -X, cross-peen at +X
HS = [(-0.0790, 0.0200, 0.0200, 0.0070),
      (-0.0770, 0.0242, 0.0242, 0.0085),
      (-0.0680, 0.0245, 0.0245, 0.0085),
      (-0.0640, 0.0222, 0.0222, 0.0078),     # forged step behind the face
      (-0.0480, 0.0205, 0.0215, 0.0068),     # neck
      (-0.0290, 0.0250, 0.0290, 0.0062),     # cheek / eye block
      (-0.0100, 0.0262, 0.0300, 0.0062),
      (0.0100, 0.0262, 0.0300, 0.0062),
      (0.0290, 0.0250, 0.0290, 0.0062),
      (0.0420, 0.0210, 0.0215, 0.0060),      # neck
      (0.0580, 0.0222, 0.0140, 0.0045),
      (0.0720, 0.0230, 0.0075, 0.0028),
      (0.0800, 0.0228, 0.0040, 0.0016),
      (0.0835, 0.0218, 0.0018, 0.0008)]       # peen edge (horizontal, along Y)
K = 1.18
HS = [(x * K, hy * K, hz * K, c * K) for x, hy, hz, c in HS]
bm = bmesh.new()
rings = []
for x, hy, hz, c in HS:
    rings.append(lib.place(lib.chamfer_rect(hy, hz, c), V(x, 0, HC), Y, Z))
lib.loft(bm, rings, cap0=V(HS[0][0] - 0.0018, 0, HC), cap1='ngon')   # slightly crowned face
ob_head = lib.bm_to_obj("Hammer_Head", bm, coll, M["M_SteelDark"], root)
NR = 8
face_rings = [list(range(1 * NR, 2 * NR)), list(range(2 * NR, 3 * NR))]

# polished striking face plate (separate bright steel shell, seated on the face)
bm = bmesh.new()
fx = HS[0][0]
pf = lib.chamfer_rect(0.0215 * K, 0.0215 * K, 0.0076 * K)
lib.loft(bm, [lib.place(pf, V(fx + 0.004, 0, HC), Y, Z),
              lib.place(pf, V(fx - 0.0006, 0, HC), Y, Z),
              lib.place(lib.offset_poly(pf, -0.0018), V(fx - 0.0020, 0, HC), Y, Z)],
         cap0='ngon', cap1=V(fx - 0.0036, 0, HC))
ob_face = lib.bm_to_obj("Hammer_Face", bm, coll, M["M_Steel"], root)

# ------------------------------------------------------- langets + rivets --
bm = bmesh.new()
LZ0, LZ1 = 0.131, HC - 0.012
for s in (1, -1):
    rings = []
    zz = [LZ0, LZ0 + 0.004, LZ0 + 0.012] + [lerp(LZ0 + 0.02, LZ1, i / 5) for i in range(6)]
    for z in zz:
        c, u, v, rx, ry = frame_at(z)
        k = 1.0 if z > LZ0 + 0.011 else (0.45 if z < LZ0 + 0.001 else 0.8)   # pointed lower end
        half = 0.42 * k
        pts = []
        for j, th in enumerate([-half, -half * 0.5, 0, half * 0.5, half]):
            a = s * math.pi / 2 + th * s
            pts.append(c + u * math.cos(a) * (rx + 0.0028) + v * math.sin(a) * (ry + 0.0028))
        for th in [half, -half]:
            a = s * math.pi / 2 + th * s
            pts.append(c + u * math.cos(a) * (rx - 0.0006) + v * math.sin(a) * (ry - 0.0006))
        rings.append(pts)
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')
ob_lang = lib.bm_to_obj("Hammer_Langets", bm, coll, M["M_SteelDark"], root)

bm = bmesh.new()
for s in (1, -1):
    for z in (0.172, 0.222):
        c, u, v, rx, ry = frame_at(z)
        lib.dome_rivet(bm, c + V(0, s * (ry + 0.0026), 0), V(0, s, 0), 0.0042, 0.0026, n=8, ref=Z)
# copper collar binding the langets
lib.band(bm, frame_at, 0.128, 0.146, n=14, out=0.0052, sink=0.001, ch=0.0014)
ob_cu = lib.bm_to_obj("Hammer_Collar", bm, coll, M["M_Copper"], root)

# wedge on top of the handle
bm = bmesh.new()
wed = lib.chamfer_rect(0.0135, 0.0024, 0.0008)
lib.loft(bm, [lib.place(wed, V(0, 0, H1 - 0.012), X, Y), lib.place(wed, V(0, 0, H1 + 0.0022), X, Y),
              lib.place(lib.offset_poly(wed, -0.0006), V(0, 0, H1 + 0.0032), X, Y)], cap0='ngon', cap1='ngon')
ob_wedge = lib.bm_to_obj("Hammer_Wedge", bm, coll, M["M_Steel"], root)

lib.finish(ob_handle, sharp=60)
lib.finish(ob_head, sharp=33, sharp_rings=face_rings)
lib.finish(ob_face, sharp=33)
lib.finish(ob_lang, sharp=40)
lib.finish(ob_cu, sharp=40)
lib.finish(ob_wedge, sharp=40)

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        print(o.name, lib.check_mesh(o))
