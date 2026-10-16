"""DEKORASYON v5 — OFİS partisi: garajın içine bir ofis kurmak için 16 eşya (yere konan 12, duvara asılan 4).

Ofisin çekirdeği: çalışma masası (çift monitör + ofis koltuğu), dosya dolabı, kitaplık, misafir koltukları,
toplantı masası, karşılama bankosu. Ofis hayatı: fotokopi, kahve köşesi, sunum panosu, ayaklı lamba.
Garaja özgü dokunuş: çizim masasında araba projesi, çelik kasada deste deste para, dünya haritasında araç
ithalat rotaları. Duvar: beyaz tahta, belge çerçeveleri, dünya haritası, klima.

Oyun kamerası uzak ve yukarıda: masa üstleri dolu (ekran, klavye, kupa, kâğıt) ve ışık veren parçalar
(monitör, lamba, bankonun AUTO YARD yazısı) eşyayı ilk bakışta okutur. Dünyada ortam ışığı ve yansıma yok:
metaller düşük metallik çizilir (tam metal koyu çıkar, bkz. props_v4_luks.py).

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası; duvar eşyasının arka yüzü
duvara (+Y) yaslanır. Yazılar dilden bağımsız (rakam, kurgusal marka AUTO YARD).
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v5_ofis.py
"""
import math as _m

import bmesh
import mathutils

R90 = _m.radians(90)

# --- Malzemeler ---------------------------------------------------------------------------
DARK = mat("Koyu", (0.045, 0.048, 0.055), 0.6)
GRAPHITE = mat("Grafit", (0.13, 0.14, 0.16), 0.5, 0.2)
GREY_M = mat("DolapGri", (0.42, 0.44, 0.46), 0.45, 0.25)
GREY_L = mat("AcikGri", (0.58, 0.60, 0.62), 0.45, 0.2)
CHROME = mat("Krom", (0.78, 0.80, 0.84), 0.12, 0.3)
WHITE = mat("Beyaz", (0.88, 0.88, 0.86), 0.45)
IVORY = mat("Fildisi", (0.82, 0.79, 0.72), 0.5)
PAPER = mat("Kagit", (0.95, 0.95, 0.92), 0.8)
CREAM_P = mat("BelgeKagidi", (0.93, 0.88, 0.74), 0.8)
OAK = mat("Mese", (0.55, 0.36, 0.18), 0.6)
OAK_D = mat("KoyuMese", (0.38, 0.23, 0.10), 0.6)
WALNUT = mat("Ceviz", (0.22, 0.11, 0.05), 0.5)
LEATHER_K = mat("SiyahDeri", (0.035, 0.035, 0.04), 0.45)
MESH_K = mat("FileSirt", (0.07, 0.075, 0.085), 0.85)
FABRIC_T = mat("KumasPetrol", (0.03, 0.26, 0.30), 0.95)
FABRIC_M = mat("KumasHardal", (0.72, 0.42, 0.06), 0.95)
SAFE_G = mat("KasaYesili", (0.05, 0.16, 0.11), 0.4, 0.2)
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
BRASS = mat("Pirinc", (0.78, 0.58, 0.22), 0.3, 0.3)
RED = mat("Kirmizi", (0.62, 0.05, 0.05), 0.45)
BLUE = mat("Mavi", (0.05, 0.22, 0.60), 0.45)
YEL = mat("Sari", (0.92, 0.70, 0.06), 0.5)
GREEN = mat("Yesil", (0.06, 0.40, 0.16), 0.5)
ORANGE = mat("Turuncu", (0.90, 0.38, 0.05), 0.5)
PINK = mat("Pembe", (0.95, 0.40, 0.60), 0.6)
LIME = mat("FistikYesili", (0.55, 0.85, 0.25), 0.6)
CASH = mat("Banknot", (0.36, 0.58, 0.30), 0.8)
LEAF = mat("Yaprak", (0.10, 0.40, 0.12), 0.7)
SOIL = mat("Toprak", (0.12, 0.07, 0.04), 0.95)
TERRA = mat("Pismis", (0.62, 0.28, 0.14), 0.8)
COFFEE = mat("Kahve", (0.16, 0.08, 0.03), 0.3)
BEANS = mat("KahveCekirdegi", (0.25, 0.12, 0.05), 0.6)
GLASS = mat("Cam", (0.80, 0.90, 0.97), 0.05, 0.1, alpha=0.30)
WATER_B = mat("SuSisesi", (0.55, 0.80, 0.95), 0.05, 0.0, alpha=0.45)
SCREEN = mat("Ekran", (0.10, 0.30, 0.60), 0.3, emit=(0.12, 0.38, 0.85))
SCREEN_L = mat("EkranSatir", (0.70, 0.85, 1.0), 0.3, emit=(0.55, 0.75, 1.0))
SCREEN_O = mat("EkranTuruncu", (1.0, 0.55, 0.15), 0.3, emit=(0.95, 0.45, 0.08))
WARM = mat("SicakIsik", (1.0, 0.86, 0.55), 0.2, emit=(1.0, 0.78, 0.40))
N_ORANGE = mat("NeonTuruncu", (1.0, 0.45, 0.1), 0.3, emit=(1.0, 0.40, 0.08))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
LED_G = mat("LedYesil", (0.2, 1.0, 0.3), 0.3, emit=(0.15, 1.0, 0.25))
LED_R = mat("LedKirmizi", (1.0, 0.15, 0.1), 0.3, emit=(1.0, 0.1, 0.08))
BLUEPRINT = mat("Proje", (0.07, 0.24, 0.58), 0.7, emit=(0.02, 0.07, 0.18))
INK_W = mat("ProjeCizgi", (0.92, 0.96, 1.0), 0.5, emit=(0.45, 0.50, 0.55))
OCEAN = mat("Okyanus", (0.16, 0.42, 0.66), 0.7)
LAND = mat("Kara", (0.86, 0.76, 0.48), 0.8)
LAND_G = mat("YesilKara", (0.40, 0.60, 0.28), 0.8)
CORK = mat("Mantar", (0.50, 0.34, 0.18), 0.95)
MARBLE = mat("Mermer", (0.93, 0.92, 0.89), 0.18)


# --- Yardımcılar --------------------------------------------------------------------------

def mesh_obj(verts, faces, material, smooth=False):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        face = bm.faces.new([vs[i] for i in f])
        face.smooth = smooth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("parca")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("parca", me)
    col().objects.link(o)
    return _place(o, material)


