"""GARAJLARIM → OYUN: garaj sahnesini kurar, IŞIĞI PİŞİRİR, glTF + dokular olarak aktarır (hurdalık hattının
garaj hâli, bkz. tools/world/export_junkyard.py — pişirme sondası, yüz çevirme, sRGB kodlama oradan).

GÖRÜNTÜ DÖNÜŞÜMÜ: önizleme render'ı sahne-doğrusal ışığı AgX (+ Punchy) ile ekrana getirir; oyunda ışıksız köşe rengi /
doku OLDUĞU GİBİ gösterilir. Ölçüldü (2026-10-19): doğrusal değeri sRGB'ye kodlayıp yazınca duvarlar ~0,02 — neredeyse
siyah. Bu yüzden pişmiş her değer Blender'ın KENDİ görüntü dönüşümünden geçirilir (görüntüye yazılıp save_render ile
renk yönetimi uygulanarak) ve ekran değeri olarak saklanır. Dönüşüm doğrusal olmadığından "zemin × ışık haritası"
çarpımı da tutmaz: zemin her (zemin sv., IŞIKLAR sv.) çifti için ayrı ve tam ışıklı pişer (9 doku, oyun yalnız seçiliyi
yükler).

Kullanım (ekransız, depo kökünden):
    blender -b --factory-startup --python tools/garages/export_garage.py -- mahalle|sanayi|…|rooftop [--fast]

NEDEN PİŞİRME: onaylanan görünüm Cycles render'ı (dolaylı ışık, yumuşak gölge, ışık havuzları). Telefon (GL
Compatibility) bunu gerçek zamanlı yapamaz: ortam / zemin / eşyalar ışığı pişmiş hâlde IŞIKSIZ çizilir; yalnız araçlar
gerçek zamanlı ışık alır.

SEVİYE KALEMLERİ (MAHALLE): her kalem 3 seviye (ayrı nesneler, oyun seviyeye göre gösterir). Pişirme:
  - köşe rengi ("Lit"): her seviyenin nesneleri KENDİ seviyesindeki komşularıyla (Static + aynı k'lı kalemler) ve
    orta ışık düzeniyle pişirilir. IŞIKLAR seviyesinin duvarlara etkisi oyunda genel çarpanla verilir.
  - zemin: ışığı ayrı dokuya (ışık haritası) her IŞIKLAR seviyesi için pişirilir; oyunda zemin = seçili zemin dokusu ×
    seçili ışık haritası (zemin sahnede tek nesne).
  - seviyeyle değişen ve zemine değen nesnelerin (lift, koliler, raf) zemine düşen gölgesi: AO çıkartması
    (Decal_<nesne>, çarpımlı çizilir) — zemin ışık haritalarında yalnız hep duran nesnelerin gölgesi var.
Işıyan yüzlerin köşe rengine kendi ışık rengi yazılır (oyunda tek ışıksız materyal). Huzmeler (Beam_*) pişmez;
köşe rengi = renk × yoğunluk, oyunda katkılı çizilir.

Çıktılar: assets/garages/<ad>/<ad>.glb + PNG dokular (oyun kodda atar: world/garage_interior.gd).
"""
import bpy, bmesh, sys, os, time, math
import numpy as np

REPO = os.getcwd()
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SCENE = argv[0] if argv else "mahalle"
FAST = "--fast" in argv
VERTEX_SAMPLES = 16 if FAST else 96
MAP_SAMPLES = 16 if FAST else 128
LIT = "Lit"
OUT_DIR = os.path.join(REPO, "assets", "garages", SCENE)
os.makedirs(OUT_DIR, exist_ok=True)
t0 = time.time()

EXPORTING = True
exec(open(os.path.join(REPO, "tools", "garages", SCENE + ".py"), encoding="utf-8").read())
scn = bpy.context.scene


# --- Hurdalık hattından: sonda, yüz çevirme, sRGB ---------------------------------------------------

