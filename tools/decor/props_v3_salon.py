"""DEKORASYON v3 — YAŞAM ALANI partisi (orijinal Car Town'un Chairs & Tables, Functional ve müzik eşyaları).

Kurallar kit.py ile aynı: metre, Blender'da ÖN = −Y (glTF'de +Z), orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_salon.py
"""
import math as _m

R90 = _m.radians(90)
DARK = mat("Koyu", (0.045, 0.048, 0.055), 0.7)
STEEL = mat("Celik", (0.34, 0.35, 0.37), 0.35, 0.75)
CHROME = mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
RED = mat("Kirmizi", (0.50, 0.045, 0.04), 0.45)
VINYL = mat("Vinil", (0.55, 0.05, 0.05), 0.35)
CREAM = mat("Krem", (0.80, 0.75, 0.62), 0.6)
WHITE = mat("Beyaz", (0.82, 0.81, 0.78), 0.55)
WOOD = mat("Ahsap", (0.30, 0.165, 0.07), 0.8)
WOOD_D = mat("KoyuAhsap", (0.12, 0.06, 0.03), 0.6)
LEATHER = mat("Deri", (0.20, 0.085, 0.035), 0.55)
FELT = mat("Cuha", (0.03, 0.26, 0.12), 0.95)
BLUE = mat("Mavi", (0.04, 0.17, 0.48), 0.5)
YEL = mat("Sari", (0.72, 0.50, 0.04), 0.5)
GLASS = mat("Cam", (0.70, 0.85, 0.95), 0.08, 0.1, alpha=0.35)
WATER = mat("Su", (0.25, 0.55, 0.85), 0.1, 0.0, alpha=0.55)
BRASS = mat("Pirinc", (0.70, 0.52, 0.18), 0.3, 0.9)
GLOW = mat("Isik", (0.92, 0.88, 0.70), 0.2, emit=(1.0, 0.94, 0.72))
SCREEN = mat("Ekran", (0.10, 0.30, 0.55), 0.3, emit=(0.15, 0.40, 0.85))
N_PINK = mat("NeonPembe", (1.0, 0.25, 0.65), 0.3, emit=(1.0, 0.2, 0.6))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
BALLS = [mat("Top%d" % i, c, 0.35) for i, c in enumerate(
    [(0.70, 0.50, 0.04), (0.04, 0.17, 0.48), (0.50, 0.045, 0.04), (0.25, 0.06, 0.35),
     (0.65, 0.25, 0.03), (0.04, 0.30, 0.12), (0.30, 0.06, 0.04), (0.03, 0.03, 0.03)])]


def legs4(w, d, h, r, material, cx=0.0, cy=0.0, seg=8):
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            cyl(r, h, (cx + x, cy + y, h / 2), material, seg=seg)


# ---------------------------------------------------------------- 1) DİNER KOLTUĞU
clear()
box((1.20, 0.76, 0.04), (0, 0, 0.74), CREAM)                         # masa
box((1.24, 0.80, 0.03), (0, 0, 0.71), CHROME)                        # krom kenar
cyl(0.05, 0.70, (0, 0, 0.36), CHROME, seg=10)
cyl(0.24, 0.03, (0, 0, 0.015), CHROME, seg=14)
for s in (-1, 1):
    y = s * 0.78
    box((1.30, 0.52, 0.42), (0, y, 0.21), VINYL)                     # oturak
    box((1.26, 0.48, 0.08), (0, y, 0.46), VINYL)                     # minder
    box((1.30, 0.18, 1.12), (0, y + s * 0.33, 0.56), VINYL)          # sırt
    box((1.30, 0.20, 0.06), (0, y + s * 0.33, 1.14), CHROME)         # sırt kapağı
    for k in range(4):                                               # dikiş çizgileri
        box((0.02, 0.01, 0.62), (-0.48 + k * 0.32, y + s * 0.235, 0.80), DARK)
    box((1.32, 0.54, 0.05), (0, y, 0.025), DARK)
