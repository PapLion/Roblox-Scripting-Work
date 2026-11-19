# Shared helpers for the Neo characters (exec'd inside Blender via the MCP addon socket)
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler

# ---------------------------------------------------------------- collections
def get_coll(name, parent=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    par = parent or bpy.context.scene.collection
    if c.name not in [x.name for x in par.children]:
        par.children.link(c)
    return c

def char_setup(char, root_loc):
    """Create CHAR_<char> with semantic sub-collections and a root Empty. Wipes previous."""
    top = bpy.data.collections.get("CHAR_" + char)
    if top:
        for c in list(top.children_recursive) + [top]:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        for c in list(top.children_recursive):
            bpy.data.collections.remove(c)
    top = get_coll("CHAR_" + char)
    subs = {}
    for s in ("Core", "Face", "Hair", "Accessories", "Emissive"):
        subs[s] = get_coll(f"{char}_{s}", top)
    root = bpy.data.objects.new(f"{char}_Root", None)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 1.2
    root.location = root_loc
    top.objects.link(root)
    return root, subs

def link(obj, coll, root):
    coll.objects.link(obj)
    obj.parent = root
    return obj

# ---------------------------------------------------------------- materials
def mat(name, color, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_str=0.0,
        alpha=1.0, sss=0.0, spec=0.5, transmission=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial"); out.location = (400, 0)
    p = nt.nodes.new("ShaderNodeBsdfPrincipled"); p.location = (0, 0)
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Coat Weight"].default_value = coat
    p.inputs["Specular IOR Level"].default_value = spec
    p.inputs["Subsurface Weight"].default_value = sss
    p.inputs["Transmission Weight"].default_value = transmission
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = emit_str
    p.inputs["Alpha"].default_value = alpha
    nt.links.new(p.outputs[0], out.inputs[0])
    m.diffuse_color = (*color, 1)
    if alpha < 1.0:
        m.surface_render_method = 'BLENDED'
        m.use_transparency_overlap = True
    return m

def mat_gradient(name, c_bottom, c_top, rough=0.5, coat=0.0, sss=0.0, zmin=-1.0, zmax=1.0,
                 rim=None, rim_str=0.0):
    """Principled with a soft vertical gradient (object-space Z) and optional fresnel rim glow."""
    m = mat(name, c_top, rough=rough, coat=coat, sss=sss)
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); tc.location = (-900, 0)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); sep.location = (-700, 0)
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.location = (-520, 0)
    mr.inputs["From Min"].default_value = zmin
    mr.inputs["From Max"].default_value = zmax
    cr = nt.nodes.new("ShaderNodeValToRGB"); cr.location = (-330, 0)
    cr.color_ramp.elements[0].color = (*c_bottom, 1)
    cr.color_ramp.elements[1].color = (*c_top, 1)
    cr.color_ramp.interpolation = 'EASE'
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], cr.inputs["Fac"])
    nt.links.new(cr.outputs["Color"], p.inputs["Base Color"])
    if rim:
        lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.location = (-520, -300)
        lw.inputs["Blend"].default_value = 0.35
        mul = nt.nodes.new("ShaderNodeMath"); mul.location = (-330, -300)
        mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = rim_str
        nt.links.new(lw.outputs["Facing"], mul.inputs[0])
        p.inputs["Emission Color"].default_value = (*rim, 1)
        nt.links.new(mul.outputs[0], p.inputs["Emission Strength"])
    return m

def mat_emit(name, color, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*color, 1)
    e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], out.inputs[0])
    m.diffuse_color = (*color, 1)
    return m

# ---------------------------------------------------------------- mesh utils
def mesh_obj(name, verts, faces, material=None, smooth=True, subsurf=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate(clean_customdata=False)
    me.update()
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    if material:
        me.materials.append(material)
    if subsurf:
        md = ob.modifiers.new("Subsurf", 'SUBSURF')
        md.levels = subsurf; md.render_levels = subsurf
    return ob

def uv_sphere(name, R, material=None, seg=48, rings=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=R)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    if material:
        me.materials.append(material)
    return ob

def D(az, el):
    """Unit direction from azimuth/elevation in degrees. az=0 -> front (-Y), +az -> +X."""
    a, e = math.radians(az), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))

def slerp(a, b, t):
    a = a.normalized(); b = b.normalized()
    dot = max(-1.0, min(1.0, a.dot(b)))
    om = math.acos(dot)
    if om < 1e-5:
        return (a + (b - a) * t).normalized()
    s = math.sin(om)
    return (a * (math.sin((1 - t) * om) / s) + b * (math.sin(t * om) / s)).normalized()

