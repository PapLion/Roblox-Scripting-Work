"""Smart-UV-project asset meshes (run after the builders).
If the global UV_COLLS (list of collection names) is defined, only those collections
are processed; otherwise every mesh of the 'Assets' scene."""
import bpy, math
sc = bpy.data.scenes["Assets"]
bpy.context.window.scene = sc
for lc in bpy.context.view_layer.layer_collection.children:
    lc.exclude = False; lc.hide_viewport = False
colls = globals().get("UV_COLLS")
objs = globals().get("UV_OBJS")
if objs:
    meshes = [bpy.data.objects[n] for n in objs]
elif colls:
    meshes = list({o for n in colls for o in bpy.data.collections[n].all_objects if o.type == 'MESH'})
else:
    meshes = [o for o in sc.objects if o.type == 'MESH']
# linked duplicates (product colour variants) share mesh data: unwrap each mesh once
seen, uniq = set(), []
for o in meshes:
    if o.data.name not in seen:
        seen.add(o.data.name); uniq.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in uniq:
    o.hide_set(False)
    o.select_set(True)
bpy.context.view_layer.objects.active = uniq[0]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.01, scale_to_bounds=False)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
for o in uniq:
    o.data.uv_layers[0].name = "UVMap"
print("UV done:", len(uniq), "meshes")
