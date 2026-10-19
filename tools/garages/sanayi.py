"""SANAYİ ATÖLYESİ — GARAJLARIM'ın 2. garajı (docs/GARAJLAR_TASARIM.md §7; kullanıcı kararları 2026-10-19: perspektif
diorama, garaja özel atmosfer). Serin SABAH: yüksek pencere bandından eğik güneş huzmeleri, sol duvardaki açık dev
kapıdan mavi gün ışığı. 18 × 14 m iç mekân, 6,2 m yükseklik; alt duvar beton blok, üstü oluklu sac; çelik kolonlar;
arka yarıda çatı makasları ve tavan vinci (ön yarıda tavan elemanı yok: kamera önü temiz).

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan):
  arka sıra  PARK 0-5   burun kameraya (taban kapasite 6)
  ön sıra    PARK 6-9   sv.1'de paletler / sandıklar / brandalı makine; PARK YERİ sv.2 → 6-7, sv.3 → 8-9
  ön sağ     LİFT alanı (sv.1 motor vinci + sehpa, sv.2 iki iki-kolonlu lift, sv.3 makaslı rot-balans + balans makinesi)
  sol duvar  dev açık kapı (koridora)
Kalemler: Floor / Walls / Lights / Lift / Park _L1..3; ortak: Static. Slot_0..9.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/sanayi.py -- preview <seviye 1-3> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 18.0, 14.0, 6.2
T = 0.3
BLOCK_H = 1.6                      # beton blok alt duvar
DOOR_Y = (5.5, 9.0)                # sol duvardaki kapı (koridor)
DOOR_H = 4.6
TRUSS_Y = (9.6, 13.2)              # çatı makasları (arka yarı)
SLOTS = [(2.3 + i * 2.85, 11.2, 0.0) for i in range(6)] + [(2.3 + i * 2.85, 3.2, 0.0) for i in range(4)]
LIFT_AT = (15.0, 2.9)
SUN_DIR = (0.32, -0.62, -0.72)     # kuzeybatıdan yüksek sabah güneşi: pencere bandından arka sıraya


def floor_textures(out_dir, ppm=80):
    """Sv.1 tozlu beton + lastik izi, sv.2 gri boya + sarı güvenlik yolu, sv.3 cilalı açık beton (derzli)."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    os.makedirs(out_dir, exist_ok=True)
    n = _fbm((h, w), 70, 101)
    fine = _fbm((h, w), 6, 111, 3)
    rng = np.random.default_rng(12)
    paths = {}
    base = np.array(_hex("#8B8780"))[None, None, :] * (0.8 + 0.32 * n[..., None] + 0.1 * fine[..., None])
    for _ in range(30):   # yağ / is lekeleri
        sx, sy, _r = SLOTS[rng.integers(0, len(SLOTS))]
        cx, cy = sx + rng.normal(0, 0.6), sy + rng.normal(-0.5, 1.0)
        r = rng.uniform(0.2, 0.7)
        d = np.sqrt((mx - cx) ** 2 + (my - cy) ** 2)
        base *= (1 - (np.clip(1 - d / r, 0, 1) ** 1.5 * rng.uniform(0.2, 0.5))[..., None] * 0.7)
    for k in range(5):    # lastik izleri: kapıdan koridor boyunca kavis
        y0 = rng.uniform(DOOR_Y[0] + 0.4, DOOR_Y[1] - 0.4)
        amp = rng.uniform(0.3, 1.4)
        track = np.abs(my - (y0 + amp * np.sin(mx / W * math.pi * rng.uniform(0.6, 1.4)))) < 0.09
        base[track & (rng.random((h, w)) < 0.6)] *= 0.72
    joints = (np.abs(mx % 4.5) < 0.025) | (np.abs(my % 4.5) < 0.025)
    base[joints] *= 0.6
    paths[1] = os.path.join(out_dir, "sanayi_floor_1.png")
    _save_image("s_floor_1", base[::-1], paths[1])
    base = np.array(_hex("#6F767D"))[None, None, :] * (0.94 + 0.08 * n[..., None] + 0.02 * fine[..., None])
    walk = ((np.abs(my - 5.55) < 0.07) | (np.abs(my - 8.85) < 0.07)) & (mx > 0.4)
    base[walk] = np.array(_hex("#E8B330"))
    hatch = (mx > LIFT_AT[0] - 2.9) & (my < 5.3) & (my > 0.3) & ((((mx + my) * 1.4).astype(int) % 2) == 0) & \
            ((mx < LIFT_AT[0] - 2.6) | (my > 5.0) | (my < 0.6))
    base[hatch] = np.array(_hex("#E8B330"))
    paths[2] = os.path.join(out_dir, "sanayi_floor_2.png")
    _save_image("s_floor_2", base[::-1], paths[2])
    base = np.array(_hex("#B9B6AE"))[None, None, :] * (0.95 + 0.07 * n[..., None] + 0.015 * fine[..., None])
    cuts = (np.abs(mx % 3.0) < 0.012) | (np.abs(my % 3.0) < 0.012)
    base[cuts] *= 0.7
    paths[3] = os.path.join(out_dir, "sanayi_floor_3.png")
    _save_image("s_floor_3", base[::-1], paths[3])
    return paths


