"""DEKORASYON v7 — GÜNLÜK GİRİŞ MERDİVENİ ödülleri, 1. AY (2026-10-23, docs/GIRIS_MERDIVENI.md).

Mağazada satılmaz (`exclusive`); merdivenin 7. / 14. / 21. günü haftanın dekorunu, 28. günü ay kupasını verir.
Her ay yeni dört eşya (kullanıcı kararı): bu betik 1. ayınkiler. Uzak oyun kamerasında "bu herkeste yok" okunmalı:
altın, krom, neon. Yazı yok (dil bağımsız); kupada yalnızca ay numarası (rakam).
  login_m01_w1  ALTIN KRİKO            (zemin)  kaide üstünde altın kriko, kenarı neon
  login_m01_w2  NEON ANAHTAR TABELASI  (duvar)  çerçevede neon halka, anahtar ve şimşek
  login_m01_w3  KROM V8 HEYKELİ        (zemin)  mermer kaide, krom V8 motor
  login_m01_cup 1. AY KUPASI           (zemin)  büyük altın kupa, önünde "1" amblemi, süzülen halka

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v7_giris.py
"""
import math as _m

R90 = _m.radians(90)

GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
GOLD_D = mat("KoyuAltin", (0.62, 0.34, 0.04), 0.35, 0.35, emit=(0.06, 0.03, 0.003))
CHROME = mat("Krom", (0.80, 0.82, 0.86), 0.12, 0.3)
STEEL = mat("Celik", (0.22, 0.23, 0.26), 0.45, 0.2)
MARBLE_K = mat("KaraMermer", (0.035, 0.035, 0.042), 0.12)
BLACK = mat("Siyah", (0.02, 0.02, 0.025), 0.35)
RED = mat("Kirmizi", (0.62, 0.04, 0.05), 0.35)
ENAMEL = mat("LacivertEmaye", (0.03, 0.09, 0.32), 0.15, emit=(0.01, 0.03, 0.12))
PURPLE = mat("NeonZeminMor", (0.06, 0.02, 0.09), 0.4)
# Kit ışımayı ×2 yazar: tam değerli neon oyunda beyaza patlıyordu → yarım, doygun (props_v6 ile aynı).
N_GOLD = mat("NeonAltin", (1.0, 0.70, 0.15), 0.3, emit=(0.60, 0.34, 0.03))
N_PINK = mat("NeonPembe", (1.0, 0.25, 0.65), 0.3, emit=(0.55, 0.10, 0.32))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.08, 0.50, 0.46))


def frame(w, h, y, material, t=0.04, d=0.05, z0=0.0):
    """Önden görünen dikdörtgen çerçeve (duvar eşyaları): genişlik w, yükseklik h, merkez z0."""
    box((w, d, t), (0, y, z0 + h / 2.0 - t / 2.0), material)
    box((w, d, t), (0, y, z0 - h / 2.0 + t / 2.0), material)
    box((t, d, h), (-w / 2.0 + t / 2.0, y, z0), material)
    box((t, d, h), (w / 2.0 - t / 2.0, y, z0), material)


def star_xz(r, x, y, z, material, depth=0.02, inner=0.45):
    """Önden görünen beş köşeli yıldız (prism)."""
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * inner
        a = _m.pi / 2 + i * _m.pi / 5
        pts.append((x + rr * _m.cos(a), z + rr * _m.sin(a)))
    return prism(pts, depth, 'xz', material, offset=y)


def digit_one(x, y, z, h, material, depth=0.012):
    """Önden görünen "1" rakamı (yükseklik h): gövde, bayrak, taban."""
    w = h * 0.16
    prism([(x - w / 2, z - h / 2), (x + w / 2, z - h / 2), (x + w / 2, z + h / 2), (x - w / 2, z + h / 2)],
          depth, 'xz', material, offset=y)
    prism([(x - w / 2, z + h / 2), (x - w / 2 - h * 0.22, z + h * 0.30), (x - w / 2 - h * 0.16, z + h * 0.20),
           (x - w / 2, z + h * 0.30)], depth, 'xz', material, offset=y)
    prism([(x - h * 0.24, z - h / 2), (x + h * 0.24, z - h / 2), (x + h * 0.24, z - h / 2 + h * 0.13),
           (x - h * 0.24, z - h / 2 + h * 0.13)], depth, 'xz', material, offset=y)


