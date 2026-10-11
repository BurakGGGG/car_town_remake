"""HURDALIK haritası — Blender'da kurulur, assets/world/junkyard.glb yazılır (ayrı harita, şehirde değil).

Tasarım kararları: docs/HURDALIK_TASARIM.md. Showroom (tools/world/showroom.py) ile aynı yöntem.

Kullanım (canlı Blender oturumu, MCP eklentisi 127.0.0.1:9876):
    python3 tools/decor/blender_send.py tools/world/junkyard.py
Kullanıcının açık sahnesine dokunulmaz: "Junkyard" adlı AYRI bir sahnede çalışılır.

Birim METRE (araç 4,4 m); oyunda kök düğüm DecorBuilder.METER (0,1367) ile ölçeklenir.
Blender eksenleri: X doğu, Y kuzey, Z yukarı; glTF'te Blender (x, y, z) → Godot (x, z, -y).
Oyun kamerası şehirdeki gibi: ortografik, güneydoğudan (45°) ve 25° yukarıdan bakar. Ekranda +X sağ-aşağı,
+Y sağ-yukarı gider; ekranın "sağ önü" = güneydoğu köşesi, "sol yukarısı" = kuzeybatı.

KURGU v3 (kullanıcı, 2026-10-11: "Car Town'a biraz daha benzet, daha cool ve detaylı çizimler"): orijinal
hurdalığın öğeleri (arkada iki katlı konteyner duvarı + önünde hurda dolu açık kasalar, jant kapaklı koyu duvar +
lastik yığınları, sarı mıknatıslı vinç, oval tabelalı ahşap baraka, yerde tekerleksiz araç iskeletleri, kavisli
sokak lambaları, toprak-gri renkler) + Mad Max sertliği (dev hurda dağları, araç kuleleri, ateş varilleri,
alçak güneş). Bütün yapılar tools/world/junk_kit.py'deki detaylı üreticilerden.
KURGU v2 notları (geçerliliğini koruyanlar):
    giriş          SAĞ ÖNDE (doğu çit, güneydoğu köşesine yakın): hurda parçalarından dev demir kapı,
                   ampullü tabela kemeri, kemerin üstünde bir araç gövdesi. Kapının iç yanında Necati'nin barakası.
    meydan         ortada beton zemin: günün 3 aracı, köşelerde iş lambaları + ateş varilleri.
    hurda dağları  arkada (kuzey ve batı) 8–14 m: ezilmiş araç kabukları, sac, boru, jant, lastikten tepeler;
                   aralarında kanyon geçitleri; yer yer 5–6 katlı araç kuleleri.
    hareket        vinç bir arabayı havada taşır, preste kıvılcım, varillerde ateş (animasyon Godot'ta).
    ışık           alçak altın güneş, uzun gölgeler, tozlu turuncu gökyüzü.
    yakın kenarlar güney ve doğu alçak oluklu sac çit (kamera o taraftan bakıyor).
"""
import bpy, bmesh, math, random

# Detaylı parça kiti (şasi, konteyner, açık kasa, jant duvarı, lamba, lastik, baraka, vinç, pres, çit)
exec(open("/home/burak/Projects/car-town-remake/tools/world/junk_kit.py").read(), globals())
# Dokulu zemin (numpy) + tabakalı arazi
exec(open("/home/burak/Projects/car-town-remake/tools/world/junk_ground.py").read(), globals())

OUT = "/home/burak/Projects/car-town-remake/assets/world/junkyard.glb"
SCENE = "Junkyard"
COLL = "JunkyardLot"
W, D = 64.0, 50.0          # saha boyutu (X, Y)
GATE = (16.0, 26.0)        # doğu çitteki kapı aralığı (Y) — barakayı ekranda örtmesin diye kuzeyde (kamera açısı hesabı)
PLAZA = (22.0, 12.0, 46.0, 28.0)   # meydan: x0, y0, x1, y1
_MATS = {}
RNG = random.Random(11)    # her çalıştırmada aynı yerleşim


# --- Kurulum -----------------------------------------------------------------------------