def shell(col, m):
    b = Builder("Shell", seed=31)
    # gövdeler: arka ve sol duvar (kapı boşluğuyla)
    soft_box(b, (W / 2, D + T / 2, H / 2), (W + 2 * T, T, H), m["block"], radius=0.02)
    soft_box(b, (-T / 2, DOOR_Y[0] / 2, H / 2), (T, DOOR_Y[0], H), m["block"], radius=0.02)
    soft_box(b, (-T / 2, (DOOR_Y[1] + D + T) / 2, H / 2), (T, D + T - DOOR_Y[1], H), m["block"], radius=0.02)
    soft_box(b, (-T / 2, sum(DOOR_Y) / 2, (DOOR_H + H) / 2), (T, DOOR_Y[1] - DOOR_Y[0], H - DOOR_H), m["block"], radius=0.02)
    # kesik ön / sağ duvar: blok taban
    soft_box(b, (W / 2, -T / 2, 0.4), (W + 2 * T, T, 0.8), m["block"], radius=0.02)
    soft_box(b, (W + T / 2, D / 2, 0.4), (T, D + 2 * T, 0.8), m["block"], radius=0.02)
    # iç yüz: blok sıraları (alt) + oluklu sac (üst)
    for (x0, y0, x1, y1, nx) in ((0.0, D - 0.02, W, D - 0.02, 0), (0.02, DOOR_Y[1], 0.02, D, 90), (0.02, 0.0, 0.02, DOOR_Y[0], 90)):
        length = math.hypot(x1 - x0, y1 - y0)
        yaw = math.degrees(math.atan2(y1 - y0, x1 - x0))
        rows = int(BLOCK_H / 0.2)
        for r_ in range(rows):
            off = 0.2 if r_ % 2 else 0.0
            t = -off
            while t < length:
                a, c = max(t, 0.0), min(t + 0.39, length)
                if c - a > 0.05:
                    mid = (a + c) / 2
                    p = (x0 + math.cos(math.radians(yaw)) * mid, y0 + math.sin(math.radians(yaw)) * mid, r_ * 0.2 + 0.1)
                    plane(b, p, (c - a, 0.19), m["block"], rot=(90, 0, yaw))
                t += 0.4
        b.corrugated((x0 + (0.04 if nx else 0.0), y0 - (0.04 if not nx else 0.0), BLOCK_H), length, H - BLOCK_H,
                     m["sheet_grey"], period=0.2, depth=0.035, rot=(0, 0, yaw), along='X')
    # yüksek pencere bandı (arka duvar): sabah göğü
    for i in range(6):
        x = 1.6 + i * 2.95
        soft_box(b, (x, D - 0.06, 5.1), (2.6, 0.14, 1.0), m["beam_grey"], radius=0.02)
        plane(b, (x, D - 0.14, 5.1), (2.45, 0.85), m["window_day"], rot=(90, 0, 0))
        for k in (-0.6, 0.0, 0.6):
            b.box((x + k, D - 0.15, 5.1), (0.04, 0.03, 0.85), m["beam_grey"])
    # kolonlar
    for x in (0.25, 6.0, 12.0, W - 0.25):
        i_column(b, (x, D - 0.25, 0.0), H, m)
    for y in (0.25, DOOR_Y[0] - 0.2, DOOR_Y[1] + 0.2):
        i_column(b, (0.25, y, 0.0), H, m, rot=90)
    # kapı: dev kepenk (tamamen açık) + sarı kasa
    roll_shutter(b, (-0.05, DOOR_Y[0], 0.0), DOOR_Y[1] - DOOR_Y[0], DOOR_H, 0.94, m, rot=90)
    for y in DOOR_Y:
        soft_box(b, (0.06, y, DOOR_H / 2), (0.16, 0.16, DOOR_H), m["beam_yellow"], radius=0.02)
    # çatı makasları (arka yarı) + vinç rayları
    for y in TRUSS_Y:
        soft_box(b, (W / 2, y, H + 0.05), (W + 0.3, 0.16, 0.16), m["beam_grey"], radius=0.02)
        soft_box(b, (W / 2, y, H + 0.85), (W + 0.3, 0.12, 0.12), m["beam_grey"], radius=0.02)
        for i in range(10):
            x0 = i * W / 10
            b.tube([(x0, y, H + 0.05), (x0 + W / 20, y, H + 0.85), (x0 + W / 10, y, H + 0.05)], 0.035, m["beam_grey"], segs=5)
    for x in (0.4, W - 0.4):
        soft_box(b, (x, (TRUSS_Y[0] + D) / 2 - 0.3, 5.55), (0.3, D - TRUSS_Y[0] + 0.8, 0.35), m["beam_yellow"], radius=0.02)
    gantry_crane(b, 12.4, 0.4, W - 0.4, 5.3, m, hook_x=W * 0.38)
    # dışarısı: kapı önü beton saha
    soft_box(b, (-3.0, sum(DOOR_Y) / 2, -0.06), (5.4, 9.0, 0.12), m["concrete"], radius=0.02)
    return b.finish(col)


