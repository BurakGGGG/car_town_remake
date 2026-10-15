"""DEKORASYON v4 — LÜKS partisi: ELMASLA satılan 24 eşya (yere konan 18, duvara asılan 6).

Oyun kamerası uzak ve yukarıda: eşyalar ilk bakışta "pahalı" okunmalı. Bu yüzden güçlü siluet (helikopter,
altın spor araba, dev elmas, çeşme), altın / mermer / kadife / kristal malzeme ve IŞIK VEREN parçalar
(akvaryum suyu, şömine ateşi, neon, kristal) kullanılır. Dünyada ortam ışığı ve yansıma yok: tam metal yüzey
koyu görünür, altın düşük metallik + parlak taban rengi + hafif ışımayla çizilir.

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası; duvar eşyasının arka yüzü
duvara (+Y) yaslanır. Yazılar dilden bağımsız (VIP, rakamlar, kurgusal marka AUTO YARD).
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v4_luks.py
"""
import math as _m

import bmesh
import mathutils

R90 = _m.radians(90)

# --- Malzemeler ---------------------------------------------------------------------------
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
GOLD_D = mat("KoyuAltin", (0.62, 0.34, 0.04), 0.35, 0.35, emit=(0.06, 0.03, 0.003))
CHROME = mat("Krom", (0.78, 0.80, 0.84), 0.12, 0.3)
MARBLE = mat("Mermer", (0.93, 0.92, 0.89), 0.18)
VEIN = mat("MermerDamar", (0.68, 0.68, 0.72), 0.25)
MARBLE_K = mat("KaraMermer", (0.035, 0.035, 0.042), 0.12)
VELVET_R = mat("KadifeBordo", (0.40, 0.02, 0.06), 0.95)
VELVET_G = mat("KadifeZumrut", (0.02, 0.24, 0.15), 0.95)
VELVET_P = mat("KadifeMor", (0.22, 0.04, 0.34), 0.95)
BLACK = mat("Siyah", (0.02, 0.02, 0.025), 0.35)
CARBON = mat("Karbon", (0.05, 0.05, 0.06), 0.3, 0.2)
WALNUT = mat("Ceviz", (0.20, 0.09, 0.04), 0.45)
TEAK = mat("Tik", (0.42, 0.24, 0.10), 0.6)
WHITE = mat("Beyaz", (0.92, 0.91, 0.88), 0.4)
RED = mat("Kirmizi", (0.62, 0.04, 0.05), 0.35)
LEAF = mat("Yaprak", (0.10, 0.36, 0.10), 0.7)
LEAF_D = mat("KoyuYaprak", (0.05, 0.22, 0.07), 0.75)
BARK = mat("Kabuk", (0.30, 0.18, 0.09), 0.9)
CERAMIC = mat("Seramik", (0.05, 0.14, 0.36), 0.25)
GLASS = mat("Cam", (0.80, 0.90, 0.97), 0.05, 0.1, alpha=0.30)
CRYSTAL = mat("Kristal", (0.85, 0.95, 1.0), 0.05, 0.1, emit=(0.30, 0.42, 0.50), alpha=0.65)
DIAMOND = mat("Elmas", (0.62, 0.92, 1.0), 0.04, 0.1, emit=(0.18, 0.55, 0.75), alpha=0.82)
WATER = mat("Su", (0.10, 0.55, 0.85), 0.05, 0.0, emit=(0.04, 0.30, 0.50), alpha=0.55)
POOL = mat("Havuz", (0.20, 0.85, 0.95), 0.05, 0.0, emit=(0.10, 0.55, 0.65), alpha=0.70)
WARM = mat("SicakIsik", (1.0, 0.86, 0.55), 0.2, emit=(1.0, 0.78, 0.40))
FIRE_O = mat("AtesTuruncu", (1.0, 0.42, 0.05), 0.3, emit=(1.0, 0.36, 0.04))
FIRE_Y = mat("AtesSari", (1.0, 0.85, 0.25), 0.3, emit=(1.0, 0.78, 0.18))
N_PINK = mat("NeonPembe", (1.0, 0.25, 0.65), 0.3, emit=(1.0, 0.2, 0.6))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
N_GOLD = mat("NeonAltin", (1.0, 0.80, 0.25), 0.3, emit=(1.0, 0.72, 0.15))
SCREEN = mat("Ekran", (0.10, 0.30, 0.60), 0.3, emit=(0.12, 0.38, 0.85))
SKY_O = mat("GunbatimiTuruncu", (0.95, 0.45, 0.12), 0.6, emit=(0.30, 0.12, 0.02))
SKY_P = mat("GunbatimiPembe", (0.75, 0.22, 0.40), 0.6, emit=(0.20, 0.05, 0.10))
SKY_V = mat("GunbatimiMor", (0.25, 0.10, 0.40), 0.6)
GREEN_FELT = mat("YesilZemin", (0.08, 0.30, 0.15), 0.8)
CORAL_P = mat("MercanPembe", (1.0, 0.40, 0.55), 0.5, emit=(0.30, 0.08, 0.14))
CORAL_O = mat("MercanTuruncu", (1.0, 0.55, 0.15), 0.5, emit=(0.30, 0.14, 0.03))
FISH_O = mat("BalikTuruncu", (1.0, 0.45, 0.05), 0.4, emit=(0.35, 0.13, 0.01))
FISH_Y = mat("BalikSari", (1.0, 0.85, 0.10), 0.4, emit=(0.32, 0.26, 0.02))
FISH_B = mat("BalikMavi", (0.10, 0.45, 1.0), 0.4, emit=(0.03, 0.15, 0.35))
SAND = mat("Kum", (0.85, 0.75, 0.55), 0.9)
BOTTLE = mat("Sise", (0.05, 0.25, 0.10), 0.15)
FOAM = mat("Kopuk", (0.95, 0.97, 1.0), 0.5)
YEL = mat("Sari", (0.95, 0.75, 0.05), 0.5)
TOWEL = mat("Havlu", (0.95, 0.94, 0.90), 0.95)


# --- Yardımcılar --------------------------------------------------------------------------

def mesh_obj(verts, faces, material, smooth=False):
    """Hazır köşe / yüz listesinden gövde (helikopter kuyruğu, yaprak, araç kabini...)."""
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


def lathe(profile, material, loc=(0.0, 0.0, 0.0), seg=16, smooth=True, scale=(1.0, 1.0)):
    """(yarıçap, yükseklik) dış hattını Z ekseni etrafında döndürür (kupa, vazo, çeşme havuzu).
    Uçlardaki yarıçap 0 değilse o uç bir kapakla kapanır. scale: (x, y) yassılaştırma."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for k in range(seg):
            a = 2.0 * _m.pi * k / seg
            ring.append(bm.verts.new((loc[0] + r * _m.cos(a) * scale[0], loc[1] + r * _m.sin(a) * scale[1],
                                      loc[2] + z)))
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
    """İki nokta arasında silindir (çubuk, ip, boru)."""
    a = mathutils.Vector(p0)
    b = mathutils.Vector(p1)
    d = b - a
    rot = mathutils.Vector((0.0, 0.0, 1.0)).rotation_difference(d.normalized()).to_euler()
    return cyl(r, d.length, tuple((a + b) * 0.5), material, rot=tuple(rot), seg=seg)


def rope(p0, p1, sag, r, material, n=8):
    """Sarkan kadife kordon: iki direk arası parabol, n çubuk."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t,
                    p0[2] + (p1[2] - p0[2]) * t - sag * 4.0 * t * (1.0 - t)))
    for i in range(n):
        rod(pts[i], pts[i + 1], r, material, seg=6)


def turn_all(angle):
    """Koleksiyondaki her şeyi orijin etrafında döndürür (eşyayı kameraya çevirmek için, finish'ten önce)."""
    m = mathutils.Matrix.Rotation(angle, 4, 'Z')
    for o in col().objects:
        o.matrix_world = m @ o.matrix_world


def transformed(local_pts, matrix):
    return [tuple(matrix @ mathutils.Vector(p)) for p in local_pts]


