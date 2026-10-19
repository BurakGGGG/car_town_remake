"""MAHALLE GARAJI — GARAJLARIM'ın başlangıç garajı (docs/GARAJLAR_TASARIM.md §7, kullanıcı kararları 2026-10-19):
perspektif diorama (ön ve sağ duvar kesik, çatı yok, ince kirişler), sıcak akşamüstü; sol duvardaki açık kepenkten
güneş girer. 14 × 10 m iç mekân, 4,4 m yükseklik.

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan bakar):
  arka sıra   PARK 0-3   arka duvara dik, burun kameraya (taban kapasite 4)
  ön sol      PARK 4-5   yan duruş; PARK YERİ sv.1'de eski koltuk / koli / hurda, sv.2 → 4 açılır, sv.3 → 5
  ön sağ      LİFT alanı (sv.1 kriko, sv.2 iki kolon, sv.3 dört kolonlu sergi lifti)
  sol duvar   kepenk (araçların girdiği koridora açılır)
Kalem seviyeleri koleksiyonlarda: Floor_L1..3, Walls_L1..3, Lights_L1..3, Lift_L1..3, Park_L1..3; ortak: Static.
Park yerleri boş nesneler: Slot_0..5 (konum + yön, araç burnu nesnenin -Y'sine bakar).

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/mahalle.py -- preview <seviye 1-3> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 14.0, 10.0, 4.4      # iç mekân
T = 0.3                        # duvar kalınlığı
DOOR_Y = (2.6, 5.4)            # sol duvardaki kepenk açıklığı (koridor)
DOOR_H = 3.3
SLOTS = [
    # (x, y, yön °) — yön: aracın burnunun baktığı açı (0 = -Y güney / kameraya)
    (2.25, 7.35, 0.0), (5.05, 7.35, 0.0), (7.85, 7.35, 0.0), (10.65, 7.35, 0.0),
    (2.9, 1.55, -90.0), (7.6, 1.55, -90.0),
]
LIFT_AT = (11.9, 2.55)


# --- Zemin dokuları (numpy) ------------------------------------------------------------------

def floor_textures(out_dir, ppm=96):
    """Üç zemin seviyesi (sv.1 aşınmış beton, sv.2 gri epoksi, sv.3 dama karo) — DOĞRUSAL renk, PNG."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm      # metre, Y kuzey (görüntü satırı ters)
    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    # sv.1: aşınmış beton — leke, çatlak, yağ izi, derz
    n = _fbm((h, w), 60, 11)
    fine = _fbm((h, w), 6, 21, 3)
    base = np.array(_hex("#8E8A82"))[None, None, :] * (0.82 + 0.3 * n[..., None] + 0.08 * fine[..., None])
    rng = np.random.default_rng(5)
    for _ in range(26):   # yağ lekeleri: arka sıra park yerlerinde yoğun
        sx, sy, _r = SLOTS[rng.integers(0, 4)]
        cx, cy = sx + rng.normal(0, 0.6), sy + rng.normal(-0.6, 0.9)
        r = rng.uniform(0.15, 0.6)
        dd = np.sqrt((mx - cx) ** 2 + ((my - cy) * rng.uniform(0.7, 1.3)) ** 2)
        a = np.clip(1.0 - dd / r, 0, 1) ** 1.5 * rng.uniform(0.25, 0.6)
        base = base * (1 - a[..., None] * 0.75)
    joints = (np.abs(((mx + 0.02) % 3.5) - 0.0) < 0.025) | (np.abs(((my + 0.02) % 3.5) - 0.0) < 0.025)
    base[joints] *= 0.55
    for i in range(14):   # çatlaklar: rastgele yürüyüş
        px, py = rng.uniform(0, W), rng.uniform(0, D)
        ang = rng.uniform(0, math.tau)
        for s in range(140):
            ang += rng.normal(0, 0.35)
            px += math.cos(ang) * 0.03
            py += math.sin(ang) * 0.03
            ix, iy = int(px * ppm), int(h - 1 - py * ppm)
            if 0 <= ix < w - 1 and 0 <= iy < h - 1:
                base[iy:iy + 2, ix:ix + 2] *= 0.5
    paths[1] = os.path.join(out_dir, "mahalle_floor_1.png")
    _save_image("floor_1", base[::-1], paths[1])
    # sv.2: epoksi — düz gri, hafif bulut, sarı yürüme şeridi kenarları
    base = np.array(_hex("#7C838A"))[None, None, :] * (0.93 + 0.1 * n[..., None] + 0.03 * fine[..., None])
    stripe = ((np.abs(my - 2.75) < 0.06) | (np.abs(my - 5.2) < 0.06)) & (mx > 0.3)
    base[stripe] = np.array(_hex("#E8B330"))
    base[(mx < 0.35)] *= 0.85
    paths[2] = os.path.join(out_dir, "mahalle_floor_2.png")
    _save_image("floor_2", base[::-1], paths[2])
    # sv.3: cilalı dama karo (siyah-beyaz, 0,6 m) + parlak lekesiz yüzey
    tile = 0.6
    checker = ((np.floor(mx / tile) + np.floor(my / tile)) % 2).astype(np.float32)
    white = np.array(_hex("#E9E6DE")); black = np.array(_hex("#26272B"))
    base = white[None, None, :] * checker[..., None] + black[None, None, :] * (1 - checker[..., None])
    base = base * (0.96 + 0.06 * n[..., None])
    grout = (np.abs((mx % tile)) < 0.012) | (np.abs((my % tile)) < 0.012)
    base[grout] = np.array(_hex("#9A968E"))
    paths[3] = os.path.join(out_dir, "mahalle_floor_3.png")
    _save_image("floor_3", base[::-1], paths[3])
    return paths


