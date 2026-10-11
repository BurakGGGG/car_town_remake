"""RESTORASYON ŞASİSİ → OYUN: garajdaki projenin 1. aşaması (%0–33 çıplak demir şasi) ve 2. aşamada aracın
altında görünen şasi. Model junk_kit.chassis() (merdiven şasi, akslar, motor, şanzıman, egzoz...).

Kullanım (ekransız):
    blender -b --factory-startup --python tools/world/export_chassis.py

Çıktı: assets/world/restoration_chassis.glb — ön +Z (oyundaki araç sahneleriyle aynı), gerçek metre
(uzunluk ~4,2 m; oyun aracın kutusuna göre ölçekler). Köşe rengi "Col" = ALBEDO, sRGB KODLU: Godot GL
Compatibility köşe rengini her zaman sRGB sayıyor (bkz. export_junkyard.py encode_srgb). Şehirde ışık
pişmez (garaj gerçek ışıkla aydınlanır): materyal Godot'ta gölgeli kurulur.
"""
import bpy, math, os
import numpy as np

PROJECT = "/home/burak/Projects/car-town-remake"
OUT = os.path.join(PROJECT, "assets/world/restoration_chassis.glb")

exec(open(os.path.join(PROJECT, "tools/world/junk_kit.py"), encoding="utf-8").read())

scn = bpy.context.scene
for o in list(scn.objects):
    bpy.data.objects.remove(o, do_unlink=True)
col = scn.collection
o = chassis(col, "RestorationChassis", loc=(0, 0, 0), rot=(0, 0, -90), wheels=False, rust=1.0, seed=3)
bpy.context.view_layer.update()
# Dönüşü mesh'e işle (ön +X → -Y = glTF +Z)
from mathutils import Matrix
o.data.transform(Matrix.Rotation(math.radians(-90), 4, 'Z'))
o.rotation_euler = (0, 0, 0)
attr = o.data.color_attributes["Col"]
arr = np.empty(len(attr.data) * 4, dtype=np.float32)
attr.data.foreach_get("color", arr)
arr = arr.reshape(-1, 4)
lin = np.clip(arr[:, :3], 0.0, 1.0)
arr[:, :3] = np.where(lin > 0.0031308, 1.055 * np.power(lin, 1 / 2.4) - 0.055, lin * 12.92)
arr[:, 3] = 1.0
attr.data.foreach_set("color", arr.reshape(-1))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, use_active_scene=True,
                          export_vertex_color='NAME', export_vertex_color_name="Col", export_all_vertex_colors=False,
                          export_image_format='NONE', export_yup=True)
tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
xs = [v.co.x for v in o.data.vertices]
ys = [v.co.y for v in o.data.vertices]
print("ŞASİ", OUT, tris, "üçgen, boy %.2f m, en %.2f m" % (max(ys) - min(ys), max(xs) - min(xs)))