def leaf(base, yaw, pitch, length, width, material, droop=0.35):
    """Uzun yaprak (palmiye / bonsai): tabandan dışa doğru, ucu sarkık; iki yüzlü ince şerit."""
    m = mathutils.Matrix.Translation(base) @ mathutils.Matrix.Rotation(yaw, 4, 'Z') \
        @ mathutils.Matrix.Rotation(-pitch, 4, 'Y')
    pts = []
    n = 5
    for i in range(n + 1):
        t = i / n
        x = length * t
        z = -droop * length * t * t
        w = width * _m.sin(_m.pi * min(t * 1.15, 1.0)) * 0.5 + 0.01
        pts.append((x, -w, z))
        pts.append((x, w, z))
    verts = transformed(pts, m)
    faces = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(n)]
    return mesh_obj(verts, faces, material)


def gem(r, crown, pavilion, loc, material, seg=8, table=0.55):
    """Pırlanta kesim: düz tabla, taç, kuşak, sivri kaide. Az kesitli + düz gölgeli = parlayan yüzler."""
    profile = [(0.0, -pavilion), (r, 0.0), (r * 0.98, crown * 0.18), (r * table, crown)]
    o = lathe(profile, material, loc=loc, seg=seg, smooth=False)
    return o


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


def frame(w, h, y, material, t=0.05, d=0.05, z0=0.0, x0=0.0):
    """Ön yüzü −Y'ye bakan çerçeve (x genişlik, z yükseklik), merkezi (x0, z0)."""
    box((w, d, t), (x0, y, z0 + h / 2 - t / 2), material)
    box((w, d, t), (x0, y, z0 - h / 2 + t / 2), material)
    box((t, d, h), (x0 - w / 2 + t / 2, y, z0), material)
    box((t, d, h), (x0 + w / 2 - t / 2, y, z0), material)


def marble_slab(size, loc, veins=3, material=MARBLE, vein=VEIN):
    """Mermer blok: üst yüzde ince damarlar (uzaktan mermer okunsun)."""
    box(size, loc, material)
    top = loc[2] + size[2] / 2 + 0.001
    for k in range(veins):
        f = (k + 1) / (veins + 1)
        box((min(size[0], size[1]) * 0.45, 0.010, 0.002), (loc[0] + size[0] * (f - 0.5) * 0.8,
                                                         loc[1] + size[1] * (0.5 - f) * 0.5, top), vein,
            rot=(0, 0, 0.5 + k * 0.7))


def plinth(w, d, h, z=0.0, material=MARBLE_K, band=GOLD):
    """Lüks kaide: kara mermer blok, altın taban ve üst bandı."""
    box((w + 0.08, d + 0.08, 0.05), (0, 0, z + 0.025), band)
    box((w, d, h - 0.1), (0, 0, z + 0.05 + (h - 0.1) / 2), material)
    box((w + 0.06, d + 0.06, 0.05), (0, 0, z + h - 0.025), band)


def stanchion(x, y, h=0.95, material=GOLD):
    cyl(0.17, 0.04, (x, y, 0.02), material, seg=14)
    cyl(0.12, 0.05, (x, y, 0.065), material, seg=14)
    cyl(0.032, h, (x, y, h / 2 + 0.05), material, seg=10)
    ball(0.065, (x, y, h + 0.08), material, seg=12, ring=7)


# ================================================================ 1) VIP KADİFE KORDON
clear()
for x in (-1.25, 0.0, 1.25):
    stanchion(x, 0.0)
for x0, x1 in ((-1.25, 0.0), (0.0, 1.25)):
    rope((x0 + 0.05, 0, 0.93), (x1 - 0.05, 0, 0.93), 0.20, 0.03, VELVET_R, n=10)
    for x in (x0 + 0.05, x1 - 0.05):
        torus(0.04, 0.012, (x, 0, 0.93), GOLD, rot=(R90, 0, 0), seg=8, mseg=4)
box((2.9, 0.9, 0.012), (0, -0.55, 0.006), VELVET_R)                      # kırmızı halı
for s in (-1, 1):
    box((2.9, 0.04, 0.014), (0, -0.55 + s * 0.43, 0.007), GOLD)
finish("lux_vip_rope")

# ================================================================ 2) ALTIN SAKSIDA PALMİYE
clear()
lathe([(0.30, 0.0), (0.34, 0.06), (0.26, 0.14), (0.30, 0.36), (0.40, 0.62), (0.44, 0.70), (0.38, 0.72)],
      GOLD, seg=18)
torus(0.42, 0.03, (0, 0, 0.68), GOLD_D, seg=18, mseg=5)
cyl(0.36, 0.04, (0, 0, 0.70), mat("Toprak", (0.12, 0.07, 0.03), 0.95), seg=16)
z = 0.70
x = 0.0
for i in range(8):                                                        # gövde: kabuk halkaları
    cone(0.14 - i * 0.008, 0.11 - i * 0.008, 0.26, (x, 0, z + 0.13), BARK, seg=8)
    z += 0.24
    x += 0.025
top = (x, 0, z)
for k in range(11):
    yaw = k * 2.0 * _m.pi / 11 + (0.2 if k % 2 else 0.0)
    pitch = 0.15 + (k % 3) * 0.18
    leaf(top, yaw, pitch, 1.15 + (k % 2) * 0.25, 0.42, LEAF if k % 2 else LEAF_D, droop=0.42)
for k in range(5):                                                        # hindistan cevizleri
    a = k * 1.25
    ball(0.07, (x + 0.12 * _m.cos(a), 0.12 * _m.sin(a), z - 0.12), BARK, seg=8, ring=5)
finish("lux_gold_palm")

# ================================================================ 3) ASIRLIK BONSAİ
clear()
box((1.20, 0.62, 0.06), (0, 0, 0.42), BLACK)                              # lake sehpa
box((1.24, 0.66, 0.02), (0, 0, 0.385), GOLD)
for sx in (-1, 1):
    for sy in (-1, 1):
        box((0.06, 0.06, 0.38), (sx * 0.54, sy * 0.25, 0.19), BLACK)
        box((0.07, 0.07, 0.04), (sx * 0.54, sy * 0.25, 0.02), GOLD)
box((0.72, 0.42, 0.14), (0, 0, 0.52), CERAMIC)                            # saksı
box((0.76, 0.46, 0.03), (0, 0, 0.60), CERAMIC)
box((0.68, 0.38, 0.02), (0, 0, 0.61), mat("Yosun", (0.16, 0.35, 0.08), 0.95))
trunk = [(0.05, 0, 0.60), (-0.08, 0, 0.78), (0.06, 0.02, 0.95), (-0.04, -0.02, 1.10), (0.10, 0, 1.22)]
for i in range(len(trunk) - 1):
    rod(trunk[i], trunk[i + 1], 0.07 - i * 0.012, BARK, seg=8)
rod((-0.08, 0, 0.78), (-0.38, 0.03, 0.92), 0.035, BARK)
rod((0.06, 0.02, 0.95), (0.36, -0.02, 1.05), 0.03, BARK)
for (cx, cy, cz, r) in ((-0.42, 0.03, 0.97, 0.20), (0.40, -0.02, 1.10, 0.19), (0.10, 0.0, 1.32, 0.24),
                        (-0.12, 0.05, 1.20, 0.16)):
    ball(r, (cx, cy, cz), LEAF_D, scale=(1.3, 1.0, 0.55), seg=10, ring=6)
    ball(r * 0.7, (cx + 0.04, cy - 0.04, cz + 0.04), LEAF, scale=(1.3, 1.0, 0.55), seg=8, ring=5)
box((0.22, 0.02, 0.07), (0, -0.33, 0.42), GOLD)                           # isim plakası
finish("lux_bonsai")

# ================================================================ 4) ALTIN BENZİN POMPASI
clear()
marble_slab((0.80, 0.60, 0.14), (0, 0, 0.07), veins=2, material=MARBLE_K, vein=GOLD)
box((0.62, 0.46, 1.30), (0, 0, 0.79), GOLD)
cyl(0.31, 0.46, (0, 0, 1.44), GOLD, rot=(R90, 0, 0), seg=16)             # yuvarlak tepe
box((0.66, 0.50, 0.05), (0, 0, 0.17), GOLD_D)
box((0.44, 0.02, 0.36), (0, -0.235, 1.12), mat("Kadran", (0.95, 0.92, 0.80), 0.4, emit=(0.25, 0.22, 0.12)))
frame(0.48, 0.40, -0.245, BLACK, t=0.03, d=0.02, z0=1.12)
for k in range(4):                                                        # sayaç rakam kutuları
    box((0.07, 0.01, 0.09), (-0.12 + k * 0.08, -0.25, 1.20), BLACK)
