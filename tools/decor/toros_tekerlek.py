"""TOROS TEKERLEK AMELİYATI.

Sorun: kaynak (renault_r12.glb) TEK mesh ve 6.887 kopuk parçadan oluşuyor; tekerler ayrı
geometri adası değil. Pipeline bu yüzden tekerleri SİLİNDİRLE kesiyordu — yarıçap küçükse
lastiğin tabanı gövdede kalıyor (dönmeyen hilal), büyükse çamurluğu kesip siyah kama bırakıyordu.

Çözüm: kaynaktaki teker bölgesini TAMAMEN sil, yerine temiz geometriyle teker üret. Tekerler
ayrı nesne olarak çıktığı için pipeline'ın `extract` adımına da gerek kalmıyor; adlandırma
`tripo_part_0..4` olduğu için mevcut CarPartMap kaydı aynen çalışır.

Çıktı GLB'si `assets/cars/source/` altında ve o klasör .gitignore'da; araç git'ten sonra bu
betikle yeniden üretilir. Kaynak `renault_r12.glb` DEĞİŞTİRİLMEZ.

Pipeline'ın devamı (sırayla):
  godot-4 --headless --path . -s res://tools/optimize_car.gd -- \
    --in res://assets/cars/source/renault_toros_wheels.glb \
    --out res://assets/cars/optimized/renault_toros.glb \
    --ratio 0.08 --min-tris 300 --rename --map res://assets/cars/renault_toros.tscn
  sed -i 's|^compress/mode=0|compress/mode=2|' \
    assets/cars/optimized/renault_toros_car_albedo_albedo.jpg.import   # başsız import atlıyor
  godot-4 --headless --path . --import
  godot-4 --headless --path . -s res://tools/make_car_scene.gd -- renault_toros
  godot-4 --headless --path . -s res://tools/make_paint_mask.gd -- --car renault_toros

Çalıştırma:  python3 tools/decor/blender_send.py tools/decor/toros_tekerlek.py
"""
import bpy, bmesh, math, os

SRC = "/home/burak/Projects/car-town-remake/assets/cars/source/renault_r12.glb"
OUT = "/home/burak/Projects/car-town-remake/assets/cars/source/renault_toros_wheels.glb"
# Blender Z-yukarı. DİKKAT: CarPartMap'teki akslar ölçümle YANLIŞ çıktı (x ±0.206, z 0.103);
# gerçek değerler ortografik siluetten ve temas yamasından ölçüldü:
#   merkez x ±0.1880 (harita 18 mm dışarıda)   → kesici silindir çamurluğu yiyordu
#   merkez z  0.0735 (harita 29 mm yukarıda)   → lastiğin tabanı gövdede kalıyordu
#   yarıçap   0.0735 (harita ~0.103, %40 iri)
#   genişlik  0.0534, çamurluk dış yüzeyi |x|=0.2225
TYRE_R, TYRE_W = 0.0735, 0.054
INNER_R = 0.050                        # lastiğin iç çapı: jant tablası buradan görünür
WX, FRONT_Y, REAR_Y = 0.1880, -0.3125, 0.2685
AXLES = [(-WX, FRONT_Y, TYRE_R), (WX, FRONT_Y, TYRE_R),
         (-WX, REAR_Y, TYRE_R), (WX, REAR_Y, TYRE_R)]
CUT_R, CUT_HALF_W = 0.078, 0.032       # lastiğin 4,5 mm ötesi; çamurluk dudağı (|x|>0.220) korunur


def clean_scene():
    col = bpy.data.collections.get("Arac")
    if col is None:
        col = bpy.data.collections.new("Arac")
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    d = bpy.data.collections.get("Dekor")
    if d:
        d.hide_viewport = True
    return col


