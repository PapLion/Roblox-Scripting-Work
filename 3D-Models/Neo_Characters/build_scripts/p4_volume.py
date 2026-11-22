exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib2.py").read(), globals())
from mathutils.bvhtree import BVHTree
import sys

def build_volume(ch, R, material, face_mask, front_zone, el_min=-50, max_dist=0.42, naz=216, nel=96, step=0.022, spacing=13.0, groove=0.028, hcap=0.10, tip_h=0.06, tip_lo=0.35,
                 exclude=("_T_", "Strand", "Curl", "Ahoge", "HairCap", "HairVolume")):
    purge([f"{ch}_HairVolume"])
    dg = bpy.context.evaluated_depsgraph_get()
    verts, polys = [], []
    for o in bpy.data.collections[f"{ch}_Hair"].objects:
        if o.type != 'MESH' or any(x in o.name for x in exclude):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_basis  # locks are parented to the root with identity inverse -> root-local
        base = len(verts)
        verts += [mw @ v.co for v in me.vertices]
        polys += [tuple(base + i for i in p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
    bvh = BVHTree.FromPolygons(verts, polys)
    els = [el_min + (89.0 - el_min) * i / (nel - 1) for i in range(nel)]
    azs = [360.0 * j / naz - 180.0 for j in range(naz)]
    H = [[-0.02] * naz for _ in range(nel)]
    HMAX = [[1e9] * naz for _ in range(nel)]
    hits = 0
    for i, el in enumerate(els):
        for j, az in enumerate(azs):
            if face_mask(az, el):
                HMAX[i][j] = -0.02
                continue
            d = D(az, el)
            loc, nrm, idx, dist = bvh.ray_cast(d * (R * 0.995), d, max_dist)
            if loc is not None:
                h = min((loc.length - R) - 0.006, hcap)   # smooth envelope: don't follow flared tips
                H[i][j] = max(h, 0.0)
                HMAX[i][j] = max((loc.length - R) - 0.006, 0.0)
                hits += 1
            if front_zone(az, el):
                H[i][j] = -0.02; HMAX[i][j] = -0.02   # the fringe locks cover the forehead; keep the volume off the face
    # dilate: ramp the under-volume down from lock edges so there is no empty slot under them
    for it in range(8):
        new = [row[:] for row in H]
        for i in range(nel):
            for j in range(naz):
                if HMAX[i][j] < 0:
                    continue
                m = H[i][j]
                for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ii, jj = i + di, (j + dj) % naz
                    if 0 <= ii < nel:
                        m = max(m, H[ii][jj] - step)
                new[i][j] = m
        H = new
    # soften, never pushing above the locks' inner surface
    for it in range(10):
        new = [row[:] for row in H]
        for i in range(1, nel - 1):
            for j in range(naz):
                avg = (H[i][j] * 2 + H[i + 1][j] + H[i - 1][j] + H[i][(j + 1) % naz] + H[i][(j - 1) % naz]) / 6
                new[i][j] = min(avg, HMAX[i][j])
        H = new
    # sculpt hair clumps: grooves along the fall direction, pointed tips at the lower edge
    for i, el in enumerate(els):
        sway = 5.0 * math.sin(math.radians(el) * 3.0)
        for j, az in enumerate(azs):
            h = H[i][j]
            if h <= 0.0:
                continue
            # irregular clumps: varying width, phase and depth so it reads as natural hair, not ribs
            sp = spacing * (1.0 + 0.35 * math.sin(math.radians(az) * 2.7 + 1.3))
            ph = 6.0 * math.sin(math.radians(az) * 1.9) + 3.0 * math.sin(math.radians(el) * 4.0 + az * 0.05)
            c = abs(math.cos(math.pi * (az + sway + ph) / sp))
            c = c ** 0.55                                   # 1 = clump centre, 0 = groove
            depth = groove * (0.6 + 0.4 * math.sin(math.radians(az) * 5.3 + 0.7))
            body = min(1.0, h / 0.05)
            h = h - depth * (1 - c) * body                  # carve grooves on the full-height parts
            if h < tip_h:                                   # thin ramp near the edge -> taper into pointed tips
                h = h * (tip_lo + (1 - tip_lo) * c * c)
            H[i][j] = h
    # avoid z-fighting with the skin: anything that ends up (almost) on the scalp is tucked inside it
    for i in range(nel):
        for j in range(naz):
            if H[i][j] < 0.006:
                H[i][j] = -0.02
    vs, fs = [], []
    for i, el in enumerate(els):
        for j, az in enumerate(azs):
            vs.append(D(az, el) * (R + H[i][j]))
    for i in range(nel - 1):
        for j in range(naz):
            j2 = (j + 1) % naz
            fs.append((i * naz + j, i * naz + j2, (i + 1) * naz + j2, (i + 1) * naz + j))
    top = len(vs); vs.append(Vector((0, 0, R + max(H[-1]))))
    for j in range(naz):
        fs.append(((nel - 1) * naz + j, (nel - 1) * naz + (j + 1) % naz, top))
    ob = mesh_obj(f"{ch}_HairVolume", vs, fs, material, subsurf=1)
    link(ob, bpy.data.collections[f"{ch}_Hair"], bpy.data.objects[f"{ch}_Root"])
    print(ch, "volume hits", hits)
    return ob

def under_mat(name, src, tint=1.0):
    m = src.copy(); m.name = name
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    bc = p.inputs["Base Color"]
    if not bc.is_linked:
        c = bc.default_value; bc.default_value = (c[0] * tint, c[1] * tint, c[2] * tint, 1)
    p.inputs["Sheen Weight"].default_value = 0.6
    p.inputs["Roughness"].default_value = 0.45
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0
    gr = nt.nodes.new("ShaderNodeTexGradient"); gr.gradient_type = 'RADIAL'
    add = nt.nodes.new("ShaderNodeMath"); add.operation = 'MULTIPLY_ADD'
    add.inputs[1].default_value = 0.03
    m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = 'MULTIPLY'; m1.inputs[1].default_value = 2 * math.pi * 140
    sn = nt.nodes.new("ShaderNodeMath"); sn.operation = 'SINE'
    bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = 0.12; bp.inputs["Distance"].default_value = 0.01
    nt.links.new(tc.outputs["Object"], gr.inputs["Vector"]); nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    nt.links.new(nz.outputs["Fac"], add.inputs[0]); nt.links.new(gr.outputs["Fac"], add.inputs[2])
    nt.links.new(add.outputs[0], m1.inputs[0]); nt.links.new(m1.outputs[0], sn.inputs[0])
    nt.links.new(sn.outputs[0], bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"], p.inputs["Normal"])
    return m
for nm_ in ("M_Nix_HairUnder", "M_Yoru_HairUnder"):
    if bpy.data.materials.get(nm_): bpy.data.materials.remove(bpy.data.materials[nm_])
M_NU = under_mat("M_Nix_HairUnder", bpy.data.materials["M_Nix_HairDark"], 0.9)
M_YU = under_mat("M_Yoru_HairUnder", bpy.data.materials["M_Yoru_HairBrown"], 0.9)

# Nix: face region (eyes + cheeks, el below the fringe) kept clear
nix_face = lambda az, el: abs(az) < 52 and el < 20
build_volume("Nix", 1.0, M_NU, nix_face, lambda az, el: abs(az) < 70 and el < 60, el_min=-32, step=0.018, hcap=0.11, groove=0.045, tip_h=0.09, tip_lo=0.0, spacing=11.0)
# Yoru: eyes top at ~el 14, keep the face clear; scarf covers below el -35
yoru_face = lambda az, el: abs(az) < 48 and el < 22
build_volume("Yoru", 0.85, M_YU, yoru_face, lambda az, el: (abs(az) < 75 and el < 62) or (-116 < az < 0 and el < 84), el_min=-36, step=0.026, hcap=0.085)

# the old smooth scalp caps are replaced by the sculpted volume (kept in the file, hidden)
for n_ in ("Nix_HairCap", "Yoru_HairCap"):
    o_ = bpy.data.objects.get(n_)
    if o_:
        o_.hide_render = True; o_.hide_viewport = True
