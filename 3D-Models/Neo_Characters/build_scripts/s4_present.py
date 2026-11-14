exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
sc = bpy.context.scene
bpy.data.objects["Nix_Root"].rotation_euler = (math.radians(4), 0, math.radians(28))
bpy.data.objects["Akemi_Root"].rotation_euler = (0, 0, math.radians(-14))
bpy.data.objects["Yoru_Root"].rotation_euler = (0, 0, math.radians(-4))
# bloom-like glow via compositor glare
msg = "no glare"
try:
    if hasattr(sc, "compositing_node_group"):
        ng = bpy.data.node_groups.get("COMP_Glow") or bpy.data.node_groups.new("COMP_Glow", "CompositorNodeTree")
        ng.nodes.clear()
        if not ng.interface.items_tree:
            ng.interface.new_socket("Image", in_out='OUTPUT', socket_type='NodeSocketColor')
        rl = ng.nodes.new("CompositorNodeRLayers")
        gl = ng.nodes.new("CompositorNodeGlare")
        out = ng.nodes.new("NodeGroupOutput")
        for prop, val in (("glare_type", 'BLOOM'),):
            if hasattr(gl, prop): setattr(gl, prop, val)
        for k, v in (("Type", 'Bloom'), ("Threshold", 1.0), ("Strength", 0.6), ("Size", 0.6)):
            if k in gl.inputs:
                try: gl.inputs[k].default_value = v
                except Exception: pass
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
        ng.links.new(gl.outputs["Image"], out.inputs[0])
        sc.compositing_node_group = ng
        sc.render.use_compositing = True
        msg = "glare ok " + str([i.name for i in gl.inputs])
except Exception as e:
    msg = "glare failed: %r" % e
print(msg)
cam = get_cam("CAM_Main")
render_view(SCRATCH + "/neo_final.png", (0.0, -11.5, 1.4), (0.0, 0, 0.25), lens=42, res=(1920, 1080), samples=64, cam="CAM_Main")
print("rendered")
