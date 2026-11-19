# v5 lighting: soft violet-blue studio light like the target (geometry carries the look, light only tints it)
import bpy
L = bpy.data.objects
L["LGT_Key"].data.color = (1.0, 0.88, 0.86);   L["LGT_Key"].data.energy = 880      # warm-white key: creams stay creamy
L["LGT_Fill"].data.color = (0.60, 0.52, 1.0);  L["LGT_Fill"].data.energy = 200
L["LGT_Top"].data.color = (0.82, 0.72, 1.0);   L["LGT_Top"].data.energy = 120
L["LGT_RimViolet"].data.color = (0.62, 0.42, 1.0)
bpy.context.scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.015, 0.045, 1.0)
e = bpy.context.scene.eevee
if hasattr(e, "shadow_ray_count"): e.shadow_ray_count = 2
print("lights v5 ok")

# v5 colour management: Standard keeps the pastel creams / lavenders saturated (AgX washed them to grey)
vs = bpy.context.scene.view_settings
vs.view_transform = 'Standard'; vs.look = 'Medium High Contrast'; vs.exposure = -0.85; vs.gamma = 1.0

# soft warm fill from the camera side: lifts the faces that sit under the heavy fringes (no hard shadows)
from mathutils import Vector
ff = bpy.data.objects.get("LGT_FrontFill")
if ff is None:
    ld = bpy.data.lights.new("LGT_FrontFill", 'AREA')
    ff = bpy.data.objects.new("LGT_FrontFill", ld)
    bpy.data.collections["STAGE"].objects.link(ff)
ff.data.color = (1.0, 0.86, 0.90); ff.data.energy = 300; ff.data.size = 7.0
ff.location = (3.3, -11.0, 1.4)
ff.rotation_euler = (Vector((0.0, 0.0, 0.3)) - ff.location).to_track_quat('-Z', 'Y').to_euler()
# a little more bloom so the ring, the X eyes and Akemi's rim glow read like the target
ng = bpy.data.node_groups.get("COMP_Glow")
if ng:
    for nd in ng.nodes:
        if nd.type == 'GLARE' and "Strength" in nd.inputs:
            nd.inputs["Strength"].default_value = 0.85
print("fill + glow ok")
