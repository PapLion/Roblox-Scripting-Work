# h3_akemi.py — v5: Akemi gets real modelled hair (run after p3_akemi.py).
# Adds the jelly-anime bob, replaces the bow with the side flower, lowers the visor, re-seats the antenna.
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
for f_ in ("lib.py", "lib2.py", "lib3.py"):
    exec(open(S_ + f_).read(), globals())
R = 1.0
root = bpy.data.objects["Akemi_Root"]
C = {s: bpy.data.collections[f"Akemi_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Akemi_Hair", "Akemi_Bow", "Akemi_Flower", "Akemi_Visor", "Akemi_XEye", "Akemi_Antenna"]))
rnd = random.Random(23)

YAW = math.radians(-5.0)          # the face is turned ~5 deg toward viewer-left in the target
RZ = Matrix.Rotation(-YAW, 3, 'Z')
def P(X, Y, r, back=False):
    """(X, Y) = pixel in the 2x crop of the target, r = distance from the body centre (body radius = 1)."""
    u = (X - 565) / 365.0; v = (545 - Y) / 365.0
    yy = math.sqrt(max(r * r - u * u - v * v, 0.0))
    return RZ @ Vector((u, yy if back else -yy, v))
FRONT = RZ @ Vector((0, -1, 0))

# ---------------- materials
M_visor = bpy.data.materials["M_Akemi_Visor"]
M_xeye = bpy.data.materials["M_Akemi_XEyeGlow"]
M_halo = bpy.data.materials["M_Akemi_XEyeHalo"]
M_ant = bpy.data.materials["M_Akemi_Antenna"]
M_bow = bpy.data.materials["M_Akemi_Bow"]
M_knot = bpy.data.materials["M_Akemi_BowKnot"]
# pearlescent pastel hair: milky periwinkle, glossy coat, soft subsurface, faint violet rim glow
M_hair = mat_gradient("M_Akemi_Hair", (0.40, 0.36, 1.0), (0.60, 0.64, 1.0), rough=0.24, coat=0.7, sss=0.35, zmin=-0.9, zmax=1.1,
                      rim=(0.50, 0.36, 1.0), rim_str=0.55)
ph_ = M_hair.node_tree.nodes["Principled BSDF"]
ph_.inputs["Subsurface Radius"].default_value = (0.5, 0.5, 1.0)
ph_.inputs["Sheen Weight"].default_value = 0.4; ph_.inputs["Sheen Tint"].default_value = (0.8, 0.7, 1.0, 1)
ph_.inputs["Roughness"].default_value = 0.34; ph_.inputs["Coat Weight"].default_value = 0.35; ph_.inputs["Coat Roughness"].default_value = 0.25
pb_ = M_bow.node_tree.nodes["Principled BSDF"]
pb_.inputs["Base Color"].default_value = (0.52, 0.36, 1.0, 1); pb_.inputs["Roughness"].default_value = 0.3
pb_.inputs["Coat Weight"].default_value = 0.5

# ---------------- body: the bell is a clean smooth sphere again (hair now carries the design, no gores)
bell = bpy.data.objects["Akemi_Bell"]
for v in bell.data.vertices:
    if v.co.length > 1e-6:
        v.co = v.co.normalized() * R

# ---------------- face: visor a little lower (room for the fringe), X eyes centred on it
VC = -6.5
visor = sphere_band("Akemi_Visor", R, lambda az: VC, lambda az: 14.5 + 2.5 * math.cos(math.radians(az)) ** 2,
                    0.034, -0.02, M_visor, seg=128, prof_n=10, pillow=0.010, subsurf=2)
link(visor, C["Face"], root)
RV = R + 0.040
for side, az in (("L", -23.7), ("R", 23.7)):
    for k, sg in enumerate((1, -1)):
        x = decal(f"Akemi_XEye_{side}_{k + 1}", outline_capsule((az - 8.2, VC + sg * 8.2), (az + 8.2, VC - sg * 8.2), 2.0, n=10),
                  RV, h_out=0.018, h_in=0.02, material=M_xeye, rings=3)
        link(x, C["Emissive"], root)
        hl = decal(f"Akemi_XEye_{side}_{k + 1}_Halo", outline_capsule((az - 8.6, VC + sg * 8.6), (az + 8.6, VC - sg * 8.6), 4.2, n=10),
                   RV, h_out=0.006, h_in=0.02, material=M_halo, rings=2)
        link(hl, C["Emissive"], root)

