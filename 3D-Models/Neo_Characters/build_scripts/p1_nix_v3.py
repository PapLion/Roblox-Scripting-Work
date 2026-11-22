exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib2.py").read(), globals())
R = 1.0
root = bpy.data.objects["Nix_Root"]
C = {s: bpy.data.collections[f"Nix_{s}"] for s in ("Core", "Face", "Hair", "Accessories", "Emissive")}
print("purged", purge(["Nix_Hair", "Nix_CatEar", "Nix_EarClip", "Nix_OrbitRing", "Nix_HatBase"]))

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

# --- fringe (kept at the approved height: it brushes the top of the eyes)
HL("P_FringePale", M_pale, (-40, 78), (46, 4), 0.82, 0.13, belly=0.13, flick=0.16, side=0.10, tip_side=0.08, ext=1.05, lift0=0.13)
HL("P_FringeDark", M_dark, (-50, 74), (-26, -4), 0.62, 0.12, belly=0.06, flick=0.06, side=-0.05, tip_side=0.05, ext=1.05, lift0=0.09)
# bangs from the parting, alternating tones, covering the upper forehead down to just above the eyes
HL("P_Bang", M_pale, (-48, 76), (-8, 9), 0.64, 0.12, belly=0.06, flick=0.07, side=0.05, tip_side=0.04, ext=1.05, lift0=0.12)
HL("P_Bang", M_dark, (-34, 80), (14, 11), 0.56, 0.11, belly=0.06, flick=0.07, side=0.05, ext=1.05, lift0=0.105)
HL("P_Bang", M_pale, (-20, 82), (32, 6), 0.62, 0.12, belly=0.07, flick=0.08, side=0.06, tip_side=0.05, ext=1.05, lift0=0.125)
HL("P_Bang", M_pale, (-66, 72), (-40, 8), 0.56, 0.11, belly=0.05, flick=0.07, side=-0.04, tip_side=0.04, ext=1.05, lift0=0.115)
HL("S_FringeUnder", M_dark, (-5, 82), (30, 10), 0.52, 0.11, belly=0.10, flick=0.10, side=0.06, ext=1.04, lift0=0.10)
# --- top: big pale sweep to the right side, flaring
HL("P_TopSweep", M_pale, (-25, 84), (78, 2), 0.80, 0.13, belly=0.18, flick=0.32, side=0.06, tip_side=0.10, ext=1.06, lift0=0.15)
HL("S_TopDark", M_dark, (10, 86), (60, 22), 0.56, 0.11, belly=0.14, flick=0.18, side=-0.04, ext=1.04, lift0=0.12)
# --- right side: layered dark under / pale over, one longer framing lock
HL("P_RightDark", M_dark, (40, 76), (84, -42), 0.62, 0.12, belly=0.07, flick=0.16, droop=0.18, side=-0.04, ext=1.06, lift0=0.08)
HL("P_RightPale", M_pale, (62, 80), (104, -18), 0.64, 0.12, belly=0.12, flick=0.34, side=0.05, tip_side=0.10, ext=1.06, lift0=0.12)
HL("S_RightFrame", M_dark, (66, 64), (80, -64), 0.34, 0.09, belly=0.04, flick=0.10, droop=0.30, side=0.04, ext=1.1, lift0=0.07, tip_start=0.35, tip_pow=0.9, blunt=0.08)
# --- left: big pale wing flaring out + dark under-locks
HL("P_LeftWing", M_pale, (-58, 80), (-118, 16), 0.82, 0.13, belly=0.20, flick=0.50, side=0.08, tip_side=-0.14, ext=1.08, lift0=0.14)
HL("P_LeftDark", M_dark, (-74, 72), (-96, -40), 0.64, 0.12, belly=0.07, flick=0.16, droop=0.2, side=-0.05, ext=1.06, lift0=0.08)
HL("S_LeftFrame", M_dark, (-96, 58), (-106, -64), 0.34, 0.09, belly=0.04, flick=0.12, droop=0.32, side=-0.04, ext=1.1, lift0=0.07, tip_start=0.35, tip_pow=0.9, blunt=0.08)
HL("S_LeftPale", M_pale, (-90, 76), (-140, -6), 0.58, 0.12, belly=0.12, flick=0.30, side=0.06, ext=1.04, lift0=0.11)
# --- crown volume (gives the taller silhouette of the concept)
HL("P_CrownPale", M_pale, (-110, 86), (-165, 22), 0.80, 0.13, belly=0.22, flick=0.38, side=-0.05, tip_side=0.08, ext=1.05, lift0=0.15)
HL("P_CrownDark", M_dark, (70, 88), (135, 26), 0.72, 0.12, belly=0.20, flick=0.40, side=0.05, tip_side=-0.08, ext=1.05, lift0=0.14)
HL("P_CrownBack", M_pale, (165, 88), (182, 14), 0.80, 0.13, belly=0.18, flick=0.30, side=0.06, ext=1.02, lift0=0.14)
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
hp_dir = D(-48, 62)
hp_c = hp_dir * (R * 1.22)
hp_rm = look_rot(hp_dir).to_matrix()
cap_ = uv_sphere("Nix_HatBase", 0.30, M_acc, 32, 16)
cap_.location = hp_c
cap_.rotation_euler = look_rot(hp_dir)
cap_.scale = (1.15, 0.9, 0.5)
md_ = cap_.modifiers.new("Subsurf", 'SUBSURF'); md_.levels = 1; md_.render_levels = 2
link(cap_, C["Accessories"], root)
def ear(name, tang_off, lean, h=0.44, b=0.44, d=0.17):
    base = hp_c + hp_rm @ Vector((tang_off, 0.0, 0.06))
    up = (hp_dir + hp_rm @ Vector(lean)).normalized()
    front = (hp_rm @ Vector((0, -1, 0))).normalized()
    front = (front - up * front.dot(up)).normalized()
    sp = [base + up * h * (i / 10) for i in range(11)]
    o = ribbon(name, sp, b, d, M_acc, lambda s: (1 - s) ** 0.9 + 0.03, up_hint=front, M=10, curl=-0.3, subsurf=2)
    link(o, C["Accessories"], root)
    sp2 = [p + front * (-d * 0.45) for p in sp[1:8]]
    o2 = ribbon(name + "_Inner", sp2, b * 0.5, d * 0.22, M_in, lambda s: (1 - s) ** 0.9 + 0.05,
                up_hint=front, M=8, curl=-0.6, subsurf=2)
    link(o2, C["Accessories"], root)
ear("Nix_CatEar_A", -0.21, (-0.55, 0.0, 0.1))
ear("Nix_CatEar_B", 0.21, (0.55, 0.0, 0.1))

# ---- orbital ring: elegant tilted orbit passing in front of the upper face, behind the crown
M_ring = bpy.data.materials["M_Nix_RingGlow"]
ring = ellipse_ring("Nix_OrbitRing", 1.95, 1.62, 0.013, M_ring, n=16)
ring.rotation_euler = look_rot(Vector((0.42, 0.55, 0.72)))
ring.location = (0.0, 0.0, 0.25)
link(ring, C["Emissive"], root)
print("hair objs", len(C["Hair"].objects))
