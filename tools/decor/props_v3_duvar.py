"""DEKORASYON v3 — DUVAR EŞYALARI partisi: takvim, dart, vantilatör, plaka kolajı, lastik tabelası, yarış
posteri, egzoz / direksiyon askısı, kask rafı, yarış tulumu vitrini (orijinal Car Town'un "race suit display"
eşyası) ve üç yeni neon.

Kurallar props_duvar.py ile aynı: metre, ÖN = −Y, arka yüz duvara (+Y) yaslanır, yazılar dilden bağımsız
(sembol, sayı, kurgusal marka AUTO YARD).
Kullanım: CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_duvar.py
"""
import math as _m

R90 = _m.radians(90)
DARK = mat("Koyu", (0.055, 0.058, 0.065), 0.75)
STEEL = mat("Celik", (0.40, 0.41, 0.43), 0.4, 0.7)
CHROME = mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
WHITE = mat("Beyaz", (0.82, 0.80, 0.74), 0.6)
CREAM = mat("Krem", (0.80, 0.72, 0.55), 0.7)
RED = mat("Kirmizi", (0.55, 0.05, 0.04), 0.55)
YEL = mat("Sari", (0.70, 0.48, 0.03), 0.55)
BLUE = mat("Mavi", (0.04, 0.16, 0.45), 0.55)
GREEN = mat("Yesil", (0.05, 0.22, 0.12), 0.6)
ORANGE = mat("Turuncu", (0.75, 0.25, 0.03), 0.55)
WOOD = mat("Ahsap", (0.32, 0.19, 0.09), 0.85)
CORK = mat("Mantar", (0.45, 0.30, 0.15), 0.95)
RUBBER = mat("Lastik", (0.03, 0.03, 0.035), 0.9)
GLASS = mat("Cam", (0.70, 0.85, 0.95), 0.08, 0.1, alpha=0.35)
BACK_N = mat("NeonZemin", (0.06, 0.03, 0.08), 0.4)
N_ORANGE = mat("NeonTuruncu", (1.0, 0.45, 0.1), 0.3, emit=(1.0, 0.4, 0.08))
N_RED = mat("NeonKirmizi", (1.0, 0.15, 0.12), 0.3, emit=(1.0, 0.12, 0.1))
N_YEL = mat("NeonSari", (1.0, 0.85, 0.2), 0.3, emit=(1.0, 0.8, 0.15))
N_PINK = mat("NeonPembe", (1.0, 0.25, 0.65), 0.3, emit=(1.0, 0.2, 0.6))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
N_WHITE = mat("NeonBeyaz", (0.95, 0.95, 1.0), 0.3, emit=(0.9, 0.9, 1.0))


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


def plate(w, h, loc, material, d=0.02):
    """Ön yüzü −Y'ye bakan düz pano (x genişlik, z yükseklik)."""
    return box((w, d, h), loc, material)


def frame(w, h, y, material, t=0.03, d=0.03, z0=0.0):
    box((w, d, t), (0, y, z0 + h / 2 - t / 2), material)
    box((w, d, t), (0, y, z0 - h / 2 + t / 2), material)
    box((t, d, h), (-w / 2 + t / 2, y, z0), material)
    box((t, d, h), (w / 2 - t / 2, y, z0), material)


def disc(r, y, z, material, x=0.0, d=0.02, seg=20):
    """Ön yüzü −Y'ye bakan daire."""
    return cyl(r, d, (x, y, z), material, rot=(R90, 0, 0), seg=seg)


# ---------------------------------------------------------------- 1) TAKVİM
clear()
plate(0.44, 0.62, (0, 0, 0.31), WHITE)
plate(0.44, 0.24, (0, -0.012, 0.48), mat("TakvimFoto", (0.20, 0.45, 0.75), 0.6), d=0.005)
box((0.30, 0.004, 0.06), (0, -0.016, 0.45), RED)                     # fotodaki araç
for dx in (-0.09, 0.09):
    disc(0.025, -0.017, 0.42, DARK, x=dx, d=0.004, seg=10)
for r in range(5):
    for c in range(7):
        box((0.045, 0.004, 0.035), (-0.165 + c * 0.055, -0.012, 0.31 - r * 0.05),
            RED if c == 6 else mat("Hucre", (0.62, 0.62, 0.60), 0.7))
box((0.06, 0.006, 0.045), (0.11, -0.016, 0.21), mat("Isaret", (0.85, 0.15, 0.10), 0.6))   # işaretli gün
for dx in (-0.12, 0.12):
    torus(0.015, 0.004, (dx, -0.005, 0.62), STEEL, rot=(0, R90, 0), seg=8, mseg=3)
finish("wall_calendar")