def static_props(col, m):
    b = Builder("Props", seed=33)
    forklift(b, (-2.6, 7.9, 0.0), m, rot=-70)   # kapı önündeki sahada: içeride arka sıranın son aracını kapatıyordu
    compressor(b, (0.75, 10.0, 0.0), m, rot=90)
    welding_cart(b, (0.6, 12.6, 0.0), m)
    for i, y in enumerate((0.9, 1.6, 2.3)):
        barrel(b, (0.5, y, 0.0), m, ["blue", "red", "green"][i])
    tire_stack_g(b, (0.55, 3.3, 0.0), 5, m, seed=7)
    tire_stack_g(b, (0.55, 4.05, 0.0), 3, m, seed=8)
    extinguisher(b, (0.12, DOOR_Y[1] + 0.6, 0.9), m)
    wall_clock(b, (9.0, D - 0.05, 4.1), m)
    return b.finish(col)


def walls_level(col, m, level):
    b = Builder("Walls_L%d" % level, seed=40 + level)
    r = random.Random(level)
    if level == 1:
        for i in range(9):   # pas yamaları sacın üstünde
            x = r.uniform(0.6, W - 0.6)
            blob(b, (x, D - 0.09, r.uniform(2.0, 4.3)), (r.uniform(0.3, 0.8), r.uniform(0.25, 0.7)), m["sheet_rust"], seed=i + 3)
        for i in range(3):
            blob(b, (0.09, r.uniform(DOOR_Y[1] + 0.5, D - 0.5), r.uniform(2.0, 4.0)), (0.5, 0.4), m["sheet_rust"],
                 rot=(90, 0, 90), seed=i + 30)
        plane(b, (6.0 + 1.4, D - 0.1, 2.4), (0.6, 0.8), m["white"], rot=(90, 0, 0))   # eski takvim
    elif level == 2:
        # lacivert boyalı sac (üst) + ikaz levhaları + alet duvarı (sol duvar arka)
        plane(b, (W / 2, D - 0.09, (BLOCK_H + 4.5) / 2), (W, 4.5 - BLOCK_H), m["sheet_navy"], rot=(90, 0, 0))
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.09, (y0 + y1) / 2, (BLOCK_H + 4.5) / 2), (y1 - y0, 4.5 - BLOCK_H), m["sheet_navy"], rot=(90, 0, 90))
        plane(b, (W / 2, D - 0.08, BLOCK_H + 0.06), (W, 0.12), m["beam_yellow"], rot=(90, 0, 0))
        for i, (x, kind) in enumerate(((3.0, "warn"), (8.9, "info"), (14.8, "exit"))):
            pictogram(b, (x, D - 0.1, 3.6), m, kind)
        pegboard(b, (0.1, 11.8, 2.6), m, w=3.0, h=1.4, rot=90, seed=11)
    else:
        # beyaz panel kaplama + kırmızı-siyah şerit grafik + jant vitrini
        plane(b, (W / 2, D - 0.09, (BLOCK_H + 4.5) / 2 - 0.4), (W, 4.5 - BLOCK_H + 0.8), m["panel_white"], rot=(90, 0, 0))
        plane(b, (W / 2, D - 0.09, BLOCK_H / 2), (W, BLOCK_H), m["black"], rot=(90, 0, 0))
        for (y0, y1) in ((0.0, DOOR_Y[0]), (DOOR_Y[1], D)):
            plane(b, (0.09, (y0 + y1) / 2, 2.6), (y1 - y0, 5.2), m["panel_white"], rot=(90, 0, 90))
        for k, c in enumerate(("red", "black", "red")):
            plane(b, (W / 2, D - 0.1, 4.25 - k * 0.22), (W, 0.14), m[c], rot=(90, 0, 0))
        wheel_rack(b, (4.4, D - 0.25, 2.0), m, count=8, seed=4)
        wheel_rack(b, (13.0, D - 0.25, 2.0), m, count=8, seed=9)
        b.tube([(0.12, 10.0, 4.3), (0.12, 13.4, 4.3)], 0.03, m["neon_cyan"])
        b.tube([(0.12, 10.0, 4.1), (0.12, 13.4, 4.1)], 0.03, m["neon_pink"])
    return b.finish(col)


