"""DEKORASYON v3 — BİTKİ partisi: kaktüs, eğrelti, top şimşir, ayçiçeği, bambu, sakura, yılbaşı ağacı ve
balkabakları (orijinal Car Town'un sezonluk Cadılar Bayramı / yılbaşı eşyalarına selam; bizde her mevsim satılır).

Kurallar kit.py ile aynı: metre, ÖN = −Y, orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_bitki.py
"""
import math as _m
import random as _r

GREEN = mat("Yaprak", (0.055, 0.22, 0.075), 0.92)
GREEN2 = mat("Yaprak2", (0.075, 0.28, 0.09), 0.92)
CACTUS = mat("Kaktus", (0.10, 0.30, 0.12), 0.8)
BAMBOO = mat("Bambu", (0.32, 0.42, 0.10), 0.6)
BARK = mat("Kabuk", (0.115, 0.075, 0.045), 0.95)
TERRA = mat("Terracotta", (0.42, 0.14, 0.075), 0.85)
STONE = mat("Tas", (0.36, 0.35, 0.33), 0.9)
SOIL = mat("Toprak", (0.09, 0.06, 0.04), 0.98)
WHITE = mat("Beyaz", (0.84, 0.83, 0.80), 0.55)
PINK = mat("Sakura", (0.95, 0.55, 0.70), 0.8)
PINK2 = mat("Sakura2", (0.98, 0.72, 0.82), 0.8)
YEL = mat("Sari", (0.85, 0.62, 0.05), 0.6)
BROWN = mat("Kahve", (0.20, 0.10, 0.03), 0.9)
ORANGE = mat("Balkabagi", (0.80, 0.30, 0.03), 0.6)
RED = mat("Kirmizi", (0.60, 0.05, 0.04), 0.3, 0.2)
GOLD = mat("Altin", (0.80, 0.58, 0.12), 0.25, 0.9)
BLUE = mat("Mavi", (0.08, 0.25, 0.70), 0.3, 0.2)
L_WARM = mat("SicakIsik", (1.0, 0.85, 0.40), 0.3, emit=(1.0, 0.8, 0.35))
WOOD = mat("Ahsap", (0.22, 0.12, 0.055), 0.9)


def pot(r, h, material=TERRA):
    cone(r * 0.78, r, h, (0, 0, h / 2), material, seg=14)
    torus(r, 0.03, (0, 0, h), material, seg=14, mseg=4)
    cyl(r * 0.94, 0.02, (0, 0, h - 0.03), SOIL, seg=14)


# ---------------------------------------------------------------- 1) KAKTÜS
clear()
pot(0.26, 0.30)
cyl(0.11, 1.10, (0, 0, 0.82), CACTUS, seg=10)
ball(0.11, (0, 0, 1.37), CACTUS, seg=10, ring=6)
for s, (h, z) in ((-1, (0.38, 0.92)), (1, (0.30, 0.72))):            # kollar
    cyl(0.07, 0.20, (s * 0.17, 0, z), CACTUS, rot=(0, _m.radians(90), 0), seg=8)
    cyl(0.07, h, (s * 0.26, 0, z + h / 2), CACTUS, seg=8)
    ball(0.07, (s * 0.26, 0, z + h), CACTUS, seg=8, ring=5)
ball(0.05, (0, 0, 1.49), mat("KaktusCicek", (0.95, 0.30, 0.45), 0.6), seg=8, ring=5)
finish("cactus")

# ---------------------------------------------------------------- 2) EĞRELTİ SAKSISI
clear()
cyl(0.24, 0.50, (0, 0, 0.25), WHITE, seg=14)                         # beyaz silindir saksı
cyl(0.22, 0.02, (0, 0, 0.50), SOIL, seg=14)
for i in range(11):                                                  # sarkan yapraklar
    a = _m.tau * i / 11.0
    tilt = _m.radians(35 + (i % 3) * 15)
    box((0.10, 0.62, 0.02), (_m.cos(a) * 0.22, _m.sin(a) * 0.22, 0.70), GREEN if i % 2 else GREEN2,
        rot=(tilt, 0, a - _m.radians(90)))
finish("fern_pot")

# ---------------------------------------------------------------- 3) TOP ŞİMŞİR
clear()
box((0.56, 0.56, 0.44), (0, 0, 0.22), STONE)
box((0.62, 0.62, 0.05), (0, 0, 0.45), STONE)
cyl(0.04, 0.50, (0, 0, 0.70), BARK, seg=6)
ball(0.34, (0, 0, 1.12), GREEN, seg=14, ring=9)
ball(0.20, (0, 0, 1.58), GREEN2, seg=12, ring=7)
finish("topiary")

# ---------------------------------------------------------------- 4) AYÇİÇEKLERİ (ahşap kasada)
clear()
box((1.10, 0.44, 0.34), (0, 0, 0.17), WOOD)
box((1.04, 0.38, 0.02), (0, 0, 0.33), SOIL)
_r.seed(7)
for i in range(5):
    x = -0.42 + i * 0.21
    h = 1.10 + _r.uniform(-0.15, 0.25)
    cyl(0.02, h, (x, 0.02, 0.33 + h / 2), GREEN2, seg=6)
    box((0.16, 0.08, 0.02), (x + 0.07, 0.02, 0.33 + h * 0.5), GREEN, rot=(0, _m.radians(-30), 0))
    head = 0.33 + h
    cyl(0.15, 0.03, (x, -0.02, head), YEL, rot=(_m.radians(70), 0, 0), seg=12)
    for j in range(8):                                               # taç yapraklar
        a = _m.tau * j / 8.0
        box((0.05, 0.02, 0.10), (x + _m.cos(a) * 0.15, -0.02 - _m.sin(a) * 0.05, head + _m.sin(a) * 0.14), YEL,
            rot=(_m.radians(70), a, 0))
    cyl(0.08, 0.035, (x, -0.035, head), BROWN, rot=(_m.radians(70), 0, 0), seg=10)
