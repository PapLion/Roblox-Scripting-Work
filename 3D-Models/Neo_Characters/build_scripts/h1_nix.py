# h1_nix.py — v5 hairstyle reconstruction for Nix (run after p1_nix.py; replaces all Nix hair, ears, ring, eyes)
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
for f_ in ("lib.py", "lib2.py", "lib3.py"):
    exec(open(S_ + f_).read(), globals())
R = 1.0
root = bpy.data.objects["Nix_Root"]
C = {s: bpy.data.collections[f"Nix_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Nix_Hair", "Nix_CatEar", "Nix_HatBase", "Nix_OrbitRing", "Nix_Lid", "Nix_Pupil", "Nix_EyeHighlight"]))
rnd = random.Random(11)

# ---------------- materials: charcoal / mid lavender-grey / pale silver-lavender
M_dark = bpy.data.materials["M_Nix_HairDark"]
M_pale = bpy.data.materials["M_Nix_HairPale"]
M_mid = bpy.data.materials.get("M_Nix_HairMid") or mat("M_Nix_HairMid", (0.24, 0.19, 0.40), rough=0.42)
pm = M_mid.node_tree.nodes["Principled BSDF"]
pm.inputs["Base Color"].default_value = (0.24, 0.19, 0.40, 1)
pm.inputs["Sheen Weight"].default_value = 0.35; pm.inputs["Sheen Tint"].default_value = (0.75, 0.6, 1.0, 1)
if not any(n_.type == 'LAYER_WEIGHT' for n_ in M_mid.node_tree.nodes):
    add_rim(M_mid, (0.55, 0.35, 1.0), 0.08)
M_dark.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.055, 0.048, 0.075, 1)
set_ramp("M_Nix_HairPale", (0.48, 0.41, 0.80), (0.72, 0.66, 0.95))
for m_ in (M_dark, M_pale, M_mid):          # soft satin hair, no plastic highlights
    p_ = m_.node_tree.nodes["Principled BSDF"]
    p_.inputs["Roughness"].default_value = 0.62; p_.inputs["Specular IOR Level"].default_value = 0.28
set_ramp("M_Nix_Skin", (0.28, 0.22, 0.56), (0.58, 0.52, 0.88))
ps_ = bpy.data.materials["M_Nix_Skin"].node_tree.nodes["Principled BSDF"]
ps_.inputs["Roughness"].default_value = 0.7; ps_.inputs["Specular IOR Level"].default_value = 0.2; ps_.inputs["Coat Weight"].default_value = 0.0
M_base = bpy.data.materials.get("M_Nix_HairBase") or mat("M_Nix_HairBase", (0.10, 0.085, 0.16), rough=0.5)
M_base.node_tree.nodes["Principled BSDF"].inputs["Sheen Weight"].default_value = 0.3

# ---------------- target-image authoring: (X, Y) = pixel in the 2x crop of the target, r = distance from head centre
YAW = math.radians(5.0)          # the face is turned ~5 deg toward viewer-right in the target
RZ = Matrix.Rotation(-YAW, 3, 'Z')
def P(X, Y, r, back=False):
    u = (X - 700) / 305.0; v = (700 - Y) / 305.0
    yy = math.sqrt(max(r * r - u * u - v * v, 0.0))
    return RZ @ Vector((u, yy if back else -yy, v))

# ---------------- envelope: big messy mass, tallest at the crown, heavier on the viewer-left
n_thick = ellipsoid_thick(R, RZ @ Vector((-0.17, 0.05, 0.45)), (1.24, 1.18, 1.07), tmin=0.11)   # sits just under the lock layer
def n_lim(az):
    return 46 - 80 * smoothstep(52, 105, abs(az))             # forehead hairline -> nape
env = Envelope(R, n_thick, n_lim, edge=lambda az: 26 - 16 * smoothstep(50, 100, abs(az)))
base = hair_base("Nix_Hair_Base", env, M_base, whorl=(-40, 72), n_clumps=22, groove=0.32, tip_amp=13.0, seed=0.7)
link(base, C["Hair"], root)