def lathe(profile, material, loc=(0.0, 0.0, 0.0), seg=16, smooth=True):
    """(yarıçap, yükseklik) dış hattını Z ekseni etrafında döndürür (kupa, kettle, saksı)."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for k in range(seg):
            a = 2.0 * _m.pi * k / seg
            ring.append(bm.verts.new((loc[0] + r * _m.cos(a), loc[1] + r * _m.sin(a), loc[2] + z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
            f.smooth = smooth
    if profile[0][0] > 0.0:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0.0:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("torna")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("torna", me)
    col().objects.link(o)
    return _place(o, material)


def rod(p0, p1, r, material, seg=6):
    """İki nokta arasında silindir (ayak, kol, ip)."""
    a = mathutils.Vector(p0)
    b = mathutils.Vector(p1)
    d = b - a
    rot = mathutils.Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_euler()
    return cyl(r, d.length, tuple((a + b) * 0.5), material, rot=tuple(rot), seg=seg)


def text(body, size, loc, material, depth=0.012):
    """Ön yüze (−Y) bakan yazı; konum yazının ORTASI."""
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.object
    t.data.body = body
    t.data.size = size
    t.data.extrude = depth
    t.data.resolution_u = 3
    t.data.align_x = 'CENTER'
    t.data.align_y = 'CENTER'
    t.rotation_euler = (R90, 0, 0)
    t.location = loc
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _place(o, material)


def frame(w, h, y, material, t=0.03, d=0.03, z0=0.0, x0=0.0):
    """Ön yüzü −Y'ye bakan çerçeve (x genişlik, z yükseklik), merkezi (x0, z0)."""
    box((w, d, t), (x0, y, z0 + h / 2 - t / 2), material)
    box((w, d, t), (x0, y, z0 - h / 2 + t / 2), material)
    box((t, d, h), (x0 - w / 2 + t / 2, y, z0), material)
    box((t, d, h), (x0 + w / 2 - t / 2, y, z0), material)


def local(build, loc=(0.0, 0.0, 0.0), yaw=0.0, tilt=0.0):
    """build() içinde kurulan parçaları birlikte taşır: önce X ekseninde `tilt`, sonra Z'de `yaw`, sonra `loc`.
    Parçalar kendi yerel düzenlerinde çizilir (koltuk −Y'ye bakar, eğik pano XY düzleminde yatar)."""
    before = {o.name for o in col().objects}
    build()
    m = mathutils.Matrix.Translation(loc) @ mathutils.Matrix.Rotation(yaw, 4, 'Z') \
        @ mathutils.Matrix.Rotation(tilt, 4, 'X')
    for o in col().objects:
        if o.name not in before:
            o.matrix_world = m @ o.matrix_world


def stroke(p, q, w, z, material, h=0.003):
    """Yatay düzlemde (XY) p→q ince şerit: çizim / grafik çizgisi (local() ile panoya yatırılır)."""
    dx, dy = q[0] - p[0], q[1] - p[1]
    length = _m.hypot(dx, dy)
    box((length + w, w, h), ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, z), material, rot=(0, 0, _m.atan2(dy, dx)))


def wall_stroke(p, q, w, y, material, d=0.006):
    """Duvar düzleminde (XZ) p→q ince şerit: tahtadaki grafik çizgisi, haritadaki ip."""
    dx, dz = q[0] - p[0], q[1] - p[1]
    length = _m.hypot(dx, dz)
    box((length + w * 0.5, d, w), ((p[0] + q[0]) / 2, y, (p[1] + q[1]) / 2), material, rot=(0, -_m.atan2(dz, dx), 0))


def office_chair(back_h=0.58, seat=LEATHER_K, back=MESH_K, arms=True):
    """Tekerlekli ofis koltuğu, yerel düzende −Y'ye bakar (sırt +Y'de). local() ile yerleştirilir."""
    for k in range(5):
        a = 2.0 * _m.pi * k / 5 + R90
        p = (0.27 * _m.cos(a), 0.27 * _m.sin(a))
        rod((0.0, 0.0, 0.09), (p[0], p[1], 0.065), 0.02, GRAPHITE)
        cyl(0.028, 0.03, (p[0], p[1], 0.028), DARK, rot=(R90, 0, a), seg=6)
    cyl(0.05, 0.06, (0, 0, 0.10), GRAPHITE, seg=8)
    cyl(0.026, 0.30, (0, 0, 0.27), CHROME, seg=8)
    box((0.52, 0.50, 0.08), (0, -0.01, 0.45), seat)
    box((0.06, 0.05, 0.26), (0, 0.24, 0.52), GRAPHITE)
    box((0.50, 0.06, back_h), (0, 0.27 + 0.06 * back_h, 0.58 + back_h / 2), back, rot=(-0.12, 0, 0))
    box((0.52, 0.07, 0.05), (0, 0.27 + 0.12 * back_h, 0.58 + back_h), seat, rot=(-0.12, 0, 0))
    if arms:
        for s in (-1, 1):
            box((0.035, 0.035, 0.20), (s * 0.27, 0.04, 0.57), GRAPHITE)
            box((0.07, 0.28, 0.03), (s * 0.27, 0.01, 0.68), DARK)


def mug(x, y, z, material, r=0.04, h=0.09, coffee=True):
    cyl(r, h, (x, y, z + h / 2), material, seg=10)
    if coffee:
        cyl(r * 0.85, 0.004, (x, y, z + h - 0.008), COFFEE, seg=10)
    torus(0.025, 0.007, (x + r + 0.012, y, z + h * 0.55), material, rot=(R90, 0, 0), seg=8, mseg=4)


def potted_plant(x, y, z, s=1.0):
    lathe([(0.05 * s, 0.0), (0.07 * s, 0.11 * s), (0.075 * s, 0.12 * s), (0.0, 0.12 * s)], TERRA,
          loc=(x, y, z), seg=10, smooth=False)
    for (dx, dy, dz, r) in ((0.0, 0.0, 0.20, 0.07), (0.05, 0.02, 0.17, 0.05), (-0.04, -0.03, 0.18, 0.05),
                            (0.01, -0.04, 0.25, 0.045)):
        ball(r * s, (x + dx * s, y + dy * s, z + dz * s), LEAF, seg=7, ring=5)


def monitor(x, y, z, yaw=0.0, w=0.60, h=0.36, chart=True):
    """Ayaklı monitör: ekran −Y'ye bakar. Ekranda satırlar ve küçük çubuk grafik."""
    def build():
        box((0.20, 0.14, 0.015), (0, 0.03, 0.0075), GRAPHITE)
        box((0.04, 0.03, 0.22), (0, 0.06, 0.12), GRAPHITE)
        box((w, 0.03, h), (0, 0.035, 0.14 + h / 2), DARK)
        box((w - 0.03, 0.006, h - 0.03), (0, 0.018, 0.14 + h / 2), SCREEN)
        for i in range(4):
            box((w * (0.42 - 0.06 * (i % 2)), 0.004, 0.018), (-w * 0.20, 0.013, 0.14 + h * 0.78 - i * 0.05), SCREEN_L)
        if chart:
            for i, bh in enumerate((0.06, 0.10, 0.08, 0.15)):
                box((0.035, 0.004, bh), (w * 0.12 + i * 0.05, 0.013, 0.14 + 0.05 + bh / 2), SCREEN_O)
    local(build, loc=(x, y, z), yaw=yaw)


