"""Vending machine (original design, fictional brand 'QUENCHO').
Pivot = bottom centre of the BACK face (snap against a wall).  Front faces -Y.
Separate parts: cabinet, door frame, side panel, glass, flap (pickup tray, pivot = top
hinge), trim, metal (buttons / coin / return cup), glow (header lettering, display,
light strip).  Stock = collection instances of the shop products (no hidden mechanism)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler
import lib
from lib import V, TAU

NAME = "VendingMachine"
LOC = V(0.0, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
HW = 0.475                    # half width
CAB_F, BACK = -0.660, -0.010  # cabinet front / back planes
DOOR_F = -0.765               # door front plane
WIN = (-0.405, 0.155, 0.600, 1.580)   # window x0, x1, z0, z1
P_X0, P_X1 = 0.205, 0.445            # right-hand control panel


def rr_xz(x0, x1, z0, z1, r, seg=3):
    return lib.shift2(lib.round_rect((x1 - x0) / 2, (z1 - z0) / 2, r, seg), (x0 + x1) / 2, (z0 + z1) / 2)


def disc(bm, cx, cz, r, y_back, y_front, n=24, ch=0.0008):
    lib.plate_xz(bm, lib.shift2(lib.ellipse(r, r, n), cx, cz), y_back, y_front, ch)


# ============================================================== cabinet ===
bm = bmesh.new()
lib.rounded_box(bm, V(0, (CAB_F + BACK) / 2, 0.945), HW, (BACK - CAB_F) / 2, 0.905, 0.035, seg=3)
cab = lib.bm_to_obj("VendingMachine_Cabinet", bm, coll, M["M_Vend_Red"], root)

# ======================================================== door (left) =====
bm = bmesh.new()
outer = rr_xz(-0.445, 0.195, 0.115, 1.615, 0.030)
inner = rr_xz(*WIN, 0.020)
lib.frame_xz(bm, outer, inner, CAB_F + 0.006, DOOR_F, ch=0.006)
door = lib.bm_to_obj("VendingMachine_Door", bm, coll, M["M_Vend_Red"], root)

# ===================================================== control panel =====
bm = bmesh.new()
lib.rounded_box(bm, V((P_X0 + P_X1) / 2, (CAB_F + 0.006 + DOOR_F - 0.008) / 2, 0.865), (P_X1 - P_X0) / 2,
                (CAB_F + 0.006 - DOOR_F + 0.008) / 2, 0.750, 0.014, seg=2)
panel = lib.bm_to_obj("VendingMachine_Panel", bm, coll, M["M_Vend_Red"], root)
PF = DOOR_F - 0.008           # panel front plane
PCX = (P_X0 + P_X1) / 2

# ============================================================ interior ====
bm = bmesh.new()
lib.plate_xz(bm, rr_xz(WIN[0] - 0.01, WIN[1] + 0.01, WIN[2] - 0.01, WIN[3] + 0.01, 0.01, 1), CAB_F - 0.002, CAB_F - 0.008)
interior = lib.bm_to_obj("VendingMachine_Interior", bm, coll, M["M_Vend_Inner"], root)

# ================================================================ glass ===
bm = bmesh.new()
GY = DOOR_F + 0.022
lib.plate_xz(bm, rr_xz(WIN[0] - 0.006, WIN[1] + 0.006, WIN[2] - 0.006, WIN[3] + 0.006, 0.02, 2), GY + 0.003, GY - 0.003, 0.0012)
glass = lib.bm_to_obj("VendingMachine_Glass", bm, coll, M["M_GlassClear"], root)

# ======================================================= trim (dark) =====
bm = bmesh.new()
# header box
lib.rounded_box(bm, V(0, (CAB_F + 0.01 + DOOR_F - 0.014) / 2, 1.725), 0.448, (CAB_F + 0.01 - DOOR_F + 0.014) / 2, 0.093,
                0.018, seg=3)
# kick plate + feet
lib.rounded_box(bm, V(0, -0.705, 0.078), 0.455, 0.048, 0.034, 0.010, seg=2)
for sx in (-1, 1):
    for y in (CAB_F + 0.06, BACK - 0.06):
        lib.lathe(bm, [(0.0, 0.0), (0.026, 0.0), (0.030, 0.006), (0.030, 0.016), (0.018, 0.022), (0.018, 0.046),
                       (0.0, 0.046)], V(sx * (HW - 0.06), y, 0.0), Z, 16)
# shelves (trays with a front lip)
ROWS = [0.615, 0.765, 0.915, 1.065, 1.315]
for z in ROWS:
    lib.rounded_box(bm, V((WIN[0] + WIN[1]) / 2, (CAB_F + GY) / 2 - 0.002, z - 0.006),
                    (WIN[1] - WIN[0]) / 2 + 0.004, (GY - CAB_F) / -2 - 0.006, 0.006, 0.003, seg=1)
    lib.rounded_box(bm, V((WIN[0] + WIN[1]) / 2, GY + 0.016, z + 0.004), (WIN[1] - WIN[0]) / 2 + 0.004, 0.004, 0.016,
                    0.003, seg=1)
# pickup bay surround (flap sits inside)
FL = (-0.385, 0.135, 0.205, 0.445)
lib.frame_xz(bm, rr_xz(FL[0] - 0.025, FL[1] + 0.025, FL[2] - 0.025, FL[3] + 0.025, 0.030),
             rr_xz(*FL, 0.012), DOOR_F + 0.004, DOOR_F - 0.017, ch=0.004)
lib.plate_xz(bm, rr_xz(FL[0] + 0.002, FL[1] - 0.002, FL[2] + 0.002, FL[3] - 0.002, 0.012), DOOR_F + 0.002, DOOR_F - 0.002)  # dark bay
# display bezel, card reader, coin slot bar
lib.plate_xz(bm, rr_xz(P_X0 + 0.025, P_X1 - 0.025, 1.245, 1.325, 0.012), PF + 0.002, PF - 0.006, 0.002)
lib.rounded_box(bm, V(PCX, PF - 0.020, 0.690), 0.058, 0.022, 0.045, 0.010, seg=2)
lib.rounded_box(bm, V(PCX, PF - 0.044, 0.700), 0.040, 0.0035, 0.0035, 0.0015, seg=1)   # card slot lip
for sx in (-1, 1):            # dark vertical stripe on both sides, next to the door
    pts = [(-0.640, 0.12), (-0.585, 0.12), (-0.585, 1.62), (-0.640, 1.62)]
    u = V(0, 1, 0) if sx > 0 else V(0, -1, 0)
    lib.prism(bm, lib.ccw([(p[0] * (1 if sx > 0 else -1), p[1]) for p in pts]),
              V(sx * (HW + 0.0012), 0, 0), u, Z, V(sx, 0, 0), 0.0015, 0.0)
# rear service panel with ventilation slots (back view)
lib.frame_xz(bm, rr_xz(-0.30, 0.30, 0.16, 0.62, 0.025), rr_xz(-0.27, 0.27, 0.19, 0.59, 0.012),
             BACK - 0.004, BACK + 0.005, ch=0.002)
for i in range(8):
    z = 0.215 + i * 0.049
    lib.rounded_box(bm, V(0, BACK + 0.0005, z), 0.262, 0.004, 0.011, 0.003, seg=1)
trim = lib.bm_to_obj("VendingMachine_Trim", bm, coll, M["M_Vend_Dark"], root)

# ============================================================== flap ======
bm = bmesh.new()
FLY = DOOR_F - 0.003
lib.plate_xz(bm, rr_xz(FL[0] + 0.006, FL[1] - 0.006, FL[2] + 0.006, FL[3] - 0.006, 0.010), FLY, FLY - 0.009, 0.002)
lib.rounded_box(bm, V((FL[0] + FL[1]) / 2, FLY - 0.012, FL[2] + 0.050), 0.13, 0.005, 0.012, 0.004, seg=2)  # push lip
flap = lib.bm_to_obj("VendingMachine_Flap", bm, coll, M["M_Polymer"], root)

# ============================================================== metal =====
bm = bmesh.new()
for r in range(4):
    for c in range(3):
        bx = PCX + (c - 1) * 0.062
        bz = 1.185 - r * 0.050
        lib.rounded_box(bm, V(bx, PF - 0.006, bz), 0.024, 0.008, 0.017, 0.006, seg=1)
# coin plate with return lever, return cup
lib.plate_xz(bm, rr_xz(PCX - 0.058, PCX + 0.058, 0.780, 0.910, 0.014), PF + 0.002, PF - 0.008, 0.002)
lib.rounded_box(bm, V(PCX, PF - 0.024, 0.345), 0.072, 0.024, 0.055, 0.016, seg=3)
metal = lib.bm_to_obj("VendingMachine_Metal", bm, coll, M["M_Alu"], root)

# coin slot + return cup opening (dark, on top of the metal plates)
bm = bmesh.new()
lib.plate_xz(bm, rr_xz(PCX - 0.006, PCX + 0.006, 0.835, 0.885, 0.005, 2), PF - 0.007, PF - 0.011, 0.001)
lib.plate_xz(bm, rr_xz(PCX + 0.022, PCX + 0.044, 0.800, 0.822, 0.010, 2), PF - 0.007, PF - 0.011, 0.001)
lib.plate_xz(bm, rr_xz(PCX - 0.052, PCX + 0.052, 0.310, 0.385, 0.014, 3), PF - 0.047, PF - 0.0495, 0.001)
slots = lib.bm_to_obj("VendingMachine_Slots", bm, coll, M["M_Vend_Dark"], root)
# ================================================================ glow ====
bm = bmesh.new()
lib.text_bm(bm, "QUENCHO", 0.150, V(0.0, DOOR_F - 0.0175, 1.722), X, Z, extrude=0.004, font_res=3)
lib.plate_xz(bm, rr_xz(P_X0 + 0.035, P_X1 - 0.035, 1.258, 1.312, 0.006, 2), PF - 0.004, PF - 0.008, 0.001)  # display
lib.rounded_box(bm, V((WIN[0] + WIN[1]) / 2, (CAB_F + GY) / 2, WIN[3] - 0.010), (WIN[1] - WIN[0]) / 2 - 0.01,
                0.010, 0.005, 0.004, seg=1)                                                         # light strip
glow = lib.bm_to_obj("VendingMachine_Glow", bm, coll, M["M_LampGlow"], root)

# ========================================================== graphics ======
bm = bmesh.new()
# brand mark on the panel: white disc + 3 bubbles
disc(bm, PCX, 1.470, 0.078, PF + 0.002, PF - 0.004, n=32)
# side decals: rising bubbles (both sides)
# rising bubble trail: big at the bottom-back, small near the top-front
BUB = [(-0.150, 0.300, 0.105), (-0.215, 0.560, 0.082), (-0.330, 0.770, 0.066), (-0.440, 0.950, 0.052),
       (-0.505, 1.110, 0.041), (-0.520, 1.250, 0.032), (-0.490, 1.365, 0.025), (-0.430, 1.455, 0.019)]
for sx in (-1, 1):
    for y, z, r in BUB:
        n = 28 if r > 0.07 else 20
        pts = [(y + r * math.cos(TAU * i / n), z + r * math.sin(TAU * i / n)) for i in range(n)]
        u = V(0, 1, 0) if sx > 0 else V(0, -1, 0)
        lib.prism(bm, lib.ccw([(p[0] * (1 if sx > 0 else -1), p[1]) for p in pts]),
                  V(sx * (HW + 0.0012), 0, 0), u, Z, V(sx, 0, 0), 0.0015, 0.0)
graphics = lib.bm_to_obj("VendingMachine_Graphics", bm, coll, M["M_Label"], root)
bm = bmesh.new()
for bx, bz, r in ((PCX - 0.022, 1.455, 0.030), (PCX + 0.030, 1.497, 0.018), (PCX + 0.020, 1.438, 0.011)):
    disc(bm, bx, bz, r, PF - 0.003, PF - 0.007, n=20, ch=0.0)
logo = lib.bm_to_obj("VendingMachine_Logo", bm, coll, M["M_Vend_Red"], root)

parts = (cab, door, panel, interior, glass, trim, flap, metal, slots, glow, graphics, logo)
for o in parts:
    lib.finish(o, sharp=40)
lib.set_origin(flap, V(0, FLY, FL[3] - 0.004))

# ============================================================ stock =======
STOCK = ["Product_Can", "Product_Can_Orange", "Product_Can", "Product_Bottle", "Product_Bottle_Juice"]
TINTS = None
for r, (z, pname) in enumerate(zip(ROWS, STOCK)):
    for c in range(5):
        x = (WIN[0] + WIN[1]) / 2 + (c - 2) * 0.108
        e = bpy.data.objects.new(f"VendingMachine_Stock_{r}{c}", None)
        coll.objects.link(e)
        e.instance_type = 'COLLECTION'
        e.instance_collection = bpy.data.collections[pname]
        e.empty_display_size = 0.03
        e.parent = root
        e.location = V(x, (CAB_F + GY) / 2 - 0.004, z)
        e.rotation_euler = (0, 0, math.radians(-20 + 37 * ((c * 3 + r) % 5)))

txt, tot = lib.report(coll)
print(txt)
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
