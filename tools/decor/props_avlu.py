"""AVLU partisi — dubalar, bidonlar, kasalar, rampa, tabelalar, istasyon ekipmanı."""
import math as _m
STEEL = mat("Celik", (0.30, 0.31, 0.33), 0.45, 0.6)
DARK = mat("Koyu", (0.055, 0.058, 0.065), 0.75)
RED = mat("Kirmizi", (0.52, 0.055, 0.045), 0.6)
YEL = mat("Sari", (0.62, 0.42, 0.03), 0.6)
WHITE = mat("Beyaz", (0.82, 0.80, 0.74), 0.6)
WOOD = mat("Ahsap", (0.30, 0.17, 0.075), 0.9)
BLUE = mat("Mavi", (0.06, 0.18, 0.42), 0.6)
CONC = mat("Beton", (0.38, 0.375, 0.36), 0.92)

# 1) Duba sırası (3 baba)
clear()
for i in range(3):
    x = -0.55 + i * 0.55
    cyl(0.085, 0.08, (x, 0, 0.04), STEEL, seg=10)
    cyl(0.055, 0.62, (x, 0, 0.35), YEL, seg=10)
    cyl(0.058, 0.07, (x, 0, 0.58), DARK, seg=10)
finish("bollards")

# 2) Benzin bidonları
clear()
for i in range(3):
    x, y = [(-0.16, 0.0), (0.16, 0.05), (0.02, -0.22)][i]
    box((0.20, 0.13, 0.34), (x, y, 0.17), RED if i != 1 else YEL)
    box((0.06, 0.05, 0.05), (x, y - 0.02, 0.365), DARK)
    box((0.14, 0.015, 0.14), (x, y + 0.07, 0.24), DARK)
finish("jerry_cans")

# 3) Ahşap kasa yığını
clear()
for i, (x, y, z, s) in enumerate([(0, 0, 0.26, 0.52), (0.0, 0.0, 0.74, 0.44),
                                  (0.46, 0.10, 0.22, 0.44), (-0.40, -0.14, 0.20, 0.40)]):
    box((s, s * 0.85, s), (x, y, z), WOOD)
    box((s * 1.02, s * 0.87, 0.035), (x, y, z + s * 0.5), mat("KasaKapak", (0.24, 0.13, 0.055), 0.9))
finish("wooden_crates")

# 4) Kum torbaları
clear()
rng = random.Random(11)
SAND = mat("Kum", (0.34, 0.28, 0.16), 0.95)
for row in range(3):
    for i in range(4 - row):
        ball(0.17, (-0.42 + i * 0.30 + row * 0.15, rng.uniform(-0.04, 0.04), 0.09 + row * 0.15),
             SAND, scale=(1.0, 0.62, 0.42), seg=8, ring=5)
finish("sandbags")

# 5) Hortum makarası (duvara dayalı)
clear()
box((0.30, 0.16, 0.50), (0, 0, 0.25), STEEL)
torus(0.22, 0.05, (0, 0.17, 0.58), DARK, rot=(_m.radians(90), 0, 0), seg=14, mseg=5)
cyl(0.06, 0.20, (0, 0.17, 0.58), STEEL, rot=(_m.radians(90), 0, 0), seg=8)
finish("hose_reel")

# 6) Yangın tüpü standı
clear()
box((0.36, 0.22, 0.05), (0, 0, 0.025), DARK)
box((0.34, 0.04, 0.70), (0, -0.09, 0.37), RED)
for i in range(2):
    cyl(0.075, 0.46, (-0.10 + i * 0.20, 0.02, 0.28), RED, seg=10)
    cyl(0.03, 0.10, (-0.10 + i * 0.20, 0.02, 0.55), DARK, seg=8)
finish("extinguisher_stand")

# 7) Hava / lastik istasyonu
clear()
box((0.26, 0.22, 0.12), (0, 0, 0.06), DARK)
box((0.22, 0.18, 1.05), (0, 0, 0.62), BLUE)
box((0.16, 0.02, 0.18), (0, 0.10, 0.98), WHITE)
cyl(0.012, 0.42, (0.13, 0.06, 0.55), DARK, rot=(0, _m.radians(24), 0), seg=6)
finish("air_station")

# 8) Çıkış rampası (çift)
clear()
for s in range(2):
    y = (1 if s else -1) * 0.42
    cone(0.0, 0.0, 0.0, (0, 0, 0), CONC) if False else None
    box((1.10, 0.34, 0.22), (0, y, 0.11), YEL, rot=(0, _m.radians(-9), 0))
    box((1.10, 0.36, 0.04), (0, y, 0.23), DARK, rot=(0, _m.radians(-9), 0))
finish("car_ramps")

# 9) Kablo makarası
clear()
for s in range(2):
    cyl(0.42, 0.05, (0, (1 if s else -1) * 0.20, 0.42), WOOD, rot=(_m.radians(90), 0, 0), seg=14)
cyl(0.16, 0.36, (0, 0, 0.42), mat("Kablo", (0.10, 0.10, 0.11), 0.9),
    rot=(_m.radians(90), 0, 0), seg=12)
finish("cable_reel")

# 10) Uyarı tabelası (A tipi)
clear()
for s in range(2):
    box((0.50, 0.03, 0.72), (0, (1 if s else -1) * 0.14, 0.36), YEL,
        rot=(_m.radians((1 if s else -1) * 11), 0, 0))
box((0.46, 0.04, 0.10), (0, 0, 0.30), DARK)
finish("warning_sign")

# 11) Kasis
clear()
for i in range(5):
    box((0.34, 0.26, 0.09), (-0.68 + i * 0.34, 0, 0.045),
        YEL if i % 2 == 0 else DARK)
finish("speed_bump")

# 12) Park tabelası
clear()
cyl(0.12, 0.06, (0, 0, 0.03), CONC, seg=10)
cyl(0.035, 1.55, (0, 0, 0.80), STEEL, seg=8)
box((0.34, 0.03, 0.44), (0, 0, 1.68), BLUE)
box((0.10, 0.04, 0.24), (0, 0, 1.70), WHITE)
finish("parking_sign")

print("avlu partisi tamam")