# ================= HAIR: soft layered bob hugging the sphere (anime hair x jellyfish) =================
def a_thick(az, el):
    return 0.075 + 0.035 * smoothstep(-10, -45, el)            # flares slightly toward the lower tips
def a_lim(az):
    return 15 - 65 * smoothstep(60, 82, abs(az))                # down to the visor's top edge in front, long at sides / back
env = Envelope(R, a_thick, a_lim, edge=lambda az: 9.0)
base = hair_base("Akemi_Hair_Base", env, M_hair, whorl=(-12, 80), n_clumps=18, groove=0.38, tip_amp=13.0, seed=2.6, hmin=0.045, warp=0.9)
link(base, C["Hair"], root)

n = 0
def L(tag, cps, w, t, **kw):
    global n; n += 1
    kw.setdefault("face", FRONT); kw.setdefault("face_k", 0.35); kw.setdefault("tip_start", 0.35); kw.setdefault("tip_pow", 1.3)
    kw.setdefault("flatness", 0.26); kw.setdefault("curl", 0.4)
    o = slock(f"Akemi_Hair_{tag}_{n:02d}", env, cps, w * 1.2, t, M_hair, **kw)
    link(o, C["Hair"], root)
    return o

# ---- fringe: one big rounded shell lock in the centre, a broad sweep to the viewer-right ending in a flick
L("P_FringeShell", [P(520, 228, 1.085), P(535, 300, 1.115), P(552, 390, 1.135), P(560, 460, 1.12), P(566, 502, 1.095)], .57, .10,
  crease={3: .16, 4: .16}, tip_start=.62, tip_pow=.6, blunt=.42, belly_at=.25, root=.6, flatness=.20, curl=.55)
L("P_SweepRight", [P(530, 225, 1.095), P(640, 250, 1.12), P(740, 320, 1.135), P(820, 410, 1.14), P(900, 480, 1.15), P(1000, 510, 1.225), P(1067, 497, 1.40)],
  .40, .11, crease={2: .2}, tip_start=.5)
L("S_SweepRight", [P(545, 240, 1.09), P(650, 320, 1.135), P(745, 405, 1.145), P(820, 455, 1.105)], .34, .11)
L("S_SideRight", [P(560, 225, 1.095), P(720, 265, 1.11), P(850, 355, 1.12), P(935, 450, 1.13), P(975, 520, 1.165)], .24, .09)
L("S_ClawRight", [P(900, 470, 1.135), P(960, 540, 1.155), P(1015, 615, 1.265), P(988, 710, 1.265)], .20, .07)
# ---- viewer-left: narrow parallel locks fanning from the whorl down to the visor's top-left edge
L("S_FanLeft", [P(490, 230, 1.09), P(390, 340, 1.115), P(320, 465, 1.105), P(255, 510, 1.095)], .21, .09)
L("S_FanLeft", [P(480, 225, 1.09), P(340, 320, 1.115), P(260, 440, 1.105), P(230, 500, 1.095)], .21, .09)
L("S_FanLeft", [P(470, 225, 1.09), P(300, 320, 1.115), P(230, 420, 1.115), P(205, 490, 1.105)], .21, .09)
# ---- below the visor: bob tips curling under on both sides (jellyfish-frill feeling)
L("P_BobRight", [P(990, 600, 1.20), P(945, 665, 1.145), P(820, 780, 1.105), P(675, 760, 1.06)], .26, .07)
L("P_BobRight", [P(1000, 640, 1.24), P(960, 690, 1.185), P(945, 815, 1.285), P(840, 885, 1.225)], .22, .07)
L("S_BobRight", [P(900, 720, 1.105), P(870, 790, 1.105), P(860, 865, 1.20), P(785, 905, 1.175)], .20, .07)
L("P_BobLeft", [P(190, 640, 1.125), P(190, 690, 1.135), P(185, 790, 1.25), P(230, 860, 1.275), P(335, 910, 1.205)], .24, .07)
L("S_BobLeft", [P(200, 700, 1.125), P(185, 800, 1.265), P(155, 790, 1.315), P(130, 760, 1.335)], .17, .06)
L("S_BobLeft", [P(240, 680, 1.085), P(255, 755, 1.085), P(300, 840, 1.105), P(360, 870, 1.075)], .20, .07)

