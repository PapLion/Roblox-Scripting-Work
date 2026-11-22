# h2_yoru.py — v5 hairstyle reconstruction for Yoru (run after p2_yoru.py; replaces hair, flower, eyes/blush decals)
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
for f_ in ("lib.py", "lib2.py", "lib3.py"):
    exec(open(S_ + f_).read(), globals())
R = 0.85
root = bpy.data.objects["Yoru_Root"]
C = {s: bpy.data.collections[f"Yoru_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Yoru_Hair", "Yoru_Rosette", "Yoru_Flower", "Yoru_Eye", "Yoru_Blush", "Yoru_Lash", "Yoru_Brow"]))
rnd = random.Random(5)

# ---------------- materials
M_blond = bpy.data.materials["M_Yoru_HairBlond"]
M_brown = bpy.data.materials["M_Yoru_HairBrown"]
set_ramp("M_Yoru_HairBlond", (0.93, 0.68, 0.58), (1.0, 0.86, 0.78))          # peachy cream, like the target
M_brown.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.17, 0.085, 0.07, 1)
for m_ in (M_blond, M_brown):                # soft satin hair, no plastic highlights
    p_ = m_.node_tree.nodes["Principled BSDF"]
    p_.inputs["Roughness"].default_value = 0.62; p_.inputs["Specular IOR Level"].default_value = 0.28
set_ramp("M_Yoru_Skin", (0.80, 0.60, 0.60), (1.0, 0.89, 0.86))          # rosy cream, like the target
pa_ = bpy.data.materials["M_Yoru_AmberGlow"].node_tree.nodes["Principled BSDF"]
pa_.inputs["Base Color"].default_value = (1.0, 0.50, 0.12, 1)
pa_.inputs["Emission Color"].default_value = (1.0, 0.42, 0.08, 1); pa_.inputs["Emission Strength"].default_value = 0.5
M_base = bpy.data.materials.get("M_Yoru_HairBase") or mat("M_Yoru_HairBase", (0.12, 0.068, 0.062), rough=0.5)
M_base.node_tree.nodes["Principled BSDF"].inputs["Sheen Weight"].default_value = 0.2
M_petal = bpy.data.materials["M_Yoru_Rosette"]
pp_ = M_petal.node_tree.nodes["Principled BSDF"]
pp_.inputs["Base Color"].default_value = (1.0, 0.90, 0.87, 1); pp_.inputs["Subsurface Weight"].default_value = 0.3
pp_.inputs["Roughness"].default_value = 0.45
M_amber = bpy.data.materials["M_Yoru_AmberGlow"]
M_hl = bpy.data.materials["M_Yoru_EyeHighlight"]
M_blush = bpy.data.materials["M_Yoru_Blush"]
M_eye = bpy.data.materials["M_Yoru_Eye"]
M_lash = bpy.data.materials["M_Yoru_Lash"]
M_stroke = bpy.data.materials["M_Yoru_BlushStroke"]

# ---------------- target-image authoring: (X, Y) = pixel in the 2x crop of the target, r in head radii
def P(X, Y, r, back=False):
    u = (X - 525) / 300.0; v = (590 - Y) / 300.0
    yy = math.sqrt(max(r * r - u * u - v * v, 0.0))
    return Vector((u, yy if back else -yy, v)) * R
FRONT = Vector((0, -1, 0))

# ================= FACE (target proportions: big glossy eyes on the equator, small blush, tiny brows) ========
EV = 1.5
for side, az in (("L", -24), ("R", 24)):
    sg = -1 if side == "L" else 1
    e = decal(f"Yoru_Eye_{side}", outline_ellipse(az, EV, 10.6, 15.2, n=36), R, h_out=0.032, material=M_eye, rings=5)
    link(e, C["Face"], root)
    for k, (a0, e0, a1, e1) in enumerate(((8.6, 10.5, 12.8, 13.2), (9.9, 7.4, 13.8, 8.6))):
        pts = [D(az + sg * (a0 + (a1 - a0) * t), EV + e0 + (e1 - e0) * t + 0.8 * math.sin(math.pi * t)) * (R + 0.022) for t in (0, 0.5, 1.0)]
        ls = curve_tube(f"Yoru_Lash_{side}_{k + 1}", pts, 0.009, M_lash, taper_end=True)
        link(ls, C["Face"], root)
    h1 = decal(f"Yoru_EyeHighlight_{side}_Big", outline_ellipse(az + 3.4, EV + 6.2, 3.9, 5.0, rot=0.3, n=20), R, h_out=0.042, material=M_hl)
    link(h1, C["Face"], root)
    h2 = decal(f"Yoru_EyeHighlight_{side}_Small", outline_ellipse(az - 4.0, EV - 8.2, 1.7, 2.0, n=12), R, h_out=0.042, material=M_hl)
    link(h2, C["Face"], root)
    bc = (az + sg * 15, -14.5)
    b = decal(f"Yoru_Blush_{side}", outline_ellipse(bc[0], bc[1], 5.6, 3.5, n=24), R, h_out=0.008, material=M_blush)
    link(b, C["Face"], root)
    for k in range(3):
        x0 = bc[0] - 3.0 + 3.0 * k
        st = decal(f"Yoru_BlushStroke_{side}_{k + 1}", outline_capsule((x0 - 0.9, bc[1] - 1.9), (x0 + 0.9, bc[1] + 1.9), 0.6, n=6),
                   R, h_out=0.012, material=M_stroke, rings=2)
        link(st, C["Face"], root)
    br = decal(f"Yoru_Brow_{side}", outline_capsule((az - sg * 1.0, 26.0), (az + sg * 5.0, 26.8), 0.8, n=6), R, h_out=0.010,
               material=M_brown, rings=2)
    link(br, C["Face"], root)