def armchair(fabric, x, y, yaw):
    def build():
        for sx in (-0.30, 0.30):
            for sy in (-0.28, 0.28):
                cone(0.025, 0.018, 0.09, (sx, sy, 0.045), WALNUT, seg=6)
        box((0.74, 0.70, 0.30), (0, 0, 0.24), fabric)
        box((0.56, 0.56, 0.11), (0, -0.04, 0.445), fabric)
        box((0.74, 0.18, 0.46), (0, 0.26, 0.62), fabric, rot=(-0.10, 0, 0))
        for s in (-1, 1):
            box((0.10, 0.68, 0.22), (s * 0.32, 0.0, 0.50), fabric)
            cyl(0.05, 0.68, (s * 0.32, 0.0, 0.61), fabric, rot=(R90, 0, 0), seg=8)
    local(build, loc=(x, y, 0.0), yaw=yaw)


# ================================================================ 1) ÇALIŞMA MASASI (çift monitör + koltuk)
clear()
box((1.50, 0.75, 0.04), (0, 0, 0.74), OAK)                                # tabla
box((0.04, 0.68, 0.72), (-0.70, 0, 0.36), WHITE)                         # sol ayak paneli
box((0.42, 0.64, 0.70), (0.50, 0.0, 0.37), WHITE)                        # çekmeceli ayak
for k in range(3):
    box((0.38, 0.015, 0.18), (0.50, -0.325, 0.15 + k * 0.205), GREY_L)
    box((0.12, 0.02, 0.02), (0.50, -0.34, 0.20 + k * 0.205), GRAPHITE)
box((1.36, 0.03, 0.38), (0, 0.345, 0.52), WHITE)                         # arka panel
monitor(-0.29, 0.20, 0.76, yaw=0.20, w=0.56)                            # kullanıcıya dönük
monitor(0.29, 0.20, 0.76, yaw=-0.20, w=0.56, chart=False)
box((0.44, 0.15, 0.02), (0, -0.10, 0.77), GRAPHITE)                      # klavye
box((0.41, 0.12, 0.006), (0, -0.10, 0.782), GREY_L)
ball(0.03, (0.30, -0.12, 0.77), GRAPHITE, scale=(0.8, 1.2, 0.5), seg=8, ring=4)   # fare
mug(0.52, -0.05, 0.76, RED)
box((0.22, 0.30, 0.012), (-0.54, -0.08, 0.766), PAPER, rot=(0, 0, 0.15))  # kâğıtlar
box((0.22, 0.30, 0.012), (-0.52, -0.06, 0.778), YEL, rot=(0, 0, 0.05))    # sarı dosya
box((0.21, 0.29, 0.006), (-0.52, -0.06, 0.787), PAPER, rot=(0, 0, 0.05))
box((0.17, 0.19, 0.04), (0.60, -0.16, 0.78), GRAPHITE, rot=(0, 0, -0.25))   # masa telefonu
box((0.05, 0.19, 0.035), (0.545, -0.145, 0.815), DARK, rot=(0, 0, -0.25))
box((0.07, 0.04, 0.005), (0.625, -0.20, 0.802), SCREEN_L, rot=(0, 0, -0.25))
potted_plant(-0.66, 0.28, 0.76, 0.7)
local(lambda: office_chair(), loc=(0.08, -0.66, 0.0), yaw=_m.pi - 0.35)  # koltuk masaya dönük, biraz açılı
finish("office_desk")

# ================================================================ 2) DOSYA DOLABI (üst çekmece açık)
clear()
box((0.47, 0.62, 1.32), (0, 0, 0.66), GREY_M)
for k in range(4):
    z = 0.17 + k * 0.32
    if k == 3:
        continue
    box((0.43, 0.015, 0.29), (0, -0.318, z), GREY_L)
    box((0.16, 0.03, 0.025), (0, -0.335, z + 0.05), CHROME)
    box((0.08, 0.004, 0.045), (0, -0.327, z + 0.10), PAPER)
z = 0.17 + 3 * 0.32                                                       # üst çekmece dışarıda
box((0.43, 0.015, 0.29), (0, -0.60, z), GREY_L)
box((0.16, 0.03, 0.025), (0, -0.617, z + 0.05), CHROME)
box((0.08, 0.004, 0.045), (0, -0.609, z + 0.10), PAPER)
box((0.43, 0.012, 0.29), (0, -0.318, z), DARK)                           # boşalan göz
for s in (-1, 1):
    box((0.015, 0.28, 0.22), (s * 0.205, -0.46, z - 0.02), GREY_L)
box((0.42, 0.28, 0.015), (0, -0.46, z - 0.13), GREY_L)
folder_mats = (RED, BLUE, YEL, GREEN, ORANGE, BLUE, RED, YEL)
for i, m in enumerate(folder_mats):
    fy = -0.575 + i * 0.033
    box((0.38, 0.010, 0.22), (0, fy, z - 0.01), m)
    box((0.07, 0.010, 0.035), (-0.12 + (i % 4) * 0.08, fy, z + 0.11), m)
for k in range(2):                                                        # üstte iki katlı evrak rafı
    box((0.30, 0.36, 0.012), (-0.05, 0.05, 1.335 + k * 0.08), GRAPHITE)
    box((0.26, 0.32, 0.02), (-0.05, 0.03, 1.355 + k * 0.08), PAPER)
for sx in (-0.19, 0.09):
    box((0.01, 0.36, 0.16), (sx, 0.05, 1.40), GRAPHITE)
potted_plant(0.14, -0.20, 1.32, 0.75)
finish("filing_cabinet")

# ================================================================ 3) KİTAPLIK
clear()
for s in (-1, 1):
    box((0.03, 0.36, 1.90), (s * 0.485, 0, 0.95), WALNUT)
box((1.00, 0.36, 0.03), (0, 0, 1.885), WALNUT)
box((0.94, 0.34, 0.08), (0, 0, 0.04), WALNUT)
box((0.94, 0.02, 1.82), (0, 0.17, 0.95), OAK_D)
for zs in (0.62, 0.98, 1.30, 1.60):
    box((0.94, 0.33, 0.025), (0, 0, zs), WALNUT)
for s in (-1, 1):                                                          # alt dolap kapakları
    box((0.455, 0.02, 0.52), (s * 0.235, -0.17, 0.35), OAK)
    cyl(0.015, 0.03, (s * 0.04, -0.19, 0.42), BRASS, rot=(R90, 0, 0), seg=6)
binders = (RED, BLUE, BLUE, YEL, GREEN, RED, BLUE)                        # 1. raf: klasörler
for i, m in enumerate(binders):
    x = -0.42 + i * 0.075
    box((0.068, 0.28, 0.31), (x, 0.0, 0.635 + 0.155), m)
    box((0.04, 0.006, 0.07), (x, -0.142, 0.635 + 0.20), PAPER)
    torus(0.012, 0.004, (x, -0.142, 0.635 + 0.07), DARK, rot=(R90, 0, 0), seg=6, mseg=3)
