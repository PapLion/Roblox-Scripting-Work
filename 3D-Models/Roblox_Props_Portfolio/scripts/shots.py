"""Presentation layer in scene 'Showcase'.

Every shot is one timeline frame; timeline markers bind the camera, and the instance
poses / visibility are keyframed (constant), so scrubbing the timeline in the .blend
reproduces each portfolio image exactly.  Asset geometry is never modified here: the
showcase only uses collection instances of the 'Assets' scene.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Euler, Quaternion
import lib
from lib import V

sc = bpy.data.scenes["Showcase"]
D = math.radians

# ------------------------------------------------------------- helpers ----
def coll_in(scene_coll, name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in scene_coll.children:
        scene_coll.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c


C_DISP = coll_in(sc.collection, "Display")
C_WIRE = coll_in(sc.collection, "WireOverlay")
C_CAM = coll_in(sc.collection, "Cameras")
for o in list(sc.collection.objects):          # old test objects
    if o.name.startswith("TEST_"):
        bpy.data.objects.remove(o, do_unlink=True)
for n in ("TEST_Axe",):
    o = bpy.data.objects.get(n)
    if o:
        bpy.data.objects.remove(o, do_unlink=True)


def local_verts(cname):
    """Vertices of a collection (recursive) in collection-instance space."""
    c = bpy.data.collections[cname]
    off = Vector(c.instance_offset)
    pts = []
    for o in c.all_objects:
        if o.type == 'MESH':
            mw = o.matrix_world
            pts += [mw @ v.co - off for v in o.data.vertices]
    return pts


def tris(cname):
    t = 0
    for o in bpy.data.collections[cname].all_objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            t += len(o.data.loop_triangles)
    return t


def bbox_center(pts):
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return (mn + mx) / 2, mx - mn


def instance(name, cname, coll=C_DISP):
    e = bpy.data.objects.new(name, None)
    coll.objects.link(e)
    e.instance_type = 'COLLECTION'
    e.instance_collection = bpy.data.collections[cname]
    e.empty_display_size = 0.05
    e.rotation_mode = 'QUATERNION'
    return e


def pose_matrix(rot, center_local, stage):
    """Matrix placing an instance so that its bbox centre lands on 'stage'."""
    R = rot.to_matrix().to_4x4()
    t = Vector(stage) - (R @ center_local)
    return Matrix.Translation(t) @ R


def look_rot(direction):
    """Camera rotation looking along -direction (direction = target->camera)."""
    return (-Vector(direction)).to_track_quat('-Z', 'Y')


def make_cam(name, ortho=False, lens=70):
    cd = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    cd.type = 'ORTHO' if ortho else 'PERSP'
    cd.lens = lens
    cd.sensor_fit = 'AUTO'
    cd.sensor_width = 36
    cd.clip_start = 0.01
    cd.clip_end = 60
    ob = bpy.data.objects.new(name, cd)
    C_CAM.objects.link(ob)
    ob.rotation_mode = 'QUATERNION'
    return ob


def fit(cam, pts, direction, aspect=1.0, margin=0.08, centre=None, shift=(0.0, 0.0)):
    """Place 'cam' looking along -direction so all points fit with margin.
    aspect = width/height of the render."""
    q = look_rot(direction)
    cam.rotation_quaternion = q
    r = q @ V(1, 0, 0); u = q @ V(0, 1, 0); f = q @ V(0, 0, -1)
    C = centre if centre is not None else bbox_center(pts)[0]
    cd = cam.data
    if cd.type == 'ORTHO':
        for _ in range(2):
            xs = [(p - C).dot(r) for p in pts]; ys = [(p - C).dot(u) for p in pts]
            C = C + r * (max(xs) + min(xs)) / 2 + u * (max(ys) + min(ys)) / 2
        xs = [(p - C).dot(r) for p in pts]; ys = [(p - C).dot(u) for p in pts]
        w = (max(xs) - min(xs)); h = (max(ys) - min(ys))
        scale = max(w, h * aspect) * (1 + 2 * margin) if aspect >= 1 else max(w / aspect, h) * (1 + 2 * margin)
        cd.ortho_scale = scale
        C = C - r * shift[0] * scale - u * shift[1] * scale
        cam.location = C - f * 28.0
        return
    # perspective
    half_long = math.atan(cd.sensor_width / (2 * cd.lens))
    tx = math.tan(half_long) if aspect >= 1 else math.tan(half_long) * aspect
    ty = tx / aspect
    tx /= (1 + 2 * margin); ty /= (1 + 2 * margin)
    for _ in range(4):
        d = max(max(abs((p - C).dot(r)) / tx, abs((p - C).dot(u)) / ty) - (p - C).dot(f) for p in pts)
        L = C - f * d
        ax = [(p - L).dot(r) / (p - L).dot(f) for p in pts]
        ay = [(p - L).dot(u) / (p - L).dot(f) for p in pts]
        C = C + r * (max(ax) + min(ax)) / 2 * d + u * (max(ay) + min(ay)) / 2 * d
    d = max(max(abs((p - C).dot(r)) / tx, abs((p - C).dot(u)) / ty) - (p - C).dot(f) for p in pts)
    cam.location = C - f * d


# --------------------------------------------------------- materials ------
def flat_mat(name, hx, rough=0.6, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs['Base Color'].default_value = lib.hexcol(hx)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = 0.0
    if emit:
        b.inputs['Emission Color'].default_value = lib.hexcol(hx)
        b.inputs['Emission Strength'].default_value = emit
    return m


CLAY = flat_mat("PRES_Clay", "#C4C8CD", 0.55)
WIRE = flat_mat("PRES_Wire", "#1B1F24", 0.9)
LABEL = flat_mat("PRES_Label", "#1E2125", 1.0, emit=0.0)

# ------------------------------------------------- wireframe node group ----
ng = bpy.data.node_groups.get("PRES_WireOverlay")
if ng:
    bpy.data.node_groups.remove(ng)
ng = bpy.data.node_groups.new("PRES_WireOverlay", 'GeometryNodeTree')
ng.interface.new_socket("Geometry", in_out='INPUT', socket_type='NodeSocketGeometry')
s_col = ng.interface.new_socket("Asset", in_out='INPUT', socket_type='NodeSocketCollection')
s_rad = ng.interface.new_socket("Radius", in_out='INPUT', socket_type='NodeSocketFloat')
s_rad.default_value = 0.0005
ng.interface.new_socket("Geometry", in_out='OUTPUT', socket_type='NodeSocketGeometry')
N = ng.nodes
gi = N.new('NodeGroupInput'); go = N.new('NodeGroupOutput')
ci = N.new('GeometryNodeCollectionInfo'); ci.transform_space = 'ORIGINAL'
ri = N.new('GeometryNodeRealizeInstances')
m2c = N.new('GeometryNodeMeshToCurve')
circ = N.new('GeometryNodeCurvePrimitiveCircle'); circ.inputs['Resolution'].default_value = 4
c2m = N.new('GeometryNodeCurveToMesh')
sm1 = N.new('GeometryNodeSetMaterial'); sm1.inputs['Material'].default_value = CLAY
sm2 = N.new('GeometryNodeSetMaterial'); sm2.inputs['Material'].default_value = WIRE
jn = N.new('GeometryNodeJoinGeometry')
L = ng.links
L.new(gi.outputs['Asset'], ci.inputs['Collection'])
L.new(ci.outputs['Instances'], ri.inputs['Geometry'])
L.new(ri.outputs['Geometry'], sm1.inputs['Geometry'])
L.new(ri.outputs['Geometry'], m2c.inputs['Mesh'])
L.new(gi.outputs['Radius'], circ.inputs['Radius'])
L.new(m2c.outputs['Curve'], c2m.inputs['Curve'])
L.new(circ.outputs['Curve'], c2m.inputs['Profile Curve'])
L.new(c2m.outputs['Mesh'], sm2.inputs['Geometry'])
L.new(sm1.outputs['Geometry'], jn.inputs['Geometry'])
L.new(sm2.outputs['Geometry'], jn.inputs['Geometry'])
L.new(jn.outputs['Geometry'], go.inputs['Geometry'])


def _set_input(md, ident, value):
    try:                                   # Blender 5.2 modifier interface
        getattr(md.properties.inputs, ident).value = value
    except AttributeError:
        md[ident] = value                  # older API


def wire_obj(name, cname, radius, parent):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    C_WIRE.objects.link(ob)
    md = ob.modifiers.new("Wire", 'NODES')
    md.node_group = ng
    _set_input(md, s_col.identifier, bpy.data.collections[cname])
    _set_input(md, s_rad.identifier, radius)
    ob.parent = parent
    ob.matrix_parent_inverse = Matrix.Identity(4)
    return ob


def label(name, text, cam, size_frac=0.030, pos=(-0.46, -0.45), aspect=1.0):
    cu = bpy.data.curves.get(name) or bpy.data.curves.new(name, 'FONT')
    cu.body = text
    cu.align_x = 'LEFT'
    cu.align_y = 'BOTTOM'
    ob = bpy.data.objects.new(name, cu)
    C_WIRE.objects.link(ob)
    cu.materials.clear(); cu.materials.append(LABEL)
    ob.parent = cam
    ob.matrix_parent_inverse = Matrix.Identity(4)
    ob.visible_shadow = False
    cd = cam.data
    dist = 1.0
    if cd.type == 'ORTHO':
        width = cd.ortho_scale
    else:
        width = 2 * dist * math.tan(math.atan(cd.sensor_width / (2 * cd.lens)))
    height = width / aspect
    cu.size = width * size_frac
    ob.location = (pos[0] * width, pos[1] * height, -dist)
    return ob


# ---------------------------------------------------------------- shots ---
STAGE = V(0, 0, 0.62)
HERO_DIR = V(0.18, -1.0, 0.30)
ASSETS = [
    # name, collection, pretty, base frame, in-plane tilt (deg), 3/4 spin (deg), detail (local point, radius)
    ("Axe", "Axe", "Lumberjack Axe", 10, -34, -32, (V(0.065, 0, 0.565), 0.150)),
    ("Sword", "Sword", "Adventurer Sword", 20, -42, -30, (V(0.0, 0, 0.065), 0.115)),
    ("Hammer", "Hammer", "Blacksmith Hammer", 30, -30, -34, (V(0.0, 0, 0.235), 0.105)),
    ("Pickaxe", "Pickaxe", "Mining Pickaxe", 40, -22, -30, (V(0.0, 0, 0.575), 0.125)),
    ("Shield", "Shield", "Round Shield", 50, 0, -28, (None, 0.0)),
    ("Dagger", "Dagger_Knife", "Dagger", 60, -38, -32, (V(0.0, 0, 0.02), 0.085)),
]
vis = {}           # object -> set of frames where it is visible
frames_all = [1, 2]
markers = []       # (frame, camera, name)
rig_key = {}       # frame -> rig location
poses = {}         # object -> {frame: matrix}


def show(ob, frame):
    vis.setdefault(ob, set()).add(frame)


def key_pose(ob, frame, M):
    poses.setdefault(ob, {})[frame] = M


for name, cname, pretty, b, tilt, spin, (dpt, drad) in ASSETS:
    pts = local_verts(cname)
    c_local, size = bbox_center(pts)
    inst = instance(f"SHOT_{name}", cname)
    fr = dict(hero=b, front=b + 1, side=b + 2, detail=b + 3, back=b + 4, wire=b + 5)
    if name == "Shield":
        rots = dict(hero=Euler((D(4), 0, D(spin)), 'XYZ').to_quaternion(),
                    front=Quaternion(), side=Euler((0, 0, D(90)), 'XYZ').to_quaternion(),
                    back=Euler((D(-6), 0, D(180 + 32)), 'XYZ').to_quaternion())
        rots['detail'] = rots['hero']
    else:
        base = Euler((0, D(tilt), 0), 'XYZ').to_quaternion()
        rots = dict(hero=base @ Euler((D(-8), 0, D(spin)), 'XYZ').to_quaternion(),
                    front=base,
                    side=base @ Euler((0, 0, D(90)), 'XYZ').to_quaternion())
        rots['detail'] = rots['hero']
    rots['wire'] = rots['hero']
    shot_list = ['hero', 'front', 'side', 'detail', 'wire'] + (['back'] if name == "Shield" else [])
    extra = None
    if name == "Dagger":
        extra = instance("SHOT_Dagger_Sheath", "Dagger_Sheath")
        s_off = Vector(bpy.data.collections["Dagger_Sheath"].instance_offset) - Vector(bpy.data.collections["Dagger_Knife"].instance_offset)
    for shot in shot_list:
        f = fr[shot]
        frames_all.append(f)
        rig_key[f] = STAGE
        rq = rots[shot]
        M = pose_matrix(rq, c_local, STAGE)
        if name == "Dagger" and shot in ('hero', 'wire'):
            # dagger + sheath side by side: shift both so the pair is centred
            R = rq.to_matrix()
            side_vec = R @ V(1, 0, 0)
            M = Matrix.Translation(-side_vec * 0.050) @ M
            key_pose(extra, f, Matrix.Translation(side_vec * 0.050) @ pose_matrix(rq, c_local, STAGE))
            if shot == 'hero':
                show(extra, f)
        key_pose(inst, f, M)
        if shot != 'wire':
            show(inst, f)
        # camera
        world_pts = [M @ p for p in pts]
        if name == "Dagger" and shot in ('hero', 'wire'):
            spts = local_verts("Dagger_Sheath")
            Ms = poses[extra][f]
            world_pts += [Ms @ p for p in spts]
        mg = 0.10 if name == "Shield" else 0.07
        if shot in ('front', 'side'):
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", ortho=True)
            fit(cam, world_pts, V(0, -1, 0), margin=mg)
        elif shot == 'back':
            cam = make_cam(f"Cam_{name}_Back", lens=70)
            fit(cam, world_pts, V(0.15, -1.0, 0.22), margin=mg)
        elif shot == 'detail':
            cam = make_cam(f"Cam_{name}_Detail", lens=90)
            if dpt is None:      # shield: boss + emblem arm + rim
                # front of the shield faces -Y in local space
                dpt = V(0.075, -0.05, 0.10)
                drad = 0.15
            P = M @ dpt
            ring = [P + V(x, y, z) * drad for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            fit(cam, ring, V(0.42, -1.0, 0.34), margin=0.0, centre=P)
        else:
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", lens=70)
            fit(cam, world_pts, HERO_DIR, margin=mg)
        markers.append((f, cam, f"{name}_{shot}"))
        if shot == 'wire':
            radius = max(size) * 0.00042
            w = wire_obj(f"WIRE_{name}", cname, radius, inst)
            show(w, f)
            t = tris(cname)
            txt = f"{pretty}  -  {t:,} triangles"
            if extra is not None:
                ws = wire_obj("WIRE_Dagger_Sheath", "Dagger_Sheath", radius, extra)
                show(ws, f)
                ts = tris("Dagger_Sheath")
                txt = f"{pretty} {t:,} + sheath {ts:,}  =  {t + ts:,} triangles"
            lb = label(f"LABEL_{name}", txt, cam, size_frac=0.026)
            show(lb, f)
    if extra is not None:
        pass

# ---------------------------------------------------------- group shot ----
GROUP = [  # name, collection, floor position (x, y), spin about Z (deg)
    ("Sword", "Sword", (-0.82, 0.00), 0),
    ("Axe", "Axe", (-0.50, 0.02), 0),
    ("Pickaxe", "Pickaxe", (-0.05, 0.02), 0),
    ("Shield", "Shield", (0.50, 0.16), 0),
    ("Hammer", "Hammer", (0.40, -0.36), -70),
    ("Dagger", "Dagger_Knife", (0.86, -0.12), 0),
    ("Sheath", "Dagger_Sheath", (0.96, -0.12), 0),
]
group_pts = []
for name, cname, (gx, gy), spin in GROUP:
    pts = local_verts(cname)
    c_local, size = bbox_center(pts)
    inst = instance(f"GROUP_{name}", cname)
    # lie flat: local -Y (front / broad side) -> world +Z, long axis -> +Y (up in the image)
    rq = Euler((0, 0, D(spin)), 'XYZ').to_quaternion() @ Euler((D(-90), 0, 0), 'XYZ').to_quaternion()
    R = rq.to_matrix().to_4x4()
    wp = [R @ (p - c_local) for p in pts]
    zmin = min(p.z for p in wp)
    M = Matrix.Translation(V(gx, gy, -zmin + 0.0005)) @ R @ Matrix.Translation(-c_local)
    for f in (1, 2):
        key_pose(inst, f, M)
    show(inst, 1)
    group_pts += [M @ p for p in pts]
    w = wire_obj(f"WIREG_{name}", cname, 0.00062, inst)
    show(w, 2)
rig_key[1] = rig_key[2] = V(0.05, -0.05, 0.0)
GROUP_ASPECT = 1.5
camg = make_cam("Cam_Group", lens=60)
fit(camg, group_pts, V(0.0, -0.62, 1.0), aspect=GROUP_ASPECT, margin=0.05)
camw = make_cam("Cam_Group_Wire", lens=60)
camw.location = camg.location; camw.rotation_quaternion = camg.rotation_quaternion
markers += [(1, camg, "Group_beauty"), (2, camw, "Group_wire")]
counts = [(p, tris(c)) for p, c in (("Axe", "Axe"), ("Sword", "Sword"), ("Hammer", "Hammer"),
                                     ("Pickaxe", "Pickaxe"), ("Shield", "Shield"), ("Dagger+sheath", "Dagger"))]
lb = label("LABEL_Group", "   ".join(f"{p} {t:,}" for p, t in counts) + "   (triangles)", camw,
           size_frac=0.016, pos=(-0.47, -0.46), aspect=GROUP_ASPECT)
show(lb, 2)

# ======================================================= SHOOTER LINE =====
SHOOTER = [
    # name, pretty, base frame, hero spin, detail (local point, radius, spin), is_gun
    ("Pistol", "Semi-auto Pistol", 110, -34, (V(0.090, -0.01, 0.075), 0.042, -40), True),
    ("Rifle", "Compact Assault Rifle", 120, -32, (V(0.055, 0, 0.072), 0.105, -34), True),
    ("Shotgun", "Pump Shotgun", 130, -30, (V(0.125, 0.02, 0.040), 0.105, 180 + 32), True),
    ("AmmoBox", "Ammo Box", 140, 180 - 34, (V(0.0, 0.062, 0.140), 0.085, 180 - 30), False),
]
FPV_CAM = V(0.0, -0.75, 0.80)
FPV = {"Pistol": (V(0.070, 0.235, -0.098), 32, 9.0), "Rifle": (V(0.100, 0.300, -0.140), 30, 3.0),
       "Shotgun": (V(0.150, 0.330, -0.175), 30, 15.0)}
for name, pretty, b, spin, (dpt, drad, dspin), is_gun in SHOOTER:
    pts = local_verts(name)
    c_local, size = bbox_center(pts)
    inst = instance(f"SHOT_{name}", name)
    fr = dict(hero=b, right=b + 1, left=b + 2, detail=b + 3, wire=b + 5, fpv=b + 6)
    tilt = Euler((D(-6), 0, 0), 'XYZ').to_quaternion()
    rots = dict(hero=Euler((0, 0, D(spin)), 'XYZ').to_quaternion() @ tilt,
                right=Quaternion() if is_gun else Euler((0, 0, D(180)), 'XYZ').to_quaternion(),
                left=Euler((0, 0, D(180)), 'XYZ').to_quaternion() if is_gun else Quaternion(),
                detail=Euler((0, 0, D(dspin)), 'XYZ').to_quaternion() @ tilt)
    rots['wire'] = rots['hero']
    shots_ = ['hero', 'right', 'left', 'detail', 'wire'] + (['fpv'] if is_gun else [])
    for shot in shots_:
        f = fr[shot]
        frames_all.append(f)
        rig_key[f] = STAGE
        if shot == 'fpv':
            off, lens, toe = FPV[name]
            # barrel away from the camera (+X -> +Y), slight cant and toe-in
            rq = Euler((0, 0, D(90 + toe)), 'XYZ').to_quaternion() @ Euler((D(-5), D(-1.5), 0), 'XYZ').to_quaternion()
            M = Matrix.Translation(FPV_CAM + off) @ rq.to_matrix().to_4x4()
        else:
            M = pose_matrix(rots[shot], c_local, STAGE)
        key_pose(inst, f, M)
        if shot != 'wire':
            show(inst, f)
        world_pts = [M @ p for p in pts]
        mg = 0.07
        if shot in ('right', 'left'):
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", ortho=True)
            fit(cam, world_pts, V(0, -1, 0), margin=mg)
        elif shot == 'detail':
            cam = make_cam(f"Cam_{name}_Detail", lens=90)
            P = M @ dpt
            ring = [P + V(x, y, z) * drad for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            fit(cam, ring, V(0.42, -1.0, 0.34), margin=0.0, centre=P)
        elif shot == 'fpv':
            cam = make_cam(f"Cam_{name}_FPV", lens=FPV[name][1])
            cam.location = FPV_CAM
            cam.rotation_quaternion = Euler((D(90 - 4), 0, 0), 'XYZ').to_quaternion()
        else:
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", lens=70)
            fit(cam, world_pts, HERO_DIR, margin=mg)
        markers.append((f, cam, f"{name}_{shot}"))
        if shot == 'wire':
            radius = max(size) * 0.00045
            w = wire_obj(f"WIRE_{name}", name, radius, inst)
            show(w, f)
            t = tris(name)
            lb = label(f"LABEL_{name}", f"{pretty}  -  {t:,} triangles", cam, size_frac=0.026)
            show(lb, f)

# shooter group (flat lay, right side up)
SGROUP = [("Shotgun", (0.02, 0.26), 0), ("Rifle", (-0.06, -0.02), 0), ("Pistol", (-0.28, -0.30), 0), ("AmmoBox", (0.22, -0.30), -8)]
sg_pts = []
for name, (gx, gy), spin in SGROUP:
    pts = local_verts(name)
    c_local, size = bbox_center(pts)
    inst = instance(f"SGROUP_{name}", name)
    if name == "AmmoBox":
        rq = Euler((0, 0, D(spin + 180)), 'XYZ').to_quaternion()
    else:
        rq = Euler((0, 0, D(spin)), 'XYZ').to_quaternion() @ Euler((D(-90), 0, 0), 'XYZ').to_quaternion()
    R = rq.to_matrix().to_4x4()
    wp = [R @ (p - c_local) for p in pts]
    zmin = min(p.z for p in wp)
    Mx = Matrix.Translation(V(gx, gy, -zmin + 0.0005)) @ R @ Matrix.Translation(-c_local)
    for f in (100, 101):
        key_pose(inst, f, Mx)
    show(inst, 100)
    sg_pts += [Mx @ p for p in pts]
    w = wire_obj(f"WIRESG_{name}", name, 0.00042, inst)
    show(w, 101)
frames_all += [100, 101]
rig_key[100] = rig_key[101] = V(0.0, -0.02, 0.0)
cams = make_cam("Cam_Shooter", lens=60)
fit(cams, sg_pts, V(0.0, -0.62, 1.0), aspect=GROUP_ASPECT, margin=0.06)
camsw = make_cam("Cam_Shooter_Wire", lens=60)
camsw.location = cams.location; camsw.rotation_quaternion = cams.rotation_quaternion
markers += [(100, cams, "Shooter_beauty"), (101, camsw, "Shooter_wire")]
lb = label("LABEL_Shooter", "   ".join(f"{n} {tris(n):,}" for n in ("Pistol", "Rifle", "Shotgun", "AmmoBox")) + "   (triangles)",
           camsw, size_frac=0.016, pos=(-0.47, -0.46), aspect=GROUP_ASPECT)
show(lb, 101)

# ================================================ CHARACTERS & VEHICLES ===
# name, collection, pretty label, base frame, hero spin, detail (local point, radius, view dir), extra shots
CHARS = [
    ("Guard", "Guard", "Guard  (official Roblox R15 body + rig, original outfit)", 200, -30, (V(0.0, -0.14, 1.27), 0.165, V(0.30, -1.0, 0.10)), []),
    ("SlimeBoss", "SlimeBoss", "Slime Boss", 210, -24, (V(0.02, -0.58, 0.74), 0.40, V(0.30, -1.0, 0.18)), []),
    ("Skeleton", "Skeleton", lambda: (f"Skeleton {tris('Skeleton_Body'):,} + rusty sword {tris('Skeleton_Sword'):,} + buckler "
                                      f"{tris('Skeleton_Buckler'):,}  =  {tris('Skeleton'):,} triangles"),
     220, -26, (V(0.0, -0.14, 1.24), 0.175, V(0.30, -1.0, 0.08)), []),
]


def car_interior(inst, floor_pose, rots, pts, f):
    M = floor_pose(Quaternion())
    key_pose(inst, f, M)
    show(inst, f)
    cam = make_cam("Cam_Car_Interior", lens=17)
    eye = M @ V(-0.05, 0.62, 1.22)
    tgt = M @ V(0.18, -0.70, 0.92)
    cam.location = eye
    cam.rotation_quaternion = look_rot(eye - tgt)
    ld = bpy.data.lights.get("PRES_CabinLight") or bpy.data.lights.new("PRES_CabinLight", 'AREA')
    ld.energy = 55; ld.size = 0.9; ld.shape = 'SQUARE'; ld.color = (1.0, 0.96, 0.9)
    lo = bpy.data.objects.new("PRES_CabinLight", ld)
    C_WIRE.objects.link(lo)
    lo.location = M @ V(0.0, -0.05, 1.36)
    show(lo, f)
    return cam

CHARS += globals().get("CHARS_EXTRA", [])


def boar_scale(inst, floor_pose, rots, pts, f):
    q = Euler((0, 0, D(-58)), 'XYZ').to_quaternion()
    M = floor_pose(q)
    key_pose(inst, f, M)
    show(inst, f)
    seat = Vector(bpy.data.objects["BoarMount"]["seat_point"])
    mq = instance("SHOT_Mannequin", "Mannequin_R6")
    key_pose(mq, f, M @ Matrix.Translation(seat))
    show(mq, f)
    mpts = [M @ (seat + p) for p in local_verts("Mannequin_R6")]
    cam = make_cam("Cam_BoarMount_Scale", lens=60)
    fit(cam, [M @ p for p in pts] + mpts, V(0.10, -1.0, 0.14), margin=0.07)
    lb = label("LABEL_BoarMount_Scale", f"Seat height {seat.z:.2f} m  -  grey R6 mannequin (presentation only) for scale", cam,
               size_frac=0.024)
    show(lb, f)
    return cam

CHARS.append(("BoarMount", "BoarMount", "Boar Mount", 240, -32, (V(0.0, -0.86, 0.60), 0.27, V(0.55, -1.0, 0.12)),
              [("scale", 246, boar_scale)]))
CHARS.append(("Car", "Car", "Compact Car", 230, -32, (V(0.48, -1.58, 0.56), 0.40, V(0.55, -1.0, 0.22)),
              [("interior", 236, car_interior)]))
try:
    exec(open("/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/scripts/shots_chars_extra.py").read())
except FileNotFoundError:
    pass
for name, cname, pretty, b, spin, (dpt, drad, ddir), extras in CHARS:
    pts = local_verts(cname)
    c_local, size = bbox_center(pts)
    zmin = min(p.z for p in pts)
    inst = instance(f"SHOT_{name}", cname)
    base_pt = V(c_local.x, c_local.y, zmin)

    def floor_pose(q):
        R = q.to_matrix().to_4x4()
        return Matrix.Translation(-(R @ base_pt)) @ R

    rots = dict(hero=Euler((0, 0, D(spin)), 'XYZ').to_quaternion(), front=Quaternion(),
                side=Euler((0, 0, D(90)), 'XYZ').to_quaternion(), back=Euler((0, 0, D(180)), 'XYZ').to_quaternion())
    rots['detail'] = rots['wire'] = rots['hero']
    fr = dict(hero=b, front=b + 1, side=b + 2, back=b + 3, detail=b + 4, wire=b + 5)
    rig_pt = V(0, 0, min(size.z * 0.45, 1.3))      # tall props: keep the rim light off the upper backdrop
    for shot in ('hero', 'front', 'side', 'back', 'detail', 'wire'):
        f = fr[shot]
        frames_all.append(f)
        rig_key[f] = rig_pt
        M = floor_pose(rots[shot])
        key_pose(inst, f, M)
        if shot != 'wire':
            show(inst, f)
        world_pts = [M @ p for p in pts]
        if shot in ('front', 'side', 'back'):
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", ortho=True)
            fit(cam, world_pts, V(0, -1, 0.14), margin=0.06)     # slight downward angle: floor fills the bottom
        elif shot == 'detail':
            cam = make_cam(f"Cam_{name}_Detail", lens=90)
            P = M @ dpt
            ring = [P + V(x, y, z) * drad for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
            fit(cam, ring, ddir, margin=0.0, centre=P)
            if P.z > 2.0:                       # detail high above the floor: lift the light rig with it
                rig_key[f] = V(0, 0, P.z - 1.0)
        else:
            cam = make_cam(f"Cam_{name}_{shot.capitalize()}", lens=70)
            fit(cam, world_pts, V(0.16, -1.0, 0.16), margin=0.06)
        markers.append((f, cam, f"{name}_{shot}"))
        if shot == 'wire':
            w = wire_obj(f"WIRE_{name}", cname, max(size) * 0.00040, inst)
            show(w, f)
            txt = pretty() if callable(pretty) else f"{pretty}  -  {tris(cname):,} triangles"
            lb = label(f"LABEL_{name}", txt, cam, size_frac=0.026)
            show(lb, f)
    for ex in extras:          # (shot name, frame, builder) builder(inst, floor_pose, rots, pts) -> camera
        sname, f, builder = ex
        frames_all.append(f)
        rig_key[f] = rig_pt
        cam = builder(inst, floor_pose, rots, pts, f)
        markers.append((f, cam, f"{name}_{sname}"))

# ------------------------------------------------------- apply animation --
prefs = bpy.context.preferences.edit
_old_interp = prefs.keyframe_new_interpolation_type
prefs.keyframe_new_interpolation_type = 'CONSTANT'
frames_all = sorted(set(frames_all))
sc.timeline_markers.clear()
for f, cam, nm in markers:
    m = sc.timeline_markers.new(nm, frame=f)
    m.camera = cam
sc.frame_start, sc.frame_end = 1, max(frames_all)

for ob, fd in poses.items():
    ob.animation_data_clear()
    last = None
    for f in frames_all:
        Mx = fd.get(f, last if last is not None else next(iter(fd.values())))
        last = Mx
        loc, rot, scl = Mx.decompose()
        ob.location = loc; ob.rotation_quaternion = rot
        ob.keyframe_insert("location", frame=f)
        ob.keyframe_insert("rotation_quaternion", frame=f)

for f in frames_all:                       # rim light off where it would paint the upper backdrop
    if f not in globals().get("NO_RIM_FRAMES", ()):
        show(bpy.data.objects["Rim"], f)
all_vis_objs = set(vis) | set(poses)
for ob in list(C_DISP.objects) + list(C_WIRE.objects):
    all_vis_objs.add(ob)
for ob in all_vis_objs:
    fs = vis.get(ob, set())
    for f in frames_all:
        ob.hide_render = f not in fs
        ob.hide_viewport = f not in fs
        ob.keyframe_insert("hide_render", frame=f)
        ob.keyframe_insert("hide_viewport", frame=f)

rig = bpy.data.objects["LightRig"]
rig.animation_data_clear()
for f in frames_all:
    rig.location = rig_key.get(f, STAGE)
    rig.keyframe_insert("location", frame=f)
bpy.data.objects["LightTarget"].location = (0, 0, 0)

for ob in all_vis_objs | {rig}:
    ad = ob.animation_data
    if ad and ad.action:
        try:
            fcs = ad.action.fcurves
        except AttributeError:
            fcs = [fc for layer in ad.action.layers for strip in layer.strips
                   for bag in strip.channelbags for fc in bag.fcurves]
        for fc in fcs:
            for k in fc.keyframe_points:
                k.interpolation = 'CONSTANT'

prefs.keyframe_new_interpolation_type = _old_interp
SHOTS = [(f, cam.name, nm) for f, cam, nm in sorted(markers, key=lambda t: t[0])]
sc["shots"] = [f"{f}|{c}|{n}" for f, c, n in SHOTS]
sc["group_aspect"] = GROUP_ASPECT
sc.frame_set(1)
print(len(SHOTS), "shots")
for s in SHOTS:
    print(s)
