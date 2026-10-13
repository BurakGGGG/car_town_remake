"""DEKORASYON v3 — AVLU partisi: orijinal Car Town'un Misc (bariyer, varil, dur levhası, trafik lambası, yarış
başlangıç ışıkları) ve Functional (telefon kulübesi, çocuk binekleri) eşyaları + yarış kürsüsü.

Kurallar kit.py ile aynı: metre, ÖN = −Y, orijin tabanın ortası. Yazılar dilden bağımsız: STOP, rakamlar.
Kullanım: CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_avlu.py
"""
import math as _m

R90 = _m.radians(90)
DARK = mat("Koyu", (0.045, 0.048, 0.055), 0.7)
STEEL = mat("Celik", (0.34, 0.35, 0.37), 0.4, 0.7)
CHROME = mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
RED = mat("Kirmizi", (0.55, 0.05, 0.04), 0.5)
ORANGE = mat("Turuncu", (0.80, 0.25, 0.03), 0.5)
YEL = mat("Sari", (0.75, 0.52, 0.04), 0.5)
WHITE = mat("Beyaz", (0.84, 0.83, 0.80), 0.55)
BLUE = mat("Mavi", (0.05, 0.20, 0.55), 0.5)
GREEN = mat("Yesil", (0.06, 0.32, 0.15), 0.55)
PINK = mat("Pembe", (0.80, 0.30, 0.45), 0.5)
MINT = mat("Nane", (0.35, 0.72, 0.58), 0.5)
CONCRETE = mat("Beton", (0.52, 0.51, 0.48), 0.95)
RUBBER = mat("Lastik", (0.03, 0.03, 0.035), 0.9)
GOLD = mat("Altin", (0.75, 0.55, 0.12), 0.3, 0.9)
SILVER = mat("Gumus", (0.70, 0.72, 0.75), 0.25, 0.9)
BRONZE = mat("Bronz", (0.50, 0.28, 0.10), 0.3, 0.9)
GLASS = mat("Cam", (0.70, 0.85, 0.95), 0.08, 0.1, alpha=0.35)
L_RED = mat("IsikKirmizi", (1.0, 0.12, 0.08), 0.3, emit=(1.0, 0.1, 0.05))
L_YEL = mat("IsikSari", (1.0, 0.70, 0.10), 0.3, emit=(1.0, 0.65, 0.08))
L_GREEN = mat("IsikYesil", (0.15, 1.0, 0.30), 0.3, emit=(0.1, 1.0, 0.25))
L_OFF = mat("IsikSonuk", (0.10, 0.08, 0.06), 0.3)


def text(body, size, loc, material, depth=0.01):
    """Ön yüze (−Y) bakan yazı; mesh'e çevrilip koleksiyona konur. Konum yazının ORTASI."""
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.object
    t.data.body = body
    t.data.size = size
    t.data.extrude = depth
    t.data.resolution_u = 3          # harf kıvrımları kaba: üçgen bütçesi
    t.data.align_x = 'CENTER'
    t.data.align_y = 'CENTER'
    t.rotation_euler = (R90, 0, 0)
    t.location = loc
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _place(o, material)


# ---------------------------------------------------------------- 1) YANGIN MUSLUĞU
clear()
cyl(0.20, 0.06, (0, 0, 0.03), RED, seg=12)
cyl(0.15, 0.62, (0, 0, 0.36), RED, seg=14)
torus(0.155, 0.02, (0, 0, 0.62), RED, seg=14, mseg=4)
cone(0.16, 0.06, 0.16, (0, 0, 0.75), RED, seg=14)
cyl(0.035, 0.06, (0, 0, 0.86), RED, seg=6)
for a in (0.0, _m.pi):
    cyl(0.07, 0.12, (_m.cos(a) * 0.17, _m.sin(a) * 0.17, 0.48), RED, rot=(0, R90, 0), seg=10)
    cyl(0.05, 0.02, (_m.cos(a) * 0.24, _m.sin(a) * 0.24, 0.48), CHROME, rot=(0, R90, 0), seg=6)
