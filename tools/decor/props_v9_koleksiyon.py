"""DEKORASYON v9 — KOLEKSİYON ödülü (2026-10-25, gameplay/collection_rewards.gd).

Mağazada satılmaz (`exclusive`); 72 aracın hepsini toplayan ustaya TAM KOLEKSİYON taşı verir (KOLEKSİYONER çerçevesi ve
unvanıyla birlikte). Ay kupasından ve ŞAMPİYONLUK KUPASI'ndan ayırt edilmeli: lacivert emaye + altın (çerçeveyle aynı
renkler), kâsenin üstünde altın bir coupé, kaidenin dört köşesinde yıldız. Yazı yok (dil bağımsız).
  collector_trophy  KOLEKSİYONER KUPASI  (zemin)  iki katlı kaide, altın kâse, üstünde altın araba, süzülen halka

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v9_koleksiyon.py
"""
import math as _m

R90 = _m.radians(90)

GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
GOLD_D = mat("KoyuAltin", (0.62, 0.34, 0.04), 0.35, 0.35, emit=(0.06, 0.03, 0.003))
CHROME = mat("Krom", (0.80, 0.82, 0.86), 0.12, 0.3)
MARBLE_K = mat("KaraMermer", (0.035, 0.035, 0.042), 0.12)
BLACK = mat("Siyah", (0.02, 0.02, 0.025), 0.35)
ENAMEL = mat("LacivertEmaye", (0.03, 0.09, 0.32), 0.15, emit=(0.01, 0.03, 0.12))
# Kit ışımayı ×2 yazar: tam değerli neon oyunda beyaza patlıyordu → yarım, doygun (props_v6 / v7 ile aynı).
N_GOLD = mat("NeonAltin", (1.0, 0.70, 0.15), 0.3, emit=(0.60, 0.34, 0.03))


def star_xz(r, x, y, z, material, depth=0.02, inner=0.45):
    """Önden görünen beş köşeli yıldız (prism)."""
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * inner
        a = _m.pi / 2 + i * _m.pi / 5
        pts.append((x + rr * _m.cos(a), z + rr * _m.sin(a)))
    return prism(pts, depth, 'xz', material, offset=y)


def coupe(x, y, z, length, material, depth):
    """Yandan coupé silüeti (XZ profili, Y'de kalınlık), tabanı z'de; altında iki tekerlek."""
    profile = [(-0.50, 0.08), (0.50, 0.08), (0.50, 0.20), (0.40, 0.27), (0.18, 0.29), (0.05, 0.45), (-0.20, 0.45),
               (-0.34, 0.30), (-0.50, 0.25)]
    prism([(x + u * length, z + v * length) for (u, v) in profile], depth, 'xz', material, offset=y)
    for wx in (-0.30, 0.30):
        for wy in (-1, 1):
            cyl(length * 0.10, depth * 0.18, (x + wx * length, y + wy * depth * 0.45, z + length * 0.10), BLACK,
                rot=(R90, 0, 0), seg=14)
            cyl(length * 0.055, depth * 0.20, (x + wx * length, y + wy * depth * 0.45, z + length * 0.10), CHROME,
                rot=(R90, 0, 0), seg=10)


# ================================================================ KOLEKSİYONER KUPASI (zemin)
clear()
box((0.66, 0.66, 0.12), (0, 0, 0.06), MARBLE_K)                              # alt kaide
box((0.68, 0.68, 0.02), (0, 0, 0.125), GOLD)
box((0.50, 0.50, 0.14), (0, 0, 0.20), ENAMEL)                                # üst kaide (lacivert)
box((0.52, 0.52, 0.02), (0, 0, 0.28), GOLD)
for sx in (-1, 1):                                                           # köşelerde yıldız
    for sy in (-1, 1):
        star_xz(0.04, sx * 0.29, sy * 0.29 - 0.03 * (1 if sy < 0 else -1), 0.20, GOLD, depth=0.012)
torus(0.31, 0.012, (0, 0, 0.03), N_GOLD, seg=28, mseg=4)                     # kaide çevresinde neon
cyl(0.06, 0.14, (0, 0, 0.36), GOLD, seg=14)                                   # ayak
ball(0.085, (0, 0, 0.46), GOLD, seg=14, ring=8)
cone(0.06, 0.18, 0.10, (0, 0, 0.56), GOLD, seg=20)                            # kâse tabanı
cone(0.18, 0.30, 0.30, (0, 0, 0.75), GOLD, seg=24)                            # kâse
torus(0.30, 0.022, (0, 0, 0.90), GOLD_D, seg=28, mseg=6)                      # ağız
for s in (-1, 1):                                                            # kulplar
    torus(0.11, 0.022, (s * 0.31, 0, 0.75), GOLD, rot=(R90, 0, 0), seg=16, mseg=6)
cyl(0.10, 0.02, (0, -0.235, 0.74), ENAMEL, rot=(R90, 0, 0), seg=20)            # amblem: lacivert, ortada yıldız
torus(0.10, 0.012, (0, -0.24, 0.74), GOLD_D, rot=(R90, 0, 0), seg=20, mseg=4)
star_xz(0.06, 0, -0.248, 0.74, GOLD, depth=0.01)
cyl(0.24, 0.03, (0, 0, 0.93), ENAMEL, seg=24)                                 # kâsenin kapağı
coupe(0, 0, 0.945, 0.46, GOLD, 0.16)                                          # kapakta altın araba
torus(0.40, 0.014, (0, 0, 1.22), N_GOLD, rot=(_m.radians(10), 0, 0), seg=30, mseg=4)   # süzülen halka
finish("collector_trophy")