# --- Kabuk ---------------------------------------------------------------------------------

def brick_wall(b, m, x0, y0, x1, y1, z0, z1, seed=1, normal_in=False):
    """Tuğla yüzlü duvar: gövde (sıva rengi) + iç yüzde sıra sıra hafif çıkıntılı tuğlalar (derz gölgesi)."""
    r = random.Random(seed)
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    yaw = math.degrees(math.atan2(dy, dx))
    course, brick = 0.075, 0.24
    rows = int((z1 - z0) / course)
    for i in range(rows):
        z = z0 + i * course + course / 2
        off = (brick / 2) if i % 2 else 0.0
        t = -off
        while t < length:
            a, bb = max(t, 0.0), min(t + brick - 0.012, length)
            if bb - a > 0.03:
                col = m["brick"] if r.random() > 0.18 else m["brick_dark"]
                mid = (a + bb) / 2
                p = (x0 + math.cos(math.radians(yaw)) * mid, y0 + math.sin(math.radians(yaw)) * mid, z)
                # tek yüz (iç tarafa bakar): 6 yüzlü kutu üç duvarda ~120 bin üçgendi, telefona ağır
                plane(b, p, (bb - a, course - 0.012), col, rot=(90, 0, yaw + (180 if normal_in else 0)))
            t += brick


