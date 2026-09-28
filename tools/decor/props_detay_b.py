"""DETAYLI PARTİ B — araç lifti, hurda araç, motosiklet, tamirci figürü, su deposu, römork."""
import math as _m
DARK  = mat("Koyu", (0.045, 0.048, 0.055), 0.7)
STEEL = mat("Celik", (0.34, 0.35, 0.37), 0.35, 0.75)
CHROME= mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
YEL   = mat("Sari", (0.60, 0.40, 0.03), 0.55)
RUST  = mat("Pas", (0.28, 0.13, 0.055), 0.95)
FADED = mat("SolukBoya", (0.30, 0.31, 0.29), 0.9)
GLASS = mat("Cam2", (0.26, 0.34, 0.38), 0.15, 0.2)
CREAM = mat("Krem2", (0.80, 0.75, 0.62), 0.6)
BLUE  = mat("Tulum", (0.09, 0.19, 0.38), 0.85)
SKIN  = mat("Ten", (0.52, 0.34, 0.24), 0.8)
WHITE = mat("Beyaz2", (0.78, 0.77, 0.72), 0.55)

# ------------------------------------------------------------- 1) ARAÇ LİFTİ
clear()
box((0.62, 0.62, 0.10), (-1.28, 0, 0.05), DARK)             # taban plakaları
box((0.62, 0.62, 0.10), (1.28, 0, 0.05), DARK)
for s in range(2):                                          # iki sütun
    x = (1 if s else -1) * 1.28
    box((0.28, 0.32, 2.70), (x, 0, 1.40), YEL)
    box((0.10, 0.36, 2.70), (x + (0.19 if s else -0.19), 0, 1.40), STEEL)
    for i in range(9):                                      # sütun delikleri
        box((0.06, 0.38, 0.06), (x, 0, 0.45 + i * 0.26), DARK)
box((2.90, 0.26, 0.20), (0, 0, 2.82), YEL)                  # üst kiriş
box((2.60, 0.10, 0.08), (0, 0, 2.70), STEEL)                # senkron zinciri
for s in range(2):                                          # kaldırma kolları + pabuçlar
    x = (1 if s else -1) * 1.28
    for a in range(2):
        y = (1 if a else -1) * 0.42
        box((0.72, 0.14, 0.12), (x - (0.46 if s else -0.46), y, 0.62), STEEL,
            rot=(0, 0, _m.radians((1 if a else -1) * (12 if s else -12))))
        box((0.18, 0.18, 0.10), (x - (0.80 if s else -0.80), y * 1.25, 0.66), DARK)
box((0.24, 0.20, 0.34), (1.28, -0.30, 1.10), DARK)          # kumanda kutusu
box((0.16, 0.03, 0.10), (1.28, -0.42, 1.18), CREAM)
finish("car_lift")

# -------------------------------------------------------------- 2) HURDA ARAÇ
clear()
box((4.05, 1.62, 0.52), (0, 0, 0.52), FADED)                # gövde
box((3.95, 1.56, 0.10), (0, 0, 0.24), RUST)                 # paslı etek
box((2.05, 1.50, 0.46), (-0.18, 0, 1.00), FADED)            # kabin
for s in range(2):                                          # yan camlar (kırık: ikiye bölünmüş)
    y = (1 if s else -1) * 0.76
    box((0.80, 0.03, 0.34), (-0.62, y, 1.02), GLASS)
    box((0.46, 0.03, 0.20), (0.36, y, 0.96), GLASS)
box((0.05, 1.42, 0.40), (0.86, 0, 1.02), GLASS)             # ön cam
box((1.10, 1.58, 0.30), (1.62, 0, 0.66), RUST)              # ezik ön kaput
box((0.24, 1.62, 0.26), (2.10, 0, 0.60), RUST, rot=(0, _m.radians(16), 0))
box((1.05, 1.58, 0.34), (-1.72, 0, 0.72), FADED)            # bagaj
for s in range(2):                                          # üç teker + bir boş poyra
    for f in range(2):
        x = 1.32 if f else -1.32
        y = (1 if s else -1) * 0.80
        if s == 0 and f == 1:
            cyl(0.13, 0.10, (x, y, 0.34), RUST, rot=(_m.radians(90), 0, 0), seg=10)
            continue
        torus(0.24, 0.10, (x, y, 0.34), DARK, rot=(_m.radians(90), 0, 0), seg=12, mseg=6)
        cyl(0.14, 0.12, (x, y, 0.34), RUST, rot=(_m.radians(90), 0, 0), seg=10)
box((0.55, 0.14, 0.14), (-2.10, 0.42, 0.58), RUST)          # sarkan tampon
finish("wreck")

# --------------------------------------------------------------- 3) MOTOSİKLET
clear()
for f in range(2):                                          # tekerler
    x = 0.66 if f else -0.66
    torus(0.27, 0.075, (x, 0, 0.345), DARK, rot=(_m.radians(90), 0, 0), seg=16, mseg=6)
    cyl(0.14, 0.05, (x, 0, 0.345), CHROME, rot=(_m.radians(90), 0, 0), seg=12)
    for sp in range(6):                                     # jant telleri
        a = _m.tau * sp / 6.0
        box((0.02, 0.02, 0.24), (x, 0, 0.345), CHROME, rot=(0, a, 0))
