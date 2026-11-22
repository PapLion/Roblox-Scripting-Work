exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib2.py").read(), globals())
import random
random.seed(3)
R = 1.0
root = bpy.data.objects["Akemi_Root"]
C = {s: bpy.data.collections[f"Akemi_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Akemi_Tentacle", "Akemi_Blade", "Akemi_BellFrill", "Akemi_Visor", "Akemi_XEye", "Akemi_Bow",
                       "Akemi_Antenna", "Akemi_Skirt", "Akemi_InnerBulb", "Akemi_Frill", "Akemi_Ribbon", "Akemi_Arm"]))

# ---------------- materials
M_jelly = bpy.data.materials["M_Akemi_Jelly"]
pj = M_jelly.node_tree.nodes["Principled BSDF"]
pj.inputs["Subsurface Weight"].default_value = 0.35
pj.inputs["Subsurface Radius"].default_value = (0.4, 0.6, 1.0)
pj.inputs["Coat Weight"].default_value = 1.0
set_ramp("M_Akemi_Jelly", (0.42, 0.34, 0.98), (0.72, 0.66, 1.0))
for nd in M_jelly.node_tree.nodes:
    if nd.type == 'BUMP': nd.inputs["Strength"].default_value = 0.4
    if nd.type == 'MATH' and nd.operation == 'POWER': nd.inputs[1].default_value = 0.12
    if nd.type == 'MATH' and nd.operation == 'MULTIPLY' and nd.inputs[1].default_value < 2: nd.inputs[1].default_value = 0.9

def glow_mat(name, base, emit, alpha, emit_base=0.35, rim=2.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    p.inputs["Base Color"].default_value = (*base, 1)
    p.inputs["Roughness"].default_value = 0.15
    p.inputs["Coat Weight"].default_value = 0.6
    p.inputs["Subsurface Weight"].default_value = 0.3
    p.inputs["Alpha"].default_value = alpha
    p.inputs["Emission Color"].default_value = (*emit, 1)
    lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = 0.4
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = emit_base; mr.inputs["To Max"].default_value = rim
    nt.links.new(lw.outputs["Facing"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], p.inputs["Emission Strength"])
    nt.links.new(p.outputs[0], out.inputs[0])
    m.surface_render_method = 'BLENDED'; m.use_transparency_overlap = True; m.use_backface_culling = False
    m.diffuse_color = (*base, 1)
    return m
M_rib = glow_mat("M_Akemi_Tentacle", (0.62, 0.52, 1.0), (0.52, 0.36, 1.0), 0.80, 0.45, 2.4)   # thick luminous tentacles
M_sec = glow_mat("M_Akemi_TentacleSecondary", (0.32, 0.40, 1.0), (0.28, 0.42, 1.0), 0.5, 0.3, 2.2)
M_blade = glow_mat("M_Akemi_Blade", (0.62, 0.62, 1.0), (0.40, 0.50, 1.0), 0.66, 0.40, 2.6)
M_skirt = glow_mat("M_Akemi_Skirt", (0.30, 0.26, 0.95), (0.38, 0.22, 1.0), 0.38, 0.4, 2.2)
M_bulb = glow_mat("M_Akemi_InnerBulb", (0.55, 0.35, 1.0), (0.55, 0.30, 1.0), 0.75, 1.2, 2.5)
M_visor = bpy.data.materials["M_Akemi_Visor"]
M_xeye = mat_emit("M_Akemi_XEyeGlow", (0.62, 0.30, 1.0), 4.5)
M_halo = glow_mat("M_Akemi_XEyeHalo", (0.05, 0.02, 0.1), (0.45, 0.15, 1.0), 0.45, 1.2, 1.2)
M_bow = bpy.data.materials["M_Akemi_Bow"]
M_bow.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.36, 1.0, 1)
M_bow.node_tree.nodes["Principled BSDF"].inputs["Sheen Weight"].default_value = 0.6
M_knot = bpy.data.materials["M_Akemi_BowKnot"]
M_ant = mat("M_Akemi_Antenna", (0.36, 0.42, 1.0), rough=0.12, coat=1.0, sss=0.3)
add_rim(M_ant, (0.40, 0.45, 1.0), 1.6)

# ---------------- transition: inner bulb + scalloped skirt margin
bulb = uv_sphere("Akemi_InnerBulb", 0.46, M_bulb, 48, 24)
bulb.location = (0, 0, -0.76); bulb.scale = (1.0, 1.0, 0.42)
link(bulb, C["Core"], root)
# (rigid scalloped skirt removed in v3: tentacles now emerge from the soft inner bulb)

