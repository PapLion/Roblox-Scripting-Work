"""Shop products (original, unbranded designs) -- each one is its own collection so it can
be exported / reused on its own, and the Shelf and Vending Machine place them as
*collection instances*.  Pivot = bottom centre.  Front of every product faces -Y."""
import bpy, bmesh, math
from mathutils import Vector, Matrix
import lib
from lib import V, TAU

M = lib.mats()
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
for _n in ("Product_Can_Orange", "Product_Bottle_Juice", "Product_BoxTall_Blue"):   # variants share mesh data
    if bpy.data.collections.get(_n):
        lib.clear_coll(bpy.data.collections[_n])


def lathe_closed(bm, prof, o=V(), n=16):
    """Closed (r, h) cross-section revolved around Z -> ring/torus-like solid."""
    rings = [[o + V(r * math.cos(TAU * i / n), r * math.sin(TAU * i / n), h) for i in range(n)] for r, h in prof]
    return lib.loft(bm, rings, wrap=True)


def start(name, loc):
    c = lib.get_coll(name)
    lib.clear_coll(c)
    c.instance_offset = loc
    return c, lib.make_root(name, c, loc)


ROW = 10.6
made = []
# ================================================================ can ===
c, root = start("Product_Can", V(0.0, ROW, 0))
bm = bmesh.new()
lib.lathe(bm, [(0.0, 0.0), (0.022, 0.0), (0.0305, 0.005), (0.033, 0.014), (0.033, 0.103), (0.0285, 0.1115),
               (0.0, 0.1135)], V(), Z, 16)
body = lib.bm_to_obj("Product_Can_Body", bm, c, M["M_Prod_Green"], root)
bm = bmesh.new()
lathe_closed(bm, [(0.0262, 0.1110), (0.0283, 0.1190), (0.0282, 0.1212), (0.0250, 0.1160)])
lib.lathe(bm, [(0.0, 0.1150), (0.0254, 0.1150), (0.0254, 0.1166), (0.0, 0.1166)], V(), Z, 16)
lib.prism(bm, [(-0.0055, -0.013), (0.0055, -0.013), (0.0055, 0.005), (-0.0055, 0.005)],
          V(0, -0.003, 0.1173), X, Y, Z, 0.0007, 0.0003)
top = lib.bm_to_obj("Product_Can_Top", bm, c, M["M_Alu"], root)
bm = bmesh.new()
lathe_closed(bm, [(0.0326, 0.040), (0.0337, 0.041), (0.0337, 0.079), (0.0326, 0.080)])
band = lib.bm_to_obj("Product_Can_Label", bm, c, M["M_Label"], root)
made.append((c, (body, top, band)))

# ============================================================= bottle ===
c, root = start("Product_Bottle", V(0.3, ROW, 0))
bm = bmesh.new()
lib.lathe(bm, [(0.0, 0.0), (0.030, 0.0), (0.034, 0.012), (0.034, 0.060), (0.031, 0.070),
               (0.031, 0.080), (0.034, 0.090), (0.034, 0.150), (0.031, 0.166), (0.024, 0.186), (0.017, 0.200), (0.0145, 0.205),
               (0.0145, 0.214), (0.0, 0.214)], V(), Z, 16)
body = lib.bm_to_obj("Product_Bottle_Body", bm, c, M["M_Prod_Blue"], root)
bm = bmesh.new()
lib.lathe(bm, [(0.0, 0.2085), (0.0165, 0.2085), (0.0172, 0.2275), (0.0160, 0.2300), (0.0, 0.2300)],
          V(), Z, 14)
cap = lib.bm_to_obj("Product_Bottle_Cap", bm, c, M["M_CarWhite"], root)
bm = bmesh.new()
lathe_closed(bm, [(0.0333, 0.092), (0.0346, 0.093), (0.0346, 0.146), (0.0333, 0.147)])
band = lib.bm_to_obj("Product_Bottle_Label", bm, c, M["M_Label"], root)
made.append((c, (body, cap, band)))