box((0.30, 0.01, 0.05), (0, -0.25, 1.02), RED)
box((0.40, 0.02, 0.50), (0, -0.235, 0.58), MARBLE_K)                      # alt kapak
for k in range(5):
    box((0.34, 0.01, 0.02), (0, -0.25, 0.40 + k * 0.08), GOLD)
cyl(0.06, 0.04, (0, 0, 1.78), GOLD_D, seg=12)
ball(0.24, (0, 0, 2.00), mat("Kure", (0.98, 0.97, 0.94), 0.3, emit=(0.70, 0.66, 0.55)), seg=16, ring=10)
torus(0.245, 0.03, (0, 0, 2.00), RED, rot=(R90, 0, 0), seg=18, mseg=5)
text("AY", 0.16, (0, -0.25, 2.00), RED, depth=0.02)
box((0.10, 0.12, 0.26), (0.36, -0.05, 1.05), BLACK)                       # tabanca yuvası
box((0.05, 0.16, 0.06), (0.36, -0.12, 1.15), GOLD)
pts = [(0.36, 0.0, 0.95), (0.42, 0.05, 0.60), (0.40, 0.08, 0.30), (0.33, 0.10, 0.22), (0.20, 0.10, 0.25)]
for i in range(len(pts) - 1):
    rod(pts[i], pts[i + 1], 0.022, BLACK, seg=6)
finish("lux_gold_gas_pump")

# ================================================================ 5) KRİSTAL AYAKLI LAMBA
clear()
lathe([(0.30, 0.0), (0.30, 0.03), (0.20, 0.06), (0.06, 0.12), (0.035, 0.16)], GOLD, seg=16)
cyl(0.025, 1.45, (0, 0, 0.88), GOLD, seg=10)
for zc in (0.55, 1.05):
    torus(0.05, 0.015, (0, 0, zc), GOLD_D, seg=10, mseg=4)
ball(0.11, (0, 0, 1.70), WARM, seg=14, ring=9)                            # parlayan çekirdek
for tier, (zr, rr, n) in enumerate(((1.98, 0.18, 8), (1.80, 0.30, 12), (1.58, 0.40, 16), (1.36, 0.30, 12))):
    torus(rr, 0.014, (0, 0, zr), GOLD, seg=max(n, 12), mseg=4)
    for k in range(n):
        a = 2.0 * _m.pi * (k + 0.5 * tier) / n
        px, py = rr * _m.cos(a), rr * _m.sin(a)
        rod((px, py, zr), (px, py, zr - 0.07), 0.004, GOLD, seg=3)
        cone(0.030, 0.0, 0.12, (px, py, zr - 0.13), CRYSTAL, rot=(_m.pi, 0, 0), seg=5)
cone(0.10, 0.0, 0.16, (0, 0, 2.10), GOLD, seg=10)                          # taç
ball(0.035, (0, 0, 2.20), CRYSTAL, seg=8, ring=5)
finish("lux_crystal_lamp")

# ================================================================ 6) ŞAMPANYA BARI
clear()
box((2.40, 0.72, 1.00), (0, 0, 0.55), MARBLE_K)                           # gövde
box((2.46, 0.78, 0.06), (0, 0, 0.03), GOLD)
for k in range(9):                                                        # altın dikey şeritler
    box((0.04, 0.02, 0.86), (-1.04 + k * 0.26, -0.37, 0.55), GOLD)
box((2.44, 0.03, 0.04), (0, -0.37, 0.98), WARM)                           # led şerit
marble_slab((2.60, 0.86, 0.07), (0, -0.02, 1.085), veins=4)
box((2.62, 0.88, 0.02), (0, -0.02, 1.04), GOLD)
# şampanya kulesi: 4 kat kadeh piramidi
levels = ((4, 0.0), (3, 0.17), (2, 0.34), (1, 0.51))
for row, (n, dz) in enumerate(levels):
    for i in range(n):
        for j in range(n):
            gx = -0.55 + (i - (n - 1) / 2) * 0.13
            gy = -0.02 + (j - (n - 1) / 2) * 0.13
            gz = 1.12 + dz
            cyl(0.035, 0.008, (gx, gy, gz + 0.004), GLASS, seg=8)
            cyl(0.006, 0.08, (gx, gy, gz + 0.045), GLASS, seg=4)
            cone(0.012, 0.05, 0.08, (gx, gy, gz + 0.125), mat("Sampanya", (1.0, 0.86, 0.45), 0.2,
                                                               emit=(0.40, 0.32, 0.10), alpha=0.75), seg=8)
# kova + şişeler
lathe([(0.12, 0.0), (0.16, 0.28), (0.17, 0.30)], GOLD, loc=(0.55, -0.02, 1.12), seg=14)
cyl(0.15, 0.02, (0.55, -0.02, 1.38), mat("Buz", (0.85, 0.95, 1.0), 0.1, alpha=0.6), seg=12)
for k, (bx, by) in enumerate(((0.50, -0.06), (0.61, 0.03))):
    cyl(0.045, 0.30, (bx, by, 1.38), BOTTLE, rot=(0.25 * (1 if k else -1), 0.0, 0.0), seg=10)
    cyl(0.022, 0.10, (bx, by + (0.04 if k else -0.04), 1.58), GOLD, rot=(0.25 * (1 if k else -1), 0.0, 0.0), seg=8)
for bx in (-1.05, 1.05):                                                  # uç kandiller
    cyl(0.07, 0.02, (bx, 0, 1.13), GOLD, seg=12)
    cyl(0.05, 0.16, (bx, 0, 1.22), CRYSTAL, seg=10)
    ball(0.03, (bx, 0, 1.24), WARM, seg=8, ring=5)
for sx in (-0.75, 0.0, 0.75):                                             # bar tabureleri
    cyl(0.20, 0.03, (sx, -0.80, 0.015), GOLD, seg=14)
    cyl(0.03, 0.70, (sx, -0.80, 0.37), GOLD, seg=8)
    torus(0.15, 0.012, (sx, -0.80, 0.32), GOLD, seg=14, mseg=4)
    cyl(0.21, 0.10, (sx, -0.80, 0.75), VELVET_R, seg=16)
finish("lux_champagne_bar")

# ================================================================ 7) VIP KADİFE KÖŞE
clear()
def sofa_run(cx, cy, length, depth, along_x, back_side):
    """Düz kanepe bölümü: oturak, minder, sırt (dikiş düğmeleri), altın ayaklar."""
    sx, sy = (length, depth) if along_x else (depth, length)
    box((sx, sy, 0.30), (cx, cy, 0.25), VELVET_G)
    box((sx - 0.08, sy - 0.10, 0.12), (cx, cy - (0.04 if along_x else 0) * back_side, 0.46), VELVET_G)
    bx = cx + (0 if along_x else back_side * (depth / 2 - 0.10))
    by = cy + (back_side * (depth / 2 - 0.10) if along_x else 0)
    box((sx if along_x else 0.20, 0.20 if along_x else sy, 0.55), (bx, by, 0.66), VELVET_G)
    n = int(length / 0.30)
    for k in range(n):
        t = -length / 2 + 0.15 + k * (length - 0.30) / max(n - 1, 1)
        px = cx + t if along_x else bx - back_side * 0.105
        py = by - back_side * 0.105 if along_x else cy + t
        ball(0.022, (px, py, 0.72), GOLD, seg=6, ring=4)
    for t in (-length / 2 + 0.08, length / 2 - 0.08):
        for u in (-depth / 2 + 0.08, depth / 2 - 0.08):
            px, py = (cx + t, cy + u) if along_x else (cx + u, cy + t)
            cone(0.035, 0.02, 0.10, (px, py, 0.05), GOLD, seg=8)

sofa_run(-0.15, 0.55, 2.30, 0.85, True, 1)                                 # arka kol
sofa_run(-1.05, -0.40, 1.10, 0.85, False, -1)                              # sol kol
for (px, py) in ((1.05, 0.55), (-1.05, 0.78)):                             # kol dayamaları
    box((0.20, 0.85, 0.50), (px, py, 0.40), VELVET_G)
    cyl(0.10, 0.85, (px, py, 0.65), VELVET_G, rot=(R90, 0, 0), seg=10)
