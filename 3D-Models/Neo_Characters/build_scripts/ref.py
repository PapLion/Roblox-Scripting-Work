import bpy
img = bpy.data.images.load("/home/dani.pp/Downloads/job/Neo-Akem-YOru-Nix.png", check_existing=True)
img.name = "REF_Neo_Concept"
col = bpy.data.collections.get("REFERENCE") or bpy.data.collections.new("REFERENCE")
if col.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(col)
ob = bpy.data.objects.get("REF_ConceptSheet")
if ob is None:
    ob = bpy.data.objects.new("REF_ConceptSheet", None)
    col.objects.link(ob)
ob.empty_display_type = 'IMAGE'
ob.data = img
ob.empty_display_size = 10.0          # width in scene units
ob.location = (0.0, 3.6, 1.2)         # behind the characters, in front of the backdrop wall
ob.rotation_euler = (1.5708, 0, 0)    # stand upright facing -Y (the front camera)
ob.empty_image_depth = 'DEFAULT'
ob.show_empty_image_perspective = True
ob.show_empty_image_orthographic = True
ob.show_empty_image_only_axis_aligned = False
ob.use_empty_image_alpha = True
ob.color[3] = 0.9
ob.hide_render = True
col.hide_render = True
print("ref ok", img.size[:])
