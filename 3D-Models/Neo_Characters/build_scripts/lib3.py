# lib3.py — v5 sculpted volumetric hair toolkit (exec'd after lib.py and lib2.py)
# Architecture: a designed hair ENVELOPE (thickness field + hairline over the head sphere) gives the big
# silhouette; a continuous sculpted base mass fills it (no bald spots); primary / secondary locks are
# authored as control points *relative to the envelope surface* and drape over it.
import random

def azel(d):
    d = d.normalized()
    return math.degrees(math.atan2(d.x, -d.y)), math.degrees(math.asin(max(-1.0, min(1.0, d.z))))

class Envelope:
    """thick(az, el) -> hair thickness above the scalp; lim(az) -> lowest covered elevation (hairline);
    edge(az) -> width (deg) over which the mass ramps up from the hairline."""
    def __init__(self, R, thick, lim, edge=10.0):
        self.R, self.thick, self.lim = R, thick, lim
        self.edge = edge if callable(edge) else (lambda az, e=edge: e)
    def h(self, d):
        az, el = azel(d)
        dist = el - self.lim(az)
        if dist <= 0:
            return 0.0
        return self.thick(az, el) * smoothstep(0.0, self.edge(az), dist)

def hpath(env, cps, per=7, floor=0.02):
    """Control points -> smooth spine.
    All (az, el, h) tuples -> heights are measured above the envelope surface (locks drape over the mass).
    Any Vector (free point in head space) -> absolute mode: directions and radii are splined directly, so the
    lock goes exactly where it was authored (tuples are converted to absolute points first)."""
    R = env.R
    if all(not isinstance(c, Vector) for c in cps):
        dirs = [D(c[0], c[1]) for c in cps]
        dd = catmull(dirs, per)
        hh = catmull([Vector((c[2], 0, 0)) for c in cps], per)
        return [d.normalized() * (R + env.h(d) + h.x) for d, h in zip(dd, hh)]
    pts = []
    for c in cps:
        if isinstance(c, Vector):
            pts.append(c)
        else:
            d = D(c[0], c[1]); pts.append(d * (R + env.h(d) + c[2]))
    dd = catmull([p.normalized() for p in pts], per)
    rr = catmull([Vector((p.length, 0, 0)) for p in pts], per)
    return [d.normalized() * max(r.x, R + floor) for d, r in zip(dd, rr)]

def sweep(spine, wfn, tfn, center=Vector((0, 0, 0)), M=12, curl=0.3, flat=0.3, ridge=0.25, skew=0.0, roll=0.0,
          sharp=1.5, crease=None, face=None, face_k=0.6):
    """Chunky lock section swept along a spine: domed top with a soft crest, flatter underside, edges
    curling toward the head. Frames follow the head normal near the scalp and are transported smoothly
    where the lock leaves it (flicked tips), so sections never flip."""
    n = len(spine)
    verts, faces = [], []
    prev = None
    for i in range(n - 1):
        s = i / (n - 1)
        P = spine[i]
        T = (spine[min(i + 1, n - 1)] - spine[max(i - 1, 0)]).normalized()
        rad = P - center
        rad = rad.normalized() if rad.length > 1e-6 else Vector((0, 0, 1))
        if face is not None:                      # shingle the lock: turn its broad face toward a viewing side
            rad = (rad * (1 - face_k) + face * face_k).normalized()
        Nr = rad - T * rad.dot(T)
        q = Nr.length
        if prev is None:
            N = Nr.normalized() if q > 1e-4 else T.orthogonal().normalized()
        else:
            Np = prev - T * prev.dot(T)
            Np = Np.normalized() if Np.length > 1e-6 else T.orthogonal().normalized()
            if q > 1e-4:
                N = Np.lerp(Nr.normalized(), smoothstep(0.2, 0.55, q))
                N = N - T * N.dot(T)
                N = N.normalized() if N.length > 1e-6 else Np
            else:
                N = Np
        prev = N.copy()
        B = N.cross(T).normalized()
        r_ = roll(s) if callable(roll) else roll * s
        if r_:
            N, B = N * math.cos(r_) + B * math.sin(r_), B * math.cos(r_) - N * math.sin(r_)
        w = wfn(s) * 0.5
        t = tfn(s)
        for k in range(M):
            a = 2 * math.pi * k / M
            c, sn = math.cos(a), math.sin(a)
            x = c * w
            if sn >= 0:
                y = t * (1 - flat) * sn ** sharp + ridge * t * 0.35 * (1 - c * c) ** 3
                x += skew * w * sn
            else:
                y = -t * flat * (-sn) ** sharp
            y -= curl * t * c * c
            if crease and k in crease:
                y -= crease[k] * t * math.sin(math.pi * min(1.0, 0.1 + s)) ** 0.5
            verts.append(P + B * x + N * y)
    rings = n - 1
    for i in range(rings - 1):
        for k in range(M):
            a = i * M + k; b = i * M + (k + 1) % M
            faces.append((a, a + M, b + M, b))
    tip = len(verts); verts.append(spine[-1].copy())
    last = (rings - 1) * M
    for k in range(M):
        faces.append((last + (k + 1) % M, last + k, tip))
    rc = len(verts)
    verts.append(sum((verts[k] for k in range(M)), Vector()) / M)
    for k in range(M):
        faces.append((k, (k + 1) % M, rc))
    return verts, faces

