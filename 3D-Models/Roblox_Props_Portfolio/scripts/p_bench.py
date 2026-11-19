"""Park bench (original design): two cast-iron side frames with armrests, a centre
rail, five seat slats and three back slats in wood, carriage-bolt heads at every joint.
Pivot = bottom centre (floor).  Front faces -Y.  Seat height suits the Roblox-scale
mannequin used in the showcase (~1.55 m tall).  root['seat_points'] = 2 sitting spots."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V, lerp, TAU

NAME = "Bench"
LOC = V(3.8, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
L = 1.80                 # slat length
FX = 0.70                # frame positions (x = +-FX)


def member(bm, x, pts_yz, w, t, r=0.012, it=2, n_seg=2):
    """Cast member: rounded-rect section (w across X, t in-plane) swept along a smoothed (y, z) path."""
    pts = lib.chaikin([V(x, y, z) for y, z in pts_yz], it)
    sec = lib.round_rect(w / 2, t / 2, r, n_seg)
    rings = []
    for p, tng, u, v in lib.path_frames(pts, up=X):
        rings.append([p + X * a + u * b for a, b in sec])
    # end caps slightly domed
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')


def slat(bm, cy, cz, ang, w, t, length=L, r=0.010, ch=0.006):
    ca, sa = math.cos(ang), math.sin(ang)
    sec = lib.round_rect(w / 2, t / 2, r, 3)
    sec_in = lib.round_rect(w / 2 - ch, t / 2 - ch, max(0.002, r - ch), 3)

    def ring(x, s):
        return [V(x, cy + a * ca - b * sa, cz + a * sa + b * ca) for a, b in s]
    lib.loft(bm, [ring(-length / 2, sec_in), ring(-length / 2 + ch, sec), ring(length / 2 - ch, sec),
                  ring(length / 2, sec_in)], cap0='ngon', cap1='ngon')


# ================================================================ frames ===
FRONT = [(-0.255, 0.0), (-0.248, 0.16), (-0.236, 0.36), (-0.232, 0.52), (-0.250, 0.600), (-0.215, 0.640),
         (-0.08, 0.650), (0.10, 0.650), (0.17, 0.655)]
REAR = [(0.255, 0.0), (0.225, 0.20), (0.185, 0.40), (0.195, 0.58), (0.235, 0.78), (0.268, 0.880)]
SEAT = [(-0.300, 0.398), (-0.10, 0.392), (0.10, 0.380), (0.215, 0.372)]
frames = []
for sx, tag in ((-1, "L"), (1, "R")):
    bm = bmesh.new()
    x = sx * FX
    member(bm, x, FRONT, 0.050, 0.044, it=2)
    member(bm, x, REAR, 0.050, 0.046, it=2)
    member(bm, x, SEAT, 0.046, 0.040, it=2)
    member(bm, x, [(-0.236, 0.10), (0.0, 0.07), (0.228, 0.10)], 0.036, 0.030, it=2)   # lower stretcher
    for y in (-0.255, 0.255):                                                         # foot pads
        lib.rounded_box(bm, V(x, y + (0.012 if y < 0 else -0.012), 0.016), 0.040, 0.060, 0.016, 0.010, seg=2)
    # decorative scroll under the armrest (original motif: open ring)
    sc = [V(x, -0.150 + 0.050 * math.cos(TAU * i / 20), 0.560 + 0.050 * math.sin(TAU * i / 20)) for i in range(20)]
    lib.loft(bm, [[p + X * a + (p - V(x, -0.150, 0.560)).normalized() * b for a, b in lib.round_rect(0.016, 0.009, 0.006, 1)]
                  for p in sc], wrap=True)
    member(bm, x, [(-0.150, 0.510), (-0.150, 0.408)], 0.026, 0.020, it=0)
    member(bm, x, [(-0.150, 0.610), (-0.150, 0.640)], 0.026, 0.020, it=0)
    ob = lib.bm_to_obj(f"Bench_Frame_{tag}", bm, coll, M["M_Iron"], root)
    frames.append(ob)

# centre rail under the seat (ties both frames)
bm = bmesh.new()
lib.rounded_box(bm, V(0, -0.02, 0.352), FX + 0.01, 0.018, 0.022, 0.008, seg=2)
lib.rounded_box(bm, V(0, -0.02, 0.200), 0.022, 0.018, 0.150, 0.008, seg=2)      # centre post
lib.rounded_box(bm, V(0, -0.02, 0.012), 0.050, 0.060, 0.012, 0.008, seg=2)
rail = lib.bm_to_obj("Bench_Rail", bm, coll, M["M_Iron"], root)

# ================================================================= slats ==
SLAT_W, SLAT_T = 0.088, 0.034
seat_y = [-0.262, -0.165, -0.068, 0.029, 0.126]
bm = bmesh.new()
bolts = []


def seat_z(y):
    # top of the seat member at y (linear fit of SEAT path) + half slat thickness
    return lerp(0.398, 0.372, (y + 0.300) / 0.515) + 0.020 + SLAT_T / 2


ang_seat = math.atan2(0.372 - 0.398, 0.515)
for i, y in enumerate(seat_y):
    z = seat_z(y)
    slat(bm, y, z, ang_seat, SLAT_W, SLAT_T, r=0.014 if i == 0 else 0.010)
    for sx in (-1, 1):
        bolts.append((V(sx * FX, y, z + SLAT_T / 2 - 0.001), V(-math.sin(ang_seat), 0, math.cos(ang_seat)).normalized()))
seat = lib.bm_to_obj("Bench_SeatSlats", bm, coll, M["M_WoodBench"], root)

bm = bmesh.new()
rear = lib.chaikin([V(0, y, z) for y, z in REAR], 3)
for zc in (0.555, 0.680, 0.805):
    # point on the rear member at height zc and its tangent
    k = min(range(len(rear) - 1), key=lambda j: abs(rear[j].z - zc))
    a, b = rear[k], rear[k + 1]
    tng = (b - a).normalized()
    nrm = V(0, -tng.z, tng.y)                    # in-plane normal pointing forward (-Y)
    if nrm.y > 0:
        nrm = -nrm
    c = a + nrm * (0.023 + SLAT_T / 2)
    ang = math.atan2(tng.z, tng.y) - math.pi / 2
    slat(bm, c.y, c.z, ang + math.pi / 2, SLAT_W * 1.05, SLAT_T)
    for sx in (-1, 1):
        bolts.append((V(sx * FX, c.y, c.z) + nrm * (SLAT_T / 2 - 0.001), nrm))
back = lib.bm_to_obj("Bench_BackSlats", bm, coll, M["M_WoodBench"], root)

bm = bmesh.new()
for o, n in bolts:
    lib.dome_rivet(bm, o, n, 0.011, 0.006, n=12, ref=X)
bolt = lib.bm_to_obj("Bench_Bolts", bm, coll, M["M_Iron"], root)

parts = frames + [rail, seat, back, bolt]
for o in parts:
    lib.finish(o, sharp=45)
root["seat_points"] = [[-0.42, -0.07, round(seat_z(-0.07) + SLAT_T / 2, 3)], [0.42, -0.07, round(seat_z(-0.07) + SLAT_T / 2, 3)]]
txt, tot = lib.report(coll)
print(txt, root["seat_points"][0][:])
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
