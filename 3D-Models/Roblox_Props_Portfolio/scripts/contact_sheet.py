"""blender -b --factory-startup -P contact_sheet.py -- out.png tile_px cols img1 img2 ..."""
import bpy, sys, numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
out, T, cols, files = a[0], int(a[1]), int(a[2]), a[3:]
tiles = []
for f in files:
    im = bpy.data.images.load(f)
    w, h = im.size
    s = T / max(w, h)
    im.scale(max(1, int(w * s)), max(1, int(h * s)))
    w, h = im.size
    tiles.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4))
    bpy.data.images.remove(im)
H = max(t.shape[0] for t in tiles); W = max(t.shape[1] for t in tiles)
rows = (len(tiles) + cols - 1) // cols
sheet = np.ones((rows * (H + 4), cols * (W + 4), 4), np.float32)
for i, t in enumerate(tiles):
    r, c = divmod(i, cols)
    y0 = (rows - 1 - r) * (H + 4); x0 = c * (W + 4)
    sheet[y0:y0 + t.shape[0], x0:x0 + t.shape[1]] = t
o = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0])
o.pixels = sheet.ravel(); o.filepath_raw = out; o.file_format = 'PNG'; o.save()