# ---------------- face: visor hugging the sphere (wider at the front) + X eyes with halo
TILT = (math.radians(3), math.radians(-5), 0)
visor = sphere_band("Akemi_Visor", R, lambda az: 3.0, lambda az: 15.0 + 3.0 * math.cos(math.radians(az)) ** 2,
                    0.034, -0.02, M_visor, seg=128, prof_n=10, pillow=0.010, subsurf=2)
visor.rotation_euler = TILT
link(visor, C["Face"], root)
RV = R + 0.040
for side, az in (("L", -21), ("R", 21)):
    for k, (p0, p1) in enumerate((((-8.6, 13.5), (8.6, -7.0)), ((-8.6, -7.0), (8.6, 13.5)))):
        x = decal(f"Akemi_XEye_{side}_{k + 1}", outline_capsule((az + p0[0], 3 + p0[1] * 0.75), (az + p1[0], 3 + p1[1] * 0.75), 2.0, n=10),
                  RV, h_out=0.018, h_in=0.02, material=M_xeye, rings=3)
        x.rotation_euler = TILT
        link(x, C["Emissive"], root)
        hl = decal(f"Akemi_XEye_{side}_{k + 1}_Halo", outline_capsule((az + p0[0] * 1.05, 3 + p0[1] * 0.8), (az + p1[0] * 1.05, 3 + p1[1] * 0.8), 4.4, n=10),
                   RV, h_out=0.006, h_in=0.02, material=M_halo, rings=2)
        hl.rotation_euler = TILT
        link(hl, C["Emissive"], root)

# ---------------- bow: real ribbon loops (4 petals) + knot + two tails
bdir = D(-74, 4)
bc = bdir * (R + 0.075)
t1 = Vector((0, 0, 1)).cross(bdir).normalized()   # horizontal tangent
t2 = bdir.cross(t1).normalized()                  # vertical tangent
L_, H_ = 0.46, 0.17
outline = [(0.0, 0.0), (0.30 * L_, H_ * 0.85), (0.80 * L_, H_), (1.0 * L_, H_ * 0.45), (0.85 * L_, 0.0), (0.35 * L_, -0.01)]
for k, ang in enumerate((40, 140, 220, 320)):
    a = math.radians(ang)
    X = (t1 * math.cos(a) + t2 * math.sin(a)).normalized()
    Y = bdir
    Z = X.cross(Y).normalized()
    lp = ribbon_loop(f"Akemi_Bow_Loop_{k + 1}", outline, 0.19, 0.016, M_bow)
    lp.matrix_basis = Matrix((
        (X.x, Y.x, Z.x, bc.x), (X.y, Y.y, Z.y, bc.y), (X.z, Y.z, Z.z, bc.z), (0, 0, 0, 1)))
    link(lp, C["Accessories"], root)
    lp.matrix_parent_inverse = Matrix.Identity(4)
    inner_ = [(x * 0.62 + 0.04 * L_, y * 0.58) for x, y in outline]
    lq = ribbon_loop(f"Akemi_Bow_LoopInner_{k + 1}", inner_, 0.21, 0.012, M_knot)
    lq.matrix_basis = lp.matrix_basis.copy()
    link(lq, C["Accessories"], root)
    lq.matrix_parent_inverse = Matrix.Identity(4)
knot = uv_sphere("Akemi_Bow_Knot", 0.10, M_knot, 20, 10)
knot.location = bc + bdir * 0.04; knot.scale = (1, 1, 0.85)
link(knot, C["Accessories"], root)
for k, (dx, dz) in enumerate(((-0.07, -0.34), (0.08, -0.30))):
    tp = [bc + bdir * 0.03, bc + bdir * 0.07 + t1 * dx * 0.4 + t2 * dz * 0.45, bc + bdir * 0.05 + t1 * dx + t2 * dz]
    tl = ribbon(f"Akemi_Bow_Tail_{k + 1}", catmull(tp, 5), 0.085, 0.016, M_bow,
                lambda s: (1 - 0.25 * s) * (1 - smoothstep(0.85, 1.0, s) * 0.6), up_hint=bdir, M=8, curl=0.2)
    link(tl, C["Accessories"], root)

# ---------------- antenna: tapered stem rising from the top-right, curling into a spiral loop
ap = [D(56, 40) * (R - 0.02), D(57, 52) * (R + 0.07), Vector((0.55, -0.13, 1.08)), Vector((0.74, -0.11, 1.36)),
      Vector((1.00, -0.05, 1.46)), Vector((1.16, -0.01, 1.30)), Vector((1.08, 0.03, 1.11)), Vector((0.90, 0.04, 1.14)),
      Vector((0.86, 0.02, 1.30)), Vector((0.98, 0.0, 1.35)), Vector((1.03, 0.0, 1.26))]