for (px, py, m) in ((-0.70, 0.40, GOLD), (-0.20, 0.40, VELVET_P), (-0.92, -0.10, VELVET_P)):
    box((0.34, 0.12, 0.32), (px, py, 0.66), m, rot=(-0.25, 0, 0))         # yastıklar
cyl(0.40, 0.04, (0.20, -0.35, 0.44), GLASS, seg=20)                        # sehpa
torus(0.40, 0.02, (0.20, -0.35, 0.44), GOLD, seg=20, mseg=4)
lathe([(0.24, 0.0), (0.10, 0.10), (0.06, 0.25), (0.14, 0.42)], GOLD, loc=(0.20, -0.35, 0.0), seg=12)
box((0.36, 0.24, 0.02), (0.20, -0.35, 0.47), GOLD)
cyl(0.04, 0.26, (0.14, -0.33, 0.61), BOTTLE, seg=10)
cyl(0.018, 0.08, (0.14, -0.33, 0.78), GOLD, seg=8)
for gx in (0.26, 0.32):
    cone(0.012, 0.035, 0.07, (gx, -0.40, 0.59), GLASS, seg=8)
box((2.9, 2.1, 0.012), (-0.10, -0.05, 0.006), mat("Hali", (0.55, 0.42, 0.25), 0.95))   # halı
for s in (-1, 1):
    box((2.9, 0.05, 0.014), (-0.10, -0.05 + s * 1.03, 0.008), GOLD)
    box((0.05, 2.1, 0.014), (-0.10 + s * 1.43, -0.05, 0.008), GOLD)
finish("lux_velvet_lounge")

# ================================================================ 8) DEV AKVARYUM
clear()
box((2.50, 0.80, 0.80), (0, 0, 0.42), MARBLE_K)                            # dolap
box((2.56, 0.86, 0.04), (0, 0, 0.02), GOLD)
box((2.56, 0.86, 0.04), (0, 0, 0.82), GOLD)
for k in range(4):
    box((0.56, 0.02, 0.62), (-0.90 + k * 0.60, -0.405, 0.42), MARBLE_K)
    frame(0.56, 0.62, -0.415, GOLD, t=0.02, d=0.01, z0=0.42, x0=-0.90 + k * 0.60)
# tank
box((2.40, 0.70, 0.10), (0, 0, 0.89), SAND)
box((2.36, 0.66, 1.05), (0, 0, 1.47), WATER)
for sx in (-1, 1):                                                         # altın köşe dikmeleri
    for sy in (-1, 1):
        box((0.04, 0.04, 1.20), (sx * 1.20, sy * 0.35, 1.44), GOLD)
box((2.46, 0.76, 0.08), (0, 0, 2.08), BLACK)                               # kapak
box((2.36, 0.04, 0.03), (0, -0.37, 2.03), WARM)
for (cx, cy, h, r, m) in ((-0.85, 0.10, 0.45, 0.10, CORAL_P), (-0.70, -0.05, 0.30, 0.08, CORAL_O),
                          (0.65, 0.12, 0.55, 0.11, CORAL_P), (0.85, -0.10, 0.32, 0.07, CORAL_O),
                          (0.10, 0.20, 0.38, 0.09, CORAL_O)):
    cone(r, 0.02, h, (cx, cy, 0.94 + h / 2), m, seg=7)
    cone(r * 0.6, 0.01, h * 0.7, (cx + 0.07, cy, 0.94 + h * 0.35), m, seg=6, rot=(0, 0.4, 0))
for (cx, cy, r) in ((-0.30, 0.15, 0.16), (0.30, 0.18, 0.12), (-0.05, 0.05, 0.10)):
    ball(r, (cx, cy, 0.96), mat("Kaya", (0.35, 0.33, 0.30), 0.9), scale=(1.4, 1.0, 0.7), seg=8, ring=5)
for (fx, fz, m, flip) in ((-0.55, 1.60, FISH_O, 1), (0.20, 1.80, FISH_Y, -1), (0.55, 1.35, FISH_B, 1),
                          (-0.15, 1.25, FISH_Y, 1), (0.85, 1.75, FISH_O, -1), (-0.90, 1.85, FISH_B, -1),
                          (0.40, 1.55, FISH_O, 1)):
    ball(0.07, (fx, -0.10, fz), m, scale=(1.6, 0.55, 1.0), seg=8, ring=5)
    cone(0.06, 0.0, 0.08, (fx - flip * 0.15, -0.10, fz), m, rot=(0, flip * R90, 0), seg=4)
for k in range(10):                                                        # hava kabarcıkları
    ball(0.018, (0.95, 0.20, 1.05 + k * 0.10), FOAM, seg=6, ring=4)
finish("lux_aquarium")

# ================================================================ 9) MERMER ŞÖMİNE
clear()
marble_slab((2.10, 0.70, 0.12), (0, -0.10, 0.06), veins=3, material=MARBLE_K, vein=GOLD)
for s in (-1, 1):                                                          # sütunlar
    marble_slab((0.32, 0.40, 1.15), (s * 0.80, 0.0, 0.70), veins=2)
    box((0.38, 0.46, 0.06), (s * 0.80, 0.0, 0.15), GOLD)
    box((0.38, 0.46, 0.06), (s * 0.80, 0.0, 1.25), GOLD)
marble_slab((1.40, 0.40, 0.25), (0, 0.0, 1.15))                            # alın
box((2.20, 0.55, 0.08), (0, -0.04, 1.33), MARBLE)                          # raf
box((2.24, 0.59, 0.03), (0, -0.04, 1.29), GOLD)
box((1.24, 0.30, 0.90), (0, 0.06, 0.57), BLACK)                            # ocak
frame(1.30, 0.92, -0.12, GOLD, t=0.04, d=0.03, z0=0.58)
for (lx, ly, rz) in ((-0.20, 0.0, 0.2), (0.15, 0.03, -0.25), (0.0, -0.05, 0.05)):
    cyl(0.07, 0.65, (lx, ly - 0.02, 0.24), BARK, rot=(0, R90, rz), seg=8)
for (fx, h, r, m) in ((-0.25, 0.42, 0.13, FIRE_O), (0.22, 0.38, 0.12, FIRE_O), (0.0, 0.55, 0.16, FIRE_O),
                      (-0.08, 0.36, 0.08, FIRE_Y), (0.10, 0.30, 0.07, FIRE_Y)):
    cone(r, 0.0, h, (fx, -0.02, 0.30 + h / 2), m, seg=7)
for s in (-1, 1):                                                          # şamdanlar
    cyl(0.05, 0.03, (s * 0.85, -0.10, 1.385), GOLD, seg=10)
    cyl(0.03, 0.22, (s * 0.85, -0.10, 1.51), WHITE, seg=8)
    ball(0.028, (s * 0.85, -0.10, 1.65), FIRE_Y, scale=(1, 1, 1.5), seg=6, ring=4)
cyl(0.16, 0.06, (0, -0.10, 1.53), GOLD, rot=(R90, 0, 0), seg=18)           # masa saati
cyl(0.13, 0.065, (0, -0.10, 1.53), WHITE, rot=(R90, 0, 0), seg=18)
box((0.10, 0.10, 0.08), (0, -0.10, 1.39), GOLD)
box((0.012, 0.005, 0.09), (0, -0.14, 1.56), BLACK)
box((0.07, 0.005, 0.012), (0.03, -0.14, 1.53), BLACK)
box((1.70, 0.04, 1.05), (0, 0.16, 2.02), mat("Ayna", (0.70, 0.78, 0.85), 0.05, 0.2))   # ayna
frame(1.80, 1.15, 0.13, GOLD, t=0.07, d=0.05, z0=2.02)
for s in (-1, 1):
    ball(0.05, (s * 0.90, 0.12, 2.60), GOLD, seg=8, ring=5)
finish("lux_marble_fireplace")

# ================================================================ 10) YARIŞ SİMÜLATÖRÜ
clear()
box((1.90, 1.70, 0.05), (0, -0.05, 0.025), BLACK)                          # zemin plakası
box((1.94, 0.02, 0.02), (0, -0.91, 0.04), N_CYAN)                          # led kenar
box((1.94, 0.02, 0.02), (0, 0.81, 0.04), N_CYAN)
for x in (-0.30, 0.30):                                                    # karbon şasi
    rod((x, 0.60, 0.10), (x, -0.55, 0.10), 0.035, CARBON, seg=8)
