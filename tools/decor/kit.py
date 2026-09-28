"""Dekor üretim kiti — Blender oturumuna gönderilir, sonraki script'ler bu fonksiyonları kullanır.

Kurallar: 1 Blender birimi = 1 METRE · +Z ön · +Y yukarı (Blender'da +Z yukarı, dışa aktarımda
yup çevrimi yapılır) · orijin tabanın ortası · tek materyal tercih edilir · 300-1500 üçgen.
Tüm fonksiyonlar `bpy` üzerinden çalışır ve nesneleri "Dekor" koleksiyonuna koyar.
"""
import bpy, math, random, os
import mathutils

OUT_DIR = "/home/burak/Projects/car-town-remake/assets/decor"
_MATS = {}


def col():
    c = bpy.data.collections.get("Dekor")
    if c is None:
        c = bpy.data.collections.new("Dekor")
        bpy.context.scene.collection.children.link(c)
    return c


def clear():
    for o in list(col().objects):
        bpy.data.objects.remove(o, do_unlink=True)


def mat(name, rgb, rough=0.8, metal=0.0, emit=None, alpha=1.0):
    """Tek Principled materyal. Düğüm TİPE göre aranır (ada göre arama Blender 5.2'de None
    dönüyor ve model sessizce beyaz kalıyordu)."""
    key = (name, tuple(rgb), rough, metal, emit, alpha)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None:
        raise RuntimeError("Principled BSDF yok")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], alpha)
    b.inputs["Roughness"].default_value = rough
    if "Metallic" in b.inputs:
        b.inputs["Metallic"].default_value = metal
    if emit and "Emission Color" in b.inputs:
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        if "Emission Strength" in b.inputs:
            b.inputs["Emission Strength"].default_value = 2.0
    if alpha < 1.0:
        # GLTF'e alphaMode=BLEND yazılması için: hem Alpha girdisi hem blend_method gerekli.
        # Sadece Base Color'un alfası yeterli değil — cam OPAK çıkıyor (kupa vitrininde
        # kupalar görünmüyordu).
        if "Alpha" in b.inputs:
            b.inputs["Alpha"].default_value = alpha
        try:
            m.blend_method = 'BLEND'
        except Exception:
            pass
    _MATS[key] = m
    return m


def _place(obj, material):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col().objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


def box(size, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _place(o, material)


def cyl(r, h, loc, material, rot=(0, 0, 0), seg=10):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=seg, location=loc, rotation=rot)
    return _place(bpy.context.object, material)


def cone(r1, r2, h, loc, material, rot=(0, 0, 0), seg=10):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=h, vertices=seg,
                                    location=loc, rotation=rot)
    return _place(bpy.context.object, material)


def ball(r, loc, material, scale=(1, 1, 1), seg=10, ring=6):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=ring, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _place(o, material)


def torus(major, minor, loc, material, rot=(0, 0, 0), seg=12, mseg=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=seg, minor_segments=mseg,
                                     location=loc, rotation=rot)
    return _place(bpy.context.object, material)


def finish(name, export=True):
    """Koleksiyondaki her şeyi tek gövdeye birleştirir, orijini tabana alır, .glb yazar."""
    objs = list(col().objects)
    if not objs:
        raise RuntimeError("bos koleksiyon: %s" % name)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    body = bpy.context.object
    body.name = name
    bpy.context.view_layer.update()
    low = min((body.matrix_world @ v.co).z for v in body.data.vertices)
    body.data.transform(mathutils.Matrix.Translation((0.0, 0.0, -low)))
    body.location = (0.0, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    d = body.dimensions
    tris = len(body.data.polygons) * 2
    if export:
        os.makedirs(OUT_DIR, exist_ok=True)
        path = os.path.join(OUT_DIR, "%s.glb" % name)
        bpy.ops.object.select_all(action='DESELECT')
        body.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                                  export_apply=True, export_yup=True,
                                  export_cameras=False, export_lights=False)
    print("  %-18s %.2f x %.2f x %.2f m  %5d ucgen  %d materyal" % (
        name, d.x, d.y, d.z, tris, len(body.data.materials)))
    return body


print("kit yuklendi")
