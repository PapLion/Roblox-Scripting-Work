"""Background renderer:  blender -b Roblox_Props_Portfolio.blend -P render_all.py -- [frames...]
Writes renders/<piece>/<piece>_<view>.png and renders/collection/*.png"""
import bpy, sys, os, time
ROOT = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/renders"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
want = {int(a) for a in argv} if argv else None
sc = bpy.data.scenes["Showcase"]
bpy.context.window_manager  # noqa
r = sc.render
r.resolution_percentage = 100
r.image_settings.file_format = 'PNG'
r.image_settings.color_mode = 'RGB'
sc.eevee.taa_render_samples = int(os.environ.get('PP_SAMPLES', '40'))
NAMES = {"Group_beauty": ("collection", "collection_beauty"), "Group_wire": ("collection", "collection_wireframe"),
         "Shooter_beauty": ("shooter_collection", "shooter_collection_beauty"), "Shooter_wire": ("shooter_collection", "shooter_collection_wireframe"),
         "Shelf_scene": ("urban_scene", "urban_corner_scene")}
for f, cam, nm in [s.split("|") for s in sc["shots"]]:
    f = int(f)
    if want and f not in want:
        continue
    if nm in NAMES:
        folder, base = NAMES[nm]
        r.resolution_x, r.resolution_y = 3072, 2048
    else:
        piece, view = nm.split("_")
        folder, base = piece.lower(), f"{piece.lower()}_{'wireframe' if view == 'wire' else view}"
        r.resolution_x = r.resolution_y = 2048
    sc.frame_set(f)
    sc.camera = bpy.data.objects[cam]
    os.makedirs(os.path.join(ROOT, folder), exist_ok=True)
    r.filepath = os.path.join(ROOT, folder, base + ".png")
    t = time.time()
    bpy.ops.render.render(write_still=True, scene=sc.name)
    print(f"RENDERED {r.filepath} {time.time() - t:.1f}s", flush=True)