def _fix_normals(me):
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()

def slock(name, env, cps, width, thick, material, per=7, M=14, curl=0.3, flat=0.3, ridge=0.25, skew=0.0, roll=0.0,
          root=0.5, belly_at=0.3, tip_start=0.4, tip_pow=1.0, blunt=0.0, prof=None, tprof=None, subsurf=2,
          spine=None, sharp=1.5, crease=None, face=None, face_k=0.6, body_end=None, tail=0.25, flatness=0.30):
    """Sculpted hair lock. cps as in hpath (or pass a ready spine). width/thick in scene units."""
    sp = spine if spine is not None else hpath(env, cps, per)
    pf = prof or (leaf_profile(belly_at, tip_start, body_end, tail, root) if body_end else clump_profile(belly_at, tip_start, tip_pow, root, blunt))
    wf = lambda s: width * pf(s) + 0.004
    tf0 = tprof or (lambda s: thick * (0.62 + 0.38 * smoothstep(0, 0.22, s)) * (1 - smoothstep(0.3, 1.0, s)) ** 0.75)
    tf = lambda s: min(tf0(s), flatness * wf(s)) + 0.005     # stays a flat leaf all the way to the tip, never a tube
    v, f = sweep(sp, wf, tf, M=M, curl=curl, flat=flat, ridge=ridge, skew=skew, roll=roll, sharp=sharp, crease=crease, face=face, face_k=face_k)
    ob = mesh_obj(name, v, f, material)
    _fix_normals(ob.data)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = subsurf
    return ob

def leaves(env, cps, offs, per=7):
    """Split one flow line into several leaves sharing a root. offs: (side, lift, length) per leaf:
    drifts sideways by `side` toward the tip (+ = viewer-right for a lock falling down the face),
    sits `lift` higher, and stops at `length` (0..1) of the main path. Returns a list of spines."""
    sp = hpath(env, cps, per)
    n = len(sp)
    out = []
    for side, lift, length in offs:
        m = max(5, int(round(length * (n - 1))) + 1)
        pts = []
        for i in range(m):
            s = i / (m - 1)
            P = sp[i]
            T = (sp[min(i + 1, n - 1)] - sp[max(i - 1, 0)]).normalized()
            rad = P.normalized()
            S = rad.cross(T)
            S = S.normalized() if S.length > 1e-6 else Vector((1, 0, 0))
            pts.append(P + S * (side * s ** 1.6) + rad * (lift * math.sin(math.pi * min(1.0, 0.15 + s)) ))
        out.append(pts)
    return out