rod((-0.30, -0.55, 0.10), (0.30, -0.55, 0.10), 0.035, CARBON, seg=8)
rod((-0.30, 0.60, 0.10), (0.30, 0.60, 0.10), 0.035, CARBON, seg=8)
for x in (-0.24, 0.24):                                                    # direksiyon kolonu
    rod((x, -0.50, 0.10), (x, -0.42, 0.70), 0.03, CARBON, seg=8)
box((0.56, 0.10, 0.06), (0, -0.42, 0.70), CARBON)
box((0.50, 0.55, 0.12), (0, 0.22, 0.30), RED)                              # koltuk oturağı
box((0.50, 0.14, 0.70), (0, 0.52, 0.62), RED, rot=(-0.30, 0, 0))           # sırt
for sx in (-1, 1):                                                         # yan destekler
    box((0.08, 0.50, 0.18), (sx * 0.25, 0.22, 0.42), RED)
    box((0.08, 0.14, 0.62), (sx * 0.25, 0.50, 0.64), RED, rot=(-0.30, 0, 0))
box((0.30, 0.12, 0.12), (0, 0.64, 0.98), BLACK, rot=(-0.30, 0, 0))         # baş desteği
box((0.06, 0.02, 0.62), (0, 0.44, 0.64), BLACK, rot=(-0.30, 0, 0))         # sırt şeridi
torus(0.17, 0.028, (0, -0.47, 0.84), BLACK, rot=(R90 - 0.30, 0, 0), seg=16, mseg=5)   # direksiyon
cyl(0.055, 0.08, (0, -0.44, 0.82), GOLD, rot=(R90 - 0.30, 0, 0), seg=10)
for k in range(3):                                                         # pedallar
    box((0.07, 0.02, 0.13), (-0.10 + k * 0.10, -0.48, 0.20), CHROME, rot=(0.45, 0, 0))
# üç ekran sürücüyü sarar: orta ekran önde, yanlar sürücüye dönük (ekran yüzü +Y yönünde, sürücüye bakar)
for k in (-1, 0, 1):
    yaw = k * 0.75
    c = mathutils.Vector((k * 0.66, -0.95 + abs(k) * 0.32, 1.05))
    face = mathutils.Vector((-_m.sin(yaw), _m.cos(yaw), 0.0))
    box((0.70, 0.05, 0.42), tuple(c), BLACK, rot=(0, 0, yaw))
    box((0.66, 0.02, 0.38), tuple(c + face * 0.03), SCREEN, rot=(0, 0, yaw))
    rod((c.x, c.y, c.z - 0.21), (c.x, c.y, 0.05), 0.025, CARBON, seg=6)
turn_all(_m.pi)   # oyun kamerası önden bakar: koltuğun sırtı ve ekranların yüzü görünsün
finish("lux_racing_sim")

# ================================================================ 11) ALTIN JANT KULESİ
clear()
cyl(0.62, 0.12, (0, 0, 0.06), MARBLE_K, seg=20)
torus(0.62, 0.025, (0, 0, 0.12), N_GOLD, seg=24, mseg=4)
cyl(0.05, 2.30, (0, 0.10, 1.24), CHROME, seg=10)
cone(0.12, 0.0, 0.20, (0, 0.10, 2.48), GOLD, seg=10)


def rim(center, yaw):
    """Önü −Y'ye (yaw ile döner) bakan lastik + altın jant."""
    torus(0.30, 0.07, center, BLACK, rot=(R90, 0, yaw), seg=20, mseg=6)    # lastik
    torus(0.23, 0.022, center, GOLD, rot=(R90, 0, yaw), seg=20, mseg=4)    # jant dudağı
    for k in range(5):
        box((0.045, 0.03, 0.23), center, GOLD, rot=(0, k * 2.0 * _m.pi / 5, yaw))
    cyl(0.055, 0.07, center, GOLD, rot=(R90, 0, yaw), seg=10)


for i, z in enumerate((0.50, 1.18, 1.86)):                                 # üç jant, öne bakar, hafif açılı
    yaw = 0.35 if i % 2 else -0.35
    rod((0, 0.10, z), (0, -0.05, z), 0.03, CHROME)
    rim((0.0, -0.10, z), yaw)
finish("lux_gold_rim_tower")

# ================================================================ 12) ALTIN V12 MOTOR
clear()
plinth(1.70, 1.10, 0.50)
box((0.50, 0.04, 0.12), (0, -0.57, 0.28), GOLD)                            # plaket
text("V12", 0.08, (0, -0.60, 0.28), BLACK, depth=0.01)
box((1.10, 0.55, 0.16), (0, 0, 0.60), GOLD_D)                              # karter
box((1.20, 0.50, 0.30), (0, 0, 0.83), GOLD)                                # blok
for s in (-1, 1):                                                          # V bankaları
    box((1.16, 0.26, 0.30), (0, s * 0.20, 1.04), GOLD, rot=(s * 0.55, 0, 0))
    box((1.12, 0.22, 0.08), (0, s * 0.29, 1.19), RED, rot=(s * 0.55, 0, 0))   # kırmızı külbütör
    for k in range(6):
        box((0.10, 0.20, 0.012), (-0.47 + k * 0.19, s * 0.31, 1.235), GOLD, rot=(s * 0.55, 0, 0))
    for k in range(6):                                                     # egzoz manifoldu
        rod((-0.47 + k * 0.19, s * 0.36, 0.95), (-0.40 + k * 0.17, s * 0.48, 0.78), 0.025, CHROME)
for k in range(12):                                                        # emme boruları
    x = -0.50 + (k % 6) * 0.20
    y = -0.06 if k < 6 else 0.06
    cyl(0.035, 0.22, (x, y, 1.30), GOLD, seg=8)
    torus(0.04, 0.01, (x, y, 1.41), CHROME, seg=8, mseg=4)
for (y, r) in ((0.0, 0.16), (0.16, 0.08), (-0.16, 0.08)):                   # kasnaklar
    cyl(r, 0.05, (-0.64, y, 0.80), CHROME, rot=(0, R90, 0), seg=14)
torus(0.17, 0.012, (-0.66, 0, 0.80), BLACK, rot=(0, R90, 0), seg=14, mseg=4)
for sx in (-1, 1):                                                         # sergi kordonu
    for sy in (-1, 1):
        cyl(0.02, 0.35, (sx * 0.82, sy * 0.52, 0.68), GOLD, seg=6)
        ball(0.03, (sx * 0.82, sy * 0.52, 0.86), GOLD, seg=6, ring=4)
finish("lux_gold_engine")

# ================================================================ 13) JAKUZİ
clear()
box((2.60, 2.60, 0.10), (0, 0, 0.05), TEAK)                               # güverte
for (cx, cy, sx, sy) in ((0, 1.12, 2.40, 0.16), (0, -1.12, 2.40, 0.16), (1.12, 0, 0.16, 2.08),
                         (-1.12, 0, 0.16, 2.08)):
    box((sx, sy, 0.75), (cx, cy, 0.47), TEAK)                              # duvarlar
    box((sx + 0.04, sy + 0.04, 0.05), (cx, cy, 0.87), MARBLE)              # mermer kenar
for k in range(12):
    box((0.012, 0.012, 0.74), (-1.10 + k * 0.20, -1.205, 0.47), WALNUT)
box((2.08, 2.08, 0.50), (0, 0, 0.35), mat("HavuzIc", (0.10, 0.45, 0.60), 0.3))   # iç
box((2.06, 2.06, 0.06), (0, 0, 0.74), POOL)                                # su
for (bx, by) in ((-0.6, 0.5), (0.4, 0.6), (0.6, -0.4), (-0.3, -0.5), (0.0, 0.1), (-0.7, -0.1), (0.75, 0.2)):
    for k in range(3):
        ball(0.03 + 0.01 * (k % 2), (bx + 0.05 * k, by - 0.04 * k, 0.78), FOAM, seg=6, ring=4)
for s in (-1, 1):                                                          # led kuşak
    box((2.06, 0.02, 0.03), (0, s * 1.03, 0.70), N_CYAN)
    box((0.02, 2.06, 0.03), (s * 1.03, 0, 0.70), N_CYAN)