def use_cycles(samples):
    try:
        scn.render.engine = 'CYCLES'
    except TypeError as e:
        print(e)
    scn.cycles.device = 'CPU'
    scn.cycles.samples = samples
    scn.render.bake.margin = 4


def select_only(objs):
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


def to_srgb(lin):
    lin = np.clip(lin, 0.0, 1.0)
    return np.where(lin > 0.0031308, 1.055 * np.power(lin, 1 / 2.4) - 0.055, lin * 12.92)


TMP_DIR = os.path.join(os.path.expanduser("~"), "Projects", "ct_shots", "garaj3d", "tmp")
os.makedirs(TMP_DIR, exist_ok=True)


def view_settings():
    """Önizleme render'ıyla aynı renk yönetimi (mahalle.py / rooftop.py render())."""
    scn.display_settings.display_device = 'sRGB'
    scn.view_settings.view_transform = 'AgX'
    looks = [i.identifier for i in bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items]
    scn.view_settings.look = 'AgX - Punchy' if 'AgX - Punchy' in looks else 'None'
    scn.view_settings.exposure = 0.0
    scn.view_settings.gamma = 1.0


def display_image(img, path):
    """Doğrusal (float) görüntüyü sahnenin görüntü dönüşümüyle 8 bit PNG'ye kaydeder: oyunda olduğu gibi gösterilir."""
    view_settings()
    scn.render.image_settings.file_format = 'PNG'
    scn.render.image_settings.color_mode = 'RGB'
    scn.render.image_settings.color_depth = '8'
    img.save_render(path, scene=scn)
    print("  PNG", os.path.relpath(path, REPO) if path.startswith(REPO) else path)


def display_values(lin):
    """(N, 3) sahne-doğrusal → (N, 3) ekran değeri (0..1, sRGB kodlu): görüntü üzerinden aynı dönüşüm."""
    n = len(lin)
    w = min(max(n, 1), 4096)
    h = (n + w - 1) // w
    img = bpy.data.images.new("dt_tmp", w, h, float_buffer=True, alpha=False)
    px = np.zeros((w * h, 4), dtype=np.float32)
    px[:n, :3] = lin
    px[:, 3] = 1.0
    img.pixels.foreach_set(px.ravel())
    path = os.path.join(TMP_DIR, "dt_tmp.png")
    view_settings()
    scn.render.image_settings.file_format = 'PNG'
    scn.render.image_settings.color_mode = 'RGB'
    scn.render.image_settings.color_depth = '16'
    img.save_render(path, scene=scn)
    out = bpy.data.images.load(path)
    # Ham (sRGB kodlu) değerler: yüklenen 16 bit PNG'nin pikselleri aksi hâlde doğrusala çevrilerek geliyor; doğrusal
    # sayıları köşe rengine yazınca Godot onları sRGB sayıp orta tonları karartıyordu (ölçüldü: 0,18 → 0,18).
    out.colorspace_settings.name = 'Non-Color'
    res = np.empty(w * h * 4, dtype=np.float32)
    out.pixels.foreach_get(res)
    bpy.data.images.remove(img)
    bpy.data.images.remove(out)
    return res.reshape(-1, 4)[:n, :3]


def display_attr(attr):
    """Köşe rengi (doğrusal ışık) → ekran değeri (görüntü dönüşümüyle)."""
    arr = np.empty(len(attr.data) * 4, dtype=np.float32)
    attr.data.foreach_get("color", arr)
    arr = arr.reshape(-1, 4)
    arr[:, :3] = display_values(arr[:, :3])
    arr[:, 3] = 1.0
    attr.data.foreach_set("color", arr.reshape(-1))


def encode_srgb(attr):
    arr = np.empty(len(attr.data) * 4, dtype=np.float32)
    attr.data.foreach_get("color", arr)
    arr = arr.reshape(-1, 4)
    arr[:, :3] = to_srgb(arr[:, :3])
    arr[:, 3] = 1.0
    attr.data.foreach_set("color", arr.reshape(-1))


