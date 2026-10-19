"""CAM SHOWROOM — GARAJLARIM'ın 4. garajı (docs/GARAJLAR_TASARIM.md §7): parlak beyaz GÜN IŞIĞI, sol duvar boydan boya
cam cephe (arkasında şehir). 26 × 16 m, 5,6 m. Araçlar galeri usulü 30° açılı üç sıra, burunları kameraya.

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan):
  arka sıra  PARK 0-5    orta sıra  PARK 6-11    ön sıra  PARK 12-17
  taban 10 (arka 6 + orta 4); PARK YERİ her adımda +2 → 12, 14, 16, 18 (5 seviye). Açılmamış yerlerde örtülü araç +
  kordon direkleri.
  ön sağ  LİFT / PLATFORM (sv.1 kordonlu alan, sv.2 yükseltilmiş yuvarlak platform, sv.3 LED halkalı döner tabla + fon)
Kalemler: Floor / Walls / Lights / Lift _L1..3, Park_L1..5; ortak: Static. Slot_0..17.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/showroom.py -- preview <seviye 1-3> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 26.0, 16.0, 5.6
T = 0.3
YAW = 30.0
ROWS_Y = (12.9, 7.9, 2.9)
SLOTS = [(2.6 + i * 3.4, ry, YAW) for ry in ROWS_Y for i in range(6)]
PLATFORM_AT = (23.6, 3.2)
PARK_LEVELS = 5
SUN_DIR = (0.55, 0.25, -0.8)          # batı-güneybatıdan yüksek öğle güneşi: cam cepheden


def rmats():
    return {
        "white_wall": k_mat("r_white_wall", "#F2F2EF", rough=0.8),
        "grey_wall": k_mat("r_grey_wall", "#C9CCCF", rough=0.8),
        "wood_band": k_mat("r_wood_band", "#B07A4A", rough=0.75),
        "mullion": k_mat("r_mullion", "#2A2D31", rough=0.5, metal=0.6),
        "glass_day": k_mat("r_glass_day", "#CFE6F5", rough=0.5, emit="#DDEEFF", strength=2.5),
        "cover": k_mat("r_cover", "#8E949C", rough=0.95),
        "cover2": k_mat("r_cover2", "#6B2730", rough=0.95),
        "rope": k_mat("r_rope", "#A3262B", rough=0.9),
        "brass": k_mat("r_brass", "#C9A55A", rough=0.35, metal=0.8),
        "led_wall": k_mat("r_led_wall", "#7FB8FF", rough=0.5, emit="#5AA8FF", strength=6.0),
        "led_wall2": k_mat("r_led_wall2", "#FF8A5A", rough=0.5, emit="#FF7A45", strength=6.0),
        "city_a": k_mat("r_city_a", "#9FB4C6", rough=0.9),
        "city_b": k_mat("r_city_b", "#B9C7D3", rough=0.9),
        "marble_dark": k_mat("r_marble_dark", "#3A3C40", rough=0.6),
    }


def floor_textures(out_dir, ppm=72):
    """Sv.1 açık gri cilalı beton, sv.2 beyaz büyük karo (ince derz), sv.3 beyaz mermer (gri damarlar)."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    os.makedirs(out_dir, exist_ok=True)
    n = _fbm((h, w), 90, 401)
    fine = _fbm((h, w), 7, 411, 3)
    paths = {}
    base = np.array(_hex("#B7B7B3"))[None, None, :] * (0.94 + 0.08 * n[..., None] + 0.02 * fine[..., None])
    cuts = (np.abs(mx % 4.0) < 0.012) | (np.abs(my % 4.0) < 0.012)
    base[cuts] *= 0.8
    paths[1] = os.path.join(out_dir, "showroom_floor_1.png")
    _save_image("r_floor_1", base[::-1], paths[1])
    base = np.array(_hex("#ECEBE7"))[None, None, :] * (0.97 + 0.04 * n[..., None])
    grout = (np.abs(mx % 1.2) < 0.008) | (np.abs(my % 1.2) < 0.008)
    base[grout] = np.array(_hex("#BDBAB3"))
    paths[2] = os.path.join(out_dir, "showroom_floor_2.png")
    _save_image("r_floor_2", base[::-1], paths[2])
    warp = _fbm((h, w), 40, 421, 4)
    veins = np.abs(np.sin((mx * 0.9 + my * 0.5 + warp * 6.0) * 2.2))
    vein = np.clip(1.0 - veins / 0.06, 0, 1) * (0.5 + 0.5 * _fbm((h, w), 20, 431, 2))
    base = np.array(_hex("#F1EFEA"))[None, None, :] * (0.97 + 0.03 * n[..., None])
    base = base * (1 - vein[..., None] * 0.45) + vein[..., None] * np.array(_hex("#8E9096")) * 0.45
    slab = (np.abs(mx % 1.6) < 0.006) | (np.abs(my % 1.6) < 0.006)
    base[slab] *= 0.9
    paths[3] = os.path.join(out_dir, "showroom_floor_3.png")
    _save_image("r_floor_3", base[::-1], paths[3])
    return paths