box((1.00, 0.32, 0.24), (0, -1.46, 0.12), TEAK)                          # basamaklar
box((1.00, 0.20, 0.52), (0, -1.30, 0.26), TEAK)
for s in (-1, 1):                                                          # altın tırabzan
    rod((s * 0.55, -1.55, 0.25), (s * 0.55, -1.55, 0.95), 0.025, GOLD)
    rod((s * 0.55, -1.55, 0.95), (s * 0.55, -1.15, 1.05), 0.025, GOLD)
    rod((s * 0.55, -1.15, 1.05), (s * 0.55, -0.95, 0.80), 0.025, GOLD)
box((0.40, 0.25, 0.06), (0.95, 1.00, 0.92), TOWEL)                         # havlu
box((0.36, 0.21, 0.05), (0.95, 1.00, 0.97), TOWEL)
for gx in (-0.95, -0.85):                                                  # kadehler
    cone(0.012, 0.035, 0.07, (gx, 1.05, 0.96), GLASS, seg=8)
cyl(0.04, 0.24, (-0.75, 1.08, 1.01), BOTTLE, seg=10)
finish("lux_hot_tub")

# ================================================================ 14) ŞAMPİYONLUK KUPASI
clear()
plinth(0.95, 0.95, 0.55)
box((0.60, 0.04, 0.16), (0, -0.50, 0.30), GOLD)
text("1", 0.14, (0, -0.53, 0.30), BLACK, depth=0.01)
cup = [(0.34, 0.0), (0.34, 0.05), (0.20, 0.10), (0.10, 0.20), (0.07, 0.55), (0.14, 0.62), (0.08, 0.70),
       (0.12, 0.76), (0.32, 0.92), (0.46, 1.20), (0.52, 1.50), (0.55, 1.62), (0.50, 1.64), (0.0, 1.60)]
lathe(cup, GOLD, loc=(0, 0, 0.55), seg=22)
torus(0.52, 0.03, (0, 0, 2.15), GOLD_D, seg=22, mseg=5)
for s in (-1, 1):                                                          # kulplar
    torus(0.24, 0.035, (s * 0.58, 0, 1.75), GOLD, rot=(R90, 0, 0), seg=14, mseg=6)
lathe([(0.48, 0.0), (0.42, 0.10), (0.18, 0.22), (0.08, 0.30), (0.0, 0.32)], GOLD, loc=(0, 0, 2.18), seg=22)
ball(0.09, (0, 0, 2.56), GOLD, seg=12, ring=8)
gem(0.07, 0.04, 0.09, (0, -0.47, 1.62), DIAMOND, seg=8)                    # kupadaki taş
for s in (-1, 1):
    gem(0.045, 0.03, 0.06, (s * 0.30, -0.40, 1.55), mat("Yakut", (0.9, 0.05, 0.12), 0.05, emit=(0.4, 0.02, 0.05),
                                                           alpha=0.85), seg=6)
finish("lux_champion_trophy")

# ================================================================ 15) DEV ELMAS HEYKELİ
clear()
lathe([(0.55, 0.0), (0.55, 0.06), (0.42, 0.10), (0.40, 0.80), (0.48, 0.86), (0.48, 0.92)], MARBLE_K,
      seg=8, smooth=False)
for z in (0.04, 0.10, 0.86, 0.92):
    torus(0.50 if z > 0.5 else 0.56, 0.022, (0, 0, z), GOLD, seg=8, mseg=4)
torus(0.42, 0.03, (0, 0, 1.02), N_CYAN, seg=24, mseg=4)                    # süzülme halkası
torus(0.30, 0.02, (0, 0, 1.06), N_CYAN, seg=20, mseg=4)
gem(0.62, 0.30, 0.70, (0, 0, 1.85), DIAMOND, seg=10, table=0.52)          # elmas (süzülüyor)
gem(0.42, 0.20, 0.47, (0, 0, 1.85), mat("ElmasIc", (0.95, 1.0, 1.0), 0.05, emit=(0.6, 0.9, 1.0), alpha=0.5),
    seg=10, table=0.5)
for (sx, sz, s) in ((-0.75, 2.30, 0.10), (0.70, 1.55, 0.08), (0.55, 2.45, 0.06), (-0.62, 1.50, 0.07)):
    for a in (0.0, R90):                                                   # parıltı yıldızları
        box((s * 2.2, 0.01, s * 0.25), (sx, -0.05, sz), mat("Parilti", (1, 1, 1), 0.2, emit=(1, 1, 1)), rot=(0, a, 0))
finish("lux_diamond_statue")

# ================================================================ 16) MERMER ÇEŞME
clear()
lathe([(1.55, 0.0), (1.62, 0.05), (1.62, 0.40), (1.55, 0.48), (1.42, 0.48), (1.40, 0.16), (0.0, 0.16)],
      MARBLE, seg=24)
torus(1.58, 0.035, (0, 0, 0.46), GOLD, seg=28, mseg=5)
cyl(1.41, 0.04, (0, 0, 0.40), WATER, seg=24)
lathe([(0.30, 0.16), (0.24, 0.30), (0.18, 0.70), (0.24, 0.85), (0.16, 0.95), (0.70, 1.12), (0.78, 1.20),
       (0.72, 1.24), (0.10, 1.12)], MARBLE, seg=20)
cyl(0.70, 0.03, (0, 0, 1.18), WATER, seg=20)
torus(0.75, 0.025, (0, 0, 1.22), GOLD, seg=22, mseg=4)
lathe([(0.12, 1.24), (0.09, 1.55), (0.14, 1.62), (0.38, 1.72), (0.40, 1.78), (0.06, 1.70)], MARBLE, seg=16)
cyl(0.36, 0.02, (0, 0, 1.75), WATER, seg=16)
torus(0.39, 0.02, (0, 0, 1.78), GOLD, seg=18, mseg=4)
lathe([(0.10, 1.78), (0.05, 1.92), (0.10, 2.00), (0.16, 2.10), (0.10, 2.24), (0.0, 2.28)], GOLD, seg=14)
ball(0.07, (0, 0, 2.32), GOLD, seg=10, ring=6)
for k in range(10):                                                        # düşen su perdeleri
    a = k * 2.0 * _m.pi / 10
    rod((0.74 * _m.cos(a), 0.74 * _m.sin(a), 1.20), (0.95 * _m.cos(a), 0.95 * _m.sin(a), 0.42), 0.03, WATER, seg=5)
for k in range(6):
    a = k * 2.0 * _m.pi / 6 + 0.3
    rod((0.38 * _m.cos(a), 0.38 * _m.sin(a), 1.76), (0.55 * _m.cos(a), 0.55 * _m.sin(a), 1.20), 0.022, WATER, seg=5)
for k in range(8):                                                         # havuz içi ışıklar
    a = k * 2.0 * _m.pi / 8
    ball(0.04, (1.20 * _m.cos(a), 1.20 * _m.sin(a), 0.20), WARM, seg=6, ring=4)
for k in range(4):                                                         # bozuk paralar
    cyl(0.03, 0.006, (0.5 + 0.12 * k, -0.4 + 0.1 * k, 0.17), GOLD, seg=8)
finish("lux_marble_fountain")

# ================================================================ 17) ALTIN SPOR ARABA HEYKELİ
clear()
lathe([(1.95, 0.0), (1.95, 0.08), (1.85, 0.12), (1.80, 0.38), (1.90, 0.42), (1.90, 0.48)], MARBLE_K, seg=28)
torus(1.90, 0.035, (0, 0, 0.47), GOLD, seg=32, mseg=5)
torus(1.96, 0.035, (0, 0, 0.06), GOLD, seg=32, mseg=5)
for k in range(16):                                                        # kaide ışıkları
    a = k * 2.0 * _m.pi / 16
    ball(0.035, (1.86 * _m.cos(a), 1.86 * _m.sin(a), 0.25), N_GOLD, seg=6, ring=4)
Z0 = 0.50
side = [(-1.72, 0.20), (-1.78, 0.36), (-1.68, 0.48), (-1.05, 0.58), (-0.55, 0.64), (0.95, 0.66), (1.50, 0.68),
        (1.74, 0.62), (1.78, 0.44), (1.72, 0.22), (1.30, 0.18), (-1.30, 0.18)]
