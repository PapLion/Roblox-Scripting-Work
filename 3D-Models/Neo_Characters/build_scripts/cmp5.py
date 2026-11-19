# per-character comparison: [TARGET crop | current render at the same framing]. CH is set by the caller.
exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
import numpy as np, time
t0 = time.time()
# frame width in scene units, resolution = target crop size, (dx, dz) of the crop centre from the head centre
CFG = {"Nix": dict(W=4.2, res=(640, 610), off=(-0.20, 0.30), R=1.0),
       "Yoru": dict(W=3.47 * 0.85, res=(520, 520), off=(-0.01, 0.20), R=0.85),
       "Akemi": dict(W=3.0, res=(570, 840), off=(0.0, -0.78), R=1.0)}
c = CFG[CH]
root = bpy.data.objects[CH + "_Root"]
ctr = root.location + Vector((c["off"][0], 0, c["off"][1]))
lens = 110.0
d = c["W"] * lens / 36.0 * max(1.0, c["res"][1] / c["res"][0])   # sensor fit AUTO: portrait frames fit the height
pitch = math.radians(PITCH if "PITCH" in globals() else 0.0)
yaw = math.radians(YAW if "YAW" in globals() else 0.0)
loc = ctr + Vector((math.sin(yaw) * d * math.cos(pitch), -math.cos(yaw) * d * math.cos(pitch), d * math.sin(pitch)))
p = f"{SCRATCH}/cmp_r_{CH}.png"
bd = bpy.data.objects.get("STAGE_Backdrop")
if bd and abs(yaw) > 1.2: bd.hide_render = True
render_view(p, loc, ctr, lens=lens, res=c["res"], only=[CH], samples=SAMPLES if "SAMPLES" in globals() else 16)
if bd: bd.hide_render = False
def load(path):
    im = bpy.data.images.load(path, check_existing=False); w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4).copy(); bpy.data.images.remove(im); return a
a = load(p)
tag = TAG if "TAG" in globals() else ""
if "SOLO" in globals() and SOLO:
    sheet = a
else:
    t = load(f"/home/dani.pp/Downloads/job/neo_build_scripts/tgt5/t1_{CH.lower()}.png")
    sheet = np.concatenate([t, a], axis=1)
if "UP" in globals() and UP > 1:
    sheet = np.repeat(np.repeat(sheet, UP, axis=0), UP, axis=1)
H, Wd = sheet.shape[:2]
img = bpy.data.images.new("tmp_cmp", Wd, H, alpha=True); img.pixels = sheet.ravel()
img.filepath_raw = f"{SCRATCH}/cmp_{CH}{tag}.png"; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
print("cmp", CH, round(time.time() - t0, 1), "s")