def car_cover(b, slot, m, color="cover"):
    """Örtülü araç (açılmamış park yeri): kaporta + öne / arkaya alçalan kaput ve bagaj, daha dar kabin, teker kemeri
    çıkıntıları, yere değen koyu etek. İlk denemede tek kubbeli kutu minder / kanepe gibi duruyordu."""
    x, y, rot = slot
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, 0.0), (0, 0, rot))
    soft_box(b, p(0, 0, 0.42), (1.86, 4.35, 0.58), m[color], radius=0.14, rot=(0, 0, rot))
    soft_box(b, p(0, -1.45, 0.66), (1.78, 1.3, 0.16), m[color], radius=0.07, rot=(-6, 0, rot))     # kaput
    soft_box(b, p(0, 1.6, 0.68), (1.78, 1.0, 0.16), m[color], radius=0.07, rot=(5, 0, rot))       # bagaj
    soft_box(b, p(0, 0.2, 0.98), (1.48, 2.0, 0.48), m[color], radius=0.2, rot=(0, 0, rot))       # kabin
    for sx in (-0.9, 0.9):
        for sy in (-1.35, 1.35):
            b.cyl(p(sx, sy, 0.36), 0.36, 0.14, m[color], axis='X', segs=12, rot=(0, 0, rot))   # teker kemeri
    soft_box(b, p(0, 0, 0.1), (1.94, 4.45, 0.16), m["black"], radius=0.05, rot=(0, 0, rot))   # kumaş eteği gölgesi


def stanchion(b, base, m):
    x, y, z = base
    b.cyl((x, y, z + 0.02), 0.16, 0.04, m["brass"], segs=12)
    b.cyl((x, y, z + 0.48), 0.025, 0.92, m["brass"], segs=8)
    b.ball((x, y, z + 0.96), 0.045, m["brass"], segs=8, rings=5)


def rope_ring(b, center, radius, m, posts=6, start=0.0):
    pts = []
    for i in range(posts):
        a = math.radians(start) + math.tau * i / posts
        pts.append((center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius))
    for i, (px, py) in enumerate(pts):
        stanchion(b, (px, py, 0.0), m)
        qx, qy = pts[(i + 1) % posts]
        mx_, my_ = (px + qx) / 2, (py + qy) / 2
        b.tube([(px, py, 0.9), (mx_, my_, 0.72), (qx, qy, 0.9)], 0.018, m["rope"], segs=5)


def reception(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.55), (3.2, 0.8, 1.1), m["white_wall"], radius=0.12, rot=(0, 0, rot))
    soft_box(b, (x, y, z + 1.13), (3.3, 0.95, 0.06), m["wood_band"], radius=0.03, rot=(0, 0, rot))
    plane(b, b._xf((0, -0.41, 0), (x, y, z + 0.55), (0, 0, rot)), (2.9, 0.08), m["led"], rot=(90, 0, rot))
    soft_box(b, b._xf((0.6, 0.15, 0), (x, y, z + 1.3), (0, 0, rot)), (0.45, 0.04, 0.3), m["black"], radius=0.01, rot=(0, 0, rot))


def lounge_chair(b, base, m, rot=0.0, color="fabric"):
    x, y, z = base
    soft_box(b, (x, y, z + 0.25), (0.8, 0.8, 0.3), m[color], radius=0.1, rot=(0, 0, rot))
    soft_box(b, b._xf((0, 0.33, 0), (x, y, z + 0.55), (0, 0, rot)), (0.8, 0.16, 0.6), m[color], radius=0.08, rot=(0, 0, rot))
    b.cyl((x, y, z + 0.06), 0.25, 0.12, m["chrome"], segs=12)


def tall_plant(b, base, m, seed=1):
    r = random.Random(seed)
    x, y, z = base
    b.cyl((x, y, z + 0.35), 0.28, 0.7, m["white_wall"], segs=14, r2=0.32)
    for i in range(14):
        a = r.uniform(0, math.tau)
        rr = r.uniform(0.0, 0.3)
        b.ball((x + math.cos(a) * rr, y + math.sin(a) * rr, z + 0.9 + r.uniform(0.1, 1.4)), r.uniform(0.18, 0.3), m["plant"],
               segs=7, rings=5)