# ================= HAIR =================
env = Envelope(R, ellipsoid_thick(R, (0.0, 0.04, 0.04), (1.22 * R, 1.18 * R, 1.18 * R), tmin=0.10),
               lambda az: 52 - 94 * smoothstep(35, 95, abs(az)), edge=lambda az: 22 - 12 * smoothstep(40, 95, abs(az)))
base = hair_base("Yoru_Hair_Base", env, M_base, whorl=(-10, 75), n_clumps=18, groove=0.28, tip_amp=11.0, seed=1.9)
link(base, C["Hair"], root)

n = 0
def L(tag, m, cps, w, t, **kw):
    global n; n += 1
    kw.setdefault("face", FRONT); kw.setdefault("tip_start", 0.32); kw.setdefault("tip_pow", 1.4)
    o = slock(f"Yoru_Hair_{tag}_{n:02d}", env, cps, w * R * 1.25, t * R, m, **kw)
    link(o, C["Hair"], root)
    return o

# ---- dark brown fringe: a wedge right of the parting with three pointed tips (drawn first: lies under the cream)
L("P_FringeBrown", M_brown, [P(482, 268, 1.28), P(488, 350, 1.17), P(503, 415, 1.10), P(516, 462, 1.05)], .44, .11, tip_start=.22, tip_pow=1.5, crease={2: .2})
L("P_FringeBrown", M_brown, [P(500, 270, 1.28), P(552, 360, 1.17), P(596, 440, 1.09), P(616, 498, 1.05)], .34, .10, tip_start=.22, tip_pow=1.5)
L("P_FringeBrown", M_brown, [P(520, 275, 1.28), P(620, 380, 1.17), P(690, 480, 1.09), P(712, 541, 1.05)], .24, .09, tip_start=.22, tip_pow=1.5)
# ---- cream: big asymmetric fringe sweeping to the viewer-left, ending in a flick under the flower
L("P_FringeLeft", M_blond, [P(472, 268, 1.31), P(385, 362, 1.21), P(290, 452, 1.15), P(190, 512, 1.24), P(122, 520, 1.38), P(68, 458, 1.60)],
  .64, .13, crease={5: .18}, tip_start=.45, tip_pow=1.25, flatness=0.22, curl=0.42)
L("S_TopLeft", M_blond, [P(465, 252, 1.33), P(340, 286, 1.38), P(240, 336, 1.42), P(185, 392, 1.44)], .30, .09, flatness=0.22, curl=0.42)
L("S_TopLeft", M_blond, [P(470, 238, 1.345), P(370, 240, 1.415), P(260, 275, 1.49), P(170, 312, 1.59)], .24, .08, flatness=0.22, curl=0.42)
L("T_TopLeftBrown", M_brown, [P(460, 262, 1.30), P(320, 278, 1.365), P(225, 332, 1.405)], .12, .07)
# ---- cream: big lock sweeping to the viewer-right over the brown fringe, flicked tips
L("P_SweepRight", M_blond, [P(475, 262, 1.33), P(600, 268, 1.36), P(715, 332, 1.35), P(790, 420, 1.33), P(840, 490, 1.36), P(888, 515, 1.45), P(975, 482, 1.63)],
  .58, .13, crease={2: .18}, tip_start=.5, tip_pow=1.25, flatness=0.22, curl=0.42)
L("S_SweepRight", M_blond, [P(640, 300, 1.31), P(722, 400, 1.25), P(752, 480, 1.18), P(737, 546, 1.11)], .26, .10)
L("P_TopRight", M_blond, [P(480, 250, 1.34), P(570, 225, 1.39), P(680, 235, 1.41), P(780, 290, 1.43), P(850, 335, 1.46), P(890, 312, 1.57)],
  .30, .10, tip_start=.45, tip_pow=1.25, flatness=0.22, curl=0.42)