def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- tube / lock
def tube_mesh(spine, width_fn, thick_fn, center=Vector((0, 0, 0)), M=8, crescent=0.25,
              up_hint=None, twist=0.0):
    """Sweep an elliptical (slightly crescent) section along spine. Returns verts, faces.
    Section normal axis points away from `center` (radial) so locks lie flat on a head."""
    n = len(spine)
    verts, faces = [], []
    for i, P in enumerate(spine):
        s = i / (n - 1)
        if i == 0:
            T = spine[1] - spine[0]
        elif i == n - 1:
            T = spine[-1] - spine[-2]
        else:
            T = spine[i + 1] - spine[i - 1]
        T.normalize()
        N0 = (up_hint if up_hint is not None else (P - center))
        if N0.length < 1e-6:
            N0 = Vector((0, 0, 1))
        N0 = N0.normalized()
        N = (N0 - T * N0.dot(T))
        if N.length < 1e-6:
            N = T.orthogonal()
        N.normalize()
        B = T.cross(N).normalized()
        if twist:
            ang = twist * s
            N, B = (N * math.cos(ang) + B * math.sin(ang)), (B * math.cos(ang) - N * math.sin(ang))
        if i == n - 1:
            verts.append(P.copy())
            continue
        w = width_fn(s) * 0.5
        h = thick_fn(s) * 0.5
        for k in range(M):
            a = 2 * math.pi * k / M
            x = math.cos(a) * w
            y = math.sin(a) * h - crescent * h * (math.cos(a) ** 2) * 1.0
            verts.append(P + B * x + N * y)
    rings = n - 1
    for i in range(rings - 1):
        for k in range(M):
            a = i * M + k; b = i * M + (k + 1) % M
            c = (i + 1) * M + (k + 1) % M; d = (i + 1) * M + k
            faces.append((a, b, c, d))
    tip = len(verts) - 1
    last = (rings - 1) * M
    for k in range(M):
        faces.append((last + k, last + (k + 1) % M, tip))
    # root cap
    rc = len(verts)
    root_c = sum((verts[k] for k in range(M)), Vector()) / M
    verts.append(root_c)
    for k in range(M):
        faces.append(((k + 1) % M, k, rc))
    return verts, faces

def head_spine(R, d0, d1, n=16, lift0=0.03, lift1=0.3, ext=1.0, sweep=None, droop=0.0,
               center=Vector((0, 0, 0))):
    """Spine hugging a sphere from direction d0 toward d1 (slerp, extrapolated to `ext`),
    radius growing quadratically so tips flare away. sweep: extra offset vector * s^2.
    droop: pulls the tip down (gravity) * s^3."""
    pts = []
    for i in range(n):
        s = i / (n - 1)
        t = s * ext
        d = slerp(d0, d1, t)
        r = R * (1 + lift0 + lift1 * s * s)
        p = center + d * r
        if sweep is not None:
            p = p + Vector(sweep) * (s * s)
        if droop:
            p = p + Vector((0, 0, -droop)) * (s ** 3)
        pts.append(p)
    return pts

def lock(name, R, d0, d1, width=0.3, thick=0.08, material=None, lift0=None, lift1=0.3, ext=1.0,
         sweep=None, droop=0.0, taper=1.2, crescent=0.35, n=16, subsurf=1, twist=0.0):
    if lift0 is None:
        lift0 = thick * 0.45 / R
    spine = head_spine(R, D(*d0), D(*d1), n=n, lift0=lift0, lift1=lift1, ext=ext, sweep=sweep,
                       droop=droop)
    wf = lambda s: width * (0.72 + 0.28 * smoothstep(0, 0.22, s)) * ((1 - s) ** taper) + 0.004
    tf = lambda s: thick * ((1 - s) ** 0.55) + 0.004
    v, f = tube_mesh(spine, wf, tf, M=8, crescent=crescent, twist=twist)
    return mesh_obj(name, v, f, material, subsurf=subsurf)

def spine_lock(name, spine, width=0.1, thick=0.05, material=None, taper=1.0, crescent=0.2,
               center=Vector((0, 0, 0)), subsurf=1, profile=None, up_hint=None, M=8, twist=0.0):
    """Lock/ribbon along an explicit spine. profile(s)->width factor overrides taper."""
    if profile is None:
        wf = lambda s: width * ((1 - s) ** taper) + 0.003
    else:
        wf = lambda s: width * profile(s) + 0.003
    tf = lambda s: thick * ((1 - s) ** 0.5) + 0.003
    v, f = tube_mesh([Vector(p) for p in spine], wf, tf, center=center, M=M, crescent=crescent,
                     up_hint=up_hint, twist=twist)
    return mesh_obj(name, v, f, material, subsurf=subsurf)