def srgb(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def use_scene():
    if bpy.context.window is None:          # ekransız (blender -b): mevcut sahnede çalışılır
        scn = bpy.context.scene
        scn.name = SCENE
    else:
        scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
        bpy.context.window.scene = scn
    col = bpy.data.collections.get(COLL)
    if col is None:
        col = bpy.data.collections.new(COLL)
    if col.name not in scn.collection.children:
        scn.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    return scn, col


def mat(name, hexcol, rough=0.85, metal=0.0, emit=None, strength=2.0):
    """Renk + yüzey tanımı (kitteki k_mat): renk köşe rengine yazılır, materyal yüzey türüne çevrilir."""
    return k_mat(name, hexcol, rough=rough, metal=metal, emit=emit, strength=strength)


# Mad Max paleti: solmuş boyalar + bol pas
PAINTS = ["#9C4A32", "#6F7F86", "#B58A4A", "#5E6B55", "#8A6E5A", "#A7A196", "#7A3F3A", "#4F5A63", "#9A7B3E"]
RUSTS = ["#7A3E22", "#8F4F2A", "#5E3220", "#A25D2E"]


def paint_mat(i):
    return mat("paint_%d" % (i % len(PAINTS)), PAINTS[i % len(PAINTS)], rough=0.7, metal=0.25)


def rust_mat(i):
    return mat("rust_%d" % (i % len(RUSTS)), RUSTS[i % len(RUSTS)], rough=0.95, metal=0.1)


def _link(col, o, material):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    col.objects.link(o)
    if material is not None:
        o.data.materials.clear()
        o.data.materials.append(material)
    return o


def box(col, name, x0, y0, z0, sx, sy, sz, material, rot=0.0, bevel=0.0):
    """Köşesi (x0, y0, z0) olan, sx × sy × sz kutu; rot = Z ekseninde derece (kutu merkezinden)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x0 + sx / 2, y0 + sy / 2, z0 + sz / 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx, sy, sz)
    o.rotation_euler.z = math.radians(rot)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = o.modifiers.new("Bevel", 'BEVEL')
        mod.width = bevel
        mod.segments = 1
    return _link(col, o, material)


def cyl(col, name, x, y, z, r, h, material, verts=16, axis='Z', rot=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=(x, y, z))
    o = bpy.context.active_object
    o.name = name
    if axis == 'X':
        o.rotation_euler = (0.0, math.radians(90), math.radians(rot))
    elif axis == 'Y':
        o.rotation_euler = (math.radians(90), 0.0, math.radians(rot))
    return _link(col, o, material)


def mesh_obj(col, name, verts, faces, material, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    o.scale = scale
    if material is not None:
        o.data.materials.append(material)
    return o


def join(col, name, objs):
    """Parçaları tek nesnede birleştirir (oyunda tek çizim çağrısı / az düğüm)."""
    objs = [o for o in objs if o is not None]
    if not objs:
        return None
    for o in objs:
        for mod in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.active_object
    out.name = name
    return out


# --- Parça üreticileri ------------------------------------------------------------------

def car_shell(col, name, x, y, z, yaw, material, crush=1.0, pitch=0.0, roll=0.0, scale=1.0, cabin=True):
    """Hurda araç kabuğu: tekerleksiz gövde + eğik camlı kabin (alçak poligon). crush < 1 → basık / ezik."""
    L, Wd, H = 4.3, 1.8, 0.62 * crush
    hl, hw = L / 2, Wd / 2
    v = [(-hl, -hw, 0), (hl, -hw, 0), (hl, hw, 0), (-hl, hw, 0),
         (-hl, -hw, H * 0.85), (hl, -hw, H), (hl, hw, H), (-hl, hw, H * 0.85)]
    f = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    if cabin:
        ch = 0.55 * crush
        b = len(v)
        v += [(-1.1, -hw * 0.92, H * 0.92), (0.9, -hw * 0.92, H * 0.97), (0.9, hw * 0.92, H * 0.97), (-1.1, hw * 0.92, H * 0.92),
              (-0.6, -hw * 0.78, H + ch), (0.3, -hw * 0.78, H + ch), (0.3, hw * 0.78, H + ch), (-0.6, hw * 0.78, H + ch)]
        f += [(b + 4, b + 7, b + 6, b + 5), (b + 0, b + 4, b + 5, b + 1), (b + 1, b + 5, b + 6, b + 2),
              (b + 2, b + 6, b + 7, b + 3), (b + 3, b + 7, b + 4, b + 0)]
    o = mesh_obj(col, name, v, f, material, loc=(x, y, z),
                 rot=(math.radians(roll), math.radians(pitch), math.radians(yaw)), scale=(scale, scale, scale))
    return o


# Hurda tepesi çekirdeğinin benek paleti: pas tonları, solgun boyalar, çelik, lastik
JUNK_SPECKLE = ["#5C4130", "#6A4030", "#74503A", "#4E3E33", "#7E6A58", "#66706F", "#6E4A40", "#5E6252",
                "#857660", "#463F3A", "#7A7B7A", "#3A3430"]


def junk_pile(col, name, cx, cy, radius, height, count, seed, shells=0.45, hero=False):
    """Hurda tepesi: koyu kubbe çekirdek, yüzeyine GERÇEK hurda araçlar (yan yatmış, ters dönmüş, ezik),
    sac paneller, borular, lastikler ve jantlar serpiştirilir; tek nesne. hero=True → yakın plan yığın
    (tam detaylı araçlar), aksi hâlde hafif varyantlar."""
    r = random.Random(seed)
    b = Builder(name, seed=seed)
    core_h = height * 0.72
    dark = mat("junk_core", "#5C4130", rough=0.97)
    for j in range(3 if radius > 4 else 1):
        ox, oy = (r.uniform(-0.3, 0.3) * radius, r.uniform(-0.3, 0.3) * radius) if j else (0.0, 0.0)
        sc = 1.0 if j == 0 else r.uniform(0.5, 0.75)
        b.dome((cx + ox, cy + oy, -0.1), radius * sc, radius * sc * r.uniform(0.8, 1.0), core_h * sc * r.uniform(0.85, 1.05),
               dark, seed=seed * 7 + j, rings=10, segs=22, rough=0.22, speckle=JUNK_SPECKLE)
    tire = mat("tire", "#1E1E1E", rough=0.95)
    steel = mat("steel", "#8D8F91", metal=0.7, rough=0.45)
    for i in range(count):
        d = radius * math.sqrt(r.random()) * 0.97
        a = r.uniform(0, math.tau)
        px, py = cx + math.cos(a) * d, cy + math.sin(a) * d
        surface = core_h * max(0.0, 1.0 - (d / radius) ** 2)
        pz = max(0.0, surface + r.uniform(-0.6, 0.2))
        k = r.random()
        if k < shells:
            # Eğim: tepenin yüzeyine yaslanmış; bazıları ters / yan
            lean = math.degrees(math.atan2(core_h * 2 * d / radius, radius)) * r.uniform(0.5, 1.0)
            roll = r.choice((0, 0, 0, 180, 90, -90)) + r.uniform(-15, 15)
            wreck_into(b, r.randrange(99), (px, py, pz - 0.4), math.degrees(a) + r.uniform(-60, 60), pitch=r.uniform(-lean, lean),
                       roll=roll, crush=r.uniform(0.55, 1.0), low=not hero, scale=r.uniform(0.92, 1.0))
        elif k < shells + 0.2:
            b.box((px, py, pz + 0.1), (r.uniform(1.2, 2.4), r.uniform(0.6, 1.4), 0.06),
                  paint_mat(r.randrange(99)) if r.random() < 0.5 else rust_mat(r.randrange(9)),
                  rot=(r.uniform(-50, 50), r.uniform(-30, 30), r.uniform(0, 180)))
        elif k < shells + 0.33:
            b.cyl((px, py, pz + 0.2), r.uniform(0.06, 0.14), r.uniform(1.5, 3.5), steel, axis='X', segs=6,
                  rot=(0, r.uniform(-30, 30), r.uniform(0, 180)))
        elif k < shells + 0.45:
            b.cyl((px, py, pz + 0.2), 0.42, 0.28, tire, segs=9, rot=(r.uniform(-70, 70), r.uniform(-40, 40), 0))
        else:
            b.cyl((px, py, pz + 0.15), 0.34, 0.18, steel, segs=9, rot=(r.uniform(-70, 70), 0, 0))
    # Orijin yığının merkezine (oyun seçimi / sallanma animasyonu bu noktayı kullanır; eskiden sahne
    # köşesindeydi, altı yığın aynı noktaya izdüşüyordu)
    from mathutils import Matrix
    o = b.finish(col)
    o.data.transform(Matrix.Translation((-cx, -cy, 0.0)))
    o.location = (cx, cy, 0.0)
    return o


def car_tower(col, name, x, y, levels, seed):
    """Ezilmiş araç kulesi: gerçek hurdalar basık hâlde üst üste, her kat hafif kaymış ve dönmüş."""
    r = random.Random(seed)
    b = Builder(name, seed=seed)
    z = 0.0
    base_yaw = 90 if seed % 2 else 0
    for k in range(levels):
        crush = r.uniform(0.32, 0.4)
        wreck_into(b, r.randrange(99), (x + r.uniform(-0.25, 0.25), y + r.uniform(-0.2, 0.2), z),
                   base_yaw + r.uniform(-10, 10) + (180 if r.random() < 0.5 else 0), roll=r.uniform(-3, 3), crush=crush, low=True)
        z += 1.45 * crush - 0.02
    return b.finish(col)


def mound(col, name, x, y, rx, ry, h, material, seed=0):
    """Toprak tepe / çalı: basık, hafif pürüzlü yarım küre."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(x, y, 0.0))
    o = bpy.context.active_object
    o.name = name
    o.scale = (rx, ry, h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    r = random.Random(seed)
    for v in o.data.vertices:
        if v.co.z < 0:
            v.co.z = 0.0
        else:
            k = 1.0 + r.uniform(-0.12, 0.12)
            v.co.x *= k
            v.co.y *= k
            v.co.z *= 1.0 + r.uniform(-0.2, 0.2)
    return _link(col, o, material)


# --- Saha --------------------------------------------------------------------------------

# Zemin dokusuna çizilen ayrıntılar (dünya metresi)
MOUNDS = [(3.0, 41.0, 8.0), (-1.0, 27.0, 7.0), (-2.0, 13.0, 7.5), (1.0, 2.0, 5.5), (28.5, 31.5, 3.6),
          (9.0, 33.5, 2.0), (8.0, 20.0, 2.0), (61.0, 44.0, 2.0), (40.0, 44.0, 2.0)]
STAINS = [(26.0, 19.4, 0.9), (42.0, 20.8, 0.7), (52.0, 38.5, 1.4), (33.5, 34.0, 1.3), (51.0, 4.6, 0.6),
          (15.0, 24.0, 1.0), (72.0, 21.3, 1.1), (19.0, 11.0, 0.7), (37.0, 14.0, 0.6)]
TRACKS = [
    [(W + 36, 21.0), (W, 21.0), (52.0, 21.5), (46.0, 20.5), (38.0, 20.5)],      # giriş → meydan
    [(34.0, 27.0), (33.0, 31.0), (31.0, 34.0)],                                # meydan → vinç
    [(45.0, 24.0), (47.0, 31.0), (50.0, 36.5)],                                # meydan → pres
    [(23.0, 20.0), (17.0, 18.0), (13.0, 12.0)],                                # meydan → iskeletler
]


def ground(col):
    img = make_ground_texture(W, D, GATE, PLAZA, MOUNDS, STAINS, TRACKS)
    ground_plane(col, img)


def fences(col):
    """Yakın kenarlar (güney + doğu): alçak oluklu sac çit, paslı yamalı; dikenli tel çizgisi."""
    sheet = mat("corrugated", "#8A7864", metal=0.35, rough=0.65)
    post = mat("post", "#3E3B38", metal=0.5)
    wire = mat("wire", "#2A2826", metal=0.6)
    h = 2.3

    def run(axis, fixed, a0, a1, tag):
        a = a0
        i = 0
        while a < a1 - 0.1:
            w = min(3.0, a1 - a)
            m = rust_mat(i) if RNG.random() < 0.35 else sheet
            hh = h + RNG.uniform(-0.25, 0.15)
            if axis == 'x':
                o = box(col, "Fence%s_%d" % (tag, i), a, fixed - 0.06, 0, w, 0.12, hh, m)
                box(col, "Post%s_%d" % (tag, i), a - 0.07, fixed - 0.14, 0, 0.14, 0.14, h + 0.5, post)
            else:
                o = box(col, "Fence%s_%d" % (tag, i), fixed - 0.06, a, 0, 0.12, w, hh, m)
                box(col, "Post%s_%d" % (tag, i), fixed - 0.14, a - 0.07, 0, 0.14, 0.14, h + 0.5, post)
            o.rotation_euler.y = math.radians(RNG.uniform(-3, 3))
            a += w
            i += 1
        if axis == 'x':
            box(col, "Wire%s" % tag, a0, fixed - 0.03, h + 0.35, a1 - a0, 0.06, 0.06, wire)
        else:
            box(col, "Wire%s" % tag, fixed - 0.03, a0, h + 0.35, 0.06, a1 - a0, 0.06, wire)

    run('x', 0.0, 0.0, W, "S")
    run('y', W, 0.0, GATE[0], "E1")
    run('y', W, GATE[1], D, "E2")


def gate(col):
    """GÖSTERİŞLİ GİRİŞ (doğu çiti): direkler üst üste üç ezilmiş araç küpü + çelik başlık, diplerinde lastik
    yığınları; perçinli paslı I-kiriş; dış yüzde ampul çerçeveli tabela (yazı Godot'ta Label3D: HURDALIK);
    kirişin üstünde hurda Mustang; altında iki sarkan iş lambası; içe açılmış çerçeveli, çapraz destekli
    oluklu sac kanatlar."""
    y0, y1 = GATE
    yc = (y0 + y1) / 2
    span = y1 - y0
    dark = mat("crane_dark", "#2B2926", metal=0.55, rough=0.6)
    beam_c = mat("beam_rust", "#6A3A24", metal=0.3, rough=0.85)
    rivet = mat("steel", "#8D8F91", metal=0.7, rough=0.45)
    sign_face = mat("sign_cream", "#E8DCC0", rough=0.7)
    sign_rim = mat("sign_red", "#A8342A", rough=0.6)
    bulb = mat("bulb", "#FFD27A", emit="#FFB84A", strength=8.0)
    lamp_glow = mat("lamp_glow", "#FFF0C6", emit="#FFE0A0", strength=9.0)
    sheet = mat("corrugated", "#8A7864", metal=0.4, rough=0.6)
    b = Builder("Gate", seed=21)
    cube_cols = ["#7A5A48", "#5B6B73", "#8C6B3A", "#6E4A4A", "#566B52", "#7D7F82"]
    for side, yp in ((-1, y0 - 1.1), (1, y1 + 1.1)):
        z = 0.0
        for k in range(3):   # gerçek hurda araçlardan pres küpleri, her biri hafif dönük
            sz = 1.75 - k * 0.1
            crushed_cube(b, k * 3 + (side > 0) * 5, (W, yp, z), sz, yaw=(k * 9 - 9) * side)
            z += sz
        b.box((W, yp, z + 0.7), (0.5, 0.5, 1.4), dark)                     # çelik başlık
        b.box((W, yp, z + 1.45), (0.8, 0.8, 0.12), dark)
        for k in range(4):                                                  # dipte lastikler
            b.cyl((W + 1.25, yp + side * 0.2, 0.15 + k * 0.28), 0.45, 0.27, mat("tire", "#1E1E1E", rough=0.95), segs=16)
    top = 5.1 + 1.5
    # I-kiriş: üst / alt flanş + gövde, perçinler
    by0, by1 = y0 - 1.6, y1 + 1.6
    for zz in (top, top + 0.9):
        b.box((W, (by0 + by1) / 2, zz), (0.7, by1 - by0, 0.1), beam_c)
    b.box((W, (by0 + by1) / 2, top + 0.45), (0.12, by1 - by0, 0.8), beam_c)
    n = int((by1 - by0) / 0.5)
    for k in range(n + 1):
        y = by0 + k * (by1 - by0) / n
        for zz in (top + 0.12, top + 0.78):
            b.cyl((W + 0.07, y, zz), 0.035, 0.04, rivet, axis='X', segs=6)
    # Tabela (kirişin dış yüzünde, alt kenardan sarkar)
    sw, sh = span + 0.4, 1.35
    sz = top - 0.75
    b.box((W + 0.25, yc, sz), (0.12, sw + 0.3, sh + 0.3), sign_rim)
    b.box((W + 0.32, yc, sz), (0.04, sw, sh), sign_face)
    nb = 16
    for k in range(nb):
        y = yc - sw / 2 - 0.05 + (sw + 0.1) * k / (nb - 1)
        for z in (sz - sh / 2 - 0.1, sz + sh / 2 + 0.1):
            b.cyl((W + 0.36, y, z), 0.08, 0.06, bulb, axis='X', segs=8)
    for z in (sz - 0.35, sz, sz + 0.35):
        for y in (yc - sw / 2 - 0.12, yc + sw / 2 + 0.12):
            b.cyl((W + 0.36, y, z), 0.08, 0.06, bulb, axis='X', segs=8)
    for y in (yc - sw / 2 + 0.6, yc + sw / 2 - 0.6):
        b.box((W + 0.2, y, top - 0.08), (0.06, 0.06, 0.2), dark)
    # Kirişin altında iki sarkan iş lambası
    for y in (yc - span * 0.25, yc + span * 0.25):
        b.cyl((W - 0.1, y, top - 0.6), 0.02, 1.1, dark, segs=4)
        b.cyl((W - 0.1, y, top - 1.25), 0.35, 0.25, dark, segs=12, r2=0.1)
        b.cyl((W - 0.1, y, top - 1.38), 0.27, 0.03, lamp_glow, segs=12)
    b.finish(col)
    # Kirişin üstünde hurda Mustang (burun güneye)
    gb = Builder("GateCar", seed=5)
    wreck_into(gb, "ford_mustang_1967", (0, 0, 0), -90, roll=6)
    gb.finish(col, loc=(W - 0.1, yc, top + 0.95), ao=False)
    # Kanatlar: içe açılmış; çerçeve borusu + oluklu sac dolgu + çapraz destek
    # Kanat yerelde +X boyunca (menteşe x=0). Kapalıyken güney kanadı +Y'ye (90°), kuzey kanadı −Y'ye (270°)
    # uzanır; içe (−X) 60° açık: güney 150°, kuzey 210°.
    for side, yh, yaw in ((-1, y0, 150.0), (1, y1, 210.0)):
        lb = Builder("GateLeaf_%d" % (side > 0), seed=31 + side)
        L, H = span / 2 - 0.2, 3.2
        lb.corrugated((0.0, 0.0, 0.15), L, H - 0.2, sheet, period=0.2, depth=0.04, along='X')
        lb.tube([(0, 0, 0.1), (L, 0, 0.1), (L, 0, H), (0, 0, H), (0, 0, 0.1)], 0.06, dark, segs=6)
        lb.tube([(0, 0, 0.1), (L, 0, H)], 0.045, dark, segs=5)
        lb.tube([(0, 0, H * 0.5), (L, 0, H * 0.5)], 0.04, dark, segs=5)
        lb.finish(col, loc=(W - 0.15, yh, 0), rot=(0, 0, yaw))


def office(col):
    """Necati'nin barakası: kapının iç yanında (güneydoğu köşesi), sundurmalı, ışığı yanan pencere."""
    wood = mat("wood", "#6E4B2F", rough=0.9)
    wood2 = mat("wood_dark", "#4F3523", rough=0.9)
    roof = mat("roof_tin", "#7A7068", metal=0.45, rough=0.55)
    window = mat("window_lit", "#F2C66B", emit="#F2A63A", strength=4.0)
    x0, y0 = 48.0, 2.5
    box(col, "Office", x0, y0, 0, 11, 7, 3.4, wood)
    for k in range(10):   # dikey tahta çıtalar
        box(col, "OfficePlank_%d" % k, x0 + 0.5 + k * 1.05, y0 + 6.98, 0, 0.14, 0.08, 3.4, wood2)
    # Çatı: tek eğimli, sundurma DOĞUYA (girişe ve kameraya) taşar
    r = box(col, "OfficeRoof", x0 - 0.5, y0 - 0.5, 3.4, 14.5, 8.0, 0.25, roof)
    r.rotation_euler.y = math.radians(5)
    for k, y in enumerate((y0 + 0.2, y0 + 3.4, y0 + 6.6)):
        box(col, "PorchPost_%d" % k, x0 + 13.4, y, 0, 0.25, 0.25, 3.2, wood2)
    box(col, "OfficeWindow", x0 + 11.0, y0 + 3.6, 1.2, 0.1, 2.6, 1.3, window)
    box(col, "OfficeWindowS", x0 + 6.0, y0 - 0.05, 1.2, 2.2, 0.1, 1.2, window)
    box(col, "OfficeDoor", x0 + 11.0, y0 + 0.9, 0, 0.1, 1.3, 2.3, mat("door", "#3C2C20"))
    # Çatıda tabela (yazı Godot'ta)
    box(col, "OfficeSign", x0 + 2.0, y0 + 0.2, 4.2, 8.0, 0.3, 1.6, mat("sign_plate", "#C8902F", metal=0.3, rough=0.6))
    # Sundurma altında koltuk, masa, çaydanlık sobası; yanında köpek kulübesi
    box(col, "Armchair", x0 + 11.6, y0 + 4.6, 0, 1.0, 1.0, 0.9, mat("chair", "#7A3B32"), bevel=0.08)
    box(col, "Table", x0 + 11.7, y0 + 2.6, 0, 0.9, 1.2, 0.8, wood2)
    cyl(col, "Stove", x0 + 12.3, y0 + 6.3, 0.5, 0.35, 1.0, mat("dark_metal", "#33302D", metal=0.6, rough=0.5), verts=10)
    box(col, "DogHouse", x0 - 2.8, y0 + 5.0, 0, 1.7, 1.5, 1.2, wood)
    r = box(col, "DogHouseRoof", x0 - 3.0, y0 + 4.8, 1.2, 2.1, 1.9, 0.2, roof)


def plaza(col):
    """Meydan: günün 3 aracı (yer tutucu), 4 iş lambası, 2 ateş varili."""
    x0, y0, x1, y1 = PLAZA
    for i in range(3):
        cx = x0 + 4.0 + i * 8.0
        cy = (y0 + y1) / 2
        # Günün araçları (önizleme): paslı tekerleksiz kabuk (oyunda gerçek klasik model + pas gelir)
        pb = Builder("DailyCar_%d" % i, seed=i)
        # Burun güneye (kameraya): hurda mesh'lerinin önü +X (farlar ölçüldü), -90° → -Y
        wreck_into(pb, ("tofas_murat_124", "vw_beetle_1967", "chevrolet_bel_air_1956")[i], (0, 0, 0.05), -90)
        pb.finish(col, loc=(cx, cy, 0))
    light_post = mat("dark_metal", "#33302D", metal=0.6, rough=0.5)
    lamp = mat("work_lamp", "#FFF1C8", emit="#FFE2A0", strength=8.0)
    for i, (x, y) in enumerate([(x0 + 0.5, y0 + 0.5), (x1 - 0.5, y0 + 0.5), (x0 + 0.5, y1 - 0.5), (x1 - 0.5, y1 - 0.5)]):
        cyl(col, "LightPole_%d" % i, x, y, 3.5, 0.12, 7.0, light_post, verts=8)
        box(col, "LightHead_%d" % i, x - 0.5, y - 0.3, 6.9, 1.0, 0.6, 0.35, light_post)
        box(col, "LightGlow_%d" % i, x - 0.42, y - 0.22, 6.86, 0.84, 0.44, 0.05, lamp)
    for i, (x, y) in enumerate([(x0 - 1.5, y1 - 1.5), (x1 + 1.5, y0 + 1.5)]):
        fire_barrel(col, "FireBarrel_%d" % i, (x, y, 0), seed=i)


def mountains(col):
    """Arkadaki dev hurda dağları + araç kuleleri; aralarında kanyon geçitleri bırakılır."""
    specs = [
        # (ad, x, y, yarıçap, yükseklik, parça)
        ("MtNW", 4.0, 44.0, 9.0, 13.0, 110),
        ("MtN1", 19.0, 47.0, 8.0, 11.0, 90),
        ("MtN2", 35.0, 48.0, 9.5, 14.0, 115),
        ("MtNE", 52.0, 47.0, 7.5, 10.0, 80),
        ("MtW1", -1.0, 30.0, 7.0, 10.0, 75),
        ("MtW2", -2.0, 15.0, 8.0, 12.0, 90),
        ("MtSW", 2.0, 2.0, 6.0, 7.0, 50),
    ]
    for i, (name, x, y, r, h, n) in enumerate(specs):
        junk_pile(col, name, x, y, r, h, n, seed=300 + i)
    for i, (x, y, lv) in enumerate([(27.0, 41.5, 6), (44.0, 41.0, 5), (8.5, 22.5, 6), (60.0, 40.0, 4), (11.0, 36.0, 5)]):
        car_tower(col, "Tower_%d" % i, x, y, lv, seed=400 + i)


def search_piles(col):
    """Aranabilir hurda yığınları (6 yer; kaçı açık olacak — ekonomi simülasyonu)."""
    ring = mat("search_ring", "#F5BE4C", emit="#FFC94A", strength=3.0)
    spots = [(17.0, 26.0), (30.0, 33.0), (44.0, 34.5), (16.0, 9.0), (38.5, 30.0), (21.0, 37.5)]
    for i, (x, y) in enumerate(spots):
        junk_pile(col, "SearchPile_%d" % i, x, y, 2.3, 2.0, 16, seed=500 + i, shells=0.08)
        rb = Builder("SearchRing_%d" % i)
        for k in range(36):
            a0, a1 = math.tau * k / 36, math.tau * (k + 1) / 36
            if k % 3 == 2:
                continue   # kesik çizgi
            rb.tube([(math.cos(a0) * 2.9, math.sin(a0) * 2.9, 0.06), (math.cos(a1) * 2.9, math.sin(a1) * 2.9, 0.06)], 0.05, ring, segs=4)
        rb.finish(col, loc=(x, y, 0), ao=False)


def crane(col):
    """Mıknatıslı vinç: kafes direk, bom; mıknatıs HAVADA bir araba taşıyor (sallanma animasyonu Godot'ta)."""
    yellow = mat("crane_yellow", "#E0A81E", metal=0.25, rough=0.5)
    dark = mat("dark_metal", "#33302D", metal=0.6, rough=0.5)
    bx, by = 36.0, 38.5
    box(col, "CraneTracks", bx - 3.0, by - 2.2, 0, 6.0, 4.4, 1.0, dark, bevel=0.1)
    box(col, "CraneCab", bx - 2.0, by - 1.5, 1.0, 3.6, 3.0, 2.6, yellow, bevel=0.08)
    box(col, "CraneCabGlass", bx - 2.05, by - 1.2, 2.2, 0.1, 2.4, 1.2, mat("glass_dark", "#2C3A40", metal=0.4, rough=0.2))
    # Kafes direk: dört dikme + çaprazlar
    mh = 9.0
    for dx in (-0.45, 0.45):
        for dy in (-0.45, 0.45):
            box(col, "MastLeg_%d_%d" % (int(dx > 0), int(dy > 0)), bx + dx - 0.08, by + dy - 0.08, 3.6, 0.16, 0.16, mh, yellow)
    for k in range(6):
        z = 3.9 + k * 1.5
        o = box(col, "MastBrace_%d" % k, bx - 0.5, by - 0.5, z, 1.0, 0.1, 0.1, yellow)
        o.rotation_euler.y = math.radians(35 if k % 2 else -35)
    top = (bx, by, 3.6 + mh)
    tip = (bx - 9.5, by - 8.0, 3.6 + mh - 1.0)
    dx, dy, dz = tip[0] - top[0], tip[1] - top[1], tip[2] - top[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((top[0] + tip[0]) / 2, (top[1] + tip[1]) / 2, (top[2] + tip[2]) / 2))
    o = bpy.context.active_object
    o.name = "CraneBoom"
    o.scale = (0.7, length, 0.8)
    o.rotation_mode = 'ZXY'
    o.rotation_euler = (math.atan2(dz, math.hypot(dx, dy)), 0.0, math.atan2(-dx, dy))
    _link(col, o, yellow)
    cable_len = 4.2
    cyl(col, "CraneCable", tip[0], tip[1], tip[2] - cable_len / 2, 0.05, cable_len, dark, verts=6)
    mz = tip[2] - cable_len
    cyl(col, "CraneMagnet", tip[0], tip[1], mz - 0.25, 1.15, 0.5, dark, verts=20)
    # Mıknatısa yapışık, hafif eğik asılı araba
    car_shell(col, "CraneCar", tip[0], tip[1], mz - 1.75, 30, paint_mat(3), crush=1.0, pitch=8, roll=-6)


def press(col):
    """Araç presi + hidrolik pistonlar; yanında ezilmiş küp yığını (kıvılcım / duman Godot'ta)."""
    blue = mat("press_blue", "#3A6E9A", metal=0.35, rough=0.5)
    dark = mat("dark_metal", "#33302D", metal=0.6, rough=0.5)
    steel = mat("steel", "#8D8F91", metal=0.7, rough=0.45)
    x0, y0 = 49.0, 33.0
    box(col, "PressBed", x0, y0, 0, 10.0, 5.0, 1.6, dark, bevel=0.06)
    box(col, "PressFrameW", x0, y0, 1.6, 1.2, 5.0, 4.4, blue, bevel=0.05)
    box(col, "PressFrameE", x0 + 8.8, y0, 1.6, 1.2, 5.0, 4.4, blue, bevel=0.05)
    box(col, "PressTop", x0, y0, 6.0, 10.0, 5.0, 1.1, blue, bevel=0.05)
    for k, x in enumerate((x0 + 3.0, x0 + 7.0)):
        cyl(col, "PressPiston_%d" % k, x, y0 + 2.5, 5.0, 0.32, 2.2, steel, verts=12)
    box(col, "PressRam", x0 + 1.4, y0 + 0.5, 3.6, 7.2, 4.0, 0.7, dark)
    car_shell(col, "PressedCar", x0 + 5.0, y0 + 2.5, 1.65, 0, rust_mat(2), crush=0.35, cabin=False)
    tints = list(range(9))
    k = 0
    for row in range(2):
        for cx in range(3):
            for lvl in range(3 if (row + cx) % 2 == 0 else 2):
                m = paint_mat(k) if k % 3 else rust_mat(k)
                box(col, "Cube_%d" % k, x0 + 0.5 + cx * 1.6, y0 - 4.2 + row * 1.6, lvl * 1.4, 1.4, 1.4, 1.4, m,
                    rot=RNG.uniform(-12, 12), bevel=0.08)
                k += 1


def containers(col):
    """Kuzeydoğu köşesinde birkaç paslı konteyner (orijinaldeki gibi), dağların arasında."""
    colors = ["#2F6E8C", "#A8432F", "#3F7A45", "#B9852E"]
    for i, (x, y, lvl, rot) in enumerate([(55.0, 42.0, 0, 0), (55.3, 42.1, 1, 4), (60.5, 34.0, 0, 90), (-4.0, 6.5, 0, 90)]):
        c = mat("cont_%d" % i, colors[i % len(colors)], metal=0.35, rough=0.6)
        box(col, "Container_%d" % i, x, y, lvl * 2.6, 12.0 if rot == 0 else 2.5, 2.5 if rot == 0 else 12.0, 2.6, c, bevel=0.04)


def scatter(col):
    """Meydan çevresine dağınık süsleme: lastik kuleleri, motor blokları, jant yığını, devrik araç."""
    tire = mat("tire", "#1E1E1E", rough=0.95)
    engine = mat("engine", "#55524D", metal=0.6, rough=0.5)
    steel = mat("steel", "#8D8F91", metal=0.7, rough=0.45)
    for i, (x, y, n) in enumerate([(19.5, 14.0, 5), (47.0, 21.0, 4), (58.5, 18.0, 6), (12.5, 31.0, 4)]):
        for k in range(n):
            cyl(col, "Tire_%d_%d" % (i, k), x + RNG.uniform(-0.1, 0.1), y + RNG.uniform(-0.1, 0.1), 0.18 + k * 0.3,
                0.45, 0.28, tire, verts=14)
    for i, (x, y) in enumerate([(25.0, 30.5), (44.5, 10.0), (13.0, 16.0)]):
        box(col, "Engine_%d" % i, x, y, 0, 1.2, 0.9, 0.9, engine, rot=RNG.uniform(0, 90), bevel=0.06)
    for k in range(5):
        cyl(col, "Rim_%d" % k, 34.0, 9.0, 0.1 + k * 0.19, 0.36, 0.17, steel, verts=14)
    # Devrik araç (tepetaklak), meydan kıyısında
    car_shell(col, "FlippedCar", 15.0, 22.0, 1.25, 25, paint_mat(5), crush=0.9, roll=180)
    bush = mat("dry_bush", "#8C834A", rough=1.0)
    for i, (x, y) in enumerate([(31.0, -3.5), (-4.0, -4.0), (70.0, 4.0), (72.0, 28.0), (40.0, -6.0), (8.0, -5.0)]):
        mound(col, "Bush_%d" % i, x, y, 0.9, 0.8, 0.7, bush, seed=200 + i)


def hills(col):
    terrain(col, W, D)


def camera_and_light(scn, col):
    # Oyun kamerası: ortografik, güneydoğudan 45°, 25° yukarıdan; açılışta yatay ~41 m
    cam_data = bpy.data.cameras.get("JY_Cam") or bpy.data.cameras.new("JY_Cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 41.0
    cam_data.clip_end = 1000.0
    cam = bpy.data.objects.get("JY_Camera") or bpy.data.objects.new("JY_Camera", cam_data)
    if cam.name not in col.objects:
        for c in list(cam.users_collection):
            c.objects.unlink(cam)
        col.objects.link(cam)
    focus = (W * 0.62, D * 0.36, 0.0)   # açılış: giriş + meydan (sağ ön)
    yaw, pitch, dist = math.radians(45.0), math.radians(25.0), 150.0
    d = (math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    cam.location = (focus[0] + d[0] * dist, focus[1] + d[1] * dist, focus[2] + d[2] * dist)
    cam.rotation_euler = (math.radians(90) - pitch, 0.0, yaw)
    scn.camera = cam
    scn.render.resolution_x = 1280
    scn.render.resolution_y = 720
    # Alçak altın güneş: batı-güneybatıdan, uzun gölgeler kameraya doğru (sağ-aşağı) düşer
    sun_data = bpy.data.lights.get("JY_Sun") or bpy.data.lights.new("JY_Sun", 'SUN')
    sun_data.energy = 5.2
    sun_data.color = srgb("#FFE2BC")
    sun_data.angle = math.radians(2.5)
    sun = bpy.data.objects.get("JY_SunObj") or bpy.data.objects.new("JY_SunObj", sun_data)
    if sun.name not in col.objects:
        for c in list(sun.users_collection):
            c.objects.unlink(sun)
        col.objects.link(sun)
    sun.rotation_euler = (math.radians(68), 0.0, math.radians(-115))
    world = scn.world or bpy.data.worlds.new("JY_World")
    scn.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == 'BACKGROUND'), None)
    if bg:
        c = srgb("#AEB4B8")   # soluk, tozlu gökyüzü: gölgeler serin, güneş sıcak (turuncu–camgöbeği karşıtlığı)
        bg.inputs["Color"].default_value = (c[0], c[1], c[2], 1.0)
        bg.inputs["Strength"].default_value = 0.85
    try:
        scn.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass


def layout_v3(col):
    """Orijinal Car Town hurdalığına benzeyen yerleşim (bkz. modül açıklaması)."""
    # Yakın kenarlar: oluklu sac çit (güney tam, doğu kapı aralığı hariç)
    fence_run(col, "FenceS", (0.0, 0.0), (W, 0.0), seed=1)
    fence_run(col, "FenceE1", (W, 0.0), (W, GATE[0]), seed=2)
    fence_run(col, "FenceE2", (W, GATE[1]), (W, D), seed=3)
    gate(col)
    # Necati'nin barakası: güneydoğu iç köşe, ön cephe (+X) girişe / kameraya
    # Necati'nin barakası: girişin güneyinde, güney çitinden 6 m içeride (2,3 m'lik çit 25° bakışta ~5 m'yi
    # gizler); ön cephe + veranda + tabela güneye, kameraya. Kemer doğuda, kuzeyde → ekranda barakayı örtmez.
    shack_v2(col, "Shack", loc=(53.0, 11.5, 0), rot=0.0)
    water_tower(col, "WaterTower", (43.6, 6.6, 0))
    db = Builder("DogHouse")
    dw = k_mat("shack_wood", "#6B4A30", rough=0.9)
    droof = k_mat("roof_rust", "#7A4A2E", rough=0.9, metal=0.15)
    db.box((0, 0, 0.55), (1.5, 1.3, 1.1), dw)
    for sx in (-1, 1):
        db.box((sx * 0.42, 0, 1.25), (0.95, 1.5, 0.08), droof, rot=(0, sx * 30, 0))
    db.box((0, -0.66, 0.4), (0.55, 0.04, 0.7), k_mat("frame_dark", "#2E2622", rough=0.8, metal=0.5))
    db.cyl((0.9, -0.5, 0.06), 0.18, 0.1, k_mat("dog_bowl", "#A8342A", rough=0.6), segs=12)
    db.finish(col, loc=(47.2, 4.6, 0), rot=(0, 0, 10))
    # Karakterler: Necati verandadaki bankta (çay bardağıyla), Cemo meydanın kıyısında, köpek kulübesinin önünde
    # Bank: barakanın yerel (2,4; -4,55), oturak üstü z = 0,45 + 0,25 + 0,175
    # Necati merdivenin yanında, yerde, tabelanın ÖNÜNDE (sundurma altında tabela başını örtüyordu); kameraya dönük.
    # Güney çiti onu örtmez: bakış çapraz (45°), çite uzaklık bakış yönünde ~6,5 m.
    necati_standing(col, "Necati", loc=(52.6, 4.5, 0.0), rot=-60.0)
    # Tabela yazıları (önizleme; oyunda Label3D)
    preview_text(col, "SignText_Shack", "HURDACI NECATİ", (53.0, 11.5 - 6.43, 3.52), (90, 0, 0), 0.72)
    preview_text(col, "SignText_Gate", "HURDALIK", (W + 0.36, (GATE[0] + GATE[1]) / 2, 5.85), (90, 0, 90), 1.0, "#7A2A20")
    cemo(col, "Cemo", loc=(35.6, 27.4, 0.0), rot=-55.0)
    guard_dog(col, "Dog", loc=(47.4, 3.4, 0.0), rot=-70.0)
    tire_stack(col, "ShackTires", 4, loc=(61.0, 9.0, 0), seed=5)
    car_tower(col, "TowerNE", 61.0, 31.5, 4, seed=411)
    # Arka kenar: iki katlı konteyner duvarı + önünde hurda dolu açık kasalar
    colors = ["#4E6B45", "#7B3328", "#3F5E73", "#6B6258", "#8A6A2E"]
    x = 1.0
    i = 0
    while x < W - 6:
        container(col, "WallCont_%d" % i, colors[i % len(colors)], loc=(x + 6.0, D - 1.6, 0), rot=(0, 0, 0))
        if i % 3 != 1:
            container(col, "WallContTop_%d" % i, colors[(i + 2) % len(colors)], loc=(x + 6.4, D - 1.5, 2.6), rot=(0, 0, 1.5))
        x += 12.3
        i += 1
    for k, (bx, by, c) in enumerate([(14.0, D - 5.4, "#7B3328"), (30.0, D - 5.6, "#4E6B45"), (44.0, D - 5.4, "#3F5E73")]):
        scrap_bin(col, "ScrapBin_%d" % k, c, length=6.0, loc=(bx, by, 0), rot=RNG.uniform(-6, 6), seed=k + 10)
    # Orta arka: jant kapaklı duvar + lastik yığınları; yanında vinç (kanca hurda tepesinin üstünde)
    hubcap_wall(col, "HubcapWall", length=9.0, loc=(22.0, 36.5, 0), rot=0.0)
    for k, (tx, ty, n) in enumerate([(18.4, 34.5, 5), (19.6, 34.0, 4), (25.5, 34.3, 6), (27.0, 35.0, 3)]):
        tire_stack(col, "WallTires_%d" % k, n, loc=(tx, ty, 0), seed=20 + k)
    magnet_crane(col, "Crane", loc=(36.0, 37.0, 0), rot=0.0, boom_yaw=-150.0, boom_len=11.0, boom_pitch=36.0)
    junk_pile(col, "CraneHill", 28.5, 31.5, 3.6, 3.0, 26, seed=77)
    # Kuzeydoğu: pres + ezilmiş küpler
    car_press(col, "Press", loc=(52.0, 40.5, 0), rot=0.0)
    cb = Builder("PressCubes", seed=41)
    k = 0
    for row in range(2):
        for cx in range(3):
            for lvl in range(3 if (row + cx) % 2 == 0 else 2):
                crushed_cube(cb, k * 7 + 3, (59.6 + cx * 1.55, 36.1 + row * 1.6, lvl * 1.42), 1.4, yaw=RNG.uniform(-12, 12))
                k += 1
    cb.finish(col)
    # Batı: dev hurda dağları + araç kuleleri (Mad Max)
    for i, (name, x, y, r, h, n) in enumerate([("MtNW", 3.0, 41.0, 8.0, 12.0, 50), ("MtW1", -1.0, 27.0, 7.0, 10.0, 38),
                                               ("MtW2", -2.0, 13.0, 7.5, 11.0, 42), ("MtSW", 1.0, 2.0, 5.5, 6.5, 24)]):
        junk_pile(col, name, x, y, r, h, n, seed=300 + i)
    for i, (x, y, lv) in enumerate([(9.0, 33.5, 6), (8.0, 20.0, 5), (61.0, 44.0, 4), (40.0, 44.0, 5)]):
        car_tower(col, "Tower_%d" % i, x, y, lv, seed=400 + i)
    # Batıda yerde yatan tekerleksiz araç iskeletleri (orijinaldeki jip şasileri)
    for i, (x, y, yaw) in enumerate([(14.5, 24.5, 35), (15.5, 16.0, -20), (18.5, 8.5, 70)]):
        chassis(col, "Wreck_%d" % i, loc=(x, y, 0), rot=(0, 0, yaw), rust=1.0, seed=i)
    # Meydan + günün 3 aracı + iş lambaları + ateş varilleri
    plaza(col)
    # Sokak lambaları (orijinaldeki gibi) güney çit boyunca ve meydanda
    for i, x in enumerate((8.0, 22.0, 36.0)):
        street_lamp(col, "StreetLamp_%d" % i, loc=(x, 1.2, 0), rot=90.0)
    search_piles(col)
    # Barakanın önünde paslı bir klasik (orijinaldeki paslı Cobra gibi) — yer tutucu kabuk
    b = Builder("RustyClassic")
    wreck_into(b, "anadol_a1", (0, 0, 0.05), 0)
    b.finish(col, loc=(37.5, 8.0, 0), rot=(0, 0, -40))   # burun güneydoğuya (kameraya)
    scatter_v3(col)


def scatter_v3(col):
    tire = mat("tire", "#1E1E1E", rough=0.95)
    engine = mat("engine", "#55524D", metal=0.6, rough=0.5)
    for i, (x, y, n) in enumerate([(19.5, 13.0, 5), (47.5, 22.0, 4), (12.5, 29.0, 4)]):
        tire_stack(col, "Tires_%d" % i, n, loc=(x, y, 0), seed=60 + i)
    for i, (x, y) in enumerate([(25.0, 30.0), (44.5, 9.0), (13.0, 12.0)]):
        box(col, "Engine_%d" % i, x, y, 0, 1.2, 0.9, 0.9, engine, rot=RNG.uniform(0, 90), bevel=0.06)
    bush = mat("dry_bush", "#8C834A", rough=1.0)
    for i, (x, y) in enumerate([(31.0, -3.5), (-4.0, -4.0), (70.0, 4.0), (72.0, 28.0), (40.0, -6.0), (8.0, -5.0)]):
        mound(col, "Bush_%d" % i, x, y, 0.9, 0.8, 0.7, bush, seed=200 + i)


# Oyunda AYRI kalması gerekenler (hareket / etkileşim / çalışma anında değişen): ad öneki
KEEP_SEPARATE = ("SearchPile_", "SearchRing_", "DailyCar_", "Crane_Hook", "Press_Ram", "Necati", "Cemo", "Dog",
                 "FireBarrel_", "Ground", "Terrain", "SignText_", "JY_Camera", "JY_SunObj")


def merge_static(col, cells=(3, 3)):
    """Hareketsiz nesneleri bölge bölge (saha 3×3 + dış alan) birleştirir: oyunda az düğüm, az çizim çağrısı;
    bölgeler yine de kamera dışı kalınca ayıklanabilir (frustum culling) ve LOD bölge başına seçilir."""
    groups = {}
    heavy = sorted(((sum(len(p.vertices) - 2 for p in o.data.polygons), o.name) for o in col.objects if o.type == 'MESH'),
                   reverse=True)[:14]
    print("AGIR", " · ".join("%s %d" % (n, t) for t, n in heavy))
    for o in list(col.objects):
        if o.type != 'MESH' or o.name.startswith(KEEP_SEPARATE):
            continue
        from mathutils import Vector
        c = sum((o.matrix_world @ Vector(v) for v in o.bound_box), Vector()) / 8.0
        if 0 <= c.x <= W and 0 <= c.y <= D:
            key = "Static_%d_%d" % (min(cells[0] - 1, int(c.x / (W / cells[0]))), min(cells[1] - 1, int(c.y / (D / cells[1]))))
        else:
            key = "Static_Outer"
        groups.setdefault(key, []).append(o)
    for key, objs in groups.items():
        for o in objs:
            for mod in list(o.modifiers):
                bpy.context.view_layer.objects.active = o
                bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        out = bpy.context.view_layer.objects.active
        out.name = key
        out["jy_vc"] = True
        # Aynı yüzey materyalinin birden çok yuvası tek yuvada toplansın
        me = out.data
        first = {}
        remap = []
        for i, m in enumerate(me.materials):
            if m.name not in first:
                first[m.name] = i
            remap.append(first[m.name])
        if len(first) < len(me.materials):
            for p in me.polygons:
                p.material_index = remap[p.material_index]
            bpy.context.view_layer.objects.active = out
            out.select_set(True)
            bpy.ops.object.material_slot_remove_unused()


def build():
    scn, col = use_scene()
    ground(col)
    layout_v3(col)
    hills(col)
    postprocess(col)
    merge_static(col)
    camera_and_light(scn, col)
    print("Junkyard: %d nesne" % len(col.objects))

build()
