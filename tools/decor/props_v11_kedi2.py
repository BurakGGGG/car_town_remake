"""DEKORASYON v11 — KEDİ EŞYALARI 2 (2026-11-03): EVCİL HAYVAN sekmesine 9 eşya + DUVAR EŞYASI'na 1.

Kullanıcı isteği: "daha fazla kedi dekorasyonu". Kedinin kullandıkları (world/pets/pet_world.gd PET_FURNITURE, noktalar
aşağıdaki TASARIM metresinde, oyunda PET_FURNITURE_SCALE ile büyür):

  cat_box         KARTON KUTU          açık kapaklı kutu, içinde battaniye — YATAK   (battaniye üstü 0,03 m)
  cat_tire_bed    LASTİK YATAK         yatık tek lastik, ortası minder — YATAK        (minder tepesi 0,165 m)
  cat_hammock     KEDİ HAMAĞI          ahşap çapraz ayaklar, sarkık bez — YATAK       (bezin dibi 0,21 m)
  cat_scratcher   TIRMALAMA DİREĞİ     sisal direk, minderli tepe — KULE (tek nokta)  (0,575 m)
  cat_house       MİNİ GARAJ KEDİ EVİ  yarı açık kepenkli garaj, çatıda minder — KULE (0,405 m)
  cat_fountain    SU ÇEŞMESİ           çiçek ağızlı seramik çeşme — KAP
  lux_cat_sakura  SAKURA KEDİ AĞACI    (elmas) lake davul + sakura gövdeli kule — KULE (0,427 m / 0,973 m)
  cat_tunnel      KEDİ TÜNELİ          kırışık bez tünel (süs)
  cat_toys        OYUNCAK SEPETİ       hasır sepet, yün yumaklar, tüy çubuğu, fareler (süs)
  cat_wall_steps  KEDİ BASAMAKLARI     duvar rafları + delikli kutu (duvar eşyası, süs)

Ölçek ve eksenler props_v10_kedi.py ile aynı (SCALE 1,25; ÖN = −Y; orijin tabanın ortası).
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v11_kedi2.py
"""
import math as _m
import os
import random

import mathutils

exec(open(os.path.join(os.path.dirname(__file__), "kit_torna.py"), encoding="utf-8").read())

SCALE = 1.25
# Kedinin kullandığı eşyalar: PET_FURNITURE noktaları tabanı 0 varsayar (finish en alt noktayı 0'a çeker)
USED_BY_CAT = {"cat_box", "cat_tire_bed", "cat_hammock", "cat_scratcher", "cat_house", "lux_cat_sakura",
               "cat_fountain"}
_finish = finish


def finish(name, export=True):
    low = min((o.matrix_world @ v.co).z for o in col().objects for v in o.data.vertices)
    if name in USED_BY_CAT and abs(low) > 0.002:
        print("  UYARI %s: en alt nokta %.4f m (kedi noktaları tabanı 0 varsayar)" % (name, low))
    m = mathutils.Matrix.Scale(SCALE, 4)
    for o in col().objects:
        o.matrix_world = m @ o.matrix_world
    return _finish(name, export)


R90 = _m.pi / 2

