# helper executed inside Blender:  exec(open(RUN).read()); build("m_axe")
import bpy, sys, importlib
S = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio/scripts"
if S not in sys.path: sys.path.insert(0, S)
import lib
def build(mod):
    importlib.reload(lib)
    prev = bpy.context.window.scene if bpy.context.window else None
    assets = bpy.data.scenes.get("Assets")
    if bpy.context.window and assets: bpy.context.window.scene = assets
    exec(compile(open(f"{S}/{mod}.py").read(), mod + ".py", "exec"), {"__name__": "__main__"})
    if bpy.context.window and prev: bpy.context.window.scene = prev
