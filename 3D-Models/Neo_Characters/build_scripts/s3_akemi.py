exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
import random
random.seed(5)
R = 1.0
root, C = char_setup("Akemi", (2.9, 0.0, 1.05))

# ---- materials
M_jelly = mat_gradient("M_Akemi_Jelly", (0.26, 0.32, 0.95), (0.60, 0.64, 1.0), rough=0.12, coat=1.0,
                       sss=0.15, zmin=-1.0, zmax=1.0, rim=(0.30, 0.55, 1.0), rim_str=0.7)
nt = M_jelly.node_tree
p = nt.nodes["Principled BSDF"]
p.inputs["Coat Roughness"].default_value = 0.05
# subtle bell "gores": thin grooves along meridians
tc = nt.nodes.new("ShaderNodeTexCoord")
gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = 'RADIAL'
m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = 'MULTIPLY'; m1.inputs[1].default_value = math.pi * 8
m2 = nt.nodes.new("ShaderNodeMath"); m2.operation = 'SINE'
m3 = nt.nodes.new("ShaderNodeMath"); m3.operation = 'ABSOLUTE'
m4 = nt.nodes.new("ShaderNodeMath"); m4.operation = 'POWER'; m4.inputs[1].default_value = 0.2
bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.25; bp.inputs["Distance"].default_value = 0.02
nt.links.new(tc.outputs["Object"], gr.inputs["Vector"])
nt.links.new(gr.outputs["Fac"], m1.inputs[0]); nt.links.new(m1.outputs[0], m2.inputs[0])
nt.links.new(m2.outputs[0], m3.inputs[0]); nt.links.new(m3.outputs[0], m4.inputs[0])
nt.links.new(m4.outputs[0], bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"], p.inputs["Normal"])

M_visor = mat("M_Akemi_Visor", (0.025, 0.022, 0.04), rough=0.3, coat=0.8)
M_xeye = mat_emit("M_Akemi_XEyeGlow", (0.50, 0.16, 1.0), 3.0)
M_bow = mat("M_Akemi_Bow", (0.50, 0.30, 0.98), rough=0.4, sss=0.2, emit=(0.5, 0.3, 1.0), emit_str=0.3)
M_knot = mat("M_Akemi_BowKnot", (0.08, 0.06, 0.14), rough=0.35, coat=0.5)
M_ant = mat("M_Akemi_Antenna", (0.40, 0.46, 1.0), rough=0.15, coat=1.0, emit=(0.35, 0.40, 1.0), emit_str=0.8)

def ribbon_mat(name, c_root, c_tip, emit_c, emit_s, alpha):
    m = mat_gradient(name, c_tip, c_root, rough=0.18, coat=0.5, zmin=-2.2, zmax=-0.7,
                     rim=emit_c, rim_str=emit_s)
    pn = m.node_tree.nodes["Principled BSDF"]
    pn.inputs["Alpha"].default_value = alpha
    pn.inputs["Subsurface Weight"].default_value = 0.2
    m.surface_render_method = 'BLENDED'
    m.use_transparency_overlap = True
    m.use_backface_culling = False
    return m
M_tent = ribbon_mat("M_Akemi_Tentacle", (0.45, 0.36, 1.0), (0.25, 0.50, 1.0), (0.38, 0.22, 1.0), 2.0, 0.6)
M_blade = ribbon_mat("M_Akemi_Blade", (0.48, 0.42, 1.0), (0.28, 0.62, 1.0), (0.30, 0.45, 1.0), 2.4, 0.55)

# ---- core: bell + frilled margin
head = uv_sphere("Akemi_Bell", R, M_jelly, 64, 32)
md = head.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
link(head, C["Core"], root)
frill = revolve("Akemi_BellFrill", circle_profile(0.50, -0.86, 0.10, 0.05, 10), 96, M_tent,
                wobble=lambda th, i: 1 + 0.06 * math.sin(12 * th))
link(frill, C["Core"], root)

# ---- face: visor band (revolved, rounded edges) + glowing X eyes
TILT = (math.radians(3), math.radians(-5), 0)
prof = []
lat0, lat1, n_ = -13.0, 19.0, 10
for i in range(n_ + 1):  # outer arc
    t = i / n_
    lat = lat0 + (lat1 - lat0) * t
    edge = 1 - math.sin(math.pi * t) ** 0.35
    off = 0.055 - 0.035 * edge
    r = R + off
    prof.append((r * math.cos(math.radians(lat)), r * math.sin(math.radians(lat))))
for i in range(n_ + 1):  # inner arc back (hidden inside bell)
    t = 1 - i / n_
    lat = lat0 + (lat1 - lat0) * t
    r = R - 0.02
    prof.append((r * math.cos(math.radians(lat)), r * math.sin(math.radians(lat))))
visor = revolve("Akemi_Visor", prof, 96, M_visor, subsurf=1)
visor.rotation_euler = TILT
link(visor, C["Face"], root)

RV = R + 0.055
for side, az in (("L", -21), ("R", 21)):
    for k, (a0, a1) in enumerate((((-6.5, 9.5), (6.5, -3.5)), ((-6.5, -3.5), (6.5, 9.5)))):
        x = decal(f"Akemi_XEye_{side}_{k + 1}",
                  outline_capsule((az + a0[0], a0[1]), (az + a1[0], a1[1]), 1.7, n=8), RV,
                  h_out=0.014, h_in=0.02, material=M_xeye)
        x.rotation_euler = TILT
        link(x, C["Emissive"], root)

# ---- accessories: violet bow on the visor (viewer-left side)
bc = D(-96, 3) * (R + 0.07)
nrm = D(-96, 3)
rm = look_rot(nrm).to_matrix()
for k, a in enumerate((35, 145, 215, 325)):
    ar = math.radians(a)
    pt = uv_sphere(f"Akemi_Bow_Petal_{k + 1}", 0.16, M_bow, 20, 10)
    pt.location = bc + rm @ Vector((math.cos(ar) * 0.17, math.sin(ar) * 0.17, 0.03))
    pt.rotation_euler = (rm @ Matrix.Rotation(ar, 3, 'Z')).to_euler()
    pt.scale = (1.35, 0.72, 0.42)
    link(pt, C["Accessories"], root)
knot = uv_sphere("Akemi_Bow_Knot", 0.06, M_knot, 16, 8)
knot.location = bc + nrm * 0.05
knot.scale = (1, 1, 0.8)
link(knot, C["Accessories"], root)
for k, (dx, dz) in enumerate(((-0.05, -0.28), (0.07, -0.25))):
    tp = [bc + nrm * 0.04, bc + nrm * 0.07 + rm @ Vector((dx * 0.5, dz * 0.5, 0)) * 1.0,
          bc + nrm * 0.06 + rm @ Vector((dx, dz, 0))]
    # tails hang in world -Z; rm's local Y ~ world up for side-facing normal
    tl = spine_lock(f"Akemi_Bow_Tail_{k + 1}", catmull(tp, 4), width=0.07, thick=0.02, material=M_bow,
                    profile=lambda s: 1.0 - 0.5 * s, up_hint=nrm, crescent=0.0)
    link(tl, C["Accessories"], root)

# antenna loop rising from the visor's right side, curling into a loop above the head
ap = [D(92, 6) * (R + 0.04), D(80, 30) * (R + 0.06), D(62, 52) * (R + 0.09),
      Vector((0.52, -0.08, 1.02)), Vector((0.70, -0.05, 1.32)), Vector((0.98, 0.0, 1.38)),
      Vector((1.08, 0.04, 1.16)), Vector((0.92, 0.06, 1.02)), Vector((0.78, 0.04, 1.16)),
      Vector((0.86, 0.0, 1.30))]
ant = curve_tube("Akemi_Antenna_Loop", ap, 0.046, M_ant, taper_end=True)
link(ant, C["Accessories"], root)
tipb = uv_sphere("Akemi_Antenna_Tip", 0.038, M_ant, 12, 6)
tipb.location = ap[-1]
link(tipb, C["Accessories"], root)

# ---- emissive appendages: wavy translucent ribbons
def tentacle(name, az, length, amp, freq, phase, width, mat_, el=-62, outward=0.22):
    base = D(az, el) * (R * 0.93)
    rad = Vector((base.x, base.y, 0)).normalized()
    tan = Vector((0, 0, 1)).cross(rad).normalized()
    pts = []
    N = 26
    for i in range(N):
        s = i / (N - 1)
        z = -length * s
        w = amp * math.sin(2 * math.pi * freq * s + phase) * (0.3 + 0.7 * s)
        pts.append(base + Vector((0, 0, z)) + rad * (outward * s + 0.05 * math.sin(3 * s + phase)) + tan * w)
    prof = lambda s: (0.65 + 0.35 * smoothstep(0, 0.15, s)) * (1 - s ** 2.2)
    o = spine_lock(name, pts, width=width, thick=0.035, material=mat_, profile=prof, up_hint=rad,
                   crescent=0.15, M=8, twist=0.6)
    return o

cfg = [(-40, 1.75, 0.12, 1.6, 0.0), (-5, 1.90, 0.13, 1.4, 1.2), (30, 1.70, 0.11, 1.7, 2.3),
       (-80, 1.50, 0.10, 1.8, 0.7), (150, 1.60, 0.12, 1.5, 2.9), (200, 1.75, 0.12, 1.6, 0.4),
       (250, 1.55, 0.11, 1.7, 1.8)]
for i, (az, L_, amp, fq, ph) in enumerate(cfg):
    t = tentacle(f"Akemi_Tentacle_{i + 1:02d}", az, L_ * 0.92, amp, fq, ph, 0.26, M_tent)
    link(t, C["Emissive"], root)

# long pointed blade-like appendages: asymmetric silhouette (viewer-right)
def blade(name, az, length, sweep_x, width, bend):
    base = D(az, -55) * (R * 0.9)
    rad = Vector((base.x, base.y, 0)).normalized()
    pts = []
    for i in range(22):
        s = i / 21
        pts.append(base + Vector((sweep_x * s ** 1.3, 0, -length * s)) + rad * (bend * math.sin(math.pi * s * 0.8)))
    prof = lambda s: (math.sin(math.pi * min(1.0, s ** 0.6)) ** 0.7) * (1 - 0.15 * s) + 0.08 * (1 - s)
    return spine_lock(name, pts, width=width, thick=0.045, material=M_blade, profile=prof, up_hint=Vector((0.15, -1, 0)),
                      crescent=0.3, M=8)
b1 = blade("Akemi_Blade_Long", 62, 2.05, 0.75, 0.46, 0.18)
link(b1, C["Emissive"], root)
b2 = blade("Akemi_Blade_Short", 112, 1.6, 0.45, 0.38, 0.12)
link(b2, C["Emissive"], root)

print("Akemi objects:", sum(len(c.objects) for c in C.values()))