# --- Malzemeler ---------------------------------------------------------------------------
CARD = mat("Karton", (0.62, 0.43, 0.22), 0.9)
CARD_D = mat("KartonIc", (0.47, 0.31, 0.15), 0.9)
TAPE = mat("Bant", (0.78, 0.62, 0.35), 0.45)
INK = mat("Murekkep", (0.07, 0.07, 0.08), 0.8)
BLANKET = mat("Battaniye", (0.70, 0.18, 0.15), 0.95)
BLANKET2 = mat("BattaniyeKrem", (0.88, 0.82, 0.70), 0.95)
TIRE = mat("Lastik", (0.045, 0.045, 0.05), 0.85)
TIRE_GR = mat("LastikDis", (0.07, 0.07, 0.075), 0.9)
WHITE = mat("Beyaz", (0.90, 0.90, 0.88), 0.35)
PLY = mat("Kontrplak", (0.62, 0.45, 0.25), 0.7)
PLY_D = mat("KontrplakKenar", (0.42, 0.29, 0.14), 0.7)
WOOD = mat("Ahsap", (0.45, 0.27, 0.12), 0.75)
CREAM = mat("KremMinder", (0.86, 0.80, 0.68), 0.95)
TEAL = mat("KumasPetrol", (0.03, 0.26, 0.30), 0.95)
MUSTARD = mat("Hardal", (0.85, 0.60, 0.12), 0.9)
RED_C = mat("MinderKirmizi", (0.62, 0.12, 0.10), 0.95)
SISAL = mat("Sisal", (0.66, 0.53, 0.33), 0.95)
SISAL_D = mat("SisalKoyu", (0.50, 0.39, 0.22), 0.95)
CARPET = mat("HaliGri", (0.36, 0.38, 0.42), 0.95)
ORANGE = mat("Turuncu", (0.90, 0.38, 0.05), 0.45)
WATER = mat("Su", (0.12, 0.42, 0.82), 0.1)
CERAMIC = mat("SeramikNane", (0.40, 0.72, 0.66), 0.3)
NAVY = mat("Paspas", (0.09, 0.20, 0.35), 0.9)
FISH = mat("OyuncakBalik", (0.95, 0.70, 0.10), 0.6)
FISH_B = mat("OyuncakBalikMavi", (0.15, 0.45, 0.85), 0.6)
STRING = mat("Ip", (0.85, 0.82, 0.75), 0.9)
MOUSE = mat("OyuncakFare", (0.55, 0.55, 0.58), 0.9)
PINK = mat("Pembe", (0.95, 0.55, 0.65), 0.7)
PURPLE = mat("Mor", (0.38, 0.18, 0.58), 0.9)
YELLOW = mat("Sari", (0.95, 0.75, 0.12), 0.8)
DARK = mat("Karanlik", (0.03, 0.03, 0.035), 0.9)
WICKER = mat("Hasir", (0.62, 0.44, 0.22), 0.9)
WICKER_D = mat("HasirKoyu", (0.42, 0.28, 0.12), 0.9)
YARN_R = mat("YunKirmizi", (0.80, 0.12, 0.16), 0.95)
YARN_B = mat("YunMavi", (0.15, 0.40, 0.80), 0.95)
YARN_G = mat("YunYesil", (0.25, 0.62, 0.25), 0.95)
WALL_C = mat("GarajDuvar", (0.88, 0.85, 0.78), 0.8)
ROOF = mat("Cati", (0.20, 0.22, 0.25), 0.7)
DOOR = mat("Kepenk", (0.62, 0.65, 0.68), 0.45, 0.3)
DOOR_L = mat("KepenkCizgi", (0.45, 0.48, 0.52), 0.5, 0.3)
GLASS_D = mat("PencereMavi", (0.30, 0.55, 0.75), 0.15)
LACQ = mat("SiyahLake", (0.03, 0.025, 0.03), 0.25)
VERMIL = mat("KirmiziLake", (0.70, 0.08, 0.05), 0.3)
BARK = mat("SakuraKabuk", (0.24, 0.13, 0.10), 0.85)
SAKURA = mat("Sakura", (1.0, 0.70, 0.80), 0.8)
SAKURA2 = mat("SakuraKoyu", (0.95, 0.52, 0.68), 0.8)
VELVET_P = mat("KadifePembe", (0.80, 0.30, 0.45), 0.95)
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
LANTERN = mat("FenerKirmizi", (0.85, 0.12, 0.08), 0.6, emit=(0.30, 0.04, 0.02))


# --- Yardımcılar --------------------------------------------------------------------------

def tyre(z0, material=TIRE, od=0.60, width=0.19, loc=(0.0, 0.0), seg=24):
    """Yatık lastik (props_v10_kedi.py ile aynı kesit)."""
    ro, ri = od / 2, od / 2 - 0.10
    w = width
    prof = [(ri, 0.035), (ri + 0.018, 0.004), (ro - 0.03, 0.0), (ro - 0.006, 0.02), (ro, 0.05),
            (ro + 0.003, w * 0.5), (ro, w - 0.05), (ro - 0.006, w - 0.02), (ro - 0.03, w), (ri + 0.018, w - 0.004),
            (ri, w - 0.035)]
    lathe(prof, material, (loc[0], loc[1], z0), seg=seg, closed=True)
    for k in range(seg):
        a = 2 * _m.pi * (k + 0.5) / seg
        box((0.012, 0.03, w * 0.62), (loc[0] + (ro + 0.002) * _m.cos(a), loc[1] + (ro + 0.002) * _m.sin(a),
                                      z0 + w * 0.5), TIRE_GR, rot=(0, 0, a))


