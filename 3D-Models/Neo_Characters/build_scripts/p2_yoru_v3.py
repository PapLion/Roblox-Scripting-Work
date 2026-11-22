exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib2.py").read(), globals())
R = 0.85
root = bpy.data.objects["Yoru_Root"]
C = {s: bpy.data.collections[f"Yoru_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Yoru_Hair", "Yoru_Rosette", "Yoru_Scarf", "Yoru_Buckle", "Yoru_Strap", "Yoru_Eye", "Yoru_Blush", "Yoru_Lash"]))

M_blond = bpy.data.materials["M_Yoru_HairBlond"]
M_brown = bpy.data.materials["M_Yoru_HairBrown"]
for m in (M_blond, M_brown):
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.5
    p.inputs["Sheen Weight"].default_value = 0.3
    p.inputs["Subsurface Weight"].default_value = 0.08
set_ramp("M_Yoru_HairBlond", (0.86, 0.66, 0.42), (1.0, 0.90, 0.70))
M_brown.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.072, 0.05, 1)
M_brown.node_tree.nodes["Principled BSDF"].inputs["Sheen Weight"].default_value = 0.1
M_scarf = bpy.data.materials["M_Yoru_Scarf"]
M_strap = bpy.data.materials["M_Yoru_Strap"]
M_brass = bpy.data.materials["M_Yoru_Brass"]
M_petal = bpy.data.materials["M_Yoru_Rosette"]
M_amber = bpy.data.materials["M_Yoru_AmberGlow"]
M_hl = bpy.data.materials["M_Yoru_EyeHighlight"]
M_blush = bpy.data.materials["M_Yoru_Blush"]
M_eye = mat_gradient("M_Yoru_Eye", (0.13, 0.08, 0.16), (0.008, 0.006, 0.014), rough=0.05, coat=1.0, zmin=-0.20, zmax=0.08)
M_lash = mat("M_Yoru_Lash", (0.01, 0.008, 0.012), rough=0.4)
M_stroke = mat("M_Yoru_BlushStroke", (0.95, 0.42, 0.22), rough=0.6)
set_ramp("M_Yoru_Rosette", (0.98, 0.70, 0.48), (1.0, 0.90, 0.74)) if any(n.type == 'VALTORGB' for n in M_petal.node_tree.nodes) else None
M_petal.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1.0, 0.84, 0.64, 1)
M_petal.node_tree.nodes["Principled BSDF"].inputs["Subsurface Weight"].default_value = 0.25

# ================= FACE =================
for side, az in (("L", -22), ("R", 22)):
    sg = -1 if side == "L" else 1
    e = decal(f"Yoru_Eye_{side}", outline_ellipse(az, -1, 9.5, 14.5, n=36), R, h_out=0.032, material=M_eye, rings=5)
    link(e, C["Face"], root)
    # upper lash: smooth tapered curve hugging the top of the eye, flicking at the outer corner
    pts = []
    for i in range(9):
        t = i / 8
        a = math.radians(160 - 130 * t) if sg > 0 else math.radians(20 + 130 * t)
        pts.append(D(az + 9.9 * math.cos(a), -1 + 14.9 * math.sin(a)) * (R + 0.036))
    pts.append(D(az + sg * 12.5, 8.5) * (R + 0.04))
    lash = curve_tube(f"Yoru_Lash_{side}", pts, 0.011, M_lash)
    link(lash, C["Face"], root)
    h1 = decal(f"Yoru_EyeHighlight_{side}_Big", outline_ellipse(az + 3.2, 5.5, 3.6, 4.6, rot=0.4, n=20), R, h_out=0.042, material=M_hl)
    link(h1, C["Face"], root)
    h2 = decal(f"Yoru_EyeHighlight_{side}_Small", outline_ellipse(az - 3.8, -8.0, 1.6, 1.9, n=12), R, h_out=0.042, material=M_hl)
    link(h2, C["Face"], root)
    bc = (az + sg * 15, -16)
    b = decal(f"Yoru_Blush_{side}", outline_ellipse(bc[0], bc[1], 8.5, 4.2, n=24), R, h_out=0.008, material=M_blush)
    link(b, C["Face"], root)
    for k in range(3):
        x0 = bc[0] - 3.8 + 3.8 * k
        st = decal(f"Yoru_BlushStroke_{side}_{k + 1}", outline_capsule((x0 - 1.0, bc[1] - 1.8), (x0 + 1.0, bc[1] + 1.8), 0.6, n=6),
                   R, h_out=0.012, material=M_stroke, rings=2)
        link(st, C["Face"], root)

