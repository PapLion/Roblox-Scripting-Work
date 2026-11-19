"""blender -b file.blend -P bg_preview.py -- out.png px cols frames..."""
import sys
a = sys.argv[sys.argv.index("--") + 1:]
PREVIEW_OUT, PREVIEW_PX, PREVIEW_COLS = a[0], int(a[1]), int(a[2])
PREVIEW_FRAMES = [int(x) for x in a[3:]]
exec(open("/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/scripts/preview.py").read())