def paw(cx, cy, z, s, material, face="up", depth=0.006):
    """Pati izi (props_v10_kedi.py ile aynı): face='up' zemine yatık, 'front' önden (−Y) bakan."""
    parts = [((0.0, -0.10), 0.42, 0.34), ((-0.30, 0.22), 0.15, 0.17), ((-0.11, 0.38), 0.15, 0.17),
             ((0.11, 0.38), 0.15, 0.17), ((0.30, 0.22), 0.15, 0.17)]
    for (dx, dy), rx, ry in parts:
        if face == "up":
            ecyl(rx * s, ry * s, depth, (cx + dx * s, cy + dy * s, z + depth / 2), material, seg=14)
        else:
            ecyl(rx * s, ry * s, depth, (cx + dx * s, cy - depth / 2, z + dy * s), material, seg=14,
                 rot=(R90, 0, 0))


def toy_fish(x, y, z, yaw=0.3, s=1.0):
    def build():
        ball(0.045 * s, (0, 0, 0.022 * s), FISH, scale=(1.0, 0.45, 0.42), seg=12, ring=6)
        cone(0.028 * s, 0.0, 0.035 * s, (0.055 * s, 0, 0.022 * s), FISH_B, rot=(0, -R90, 0), seg=8)
        ball(0.006 * s, (-0.03 * s, -0.019 * s, 0.03 * s), NAVY, seg=6, ring=4)
    local(build, (x, y, z), yaw)


def toy_mouse(x, y, yaw=0.0, s=1.0, material=MOUSE):
    def build():
        ball(0.04 * s, (0, 0, 0.022 * s), material, scale=(1.0, 0.62, 0.55), seg=12, ring=6)
        cone(0.016 * s, 0.0, 0.03 * s, (-0.05 * s, 0, 0.022 * s), material, rot=(0, -R90, 0), seg=8)   # burun
        for sy in (-1, 1):
            ecyl(0.013 * s, 0.013 * s, 0.004 * s, (-0.02 * s, sy * 0.016 * s, 0.045 * s), PINK, seg=10,
                 rot=(0, -0.5, 0))
        ball(0.005 * s, (-0.078 * s, 0, 0.022 * s), PINK, seg=6, ring=4)
        branch([(0.04 * s, 0, 0.015 * s), (0.08 * s, 0.02 * s, 0.006 * s), (0.12 * s, -0.01 * s, 0.004 * s)],
               0.004 * s, 0.003 * s, PINK, seg=5)
    local(build, (x, y, 0.0), yaw)


def yarn(x, y, z, r, material, seed=1):
    ball(r, (x, y, z), material, seg=14, ring=9)
    rng = random.Random(seed)
    for k in range(4):
        torus(r * 0.98, r * 0.06, (x, y, z), material, rot=(rng.uniform(0, _m.pi), rng.uniform(0, _m.pi), 0),
              seg=14, mseg=3)
    branch([(x + r * 0.7, y - r * 0.5, z - r * 0.5), (x + r * 1.6, y - r * 1.2, z - r * 0.9),
            (x + r * 2.4, y - r * 1.0, max(z - r * 1.0, 0.004))], r * 0.07, r * 0.07, material, seg=4)


def arrow_up(x, y, z, s, material):
    """Kolinin ön yüzüne basılı 'bu taraf yukarı' oku (önden −Y bakan)."""
    box((0.10 * s, 0.002, 0.42 * s), (x, y, z), material)
    prism([(x - 0.28 * s, z + 0.18 * s), (x + 0.28 * s, z + 0.18 * s), (x, z + 0.48 * s)], 0.002, 'xz', material,
          offset=y)


# --- 1) KARTON KUTU (yatak) -------------------------------------------------------------------