box((0.30, 0.26, 0.24), (0.27, 0.0, 0.635 + 0.12), GREY_L)                # arşiv kutusu
box((0.10, 0.004, 0.05), (0.27, -0.131, 0.635 + 0.15), PAPER)
book_mats = (RED, OAK_D, BLUE, GREEN, IVORY, ORANGE, BLUE, RED, GRAPHITE, YEL)
x = -0.44
for i, m in enumerate(book_mats):                                          # 2. raf: kitaplar + kupa
    w = (0.035, 0.05, 0.04, 0.03, 0.045, 0.035, 0.05, 0.04, 0.03, 0.045)[i]
    h = (0.24, 0.27, 0.22, 0.25, 0.20, 0.26, 0.23, 0.28, 0.21, 0.24)[i]
    box((w, 0.22, h), (x + w / 2, -0.02, 0.993 + h / 2), m)
    x += w + 0.004
lathe([(0.06, 0.0), (0.06, 0.02), (0.02, 0.04), (0.015, 0.09), (0.06, 0.13), (0.07, 0.20), (0.0, 0.20)], GOLD,
      loc=(0.25, -0.02, 0.993), seg=12)
cyl(0.065, 0.008, (0.25, -0.02, 1.192), DARK, seg=12)
car_x = -0.25                                                              # 3. raf: maket araba + kitap yığını
box((0.30, 0.13, 0.07), (car_x, -0.04, 1.37), RED)
box((0.16, 0.12, 0.06), (car_x - 0.02, -0.04, 1.43), RED)
box((0.14, 0.125, 0.04), (car_x - 0.02, -0.04, 1.435), GLASS)
for wx in (-0.10, 0.10):
    cyl(0.035, 0.14, (car_x + wx, -0.04, 1.348), DARK, rot=(R90, 0, 0), seg=10)
for k, m in enumerate((BLUE, IVORY, GREEN)):
    box((0.26, 0.20, 0.045), (0.20, -0.02, 1.335 + k * 0.047), m, rot=(0, 0, 0.06 * (k - 1)))
for k, m in enumerate((OAK_D, RED, BLUE)):                                 # 4. raf: dergi kutuları + bitki
    box((0.09, 0.24, 0.22), (-0.38 + k * 0.10, 0.0, 1.725), m)
potted_plant(0.22, -0.03, 1.613, 0.8)
finish("bookcase")

# ================================================================ 4) MİSAFİR KOLTUKLARI (+ yan sehpa)
clear()
armchair(FABRIC_T, -0.64, 0.0, 0.22)
armchair(FABRIC_T, 0.64, 0.0, -0.22)
cyl(0.21, 0.03, (0, 0.05, 0.52), WHITE, seg=16)                            # sehpa
cyl(0.025, 0.50, (0, 0.05, 0.26), GRAPHITE, seg=8)
cyl(0.16, 0.02, (0, 0.05, 0.01), GRAPHITE, seg=12)
box((0.20, 0.27, 0.01), (-0.04, 0.02, 0.54), BLUE, rot=(0, 0, 0.30))       # dergiler
box((0.20, 0.27, 0.01), (0.03, 0.08, 0.55), ORANGE, rot=(0, 0, -0.20))
cyl(0.03, 0.10, (0.12, -0.06, 0.585), GLASS, seg=10)
finish("visitor_chairs")

# ================================================================ 5) FOTOKOPİ MAKİNESİ
clear()
box((0.64, 0.64, 0.46), (0, 0, 0.27), GRAPHITE)                          # alt dolap (kâğıt çekmeceleri)
for k in range(2):
    box((0.58, 0.015, 0.17), (0, -0.325, 0.16 + k * 0.20), GREY_M)
    box((0.20, 0.025, 0.03), (0, -0.34, 0.21 + k * 0.20), DARK)
for sx in (-0.26, 0.26):
    for sy in (-0.26, 0.26):
        cyl(0.03, 0.04, (sx, sy, 0.03), DARK, rot=(R90, 0, 0), seg=6)
box((0.64, 0.62, 0.42), (0, 0.0, 0.71), IVORY)                            # gövde
box((0.50, 0.02, 0.06), (0, -0.315, 0.62), DARK)                         # çıkış yuvası
box((0.62, 0.58, 0.05), (0, 0.0, 0.945), GREY_M)                          # tarayıcı kapağı
box((0.60, 0.56, 0.04), (0, 0.0, 1.0), IVORY)
box((0.32, 0.24, 0.015), (-0.10, 0.02, 1.027), GREY_L)                    # belge besleyici
box((0.22, 0.13, 0.04), (0.18, -0.29, 1.00), GRAPHITE, rot=(0.35, 0, 0))   # kontrol paneli
box((0.10, 0.06, 0.01), (0.15, -0.31, 1.025), SCREEN, rot=(0.35, 0, 0))
cyl(0.012, 0.01, (0.25, -0.305, 1.02), LED_G, rot=(0.35, 0, 0), seg=6)
box((0.30, 0.40, 0.012), (-0.40, 0.0, 0.70), GREY_L, rot=(0, -0.15, 0))    # yan çıkış tepsisi
box((0.24, 0.32, 0.03), (-0.38, 0.0, 0.725), PAPER, rot=(0, -0.15, 0))
box((0.21, 0.28, 0.03), (-0.10, 0.02, 1.049), PAPER)                     # besleyicide belge yığını
finish("copier")

# ================================================================ 6) KAHVE KÖŞESİ
clear()
box((1.10, 0.55, 0.84), (0, 0, 0.42), OAK)
box((1.14, 0.58, 0.04), (0, -0.01, 0.86), WHITE)                          # tezgâh
for s in (-1, 1):
    box((0.35, 0.015, 0.62), (s * 0.36, -0.28, 0.36), OAK_D)
    box((0.02, 0.02, 0.14), (s * 0.22, -0.30, 0.50), CHROME)
box((0.30, 0.015, 0.16), (0, -0.28, 0.73), OAK_D)
box((0.14, 0.02, 0.02), (0, -0.30, 0.73), CHROME)
box((0.30, 0.015, 0.50), (0, -0.28, 0.30), OAK_D)                        # orta kapak
cyl(0.015, 0.03, (0.10, -0.29, 0.45), CHROME, rot=(R90, 0, 0), seg=6)
# espresso makinesi
ex = -0.24
box((0.38, 0.36, 0.38), (ex, 0.04, 1.07), CHROME)
box((0.38, 0.03, 0.10), (ex, -0.15, 1.20), RED)                           # ön şerit
box((0.30, 0.20, 0.025), (ex, -0.10, 0.895), GRAPHITE)                    # damlalık
cyl(0.045, 0.06, (ex, -0.18, 1.01), GRAPHITE, seg=8)                      # grup başı
rod((ex, -0.20, 0.98), (ex, -0.36, 0.97), 0.014, DARK)                    # portafiltre sapı
mug(ex, -0.18, 0.91, WHITE, r=0.032, h=0.06)
for k in range(3):                                                         # üstte fincanlar
    cyl(0.03, 0.05, (ex - 0.10 + k * 0.10, 0.06, 1.285), (WHITE, RED, WHITE)[k], seg=8)
