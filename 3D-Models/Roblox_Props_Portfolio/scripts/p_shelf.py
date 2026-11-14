"""Modular shop shelf (gondola wall bay, original design).
Pivot = bottom centre of the BACK (snap against a wall).  Front faces -Y.
Modular parts: uprights (+ slot inserts), back panel, base plinth, 4 removable shelf
boards (Shelf_Board_1..4, each with its own brackets, origin at its back edge so it can
be re-hung at another height), price strips + tags, header sign.
Stock = collection instances of the Product_* collections (reused, never duplicated)."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
import lib
from lib import V, lerp, TAU

NAME = "Shelf"
LOC = V(8.6, 9.0, 0)
M = lib.mats()
coll = lib.get_coll(NAME)
lib.clear_coll(coll)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
HW, H = 0.500, 1.850
UX = HW - 0.026                         # upright centre x
DEPTH = 0.420                           # shelf board depth (from the back panel)
BACKY = -0.034                          # front face of the back panel
LEVELS = [0.500, 0.860, 1.180, 1.500]   # board top heights (deck is part of the base)

# ============================================================== uprights ==
bm = bmesh.new()
for sx in (-1, 1):
    lib.rounded_box(bm, V(sx * UX, -0.032, H / 2), 0.025, 0.022, H / 2, 0.004, seg=2)
    lib.rounded_box(bm, V(sx * UX, -0.032, 0.008), 0.034, 0.030, 0.008, 0.004, seg=1)       # levelling foot
upr = lib.bm_to_obj("Shelf_Uprights", bm, coll, M["M_SteelDark"], root)
bm = bmesh.new()
for sx in (-1, 1):
    for i in range(52):
        z = 0.15 + i * 0.032
        lib.plate_xz(bm, lib.shift2([(0.0055, -0.011), (0.0055, 0.011), (-0.0055, 0.011), (-0.0055, -0.011)], sx * UX, z), -0.0535, -0.0555, 0.0)
slots = lib.bm_to_obj("Shelf_UprightSlots", bm, coll, M["M_Vend_Dark"], root)

# ============================================================ back panel ==
bm = bmesh.new()
for z0, z1 in ((0.130, 0.700), (0.706, 1.276), (1.282, 1.800)):      # three panels with fine seams
    lib.plate_xz(bm, lib.shift2(lib.round_rect(UX - 0.026, (z1 - z0) / 2, 0.004, 1), 0, (z0 + z1) / 2), -0.012, BACKY, 0.0015)
back = lib.bm_to_obj("Shelf_BackPanel", bm, coll, M["M_Shelf_White"], root)

# ================================================================== base ==
bm = bmesh.new()
lib.rounded_box(bm, V(0, BACKY - (DEPTH + 0.03) / 2, 0.070), UX - 0.026, (DEPTH + 0.03) / 2, 0.060, 0.006, seg=2)  # deck
base = lib.bm_to_obj("Shelf_Base", bm, coll, M["M_Shelf_White"], root)
bm = bmesh.new()
KY = BACKY - DEPTH - 0.030
lib.rounded_box(bm, V(0, KY - 0.004, 0.064), UX - 0.020, 0.008, 0.056, 0.006, seg=2)   # kick plate
kick = lib.bm_to_obj("Shelf_KickPlate", bm, coll, M["M_Vend_Dark"], root)

# ================================================================ boards ==
boards = []
strips = bmesh.new()
tags = bmesh.new()
FRONT = BACKY - DEPTH
for i, zt in enumerate(LEVELS):
    bm = bmesh.new()
    # profile in (y, z): top deck with a folded, rounded front lip
    prof = [(BACKY - 0.002, zt), (FRONT + 0.008, zt), (FRONT + 0.001, zt - 0.003), (FRONT - 0.002, zt - 0.012),
            (FRONT - 0.002, zt - 0.040), (FRONT + 0.004, zt - 0.046), (FRONT + 0.016, zt - 0.046), (FRONT + 0.016, zt - 0.014),
            (BACKY - 0.002, zt - 0.014)]
    sec = [(y, z) for y, z in prof]
    hw = UX - 0.030
    lib.loft(bm, [[V(x, y, z) for y, z in sec] for x in (-hw, hw)], cap0='ngon', cap1='ngon')
    for sx in (-1, 1):            # bracket arms hooking into the uprights
        out = lib.fillet([(BACKY + 0.020, zt - 0.014), (BACKY - 0.30, zt - 0.014), (BACKY + 0.004, zt - 0.150),
                          (BACKY + 0.020, zt - 0.150)], [0.003, 0.02, 0.02, 0.003], 3)
        lib.prism(bm, lib.ccw([(y, z) for y, z in out]), V(sx * (UX - 0.032), 0, 0), Y, Z, X, 0.004, 0.0012)
    b = lib.bm_to_obj(f"Shelf_Board_{i + 1}", bm, coll, M["M_Shelf_White"], root)
    boards.append(b)
    # price strip clipped on the lip
    lib.plate_xz(strips, lib.shift2(lib.round_rect(hw - 0.004, 0.0135, 0.004, 1), 0, zt - 0.026), FRONT - 0.001, FRONT - 0.005, 0.001)
    for k in range(5):
        x = -0.38 + k * 0.19
        lib.plate_xz(tags, lib.shift2(lib.round_rect(0.032, 0.010, 0.002, 1), x, zt - 0.026), FRONT - 0.004, FRONT - 0.0065, 0.0005)
strip = lib.bm_to_obj("Shelf_PriceStrips", strips, coll, M["M_Shelf_Accent"], root)
tag = lib.bm_to_obj("Shelf_PriceTags", tags, coll, M["M_Label"], root)

# ================================================================ header ==
bm = bmesh.new()
lib.rounded_box(bm, V(0, -0.060, H + 0.075), HW - 0.004, 0.012, 0.075, 0.010, seg=3)
lib.rounded_box(bm, V(0, -0.040, H + 0.004), 0.30, 0.010, 0.010, 0.004, seg=1)          # mounting bar
header = lib.bm_to_obj("Shelf_Header", bm, coll, M["M_Shelf_Accent"], root)
bm = bmesh.new()
lib.text_bm(bm, "DAILY GOODS", 0.070, V(0, -0.0735, H + 0.075), X, Z, extrude=0.0015, font_res=3)
htxt = lib.bm_to_obj("Shelf_HeaderText", bm, coll, M["M_Label"], root)

parts = [upr, slots, back, base, kick, strip, tag, header, htxt] + boards
for o in parts:
    lib.finish(o, sharp=40)
for b, zt in zip(boards, LEVELS):
    lib.set_origin(b, V(0, BACKY, zt))      # re-hang height = origin z

# ================================================================= stock ==
STOCK = []                     # (collection, x, y, z, rot_deg)
deck = 0.130
for k, x in enumerate((-0.33, -0.11, 0.11, 0.33)):              # deck: tall boxes, 2 colours
    STOCK.append(("Product_BoxTall" if k % 2 == 0 else "Product_BoxTall_Blue", x, -0.40, deck, 0))
    if k != 2:
        STOCK.append(("Product_BoxTall_Blue" if k % 2 == 0 else "Product_BoxTall", x, -0.31, deck, 0))
for k in range(8):                                               # level 1: bottles, two deep
    x = -0.385 + k * 0.110
    for j, y in enumerate((-0.385, -0.300)):
        if (k, j) in ((5, 0),):
            continue                                             # one sold-out spot
        STOCK.append(("Product_Bottle" if k < 4 else "Product_Bottle_Juice", x, y, LEVELS[0], 25 * k + 40 * j))
for k in range(12):                                              # level 2: cans, stacked two high
    x = -0.407 + k * 0.074
    for h in range(2 if k not in (9,) else 1):
        STOCK.append(("Product_Can" if (k // 3) % 2 == 0 else "Product_Can_Orange", x, -0.395, LEVELS[1] + h * 0.1215,
                      30 * k + 60 * h))
for k in range(6):                                               # level 3: snack boxes, stacked
    x = -0.375 + k * 0.150
    for h in range(2 if k % 3 != 1 else 1):
        STOCK.append(("Product_BoxSmall", x, -0.385, LEVELS[2] + h * 0.080, (-4 + 6 * h) if k % 2 else 3))
for k, x in enumerate((-0.30, -0.10, 0.10, 0.30)):              # level 4: tall boxes
    if k == 3:
        continue
    STOCK.append(("Product_BoxTall_Blue" if k % 2 == 0 else "Product_BoxTall", x, -0.36, LEVELS[3], 0))
for n, (cname, x, y, z, rz) in enumerate(STOCK):
    e = bpy.data.objects.new(f"Shelf_Stock_{n:02d}", None)
    coll.objects.link(e)
    e.instance_type = 'COLLECTION'
    e.instance_collection = bpy.data.collections[cname]
    e.empty_display_size = 0.03
    e.parent = root
    e.location = V(x, y, z)
    e.rotation_euler = (0, 0, math.radians(rz))

txt, tot = lib.report(coll)
print(txt, "stock instances:", len(STOCK))
for o in parts:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