cyl(0.09, 0.12, (0, -0.18, 0.40), RED, rot=(R90, 0, 0), seg=10)
cyl(0.07, 0.02, (0, -0.25, 0.40), CHROME, rot=(R90, 0, 0), seg=6)
finish("fire_hydrant")

# ---------------------------------------------------------------- 2) A TİPİ BARİYER
clear()
for s in (-1, 1):
    for t in (-1, 1):                                                 # A ayakları
        box((0.06, 0.06, 0.95), (s * 0.70, t * 0.14, 0.46), WHITE, rot=(t * _m.radians(-9), 0, 0))
for k, z in enumerate((0.78, 0.48)):                                 # şeritli paneller
    box((1.56, 0.04, 0.18), (0, -0.07, z), WHITE)
    for i in range(5):
        box((0.12, 0.045, 0.18), (-0.62 + i * 0.31, -0.07, z), ORANGE, rot=(0, _m.radians(35), 0))
box((0.14, 0.12, 0.10), (-0.70, 0, 0.98), L_YEL)                     # uyarı lambası
finish("a_barrier")

# ---------------------------------------------------------------- 3) TRAFİK VARİLLERİ (şeritli)
clear()
for i, (x, y) in enumerate(((-0.42, 0.0), (0.0, 0.08), (0.42, -0.04))):
    cyl(0.30, 0.06, (x, y, 0.03), RUBBER, seg=14)
    cyl(0.25, 0.92, (x, y, 0.52), ORANGE, seg=14)
    for z in (0.40, 0.70):
        cyl(0.255, 0.10, (x, y, z), WHITE, seg=14)
    cyl(0.20, 0.04, (x, y, 0.99), ORANGE, seg=14)
    cyl(0.03, 0.06, (x, y, 1.04), DARK, seg=6)
finish("traffic_drums")

# ---------------------------------------------------------------- 4) DUR LEVHASI
clear()
cyl(0.30, 0.10, (0, 0, 0.05), CONCRETE, seg=12)
cyl(0.03, 2.00, (0, 0, 1.05), STEEL, seg=8)
cyl(0.38, 0.03, (0, -0.04, 1.90), WHITE, rot=(R90, _m.pi / 8, 0), seg=8)
cyl(0.35, 0.035, (0, -0.045, 1.90), RED, rot=(R90, _m.pi / 8, 0), seg=8)
text("STOP", 0.20, (0, -0.07, 1.90), WHITE)
finish("stop_sign")

# ---------------------------------------------------------------- 5) POSTA KUTUSU
clear()
box((0.10, 0.10, 1.00), (0, 0.05, 0.50), DARK)
box((0.30, 0.50, 0.24), (0, 0, 1.12), BLUE)
cyl(0.15, 0.50, (0, 0, 1.24), BLUE, rot=(R90, 0, 0), seg=14)
box((0.18, 0.02, 0.10), (0, -0.25, 1.14), WHITE)
box((0.03, 0.18, 0.06), (0.17, 0.05, 1.32), RED)                     # bayrak
box((0.03, 0.10, 0.10), (0.17, 0.10, 1.40), RED)
finish("mailbox")

# ---------------------------------------------------------------- 6) BETON BARİYER (New Jersey)
clear()
profile = [(-0.30, 0.0), (0.30, 0.0), (0.30, 0.08), (0.22, 0.32), (0.10, 0.82), (-0.10, 0.82),
           (-0.22, 0.32), (-0.30, 0.08)]
for k in range(2):
    prism(profile, 1.95, 'yz', CONCRETE, offset=-1.0 + k * 2.0)
    for i in range(3):                                               # kırmızı-beyaz şerit
        box((0.30, 0.02, 0.12), (-1.6 + k * 2.0 + i * 0.60, -0.21, 0.56), RED if i % 2 == 0 else WHITE,
            rot=(_m.radians(-14), 0, 0))