def catmull(points, per=6):
    """Catmull-Rom resample of control points -> smooth spine."""
    P = [Vector(p) for p in points]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for j in range(per):
            t = j / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return out

# ---------------------------------------------------------------- curves
def curve_tube(name, points, radius=0.02, material=None, cyclic=False, res=12, bevel_res=4,
               taper_end=False):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.resolution_u = res
    cu.bevel_depth = radius
    cu.bevel_resolution = bevel_res
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER')
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = Vector(p)
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    sp.use_cyclic_u = cyclic
    if taper_end:
        for i, bp in enumerate(sp.bezier_points):
            bp.radius = 1.0 - 0.85 * (i / (len(points) - 1)) ** 2
    ob = bpy.data.objects.new(name, cu)
    if material:
        cu.materials.append(material)
    return ob

def ellipse_ring(name, rx, ry, radius, material=None, n=8):
    pts = [(rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n), 0) for i in range(n)]
    return curve_tube(name, pts, radius, material, cyclic=True, res=16)

# ---------------------------------------------------------------- sphere decals
def outline_ellipse(cu, cv, ru, rv, rot=0.0, n=32):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = ru * math.cos(a), rv * math.sin(a)
        c, s = math.cos(rot), math.sin(rot)
        out.append((cu + x * c - y * s, cv + x * s + y * c))
    return out

def outline_capsule(p0, p1, r, n=12):
    (x0, y0), (x1, y1) = p0, p1
    ang = math.atan2(y1 - y0, x1 - x0)
    out = []
    for i in range(n + 1):
        a = ang - math.pi / 2 - math.pi * i / n
        out.append((x0 + r * math.cos(a), y0 + r * math.sin(a)))
    for i in range(n + 1):
        a = ang + math.pi / 2 - math.pi * i / n
        out.append((x1 + r * math.cos(a), y1 + r * math.sin(a)))
    return out

def decal(name, outline_deg, R, h_out=0.02, h_in=0.03, material=None, rings=4, center=Vector((0, 0, 0))):
    """Convex 2D outline (az,el in degrees) wrapped on a sphere of radius R as a thin solid.
    Front cap at R+h_out (domed), back hidden inside at R-h_in."""
    n = len(outline_deg)
    cu = sum(p[0] for p in outline_deg) / n
    cv = sum(p[1] for p in outline_deg) / n
    verts, faces = [], []
    # front cap: concentric rings, outer ring index 0
    for r in range(rings):
        f = 1 - r / rings
        dome = (1 - f * f) * 0.35  # slight dome toward centre
        for (u, v) in outline_deg:
            uu, vv = cu + (u - cu) * f, cv + (v - cv) * f
            verts.append(center + D(uu, vv) * (R + h_out * (0.65 + dome)))
    verts.append(center + D(cu, cv) * (R + h_out * 1.0))
    cidx = len(verts) - 1
    for r in range(rings - 1):
        for k in range(n):
            a = r * n + k; b = r * n + (k + 1) % n
            faces.append((a, b, b + n, a + n))
    last = (rings - 1) * n
    for k in range(n):
        faces.append((last + k, last + (k + 1) % n, cidx))
    # side wall down to back ring
    base = len(verts)
    for (u, v) in outline_deg:
        verts.append(center + D(u, v) * (R - h_in))
    for k in range(n):
        a = k; b = (k + 1) % n
        faces.append((base + a, base + b, b, a))
    bc = len(verts)
    verts.append(center + D(cu, cv) * (R - h_in))
    for k in range(n):
        faces.append((base + (k + 1) % n, base + k, bc))
    ob = mesh_obj(name, verts, faces, material, smooth=True)
    return ob

# ---------------------------------------------------------------- revolve
def revolve(name, profile_rz, seg=64, material=None, wobble=None, subsurf=1, closed_profile=True):
    """Revolve (r,z) profile around Z. wobble(theta, i)->radial multiplier for folds."""
    np_ = len(profile_rz)
    verts, faces = [], []
    for s in range(seg):
        th = 2 * math.pi * s / seg
        for i, (r, z) in enumerate(profile_rz):
            k = wobble(th, i) if wobble else 1.0
            verts.append((r * k * math.cos(th), r * k * math.sin(th), z))
    for s in range(seg):
        s2 = (s + 1) % seg
        rng = np_ if closed_profile else np_ - 1
        for i in range(rng):
            i2 = (i + 1) % np_
            faces.append((s * np_ + i, s2 * np_ + i, s2 * np_ + i2, s * np_ + i2))
    return mesh_obj(name, verts, faces, material, subsurf=subsurf)

