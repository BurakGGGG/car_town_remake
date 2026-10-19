"""UÇAK HANGARI — GARAJLARIM'ın taç garajı (docs/GARAJLAR_TASARIM.md §7): GÜN BATIMI dev kayar kapıdan içeri uzanır,
projektörler; kemerli çatı makaslarına asılı pervaneli klasik uçak (müze havası). 34 × 22 m, 11 m.
Kemerler yalnız arka yarıda (kamera önü temiz); uçak yüksekte: zeminde arka duvarın ötesine izdüşer, araçları örtmez.

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan):
  arka sıra PARK 0-9   orta sıra PARK 10-19   ön sıra PARK 20-29
  taban 18 (arka 10 + orta 8); PARK YERİ her adımda +3 → 21, 24, 27, 30 (5 seviye)
  sol duvar  dev kayar kapı (apron, sarı taksi çizgisi)   ön sağ  LİFT alanı
Kalemler: Floor / Walls / Lights / Lift _L1..3, Park_L1..5; ortak: Static. Slot_0..29.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/hangar.py -- preview <seviye 1-3> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 34.0, 22.0, 11.0
T = 0.4
WALL_H = 7.0                      # yan duvar yüksekliği (üstünde kemer başlar)
DOOR_Y = (4.0, 17.0)              # sol duvardaki kayar kapı açıklığı
DOOR_H = 8.5
ARCH_Y = (13.0, 17.5, 21.6)       # kemerli makaslar (arka yarı)
SLOTS = [(2.6 + i * 2.95, 18.8, 0.0) for i in range(10)] + [(2.6 + i * 2.95, 12.4, 0.0) for i in range(10)] + \
        [(2.6 + i * 2.95, 4.2, 0.0) for i in range(10)]
LIFT_AT = (31.6, 4.6)
PLANE_AT = (W * 0.6, 15.5, 7.6)
PARK_LEVELS = 5
SUN_DIR = (0.95, -0.12, -0.26)    # batıdan alçak gün batımı güneşi: kapıdan içeri


def hmats():
    return {
        "hangar_sheet": k_mat("h_sheet", "#7F8A7E", rough=0.85, metal=0.3),
        "hangar_rust": k_mat("h_rust", "#6E5442", rough=0.9, metal=0.2),
        "hangar_paint": k_mat("h_paint", "#3E5A4A", rough=0.8),
        "hangar_cream": k_mat("h_cream", "#E2D7BD", rough=0.8),
        "plane_body": k_mat("h_plane_body", "#C9C2B0", rough=0.5, metal=0.4),
        "plane_red": k_mat("h_plane_red", "#B42B26", rough=0.5),
        "prop": k_mat("h_prop", "#2B2622", rough=0.6),
        "tarmac": k_mat("h_tarmac", "#3E3F42", rough=0.95),
        "sunset_sky": k_mat("h_sky", "#FFC48A", rough=0.9, emit="#FFB070", strength=3.0),
        "flood": k_mat("h_flood", "#FFF4DC", rough=0.5, emit="#FFF0D0", strength=10.0),
        "chevron_a": k_mat("h_chev_a", "#E0A325", rough=0.75),
        "chevron_b": k_mat("h_chev_b", "#20262C", rough=0.75),
    }


def floor_textures(out_dir, ppm=56):
    """Sv.1 eski beton + soluk sarı taksi çizgisi + yağ, sv.2 gri epoksi + taze sarı çizgi, sv.3 beyaz epoksi + amblem."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    os.makedirs(out_dir, exist_ok=True)
    n = _fbm((h, w), 90, 601)
    fine = _fbm((h, w), 6, 611, 3)
    rng = np.random.default_rng(42)
    paths = {}
    taxi = np.abs(my - sum(DOOR_Y) / 2 + 2.0) < 0.12
    base = np.array(_hex("#8A867E"))[None, None, :] * (0.8 + 0.3 * n[..., None] + 0.1 * fine[..., None])
    for _ in range(40):
        sx, sy, _r = SLOTS[rng.integers(0, len(SLOTS))]
        cx, cy = sx + rng.normal(0, 0.6), sy + rng.normal(-0.4, 1.0)
        r = rng.uniform(0.2, 0.8)
        d = np.sqrt((mx - cx) ** 2 + (my - cy) ** 2)
        base *= (1 - (np.clip(1 - d / r, 0, 1) ** 1.5 * rng.uniform(0.2, 0.5))[..., None] * 0.7)
    joints = (np.abs(mx % 6.0) < 0.03) | (np.abs(my % 6.0) < 0.03)
    base[joints] *= 0.65
    fade = np.clip(_fbm((h, w), 12, 621, 2) * 1.6 - 0.3, 0, 1)
    base[taxi] = base[taxi] * (1 - fade[taxi][:, None] * 0.6) + np.array(_hex("#D9A62E")) * fade[taxi][:, None] * 0.6
    paths[1] = os.path.join(out_dir, "hangar_floor_1.png")
    _save_image("h_floor_1", base[::-1], paths[1])
    base = np.array(_hex("#767C80"))[None, None, :] * (0.94 + 0.08 * n[..., None] + 0.02 * fine[..., None])
    base[taxi] = np.array(_hex("#EDB430"))
    paths[2] = os.path.join(out_dir, "hangar_floor_2.png")
    _save_image("h_floor_2", base[::-1], paths[2])
    base = np.array(_hex("#E6E4DE"))[None, None, :] * (0.96 + 0.05 * n[..., None])
    cx, cy = W * 0.5, sum(DOOR_Y) / 2 - 2.0
    d = np.sqrt((mx - cx) ** 2 + ((my - cy) * 1.0) ** 2)
    ring = (np.abs(d - 2.6) < 0.12) | (np.abs(d - 2.1) < 0.05)
    star = (d < 1.8) & (np.abs(np.sin(np.arctan2(my - cy, mx - cx) * 2.5)) * d < 0.5)
    base[ring] = np.array(_hex("#2A3A55"))
    base[star] = np.array(_hex("#C53A2E"))
    base[taxi & (d > 2.8)] = np.array(_hex("#2A3A55"))
    paths[3] = os.path.join(out_dir, "hangar_floor_3.png")
    _save_image("h_floor_3", base[::-1], paths[3])
    return paths