# ================================================================ 1) ALTIN KRİKO (zemin)
clear()
box((0.96, 0.62, 0.10), (0, 0, 0.05), MARBLE_K)                               # kaide
box((0.98, 0.64, 0.02), (0, 0, 0.11), GOLD)
for sy in (-1, 1):                                                           # kaide kenarında neon
    box((0.90, 0.012, 0.014), (0, sy * 0.316, 0.03), N_GOLD)
for sx in (-1, 1):
    box((0.012, 0.56, 0.014), (sx * 0.476, 0, 0.03), N_GOLD)
for sx in (-0.27, 0.27):                                                     # tekerler (aks Y)
    for sy in (-0.15, 0.15):
        cyl(0.05, 0.04, (sx, sy, 0.17), BLACK, rot=(R90, 0, 0), seg=12)
        cyl(0.025, 0.045, (sx, sy, 0.17), GOLD_D, rot=(R90, 0, 0), seg=10)
box((0.68, 0.26, 0.12), (0, 0, 0.27), GOLD)                                  # gövde
box((0.70, 0.04, 0.02), (0, -0.13, 0.30), GOLD_D)
box((0.70, 0.04, 0.02), (0, 0.13, 0.30), GOLD_D)
arm = box((0.44, 0.10, 0.06), (-0.14, 0, 0.40), GOLD, rot=(0, _m.radians(-24), 0))   # kaldırma kolu (ön ucu yukarı)
cyl(0.05, 0.20, (0.04, 0, 0.40), CHROME, rot=(0, _m.radians(30), 0), seg=12)         # hidrolik
cyl(0.10, 0.05, (-0.34, 0, 0.51), GOLD, seg=18)                                      # tabla
cyl(0.075, 0.02, (-0.34, 0, 0.545), BLACK, seg=16)
rod((0.30, 0, 0.30), (0.60, 0, 0.72), 0.024, GOLD, seg=10)                          # kol
rod((0.60, 0, 0.72), (0.66, 0, 0.82), 0.036, BLACK, seg=10)                         # tutamak
star_xz(0.06, -0.34, -0.001, 0.68, N_GOLD, depth=0.012)                             # tablanın üstünde yıldız
finish("login_m01_w1")

# ================================================================ 2) NEON ANAHTAR TABELASI (duvar)
clear()
box((1.20, 0.03, 0.78), (0, -0.015, 0.39), PURPLE)                            # arka levha
frame(1.26, 0.84, -0.025, GOLD, t=0.04, d=0.05, z0=0.39)
torus(0.29, 0.018, (-0.16, -0.06, 0.39), N_CYAN, rot=(R90, 0, 0), seg=32, mseg=6)   # halka
# Anahtar: çapraz sap + üstte açık ağız (halka parçası) + altta yuvarlak uç
p0, p1 = (-0.33, 0.20), (0.01, 0.58)
rod((p0[0], -0.07, p0[1]), (p1[0], -0.07, p1[1]), 0.022, N_PINK, seg=8)
torus(0.075, 0.020, (0.05, -0.07, 0.62), N_PINK, rot=(R90, 0, 0), seg=16, mseg=5)
box((0.06, 0.05, 0.08), (0.10, -0.07, 0.68), PURPLE, rot=(0, _m.radians(-45), 0))   # ağzın açıklığı (levha rengi)
ball(0.045, (p0[0], -0.07, p0[1]), N_PINK, seg=10, ring=6)
# Şimşek (sağda)
bolt = [(0.30, 0.66), (0.42, 0.66), (0.37, 0.46), (0.47, 0.46), (0.28, 0.12), (0.33, 0.36), (0.24, 0.36)]
for i in range(len(bolt)):
    a, b = bolt[i], bolt[(i + 1) % len(bolt)]
    rod((a[0], -0.065, a[1]), (b[0], -0.065, b[1]), 0.014, N_GOLD, seg=6)
