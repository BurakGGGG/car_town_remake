"""HURDA ARAÇ KÜTÜPHANESİ — oyunun gerçek araç modellerinden hafif, paslı hurda varyantları üretir.

Neden: elle kurulan kutu "kabuklar" araca benzemiyordu (kullanıcı: "çok amatör"). Kaynak olarak oyundaki
optimize GLB'ler (assets/cars/optimized/<id>.glb) kullanılır:
  1. tekerlek / lastik / jant parçaları atılır (CarPartMap rolleri: vehicles/car_part_map.gd) → soyulmuş hurda,
  2. parçalar birleştirilir, gerçek boya göre ölçeklenir (cars.json real_dimensions.length_m), ön +X'e döner,
  3. COLLAPSE decimate ile ~TARGET_TRIS üçgene indirilir (UV korunur),
  4. albedo dokusu her köşeye örneklenir → "Col" köşe rengi (doku gerekmez: oyunda tek materyal),
  5. renk soldurulur (doygunluk ↓, parlaklık ↓) ve 3B gürültüyle pas lekeleri (altta daha yoğun) eklenir.
Sonuç: "WreckMesh_<id>" mesh veri blokları (fake user), junk_kit.py / junkyard.py örnekler.

Kullanım: junkyard.py başında exec edilir; ensure_wrecks() eksik olanları üretir (araç başına birkaç saniye).
"""
import bpy, bmesh, math, json, re, os
import numpy as np
from mathutils import Vector, Matrix, noise

PROJECT = "/home/burak/Projects/car-town-remake"
WRECK_IDS = ["tofas_murat_124", "anadol_a1", "vw_beetle_1967", "fiat_500_1965", "mercedes_w123", "peugeot_404",
             "chevrolet_bel_air_1956", "ford_mustang_1967", "tofas_sahin", "renault_toros"]
TARGET_TRIS = 1800
# Hafif kütüphanede yalnız iyi inceltilebilenler (açık yüzeyli Tripo parçaları inceltmeyi sınırlıyor: bu altısı
# ~520–870 üçgene iniyor, Murat / Fiat / Peugeot / Anadol 1.100–1.800'de takılıyor → onlar yalnız tam detaylı yerlerde)
LOW_IDS = ["mercedes_w123", "ford_mustang_1967", "renault_toros", "tofas_sahin", "chevrolet_bel_air_1956", "vw_beetle_1967"]
DROP_ROLES = ("wheels", "tires", "rims")
RUST = [np.array(c) for c in ((0.62, 0.33, 0.18), (0.45, 0.24, 0.14), (0.70, 0.42, 0.22))]   # sRGB (doku da sRGB okunur)


def _part_roles(car_id):
    """car_part_map.gd'den bu aracın atılacak parça indeksleri."""
    text = open(os.path.join(PROJECT, "vehicles/car_part_map.gd"), encoding="utf-8").read()
    data = json.load(open(os.path.join(PROJECT, "vehicles/cars.json"), encoding="utf-8"))
    entry = next(c for c in data["cars"] if c["id"] == car_id)
    key = '"%s": {' % entry["scene_path"]
    i = text.find(key)
    if i < 0:
        return set(), entry
    j = text.find("\n\t},", i)
    block = text[i:j]
    drop = set()
    for role in DROP_ROLES:
        m = re.search(r'"%s": \[([^\]]*)\]' % role, block)
        if m:
            drop |= {int(x) for x in m.group(1).split(",") if x.strip()}
    # Teker gruplarındaki her parça da (jant kolu dilimleri vb.)
    m = re.search(r'"wheel_groups": \{([^}]*)\}', block)
    if m:
        drop |= {int(x) for x in re.findall(r'\d+', m.group(1))}
    return drop, entry


def _albedo_array(objs):
    for o in objs:
        for slot in o.material_slots:
            if slot.material and slot.material.use_nodes:
                for n in slot.material.node_tree.nodes:
                    if n.type == 'TEX_IMAGE' and n.image:
                        img = n.image
                        w, h = img.size
                        arr = np.empty(w * h * 4, dtype=np.float32)
                        img.pixels.foreach_get(arr)
                        return arr.reshape(h, w, 4), w, h
    return None, 0, 0


def _to_linear(c):
    return [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]


