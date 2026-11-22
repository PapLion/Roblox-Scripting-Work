"""blender -b --factory-startup -P verify_fbx.py
Re-imports every exported FBX into an empty scene and compares with the manifest."""
import bpy, json
ROOT = "/home/dani.pp/Downloads/job/Roblox_Props_Portfolio"
man = json.load(open(f"{ROOT}/export/export_manifest.json"))
lines = []
ok_all = True
for name, info in man["assets"].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=info["file"])
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    pts = [o.matrix_world @ v.co for o in obs for v in o.data.vertices]
    mn = [min(p[i] for p in pts) for i in range(3)]; mx = [max(p[i] for p in pts) for i in range(3)]
    size = [mx[i] - mn[i] for i in range(3)]
    tris = sum(len(p.vertices) - 2 for o in obs for p in o.data.polygons)
    mats = sorted({s.material.name for o in obs for s in o.material_slots if s.material})
    names = sorted(o.name for o in obs)
    colors = {}
    for o in obs:
        m = o.material_slots[0].material
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.node_tree else None
        if b:
            colors[m.name] = tuple(round(c, 3) for c in b.inputs['Base Color'].default_value[:3])
    d_size = max(abs(a - b) for a, b in zip(sorted(size), sorted(info["size_m"])))
    multi = [o.name for o in obs if len(o.material_slots) != 1]
    nonuv = [o.name for o in obs if not o.data.uv_layers]
    arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    bones = len(arms[0].data.bones) if arms else 0
    ok = (tris == info["tris"] and d_size < 0.002 and names == info["parts"] and mats == info["materials"]
          and not multi and not nonuv and bones == info.get("bones", 0))
    ok_all &= ok
    lines.append(f"{'OK  ' if ok else 'FAIL'} {name:14s} tris {tris:5d}/{info['tris']:5d}  size(m) "
                 f"{' x '.join(f'{v:.3f}' for v in size)}  parts {len(obs):2d}  mats {len(mats)}  "
                 f"uv {'yes' if not nonuv else 'NO'}  1-mat/part {'yes' if not multi else 'NO'}"
                 + (f"  bones {bones}" if bones else ""))
open(f"{ROOT}/export/verify_report.txt", "w").write("\n".join(lines) + f"\nALL_OK={ok_all}\n")
print("\n".join(lines)); print("ALL_OK", ok_all)
