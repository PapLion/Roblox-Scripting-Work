exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
import random
random.seed(7)
R = 1.0
root, C = char_setup("Nix", (-2.9, 0.0, 0.35))

M_skin = mat_gradient("M_Nix_Skin", (0.36, 0.31, 0.54), (0.74, 0.70, 0.89), rough=0.42, coat=0.15,
                      sss=0.05, zmin=-1.0, zmax=0.8, rim=(0.55, 0.35, 1.0), rim_str=0.35)
M_dark = mat("M_Nix_HairDark", (0.045, 0.040, 0.055), rough=0.55, spec=0.35)
M_pale = mat_gradient("M_Nix_HairPale", (0.48, 0.45, 0.60), (0.84, 0.82, 0.90), rough=0.5,
                      zmin=-0.5, zmax=1.3)
M_eye = mat("M_Nix_Eye", (0.025, 0.02, 0.04), rough=0.12, coat=1.0)
M_lid = mat("M_Nix_Lid", (0.02, 0.018, 0.028), rough=0.5)
M_hl = mat_emit("M_Nix_EyeHighlight", (1.0, 0.97, 1.0), 2.0)
M_acc = mat("M_Nix_Accessory", (0.03, 0.028, 0.04), rough=0.35, coat=0.6)
M_acc_in = mat("M_Nix_AccessoryInner", (0.20, 0.10, 0.32), rough=0.4)
M_ring = mat_emit("M_Nix_RingGlow", (0.42, 0.10, 1.0), 3.0)

# ---- core
head = uv_sphere("Nix_Head", R, M_skin, 64, 32)
md = head.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
link(head, C["Core"], root)

# ---- face: half-lidded, unimpressed eyes (looking slightly to her left)
for side, az in (("L", -24), ("R", 24)):
    tilt = -1.0 if side == "L" else 1.0
    lid = decal(f"Nix_Lid_{side}", outline_capsule((az - 14, -3 + tilt * 0.8), (az + 14, -3 - tilt * 0.8), 2.3),
                R, h_out=0.03, material=M_lid)
    link(lid, C["Face"], root)
    # pupil: lower half-disc hanging under the lid, shifted to look sideways
    pu = []
    cu_, cv_ = az + 4, -3.2
    for i in range(21):
        a = math.pi + math.pi * i / 20
        pu.append((cu_ + 9.0 * math.cos(a), cv_ + 10.0 * math.sin(a)))
    p = decal(f"Nix_Pupil_{side}", pu, R, h_out=0.018, material=M_eye)
    link(p, C["Face"], root)
    hl = decal(f"Nix_EyeHighlight_{side}", outline_ellipse(cu_ + 4.5, -7.5, 1.7, 2.0, n=12), R,
               h_out=0.024, material=M_hl)
    link(hl, C["Face"], root)

# ---- hair base cap (charcoal) with a jagged fringe edge so no scalp shows between locks
def cap_edge(az):
    base = 40 - 76 * smoothstep(35, 165, abs(az))
    saw = abs(((az + 7) / 16.0) % 1.0 - 0.5) * 2  # 0..1 zig-zag -> pointed fringe
    return base - 7 * saw
cap = hair_cap("Nix_HairCap", R + 0.028, cap_edge, M_dark, naz=72, nel=14)
link(cap, C["Hair"], root)

def L(name, mat_, d0, d1, w, t, lift1=0.3, ext=1.0, droop=0.0, lift0=None, sweep=None, taper=0.6, twist=0.0):
    o = lock(name, R, d0, d1, width=w, thick=t, material=mat_, lift0=lift0, lift1=lift1, ext=ext,
             droop=droop, sweep=sweep, taper=taper, twist=twist)
    link(o, C["Hair"], root)
    return o

n = 0
def nm(tag):
    global n; n += 1
    return f"Nix_Hair_{tag}_{n:02d}"

# back: charcoal locks fanning down from the crown, flared tips curling down
for az in range(95, 275, 20):
    j = random.uniform(-10, 10)
    L(nm("Back"), M_dark, (az, 80), (az + j, -18 - random.uniform(0, 16)), 0.62, 0.13,
      lift1=0.22 + random.uniform(0, 0.12), ext=1.05, droop=0.12)
# back outer pale layer
for az, el_end in ((140, 8), (185, -2), (228, 10)):
    L(nm("BackPale"), M_pale, (az + 12, 86), (az - 14, el_end), 0.62, 0.14, lift0=0.09, lift1=0.34, ext=1.05, droop=0.1)