def shell(col, m):
    """Duvarlar, kesik kenarlar, kepenk, pencereler, kirişler, dışarıdaki kaldırım."""
    b = Builder("Shell", seed=4)
    # Arka duvar (kuzey) ve sol duvar (batı) — gövde
    soft_box(b, (W / 2, D + T / 2, H / 2), (W + 2 * T, T, H), m["mortar"], radius=0.02)
    # sol duvar kepenk açıklığıyla iki parça + üst lento
    soft_box(b, (-T / 2, DOOR_Y[0] / 2, H / 2), (T, DOOR_Y[0], H), m["mortar"], radius=0.02)
    soft_box(b, (-T / 2, (DOOR_Y[1] + D + T) / 2, H / 2), (T, D + T - DOOR_Y[1], H), m["mortar"], radius=0.02)
    soft_box(b, (-T / 2, (DOOR_Y[0] + DOOR_Y[1]) / 2, (DOOR_H + H) / 2), (T, DOOR_Y[1] - DOOR_Y[0], H - DOOR_H), m["mortar"], radius=0.02)
    # Kesik ön (güney) ve sağ (doğu) duvar: diz boyu taban, kesit tuğla görünür
    soft_box(b, (W / 2, -T / 2, 0.28), (W + 2 * T, T, 0.56), m["brick"], radius=0.02)
    soft_box(b, (W + T / 2, D / 2, 0.28), (T, D + 2 * T, 0.56), m["brick"], radius=0.02)
    # Köşe kolonları (kesik duvarın ucunda yüksek kalan ayak: derinlik çerçevesi)
    soft_box(b, (W + T / 2, D + T / 2, H / 2), (T * 1.4, T * 1.4, H), m["mortar"], radius=0.03)
    soft_box(b, (-T / 2, -T / 2, 1.2), (T * 1.4, T * 1.4, 2.4), m["mortar"], radius=0.03)
    # İç yüz tuğla dokusu (sıvası dökülmüş garaj; WALLS sv.2/3 bunun önüne kaplama koyar)
    brick_wall(b, m, 0.0, D - 0.012, W, D - 0.012, 0.0, H, seed=2)
    brick_wall(b, m, 0.012, DOOR_Y[1], 0.012, D, 0.0, H, seed=3)
    brick_wall(b, m, 0.012, 0.0, 0.012, DOOR_Y[0], 0.0, H, seed=5)
    # Arka duvarda yüksek pencereler (akşam göğü)
    for x in (2.5, 7.0, 11.5):
        soft_box(b, (x, D - 0.02, 3.35), (2.4, 0.12, 1.1), m["steel_dark"], radius=0.02)
        plane(b, (x, D - 0.09, 3.35), (2.2, 0.95), m["sky"], rot=(90, 0, 0))
        for k in (-0.55, 0.0, 0.55):
            b.box((x + k, D - 0.1, 3.35), (0.04, 0.03, 0.95), m["steel_dark"])
    # Kepenk (yüzde 85 açık) + kapı kasası
    roll_shutter(b, (-0.05, DOOR_Y[0], 0.0), DOOR_Y[1] - DOOR_Y[0], DOOR_H, 0.86, m, rot=90)
    for y in DOOR_Y:
        soft_box(b, (0.02, y, DOOR_H / 2), (0.14, 0.14, DOOR_H), m["yellow"], radius=0.02)
    # Tavan kirişleri (çatı yok: kesitli maket). Yalnız enine ve arka yarıda: ön yarıdakiler araçların üstünü
    # kesen kalın çizgilere dönüşüyordu (ilk render)
    for y in (6.0, 9.2):
        soft_box(b, (W / 2, y, H + 0.08), (W + 0.4, 0.14, 0.22), m["wood_dark"], radius=0.02)
    # Dışarısı: kepenk önünde kaldırım + yol şeridi (güneşli)
    soft_box(b, (-1.6, D / 2, -0.06), (2.6, D + 6, 0.12), m["concrete"], radius=0.02)
    soft_box(b, (-5.0, D / 2, -0.12), (4.2, D + 6, 0.12), m["black"], radius=0.0)
    soft_box(b, (-2.95, D / 2, 0.02), (0.18, D + 6, 0.16), m["concrete_dark"], radius=0.03)
    o = b.finish(col)
    return o