def shell(col, m):
    b = Builder("Shell", seed=501)
    soft_box(b, (W / 2, D + T / 2, H / 2), (W + 2 * T, T, H), m["white_wall"], radius=0.02)
    plane(b, (W / 2, D - 0.01, H / 2), (W, H), m["white_wall"], rot=(90, 0, 0))
    soft_box(b, (W / 2, -T / 2, 0.3), (W + 2 * T, T, 0.6), m["grey_wall"], radius=0.02)
    soft_box(b, (W + T / 2, D / 2, 0.3), (T, D + 2 * T, 0.6), m["grey_wall"], radius=0.02)
    # cam cephe (sol duvar): ızgara + parlak gökyüzü / şehir arka planı
    soft_box(b, (-0.05, D / 2, 0.15), (0.3, D, 0.3), m["mullion"], radius=0.02)
    soft_box(b, (-0.05, D / 2, H - 0.1), (0.3, D, 0.2), m["mullion"], radius=0.02)
    for i in range(9):
        y = i * D / 8
        soft_box(b, (-0.05, y, H / 2), (0.16, 0.12, H), m["mullion"], radius=0.01)
    b.box((-0.05, D / 2, 2.8), (0.12, D, 0.08), m["mullion"])
    plane(b, (-6.0, D / 2, 4.0), (D + 10, 9.0), m["glass_day"], rot=(90, 0, 90))   # açık gök
    r = random.Random(5)
    for i in range(10):   # camın arkasındaki şehir (uzak, solgun)
        bw, bh = r.uniform(1.5, 3.2), r.uniform(3.0, 9.0)
        soft_box(b, (-4.8 - r.uniform(0, 1.2), -1.0 + i * 1.9, bh / 2 - 0.5), (1.4, bw, bh), m["city_a" if i % 2 else "city_b"],
                 radius=0.05)
    soft_box(b, (-2.0, D / 2, -0.05), (3.8, D + 4, 0.1), m["concrete"], radius=0.02)   # dışarıdaki kaldırım
    # arka duvar üstünde ray (lambalar buna asılır)
    soft_box(b, (W / 2, D - 0.5, H - 0.1), (W - 0.6, 0.12, 0.08), m["black"], radius=0.01)
    soft_box(b, (0.5, D / 2, H - 0.1), (0.12, D - 1.0, 0.08), m["black"], radius=0.01)
    return b.finish(col)


def static_props(col, m):
    b = Builder("Props", seed=503)
    reception(b, (2.2, 0.9, 0.0), m)
    for i, x in enumerate((19.6, 21.0)):
        lounge_chair(b, (x, D - 1.0, 0.0), m, rot=180, color="fabric")
    b.cyl((20.3, D - 1.0, 0.25), 0.35, 0.5, m["white_wall"], segs=16)
    for i, (x, y) in enumerate(((0.8, D - 0.8), (W - 0.8, D - 0.8), (0.8, 5.4))):
        tall_plant(b, (x, y, 0.0), m, seed=i + 3)
    return b.finish(col)


def walls_level(col, m, level):
    b = Builder("Walls_L%d" % level, seed=510 + level)
    if level == 1:
        for i, x in enumerate((5.0, 13.0, 21.0)):
            soft_box(b, (x, D - 0.04, 2.6), (1.6, 0.04, 1.1), m["grey_wall"], radius=0.01)
    elif level == 2:
        plane(b, (W / 2, D - 0.03, 1.0), (W, 0.5), m["wood_band"], rot=(90, 0, 0))
        for i in range(int(W / 0.1)):
            b.box((0.05 + i * 0.1, D - 0.05, 3.7), (0.06, 0.03, 2.2), m["wood_band"])
        for i, x in enumerate((6.0, 13.0, 20.0)):
            soft_box(b, (x, D - 0.08, 2.0), (2.2, 0.05, 1.4), m["black"], radius=0.01)
            poster(b, (x, D - 0.11, 2.0), (2.0, 1.2), m, [["blue", "white", "yellow"], ["red", "white", "black"],
                                                          ["black", "yellow", "red"]][i], seed=40 + i)
        b.cyl((W / 2, D - 0.09, 4.4), 0.5, 0.05, m["brass"], axis='Y', segs=24)   # yazısız amblem halkası
        b.cyl((W / 2, D - 0.11, 4.4), 0.32, 0.05, m["white_wall"], axis='Y', segs=24)
    else:
        # LED video duvarı (soyut gradyan şeritler) + aydınlatmalı cam raflar (maket araçlar)
        soft_box(b, (W / 2, D - 0.1, 2.9), (11.0, 0.12, 4.0), m["black"], radius=0.03)
        for k in range(6):
            plane(b, (W / 2, D - 0.17, 1.3 + k * 0.62), (10.6, 0.5), m["led_wall" if k % 2 else "led_wall2"], rot=(90, 0, 0))
        for x0 in (2.0, W - 6.0):
            for row in range(3):
                soft_box(b, (x0 + 2.0, D - 0.3, 1.4 + row * 0.9), (4.0, 0.4, 0.03), m["glass"], radius=0.0)
                plane(b, (x0 + 2.0, D - 0.3, 1.38 + row * 0.9), (3.9, 0.05), m["led"], rot=(180, 0, 0))
                for k in range(5):
                    c = ["red", "blue", "yellow", "white", "black"][(k + row) % 5]
                    soft_box(b, (x0 + 0.4 + k * 0.8, D - 0.3, 1.5 + row * 0.9), (0.45, 0.2, 0.14), m[c], radius=0.05)
    return b.finish(col)


