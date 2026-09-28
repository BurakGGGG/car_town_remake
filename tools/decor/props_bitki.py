"""BİTKİ / PEYZAJ partisi — ağaçlar, saksılar, çit, çiçek tarhı."""
GREEN = mat("Yaprak", (0.055, 0.22, 0.075), 0.92)
GREEN2 = mat("Yaprak2", (0.075, 0.28, 0.09), 0.92)
BARK = mat("Kabuk", (0.115, 0.075, 0.045), 0.95)
TERRA = mat("Terracotta", (0.42, 0.14, 0.075), 0.85)
STONE = mat("Tas", (0.36, 0.35, 0.33), 0.9)
SOIL = mat("Toprak", (0.09, 0.06, 0.04), 0.98)
WOOD = mat("Ahsap", (0.22, 0.12, 0.055), 0.9)

# 1) Yuvarlak ağaç (3.4 m)
clear()
cyl(0.11, 1.5, (0, 0, 0.75), BARK, seg=8)
ball(0.78, (0, 0, 2.15), GREEN, scale=(1.0, 1.0, 0.85), seg=12, ring=7)
ball(0.48, (0.42, 0.18, 1.78), GREEN2, seg=10, ring=6)
ball(0.40, (-0.36, -0.24, 2.60), GREEN2, seg=10, ring=6)
finish("tree_round")

# 2) Çam (4.0 m)
clear()
cyl(0.10, 0.9, (0, 0, 0.45), BARK, seg=8)
cone(0.95, 0.0, 1.5, (0, 0, 1.35), GREEN, seg=12)
cone(0.72, 0.0, 1.3, (0, 0, 2.25), GREEN2, seg=12)
cone(0.46, 0.0, 1.1, (0, 0, 3.05), GREEN, seg=12)
finish("tree_pine")

# 3) İnce uzun ağaç (4.6 m) — sıraya dizilince avluya derinlik verir
clear()
cyl(0.075, 2.3, (0, 0, 1.15), BARK, seg=8)
ball(0.46, (0, 0, 2.90), GREEN, scale=(1.0, 1.0, 1.75), seg=10, ring=8)
ball(0.30, (0.16, 0.10, 3.95), GREEN2, scale=(1.0, 1.0, 1.3), seg=8, ring=6)
finish("tree_slim")

# 4) Palmiye (4.2 m)
clear()
for i in range(7):
    cyl(0.085 - i * 0.006, 0.42, (0, 0, 0.21 + i * 0.40), BARK, seg=8)
import math as _m
for i in range(7):
    a = _m.tau * i / 7.0
    box((1.05, 0.10, 0.03), (_m.cos(a) * 0.52, _m.sin(a) * 0.52, 2.98), GREEN,
        rot=(0, _m.radians(-22), a))
finish("tree_palm")

# 5) Çit bloğu (1.8 x 0.5 x 0.9 m)
clear()
box((1.8, 0.5, 0.82), (0, 0, 0.41), GREEN)
box((1.86, 0.56, 0.10), (0, 0, 0.80), GREEN2)
finish("hedge")

# 6) Çiçek tarhı (1.4 x 1.0 m)
clear()
for s in range(4):
    dx = 0.7 if s < 2 else 0.0
    dy = 0.0 if s < 2 else 0.5
    sx = 0.12 if s < 2 else 1.44
    sy = 1.0 if s < 2 else 0.12
    box((sx, sy, 0.24), ((1 if s % 2 else -1) * dx, (1 if s % 2 else -1) * dy, 0.12), STONE)
box((1.3, 0.88, 0.20), (0, 0, 0.14), SOIL)
rng = random.Random(7)
for i in range(11):
    c = [(0.55, 0.05, 0.06), (0.62, 0.42, 0.04), (0.45, 0.10, 0.38)][i % 3]
    ball(0.075, (rng.uniform(-0.55, 0.55), rng.uniform(-0.34, 0.34), 0.27),
         mat("Cicek%d" % (i % 3), c, 0.85), seg=7, ring=4)
finish("flower_bed")

# 7) Büyük vazo (0.8 x 1.1 m)
clear()
cyl(0.30, 0.16, (0, 0, 0.08), TERRA, seg=14)
cyl(0.40, 0.55, (0, 0, 0.44), TERRA, seg=14)
cyl(0.30, 0.22, (0, 0, 0.82), TERRA, seg=14)
cyl(0.34, 0.07, (0, 0, 0.96), TERRA, seg=14)
ball(0.30, (0, 0, 1.12), GREEN, scale=(1.0, 1.0, 0.7), seg=10, ring=6)
finish("vase_large")

# 8) Ahşap saksı kasası (1.0 x 0.45 x 0.55 m)
clear()
for s in range(2):
    box((1.0, 0.04, 0.42), (0, (1 if s else -1) * 0.205, 0.21), WOOD)
for s in range(2):
    box((0.04, 0.45, 0.42), ((1 if s else -1) * 0.48, 0, 0.21), WOOD)
box((0.92, 0.38, 0.06), (0, 0, 0.42), SOIL)
for i in range(3):
    ball(0.17, (-0.28 + i * 0.28, 0.0, 0.52), GREEN if i % 2 else GREEN2,
         scale=(1.0, 1.0, 0.8), seg=9, ring=5)
finish("planter_box")

# 9) Lastik saksı — Car Town klasiği: boyalı lastiğin içinde çiçek
clear()
torus(0.235, 0.080, (0, 0, 0.08), mat("BoyaliLastik", (0.62, 0.48, 0.05), 0.8), seg=12, mseg=6)
cyl(0.20, 0.06, (0, 0, 0.11), SOIL, seg=12)
for i in range(5):
    a = _m.tau * i / 5.0
    ball(0.075, (_m.cos(a) * 0.10, _m.sin(a) * 0.10, 0.19),
         mat("CicekL", (0.58, 0.07, 0.10), 0.85), seg=7, ring=4)
finish("tyre_planter")

print("bitki partisi tamam")
