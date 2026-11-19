# Polish-pass helpers (exec'd after lib.py)

def purge(names_or_prefixes):
    """Delete objects whose name starts with any of the given prefixes."""
    gone = 0
    for o in list(bpy.data.objects):
        if any(o.name.startswith(p) for p in names_or_prefixes):
            data = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if data is not None and data.users == 0:
                if isinstance(data, bpy.types.Mesh): bpy.data.meshes.remove(data)
                elif isinstance(data, bpy.types.Curve): bpy.data.curves.remove(data)
            gone += 1
    return gone

def frames(spine, center=None, up_hint=None):
    out = []
    n = len(spine)
    for i, P in enumerate(spine):
        T = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized()
        if up_hint is not None:
            N0 = Vector(up_hint(i / (n - 1)) if callable(up_hint) else up_hint)
        else:
            N0 = P - (center if center is not None else Vector())
        N0 = N0.normalized() if N0.length > 1e-6 else Vector((0, 0, 1))
        N = N0 - T * N0.dot(T)
        if N.length < 1e-6:
            N = T.orthogonal()
        N.normalize()
        out.append((T, N, T.cross(N).normalized()))
    return out

def tube2(spine, wfn, tfn, center=None, up_hint=None, M=10, curl=0.45, flat_bottom=0.5, ridge=0.18,
          ruffle=None, twist=0.0, diamond=False, round_tip=False):
    """Sculpted clump section: arched 'roof tile' (edges curl toward the head), soft top ridge,
    flatter underside. ruffle(s)->amplitude for wavy edges. twist(rad) total over length."""
    n = len(spine)
    F = frames(spine, center, up_hint)
    verts, faces = [], []
    for i in range(n - 1):
        s = i / (n - 1)
        P = spine[i]; T, N, B = F[i]
        if twist:
            a_ = twist * s
            N, B = N * math.cos(a_) + B * math.sin(a_), B * math.cos(a_) - N * math.sin(a_)
        w = wfn(s) * 0.5; h = tfn(s) * 0.5
        rf = ruffle(s) if ruffle else 0.0
        for k in range(M):
            a = 2 * math.pi * k / M
            c, sn = math.cos(a), math.sin(a)
            if diamond:
                x = math.copysign(abs(c) ** 0.85, c) * w
                y = math.copysign(abs(sn) ** 1.7, sn) * h
            else:
                x = c * w
                y = sn * h
                if y < 0:
                    y *= flat_bottom
                if sn > 0:
                    y += ridge * h * (1 - c * c) ** 3
            y -= curl * h * c * c
            y += rf * c * c * math.copysign(1, c)  # edges wave in opposite directions
            verts.append(P + B * x + N * y)
    rings = n - 1
    for i in range(rings - 1):
        for k in range(M):
            a = i * M + k; b = i * M + (k + 1) % M
            faces.append((a, b, b + M, a + M))
    tip = len(verts); verts.append(spine[-1].copy())
    last = (rings - 1) * M
    for k in range(M):
        faces.append((last + k, last + (k + 1) % M, tip))
    rc = len(verts)
    verts.append(sum((verts[k] for k in range(M)), Vector()) / M)
    for k in range(M):
        faces.append(((k + 1) % M, k, rc))
    return verts, faces

def clump_profile(belly_at=0.3, tip_start=0.4, tip_pow=0.8, root=0.6, blunt=0.0):
    def f(s):
        g = root + (1 - root) * smoothstep(0, belly_at, s)
        t = (1 - smoothstep(tip_start, 1.0, s)) ** tip_pow
        return g * (blunt + (1 - blunt) * t) if s < 0.999 else 0.0
    return f

