"""Compact city car (original design).  Front faces -Y, origin = ground centre between the axles.
Separate parts: body, roof (+pillars), glass, trim, lights, interior, seats, steering wheel and four
wheels (pivot = hub centre).  No driving system."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler
import lib
from lib import V, lerp, TAU

NAME = "Car"
LOC = V(0.0, 5.2, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

YF, YR = -1.75, 1.75           # nose / tail
AX = (-1.20, 1.20)             # axles
WR, WW, TRK = 0.29, 0.19, 0.69 # wheel radius, width, half track
CAB = (-0.80, 0.75)            # cabin cavity (dash .. rear bench back)
ZBELT = 0.93


def width(y):
    a = max(0.0, (abs(y) - 1.15) / 0.60)
    return 0.80 - 0.07 * a * a


def zbot(y):
    zb = 0.22
    for ya in AX:
        d = (y - ya) / 0.37
        if abs(d) < 1:
            zb = max(zb, 0.22 + 0.40 * math.sqrt(1 - d * d))
    return zb


def ztop(y):
    if y < CAB[0]:
        t = (y - YF) / (CAB[0] - YF)
        return 0.70 + 0.19 * math.sin(t * math.pi / 2)
    if y > CAB[1]:
        if y < 1.45:
            return 0.935 - 0.035 * (y - CAB[1]) / (1.45 - CAB[1])
        t = (y - 1.45) / (YR - 1.45)
        return 0.900 - 0.11 * t * t                      # rounded hatch tail
    return ZBELT


def zfloor(y):
    return 0.34 if y < 0.25 else lerp(0.34, 0.60, min(1, (y - 0.25) / 0.45))


def section(y, cabin, k=1.0):
    w = width(y) * k
    zb = zbot(y)
    ze = ztop(y)
    zc = (zb + ze) / 2
    p1 = (w - 0.07, zb)
    p2 = (w - 0.006, zb + 0.040)
    p3 = (w + 0.012, max(0.60, zb + 0.070))
    p4 = (w, ze - 0.045)
    p5 = (w - 0.032, ze)
    p2b = (w + 0.007, lerp(p2[1], p3[1], 0.5))
    p3b = (w + 0.010, lerp(p3[1], p4[1], 0.5))
    p4b = (w - 0.012, ze - 0.014)
    if cabin:
        wi = width(y) - 0.075
        p6, p7, p8 = (wi, ze), (wi, zfloor(y)), (0.0, zfloor(y))
    else:
        p6, p7, p8 = (w - 0.10, ze + 0.004), (0.38 * k, ze + 0.014), (0.0, ze + 0.018)
    right = [p1, p2, p2b, p3, p3b, p4, p4b, p5, p6, p7]
    pts = [(0.0, zb)] + right + [p8] + [(-x, z) for x, z in reversed(right)]
    if k != 1.0:
        pts = [(x, lerp(zc, z, k)) for x, z in pts]
    return [V(x, y, z) for x, z in pts]


ys = [(YF, False, 0.90), (YF + 0.006, False, 0.965), (YF + 0.025, False, 1.0), (-1.66, False, 1.0)]
ys += [(AX[0] + 0.37 * math.cos(math.pi * (1 - i / 16)), False, 1.0) for i in range(17)]
ys += [(CAB[0], False, 1.0), (CAB[0] + 0.005, True, 1.0)]
ys += [(y, True, 1.0) for y in (-0.65, -0.4, -0.1, 0.2, 0.4, 0.6)] + [(CAB[1], True, 1.0), (CAB[1] + 0.005, False, 1.0)]
ys += [(AX[1] + 0.37 * math.cos(math.pi * (1 - i / 16)), False, 1.0) for i in range(5, 17)]
ys += [(1.64, False, 1.0), (YR - 0.025, False, 1.0), (YR - 0.006, False, 0.965), (YR, False, 0.90)]
ys = sorted(ys, key=lambda t: t[0])
bm = bmesh.new()
lib.loft(bm, [section(y, c, k) for y, c, k in ys], cap0='ngon', cap1='ngon')
ob_body = lib.bm_to_obj("Car_Body", bm, coll, M["M_CarPaint"], root)


def side_x(y, z):
    """x of the right body side at height z (for decals)."""
    pts = section(y, CAB[0] < y < CAB[1])[1:9]
    for a, b in zip(pts, pts[1:]):
        if a.z <= z <= b.z:
            t = (z - a.z) / max(1e-6, b.z - a.z)
            return lerp(a.x, b.x, t)
    return pts[-1].x


# ------------------------------------------------------- roof + pillars --
def bar(bm, pts, hw, hh, up):
    fr = lib.path_frames(pts, up=up)
    lib.loft(bm, [lib.place(lib.round_rect(hw, hh, min(hw, hh) * 0.8, 1), p, u, v) for p, t, u, v in fr],
             cap0='ngon', cap1='ngon')


bm = bmesh.new()
roof = []
for y, k in ((-0.30, 0.90), (-0.285, 0.97), (-0.26, 1.0), (0.20, 1.0), (0.80, 1.0), (1.035, 0.97), (1.05, 0.90)):
    roof.append(lib.place(lib.round_rect(0.665 * k, 0.034 * k, 0.026, 2), V(0, y, 1.440 + 0.01 * math.sin(math.pi * (y + 0.3) / 1.35)), X, Z))
lib.loft(bm, roof, cap0='ngon', cap1='ngon')
for s in (1, -1):
    bar(bm, [V(s * 0.728, -0.798, 0.925), V(s * 0.705, -0.54, 1.18), V(s * 0.665, -0.27, 1.425)], 0.030, 0.026, Z)   # A
    bar(bm, [V(s * 0.735, 0.085, 0.925), V(s * 0.665, 0.085, 1.425)], 0.040, 0.022, Z)                            # B
    bar(bm, [V(s * 0.738, 1.470, 0.895), V(s * 0.705, 1.250, 1.180), V(s * 0.660, 1.030, 1.425)], 0.060, 0.026, Z) # C
ob_roof = lib.bm_to_obj("Car_Roof", bm, coll, M["M_CarWhite"], root)


# ---------------------------------------------------------------- glass --
def slab(bm, pts, t=0.004):
    c = sum(pts, V()) / len(pts)
    n = (pts[1] - pts[0]).cross(pts[-1] - pts[0]).normalized()
    lib.loft(bm, [[p + n * t for p in pts], [p - n * t for p in pts]], cap0='ngon', cap1='ngon')


bm = bmesh.new()
slab(bm, [V(-0.69, -0.792, 0.930), V(0.69, -0.792, 0.930), V(0.632, -0.272, 1.418), V(-0.632, -0.272, 1.418)])   # windshield
slab(bm, [V(-0.64, 1.455, 0.900), V(-0.59, 1.035, 1.415), V(0.59, 1.035, 1.415), V(0.64, 1.455, 0.900)])         # rear glass
for s in (1, -1):
    slab(bm, [V(s * 0.732, -0.775, 0.935), V(s * 0.735, 0.070, 0.935), V(s * 0.670, 0.070, 1.405), V(s * 0.672, -0.275, 1.405),
              V(s * 0.700, -0.530, 1.170)])
    slab(bm, [V(s * 0.735, 0.100, 0.935), V(s * 0.738, 1.440, 0.902), V(s * 0.703, 1.240, 1.170), V(s * 0.670, 1.020, 1.405),
              V(s * 0.668, 0.100, 1.405)])
ob_glass = lib.bm_to_obj("Car_Glass", bm, coll, M["M_Glass"], root)

# ----------------------------------------------------------------- trim --
bm = bmesh.new()
lib.rounded_box(bm, V(0, YF - 0.020, 0.335), 0.815, 0.080, 0.105, 0.050, rz=0.040)            # front bumper
lib.rounded_box(bm, V(0, YR + 0.020, 0.355), 0.815, 0.080, 0.105, 0.050, rz=0.040)            # rear bumper
lib.rounded_box(bm, V(0, YF + 0.004, 0.545), 0.300, 0.012, 0.042, 0.020)                        # grille
for s in (1, -1):
    # door seams following the body side
    for y in (-0.785, 0.080, 0.900):
        pts = [V(s * (side_x(y, z) + 0.0015), y, z) for z in (0.30 if zbot(y) < 0.3 else zbot(y) + 0.05, 0.45, 0.60, 0.75, 0.90)]
        bar(bm, pts, 0.0028, 0.0035, Y)
    # mirror stalk + housing base
    lib.rounded_box(bm, V(s * 0.835, -0.70, 0.975), 0.075, 0.045, 0.040, 0.020)
    # side skirt strip between arches
    lib.rounded_box(bm, V(s * (width(0) - 0.035), 0.0, 0.245), 0.040, 0.80, 0.025, 0.012, seg=1)
for k in range(4):                                                                              # grille slats
    lib.rounded_box(bm, V(0, YF - 0.004, 0.520 + k * 0.018), 0.285, 0.010, 0.0045, 0.003, seg=1)
lib.rounded_box(bm, V(0, YF - 0.095, 0.300), 0.36, 0.010, 0.030, 0.012, seg=2)                 # lower intake
for s_ in (1, -1):
    for ya in AX:                                                                               # wheel-arch lips
        pts = []
        for i in range(25):
            a_ = math.pi * (1 - i / 24)
            y = ya + 0.385 * math.cos(a_)
            z = max(0.23, WR + 0.385 * math.sin(a_) * 0.97 + 0.04)
            pts.append(V(s_ * (side_x(min(max(y, YF + 0.05), YR - 0.05), min(z, 0.62)) + 0.004), y, z))
        bar(bm, pts, 0.014, 0.022, V(s_, 0, 0))
    # side-window frames (black) along the glass edges
    for poly in ([V(s_ * 0.738, -0.775, 0.932), V(s_ * 0.704, -0.530, 1.172), V(s_ * 0.674, -0.275, 1.408),
                  V(s_ * 0.670, 0.070, 1.408), V(s_ * 0.672, 1.020, 1.408), V(s_ * 0.706, 1.240, 1.172),
                  V(s_ * 0.742, 1.440, 0.904)],):
        bar(bm, poly, 0.012, 0.010, V(s_, 0, 0))
    bar(bm, [V(s_ * 0.744, -0.775, 0.930), V(s_ * 0.746, 1.440, 0.902)], 0.012, 0.008, V(s_, 0, 0))   # belt moulding
# wipers resting at the base of the windshield
for x0 in (-0.52, 0.06):
    bar(bm, [V(x0, -0.770, 0.948), V(x0 + 0.46, -0.742, 0.968)], 0.008, 0.006, V(0, -1, 1).normalized())
# exhaust tip under the rear bumper
lib.lathe(bm, [(0.0, -0.06), (0.034, -0.06), (0.036, -0.055), (0.036, 0.060), (0.030, 0.064), (0.024, 0.040), (0.0, 0.040)],
          V(-0.45, YR + 0.03, 0.215), V(0, 1, 0), 16, ref=Z)
ob_trim = lib.bm_to_obj("Car_Trim", bm, coll, M["M_Polymer"], root)

bm = bmesh.new()
for s in (1, -1):
    for y in (-0.28, 0.62):
        x = side_x(y, 0.80)
        lib.rounded_box(bm, V(s * (x + 0.008), y, 0.800), 0.010, 0.055, 0.012, 0.006, seg=1)   # handles
d = [(0.0, 0.035), (0.030, 0.0), (0.0, -0.035), (-0.030, 0.0)]
lib.prism(bm, lib.ccw(d), V(0, YF + 0.002, 0.660), V(1, 0, 0), V(0, 0, 1), V(0, 1, 0), 0.006, 0.002)               # emblem
ob_chrome = lib.bm_to_obj("Car_Chrome", bm, coll, M["M_Chrome"], root)

bm = bmesh.new()
for s in (1, -1):
    lib.rounded_box(bm, V(s * 0.86, -0.705, 0.980), 0.040, 0.050, 0.045, 0.022)                  # mirror caps
ob_mir = lib.bm_to_obj("Car_MirrorCaps", bm, coll, M["M_CarPaint"], root)

bm = bmesh.new()
for s in (1, -1):
    lib.rounded_box(bm, V(s * 0.535, YF + 0.004, 0.665), 0.128, 0.014, 0.052, 0.028, seg=3)          # lens
    lib.rounded_box(bm, V(s * 0.440, YF - 0.240 + 0.100, 0.300), 0.040, 0.012, 0.022, 0.012, seg=2)  # fog lights
ob_hl = lib.bm_to_obj("Car_HeadLights", bm, coll, M["M_HeadLight"], root)
bm = bmesh.new()
for s in (1, -1):
    lib.frame_xz(bm, lib.shift2(lib.round_rect(0.142, 0.066, 0.036, 3), s * 0.535, 0.665),
                 lib.shift2(lib.round_rect(0.126, 0.050, 0.026, 3), s * 0.535, 0.665), YF + 0.020, YF - 0.016, 0.003)
    for k, dx in enumerate((-0.060, 0.045)):                                                         # projector rings
        cx = s * (0.535 + dx * s)
        lib.lathe(bm, [(0.0, 0.0), (0.030 - 0.006 * k, 0.0), (0.034 - 0.006 * k, 0.006), (0.028 - 0.006 * k, 0.012),
                       (0.0, 0.006)], V(cx, YF - 0.008, 0.668), V(0, -1, 0), 20, ref=Z)
ob_hb = lib.bm_to_obj("Car_LightBezels", bm, coll, M["M_Chrome"], root)
bm = bmesh.new()
for s in (1, -1):
    lib.rounded_box(bm, V(s * 0.610, YR - 0.006, 0.800), 0.114, 0.016, 0.054, 0.024, seg=3)
ob_tl = lib.bm_to_obj("Car_TailLights", bm, coll, M["M_TailLight"], root)
bm = bmesh.new()
for s in (1, -1):
    lib.frame_xz(bm, lib.shift2(lib.round_rect(0.126, 0.066, 0.030, 3), s * 0.610, 0.800),
                 lib.shift2(lib.round_rect(0.112, 0.052, 0.022, 3), s * 0.610, 0.800), YR - 0.020, YR + 0.016, 0.003)
    for k in range(3):                                                                               # inner light bars
        lib.rounded_box(bm, V(s * 0.610, YR + 0.012, 0.775 + k * 0.026), 0.090, 0.004, 0.004, 0.002, seg=1)
ob_tb = lib.bm_to_obj("Car_TailBezels", bm, coll, M["M_Polymer"], root)
bm = bmesh.new()
lib.rounded_box(bm, V(0, YF - 0.100, 0.350), 0.180, 0.004, 0.050, 0.006, seg=1)
lib.rounded_box(bm, V(0, YR + 0.100, 0.370), 0.180, 0.004, 0.050, 0.006, seg=1)
ob_pl = lib.bm_to_obj("Car_Plates", bm, coll, M["M_CarWhite"], root)

# ------------------------------------------------------------- interior --
bm = bmesh.new()
car = []
for y in (CAB[0] + 0.01, -0.5, 0.0, 0.25, 0.50, CAB[1] - 0.01):
    zf = zfloor(y) + 0.008
    car.append([V(-0.72, y, zf - 0.01), V(0.72, y, zf - 0.01), V(0.72, y, zf + 0.012), V(-0.72, y, zf + 0.012)])
lib.loft(bm, car, cap0='ngon', cap1='ngon')                                                     # carpet
for s in (1, -1):
    x = s * (width(0) - 0.075 - 0.010)
    lib.prism(bm, lib.ccw(lib.fillet([(CAB[0] + 0.01, 0.46), (CAB[1] - 0.02, 0.62), (CAB[1] - 0.02, 0.92), (CAB[0] + 0.01, 0.92)], 0.02)),
              V(x, 0, 0), V(0, 1, 0), V(0, 0, 1), V(1, 0, 0), 0.010, 0.004)                     # door panels
dash = [(CAB[0] + 0.012, 0.50), (CAB[0] + 0.012, 0.930), (-0.65, 0.990), (-0.54, 0.900), (-0.57, 0.76), (-0.66, 0.55)]
lib.prism(bm, lib.ccw(lib.fillet(dash, [0.0, 0.02, 0.04, 0.05, 0.04, 0.0])), V(0, 0, 0), V(0, 1, 0), V(0, 0, 1), V(1, 0, 0),
          0.715, 0.012)                                                                          # dashboard
lib.rounded_box(bm, V(0.36, -0.65, 1.010), 0.150, 0.060, 0.022, 0.018)                         # instrument hood
lib.rounded_box(bm, V(0.0, -0.25, 0.42), 0.075, 0.30, 0.07, 0.03)                               # centre console
ob_int = lib.bm_to_obj("Car_Interior", bm, coll, M["M_Interior"], root)

bm = bmesh.new()


def rbox_rot(bm, c, hx, hy, hz, r, rx):
    faces = lib.rounded_box(bm, V(0, 0, 0), hx, hy, hz, r)
    vs = {v for f in faces for v in f.verts}
    bmesh.ops.transform(bm, matrix=Matrix.Translation(c) @ Matrix.Rotation(math.radians(rx), 4, 'X'), verts=list(vs))


for s in (1, -1):
    x = s * 0.355
    rbox_rot(bm, V(x, -0.18, 0.455), 0.205, 0.235, 0.060, 0.040, 0)
    rbox_rot(bm, V(x, 0.085, 0.775), 0.205, 0.060, 0.265, 0.045, -12)
    rbox_rot(bm, V(x, 0.135, 1.115), 0.115, 0.050, 0.065, 0.030, -12)
rbox_rot(bm, V(0, 0.495, 0.690), 0.635, 0.190, 0.065, 0.045, 0)
rbox_rot(bm, V(0, 0.500, 0.560), 0.610, 0.170, 0.085, 0.020, 0)                                # bench base
rbox_rot(bm, V(0, 0.700, 0.935), 0.635, 0.060, 0.220, 0.045, -14)
ob_seat = lib.bm_to_obj("Car_Seats", bm, coll, M["M_Seat"], root)

# steering wheel (separate, pivot at its centre)
SW = V(0.36, -0.465, 0.955)
axis = V(0, 1.0, 0.55).normalized()
bm = bmesh.new()
q = axis.to_track_quat('Z', 'Y').to_matrix().to_4x4()
ring = []
NR = 20
for i in range(NR):
    a = TAU * i / NR
    ring.append(SW + (q @ V(math.cos(a), math.sin(a), 0)) * 0.165)
fr = lib.path_frames([ring[-1]] + ring + [ring[0]], up=axis)[1:NR + 1]
lib.loft(bm, [lib.place(lib.ellipse(0.019, 0.019, 8), p, u, v) for p, t, u, v in fr], wrap=True)
for a in (math.radians(90), math.radians(210), math.radians(330)):
    p1 = SW + (q @ V(math.cos(a), math.sin(a), 0)) * 0.155
    bar(bm, [SW, p1], 0.018, 0.008, axis)
lib.lathe(bm, [(0.0, 0.012), (0.045, 0.010), (0.050, -0.010), (0.0, -0.012)], SW, axis, 12)
bar(bm, [SW - axis * 0.01, SW - axis * 0.26], 0.026, 0.026, Z)                                     # column
ob_sw = lib.bm_to_obj("Car_SteeringWheel", bm, coll, M["M_Polymer"], root)

# ---------------------------------------------------------------- wheels --
wheels = []
tire = [(0.200, -0.090), (0.250, -0.097), (0.272, -0.093), (0.284, -0.080), (0.290, -0.058), (0.291, -0.034),
        (0.285, -0.028), (0.285, -0.020), (0.291, -0.014), (0.291, 0.014), (0.285, 0.020), (0.285, 0.028),
        (0.291, 0.034), (0.290, 0.058), (0.284, 0.080), (0.272, 0.093), (0.250, 0.097), (0.200, 0.090)]
barrel = [(0.170, -0.050), (0.196, -0.050), (0.198, 0.040), (0.212, 0.070), (0.214, 0.082), (0.204, 0.086),
          (0.190, 0.074), (0.172, 0.060)]
for tag, sx, ya in (("FL", 1, AX[0]), ("FR", -1, AX[0]), ("RL", 1, AX[1]), ("RR", -1, AX[1])):
    c = V(sx * TRK, ya, WR)
    ax = V(sx, 0, 0)
    bm = bmesh.new()
    NS = 40
    rows = [[bm.verts.new(c + ax * h + (V(0, math.cos(TAU * i / NS), math.sin(TAU * i / NS))) * r) for i in range(NS)] for r, h in tire]
    for k in range(len(rows)):
        a, b2 = rows[k], rows[(k + 1) % len(rows)]
        for i in range(NS):
            j = (i + 1) % NS
            bm.faces.new((a[i], a[j], b2[j], b2[i]))
    ob_t = lib.bm_to_obj(f"Car_Wheel_{tag}", bm, coll, M["M_Rubber"], root)
    bm = bmesh.new()
    rows = [[bm.verts.new(c + ax * h + (V(0, math.cos(TAU * i / 32), math.sin(TAU * i / 32))) * r) for i in range(32)] for r, h in barrel]
    for k in range(len(rows)):
        a, b2 = rows[k], rows[(k + 1) % len(rows)]
        for i in range(32):
            j = (i + 1) % 32
            bm.faces.new((a[i], a[j], b2[j], b2[i]))
    lib.lathe(bm, [(0.0, 0.074), (0.040, 0.074), (0.058, 0.066), (0.062, 0.040), (0.0, 0.040)], c, ax, 24, ref=Z)   # hub face
    u0 = V(0, 0, 1)
    for i in range(6):                                                                                    # spokes
        a = TAU * i / 6
        d = V(0, math.cos(a), math.sin(a)); t = ax.cross(d)
        sp = [(0.050, -0.022), (0.186, -0.030), (0.186, 0.030), (0.050, 0.022)]
        lib.prism(bm, lib.ccw(lib.fillet(sp, 0.008, 2)), c + ax * 0.058, d, t, ax, 0.012, 0.004)
    for i in range(5):                                                                                    # wheel nuts
        a = TAU * (i + 0.5) / 5
        p = c + ax * 0.075 + V(0, math.cos(a), math.sin(a)) * 0.034
        lib.lathe(bm, [(0.0, 0.0), (0.008, 0.0), (0.008, 0.008), (0.0, 0.010)], p, ax, 6, ref=Z)
    ob_r = lib.bm_to_obj(f"Car_Wheel_{tag}_Rim", bm, coll, M["M_CarWhite"], root)
    bm = bmesh.new()
    lib.lathe(bm, [(0.0, 0.088), (0.022, 0.086), (0.028, 0.078), (0.028, 0.072), (0.0, 0.072)], c, ax, 16, ref=Z)
    lib.loft(bm, [[c + ax * h + V(0, math.cos(TAU * i / 32), math.sin(TAU * i / 32)) * r for i in range(32)]
                  for r, h in ((0.060, 0.010), (0.165, 0.010), (0.165, 0.026), (0.060, 0.026))], wrap=True)       # brake disc
    lib.rounded_box(bm, c + ax * 0.018 + V(0, 0.10 * (1 if ya < 0 else -1), 0.10), 0.016, 0.035, 0.045, 0.010, seg=2)  # caliper
    ob_h = lib.bm_to_obj(f"Car_Wheel_{tag}_Hub", bm, coll, M["M_Chrome"], root)
    wheels.append((ob_t, ob_r, ob_h, c))

for o in (ob_body, ob_roof, ob_glass, ob_trim, ob_chrome, ob_mir, ob_hl, ob_hb, ob_tl, ob_tb, ob_pl, ob_int, ob_seat, ob_sw):
    lib.finish(o, sharp=40)
for ob_t, ob_r, ob_h, c in wheels:
    for o in (ob_t, ob_r, ob_h):
        lib.finish(o, sharp=45)
        lib.set_origin(o, c)
lib.set_origin(ob_sw, SW)
bpy.context.view_layer.update()
for ob_t, ob_r, ob_h, c in wheels:
    for ch in (ob_r, ob_h):
        mw = ch.matrix_world.copy(); ch.parent = ob_t; ch.matrix_world = mw

txt, tot = lib.report(coll)
print(txt)
for o in coll.objects:
    if o.type == 'MESH':
        st = lib.check_mesh(o)
        if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
            print("CHECK", o.name, st)