finish("concrete_barrier")

# ---------------------------------------------------------------- 7) LASTİK BARİYER (pist kenarı)
clear()
for row in range(3):
    for i in range(5):
        x = -0.96 + i * 0.48
        torus(0.17, 0.07, (x, 0.0, 0.08 + row * 0.15), RUBBER, seg=12, mseg=5)
box((2.40, 0.04, 0.40), (0, -0.25, 0.26), WHITE)                      # önündeki kayış
for i in range(6):
    box((0.20, 0.045, 0.40), (-1.00 + i * 0.40, -0.25, 0.26), RED)
finish("tyre_wall")

# ---------------------------------------------------------------- 8) TELEFON KULÜBESİ
clear()
box((0.96, 0.96, 0.12), (0, 0, 0.06), RED)
for x in (-0.44, 0.44):
    for y in (-0.44, 0.44):
        box((0.10, 0.10, 2.20), (x, y, 1.20), RED)
for (x, y, w, d) in ((0, 0.44, 0.80, 0.04), (-0.44, 0, 0.04, 0.80), (0.44, 0, 0.04, 0.80)):
    box((w, d, 1.40), (x, y, 1.28), GLASS)
box((0.80, 0.04, 1.40), (0, -0.44, 1.28), GLASS)                     # kapı camı
for i in range(1, 6):                                                # pencere kayıtları
    z = 0.58 + i * 0.235
    box((0.88, 0.05, 0.035), (0, -0.45, z), RED)
    box((0.05, 0.88, 0.035), (-0.45, 0, z), RED)
    box((0.05, 0.88, 0.035), (0.45, 0, z), RED)
for s in (-1, 1):
    box((0.035, 0.05, 1.40), (s * 0.14, -0.45, 1.28), RED)
box((0.88, 0.88, 0.50), (0, 0, 0.33), RED)                           # alt panel
box((1.00, 1.00, 0.22), (0, 0, 2.08), RED)                           # tepe
box((0.80, 0.02, 0.14), (0, -0.505, 2.08), mat("TepeIsik", (0.95, 0.95, 0.9), 0.3, emit=(0.95, 0.92, 0.85)))
prism([(-0.50, 2.19), (0.50, 2.19), (0.30, 2.34), (-0.30, 2.34)], 1.0, 'xz', RED)
box((0.24, 0.10, 0.34), (0, 0.36, 1.30), DARK)                       # içerdeki telefon
box((0.06, 0.05, 0.18), (0.08, 0.32, 1.38), DARK)
finish("phone_booth")

# ---------------------------------------------------------------- 9) TRAFİK LAMBASI
clear()
cyl(0.24, 0.10, (0, 0, 0.05), CONCRETE, seg=12)
cyl(0.06, 2.10, (0, 0, 1.15), DARK, seg=10)
box((0.36, 0.30, 0.98), (0, 0, 2.62), DARK)
for i, m in enumerate((L_RED, L_OFF, L_GREEN)):
    z = 2.92 - i * 0.30
    cyl(0.11, 0.03, (0, -0.16, z), m, rot=(R90, 0, 0), seg=14)
    box((0.28, 0.14, 0.03), (0, -0.21, z + 0.12), DARK, rot=(_m.radians(-25), 0, 0))   # siperlik
box((0.40, 0.03, 1.02), (0, 0.16, 2.62), YEL)                        # arka levha
box((0.20, 0.12, 0.30), (0, -0.06, 1.20), mat("ButonKutu", (0.70, 0.55, 0.05), 0.5))
finish("traffic_light")

# ---------------------------------------------------------------- 10) DONDURMA ARABASI
clear()
box((1.20, 0.62, 0.70), (0, 0, 0.62), WHITE)
box((1.22, 0.64, 0.12), (0, 0, 0.30), PINK)
box((1.22, 0.64, 0.06), (0, 0, 1.00), PINK)
for k in range(3):                                                   # kapaklar
    box((0.30, 0.50, 0.04), (-0.38 + k * 0.38, 0, 1.05), CHROME)
