"""ATÖLYE + YAŞAM ALANI partisi."""
import math as _m
STEEL = mat("Celik", (0.30, 0.31, 0.33), 0.45, 0.6)
DARK = mat("Koyu", (0.055, 0.058, 0.065), 0.75)
RED = mat("Kirmizi", (0.52, 0.055, 0.045), 0.6)
WOOD = mat("Ahsap", (0.30, 0.17, 0.075), 0.9)
CLOTH = mat("Kumas", (0.10, 0.16, 0.26), 0.95)
WHITE = mat("Beyaz", (0.82, 0.80, 0.74), 0.6)
GREEN = mat("Yesil", (0.06, 0.22, 0.10), 0.85)

# 1) Çalışma tezgahı
clear()
box((1.70, 0.68, 0.06), (0, 0, 0.88), WOOD)
for x in (-0.78, 0.78):
    for y in (-0.28, 0.28):
        box((0.07, 0.07, 0.85), (x, y, 0.43), STEEL)
box((1.62, 0.60, 0.04), (0, 0, 0.32), STEEL)
box((1.70, 0.06, 0.55), (0, -0.34, 1.20), mat("Pano", (0.18, 0.19, 0.21), 0.7))
for i in range(5):
    box((0.05, 0.02, 0.18), (-0.55 + i * 0.28, -0.30, 1.22), STEEL)
finish("workbench")

# 2) Motor bloğu (sehpa üstünde)
clear()
for x in (-0.28, 0.28):
    for y in (-0.22, 0.22):
        box((0.06, 0.06, 0.52), (x, y, 0.26), STEEL)
box((0.72, 0.56, 0.05), (0, 0, 0.54), STEEL)
box((0.52, 0.44, 0.40), (0, 0, 0.77), mat("Motor", (0.16, 0.17, 0.20), 0.55, 0.5))
for i in range(4):
    cyl(0.055, 0.12, (-0.18 + i * 0.12, 0.0, 1.02), STEEL, seg=8)
box((0.46, 0.38, 0.05), (0, 0, 1.00), mat("Kapak", (0.34, 0.09, 0.07), 0.5, 0.3))
finish("engine_block")

# 3) Kaynak takımı
clear()
box((0.42, 0.34, 0.06), (0, 0, 0.03), DARK)
for i in range(2):
    cyl(0.085, 0.86, (-0.11 + i * 0.22, 0, 0.49), GREEN if i == 0 else RED, seg=10)
    cyl(0.035, 0.10, (-0.11 + i * 0.22, 0, 0.96), STEEL, seg=8)
box((0.30, 0.22, 0.24), (0.0, -0.22, 0.14), mat("Kaynak", (0.36, 0.20, 0.03), 0.6))
finish("welding_set")

# 4) Varil rafı
clear()
for s in range(2):
    box((0.06, 0.06, 1.10), (-0.62 + s * 1.24, 0, 0.55), STEEL)
for level in range(2):
    box((1.30, 0.50, 0.05), (0, 0, 0.30 + level * 0.52), STEEL)
    for i in range(3):
        cyl(0.115, 0.42, (-0.40 + i * 0.40, 0, 0.54 + level * 0.52),
            [RED, mat("Sari2", (0.62, 0.42, 0.03), 0.6), mat("Mavi2", (0.06, 0.18, 0.42), 0.6)][i],
            rot=(0, _m.radians(90), 0), seg=10)
finish("barrel_rack")

# 5) Yedek kapılar (duvara yaslanmış)
clear()
for i in range(3):
    box((0.95, 0.05, 1.05), (-0.16 + i * 0.16, i * 0.07, 0.54),
        [mat("KapiA", (0.48, 0.06, 0.05), 0.55), mat("KapiB", (0.10, 0.20, 0.42), 0.55),
         mat("KapiC", (0.55, 0.55, 0.52), 0.55)][i], rot=(_m.radians(9), 0, 0))
finish("spare_doors")

# 6) Şemsiyeli masa
clear()
cyl(0.40, 0.05, (0, 0, 0.72), WHITE, seg=14)
cyl(0.05, 0.72, (0, 0, 0.36), STEEL, seg=8)
cyl(0.22, 0.04, (0, 0, 0.02), STEEL, seg=12)
cyl(0.035, 1.55, (0, 0, 0.78), STEEL, seg=8)
cone(0.95, 0.06, 0.34, (0, 0, 1.68), RED, seg=12)
for i in range(3):
    a = _m.tau * i / 3.0
    box((0.34, 0.34, 0.04), (_m.cos(a) * 0.62, _m.sin(a) * 0.62, 0.44), WHITE)
finish("parasol_table")

# 7) Mangal
clear()
for i in range(3):
    a = _m.tau * i / 3.0
    cyl(0.025, 0.58, (_m.cos(a) * 0.20, _m.sin(a) * 0.20, 0.29), STEEL, seg=6)
cyl(0.34, 0.20, (0, 0, 0.68), DARK, seg=14)
cyl(0.33, 0.03, (0, 0, 0.79), STEEL, seg=14)
cyl(0.34, 0.14, (0, 0, 0.86), mat("Kapak2", (0.10, 0.11, 0.13), 0.5, 0.4), seg=14)
finish("bbq")

# 8) Buzluk
clear()
box((0.62, 0.38, 0.32), (0, 0, 0.16), mat("Buzluk", (0.10, 0.28, 0.48), 0.6))
box((0.64, 0.40, 0.06), (0, 0, 0.35), WHITE)
box((0.12, 0.03, 0.10), (0, -0.20, 0.22), DARK)
finish("cooler")

# 9) Şezlong
clear()
box((0.58, 1.05, 0.05), (0, 0.05, 0.34), CLOTH)
box((0.58, 0.48, 0.05), (0, -0.62, 0.52), CLOTH, rot=(_m.radians(-38), 0, 0))
for x in (-0.26, 0.26):
    for y in (-0.42, 0.44):
        box((0.04, 0.04, 0.34), (x, y, 0.17), STEEL)
finish("deck_chair")

# 10) Köpek kulübesi
clear()
box((0.72, 0.86, 0.52), (0, 0, 0.26), WOOD)
box((0.26, 0.05, 0.34), (0, -0.44, 0.19), DARK)
for s in range(2):
    box((0.46, 0.90, 0.05), ((1 if s else -1) * 0.20, 0, 0.66), mat("Cati", (0.40, 0.10, 0.06), 0.8),
        rot=(0, _m.radians((1 if s else -1) * -36), 0))
finish("dog_house")

print("atolye + yasam partisi tamam")