prism([(x, z + Z0) for (x, z) in side], 1.60, 'xz', GOLD, offset=0.0)      # alt gövde (bel çizgisine kadar)
glass = [(-0.62, 0.62), (-0.22, 0.93), (0.48, 0.96), (0.98, 0.66)]
prism([(x, z + Z0) for (x, z) in glass], 1.34, 'xz', mat("KoyuCam", (0.03, 0.05, 0.08), 0.06, 0.2,
                                                           emit=(0.02, 0.04, 0.07)), offset=0.0)
roof = [(-0.24, 0.93), (-0.10, 0.99), (0.46, 1.01), (0.52, 0.96)]
prism([(x, z + Z0) for (x, z) in roof], 1.26, 'xz', GOLD, offset=0.0)     # tavan
for sy in (-1, 1):                                                         # kapı çizgisi ve yan ızgara
    box((0.02, 0.01, 0.30), (0.10, sy * 0.805, Z0 + 0.42), GOLD_D)
    box((0.40, 0.01, 0.06), (0.55, sy * 0.805, Z0 + 0.40), BLACK)
for sx in (-1.08, 1.12):                                                   # tekerlekler
    for sy in (-1, 1):
        cyl(0.33, 0.24, (sx, sy * 0.70, Z0 + 0.33), BLACK, rot=(R90, 0, 0), seg=18)
        cyl(0.23, 0.26, (sx, sy * 0.70, Z0 + 0.33), GOLD_D, rot=(R90, 0, 0), seg=14)
        for k in range(5):
            box((0.04, 0.27, 0.21), (sx, sy * 0.70, Z0 + 0.33), GOLD, rot=(0, k * 2.0 * _m.pi / 5, 0))
for sy in (-1, 1):                                                         # far / stop
    box((0.05, 0.30, 0.08), (-1.76, sy * 0.48, Z0 + 0.42), WARM)
    box((0.05, 0.30, 0.06), (1.76, sy * 0.48, Z0 + 0.58), mat("Stop", (0.9, 0.05, 0.05), 0.3, emit=(0.6, 0.02, 0.02)))
box((0.30, 1.62, 0.04), (1.60, 0, Z0 + 0.90), GOLD)                        # rüzgârlık
for sy in (-1, 1):
    box((0.08, 0.04, 0.22), (1.55, sy * 0.70, Z0 + 0.78), GOLD)
box((0.70, 0.04, 0.16), (0, -1.94, 0.25), GOLD)                            # plaket
text("AUTO YARD", 0.08, (0, -1.97, 0.25), BLACK, depth=0.01)
finish("lux_gold_car_statue")

# ================================================================ 18) ÖZEL HELİKOPTER
clear()
cyl(3.10, 0.10, (0, 0, 0.05), mat("Pist", (0.16, 0.17, 0.19), 0.85), seg=32)   # helipad
torus(2.85, 0.06, (0, 0, 0.10), YEL, seg=36, mseg=4)
for (sx, sy, x, y) in ((0.22, 1.60, -0.55, 0), (0.22, 1.60, 0.55, 0), (0.90, 0.22, 0, 0)):
    box((sx, sy, 0.02), (x, y + 1.35, 0.11), WHITE)                        # H (arkada)
for k in range(16):
    a = k * 2.0 * _m.pi / 16
    ball(0.06, (3.0 * _m.cos(a), 3.0 * _m.sin(a), 0.12), N_GOLD if k % 2 else N_CYAN, seg=6, ring=4)
HZ = 0.25
for sy in (-1, 1):                                                         # kızaklar
    rod((-1.25, sy * 0.70, HZ), (1.10, sy * 0.70, HZ), 0.05, BLACK, seg=8)
    rod((1.10, sy * 0.70, HZ), (1.35, sy * 0.70, HZ + 0.18), 0.05, BLACK, seg=8)
    for x in (-0.70, 0.55):
        rod((x, sy * 0.70, HZ), (x, sy * 0.40, HZ + 0.62), 0.04, BLACK, seg=6)
ball(1.0, (0.10, 0, HZ + 1.25), BLACK, scale=(1.75, 0.85, 0.80), seg=18, ring=12)   # gövde
ball(0.80, (-0.75, 0, HZ + 1.38), mat("Kokpit", (0.10, 0.18, 0.28), 0.05, 0.2, emit=(0.03, 0.06, 0.10)),
     scale=(1.0, 0.82, 0.70), seg=16, ring=10)                             # kokpit camı (ön = −X)
torus(0.86, 0.04, (0.55, 0, HZ + 1.25), GOLD, rot=(0, R90, 0), seg=24, mseg=4)
box((2.2, 0.02, 0.10), (0.40, -0.83, HZ + 1.15), GOLD)
box((2.2, 0.02, 0.10), (0.40, 0.83, HZ + 1.15), GOLD)
tail = [(1.60, -0.30, 1.10), (1.60, 0.30, 1.10), (1.60, 0.30, 1.55), (1.60, -0.30, 1.55),
        (4.30, -0.08, 1.45), (4.30, 0.08, 1.45), (4.30, 0.08, 1.60), (4.30, -0.08, 1.60)]
mesh_obj([(x, y, z + HZ) for (x, y, z) in tail],
         [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], BLACK)
fin = [(3.90, 0.0, 1.50), (4.45, 0.0, 1.50), (4.55, 0.0, 2.25), (4.25, 0.0, 2.25)]
mesh_obj([(x, -0.03, z + HZ) for (x, _y, z) in fin] + [(x, 0.03, z + HZ) for (x, _y, z) in fin],
         [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], GOLD)
box((0.70, 0.90, 0.04), (3.90, 0, HZ + 1.52), BLACK)                       # yatay dengeleyici
cyl(0.05, 0.12, (4.35, 0.10, HZ + 1.80), CHROME, rot=(R90, 0, 0), seg=8)   # kuyruk rotoru
for a in (0.0, R90):
    box((0.03, 0.02, 0.70), (4.35, 0.16, HZ + 1.80), CARBON, rot=(0, a, 0))
cyl(0.10, 0.35, (0.20, 0, HZ + 2.12), CHROME, seg=10)                      # rotor mili
cyl(0.18, 0.08, (0.20, 0, HZ + 2.30), GOLD, seg=12)
for k in range(4):                                                         # ana pervane
    a = k * R90 + 0.35
    box((3.30, 0.22, 0.03), (0.20 + 1.70 * _m.cos(a), 1.70 * _m.sin(a), HZ + 2.33), CARBON, rot=(0, 0, a))
    box((0.30, 0.23, 0.032), (0.20 + 3.20 * _m.cos(a), 3.20 * _m.sin(a), HZ + 2.33), GOLD, rot=(0, 0, a))
for sy in (-1, 1):                                                         # kapı çizgisi + basamak
    box((0.02, 0.01, 0.60), (-0.20, sy * 0.86, HZ + 1.20), GOLD)
    box((0.60, 0.20, 0.03), (-0.20, sy * 0.92, HZ + 0.62), CHROME)
finish("lux_helicopter")

# ================================================================ 19) ALTIN ÇERÇEVELİ TABLO (duvar)
clear()
box((1.60, 0.03, 1.10), (0, -0.02, 0.62), SKY_V)                            # tuval: gün batımı
box((1.60, 0.005, 0.38), (0, -0.036, 0.92), SKY_O)
box((1.60, 0.005, 0.22), (0, -0.037, 0.70), SKY_P)
cyl(0.16, 0.005, (0.38, -0.040, 0.80), mat("Gunes", (1.0, 0.85, 0.40), 0.4, emit=(0.6, 0.45, 0.15)),
    rot=(R90, 0, 0), seg=16)
box((1.60, 0.006, 0.20), (0, -0.041, 0.17 + 0.10), mat("Yol", (0.10, 0.10, 0.12), 0.8))
box((1.50, 0.007, 0.01), (0, -0.045, 0.27), YEL)
car = [(-0.42, 0.30), (-0.44, 0.36), (-0.30, 0.40), (-0.12, 0.47), (0.12, 0.47), (0.26, 0.40), (0.42, 0.38),
       (0.44, 0.31)]
prism(car, 0.01, 'xz', RED, offset=-0.048)
for x in (-0.26, 0.28):
    cyl(0.05, 0.01, (x, -0.054, 0.31), BLACK, rot=(R90, 0, 0), seg=10)
frame(1.78, 1.28, -0.035, GOLD, t=0.10, d=0.07, z0=0.62)                    # altın çerçeve
frame(1.66, 1.16, -0.072, GOLD_D, t=0.025, d=0.01, z0=0.62)
for sx in (-1, 1):
    for sz in (-1, 1):
        ball(0.06, (sx * 0.86, -0.07, 0.62 + sz * 0.61), GOLD, seg=8, ring=5)