finish("sunflowers")

# ---------------------------------------------------------------- 5) BAMBU
clear()
box((0.90, 0.40, 0.40), (0, 0, 0.20), STONE)
box((0.84, 0.34, 0.02), (0, 0, 0.40), SOIL)
_r.seed(11)
for i in range(7):
    x = -0.32 + (i % 4) * 0.21 + (i // 4) * 0.10
    y = -0.08 + (i // 4) * 0.16
    h = 2.0 + _r.uniform(-0.3, 0.4)
    seg_n = 4
    for k in range(seg_n):                                           # boğumlu sap
        cyl(0.03, h / seg_n - 0.02, (x, y, 0.40 + (k + 0.5) * h / seg_n), BAMBOO, seg=6)
        cyl(0.036, 0.02, (x, y, 0.40 + (k + 1) * h / seg_n - 0.01), BAMBOO, seg=6)
    for k in range(3):
        a = _r.uniform(0, _m.tau)
        box((0.30, 0.05, 0.01), (x + _m.cos(a) * 0.14, y + _m.sin(a) * 0.14, 0.40 + h * (0.6 + k * 0.15)),
            GREEN2 if k % 2 else GREEN, rot=(0, _m.radians(-25), a))
finish("bamboo")

# ---------------------------------------------------------------- 6) SAKURA (çiçekli ağaç)
clear()
cyl(0.12, 1.30, (0, 0, 0.65), BARK, seg=8)
for (a, l) in ((0.5, 0.75), (2.6, 0.70), (4.4, 0.65)):               # dallar
    cyl(0.06, l, (_m.cos(a) * 0.22, _m.sin(a) * 0.22, 1.50), BARK,
        rot=(0, _m.radians(45), a), seg=6)
for (x, y, z, r, m) in ((0, 0, 2.15, 0.80, PINK), (0.55, 0.20, 1.85, 0.52, PINK2), (-0.50, -0.25, 1.90, 0.55, PINK2),
                        (0.10, -0.45, 2.50, 0.45, PINK2), (-0.20, 0.45, 2.45, 0.45, PINK)):
    ball(r, (x, y, z), m, scale=(1.0, 1.0, 0.78), seg=12, ring=7)
cyl(0.90, 0.01, (0, 0, 0.005), PINK2, seg=16)                        # dökülen yapraklar
finish("tree_blossom")

# ---------------------------------------------------------------- 7) YILBAŞI AĞACI
clear()
box((0.50, 0.50, 0.36), (0, 0, 0.18), RED)                           # hediye kutusu kaide
box((0.52, 0.08, 0.37), (0, 0, 0.185), GOLD)
box((0.08, 0.52, 0.37), (0, 0, 0.185), GOLD)
cyl(0.08, 0.30, (0, 0, 0.50), BARK, seg=8)
for k, (r, h, z) in enumerate(((0.95, 1.05, 1.05), (0.75, 0.95, 1.70), (0.52, 0.85, 2.30))):
    cone(r, 0.0, h, (0, 0, z), GREEN if k % 2 == 0 else GREEN2, seg=14)
_r.seed(3)
for i in range(22):                                                  # süs topları ve ışıklar
    t = _r.uniform(0.0, 1.0)
    z = 0.70 + t * 1.95
    r = 0.95 * (1.0 - (z - 0.55) / 2.60) * 0.92 + 0.04
    a = _r.uniform(0, _m.tau)
    ball(0.055 if i % 3 else 0.04, (_m.cos(a) * r, _m.sin(a) * r, z), [RED, GOLD, BLUE, L_WARM][i % 4], seg=8, ring=5)
for k in range(5):                                                   # yıldız
    a = _m.tau * k / 5.0
    box((0.05, 0.03, 0.22), (_m.sin(a) * 0.08, 0, 2.90 + _m.cos(a) * 0.08), GOLD, rot=(0, a, 0))
for (x, y, w, m) in ((0.70, -0.30, 0.34, BLUE), (-0.65, -0.40, 0.28, GOLD), (0.20, -0.75, 0.24, RED)):  # hediyeler
    box((w, w, w * 0.8), (x, y, w * 0.4), m)
    box((w + 0.01, 0.04, w * 0.81), (x, y, w * 0.4), WHITE)
finish("xmas_tree")

# ---------------------------------------------------------------- 8) BALKABAKLARI (saman balyası üstünde)
clear()
box((1.10, 0.55, 0.45), (0, 0.08, 0.225), mat("Saman", (0.72, 0.56, 0.22), 0.95))
for z in (0.12, 0.33):
    box((1.11, 0.56, 0.025), (0, 0.08, z), mat("Ip", (0.45, 0.30, 0.10), 0.9))
for (x, y, z, r) in ((-0.28, 0.08, 0.62, 0.20), (0.22, 0.10, 0.60, 0.17), (0.48, -0.35, 0.16, 0.16),
                     (-0.05, -0.42, 0.15, 0.15)):
    for k in range(6):                                               # dilimli balkabağı
        a = _m.tau * k / 6.0
        ball(r * 0.55, (x + _m.cos(a) * r * 0.45, y + _m.sin(a) * r * 0.45, z), ORANGE,
             scale=(1.0, 1.0, 1.25), seg=6, ring=5)
    cyl(0.025, 0.10, (x, y, z + r * 0.75), mat("Sap", (0.15, 0.25, 0.06), 0.9), seg=6)
finish("pumpkins")

print("v3 bitki partisi tamam")