def static_props(col, m):
    """Her seviyede duran eşyalar: tezgâh köşesi, dolap, lastikler, variller, kedi."""
    b = Builder("Props", seed=8)
    workbench(b, (W - 1.35, D - 0.55, 0.0), m, length=2.4, rot=0)
    tool_cabinet(b, (W - 0.5, D - 2.0, 0.0), m, rot=90, color="red")
    tool_cabinet(b, (W - 0.5, D - 3.05, 0.0), m, rot=90, color="blue", drawers=4, h=0.85)
    tire_stack_g(b, (0.45, D - 0.5, 0.0), 6, m, seed=1)
    tire_stack_g(b, (0.45, D - 1.25, 0.0), 4, m, seed=2)
    tire_stack_g(b, (1.05, D - 0.45, 0.0), 3, m, seed=3)
    barrel(b, (0.45, 6.05, 0.0), m, "blue")
    barrel(b, (0.5, 6.7, 0.0), m, "red")
    sleeping_cat(b, (1.05, D - 0.45, 0.68), m, rot=-30)
    extinguisher(b, (W - 2.8, D - 0.14, 0.9), m)
    wall_clock(b, (6.4, D - 0.05, 3.0), m)
    hose_reel(b, (0.12, 8.0, 2.1), m, rot=90)
    radio(b, (W - 2.1, D - 0.6, 0.955), m)
    broom(b, (W - 0.2, D - 4.0, 0.0), m, lean=-10, rot=90)
    # tezgâh üstü: yağ tenekesi, eldiven, bez
    b.cyl((W - 0.65, D - 0.55, 1.05), 0.07, 0.2, m["green"], segs=10)
    soft_box(b, (W - 1.0, D - 0.7, 0.97), (0.2, 0.12, 0.03), m["yellow"], radius=0.01, rot=(0, 0, 20))
    potted_plant(b, (-0.75, DOOR_Y[1] + 0.55, 0.0), m, seed=4)
    potted_plant(b, (-0.75, DOOR_Y[0] - 0.55, 0.0), m, h=0.7, seed=7)
    return b.finish(col)


# --- Kalemler ------------------------------------------------------------------------------

def walls_level(col, m, level):
    b = Builder("Walls_L%d" % level, seed=20 + level)
    if level == 1:
        # Sıva yamaları, nem lekeleri, eski posterler, takvim
        r = random.Random(3)
        for i in range(5):   # düzensiz kenarlı sıva kalıntıları / nem lekeleri (düz dikdörtgen karton gibi duruyordu)
            x = r.uniform(0.8, W - 0.8)
            z = r.uniform(1.0, 2.6)
            blob(b, (x, D - 0.03, z), (r.uniform(0.25, 0.55), r.uniform(0.18, 0.4)), m["plaster" if i % 3 else "plaster_stain"],
                 seed=i + 1)
        for i in range(3):
            y = r.uniform(5.8, 9.4)
            blob(b, (0.03, y, r.uniform(1.0, 2.4)), (r.uniform(0.3, 0.7), r.uniform(0.25, 0.5)), m["plaster"],
                 rot=(90, 0, 90), seed=20 + i)
        poster(b, (6.4, D - 0.04, 2.2), (0.7, 0.95), m, ["yellow", "red", "black"], seed=1)
        poster(b, (9.2, D - 0.04, 2.0), (0.6, 0.8), m, ["blue", "white", "yellow"], seed=2)
        plane(b, (W - 1.35, D - 0.04, 2.0), (1.6, 0.9), m["wood_light"], rot=(90, 0, 0))   # boş alet panosu yeri
        plane(b, (0.04, 7.8, 1.9), (0.5, 0.7), m["white"], rot=(90, 0, 90))   # takvim
    elif level == 2:
        # Boyalı duvar: alt bant petrol yeşili, üstü krem; alet panosu, raf
        plane(b, (W / 2, D - 0.03, 0.6), (W, 1.2), m["paint_teal"], rot=(90, 0, 0))
        plane(b, (W / 2, D - 0.03, 1.2 + (H - 1.2) / 2), (W, H - 1.2), m["paint_cream"], rot=(90, 0, 0))
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.03, (y0 + y1) / 2, 0.6), (y1 - y0, 1.2), m["paint_teal"], rot=(90, 0, 90))
            plane(b, (0.03, (y0 + y1) / 2, 1.2 + (H - 1.2) / 2), (y1 - y0, H - 1.2), m["paint_cream"], rot=(90, 0, 90))
        pegboard(b, (W - 1.35, D - 0.06, 1.75), m, w=2.2, h=1.1, seed=4)
        shelf_unit(b, (W - 0.35, 5.6, 0.0), m, w=1.4, d=0.45, rot=90, seed=6)
        poster(b, (6.4, D - 0.05, 2.3), (0.8, 1.05), m, ["red", "white", "black"], seed=3)
    else:
        # Ahşap çıta kaplama, çerçeveli posterler, neon tabela, kupa rafı
        plane(b, (W / 2, D - 0.03, H / 2), (W, H), m["wood_dark"], rot=(90, 0, 0))
        for i in range(int(W / 0.12)):
            b.box((0.06 + i * 0.12, D - 0.05, H / 2), (0.08, 0.025, H), m["wood"])
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.03, (y0 + y1) / 2, H / 2), (y1 - y0, H), m["wood_dark"], rot=(90, 0, 90))
        pegboard(b, (W - 1.35, D - 0.08, 1.8), m, w=2.2, h=1.1, seed=5)
        shelf_unit(b, (W - 0.35, 5.6, 0.0), m, w=1.4, d=0.45, rot=90, seed=6)
        for i, x in enumerate((3.6, 6.4, 9.2)):
            soft_box(b, (x, D - 0.07, 2.45), (1.0, 0.04, 1.3), m["black"], radius=0.01)
            poster(b, (x, D - 0.1, 2.45), (0.86, 1.16), m, [["blue", "white", "yellow"], ["red", "white", "black"],
                                                              ["yellow", "black", "red"]][i], seed=10 + i)
        # neon tabela: yazısız çizgi-ok + çerçeve (dil bağımsız)
        b.tube([(0.08, 6.6, 3.2), (0.08, 9.2, 3.2), (0.08, 9.2, 3.9), (0.08, 6.6, 3.9), (0.08, 6.6, 3.2)], 0.025, m["neon_pink"])
        b.tube([(0.08, 7.0, 3.55), (0.08, 8.6, 3.55), (0.08, 8.3, 3.75)], 0.025, m["neon_cyan"])
        b.tube([(0.08, 8.6, 3.55), (0.08, 8.3, 3.35)], 0.025, m["neon_cyan"])
        # kupa rafı: neon tabelanın altında, sol duvarda
        soft_box(b, (0.2, 7.9, 2.6), (0.3, 2.4, 0.04), m["wood"], radius=0.01)
        for k in range(6):
            y = 6.95 + k * 0.38
            b.cyl((0.2, y, 2.72), 0.05, 0.16, m["yellow"], segs=10, r2=0.08)
            b.cyl((0.2, y, 2.65), 0.035, 0.04, m["steel_dark"], segs=8)
    return b.finish(col)