def cat_box():
    W, D, H, t = 0.46, 0.36, 0.15, 0.012
    box((W, D, t), (0, 0, t / 2), CARD_D)
    box((W, t, H), (0, -D / 2 + t / 2, H / 2), CARD)
    box((W, t, H), (0, D / 2 - t / 2, H / 2), CARD)
    for sx in (-1, 1):
        box((t, D - 2 * t, H), (sx * (W / 2 - t / 2), 0, H / 2), CARD)
    # Açık kapaklar: uzun kapaklar öne / arkaya, kısalar yanlara sarkar
    lf, th = D / 2 * 0.9, _m.radians(125)
    for sy in (-1, 1):
        c = (0, sy * (D / 2 + _m.sin(th) * lf / 2), H + _m.cos(th) * lf / 2)
        box((W, t, lf), c, CARD, rot=(-sy * th, 0, 0))
        box((0.06, t * 1.3, lf * 0.92), c, TAPE, rot=(-sy * th, 0, 0))     # yırtık koli bandı
    ls, ts = 0.14, _m.radians(105)
    for sx in (-1, 1):
        c = (sx * (W / 2 + _m.sin(ts) * ls / 2), 0, H + _m.cos(ts) * ls / 2)
        box((t, D - 0.03, ls), c, CARD, rot=(0, sx * ts, 0))
    # Ön yüzde 'bu taraf yukarı' okları + pati damgası
    arrow_up(-0.15, -D / 2 - 0.001, 0.055, 0.12, INK)
    arrow_up(-0.10, -D / 2 - 0.001, 0.055, 0.12, INK)
    paw(0.13, -D / 2 - 0.001, 0.075, 0.07, INK, face="front", depth=0.002)
    # İçeride buruşuk battaniye
    box((W - 2 * t - 0.01, D - 2 * t - 0.01, 0.018), (0, 0, t + 0.009), BLANKET)
    ball(0.08, (0.12, 0.09, 0.03), BLANKET, scale=(1.4, 0.8, 0.30), seg=12, ring=6)
    for x in (-0.16, -0.08, 0.0, 0.08, 0.16):
        box((0.012, D - 2 * t - 0.02, 0.0025), (x, 0, t + 0.0185), BLANKET2)   # ekose çizgiler
    toy_mouse(0.36, -0.33, yaw=2.4)
    finish("cat_box")


# --- 2) LASTİK YATAK ----------------------------------------------------------------------------

def cat_tire_bed():
    tyre(0.0, TIRE, od=0.62)
    torus(0.255, 0.006, (0, 0, 0.188), WHITE, seg=40, mseg=4)        # beyaz yanak şeridi
    cyl(0.21, 0.02, (0, 0, 0.03), PLY, seg=24)
    lathe([(0.215, 0.0), (0.225, 0.04), (0.22, 0.09), (0.19, 0.115), (0.10, 0.125), (0.0, 0.127)], CREAM,
          (0, 0, 0.04), seg=28)
    for k in range(8):                                                # minder düğmeleri
        a = k * _m.tau / 8
        ball(0.008, (0.13 * _m.cos(a), 0.13 * _m.sin(a), 0.162), TEAL, seg=6, ring=4)
    toy_fish(0.21, -0.20, 0.188, yaw=0.9)
    finish("cat_tire_bed")


# --- 3) KEDİ HAMAĞI -------------------------------------------------------------------------------

def cat_hammock():
    X, Y, Z = 0.26, 0.16, 0.30
    for sx in (-1, 1):
        rod((sx * X, -Y, 0.012), (sx * X, Y, Z), 0.016, WOOD)          # uç kapağı zeminin altına inmesin
        rod((sx * X, Y, 0.012), (sx * X, -Y, Z), 0.016, WOOD)
        ball(0.022, (sx * X, 0, Z / 2), PLY_D, seg=8, ring=5)        # çapraz cıvatası
        for sy in (-1, 1):
            ball(0.018, (sx * X, sy * Y, Z), WOOD, seg=8, ring=5)
            cyl(0.02, 0.01, (sx * X, sy * Y, 0.005), PLY_D, seg=8)    # ayak pabucu
    for sy in (-1, 1):
        rod((-X - 0.03, sy * Y, Z), (X + 0.03, sy * Y, Z), 0.016, WOOD)
    rod((-X, 0, Z / 2), (X, 0, Z / 2), 0.012, WOOD)
    sag = 0.09

    def zf(x, y):
        return Z - 0.012 - sag * (1.0 - (y / Y) ** 2)

    sheet(zf, -X + 0.02, X - 0.02, -Y, Y, 8, 10, CREAM, t=0.008)
    for x0 in (-0.17, 0.11):                                          # bezde petrol şeritler
        sheet(lambda x, y: zf(x, y) + 0.005, x0, x0 + 0.06, -Y + 0.005, Y - 0.005, 2, 10, TEAL, t=0.002)
    # Raya sarılan bez kenarı
    for sy in (-1, 1):
        cyl(0.021, 2 * X - 0.04, (0, sy * Y, Z), CREAM, rot=(0, R90, 0), seg=10)
    finish("cat_hammock")


# --- 4) TIRMALAMA DİREĞİ ------------------------------------------------------------------------------

