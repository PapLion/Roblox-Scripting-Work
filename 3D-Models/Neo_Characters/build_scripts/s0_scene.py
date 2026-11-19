exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
# wipe default scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for c in list(bpy.data.collections):
    bpy.data.collections.remove(c)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng; break
    except TypeError:
        pass
print("engine", sc.render.engine)
sc.view_settings.view_transform = 'AgX'
sc.view_settings.look = 'AgX - Medium High Contrast' if 'AgX - Medium High Contrast' in [i.identifier for i in sc.view_settings.bl_rna.properties['look'].enum_items] else 'None'
st = get_coll("STAGE")
# world
w = bpy.data.worlds.get("W_Studio") or bpy.data.worlds.new("W_Studio")
sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.012, 0.010, 0.028, 1); bg.inputs[1].default_value = 1.0
# cyclorama backdrop: floor plane bent up at the back
verts, faces = [], []
W, nseg = 14.0, 16
prof = []
for i in range(nseg + 1):
    a = math.pi / 2 * i / nseg
    prof.append((4.0 + 2.5 * math.sin(a), -1.6 + 2.5 * (1 - math.cos(a))))
prof = [(-6.0, -1.6)] + prof + [(6.5, 9.0)]
for (y, z) in prof:
    verts += [(-W / 2, y, z), (W / 2, y, z)]
for i in range(len(prof) - 1):
    faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
bd = mesh_obj("STAGE_Backdrop", verts, faces, mat("M_Stage_Backdrop", (0.035, 0.03, 0.06), rough=0.6), subsurf=0)
st.objects.link(bd)
def area(name, loc, target, energy, color, size):
    ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.color = color
    ld.shape = 'DISK'; ld.size = size
    o = bpy.data.objects.new(name, ld); o.location = loc; aim(o, target); st.objects.link(o); return o
area("LGT_Key", (-4.5, -6.5, 5.5), (0, 0, 0.3), 1400, (1.0, 0.96, 0.93), 4.0)
area("LGT_Fill", (6.0, -5.0, 1.5), (0, 0, 0.3), 450, (0.70, 0.75, 1.0), 5.0)
area("LGT_RimViolet", (-5.0, 5.0, 4.0), (0, 0, 0.5), 1200, (0.62, 0.42, 1.0), 3.0)
area("LGT_RimCyan", (5.5, 4.5, 3.0), (0, 0, 0.5), 900, (0.40, 0.65, 1.0), 3.0)
area("LGT_Top", (0, -1.0, 8.0), (0, 0, 0), 500, (0.85, 0.82, 1.0), 6.0)
print("scene ok", [o.name for o in bpy.data.objects])
