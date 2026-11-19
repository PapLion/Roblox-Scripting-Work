exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib2.py").read(), globals())
R = 1.0
root = bpy.data.objects["Nix_Root"]
C = {s: bpy.data.collections[f"Nix_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Nix_Hair", "Nix_CatEar", "Nix_EarClip", "Nix_OrbitRing", "Nix_HatBase", "Nix_Lid", "Nix_Pupil", "Nix_EyeHighlight"]))

M_dark = bpy.data.materials["M_Nix_HairDark"]
M_pale = bpy.data.materials["M_Nix_HairPale"]
# satin hair: soft sheen + slight violet rim so dark/light layers separate in depth
for m, rim in ((M_dark, 0.10), (M_pale, 0.06)):
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.42
    p.inputs["Sheen Weight"].default_value = 0.35
    p.inputs["Sheen Tint"].default_value = (0.75, 0.6, 1.0, 1)
    if not any(n.type == 'LAYER_WEIGHT' for n in m.node_tree.nodes):
        add_rim(m, (0.55, 0.35, 1.0), rim)
M_dark.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.043, 0.065, 1)
set_ramp("M_Nix_HairPale", (0.55, 0.52, 0.68), (0.92, 0.90, 0.97))
M_mid = bpy.data.materials.get("M_Nix_HairShadow") or mat("M_Nix_HairShadow", (0.16, 0.14, 0.21), rough=0.45)

n = 0
def H(tag, m, d0, d1, w, t, **kw):
    global n; n += 1
    o = lock2(f"Nix_Hair_{tag}_{n:02d}", R, d0, d1, w, t, m, **kw)
    link(o, C["Hair"], root)
    return o

# ---- base mass: thicker shell so locks sit on a real volume, edge hidden under the fringe
def cap_edge(az):
    return 46 - 86 * smoothstep(30, 170, abs(az)) - 6 * abs(((az + 7) / 20.0) % 1.0 - 0.5) * 2
cap = hair_cap("Nix_HairCap", R + 0.05, cap_edge, M_dark, naz=72, nel=14)
link(cap, C["Hair"], root)

# ================= v3 art-directed hairstyle =================
# Flow: a parting at the top-left (az -45, el 76). The fringe sweeps from it across the forehead to the right,
# the left wing flares out, and the back falls from a crown ring in two overlapping rows (inner dark / outer mixed).
# Locks are thinner in depth (no plates); tips taper smoothly but never become wires.
def HL(tag, m, d0, d1, w, t, **kw):
    kw.setdefault("curl", 0.35); kw.setdefault("ridge", 0.12); kw.setdefault("tip_start", 0.42); kw.setdefault("tip_pow", 1.05)
    return H(tag, m, d0, d1, w, t, **kw)