box((0.14, 0.08, 0.10), (0.40, 0, 0.81), CHROME)                     # peçetelik
cyl(0.03, 0.14, (0.25, 0.05, 0.83), RED, seg=8)                      # ketçap
cyl(0.03, 0.14, (0.30, -0.05, 0.83), YEL, seg=8)                     # hardal
finish("diner_booth")

# ---------------------------------------------------------------- 2) BAR TABURELERİ
clear()
for i in range(3):
    x = -0.62 + i * 0.62
    cyl(0.20, 0.03, (x, 0, 0.015), CHROME, seg=14)
    cyl(0.035, 0.66, (x, 0, 0.36), CHROME, seg=8)
    torus(0.15, 0.012, (x, 0, 0.30), CHROME, seg=14, mseg=4)
    cyl(0.20, 0.10, (x, 0, 0.73), VINYL, seg=16)
    torus(0.20, 0.022, (x, 0, 0.73), CHROME, seg=16, mseg=5)
finish("bar_stools")

# ---------------------------------------------------------------- 3) YUVARLAK MASA (iki sandalyeli)
clear()
cyl(0.46, 0.05, (0, 0, 0.74), WOOD, seg=18)
cyl(0.05, 0.70, (0, 0, 0.36), WOOD_D, seg=8)
box((0.60, 0.08, 0.04), (0, 0, 0.02), WOOD_D)
box((0.08, 0.60, 0.04), (0, 0, 0.02), WOOD_D)
for s in (-1, 1):
    x = s * 0.78
    box((0.44, 0.42, 0.05), (x, 0, 0.46), WOOD)
    legs4(0.36, 0.34, 0.44, 0.022, WOOD_D, cx=x)
    box((0.05, 0.42, 0.50), (x + s * 0.20, 0, 0.74), WOOD)
    box((0.04, 0.36, 0.06), (x + s * 0.20, 0, 0.98), WOOD_D)
cyl(0.06, 0.12, (0.0, 0.0, 0.83), GLASS, seg=10)                     # vazo
ball(0.07, (0.0, 0.0, 0.94), RED, seg=8, ring=5)
finish("round_table")

# ---------------------------------------------------------------- 4) DERİ KANEPE (chesterfield)
clear()
box((1.90, 0.86, 0.36), (0, 0, 0.28), LEATHER)                      # gövde
box((1.56, 0.70, 0.14), (0, -0.05, 0.52), LEATHER)                   # minder
box((0.02, 0.66, 0.02), (0, -0.05, 0.595), DARK)                     # minder ayrımı
box((1.90, 0.24, 0.50), (0, 0.31, 0.71), LEATHER)                    # sırt
cyl(0.12, 1.90, (0, 0.31, 0.96), LEATHER, rot=(0, R90, 0), seg=12)   # sırt rulo
for s in (-1, 1):
    box((0.20, 0.86, 0.36), (s * 0.85, 0, 0.54), LEATHER)            # kol
    cyl(0.13, 0.86, (s * 0.85, 0, 0.72), LEATHER, rot=(R90, 0, 0), seg=12)
for r in range(2):                                                   # kapitone düğmeler
    for k in range(7):
        ball(0.022, (-0.66 + k * 0.22 + (0.11 if r else 0), 0.185, 0.66 + r * 0.14), DARK, seg=6, ring=4)
for x in (-0.86, 0.86):
    for y in (-0.36, 0.36):
        cyl(0.04, 0.10, (x, y, 0.05), WOOD_D, seg=8)
finish("leather_sofa")

# ---------------------------------------------------------------- 5) MASA TENİSİ
clear()
box((2.74, 1.52, 0.04), (0, 0, 0.74), mat("MasaYesil", (0.03, 0.22, 0.17), 0.5))
box((2.74, 0.02, 0.005), (0, 0, 0.762), WHITE)                       # orta çizgi
for s in (-1, 1):
    box((2.74, 0.02, 0.005), (0, s * 0.75, 0.762), WHITE)
    box((0.02, 1.52, 0.005), (s * 1.36, 0, 0.762), WHITE)