def arch_truss(b, y, m, rise=4.0):
    """Kemerli çatı makası: iki kemer + aralarında kafes (yalnız arka yarı)."""
    def pt(t, r_off):
        x = t * W
        z = WALL_H + rise * math.sin(math.pi * t) + r_off
        return (x, y, z)
    for r_off in (0.0, 0.8):
        b.tube([pt(i / 24, r_off) for i in range(25)], 0.09, m["beam_grey"], segs=6)
    for i in range(24):
        b.tube([pt(i / 24, 0.0), pt((i + 1) / 24, 0.8)], 0.05, m["beam_grey"], segs=5)


def propeller_plane(b, center, m, yaw=0.0, scale=1.0):
    """Pervaneli klasik uçak (tek kanat, kuyruk tekerli): gövde, kanatlar, kuyruk, pervane, tekerler."""
    x, y, z = center
    s = scale
    def p(dx, dy, dz):
        return b._xf((dx * s, dy * s, dz * s), (x, y, z), (0, 0, yaw))
    b.cyl(p(0, 0, 0), 0.6 * s, 6.5 * s, m["plane_body"], axis='Y', segs=14, rot=(0, 0, yaw), r2=0.25 * s)
    b.ball(p(0, -3.3, 0), 0.6 * s, m["plane_red"], segs=12, rings=7, rot=(0, 0, yaw))
    soft_box(b, p(0, -0.8, -0.15), (10.5 * s, 1.6 * s, 0.18 * s), m["plane_body"], radius=0.08 * s, rot=(0, 0, yaw))
    for sx in (-1, 1):
        plane(b, p(sx * 4.6, -0.8, -0.05), (0.9 * s, 1.5 * s), m["plane_red"], rot=(0, 0, yaw))
    soft_box(b, p(0, 3.0, 0.15), (3.4 * s, 0.9 * s, 0.1 * s), m["plane_body"], radius=0.05 * s, rot=(0, 0, yaw))
    soft_box(b, p(0, 3.1, 0.75), (0.1 * s, 1.0 * s, 1.3 * s), m["plane_red"], radius=0.05 * s, rot=(0, 0, yaw))
    soft_box(b, p(0, -0.6, 0.55), (0.7 * s, 1.2 * s, 0.5 * s), m["glass"], radius=0.2 * s, rot=(0, 0, yaw))
    for k in range(2):
        a = 90 * k + 20
        soft_box(b, p(0, -3.95, 0), (0.18 * s, 0.06 * s, 2.6 * s), m["prop"], radius=0.03 * s, rot=(0, a, yaw))
    for sx in (-1, 1):
        b.tube([p(sx * 1.0, -1.3, -0.2), p(sx * 1.2, -1.4, -1.4)], 0.05 * s, m["steel_dark"])
        b.cyl(p(sx * 1.2, -1.4, -1.5), 0.3 * s, 0.16 * s, m["rubber"], axis='X', segs=12, rot=(0, 0, yaw))
    for k in (-2.0, 2.0):   # asma halatları
        b.cyl(p(k, -0.8, 1.6), 0.015, 3.2 * s, m["steel"], segs=4)