n = 0
FRONT = RZ @ Vector((0, -1, 0))
def L(tag, m, cps, w, t, **kw):
    global n; n += 1
    kw.setdefault("face", FRONT); kw.setdefault("tip_start", 0.3); kw.setdefault("tip_pow", 1.5)
    o = slock(f"Nix_Hair_{tag}_{n:02d}", env, cps, w * 1.28, t, m, **kw)
    link(o, C["Hair"], root)
    return o

# ================= FRONT: dark charcoal fringe, five spiky leaves fanning from the parting =================
L("P_FringeDark", M_dark, [P(545, 290, 1.46), P(520, 430, 1.20), P(500, 540, 1.10), P(495, 625, 1.06)], .38, .10, tip_pow=1.25)
L("P_FringeDark", M_dark, [P(550, 280, 1.48), P(590, 440, 1.19), P(608, 560, 1.09), P(612, 632, 1.06)], .44, .11, tip_pow=1.25)
L("P_FringeDark", M_dark, [P(560, 290, 1.46), P(640, 460, 1.17), P(680, 580, 1.08), P(692, 655, 1.05)], .46, .11, tip_pow=1.25)
L("P_FringeDark", M_dark, [P(570, 295, 1.45), P(690, 440, 1.17), P(745, 540, 1.08), P(765, 612, 1.05)], .40, .10, tip_pow=1.25)
L("P_FringeDark", M_dark, [P(580, 300, 1.44), P(740, 450, 1.16), P(820, 560, 1.08), P(844, 634, 1.05)], .36, .10, tip_pow=1.25)
L("S_LeftUnder", M_dark, [P(470, 330, 1.48), P(430, 430, 1.38), P(400, 560, 1.22), P(410, 680, 1.09)], .30, .10)
L("S_LeftUnder", M_dark, [P(510, 320, 1.47), P(480, 420, 1.30), P(468, 540, 1.14), P(480, 640, 1.07)], .28, .10)
# ================= pale silver sweep: leaves fanning from the parting toward the viewer-right =================
L("P_PaleFringe", M_pale, [P(565, 320, 1.46), P(685, 430, 1.29), P(820, 520, 1.20), P(930, 605, 1.12), P(975, 668, 1.07)], .48, .12, crease={2: .22})
L("S_PaleFringe", M_pale, [P(900, 420, 1.37), P(975, 520, 1.26), P(1005, 600, 1.16), P(1010, 650, 1.10)], .26, .10)
L("P_PaleSweep", M_pale, [P(560, 280, 1.52), P(695, 320, 1.53), P(845, 370, 1.49), P(960, 430, 1.45), P(1012, 462, 1.45)], .44, .12, crease={5: .22})
L("P_PaleTop", M_pale, [P(555, 265, 1.54), P(670, 232, 1.60), P(820, 228, 1.65), P(945, 262, 1.69), P(1020, 296, 1.75), P(1070, 250, 1.93)], .28, .09, flatness=0.22)

# ================= VIEWER-LEFT: mid lavender mass sweeping out, thin curved flicked tips =================
L("P_LeftLeaf", M_mid, [P(550, 275, 1.54), P(440, 360, 1.56), P(320, 460, 1.60), P(235, 532, 1.68)], .58, .13, crease={2: .2, 5: .2})
L("P_LeftLeaf", M_mid, [P(535, 300, 1.48), P(430, 420, 1.48), P(330, 520, 1.52), P(268, 592, 1.58)], .46, .12)
L("S_LeftFlick", M_mid, [P(430, 290, 1.63), P(360, 240, 1.88), P(270, 270, 2.0), P(200, 310, 2.1), P(175, 335, 2.13)], .18, .08)
L("S_LeftFlick", M_mid, [P(420, 330, 1.60), P(360, 340, 1.67), P(260, 400, 1.77), P(190, 430, 1.9), P(160, 428, 2.0)], .26, .10)
L("S_LeftFlick", M_mid, [P(360, 420, 1.54), P(290, 440, 1.61), P(200, 480, 1.80), P(140, 490, 1.97), P(120, 482, 2.04)], .28, .10)
L("P_LeftPale", M_pale, [P(400, 470, 1.42), P(330, 520, 1.44), P(250, 580, 1.57), P(160, 600, 1.80), P(112, 585, 1.97), P(105, 568, 2.0)], .36, .12)
L("S_LeftHang", M_pale, [P(330, 470, 1.44), P(290, 540, 1.44), P(240, 620, 1.57), P(205, 700, 1.64), P(195, 745, 1.67)], .30, .11)
L("S_LeftHang", M_mid, [P(330, 540, 1.38), P(300, 620, 1.37), P(290, 720, 1.38), P(305, 820, 1.38), P(325, 885, 1.38)], .30, .11)
L("S_LeftHang", M_dark, [P(340, 640, 1.30), P(340, 740, 1.27), P(355, 840, 1.27), P(385, 940, 1.30), P(420, 1010, 1.38)], .26, .10)
L("S_LeftTrail", M_dark, [P(400, 760, 1.16, True), P(420, 860, 1.16, True), P(450, 950, 1.21, True), P(500, 1050, 1.35, True), P(540, 1110, 1.45, True)], .22, .09)
L("S_LeftFrame", M_pale, [P(350, 500, 1.37), P(335, 580, 1.31), P(350, 680, 1.21), P(400, 770, 1.09), P(490, 825, 1.045)], .26, .09)

