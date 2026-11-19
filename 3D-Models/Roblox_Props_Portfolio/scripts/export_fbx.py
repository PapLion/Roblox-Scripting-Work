"""blender -b Roblox_Props_Portfolio.blend -P export_fbx.py
Exports each asset to export/<Asset>/<Asset>.fbx with the *export* materials only
(procedural presentation nodes are removed in this session; the .blend is not saved).
Writes export/export_manifest.json with the source stats used by verify_fbx.py."""
import bpy, json, os
from mathutils import Vector, Matrix

ROOT = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio"
ASSETS = [  # (export name, collection, root empty)
    ("Axe", "Axe", "Axe"), ("Sword", "Sword", "Sword"), ("Hammer", "Hammer", "Hammer"),
    ("Pickaxe", "Pickaxe", "Pickaxe"), ("Shield", "Shield", "Shield"),
    ("Dagger", "Dagger_Knife", "Dagger"), ("Dagger_Sheath", "Dagger_Sheath", "Dagger_Sheath"),
    ("Pistol", "Pistol", "Pistol"), ("Rifle", "Rifle", "Rifle"), ("Shotgun", "Shotgun", "Shotgun"),
    ("AmmoBox", "AmmoBox", "AmmoBox"),
    ("Guard", "Guard", "Guard"), ("SlimeBoss", "SlimeBoss", "SlimeBoss"),
    ("Skeleton", "Skeleton_Body", "Skeleton"), ("Skeleton_Sword", "Skeleton_Sword", "Skeleton_Sword"),
    ("Skeleton_Buckler", "Skeleton_Buckler", "Skeleton_Buckler"),
    ("Car", "Car", "Car"), ("BoarMount", "BoarMount", "BoarMount"),
    ("VendingMachine", "VendingMachine", "VendingMachine"), ("Dumpster", "Dumpster", "Dumpster"),
    ("Bench", "Bench", "Bench"), ("StreetLamp", "StreetLamp", "StreetLamp"), ("ACUnit", "ACUnit", "ACUnit"),
    ("Shelf", "Shelf", "Shelf"), ("Shelf_Stocked", "Shelf", "Shelf"),
    ("Product_Can", "Product_Can", "Product_Can"), ("Product_Bottle", "Product_Bottle", "Product_Bottle"),
    ("Product_BoxTall", "Product_BoxTall", "Product_BoxTall"), ("Product_BoxSmall", "Product_BoxSmall", "Product_BoxSmall"),
]
WITH_RIG = {"Guard"}                       # exported with the official R15 armature
REALIZE = {"VendingMachine", "Shelf_Stocked"}   # collection-instanced stock baked into one mesh per material


def realize_stock(cname, root, sc):
    """Bake the product instances of a collection into temp meshes (one per material)."""
    import bmesh
    # 1) collect everything first: never add/remove IDs while iterating collection caches
    items = []
    for e in list(bpy.data.collections[cname].all_objects):
        if e.instance_type != 'COLLECTION' or not e.instance_collection:
            continue
        ic = e.instance_collection
        off = Matrix.Translation(-Vector(ic.instance_offset))
        for o in list(ic.all_objects):
            if o.type == 'MESH':
                items.append((o.data, e.matrix_world @ off @ o.matrix_world, o.material_slots[0].material))
    # 2) bake
    groups = {}
    for me_src, mtx, mat in items:
        if mat.name not in groups:
            groups[mat.name] = (mat, bmesh.new())
        bm = groups[mat.name][1]
        tmp = bmesh.new()
        tmp.from_mesh(me_src)
        bmesh.ops.transform(tmp, matrix=mtx, verts=tmp.verts)
        me_tmp = bpy.data.meshes.new("_tmp_stock")
        tmp.to_mesh(me_tmp); tmp.free()
        bm.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
    made = []
    for mname, (mat, bm) in groups.items():
        me = bpy.data.meshes.new(f"{cname}_Stock_{mname[2:]}")
        bm.to_mesh(me); bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(me.name, me)
        sc.collection.objects.link(ob)
        ob.matrix_world = root.matrix_world.inverted() @ Matrix.Identity(4) if False else Matrix.Identity(4)
        made.append(ob)
    return made

