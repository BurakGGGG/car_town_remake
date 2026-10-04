"""DUVAR EŞYALARI partisi (dekorasyon v2) — tabelalar, posterler, neonlar, atölye duvarı, gösteri, ışık.

Kurallar kit.py ile aynı: metre, Blender'da ÖN = −Y (glTF'de +Z), arka yüz +Y'de duvara yaslanır,
orijini finish() tabana alır, yerleştiren taraf duvar eşyasını kendi kutusundan duvara oturtur.
Yazılar dilden bağımsız tutuldu: sembol, sayı ve kurgusal marka (AUTO YARD); gerçek marka yok.

Kullanım (Blender açmadan):
  cat tools/decor/kit.py tools/decor/props_duvar.py > /tmp/x.py
  blender --background --factory-startup --python /tmp/x.py
"""
import math as _m

R90 = _m.radians(90)

DARK = mat("Koyu", (0.055, 0.058, 0.065), 0.75)
STEEL = mat("Celik", (0.40, 0.41, 0.43), 0.4, 0.7)
ALU = mat("Aluminyum", (0.62, 0.63, 0.65), 0.35, 0.8)
WHITE = mat("Beyaz", (0.82, 0.80, 0.74), 0.6)
CREAM = mat("Krem", (0.80, 0.72, 0.55), 0.7)
RED = mat("Kirmizi", (0.55, 0.05, 0.04), 0.55)
YEL = mat("Sari", (0.70, 0.48, 0.03), 0.55)
BLUE = mat("Mavi", (0.04, 0.16, 0.45), 0.55)
GREEN = mat("Yesil", (0.05, 0.22, 0.12), 0.6)
WOOD = mat("Ahsap", (0.32, 0.19, 0.09), 0.85)
PEG = mat("Pano", (0.42, 0.30, 0.18), 0.9)
RUBBER = mat("Lastik", (0.03, 0.03, 0.035), 0.9)
GOLD = mat("Altin", (0.75, 0.55, 0.12), 0.3, 0.9)
GLASS = mat("Cam", (0.70, 0.85, 0.95), 0.08, 0.1, alpha=0.35)
FABRIC = mat("Perde", (0.55, 0.10, 0.08), 0.95)
N_YEL = mat("NeonSari", (1.0, 0.85, 0.2), 0.3, emit=(1.0, 0.8, 0.15))
N_RED = mat("NeonKirmizi", (1.0, 0.15, 0.12), 0.3, emit=(1.0, 0.12, 0.1))
N_BLUE = mat("NeonMavi", (0.2, 0.55, 1.0), 0.3, emit=(0.15, 0.5, 1.0))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
N_WHITE = mat("NeonBeyaz", (0.95, 0.95, 1.0), 0.3, emit=(0.9, 0.9, 1.0))
N_ORANGE = mat("NeonTuruncu", (1.0, 0.45, 0.1), 0.3, emit=(1.0, 0.4, 0.08))
SCREEN = mat("Ekran", (0.10, 0.30, 0.18), 0.4, emit=(0.08, 0.25, 0.14))
BACK_N = mat("NeonZemin", (0.06, 0.03, 0.08), 0.4)


def text(body, size, loc, material, depth=0.01):
    """Ön yüze (−Y) bakan yazı; mesh'e çevrilip koleksiyona konur. Konum yazının ORTASI."""
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.object
    t.data.body = body
    t.data.size = size
    t.data.extrude = depth
    t.data.align_x = 'CENTER'
    t.data.align_y = 'CENTER'
    t.rotation_euler = (R90, 0, 0)
    t.location = loc
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _place(o, material)


def plate(w, h, loc, material, d=0.02):
    """Ön yüzü −Y'ye bakan düz pano (x genişlik, z yükseklik)."""
    return box((w, d, h), loc, material)


def frame(w, h, y, material, t=0.03, d=0.03, z0=0.0):
    box((w, d, t), (0, y, z0 + h / 2 - t / 2), material)
    box((w, d, t), (0, y, z0 - h / 2 + t / 2), material)
    box((t, d, h), (-w / 2 + t / 2, y, z0), material)
    box((t, d, h), (w / 2 - t / 2, y, z0), material)