for (x, z) in ((0.47, 0.70), (-0.47, 0.12), (0.12, 0.10)):                   # kıvılcımlar
    star_xz(0.035, x, -0.07, z, N_GOLD, depth=0.01)
finish("login_m01_w2")

# ================================================================ 3) KROM V8 HEYKELİ (zemin)
clear()
cyl(0.42, 0.30, (0, 0, 0.15), MARBLE_K, seg=24)                               # kaide
torus(0.42, 0.016, (0, 0, 0.30), GOLD, seg=28, mseg=5)
torus(0.42, 0.010, (0, 0, 0.03), N_GOLD, seg=28, mseg=4)
box((0.50, 0.24, 0.06), (0, 0, 0.35), STEEL)                                  # karter
box((0.56, 0.30, 0.24), (0, 0, 0.50), STEEL)                                  # blok
for s in (-1, 1):                                                            # silindir kapakları (V)
    box((0.56, 0.15, 0.10), (0, s * 0.15, 0.66), CHROME, rot=(s * _m.radians(35), 0, 0))
    box((0.54, 0.05, 0.02), (0, s * 0.19, 0.72), RED, rot=(s * _m.radians(35), 0, 0))
    for k in range(4):                                                       # egzoz manifoldu
        x = -0.21 + k * 0.14
        rod((x, s * 0.20, 0.60), (x + 0.03, s * 0.30, 0.46), 0.022, CHROME, seg=8)
box((0.50, 0.12, 0.08), (0, 0, 0.70), STEEL)                                  # emme manifoldu
for k in range(4):                                                           # 8 hava borusu
    for sy in (-0.035, 0.035):
        cyl(0.03, 0.12, (-0.21 + k * 0.14, sy, 0.80), CHROME, seg=10)
cyl(0.11, 0.04, (-0.30, 0, 0.48), CHROME, rot=(0, R90, 0), seg=16)             # kasnak
cyl(0.06, 0.05, (-0.31, 0, 0.60), BLACK, rot=(0, R90, 0), seg=12)
finish("login_m01_w3")

# ================================================================ 4) 1. AY KUPASI (zemin)
clear()
box((0.62, 0.62, 0.12), (0, 0, 0.06), MARBLE_K)                               # kaide
box((0.64, 0.64, 0.02), (0, 0, 0.125), GOLD)
box((0.48, 0.48, 0.12), (0, 0, 0.19), MARBLE_K)
box((0.50, 0.50, 0.02), (0, 0, 0.255), GOLD)
box((0.26, 0.02, 0.09), (0, -0.25, 0.19), GOLD)                               # ön plaka
digit_one(0, -0.262, 0.19, 0.07, BLACK, depth=0.008)
cyl(0.05, 0.16, (0, 0, 0.34), GOLD, seg=14)                                   # ayak
ball(0.08, (0, 0, 0.45), GOLD, seg=14, ring=8)
cone(0.06, 0.20, 0.12, (0, 0, 0.56), GOLD, seg=20)                            # kâse tabanı
cone(0.20, 0.32, 0.40, (0, 0, 0.82), GOLD, seg=24)                            # kâse
torus(0.32, 0.022, (0, 0, 1.02), GOLD_D, seg=28, mseg=6)                      # ağız
for s in (-1, 1):                                                            # kulplar
    torus(0.12, 0.024, (s * 0.33, 0, 0.82), GOLD, rot=(R90, 0, 0), seg=16, mseg=6)
cyl(0.12, 0.02, (0, -0.25, 0.80), ENAMEL, rot=(R90, 0, 0), seg=20)             # amblem
torus(0.12, 0.012, (0, -0.255, 0.80), GOLD_D, rot=(R90, 0, 0), seg=20, mseg=4)
digit_one(0, -0.262, 0.80, 0.15, GOLD, depth=0.012)
torus(0.38, 0.016, (0, 0, 1.18), N_GOLD, rot=(_m.radians(12), 0, 0), seg=30, mseg=4)   # süzülen halka
star_xz(0.07, 0, 0.0, 1.30, N_GOLD, depth=0.02)
finish("login_m01_cup")