# --- fringe (v4, matches target B): dark-dominant left forehead with pointed tips + one big pale crescent
HL("P_FringeDark", M_dark, (-50, 74), (-26, -4), 0.62, 0.12, belly=0.07, flick=0.08, side=-0.05, tip_side=0.05, ext=1.05, lift0=0.10)
HL("P_Bang", M_dark, (-48, 76), (-12, 8), 0.62, 0.12, belly=0.07, flick=0.09, side=0.05, tip_side=0.04, ext=1.05, lift0=0.12)
HL("P_Bang", M_dark, (-66, 72), (-44, 4), 0.56, 0.11, belly=0.06, flick=0.12, side=-0.04, tip_side=-0.05, ext=1.05, lift0=0.115)
HL("P_Bang", M_dark, (-32, 80), (0, 12), 0.52, 0.11, belly=0.06, flick=0.07, side=0.05, ext=1.05, lift0=0.105)
HL("P_FringePale", M_pale, (-14, 86), (13, 5), 0.74, 0.13, belly=0.12, flick=0.10, side=0.14, tip_side=0.07, ext=1.05, lift0=0.14)  # crescent
HL("P_Bang", M_pale, (-2, 84), (46, 8), 0.64, 0.12, belly=0.09, flick=0.16, side=0.07, tip_side=0.06, ext=1.05, lift0=0.13)
HL("S_FringeUnder", M_dark, (8, 82), (34, 12), 0.46, 0.10, belly=0.08, flick=0.10, side=0.06, ext=1.04, lift0=0.10)
# --- top: big pale sweep to the right side, flaring
HL("P_TopSweep", M_pale, (-25, 84), (78, 2), 0.80, 0.13, belly=0.24, flick=0.46, side=0.06, tip_side=0.14, ext=1.06, lift0=0.15)
HL("S_TopDark", M_dark, (10, 86), (60, 22), 0.56, 0.11, belly=0.14, flick=0.18, side=-0.04, ext=1.04, lift0=0.12)
# --- right side: layered dark under / pale over, one longer framing lock
HL("P_RightDark", M_dark, (40, 76), (84, -42), 0.62, 0.12, belly=0.07, flick=0.16, droop=0.18, side=-0.04, ext=1.06, lift0=0.08)
HL("P_RightPale", M_pale, (62, 80), (104, -18), 0.64, 0.12, belly=0.14, flick=0.46, side=0.05, tip_side=0.10, ext=1.06, lift0=0.12)
HL("S_RightStrand", M_dark, (44, 70), (56, -62), 0.26, 0.08, belly=0.04, flick=0.08, droop=0.30, side=0.05, ext=1.12, lift0=0.10, tip_start=0.35, tip_pow=0.9, blunt=0.06)
HL("S_RightStrand", M_dark, (56, 72), (70, -70), 0.24, 0.08, belly=0.05, flick=0.12, droop=0.34, side=-0.05, ext=1.12, lift0=0.09, tip_start=0.35, tip_pow=0.9, blunt=0.06)
HL("S_RightFrame", M_dark, (66, 64), (80, -64), 0.34, 0.09, belly=0.04, flick=0.10, droop=0.30, side=0.04, ext=1.1, lift0=0.07, tip_start=0.35, tip_pow=0.9, blunt=0.08)
# --- left: big pale wing flaring out + dark under-locks
HL("P_LeftWing", M_pale, (-58, 80), (-118, 16), 0.82, 0.13, belly=0.24, flick=0.62, side=0.08, tip_side=-0.14, ext=1.08, lift0=0.14)
HL("P_LeftDark", M_dark, (-74, 72), (-96, -40), 0.64, 0.12, belly=0.07, flick=0.16, droop=0.2, side=-0.05, ext=1.06, lift0=0.08)
HL("S_LeftFrame", M_dark, (-96, 58), (-106, -64), 0.34, 0.09, belly=0.04, flick=0.12, droop=0.32, side=-0.04, ext=1.1, lift0=0.07, tip_start=0.35, tip_pow=0.9, blunt=0.08)
HL("S_LeftPale", M_pale, (-90, 76), (-140, -6), 0.58, 0.12, belly=0.12, flick=0.30, side=0.06, ext=1.04, lift0=0.11)
# --- crown volume (gives the taller silhouette of the concept)
HL("P_CrownPale", M_pale, (-110, 86), (-165, 22), 0.80, 0.13, belly=0.28, flick=0.46, side=-0.05, tip_side=0.08, ext=1.05, lift0=0.15)
HL("P_CrownDark", M_dark, (70, 88), (135, 26), 0.72, 0.12, belly=0.26, flick=0.46, side=0.05, tip_side=-0.08, ext=1.05, lift0=0.14)
HL("P_CrownBack", M_pale, (165, 88), (182, 14), 0.80, 0.13, belly=0.24, flick=0.38, side=0.06, ext=1.02, lift0=0.14)
# --- back, inner row: dark, long, overlapping (spacing < width) so no scalp shows
inner = ((96, -34, 0.66, 0.05), (118, -40, 0.70, -0.05), (141, -32, 0.64, 0.06), (163, -42, 0.72, -0.04),
         (186, -36, 0.68, 0.05), (209, -44, 0.70, -0.06), (232, -34, 0.66, 0.05), (255, -40, 0.68, -0.05), (276, -32, 0.62, 0.04))
for az, el1, w, sd in inner:
    HL("S_BackInner", M_dark, (az, 74), (az + sd * 80, el1), w, 0.11, belly=0.05, flick=0.14, side=sd, ext=1.0, lift0=0.06)
# --- back, outer row: shorter, offset half a step, alternating tones, more volume and flick
outer = ((107, -14, M_dark, 0.62), (152, -8, M_pale, 0.70), (198, -16, M_dark, 0.66), (243, -10, M_pale, 0.68))
for az, el1, m_, w in outer:
    HL("S_BackOuter", m_, (az, 82), (az + 6, el1), w, 0.12, belly=0.13, flick=0.30, side=0.05, ext=1.0, lift0=0.11)
# --- small soft flick on the crown for the rebellious note (wide enough to stay soft)
HL("T_CrownFlick", M_pale, (-25, 88), (-62, 54), 0.32, 0.09, belly=0.22, flick=0.42, side=0.05, tip_side=-0.08, ext=1.1, lift0=0.22, tip_start=0.35)

