"""HURDALIK → OYUN: sahneyi kurar, IŞIĞI PİŞİRİR, glTF'e aktarır.

Kullanım (ekransız):
    blender -b --factory-startup --python tools/world/export_junkyard.py [-- --no-wrecks | --wrecks-only] [--fast]

NEDEN PİŞİRME: kullanıcının onayladığı görünüm Blender render'ı. O görünümün asıl kaynağı dolaylı ışık
(güneşli kumdan ve yüzeylerden seken ışık): güneş arkadan vurduğu için kameraya bakan yüzler yalnız bununla
aydınlanıyor. Telefonda bu gerçek zamanlı yapılamaz (GL Compatibility: GI / SSAO / gölge yok). Ölçüldü:
Godot'ta güneş + ortam ışığıyla çit, baraka, yığınlar neredeyse siyah çıkıyordu; Blender'da yalnız-diffuse
render bile parlak (parlama değil, sekme ışığı). Çözüm: Cycles DIFFUSE bake (doğrudan + dolaylı + renk)
→ köşe rengi "Lit" ve zemin dokusu; oyunda IŞIKSIZ (unshaded) çizilir. Kamera açısı ve güneş sabit
olduğundan bu kayıpsızdır, telefonda da en ucuz çizim yoludur. Parlama (glossy) pişirilmez: bakış
yönüne bağlı, ölçüldü — görünüme katkısı çok küçük.

Çıktılar (Godot bunları içe aktarır):
  assets/world/junkyard.glb          — sahne (köşe rengi = pişmiş ışık). Hareketsiz bölgeler (Static_*) +
                                       ayrı nesneler (arama yığınları, halkalar, vinç kancası, pres çenesi,
                                       karakterler, ateşler, arazi) + günün araç yerleri (DailyCarSpot_*).
                                       Zemin YOK: Godot kendisi kurar.
  assets/world/junkyard_ground.png   — zemin dokusu, ışığı pişmiş (gölgeler, gök ışığı dahil).
  assets/world/junk_wrecks/<id>.glb  — her restorasyon aracının paslı, tekerleksiz hurda varyantı (~3.000
                                       üçgen), meydandaki yerinde ışığı pişmiş. Ön +Z (oyundaki araç sahneleri
                                       gibi), gerçek metre. Sahadaki günün araçları.
"""
import bpy, sys, os, time, math
import numpy as np

PROJECT = "/home/burak/Projects/car-town-remake"
OUT_GLB = os.path.join(PROJECT, "assets/world/junkyard.glb")
WRECK_DIR = os.path.join(PROJECT, "assets/world/junk_wrecks")
DAILY_TRIS = 3000
LIT = "Lit"
# Hurda varyantlarının pişirildiği yer: meydanın ortası (günün 3 aracının ortadaki yeri), burun güneye.
WRECK_BAKE_SPOT = (34.0, 20.0, 0.05)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WITH_WRECKS = "--no-wrecks" not in argv
WRECKS_ONLY = "--wrecks-only" in argv   # sahne / zemin pişirilmez, yalnız hurda varyantları
FAST = "--fast" in argv
GROUND_SAMPLES = 8 if FAST else 48
VERTEX_SAMPLES = 16 if FAST else 128

t0 = time.time()
GROUND_PNG_PATH = os.path.join(PROJECT, "assets/world/junkyard_ground.png")
# Sahne kurulumu zemin dokusunu IŞIKSIZ hâliyle yeniden yazar; yalnız-hurda kipinde pişmiş doku korunur
_ground_backup = open(GROUND_PNG_PATH, "rb").read() if WRECKS_ONLY and os.path.exists(GROUND_PNG_PATH) else None
exec(open(os.path.join(PROJECT, "tools/world/junkyard.py"), encoding="utf-8").read())
if _ground_backup is not None:
    open(GROUND_PNG_PATH, "wb").write(_ground_backup)