# 1) strip presentation layer -> flat Principled values
for m in bpy.data.materials:
    if not m.node_tree or "export_color_hex" not in m:
        continue
    for n in [n for n in m.node_tree.nodes if n.get("presentation")]:
        m.node_tree.nodes.remove(n)

sc = bpy.data.scenes["Assets"]
vl = sc.view_layers[0]
for lc in vl.layer_collection.children:
    lc.exclude = False; lc.hide_viewport = False
manifest = {}
# bake the instanced stock up-front (before any FBX export runs), with the roots at identity
PRE = {}
for name, cname, rname in ASSETS:
    if name in REALIZE:
        root = bpy.data.objects[rname]
        old = root.matrix_world.copy()
        root.matrix_world = Matrix.Identity(4)
        vl.update()
        PRE[name] = realize_stock(cname, root, sc)
        root.matrix_world = old
        vl.update()
        print("BAKED", name, [o.name for o in PRE[name]], flush=True)
for name, cname, rname in ASSETS:
    root = bpy.data.objects[rname]
    old = root.matrix_world.copy()
    root.matrix_world = Matrix.Identity(4)          # grip / pivot at world origin
    vl.update()
    meshes = [o for o in bpy.data.collections[cname].all_objects if o.type == 'MESH']
    extra = PRE.get(name, [])
    meshes += extra
    rig = [o for o in bpy.data.collections[cname].all_objects if o.type == 'ARMATURE'] if name in WITH_RIG else []
    for o in sc.objects:
        o.select_set(False, view_layer=vl)
    for o in meshes + rig:
        o.hide_set(False, view_layer=vl)
        o.select_set(True, view_layer=vl)
    vl.objects.active = meshes[0]
    # stats in pivot space
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in meshes:
        ev = o.evaluated_get(dg); me = ev.to_mesh()
        pts += [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    mn = [min(p[i] for p in pts) for i in range(3)]; mx = [max(p[i] for p in pts) for i in range(3)]
    tris = 0
    for o in meshes:
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
    mats = sorted({o.material_slots[0].material.name for o in meshes})
    os.makedirs(f"{ROOT}/export/{name}", exist_ok=True)
    path = f"{ROOT}/export/{name}/{name}.fbx"
    with bpy.context.temp_override(scene=sc, view_layer=vl, active_object=meshes[0], selected_objects=meshes + rig):
      bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH', 'ARMATURE'} if rig else {'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
                             axis_forward='-Z', axis_up='Y', use_mesh_modifiers=True,
                             mesh_smooth_type='FACE', use_triangles=True, use_tspace=False,
                             add_leaf_bones=False, bake_anim=False, path_mode='AUTO', embed_textures=False)
    manifest[name] = dict(file=path, tris=tris, size_m=[round(mx[i] - mn[i], 4) for i in range(3)],
                          bbox_min=[round(v, 4) for v in mn], bbox_max=[round(v, 4) for v in mx],
                          parts=sorted(o.name for o in meshes), materials=mats,
                          pivots={o.name: [round(c, 4) for c in o.matrix_world.translation] for o in meshes},
                          bones=len(rig[0].data.bones) if rig else 0)
    for o in extra:
        me = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.meshes.remove(me)
    root.matrix_world = old
    print("EXPORTED", path, tris, flush=True)

mat_info = {}
for m in bpy.data.materials:
    if "export_color_hex" in m:
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        mat_info[m.name] = dict(hex=m["export_color_hex"], metallic=round(b.inputs['Metallic'].default_value, 2),
                                roughness=round(b.inputs['Roughness'].default_value, 2))
json.dump(dict(assets=manifest, materials=mat_info), open(f"{ROOT}/export/export_manifest.json", "w"), indent=1)
print("MANIFEST OK")