box((0.02, 1.70, 0.15), (0, 0, 0.84), mat("File", (0.85, 0.85, 0.85), 0.9, alpha=0.6))
box((0.03, 1.72, 0.02), (0, 0, 0.92), WHITE)
for s in (-1, 1):
    box((0.06, 1.30, 0.06), (s * 1.00, 0, 0.12), DARK)
    for y in (-0.62, 0.62):
        box((0.06, 0.06, 0.70), (s * 1.00, y, 0.37), DARK)
for s, m in ((-1, RED), (1, DARK)):                                  # raketler
    cyl(0.08, 0.012, (s * 0.80, -0.25 * s, 0.768), m, seg=14)
    box((0.10, 0.03, 0.012), (s * 0.92, -0.25 * s, 0.768), WOOD)
ball(0.02, (0.35, 0.2, 0.78), mat("Pinpon", (0.9, 0.6, 0.2), 0.5), seg=8, ring=5)
finish("ping_pong")

# ---------------------------------------------------------------- 6) AIR HOCKEY
clear()
box((2.10, 1.12, 0.62), (0, 0, 0.47), BLUE)                          # gövde
box((2.00, 1.02, 0.02), (0, 0, 0.79), WHITE)                         # oyun yüzeyi
for s in (-1, 1):
    box((2.10, 0.06, 0.08), (0, s * 0.53, 0.82), RED)                # yan bant
    box((0.06, 1.12, 0.08), (s * 1.02, 0, 0.82), RED)
    box((0.04, 0.34, 0.02), (s * 0.99, 0, 0.805), DARK)              # kale ağzı
    cyl(0.07, 0.06, (s * 0.70, 0, 0.83), RED if s < 0 else BLUE, seg=12)   # tokmak
    cyl(0.03, 0.06, (s * 0.70, 0, 0.88), CHROME, seg=8)
box((0.01, 1.02, 0.004), (0, 0, 0.802), RED)                         # orta çizgi
torus(0.16, 0.006, (0, 0, 0.802), RED, seg=18, mseg=3)
cyl(0.04, 0.012, (0.18, -0.12, 0.806), DARK, seg=12)                 # pak
for x in (-0.95, 0.95):
    for y in (-0.48, 0.48):
        box((0.10, 0.10, 0.16), (x, y, 0.08), DARK)
box((0.08, 0.50, 0.30), (0, 0.60, 1.30), DARK)                       # skor panosu
cyl(0.025, 0.50, (0, 0.60, 1.00), CHROME, seg=8)
for s in (-1, 1):
    box((0.012, 0.18, 0.12), (-0.046, 0.60 + s * 0.12, 1.32), mat("Skor", (1.0, 0.3, 0.1), 0.3, emit=(1.0, 0.25, 0.05)))
finish("air_hockey")

# ---------------------------------------------------------------- 7) PİNBOL MAKİNESİ
clear()
# eğik oyun kasası: önden arkaya yükselir (yandan profil)
prism([(-0.62, 0.70), (0.62, 0.82), (0.62, 1.02), (-0.62, 0.92)], 0.70, 'yz', mat("Kasa", (0.32, 0.04, 0.22), 0.45))
prism([(-0.58, 0.925), (0.58, 1.03), (0.58, 1.035), (-0.58, 0.93)], 0.62, 'yz', GLASS)
prism([(-0.58, 0.90), (0.58, 1.01), (0.58, 1.015), (-0.58, 0.905)], 0.60, 'yz', mat("Oyun", (0.10, 0.30, 0.55), 0.4))
for (x, y) in ((-0.12, -0.2), (0.14, 0.05), (-0.05, 0.28)):       # tamponlar
    cyl(0.05, 0.05, (x, y, 0.96 + (y + 0.62) * 0.1), N_PINK, seg=10)
for s in (-1, 1):                                                    # paletler
    box((0.14, 0.03, 0.02), (s * 0.08, -0.48, 0.92), YEL, rot=(0, 0, s * _m.radians(20)))
for x in (-0.30, 0.30):
    for y in (-0.55, 0.55):
        box((0.05, 0.05, 0.75 if y < 0 else 0.86), (x, y, (0.75 if y < 0 else 0.86) / 2), CHROME)
