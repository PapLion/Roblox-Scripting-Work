"""Shared helpers for the Roblox props portfolio (Blender 5.2).

Convention for every asset (local space, metres):
  * origin  = grip point (where the hand holds it)  -> pivot for equipping
  * +Z      = long axis toward the head / blade tip
  * +X      = direction of the cutting edge / striking face
  * Y       = thickness (broad side faces the front camera)
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

ROOT = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio"
TAU = math.tau


# ----------------------------------------------------------------- utils
def V(x=0.0, y=0.0, z=0.0):
    return Vector((x, y, z))


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def interp(table, x):
    """Piecewise-linear interpolation over [(x, value), ...] (values may be tuples)."""
    if x <= table[0][0]:
        return table[0][1]
    for (x0, v0), (x1, v1) in zip(table, table[1:]):
        if x <= x1:
            t = (x - x0) / (x1 - x0)
            if isinstance(v0, tuple):
                return tuple(lerp(a, b, t) for a, b in zip(v0, v1))
            return lerp(v0, v1, t)
    return table[-1][1]


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip('#')
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1.0,)


# ------------------------------------------------------------- collections
def get_coll(name, parent=None):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(c)
    return c


def clear_coll(c):
    for o in list(c.objects):
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Mesh) and data.users == 0:
            bpy.data.meshes.remove(data)


# --------------------------------------------------------------- materials
# name: (hex sRGB, metallic, roughness, presentation-kind)
PALETTE = {
    "M_Steel":       ("#8E99A8", 1.0, 0.30, "metal"),
    "M_SteelDark":   ("#646C78", 1.0, 0.40, "metal"),
    "M_Wood":        ("#87573A", 0.0, 0.58, "wood"),
    "M_Leather":     ("#3B261B", 0.0, 0.62, "leather"),
    "M_Brass":       ("#C39A4C", 1.0, 0.32, "metal"),
    "M_Copper":      ("#B86E45", 1.0, 0.34, "metal"),
    "M_Paint_Red":   ("#A8352C", 0.0, 0.48, "paint"),
    "M_Paint_Amber": ("#D9982C", 0.0, 0.48, "paint"),
    "M_Paint_Teal":  ("#2E8A84", 0.0, 0.42, "paint"),
    "M_Gem_Blue":    ("#2F6FD6", 0.0, 0.10, "gem"),
    "M_Gem_Green":   ("#2FA56E", 0.0, 0.10, "gem"),
    # ---- shooter line
    "M_Gunmetal":    ("#4A515B", 1.0, 0.36, "metal"),
    "M_Polymer":     ("#2C3035", 0.0, 0.58, "paint"),
    "M_Polymer_Tan": ("#A08763", 0.0, 0.60, "paint"),
    "M_Paint_Orange":("#E2702B", 0.0, 0.45, "paint"),
    "M_Paint_OD":    ("#56603F", 0.25, 0.50, "paint"),
    "M_Rubber":      ("#1C1E21", 0.0, 0.80, "leather"),
    "M_Shell_Red":   ("#B23A2E", 0.0, 0.40, "paint"),
    # ---- characters / creatures / vehicles
    "M_Skin":        ("#E9B98F", 0.0, 0.55, "paint"),
    "M_Cloth_Blue":  ("#3D5E9C", 0.0, 0.75, "leather"),
    "M_Cloth_Gray":  ("#4B505B", 0.0, 0.80, "leather"),
    "M_Cloth_Cream": ("#DCCFB2", 0.0, 0.75, "leather"),
    "M_Face":        ("#231C1C", 0.0, 0.45, "paint"),
    "M_Eye_White":   ("#F4F1EA", 0.0, 0.25, "paint"),
    "M_Slime":       ("#5ED66E", 0.0, 0.16, "gem"),
    "M_Slime_Dark":  ("#1F4A2B", 0.0, 0.40, "paint"),
    "M_Gold":        ("#E3B23C", 1.0, 0.26, "metal"),
    "M_Gem_Red":     ("#D3344A", 0.0, 0.10, "gem"),
    "M_Bone":        ("#E3D8BE", 0.0, 0.62, "paint"),
    "M_Bone_Dark":   ("#3A302A", 0.0, 0.70, "paint"),
    "M_Glow":        ("#FF7A3A", 0.0, 0.40, "gem"),
    "M_Rust":        ("#6E4630", 0.45, 0.78, "metal"),
    "M_CarPaint":    ("#2C8C99", 0.3, 0.28, "paint"),
    "M_CarWhite":    ("#E7E8E4", 0.0, 0.35, "paint"),
    "M_Glass":       ("#A9CBD8", 0.0, 0.05, "glass"),
    "M_Chrome":      ("#C9CFD7", 1.0, 0.16, "metal"),
    "M_HeadLight":   ("#F6F3E4", 0.0, 0.15, "gem"),
    "M_TailLight":   ("#C42E2B", 0.0, 0.20, "gem"),
    "M_Seat":        ("#3C4048", 0.0, 0.85, "leather"),
    "M_Interior":    ("#5B616B", 0.0, 0.70, "paint"),
    "M_Fur":         ("#5B3E2C", 0.0, 0.85, "leather"),
    "M_Fur_Dark":    ("#3A291E", 0.0, 0.90, "leather"),
    "M_Snout":       ("#6E4A3E", 0.0, 0.60, "paint"),
    "M_Tusk":        ("#EEE4C9", 0.0, 0.40, "paint"),
    "M_Hoof":        ("#2B2523", 0.0, 0.60, "paint"),
    "M_Mannequin":   ("#B9BDC3", 0.0, 0.60, "paint"),
    # urban / shop props
    "M_Vend_Red":    ("#C73A35", 0.0, 0.36, "paint"),
    "M_Vend_Dark":   ("#26292E", 0.0, 0.45, "paint"),
    "M_Vend_Inner":  ("#D6D9DC", 0.0, 0.55, "paint"),
    "M_LampGlow":    ("#FFE3AE", 0.0, 0.35, "glow"),
    "M_Bin_Green":   ("#3E7A55", 0.0, 0.55, "paint"),
    "M_Bin_Lid":     ("#2F6044", 0.0, 0.50, "paint"),
    "M_Iron":        ("#2E3533", 0.6, 0.45, "metal"),
    "M_AC_Shell":    ("#E6E4DE", 0.0, 0.42, "paint"),
    "M_Shelf_White": ("#E1E3E5", 0.2, 0.40, "paint"),
    "M_Shelf_Accent":("#2F6FB5", 0.0, 0.45, "paint"),
    "M_Alu":         ("#C3C8CE", 1.0, 0.28, "metal"),
    "M_Label":       ("#F3F1EA", 0.0, 0.50, "paint"),
    "M_Prod_Yellow": ("#F0BE2E", 0.0, 0.42, "paint"),
    "M_Prod_Blue":   ("#2F73D0", 0.0, 0.30, "paint"),
    "M_Prod_Green":  ("#45A863", 0.0, 0.42, "paint"),
    "M_Prod_Pink":   ("#E36A93", 0.0, 0.42, "paint"),
    "M_Prod_Purple": ("#7656C4", 0.0, 0.42, "paint"),
    "M_WoodBench":   ("#9C6B45", 0.0, 0.55, "wood"),
    "M_GlassClear":  ("#D3E6EC", 0.0, 0.04, "glass"),
    "M_SlimeBlue":   ("#3F8FE3", 0.0, 0.10, "gem"),
    "M_SlimeMouth":  ("#14304F", 0.0, 0.30, "paint"),
}


def _node(nt, t, loc):
    n = nt.nodes.new(t)
    n.location = loc
    return n


def make_mat(name):
    """Principled material.  The BSDF *default values* are the export values
    (written to FBX).  Extra procedural nodes ("presentation layer") are only
    for the portfolio renders and are stripped by export_fbx.py."""
    hx, metal, rough, kind = PALETTE[name]
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    out = _node(nt, 'ShaderNodeOutputMaterial', (600, 0))
    bsdf = _node(nt, 'ShaderNodeBsdfPrincipled', (300, 0))
    nt.links.new(bsdf.outputs[0], out.inputs['Surface'])
    col = hexcol(hx)
    bsdf.inputs['Base Color'].default_value = col
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = rough
    m.diffuse_color = col
    m.metallic = metal
    m.roughness = rough
    m["export_color_hex"] = hx
    m["presentation_kind"] = kind
    if kind == "glow":
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = 3.0
    if name == "M_Glow":
        bsdf.inputs['Emission Color'].default_value = col
        bsdf.inputs['Emission Strength'].default_value = 6.0
    if kind == "gem":
        bsdf.inputs['IOR'].default_value = 1.6
        try:
            bsdf.inputs['Coat Weight'].default_value = 0.6
            bsdf.inputs['Emission Color'].default_value = col
            bsdf.inputs['Emission Strength'].default_value = 6.0 if name == "M_Glow" else 0.15
        except KeyError:
            pass

    if name == "M_SlimeBlue":                       # jelly: soft subsurface glow + clear coat
        for k_, v_ in (('Subsurface Weight', 0.45), ('Subsurface Scale', 0.12), ('Coat Weight', 1.0),
                       ('Coat Roughness', 0.04), ('Emission Strength', 0.10)):
            try:
                bsdf.inputs[k_].default_value = v_
            except KeyError:
                pass
        try:
            bsdf.inputs['Subsurface Radius'].default_value = (0.5, 0.8, 1.0)
        except KeyError:
            pass
    if kind == "glass":
        bsdf.inputs['Alpha'].default_value = 0.14 if name == "M_GlassClear" else 0.32
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    # ---------------- presentation layer (render only) -------------------
    tc = _node(nt, 'ShaderNodeTexCoord', (-1000, 0))
    mp = _node(nt, 'ShaderNodeMapping', (-800, 0))
    nt.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    noise = _node(nt, 'ShaderNodeTexNoise', (-600, 0))
    nt.links.new(mp.outputs[0], noise.inputs['Vector'])
    for n in (tc, mp, noise):
        n["presentation"] = True
    if kind == "wood":
        # long streaks along local Z = grain along handles / planks
        mp.inputs['Scale'].default_value = (4, 55, 55) if name == "M_WoodBench" else (55, 55, 4)
        noise.inputs['Scale'].default_value = 2.0
        noise.inputs['Detail'].default_value = 6
        noise.inputs['Distortion'].default_value = 0.6
        ramp = _node(nt, 'ShaderNodeValToRGB', (-350, 100))
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[1].position = 0.75
        ramp.color_ramp.elements[0].color = tuple(c * 0.78 for c in col[:3]) + (1,)
        ramp.color_ramp.elements[1].color = tuple(min(1, c * 1.12) for c in col[:3]) + (1,)
        ramp["presentation"] = True
        nt.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], bsdf.inputs['Base Color'])
    elif kind in ("metal", "paint", "leather"):
        mp.inputs['Scale'].default_value = (1, 1, 1)
        noise.inputs['Scale'].default_value = 25 if kind != "leather" else 140
        noise.inputs['Detail'].default_value = 4
        mr = _node(nt, 'ShaderNodeMapRange', (-350, -150))
        k = 0.035 if kind == "metal" else 0.06
        mr.inputs['To Min'].default_value = rough - k
        mr.inputs['To Max'].default_value = rough + k
        mr["presentation"] = True
        nt.links.new(noise.outputs['Fac'], mr.inputs['Value'])
        nt.links.new(mr.outputs['Result'], bsdf.inputs['Roughness'])
        if kind == "leather":
            bump = _node(nt, 'ShaderNodeBump', (0, -300))
            bump.inputs['Strength'].default_value = 0.12
            bump.inputs['Distance'].default_value = 0.0005
            bump["presentation"] = True
            nt.links.new(noise.outputs['Fac'], bump.inputs['Height'])
            nt.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
    if name in WEAR:
        # light, controlled wear (presentation only): sun-faded patches + AO grime in creases
        fade = _node(nt, 'ShaderNodeTexNoise', (-600, 300))
        fade.inputs['Scale'].default_value = WEAR[name][0]
        fade.inputs['Detail'].default_value = 3
        nt.links.new(mp.outputs[0], fade.inputs['Vector'])
        fr = _node(nt, 'ShaderNodeValToRGB', (-350, 350))
        fr.color_ramp.elements[0].position = 0.35
        fr.color_ramp.elements[1].position = 0.70
        fr.color_ramp.elements[0].color = tuple(c * 0.90 for c in col[:3]) + (1,)
        fr.color_ramp.elements[1].color = tuple(min(1, c * 1.10 + 0.01) for c in col[:3]) + (1,)
        nt.links.new(fade.outputs['Fac'], fr.inputs['Fac'])
        ao = _node(nt, 'ShaderNodeAmbientOcclusion', (-600, 550))
        ao.inputs['Distance'].default_value = WEAR[name][1]
        ar = _node(nt, 'ShaderNodeValToRGB', (-350, 600))
        ar.color_ramp.elements[0].position = 0.0
        ar.color_ramp.elements[0].color = (0.55, 0.55, 0.52, 1)
        ar.color_ramp.elements[1].position = 0.85
        mix = _node(nt, 'ShaderNodeMix', (-100, 400))
        mix.data_type = 'RGBA'
        mix.blend_type = 'MULTIPLY'
        mix.inputs['Factor'].default_value = 1.0
        nt.links.new(ao.outputs['AO'], ar.inputs['Fac'])
        nt.links.new(fr.outputs['Color'], mix.inputs[6])
        nt.links.new(ar.outputs['Color'], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
        for n in (fade, fr, ao, ar, mix):
            n["presentation"] = True
    return m


WEAR = {"M_Bone": (6.0, 0.05), "M_Rust": (8.0, 0.04), "M_Fur": (4.0, 0.12), "M_Fur_Dark": (4.0, 0.10),
        "M_Bin_Green": (3.0, 0.10), "M_Bin_Lid": (3.0, 0.10), "M_Iron": (6.0, 0.05), "M_AC_Shell": (2.5, 0.06)}


def mats():
    return {k: make_mat(k) for k in PALETTE}


# -------------------------------------------------------------- 2D shapes
def ellipse(rx, ry, n, phase=0.0):
    return [(rx * math.cos(phase + TAU * i / n), ry * math.sin(phase + TAU * i / n)) for i in range(n)]


def chamfer_rect(hx, hy, c):
    """Octagon: rectangle half-sizes hx, hy with 45deg chamfer c (CCW from +X)."""
    c = min(c, hx * 0.95, hy * 0.95)
    return [(hx, -hy + c), (hx, hy - c), (hx - c, hy), (-hx + c, hy),
            (-hx, hy - c), (-hx, -hy + c), (-hx + c, -hy), (hx - c, -hy)]


def round_rect(hx, hy, r, seg=2):
    """Rounded rectangle, 4*(seg+1) points CCW starting near +X."""
    r = min(r, hx * 0.98, hy * 0.98)
    pts = []
    for cx, cy, a0 in ((hx - r, hy - r, 0), (-hx + r, hy - r, 90), (-hx + r, -hy + r, 180), (hx - r, -hy + r, 270)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def rounded_box(bm, c, hx, hy, hz, r, seg=2, rz=None, taper=(1.0, 1.0)):
    """Rounded box around centre c (axis aligned). r = edge radius; rz = radius of
    the top/bottom edges (defaults to r).  taper = (scale at bottom, scale at top) in XY."""
    rz = r if rz is None else rz
    rings = []
    prof = []
    for k in range(seg + 1):                       # bottom quarter
        a = math.pi / 2 * (1 - k / seg)
        prof.append((-hz + rz - rz * math.sin(a), rz * (1 - math.cos(a))))
    for k in range(seg + 1):                       # top quarter
        a = math.pi / 2 * k / seg
        prof.append((hz - rz + rz * math.sin(a), rz * (1 - math.cos(a))))
    for z, inset in prof:
        t = (z + hz) / (2 * hz)
        sc = lerp(taper[0], taper[1], t)
        ax, ay = hx * sc - inset, hy * sc - inset
        rr = min(max(0.3 * r, r - inset), ax * 0.95, ay * 0.95)
        rings.append(place(round_rect(ax, ay, rr, seg), c + V(0, 0, z), V(1, 0, 0), V(0, 1, 0)))
    return loft(bm, rings, cap0='ngon', cap1='ngon')


def area2d(poly):
    return 0.5 * sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                     for i in range(len(poly)))


def ccw(poly):
    return list(poly) if area2d(poly) > 0 else list(reversed(poly))


def fillet(poly, r, seg=2):
    """Round every corner of a polygon with radius r (clamped per corner).
    r may be a list (one radius per vertex)."""
    n = len(poly)
    out = []
    for i in range(n):
        p0 = Vector(poly[i - 1]); p1 = Vector(poly[i]); p2 = Vector(poly[(i + 1) % n])
        ri = r[i] if isinstance(r, (list, tuple)) else r
        a = (p0 - p1); b = (p2 - p1)
        la, lb = a.length, b.length
        if ri <= 0 or la < 1e-9 or lb < 1e-9:
            out.append((p1.x, p1.y)); continue
        a.normalize(); b.normalize()
        ang = math.acos(max(-1, min(1, a.dot(b))))
        if ang > math.radians(175):
            out.append((p1.x, p1.y)); continue
        t = ri / math.tan(ang / 2)
        t = min(t, la * 0.45, lb * 0.45)
        ri = t * math.tan(ang / 2)
        q0 = p1 + a * t; q1 = p1 + b * t
        bis = (a + b).normalized()
        c = p1 + bis * (ri / math.sin(ang / 2))
        v0 = q0 - c; v1 = q1 - c
        a0 = math.atan2(v0.y, v0.x); a1 = math.atan2(v1.y, v1.x)
        da = (a1 - a0 + math.pi) % TAU - math.pi
        for k in range(seg + 1):
            aa = a0 + da * k / seg
            out.append((c.x + ri * math.cos(aa), c.y + ri * math.sin(aa)))
    return out


def prism_xz(bm, outline, y0, y1, chamfer=0.0015, r=0.0, seg=2):
    """Side-profile extrusion: outline in (X, Z), extruded across Y from y0 to y1."""
    pts = ccw(fillet(outline, r, seg) if r else outline)
    return prism(bm, pts, V(0, (y0 + y1) / 2, 0), V(1, 0, 0), V(0, 0, 1), V(0, -1, 0), abs(y1 - y0) / 2, chamfer)


def set_origin(ob, p_local):
    """Move the object origin to p_local (in parent space) without moving geometry."""
    d = Vector(p_local) - Vector(ob.location)
    ob.data.transform(Matrix.Translation(-d))
    ob.location = Vector(ob.location) + d


def offset_poly(pts, d):
    """Offset a convex/simple CCW polygon outward by d (negative = inset)."""
    n = len(pts)
    out = []
    for i in range(n):
        p0 = Vector(pts[i - 1]); p1 = Vector(pts[i]); p2 = Vector(pts[(i + 1) % n])
        e0 = (p1 - p0).normalized(); e1 = (p2 - p1).normalized()
        n0 = Vector((e0.y, -e0.x)); n1 = Vector((e1.y, -e1.x))
        b = (n0 + n1)
        if b.length < 1e-9:
            b = n0
        b.normalize()
        s = d / max(0.25, b.dot(n0))
        q = p1 + b * s
        out.append((q.x, q.y))
    return out


# ------------------------------------------------------------- 3D building
def place(pts2d, o, u, v):
    return [o + u * x + v * y for x, y in pts2d]


def path_frames(pts, up=V(0, 1, 0)):
    """For a polyline return [(p, t, u, v)] with v ~ up."""
    res = []
    n = len(pts)
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]; b = pts[min(n - 1, i + 1)]
        t = (b - a).normalized()
        u = up.cross(t)
        if u.length < 1e-6:
            u = V(1, 0, 0)
        u.normalize()
        v = t.cross(u).normalized()
        res.append((p, t, u, v))
    return res


def loft(bm, rings, closed=True, cap0=None, cap1=None, wrap=False):
    """rings: list of lists of Vector (same count). cap: None | 'ngon' | Vector (fan point).
    wrap=True connects the last ring back to the first (torus-like, no caps)."""
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    faces = []
    pairs = list(zip(vs, vs[1:])) + ([(vs[-1], vs[0])] if wrap else [])
    for a, b in pairs:
        for j in range(n if closed else n - 1):
            k = (j + 1) % n
            faces.append(bm.faces.new((a[j], a[k], b[k], b[j])))
    for cap, ring in ((cap0, vs[0]), (cap1, vs[-1])):
        if cap is None:
            continue
        if isinstance(cap, str):
            faces.append(bm.faces.new(ring))
        else:
            c = bm.verts.new(cap)
            for j in range(n):
                faces.append(bm.faces.new((ring[j], ring[(j + 1) % n], c)))
    return faces


def lathe(bm, profile, axis_o, axis, n, ref=None, phase=0.0):
    """Revolve [(r, h), ...] around axis. Points with r==0 become single poles."""
    axis = axis.normalized()
    if ref is None:
        ref = V(1, 0, 0) if abs(axis.x) < 0.9 else V(0, 0, 1)
    u = (ref - axis * ref.dot(axis)).normalized()
    v = axis.cross(u)
    rows = []
    for r, h in profile:
        c = axis_o + axis * h
        if r < 1e-9:
            rows.append([bm.verts.new(c)])
        else:
            rows.append([bm.verts.new(c + (u * math.cos(phase + TAU * i / n) + v * math.sin(phase + TAU * i / n)) * r)
                         for i in range(n)])
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    return rows


def prism(bm, outline, o, u, v, w, depth, chamfer):
    """Extrude a CCW 2D outline (in u,v) along w by +-depth with chamfered caps."""
    if chamfer <= 0:                                  # flat decal: no bevel rings
        return loft(bm, [place(outline, o + w * depth, u, v), place(outline, o - w * depth, u, v)],
                    cap0='ngon', cap1='ngon')
    inner = offset_poly(outline, -chamfer)
    rings = [place(inner, o + w * depth, u, v),
             place(outline, o + w * (depth - chamfer), u, v),
             place(outline, o - w * (depth - chamfer), u, v),
             place(inner, o - w * depth, u, v)]
    return loft(bm, rings, cap0='ngon', cap1='ngon')


def helix_strap(bm, frame_at, z0, z1, pitch, width, thick, seg_per_turn=12, sink=0.0006, phase=0.0):
    """Leather strap wound around a shaft.  frame_at(z) -> (centre, u, v, rx, ry).
    Section is a shingle: thin at the lower edge, thick at the upper edge."""
    turns = (z1 - z0) / pitch
    n = max(2, int(round(turns * seg_per_turn)) + 1)
    # section in (radial offset, axial offset)
    sec = [(-sink, -width / 2), (thick * 0.35, -width / 2 + 0.0006),
           (thick, width / 2 - 0.0008), (-sink, width / 2)]
    rings = []
    for i in range(n):
        f = i / (n - 1)
        th = phase + TAU * turns * f
        zc = lerp(z0 + width / 2, z1 - width / 2, f)
        ring = []
        for dr, da in sec:
            c, u, v, rx, ry = frame_at(zc + da)
            ring.append(c + u * math.cos(th) * (rx + dr) + v * math.sin(th) * (ry + dr))
        rings.append(ring)
    return loft(bm, rings, cap0='ngon', cap1='ngon')


def band(bm, frame_at, z0, z1, n=12, out=0.0015, sink=0.0008, ch=0.0006):
    """Closed ring band around a shaft (ferrule / collar / binding end)."""
    prof = [(-sink, z0), (out - ch, z0), (out, z0 + ch), (out, z1 - ch), (out - ch, z1), (-sink, z1)]
    rings = []
    for dr, z in prof:
        c, u, v, rx, ry = frame_at(z)
        rings.append([c + u * math.cos(TAU * i / n) * (rx + dr) + v * math.sin(TAU * i / n) * (ry + dr)
                      for i in range(n)])
    # close as a torus-like tube (inner wall back to start)
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    m = len(vs)
    for a in range(m):
        b = (a + 1) % m
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((vs[a][i], vs[a][j], vs[b][j], vs[b][i]))


def dome_rivet(bm, o, nrm, r, h, n=8, ref=None):
    """Low-poly domed rivet head; base slightly sunk below the surface."""
    prof = [(r * 0.98, -0.0006), (r, 0.0), (r * 0.82, h * 0.6), (r * 0.42, h * 0.95), (0, h)]
    rows = lathe(bm, prof, o, nrm, n, ref=ref)
    bm.faces.new(list(reversed(rows[0])))


# ------------------------------------------------------------ object build
def bm_to_obj(name, bm, coll, mat, parent=None):
    me = bpy.data.meshes.new(name)
    zero = [f for f in bm.faces if f.calc_area() < 1e-11]
    if zero:
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=list({e for f in zero for e in f.edges}))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ng = [f for f in bm.faces if len(f.verts) > 4]
    if ng:
        bmesh.ops.triangulate(bm, faces=ng, quad_method='BEAUTY', ngon_method='BEAUTY')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    me.materials.append(mat)
    if parent is not None:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
    return ob


def finish(ob, sharp=38, weighted=True, bevel=None, sharp_rings=()):
    """Optional bevel, smooth-by-angle, weighted normals; everything applied.
    sharp_rings: iterables of vertex indices whose connecting edges are forced sharp."""
    me = ob.data
    if bevel:
        m = ob.modifiers.new("Bevel", 'BEVEL')
        m.width = bevel[0]
        m.segments = bevel[1]
        m.limit_method = 'ANGLE'
        m.angle_limit = math.radians(bevel[2] if len(bevel) > 2 else 40)
        m.use_clamp_overlap = True
        m.miter_outer = 'MITER_ARC'
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(sharp))
    if sharp_rings:
        sets = [set(r) for r in sharp_rings]
        att = me.attributes.get("sharp_edge") or me.attributes.new("sharp_edge", 'BOOLEAN', 'EDGE')
        for e in me.edges:
            a, b = e.vertices
            if any(a in st and b in st for st in sets):
                att.data[e.index].value = True
    if weighted:
        w = ob.modifiers.new("WN", 'WEIGHTED_NORMAL')
        w.keep_sharp = True
        w.weight = 50
    for mod in list(ob.modifiers):
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # sharp edges after bevel
    if bevel:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    return ob


def make_root(name, coll, loc):
    e = bpy.data.objects.get(name)
    if e is None:
        e = bpy.data.objects.new(name, None)
    if e.name not in coll.objects:
        coll.objects.link(e)
    e.empty_display_type = 'ARROWS'
    e.empty_display_size = 0.08
    e.location = loc
    e.rotation_euler = (0, 0, 0)
    e.scale = (1, 1, 1)
    return e


def tri_count(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def report(coll):
    tot = 0
    lines = []
    for o in sorted(coll.objects, key=lambda o: o.name):
        if o.type != 'MESH':
            continue
        t = tri_count(o)
        tot += t
        lines.append(f"  {o.name:24s} {t:5d} tris  {o.data.materials[0].name}")
    lines.append(f"  TOTAL {coll.name}: {tot} tris")
    return "\n".join(lines), tot


def check_mesh(ob):
    """Return dict of health stats for a mesh object."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    nm = sum(1 for e in bm.edges if not e.is_manifold)
    loose_v = sum(1 for v in bm.verts if not v.link_edges)
    zero = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
    keys = {}
    dup = 0
    for f in bm.faces:
        k = tuple(sorted(v.index for v in f.verts))
        if k in keys:
            dup += 1
        keys[k] = 1
    # shells
    seen = set(); shells = 0
    for v in bm.verts:
        if v.index in seen:
            continue
        shells += 1
        stack = [v]
        while stack:
            x = stack.pop()
            if x.index in seen:
                continue
            seen.add(x.index)
            for e in x.link_edges:
                stack.append(e.other_vert(x))
    bm.free()
    return dict(non_manifold=nm, loose=loose_v, zero_area=zero, dup_faces=dup, shells=shells)


