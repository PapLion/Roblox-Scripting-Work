"""Grab and stitch a tiled specimen capture from Roblox Studio.

The gallery (bridge command "tiles") renders a specimen at a fixed scale inside a clipped window and walks
a grid of tiles. Above the window's top-right corner it shows six marker squares that encode the current
tile index in binary (62 = moving, 63 = done). This script grabs the Studio window with PrintWindow
(never the desktop), decodes the marker, keeps one settled frame per tile, crops the window and stitches
the tiles into the full canvas.

usage: tiles.py <out.png> <geometry json from the bridge>
"""
from __future__ import annotations

import ctypes
import json
import sys
import time
from ctypes import wintypes

from PIL import Image

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32
user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))


def studio_hwnd() -> int:
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def cb(hwnd, _):
        n = user32.GetWindowTextLengthW(hwnd)
        if n and user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, buf, n + 1)
            if buf.value.endswith("Roblox Studio"):
                found.append(hwnd)
        return True

    user32.EnumWindows(cb, 0)
    if not found:
        sys.exit("Roblox Studio window not found")
    return found[0]


class BITMAPINFOHEADER(ctypes.Structure):
    _fields_ = [("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG), ("biPlanes", wintypes.WORD),
                ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD), ("biSizeImage", wintypes.DWORD),
                ("biXPelsPerMeter", wintypes.LONG), ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD)]


def grab(hwnd: int) -> Image.Image:
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    w, h = r.right, r.bottom
    hdc = user32.GetDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    user32.PrintWindow(hwnd, mem, 3)  # PW_CLIENTONLY | PW_RENDERFULLCONTENT
    bi = BITMAPINFOHEADER()
    bi.biSize, bi.biWidth, bi.biHeight, bi.biPlanes, bi.biBitCount = ctypes.sizeof(BITMAPINFOHEADER), w, -h, 1, 32
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bi), 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(hwnd, hdc)
    return Image.frombuffer("RGB", (w, h), buf, "raw", "BGRX", 0, 1)


def matte(p) -> bool:
    return p[0] > 235 and p[1] < 25 and p[2] > 235


def window_rect(im: Image.Image):
    """Bounding box of the non-matte window, found by scanning its centre row and column."""
    px = im.load()
    w, h = im.size
    ys = [y for y in range(0, h, 2) if matte(px[w // 2, y])]
    if not ys:
        return None
    xs = [x for x in range(0, w, 2) if matte(px[x, h // 2])]
    if not xs:
        return None
    cx = (xs[0] + xs[-1]) // 2
    # vertical: from the matte band above the window down to the bottom matte strip
    col = [y for y in range(ys[0], ys[-1] + 1) if not matte(px[cx, y])]
    cy = (col[0] + col[-1]) // 2
    row = [x for x in range(xs[0], xs[-1] + 1) if not matte(px[x, cy])]
    return row[0], col[0], row[-1] + 1, col[-1] + 1


def read_marker(im: Image.Image, box, ratio: float):
    px = im.load()
    x1, y0 = box[2], box[1]
    bits = 0
    for i in range(6):
        # marker i: 16 logical px square, right edge at 16 + i*24 left of the window's right edge, bottom 16 above the top
        cx = x1 - (16 + i * 24 + 8) * ratio
        cy = y0 - (16 + 8) * ratio
        p = px[int(cx), int(cy)]
        if matte(p):
            return None
        if sum(p) > 380:
            bits |= 1 << i
    return bits


def main():
    out = sys.argv[1]
    g = json.loads(sys.argv[2])
    n = g["cols"] * g["rows"]
    hwnd = studio_hwnd()
    tiles: dict[int, Image.Image] = {}
    last = None
    ratio = None
    box0 = None
    t0 = time.time()
    while time.time() - t0 < 120:
        im = grab(hwnd)
        box = window_rect(im)
        if not box:
            time.sleep(0.1)
            continue
        ratio = (box[2] - box[0]) / g["winW"]
        k = read_marker(im, box, ratio)
        if k == 63 and len(tiles) == n:
            break
        if k is not None and k < n and k == last and k not in tiles:
            tiles[k] = im.crop(box)
            box0 = box
            print(f"tile {k + 1}/{n} {tiles[k].size}", flush=True)
        last = k
        if len(tiles) == n:
            break
        time.sleep(0.12)
    if len(tiles) < n:
        sys.exit(f"timed out with {len(tiles)}/{n} tiles")
    W, H = round(g["w"] * ratio), round(g["h"] * ratio)
    canvas = Image.new("RGB", (W, H))
    i = 0
    for r in range(g["rows"]):
        for c in range(g["cols"]):
            canvas.paste(tiles[i], (round(c * g["stepX"] * ratio), round(r * g["stepY"] * ratio)))
            i += 1
    canvas.save(out)
    print(f"saved {out} {canvas.size} ratio {ratio:.4f} window {box0}")


if __name__ == "__main__":
    main()