def lights_level(col, m, level):
    b = Builder("Lights_L%d" % level, seed=530 + level)
    count = {1: 4, 2: 8, 3: 12}[level]
    for i in range(count):
        x = 1.5 + i * (W - 3.0) / (count - 1)
        target = SLOTS[min(int(i * 6 / count), 5)]
        spot_lamp(b, (x, D - 0.55, H - 0.25), (target[0], target[1] - 1.0, 0.5), m)
    for i in range(count // 2):
        y = 1.2 + i * (D - 2.4) / max(count // 2 - 1, 1)
        spot_lamp(b, (0.55, y, H - 0.25), (6.0, y, 0.5), m)
    if level >= 2:
        plane(b, (W / 2, D - 0.04, H - 0.3), (W - 0.6, 0.08), m["led"], rot=(90, 0, 0))   # duvar yıkayıcı şerit
    if level == 3:
        x, y = PLATFORM_AT
        ring = [(x + math.cos(a) * 2.0, y + math.sin(a) * 2.0, 4.6) for a in [i * math.tau / 24 for i in range(25)]]
        b.tube(ring, 0.07, m["led"], segs=6)   # döner tablanın üstünde halo halka
        for a in (0, 120, 240):
            b.cyl((x + math.cos(math.radians(a)) * 2.0, y + math.sin(math.radians(a)) * 2.0, 5.1), 0.008, 1.0, m["black"], segs=4)
    return b.finish(col)


def lift_level(col, m, level):
    b = Builder("Lift_L%d" % level, seed=550 + level)
    x, y = PLATFORM_AT
    if level == 1:
        rope_ring(b, (x, y), 1.9, m, posts=6, start=15)
    elif level == 2:
        b.cyl((x, y, 0.12), 1.95, 0.24, m["white_wall"], segs=40)
        b.cyl((x, y, 0.25), 1.85, 0.02, m["grey_wall"], segs=40)
        rope_ring(b, (x, y), 2.4, m, posts=8, start=10)
    else:
        b.cyl((x, y, 0.1), 2.05, 0.2, m["marble_dark"], segs=48)
        b.cyl((x, y, 0.21), 1.9, 0.03, m["steel"], segs=48)
        ring = [(x + math.cos(a) * 2.06, y + math.sin(a) * 2.06, 0.12) for a in [i * math.tau / 32 for i in range(33)]]
        b.tube(ring, 0.03, m["led"], segs=5)
        # kavisli fon (cyclorama): platformun arkasında
        for i in range(10):
            a0 = math.radians(40 + i * 10)
            a1 = math.radians(40 + (i + 1) * 10)
            r = 2.8
            p0 = (x + math.cos(a0) * r, y + math.sin(a0) * r)
            p1 = (x + math.cos(a1) * r, y + math.sin(a1) * r)
            v = [(p0[0], p0[1], 0.0), (p1[0], p1[1], 0.0), (p1[0], p1[1], 3.2), (p0[0], p0[1], 3.2)]
            b._add(v, [(0, 1, 2, 3)], m["white_wall"])
    return b.finish(col)


def park_level(col, m, level):
    b = Builder("Park_L%d" % level, seed=570 + level)
    open_slots = 10 + 2 * (level - 1)
    for i, slot in enumerate(SLOTS):
        if i < open_slots:
            x, y, rot = slot
            # galeri: çizgi yerine aracın altında ince plaka (sv.1 gri, sv.4+ pirinç kenarlı)
            soft_box(b, (x, y, 0.01), (2.3, 4.9, 0.02), m["grey_wall" if level < 4 else "brass"], radius=0.0, rot=(0, 0, rot))
            soft_box(b, (x, y, 0.016), (2.2, 4.8, 0.02), m["white_wall"], radius=0.0, rot=(0, 0, rot))
        else:
            car_cover(b, slot, m, "cover" if i % 2 else "cover2")
    return b.finish(col)


def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("Showroom")
    m = gmats()
    m.update(rmats())
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
    light_beam(beams, "Beam_Glass", [(0.05, 1.0, 1.0), (0.05, D - 1.0, 1.0), (0.05, D - 1.0, H - 0.6), (0.05, 1.0, H - 0.6)],
               SUN_DIR, 8.0, (1.0, 0.97, 0.9), strength=0.025)
    slots = new_col("Slots", root)
    markers(slots, SLOTS)
    return root, groups


PREVIEW_CARS = ["lambo_huracan", "porsche_gt3", "bmw_f30", "mercedes_g", "porsche_taycan", "audi_a6", "ferrari_laferrari",
                "bugatti_chiron", "vw_golf_7", "cupra_formentor", "bmw_e46", "renault_megane_4", "toyota_corolla", "skoda_superb",
                "vw_passat_b8", "chery_tiggo_8", "hyundai_getz", "tofas_sahin"]


def preview_lights(level):
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.11, 0.12, 0.14, 1.0)   # aydınlık salon: koyu-gri dolgu
    bg.inputs["Strength"].default_value = 0.8
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 4.5
    sun.color = (1.0, 0.98, 0.94)
    sun.angle = math.radians(2.0)
    so = bpy.data.objects.new("Sun", sun)
    scn.collection.objects.link(so)
    aim(so, SUN_DIR)
    glass = bpy.data.lights.new("GlassSky", 'AREA')
    glass.shape = 'RECTANGLE'
    glass.size, glass.size_y = D, H
    glass.energy = 2400
    glass.color = (0.86, 0.93, 1.0)
    go = bpy.data.objects.new("GlassSky", glass)
    scn.collection.objects.link(go)
    go.location = (-0.8, D / 2, H / 2)
    aim(go, (6.0, D / 2, H / 2 - 0.8))
    count = {1: 4, 2: 8, 3: 12}[level]
    for i in range(count):
        x = 1.5 + i * (W - 3.0) / (count - 1)
        t = SLOTS[min(int(i * 6 / count), 5)]
        l = bpy.data.lights.new("Spot", 'SPOT')
        l.energy = 900
        l.spot_size = math.radians(40)
        l.spot_blend = 0.6
        l.shadow_soft_size = 0.15
        lo = bpy.data.objects.new("Spot", l)
        scn.collection.objects.link(lo)
        lo.location = (x, D - 0.7, H - 0.35)
        aim(lo, (t[0], t[1] - 1.0, 0.5))
    if level >= 2:
        wash = bpy.data.lights.new("Wash", 'AREA')
        wash.shape = 'RECTANGLE'
        wash.size, wash.size_y = W - 1.0, 0.2
        wash.energy = 1500
        wo = bpy.data.objects.new("Wash", wash)
        scn.collection.objects.link(wo)
        wo.location = (W / 2, D - 0.3, H - 0.4)
        aim(wo, (W / 2, D - 2.0, 1.0))
    if level == 3:
        halo = bpy.data.lights.new("Halo", 'AREA')
        halo.shape = 'DISK'
        halo.size = 4.0
        halo.energy = 1200
        ho = bpy.data.objects.new("Halo", halo)
        scn.collection.objects.link(ho)
        ho.location = (PLATFORM_AT[0], PLATFORM_AT[1], 4.5)


def preview_camera(width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 32
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    co.location = (W * 0.5 + 11.5, -12.5, 14.0)
    aim(co, (W * 0.5 + 0.6, D * 0.52, 0.3))
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        level = int(argv[1]) if len(argv) > 1 else 1
        out = argv[2] if len(argv) > 2 else "/tmp/showroom.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 640
        samples = int(argv[5]) if len(argv) > 5 else 48
        root, groups = build(os.path.join(os.path.dirname(out), "tex"))
        park = {1: 1, 2: 3, 3: 5}[level]
        show_levels(groups, {"Floor": level, "Walls": level, "Lights": level, "Lift": level, "Park": park})
        place_cars(SLOTS, PREVIEW_CARS[:10 + 2 * (park - 1)])
        preview_lights(level)
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