box((0.72, 0.16, 0.66), (0, 0.62, 1.36), mat("Kasa", (0.32, 0.04, 0.22), 0.45))   # arka kutu
box((0.62, 0.02, 0.48), (0, 0.535, 1.38), N_CYAN)                   # ışıklı pano
box((0.40, 0.012, 0.12), (0, 0.522, 1.40), N_PINK)
box((0.06, 0.04, 0.04), (0.28, -0.64, 0.78), CHROME)                 # tetik
finish("pinball")

# ---------------------------------------------------------------- 8) ATARİ MAKİNESİ
clear()
side = [(-0.34, 0.0), (0.34, 0.0), (0.34, 1.86), (0.06, 1.86), (-0.08, 1.56),
        (-0.30, 1.40), (-0.30, 1.00), (-0.34, 0.96)]
CAB = mat("AtariKasa", (0.05, 0.05, 0.08), 0.6)
for s in (-1, 1):
    prism(side, 0.03, 'yz', mat("AtariYan", (0.40, 0.04, 0.32), 0.5), offset=s * 0.33)
box((0.64, 0.66, 0.96), (0, 0.0, 0.48), CAB)                        # alt gövde
box((0.64, 0.30, 0.42), (0, 0.18, 1.62), CAB)                        # üst gövde
prism([(-0.30, 1.00), (-0.10, 1.04), (-0.10, 1.00)], 0.64, 'yz', CAB)
box((0.66, 0.30, 0.08), (0, -0.20, 1.02), mat("Panel", (0.08, 0.12, 0.40), 0.5), rot=(_m.radians(-12), 0, 0))
cyl(0.012, 0.08, (-0.15, -0.22, 1.10), CHROME, seg=6)                # joystick
ball(0.03, (-0.15, -0.22, 1.15), RED, seg=8, ring=5)
for k in range(3):
    cyl(0.025, 0.02, (0.02 + k * 0.08, -0.20, 1.08), [RED, YEL, N_CYAN][k], seg=8)
box((0.56, 0.03, 0.40), (0, -0.16, 1.32), SCREEN, rot=(_m.radians(-22), 0, 0))
box((0.62, 0.04, 0.16), (0, 0.04, 1.80), N_PINK, rot=(_m.radians(-12), 0, 0))   # ışıklı başlık
box((0.20, 0.02, 0.12), (0, -0.335, 0.62), DARK)                     # jeton kapağı
box((0.03, 0.01, 0.06), (0, -0.347, 0.62), N_PINK)
finish("arcade_cabinet")

# ---------------------------------------------------------------- 9) GAZOZ MAKİNESİ (retro, oval tepeli)
clear()
box((0.84, 0.70, 1.38), (0, 0, 0.75), RED)
cyl(0.42, 0.70, (0, 0, 1.44), RED, rot=(R90, 0, 0), seg=20)          # yuvarlak tepe
box((0.88, 0.74, 0.08), (0, 0, 0.04), DARK)
box((0.86, 0.02, 0.10), (0, -0.355, 1.55), WHITE)                    # beyaz dalga şeridi
cyl(0.16, 0.02, (0, -0.36, 1.60), WHITE, rot=(R90, 0, 0), seg=16)
cyl(0.12, 0.022, (0, -0.37, 1.60), RED, rot=(R90, 0, 0), seg=16)
box((0.46, 0.03, 0.62), (-0.12, -0.355, 0.95), DARK)                # şişe penceresi
box((0.42, 0.02, 0.58), (-0.12, -0.37, 0.95), GLOW)
for r in range(3):
    for k in range(5):
        cyl(0.025, 0.14, (-0.29 + k * 0.085, -0.37, 0.75 + r * 0.19), mat("Sise", (0.18, 0.10, 0.05), 0.2), seg=6)
box((0.12, 0.03, 0.30), (0.26, -0.36, 1.00), CHROME)                 # para / tuş
box((0.04, 0.02, 0.06), (0.26, -0.38, 1.08), DARK)
box((0.40, 0.04, 0.14), (-0.12, -0.36, 0.38), DARK)                  # şişe ağzı
box((0.03, 0.06, 0.10), (0.30, -0.37, 0.60), CHROME)                 # açacak
finish("soda_machine")

