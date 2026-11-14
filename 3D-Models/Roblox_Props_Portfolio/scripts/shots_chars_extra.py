# Executed inside shots.py (same globals) before the CHARS loop.
# URBAN / SHOP PROPS: frames 300-366 (per piece), 357 products line-up, 370 urban corner scene.


def inst_children(cname):
    return [o for o in bpy.data.collections[cname].all_objects if o.instance_type == 'COLLECTION' and o.instance_collection]


def total_tris(cname):
    return tris(cname) + sum(tris(o.instance_collection.name) for o in inst_children(cname))


def stock_label(cname, pretty):
    def f():
        ins = inst_children(cname)
        if not ins:
            return f"{pretty}  -  {tris(cname):,} triangles"
        return (f"{pretty} {tris(cname):,} + {len(ins)} product instances {total_tris(cname) - tris(cname):,}"
                f"  =  {total_tris(cname):,} triangles rendered")
    return f


def products_lineup(inst, floor_pose, rots, pts, f):
    names = ["Product_Can", "Product_Can_Orange", "Product_Bottle", "Product_Bottle_Juice", "Product_BoxSmall",
             "Product_BoxTall", "Product_BoxTall_Blue"]
    allp = []
    # small still-life: tall items at the back, cans and the snack box in front
    LAY = {"Product_BoxTall": (-0.215, 0.10, 8), "Product_BoxTall_Blue": (0.0, 0.13, -6),
           "Product_Bottle": (0.165, 0.10, 20), "Product_Bottle_Juice": (0.255, 0.07, -30),
           "Product_Can": (-0.17, -0.10, 30), "Product_Can_Orange": (-0.075, -0.09, -20),
           "Product_BoxSmall": (0.10, -0.10, 12)}
    for n in names:
        p = local_verts(n)
        c, s = bbox_center(p)
        x, y, rz = LAY[n]
        e = instance(f"SHOT_{n}", n)
        R = Euler((0, 0, D(rz)), 'XYZ').to_matrix().to_4x4()
        M = Matrix.Translation(V(x, y, -min(q.z for q in p))) @ R @ Matrix.Translation(V(-c.x, -c.y, 0))
        key_pose(e, f, M)
        show(e, f)
        allp += [M @ q for q in p]
    cam = make_cam("Cam_Shelf_Products", lens=85)
    fit(cam, allp, V(0.25, -1.0, 0.45), margin=0.10)
    lb = label("LABEL_Shelf_Products", "Can " + f"{tris('Product_Can'):,}" + "  -  Bottle " + f"{tris('Product_Bottle'):,}"
               + "  -  Tall box " + f"{tris('Product_BoxTall'):,}" + "  -  Snack box " + f"{tris('Product_BoxSmall'):,}"
               + " triangles  (colour variants reuse the same meshes)", cam, size_frac=0.019, pos=(-0.46, -0.45))
    show(lb, f)
    rig_key[f] = V(0, 0, 0.12)
    return cam


