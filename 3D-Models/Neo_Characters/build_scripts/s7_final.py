exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
OUT = "/home/dani.pp/Downloads/job/renders"
import os; os.makedirs(OUT, exist_ok=True)
render_view(OUT + "/Neo_Final_Presentation_v2.png", (0.0, -11.5, 1.4), (0.0, 0, 0.25), lens=42, res=(1920, 1080), samples=64, cam="CAM_Main")
bd = bpy.data.objects["STAGE_Backdrop"]
cfg = {"Nix": (Vector((-2.9, 0, 0.35)), 6.8, 0.0), "Yoru": (Vector((0, 0, -0.15)), 6.0, -0.1), "Akemi": (Vector((2.9, 0, 1.05)), 8.8, -0.6)}
views = (("front", 0), ("34", -40), ("side", 90), ("back", 180))
for ch, (c, dist, tz) in cfg.items():
    root = bpy.data.objects[ch + "_Root"]
    rz = root.rotation_euler.z
    t = c + Vector((0, 0, tz))
    for vn, az in views:
        a = math.radians(az) + rz
        loc = t + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.9))
        bd.hide_render = (vn == "back")
        render_view(f"{OUT}/insp_{ch}_{vn}.png", loc, t, lens=55, res=(480, 480), only=[ch], samples=24)
bd.hide_render = False
contact_sheet([[f"{OUT}/insp_{c}_{v}.png" for v, _ in views] for c in cfg], OUT + "/Neo_Inspection_Sheet_v2.png")
for ch in cfg:
    for v, _ in views:
        os.remove(f"{OUT}/insp_{ch}_{v}.png")
sc = bpy.context.scene
sc.camera = bpy.data.objects["CAM_Main"]
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.eevee.taa_render_samples = 64
bpy.ops.wm.save_as_mainfile(filepath="/home/dani.pp/Downloads/job/Neo_Characters.blend")
print("saved", bpy.data.filepath)
