"""DETAYLI PARTİ A — otomat, retro yakıt pompası, jukebox, kupa vitrini, langırt.
Bunlar "hero" eşyalar: daha çok parça ve daha yüksek üçgen bütçesi (1.500-3.000)."""
import math as _m
DARK   = mat("Koyu", (0.045, 0.048, 0.055), 0.7)
STEEL  = mat("Celik", (0.34, 0.35, 0.37), 0.35, 0.75)
CHROME = mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
RED    = mat("Kirmizi", (0.48, 0.045, 0.04), 0.5)
CREAM  = mat("Krem", (0.80, 0.75, 0.62), 0.6)
GLASS  = mat("Cam", (0.30, 0.40, 0.45), 0.12, 0.2)
GLOW   = mat("Vitrin", (0.92, 0.88, 0.70), 0.2, 0.0, emit=(1.0, 0.94, 0.72))
WOOD   = mat("Ahsap", (0.26, 0.135, 0.06), 0.85)
GOLD   = mat("Altin", (0.68, 0.48, 0.09), 0.25, 0.9)

# ---------------------------------------------------------------- 1) OTOMAT
clear()
# gövde: yanları hafif içeri çekik (iki kutu üst üste) → düz blok görüntüsü kırılır
box((0.90, 0.78, 1.72), (0, 0, 0.88), RED)
box((0.94, 0.82, 0.10), (0, 0, 0.05), DARK)          # taban kaidesi
box((0.92, 0.80, 0.12), (0, 0, 1.82), DARK)          # üst bant
box((0.70, 0.03, 0.09), (0, -0.40, 1.82), CREAM)     # marka şeridi
# vitrin: çerçeve + cam + iç aydınlatma
box((0.62, 0.05, 1.18), (-0.10, -0.385, 1.02), DARK)
box((0.56, 0.02, 1.10), (-0.10, -0.40, 1.02), GLASS)
box((0.54, 0.22, 1.06), (-0.10, -0.26, 1.02), GLOW)
# raflar + ürün sıraları
for shelf in range(4):
    z = 0.56 + shelf * 0.30
    box((0.54, 0.24, 0.02), (-0.10, -0.26, z), STEEL)
    for i in range(5):
        c = [(0.55, 0.06, 0.05), (0.10, 0.28, 0.52), (0.62, 0.45, 0.04),
             (0.08, 0.34, 0.14), (0.52, 0.52, 0.52)][(shelf + i) % 5]
        box((0.085, 0.085, 0.20), (-0.31 + i * 0.105, -0.26, z + 0.12),
            mat("Urun%d" % ((shelf + i) % 5), c, 0.6))
# sağ sütun: tuş takımı, para yuvası, ekran
box((0.22, 0.04, 1.18), (0.30, -0.395, 1.02), DARK)
for r in range(4):
    for c2 in range(2):
        box((0.06, 0.02, 0.06), (0.24 + c2 * 0.12, -0.415, 1.42 - r * 0.13), CREAM)
box((0.14, 0.02, 0.10), (0.30, -0.415, 0.86), GLOW)   # küçük ekran
box((0.03, 0.03, 0.12), (0.30, -0.415, 0.66), CHROME) # para yuvası
box((0.44, 0.06, 0.18), (-0.10, -0.38, 0.30), DARK)   # teslim kapağı
box((0.40, 0.02, 0.12), (-0.10, -0.415, 0.30), STEEL)
finish("vending")

# ------------------------------------------------- 2) RETRO YAKIT POMPASI
clear()
box((0.86, 0.68, 0.14), (0, 0, 0.07), DARK)                 # beton kaide
box((0.62, 0.48, 1.34), (0, 0, 0.80), RED)                  # ana gövde
for s in range(2):                                          # yuvarlatılmış köşe sütunları
    cyl(0.24, 1.34, ((1 if s else -1) * 0.31, 0, 0.80), RED, seg=12)
box((0.68, 0.54, 0.06), (0, 0, 1.50), CREAM)                # üst plaka
cyl(0.13, 0.12, (0, 0, 1.60), CHROME, seg=12)               # küre boynu
ball(0.20, (0, 0, 1.80), GLOW, seg=12, ring=8)              # cam küre (ışıklı)
box((0.10, 0.10, 0.05), (0, 0, 1.99), CHROME)               # küre tepesi
# sayaç penceresi + rakam şeritleri
box((0.46, 0.04, 0.34), (0, -0.25, 1.16), CREAM)
box((0.40, 0.02, 0.26), (0, -0.275, 1.16), DARK)
for i in range(3):
    box((0.10, 0.015, 0.18), (-0.13 + i * 0.13, -0.29, 1.16), GLOW)
box((0.46, 0.04, 0.10), (0, -0.25, 0.92), CHROME)           # marka bandı
# hortum: üç parçalı eğri + tabanca yuvası
box((0.10, 0.14, 0.30), (0.34, -0.14, 0.86), DARK)          # yuva
cyl(0.028, 0.34, (0.42, -0.06, 0.94), DARK, rot=(_m.radians(70), 0, _m.radians(-18)), seg=6)
cyl(0.028, 0.30, (0.48, 0.02, 0.68), DARK, rot=(_m.radians(30), 0, _m.radians(-10)), seg=6)
box((0.07, 0.16, 0.06), (0.50, 0.06, 0.52), CHROME)         # tabanca
box((0.05, 0.05, 0.13), (0.50, 0.12, 0.47), CHROME)
finish("fuel_pump")