def cat_scratcher():
    box((0.42, 0.42, 0.04), (0, 0, 0.02), CARPET)
    box((0.30, 0.16, 0.008), (0, -0.11, 0.044), SISAL)               # önde sisal paspas
    for x in (-0.12, -0.06, 0.0, 0.06, 0.12):
        box((0.006, 0.16, 0.002), (x, -0.11, 0.049), SISAL_D)
    cyl(0.05, 0.48, (0, 0, 0.28), SISAL, seg=14)
    z, k = 0.06, 0
    while z < 0.50:
        torus(0.05, 0.0065, (0, 0, z), SISAL_D if k % 2 else SISAL, seg=12, mseg=3)
        z += 0.04
        k += 1
    cyl(0.19, 0.025, (0, 0, 0.5325), PLY, seg=28)
    torus(0.19, 0.0125, (0, 0, 0.5325), PLY_D, seg=32, mseg=4)
    lathe([(0.165, 0.0), (0.16, 0.018), (0.14, 0.03), (0.0, 0.032)], TEAL, (0, 0, 0.545), seg=24)
    hx, hy = 0.13, -0.10                                              # sarkan ponpon
    rod((hx, hy, 0.52), (hx, hy, 0.30), 0.003, STRING, seg=4)
    ball(0.032, (hx, hy, 0.275), PINK, seg=12, ring=8)
    for k in range(4):
        a = k * _m.pi / 2
        cone(0.010, 0.0, 0.04, (hx + 0.02 * _m.cos(a), hy + 0.02 * _m.sin(a), 0.255), YELLOW, rot=(_m.pi, 0, 0),
             seg=5)
    finish("cat_scratcher")


# --- 5) SU ÇEŞMESİ (kap) ----------------------------------------------------------------------------

def cat_fountain():
    cyl(0.17, 0.008, (0, 0, 0.004), NAVY, seg=32)
    paw(0.0, -0.135, 0.008, 0.028, ORANGE)
    lathe([(0.095, 0.0), (0.105, 0.01), (0.112, 0.055), (0.116, 0.07), (0.104, 0.07), (0.098, 0.05),
           (0.0, 0.045)], CERAMIC, (0, 0, 0.008), seg=28)
    cyl(0.1, 0.004, (0, 0, 0.068), WATER, seg=28)
    lathe([(0.038, 0.0), (0.034, 0.03), (0.018, 0.048), (0.0, 0.052)], WHITE, (0, 0, 0.05), seg=16)
    for k in range(5):                                                # çiçek ağız
        a = k * _m.tau / 5
        ball(0.018, (0.016 * _m.cos(a), 0.016 * _m.sin(a), 0.104), CERAMIC, scale=(1.0, 1.0, 0.45), seg=8, ring=5)
    cone(0.008, 0.016, 0.03, (0, 0, 0.12), WATER, seg=10)            # fışkıran su
    ball(0.016, (0, 0, 0.138), WATER, scale=(1.0, 1.0, 0.5), seg=10, ring=5)
    for k in range(6):                                                # damlalar
        a = k * _m.tau / 6 + 0.3
        ball(0.005, (0.05 * _m.cos(a), 0.05 * _m.sin(a), 0.074), WHITE, seg=6, ring=4)
    finish("cat_fountain")


# --- 6) KEDİ TÜNELİ ------------------------------------------------------------------------------------