# ---------------------------------------------------------------- 10) SAKIZ MAKİNESİ
clear()
cyl(0.16, 0.04, (0, 0, 0.02), RED, seg=14)
cyl(0.035, 0.66, (0, 0, 0.37), CHROME, seg=8)
box((0.22, 0.22, 0.24), (0, 0, 0.80), RED)                           # mekanizma kutusu
cyl(0.03, 0.02, (0, -0.115, 0.84), CHROME, rot=(R90, 0, 0), seg=10)
box((0.05, 0.03, 0.04), (0, -0.12, 0.72), CHROME)                    # ağız
ball(0.17, (0, 0, 1.08), GLASS, seg=14, ring=9)
for i in range(16):                                                  # sakızlar
    a = i * 2.4
    rr = 0.10 if i % 2 else 0.05
    ball(0.035, (_m.cos(a) * rr, _m.sin(a) * rr, 0.96 + (i % 4) * 0.035), BALLS[i % 6], seg=6, ring=4)
cyl(0.07, 0.04, (0, 0, 1.25), RED, seg=12)
finish("gumball")

# ---------------------------------------------------------------- 11) DAVUL SETİ
clear()
cyl(0.95, 0.01, (0, 0, 0.005), mat("Hali", (0.30, 0.06, 0.05), 0.95), seg=20)   # halı
SHELL = mat("Davul", (0.45, 0.05, 0.12), 0.25, 0.3)
cyl(0.28, 0.40, (0, 0.10, 0.30), SHELL, rot=(R90, 0, 0), seg=18)    # bas davul
cyl(0.26, 0.41, (0, 0.10, 0.30), WHITE, rot=(R90, 0, 0), seg=18)
cyl(0.28, 0.02, (0, -0.105, 0.30), SHELL, rot=(R90, 0, 0), seg=18)
for (x, y, z, r) in ((-0.18, 0.12, 0.70, 0.13), (0.18, 0.12, 0.70, 0.13), (0.50, -0.05, 0.48, 0.20)):
    cyl(r, 0.18, (x, y, z), SHELL, seg=14)
    cyl(r - 0.01, 0.01, (x, y, z + 0.09), WHITE, seg=14)
cyl(0.17, 0.12, (-0.45, -0.18, 0.62), CHROME, seg=14)                # trampet
cyl(0.16, 0.01, (-0.45, -0.18, 0.685), WHITE, seg=14)
cyl(0.015, 0.56, (-0.45, -0.18, 0.28), CHROME, seg=6)
for (x, y, h) in ((-0.62, 0.20, 1.10), (0.55, 0.30, 1.20), (-0.75, -0.25, 0.90)):   # zil
    cyl(0.015, h, (x, y, h / 2), CHROME, seg=6)
    cone(0.22, 0.03, 0.03, (x, y, h + 0.01), BRASS, seg=16)
cyl(0.15, 0.06, (0.05, -0.62, 0.48), DARK, seg=12)                   # tabure
cyl(0.025, 0.45, (0.05, -0.62, 0.23), CHROME, seg=6)
finish("drum_kit")

# ---------------------------------------------------------------- 12) DJ MASASI
clear()
box((1.60, 0.70, 0.90), (0, 0, 0.45), DARK)
box((1.56, 0.02, 0.70), (0, -0.355, 0.46), N_PINK)                   # ışıklı ön yüz
box((1.40, 0.025, 0.56), (0, -0.37, 0.46), DARK)
for k in range(9):                                                   # ekolayzer çubukları
    h = 0.12 + 0.30 * abs(_m.sin(k * 1.3))
    box((0.09, 0.02, h), (-0.56 + k * 0.14, -0.385, 0.20 + h / 2), N_CYAN)
box((1.64, 0.74, 0.04), (0, 0, 0.92), STEEL)
for s in (-1, 1):                                                    # pikaplar
    box((0.42, 0.34, 0.06), (s * 0.48, 0, 0.97), DARK)
    cyl(0.14, 0.02, (s * 0.50, 0, 1.01), mat("Plak", (0.02, 0.02, 0.02), 0.2), seg=18)
    cyl(0.04, 0.022, (s * 0.50, 0, 1.012), RED, seg=10)
    box((0.02, 0.18, 0.015), (s * 0.66, 0.06, 1.02), CHROME)
