exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
import random
random.seed(11)
R = 0.85
root, C = char_setup("Yoru", (0.0, 0.0, -0.15))

M_skin = mat_gradient("M_Yoru_Skin", (0.82, 0.70, 0.60), (1.0, 0.96, 0.89), rough=0.45, coat=0.12,
                      sss=0.06, zmin=-0.85, zmax=0.7, rim=(1.0, 0.72, 0.42), rim_str=0.12)
M_blond = mat_gradient("M_Yoru_HairBlond", (0.86, 0.72, 0.52), (1.0, 0.94, 0.80), rough=0.5,
                       zmin=-0.6, zmax=1.1)
M_brown = mat("M_Yoru_HairBrown", (0.10, 0.062, 0.042), rough=0.55, spec=0.35)
M_eye = mat("M_Yoru_Eye", (0.012, 0.010, 0.02), rough=0.06, coat=1.0)
M_hl = mat_emit("M_Yoru_EyeHighlight", (1.0, 1.0, 1.0), 2.2)
M_blush = mat("M_Yoru_Blush", (1.0, 0.55, 0.36), rough=0.6, emit=(1.0, 0.55, 0.30), emit_str=0.25)
M_scarf = mat("M_Yoru_Scarf", (0.045, 0.038, 0.045), rough=0.78, spec=0.25, sss=0.0)
M_strap = mat("M_Yoru_Strap", (0.045, 0.032, 0.028), rough=0.45, coat=0.3)
M_brass = mat("M_Yoru_Brass", (0.80, 0.56, 0.26), rough=0.28, metal=1.0)
M_petal = mat("M_Yoru_Rosette", (1.0, 0.80, 0.56), rough=0.5, sss=0.1)
M_amber = mat("M_Yoru_AmberGlow", (1.0, 0.62, 0.22), rough=0.3, emit=(1.0, 0.55, 0.15), emit_str=1.5)

# knit-ish bump on the scarf (cheap procedural)
nt = M_scarf.node_tree
wv = nt.nodes.new("ShaderNodeTexWave"); wv.wave_type = 'BANDS'; wv.bands_direction = 'Z'
wv.inputs["Scale"].default_value = 18; wv.inputs["Distortion"].default_value = 2.0
bmp = nt.nodes.new("ShaderNodeBump"); bmp.inputs["Strength"].default_value = 0.18
nt.links.new(wv.outputs["Fac"], bmp.inputs["Height"])
nt.links.new(bmp.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])

# ---- core
head = uv_sphere("Yoru_Head", R, M_skin, 64, 32)
md = head.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
link(head, C["Core"], root)

# ---- face: big glossy oval eyes, highlights, blush
for side, az in (("L", -22), ("R", 22)):
    sg = -1 if side == "L" else 1
    e = decal(f"Yoru_Eye_{side}", outline_ellipse(az, 0, 9.0, 14.5, n=32), R, h_out=0.03, material=M_eye)
    link(e, C["Face"], root)
    h1 = decal(f"Yoru_EyeHighlight_{side}_Big", outline_ellipse(az + 2.8, 6.5, 3.4, 4.2, n=16), R,
               h_out=0.04, material=M_hl)
    link(h1, C["Face"], root)
    h2 = decal(f"Yoru_EyeHighlight_{side}_Small", outline_ellipse(az - 3.2, -7.0, 1.5, 1.7, n=12), R,
               h_out=0.04, material=M_hl)
    link(h2, C["Face"], root)
    b = decal(f"Yoru_Blush_{side}", outline_ellipse(az + sg * 15, -15, 7.5, 3.6, n=20), R,
              h_out=0.01, material=M_blush)
    link(b, C["Face"], root)

# ---- hair
cap_edge = lambda az: 46 - 80 * smoothstep(30, 160, abs(az)) - 5 * abs(((az + 5) / 18.0) % 1.0 - 0.5) * 2
cap = hair_cap("Yoru_HairCap", R + 0.024, cap_edge, M_brown, naz=72, nel=14)
link(cap, C["Hair"], root)

n = 0
def H(tag, mat_, d0, d1, w, t, lift1=0.25, ext=1.0, droop=0.0, lift0=None, taper=0.6, sweep=None):
    global n; n += 1
    o = lock(f"Yoru_Hair_{tag}_{n:02d}", R, d0, d1, width=w, thick=t, material=mat_, lift0=lift0,
             lift1=lift1, ext=ext, droop=droop, taper=taper, sweep=sweep)
    link(o, C["Hair"], root)
    return o

# back: brown underlayer, blond outer
for az in range(100, 265, 22):
    H("BackBrown", M_brown, (az, 80), (az + random.uniform(-8, 8), -30), 0.52, 0.11, lift1=0.14, ext=1.0, droop=0.08)