cyl(0.02, 0.02, (ex + 0.13, -0.145, 1.10), LED_G, rot=(R90, 0, 0), seg=6)
# öğütücü
box((0.14, 0.16, 0.20), (0.06, 0.06, 0.98), GRAPHITE)
lathe([(0.04, 0.0), (0.08, 0.14), (0.0, 0.14)], GLASS, loc=(0.06, 0.06, 1.08), seg=10, smooth=False)
lathe([(0.035, 0.0), (0.065, 0.09), (0.0, 0.09)], BEANS, loc=(0.06, 0.06, 1.085), seg=10, smooth=False)
# kettle + kupalar + şeker kavanozu
lathe([(0.09, 0.0), (0.10, 0.06), (0.08, 0.17), (0.04, 0.20), (0.0, 0.21)], WHITE, loc=(0.36, 0.10, 0.88), seg=12)
cyl(0.11, 0.02, (0.36, 0.10, 0.89), GRAPHITE, seg=12)
rod((0.30, 0.10, 1.07), (0.44, 0.10, 1.07), 0.012, GRAPHITE)
rod((0.44, 0.10, 1.07), (0.46, 0.10, 0.98), 0.012, GRAPHITE)
rod((0.27, 0.10, 0.94), (0.21, 0.10, 1.02), 0.013, WHITE)
for k, m in enumerate((BLUE, YEL, GREEN)):
    mug(0.20 + k * 0.11, -0.16, 0.88, m, r=0.035, h=0.08, coffee=False)
cyl(0.05, 0.11, (0.50, -0.03, 0.935), GLASS, seg=10)                     # şeker kavanozu
cyl(0.045, 0.08, (0.50, -0.03, 0.92), WHITE, seg=10)
cyl(0.052, 0.02, (0.50, -0.03, 1.0), OAK_D, seg=10)
finish("coffee_station")

# ================================================================ 7) TOPLANTI MASASI (6 koltuk)
clear()
top = []
for k in range(9):                                                          # yuvarlatılmış dikdörtgen tabla
    a = -R90 + _m.pi * k / 8
    top.append((0.60 + 0.50 * _m.cos(a), 0.50 * _m.sin(a)))
for k in range(9):
    a = R90 + _m.pi * k / 8
    top.append((-0.60 + 0.50 * _m.cos(a), 0.50 * _m.sin(a)))
prism(top, 0.05, 'xy', WALNUT, offset=0.745)
for sx in (-0.55, 0.55):
    box((0.14, 0.50, 0.68), (sx, 0, 0.38), GRAPHITE)
    box((0.16, 0.80, 0.04), (sx, 0, 0.02), GRAPHITE)
seats = ((-0.68, -0.80, _m.pi + 0.06), (0.0, -0.82, _m.pi - 0.04), (0.68, -0.78, _m.pi + 0.10),
         (-0.66, 0.80, -0.08), (0.02, 0.82, 0.05), (0.70, 0.79, -0.03))
for (sx, sy, yaw) in seats:
    local(lambda: office_chair(back_h=0.44, back=LEATHER_K), loc=(sx, sy, 0.0), yaw=yaw)
box((0.34, 0.24, 0.015), (-0.68, -0.22, 0.778), GREY_L)                   # dizüstü
local(lambda: (box((0.34, 0.012, 0.23), (0, 0.006, 0.115), GREY_L),
               box((0.31, 0.004, 0.20), (0, -0.002, 0.118), SCREEN)),
      loc=(-0.68, -0.10, 0.785), tilt=-0.26)
for (px, py, r) in ((0.0, -0.25, 0.10), (0.66, -0.24, -0.20), (-0.02, 0.26, 0.25), (0.64, 0.22, 0.05)):
    box((0.21, 0.30, 0.008), (px, py, 0.774), PAPER, rot=(0, 0, r))       # evraklar
for (bx, by) in ((-0.30, -0.10), (0.34, -0.08), (-0.34, 0.14), (0.30, 0.16)):
    cyl(0.032, 0.20, (bx, by, 0.87), WATER_B, seg=8)                      # su şişeleri
    cyl(0.02, 0.025, (bx, by, 0.982), BLUE, seg=8)
cyl(0.11, 0.035, (0.0, 0.0, 0.787), DARK, seg=3)                          # konferans telefonu
cyl(0.03, 0.005, (0.0, 0.0, 0.806), LED_G, seg=8)
finish("meeting_table")

# ================================================================ 8) ÇELİK KASA (deste deste para)
clear()
box((0.72, 0.66, 0.92), (0, 0, 0.52), SAFE_G)
for sx in (-0.30, 0.30):
    for sy in (-0.26, 0.26):
        box((0.10, 0.10, 0.06), (sx, sy, 0.03), DARK)
box((0.60, 0.03, 0.78), (0, -0.335, 0.52), SAFE_G)                       # kapak
frame(0.62, 0.80, -0.352, GOLD, t=0.018, d=0.006, z0=0.52)
frame(0.54, 0.72, -0.352, GOLD, t=0.006, d=0.006, z0=0.52)
for sz in (0.30, 0.74):                                                   # menteşeler
    cyl(0.025, 0.10, (-0.34, -0.345, sz), GRAPHITE, seg=8)
cyl(0.085, 0.03, (0.0, -0.36, 0.70), GRAPHITE, rot=(R90, 0, 0), seg=16)   # şifre kadranı
cyl(0.065, 0.02, (0.0, -0.38, 0.70), CHROME, rot=(R90, 0, 0), seg=16)
box((0.012, 0.01, 0.03), (0.0, -0.392, 0.75), RED)
cyl(0.03, 0.04, (0.0, -0.37, 0.42), GRAPHITE, rot=(R90, 0, 0), seg=8)     # çark
for k in range(3):
    a = R90 + 2.0 * _m.pi * k / 3
    end = (0.13 * _m.cos(a), -0.39, 0.42 + 0.13 * _m.sin(a))
    rod((0.0, -0.39, 0.42), end, 0.012, CHROME)
    ball(0.025, end, CHROME, seg=6, ring=4)
box((0.20, 0.006, 0.05), (0.0, -0.355, 0.92), GOLD)                       # isim plakası
box((0.03, 0.01, 0.05), (0.18, -0.355, 0.56), DARK)                       # anahtar deliği
for (bx, by, n) in ((-0.16, -0.06, 4), (0.14, 0.05, 3), (0.06, -0.16, 2)):  # banknot desteleri
    for k in range(n):
        box((0.18, 0.08, 0.035), (bx, by, 1.0 + k * 0.037), CASH, rot=(0, 0, 0.08 * ((k % 2) * 2 - 1)))
        box((0.04, 0.084, 0.037), (bx, by, 1.0 + k * 0.037), PAPER, rot=(0, 0, 0.08 * ((k % 2) * 2 - 1)))
finish("office_safe")