def floodlight_tower(b, base, m, aim_deg=0.0):
    x, y, z = base
    for a in (0, 120, 240):
        ar = math.radians(a)
        b.tube([(x + math.cos(ar) * 0.9, y + math.sin(ar) * 0.9, z), (x, y, z + 4.8)], 0.05, m["steel_dark"], segs=5)
    b.cyl((x, y, z + 5.2), 0.06, 0.8, m["steel_dark"], segs=6)
    for k in (-0.45, 0.45):
        hx, hy = x + math.cos(math.radians(aim_deg + 90)) * k, y + math.sin(math.radians(aim_deg + 90)) * k
        soft_box(b, (hx, hy, z + 5.6), (0.55, 0.3, 0.45), m["black"], radius=0.05, rot=(0, 25, aim_deg))
        plane(b, b._xf((0.16, 0, 0), (hx, hy, z + 5.6), (0, 25, aim_deg)), (0.4, 0.35), m["flood"], rot=(0, 115, aim_deg))


def tow_tractor(b, base, m, rot=0.0):
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.55), (1.6, 3.0, 0.6), m["yellow"], radius=0.12, rot=(0, 0, rot))
    soft_box(b, p(0, 0.6, 1.1), (0.5, 0.5, 0.3), m["black"], radius=0.06, rot=(0, 0, rot))
    b.cyl(p(0, -0.2, 1.25), 0.2, 0.06, m["black"], axis='X', segs=10, rot=(30, 0, rot))
    for sx in (-0.85, 0.85):
        for sy in (-1.0, 1.0):
            tire(b, p(sx, sy, 0.38), rot=(0, 90, rot), r=0.38, w=0.3, m=m)
    b.tube([p(0, 1.5, 0.5), p(0, 2.4, 0.35)], 0.06, m["steel_dark"])


def prop_crate(b, base, m, rot=0.0):
    x, y, z = base
    crate(b, (x, y, z), (2.6, 0.8, 0.5), m, rot=rot)
    for k in range(3):
        soft_box(b, b._xf((-0.8 + k * 0.8, 0, 0), (x, y, z + 0.62), (0, 0, rot)), (0.7, 0.12, 0.04), m["prop"], radius=0.02,
                 rot=(0, 0, rot + 20))


def dyno(b, center, m, rot=0.0):
    """Güç ölçer (LİFT sv.3): zemindeki iki makara çifti, rampa, egzoz fanı, ekran."""
    x, y, z = center
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.03), (2.6, 5.2, 0.06), m["steel_dark"], radius=0.02, rot=(0, 0, rot))
    for sy in (0.9, 1.5):
        for sx in (-0.75, 0.75):
            b.cyl(p(sx, sy, 0.06), 0.16, 0.8, m["chrome"], axis='X', segs=12, rot=(0, 0, rot))
    plane(b, p(0, 0, 0.065), (2.4, 0.06), m["yellow"], rot=(0, 0, rot))
    soft_box(b, p(0, -3.4, 0.8), (1.2, 0.6, 1.4), m["black"], radius=0.08, rot=(0, 0, rot))   # fan
    b.cyl(p(0, -3.1, 0.85), 0.5, 0.05, m["steel"], axis='Y', segs=16, rot=(0, 0, rot))
    soft_box(b, p(1.8, 2.6, 1.3), (0.9, 0.12, 0.6), m["black"], radius=0.02, rot=(0, 0, rot))   # ekran
    plane(b, p(1.8, 2.53, 1.3), (0.8, 0.5), m["led"], rot=(90, 0, rot))
    b.cyl(p(1.8, 2.6, 0.5), 0.05, 1.0, m["steel_dark"], segs=6)