# viewer-left side: dark locks + long strands hanging below the head
L(nm("SideL"), M_dark, (-72, 62), (-92, -38), 0.48, 0.12, lift1=0.16, ext=1.1, droop=0.25)
L(nm("SideL"), M_dark, (-100, 58), (-112, -52), 0.42, 0.11, lift1=0.14, ext=1.15, droop=0.4)
L(nm("SideLStrand"), M_dark, (-84, 40), (-98, -70), 0.20, 0.07, lift1=0.22, ext=1.25, droop=0.55, taper=0.5)
L(nm("SideLStrand"), M_dark, (-122, 45), (-126, -72), 0.20, 0.07, lift1=0.2, ext=1.2, droop=0.6, taper=0.5)
# viewer-right side
L(nm("SideR"), M_dark, (66, 62), (84, -44), 0.44, 0.12, lift1=0.12, ext=1.1, droop=0.3)
L(nm("SideRPale"), M_pale, (48, 72), (72, -28), 0.40, 0.11, lift0=0.08, lift1=0.15, ext=1.05, droop=0.2)
L(nm("SideRStrand"), M_dark, (58, 40), (78, -72), 0.17, 0.06, lift1=0.14, ext=1.2, droop=0.5, taper=0.5)
L(nm("SideRStrand"), M_pale, (96, 52), (100, -62), 0.19, 0.065, lift0=0.07, lift1=0.2, ext=1.15, droop=0.45, taper=0.5)

# big pale top mass sweeping out toward viewer-left, spiky but falling
L(nm("TopPale"), M_pale, (-30, 84), (-102, 20), 0.72, 0.16, lift0=0.12, lift1=0.42, ext=1.12, droop=0.12)
L(nm("TopPale"), M_pale, (-2, 88), (-70, 36), 0.62, 0.15, lift0=0.16, lift1=0.46, ext=1.12, droop=0.08)
L(nm("TopPale"), M_pale, (-82, 82), (-138, 22), 0.62, 0.15, lift0=0.12, lift1=0.42, ext=1.1, droop=0.12)
L(nm("TopPale"), M_pale, (40, 86), (96, 30), 0.58, 0.14, lift0=0.13, lift1=0.40, ext=1.1, droop=0.12)
L(nm("TopPale"), M_pale, (102, 84), (148, 34), 0.56, 0.14, lift0=0.13, lift1=0.42, ext=1.1, droop=0.12)
L(nm("TopDark"), M_dark, (-150, 86), (-172, 30), 0.58, 0.14, lift0=0.14, lift1=0.44, ext=1.1, droop=0.12)
L(nm("TopDark"), M_dark, (-58, 80), (-118, 4), 0.52, 0.13, lift0=0.08, lift1=0.30, ext=1.05, droop=0.1)

# bangs: alternating dark / pale locks sweeping across the forehead toward viewer-right
L(nm("BangPale"), M_pale, (-55, 74), (-46, 6), 0.62, 0.13, lift0=0.07, lift1=0.16, ext=1.08)
L(nm("BangDark"), M_dark, (-32, 78), (-14, 6), 0.62, 0.13, lift0=0.08, lift1=0.12, ext=1.08)
L(nm("BangPale"), M_pale, (-10, 80), (18, 6), 0.70, 0.14, lift0=0.11, lift1=0.12, ext=1.1)
L(nm("BangDark"), M_dark, (14, 78), (44, 0), 0.58, 0.13, lift0=0.08, lift1=0.15, ext=1.08)
L(nm("BangPale"), M_pale, (36, 76), (64, -14), 0.50, 0.12, lift0=0.10, lift1=0.18, ext=1.08)
L(nm("BangStrand"), M_dark, (-6, 62), (13, -17), 0.13, 0.05, lift0=0.045, lift1=0.05, ext=1.1, taper=0.5)

# ---- accessory: small dark cat ears perched top-left
def ear(name, base_dir, out_len, lean, size):
    b = D(*base_dir) * (R * 1.22)
    up = (D(*base_dir) + Vector(lean)).normalized()
    sp = [b + up * out_len * (i / 8) for i in range(9)]
    front = D(base_dir[0], 0)
    o = spine_lock(name, sp, width=size, thick=size * 0.45, material=M_acc, taper=0.7, crescent=-0.25,
                   up_hint=front, subsurf=2)
    link(o, C["Accessories"], root)
    sp2 = [p + front * size * 0.16 + up * 0.03 for p in sp[1:8]]
    o2 = spine_lock(name + "_Inner", sp2, width=size * 0.55, thick=size * 0.12, material=M_acc_in,
                    taper=0.9, up_hint=front, subsurf=2)
    link(o2, C["Accessories"], root)
ear("Nix_CatEar_A", (-60, 58), 0.30, (-0.30, 0, 0.1), 0.56)
ear("Nix_CatEar_B", (-20, 72), 0.30, (0.20, 0, 0.3), 0.56)
# small band joining the ears (hair clip)
clip = curve_tube("Nix_EarClip", [D(-70, 52) * 1.24, D(-40, 66) * 1.30, D(-10, 76) * 1.30, D(10, 80) * 1.25],
                  0.035, M_acc)
link(clip, C["Accessories"], root)

# ---- emissive orbital ring (real 3D curve)
ring = ellipse_ring("Nix_OrbitRing", 1.78, 1.48, 0.014, M_ring, n=12)
ring.rotation_euler = (math.radians(30), math.radians(62), math.radians(-10))
ring.location = (-0.05, 0.0, 0.30)
link(ring, C["Emissive"], root)

print("Nix objects:", sum(len(c.objects) for c in C.values()))