scn = bpy.context.scene
for o in list(scn.objects):   # fabrika sahnesinin küpü / ışığı / kamerası
    if o.name in ("Cube", "Light", "Camera"):
        bpy.data.objects.remove(o, do_unlink=True)
print("KURULUM %.1f sn" % (time.time() - t0))


def use_cycles(samples):
    try:
        scn.render.engine = 'CYCLES'
    except TypeError as e:
        print(e)
    scn.cycles.device = 'CPU'
    scn.cycles.samples = samples
    scn.render.bake.margin = 4


def select_only(objs):
    """Seçim AÇIK görüntü katmanında (glTF dışa / içe aktarıcı etkin sahneyi değiştirebiliyor)."""
    vl = scn.view_layers[0]
    for o in vl.objects:
        o.select_set(False, view_layer=vl)
    for o in objs:
        o.select_set(True, view_layer=vl)
    vl.objects.active = objs[0]


def bake(objs, **kw):
    vl = scn.view_layers[0]
    with bpy.context.temp_override(scene=scn, view_layer=vl, active_object=objs[0], object=objs[0],
                                   selected_objects=objs, selected_editable_objects=objs):
        bpy.ops.object.bake(**kw)


def daily_spots():
    """Günün araç yer tutucuları → boş düğüm (oyun gerçek hurda varyantını oraya koyar)."""
    for o in list(scn.objects):
        if o.name.startswith("DailyCar_"):
            e = bpy.data.objects.new("DailyCarSpot_" + o.name.split("_")[1], None)
            e.location = o.location
            for c in o.users_collection:
                c.objects.link(e)
            bpy.data.objects.remove(o, do_unlink=True)


def bake_ground():
    """Zemin dokusu → ışığı pişmiş doku (DIFFUSE: doğrudan + renk; gök ışığı doğrudan sayılır)."""
    ground = bpy.data.objects["Ground"]
    nt = ground.data.materials[0].node_tree
    img = next(n for n in nt.nodes if n.type == 'TEX_IMAGE').image
    w, h = img.size
    target = bpy.data.images.new("JY_GroundLit", w, h, float_buffer=True)
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = target
    nt.nodes.active = node
    hidden = [o for o in scn.objects if o.name.startswith("SearchRing_") or o.get("jy_preview_only")]
    for o in hidden:
        o.hide_render = True
    use_cycles(GROUND_SAMPLES)
    scn.render.bake.target = 'IMAGE_TEXTURES'
    select_only([ground])
    t = time.time()
    bake([ground], type='DIFFUSE', pass_filter={'DIRECT', 'COLOR'})
    print("ZEMİN PİŞİRME %.1f sn" % (time.time() - t))
    for o in hidden:
        o.hide_render = False
    px = np.empty(w * h * 4, dtype=np.float32)
    target.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    lin = np.clip(px[:, :, :3], 0.0, 1.0)
    px[:, :, :3] = np.where(lin > 0.0031308, 1.055 * np.power(lin, 1 / 2.4) - 0.055, lin * 12.92)
    px[:, :, 3] = 1.0
    img.pixels.foreach_set(px.reshape(-1).astype(np.float32))
    img.save()
    nt.nodes.remove(node)
    print("ZEMİN", img.filepath_raw)


# Oyun kamerasına doğru birim vektör (Blender dünyası): güneydoğudan 45°, 25° yukarıdan.
TO_CAMERA = (math.sin(math.radians(45)) * math.cos(math.radians(25)), -math.cos(math.radians(45)) * math.cos(math.radians(25)),
             math.sin(math.radians(25)))


def face_camera(o):
    """Yüzleri kameranın gördüğü tarafa çevirir. Pişirme yüzün NORMAL tarafını aydınlatır; Builder'ın küre / uzuv
    parçalarında normaller içe bakıyordu (Eevee iki taraflı çizdiği için render'da görünmüyordu, pişirmede figürler
    simsiyah çıktı). Kamera açısı sabit: kapalı hacimde arkaya bakan yüz zaten görünmez, açık sacta (hurda kabuk,
    oluklu levha) görünen taraf kameraya bakan taraftır — iki durumda da doğru taraf pişer."""
    import bmesh
    from mathutils import Vector
    local = (o.matrix_world.to_3x3().inverted_safe() @ Vector(TO_CAMERA)).normalized()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    away = [f for f in bm.faces if f.normal.dot(local) < 0.0]
    if away:
        bmesh.ops.reverse_faces(bm, faces=away, flip_multires=False)
        bm.to_mesh(o.data)
    bm.free()
    return len(away)