def rounded_rect_profile(cx, cz, hw, hh, rr, n=4):
    """Rounded rectangle in (r,z), counter-clockwise."""
    pts = []
    corners = [(cx + hw - rr, cz - hh + rr, -90), (cx + hw - rr, cz + hh - rr, 0),
               (cx - hw + rr, cz + hh - rr, 90), (cx - hw + rr, cz - hh + rr, 180)]
    for (x, z, a0) in corners:
        for j in range(n + 1):
            a = math.radians(a0 + 90 * j / n)
            pts.append((x + rr * math.cos(a), z + rr * math.sin(a)))
    return pts

def circle_profile(cx, cz, rx, rz, n=16):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cz + rz * math.sin(2 * math.pi * i / n)) for i in range(n)]

def box(name, size, material=None, bevel=0.01):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    if material:
        me.materials.append(material)
    if bevel:
        md = ob.modifiers.new("Bevel", 'BEVEL'); md.width = bevel; md.segments = 3
        md.limit_method = 'NONE'
    me.shade_smooth()
    return ob

def look_rot(direction, up=Vector((0, 0, 1))):
    """Rotation (Euler) whose local -Y axis... we use local +Z = direction (outward normal)."""
    z = Vector(direction).normalized()
    x = up.cross(z)
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_euler()

# ---------------------------------------------------------------- staging / rendering
SCRATCH = "/home/dani.pp/Downloads/job/renders/_tmp"
import os as _os; _os.makedirs(SCRATCH, exist_ok=True)

def get_cam(name="CAM_Inspect"):
    st = get_coll("STAGE")
    cam = bpy.data.objects.get(name)
    if cam is None:
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        st.objects.link(cam)
    return cam

def aim(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()

def render_view(path, cam_loc, target, lens=50, res=(900, 700), only=None, samples=32, cam="CAM_Inspect"):
    sc = bpy.context.scene
    c = get_cam(cam)
    c.location = Vector(cam_loc); aim(c, target)
    c.data.lens = lens
    sc.camera = c
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.eevee.taa_render_samples = samples
    if only is not None:
        for ch in ("Nix", "Yoru", "Akemi"):
            col = bpy.data.collections.get("CHAR_" + ch)
            if col:
                col.hide_render = (ch not in only)
    sc.render.filepath = path
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    if only is not None:
        for ch in ("Nix", "Yoru", "Akemi"):
            col = bpy.data.collections.get("CHAR_" + ch)
            if col:
                col.hide_render = False

def hair_cap(name, R, el_limit, material=None, naz=48, nel=12, subsurf=1):
    """Shell covering the scalp above el_limit(az) (degrees) at radius R. Solid (2 layers)."""
    verts, faces = [], []
    for layer, rr in enumerate((R, R - 0.03)):
        for i in range(nel + 1):
            for j in range(naz):
                az = 360.0 * j / naz - 180.0
                lo = el_limit(az)
                el = lo + (88.0 - lo) * (i / nel) ** 0.9
                verts.append(D(az, el) * rr)
    L = (nel + 1) * naz
    for layer in range(2):
        off = layer * L
        for i in range(nel):
            for j in range(naz):
                j2 = (j + 1) % naz
                q = (off + i * naz + j, off + i * naz + j2, off + (i + 1) * naz + j2, off + (i + 1) * naz + j)
                faces.append(q if layer == 0 else q[::-1])
    # close the hole at the top & bottom rim
    for layer in range(2):
        pass
    top_o = len(verts); verts.append(Vector((0, 0, R)))
    top_i = len(verts); verts.append(Vector((0, 0, R - 0.03)))
    for j in range(naz):
        j2 = (j + 1) % naz
        faces.append((nel * naz + j, nel * naz + j2, top_o))
        faces.append((L + nel * naz + j2, L + nel * naz + j, top_i))
    for j in range(naz):
        j2 = (j + 1) % naz
        faces.append((L + j, L + j2, j2, j))
    return mesh_obj(name, verts, faces, material, subsurf=subsurf)

def contact_sheet(paths_grid, out):
    """paths_grid: list of rows of png paths (same size). Composited with numpy inside Blender."""
    import numpy as np
    rows = []
    for row in paths_grid:
        tiles = []
        for p in row:
            im = bpy.data.images.load(p, check_existing=False)
            w, h = im.size
            a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
            tiles.append(a); bpy.data.images.remove(im)
        rows.append(np.concatenate(tiles, axis=1))
    sheet = np.concatenate(rows[::-1], axis=0)  # blender images are bottom-up
    H, W = sheet.shape[:2]
    img = bpy.data.images.new("tmp_sheet", W, H, alpha=True)
    img.pixels = sheet.ravel()
    img.filepath_raw = out; img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)