# ---------------------------------------------------------------- 3) JUKEBOX
clear()
box((0.78, 0.56, 0.72), (0, 0, 0.36), WOOD)                 # alt gövde
box((0.82, 0.60, 0.06), (0, 0, 0.03), DARK)
# kavisli üst: yarıçapı azalan kutu dizisi
for i in range(7):
    t = i / 6.0
    w = 0.78 - t * t * 0.36
    box((w, 0.56, 0.10), (0, 0, 0.76 + i * 0.10), WOOD)
# ışıklı ön panel + krom kemer
box((0.58, 0.04, 0.46), (0, -0.29, 0.92), GLOW)
for s in range(2):
    cyl(0.035, 0.94, ((1 if s else -1) * 0.34, -0.26, 0.86), CHROME, seg=8)
box((0.52, 0.03, 0.05), (0, -0.30, 1.18), CHROME)
# plak penceresi
box((0.34, 0.03, 0.22), (0, -0.30, 0.94), DARK)
cyl(0.09, 0.02, (0, -0.315, 0.94), mat("Plak", (0.06, 0.06, 0.07), 0.5),
    rot=(_m.radians(90), 0, 0), seg=14)
cyl(0.03, 0.025, (0, -0.32, 0.94), RED, rot=(_m.radians(90), 0, 0), seg=10)
# hoparlör ızgarası + tuşlar
for i in range(5):
    box((0.52, 0.02, 0.025), (0, -0.28, 0.52 - i * 0.055), DARK)
for i in range(6):
    box((0.05, 0.02, 0.04), (-0.21 + i * 0.085, -0.30, 0.66), CREAM)
finish("jukebox")

# ----------------------------------------------------------- 4) KUPA VİTRİNİ
clear()
box((1.16, 0.42, 0.14), (0, 0, 0.07), WOOD)                 # kaide
for s in range(2):                                          # yan sütunlar
    box((0.06, 0.42, 1.66), ((1 if s else -1) * 0.55, 0, 0.97), WOOD)
box((1.16, 0.42, 0.08), (0, 0, 1.84), WOOD)                 # üst
box((1.04, 0.03, 1.60), (0, -0.19, 0.96), GLASS)            # ön cam
box((1.04, 0.42, 0.04), (0, 0.10, 1.86), GLOW)              # üst aydınlatma
for shelf in range(3):
    z = 0.42 + shelf * 0.44
    box((1.02, 0.36, 0.03), (0, 0, z), WOOD)
    for i in range(3):
        x = -0.32 + i * 0.32
        h = 0.20 + ((shelf + i) % 3) * 0.05
        cyl(0.075, 0.04, (x, 0, z + 0.04), GOLD, seg=10)     # kaide
        cyl(0.022, h * 0.45, (x, 0, z + 0.06 + h * 0.22), GOLD, seg=8)  # sap
        cone(0.10, 0.055, h * 0.5, (x, 0, z + 0.06 + h * 0.7), GOLD, seg=10)  # kupa
        for hs in range(2):                                   # kulplar
            torus(0.045, 0.010, (x + (1 if hs else -1) * 0.10, 0, z + 0.06 + h * 0.72),
                  GOLD, rot=(_m.radians(90), 0, 0), seg=8, mseg=4)
finish("trophy_case")

# ---------------------------------------------------------------- 5) LANGIRT
clear()
FIELD = mat("Saha", (0.045, 0.20, 0.065), 0.85)
box((1.40, 0.78, 0.10), (0, 0, 0.80), WOOD)                 # gövde
box((1.26, 0.66, 0.02), (0, 0, 0.86), FIELD)                # saha
box((0.30, 0.02, 0.006), (0, 0, 0.872), CREAM)              # orta çizgi
cyl(0.11, 0.004, (0, 0, 0.872), CREAM, seg=14)              # orta daire
for s in range(2):                                          # bordür
    box((1.40, 0.06, 0.12), (0, (1 if s else -1) * 0.42, 0.85), WOOD)
    box((0.06, 0.78, 0.12), ((1 if s else -1) * 0.73, 0, 0.85), WOOD)
for x in (-0.62, 0.62):                                     # ayaklar
    for y in (-0.30, 0.30):
        box((0.09, 0.09, 0.78), (x, y, 0.39), WOOD)
        box((0.11, 0.11, 0.05), (x, y, 0.025), DARK)
for i in range(8):                                          # çubuklar + oyuncular
    x = -0.56 + i * 0.16
    cyl(0.013, 1.02, (x, 0, 0.98), CHROME, rot=(_m.radians(90), 0, 0), seg=6)
    team = RED if i % 2 == 0 else mat("Mavi3", (0.07, 0.20, 0.50), 0.6)
    for p in range(2 if i in (0, 7) else 3):
        y = -0.20 + p * 0.20 if i not in (0, 7) else -0.12 + p * 0.24
        box((0.045, 0.045, 0.13), (x, y, 0.935), team)
        ball(0.028, (x, y, 1.02), CREAM, seg=6, ring=4)
finish("foosball")

print("detay partisi A tamam")