def lock2(name, R, d0, d1, width, thick, material, lift0=None, belly=0.08, flick=0.15, ext=1.0,
          side=0.0, tip_side=0.0, droop=0.0, n=22, M=10, curl=0.45, ridge=0.18, twist=0.0,
          prof=None, subsurf=2, tip_pow=0.8, tip_start=0.4, belly_at=0.3, root=0.6, blunt=0.0,
          center=Vector((0, 0, 0))):
    """Sculpted anime hair clump hugging a sphere from d0 to d1 (az,el degrees).
    belly: arcs away from the head mid-length (volume); flick: tip flares outward;
    side: lateral S-curve amplitude; tip_side: lateral hook of the tip; droop: gravity on the tip."""
    if lift0 is None:
        lift0 = thick * 0.35
    A, Bd = D(*d0), D(*d1)
    base = []
    for i in range(n):
        s = i / (n - 1)
        d = slerp(A, Bd, s * ext)
        r = R + lift0 + belly * math.sin(math.pi * min(1.0, s * 1.1)) + flick * smoothstep(0.5, 1.0, s) ** 2
        base.append(center + d * r)
    pts = []
    for i, p in enumerate(base):
        s = i / (n - 1)
        T = (base[min(i + 1, n - 1)] - base[max(i - 1, 0)]).normalized()
        Bv = T.cross((p - center).normalized()).normalized()
        off = Bv * (side * math.sin(math.pi * s) + tip_side * s ** 3) + Vector((0, 0, -droop * s ** 3))
        pts.append(p + off)
    wf_ = prof or clump_profile(belly_at, tip_start, tip_pow, root, blunt)
    wf = lambda s: width * wf_(s) + 0.004
    tf = lambda s: thick * (0.7 + 0.3 * smoothstep(0, 0.25, s)) * (1 - smoothstep(0.15, 1.0, s)) ** 0.6 + 0.006
    v, f = tube2(pts, wf, tf, center=center, M=M, curl=curl, ridge=ridge, twist=twist)
    ob = mesh_obj(name, v, f, material)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = subsurf
    return ob

def ribbon(name, spine, width, thick, material, prof, up_hint=None, center=None, M=10, ruffle=None,
           twist=0.0, diamond=False, curl=0.15, subsurf=2):
    wf = lambda s: width * prof(s) + 0.003
    tf = lambda s: thick * (1 - 0.6 * s) + 0.004
    v, f = tube2([Vector(p) for p in spine], wf, tf, center=center, up_hint=up_hint, M=M, curl=curl,
                 ridge=0.25 if not diamond else 0.0, flat_bottom=1.0, ruffle=ruffle, twist=twist,
                 diamond=diamond)
    ob = mesh_obj(name, v, f, material)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = subsurf
    return ob

def sphere_band(name, R, lat_fn, half_fn, off_out, off_in, material, seg=128, prof_n=6, pillow=0.012,
                subsurf=1):
    """Band hugging a sphere: at azimuth az spans lat_fn(az)±half_fn(az) (deg), outer surface at
    R+off_out (pillowed in the middle, rounded edges), inner surface hidden at R+off_in."""
    prof = []
    # rounded-rect in (t in [-1,1] across band, radial offset)
    for j in range(prof_n + 1):  # outer surface, bottom->top
        t = -1 + 2 * j / prof_n
        e = abs(t)
        off = off_out + pillow * (1 - t * t) - (off_out - off_in) * 0.45 * smoothstep(0.75, 1.0, e)
        prof.append((t * (1 - 0.06 * smoothstep(0.8, 1.0, e)), off))
    for j in range(prof_n + 1):  # inner, top->bottom
        t = 1 - 2 * j / prof_n
        prof.append((t * 0.96, off_in))
    np_ = len(prof)
    verts, faces = [], []
    for s_ in range(seg):
        az = 360.0 * s_ / seg - 180.0
        c, hw = lat_fn(az), half_fn(az)
        for (t, off) in prof:
            verts.append(D(az, c + t * hw) * (R + off))
    for s_ in range(seg):
        s2 = (s_ + 1) % seg
        for i in range(np_):
            i2 = (i + 1) % np_
            faces.append((s_ * np_ + i, s_ * np_ + i2, s2 * np_ + i2, s2 * np_ + i))
    return mesh_obj(name, verts, faces, material, subsurf=subsurf)

