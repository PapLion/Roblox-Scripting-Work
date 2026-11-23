"""Grab a whole capture batch from Roblox Studio in one run.

The gallery's bridge command "batch" returns every job's geometry (saved to a JSON file and passed here)
and then walks the jobs: the upper marker row encodes the job index, the lower row the tile index
(62 = moving, 63 = job done). Each finished job is stitched and saved as <out_dir>/<id>.png.

usage: batch.py <geometry.json> <out_dir>
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from tiles import grab, matte, studio_hwnd, window_rect  # noqa: E402


def read_row(im, box, ratio, row: int):
    px = im.load()
    bits = 0
    for i in range(6):
        cx = box[2] - (16 + i * 24 + 8) * ratio
        cy = box[1] - (16 + 8 + row * 24) * ratio
        p = px[int(cx), int(cy)]
        if matte(p):
            return None
        if sum(p) > 380:
            bits |= 1 << i
    return bits


def main():
    geo = json.loads(Path(sys.argv[1]).read_text())
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    hwnd = studio_hwnd()
    tiles: dict[int, dict[int, Image.Image]] = {}
    saved = set()
    last = None
    t0 = time.time()
    while len(saved) < len(geo) and time.time() - t0 < 900:
        im = grab(hwnd)
        box = window_rect(im)
        if not box:
            time.sleep(0.1)
            continue
        g0 = geo[0]
        ratio = (box[2] - box[0]) / g0["winW"]
        k = read_row(im, box, ratio, 0)
        j = read_row(im, box, ratio, 1)
        if k is None or j is None or j >= len(geo):
            time.sleep(0.1)
            continue
        g = geo[j]
        n = g["cols"] * g["rows"]
        got = tiles.setdefault(j, {})
        if k < n and (j, k) == last and k not in got:
            got[k] = im.crop(box)
        last = (j, k)
        if len(got) == n and j not in saved:
            W, H = round(g["w"] * ratio), round(g["h"] * ratio)
            canvas = Image.new("RGB", (W, H))
            i = 0
            for r in range(g["rows"]):
                for c in range(g["cols"]):
                    canvas.paste(got[i], (round(c * g["stepX"] * ratio), round(r * g["stepY"] * ratio)))
                    i += 1
            path = out / f"{g['id']}.png"
            canvas.save(path)
            saved.add(j)
            print(f"[{len(saved)}/{len(geo)}] {g['id']} {canvas.size} from {n} tiles", flush=True)
        time.sleep(0.1)
    missing = [g["id"] for i, g in enumerate(geo) if i not in saved]
    if missing:
        sys.exit(f"missing: {missing}")


if __name__ == "__main__":
    main()