# ---------------------------------------------------------------- 2) DART TAHTASI (dolapta)
clear()
plate(0.66, 0.70, (0, 0, 0.35), WOOD, d=0.06)
for s in (-1, 1):                                                    # açık kapaklar
    box((0.33, 0.03, 0.70), (s * 0.48, -0.10, 0.35), WOOD, rot=(0, 0, s * _m.radians(-50)))
    box((0.27, 0.02, 0.10), (s * 0.48, -0.12, 0.55), mat("Tebesir", (0.10, 0.12, 0.12), 0.95), rot=(0, 0, s * _m.radians(-50)))
disc(0.26, -0.04, 0.37, DARK, d=0.03, seg=24)
for k in range(10):                                                  # dilimler
    box((0.05, 0.004, 0.40), (0, -0.057, 0.37), [RED, GREEN][k % 2], rot=(0, _m.tau * k / 20.0, 0))
for (r, m) in ((0.19, CREAM), (0.12, DARK), (0.075, GREEN), (0.03, RED)):
    torus(r, 0.008, (0, -0.058, 0.37), m, rot=(R90, 0, 0), seg=20, mseg=3)
for (x, z) in ((0.04, 0.40), (-0.08, 0.33), (0.10, 0.28)):           # oklar
    cyl(0.006, 0.12, (x, -0.11, z), CHROME, rot=(R90, 0, 0), seg=6)
    box((0.03, 0.03, 0.003), (x, -0.17, z), RED, rot=(0, _m.radians(45), 0))
finish("dartboard")

# ---------------------------------------------------------------- 3) DUVAR VANTİLATÖRÜ
clear()
box((0.14, 0.06, 0.20), (0, -0.03, 0.10), STEEL)                     # duvar ayağı
cyl(0.03, 0.22, (0, -0.15, 0.16), STEEL, rot=(R90, 0, 0), seg=8)
cyl(0.10, 0.20, (0, -0.30, 0.20), mat("VantMotor", (0.10, 0.30, 0.40), 0.5), rot=(R90, 0, 0), seg=12)
torus(0.30, 0.012, (0, -0.44, 0.20), CHROME, rot=(R90, 0, 0), seg=24, mseg=3)   # kafes
torus(0.18, 0.008, (0, -0.47, 0.20), CHROME, rot=(R90, 0, 0), seg=18, mseg=3)
for k in range(8):
    box((0.60, 0.006, 0.008), (0, -0.47, 0.20), CHROME, rot=(0, _m.tau * k / 16.0, 0))
for k in range(3):                                                   # pervane
    a = _m.tau * k / 3.0
    box((0.10, 0.012, 0.22), (_m.sin(a) * 0.13, -0.42, 0.20 + _m.cos(a) * 0.13), mat("Pervane", (0.10, 0.30, 0.40), 0.5),
        rot=(0, a, 0))
disc(0.05, -0.475, 0.20, mat("VantMotor", (0.10, 0.30, 0.40), 0.5), seg=10)
finish("wall_fan")

# ---------------------------------------------------------------- 4) PLAKA KOLAJI
clear()
plate(1.10, 0.62, (0, 0, 0.31), WOOD)
plates = [(-0.27, 0.46, BLUE, "AY 42"), (0.27, 0.46, WHITE, "GT 500"), (-0.27, 0.31, YEL, "V8 77"),
          (0.27, 0.31, RED, "RACE 1"), (-0.27, 0.16, WHITE, "34 CT 7"), (0.27, 0.16, GREEN, "DRIFT")]
for i, (x, z, m, t) in enumerate(plates):
    tilt = _m.radians((-4, 3, 5, -3, 2, -5)[i])
    box((0.50, 0.012, 0.13), (x, -0.016, z), m, rot=(0, tilt, 0))
    box((0.52, 0.010, 0.15), (x, -0.010, z), CHROME, rot=(0, tilt, 0))
    o = text(t, 0.07, (x, -0.024, z), DARK if m in (WHITE, YEL) else WHITE, depth=0.004)
    o.data.transform(mathutils.Matrix.Rotation(tilt, 4, 'Y'))       # yazı plakayla birlikte eğik
finish("license_plates")

# ---------------------------------------------------------------- 5) LASTİK TABELASI (lastik çerçeveli)
clear()
torus(0.34, 0.10, (0, -0.06, 0.44), RUBBER, rot=(R90, 0, 0), seg=24, mseg=8)
for k in range(24):                                                  # diş izleri
    a = _m.tau * k / 24.0
    box((0.05, 0.10, 0.03), (_m.cos(a) * 0.44, -0.06, 0.44 + _m.sin(a) * 0.44), RUBBER, rot=(0, -a, 0))
disc(0.26, -0.05, 0.44, YEL, d=0.03, seg=24)
text("TIRES", 0.10, (0, -0.07, 0.48), DARK)
text("AUTO YARD", 0.045, (0, -0.07, 0.37), RED)
finish("sign_tires")