def ribbon_loop(name, pts2d, width, thick, material, res=24):
    """Closed flat ribbon loop (bow loop) from a planar outline in local XY; extrude = ribbon width."""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'; cu.resolution_u = res
    cu.extrude = width * 0.5
    cu.bevel_depth = thick * 0.5; cu.bevel_resolution = 2
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(len(pts2d) - 1)
    for bp, (x, y) in zip(sp.bezier_points, pts2d):
        bp.co = (x, y, 0); bp.handle_left_type = bp.handle_right_type = 'AUTO'
    sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu)
    cu.materials.append(material)
    return ob

def set_ramp(mname, bottom, top):
    cr = [n for n in bpy.data.materials[mname].node_tree.nodes if n.type == 'VALTORGB'][0].color_ramp
    cr.elements[0].color = (*bottom, 1); cr.elements[1].color = (*top, 1)

def add_rim(m, color, strength, blend=0.3):
    nt = m.node_tree; p = nt.nodes["Principled BSDF"]
    lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs["Blend"].default_value = blend
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = strength
    nt.links.new(lw.outputs["Facing"], mul.inputs[0])
    p.inputs["Emission Color"].default_value = (*color, 1)
    nt.links.new(mul.outputs[0], p.inputs["Emission Strength"])

def inspect(ch, center, dist, tz=0.0, views=(("front", 0), ("34", -40), ("side", 90), ("back", 180)),
            res=420, samples=12, out=None):
    root = bpy.data.objects[ch + "_Root"]
    rz = root.rotation_euler.z
    t = Vector(center) + Vector((0, 0, tz))
    bd = bpy.data.objects.get("STAGE_Backdrop")
    paths = []
    for vn, az in views:
        a = math.radians(az) + rz
        loc = t + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.9))
        if bd: bd.hide_render = (vn == "back")
        p = f"{SCRATCH}/insp_{ch}_{vn}.png"
        render_view(p, loc, t, lens=55, res=(res, res), only=[ch], samples=samples)
        paths.append(p)
    if bd: bd.hide_render = False
    contact_sheet([paths], out or f"{SCRATCH}/sheet_{ch}.png")

def clay_inspect(ch, center, dist, tz=0.0, res=420, samples=12, out=None,
                 views=(("front", 0), ("34", -40), ("side", 90), ("back", 180))):
    """Neutral clay pass: grey material override, white lights, grey world. Restores everything after."""
    sc = bpy.context.scene; vl = bpy.context.view_layer
    clay = bpy.data.materials.get("M_Clay") or mat("M_Clay", (0.62, 0.62, 0.64), rough=0.55)
    saved_l = {o.name: (tuple(o.data.color), o.data.energy) for o in bpy.data.objects if o.type == 'LIGHT'}
    bg = sc.world.node_tree.nodes["Background"]; saved_w = tuple(bg.inputs[0].default_value)
    saved_look = sc.view_settings.look
    for o in bpy.data.objects:
        if o.type == 'LIGHT':
            o.data.color = (1, 1, 1)
            if "Rim" in o.name: o.data.energy *= 0.5
    bg.inputs[0].default_value = (0.05, 0.05, 0.055, 1)
    vl.material_override = clay
    try:
        inspect(ch, center, dist, tz=tz, res=res, samples=samples, views=views,
                out=out or f"{SCRATCH}/clay_{ch}.png")
    finally:
        vl.material_override = None
        for n, (c, e) in saved_l.items():
            bpy.data.objects[n].data.color = c; bpy.data.objects[n].data.energy = e
        bg.inputs[0].default_value = saved_w
        sc.view_settings.look = saved_look
