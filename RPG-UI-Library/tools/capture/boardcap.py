"""Crop the specimen canvas out of a PrintWindow capture of Roblox Studio.

In capture mode the gallery paints everything around the canvas with a pure magenta matte. Scanning the
centre row and column for the first and last non-matte pixel gives the canvas rectangle exactly; Roblox's
own top-bar icons sit on the matte outside it.
usage: boardcap.py <studio_full.png> <out.png> [--trim N]
"""
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
px = im.load()
w, h = im.size


def matte(p):
    return p[0] > 235 and p[1] < 25 and p[2] > 235


ys = [y for y in range(h) if any(matte(px[x, y]) for x in range(0, w, 16))]
xs = [x for x in range(w) if any(matte(px[x, y]) for y in range(ys[0], ys[-1], 16))]
cx, cy = (xs[0] + xs[-1]) // 2, (ys[0] + ys[-1]) // 2
row = [x for x in range(xs[0], xs[-1] + 1) if not matte(px[x, cy])]
col = [y for y in range(ys[0], ys[-1] + 1) if not matte(px[cx, y])]
box = (row[0], col[0], row[-1] + 1, col[-1] + 1)
crop = im.crop(box)
# sanity: no matte pixels may survive inside the crop edge (would mean a clipped canvas)
cw, ch = crop.size
cp = crop.load()
leaks = sum(1 for x in range(cw) for y in (0, ch - 1) if matte(cp[x, y]))
crop.save(out)
print("board", box, crop.size, "edge-matte", leaks)