# ---------------------------------------------------------------- 6) YARIŞ POSTERİ (damalı bayrak + numara)
clear()
plate(0.62, 0.86, (0, 0, 0.43), DARK, d=0.03)
plate(0.56, 0.80, (0, -0.02, 0.43), mat("PosterSari", (0.85, 0.60, 0.08), 0.6))
for r in range(3):                                                   # damalı şerit
    for c in range(8):
        if (r + c) % 2 == 0:
            box((0.07, 0.012, 0.07), (-0.245 + c * 0.07, -0.03, 0.74 - r * 0.07), DARK)
disc(0.15, -0.03, 0.40, WHITE, seg=20)
text("44", 0.16, (0, -0.042, 0.40), RED, depth=0.006)
box((0.50, 0.012, 0.04), (0, -0.03, 0.18), RED)
text("GRAND PRIX", 0.055, (0, -0.032, 0.11), DARK, depth=0.004)
finish("poster_race")

# ---------------------------------------------------------------- 7) EGZOZ ASKISI
clear()
for s in (-1, 1):
    box((0.05, 0.12, 0.05), (s * 0.55, -0.06, 0.50), STEEL)          # konsollar
    box((0.05, 0.12, 0.05), (s * 0.55, -0.06, 0.22), STEEL)
box((1.20, 0.04, 0.04), (0, -0.12, 0.50), STEEL)
box((1.20, 0.04, 0.04), (0, -0.12, 0.22), STEEL)
for i, m in enumerate((CHROME, mat("Titanyum", (0.35, 0.25, 0.55), 0.2, 0.9), CHROME)):   # susturucular
    cyl(0.09, 0.56, (-0.38 + i * 0.38, -0.20, 0.58 - (i % 2) * 0.30), m, rot=(0, R90, 0), seg=14)
    cyl(0.04, 0.24, (-0.38 + i * 0.38 + 0.38, -0.20, 0.58 - (i % 2) * 0.30), m, rot=(0, R90, 0), seg=10)
    cyl(0.05, 0.02, (-0.38 + i * 0.38 + 0.50, -0.20, 0.58 - (i % 2) * 0.30), DARK, rot=(0, R90, 0), seg=10)
finish("exhaust_rack")

# ---------------------------------------------------------------- 8) DİREKSİYON ASKISI
clear()
plate(1.10, 0.10, (0, 0, 0.62), WOOD, d=0.04)
for i, (m, r) in enumerate(((DARK, 0.17), (mat("AhsapDir", (0.40, 0.22, 0.08), 0.5), 0.19), (RED, 0.16))):
    x = -0.36 + i * 0.36
    cyl(0.012, 0.10, (x, -0.06, 0.62), STEEL, rot=(R90, 0, 0), seg=6)   # askı çivisi
    torus(r, 0.022, (x, -0.10, 0.62 - r - 0.02), m, rot=(R90, 0, 0), seg=20, mseg=5)
    for k in range(3):                                               # kollar
        a = _m.tau * k / 3.0 + (0.0 if i != 1 else _m.pi / 6)
        box((0.025, 0.015, r), (x + _m.sin(a) * r / 2, -0.10, 0.60 - r + _m.cos(a) * r / 2), STEEL, rot=(0, a, 0))
    disc(0.045, -0.105, 0.60 - r, DARK if i != 0 else RED, x=x, seg=12)
finish("steering_rack")

# ---------------------------------------------------------------- 9) KASK RAFI
clear()
for k in range(2):
    box((1.10, 0.30, 0.03), (0, -0.15, 0.10 + k * 0.42), WOOD)
for s in (-1, 1):
    box((0.03, 0.30, 0.48), (s * 0.55, -0.15, 0.32), WOOD)
for k in range(2):
    for i, m in enumerate(((RED, WHITE, BLUE), (mat("KaskSari", (0.80, 0.58, 0.05), 0.3), DARK, mat("KaskYesil", (0.05, 0.40, 0.20), 0.3)))[k]):
        x = -0.34 + i * 0.34
        z = 0.115 + k * 0.42
        ball(0.15, (x, -0.16, z + 0.14), m, scale=(0.95, 1.05, 1.0), seg=14, ring=8)
        box((0.20, 0.02, 0.08), (x, -0.31, z + 0.16), mat("Vizor", (0.08, 0.10, 0.14), 0.1, 0.4))
        box((0.30, 0.20, 0.06), (x, -0.16, z + 0.03), m)
        if m is not DARK:
            box((0.03, 0.30, 0.012), (x, -0.16, z + 0.29), WHITE if m is not WHITE else RED)
finish("helmet_shelf")

