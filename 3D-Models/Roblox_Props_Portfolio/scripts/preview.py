"""Low-res preview contact sheet of selected frames (run inside Blender).
PREVIEW_FRAMES / PREVIEW_OUT / PREVIEW_PX must be defined by the caller."""
import bpy, numpy as np, os
sc = bpy.data.scenes["Showcase"]
r = sc.render
old = (r.resolution_x, r.resolution_y, r.resolution_percentage, sc.eevee.taa_render_samples, r.filepath)
tiles = []
tmp = os.path.join(os.path.dirname(PREVIEW_OUT), "_tile.png")
for f in PREVIEW_FRAMES:
    sc.frame_set(f)
    cam = next((m.camera for m in sc.timeline_markers if m.frame == f), None)
    sc.camera = cam
    if f in (1, 2, 100, 101, 370):
        r.resolution_x, r.resolution_y = int(PREVIEW_PX * 1.5), PREVIEW_PX
    else:
        r.resolution_x = r.resolution_y = PREVIEW_PX
    r.resolution_percentage = 100
    sc.eevee.taa_render_samples = 12
    r.filepath = tmp
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(tmp, check_existing=False)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    tiles.append(a)
H = max(t.shape[0] for t in tiles); W = max(t.shape[1] for t in tiles)
cols = min(len(tiles), PREVIEW_COLS)
rows = (len(tiles) + cols - 1) // cols
sheet = np.ones((rows * (H + 6), cols * (W + 6), 4), dtype=np.float32)
for i, t in enumerate(tiles):
    rr, cc = divmod(i, cols)
    y0 = (rows - 1 - rr) * (H + 6); x0 = cc * (W + 6)
    sheet[y0:y0 + t.shape[0], x0:x0 + t.shape[1]] = t
out = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0], alpha=True)
out.pixels = sheet.ravel()
out.filepath_raw = PREVIEW_OUT
out.file_format = 'PNG'
out.save()
bpy.data.images.remove(out)
r.resolution_x, r.resolution_y, r.resolution_percentage, sc.eevee.taa_render_samples, r.filepath = old
print("sheet", PREVIEW_OUT)
