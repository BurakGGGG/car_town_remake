"""ARAÇ MESH ANALİZİ: kaynakta ne kadar fazlalık var?

Ölçülenler, parça parça:
  - kopuk geometri adası sayısı (mesh ne kadar parçalanmış)
  - mesafeye göre kaynaşan vertex oranı (aynı noktada duran kopyalar)
  - düzlemsel sadeleştirmenin (Decimate/PLANAR) kaldırdığı üçgen oranı — "kapı zaten düz"
Çalıştırma: python3 tools/decor/blender_send.py tools/decor/mesh_analiz.py
"""
import bpy, bmesh

SRC = "/home/burak/Projects/car-town-remake/assets/cars/source/bmw_e46.glb"
WELD = 0.0002        # model 1,0 uzunluğa normalize → 4,5 m araçta ~0,9 mm
PLANAR_DEG = 5.0     # bu açıdan düz sayılan komşu yüzler birleşir


def islands(me):
    bm = bmesh.new(); bm.from_mesh(me)
    seen, n = set(), 0
    for v in bm.verts:
        if v.index in seen:
            continue
        n += 1; stack = [v]; seen.add(v.index)
        while stack:
            c = stack.pop()
            for e in c.link_edges:
                o = e.other_vert(c)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
    bm.free(); return n


def run():
    col = bpy.data.collections.get("Analiz")
    if col is None:
        col = bpy.data.collections.new("Analiz"); bpy.context.scene.collection.children.link(col)
    for o in list(col.objects): bpy.data.objects.remove(o, do_unlink=True)
    for c in bpy.data.collections:
        c.hide_viewport = (c.name != "Analiz")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SRC)
    objs = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    for o in objs:
        for c in list(o.users_collection): c.objects.unlink(o)
        col.objects.link(o)

    t0 = v0 = t1 = v1 = t2 = isl = 0
    for o in objs:
        me = o.data
        t0 += len(me.polygons); v0 += len(me.vertices)
        isl += islands(me)
        # kaynaştır
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD)
        bm.to_mesh(me); bm.free(); me.update()
        t1 += len(me.polygons); v1 += len(me.vertices)
    # kaynaşmış hâlde düzlemsel sadeleştirme
    for o in objs:
        m = o.modifiers.new("Duz", 'DECIMATE')
        m.decimate_type = 'DISSOLVE'; m.angle_limit = PLANAR_DEG * 3.14159265 / 180.0
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
        t2 += sum(len(p.vertices) - 2 for p in o.data.polygons)   # ngon → üçgen karşılığı

    print("parça=%d  kopuk ada=%d" % (len(objs), isl))
    print("ham        : %8d ucgen %8d vertex  (v/u=%.2f)" % (t0, v0, v0 / max(t0, 1)))
    print("kaynastir  : %8d ucgen %8d vertex  (v/u=%.2f)  vertex -%.1f%%" % (
        t1, v1, v1 / max(t1, 1), 100.0 * (v0 - v1) / max(v0, 1)))
    print("+duzlemsel : %8d ucgen  -> ucgen -%.1f%% (ham'a gore)" % (t2, 100.0 * (t0 - t2) / max(t0, 1)))


run()