# ================= HAIR =================
cap_edge = lambda az: 50 - 86 * smoothstep(28, 165, abs(az)) - 5 * abs(((az + 5) / 18.0) % 1.0 - 0.5) * 2
cap = hair_cap("Yoru_HairCap", R + 0.04, cap_edge, M_brown, naz=72, nel=14)
link(cap, C["Hair"], root)
n = 0
def H(tag, m, d0, d1, w, t, **kw):
    global n; n += 1
    kw.setdefault("blunt", 0.18); kw.setdefault("tip_pow", 0.65); kw.setdefault("curl", 0.4)
    o = lock2(f"Yoru_Hair_{tag}_{n:02d}", R, d0, d1, w, t, m, **kw)
    link(o, C["Hair"], root)
    return o
# primary: heavy soft fringe sweeping viewer-left -> right, tips rounded
H("P_Fringe", M_blond, (-18, 86), (50, -6), 0.86, 0.22, belly=0.08, flick=0.08, side=0.07, tip_side=0.08, ext=1.06, lift0=0.14)  # big cream lock sweeping to the right, over the dark lock
H("P_FringeRight", M_blond, (22, 86), (74, -22), 0.72, 0.21, belly=0.08, flick=0.12, side=0.05, tip_side=0.08, ext=1.06, lift0=0.13)
H("P_FringeLeft", M_blond, (-62, 80), (-44, 18), 0.60, 0.19, belly=0.06, flick=0.06, side=-0.04, ext=1.04, lift0=0.11)
# primary: long wavy side lock on viewer-right, flaring out over the scarf
H("P_SideLockR", M_blond, (52, 80), (86, -62), 0.52, 0.16, belly=0.07, flick=0.24, side=-0.07, tip_side=0.10, droop=0.12, ext=1.08, lift0=0.10, blunt=0.1)
H("P_SideLockRb", M_blond, (66, 80), (100, -40), 0.44, 0.14, belly=0.09, flick=0.26, side=0.05, tip_side=0.08, droop=0.08, ext=1.06, lift0=0.13)
H("P_SideLockR2", M_blond, (88, 76), (118, -46), 0.56, 0.17, belly=0.07, flick=0.20, side=0.05, droop=0.1, ext=1.05, lift0=0.09)
# ---- back (v3): two overlapping rows instead of equally spaced panels.
# Outer cream row: long, varied lengths/widths, soft volume. Inner brown row: peeks out below and at the sides.
outer = ((122, -8, 0.66, 0.05), (150, -16, 0.74, -0.05), (176, -4, 0.70, 0.06), (-154, -18, 0.76, -0.04),
         (-128, -6, 0.64, 0.05))
for az, el1, w, sd in outer:
    H("P_BackCream", M_blond, (az, 86), (az + sd * 70, el1), w, 0.16, belly=0.11, flick=0.16, side=sd, ext=1.0, lift0=0.12)
H("P_Crown", M_blond, (160, 89), (-170, 30), 0.70, 0.16, belly=0.12, flick=0.12, side=0.05, ext=1.0, lift0=0.15)
inner = ((-84, -30, 0.54, 0.05, 72), (-102, -40, 0.60, -0.04, 74), (-121, -33, 0.52, 0.06, 72), (-140, -42, 0.58, -0.05, 76),
         (-160, -36, 0.60, 0.04, 76), (-178, -44, 0.56, -0.06, 74), (163, -34, 0.60, 0.05, 76), (143, -42, 0.56, -0.04, 74),
         (124, -30, 0.54, 0.06, 72), (106, -38, 0.52, -0.05, 72))
for az, el1, w, sd, el0 in inner:
    H("S_Under", M_brown, (az, el0), (az + sd * 60, el1), w, 0.14, belly=0.05, flick=0.12, side=sd, ext=1.0, lift0=0.06)
# secondary blond accents
H("S_LeftBlond", M_blond, (-58, 76), (-76, -10), 0.48, 0.15, belly=0.06, flick=0.10, side=0.05, ext=1.05, lift0=0.12)
H("S_TopL", M_blond, (-70, 88), (-122, 38), 0.58, 0.17, belly=0.1, flick=0.16, ext=1.0, lift0=0.13)
H("S_TopR", M_blond, (66, 88), (120, 38), 0.56, 0.17, belly=0.1, flick=0.16, ext=1.0, lift0=0.13)
# dark under-layer of the fringe: several straight, staggered locks peeking out under the big cream lock
H("S_FringeBrown", M_brown, (-6, 89), (13, 14), 0.62, 0.16, belly=0.03, flick=0.0, ext=1.0, lift0=0.08, blunt=0.0, tip_start=0.5, tip_pow=0.9, root=0.8)   # centre -> right eye (thickest)
H("S_FringeBrown", M_brown, (10, 88), (29, 8), 0.50, 0.14, belly=0.03, flick=0.02, ext=1.0, lift0=0.075, blunt=0.0, tip_start=0.45, tip_pow=0.9, root=0.8)  # ends over the outer corner of the right eye
H("S_FringeBrown", M_brown, (26, 84), (42, -26), 0.42, 0.12, belly=0.03, flick=0.04, ext=1.0, lift0=0.07, blunt=0.0, tip_start=0.4, tip_pow=0.9, root=0.8)   # down the right side of the face
H("S_FringeBrown", M_brown, (-22, 88), (-4, 30), 0.34, 0.10, belly=0.03, flick=0.0, ext=1.0, lift0=0.075, blunt=0.0, tip_start=0.4, tip_pow=0.9, root=0.8)  # short one, adds layering at the parting
H("T_FringeWisp", M_blond, (30, 80), (40, 4), 0.24, 0.08, belly=0.05, flick=0.06, side=0.04, ext=1.05, lift0=0.15, blunt=0.0)