def car_silhouette(cx, cz, w, y, body_mat, wheel_mat, glass_mat=None):
    """Yandan araç silueti: gövde + kabin + iki teker (posterler ve neon için)."""
    box((w, 0.012, w * 0.22), (cx, y, cz), body_mat)
    box((w * 0.52, 0.012, w * 0.17), (cx - w * 0.04, y, cz + w * 0.18), body_mat)
    if glass_mat:
        box((w * 0.40, 0.013, w * 0.10), (cx - w * 0.04, y - 0.002, cz + w * 0.19), glass_mat)
    for dx in (-0.30, 0.30):
        cyl(w * 0.11, 0.014, (cx + w * dx, y - 0.003, cz - w * 0.11), wheel_mat, rot=(R90, 0, 0), seg=14)


# ---- TABELA / LEVHA --------------------------------------------------------------------

clear()  # 1) Emaye yağ tabelası
plate(0.92, 0.52, (0, 0, 0.26), GREEN)
frame(0.92, 0.52, -0.012, YEL, t=0.035, d=0.012, z0=0.26)
box((0.13, 0.012, 0.16), (-0.27, -0.02, 0.24), YEL)
cyl(0.025, 0.02, (-0.21, -0.02, 0.33), YEL, rot=(0, R90, 0))
text("MOTOR OIL", 0.10, (0.12, -0.02, 0.28), WHITE)
text("AUTO YARD", 0.05, (0.12, -0.02, 0.16), YEL)
finish("sign_oil")

clear()  # 2) Servis levhası (anahtar sembolü)
plate(0.80, 0.50, (0, 0, 0.25), BLUE)
frame(0.80, 0.50, -0.012, WHITE, t=0.025, d=0.012, z0=0.25)
box((0.07, 0.014, 0.30), (-0.20, -0.02, 0.25), WHITE, rot=(0, _m.radians(35), 0))
torus(0.06, 0.02, (-0.29, -0.02, 0.37), WHITE, rot=(R90, 0, 0))
text("SERVICE", 0.10, (0.12, -0.02, 0.25), WHITE)
finish("sign_service")

clear()  # 3) Giriş yasağı
cyl(0.30, 0.02, (0, 0, 0.30), RED, rot=(R90, 0, 0), seg=28)
torus(0.29, 0.015, (0, -0.012, 0.30), WHITE, rot=(R90, 0, 0), seg=28)
box((0.40, 0.014, 0.08), (0, -0.016, 0.30), WHITE)
finish("sign_no_entry")

clear()  # 4) Sokak levhası
plate(0.92, 0.24, (0, 0, 0.12), BLUE)
frame(0.92, 0.24, -0.012, WHITE, t=0.02, d=0.012, z0=0.12)
text("GARAGE ST.", 0.10, (0, -0.02, 0.12), WHITE)
finish("sign_street")

clear()  # 5) Yön okları (üç şerit ok)
plate(0.92, 0.30, (0, 0, 0.15), DARK)
for i in range(3):
    x = -0.28 + i * 0.28
    box((0.16, 0.014, 0.05), (x - 0.02, -0.016, 0.20), YEL, rot=(0, _m.radians(-35), 0))
    box((0.16, 0.014, 0.05), (x - 0.02, -0.016, 0.10), YEL, rot=(0, _m.radians(35), 0))
finish("sign_arrows")

# ---- POSTER ----------------------------------------------------------------------------

clear()  # 6) Kırmızı yarış posteri
plate(0.62, 0.86, (0, 0, 0.43), DARK, d=0.03)
plate(0.56, 0.80, (0, -0.02, 0.43), RED)
car_silhouette(0, 0.36, 0.44, -0.032, WHITE, DARK, DARK)
box((0.50, 0.012, 0.03), (0, -0.032, 0.62), WHITE)
box((0.40, 0.012, 0.02), (0, -0.032, 0.67), YEL)
text("No.7", 0.08, (0, -0.032, 0.14), WHITE)
finish("poster_red")

clear()  # 7) Mavi rali posteri
plate(0.62, 0.86, (0, 0, 0.43), DARK, d=0.03)
plate(0.56, 0.80, (0, -0.02, 0.43), BLUE)
car_silhouette(0, 0.38, 0.44, -0.032, YEL, DARK, DARK)
cyl(0.07, 0.012, (0.0, -0.034, 0.40), WHITE, rot=(R90, 0, 0), seg=16)
text("23", 0.07, (0.0, -0.042, 0.40), DARK)
box((0.56, 0.012, 0.10), (0, -0.032, 0.70), mat("Gok", (0.35, 0.55, 0.85), 0.6))
finish("poster_blue")