# ======================================================== tall box =====
c, root = start("Product_BoxTall", V(0.6, ROW, 0))
BW, BD, BH = 0.095, 0.034, 0.270
bm = bmesh.new()
lib.rounded_box(bm, V(0, 0, BH / 2), BW, BD, BH / 2, 0.004, seg=1)
body = lib.bm_to_obj("Product_BoxTall_Body", bm, c, M["M_Prod_Yellow"], root)
bm = bmesh.new()
pan = lib.round_rect(0.074, 0.088, 0.018, 3)
lib.prism(bm, pan, V(0, -BD - 0.0004, 0.150), X, Z, V(0, -1, 0), 0.0008, 0.0004)
lib.prism(bm, lib.round_rect(0.080, 0.012, 0.012, 2), V(0, -BD - 0.0004, 0.034), X, Z, V(0, -1, 0), 0.0008, 0.0004)
panel = lib.bm_to_obj("Product_BoxTall_Panel", bm, c, M["M_Label"], root)
bm = bmesh.new()
lib.prism(bm, lib.ellipse(0.038, 0.038, 20), V(0, -BD - 0.0016, 0.165), X, Z, V(0, -1, 0), 0.0008, 0.0004)
lib.prism(bm, lib.ellipse(0.016, 0.016, 12), V(0.040, -BD - 0.0016, 0.105), X, Z, V(0, -1, 0), 0.0008, 0.0004)
logo = lib.bm_to_obj("Product_BoxTall_Logo", bm, c, M["M_Prod_Pink"], root)
made.append((c, (body, panel, logo)))

# ======================================================= small box =====
c, root = start("Product_BoxSmall", V(0.9, ROW, 0))
SW, SD, SH = 0.070, 0.048, 0.080
bm = bmesh.new()
lib.rounded_box(bm, V(0, 0, SH / 2), SW, SD, SH / 2, 0.005, seg=1)
body = lib.bm_to_obj("Product_BoxSmall_Body", bm, c, M["M_Prod_Purple"], root)
bm = bmesh.new()
rr_o = lib.round_rect(SW + 0.0010, SD + 0.0010, 0.006, 1)
rr_i = lib.round_rect(SW - 0.0010, SD - 0.0010, 0.004, 1)
z0, z1 = 0.050, 0.064
lib.loft(bm, [lib.place(rr_i, V(0, 0, z0), X, Y), lib.place(rr_o, V(0, 0, z0), X, Y),
              lib.place(rr_o, V(0, 0, z1), X, Y), lib.place(rr_i, V(0, 0, z1), X, Y)], wrap=True)
band = lib.bm_to_obj("Product_BoxSmall_Band", bm, c, M["M_Prod_Yellow"], root)
made.append((c, (body, band)))

for c, obs in made:
    for o in obs:
        lib.finish(o, sharp=40)


def variant(src, new, loc, overrides):
    """Colour variant that REUSES the mesh data of 'src' (linked duplicates) with an
    object-level material override -> same geometry, different label colour."""
    c = lib.get_coll(new)
    lib.clear_coll(c)
    c.instance_offset = loc
    r = lib.make_root(new, c, loc)
    for o in bpy.data.collections[src].objects:
        if o.type != 'MESH':
            continue
        d = bpy.data.objects.new(o.name.replace(src, new), o.data)
        c.objects.link(d)
        d.parent = r
        d.matrix_parent_inverse = Matrix.Identity(4)
        d.location = o.location
        for suf, mat in overrides.items():
            if o.name.endswith(suf):
                d.material_slots[0].link = 'OBJECT'
                d.material_slots[0].material = M[mat]
    return c


made_v = [variant("Product_Can", "Product_Can_Orange", V(0.0, ROW + 0.4, 0), {"_Body": "M_Paint_Orange"}),
          variant("Product_Bottle", "Product_Bottle_Juice", V(0.3, ROW + 0.4, 0), {"_Body": "M_Prod_Yellow", "_Cap": "M_Prod_Green"}),
          variant("Product_BoxTall", "Product_BoxTall_Blue", V(0.6, ROW + 0.4, 0), {"_Body": "M_Prod_Blue", "_Logo": "M_Prod_Yellow"})]
for c, obs in made:
    txt, tot = lib.report(c)
    print(txt)
    for o in obs:
        st = lib.check_mesh(o)
        if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
            print("CHECK", o.name, st)