for az in (120, 160, 200, 240):
    H("BackBlond", M_blond, (az + 10, 86), (az - 10, 0), 0.56, 0.12, lift0=0.08, lift1=0.2, ext=1.0, droop=0.06)
# viewer-left: brown underlayer side locks, one blond
H("SideLBrown", M_brown, (-70, 64), (-88, -30), 0.42, 0.10, lift1=0.12, ext=1.05, droop=0.12)
H("SideLBrown", M_brown, (-100, 62), (-112, -40), 0.40, 0.10, lift1=0.12, ext=1.05, droop=0.15)
H("SideLBlond", M_blond, (-58, 74), (-74, -12), 0.44, 0.11, lift0=0.07, lift1=0.14, ext=1.05, droop=0.1)
# viewer-right: long soft blond side locks down to the scarf
H("SideRBlond", M_blond, (40, 78), (72, -40), 0.50, 0.12, lift0=0.08, lift1=0.14, ext=1.08, droop=0.15)
H("SideRBlond", M_blond, (70, 74), (95, -42), 0.46, 0.11, lift0=0.07, lift1=0.12, ext=1.08, droop=0.15)
H("SideRBrown", M_brown, (88, 66), (110, -30), 0.40, 0.10, lift1=0.12, ext=1.0, droop=0.1)
# big playful bangs sweeping over the forehead toward viewer-right
H("Bang", M_blond, (-48, 76), (-32, 14), 0.52, 0.12, lift0=0.07, lift1=0.12, ext=1.05)
H("Bang", M_blond, (-26, 82), (8, 16), 0.62, 0.13, lift0=0.10, lift1=0.10, ext=1.08)
H("Bang", M_blond, (-2, 84), (34, 10), 0.62, 0.13, lift0=0.12, lift1=0.10, ext=1.08)
H("Bang", M_blond, (20, 80), (54, -4), 0.50, 0.12, lift0=0.10, lift1=0.13, ext=1.08)
H("BangBrown", M_brown, (-12, 80), (-12, 22), 0.34, 0.09, lift0=0.06, lift1=0.08, ext=1.0)
# top volume
H("Top", M_blond, (150, 88), (-150, 50), 0.58, 0.13, lift0=0.12, lift1=0.18, ext=1.0)
H("Top", M_blond, (60, 86), (120, 40), 0.54, 0.12, lift0=0.11, lift1=0.2, ext=1.0, droop=0.05)
H("Top", M_blond, (-60, 86), (-120, 40), 0.54, 0.12, lift0=0.11, lift1=0.2, ext=1.0, droop=0.05)

# ahoge: one small upward-curving tuft
top = Vector((0, 0, R))
ah = catmull([top * 0.98 + Vector((0.0, 0.02, 0)), top + Vector((0.02, -0.02, 0.18)),
              top + Vector((0.08, -0.10, 0.36)), top + Vector((0.19, -0.10, 0.42)),
              top + Vector((0.26, -0.02, 0.36))], per=5)
o = spine_lock("Yoru_Hair_Ahoge", ah, width=0.10, thick=0.05, material=M_blond, crescent=0.1,
               profile=lambda s: (0.55 + 0.45 * smoothstep(0, 0.3, s)) * (1 - s) ** 0.7,
               up_hint=Vector((0, -1, 0)))
link(o, C["Hair"], root)

# rounded curl loops behind the head (dark brown)
for i, (az, el, rad, rot) in enumerate(((-115, 46, 0.16, 0.0), (-145, 38, 0.13, 0.7))):
    base = D(az, el) * (R * 1.08)
    out = D(az, el)
    side = Vector((0, 0, 1)).cross(out).normalized()
    up = out.cross(side).normalized()
    pts = []
    for k in range(10):
        a = rot + 2 * math.pi * k / 9 * 0.92
        rr = rad * (1 - 0.18 * k / 9)
        pts.append(base + out * (rad + rr * math.sin(a)) + up * (rr * math.cos(a) - rad * 0.2))
    c = curve_tube(f"Yoru_Hair_Curl_{i + 1}", pts, 0.032, M_brown, taper_end=True)
    link(c, C["Hair"], root)

# ---- accessory: cream rosette at viewer-left side
rc = D(-74, 22) * (R * 1.12)
nrm = D(-74, 22)
rot = look_rot(nrm)
for k in range(5):
    a = 2 * math.pi * k / 5 + 0.3
    pt = uv_sphere(f"Yoru_Rosette_Petal_{k + 1}", 0.095, M_petal, 16, 8)
    off = Matrix.Rotation(rot.z, 4, 'Z') @ Matrix.Rotation(rot.y, 4, 'Y') @ Matrix.Rotation(rot.x, 4, 'X')
    local = Vector((math.cos(a) * 0.105, math.sin(a) * 0.105, 0))
    pt.location = rc + (rot.to_matrix() @ local)
    pt.rotation_euler = (rot.to_matrix() @ Matrix.Rotation(a, 3, 'Z')).to_euler()
    pt.scale = (1.25, 0.8, 0.45)
    link(pt, C["Accessories"], root)