def urban_scene(inst, floor_pose, rots, pts, f):
    """Small urban corner built ONLY from the props + a floor and two plain walls,
    with the standing mannequin for scale."""
    W_BACK, W_LEFT = 1.25, -3.20
    Z0 = 0.18                                  # sidewalk top (street sits just above the studio floor)
    walls = flat_mat("PRES_Wall", "#D9CDBB", 0.85)
    wall2 = flat_mat("PRES_Wall2", "#B38D78", 0.85)
    tile = flat_mat("PRES_Tile", "#ABA9A3", 0.8)
    grout = flat_mat("PRES_Grout", "#5E5F60", 0.9)
    asph = flat_mat("PRES_Asphalt", "#3E4146", 0.9)
    curb = flat_mat("PRES_Curb", "#C5C3BC", 0.8)

    def box(name, c, h, mat, r=0.01):
        bm = bmesh.new()
        lib.rounded_box(bm, c + V(0, 0, Z0), h[0], h[1], h[2], r, seg=1)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me); bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        C_DISP.objects.link(ob)
        show(ob, f)
        return ob

    box("SCENE_WallBack", V(0.75, W_BACK + 0.15, 3.6), (4.10, 0.15, 3.6), walls)
    box("SCENE_WallLeft", V(W_LEFT - 0.15, -1.10, 3.6), (0.15, 2.50, 3.6), wall2)
    box("SCENE_Plinth", V(0.75, W_BACK - 0.01, 0.06), (4.10, 0.012, 0.06), grout, r=0.004)
    box("SCENE_Base", V(0.75, -0.40, -0.09), (4.10, 1.68, 0.085), grout)
    for i in range(13):                       # sidewalk tiles 0.6 m
        for j in range(5):
            x = W_LEFT + 0.30 + i * 0.60
            y = W_BACK - 0.30 - j * 0.60
            box(f"SCENE_Tile_{i}_{j}", V(x, y, -0.02), (0.294, 0.294, 0.02), tile, r=0.006)
    box("SCENE_Curb", V(0.75, W_BACK - 3.0 - 0.09, -0.085), (4.10, 0.09, 0.085), curb, r=0.02)
    box("SCENE_Street", V(0.75, W_BACK - 3.0 - 0.18 - 1.6, -0.135), (4.10, 1.6, 0.04), asph)

    def put(cname, loc, rz):
        e = instance(f"SCENE_{cname}", cname)
        M = Matrix.Translation(loc + V(0, 0, Z0)) @ Euler((0, 0, D(rz)), 'XYZ').to_matrix().to_4x4()
        key_pose(e, f, M)
        show(e, f)
        return M

    put("VendingMachine", V(-1.05, W_BACK, 0), 0)
    put("Shelf", V(0.25, W_BACK, 0), 0)
    put("ACUnit", V(1.75, W_BACK, 1.55), 0)
    put("Dumpster", V(W_LEFT + 0.62, 0.10, 0), 90)
    put("Bench", V(1.55, -0.55, 0), 0)
    put("StreetLamp", V(3.05, 0.55, 0), 0)
    put("Mannequin_R6_Standing", V(-1.55, -0.80, 0), 20)
    cam = make_cam("Cam_UrbanCorner", lens=24)
    eye = V(1.60, -6.30, 2.90 + Z0)
    tgt = V(0.10, 0.30, 2.25 + Z0)
    # warm pool of light under the lamp head
    ld = bpy.data.lights.get("PRES_LampSpot") or bpy.data.lights.new("PRES_LampSpot", 'SPOT')
    ld.energy = 450; ld.spot_size = D(95); ld.spot_blend = 0.6; ld.color = (1.0, 0.88, 0.70); ld.shadow_soft_size = 0.25
    lo = bpy.data.objects.new("PRES_LampSpot", ld)
    C_WIRE.objects.link(lo)
    lo.location = V(3.05, 0.55 - 1.21, 4.40 + Z0)
    show(lo, f)
    cam.location = eye
    cam.rotation_quaternion = look_rot(eye - tgt)
    lb = label("LABEL_UrbanCorner", "Urban corner: the six props + floor and plain walls  -  grey mannequin 1.50 m for scale "
               "(presentation only)", cam, size_frac=0.016, pos=(-0.47, -0.46), aspect=1.5)
    show(lb, f)
    rig_key[f] = V(-0.2, -0.3, 0.0)
    return cam


NO_RIM_FRAMES = list(range(330, 336))

PROPS = [
    ("VendingMachine", "Vending Machine", 300, -30, (V(0.30, -0.80, 1.12), 0.24, V(0.55, -1.0, 0.10)), []),
    ("Dumpster", "Waste Container", 310, -32, (V(-0.40, -0.40, 0.17), 0.22, V(0.40, -1.0, 0.32)), []),
    ("Bench", "Park Bench", 320, -30, (V(0.68, -0.20, 0.50), 0.24, V(0.75, -1.0, 0.35)), []),
    ("StreetLamp", "Street Lamp", 330, -40, (V(0.0, -1.18, 4.52), 0.40, V(0.40, -1.0, -0.10)), []),
    ("ACUnit", "AC Outdoor Unit", 340, -28, (V(-0.115, -0.40, 0.715), 0.27, V(0.35, -1.0, 0.18)), []),
    ("Shelf", "Shop Shelf", 350, -28, (V(0.0, -0.40, 0.98), 0.30, V(0.35, -1.0, 0.22)),
     [("products", 357, products_lineup), ("scene", 370, urban_scene)]),
]
for cname, pretty, b, spin, det, extras in PROPS:
    CHARS.append((cname, cname, stock_label(cname, pretty), b, spin, det, extras))
