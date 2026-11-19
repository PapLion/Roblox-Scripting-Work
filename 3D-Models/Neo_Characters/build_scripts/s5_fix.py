exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
ring = bpy.data.objects["Nix_OrbitRing"]
ring.rotation_euler = (math.radians(30), math.radians(62), math.radians(-10))
ring.location = (-0.05, 0.0, 0.30)
def ramp(mname, bottom, top):
    cr = [n for n in bpy.data.materials[mname].node_tree.nodes if n.type == 'VALTORGB'][0].color_ramp
    cr.elements[0].color = (*bottom, 1); cr.elements[1].color = (*top, 1)
ramp("M_Yoru_HairBlond", (0.86, 0.72, 0.52), (1.0, 0.94, 0.80))
ramp("M_Yoru_Skin", (0.82, 0.70, 0.60), (1.0, 0.96, 0.89))