for s in (-1, 1):
    torus(0.20, 0.035, (s * 0.40, -0.33, 0.24), DARK, rot=(R90, 0, 0), seg=16, mseg=4)
    for j in range(4):
        box((0.36, 0.015, 0.015), (s * 0.40, -0.33, 0.24), CHROME, rot=(0, _m.tau * j / 8.0, 0))
box((0.04, 0.04, 0.50), (0.72, 0, 0.60), CHROME)                     # sap
cyl(0.03, 1.60, (-0.40, 0.10, 1.80), WHITE, seg=6)                   # şemsiye direği
cone(0.85, 0.04, 0.35, (-0.40, 0.10, 2.62), MINT, seg=12)
torus(0.80, 0.05, (-0.40, 0.10, 2.46), PINK, seg=16, mseg=4)               # şemsiye fırfırı
cone(0.30, 0.04, 0.12, (-0.40, 0.10, 2.82), PINK, seg=12)
for (x, m) in ((0.10, PINK), (0.30, MINT), (0.50, mat("Vanilya", (0.90, 0.80, 0.55), 0.6))):  # külahlar
    cone(0.05, 0.0, 0.16, (x, -0.10, 1.12), mat("Kulah", (0.60, 0.38, 0.12), 0.8), rot=(_m.pi, 0, 0), seg=8)
    ball(0.06, (x, -0.10, 1.24), m, seg=8, ring=5)
finish("ice_cream_cart")

# ---------------------------------------------------------------- 11) ÇOCUK ARABASI (jetonlu binek)
clear()
box((1.10, 0.80, 0.24), (0, 0, 0.12), mat("Platform", (0.55, 0.38, 0.06), 0.5))
CAR = mat("BinekKirmizi", (0.62, 0.06, 0.05), 0.25, 0.2)
prism([(-0.48, 0.30), (0.48, 0.30), (0.50, 0.50), (0.30, 0.56), (0.10, 0.82), (-0.24, 0.82),
       (-0.36, 0.56), (-0.50, 0.52)], 0.56, 'xz', CAR)
box((0.30, 0.48, 0.20), (-0.07, 0, 0.74), GLASS)                      # ön cam
box((0.30, 0.40, 0.08), (0.02, 0, 0.58), DARK)                        # koltuk boşluğu
cyl(0.07, 0.02, (-0.20, 0, 0.66), DARK, rot=(0, _m.radians(60), 0), seg=10)   # direksiyon
for x in (-0.32, 0.32):
    for y in (-0.29, 0.29):
        cyl(0.12, 0.08, (x, y, 0.34), RUBBER, rot=(R90, 0, 0), seg=12)
        cyl(0.06, 0.085, (x, y, 0.34), CHROME, rot=(R90, 0, 0), seg=8)
for y in (-0.15, 0.15):
    ball(0.045, (-0.50, y, 0.45), L_YEL, seg=8, ring=5)              # farlar
text("7", 0.14, (0.20, -0.29, 0.44), WHITE)
box((0.16, 0.12, 0.40), (0.50, 0.30, 0.44), DARK)                     # jeton kutusu
box((0.04, 0.02, 0.06), (0.50, 0.235, 0.56), YEL)
finish("kiddie_car")

# ---------------------------------------------------------------- 12) UZAY GEMİSİ BİNEĞİ
clear()
cyl(0.55, 0.20, (0, 0, 0.10), mat("Platform2", (0.10, 0.12, 0.30), 0.5), seg=18)
SHIP = mat("Gemi", (0.80, 0.80, 0.82), 0.3, 0.4)
cyl(0.22, 0.90, (0, 0, 0.80), SHIP, seg=16)
cone(0.22, 0.0, 0.55, (0, 0, 1.52), RED, seg=16)
cone(0.30, 0.22, 0.18, (0, 0, 0.30), SHIP, seg=16)
for i in range(3):                                                   # kanatlar
    a = _m.tau * i / 3.0 + R90
    o = prism([(0.0, 0.18), (0.44, 0.08), (0.32, 0.50), (0.0, 0.85)], 0.05, 'xz', RED)
    o.data.transform(mathutils.Matrix.Translation((0.16, 0, 0)))
    o.data.transform(mathutils.Matrix.Rotation(a, 4, 'Z'))
