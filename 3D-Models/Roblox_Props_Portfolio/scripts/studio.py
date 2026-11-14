"""Reusable studio: scene 'Showcase' with a seamless cyclorama, soft 3-light rig,
neutral world and render settings.  Assets are shown through collection instances,
so the 'Assets' scene keeps the clean, exportable originals."""
import bpy, bmesh, math
from mathutils import Vector
import lib
from lib import V

sc = bpy.data.scenes.get("Showcase") or bpy.data.scenes.new("Showcase")
studio = bpy.data.collections.get("Studio")
if studio is None:
    studio = bpy.data.collections.new("Studio")
if studio.name not in sc.collection.children:
    sc.collection.children.link(studio)
for o in list(studio.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# ------------------------------------------------------------ cyclorama ---
R, WALL_Y, TOP, FRONT, HALF_W = 1.6, 2.4, 7.0, -45.0, 9.0
prof = [(FRONT, 0.0), (-3.0, 0.0), (0.0, 0.0), (WALL_Y - R - 0.4, 0.0)]
for i in range(1, 17):
    a = math.pi / 2 * i / 16
    prof.append((WALL_Y - R + R * math.sin(a), R - R * math.cos(a)))
prof += [(WALL_Y, R + 1.0), (WALL_Y, TOP)]
bm = bmesh.new()
cols = 24
grid = []
for (y, z) in prof:
    grid.append([bm.verts.new((-HALF_W + 2 * HALF_W * i / cols, y, z)) for i in range(cols + 1)])
for a, b in zip(grid, grid[1:]):
    for i in range(cols):
        bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
me = bpy.data.meshes.new("Cyclorama")
bm.normal_update()
bm.to_mesh(me)
bm.free()
cyc = bpy.data.objects.new("Cyclorama", me)
studio.objects.link(cyc)
me.shade_smooth()
for f in me.polygons:
    pass
# make sure normals point up / toward camera
bm = bmesh.new(); bm.from_mesh(me)
for f in bm.faces:
    f.normal_update()
if sum(f.normal.z for f in bm.faces) < 0:
    for f in bm.faces:
        f.normal_flip()
bm.to_mesh(me); bm.free()

bg = bpy.data.materials.get("PRES_Backdrop") or bpy.data.materials.new("PRES_Backdrop")
bg.use_nodes = True
nt = bg.node_tree
b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
b.inputs['Base Color'].default_value = lib.hexcol("#A7AAAE")
b.inputs['Roughness'].default_value = 0.9
try:
    b.inputs['Specular IOR Level'].default_value = 0.2
except KeyError:
    pass
me.materials.clear(); me.materials.append(bg)

# ---------------------------------------------------------------- lights --
rig = bpy.data.objects.new("LightRig", None)
studio.objects.link(rig)
rig.empty_display_size = 0.3
target = bpy.data.objects.new("LightTarget", None)
studio.objects.link(target)
target.parent = rig
target.location = (0, 0, 0.0)


def area(name, loc, size, power, color=(1, 1, 1), sy=None):
    ld = bpy.data.lights.get(name) or bpy.data.lights.new(name, 'AREA')
    ld.shape = 'RECTANGLE'
    ld.size = size
    ld.size_y = sy or size
    ld.energy = power
    ld.color = color
    try:
        ld.use_shadow = True
        ld.shadow_soft_size = size
    except Exception:
        pass
    ob = bpy.data.objects.new(name, ld)
    studio.objects.link(ob)
    ob.parent = rig
    ob.location = loc
    c = ob.constraints.new('TRACK_TO')
    c.target = target
    c.track_axis = 'TRACK_NEGATIVE_Z'
    c.up_axis = 'UP_Y'
    return ob


area("Key", (-2.3, -2.4, 3.0), 2.6, 520, (1.0, 0.97, 0.93))
area("Fill", (3.0, -2.2, 1.3), 3.2, 160, (0.93, 0.96, 1.0))
area("Rim", (1.6, 2.0, 2.6), 2.4, 380, (0.92, 0.95, 1.0), sy=0.8)
area("Top", (0.0, -0.4, 4.2), 3.0, 140)

# ----------------------------------------------------------------- world --
w = bpy.data.worlds.get("PRES_World") or bpy.data.worlds.new("PRES_World")
w.use_nodes = True
nt = w.node_tree
bgn = next(n for n in nt.nodes if n.type == "BACKGROUND")
bgn.inputs['Color'].default_value = lib.hexcol("#6E7176")
bgn.inputs['Strength'].default_value = 0.55
sc.world = w

# --------------------------------------------------------- render settings -
r = sc.render
try:
    r.engine = 'BLENDER_EEVEE'
except TypeError as e:
    print("engine:", e)
r.resolution_x = r.resolution_y = 2048
r.resolution_percentage = 100
r.film_transparent = False
r.image_settings.file_format = 'PNG'
r.image_settings.color_mode = 'RGB'
r.image_settings.color_depth = '8'
ee = sc.eevee
for k, v in (("taa_render_samples", 96), ("use_raytracing", True), ("use_shadows", True),
             ("shadow_ray_count", 3), ("shadow_step_count", 8), ("use_gtao", True),
             ("gtao_distance", 0.25), ("fast_gi_distance", 0.6)):
    try:
        setattr(ee, k, v)
    except Exception as e:
        print("eevee", k, e)
try:
    ee.ray_tracing_options.resolution_scale = '1'
except Exception as e:
    print(e)
vs = sc.view_settings
looks = [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties['look'].enum_items] if False else None
vs.view_transform = 'AgX'
try:
    vs.look = 'AgX - Medium High Contrast'
except TypeError as e:
    print("look", e)
vs.exposure = 0.0
sc.unit_settings.system = 'METRIC'
print("studio ok", [o.name for o in studio.objects])