# ================= VIEWER-RIGHT: curved claws behind the pale sweep + long dark trailing strands =================
L("S_RightCurve", M_mid, [P(880, 240, 1.68), P(950, 270, 1.71), P(1040, 330, 1.71), P(1100, 420, 1.67), P(1120, 530, 1.57)], .26, .10)
L("S_RightCurve", M_mid, [P(940, 360, 1.48), P(1000, 440, 1.44), P(1070, 540, 1.41), P(1085, 620, 1.35), P(1075, 662, 1.30)], .26, .10)
L("S_RightLong", M_dark, [P(990, 500, 1.24), P(1010, 620, 1.13), P(1000, 780, 1.08), P(940, 930, 1.12), P(800, 1070, 1.30), P(655, 1135, 1.46)], .20, .09)
L("S_RightLong", M_dark, [P(1010, 470, 1.31), P(1040, 560, 1.27), P(1060, 700, 1.21), P(1030, 840, 1.18), P(985, 925, 1.20)], .22, .09)
L("S_RightLong", M_mid, [P(1040, 520, 1.35), P(1075, 600, 1.33), P(1110, 720, 1.30), P(1095, 800, 1.28)], .16, .08)
L("S_RightTrail", M_dark, [P(960, 800, 1.13, True), P(900, 900, 1.11, True), P(840, 980, 1.16, True), P(770, 1025, 1.20, True)], .20, .09)

# ================= BACK (not visible in the target: designed to hold up from every angle) =================
# inner row: long dark locks hanging below the body (read from the front as thin trailing strands)
for i, az in enumerate(range(104, 262, 22)):
    sd = rnd.uniform(-1, 1)
    elt = rnd.uniform(-76, -54)
    rt = rnd.uniform(1.36, 1.78)
    cps = [(az + rnd.uniform(-4, 4), 62, .00), (az + 4 * sd, 28, .02), (az + 8 * sd, -12, .04), (az + 9 * sd, -36, .12),
           D(az + 10 * sd, (elt - 36) * 0.5) * (1.12 + 0.3 * (rt - 1.12)), D(az + 16 * sd, elt) * rt + Vector((0.10 * sd, 0, -0.04))]
    L("S_BackLong", M_dark, cps, rnd.uniform(.30, .40), .11, face=None, tip_start=.5, tip_pow=1.2)
# outer row: shorter mid / pale layers with flicked tips
for i, az in enumerate(range(104, 268, 20)):
    sd = rnd.uniform(-1, 1)
    m_ = M_pale if i % 3 == 1 else M_mid
    cps = [(az + rnd.uniform(-5, 5), 78, .02), (az + 5 * sd, 48, .04), (az + 9 * sd, 14, .07),
           (az + 10 * sd, rnd.uniform(-8, 4), rnd.uniform(.22, .36))]
    L("P_BackOuter", m_, cps, rnd.uniform(.46, .58), .13, face=None)
# crown: leaves radiating backward from the whorl
for i, az in enumerate((118, 150, 182, 214, 246)):
    m_ = M_pale if i % 2 == 0 else M_mid
    L("P_Crown", m_, [(-38, 78, .03), (az, 76, .05), (az + 4, 52, .07), (az + 6, 36, .26)], .50, .13, face=None)