# Örnek noktası: köşeden yüz merkezine doğru bu oranda içeride, normal boyunca bu kadar dışarıda (m).
PROBE_SHRINK = 0.6
PROBE_LIFT = 0.01


def make_probe(o):
    """Pişirme sondası: nesnenin kopyası, her yüz kendi merkezine doğru küçültülmüş (köşeler ayrık).
    NEDEN: Cycles köşe rengine pişirirken ışığı KÖŞE NOKTASINDA ölçer. Girintili yüzeylerde (oluklu sac,
    iç içe kitbash parçalar, yığınlar) köşeler komşu yüzün gölgesinde ya da başka parçanın içinde kalıyor,
    bütün yüz kararıyordu (Eevee piksel başına gölgelediği için render'da yok). Sonda yüzün İÇİNDEN ölçer;
    kendisi ışınlara görünmez, gölgeyi ve sekmeyi asıl nesneler verir. Yüz / köşe sırası korunur."""
    import bmesh
    me = o.data.copy()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.split_edges(bm, edges=bm.edges[:])
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        n = f.normal
        for v in f.verts:
            v.co = c + (v.co - c) * PROBE_SHRINK + n * PROBE_LIFT
    bm.to_mesh(me)
    bm.free()
    probe = bpy.data.objects.new(o.name + "_Probe", me)
    scn.collection.objects.link(probe)
    probe.matrix_world = o.matrix_world.copy()
    for attr in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter"):
        setattr(probe, attr, False)
    return probe


def bake_vertex(objs, samples):
    """Nesnelerin köşe rengine pişmiş ışık ("Lit"; albedo "Col" olduğu gibi kalır). Sondalarla ölçülür."""
    # Yeni yerleştirilen nesnenin matrix_world'ü güncellenmeden sonda (0, 0)'a — hurda dağının içine — düşüyor,
    # hurda varyantları simsiyah pişiyordu.
    scn.view_layers[0].update()
    probes = []
    for o in objs:
        face_camera(o)
        probe = make_probe(o)
        me = probe.data
        lit = me.color_attributes.get(LIT) or me.color_attributes.new(LIT, 'FLOAT_COLOR', 'CORNER')
        me.color_attributes.active_color = lit
        probes.append(probe)
    use_cycles(samples)
    scn.render.bake.target = 'VERTEX_COLORS'
    select_only(probes)
    bake(probes, type='DIFFUSE', pass_filter={'DIRECT', 'INDIRECT', 'COLOR'})
    for o, probe in zip(objs, probes):
        src = probe.data.color_attributes[LIT]
        dst = o.data.color_attributes.get(LIT) or o.data.color_attributes.new(LIT, 'FLOAT_COLOR', 'CORNER')
        assert len(src.data) == len(dst.data), o.name
        arr = np.empty(len(src.data) * 4, dtype=np.float32)
        src.data.foreach_get("color", arr)
        dst.data.foreach_set("color", arr)
        encode_srgb(dst)
        me = probe.data
        bpy.data.objects.remove(probe, do_unlink=True)
        bpy.data.meshes.remove(me)