box((0.34, 0.30, 0.07), (0, 0, 0.975), STEEL)                        # mikser
for k in range(4):
    cyl(0.018, 0.03, (-0.11 + k * 0.073, 0.06, 1.02), WHITE, seg=6)
for s in (-1, 1):                                                    # hoparlörler
    box((0.42, 0.42, 1.10), (s * 1.10, 0.05, 0.55), DARK)
    for (z, r) in ((0.38, 0.15), (0.80, 0.08)):
        cyl(r, 0.02, (s * 1.10, -0.165, z), STEEL, rot=(R90, 0, 0), seg=16)
        cyl(r * 0.4, 0.025, (s * 1.10, -0.17, z), DARK, rot=(R90, 0, 0), seg=10)
finish("dj_booth")

# ---------------------------------------------------------------- 13) KUYRUKLU PİYANO
clear()
PIANO = mat("Piyano", (0.015, 0.015, 0.018), 0.12, 0.1)
# kuyruklu gövde dış hattı (üstten): düz klavye kenarı -Y'de, kıvrımlı kuyruk +Y'de
outline = [(-0.74, -0.70), (0.74, -0.70), (0.74, -0.30)]
for i in range(1, 9):
    t = i / 8.0
    outline.append((0.74 - 0.30 * t * t, -0.30 + 1.30 * t))
outline += [(0.30, 1.05), (0.05, 1.15), (-0.20, 1.10), (-0.45, 0.80), (-0.62, 0.30), (-0.74, -0.10)]
prism(outline, 0.32, 'xy', PIANO, offset=0.82)
box((1.36, 0.22, 0.10), (0, -0.80, 0.75), PIANO)                     # klavye yatağı
box((1.28, 0.16, 0.02), (0, -0.82, 0.81), WHITE)                     # beyaz tuşlar
for k in range(22):
    if k % 7 in (2, 6):
        continue
    box((0.025, 0.09, 0.025), (-0.60 + k * 0.058, -0.79, 0.825), PIANO)
for (x, y) in ((-0.62, -0.62), (0.62, -0.62), (0.10, 0.85)):
    cyl(0.05, 0.66, (x, y, 0.33), PIANO, seg=8)
    cyl(0.04, 0.04, (x, y, 0.02), BRASS, seg=8)
# açık kapak: gövdenin dış hattı, sağ (bas) kenarındaki menteşeden 35° kalkık + destek çubuğu
lid = prism(outline, 0.02, 'xy', PIANO, offset=0.0)
hinge = mathutils.Matrix.Translation((0.74, 0.0, 0.99)) @ mathutils.Matrix.Rotation(_m.radians(35), 4, 'Y') \
    @ mathutils.Matrix.Translation((-0.74, 0.0, 0.0))
lid.data.transform(hinge)
cyl(0.012, 0.74, (-0.36, 0.25, 1.36), PIANO, seg=6)
box((0.50, 0.04, 0.24), (0, -0.70, 1.00), PIANO)                     # nota sehpası
box((0.70, 0.36, 0.48), (0, -1.20, 0.24), PIANO)                     # tabure
box((0.66, 0.32, 0.05), (0, -1.20, 0.50), LEATHER)
finish("grand_piano")

# ---------------------------------------------------------------- 14) SU SEBİLİ
clear()
box((0.32, 0.32, 0.94), (0, 0, 0.47), WHITE)
box((0.34, 0.34, 0.04), (0, 0, 0.02), DARK)
box((0.24, 0.10, 0.03), (0, -0.14, 0.62), DARK)                      # damlalık
cyl(0.022, 0.06, (-0.06, -0.17, 0.78), mat("MaviMusluk", (0.05, 0.20, 0.70), 0.4), seg=8)
cyl(0.022, 0.06, (0.06, -0.17, 0.78), RED, seg=8)
cyl(0.14, 0.40, (0, 0, 1.15), WATER, seg=14)                         # damacana
cone(0.14, 0.05, 0.08, (0, 0, 1.39), WATER, seg=14)
cyl(0.07, 0.04, (0, 0, 0.95), WHITE, seg=10)
for k in range(3):                                                   # bardak kulesi
    cyl(0.035, 0.08, (0.20, 0.0, 0.62 + k * 0.07), WHITE, seg=8)