# ---------------------------------------------------------------- 10) YARIŞ TULUMU VİTRİNİ
clear()
plate(0.84, 1.36, (0, 0, 0.68), DARK, d=0.10)
frame(0.84, 1.36, -0.055, mat("Cerceve", (0.70, 0.52, 0.18), 0.3, 0.9), t=0.04, d=0.03, z0=0.68)
plate(0.76, 1.28, (0, -0.052, 0.68), mat("Kadife", (0.25, 0.04, 0.06), 0.95), d=0.005)
SUIT = mat("Tulum", (0.10, 0.25, 0.65), 0.6)
box((0.30, 0.03, 0.46), (0, -0.07, 0.86), SUIT)                      # gövde
for s in (-1, 1):
    box((0.11, 0.03, 0.44), (s * 0.20, -0.07, 0.86), SUIT, rot=(0, s * _m.radians(-14), 0))   # kollar
    box((0.12, 0.03, 0.48), (s * 0.085, -0.07, 0.40), SUIT)          # bacaklar
    box((0.12, 0.032, 0.05), (s * 0.085, -0.072, 0.19), WHITE)       # bot
box((0.30, 0.032, 0.06), (0, -0.072, 0.64), WHITE)                   # kemer
box((0.32, 0.032, 0.05), (0, -0.072, 1.06), WHITE)                   # yaka
box((0.04, 0.033, 0.40), (-0.06, -0.074, 0.84), RED)                 # şerit
text("7", 0.10, (0.07, -0.088, 0.88), WHITE, depth=0.004)
box((0.78, 0.01, 1.30), (0, -0.085, 0.68), mat("VitrinCam", (0.80, 0.90, 0.95), 0.05, 0.1, alpha=0.15))                    # vitrin camı
finish("race_suit")

# ---------------------------------------------------------------- 11) NEON ANAHTAR
clear()
plate(0.70, 0.70, (0, 0, 0.35), BACK_N, d=0.03)
for a in (45, -45):
    box((0.44, 0.022, 0.035), (0, -0.032, 0.35), N_CYAN, rot=(0, _m.radians(a), 0))
for (x, z) in ((-0.20, 0.55), (0.20, 0.55), (-0.20, 0.15), (0.20, 0.15)):   # anahtar ağızları
    torus(0.055, 0.012, (x, -0.034, z), N_CYAN, rot=(R90, 0, 0), seg=14, mseg=3)
torus(0.30, 0.012, (0, -0.033, 0.35), N_PINK, rot=(R90, 0, 0), seg=28, mseg=3)
finish("neon_wrench")

# ---------------------------------------------------------------- 12) NEON ALEV (hot rod alevi)
clear()
plate(1.00, 0.56, (0, 0, 0.28), BACK_N, d=0.03)


def tongue(z, length, half, y, material):
    """Sağa uzanan alev dili: kökte kalın, ucu kıvrık ve sivri."""
    x0 = -0.44
    pts = [(x0, z - half), (x0 + length * 0.55, z - half * 0.7), (x0 + length * 0.85, z - half * 0.1),
           (x0 + length, z + half * 0.5), (x0 + length * 0.75, z + half * 0.35), (x0 + length * 0.45, z + half),
           (x0, z + half)]
    prism(pts, 0.02, 'xz', material, offset=y)


for (z, l) in ((0.42, 0.72), (0.28, 0.88), (0.14, 0.62)):            # üç kat: kırmızı > turuncu > sarı
    tongue(z, l, 0.075, -0.020, N_RED)
    tongue(z, l * 0.80, 0.050, -0.026, N_ORANGE)
    tongue(z, l * 0.55, 0.026, -0.032, N_YEL)
finish("neon_flame")

# ---------------------------------------------------------------- 13) NEON HIZ GÖSTERGESİ
clear()
plate(0.80, 0.62, (0, 0, 0.31), BACK_N, d=0.03)
for k in range(11):                                                  # kadran çizgileri (yarım daire)
    a = _m.radians(200 - k * 22)
    r = 0.28
    box((0.012, 0.022, 0.06), (_m.cos(a) * r, -0.032, 0.24 + _m.sin(a) * r), N_RED if k > 7 else N_WHITE,
        rot=(0, -a + R90, 0))
for k in range(16):
    a = _m.radians(200 - k * 14.6)
    box((0.06, 0.022, 0.012), (_m.cos(a) * 0.34, -0.032, 0.24 + _m.sin(a) * 0.34), N_CYAN, rot=(0, -a + R90, 0))
box((0.012, 0.024, 0.26), (0.08, -0.036, 0.36), N_ORANGE, rot=(0, _m.radians(-35), 0))   # ibre
disc(0.03, -0.036, 0.24, N_ORANGE, seg=10)
text("300", 0.07, (0, -0.036, 0.12), N_WHITE, depth=0.01)
finish("neon_speed")

print("v3 duvar partisi tamam")
