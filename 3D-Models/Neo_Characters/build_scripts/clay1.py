# big neutral clay view of one character (CH), front (and optional yaw), to judge pure form
S_ = "/home/dani.pp/Downloads/job/neo_build_scripts/"
for f_ in ("lib.py", "lib2.py"):
    exec(open(S_ + f_).read(), globals())
CF = {"Nix": (4.6, (-0.20, 0.30), (520, 520)), "Yoru": (3.47 * 0.85, (-0.01, 0.20), (900, 900)), "Akemi": (2.9, (0.0, 0.05), (700, 700))}
W, off, res = CF[CH]
root = bpy.data.objects[CH + "_Root"]
sc = bpy.context.scene; vl = bpy.context.view_layer
clay = bpy.data.materials.get("M_Clay") or mat("M_Clay", (0.62, 0.62, 0.64), rough=0.55)
saved_l = {o.name: (tuple(o.data.color), o.data.energy) for o in bpy.data.objects if o.type == 'LIGHT'}
bg = sc.world.node_tree.nodes["Background"]; saved_w = tuple(bg.inputs[0].default_value)
for o in bpy.data.objects:
    if o.type == 'LIGHT':
        o.data.color = (1, 1, 1)
        if "Rim" in o.name: o.data.energy *= 0.5
bg.inputs[0].default_value = (0.05, 0.05, 0.055, 1)
if not ("COLOR" in globals() and COLOR):
    vl.material_override = clay
try:
    yaws = YAWS if "YAWS" in globals() else (0,)
    paths = []
    for yw in yaws:
        ctr = root.location + Vector((off[0] * math.cos(math.radians(yw)), 0, off[1]))
        d = W * 110.0 / 36.0; a = math.radians(yw)
        loc = ctr + Vector((math.sin(a) * d, -math.cos(a) * d, 0))
        p = f"{SCRATCH}/clay1_{CH}_{yw}.png"
        bd = bpy.data.objects.get("STAGE_Backdrop")
        if bd: bd.hide_render = abs(yw) > 60
        render_view(p, loc, ctr, lens=110, res=res, only=[CH], samples=24)
        if bd: bd.hide_render = False
        paths.append(p)
    contact_sheet([paths], f"{SCRATCH}/clay1_{CH}.png")
finally:
    vl.material_override = None
    for n_, (c_, e_) in saved_l.items():
        bpy.data.objects[n_].data.color = c_; bpy.data.objects[n_].data.energy = e_
    bg.inputs[0].default_value = saved_w
print("clay1 ok")