# ahoge: plump upward-curving tuft
top = Vector((0, 0, R))
ah = catmull([top * 0.97, top + Vector((0.01, -0.02, 0.16)), top + Vector((0.07, -0.08, 0.33)),
              top + Vector((0.17, -0.09, 0.40)), top + Vector((0.25, -0.03, 0.35)), top + Vector((0.27, 0.02, 0.27))], per=5)
o = ribbon("Yoru_Hair_Ahoge", ah, 0.13, 0.07, M_blond, lambda s: (0.7 + 0.3 * smoothstep(0, 0.25, s)) * (1 - s) ** 0.75,
           up_hint=Vector((0, -1, 0)), M=10, curl=0.25)
link(o, C["Hair"], root)
# rounded curl loops behind the head (brown), thicker and tapered
for i, (az, el, rad, rot) in enumerate(((-112, 50, 0.17, 0.0), (-142, 40, 0.14, 0.7))):
    base = D(az, el) * (R * 1.10); out = D(az, el)
    side_ = Vector((0, 0, 1)).cross(out).normalized(); up = out.cross(side_).normalized()
    pts = []
    for k in range(11):
        a = rot + 2 * math.pi * k / 10 * 0.95
        rr = rad * (1 - 0.22 * k / 10)
        pts.append(base + out * (rad + rr * math.sin(a)) + up * (rr * math.cos(a) - rad * 0.2))
    c = curve_tube(f"Yoru_Hair_Curl_{i + 1}", pts, 0.042, M_brown, taper_end=True)
    link(c, C["Hair"], root)

# ================= FLOWER (cupped petals, two layers) =================
fc_dir = D(-60, 36); fc = fc_dir * (R * 1.22)
rm = look_rot(fc_dir).to_matrix()
for layer, (cnt, rad, size, cup, z) in enumerate(((5, 0.14, 0.13, 0.55, 0.0), (4, 0.07, 0.095, 0.85, 0.03))):
    for k in range(cnt):
        a = 2 * math.pi * k / cnt + 0.3 + layer * 0.5
        pt = uv_sphere(f"Yoru_Rosette_Petal_{layer + 1}_{k + 1}", size, M_petal, 20, 10)
        loc = Vector((math.cos(a) * rad, math.sin(a) * rad, z))
        pt.location = fc + rm @ loc
        # orient petal radially and cup it upward (tilt toward the flower normal)
        rot = rm @ Matrix.Rotation(a, 3, 'Z') @ Matrix.Rotation(-cup, 3, 'Y')
        pt.rotation_euler = rot.to_euler()
        pt.scale = (1.25, 0.95, 0.42)
        link(pt, C["Accessories"], root)
ctr = uv_sphere("Yoru_Rosette_Center", 0.055, M_amber, 16, 8)
ctr.location = fc + fc_dir * 0.045
link(ctr, C["Accessories"], root)

# ================= SCARF: three overlapping, tilted wraps + belt =================
def wrap(name, cr, cz, rx, rz, tilt, phase, amp=0.05):
    wob = lambda th, i: (1 + amp * math.sin(5 * th + phase + 0.3 * i) + 0.5 * amp * math.sin(9 * th - phase - 0.5 * i)
                         + 0.35 * amp * math.sin(2 * th + phase))
    # squash-profile: flatter on top where the next wrap overlaps (compression)
    prof = []
    for j in range(18):
        a = 2 * math.pi * j / 18
        z = math.sin(a) * rz * (0.78 if math.sin(a) > 0 else 1.0)
        prof.append((cr + math.cos(a) * rx, cz + z))
    o = revolve(name, prof, 72, M_scarf, wobble=wob, subsurf=2)
    # vertical undulation: the wrap rises and dips like wound fabric instead of a flat ring
    for v in o.data.vertices:
        th = math.atan2(v.co.y, v.co.x)
        v.co.z += 0.034 * math.sin(3 * th + phase) + 0.016 * math.sin(5 * th - 2 * phase)
    o.rotation_euler = tilt
    link(o, C["Accessories"], root)
    return o, wob