ant = curve_tube("Akemi_Antenna_Loop", ap, 0.055, M_ant, res=16, bevel_res=5)
for i, bp in enumerate(ant.data.splines[0].bezier_points):
    bp.radius = 1.0 - 0.6 * (i / (len(ap) - 1)) ** 0.8
link(ant, C["Accessories"], root)
tipb = uv_sphere("Akemi_Antenna_Tip", 0.032, M_ant, 12, 6)
tipb.location = ap[-1]
link(tipb, C["Accessories"], root)

# ---------------- appendages
def flow_spine(az, r0, z0, length, out, amp1, amp2, f1, f2, ph, N=30, lean=(0, 0)):
    rad = Vector((math.sin(math.radians(az)), -math.cos(math.radians(az)), 0))
    tan = Vector((0, 0, 1)).cross(rad).normalized()
    base = rad * r0 + Vector((0, 0, z0))
    pts = []
    for i in range(N):
        s = i / (N - 1)
        env = 0.25 + 0.75 * s
        p = (base + Vector((lean[0] * s * s, lean[1] * s * s, -length * s))
             + rad * (out * math.sin(math.pi * 0.5 * s) + amp2 * env * math.sin(2 * math.pi * f2 * s + ph * 1.7))
             + tan * (amp1 * env * math.sin(2 * math.pi * f1 * s + ph)))
        pts.append(p)
    return pts, rad

ruff = lambda amp, fq: (lambda s: amp * math.sin(2 * math.pi * fq * s) * smoothstep(0.05, 0.3, s))
rib_prof = lambda s: (0.55 + 0.45 * smoothstep(0, 0.18, s)) * (1 - s ** 2.4) * (1 - 0.25 * smoothstep(0.5, 1.0, s))

# v3 hierarchy: 3 graceful primary ribbons (front), 2 slimmer secondary ones (back), 2 crystal blades (right).
# Smooth S-curves, no ruffles, gentle twist, roots tucked into the inner bulb.
def s_spine(az, r0, length, out, amp, freq, ph, N=34, z0=-0.80, drift=(0.0, 0.0)):
    rad = Vector((math.sin(math.radians(az)), -math.cos(math.radians(az)), 0))
    tan = Vector((0, 0, 1)).cross(rad).normalized()
    base = rad * r0 + Vector((0, 0, z0))
    pts = []
    for i in range(N):
        s_ = i / (N - 1)
        env = smoothstep(0.0, 0.35, s_) * (0.55 + 0.45 * s_)          # waves grow after the root
        p_ = (base + Vector((drift[0] * s_ * s_, drift[1] * s_ * s_, -length * s_))
              + rad * (out * math.sin(math.pi * 0.5 * min(1.0, s_ * 1.4)))
              + tan * (amp * env * math.sin(2 * math.pi * freq * s_ + ph)))
        pts.append(p_)
    return pts, rad, tan

prim_prof = lambda s_: (0.80 + 0.20 * smoothstep(0, 0.14, s_)) * (1 - s_ ** 1.7)
sec_prof = lambda s_: (0.6 + 0.4 * smoothstep(0, 0.12, s_)) * (1 - s_ ** 1.5)
# primary (front / sides): different lengths, widths and phases -> no duplicated shapes
def tentacle(name, az, L, w, amp, fq, ph, drift, mat_, tr=0.74):
    sp, rad, tan = s_spine(az, 0.36, L, 0.20, amp, fq, ph, N=44, z0=-0.80, drift=drift)
    sp = [p_ + rad * (0.05 * math.sin(2 * math.pi * 1.3 * (i / 43) + ph * 0.7) * (i / 43)) for i, p_ in enumerate(sp)]
    prof = lambda s_: (0.78 + 0.22 * smoothstep(0, 0.15, s_)) * (1 - s_ ** 1.3)
    v, f = tube2(sp, lambda s_: w * prof(s_) + 0.006, lambda s_: w * tr * prof(s_) + 0.006, up_hint=rad, M=14,
                 curl=0.0, flat_bottom=1.0, ridge=0.0)
    ob = mesh_obj(name, v, f, mat_)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
    return ob
# (az, length, width, wave amp, waves, phase, drift)
prim = [(-46, 1.72, 0.33, 0.15, 1.85, 0.0, (-0.34, 0.0)),
        (-4, 1.62, 0.31, 0.15, 2.0, 0.0, (-0.04, 0.0)),
        (38, 1.50, 0.30, 0.14, 1.9, 0.0, (0.20, 0.0))]   # same phase -> parallel waves, never crossing