def shell(col, m):
    b = Builder("Shell", seed=701)
    soft_box(b, (W / 2, D + T / 2, WALL_H / 2), (W + 2 * T, T, WALL_H), m["hangar_sheet"], radius=0.03)
    soft_box(b, (-T / 2, DOOR_Y[0] / 2, WALL_H / 2), (T, DOOR_Y[0], WALL_H), m["hangar_sheet"], radius=0.03)
    soft_box(b, (-T / 2, (DOOR_Y[1] + D + T) / 2, WALL_H / 2), (T, D + T - DOOR_Y[1], WALL_H), m["hangar_sheet"], radius=0.03)
    soft_box(b, (W / 2, -T / 2, 0.45), (W + 2 * T, T, 0.9), m["hangar_sheet"], radius=0.03)
    soft_box(b, (W + T / 2, D / 2, 0.45), (T, D + 2 * T, 0.9), m["hangar_sheet"], radius=0.03)
    # arka duvar: kemer biçimli üst (gable) + oluklu iç yüz
    rise = 4.0
    pts = [(t / 20 * W, D - 0.02, WALL_H + rise * math.sin(math.pi * t / 20)) for t in range(21)]
    for (x0, _y0, z0), (x1, _y1, z1) in zip(pts[:-1], pts[1:]):
        b._add([(x0, D, WALL_H), (x1, D, WALL_H), (x1, D, z1), (x0, D, z0)], [(0, 1, 2, 3)], m["hangar_sheet"])
    b.corrugated((0.0, D - 0.05, 0.0), W, WALL_H, m["hangar_sheet"], period=0.3, depth=0.05, along='X')
    b.corrugated((0.05, DOOR_Y[1], 0.0), D - DOOR_Y[1], WALL_H, m["hangar_sheet"], period=0.3, depth=0.05, rot=(0, 0, 90))
    b.corrugated((0.05, 0.0, 0.0), DOOR_Y[0], WALL_H, m["hangar_sheet"], period=0.3, depth=0.05, rot=(0, 0, 90))
    # arka duvarda yüksek pencere şeridi
    for i in range(8):
        x = 2.2 + i * 4.2
        plane(b, (x, D - 0.12, WALL_H + 1.2), (3.2, 0.9), m["window_day"], rot=(90, 0, 0))
    # kemerler
    for y in ARCH_Y:
        arch_truss(b, y, m, rise=rise)
    for x in (0.3, W - 0.3):
        for y in ARCH_Y:
            soft_box(b, (x, y, WALL_H / 2), (0.5, 0.5, WALL_H), m["beam_grey"], radius=0.03)
    # kayar kapı: iki panel açılıp duvar önüne yığılmış + üst ray
    soft_box(b, (-0.3, sum(DOOR_Y) / 2, DOOR_H + 0.3), (0.5, DOOR_Y[1] - DOOR_Y[0] + 2.0, 0.6), m["beam_grey"], radius=0.03)
    for k, y in enumerate((DOOR_Y[0] - 1.6, DOOR_Y[1] + 1.6)):
        b.corrugated((-0.75 - k * 0.25, y - 1.5, 0.0), 3.0, DOOR_H, m["hangar_paint"], period=0.3, depth=0.05, rot=(0, 0, 90))
    # dışarısı: apron + taksi çizgisi + gün batımı göğü
    soft_box(b, (-10.0, D / 2, -0.06), (20.0, D + 16, 0.12), m["tarmac"], radius=0.0)
    plane(b, (-10.0, sum(DOOR_Y) / 2 - 2.0, 0.01), (20.0, 0.25), m["yellow"])
    plane(b, (-21.0, D / 2, 7.0), (D + 30, 20.0), m["sunset_sky"], rot=(90, 0, 90))
    return b.finish(col)


