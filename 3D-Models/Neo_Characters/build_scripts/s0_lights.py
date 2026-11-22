exec(open("/home/dani.pp/Downloads/job/neo_build_scripts/lib.py").read(), globals())
E = {"LGT_Key": 520, "LGT_Fill": 160, "LGT_RimViolet": 900, "LGT_RimCyan": 650, "LGT_Top": 150}
for k, v in E.items(): bpy.data.objects[k].data.energy = v
bpy.data.materials["M_Stage_Backdrop"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.018, 0.015, 0.032, 1)