box((0.50, 0.08, 0.04), (0, -0.09, 1.32), GOLD)                            # tablo lambası
cyl(0.03, 0.46, (0, -0.13, 1.32), WARM, rot=(0, R90, 0), seg=8)
finish("lux_gold_painting")

# ================================================================ 20) KRİSTAL APLİKLER (duvar)
clear()
for sx in (-0.50, 0.50):
    cyl(0.11, 0.03, (sx, -0.015, 0.45), GOLD, rot=(R90, 0, 0), seg=12)
    rod((sx, -0.03, 0.40), (sx, -0.22, 0.30), 0.016, GOLD)
    rod((sx, -0.22, 0.30), (sx, -0.26, 0.42), 0.016, GOLD)
    lathe([(0.03, 0.0), (0.07, 0.04), (0.09, 0.06)], GOLD, loc=(sx, -0.26, 0.42), seg=10)
    ball(0.055, (sx, -0.26, 0.53), WARM, scale=(1, 1, 1.4), seg=10, ring=6)
    torus(0.11, 0.008, (sx, -0.26, 0.47), GOLD, seg=12, mseg=4)
    for k in range(8):
        a = k * 2.0 * _m.pi / 8
        cone(0.016, 0.0, 0.08, (sx + 0.11 * _m.cos(a), -0.26 + 0.11 * _m.sin(a), 0.41), CRYSTAL,
             rot=(_m.pi, 0, 0), seg=5)
    cone(0.025, 0.0, 0.12, (sx, -0.26, 0.24), CRYSTAL, rot=(_m.pi, 0, 0), seg=6)
finish("lux_crystal_sconces")

# ================================================================ 21) KUPA DUVARI (duvar)
clear()
box((1.80, 0.05, 1.40), (0, -0.025, 0.70), WALNUT)
frame(1.86, 1.46, -0.03, GOLD, t=0.05, d=0.06, z0=0.70)
box((1.70, 0.01, 1.30), (0, -0.052, 0.70), mat("ArkaIsik", (0.15, 0.08, 0.04), 0.6, emit=(0.18, 0.10, 0.03)))
for zs in (0.08, 0.52, 0.96):                                              # cam raflar
    box((1.70, 0.26, 0.02), (0, -0.16, zs), GLASS)
    box((1.70, 0.01, 0.02), (0, -0.29, zs), GOLD)
shelf_items = (((-0.62, 0.08), 0.30, GOLD), ((-0.20, 0.08), 0.22, CHROME), ((0.25, 0.08), 0.26, GOLD),
               ((0.65, 0.08), 0.18, GOLD_D), ((-0.55, 0.52), 0.24, CHROME), ((0.0, 0.52), 0.34, GOLD),
               ((0.55, 0.52), 0.24, GOLD), ((-0.45, 0.96), 0.22, GOLD), ((0.45, 0.96), 0.22, CHROME))
for ((x, z), h, m) in shelf_items:
    lathe([(0.06, 0.0), (0.03, 0.03), (0.02, h * 0.45), (0.05, h * 0.55), (0.09, h * 0.85), (0.10, h),
           (0.0, h * 0.98)], m, loc=(x, -0.16, z + 0.01), seg=10)
    for s in (-1, 1):
        torus(0.04, 0.008, (x + s * 0.10, -0.16, z + h * 0.75), m, rot=(R90, 0, 0), seg=8, mseg=4)
for x in (-0.22, 0.22):                                                    # madalyalar
    cyl(0.07, 0.012, (x, -0.17, 1.17), GOLD, rot=(R90, 0, 0), seg=12)
    box((0.04, 0.01, 0.12), (x, -0.165, 1.28), RED)
ball(0.06, (0, -0.16, 1.18), GOLD, seg=8, ring=5)
finish("lux_trophy_wall")

# ================================================================ 22) SİNEMA EKRANI (duvar)
clear()
box((2.80, 0.03, 1.66), (0, -0.015, 0.83), mat("Hale", (0.25, 0.10, 0.45), 0.4, emit=(0.30, 0.10, 0.55)))
box((2.62, 0.06, 1.50), (0, -0.05, 0.85), BLACK)                            # çerçeve
box((2.52, 0.01, 1.40), (0, -0.085, 0.85), mat("EkranGok", (0.10, 0.35, 0.80), 0.3, emit=(0.08, 0.30, 0.70)))
box((2.52, 0.012, 0.45), (0, -0.088, 0.38), mat("EkranPist", (0.12, 0.12, 0.15), 0.3, emit=(0.06, 0.06, 0.08)))
for k in range(6):                                                         # pist şeritleri
    box((0.20, 0.014, 0.02), (-1.0 + k * 0.40, -0.092, 0.38), mat("EkranSerit", (1, 1, 1), 0.3, emit=(0.8, 0.8, 0.8)))
for (x, m) in ((-0.40, mat("EkranKirmizi", (1.0, 0.1, 0.1), 0.3, emit=(0.8, 0.05, 0.05))),
               (0.45, mat("EkranSari", (1.0, 0.8, 0.1), 0.3, emit=(0.8, 0.6, 0.05)))):
    box((0.50, 0.015, 0.14), (x, -0.094, 0.50), m)
    box((0.26, 0.016, 0.08), (x - 0.04, -0.095, 0.60), m)
cyl(0.18, 0.012, (0.80, -0.090, 1.25), mat("EkranGunes", (1.0, 0.9, 0.6), 0.3, emit=(0.9, 0.8, 0.5)),
    rot=(R90, 0, 0), seg=14)
box((1.60, 0.14, 0.10), (0, -0.07, 0.0 + 0.05), BLACK)                     # ses çubuğu
for k in range(10):
    box((0.10, 0.005, 0.06), (-0.72 + k * 0.16, -0.142, 0.05), CARBON)
box((1.50, 0.005, 0.01), (0, -0.143, 0.10), N_CYAN)
finish("lux_cinema_wall")

# ================================================================ 23) ALTIN DİREKSİYON PANOSU (duvar)
clear()
box((1.10, 0.04, 1.20), (0, -0.02, 0.60), VELVET_R)
frame(1.18, 1.28, -0.03, GOLD, t=0.07, d=0.06, z0=0.60)
torus(0.34, 0.045, (0, -0.10, 0.70), GOLD, rot=(R90, 0, 0), seg=24, mseg=6)
for a in (0.0, 2.0 * _m.pi / 3, 4.0 * _m.pi / 3):
    box((0.05, 0.03, 0.34), (0.17 * _m.sin(a), -0.10, 0.70 + 0.17 * _m.cos(a)), GOLD, rot=(0, a, 0))
cyl(0.10, 0.06, (0, -0.11, 0.70), GOLD, rot=(R90, 0, 0), seg=14)
cyl(0.05, 0.03, (0, -0.15, 0.70), DIAMOND, rot=(R90, 0, 0), seg=8)
box((0.60, 0.03, 0.14), (0, -0.07, 0.17), GOLD)
text("AUTO YARD", 0.07, (0, -0.09, 0.17), BLACK, depth=0.008)
finish("lux_gold_wheel")

# ================================================================ 24) NEON TAÇ (duvar)
clear()
box((1.60, 0.03, 1.10), (0, -0.015, 0.55), mat("NeonZeminMor", (0.06, 0.02, 0.09), 0.4))
frame(1.66, 1.16, -0.02, GOLD, t=0.04, d=0.05, z0=0.55)
crown = [(-0.50, 0.55), (-0.50, 0.95), (-0.25, 0.72), (0.0, 1.00), (0.25, 0.72), (0.50, 0.95), (0.50, 0.55),
         (-0.50, 0.55)]
for i in range(len(crown) - 1):
    rod((crown[i][0], -0.06, crown[i][1]), (crown[i + 1][0], -0.06, crown[i + 1][1]), 0.022, N_GOLD, seg=6)
for (x, z) in ((-0.50, 0.95), (0.0, 1.00), (0.50, 0.95)):
    ball(0.045, (x, -0.06, z + 0.03), N_GOLD, seg=8, ring=5)
text("VIP", 0.30, (0, -0.06, 0.30), N_PINK, depth=0.03)
finish("lux_neon_crown")