def static_props(col, m):
    b = Builder("Props", seed=703)
    # 9,3 m'de kadrajın tepesinde kesiliyordu; 7,6 m / y=15,5: zeminde arka duvarın ötesine izdüşer (araçları örtmez)
    propeller_plane(b, PLANE_AT, m, yaw=-20.0, scale=1.0)
    floodlight_tower(b, (-3.5, DOOR_Y[0] - 2.5, 0.0), m, aim_deg=40)
    floodlight_tower(b, (W - 1.2, D - 1.2, 0.0), m, aim_deg=215)
    tow_tractor(b, (-4.5, 13.5, 0.0), m, rot=-70)
    prop_crate(b, (1.6, D - 0.8, 0.0), m)
    for i, y in enumerate((DOOR_Y[1] + 0.8, DOOR_Y[1] + 1.6, DOOR_Y[1] + 2.4)):
        barrel(b, (0.6, y, 0.0), m, ["blue", "red", "green"][i])
    tool_cabinet(b, (W - 0.6, D - 3.2, 0.0), m, rot=90, color="red")
    tool_cabinet(b, (W - 0.6, D - 4.3, 0.0), m, rot=90, color="blue")
    return b.finish(col)


def walls_level(col, m, level):
    b = Builder("Walls_L%d" % level, seed=710 + level)
    r = random.Random(level * 5)
    if level == 1:
        for i in range(8):
            blob(b, (r.uniform(0.8, W - 0.8), D - 0.12, r.uniform(1.5, WALL_H - 1.0)), (r.uniform(0.3, 0.8), r.uniform(0.25, 0.6)),
                 m["hangar_rust"], seed=i + 80)
    elif level == 2:
        plane(b, (W / 2, D - 0.12, WALL_H / 2), (W, WALL_H), m["hangar_paint"], rot=(90, 0, 0))
        plane(b, (W / 2, D - 0.13, 1.0), (W, 0.4), m["hangar_cream"], rot=(90, 0, 0))
        for k, x in enumerate((7.0, 27.0)):   # yazısız kokart (iç içe daireler)
            for rr, c in ((1.3, "hangar_cream"), (0.9, "blue"), (0.45, "red")):
                b.cyl((x, D - 0.14 - rr * 0.001, 4.2), rr, 0.02, m[c], axis='Y', segs=24)
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.12, (y0 + y1) / 2, WALL_H / 2), (y1 - y0, WALL_H), m["hangar_paint"], rot=(90, 0, 90))
    else:
        plane(b, (W / 2, D - 0.12, WALL_H / 2), (W, WALL_H), m["hangar_cream"], rot=(90, 0, 0))
        for i in range(12):   # büyük şerit (chevron) bandı
            x = 1.4 + i * 2.8
            v = [(x, D - 0.14, 1.2), (x + 1.4, D - 0.14, 2.6), (x + 2.2, D - 0.14, 2.6), (x + 0.8, D - 0.14, 1.2)]
            b._add(v, [(0, 1, 2, 3)], m["chevron_a"] if i % 2 == 0 else m["chevron_b"])
        for k, x in enumerate((8.0, 17.0, 26.0)):
            soft_box(b, (x, D - 0.16, 4.6), (3.0, 0.05, 2.0), m["black"], radius=0.02)
            poster(b, (x, D - 0.2, 4.6), (2.7, 1.7), m, [["blue", "white", "red"], ["red", "hangar_cream", "black"],
                                                         ["black", "yellow", "red"]][k], seed=90 + k)
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.12, (y0 + y1) / 2, WALL_H / 2), (y1 - y0, WALL_H), m["hangar_cream"], rot=(90, 0, 90))
    return b.finish(col)


LAMPS = [(x, y) for y in ARCH_Y[:2] for x in (5.0, 12.0, 19.0, 26.0, 31.0)]