def encode_srgb(attr):
    """Doğrusal ışık → sRGB kodlu değer. Godot GL Compatibility köşe rengini HER ZAMAN sRGB sayıyor
    (vertex_color_is_srgb bu çizicide etkisiz; ölçüldü: 0,5 doğrusal değer ekranda 0,5 çıktı, 0,74 değil).
    Doğrusal yazınca her şey ~2,2 kat koyu görünüyordu. Godot okurken sRGB → doğrusal çevirir: sonuç doğru."""
    arr = np.empty(len(attr.data) * 4, dtype=np.float32)
    attr.data.foreach_get("color", arr)
    arr = arr.reshape(-1, 4)
    lin = np.clip(arr[:, :3], 0.0, 1.0)
    arr[:, :3] = np.where(lin > 0.0031308, 1.055 * np.power(lin, 1 / 2.4) - 0.055, lin * 12.92)
    arr[:, 3] = 1.0
    attr.data.foreach_set("color", arr.reshape(-1))


def bake_scene():
    objs = [o for o in scn.objects if o.type == 'MESH' and o.name != "Ground" and not o.get("jy_preview_only")]
    t = time.time()
    bake_vertex(objs, VERTEX_SAMPLES)
    print("NESNE PİŞİRME %.1f sn, %d nesne" % (time.time() - t, len(objs)))


def export_scene():
    bpy.ops.object.select_all(action='DESELECT')
    n = 0
    for o in scn.objects:
        if o.get("jy_preview_only") or o.name == "Ground" or o.type not in ('MESH', 'EMPTY'):
            continue
        o.select_set(True)
        n += 1
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, use_active_scene=True,
                              export_apply=True, export_vertex_color='NAME', export_vertex_color_name=LIT,
                              export_all_vertex_colors=False, export_materials='EXPORT', export_image_format='NONE',
                              export_cameras=False, export_lights=False, export_yup=True, export_extras=False)
    print("GLB", OUT_GLB, n, "nesne, %.1f MB" % (os.path.getsize(OUT_GLB) / 1e6))


def export_wrecks():
    import json
    from mathutils import Matrix
    os.makedirs(WRECK_DIR, exist_ok=True)
    cars = {c["id"]: c for c in json.load(open(os.path.join(PROJECT, "vehicles/cars.json"), encoding="utf-8"))["cars"]}
    rest = json.load(open(os.path.join(PROJECT, "vehicles/restorations.json"), encoding="utf-8"))["cars"]
    lib = bpy.data.scenes.get("JY_WreckLib") or bpy.data.scenes.new("JY_WreckLib")
    out = bpy.data.scenes.new("JY_WreckOut")
    paint = surface_mat("metal_paint", 0.7, 0.25)
    col = scn.collection
    for r in rest:
        cid = r["id"]
        entry = cars.get(cid)
        if entry is None or not os.path.exists(os.path.join(PROJECT, entry.get("optimized_path", "").replace("res://", ""))):
            print("ATLA (model yok)", cid)
            continue
        me = make_wreck(cid, lib, DAILY_TRIS, "_day")
        me.materials.append(paint)
        # Ön +X → -Y (glTF +Z = Godot +Z: oyundaki araç sahneleri gibi)
        me.transform(Matrix.Rotation(math.radians(-90), 4, 'Z'))
        o = bpy.data.objects.new("Wreck_" + cid, me)
        col.objects.link(o)
        o.location = WRECK_BAKE_SPOT
        bake_vertex([o], VERTEX_SAMPLES)
        col.objects.unlink(o)
        o.location = (0, 0, 0)
        out.collection.objects.link(o)
        path = os.path.join(WRECK_DIR, cid + ".glb")
        with bpy.context.temp_override(scene=out, view_layer=out.view_layers[0]):
            bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, use_active_scene=True,
                                      export_vertex_color='NAME', export_vertex_color_name=LIT,
                                      export_all_vertex_colors=False, export_image_format='NONE', export_yup=True)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        print("HURDA", cid, tris, "üçgen, %.0f KB" % (os.path.getsize(path) / 1e3))
        out.collection.objects.unlink(o)


daily_spots()
if not WRECKS_ONLY:
    bake_ground()
    bake_scene()
    export_scene()
if WITH_WRECKS or WRECKS_ONLY:
    export_wrecks()
print("BİTTİ %.1f sn" % (time.time() - t0))
