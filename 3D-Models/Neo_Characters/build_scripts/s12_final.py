# s12_final.py — v5 deliverables: beauty render (target framing), multi-angle inspection sheet, clay sheet, save.
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
exec(open(S_ + "s10_light.py").read(), globals())
exec(open(S_ + "s11_present.py").read(), globals())      # camera, facing, stage (also loads lib/lib2/lib3)
import os, time
QUICK = bool(globals().get("QUICK", False))
OUT = SCRATCH + "/v5q" if QUICK else "/home/dani.pp/Downloads/job/renders"
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
bd = bpy.data.objects["STAGE_Backdrop"]
t0 = time.time()
if not (QUICK and globals().get("NO_BEAUTY", False)):
    sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
    sc.render.resolution_percentage = 100
    sc.eevee.taa_render_samples = 24 if QUICK else 128
    for ch in ("Nix", "Yoru", "Akemi"):
        bpy.data.collections["CHAR_" + ch].hide_render = False
    sc.render.filepath = OUT + "/Neo_Final_Presentation_v5.png"
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    print("beauty", round(time.time() - t0, 1), "s")
# ---- inspection: front / three-quarter / side / back, each relative to the character's own facing
cfg = {"Nix": (Vector((-2.9, 0, 0.35)), 9.0, 0.30), "Yoru": (Vector((0, 0, -0.15)), 6.6, 0.05), "Akemi": (Vector((2.9, 0, 1.05)), 8.8, -0.45)}
views = (("front", 0), ("34", -40), ("side", 90), ("back", 180))
RES = 400 if QUICK else 480
SMP = 16 if QUICK else 48
def sheet(prefix, out):
    for ch, (c, dist, tz) in cfg.items():
        rz = bpy.data.objects[ch + "_Root"].rotation_euler.z
        t = c + Vector((0, 0, tz))
        for vn, az in views:
            a = math.radians(az) + rz
            loc = t + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.5))
            bd.hide_render = (vn in ("back", "side"))
            render_view(f"{OUT}/{prefix}_{ch}_{vn}.png", loc, t, lens=55, res=(RES, RES), only=[ch], samples=SMP)
    bd.hide_render = False
    contact_sheet([[f"{OUT}/{prefix}_{c}_{v}.png" for v, _ in views] for c in cfg], out)
    for ch in cfg:
        for v, _ in views:
            os.remove(f"{OUT}/{prefix}_{ch}_{v}.png")
sheet("insp", OUT + "/Neo_Inspection_Sheet_v5.png")
# ---- clay sheet: neutral grey override, white lights -> pure form
vl = bpy.context.view_layer
clay = bpy.data.materials.get("M_Clay") or mat("M_Clay", (0.62, 0.62, 0.64), rough=0.55)
saved_l = {o.name: (tuple(o.data.color), o.data.energy) for o in bpy.data.objects if o.type == 'LIGHT'}
bg = sc.world.node_tree.nodes["Background"]; saved_w = tuple(bg.inputs[0].default_value)
for o in bpy.data.objects:
    if o.type == 'LIGHT':
        o.data.color = (1, 1, 1)
        if "Rim" in o.name or "Pool" in o.name: o.data.energy *= 0.3
bg.inputs[0].default_value = (0.05, 0.05, 0.055, 1)
vl.material_override = clay
try:
    sheet("clay", OUT + "/Neo_Clay_Sheet_v5.png")
finally:
    vl.material_override = None
    for n_, (c_, e_) in saved_l.items():
        bpy.data.objects[n_].data.color = c_; bpy.data.objects[n_].data.energy = e_
    bg.inputs[0].default_value = saved_w
# ---- leave the scene ready on the presentation camera and save
sc.camera = bpy.data.objects["CAM_Main"]
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.eevee.taa_render_samples = 128
if not QUICK:
    bpy.ops.wm.save_as_mainfile(filepath="/home/dani.pp/Downloads/job/Neo_Characters.blend")
    print("saved", bpy.data.filepath)
print("final done", round(time.time() - t0, 1), "s")