LAMPS = [(x, y) for y in TRUSS_Y for x in (2.5, 6.5, 10.5, 14.5)]


def lights_level(col, m, level):
    b = Builder("Lights_L%d" % level, seed=60 + level)
    kind = {1: "sodium", 2: "tube", 3: "led"}[level]
    lamps = LAMPS if level > 1 else [LAMPS[i] for i in (0, 2, 5, 7)]
    for x, y in lamps:
        high_bay(b, (x, y, H + 0.05), m, kind, drop=1.0 if level != 2 else 0.8)
    if level == 3:
        plane(b, (W / 2, 12.4, 5.02), (W - 1.0, 0.08), m["led"], rot=(180, 0, 0))   # vinç köprüsünün altında LED şerit
    return b.finish(col)


def lift_level(col, m, level):
    b = Builder("Lift_L%d" % level, seed=70 + level)
    x, y = LIFT_AT
    if level == 1:
        engine_hoist(b, (x - 1.0, y + 0.6, 0.0), m, rot=-30)
        engine_stand(b, (x + 1.2, y - 0.4, 0.0), m, rot=20)
        b.cyl((x + 0.2, y + 1.3, 0.03), 0.4, 0.06, m["black"], segs=14)   # yağ tavası
        plane(b, (x, y, 0.004), (5.4, 4.6), m["concrete_dark"])
    elif level == 2:
        plane(b, (x, y, 0.004), (5.6, 4.8), m["concrete_dark"])
        for dx in (-1.35, 1.35):
            two_post_lift(b, (x + dx, y, 0.0), m, rot=90.0, width=2.9, height=2.3, bridge=False)
    else:
        plane(b, (x, y, 0.004), (5.8, 4.9), m["black"])
        scissor_lift(b, (x - 0.5, y, 0.0), m, rot=90.0, length=4.4, width=2.2)
        wheel_balancer(b, (x + 2.1, y - 1.5, 0.0), m, rot=-90)
    return b.finish(col)


def clutter_slot(b, m, slot, kind):
    x, y, _r = slot
    r = random.Random(kind * 7 + 1)
    if kind % 2 == 0:
        for dx in (-0.7, 0.7):
            pallet(b, (x + dx, y + 0.6, 0.0), m)
            crate(b, (x + dx, y + 0.6, 0.15), (1.0, 0.9, r.uniform(0.6, 1.0)), m, rot=r.uniform(-6, 6))
        pallet(b, (x, y - 1.2, 0.0), m, rot=90)
        crate(b, (x, y - 1.2, 0.15), (0.9, 0.9, 0.7), m, tarp=True)
    else:
        crate(b, (x, y, 0.0), (1.8, 3.2, 1.3), m, tarp=True)   # brandalı eski makine
        tire_stack_g(b, (x + 1.1, y - 1.6, 0.0), 4, m, seed=kind)
        b.cyl((x - 0.9, y + 1.6, 0.4), 0.29, 0.8, m["red"], segs=12)


def park_level(col, m, level):
    b = Builder("Park_L%d" % level, seed=90 + level)
    open_slots = 6 + 2 * (level - 1)
    for i, slot in enumerate(SLOTS):
        if i < open_slots:
            slot_lines(b, m, slot, "white" if level < 3 else "black", ln=5.2, wd=2.75)
        else:
            clutter_slot(b, m, slot, i - 6)
    return b.finish(col)