def hair_base(name, env, material, whorl=(0.0, 90.0), n_clumps=20, groove=0.3, tip_amp=10.0, naz=192, nel=72,
              el_lo=-72.0, tuck=-0.03, seed=0.0, subsurf=1, warp=0.5, hmin=0.03):
    """Continuous sculpted hair mass filling the envelope. Grooves run along the flow lines leaving the
    whorl; the lower edge is broken into pointed tips (clump centres hang lower). n_clumps must be even."""
    R = env.R
    zax = D(*whorl)
    xax = Vector((0, 0, 1)).cross(zax)
    xax = xax.normalized() if xax.length > 1e-4 else Vector((1, 0, 0))
    yax = zax.cross(xax)
    tip_fn = tip_amp if callable(tip_amp) else (lambda az, t=tip_amp: t)
    gr_fn = groove if callable(groove) else (lambda az, el, g=groove: g)
    verts, faces = [], []
    for i in range(nel):
        elp = el_lo + (89.0 - el_lo) * i / (nel - 1)
        fade = 1.0 - smoothstep(55.0, 88.0, elp)
        for j in range(naz):
            azp = 360.0 * j / naz - 180.0
            a = math.radians(azp)
            dl = D(azp, elp)
            d = (xax * dl.x + yax * dl.y + zax * dl.z).normalized()
            az, el = azel(d)
            ph = warp * math.sin(3 * a + seed) + 0.6 * warp * math.sin(math.radians(elp) * 3.0 + 2 * a + seed * 1.7)
            c = abs(math.cos(0.5 * n_clumps * a + ph)) ** 0.6       # 1 = clump centre, 0 = groove
            L = env.lim(az) + tip_fn(az) * (1 - c * c)
            dist = el - L
            if dist <= 0:
                h = tuck
            else:
                cov = smoothstep(0.0, env.edge(az), dist)
                h = env.thick(az, el) * cov * (1 - gr_fn(az, el) * (1 - c) * fade)
                h = max(h, hmin)
            verts.append(d * (R + h))
    tk = R + tuck + 1e-6
    for i in range(nel - 1):
        for j in range(naz):
            j2 = (j + 1) % naz
            q = (i * naz + j, i * naz + j2, (i + 1) * naz + j2, (i + 1) * naz + j)
            if all(verts[k].length <= tk for k in q):
                continue                      # nothing below the hairline: no hidden shell inside the head
            faces.append(q)
    top = len(verts)
    verts.append(zax * (R + max(env.h(zax), 0.006)))
    for j in range(naz):
        faces.append(((nel - 1) * naz + j, (nel - 1) * naz + (j + 1) % naz, top))
    return mesh_obj(name, verts, faces, material, subsurf=subsurf)

def flower(prefix, center, normal, coll, root, m_petal, m_center, n=5, plen=0.2, pw=0.17, cup=0.3, droop=0.1,
           spin=0.0, center_r=0.05, thick=0.03, up=Vector((0, 0, 1))):
    """Soft puffy flower: n cupped petals (solidified surfaces) around a small centre bead."""
    nz = Vector(normal).normalized()
    x = Vector(up).cross(nz)
    x = x.normalized() if x.length > 1e-4 else Vector((1, 0, 0))
    y = nz.cross(x)
    NT, NU = 10, 7
    obs = []
    for k in range(n):
        a = spin + 2 * math.pi * k / n
        rdir = x * math.cos(a) + y * math.sin(a)
        tdir = nz.cross(rdir)
        verts, faces = [], []
        for i in range(NT):
            t = i / (NT - 1)
            tt = t ** 0.8
            w = pw * math.sqrt(max(1 - (2 * tt - 1) ** 2, 0.0)) * (0.30 + 0.70 * smoothstep(0, 0.45, t)) + 0.012   # round puffy petal, narrow at the base
            lift = cup * plen * t ** 1.5 - droop * plen * smoothstep(0.55, 1.0, t)
            for j in range(NU):
                u = -1 + 2 * j / (NU - 1)
                verts.append(Vector(center) + rdir * (t * plen) + tdir * (u * w * 0.5)
                             + nz * (lift + 0.22 * w * (u * u) - 0.05 * w * math.exp(-(u / 0.3) ** 2)))
        for i in range(NT - 1):
            for j in range(NU - 1):
                a_ = i * NU + j
                faces.append((a_, a_ + 1, a_ + NU + 1, a_ + NU))
        ob = mesh_obj(f"{prefix}_Petal_{k + 1}", verts, faces, m_petal)
        so = ob.modifiers.new("Solidify", 'SOLIDIFY'); so.thickness = thick; so.offset = 0.0
        md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
        link(ob, coll, root); obs.append(ob)
    ctr = uv_sphere(f"{prefix}_Center", center_r, m_center, 20, 10)
    ctr.location = Vector(center) + nz * (center_r * 0.5)
    ctr.scale = (1, 1, 1)
    ctr.rotation_euler = look_rot(nz); ctr.scale = (1.0, 1.0, 0.7)
    link(ctr, coll, root); obs.append(ctr)
    return obs