## Armatürler YALNIZ kirişlere asılır (BEAM_Y): çatısız makette ön yarıda havada yüzen lamba / panel tuhaf duruyordu.
BEAM_Y = (6.0, 9.2)
BULBS = [(2.8, 6.0), (7.0, 6.0), (11.2, 6.0), (5.0, 9.2), (12.3, 9.2)]
TUBES = [(3.5, 6.0), (7.0, 6.0), (10.5, 6.0), (3.5, 9.2), (7.0, 9.2), (10.5, 9.2)]


def lights_level(col, m, level):
    b = Builder("Lights_L%d" % level, seed=40 + level)
    if level == 1:
        for x, y in BULBS:
            hanging_bulb(b, (x, y, H), m, drop=1.15)
    elif level == 2:
        for x, y in TUBES:
            fluorescent(b, (x, y, H - 0.42), m, length=1.6)
    else:
        # kirişlerin altında LED şerit + öndeki kirişte her park yerine spot
        for y in BEAM_Y:
            plane(b, (W / 2, y, H - 0.04), (W - 0.6, 0.06), m["led"], rot=(180, 0, 0))
        for (x, y, _r) in SLOTS:
            spot_lamp(b, (x + (0.0 if y > 5 else 0.6), BEAM_Y[0] - 0.12, H - 0.12), (x, y, 0.5), m)
    return b.finish(col)