def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("Sanayi")
    m = gmats()
    m.update(smats())
    static = new_col("Static", root)
    shell(static, m)
    static_props(static, m)
    paths = floor_textures(tex_dir)
    groups = {}
    for level in (1, 2, 3):
        groups[("Floor", level)] = new_col("Floor_L%d" % level, root)
        floor_object(groups[("Floor", level)], "Floor_L%d" % level, paths[level], (W, D))
        for item, fn in (("Walls", walls_level), ("Lights", lights_level), ("Lift", lift_level), ("Park", park_level)):
            groups[(item, level)] = new_col("%s_L%d" % (item, level), root)
            fn(groups[(item, level)], m, level)
    beams = new_col("Beams", root)
    for i in range(6):
        x = 1.6 + i * 2.95
        light_beam(beams, "Beam_Win_%d" % i, [(x - 1.15, D - 0.15, 4.7), (x + 1.15, D - 0.15, 4.7), (x + 1.15, D - 0.15, 5.5),
                   (x - 1.15, D - 0.15, 5.5)], SUN_DIR, 7.5, (0.85, 0.92, 1.0), strength=0.03)
    light_beam(beams, "Beam_Door", [(0.0, DOOR_Y[0] + 0.2, 0.2), (0.0, DOOR_Y[1] - 0.2, 0.2), (0.0, DOOR_Y[1] - 0.2, DOOR_H - 0.3),
               (0.0, DOOR_Y[0] + 0.2, DOOR_H - 0.3)], (1.0, -0.05, -0.12), 7.0, (0.75, 0.85, 1.0), strength=0.035)
    slots = new_col("Slots", root)
    markers(slots, SLOTS)
    return root, groups


PREVIEW_CARS = ["tofas_sahin", "bmw_e46", "lambo_huracan", "vw_golf_7", "porsche_gt3", "renault_toros",
                "hyundai_getz", "vw_passat_b55", "bmw_f30", "toyota_corolla"]


def preview_lights(level):
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.02, 0.026, 0.036, 1.0)   # serin, koyu
    bg.inputs["Strength"].default_value = 0.7
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 6.0
    sun.color = (1.0, 0.95, 0.86)
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("Sun", sun)
    scn.collection.objects.link(so)
    aim(so, SUN_DIR)
    door = bpy.data.lights.new("DoorSky", 'AREA')
    door.shape = 'RECTANGLE'
    door.size, door.size_y = DOOR_Y[1] - DOOR_Y[0], DOOR_H
    door.energy = 900
    door.color = (0.72, 0.84, 1.0)
    do = bpy.data.objects.new("DoorSky", door)
    scn.collection.objects.link(do)
    do.location = (-0.6, sum(DOOR_Y) / 2, DOOR_H / 2)
    aim(do, (5.0, sum(DOOR_Y) / 2, DOOR_H / 2 - 0.5))
    lamps = LAMPS if level > 1 else [LAMPS[i] for i in (0, 2, 5, 7)]
    for x, y in lamps:
        if level == 1:
            l = bpy.data.lights.new("Sodium", 'POINT')
            l.energy = 420
            l.color = (1.0, 0.62, 0.3)
            l.shadow_soft_size = 0.3
            z = H - 1.55
        elif level == 2:
            l = bpy.data.lights.new("Tube", 'AREA')
            l.shape = 'RECTANGLE'
            l.size, l.size_y = 2.1, 0.3
            l.energy = 420
            l.color = (0.92, 0.96, 1.0)
            z = H - 0.95
        else:
            l = bpy.data.lights.new("Led", 'AREA')
            l.shape = 'DISK'
            l.size = 0.8
            l.energy = 650
            l.color = (1.0, 1.0, 1.0)
            z = H - 1.1
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
    co.location = (W * 0.5 + 9.6, -10.2, 11.6)
    aim(co, (W * 0.5 + 0.5, D * 0.55, 0.4))
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        level = int(argv[1]) if len(argv) > 1 else 1
        out = argv[2] if len(argv) > 2 else "/tmp/sanayi.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 640
        samples = int(argv[5]) if len(argv) > 5 else 48
        root, groups = build(os.path.join(os.path.dirname(out), "tex"))
        show_levels(groups, {"Floor": level, "Walls": level, "Lights": level, "Lift": level, "Park": level})
        place_cars(SLOTS, PREVIEW_CARS[:6 + 2 * (level - 1)])
        preview_lights(level)
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