finish("water_cooler")

# ---------------------------------------------------------------- 15) BİLARDO MASASI
clear()
box((2.54, 1.42, 0.24), (0, 0, 0.70), WOOD_D)                        # gövde
box((2.30, 1.18, 0.02), (0, 0, 0.83), FELT)                          # çuha
for s in (-1, 1):
    box((2.54, 0.12, 0.08), (0, s * 0.65, 0.85), WOOD)               # bant
    box((0.12, 1.42, 0.08), (s * 1.21, 0, 0.85), WOOD)
for x in (-1.17, 0.0, 1.17):                                         # cepler
    for y in (-0.61, 0.61):
        cyl(0.065, 0.10, (x, y, 0.85), DARK, seg=10)
for x in (-1.0, 0.0, 1.0):
    for y in (-0.52, 0.52):
        box((0.16, 0.16, 0.60), (x, y, 0.30), WOOD_D)
for i in range(10):                                                  # üçgen dizilmiş toplar
    row = int((_m.sqrt(8 * i + 1) - 1) / 2)
    col_i = i - row * (row + 1) // 2
    ball(0.03, (0.50 + row * 0.052, (col_i - row / 2) * 0.062, 0.87), BALLS[i % 8], seg=8, ring=5)
ball(0.03, (-0.60, 0.0, 0.87), WHITE, seg=8, ring=5)
cyl(0.012, 1.40, (-0.10, 0.30, 0.88), WOOD, rot=(0, R90, _m.radians(8)), seg=6)   # isteka
finish("pool_table")

# ---------------------------------------------------------------- 16) MÜDÜR MASASI (kaptan koltuğu)
clear()
box((1.80, 0.85, 0.06), (0, 0.10, 0.76), WOOD_D)                     # masa tablası
for s in (-1, 1):
    box((0.46, 0.80, 0.72), (s * 0.64, 0.10, 0.37), WOOD)            # çekmeceli ayaklar
    for k in range(3):
        box((0.38, 0.02, 0.18), (s * 0.64, 0.51, 0.15 + k * 0.22), WOOD_D)
        box((0.08, 0.02, 0.02), (s * 0.64, 0.525, 0.18 + k * 0.22), BRASS)
box((0.82, 0.04, 0.50), (0, -0.28, 0.45), WOOD)                      # ön panel (ziyaretçiye bakar)
box((0.50, 0.04, 0.32), (0.10, 0.32, 1.00), DARK)                    # monitör (koltuğa bakar)
box((0.46, 0.02, 0.28), (0.10, 0.345, 1.00), SCREEN)
box((0.06, 0.06, 0.12), (0.10, 0.30, 0.83), DARK)
box((0.30, 0.22, 0.02), (-0.50, 0.0, 0.80), mat("Defter", (0.55, 0.05, 0.05), 0.6))
cyl(0.015, 0.36, (0.70, 0.30, 0.97), BRASS, seg=6)   # masa lambası
cone(0.11, 0.06, 0.12, (0.70, 0.30, 1.18), mat("LambaYesil", (0.05, 0.30, 0.12), 0.3), seg=12)
# kaptan koltuğu (masanın arkasında, masaya bakar: −Y)
cyl(0.30, 0.03, (0, 0.95, 0.04), CHROME, seg=5)
cyl(0.035, 0.40, (0, 0.95, 0.24), CHROME, seg=8)
box((0.62, 0.58, 0.14), (0, 0.95, 0.50), LEATHER)
box((0.62, 0.16, 0.78), (0, 1.20, 0.92), LEATHER)
cyl(0.09, 0.62, (0, 1.20, 1.32), LEATHER, rot=(0, R90, 0), seg=10)
for s in (-1, 1):
    box((0.10, 0.48, 0.22), (s * 0.34, 0.95, 0.66), LEATHER)
finish("manager_desk")

print("v3 salon partisi tamam")