# ================================================================ 9) ÇİZİM MASASI (araba projesi)
clear()
TILT = _m.radians(24)
for sx in (-0.48, 0.48):                                                   # A tipi ayaklar
    rod((sx, -0.32, 0.0), (sx, 0.04, 0.90), 0.022, GRAPHITE)
    rod((sx, 0.40, 0.0), (sx, 0.04, 0.90), 0.022, GRAPHITE)
    box((0.06, 0.82, 0.03), (sx, 0.04, 0.015), GRAPHITE)
rod((-0.48, 0.04, 0.26), (0.48, 0.04, 0.26), 0.02, GRAPHITE)
CAR = ((-0.35, 0.05), (-0.35, 0.10), (-0.31, 0.12), (-0.15, 0.13), (-0.07, 0.21), (0.09, 0.22),
       (0.17, 0.14), (0.32, 0.12), (0.35, 0.08), (0.35, 0.05))


def drafting_board():
    box((1.12, 0.78, 0.025), (0, 0, 0), WHITE)
    box((1.02, 0.68, 0.004), (0, 0.02, 0.0145), BLUEPRINT)
    ox, oy, zl = -0.08, 0.02, 0.018
    pts = [(ox + px, oy + py) for (px, py) in CAR]
    for i in range(len(pts) - 1):
        stroke(pts[i], pts[i + 1], 0.007, zl, INK_W)
    for (a, b) in (((-0.35, 0.05), (-0.29, 0.05)), ((-0.15, 0.05), (0.15, 0.05)), ((0.29, 0.05), (0.35, 0.05)),
                   ((-0.12, 0.13), (0.15, 0.13)), ((0.02, 0.13), (0.03, 0.21))):
        stroke((ox + a[0], oy + a[1]), (ox + b[0], oy + b[1]), 0.005, zl, INK_W)
    for wx in (-0.22, 0.22):
        torus(0.06, 0.004, (ox + wx, oy + 0.05, zl), INK_W, seg=14, mseg=3)
        cyl(0.02, 0.003, (ox + wx, oy + 0.05, zl), INK_W, seg=8)
    stroke((ox - 0.35, oy - 0.08), (ox + 0.35, oy - 0.08), 0.004, zl, INK_W)    # ölçü çizgisi
    for ex in (-0.35, 0.35):
        stroke((ox + ex, oy - 0.10), (ox + ex, oy - 0.06), 0.004, zl, INK_W)
    fx = 0.40                                                                   # önden görünüş
    stroke((fx - 0.08, oy + 0.03), (fx + 0.08, oy + 0.03), 0.005, zl, INK_W)
    stroke((fx - 0.08, oy + 0.03), (fx - 0.07, oy + 0.13), 0.005, zl, INK_W)
    stroke((fx + 0.08, oy + 0.03), (fx + 0.07, oy + 0.13), 0.005, zl, INK_W)
    stroke((fx - 0.07, oy + 0.13), (fx - 0.04, oy + 0.20), 0.005, zl, INK_W)
    stroke((fx + 0.07, oy + 0.13), (fx + 0.04, oy + 0.20), 0.005, zl, INK_W)
    stroke((fx - 0.04, oy + 0.20), (fx + 0.04, oy + 0.20), 0.005, zl, INK_W)
    box((0.30, 0.10, 0.004), (0.32, -0.25, 0.0175), PAPER)                     # antet kutusu
    box((1.06, 0.05, 0.012), (0, -0.16, 0.025), GLASS)                         # paralel cetvel
    box((1.06, 0.008, 0.014), (0, -0.185, 0.026), RED)
    box((1.00, 0.07, 0.035), (0, -0.40, 0.0), OAK)                             # kalem kanalı
    for k, m in enumerate((RED, BLUE, YEL)):
        rod((-0.30 + k * 0.12, -0.40, 0.025), (-0.16 + k * 0.12, -0.39, 0.025), 0.007, m)


local(drafting_board, loc=(0.0, 0.04, 0.92), tilt=TILT)
rod((-0.53, 0.36, 1.06), (-0.50, 0.28, 1.42), 0.012, GRAPHITE)            # projektör lamba
rod((-0.50, 0.28, 1.42), (-0.30, 0.06, 1.40), 0.012, GRAPHITE)
cone(0.10, 0.04, 0.12, (-0.28, 0.03, 1.34), GRAPHITE, seg=10)
cyl(0.085, 0.01, (-0.28, 0.03, 1.275), WARM, seg=10)
STOOL = (0.18, -0.70)                                                      # tabure
cyl(0.18, 0.05, (STOOL[0], STOOL[1], 0.71), LEATHER_K, seg=14)
for k in range(4):
    a = R90 / 2 + R90 * k
    rod((STOOL[0] + 0.17 * _m.cos(a), STOOL[1] + 0.17 * _m.sin(a), 0.0),
        (STOOL[0] + 0.08 * _m.cos(a), STOOL[1] + 0.08 * _m.sin(a), 0.69), 0.014, CHROME)
torus(0.135, 0.01, (STOOL[0], STOOL[1], 0.28), CHROME, seg=12, mseg=4)
finish("drafting_table")

# ================================================================ 10) KARŞILAMA BANKOSU (AUTO YARD)
clear()
box((1.60, 0.46, 1.04), (0, -0.05, 0.52), WHITE)                          # gövde
for s in (-1, 1):
    cyl(0.23, 1.04, (s * 0.80, -0.05, 0.52), WHITE, seg=16)              # yuvarlak uçlar
    cyl(0.255, 0.04, (s * 0.80, -0.06, 1.06), MARBLE, seg=16)
    cyl(0.235, 0.05, (s * 0.80, -0.05, 0.12), N_ORANGE, seg=16)
box((1.62, 0.52, 0.04), (0, -0.06, 1.06), MARBLE)                         # yüksek tezgâh
box((1.60, 0.50, 0.05), (0, -0.04, 0.12), N_ORANGE)                       # alt ışık bandı
box((1.10, 0.03, 0.40), (0, -0.29, 0.62), GRAPHITE)                       # logo panosu
text("AUTO YARD", 0.15, (0, -0.31, 0.63), N_ORANGE, depth=0.015)
box((0.98, 0.006, 0.012), (0, -0.307, 0.51), N_ORANGE)
box((1.80, 0.46, 0.04), (0, 0.42, 0.74), OAK)                             # arkadaki çalışma tablası
for s in (-1, 1):
    box((0.04, 0.42, 0.72), (s * 0.85, 0.42, 0.36), OAK_D)
local(lambda: monitor(0.0, 0.0, 0.0, chart=False), loc=(0.30, 0.48, 0.76), yaw=_m.pi + 0.15)  # görevliye bakar
box((0.40, 0.14, 0.02), (0.28, 0.30, 0.77), GRAPHITE)
lathe([(0.06, 0.0), (0.06, 0.012), (0.05, 0.03), (0.03, 0.055), (0.0, 0.065)], GOLD, loc=(0.42, -0.10, 1.08), seg=12)
cyl(0.008, 0.02, (0.42, -0.10, 1.150), GOLD, seg=6)                       # servis zili
box((0.22, 0.10, 0.20), (-0.45, -0.08, 1.18), GLASS, rot=(0.12, 0, 0))     # broşürlük
for k, m in enumerate((ORANGE, BLUE, RED)):
    box((0.06, 0.06, 0.16), (-0.52 + k * 0.07, -0.08, 1.165), m, rot=(0.12, 0, 0))