# ------------------------------------------------------ urban prop helpers
def frame_xz(bm, outer, inner, y_back, y_front, ch=0.002):
    """Picture-frame solid in the XZ plane: outer/inner = CCW (x, z) outlines with the
    same point count (inner = the hole).  Extruded from y_back to y_front (front side
    chamfered by ch).  Closed torus-like loft, no caps."""
    d = 1 if y_front > y_back else -1
    P = lambda pts, y: [V(x, y, z) for x, z in pts]
    rings = [P(outer, y_back), P(outer, y_front - d * ch), P(offset_poly(outer, -ch), y_front),
             P(offset_poly(inner, ch), y_front), P(inner, y_front - d * ch), P(inner, y_back)]
    return loft(bm, rings, wrap=True)


def plate_xz(bm, outline, y_back, y_front, ch=0.0006):
    """Flat decal / plate: CCW (x, z) outline extruded between y_back and y_front."""
    c = (y_back + y_front) / 2
    w = V(0, 1 if y_back > y_front else -1, 0)          # towards the back
    return prism(bm, ccw(outline), V(0, c, 0), V(1, 0, 0), V(0, 0, 1), w, abs(y_back - y_front) / 2, ch)


def shift2(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


def text_bm(bm, text, size, o, u, v, extrude=0.003, font_res=2, align='CENTER'):
    """Append a text string as mesh: glyphs lie in the (u, v) plane at o, extruded
    +-extrude along u x v.  Uses Blender's built-in font (original wordmarks only)."""
    cu = bpy.data.curves.new("_tmp_txt", 'FONT')
    cu.body = text
    cu.size = size
    cu.extrude = extrude
    cu.resolution_u = font_res
    cu.align_x = align
    cu.align_y = 'CENTER'
    cu.fill_mode = 'BOTH'
    ob = bpy.data.objects.new("_tmp_txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    w = u.cross(v)
    M = Matrix(((u.x, v.x, w.x, o.x), (u.y, v.y, w.y, o.y), (u.z, v.z, w.z, o.z), (0, 0, 0, 1)))
    me.transform(M)
    tmp = bmesh.new(); tmp.from_mesh(me)
    bmesh.ops.remove_doubles(tmp, verts=tmp.verts, dist=1e-6)
    tmp.to_mesh(me); tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def chaikin(pts, it=2, keep_ends=True):
    """Corner-cutting smoothing of an open polyline of Vectors."""
    for _ in range(it):
        out = [pts[0]] if keep_ends else []
        for a, b in zip(pts, pts[1:]):
            out += [a.lerp(b, 0.25), a.lerp(b, 0.75)]
        if keep_ends:
            out.append(pts[-1])
        pts = out
    return pts


def pillow_xz(bm, outline, y0, y1, r, seg=4, fil=None):
    """Side-profile solid like prism_xz, but the edges are rounded with a large radius r
    (moulded stock / grip look instead of a flat slab).  outline in (X, Z)."""
    pts = ccw(fillet(outline, fil, 3) if fil else outline)
    yc, yh = (y0 + y1) / 2, abs(y1 - y0) / 2
    r = min(r, yh * 0.95)
    rings = []
    for side in (-1, 1):
        ks = range(seg + 1) if side < 0 else range(seg, -1, -1)
        for k in ks:
            a = math.pi / 2 * k / seg
            inset = r * (1 - math.sin(a))
            y = yc + side * (yh - r * (1 - math.cos(a)))
            rings.append([V(x, y, z) for x, z in offset_poly(pts, -inset)])
    return loft(bm, rings, cap0='ngon', cap1='ngon')