# ---- viewer-right side: cream locks hanging over the scarf, brown under-layer against the face
L("S_RightUnder", M_brown, [P(760, 470, 1.14), P(800, 600, 1.14), P(815, 720, 1.16), P(800, 800, 1.20)], .30, .10)
L("S_RightUnder", M_brown, [P(800, 700, 1.20), P(790, 830, 1.22), P(740, 930, 1.30), P(700, 990, 1.38)], .16, .08)
L("P_SideRight", M_blond, [P(820, 440, 1.36), P(866, 540, 1.38), P(905, 615, 1.39), P(900, 690, 1.37)], .19, .08, tip_start=.3)
L("P_SideRight", M_blond, [P(790, 520, 1.29), P(840, 640, 1.31), P(850, 740, 1.33), P(880, 795, 1.39), P(925, 822, 1.51), P(972, 820, 1.63)], .21, .08, tip_start=.3)
# ---- viewer-left side: cream locks under the flower, lower flick, brown under-layer
L("S_LeftUnder", M_brown, [P(250, 480, 1.12), P(215, 600, 1.13), P(205, 700, 1.15), P(225, 780, 1.18)], .28, .10)
L("P_SideLeft", M_blond, [P(190, 440, 1.33), P(128, 535, 1.41), P(92, 620, 1.47), P(100, 716, 1.47)], .19, .08, tip_start=.3)
L("P_SideLeft", M_blond, [P(225, 470, 1.26), P(188, 590, 1.26), P(172, 700, 1.27), P(200, 764, 1.25)], .19, .08, tip_start=.3)
L("P_SideLeft", M_blond, [P(215, 600, 1.28), P(184, 720, 1.31), P(140, 795, 1.43), P(96, 806, 1.57)], .19, .08, tip_start=.3)

# ---- back (not visible in the target): layered cream bob with flicked tips over brown under-tips
for i, az in enumerate(range(100, 262, 20)):
    sd = rnd.uniform(-1, 1)
    cps = [(az + rnd.uniform(-5, 5), 80, .02), (az + 5 * sd, 45, .035), (az + 8 * sd, 5, .05), (az + 9 * sd, rnd.uniform(-26, -16), .09),
           (az + 10 * sd, rnd.uniform(-38, -28), rnd.uniform(.20, .30))]
    L("P_BackCream", M_blond, cps, rnd.uniform(.46, .56), .12, face=None)
for i, az in enumerate((128, 162, 198, 232)):
    L("P_Crown", M_blond, [(-6, 84, .03), (az, 72, .035), (az + 4, 44, .05), (az + 6, 26, .20)], .50, .12, face=None)
for i, az in enumerate(range(106, 256, 25)):
    sd = rnd.uniform(-1, 1)
    L("S_BackUnder", M_brown, [(az, 6, -.03), (az + 3 * sd, -24, .0), (az + 6 * sd, rnd.uniform(-50, -42), .09)], .34, .10, face=None)

# ---- ahoge: plump curved hook
L("Ahoge", M_blond, [P(505, 235, 1.24), P(510, 210, 1.30), P(500, 150, 1.47), P(535, 90, 1.67), P(600, 67, 1.76), P(645, 90, 1.72), P(657, 132, 1.59)],
  .095, .09, flatness=0.85, sharp=1.0, curl=0.0, flat=0.5, ridge=0.0, root=0.9, belly_at=0.1, tip_start=.45, tip_pow=1.0)
# ---- thin brown loop strand arcing out at the top-left, ending behind the flower
lp = [(400, 215), (320, 180), (235, 190), (175, 230), (152, 280), (155, 335), (166, 385)]
pts = []
for X, Y in lp:
    u = (X - 525) / 300.0; v = (590 - Y) / 300.0
    pts.append(P(X, Y, math.hypot(u, v) * 1.012))
M_loop = bpy.data.materials.get("M_Yoru_HairLoop") or mat("M_Yoru_HairLoop", (0.36, 0.17, 0.08), rough=0.3, coat=0.5)
loop = curve_tube("Yoru_Hair_Loop", pts, 0.028, M_loop, res=16)
link(loop, C["Hair"], root)

# ================= FLOWER: five puffy petals + amber centre, on the viewer-left side =================
flower("Yoru_Flower", P(165, 425, 1.42), Vector((-0.40, -0.90, 0.12)), C["Accessories"], root, M_petal, M_amber,
       n=5, plen=0.245, pw=0.25, cup=0.20, droop=0.14, spin=math.radians(18), center_r=0.065, thick=0.05)
# ================= SCARF: bulkier, rounder rolls like the target (thicken the existing wraps in place) ======
for nm, cz, k, dz in (("Yoru_Scarf_Wrap_Mid", -0.60, 1.30, -0.03), ("Yoru_Scarf_Wrap_Low", -0.75, 1.30, -0.10)):
    o_ = bpy.data.objects.get(nm)
    if o_ and not o_.get("v5_thick"):
        for v_ in o_.data.vertices:
            v_.co.z = cz + (v_.co.z - cz) * k + dz
        o_["v5_thick"] = True
face_camera("Yoru")
print("Yoru hair objs", len(C["Hair"].objects))
