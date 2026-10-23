"""DEKORASYON v8 — ARKADAŞ DAVETİ ödülü (2026-10-23, docs/ARKADAS_DAVET.md).

Mağazada satılmaz (`exclusive`); davet merdiveninin 5. basamağı verir (DAVETÇİ çerçevesiyle birlikte).
Yazı yok (dil bağımsız): iki arkadaş silüeti (camgöbeği / pembe neon) ve aralarında altın neon kalp, köşelerde
kıvılcımlar. Uzak oyun kamerasında "neon tabela" okunmalı.
  referral_neon  DOSTLAR NEON TABELASI  (duvar)  mor levha, altın çerçeve, iki silüet + kalp

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v8_davet.py
"""
import math as _m

R90 = _m.radians(90)

GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
PURPLE = mat("NeonZeminMor", (0.06, 0.02, 0.09), 0.4)
# Kit ışımayı ×2 yazar: tam değerli neon oyunda beyaza patlıyordu → yarım, doygun (props_v6 / v7 ile aynı).
N_GOLD = mat("NeonAltin", (1.0, 0.70, 0.15), 0.3, emit=(0.60, 0.34, 0.03))
N_PINK = mat("NeonPembe", (1.0, 0.25, 0.65), 0.3, emit=(0.55, 0.10, 0.32))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.08, 0.50, 0.46))

TUBE = 0.018   # neon borusu yarıçapı
Y = -0.065     # boruların düzlemi (levhanın önü)


def frame(w, h, y, material, t=0.04, d=0.05, z0=0.0):
    """Önden görünen dikdörtgen çerçeve: genişlik w, yükseklik h, merkez z0 (props_v7 ile aynı)."""
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


def polyline(points, material, closed=False, r=TUBE):
    """XZ düzleminde neon boru: ardışık noktalar çubukla, köşeler küreyle (kıvrımda boşluk kalmasın)."""
    count = len(points) if closed else len(points) - 1
    for i in range(count):
        a, b = points[i], points[(i + 1) % len(points)]
        rod((a[0], Y, a[1]), (b[0], Y, b[1]), r, material, seg=8)
    for p in points:
        ball(r, (p[0], Y, p[1]), material, seg=8, ring=5)


def friend(x, material):
    """Arkadaş silüeti: baş halkası + omuz yayı (yarım daire)."""
    torus(0.085, TUBE, (x, Y, 0.50), material, rot=(R90, 0, 0), seg=28, mseg=6)
    arc = []
    for i in range(13):
        a = _m.pi * i / 12.0
        arc.append((x + 0.17 * _m.cos(a), 0.17 + 0.17 * _m.sin(a)))
    polyline(arc, material)
    rod((x - 0.17, Y, 0.17), (x + 0.17, Y, 0.17), TUBE, material, seg=8)   # omuzların tabanı


def heart(cx, cz, s, material):
    """Kalp ana hattı (parametrik eğri), s: ölçek (genişlik ≈ 32 s)."""
    pts = []
    for i in range(28):
        t = 2.0 * _m.pi * i / 28.0
        x = 16.0 * _m.sin(t) ** 3
        z = 13.0 * _m.cos(t) - 5.0 * _m.cos(2 * t) - 2.0 * _m.cos(3 * t) - _m.cos(4 * t)
        pts.append((cx + x * s, cz + z * s))
    polyline(pts, material, closed=True)


# ================================================================ DOSTLAR NEON TABELASI (duvar)
clear()
box((1.10, 0.03, 0.74), (0, -0.015, 0.37), PURPLE)                            # arka levha
frame(1.16, 0.80, -0.025, GOLD, t=0.04, d=0.05, z0=0.37)
friend(-0.28, N_CYAN)
friend(0.28, N_PINK)
heart(0.0, 0.40, 0.0062, N_GOLD)
for (x, z, r) in ((-0.47, 0.66, 0.035), (0.47, 0.66, 0.035), (0.0, 0.64, 0.028), (-0.47, 0.10, 0.025),
                  (0.47, 0.10, 0.025)):                                       # kıvılcımlar
    star_xz(r, x, Y - 0.005, z, N_GOLD, depth=0.01)
finish("referral_neon")
