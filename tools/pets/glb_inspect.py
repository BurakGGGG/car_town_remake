"""GLB İNCELEME: bir hayvan modelini (Meshy çıktısı / iskeletli GLB) içe alır, ölçü + üçgen + materyal raporu basar ve
4 açıdan (ön, yan, 3/4, üst) tek temas sayfası render alır. Kullanıcının canlı Blender'ına dokunmaz (başsız).

  blender -b --factory-startup --python tools/pets/glb_inspect.py -- <model.glb> <çıktı.png> [kare_px]
"""
import bpy, sys, math, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
px = int(argv[2]) if len(argv) > 2 else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=src)

meshes = [o for o in scene.objects if o.type == "MESH"]
tris = 0
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for o in meshes:
    me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
    for v in me.vertices:
        w = o.matrix_world @ v.co
        lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
        hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
size = hi - lo
print("RAPOR nesne=%d üçgen=%d boyut=(%.3f, %.3f, %.3f) alt=%.3f" % (len(meshes), tris, size.x, size.y, size.z, lo.z))
for o in scene.objects:
    print("RAPOR  nesne", o.name, o.type, [m.name for m in getattr(o.data, "materials", [])] if o.type == "MESH" else "")
for a in bpy.data.actions:
    print("RAPOR  eylem", a.name, a.frame_range[:])
for img in bpy.data.images:
    print("RAPOR  doku", img.name, tuple(img.size))

center = (lo + hi) / 2
radius = max(size.x, size.y, size.z)

# Işık + dünya
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.62, 0.63, 0.66, 1)
bg.inputs[1].default_value = 0.8
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(35))
scene.collection.objects.link(sun)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = radius * 1.25
scene.collection.objects.link(cam)
scene.camera = cam
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    pass
scene.render.resolution_x = px
scene.render.resolution_y = px
scene.view_settings.view_transform = "Standard"

views = {
    "on": Vector((0, -1, 0.15)),
    "yan": Vector((1, 0, 0.15)),
    "uc_ceyrek": Vector((0.8, -0.8, 0.55)),
    "ust": Vector((0.001, -0.001, 1)),
}
shots = []
base, _ = os.path.splitext(out)
for name, d in views.items():
    d = d.normalized()
    cam.location = center + d * radius * 4
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    path = "%s_%s.png" % (base, name)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    shots.append(path)

# Temas sayfası (2x2) — Blender'ın kendi görüntü API'siyle, PIL gerektirmez
sheet = bpy.data.images.new("sheet", px * 2, px * 2)
import numpy as np
buf = np.zeros((px * 2, px * 2, 4), dtype=np.float32)
for i, p in enumerate(shots):
    im = bpy.data.images.load(p)
    a = np.array(im.pixels[:], dtype=np.float32).reshape(px, px, 4)
    r, c = 1 - i // 2, i % 2
    buf[r * px:(r + 1) * px, c * px:(c + 1) * px] = a
    os.remove(p)
sheet.pixels = buf.ravel()
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("RAPOR temas sayfası", out)