def camera_dir():
    """Önizleme kamerasından sahneye bakış yönünün tersi (yüz çevirme için)."""
    from mathutils import Vector
    cam = scn.camera
    return (cam.matrix_world.to_3x3() @ Vector((0, 0, 1))).normalized()


def face_camera(o, to_cam):
    from mathutils import Vector
    local = (o.matrix_world.to_3x3().inverted_safe() @ to_cam).normalized()
    bm = bmesh.new()
    bm.from_mesh(o.data)
    away = [f for f in bm.faces if f.normal.dot(local) < 0.0]
    if away:
        bmesh.ops.reverse_faces(bm, faces=away, flip_multires=False)
        bm.to_mesh(o.data)
    bm.free()


def make_probe(o):
    me = o.data.copy()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.split_edges(bm, edges=bm.edges[:])
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        n = f.normal
        for v in f.verts:
            v.co = c + (v.co - c) * 0.6 + n * 0.01
    bm.to_mesh(me)
    bm.free()
    probe = bpy.data.objects.new(o.name + "_Probe", me)
    scn.collection.objects.link(probe)
    probe.matrix_world = o.matrix_world.copy()
    for attr in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter"):
        setattr(probe, attr, False)
    return probe


def bake_vertex(objs, samples):
    if not objs:
        return
    scn.view_layers[0].update()
    to_cam = camera_dir()
    probes = []
    for o in objs:
        face_camera(o, to_cam)
        probe = make_probe(o)
        me = probe.data
        lit = me.color_attributes.get(LIT) or me.color_attributes.new(LIT, 'FLOAT_COLOR', 'CORNER')
        me.color_attributes.active_color = lit
        probes.append(probe)
    use_cycles(samples)
    scn.render.bake.target = 'VERTEX_COLORS'
    select_only(probes)
    t = time.time()
    bake(probes, type='DIFFUSE', pass_filter={'DIRECT', 'INDIRECT', 'COLOR'})
    for o, probe in zip(objs, probes):
        src = probe.data.color_attributes[LIT]
        dst = o.data.color_attributes.get(LIT) or o.data.color_attributes.new(LIT, 'FLOAT_COLOR', 'CORNER')
        arr = np.empty(len(src.data) * 4, dtype=np.float32)
        src.data.foreach_get("color", arr)
        dst.data.foreach_set("color", arr)
        display_attr(dst)
        emissive_lit(o)
        me = probe.data
        bpy.data.objects.remove(probe, do_unlink=True)
        bpy.data.meshes.remove(me)
    print("  köşe pişirme %s: %.1f sn" % (", ".join(o.name for o in objs), time.time() - t))


