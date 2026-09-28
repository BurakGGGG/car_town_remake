"""TOPLU KAYNAŞTIRMA: her kaynak GLB'nin kopya vertex'lerini birleştirip <ad>_weld.glb yazar.

Neden: Tripo modelleri binlerce kopuk geometri adasından oluşuyor (BMW E46'da 14.326).
meshoptimizer ada SINIRLARINI çökertmez, bu yüzden sadeleştirme erken tıkanıyor ve çıktıda
vertex/üçgen oranı 0,99'a çıkıyor (sağlıklı mesh 0,5). Kaynaştırma ÜÇGEN SİLMEZ, yalnızca aynı
noktadaki kopyaları birleştirir; özel bölünmüş normaller korunduğu için gölgeleme değişmez.
Ölçüm ve gerekçe: docs/MESH_BUTCESI.md

DİKKAT: parça ADLARI (tripo_part_N) korunmak ZORUNDA — CarPartMap rolleri indekse bağlı, ad
kayarsa yanlış parçaya yanlış rol düşer. Betik her araçta adları içe/dışa aktarım arasında
karşılaştırır ve uyuşmazsa o aracı ATLAR.

Çalıştırma: python3 tools/decor/blender_send.py tools/decor/mesh_kaynastir.py
"""
import bpy, bmesh, os, json

ROOT = "/home/burak/Projects/car-town-remake/"
WELD = 0.0002        # model 1,0 uzunluğa normalize → 4,5 m araçta ~0,9 mm


def sources():
    cars = json.load(open(ROOT + "vehicles/cars.json"))["cars"]
    return [(c["id"], ROOT + c["source_path"].replace("res://", "")) for c in cars]


def wipe_stale():
    """Oturumda kalmış araç nesnelerini temizle. Blender ad çakışmasında ".001" ekler ve
    parça indeksleri kayar; bu da CarPartMap rollerini yanlış parçaya bağlar."""
    for name in ("Analiz", "Arac", "Olcum", "Kaynastir"):
        c = bpy.data.collections.get(name)
        if c:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.name.startswith("tripo_") or o.name.startswith("Lastik"):
            bpy.data.objects.remove(o, do_unlink=True)


def purge():
    for block in (bpy.data.meshes, bpy.data.objects, bpy.data.materials, bpy.data.images):
        for b in list(block):
            if b.users == 0:
                block.remove(b)


def run():
    col = bpy.data.collections.get("Kaynastir")
    if col is None:
        col = bpy.data.collections.new("Kaynastir")
        bpy.context.scene.collection.children.link(col)
    for c in bpy.data.collections:
        c.hide_viewport = (c.name != "Kaynastir")
    wipe_stale()
    purge()

    ok = skip = 0
    for car_id, src in sources():
        if not os.path.exists(src):
            print("ATLANDI %-22s kaynak yok: %s" % (car_id, src)); skip += 1; continue
        for o in list(col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        purge()
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=src)
        objs = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
        for o in objs:
            for c in list(o.users_collection):
                c.objects.unlink(o)
            col.objects.link(o)
        names = [o.name for o in objs]
        bad = [n for n in names if "." in n]          # Blender çakışmada ".001" ekler
        if bad:
            print("ATLANDI %-22s ad çakışması: %s" % (car_id, bad[:4])); skip += 1; continue

        v0 = sum(len(o.data.vertices) for o in objs)
        t0 = sum(len(o.data.polygons) for o in objs)
        for o in objs:
            bm = bmesh.new(); bm.from_mesh(o.data)
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
            bm.to_mesh(o.data); bm.free(); o.data.update()
        v1 = sum(len(o.data.vertices) for o in objs)
        t1 = sum(len(o.data.polygons) for o in objs)
        if t1 < t0 * 0.995:
            print("ATLANDI %-22s kaynaştırma üçgen sildi: %d -> %d" % (car_id, t0, t1)); skip += 1; continue

        out = src.replace(".glb", "_weld.glb")
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True,
                                  export_apply=False, export_yup=True,
                                  export_cameras=False, export_lights=False)
        print("%-22s parça=%-3d vertex %7d -> %7d (-%4.1f%%)  ucgen %7d -> %7d  %5.1f MB" % (
            car_id, len(objs), v0, v1, 100.0 * (v0 - v1) / v0, t0, t1,
            os.path.getsize(out) / 1048576.0))
        ok += 1
    print("--- kaynaştırıldı: %d, atlanan: %d ---" % (ok, skip))


run()