def lights_level(col, m, level):
    b = Builder("Lights_L%d" % level, seed=730 + level)
    kind = {1: "sodium", 2: "tube", 3: "led"}[level]
    lamps = LAMPS if level > 1 else LAMPS[::2]
    for x, y in lamps:
        top = WALL_H + 4.0 * math.sin(math.pi * x / W)
        high_bay(b, (x, y, top), m, kind, drop=1.4)
    if level == 3:   # uçağa aşağıdan vuran spotlar
        for dx in (-3.0, 3.0):
            spot_lamp(b, (PLANE_AT[0] + dx, D - 0.6, 2.0), PLANE_AT, m)
    return b.finish(col)


def lift_level(col, m, level):
    b = Builder("Lift_L%d" % level, seed=750 + level)
    x, y = LIFT_AT
    if level == 1:
        tool_cabinet(b, (x - 1.0, y + 1.6, 0.0), m, rot=0, color="red")
        floor_jack(b, (x - 0.4, y - 0.6, 0.0), m, rot=20)
        tire_stack_g(b, (x + 1.2, y - 1.6, 0.0), 5, m, seed=71)
        plane(b, (x, y, 0.004), (4.4, 6.0), m["concrete_dark"])
    elif level == 2:
        plane(b, (x, y, 0.004), (4.6, 6.2), m["concrete_dark"])
        two_post_lift(b, (x, y, 0.0), m, rot=90.0, width=3.0, height=2.4, bridge=False)
    else:
        plane(b, (x, y, 0.004), (4.8, 6.4), m["black"])
        dyno(b, (x, y, 0.0), m)
    return b.finish(col)


def clutter_slot(b, m, slot, kind):
    x, y, _r = slot
    r = random.Random(kind * 13 + 5)
    k = kind % 3
    if k == 0:
        prop_crate(b, (x, y + 1.0, 0.0), m, rot=90)
        crate(b, (x, y - 1.2, 0.0), (1.2, 1.2, 1.0), m)
    elif k == 1:
        crate(b, (x, y, 0.0), (1.9, 3.6, 1.5), m, tarp=True)
    else:
        engine_stand(b, (x, y - 0.8, 0.0), m)
        pallet(b, (x, y + 1.2, 0.0), m)
        barrel(b, (x + 0.3, y + 1.2, 0.15), m, "green")


def park_level(col, m, level):
    b = Builder("Park_L%d" % level, seed=770 + level)
    open_slots = 18 + 3 * (level - 1)
    for i, slot in enumerate(SLOTS):
        if i < open_slots:
            slot_lines(b, m, slot, "white" if level < 4 else "yellow", ln=5.2, wd=2.85)
        else:
            clutter_slot(b, m, slot, i)
    return b.finish(col)


def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("Hangar")
    m = gmats()
    m.update(smats())
    m.update(hmats())
    static = new_col("Static", root)
    shell(static, m)
    static_props(static, m)
    paths = floor_textures(tex_dir)
    groups = {}
    for level in (1, 2, 3):
        groups[("Floor", level)] = new_col("Floor_L%d" % level, root)
        floor_object(groups[("Floor", level)], "Floor_L%d" % level, paths[level], (W, D))
        for item, fn in (("Walls", walls_level), ("Lights", lights_level), ("Lift", lift_level)):
            groups[(item, level)] = new_col("%s_L%d" % (item, level), root)
            fn(groups[(item, level)], m, level)
    for level in range(1, PARK_LEVELS + 1):
        groups[("Park", level)] = new_col("Park_L%d" % level, root)
        park_level(groups[("Park", level)], m, level)
    beams = new_col("Beams", root)
    light_beam(beams, "Beam_Door", [(0.0, DOOR_Y[0] + 0.5, 0.3), (0.0, DOOR_Y[1] - 0.5, 0.3), (0.0, DOOR_Y[1] - 0.5, DOOR_H - 0.5),
               (0.0, DOOR_Y[0] + 0.5, DOOR_H - 0.5)], SUN_DIR, 22.0, (1.0, 0.65, 0.35), strength=0.05)
    for i in range(8):
        x = 2.2 + i * 4.2
        light_beam(beams, "Beam_Win_%d" % i, [(x - 1.5, D - 0.15, WALL_H + 0.8), (x + 1.5, D - 0.15, WALL_H + 0.8),
                   (x + 1.5, D - 0.15, WALL_H + 1.6), (x - 1.5, D - 0.15, WALL_H + 1.6)], (0.4, -0.5, -0.75), 9.0,
                   (1.0, 0.8, 0.55), strength=0.02)
    slots = new_col("Slots", root)
    markers(slots, SLOTS)
    return root, groups