box((0.62, 0.20, 0.26), (0.02, 0, 0.60), mat("MotorBlok", (0.20, 0.21, 0.23), 0.4, 0.7))
box((0.46, 0.26, 0.20), (-0.18, 0, 0.84), RED := mat("Depo", (0.46, 0.05, 0.05), 0.35))
box((0.40, 0.24, 0.10), (-0.56, 0, 0.86), DARK)             # sele
box((0.22, 0.20, 0.08), (-0.86, 0, 0.92), DARK)
cyl(0.035, 0.66, (0.52, 0, 0.72), CHROME, rot=(0, _m.radians(20), 0), seg=8)  # ön amortisör
box((0.06, 0.62, 0.05), (0.60, 0, 1.02), CHROME)            # gidon
cyl(0.09, 0.06, (0.72, 0, 0.92), CREAM, rot=(0, _m.radians(70), 0), seg=12)   # far
cyl(0.05, 0.52, (0.10, -0.20, 0.42), CHROME, rot=(0, _m.radians(90), 0), seg=8)  # egzoz
finish("motorcycle")

# ----------------------------------------------------------- 4) TAMİRCİ FİGÜRÜ
clear()
for s in range(2):                                          # bacaklar + bot
    y = (1 if s else -1) * 0.11
    box((0.17, 0.17, 0.78), (0, y, 0.42), BLUE)
    box((0.24, 0.19, 0.10), (0.02, y, 0.05), DARK)
box((0.34, 0.44, 0.60), (0, 0, 1.12), BLUE)                 # gövde
box((0.30, 0.40, 0.08), (0, 0, 0.84), DARK)                 # kemer
for s in range(2):                                          # kollar
    y = (1 if s else -1) * 0.29
    box((0.14, 0.14, 0.52), (0, y, 1.14), BLUE)
    ball(0.075, (0, y, 0.86), SKIN, seg=8, ring=5)
ball(0.135, (0, 0, 1.56), SKIN, scale=(1.0, 0.92, 1.1), seg=10, ring=7)   # baş
box((0.28, 0.28, 0.09), (0, 0, 1.68), RED)                  # şapka
box((0.16, 0.26, 0.03), (0.14, 0, 1.64), RED)               # siperlik
box((0.12, 0.02, 0.14), (-0.18, 0.06, 1.20), CREAM)         # sırt yazısı
finish("mechanic")

# ------------------------------------------------------------- 5) SU DEPOSU
clear()
for i in range(4):                                          # dört ayak (içe eğik)
    a = _m.tau * i / 4.0 + _m.pi / 4.0
    x, y = _m.cos(a) * 0.86, _m.sin(a) * 0.86
    cyl(0.055, 2.30, (x * 0.78, y * 0.78, 1.15), STEEL,
        rot=(_m.radians(-y * 7), _m.radians(x * 7), 0), seg=6)
    box((0.22, 0.22, 0.08), (x, y, 0.04), DARK)
for lev in range(2):                                        # çapraz bağlar
    r = 0.80 - lev * 0.10
    for i in range(4):
        a = _m.tau * i / 4.0 + _m.pi / 4.0
        b = _m.tau * (i + 1) / 4.0 + _m.pi / 4.0
        mx, my = (_m.cos(a) + _m.cos(b)) * r / 2.0, (_m.sin(a) + _m.sin(b)) * r / 2.0
        box((0.95 * r, 0.04, 0.04), (mx, my, 0.70 + lev * 0.80), STEEL,
            rot=(0, 0, a + _m.pi / 4.0))
cyl(0.92, 1.30, (0, 0, 2.95), CREAM, seg=16)                # tank
cone(0.92, 0.10, 0.42, (0, 0, 3.78), STEEL, seg=16)         # konik çatı
cyl(0.10, 0.16, (0, 0, 4.02), STEEL, seg=8)
for i in range(3):                                          # tank bantları
    torus(0.93, 0.025, (0, 0, 2.55 + i * 0.40), STEEL, seg=16, mseg=4)
for i in range(9):                                          # merdiven
    box((0.26, 0.03, 0.03), (0.98, 0, 0.35 + i * 0.30), STEEL)
for s in range(2):
    box((0.03, 0.03, 2.70), (0.98, (1 if s else -1) * 0.12, 1.55), STEEL)
finish("water_tower")

# ---------------------------------------------------------------- 6) RÖMORK
clear()
box((3.40, 1.90, 1.40), (0, 0, 1.02), WHITE)                # kasa
box((3.44, 1.94, 0.10), (0, 0, 0.37), STEEL)                # şasi
box((3.30, 1.84, 0.12), (0, 0, 1.78), mat("Cati2", (0.60, 0.59, 0.56), 0.7))
box((3.36, 0.04, 0.16), (0, -0.96, 1.30), RED)              # yan bant
box((0.70, 0.04, 1.06), (-0.90, -0.96, 0.98), mat("Kapi3", (0.66, 0.65, 0.61), 0.6))
box((0.06, 0.05, 0.16), (-0.60, -0.99, 0.98), CHROME)       # kapı kolu
box((0.86, 0.04, 0.46), (0.72, -0.96, 1.22), GLASS)         # servis penceresi
box((0.90, 0.06, 0.06), (0.72, -0.99, 1.48), WHITE)
for s in range(2):                                          # tekerler
    y = (1 if s else -1) * 0.92
    torus(0.30, 0.11, (-0.35, y, 0.34), DARK, rot=(_m.radians(90), 0, 0), seg=14, mseg=6)
    cyl(0.17, 0.14, (-0.35, y, 0.34), STEEL, rot=(_m.radians(90), 0, 0), seg=10)
box((0.90, 0.12, 0.10), (2.00, 0, 0.42), STEEL)             # çeki oku
cyl(0.09, 0.14, (2.44, 0, 0.44), DARK, seg=10)
box((0.10, 0.10, 0.34), (1.70, 0, 0.22), STEEL)             # destek ayağı
finish("trailer")

print("detay partisi B tamam")