lathe([(0.04, 0.0), (0.05, 0.10), (0.035, 0.22), (0.04, 0.24)], GLASS, loc=(0.0, -0.05, 1.08), seg=10)  # vazo
for (dx, dz) in ((-0.04, 0.34), (0.03, 0.38), (0.0, 0.30)):
    ball(0.035, (dx, -0.05, 1.08 + dz), PINK, seg=7, ring=5)
    rod((0.0, -0.05, 1.30), (dx, -0.05, 1.08 + dz), 0.004, LEAF)
finish("reception_desk")

# ================================================================ 11) AYAKLI LAMBA (kavisli)
clear()
box((0.32, 0.32, 0.07), (0, 0, 0.035), MARBLE)
p0 = mathutils.Vector((0.0, 0.0, 0.07))
p1 = mathutils.Vector((-0.05, 0.0, 2.30))
p2 = mathutils.Vector((0.82, 0.0, 1.78))
prev = p0
for k in range(1, 13):
    t = k / 12
    p = (1 - t) * (1 - t) * p0 + 2 * (1 - t) * t * p1 + t * t * p2
    rod(tuple(prev), tuple(p), 0.016, CHROME, seg=6)
    prev = p
lathe([(0.0, 0.20), (0.07, 0.19), (0.15, 0.12), (0.20, 0.0)], GRAPHITE, loc=(0.84, 0.0, 1.58), seg=16)
cyl(0.17, 0.01, (0.84, 0.0, 1.575), WARM, seg=16)
ball(0.05, (0.84, 0.0, 1.62), WARM, seg=8, ring=5)
finish("floor_lamp")

# ================================================================ 12) SUNUM PANOSU (satış grafiği)
clear()
rod((-0.42, -0.22, 0.0), (-0.39, 0.0, 1.70), 0.016, OAK_D)                # sehpa ayakları
rod((0.42, -0.22, 0.0), (0.39, 0.0, 1.70), 0.016, OAK_D)
rod((0.0, 0.42, 0.0), (0.0, 0.05, 1.55), 0.016, OAK_D)
box((0.74, 0.035, 0.96), (0, -0.04, 1.20), WHITE, rot=(-0.10, 0, 0))       # arka pano
box((0.70, 0.01, 0.90), (0, -0.065, 1.19), PAPER, rot=(-0.10, 0, 0))       # kâğıt blok
box((0.76, 0.05, 0.05), (0, -0.02, 1.665), GRAPHITE, rot=(-0.10, 0, 0))     # üst kıskaç
for i, (h, m) in enumerate(((0.16, BLUE), (0.24, BLUE), (0.20, BLUE), (0.36, GREEN))):   # çubuklar
    z0 = 0.86
    box((0.09, 0.006, h), (-0.22 + i * 0.13, -0.075 + (z0 + h / 2 - 1.19) * 0.10, z0 + h / 2), m, rot=(-0.10, 0, 0))
line = ((-0.26, 1.18), (-0.12, 1.26), (0.02, 1.22), (0.20, 1.40))                       # yükselen çizgi
for i in range(len(line) - 1):
    (ax, az), (bx, bz) = line[i], line[i + 1]
    wall_stroke((ax, az), (bx, bz), 0.018, -0.082 + ((az + bz) / 2 - 1.19) * 0.10, RED, d=0.006)
cone(0.035, 0.0, 0.07, (0.22, -0.058, 1.43), RED, rot=(0, 0.75, 0), seg=4)
box((0.66, 0.008, 0.012), (0, -0.108, 0.84), GRAPHITE)                     # taban çizgisi
box((0.84, 0.09, 0.03), (0, -0.08, 0.72), OAK_D)                           # kalem tablası
for k, m in enumerate((RED, BLUE, GREEN)):
    rod((-0.20 + k * 0.10, -0.08, 0.745), (-0.08 + k * 0.10, -0.08, 0.745), 0.01, m)
finish("flip_chart")

# ================================================================ 13) BEYAZ TAHTA (duvar)
clear()
box((1.40, 0.02, 0.90), (0, 0.0, 0.45), WHITE)
frame(1.44, 0.94, -0.005, GREY_L, t=0.03, d=0.035, z0=0.45)
wall_stroke((-0.62, 0.14), (-0.62, 0.80), 0.012, -0.013, DARK)             # eksenler
wall_stroke((-0.62, 0.14), (0.20, 0.14), 0.012, -0.013, DARK)
for i, h in enumerate((0.16, 0.24, 0.20, 0.34, 0.46)):                    # çubuk grafik
    box((0.08, 0.006, h), (-0.50 + i * 0.15, -0.013, 0.15 + h / 2), GREEN if i == 4 else BLUE)
pts = ((-0.56, 0.40), (-0.42, 0.48), (-0.28, 0.44), (-0.12, 0.60), (0.02, 0.58), (0.16, 0.76))
for i in range(len(pts) - 1):
    wall_stroke(pts[i], pts[i + 1], 0.016, -0.016, RED)
for p in pts:
    cyl(0.018, 0.01, (p[0], -0.019, p[1]), RED, rot=(R90, 0, 0), seg=8)
notes = ((0.36, 0.72, YEL, 0.08), (0.48, 0.70, PINK, -0.10), (0.60, 0.73, LIME, 0.05),
         (0.36, 0.56, ORANGE, -0.06), (0.49, 0.55, YEL, 0.12), (0.61, 0.57, PINK, -0.04),
         (0.42, 0.40, LIME, 0.10), (0.56, 0.41, YEL, -0.08))
for (nx, nz, m, r) in notes:                                               # yapışkan notlar
    box((0.10, 0.006, 0.10), (nx, -0.013, nz), m, rot=(0, r, 0))
    box((0.06, 0.003, 0.008), (nx, -0.017, nz + 0.01), GRAPHITE, rot=(0, r, 0))
for (mx, m) in ((0.30, RED), (0.42, BLUE), (0.66, GREEN)):                 # mıknatıslar
    cyl(0.018, 0.015, (mx, -0.02, 0.84), m, rot=(R90, 0, 0), seg=8)
box((0.90, 0.07, 0.025), (0, -0.04, 0.01), GREY_L)                         # kalem tablası
box((0.90, 0.012, 0.04), (0, -0.07, 0.025), GREY_L)
for k, m in enumerate((RED, BLUE, DARK)):
    rod((-0.30 + k * 0.14, -0.04, 0.035), (-0.18 + k * 0.14, -0.04, 0.035), 0.011, m)
box((0.13, 0.05, 0.04), (0.28, -0.04, 0.045), GRAPHITE)                    # silgi
finish("office_whiteboard")

# ================================================================ 14) BELGE ÇERÇEVELERİ (duvar)
clear()