clear()  # 8) Klasik araç posteri
plate(0.66, 0.90, (0, 0, 0.45), WOOD, d=0.03)
plate(0.58, 0.82, (0, -0.02, 0.45), CREAM)
box((0.36, 0.012, 0.08), (0, -0.032, 0.38), mat("Bordo", (0.40, 0.04, 0.06), 0.5))
ball(0.06, (-0.13, -0.032, 0.40), mat("Bordo", (0.40, 0.04, 0.06), 0.5), scale=(1.4, 0.2, 0.9))
ball(0.06, (0.13, -0.032, 0.40), mat("Bordo", (0.40, 0.04, 0.06), 0.5), scale=(1.4, 0.2, 0.9))
box((0.18, 0.012, 0.08), (-0.01, -0.032, 0.46), mat("Bordo", (0.40, 0.04, 0.06), 0.5))
for dx in (-0.12, 0.12):
    cyl(0.045, 0.014, (dx, -0.036, 0.33), DARK, rot=(R90, 0, 0), seg=14)
text("1957", 0.09, (0, -0.032, 0.66), mat("Bordo", (0.40, 0.04, 0.06), 0.5))
finish("poster_vintage")

# ---- NEON ------------------------------------------------------------------------------

clear()  # 9) Neon şimşek
plate(0.50, 0.70, (0, 0, 0.35), BACK_N, d=0.03)
for (x, z, a) in [(0.06, 0.52, -25), (-0.02, 0.38, 60), (0.03, 0.22, -25)]:
    box((0.05, 0.025, 0.22), (x, -0.03, z), N_YEL, rot=(0, _m.radians(a), 0))
finish("neon_bolt")

clear()  # 10) Neon OPEN
plate(0.90, 0.40, (0, 0, 0.20), BACK_N, d=0.03)
frame(0.84, 0.34, -0.03, N_BLUE, t=0.02, d=0.02, z0=0.20)
text("OPEN", 0.18, (0, -0.035, 0.20), N_RED, depth=0.015)
finish("neon_open")

clear()  # 11) Neon damalı bayrak
plate(0.70, 0.56, (0, 0, 0.28), BACK_N, d=0.03)
cyl(0.012, 0.50, (-0.28, -0.03, 0.28), N_WHITE)
for r in range(4):
    for c in range(5):
        if (r + c) % 2 == 0:
            box((0.085, 0.02, 0.085), (-0.20 + c * 0.095, -0.032, 0.44 - r * 0.095), N_WHITE)
finish("neon_flag")

clear()  # 12) Neon çapraz piston
plate(0.64, 0.64, (0, 0, 0.32), BACK_N, d=0.03)
for a in (45, -45):
    box((0.46, 0.022, 0.035), (0, -0.032, 0.32), N_ORANGE, rot=(0, _m.radians(a), 0))
for (x, z) in [(-0.17, 0.49), (0.17, 0.49)]:
    box((0.14, 0.022, 0.10), (x, -0.034, z), N_ORANGE)
finish("neon_piston")

clear()  # 13) Neon araç silueti (çizgi)
plate(1.10, 0.52, (0, 0, 0.26), BACK_N, d=0.03)
segs = [(-0.42, 0.22, 0.18, 0), (0.42, 0.22, 0.18, 0), (0.0, 0.14, 0.86, 0),
        (-0.24, 0.30, 0.20, 20), (0.20, 0.30, 0.22, -25), (-0.02, 0.40, 0.40, 0)]
for (x, z, w, a) in segs:
    box((w, 0.02, 0.02), (x, -0.032, z), N_CYAN, rot=(0, _m.radians(a), 0))
for x in (-0.26, 0.26):
    torus(0.07, 0.012, (x, -0.034, 0.14), N_CYAN, rot=(R90, 0, 0), seg=16)
finish("neon_car")

# ---- ATÖLYE DUVARI ---------------------------------------------------------------------

clear()  # 14) Takım panosu
plate(1.20, 0.80, (0, 0, 0.40), PEG)
for r in range(6):
    for c in range(10):
        box((0.012, 0.004, 0.012), (-0.54 + c * 0.12, -0.012, 0.10 + r * 0.12), DARK)