# ================= TOP TUFT (messy rebel note) =================
L("T_Tuft", M_pale, [P(500, 250, 1.66), P(490, 205, 1.78), P(480, 155, 1.94), P(520, 125, 2.0), P(590, 120, 1.97), P(680, 110, 1.96)], .22, .09)
L("T_Tuft", M_mid, [P(540, 250, 1.63), P(530, 215, 1.72), P(570, 170, 1.79), P(630, 160, 1.81), P(680, 185, 1.73)], .16, .08)
L("T_Tuft", M_dark, [P(560, 250, 1.61), P(580, 200, 1.70), P(650, 185, 1.73), P(720, 215, 1.67)], .14, .07)

# ================= CAT EARS (dark glossy cones seated in the hair mass) =================
M_acc = bpy.data.materials["M_Nix_Accessory"]
M_in = bpy.data.materials["M_Nix_AccessoryInner"]
pa_ = M_acc.node_tree.nodes["Principled BSDF"]
pa_.inputs["Base Color"].default_value = (0.06, 0.05, 0.085, 1)
pa_.inputs["Roughness"].default_value = 0.25; pa_.inputs["Coat Weight"].default_value = 0.8
M_in.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.13, 0.24, 1)
axA = RZ @ Vector((-0.64, -0.10, 0.77)); axB = RZ @ Vector((0.05, -0.08, 1.0))
cone_ear("Nix_CatEar_A", P(425, 295, 1.72) - axA.normalized() * 0.10, axA, FRONT, 0.70, 0.58, 0.34, M_acc, C["Accessories"], root)
cone_ear("Nix_CatEar_B", P(770, 205, 1.70) - axB.normalized() * 0.08, axB, FRONT, 0.46, 0.54, 0.30, M_acc, C["Accessories"], root)

# ================= EYES: long heavy lids slanting toward the centre, half-disc pupils -> unimpressed =========
M_eye = bpy.data.materials["M_Nix_Eye"]; M_lid = bpy.data.materials["M_Nix_Lid"]; M_hl = bpy.data.materials["M_Nix_EyeHighlight"]
EY = 4.5
for side, az in (("L", -27), ("R", 27)):
    sg = -1.0 if side == "L" else 1.0
    lid = decal(f"Nix_Lid_{side}", outline_capsule((az - 19, EY + sg * (-1.5)), (az + 19, EY + sg * 1.5), 2.5), R, h_out=0.03, material=M_lid)
    link(lid, C["Face"], root)
    cu_ = az - sg * 3.0
    pu = [(cu_ + 8.0 * math.cos(math.pi + math.pi * i / 20), EY - 0.6 + 9.5 * math.sin(math.pi + math.pi * i / 20)) for i in range(21)]
    link(decal(f"Nix_Pupil_{side}", pu, R, h_out=0.018, material=M_eye), C["Face"], root)
    link(decal(f"Nix_EyeHighlight_{side}", outline_ellipse(cu_ + 2.6, EY - 4.6, 1.6, 1.8, n=12), R, h_out=0.024, material=M_hl), C["Face"], root)

# ================= ORBIT RING: large tilted orbit, front arc passes over the hair, never over the eyes ======
M_ring = bpy.data.materials["M_Nix_RingGlow"]
for nd_ in M_ring.node_tree.nodes:
    if nd_.type == 'EMISSION':
        nd_.inputs["Color"].default_value = (0.34, 0.25, 1.0, 1); nd_.inputs["Strength"].default_value = 3.2   # lavender, not pink
RING_R, RING_N, RING_C = 2.0, RZ @ Vector((0.32, 0.36, 0.876)), RZ @ Vector((-0.28, 0.0, 0.62))
ring = ellipse_ring("Nix_OrbitRing", RING_R, RING_R, 0.017, M_ring, n=16)
ring.rotation_euler = look_rot(RING_N)
ring.location = RING_C
link(ring, C["Emissive"], root)
ring.visible_shadow = False        # a light source should not draw a shadow line across the hair
face_camera("Nix")
print("Nix hair objs", len(C["Hair"].objects))