PREVIEW_CARS = ["lambo_huracan", "porsche_gt3", "bmw_f30", "mercedes_g", "porsche_taycan", "audi_a6", "ferrari_laferrari",
                "bugatti_chiron", "vw_golf_7", "cupra_formentor", "bmw_e46", "renault_megane_4", "toyota_corolla", "skoda_superb",
                "vw_passat_b8", "chery_tiggo_8", "hyundai_getz", "tofas_sahin", "renault_toros", "vw_passat_b55",
                "bugatti_veyron", "ford_transit", "mercedes_sprinter", "porsche_gt3", "lambo_huracan", "bmw_f30", "audi_a6",
                "mercedes_g", "vw_golf_7", "tofas_sahin"]


def preview_lights(level):
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.05, 0.035, 0.03, 1.0)
    bg.inputs["Strength"].default_value = 0.7
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 7.0
    sun.color = (1.0, 0.66, 0.38)
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("Sun", sun)
    scn.collection.objects.link(so)
    aim(so, SUN_DIR)
    sky = bpy.data.lights.new("DoorSky", 'AREA')
    sky.shape = 'RECTANGLE'
    sky.size, sky.size_y = DOOR_Y[1] - DOOR_Y[0], DOOR_H
    sky.energy = 2600
    sky.color = (1.0, 0.75, 0.55)
    do = bpy.data.objects.new("DoorSky", sky)
    scn.collection.objects.link(do)
    do.location = (-1.5, sum(DOOR_Y) / 2, DOOR_H / 2)
    aim(do, (8.0, sum(DOOR_Y) / 2, DOOR_H / 2 - 1.5))
    for (x, y, aim_deg) in ((-3.5, DOOR_Y[0] - 2.5, 40), (W - 1.2, D - 1.2, 215)):   # projektör kuleleri
        l = bpy.data.lights.new("Flood", 'SPOT')
        l.energy = 6000
        l.spot_size = math.radians(70)
        l.spot_blend = 0.5
        l.color = (1.0, 0.95, 0.85)
        lo = bpy.data.objects.new("Flood", l)
        scn.collection.objects.link(lo)
        lo.location = (x, y, 5.6)
        aim(lo, (x + math.cos(math.radians(aim_deg)) * 12, y + math.sin(math.radians(aim_deg)) * 12, 0.0))
    lamps = LAMPS if level > 1 else LAMPS[::2]
    for x, y in lamps:
        top = WALL_H + 4.0 * math.sin(math.pi * x / W)
        if level == 1:
            l = bpy.data.lights.new("Sodium", 'POINT')
            l.energy = 1200
            l.color = (1.0, 0.62, 0.3)
            z = top - 2.0
        elif level == 2:
            l = bpy.data.lights.new("Tube", 'AREA')
            l.shape = 'RECTANGLE'
            l.size, l.size_y = 2.1, 0.3
            l.energy = 1100
            l.color = (0.94, 0.96, 1.0)
            z = top - 1.5
        else:
            l = bpy.data.lights.new("Led", 'AREA')
            l.shape = 'DISK'
            l.size = 0.8
            l.energy = 1700
            z = top - 1.55
        lo = bpy.data.objects.new(l.name, l)
        scn.collection.objects.link(lo)
        lo.location = (x, y, z)


def preview_camera(width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 32
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    co.location = (W * 0.5 + 15.5, -16.5, 19.5)
    aim(co, (W * 0.5 + 0.8, D * 0.52, 0.5))
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        level = int(argv[1]) if len(argv) > 1 else 1
        out = argv[2] if len(argv) > 2 else "/tmp/hangar.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 640
        samples = int(argv[5]) if len(argv) > 5 else 48
        root, groups = build(os.path.join(os.path.dirname(out), "tex"))
        park = {1: 1, 2: 3, 3: 5}[level]
        show_levels(groups, {"Floor": level, "Walls": level, "Lights": level, "Lift": level, "Park": park})
        place_cars(SLOTS, PREVIEW_CARS[:18 + 3 * (park - 1)])
        preview_lights(level)
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