for i, x in enumerate([-0.45, -0.35, -0.25]):
    box((0.04, 0.02, 0.28 - i * 0.05), (x, -0.025, 0.46), STEEL)
    torus(0.03, 0.01, (x, -0.025, 0.62 - i * 0.025), STEEL, rot=(R90, 0, 0))
box((0.05, 0.03, 0.22), (-0.05, -0.03, 0.40), WOOD)
box((0.16, 0.04, 0.05), (-0.05, -0.03, 0.53), STEEL)
for i, (x, m) in enumerate([(0.15, RED), (0.23, YEL), (0.31, RED)]):
    cyl(0.018, 0.12, (x, -0.03, 0.52), m)
    cyl(0.006, 0.12, (x, -0.03, 0.40), STEEL)
box((0.26, 0.06, 0.14), (0.38, -0.04, 0.18), RED)
finish("pegboard")

clear()  # 15) Duvar rafı
for z in (0.18, 0.48):
    box((1.00, 0.28, 0.025), (0, -0.14, z), WOOD)
    for x in (-0.42, 0.42):
        box((0.03, 0.26, 0.10), (x, -0.13, z - 0.06), STEEL)
for (x, z, w, h, m) in [(-0.30, 0.25, 0.22, 0.14, CREAM), (-0.05, 0.24, 0.18, 0.12, BLUE),
                        (0.25, 0.26, 0.26, 0.16, CREAM), (-0.25, 0.55, 0.20, 0.12, RED),
                        (0.12, 0.54, 0.16, 0.10, CREAM)]:
    box((w, 0.20, h), (x, -0.14, z + h / 2 - 0.06), m)
for x in (0.33, 0.39):
    cyl(0.03, 0.12, (x, -0.14, 0.555), YEL)
finish("wall_shelf")

clear()  # 16) Lastik askısı
box((1.30, 0.05, 0.05), (0, -0.03, 0.56), STEEL)
for x in (-0.44, 0.0, 0.44):
    box((0.03, 0.12, 0.03), (x, -0.08, 0.56), STEEL)
    torus(0.16, 0.06, (x, -0.16, 0.36), RUBBER, rot=(R90, 0, 0), seg=20, mseg=8)
    cyl(0.11, 0.05, (x, -0.16, 0.36), STEEL, rot=(R90, 0, 0), seg=16)
finish("tyre_hanger")

clear()  # 17) Jant vitrini
plate(1.10, 0.62, (0, 0, 0.31), DARK)
for x in (-0.27, 0.27):
    cyl(0.23, 0.04, (x, -0.04, 0.31), ALU, rot=(R90, 0, 0), seg=24)
    cyl(0.07, 0.05, (x, -0.06, 0.31), STEEL, rot=(R90, 0, 0), seg=16)
    for a in range(5):
        box((0.035, 0.02, 0.18), (x, -0.065, 0.31), DARK, rot=(0, _m.radians(a * 72), 0))
finish("rim_display")

clear()  # 18) Yangın tüpü (duvar askılı)
box((0.16, 0.03, 0.06), (0, -0.015, 0.40), STEEL)
cyl(0.085, 0.50, (0, -0.10, 0.28), RED, seg=16)
cyl(0.03, 0.06, (0, -0.10, 0.56), DARK)
box((0.10, 0.03, 0.03), (0.04, -0.10, 0.60), DARK)
cyl(0.012, 0.30, (0.09, -0.12, 0.42), RUBBER)
finish("extinguisher_wall")

clear()  # 19) İlk yardım dolabı
box((0.42, 0.14, 0.46), (0, -0.07, 0.23), WHITE)
box((0.30, 0.012, 0.08), (0, -0.145, 0.24), RED)
box((0.08, 0.012, 0.30), (0, -0.145, 0.24), RED)
finish("first_aid")

clear()  # 20) Havalandırma ızgarası
frame(0.60, 0.40, -0.01, STEEL, t=0.04, d=0.04, z0=0.20)
plate(0.54, 0.34, (0, 0.0, 0.20), DARK, d=0.01)
for i in range(6):
    box((0.52, 0.03, 0.02), (0, -0.02, 0.06 + i * 0.054), STEEL, rot=(_m.radians(-30), 0, 0))
finish("vent_grille")

# ---- GÖSTERİ ---------------------------------------------------------------------------