for i, (az, L, w, amp, fq, ph, dr) in enumerate(prim):
    o = tentacle(f"Akemi_Tentacle_Primary_{i + 1}", az, L, w, amp, fq, ph, dr, M_rib)
    link(o, C["Emissive"], root)
# secondary (behind): slimmer and shorter, supporting the silhouette
sec = [(150, 1.25, 0.24, 0.12, 1.6, 0.8), (220, 1.08, 0.21, 0.10, 1.8, 2.4)]
for i, (az, L, w, amp, fq, ph) in enumerate(sec):
    sp, rad, tan = s_spine(az, 0.36, L, 0.30, amp, fq, ph)
    o = ribbon(f"Akemi_Tentacle_Secondary_{i + 1}", sp, w, 0.026, M_sec, sec_prof, up_hint=rad, M=10, twist=0.4, curl=0.2)
    link(o, C["Emissive"], root)

# primary blades: long crystal leaves, smooth single S-curve, asymmetric toward viewer-right
def blade(name, az, length, sweep, width, bend, twist):
    rad = Vector((math.sin(math.radians(az)), -math.cos(math.radians(az)), 0))
    base = rad * 0.34 + Vector((0, 0, -0.78))
    side = Vector((1, 0, 0))
    pts = []
    for i in range(30):
        s_ = i / 29
        pts.append(base + Vector((0, 0, -length * s_)) + side * (sweep * smoothstep(0.0, 1.0, s_) ** 1.2)
                   + rad * (bend * math.sin(math.pi * s_)) + Vector((0, 0, 0.10 * math.sin(math.pi * s_))))
    prof = lambda s_: (0.28 + 0.72 * smoothstep(0, 0.30, s_)) * (1 - smoothstep(0.30, 1.0, s_)) ** 0.9 + 0.015 * (1 - s_)
    return ribbon(name, pts, width, 0.07, M_blade, prof, up_hint=Vector((0.15, -1, 0)), M=8, diamond=True,
                  twist=twist, curl=0.0)
b1 = blade("Akemi_Blade_Long", 60, 1.95, 0.55, 0.64, 0.10, 0.15)
link(b1, C["Emissive"], root)
b2 = blade("Akemi_Blade_Short", 96, 1.55, 0.42, 0.40, 0.08, -0.2)
link(b2, C["Emissive"], root)

# bell gores as real (very shallow) geometry so the segmented bell reads even in clay
bell = bpy.data.objects["Akemi_Bell"]
for v in bell.data.vertices:
    co = v.co
    if co.length < 1e-6: continue
    az_ = math.atan2(co.x, -co.y)
    g = abs(math.sin(az_ * 4.0)) ** 0.15        # 8 meridian seams
    k = 1.0 - 0.026 * (1 - g) * max(0.0, 1 - abs(co.z) / R) ** 0.3
    v.co = co.normalized() * R * k
print("Akemi objs", sum(len(c.objects) for c in C.values()))
m = bpy.data.materials["M_Akemi_Jelly"]
for nd in m.node_tree.nodes:
    if nd.type == 'MATH' and nd.operation == 'MULTIPLY' and nd.inputs[1].default_value < 2:
        nd.inputs[1].default_value = 0.35
p = m.node_tree.nodes["Principled BSDF"]
p.inputs["Coat Weight"].default_value = 0.75
p.inputs["Subsurface Weight"].default_value = 0.2
ant = bpy.data.objects["Akemi_Antenna_Loop"].data
ant.twist_mode = 'MINIMUM'; ant.bevel_resolution = 6; ant.resolution_u = 24
for sp in ant.splines: sp.use_smooth = True

# v4: softer satin visor, milkier jelly
pv_ = M_visor.node_tree.nodes["Principled BSDF"]
pv_.inputs["Roughness"].default_value = 0.42; pv_.inputs["Coat Weight"].default_value = 0.3
pv_.inputs["Base Color"].default_value = (0.03, 0.022, 0.045, 1)
p.inputs["Subsurface Weight"].default_value = 0.45
p.inputs["Roughness"].default_value = 0.18
# tentacles: solid luminous jelly (opaque + subsurface + facing glow) -> no transparency banding
pr_ = M_rib.node_tree.nodes["Principled BSDF"]
pr_.inputs["Alpha"].default_value = 1.0
pr_.inputs["Subsurface Weight"].default_value = 0.6
pr_.inputs["Subsurface Radius"].default_value = (0.6, 0.5, 1.0)
pr_.inputs["Roughness"].default_value = 0.2
M_rib.surface_render_method = 'DITHERED'; M_rib.use_backface_culling = True