# ---- accessory: small dark cat-ear headpiece (rounded cap + two soft triangular ears), perched top-left
M_acc = bpy.data.materials["M_Nix_Accessory"]
M_in = bpy.data.materials["M_Nix_AccessoryInner"]
M_in.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.32, 0.14, 0.55, 1)
def ear_at(tag, dirv, h=0.42, b=0.62, d=0.12, lean=0.22, pad=0.25):
    rm = look_rot(dirv).to_matrix()
    c = dirv * (R * 1.24)
    pd = uv_sphere(f"Nix_HatBase_{tag}", pad, M_acc, 32, 16)
    pd.location = c; pd.rotation_euler = look_rot(dirv); pd.scale = (1.25, 1.0, 0.48)
    md_ = pd.modifiers.new("Subsurf", 'SUBSURF'); md_.levels = 1; md_.render_levels = 2
    link(pd, C["Accessories"], root)
    up = (dirv + Vector((0, 0, lean))).normalized()
    front = Vector((0, -1, 0)); front = (front - up * front.dot(up)).normalized()
    base = c + dirv * 0.05
    sp = [base + up * h * (i / 10) for i in range(11)]
    o = ribbon(f"Nix_CatEar_{tag}", sp, b, d, M_acc, lambda s: (1 - s ** 1.15) ** 0.85 * (1 - 0.15 * s) + 0.05, up_hint=front, M=12, curl=-0.55, subsurf=2)
    link(o, C["Accessories"], root)
    sp2 = [p + front * (-d * 0.45) for p in sp[1:8]]
    o2 = ribbon(f"Nix_CatEar_{tag}_Inner", sp2, b * 0.5, d * 0.22, M_in, lambda s: (1 - s) ** 0.9 + 0.05,
                up_hint=front, M=8, curl=-0.6, subsurf=2)
    link(o2, C["Accessories"], root)
ear_at("A", D(-58, 50), h=0.50, b=0.70, pad=0.28)
ear_at("B", D(30, 66), h=0.36, b=0.54)
pa_ = M_acc.node_tree.nodes["Principled BSDF"]
pa_.inputs["Roughness"].default_value = 0.55; pa_.inputs["Coat Weight"].default_value = 0.15
pa_.inputs["Sheen Weight"].default_value = 0.5; pa_.inputs["Sheen Tint"].default_value = (0.7, 0.55, 1.0, 1)

# ---- eyes (v4): longer heavy lids, smaller half-disc pupils -> relaxed, unimpressed look
M_eye = bpy.data.materials["M_Nix_Eye"]; M_lid = bpy.data.materials["M_Nix_Lid"]; M_hl = bpy.data.materials["M_Nix_EyeHighlight"]
for side, az in (("L", -24), ("R", 24)):
    tilt = -1.0 if side == "L" else 1.0
    lid = decal(f"Nix_Lid_{side}", outline_capsule((az - 16, -2 + tilt * 0.6), (az + 15, -2 - tilt * 0.6), 2.6), R, h_out=0.03, material=M_lid)
    link(lid, C["Face"], root)
    cu_ = az + 5
    pu = [(cu_ + 7.0 * math.cos(math.pi + math.pi * i / 20), -2.4 + 8.0 * math.sin(math.pi + math.pi * i / 20)) for i in range(21)]
    link(decal(f"Nix_Pupil_{side}", pu, R, h_out=0.018, material=M_eye), C["Face"], root)
    link(decal(f"Nix_EyeHighlight_{side}", outline_ellipse(cu_ + 3.0, -5.6, 1.5, 1.7, n=12), R, h_out=0.024, material=M_hl), C["Face"], root)
root.rotation_euler = (math.radians(4), 0, math.radians(28))   # head turned toward viewer-right like the target
RING_N = (0.42, 0.42, 0.80)
# ---- orbital ring: elegant tilted orbit passing in front of the upper face, behind the crown
M_ring = bpy.data.materials["M_Nix_RingGlow"]
ring = ellipse_ring("Nix_OrbitRing", 1.78, 1.50, 0.013, M_ring, n=16)
ring.rotation_euler = look_rot(Vector(RING_N))
ring.location = (0.0, 0.0, 0.30)
link(ring, C["Emissive"], root)
print("hair objs", len(C["Hair"].objects))
bpy.context.view_layer.update()
mw = ring.matrix_basis
pts = [mw @ Vector((1.78 * math.cos(2 * math.pi * i / 90), 1.50 * math.sin(2 * math.pi * i / 90), 0)) for i in range(90)]
fr = [p for p in pts if p.y < -0.3 and abs(p.x) < 0.8]
print("ring front-arc min z", min(p.z for p in fr) if fr else None)