clear()  # 21) Çerçeveli plaka
plate(0.66, 0.30, (0, 0, 0.15), WOOD, d=0.03)
plate(0.56, 0.20, (0, -0.02, 0.15), WHITE)
box((0.07, 0.012, 0.20), (-0.245, -0.03, 0.15), BLUE)
text("34 AY 2026", 0.075, (0.04, -0.032, 0.15), DARK)
finish("plate_frame")

clear()  # 22) Çapraz damalı bayraklar
for side in (-1, 1):
    a = _m.radians(30 * side)
    cyl(0.012, 0.80, (side * 0.06, -0.03, 0.40), DARK, rot=(0, a, 0))
    for r in range(3):
        for c in range(4):
            m = WHITE if (r + c) % 2 == 0 else DARK
            box((0.07, 0.012, 0.07), (side * (0.20 + c * 0.07), -0.04, 0.68 - r * 0.07), m)
finish("checkered_flags")

clear()  # 23) Duvar TV (yarış yayını)
box((1.00, 0.05, 0.60), (0, -0.025, 0.30), DARK)
plate(0.92, 0.52, (0, -0.052, 0.30), SCREEN, d=0.005)
box((0.92, 0.006, 0.08), (0, -0.056, 0.16), mat("Pist", (0.2, 0.2, 0.22), 0.5, emit=(0.12, 0.12, 0.13)))
for (x, m) in [(-0.2, N_RED), (0.05, N_YEL), (0.25, N_BLUE)]:
    box((0.10, 0.006, 0.04), (x, -0.058, 0.17), m)
finish("wall_tv")

clear()  # 24) İş tahtası
frame(1.00, 0.70, -0.015, ALU, t=0.03, d=0.03, z0=0.35)
plate(0.94, 0.64, (0, 0.0, 0.35), WHITE, d=0.01)
for i in range(6):
    w = [0.70, 0.55, 0.62, 0.40, 0.66, 0.30][i]
    box((w, 0.006, 0.018), (-0.40 + w / 2, -0.012, 0.58 - i * 0.08), BLUE if i % 3 else RED)
for (x, m) in [(0.34, RED), (0.40, YEL)]:
    cyl(0.02, 0.02, (x, -0.015, 0.60), m, rot=(R90, 0, 0))
box((0.30, 0.04, 0.03), (0.25, -0.03, 0.03), ALU)
finish("job_board")

clear()  # 25) Kupa rafı
box((0.90, 0.24, 0.03), (0, -0.12, 0.10), WOOD)
for x in (-0.38, 0.38):
    box((0.03, 0.22, 0.08), (x, -0.11, 0.05), STEEL)
for (x, h) in [(-0.26, 0.30), (0.0, 0.40), (0.26, 0.26)]:
    box((0.12, 0.12, 0.05), (x, -0.12, 0.14), DARK)
    cyl(0.018, h * 0.4, (x, -0.12, 0.16 + h * 0.2), GOLD)
    cone(0.09, 0.05, h * 0.45, (x, -0.12, 0.16 + h * 0.4 + h * 0.2), GOLD, seg=16)
finish("trophy_shelf")

# ---- IŞIK ------------------------------------------------------------------------------

clear()  # 26) Endüstriyel aplik
box((0.10, 0.03, 0.14), (0, -0.015, 0.40), DARK)
box((0.03, 0.22, 0.03), (0, -0.12, 0.42), DARK)
cone(0.12, 0.04, 0.12, (0, -0.24, 0.36), DARK, seg=16)
ball(0.045, (0, -0.24, 0.31), N_YEL)
torus(0.08, 0.008, (0, -0.24, 0.29), STEEL, seg=14)
finish("wall_lamp")

clear()  # 27) Şerit LED
box((1.60, 0.04, 0.05), (0, -0.02, 0.025), ALU)
box((1.56, 0.02, 0.025), (0, -0.045, 0.025), N_BLUE)
finish("led_strip")

clear()  # 28) Sahte pencere (perdeli)
frame(0.80, 0.70, -0.02, WHITE, t=0.05, d=0.05, z0=0.40)
box((0.03, 0.05, 0.62), (0, -0.02, 0.40), WHITE)
plate(0.72, 0.62, (0, 0.0, 0.40), GLASS, d=0.01)
for x in (-0.30, 0.30):
    box((0.18, 0.04, 0.64), (x, -0.06, 0.42), FABRIC)
box((0.92, 0.12, 0.04), (0, -0.06, 0.04), WHITE)
finish("wall_window_deco")

print("duvar partisi tamam")