def make_wreck(car_id, lib_scene, target=TARGET_TRIS, suffix=""):
    drop, entry = _part_roles(car_id)
    path = os.path.join(PROJECT, entry["optimized_path"].replace("res://", ""))
    before = set(bpy.data.objects)
    if bpy.context.window is not None:
        bpy.context.window.scene = lib_scene
    import contextlib, io
    with contextlib.redirect_stdout(io.StringIO()):
        bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = []
    for o in new:
        if o.type != 'MESH':
            continue
        base = o.name.split(".")[0]
        m = re.match(r'tripo_part_(\d+)$', base)
        if m and int(m.group(1)) in drop:
            continue
        meshes.append(o)
    img, w, h = _albedo_array(meshes)
    # Birleştir (dünya dönüşümleri uygulanarak)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UV")
    for o in meshes:
        me = o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        tb = bmesh.new()
        tb.from_mesh(me)
        tb.transform(o.matrix_world)
        tuv = tb.loops.layers.uv.active
        vmap = {}
        for v in tb.verts:
            vmap[v] = bm.verts.new(v.co)
        for f in tb.faces:
            try:
                nf = bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            if tuv:
                for l_new, l_old in zip(nf.loops, f.loops):
                    l_new[uv_layer].uv = l_old[tuv].uv
        tb.free()
        o.to_mesh_clear()
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    # Ölçek: gerçek uzunluk, ön +X (glTF +Z ön → Blender -Y → +90° Z)
    bm.transform(Matrix.Rotation(math.radians(90), 4, 'Z'))
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    length = max(xs) - min(xs)
    s = float(entry["real_dimensions"]["length_m"]) / max(length, 1e-6)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    bm.transform(Matrix.Translation((-cx * s, -cy * s, -min(zs) * s)) @ Matrix.Scale(s, 4))
    # Parçaların çakışan köşeleri birleşsin (UV köşe başına korunur) → inceltme temiz çöker; boşta köşe kalmasın
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    if target < 1000:
        # Hafif varyant: küçük kopuk parçalar (ayna, trim, çerçeve) inceltmeyi kilitliyor — her ada en az birkaç
        # üçgen ister, 300'e inilemiyordu. Alanın büyük kısmını taşıyan adalar kalır (kümülatif %92), kırıntılar atılır.
        bm.faces.ensure_lookup_table()
        seen = set()
        islands = []
        for f in bm.faces:
            if f.index in seen:
                continue
            stack, isl = [f], []
            seen.add(f.index)
            while stack:
                g = stack.pop()
                isl.append(g)
                for e in g.edges:
                    for nb in e.link_faces:
                        if nb.index not in seen:
                            seen.add(nb.index)
                            stack.append(nb)
            islands.append((sum(x.calc_area() for x in isl), isl))
        islands.sort(key=lambda t: -t[0])
        total = sum(a for a, _ in islands) or 1.0
        acc = 0.0
        drop = []
        for a_, isl in islands:
            if acc / total >= 0.92:
                drop += isl
            acc += a_
        bmesh.ops.delete(bm, geom=drop, context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    me = bpy.data.meshes.new("WreckMesh_" + car_id + suffix)
    bm.to_mesh(me)
    bm.free()
    tmp = bpy.data.objects.new("WreckTmp", me)
    bpy.context.scene.collection.objects.link(tmp)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    mod = tmp.modifiers.new("Dec", 'DECIMATE')
    mod.ratio = min(1.0, target / max(tris, 1))
    bpy.context.view_layer.objects.active = tmp
    bpy.ops.object.modifier_apply(modifier=mod.name)
    me = tmp.data
    # Doku → köşe rengi + soldurma + pas
    col = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
    uv = me.uv_layers.active
    zmax = max(v.co.z for v in me.vertices) or 1.0
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            p = me.vertices[vi].co
            if img is not None and uv is not None:
                u, v = uv.data[li].uv
                px = min(w - 1, max(0, int((u % 1.0) * w)))
                py = min(h - 1, max(0, int((v % 1.0) * h)))
                c = img[py, px, :3].astype(np.float64)
            else:
                c = np.array((0.4, 0.4, 0.4))
            grey = c.mean()
            c = c * 0.8 + grey * 0.2                         # hafif soldur (doku sRGB değerleri)
            c *= 0.88
            n = noise.noise(Vector((p.x * 1.4, p.y * 1.4, p.z * 1.4)))
            low = 1.0 - min(1.0, p.z / zmax)
            # Pas lekeler hâlinde (~%30–40): gürültü eşiği + altta (marşpiyel, çamurluk dibi) daha yoğun
            rust = max(0.0, min(1.0, (n + low * 0.6 - 0.18) * 2.6))
            k = int((noise.noise(Vector((p.x * 3.0, p.y * 3.0, 7.0))) + 1.0) * 1.5) % 3
            c = c * (1 - rust) + RUST[k] * rust
            lc = _to_linear([float(max(0.0, min(1.0, x))) for x in c])
            col.data[li].color = (lc[0], lc[1], lc[2], 1.0)
    if uv:
        me.uv_layers.remove(uv)
    bm2 = bmesh.new()
    bm2.from_mesh(me)
    bmesh.ops.delete(bm2, geom=[v for v in bm2.verts if not v.link_faces], context='VERTS')
    bm2.to_mesh(me)
    bm2.free()
    me.materials.clear()
    me.name = "WreckMesh_" + car_id + suffix
    me.use_fake_user = True
    bpy.data.objects.remove(tmp, do_unlink=True)
    return me


def ensure_wrecks(ids=WRECK_IDS, rebuild=False, low=False):
    """Hurda mesh'leri (yoksa üretir). low=True → ~300 üçgenlik hafif varyant (kuleler, dağ içleri)."""
    lib = bpy.data.scenes.get("JY_WreckLib") or bpy.data.scenes.new("JY_WreckLib")
    back = bpy.context.window.scene if bpy.context.window is not None else None
    out = {}
    suffix, target = ("_low", 300) if low else ("", TARGET_TRIS)   # hafif: yığın / kule / kasa / pres (uzak, yarı gömülü)
    for cid in ids:
        me = bpy.data.meshes.get("WreckMesh_" + cid + suffix)
        if me is not None and low and len(me.polygons) > target * 1.3:
            rebuild_this = True
        else:
            rebuild_this = False
        if me is not None and (rebuild or rebuild_this or me.color_attributes.get("Col") is None
                               or me.color_attributes["Col"].data_type != 'FLOAT_COLOR'):
            me.use_fake_user = False
            bpy.data.meshes.remove(me)
            me = None
        if me is None:
            if low:
                # Hafif varyant TAM varyanttan inceltilir: UV yok (renk köşe renginde) → doku dikişleri inceltmeyi
                # kilitlemez (kaynaktan doğrudan inceltince 300 hedefi 460–1.800'de takılıyordu).
                full = bpy.data.meshes.get("WreckMesh_" + cid) or make_wreck(cid, lib)
                me = full.copy()
                me.name = "WreckMesh_" + cid + suffix
                # Yüz köşesi renkleri köşe başına ortalanır: renk farkları dikiş sayılıp inceltmeyi kilitliyordu
                attr = me.color_attributes["Col"]
                acc = {}
                for li, loop in enumerate(me.loops):
                    c = attr.data[li].color
                    a_ = acc.setdefault(loop.vertex_index, [0.0, 0.0, 0.0, 0])
                    a_[0] += c[0]; a_[1] += c[1]; a_[2] += c[2]; a_[3] += 1
                for li, loop in enumerate(me.loops):
                    a_ = acc[loop.vertex_index]
                    attr.data[li].color = (a_[0] / a_[3], a_[1] / a_[3], a_[2] / a_[3], 1.0)
                tmp = bpy.data.objects.new("WreckLowTmp", me)
                bpy.context.scene.collection.objects.link(tmp)
                mod = tmp.modifiers.new("Dec", 'DECIMATE')
                mod.ratio = min(1.0, target / max(len(me.polygons), 1))
                bpy.context.view_layer.objects.active = tmp
                bpy.ops.object.modifier_apply(modifier=mod.name)
                bpy.data.objects.remove(tmp, do_unlink=True)
                me.use_fake_user = True
            else:
                me = make_wreck(cid, lib, target, suffix)
        out[cid] = me
    if back is not None:
        bpy.context.window.scene = back
    return out