def wheel_materials():
    """Tekerin KENDİ materyalleri. optimize_car.gd dokusuz materyalleri koruduğu için
    (bkz. `_surface_material`) bu renkler oyuna aynen geçer; atlasta teker texel'i aramaya
    gerek yok. Değerler Blender'ın doğrusal uzayında: 0,035 ≈ sRGB 53/255 (gerçek lastik
    siyahı, mutlak siyah değil), 0,32 ≈ sRGB 152/255 — bu, aracın kendi dokusundan ölçülen
    jant kapağı grisidir.
    """
    rubber = bpy.data.materials.new("TorosLastik")
    rubber.use_nodes = True
    b1 = next(n for n in rubber.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b1.inputs["Base Color"].default_value = (0.035, 0.036, 0.040, 1.0)
    b1.inputs["Roughness"].default_value = 0.93
    if "Metallic" in b1.inputs:
        b1.inputs["Metallic"].default_value = 0.0
    rim = bpy.data.materials.new("TorosJant")
    rim.use_nodes = True
    b2 = next(n for n in rim.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b2.inputs["Base Color"].default_value = (0.32, 0.325, 0.335, 1.0)
    b2.inputs["Roughness"].default_value = 0.38
    if "Metallic" in b2.inputs:
        b2.inputs["Metallic"].default_value = 0.55
    return rubber, rim


def clean_scene():
    col = bpy.data.collections.get("Arac")
    if col is None:
        col = bpy.data.collections.new("Arac")
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    d = bpy.data.collections.get("Dekor")
    if d:
        d.hide_viewport = True
    return col


def uv_samples(body, axles):
    """Silinecek lastiğin (pozisyon, UV) örneklerini toplar.

    Neden en-yakın-komşu aktarımı: optimize_car.gd çıkışta tüm yüzeylere TEK gövde materyalini
    verir, yani teker rengi yalnızca UV'den gelir. İki yaklaşım denendi ve elendi —
      (1) bütün tekeri tek siyah texel'e nişanlamak: mipmap onu yuttu (9x9 komşu ortalaması
          2 → 93), lastik oyunda açık gri çıktı;
      (2) atlasın boş hücresine düz renk blok basmak: blok dışa aktarımda beklenen yere
          oturmadı, doğrulanamadı.
    Bu yüzden UV, ORİJİNAL lastiğin kendi UV adasından taşınıyor: adanın tamamına yayıldığı
    için her mip seviyesinde doğru renk gelir ve doku düzenine hiç dokunulmaz.
    """
    me = body.data
    uvl = me.uv_layers.active
    if uvl is None:
        raise RuntimeError("gövde mesh'inde UV yok")
    co = me.vertices
    tread_p, tread_t, hub_p, hub_t = [], [], [], []
    for loop in me.loops:
        v = co[loop.vertex_index].co
        for ax, ay, az in axles:
            if abs(v.x - ax) > CUT_HALF_W:
                continue
            r = math.hypot(v.y - ay, v.z - az)
            # aks merkezine göre YEREL koordinat: dört tekerin örnekleri ortak havuzda birleşir
            local = (v.x - ax if ax > 0 else ax - v.x, v.y - ay, v.z - az)
            if 0.050 <= r <= CUT_R:
                tread_p.append(local)
                tread_t.append(tuple(uvl.data[loop.index].uv))
                break
            if r <= 0.032:
                hub_p.append(local)
                hub_t.append(tuple(uvl.data[loop.index].uv))
                break
    def pack(pos, uv, cap=40000):
        arr_p = np.asarray(pos, dtype=np.float32)
        arr_u = np.asarray(uv, dtype=np.float32)
        if len(arr_p) > cap:                      # seyreltme: eşit aralıklı örnekleme
            idx = np.linspace(0, len(arr_p) - 1, cap).astype(np.int32)
            arr_p, arr_u = arr_p[idx], arr_u[idx]
        return arr_p, arr_u
    tp, tu = pack(tread_p, tread_t)
    hp, hu = pack(hub_p, hub_t)
    print("UV örnekleri: lastik %d (seyreltilmiş %d) | göbek %d (seyreltilmiş %d)" % (
        len(tread_p), len(tp), len(hub_p), len(hp)))
    if len(tp) == 0 or len(hp) == 0:
        raise RuntimeError("UV örneği toplanamadı")
    return (tp, tu), (hp, hu)


def transfer_uv(obj, axle, slot_samples):
    """Her yüzün materyal yuvasına göre, o yuvanın örnek havuzundan EN YAKIN komşunun UV'si."""
    me = obj.data
    # DİKKAT: birleştirilen silindir primitifleri kendi UV katmanlarını getiriyor ve glTF
    # dışa aktarımı AKTİF katmanı değil İLK katmanı TEXCOORD_0 olarak yazıyor. Bu yüzden
    # önce bütün katmanlar silinip tek katman kuruluyor — yoksa lastiğin UV'si sıfır kalıyor
    # (ölçüldü: oyunda teker UV'si (0,1) köşesine düşüyor, lastik açık gri çıkıyordu).
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uvl = me.uv_layers.new(name="UVMap")
    uvl.active = True
    uvl.active_render = True
    ax, ay, az = axle
    vs = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", vs)
    vs = vs.reshape(-1, 3)
    local = np.stack([(vs[:, 0] - ax) if ax > 0 else (ax - vs[:, 0]),
                      vs[:, 1] - ay, vs[:, 2] - az], axis=1)
    picked = {}
    for slot, (sp, su) in slot_samples.items():
        d = ((local[:, None, :] - sp[None, :, :]) ** 2).sum(axis=2)
        picked[slot] = su[d.argmin(axis=1)]
    for poly in me.polygons:
        table = picked.get(poly.material_index)
        if table is None:
            continue
        for li in poly.loop_indices:
            uvl.data[li].uv = tuple(table[me.loops[li].vertex_index])
    us = [uvl.data[i].uv for i in range(len(uvl.data))]
    print("    UV aralık: u[%.3f..%.3f] v[%.3f..%.3f]" % (
        min(u[0] for u in us), max(u[0] for u in us),
        min(u[1] for u in us), max(u[1] for u in us)))


def set_uv(obj, mat_index_uv):
    """Her materyal yuvasının bütün loop'larını tek bir texel'e sabitle."""
    me = obj.data
    uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        uv = mat_index_uv.get(poly.material_index)
        if uv is None:
            continue
        for li in poly.loop_indices:
            uvl.data[li].uv = uv


def run():
    col = clean_scene()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=SRC)
    body = [o for o in bpy.data.objects if o not in before and o.type == 'MESH'][0]
    for c in list(body.users_collection):
        c.objects.unlink(body)
    col.objects.link(body)
    body.name = "tripo_part_0"
    src_mat = body.data.materials[0] if body.data.materials else None

    # 2) Teker bölgelerini sil
    bm = bmesh.new()
    bm.from_mesh(body.data)
    doomed = []
    for v in bm.verts:
        for ax, ay, az in AXLES:
            if abs(v.co.x - ax) <= CUT_HALF_W and math.hypot(v.co.y - ay, v.co.z - az) <= CUT_R:
                doomed.append(v)
                break
    bmesh.ops.delete(bm, geom=doomed, context='VERTS')
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    print("govde: %d vertex kaldi (%d silindi)" % (len(body.data.vertices), len(doomed)))

    # 3) Temiz tekerler
    rubber, rim = wheel_materials()

    for i, (ax, ay, az) in enumerate(AXLES):
        parts = []
        rot = (0.0, math.radians(90), 0.0)
        # Lastik GERÇEK HALKA profilinden döndürülerek üretilir. İlk denemede dolu silindirdi;
        # o zaman jant tablası lastiğin arkasında kalıyor, dışarıdan yalnızca 2 mm taşan göbek
        # görünüyordu (render'da siyah disk + küçük beyaz nokta).
        hw = TYRE_W * 0.5
        prof = [(INNER_R, -hw), (TYRE_R - 0.004, -hw), (TYRE_R, -hw + 0.006),
                (TYRE_R, hw - 0.006), (TYRE_R - 0.004, hw), (INNER_R, hw)]
        bm = bmesh.new()
        vs = [bm.verts.new((ax + w, ay, az + r)) for r, w in prof]
        for k in range(len(vs)):
            bm.edges.new((vs[k], vs[(k + 1) % len(vs)]))
        bmesh.ops.spin(bm, geom=list(bm.verts) + list(bm.edges), axis=(1.0, 0.0, 0.0),
                       cent=(ax, ay, az), dvec=(0.0, 0.0, 0.0),
                       angle=2.0 * math.pi, steps=24, use_duplicate=False)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("Lastik%d" % i)
        bm.to_mesh(me)
        bm.free()
        t = bpy.data.objects.new("Lastik%d" % i, me)
        bpy.context.scene.collection.objects.link(t)
        t.data.materials.append(rubber)
        parts.append(t)
        # jant tablası: deliği doldurur, lastikten 4 mm içeride (çanak etkisi)
        bpy.ops.mesh.primitive_cylinder_add(radius=INNER_R + 0.003, depth=TYRE_W - 0.008,
                                            vertices=28, location=(ax, ay, az), rotation=rot)
        r_obj = bpy.context.object
        r_obj.data.materials.append(rim)
        parts.append(r_obj)
        # göbek (jant kapağı): jantın 3 mm önünde
        bpy.ops.mesh.primitive_cylinder_add(radius=TYRE_R * 0.30, depth=TYRE_W - 0.002,
                                            vertices=24, location=(ax, ay, az), rotation=rot)
        h = bpy.context.object
        h.data.materials.append(rim)
        parts.append(h)
        bpy.ops.object.select_all(action='DESELECT')
        for pt in parts:
            pt.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        w_obj = bpy.context.object
        w_obj.name = "tripo_part_%d" % (i + 1)
        for c in list(w_obj.users_collection):
            c.objects.unlink(w_obj)
        col.objects.link(w_obj)
        print("  %s: %d ucgen" % (w_obj.name, len(w_obj.data.polygons) * 2))

    # 4) Dışa aktar
    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False)
    print("yazildi: %s  (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1048576.0))


run()