def lift_level(col, m, level):
    b = Builder("Lift_L%d" % level, seed=60 + level)
    x, y = LIFT_AT
    if level == 1:
        floor_jack(b, (x - 0.6, y - 0.4, 0.0), m, rot=20)
        for dx, dy in ((0.8, 0.9), (0.8, -0.9), (-0.9, 1.0)):
            jack_stand(b, (x + dx, y + dy, 0.0), m)
        soft_box(b, (x + 0.3, y + 0.1, 0.06), (1.0, 0.45, 0.06), m["red"], radius=0.02, rot=(0, 0, 15))   # kızak
        plane(b, (x, y, 0.004), (4.2, 3.4), m["concrete_dark"])
    elif level == 2:
        plane(b, (x, y, 0.004), (4.4, 3.8), m["yellow"])
        plane(b, (x, y, 0.005), (4.1, 3.5), m["concrete_dark"])
        # köprüsüz, alçak, köşeye yakın: köprülü model kırmızı Golf'ün önüne kapı gibi düşüyordu
        two_post_lift(b, (x + 0.35, y - 0.35, 0.0), m, rot=90.0, width=3.0, height=2.3, bridge=False)
    else:
        plane(b, (x, y, 0.004), (4.6, 3.9), m["black"])
        four_post_lift(b, (x, y, 0.0), m, rot=90.0, length=3.4, width=2.4, lift=0.75)
    return b.finish(col)


def clutter_slot(b, m, slot, kind):
    x, y, rot = slot
    if kind == 0:
        old_sofa(b, (x - 0.6, y + 0.15, 0.0), m, rot=0)
        cardboard_box(b, (x + 1.25, y - 0.2, 0.0), (0.6, 0.5, 0.45), m, rot=12)
        cardboard_box(b, (x + 1.3, y - 0.15, 0.45), (0.45, 0.4, 0.35), m, rot=-8)
        tire(b, (x + 1.9, y + 0.5, 0.11), m=m)
    else:
        for i, (dx, dy, s) in enumerate(((-1.4, 0.2, 0.7), (-0.6, -0.3, 0.55), (0.3, 0.25, 0.8), (1.2, -0.1, 0.6))):
            cardboard_box(b, (x + dx, y + dy, 0.0), (s, s * 0.8, s * 0.7), m, rot=i * 17)
        # palet üstünde eski motor bloğu
        soft_box(b, (x + 1.8, y + 0.2, 0.07), (1.0, 0.8, 0.12), m["wood_light"], radius=0.01)
        soft_box(b, (x + 1.8, y + 0.2, 0.42), (0.7, 0.5, 0.5), m["steel_dark"], radius=0.05)
        b.cyl((x + 1.8, y + 0.2, 0.75), 0.12, 0.2, m["red_dark"], segs=10)


def park_level(col, m, level):
    b = Builder("Park_L%d" % level, seed=80 + level)
    open_slots = 4 + (level - 1)
    for i, slot in enumerate(SLOTS):
        if i < open_slots:
            slot_lines(b, m, slot, "white" if level < 3 else "yellow")
        else:
            clutter_slot(b, m, slot, i - 4)
    return b.finish(col)


# --- Sahne ---------------------------------------------------------------------------------

def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("Mahalle")
    m = gmats()
    static = new_col("Static", root)
    shell(static, m)
    static_props(static, m)
    paths = floor_textures(tex_dir)
    groups = {}
    for level in (1, 2, 3):
        groups[("Floor", level)] = new_col("Floor_L%d" % level, root)
        floor_object(groups[("Floor", level)], "Floor_L%d" % level, paths[level], (W, D))
        groups[("Walls", level)] = new_col("Walls_L%d" % level, root)
        walls_level(groups[("Walls", level)], m, level)
        groups[("Lights", level)] = new_col("Lights_L%d" % level, root)
        lights_level(groups[("Lights", level)], m, level)
        groups[("Lift", level)] = new_col("Lift_L%d" % level, root)
        lift_level(groups[("Lift", level)], m, level)
        groups[("Park", level)] = new_col("Park_L%d" % level, root)
        park_level(groups[("Park", level)], m, level)
    beams = new_col("Beams", root)
    sun_dir = (math.cos(math.radians(16)), 0.18, -math.sin(math.radians(16)))
    y0, y1 = DOOR_Y[0] + 0.15, DOOR_Y[1] - 0.15
    light_beam(beams, "Beam_Door", [(0.0, y0, 0.2), (0.0, y1, 0.2), (0.0, y1, DOOR_H - 0.5), (0.0, y0, DOOR_H - 0.5)],
               sun_dir, 9.0, (1.0, 0.62, 0.3), strength=0.07)
    for x in (2.5, 7.0, 11.5):
        light_beam(beams, "Beam_Win_%d" % int(x), [(x - 1.0, D - 0.1, 2.9), (x + 1.0, D - 0.1, 2.9), (x + 1.0, D - 0.1, 3.8),
                   (x - 1.0, D - 0.1, 3.8)], (0.15, -0.55, -0.8), 4.2, (1.0, 0.78, 0.5), strength=0.035)
    slots = new_col("Slots", root)
    markers(slots, SLOTS)
    return root, groups