cyl(0.12, 0.02, (0, -0.22, 1.00), GLASS, rot=(R90, 0, 0), seg=14)    # lomboz
torus(0.12, 0.02, (0, -0.22, 1.00), CHROME, rot=(R90, 0, 0), seg=14, mseg=4)
box((0.30, 0.16, 0.18), (0, -0.30, 0.66), DARK)                      # oturak boşluğu
cone(0.14, 0.05, 0.14, (0, 0, 0.17), L_YEL, rot=(_m.pi, 0, 0), seg=12)   # ateş
ball(0.03, (0, 0, 1.82), L_RED, seg=6, ring=4)
finish("kiddie_rocket")

# ---------------------------------------------------------------- 13) YARIŞ START IŞIKLARI (drag ağacı)
clear()
box((0.50, 0.40, 0.12), (0, 0, 0.06), CONCRETE)
box((0.12, 0.12, 1.30), (0, 0.04, 0.75), DARK)                       # direk
box((0.46, 0.18, 1.56), (0, 0, 2.18), DARK)                          # ağaç gövdesi
for side in (-1, 1):
    x = side * 0.11
    for k, m in enumerate((L_YEL, L_YEL, L_YEL, L_YEL, L_GREEN, L_RED)):
        z = 2.80 - k * 0.24
        cyl(0.075, 0.03, (x, -0.10, z), m if k != 3 else L_OFF, rot=(R90, 0, 0), seg=12)
        torus(0.08, 0.012, (x, -0.11, z), CHROME, rot=(R90, 0, 0), seg=12, mseg=3)
box((0.50, 0.20, 0.14), (0, 0, 3.02), YEL)                           # tepe
for s in (-1, 1):
    cyl(0.04, 0.02, (s * 0.11, -0.10, 3.02), WHITE, rot=(R90, 0, 0), seg=10)
finish("start_lights")

# ---------------------------------------------------------------- 14) YARIŞ KÜRSÜSÜ
clear()
for (x, h, m, n) in ((0.0, 0.90, GOLD, "1"), (-0.95, 0.62, SILVER, "2"), (0.95, 0.42, BRONZE, "3")):
    box((0.90, 0.80, h), (x, 0, h / 2), WHITE)
    box((0.92, 0.82, 0.06), (x, 0, h - 0.03), m)
    text(n, 0.34, (x, -0.41, h * 0.5), m, depth=0.02)
    cyl(0.07, 0.04, (x, 0.05, h + 0.02), m, seg=10)                  # kupa kaidesi
    cyl(0.025, 0.14, (x, 0.05, h + 0.11), m, seg=8)
    cone(0.06, 0.13, 0.20, (x, 0.05, h + 0.28), m, seg=12)
    for s in (-1, 1):
        torus(0.05, 0.012, (x + s * 0.13, 0.05, h + 0.30), m, rot=(R90, 0, 0), seg=10, mseg=3)
box((2.90, 1.00, 0.04), (0, 0.04, 0.02), RED)                        # kırmızı halı
box((0.04, 0.04, 1.60), (0, 0.38, 0.80 + 0.90), DARK)                # dama bayrak direği
for i in range(4):
    for j in range(3):
        box((0.12, 0.012, 0.12), (0.10 + i * 0.12, 0.38, 2.36 - j * 0.12), DARK if (i + j) % 2 else WHITE)
finish("podium")

print("v3 avlu partisi tamam")
