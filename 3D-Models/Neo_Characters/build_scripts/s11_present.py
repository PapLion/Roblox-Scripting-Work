# s11_present.py — v5 presentation: camera matched to the target framing + preview render
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
for f_ in ("lib.py", "lib2.py", "lib3.py"):
    exec(open(S_ + f_).read(), globals())
import time
for ch in ("Nix", "Yoru", "Akemi"):
    face_camera(ch)
cam = get_cam("CAM_Main")
cam.location = CAM_POS
cam.rotation_euler = CAM_FWD.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = CAM_LENS
sc = bpy.context.scene
sc.camera = cam
bd_ = bpy.data.objects.get("STAGE_Backdrop")
if bd_:
    bd_.rotation_euler = (0, 0, math.atan2(-CAM_FWD.x, CAM_FWD.y))     # the stage faces the camera
    bd_.scale = (1.9, 1.9, 1.0)                                            # wide enough: no wall edges in frame
    zmin = min(v.co.z for v in bd_.data.vertices)
else:
    zmin = -2.0
# soft violet pool of light on the floor / lower wall behind the characters (the target's glowing stage)
pl = bpy.data.objects.get("LGT_FloorPool")
if pl is None:
    ld = bpy.data.lights.new("LGT_FloorPool", 'SPOT')
    pl = bpy.data.objects.new("LGT_FloorPool", ld)
    bpy.data.collections["STAGE"].objects.link(pl)
pl.data.color = (0.50, 0.30, 1.0); pl.data.energy = 9000; pl.data.spot_size = math.radians(95); pl.data.spot_blend = 1.0
pl.data.shadow_soft_size = 2.0
pl.location = Vector((-1.2, 3.2, 5.5))
aim(pl, Vector((-0.6, 1.2, zmin)))
# the pool only lights the stage, never the characters (so back / side views are not burnt out)
rc = bpy.data.collections.get("STAGE_PoolReceivers") or bpy.data.collections.new("STAGE_PoolReceivers")
if bd_ and bd_.name not in rc.objects: rc.objects.link(bd_)
try:
    pl.light_linking.receiver_collection = rc
    print("pool light linked to the backdrop only")
except Exception as e_:
    pl.data.energy = 2500
    print("light linking unavailable:", e_)
print("floor z", round(zmin, 2))
if "PREVIEW" in globals() and PREVIEW:
    t0 = time.time()
    sc.render.resolution_x, sc.render.resolution_y = 1672, 941
    sc.render.resolution_percentage = 100
    sc.eevee.taa_render_samples = 24
    for ch in ("Nix", "Yoru", "Akemi"):
        bpy.data.collections["CHAR_" + ch].hide_render = False
    sc.render.filepath = SCRATCH + "/pv5_full.png"
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    print("preview", round(time.time() - t0, 1), "s")