ctr = uv_sphere("Yoru_Rosette_Center", 0.05, M_amber, 16, 8)
ctr.location = rc + nrm * 0.03
link(ctr, C["Accessories"], root)

# ---- scarf: two fat rolls with folds + hanging tail
wob = lambda th, i: 1 + 0.045 * math.sin(5 * th + 0.4 + 0.25 * i) + 0.022 * math.sin(11 * th + 1.3 - 0.4 * i) + 0.02 * math.sin(3 * th)
sc1 = revolve("Yoru_Scarf_Roll_Low", circle_profile(0.60, -0.56, 0.28, 0.23, 16), 64, M_scarf, wobble=wob)
link(sc1, C["Accessories"], root)
wob2 = lambda th, i: 1 + 0.04 * math.sin(6 * th + 2.0 + 0.3 * i) + 0.02 * math.sin(13 * th - 0.5 * i)
sc2 = revolve("Yoru_Scarf_Roll_High", circle_profile(0.68, -0.30, 0.20, 0.15, 14), 64, M_scarf, wobble=wob2)
link(sc2, C["Accessories"], root)
# strap belt around the low roll
strap = revolve("Yoru_Scarf_Strap", rounded_rect_profile(0.895, -0.53, 0.02, 0.045, 0.014, 3), 64,
                M_strap, wobble=lambda th, i: wob(th, 0), subsurf=0)
link(strap, C["Accessories"], root)

# square buckle (frame + prong) at front
az_b = 12.0
th_b = math.radians(-90 + az_b)
rb = 0.895 * wob(th_b, 0) + 0.03
bpos = Vector((math.cos(th_b) * rb, math.sin(th_b) * rb, -0.53))
bm = bmesh.new()
o_, i_, d_ = 0.12, 0.075, 0.03
sq_o = [(-o_, -o_), (o_, -o_), (o_, o_), (-o_, o_)]
sq_i = [(-i_, -i_), (i_, -i_), (i_, i_), (-i_, i_)]
vs = {}
for lay, z in (("f", d_), ("b", -d_)):
    vs[lay + "o"] = [bm.verts.new((x, y, z)) for x, y in sq_o]
    vs[lay + "i"] = [bm.verts.new((x, y, z)) for x, y in sq_i]
for k in range(4):
    k2 = (k + 1) % 4
    bm.faces.new((vs["fo"][k], vs["fo"][k2], vs["fi"][k2], vs["fi"][k]))
    bm.faces.new((vs["bi"][k], vs["bi"][k2], vs["bo"][k2], vs["bo"][k]))
    bm.faces.new((vs["bo"][k], vs["bo"][k2], vs["fo"][k2], vs["fo"][k]))
    bm.faces.new((vs["fi"][k], vs["fi"][k2], vs["bi"][k2], vs["bi"][k]))
me = bpy.data.meshes.new("Yoru_Buckle"); bm.to_mesh(me); bm.free()
me.materials.append(M_brass)
buckle = bpy.data.objects.new("Yoru_Buckle", me)
bv = buckle.modifiers.new("Bevel", 'BEVEL'); bv.width = 0.012; bv.segments = 3; bv.limit_method = 'ANGLE'
buckle.location = bpos
outward = Vector((math.cos(th_b), math.sin(th_b), 0))
buckle.rotation_euler = look_rot(outward)
link(buckle, C["Accessories"], root)
me.shade_smooth()
prong = box("Yoru_Buckle_Prong", (0.012, 0.11, 0.012), M_brass, bevel=0.004)
prong.location = bpos + outward * 0.01
prong.rotation_euler = look_rot(outward)
link(prong, C["Accessories"], root)
# strap end hanging below the buckle
tabp = catmull([bpos + outward * 0.02 + Vector((0, 0, -0.10)), bpos + outward * 0.05 + Vector((0.01, 0, -0.24)),
                bpos + outward * 0.03 + Vector((0.03, 0, -0.46))], per=5)
tab = spine_lock("Yoru_Strap_Tab", tabp, width=0.12, thick=0.035, material=M_strap, crescent=0.0,
                 profile=lambda s: 1.0 - 0.35 * smoothstep(0.75, 1.0, s), up_hint=outward, M=8)
link(tab, C["Accessories"], root)

print("Yoru objects:", sum(len(c.objects) for c in C.values()))