def emissive_lit(o):
    """Işıyan yüzlerin (JYS_emit_<renk>_<güç>) köşe rengine kendi ışık rengi: oyunda tek ışıksız materyal yeter."""
    me = o.data
    lit = me.color_attributes.get(LIT)
    for poly in me.polygons:
        if poly.material_index >= len(me.materials):
            continue
        mat = me.materials[poly.material_index]
        if mat is None or not mat.name.startswith("JYS_emit_"):
            continue
        hexcol = mat.name.split("_")[2]
        c = [int(hexcol[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
        for li in poly.loop_indices:
            lit.data[li].color = (c[0], c[1], c[2], 1.0)


def bake_image(obj, name, w, h, pass_filter, encode_half=False):
    """Nesnenin UV'sine DIFFUSE pişirir; doğrusal değerler (h, w, 3) ve pişirme görüntüsü döner."""
    mat = obj.data.materials[0]
    nt = mat.node_tree
    img = bpy.data.images.new(name, w, h, float_buffer=True)
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    nt.nodes.active = node
    use_cycles(MAP_SAMPLES)
    scn.render.bake.target = 'IMAGE_TEXTURES'
    select_only([obj])
    t = time.time()
    bake([obj], type='DIFFUSE', pass_filter=pass_filter)
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rgb = px[:, :, :3] * (0.5 if encode_half else 1.0)
    nt.nodes.remove(node)
    print("  doku pişirme %s: %.1f sn" % (name, time.time() - t))
    bake_image.last = img
    return rgb


def save_png(rgb_lin, path):
    """Doğrusal → sRGB kodlu 8 bit PNG (Blender görüntü satırları alttan üste: olduğu gibi)."""
    h, w, _ = rgb_lin.shape
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = to_srgb(rgb_lin)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    print("  PNG", os.path.relpath(path, REPO))


def shadow_decal(objs, name, hide_also, px_per_m=40.0, margin=0.7):
    """objs'nin zemine düşürdüğü gölge → çarpımlı çıkartma (düzlem + PNG). Düzlem iki kez pişer (ışık, renk yok):
    nesneler görünürken ve gizliyken; oran = gölge çarpanı (gerçek ışıkların gölgesi, AO değil). hide_also: iki
    pişirmede de gizli kalanlar (zemin, hep duranlar: onların gölgesi zemin dokusunda zaten var)."""
    from mathutils import Vector
    mn = Vector((1e9, 1e9)); mx = Vector((-1e9, -1e9))
    for o in objs:
        me = o.data
        mw = o.matrix_world
        for v in me.vertices:
            w = mw @ v.co
            if w.z < 1.0:
                mn.x, mn.y = min(mn.x, w.x), min(mn.y, w.y)
                mx.x, mx.y = max(mx.x, w.x), max(mx.y, w.y)
    mn -= Vector((margin, margin)); mx += Vector((margin, margin))
    size = mx - mn
    w, h = max(8, int(size.x * px_per_m)), max(8, int(size.y * px_per_m))
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0.012)) for x, y in ((mn.x, mn.y), (mx.x, mn.y), (mx.x, mx.y), (mn.x, mx.y))]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, c in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uv].uv = c
    bm.to_mesh(me)
    bm.free()
    plane_o = bpy.data.objects.new(name, me)
    scn.collection.objects.link(plane_o)
    mat = bpy.data.materials.new(name + "_mat")
    mat.use_nodes = True
    me.materials.append(mat)
    set_visible(hide_also, False)
    set_visible(objs, True)
    lit_with = bake_image(plane_o, name + "_a", w, h, {'DIRECT', 'INDIRECT'})
    set_visible(objs, False)
    lit_without = bake_image(plane_o, name + "_b", w, h, {'DIRECT', 'INDIRECT'})
    set_visible(hide_also, True)
    # pay: ışığın hiç ulaşmadığı yerde iki pişirme de ~0 → oran gürültüden 0 çıkıp sahte siyah leke oluyordu
    base = lit_without.mean(axis=2)
    eps = max(float(np.percentile(base, 50)) * 0.15, 1e-3)
    ratio = np.clip((lit_with.mean(axis=2) + eps) / (base + eps), 0.0, 1.0)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / (margin * px_per_m * 0.8)
    ratio = 1.0 - (1.0 - ratio) * np.clip(edge, 0, 1)   # kenara doğru 1: çıkartmanın sınırı görünmesin
    img = bpy.data.images.new(name + "_out", w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = ratio[:, :, None]   # çarpan: doğrusal değil, ekrana doğrudan çarpılır (8 bit, dönüşümsüz)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(OUT_DIR, name.lower() + ".png")
    img.file_format = 'PNG'
    img.save()
    print("  PNG", os.path.relpath(img.filepath_raw, REPO), "en koyu %.2f ort %.2f" % (ratio.min(), ratio.mean()))
    plane_o["g_decal"] = name.lower() + ".png"
    plane_o["g_blank"] = bool(ratio.min() > 0.97)
    # pişirmeden sonra gizli: zemini kaplayan düzlem görünür kalınca sonraki çıkartmalar (aynı yükseklik) onun gölgesinde
    # kalıp tamamen siyah pişiyordu (2026-10-19). Dışa aktarmada geri açılır.
    plane_o.hide_render = True
    return plane_o


def clear_lights():
    for o in list(scn.objects):
        if o.type == 'LIGHT':
            bpy.data.objects.remove(o, do_unlink=True)


def set_visible(objs, visible):
    for o in objs:
        o.hide_render = not visible


def beam_lit(objs):
    """Huzme: köşe rengi = renk × yoğunluk (alfa "Col"de); oyunda katkılı."""
    for o in objs:
        me = o.data
        src = me.color_attributes.get("Col")
        dst = me.color_attributes.get(LIT) or me.color_attributes.new(LIT, 'FLOAT_COLOR', 'CORNER')
        for i in range(len(src.data)):
            c = src.data[i].color
            dst.data[i].color = (c[0] * c[3], c[1] * c[3], c[2] * c[3], 1.0)
        encode_srgb(dst)


def export_glb(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    vl = scn.view_layers[0]
    for o in vl.objects:
        o.select_set(o in objs, view_layer=vl)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, use_active_scene=True,
                              export_apply=True, export_vertex_color='NAME', export_vertex_color_name=LIT,
                              export_all_vertex_colors=False, export_materials='EXPORT', export_image_format='NONE',
                              export_cameras=False, export_lights=False, export_yup=True, export_extras=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == 'MESH')
    print("GLB %s: %d nesne, %d üçgen, %.1f MB" % (os.path.relpath(path, REPO), len(objs), tris, os.path.getsize(path) / 1e6))


# --- SEVİYELİ GARAJLAR (MAHALLE, SANAYİ …) -----------------------------------------------------------
# Sahne betiği sözleşmesi: build(tex_dir) → (kök, gruplar); zemin ALBEDO dokuları <sahne>_floor_<1..3>.png tex_dir'e;
# Floor_L1..3 nesneleri; koleksiyonlar Static, Beams, Slots, <Kalem>_L<k>; preview_lights(k), preview_camera(w, h);
# genel W, D (metre).

def export_leveled():
    root, groups = build(TMP_DIR)   # zemin albedo dokuları ara dosya: oyuna pişmiş hâlleri gider
    for lv in (2, 3):
        o = bpy.data.objects.get("Floor_L%d" % lv)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
    floor = bpy.data.objects["Floor_L1"]
    floor.name = "Floor"
    albedo = {lv: bpy.data.images.load(os.path.join(TMP_DIR, "%s_floor_%d.png" % (SCENE, lv))) for lv in (1, 2, 3)}
    preview_camera(1280, 640)   # yüz çevirme bu bakışa göre
    view_settings()
    statics = [o for o in bpy.data.collections["Static"].objects if o.type == "MESH"]
    beams = [o for o in bpy.data.collections["Beams"].objects]
    set_visible(beams, False)
    items = ("Walls", "Lights", "Lift", "Park")
    # Seviyeler sahnedeki koleksiyonlardan: PARK YERİ büyük garajlarda 4-5 seviyeli (NEON, CAM SHOWROOM, HANGAR)
    variant = {}
    for item in items:
        for lv in range(1, 7):
            c = bpy.data.collections.get("%s_L%d" % (item, lv))
            if c is not None:
                variant[(item, lv)] = [o for o in c.objects if o.type == 'MESH']
    top_level = max(lv for (_item, lv) in variant)

    def show_level(k):
        for (item, lv), objs in variant.items():
            set_visible(objs, lv == k)

    # 1) köşe rengi: her seviye kendi komşularıyla, orta ışık düzeniyle. Hep duranlar sv.1 geçişinde: tuğla duvar yalnız
    #    orada açıkta (sv.2 / sv.3'te önüne boya / ahşap kaplama geliyor, tuğlalar gölgede kalıp siyah pişiyordu)
    clear_lights()
    preview_lights(2)
    for k in range(1, top_level + 1):
        show_level(k)
        objs = [o for item in items for o in variant.get((item, k), [])] + (statics if k == 1 else [])
        bake_vertex(objs, VERTEX_SAMPLES)
    # 2) zemin: her (zemin, IŞIKLAR) çifti tam ışıklı; yalnız hep duranlar + o seviyenin armatürleri görünür
    floor_tex = next(n for n in floor.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE')
    for k in (1, 2, 3):
        show_level(0)
        set_visible(variant[("Lights", k)], True)
        clear_lights()
        preview_lights(k)
        for f in (1, 2, 3):
            floor_tex.image = albedo[f]
            ppm = min(80.0, 2048.0 / max(W, D))   # uzun kenar en çok 2048 px (HANGAR 34 m: 2720 px, 9 pişirme, gereksiz VRAM)
            bake_image(floor, "floor_%d_%d" % (f, k), int(W * ppm), int(D * ppm), {'DIRECT', 'INDIRECT', 'COLOR'})
            display_image(bake_image.last, os.path.join(OUT_DIR, "floor_%d_%d.png" % (f, k)))
    # 3) zemin gölge çıkartmaları: seviyeyle gelen, zemine değen nesneler (lift, koliler, raf)
    clear_lights()
    preview_lights(2)
    decals = []
    show_level(0)
    for (item, lv), objs in variant.items():
        if item == "Lights" or not objs or (item == "Walls" and lv == 1):
            continue   # armatürler ve sv.1 duvarı (lekeler / posterler) zemine değmez
        decal = shadow_decal(objs, "Decal_%s_L%d" % (item, lv), [floor] + statics)
        set_visible(objs, False)
        if decal.get("g_blank"):   # gölgesi yok (ör. yalnız zemin çizgileri): boşuna çizilmesin
            os.remove(os.path.join(OUT_DIR, decal["g_decal"]))
            bpy.data.objects.remove(decal, do_unlink=True)
            continue
        decals.append(decal)
    beam_lit(beams)
    slots = [o for o in bpy.data.collections["Slots"].objects]
    every = statics + [floor] + beams + decals + slots + [o for objs in variant.values() for o in objs]
    for o in every:
        o.hide_render = False
    export_glb(every, os.path.join(OUT_DIR, SCENE + ".glb"))


# --- ÇATI KATI OTOPARK ------------------------------------------------------------------------------

def export_rooftop():
    build(TMP_DIR)   # rooftop_deck.png (ışıksız albedo) + rooftop_backdrop.png ara dosya
    preview_camera(1280, 640)
    view_settings()
    clear_lights()
    preview_lights()
    deck = bpy.data.objects["DeckTop"]
    backdrop_o = bpy.data.objects["Backdrop"]
    beams = [o for o in bpy.data.collections["Beams"].objects]
    set_visible(beams, False)
    meshes = [o for o in bpy.data.collections["Static"].objects if o.type == 'MESH' and o not in (deck, backdrop_o)]
    bake_vertex(meshes, VERTEX_SAMPLES)
    bake_image(deck, "deck_lit", 1632, 1120, {'DIRECT', 'INDIRECT', 'COLOR'})
    display_image(bake_image.last, os.path.join(OUT_DIR, "deck.png"))
    # fon: önizlemede ışıyan yüzey (güç 1) AgX'ten geçiyordu — oyunda da aynı görünsün
    display_image(bpy.data.images.load(os.path.join(TMP_DIR, "rooftop_backdrop.png")), os.path.join(OUT_DIR, "backdrop.png"))
    beam_lit(beams)
    slots = [o for o in bpy.data.collections["Slots"].objects]
    set_visible(beams, True)
    export_glb(meshes + [deck, backdrop_o] + beams + slots, os.path.join(OUT_DIR, "rooftop.glb"))


for o in list(scn.objects):
    if o.name in ("Cube", "Light", "Camera"):
        bpy.data.objects.remove(o, do_unlink=True)
export_rooftop() if SCENE == "rooftop" else export_leveled()
print("BİTTİ %.1f sn" % (time.time() - t0))