# ---- crown layers + back bob (not visible in the target; keeps the hairstyle whole from every angle)
for i, az in enumerate((70, 100, 130, 160, 190, 220, 250, 280)):
    L("P_Crown", [(-12, 82, .015), (az - 6, 62, .02), (az, 32, .025), (az + 3, 10, .05)], .40, .09, face=None)
for i, az in enumerate(range(96, 266, 19)):
    sd = rnd.uniform(-1, 1)
    out = (i % 2 == 0)
    cps = [(az + rnd.uniform(-4, 4), 34, .01), (az + 4 * sd, -6, .02), (az + 7 * sd, -34, .03),
           (az + 9 * sd, rnd.uniform(-56, -46), .10 if out else .05), (az + 12 * sd, rnd.uniform(-66, -58), .22 if out else .03)]
    L("P_BobBack", cps, rnd.uniform(.34, .44), .10, face=None)

# ================= FLOWER at the viewer-left end of the visor (replaces the bow) =================
fl = flower("Akemi_Flower", P(122, 548, 1.27), RZ @ Vector((-0.74, -0.66, 0.05)), C["Accessories"], root, M_bow, M_knot,
            n=5, plen=0.40, pw=0.28, cup=0.30, droop=0.22, spin=math.radians(54), center_r=0.055, thick=0.05)

# ================= ANTENNA: glassy stalk rising from the front-right hair into a spiral =================
ap = [D(28, 24) * (R + 0.05), Vector((0.47, -0.84, 0.62)), Vector((0.52, -0.74, 0.93)), Vector((0.64, -0.62, 1.15)),
      Vector((0.84, -0.52, 1.30)), Vector((1.05, -0.47, 1.36)), Vector((1.18, -0.45, 1.21)), Vector((1.11, -0.45, 1.00)),
      Vector((0.92, -0.46, 0.99)), Vector((0.82, -0.47, 1.11)), Vector((0.88, -0.47, 1.23)), Vector((1.00, -0.47, 1.23)),
      Vector((1.03, -0.47, 1.16))]
ap = [ap[0]] + [RZ @ p for p in ap[1:]]
ant = curve_tube("Akemi_Antenna_Loop", ap, 0.058, M_ant, res=20, bevel_res=6)
for i, bp in enumerate(ant.data.splines[0].bezier_points):
    bp.radius = 1.0 - 0.42 * (i / (len(ap) - 1)) ** 0.8
ant.data.twist_mode = 'MINIMUM'
for sp in ant.data.splines: sp.use_smooth = True
link(ant, C["Accessories"], root)
tipb = uv_sphere("Akemi_Antenna_Tip", 0.034, M_ant, 12, 6)
tipb.location = ap[-1]
link(tipb, C["Accessories"], root)

set_ramp("M_Akemi_Jelly", (0.38, 0.32, 0.98), (0.60, 0.58, 1.0))
for nd_ in bpy.data.materials["M_Akemi_Jelly"].node_tree.nodes:
    if nd_.type == 'BUMP': nd_.inputs["Strength"].default_value = 0.0      # smooth body: the old painted gore seams are gone
pt_ = bpy.data.materials["M_Akemi_Tentacle"].node_tree.nodes["Principled BSDF"]
pt_.inputs["Base Color"].default_value = (0.50, 0.34, 1.0, 1)
pt_.inputs["Emission Color"].default_value = (0.50, 0.28, 1.0, 1)
face_camera("Akemi")
print("Akemi hair objs", len(C["Hair"].objects))