w1, wob1 = wrap("Yoru_Scarf_Wrap_Low", 0.55, -0.63, 0.33, 0.22, (math.radians(5), math.radians(-3), 0), 0.4)
w2, wob2 = wrap("Yoru_Scarf_Wrap_Mid", 0.66, -0.44, 0.29, 0.19, (math.radians(-9), math.radians(11), 0), 2.1, 0.06)
w3, wob3 = wrap("Yoru_Scarf_Wrap_High", 0.75, -0.27, 0.20, 0.14, (math.radians(6), math.radians(-3), 0), 4.0, 0.05)
# belt strap around the mid wrap (same tilt, follows its folds)
th0 = 0.0
sr = 0.66 + 0.29 * 0.97
strap = revolve("Yoru_Scarf_Strap", rounded_rect_profile(sr + 0.012, -0.46, 0.022, 0.05, 0.016, 3), 72, M_strap,
                wobble=lambda th, i: wob2(th, 0), subsurf=1)
und2 = lambda th: 0.034 * math.sin(3 * th + 2.1) + 0.016 * math.sin(5 * th - 4.2)
for v in strap.data.vertices:
    v.co.z += und2(math.atan2(v.co.y, v.co.x))
strap.rotation_euler = w2.rotation_euler
link(strap, C["Accessories"], root)
# buckle in the mid-wrap frame
az_b = 8.0
th_b = math.radians(-90 + az_b)
rb = (sr + 0.012) * wob2(th_b, 0) + 0.03
Rw = w2.rotation_euler.to_matrix()
local = Vector((math.cos(th_b) * rb, math.sin(th_b) * rb, -0.46 + und2(th_b)))
bpos = Rw @ local
outward = (Rw @ Vector((math.cos(th_b), math.sin(th_b), 0))).normalized()
bm = bmesh.new()
o_x, o_y, i_x, i_y, d_ = 0.15, 0.12, 0.095, 0.07, 0.032
def sq(hx, hy, z):
    return [bm.verts.new(v) for v in ((-hx, -hy, z), (hx, -hy, z), (hx, hy, z), (-hx, hy, z))]
fo, fi, bo, bi = sq(o_x, o_y, d_), sq(i_x, i_y, d_), sq(o_x, o_y, -d_), sq(i_x, i_y, -d_)
for k in range(4):
    k2 = (k + 1) % 4
    bm.faces.new((fo[k], fo[k2], fi[k2], fi[k])); bm.faces.new((bi[k], bi[k2], bo[k2], bo[k]))
    bm.faces.new((bo[k], bo[k2], fo[k2], fo[k])); bm.faces.new((fi[k], fi[k2], bi[k2], bi[k]))
me = bpy.data.meshes.new("Yoru_Buckle"); bm.to_mesh(me); bm.free()
me.materials.append(M_brass); me.shade_smooth()
buckle = bpy.data.objects.new("Yoru_Buckle", me)
bv = buckle.modifiers.new("Bevel", 'BEVEL'); bv.width = 0.018; bv.segments = 4; bv.limit_method = 'ANGLE'
buckle.location = bpos
buckle.rotation_euler = look_rot(outward)
link(buckle, C["Accessories"], root)
prong = box("Yoru_Buckle_Prong", (0.016, 0.15, 0.016), M_brass, bevel=0.006)
prong.location = bpos + outward * 0.012
prong.rotation_euler = look_rot(outward)
link(prong, C["Accessories"], root)
# strap end: exits the buckle and hangs with a rounded tip
tabp = catmull([bpos + outward * 0.03 + Vector((0, 0, -0.06)), bpos + outward * 0.06 + Vector((0.01, 0, -0.22)),
                bpos + outward * 0.05 + Vector((0.02, 0, -0.26)), bpos + outward * 0.03 + Vector((0.04, 0, -0.34))], per=5)
tab = ribbon("Yoru_Strap_Tab", tabp, 0.13, 0.035, M_strap, lambda s: 1.0 - 0.5 * smoothstep(0.82, 1.0, s),
             up_hint=outward, M=8, curl=0.0)
link(tab, C["Accessories"], root)
print("Yoru objs", sum(len(c.objects) for c in C.values()))

# scarf / strap material polish so folds read against each other
ps = M_scarf.node_tree.nodes["Principled BSDF"]
ps.inputs["Base Color"].default_value = (0.085, 0.072, 0.09, 1)
ps.inputs["Sheen Weight"].default_value = 0.8
ps.inputs["Sheen Tint"].default_value = (0.8, 0.7, 1.0, 1)
ps.inputs["Roughness"].default_value = 0.7
pst = M_strap.node_tree.nodes["Principled BSDF"]
pst.inputs["Base Color"].default_value = (0.05, 0.034, 0.03, 1)
pst.inputs["Coat Weight"].default_value = 0.6
