"""Copy the built atlases into Roblox Studio's content folder so rbxasset://textures/vellum/... resolves
locally (development and capture without uploading anything). Run after build_atlas.py.
Studio updates replace the versioned folder; run again after an update.
"""
import os
import shutil
from pathlib import Path

OUT = Path(__file__).resolve().parent / "out" / "local"
versions = Path(os.environ["LOCALAPPDATA"]) / "Roblox" / "Versions"
targets = [v / "content" / "textures" / "vellum" for v in versions.iterdir() if (v / "RobloxStudioBeta.exe").exists()]
for t in targets:
    t.mkdir(parents=True, exist_ok=True)
    for old in t.glob("vellum_*.png"):
        old.unlink()
    for png in OUT.glob("vellum_*.png"):
        shutil.copy2(png, t / png.name)
    print("installed", len(list(OUT.glob("vellum_*.png"))), "files ->", t)