def cat_tunnel():
    r, n = 0.12, 25
    path = [(-0.45 + 0.9 * i / (n - 1), 0.06 * _m.sin(_m.pi * (i / (n - 1)) * 1.6 - 0.4), r) for i in range(n)]
    o = tube(path, lambda i, nn: r + (0.008 if i % 2 else -0.004), PURPLE, seg=16)
    solidify(o, 0.006)
    for p in (path[0], path[-1]):                                     # uçlarda sarı kasnak + karanlık iç
        x = p[0]
        rot = (0, R90, 0)
        torus(r + 0.004, 0.012, p, YELLOW, rot=rot, seg=18, mseg=4)
        cyl(r - 0.01, 0.004, (x * 0.86, p[1], r), DARK, rot=rot, seg=16)
    cyl(r - 0.01, 0.004, (0.0, path[n // 2][1], r), DARK, rot=(0, R90, 0), seg=16)   # ortada da karanlık
    hx, hy = 0.43, path[-1][1]                                       # uçta sarkan ponpon
    rod((hx, hy, 2 * r + 0.005), (hx + 0.06, hy - 0.04, 0.10), 0.003, STRING, seg=4)
    ball(0.028, (hx + 0.06, hy - 0.04, 0.075), YELLOW, seg=10, ring=6)
    finish("cat_tunnel")


# --- 7) OYUNCAK SEPETİ ----------------------------------------------------------------------------------

def cat_toys():
    lathe([(0.15, 0.0), (0.17, 0.02), (0.19, 0.16), (0.20, 0.18), (0.186, 0.18), (0.176, 0.03), (0.0, 0.022)],
          WICKER, (0, 0, 0), seg=28)
    for z in (0.05, 0.09, 0.13):
        torus(0.178 + (z - 0.02) * 0.125, 0.006, (0, 0, z), WICKER_D, seg=28, mseg=3)
    torus(0.193, 0.012, (0, 0, 0.18), WICKER_D, seg=28, mseg=4)
    yarn(-0.07, 0.03, 0.17, 0.065, YARN_R, seed=2)
    yarn(0.07, -0.03, 0.16, 0.058, YARN_B, seed=3)
    yarn(0.02, 0.10, 0.15, 0.05, YARN_G, seed=4)
    rod((0.05, 0.06, 0.08), (0.20, 0.17, 0.62), 0.006, PLY_D, seg=6)   # tüy çubuğu
    tip = (0.20, 0.17, 0.62)
    for k, m in enumerate((PINK, YELLOW, FISH_B)):
        a = -0.6 + 0.6 * k
        cone(0.018, 0.0, 0.14, (tip[0] + 0.05 * _m.sin(a), tip[1], tip[2] + 0.05), m, rot=(0, a, 0), seg=6)
    toy_mouse(-0.27, -0.14, yaw=0.5)
    toy_mouse(0.26, -0.22, yaw=-2.2, material=mat("FareKrem", (0.85, 0.80, 0.70), 0.9))
    ball(0.03, (0.02, -0.29, 0.03), PINK, seg=12, ring=8)            # zilli top
    ball(0.012, (0.02, -0.318, 0.03), GOLD, seg=8, ring=5)
    finish("cat_toys")


# --- 8) MİNİ GARAJ KEDİ EVİ (kule: çatıda minder) ----------------------------------------------------

def cat_house():
    W, D, H = 0.56, 0.44, 0.34
    box((W, D, H), (0, 0, H / 2), WALL_C)
    box((W + 0.02, D + 0.02, 0.03), (0, 0, 0.015), ROOF)               # kaide
    box((0.30, 0.012, 0.20), (0, -D / 2 - 0.004, 0.10), DARK)          # kapı boşluğu
    box((0.32, 0.03, 0.10), (0, -D / 2 - 0.012, 0.255), DOOR)          # yarı açık kepenk
    for z in (0.215, 0.235, 0.255, 0.275, 0.295):
        box((0.322, 0.003, 0.004), (0, -D / 2 - 0.028, z), DOOR_L)
    box((0.30, 0.03, 0.012), (0, -D / 2 - 0.012, 0.206), DOOR_L)        # kepenk alt çıtası
    for sx in (-1, 1):                                                 # kapı pervazı (sarı)
        box((0.022, 0.016, 0.31), (sx * 0.166, -D / 2 - 0.006, 0.155), YELLOW)
    box((0.354, 0.016, 0.022), (0, -D / 2 - 0.006, 0.311), YELLOW)
    box((0.12, 0.012, 0.022), (0, -D / 2 - 0.006, 0.329), ORANGE)       # pati tabelası
    paw(0.0, -D / 2 - 0.013, 0.32, 0.03, WHITE, face="front", depth=0.002)
    box((0.012, 0.14, 0.10), (W / 2 + 0.004, 0.04, 0.20), GLASS_D)      # yan pencere
    box((0.016, 0.16, 0.012), (W / 2 + 0.005, 0.04, 0.144), PLY_D)
    box((0.016, 0.16, 0.012), (W / 2 + 0.005, 0.04, 0.256), PLY_D)
    box((0.016, 0.012, 0.10), (W / 2 + 0.006, 0.04, 0.20), PLY_D)
    box((W + 0.04, D + 0.04, 0.03), (0, 0, H + 0.015), ROOF)           # çatı + parapet
    for sy in (-1, 1):
        box((W + 0.04, 0.02, 0.035), (0, sy * (D / 2 + 0.01), H + 0.047), ROOF)
    for sx in (-1, 1):
        box((0.02, D + 0.04, 0.035), (sx * (W / 2 + 0.01), 0, H + 0.047), ROOF)
    box((0.38, 0.30, 0.025), (0, 0.02, H + 0.0425), RED_C)             # çatıda minder
    box((0.35, 0.27, 0.012), (0, 0.02, H + 0.061), RED_C)
    cone(0.035, 0.008, 0.08, (0.23, -0.30, 0.04), ORANGE, seg=8)       # oyuncak koni
    box((0.07, 0.07, 0.008), (0.23, -0.30, 0.004), ORANGE)
    cyl(0.031, 0.012, (0.23, -0.30, 0.045), WHITE, seg=8)
    finish("cat_house")


# --- 9) KEDİ BASAMAKLARI (duvar) -------------------------------------------------------------------------

def cat_wall_steps():
    def shelf(x, z, cushion=None):
        box((0.36, 0.22, 0.03), (x, -0.11, z), PLY)
        box((0.36, 0.012, 0.034), (x, -0.226, z), PLY_D)
        for sx in (-1, 1):
            prism([(0.0, z - 0.015), (-0.15, z - 0.015), (0.0, z - 0.15)], 0.02, 'yz', DARK, offset=x + sx * 0.14)
        if cushion:
            box((0.30, 0.18, 0.025), (x, -0.11, z + 0.0275), cushion)

    shelf(-0.38, 0.0, TEAL)
    shelf(0.0, 0.28, None)
    cyl(0.018, 0.36, (0.0, -0.21, 0.30), SISAL, rot=(0, R90, 0), seg=10)   # sisal sarılı ön kenar
    for x in (-0.15, -0.09, -0.03, 0.03, 0.09, 0.15):
        torus(0.019, 0.004, (x, -0.21, 0.30), SISAL_D, rot=(0, R90, 0), seg=10, mseg=3)
    shelf(0.38, 0.56, None)
    box((0.30, 0.22, 0.24), (0.38, -0.11, 0.695), PLY)                 # delikli kutu
    box((0.32, 0.23, 0.02), (0.38, -0.115, 0.825), PLY_D)
    cyl(0.07, 0.004, (0.38, -0.222, 0.69), DARK, rot=(R90, 0, 0), seg=18)
    torus(0.07, 0.008, (0.38, -0.222, 0.69), MUSTARD, rot=(R90, 0, 0), seg=18, mseg=4)
    rod((-0.30, -0.20, -0.015), (-0.30, -0.20, -0.22), 0.003, STRING, seg=4)   # sarkan fare
    ball(0.025, (-0.30, -0.20, -0.24), MOUSE, scale=(0.62, 0.62, 1.0), seg=10, ring=6)
    for sy in (-1, 1):
        ball(0.009, (-0.30 + sy * 0.012, -0.20, -0.22), PINK, seg=6, ring=4)
    finish("cat_wall_steps")


# --- 10) SAKURA KEDİ AĞACI (elmas; kule) -------------------------------------------------------------------

def lux_cat_sakura():
    ecyl(0.52, 0.34, 0.04, (0.18, 0.02, 0.02), LACQ, seg=32)
    o = torus(1.0, 0.012, (0.18, 0.02, 0.038), GOLD, seg=40, mseg=4)
    o.scale = (0.52, 0.34, 1.0)
    # Lake davul (alt konak): girişi önde, altın bantlar, pembe kadife minder
    lathe([(0.22, 0.0), (0.235, 0.03), (0.238, 0.20), (0.235, 0.36), (0.22, 0.39), (0.0, 0.39)], VERMIL,
          (0, 0, 0.04), seg=28)
    for z in (0.10, 0.36):
        torus(0.238, 0.008, (0, 0, z), GOLD, seg=32, mseg=4)
    cyl(0.085, 0.006, (0, -0.236, 0.21), DARK, rot=(R90, 0, 0), seg=18)
    torus(0.085, 0.008, (0, -0.238, 0.21), GOLD, rot=(R90, 0, 0), seg=18, mseg=4)
    lathe([(0.21, 0.0), (0.205, 0.02), (0.18, 0.035), (0.0, 0.037)], VELVET_P, (0, 0, 0.43), seg=28)
    # Sakura gövdesi (kalın, kıvrık) + tepe platformu
    branch([(0.42, 0.06, 0.04), (0.36, 0.08, 0.30), (0.44, 0.05, 0.58), (0.37, 0.02, 0.80), (0.38, 0.0, 0.92)],
           0.075, 0.05, BARK, seg=10)
    for (a, b) in (((0.42, 0.06, 0.07), (0.52, 0.16, 0.05)), ((0.42, 0.06, 0.07), (0.30, 0.14, 0.05))):   # kökler (kaide üstünde)
        rod(a, b, 0.03, BARK, seg=6)
    cyl(0.17, 0.025, (0.38, 0.0, 0.9325), LACQ, seg=28)
    torus(0.17, 0.0125, (0.38, 0.0, 0.9325), GOLD, seg=32, mseg=4)
    lathe([(0.145, 0.0), (0.14, 0.016), (0.12, 0.026), (0.0, 0.028)], VELVET_P, (0.38, 0.0, 0.945), seg=24)
    # Dallar ARKAYA / YUKARIYA (kamera önden-sağdan bakar: taç y ≥ 0'da kalır, platformdaki kediyi örtmez)
    rng = random.Random(11)
    limbs = ([(0.40, 0.05, 0.70), (0.20, 0.22, 0.95), (-0.05, 0.36, 1.12), (-0.22, 0.42, 1.20)],
             [(0.42, 0.04, 0.78), (0.62, 0.20, 1.00), (0.80, 0.32, 1.12), (0.92, 0.40, 1.18)],
             [(0.38, 0.06, 0.92), (0.36, 0.26, 1.18), (0.30, 0.40, 1.42)],
             [(0.39, 0.05, 0.86), (0.52, 0.30, 1.22), (0.62, 0.44, 1.40)],
             [(0.38, 0.05, 0.90), (0.18, 0.30, 1.26), (0.08, 0.48, 1.36)])
    tips = []
    for pts in limbs:
        branch(pts, 0.035, 0.016, BARK, seg=6)
        tips.extend(pts[1:])
    for (x, y, z) in tips:                                             # çiçek kümeleri dal boyunca
        for k in range(2):
            r = rng.uniform(0.10, 0.15)
            ball(r, (x + rng.uniform(-0.10, 0.10), max(y + rng.uniform(-0.04, 0.12), 0.16),   # davul → tepe zıplama yolundan geride
                     z + rng.uniform(0.0, 0.12)), SAKURA if (k + int(z * 10)) % 2 else SAKURA2,
                 scale=(1.15, 1.0, 0.72), seg=8, ring=5)
    for k in range(10):                                                # tacı dolduran üst katman
        a = rng.uniform(0.15, _m.pi - 0.15)
        x, y = 0.35 + 0.55 * _m.cos(a), 0.12 + 0.40 * _m.sin(a)
        ball(rng.uniform(0.13, 0.18), (x, y, rng.uniform(1.30, 1.55)), SAKURA if k % 2 else SAKURA2,
             scale=(1.2, 1.0, 0.65), seg=8, ring=5)
    for k in range(6):                                                 # altın varak parıltıları
        a = rng.uniform(0.2, _m.pi - 0.2)
        ball(0.025, (0.35 + 0.50 * _m.cos(a), 0.12 + 0.36 * _m.sin(a), rng.uniform(1.25, 1.55)), GOLD, seg=6, ring=4)
    for k in range(10):                                                # yere düşmüş yapraklar
        a = rng.uniform(0, _m.tau)
        d = rng.uniform(0.28, 0.46)
        cyl(0.013, 0.003, (0.18 + d * _m.cos(a), 0.02 + d * _m.sin(a) * 0.62, 0.0415), SAKURA, seg=6)
    # Daldan sarkan iki küçük fener
    for (lx, ly, lz) in ((-0.05, 0.36, 1.10), (0.80, 0.32, 1.10)):
        rod((lx, ly, lz), (lx, ly, lz - 0.16), 0.003, STRING, seg=4)
        lathe([(0.0, 0.0), (0.035, 0.012), (0.045, 0.045), (0.035, 0.078), (0.0, 0.09)], LANTERN,
              (lx, ly, lz - 0.25), seg=12)
        cyl(0.022, 0.012, (lx, ly, lz - 0.158), LACQ, seg=10)
        cyl(0.022, 0.012, (lx, ly, lz - 0.252), LACQ, seg=10)
        cone(0.012, 0.0, 0.04, (lx, ly, lz - 0.28), GOLD, rot=(_m.pi, 0, 0), seg=6)
    finish("lux_cat_sakura")


for build in (cat_box, cat_tire_bed, cat_hammock, cat_scratcher, cat_fountain, cat_tunnel, cat_toys, cat_house,
              cat_wall_steps, lux_cat_sakura):
    build()
    clear()
print("v11 kedi partisi tamam")