# --- Önizleme (Cycles) ---------------------------------------------------------------------

PREVIEW_CARS = ["tofas_sahin", "bmw_e46", "lambo_huracan", "vw_golf_7", "porsche_gt3", "renault_toros"]


def preview_lights(level):
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.03, 0.022, 0.018, 1.0)   # sıcak, koyu: maket karanlıkta yüzer
    bg.inputs["Strength"].default_value = 0.6
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 7.5
    sun.color = (1.0, 0.72, 0.45)
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("Sun", sun)
    scn.collection.objects.link(so)
    so.location = (0, 0, 0)
    aim(so, (math.cos(math.radians(16)), 0.18, -math.sin(math.radians(16))))   # batıdan alçak akşam güneşi kepenkten girer
    sky = bpy.data.lights.new("SkyFill", 'AREA')
    sky.energy = 120
    sky.size = 6
    sky.color = (1.0, 0.82, 0.62)
    ko = bpy.data.objects.new("SkyFill", sky)
    scn.collection.objects.link(ko)
    ko.location = (W / 2, D - 0.4, 3.35)
    ko.rotation_euler = (math.radians(-90), 0, 0)
    if level == 1:
        for x, y in BULBS:
            l = bpy.data.lights.new("Bulb", 'POINT')
            l.energy = 140
            l.color = (1.0, 0.75, 0.45)
            l.shadow_soft_size = 0.08
            lo = bpy.data.objects.new("Bulb", l)
            scn.collection.objects.link(lo)
            lo.location = (x, y, H - 1.27)
    elif level == 2:
        for x, y in TUBES:
            l = bpy.data.lights.new("Tube", 'AREA')
            l.shape = 'RECTANGLE'
            l.size, l.size_y = 1.6, 0.2
            l.energy = 260
            l.color = (0.92, 0.96, 1.0)
            lo = bpy.data.objects.new("Tube", l)
            scn.collection.objects.link(lo)
            lo.location = (x, y, H - 0.47)
    else:
        for y in BEAM_Y:
            l = bpy.data.lights.new("Strip", 'AREA')
            l.shape = 'RECTANGLE'
            l.size, l.size_y = W - 0.6, 0.1
            l.energy = 900
            lo = bpy.data.objects.new("Strip", l)
            scn.collection.objects.link(lo)
            lo.location = (W / 2, y, H - 0.08)
        for (x, y, _r) in SLOTS:
            l = bpy.data.lights.new("Spot", 'SPOT')
            l.energy = 900
            l.spot_size = math.radians(48)
            l.spot_blend = 0.6
            l.shadow_soft_size = 0.15
            lo = bpy.data.objects.new("Spot", l)
            scn.collection.objects.link(lo)
            lo.location = (x + (0.0 if y > 5 else 0.6), BEAM_Y[0] - 0.25, H - 0.2)
            aim(lo, (x, y, 0.5))


def preview_camera(width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 32
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    target = (W * 0.5 + 0.4, D * 0.55, 0.4)
    co.location = (W * 0.5 + 7.5, -8.0, 9.0)
    aim(co, target)
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        level = int(argv[1]) if len(argv) > 1 else 1
        out = argv[2] if len(argv) > 2 else "/tmp/mahalle.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 640
        samples = int(argv[5]) if len(argv) > 5 else 48
        tex_dir = os.path.join(os.path.dirname(out), "tex")
        root, groups = build(tex_dir)
        show_levels(groups, {"Floor": level, "Walls": level, "Lights": level, "Lift": level, "Park": level})
        place_cars(SLOTS, PREVIEW_CARS[:4 + (level - 1)])
        preview_lights(level)
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