def cone_ear(name, base_c, axis, front, h, b, d, material, coll, root, inner_mat=None):
    """Cat ear: wide soft cone with a flatter, slightly scooped front face (+ optional inner facet)."""
    axis = Vector(axis).normalized()
    side = axis.cross(Vector(front)).normalized()
    fr = side.cross(axis).normalized()          # true front, perpendicular to the axis
    NR, NA = 10, 14
    verts, faces = [], []
    for i in range(NR):
        t = i / NR
        k = (1 - t) ** 0.85 * (1 - 0.10 * math.sin(math.pi * t))
        for j in range(NA):
            a = 2 * math.pi * j / NA
            x = math.cos(a) * b * 0.5 * k
            y = math.sin(a) * d * 0.5 * k
            if y > 0:
                y *= 0.30 * (1 - 0.6 * math.sin(math.pi * min(1.0, t * 1.2)) * abs(math.sin(a)))   # scooped front
            verts.append(Vector(base_c) + axis * (h * t) + side * x + fr * y)
    for i in range(NR - 1):
        for j in range(NA):
            a_ = i * NA + j; b_ = i * NA + (j + 1) % NA
            faces.append((a_, b_, b_ + NA, a_ + NA))
    tip = len(verts); verts.append(Vector(base_c) + axis * h)
    last = (NR - 1) * NA
    for j in range(NA):
        faces.append((last + j, last + (j + 1) % NA, tip))
    bc = len(verts); verts.append(Vector(base_c))
    for j in range(NA):
        faces.append(((j + 1) % NA, j, bc))
    ob = mesh_obj(name, verts, faces, material)
    _fix_normals(ob.data)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 2
    link(ob, coll, root)
    if inner_mat:
        vs = [Vector(base_c) + axis * (h * 0.10) + side * (b * 0.30) + fr * (d * 0.10),
              Vector(base_c) + axis * (h * 0.10) - side * (b * 0.30) + fr * (d * 0.10),
              Vector(base_c) + axis * (h * 0.74) + fr * (d * 0.045)]
        o2 = mesh_obj(name + "_Inner", vs, [(0, 1, 2)], inner_mat)
        so = o2.modifiers.new("Solidify", 'SOLIDIFY'); so.thickness = 0.012; so.offset = 1.0
        _fix_normals(o2.data)
        link(o2, coll, root)
    return ob


def leaf_profile(belly_at=0.25, tip_start=0.45, body_end=0.75, tail=0.25, root=0.5):
    """Anime leaf lock: broad body that keeps its width, then a thin curved tail ending in a point."""
    def f(s):
        if s >= 0.999:
            return 0.0
        g = root + (1 - root) * smoothstep(0, belly_at, s)
        if s < body_end:
            return g * (1 - smoothstep(tip_start, body_end, s) * (1 - tail))
        return g * tail * ((1 - s) / (1 - body_end)) ** 0.9
    return f


def ellipsoid_thick(R, c, a, tmin=0.12):
    """Envelope thickness from an off-centre ellipsoid (the 'wig' silhouette): distance from the head
    centre to the ellipsoid along each direction, minus the head radius."""
    c = Vector(c); a = Vector(a)
    def f(az, el):
        d = D(az, el)
        A = sum((d[i] / a[i]) ** 2 for i in range(3))
        B = -2 * sum(d[i] * c[i] / a[i] ** 2 for i in range(3))
        Cc = sum((c[i] / a[i]) ** 2 for i in range(3)) - 1
        disc = B * B - 4 * A * Cc
        r = (-B + math.sqrt(disc)) / (2 * A) if disc > 0 else R
        return max(r - R, tmin)
    return f


# ---------------- v5 staging: the presentation camera sits to the viewer-right and looks slightly across the
# row (Akemi nearest, Nix farthest, as in the target). Each character is turned to face that camera;
# FACE_YAW is the small extra head turn each one has in the target.
CAM_POS = Vector((4.285, -10.55, 0.38)); CAM_FWD = Vector((-0.384, 0.923, 0.0)); CAM_LENS = 41.0
STAGE_AZ = {"Nix": 34.3, "Yoru": 22.1, "Akemi": 7.5}
FACE_YAW = {"Nix": 5.0, "Yoru": 0.0, "Akemi": -5.0}
def face_camera(ch):
    bpy.data.objects[ch + "_Root"].rotation_euler = (0, 0, math.radians(STAGE_AZ[ch] + FACE_YAW[ch]))
