"""LASTİK YIĞINI — avlu dekorasyonu (id: tyre_pile).

Gerçek ölçü ~1.15 x 1.05 x 1.15 m. Kodla üretilen "düzgün silindir istifi" yığın gibi
durmuyordu; burada iki eğik kule + yerde yatan birkaç lastik var, hepsi sabit tohumla
(deterministik) dağıtıldı. Birim: 1 = 1 metre. Orijin tabanın ortasında, +Z ön.
"""
import bpy, math, random

NAME = "tyre_pile"
MAJOR, MINOR = 0.235, 0.080          # 16" lastik: dış çap 0.63 m
SEG_MAJOR, SEG_MINOR = 12, 6         # lastik başına 144 üçgen


def make_material(name, rgb, roughness, metallic=0.0):
    """Tek Principled materyal. Node'u ADIYLA aramak güvenilir değil (Blender sürümüne /
    dile göre değişiyor); ilk denemede `nodes.get("Principled BSDF")` None dönmüş ve
    materyal sessizce VARSAYILAN beyaz kalmıştı — o yüzden TİPE göre aranır ve
    bulunamazsa hata verilir."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        raise RuntimeError("Principled BSDF bulunamadi: %s" % [n.type for n in mat.node_tree.nodes])
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    # Dışa aktarımda görünür değer bu: doğrulama için geri oku
    print("materyal %s → albedo %.3f/%.3f/%.3f roughness %.2f" % (
        name, *bsdf.inputs["Base Color"].default_value[:3], bsdf.inputs["Roughness"].default_value))
    return mat


def build():
    col = bpy.data.collections.get("Dekor") or bpy.data.collections.new("Dekor")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    rng = random.Random(20260928)
    parts = []

    def tyre(x, y, z, rx=0.0, ry=0.0, rz=0.0):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=MAJOR, minor_radius=MINOR,
            major_segments=SEG_MAJOR, minor_segments=SEG_MINOR,
            location=(x, y, z), rotation=(rx, ry, rz))
        obj = bpy.context.object
        for c in list(obj.users_collection):
            c.objects.unlink(obj)
        col.objects.link(obj)
        parts.append(obj)
        return obj

    # 1) Ana kule: 4 lastik, hafif kaçık ve her biri farklı açıda dönük
    for i in range(4):
        tyre(rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), 0.082 + i * 0.145,
             rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), rng.uniform(0, math.tau))
    # 2) Yan kule: 3 lastik, ana kuleye yaslanmış
    for i in range(3):
        tyre(0.40 + rng.uniform(-0.02, 0.02), 0.16 + rng.uniform(-0.02, 0.02),
             0.082 + i * 0.145, rng.uniform(-0.05, 0.05), -0.12 + rng.uniform(-0.05, 0.05),
             rng.uniform(0, math.tau))
    # 3) Yerde yatan iki lastik: yığının eteğini doldurur, "dizilmiş" değil "atılmış" görünür
    tyre(-0.30, -0.22, 0.082, 0.0, 0.0, rng.uniform(0, math.tau))
    tyre(0.14, -0.38, 0.082, 0.0, 0.0, rng.uniform(0, math.tau))
    # 4) En tepede yana devrilmiş bir lastik
    tyre(0.10, 0.05, 0.66, math.radians(78.0), 0.0, rng.uniform(0, math.tau))

    # Tek gövdeye birleştir: oyunda tek mesh + tek materyal
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = NAME

    # Materyal: mat siyah kauçuk
    body.data.materials.clear()
    body.data.materials.append(make_material("Lastik", (0.055, 0.058, 0.062), 0.92))

    # ORİJİN: tabanın ortası (y=0 zemine otursun) — oyunda böyle yerleştiriliyor
    bpy.context.view_layer.update()
    lowest = min((body.matrix_world @ v.co).z for v in body.data.vertices)
    bpy.ops.object.mode_set(mode='OBJECT')
    body.data.transform(__import__("mathutils").Matrix.Translation((0.0, 0.0, -lowest)))
    body.location = (0.0, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    dims = body.dimensions
    print("%s: %.2f x %.2f x %.2f m, %d ucgen, %d materyal" % (
        NAME, dims.x, dims.y, dims.z, len(body.data.polygons) * 2, len(body.data.materials)))
    return body


build()
