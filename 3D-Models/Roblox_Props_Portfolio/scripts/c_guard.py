"""Town guard (v2) built on Roblox's OFFICIAL blocky R15 character
(BlockyCharacter.fbx from create.roblox.com character-body reference files: R15 armature
with 51 bones incl. dynamic-head FACS bones, 15 skinned body parts, dynamic head + face
texture).  The body is kept as-is (scaled 1 stud = 0.28 m, feet on the ground, facing -Y);
the outfit is original: gambeson colours, steel kettle helmet with plume, breastplate with
emblem, pauldrons, belt + buckle + pouch, bracers, boot cuffs, short cape, scarf.
Every outfit piece is a separate mesh rigidly skinned (weight 1.0) to its R15 bone, so the
whole character deforms with the official rig.  Attachment markers and layered-clothing
cages of the template are not included."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix
import lib
from lib import V, lerp, TAU

NAME = "Guard"
LOC = V(0.0, 2.6, 0)
U = 0.28                                   # metres per stud
SRC = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/reference/roblox_official/BlockyCharacter.fbx"
TEX_DIR = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/textures"
M = lib.mats()
coll = lib.get_coll(NAME)
for o in list(coll.objects):
    if o.type == 'ARMATURE':
        d = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.armatures.remove(d)
lib.clear_coll(coll)
for o in [o for o in bpy.data.objects if o.name.startswith("Guard_") or o.name.endswith("_Geo")]:
    if o.type == 'ARMATURE':
        d = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.armatures.remove(d)
    else:
        bpy.data.objects.remove(o, do_unlink=True)
coll.instance_offset = LOC
root = lib.make_root(NAME, coll, LOC)
X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)

# ------------------------------------------------------- import template --
vl = bpy.context.view_layer
def find_lc(lc, name):
    if lc.collection.name == name:
        return lc
    for c in lc.children:
        r = find_lc(c, name)
        if r:
            return r
vl.active_layer_collection = find_lc(vl.layer_collection, NAME)
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=SRC)
new = [o for o in bpy.data.objects if o not in before]
for o in new:
    if o.name.endswith("_Att") or "Cage" in o.name:
        bpy.data.objects.remove(o, do_unlink=True)
new = [o for o in bpy.data.objects if o not in before]
arm = next(o for o in new if o.type == 'ARMATURE')
arm.name = arm.data.name = "Guard_Rig"
for o in new:                              # the template ships a baked action that would override the transform
    if o.animation_data:
        act = o.animation_data.action
        o.animation_data_clear()
        if act and act.users == 0:
            bpy.data.actions.remove(act)
for pb in arm.pose.bones:
    pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.scale = (1, 1, 1)
arm.scale = (U, U, U)
bpy.context.view_layer.update()
foot = min((o.matrix_world @ v.co).z for o in new if o.type == 'MESH' for v in o.data.vertices)
arm.location = LOC + V(0, 0, -foot)
bpy.context.view_layer.update()
mw = arm.matrix_world.copy(); arm.parent = root; arm.matrix_world = mw
arm.data.display_type = 'STICK'
arm.show_in_front = False
body = {}
for o in new:
    if o.type == 'MESH':
        o.name = o.data.name = "Guard_" + o.name.replace("_Geo", "")
        body[o.name[6:]] = o


def bb(part):
    o = body[part]
    pts = [o.matrix_world @ v.co - LOC for v in o.data.vertices]
    mn = V(min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))
    mx = V(max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))
    return mn, mx


# ---------------------------------------------------------- body colours --
COL = {"UpperTorso": "M_Cloth_Blue", "LowerTorso": "M_Cloth_Gray", "LeftUpperArm": "M_Cloth_Blue",
       "RightUpperArm": "M_Cloth_Blue", "LeftLowerArm": "M_Cloth_Blue", "RightLowerArm": "M_Cloth_Blue",
       "LeftHand": "M_Leather", "RightHand": "M_Leather", "LeftUpperLeg": "M_Cloth_Gray", "RightUpperLeg": "M_Cloth_Gray",
       "LeftLowerLeg": "M_Cloth_Gray", "RightLowerLeg": "M_Cloth_Gray", "LeftFoot": "M_Leather", "RightFoot": "M_Leather"}
for k, mat in COL.items():
    body[k].data.materials.clear(); body[k].data.materials.append(M[mat])
# head keeps the official face texture, tinted to the guard's skin tone
body["Head"].data.materials.clear(); body["Head"].data.materials.append(M["M_Skin"])


# -------------------------------------------------------- outfit helpers --
def rig_piece(name, bm, mat, bone, sharp=45):
    ob = lib.bm_to_obj(f"Guard_{name}", bm, coll, M[mat], None)
    ob.location = LOC
    lib.finish(ob, sharp=sharp)
    ob.parent = arm
    ob.matrix_parent_inverse = arm.matrix_world.inverted()
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    md = ob.modifiers.new("Armature", 'ARMATURE')
    md.object = arm
    return ob


def shell_ring(cx, cy, hx, hy, r, z, seg=3):
    return lib.place(lib.round_rect(hx, hy, r, seg), V(cx, cy, z), X, Y)


tmn, tmx = bb("UpperTorso")
lmn, lmx = bb("LowerTorso")
hmn, hmx = bb("Head")
TH = tmx.z - tmn.z
pieces = []

# breastplate: rounded shell over the chest, front bulge + central ridge
bm = bmesh.new()
z0, z1 = tmn.z + TH * 0.34, tmx.z - 0.010
rings = []
for t, k, fy in ((0.0, 0.96, 0.000), (0.04, 1.00, 0.004), (0.35, 1.02, 0.014), (0.7, 1.02, 0.012), (0.93, 0.99, 0.006),
                 (1.0, 0.93, 0.0)):
    z = lerp(z0, z1, t)
    rings.append([V(p.x, p.y - fy * (1 if p.y < 0 else 0), p.z) for p in
                  shell_ring(0, 0, (tmx.x + 0.018) * k, (tmx.y + 0.020) * k, 0.040, z)])
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
lib.prism(bm, lib.ccw([(-0.010, z0 + 0.02), (0.010, z0 + 0.02), (0.006, z1 - 0.02), (-0.006, z1 - 0.02)]),
          V(0, tmn.y - 0.030, 0), X, Z, V(0, 1, 0), 0.006, 0.002)
pieces.append(rig_piece("Breastplate", bm, "M_Steel", "UpperTorso"))
# emblem on the breastplate (teal diamond with a gold rim)
bm = bmesh.new()
ez = lerp(z0, z1, 0.55)
dia = [(0.0, -0.060), (0.045, 0.0), (0.0, 0.060), (-0.045, 0.0)]
lib.prism(bm, lib.ccw(lib.fillet(dia, 0.008, 2)), V(0, tmn.y - 0.0395, ez), X, Z, V(0, 1, 0), 0.004, 0.0015)
pieces.append(rig_piece("Emblem", bm, "M_Paint_Teal", "UpperTorso"))
bm = bmesh.new()
outer = lib.ccw(lib.fillet([(0.0, -0.074), (0.056, 0.0), (0.0, 0.074), (-0.056, 0.0)], 0.010, 2))
inner = lib.ccw(lib.fillet(dia, 0.008, 2))
lib.frame_xz(bm, [(x, ez + z) for x, z in outer], [(x, ez + z) for x, z in inner], tmn.y - 0.032, tmn.y - 0.042, 0.0015)
for dx in (-0.20, 0.20):
    for dz in (z0 + 0.035, z1 - 0.035):
        lib.dome_rivet(bm, V(dx, tmn.y - 0.036, dz), V(0, -1, 0), 0.010, 0.006, n=10)
pieces.append(rig_piece("Trim", bm, "M_Brass", "UpperTorso"))

# scarf around the neck (red), knot at the front
bm = bmesh.new()
nz = tmx.z + 0.004
rings = [shell_ring(0, 0, hx, hy, 0.05, z) for hx, hy, z in ((0.150, 0.110, nz - 0.020), (0.175, 0.135, nz - 0.010),
                                                           (0.180, 0.140, nz + 0.020), (0.160, 0.125, nz + 0.034),
                                                           (0.130, 0.100, nz + 0.030))]
lib.loft(bm, rings, cap0='ngon', cap1='ngon')
lib.rounded_box(bm, V(0.05, -0.150, nz - 0.010), 0.030, 0.020, 0.026, 0.014, seg=2)
for sx, ang in ((0.035, -0.20), (0.075, 0.35)):
    pts = [V(0.05 + sx * 0.3, -0.155, nz - 0.03), V(0.05 + sx, -0.165, nz - 0.10), V(0.05 + sx * 1.4, -0.160, nz - 0.17)]
    fr = lib.path_frames(lib.chaikin(pts, 2), up=Y)
    lib.loft(bm, [lib.place(lib.round_rect(0.024 * (1 - 0.3 * k / 8), 0.006, 0.004, 1), p, u, v)
                  for k, (p, t, u, v) in enumerate(fr)], cap0='ngon', cap1='ngon')
pieces.append(rig_piece("Scarf", bm, "M_Paint_Red", "UpperTorso"))

# short cape on the back
bm = bmesh.new()
rows = []
for k in range(7):
    t = k / 6
    z = lerp(tmx.z - 0.005, tmn.z + 0.02, t)
    w = lerp(0.24, 0.30, t)
    out = 0.012 + 0.03 * t
    pts_o, pts_i = [], []
    for i in range(11):
        s = lerp(-1, 1, i / 10)
        wave = 0.010 * math.sin(i * 1.7 + t * 2) * t
        y = tmx.y + out + 0.035 * (1 - s * s) * (0.3 + t) + wave
        pts_o.append(V(s * w, y + 0.010, z))
        pts_i.append(V(s * w, y, z))
    rows.append(pts_o + list(reversed(pts_i)))
lib.loft(bm, rows, cap0='ngon', cap1='ngon')
pieces.append(rig_piece("Cape", bm, "M_Paint_Red", "UpperTorso"))

# belt + buckle + pouch
bm = bmesh.new()
bz0, bz1 = lmn.z + 0.010, lmn.z + 0.075
lib.loft(bm, [shell_ring(0, 0, lmx.x + d, lmx.y + d, 0.02 + d, z) for d, z in ((0.004, bz0), (0.014, bz0 + 0.008),
                                                                              (0.014, bz1 - 0.008), (0.004, bz1))],
         wrap=False, cap0='ngon', cap1='ngon')
lib.rounded_box(bm, V(0.17, lmn.y - 0.045, bz0 - 0.03), 0.055, 0.035, 0.050, 0.015, seg=2)        # pouch
pieces.append(rig_piece("Belt", bm, "M_Leather", "LowerTorso"))
bm = bmesh.new()
lib.frame_xz(bm, lib.shift2(lib.round_rect(0.045, 0.040, 0.012, 2), 0, (bz0 + bz1) / 2),
             lib.shift2(lib.round_rect(0.028, 0.024, 0.006, 2), 0, (bz0 + bz1) / 2), lmn.y - 0.012, lmn.y - 0.024, 0.002)
lib.dome_rivet(bm, V(0.17, lmn.y - 0.081, bz0 - 0.010), V(0, -1, 0), 0.012, 0.006, n=12)
pieces.append(rig_piece("Buckle", bm, "M_Brass", "LowerTorso"))

# pauldrons: layered steel plates over each shoulder + brass rivets
for side, sx in (("Left", 1), ("Right", -1)):
    amn, amx = bb(f"{side}UpperArm")
    cx = (amn.x + amx.x) / 2
    top = amx.z
    bm = bmesh.new()
    for layer, (dz, sc) in enumerate(((0.0, 1.0), (-0.055, 0.96))):
        rows = []
        for k in range(9):
            a = math.radians(lerp(-62, 92, k / 8))            # from inner shoulder over the top to the outer side
            rr = 0.165 * sc
            cxx = cx - sx * 0.02
            pts = []
            for j in range(9):
                yy = lerp(-0.165, 0.165, j / 8) * sc
                bulge = 0.02 * (1 - (2 * j / 8 - 1) ** 2)
                pts.append(V(cxx + sx * (rr + bulge) * math.sin(a), yy, top + dz - 0.06 + (rr + bulge) * math.cos(a) * 0.62))
            rows.append(pts)
        # thickness
        th = 0.012
        inner = [[p + (p - V(cxx, p.y, top + dz - 0.06)).normalized() * -th for p in r] for r in rows]
        vs_o = [[bm.verts.new(p) for p in r] for r in rows]
        vs_i = [[bm.verts.new(p) for p in r] for r in inner]
        n1, n2 = len(rows), len(rows[0])
        for i in range(n1 - 1):
            for j in range(n2 - 1):
                bm.faces.new((vs_o[i][j], vs_o[i + 1][j], vs_o[i + 1][j + 1], vs_o[i][j + 1]))
                bm.faces.new((vs_i[i][j], vs_i[i][j + 1], vs_i[i + 1][j + 1], vs_i[i + 1][j]))
        for i in range(n1 - 1):
            for j in (0, n2 - 1):
                bm.faces.new((vs_o[i][j], vs_i[i][j], vs_i[i + 1][j], vs_o[i + 1][j]))
        for j in range(n2 - 1):
            for i in (0, n1 - 1):
                bm.faces.new((vs_o[i][j], vs_o[i][j + 1], vs_i[i][j + 1], vs_i[i][j]))
    pieces.append(rig_piece(f"{side}Pauldron", bm, "M_Steel", f"{side}UpperArm"))
    bm = bmesh.new()
    for yy in (-0.10, 0.0, 0.10):
        a = math.radians(60)
        p = V(cx - sx * 0.02 + sx * 0.170 * math.sin(a), yy, top - 0.06 + 0.170 * math.cos(a) * 0.62)
        n = V(sx * math.sin(a), 0, math.cos(a) * 0.62).normalized()
        lib.dome_rivet(bm, p, n, 0.011, 0.006, n=10)
    pieces.append(rig_piece(f"{side}PauldronRivets", bm, "M_Brass", f"{side}UpperArm"))
    # leather bracer on the forearm
    fmn, fmx = bb(f"{side}LowerArm")
    fcx, fcy = (fmn.x + fmx.x) / 2, (fmn.y + fmx.y) / 2
    hx, hy = (fmx.x - fmn.x) / 2, (fmx.y - fmn.y) / 2
    bm = bmesh.new()
    z0, z1 = fmn.z + 0.02, fmn.z + 0.15
    lib.loft(bm, [shell_ring(fcx, fcy, hx + d, hy + d, 0.02 + d, z) for d, z in ((0.004, z0), (0.016, z0 + 0.010),
                                                                                (0.020, z1 - 0.012), (0.012, z1),
                                                                                (0.004, z1 + 0.004))],
             cap0='ngon', cap1='ngon')
    pieces.append(rig_piece(f"{side}Bracer", bm, "M_Leather", f"{side}LowerArm"))
    # boot cuff
    lmn2, lmx2 = bb(f"{side}LowerLeg")
    lcx, lcy = (lmn2.x + lmx2.x) / 2, (lmn2.y + lmx2.y) / 2
    hx, hy = (lmx2.x - lmn2.x) / 2, (lmx2.y - lmn2.y) / 2
    bm = bmesh.new()
    z0 = lmn2.z
    lib.loft(bm, [shell_ring(lcx, lcy, hx + d, hy + d, 0.02 + d, z) for d, z in ((0.004, z0), (0.012, z0 + 0.010),
                                                                                (0.014, z0 + 0.150), (0.026, z0 + 0.165),
                                                                                (0.026, z0 + 0.200), (0.008, z0 + 0.210))],
             cap0='ngon', cap1='ngon')
    pieces.append(rig_piece(f"{side}BootCuff", bm, "M_Leather", f"{side}LowerLeg"))

# kettle helmet + plume
bm = bmesh.new()
hc = V((hmn.x + hmx.x) / 2, (hmn.y + hmx.y) / 2, 0)
HR = (hmx.x - hmn.x) / 2
zb = hmx.z - 0.060
prof = [(0.0, zb + 0.150), (HR * 0.40, zb + 0.145), (HR * 0.78, zb + 0.120), (HR * 1.02, zb + 0.070),
        (HR * 1.10, zb + 0.020), (HR * 1.12, zb + 0.000), (HR * 1.55, zb - 0.025), (HR * 1.62, zb - 0.040),
        (HR * 1.58, zb - 0.050), (HR * 1.50, zb - 0.040), (HR * 1.08, zb - 0.016), (HR * 1.04, zb - 0.020), (0.0, zb - 0.020)]
lib.lathe(bm, [(r, z) for r, z in prof], hc, Z, 40)
lib.lathe(bm, [(0.0, zb + 0.140), (0.016, zb + 0.140), (0.016, zb + 0.180), (0.0, zb + 0.180)], hc, Z, 14)
pieces.append(rig_piece("Helmet", bm, "M_Steel", "Head"))
bm = bmesh.new()
pts = lib.chaikin([hc + V(0, 0.0, zb + 0.175), hc + V(0, 0.03, zb + 0.24), hc + V(0, 0.10, zb + 0.27),
                   hc + V(0, 0.17, zb + 0.24), hc + V(0, 0.20, zb + 0.18)], 2)
fr = lib.path_frames(pts, up=X)
m = len(fr)
lib.loft(bm, [lib.place(lib.ellipse(0.020 + 0.022 * math.sin(math.pi * k / (m - 1)), 0.030 + 0.030 * math.sin(math.pi * k / (m - 1)), 12),
                        p, u, v) for k, (p, t, u, v) in enumerate(fr)], cap0='ngon', cap1=pts[-1] + V(0, 0.01, -0.02))
pieces.append(rig_piece("Plume", bm, "M_Paint_Red", "Head"))

# face: eyes with highlights, brows and a small smile, projected onto the template head
from mathutils.bvhtree import BVHTree
ho = body["Head"]
hverts = [ho.matrix_world @ v.co - LOC for v in ho.data.vertices]
hbvh = BVHTree.FromPolygons(hverts, [list(p.vertices) for p in ho.data.polygons])


def hsurf(x, z):
    hit, n, i, d = hbvh.ray_cast(V(x, -2.0, z), V(0, 1, 0))
    return hit, n.normalized()


def hdecal(bm, outline, cx, cz, lift, depth=0.006):
    rings = []
    for k in (0.4, 1.0):
        rings.append([hsurf(cx + ox * k, cz + oz * k)[0] + hsurf(cx + ox * k, cz + oz * k)[1] * lift for ox, oz in outline])
    rings.append([hsurf(cx + ox, cz + oz)[0] - hsurf(cx + ox, cz + oz)[1] * depth for ox, oz in outline])
    lib.loft(bm, rings, cap0='ngon', cap1='ngon')


HH = hmx.z - hmn.z
ez = hmn.z + HH * 0.50
bm_e, bm_w, bm_b = bmesh.new(), bmesh.new(), bmesh.new()
for sx in (-1, 1):
    hdecal(bm_e, lib.ellipse(0.0165, 0.026, 20), sx * 0.052, ez, 0.0015)
    hdecal(bm_w, lib.ellipse(0.0055, 0.0075, 10), sx * 0.052 - 0.006, ez + 0.010, 0.0030)
    brow = [(-0.022, -0.004), (0.022, 0.004), (0.022, 0.011), (-0.022, 0.004)]
    brow = [(x * -sx if sx < 0 else x, y) for x, y in brow]
    hdecal(bm_b, lib.ccw(lib.fillet(brow, 0.003, 2)), sx * 0.054, ez + 0.040 - 0.004 * sx * 0, 0.0018)
smile = []
for i in range(12):
    a = math.radians(lerp(200, 340, i / 11))
    smile.append((0.040 * math.cos(a), 0.022 * math.sin(a)))
for i in range(12):
    a = math.radians(lerp(340, 200, i / 11))
    smile.append((0.034 * math.cos(a), 0.022 * math.sin(a) + 0.007))
hdecal(bm_e, lib.ccw(smile), 0.0, hmn.z + HH * 0.30, 0.0015)
pieces.append(rig_piece("FaceFeatures", bm_e, "M_Face", "Head", sharp=60))
pieces.append(rig_piece("EyeShine", bm_w, "M_Eye_White", "Head", sharp=60))
pieces.append(rig_piece("Brows", bm_b, "M_Leather", "Head", sharp=60))

for o in body.values():
    o.data.shade_smooth()
txt, tot = lib.report(coll)
print(txt)
print("height", round(max((o.matrix_world @ v.co).z for o in coll.objects if o.type == 'MESH' for v in o.data.vertices), 3),
      "bones", len(arm.data.bones))
for o in pieces:
    st = lib.check_mesh(o)
    if any(st[k] for k in ('non_manifold', 'loose', 'zero_area', 'dup_faces')):
        print("CHECK", o.name, st)
