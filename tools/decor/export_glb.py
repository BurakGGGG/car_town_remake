"""Dekor koleksiyonundaki aktif gövdeyi assets/decor/<ad>.glb olarak dışa aktarır."""
import bpy, os

OUT_DIR = "/home/burak/Projects/car-town-remake/assets/decor"


def export(name: str) -> None:
    obj = bpy.data.objects.get(name)
    if obj is None:
        print("HATA: '%s' bulunamadi" % name)
        return
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, "%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
    print("yazildi: %s  (%.1f KB)" % (path, os.path.getsize(path) / 1024.0))


export(bpy.context.object.name if bpy.context.object else "")
