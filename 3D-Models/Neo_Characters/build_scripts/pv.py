exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
import numpy as np, time
t0 = time.time()
p = SCRATCH + "/pv_full.png"
render_view(p, (0.0, -11.5, 1.4), (0.0, 0, 0.25), lens=42, res=(1920, 1080), samples=24, cam="CAM_Main")
im = bpy.data.images.load(p, check_existing=False); w, h = im.size
a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
for name, (x0, y0, x1, y1) in {"nix": (100, 180, 780, 860), "yoru": (720, 330, 1240, 880), "akemi": (1240, 40, 1860, 900)}.items():
    c = a[y0:y1, x0:x1]; ch, cw = c.shape[:2]
    o = bpy.data.images.new("pv_" + name, cw, ch, alpha=True); o.pixels[:] = c[::-1].ravel()
    o.filepath_raw = f"{SCRATCH}/pv_{name}.png"; o.file_format = 'PNG'; o.save(); bpy.data.images.remove(o)
bpy.data.images.remove(im)
print("pv", round(time.time() - t0, 1), "s")