def certificate(cx, cz, w, h, seal):
    box((w, 0.025, h), (cx, -0.0125, cz), WALNUT)
    box((w - 0.05, 0.01, h - 0.05), (cx, -0.03, cz), CREAM_P)
    frame(w - 0.09, h - 0.09, -0.036, GOLD, t=0.008, d=0.004, z0=cz, x0=cx)
    box((w * 0.55, 0.004, 0.025), (cx, -0.037, cz + h * 0.30), DARK)              # başlık
    for k in range(4):
        box((w * (0.62 - 0.10 * (k % 2)), 0.004, 0.008), (cx, -0.037, cz + h * 0.14 - k * 0.04), GRAPHITE)
    sx, sz = cx + w * 0.22, cz - h * 0.28
    for side in (-1, 1):
        box((0.025, 0.004, 0.08), (sx + side * 0.018, -0.040, sz - 0.05), RED, rot=(0, side * 0.35, 0))
    cyl(0.045, 0.008, (sx, -0.044, sz), seal, rot=(R90, 0, 0), seg=12)
    box((w * 0.25, 0.004, 0.006), (cx - w * 0.18, -0.037, sz - 0.02), GRAPHITE)  # imza çizgisi


certificate(0.0, 0.30, 0.44, 0.58, GOLD)
certificate(-0.43, 0.26, 0.34, 0.44, BLUE)
box((0.34, 0.025, 0.44), (0.43, -0.0125, 0.26), WALNUT)                     # araba fotoğrafı
box((0.29, 0.01, 0.39), (0.43, -0.03, 0.26), mat("Gokyuzu", (0.45, 0.70, 0.92), 0.6))
box((0.29, 0.011, 0.10), (0.43, -0.031, 0.11), mat("Asfalt", (0.25, 0.25, 0.27), 0.7))
box((0.22, 0.012, 0.05), (0.43, -0.033, 0.18), RED)
box((0.12, 0.012, 0.04), (0.42, -0.033, 0.22), RED)
box((0.09, 0.013, 0.025), (0.42, -0.035, 0.22), GLASS)
for wx in (-0.07, 0.07):
    cyl(0.025, 0.014, (0.43 + wx, -0.034, 0.155), DARK, rot=(R90, 0, 0), seg=10)
ball(0.035, (0.53, -0.033, 0.39), mat("Gunes", (1.0, 0.85, 0.3), 0.5, emit=(0.6, 0.45, 0.1)), seg=8, ring=5)
finish("certificates")

# ================================================================ 15) DÜNYA HARİTASI (ithalat rotaları)
clear()
MW, MH, MZ = 1.50, 0.86, 0.43
box((MW, 0.02, MH), (0, -0.01, MZ), OCEAN)
frame(MW + 0.06, MH + 0.06, -0.018, WALNUT, t=0.04, d=0.04, z0=MZ)


def geo(lon, lat):
    return (lon / 180.0 * MW * 0.46, MZ + 0.04 + lat / 90.0 * MH * 0.44)


CONTINENTS = (
    (LAND_G, ((-165, 65), (-140, 70), (-95, 72), (-75, 62), (-60, 50), (-80, 25), (-97, 18), (-105, 22),
              (-118, 32), (-125, 48), (-140, 58), (-165, 58))),                                     # K. Amerika
    (LAND_G, ((-80, 10), (-60, 8), (-35, -7), (-40, -22), (-58, -38), (-70, -55), (-75, -45), (-72, -18),
              (-81, -5))),                                                                           # G. Amerika
    (LAND, ((-55, 60), (-45, 60), (-20, 70), (-25, 82), (-60, 82), (-70, 77))),                      # Grönland
    (LAND_G, ((-10, 36), (5, 42), (12, 44), (20, 40), (28, 40), (40, 45), (45, 55), (40, 68), (25, 70),
              (10, 63), (-5, 58), (-2, 48), (-9, 44))),                                              # Avrupa
    (LAND, ((-17, 15), (-8, 4), (9, 4), (13, -20), (20, -35), (32, -30), (40, -15), (51, 12), (43, 12),
            (32, 31), (10, 37), (-10, 33))),                                                         # Afrika
    (LAND, ((40, 45), (28, 40), (36, 36), (50, 28), (60, 25), (72, 20), (80, 10), (95, 16), (100, 8),
            (108, 18), (120, 30), (135, 35), (140, 50), (160, 58), (170, 66), (140, 72), (110, 77), (70, 73),
            (40, 68), (45, 55))),                                                                    # Asya
    (LAND, ((114, -22), (130, -12), (142, -11), (153, -25), (150, -37), (140, -38), (130, -32),
            (115, -34))),                                                                            # Avustralya
)
for (m, poly) in CONTINENTS:
    prism([geo(lon, lat) for (lon, lat) in poly], 0.008, 'xz', m, offset=-0.024)
HOME = geo(29, 41)                                                          # İstanbul
CITIES = (geo(9, 48), geo(-83, 42), geo(139, 35), geo(-46, -23), geo(127, 37), geo(12, 45))
for c in CITIES:                                                            # ip + iğne
    wall_stroke(HOME, c, 0.006, -0.034, RED, d=0.004)
    rod((c[0], -0.03, c[1]), (c[0], -0.06, c[1]), 0.004, GREY_L)
    ball(0.016, (c[0], -0.062, c[1]), YEL, seg=6, ring=4)
rod((HOME[0], -0.03, HOME[1]), (HOME[0], -0.07, HOME[1]), 0.005, GREY_L)
ball(0.024, (HOME[0], -0.072, HOME[1]), RED, seg=8, ring=5)
finish("world_map")

# ================================================================ 16) KLİMA (duvar)
clear()
profile = ((0.0, 0.30), (-0.16, 0.30), (-0.205, 0.28), (-0.225, 0.22), (-0.225, 0.08), (-0.205, 0.03),
           (-0.15, 0.0), (0.0, 0.0))
prism(profile, 0.92, 'yz', WHITE)
box((0.80, 0.05, 0.012), (0, -0.16, 0.012), DARK)                          # hava çıkışı
box((0.82, 0.07, 0.012), (0, -0.20, 0.03), GREY_L, rot=(-0.55, 0, 0))      # kanat
box((0.92, 0.004, 0.012), (0, -0.227, 0.20), GREY_L)                       # ön çizgi
box((0.93, 0.15, 0.05), (0, -0.13, 0.055), GREY_M)                         # alt gövde (beyaz duvarda okunsun)
box((0.50, 0.004, 0.008), (-0.14, -0.229, 0.165), N_CYAN)                  # ışık şeridi
box((0.12, 0.004, 0.05), (0.30, -0.228, 0.12), DARK)                       # ekran
text("22", 0.035, (0.29, -0.231, 0.12), N_CYAN, depth=0.003)
cyl(0.006, 0.004, (0.35, -0.231, 0.12), LED_G, rot=(R90, 0, 0), seg=6)
for k in range(5):                                                          # üst ızgara
    box((0.80, 0.03, 0.004), (0, -0.04 - k * 0.03, 0.302), GREY_L)
finish("wall_ac")

print("v5 ofis partisi tamam")
