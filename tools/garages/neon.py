"""NEON YERALTI — GARAJLARIM'ın 3. garajı (docs/GARAJLAR_TASARIM.md §7): yeraltı otoparkı, JDM havası, GECE.
Güneş yok: ışık neonlardan ve sol duvardaki rampanın ağzından (gece sokak ışığı) gelir. 26 × 15 m, 4,2 m tavan hissi;
arka yarıda beton kirişler + yangın borusu + havalandırma kanalı (ön yarıda tavan elemanı yok: kamera önü temiz),
kolonlar yalnız arka yarıda.

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan):
  arka sıra  PARK 0-6   burun kameraya
  ön sıra    PARK 7-13  taban 8 (ön sıranın ilki açık); PARK YERİ sv.2 → 8-9, sv.3 → 10-11, sv.4 → 12-13 (4 seviye)
  ön sağ     LİFT alanı   arka sağ  köşe: otomat, atari, koltuk, lastik vitrini   sol duvar  rampa (sokağa çıkar)
Kalemler: Floor / Walls / Lights / Lift _L1..3, Park_L1..4; ortak: Static. Slot_0..13.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/neon.py -- preview <seviye 1-3> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 26.0, 15.0, 4.2
T = 0.35
RAMP_Y = (5.6, 9.6)                 # sol duvardaki rampa ağzı (koridor)
## Tavan kirişi duvar dibinde: y=10,4'teyken kamera açısından (~40°) tam arka duvarın üstüne izdüşüp duvar resmini /
## neon sanatını örtüyordu (önizleme, 2026-10-19). Kolonlar arka sıranın önünde serbest durur.
BEAM_Y = (14.1,)
COLUMN_Y = 10.3
COLUMNS = [(0.35, COLUMN_Y), (9.4, COLUMN_Y), (17.8, COLUMN_Y), (W - 0.3, COLUMN_Y)]
SLOTS = [(2.4 + i * 2.8, 12.4, 0.0) for i in range(7)] + [(2.4 + i * 2.8, 3.0, 0.0) for i in range(7)]
LIFT_AT = (23.4, 2.9)
PARK_LEVELS = 4


def nmats():
    return {
        "concrete_n": k_mat("n_concrete", "#5E5E62", rough=0.95),
        "concrete_n2": k_mat("n_concrete2", "#45464B", rough=0.95),
        "stain": k_mat("n_stain", "#3A3B3F", rough=0.95),
        "mural_a": k_mat("n_mural_a", "#F26A3D", rough=0.85),
        "mural_b": k_mat("n_mural_b", "#D6336C", rough=0.85),
        "mural_c": k_mat("n_mural_c", "#5B2A86", rough=0.85),
        "mural_d": k_mat("n_mural_d", "#1F1B3A", rough=0.85),
        "panel_black": k_mat("n_panel_black", "#16161C", rough=0.6),
        "pipe_red": k_mat("n_pipe_red", "#B5302A", rough=0.6, metal=0.3),
        "duct": k_mat("n_duct", "#9EA4AA", rough=0.4, metal=0.7),
        "dim_tube": k_mat("n_dim_tube", "#D8F2E0", rough=0.5, emit="#C6F5D6", strength=4.0),
        "screen": k_mat("n_screen", "#7FD8FF", rough=0.5, emit="#6CD3FF", strength=6.0),
        "vend": k_mat("n_vend", "#FFF2D6", rough=0.5, emit="#FFF0C8", strength=5.0),
        "street": k_mat("n_street", "#FFC98A", rough=0.5, emit="#FFB15C", strength=6.0),
        "neon_purple": k_mat("n_neon_purple", "#B35CFF", rough=0.5, emit="#A64DFF", strength=12.0),
        "cone": k_mat("n_cone", "#F2652A", rough=0.7),
    }


def floor_textures(out_dir, ppm=72):
    """Sv.1 ıslak koyu beton (birikinti, lastik izi), sv.2 koyu epoksi, sv.3 parlak siyah (ince pırıltı)."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    os.makedirs(out_dir, exist_ok=True)
    n = _fbm((h, w), 80, 201)
    fine = _fbm((h, w), 6, 211, 3)
    rng = np.random.default_rng(22)
    paths = {}
    base = np.array(_hex("#4F4F52"))[None, None, :] * (0.78 + 0.32 * n[..., None] + 0.1 * fine[..., None])
    puddle = _fbm((h, w), 45, 221, 3)
    wet = np.clip((puddle - 0.58) * 6.0, 0, 1)
    base = base * (1 - wet[..., None] * 0.45) + wet[..., None] * np.array(_hex("#20242E")) * 0.6
    for _ in range(6):
        y0 = rng.uniform(RAMP_Y[0] + 0.4, RAMP_Y[1] - 0.4)
        amp = rng.uniform(0.3, 1.2)
        track = np.abs(my - (y0 + amp * np.sin(mx / W * math.pi * rng.uniform(0.6, 1.3)))) < 0.1
        base[track & (rng.random((h, w)) < 0.5)] *= 0.75
    joints = (np.abs(mx % 5.6) < 0.03) | (np.abs(my % 5.0) < 0.03)
    base[joints] *= 0.7
    paths[1] = os.path.join(out_dir, "neon_floor_1.png")
    _save_image("n_floor_1", base[::-1], paths[1])
    base = np.array(_hex("#3A3D44"))[None, None, :] * (0.94 + 0.08 * n[..., None] + 0.02 * fine[..., None])
    aisle = (my > 5.4) & (my < 10.0)
    base[aisle] *= 0.85
    paths[2] = os.path.join(out_dir, "neon_floor_2.png")
    _save_image("n_floor_2", base[::-1], paths[2])
    base = np.array(_hex("#151519"))[None, None, :] * (0.95 + 0.1 * n[..., None])
    sparkle = rng.random((h, w)) < 0.004
    base[sparkle] = np.array(_hex("#5A5E70"))
    paths[3] = os.path.join(out_dir, "neon_floor_3.png")
    _save_image("n_floor_3", base[::-1], paths[3])
    return paths


def concrete_column(b, base, m, h=H, s=0.6):
    x, y, z = base
    soft_box(b, (x, y, z + h / 2), (s, s, h), m["concrete_n"], radius=0.03)
    for i in range(3):
        b.box((x, y, z + 0.15 + i * 0.3), (s + 0.02, s + 0.02, 0.15), m["yellow"] if i % 2 == 0 else m["black"])


def vending_machine(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.95), (1.0, 0.8, 1.9), m["red"], radius=0.05, rot=(0, 0, rot))
    plane(b, b._xf((0.0, -0.41, 0), (x, y, z + 1.15), (0, 0, rot)), (0.8, 1.2), m["vend"], rot=(90, 0, rot))
    for i in range(4):
        plane(b, b._xf((-0.3 + i * 0.2, -0.42, 0), (x, y, z + 1.25), (0, 0, rot)), (0.12, 0.3),
              m[["blue", "green", "yellow", "red_dark"][i]], rot=(90, 0, rot))
    soft_box(b, b._xf((0.0, -0.41, 0), (x, y, z + 0.3), (0, 0, rot)), (0.7, 0.04, 0.2), m["black"], radius=0.01, rot=(0, 0, rot))


def arcade(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.9), (0.75, 0.75, 1.8), m["panel_black"], radius=0.04, rot=(0, 0, rot))
    plane(b, b._xf((0, -0.39, 0), (x, y, z + 1.3), (0, 0, rot)), (0.55, 0.45), m["screen"], rot=(75, 0, rot))
    soft_box(b, b._xf((0, -0.45, 0), (x, y, z + 0.95), (0, 0, rot)), (0.72, 0.3, 0.08), m["mural_b"], radius=0.02, rot=(0, 0, rot))
    for dx in (-0.15, 0.12, 0.22):
        b.ball(b._xf((dx, -0.5, 0), (x, y, z + 1.02), (0, 0, rot)), 0.035, m[["red", "yellow", "blue"][int(dx * 10) % 3]],
               segs=6, rings=4)
    plane(b, b._xf((0, -0.39, 0), (x, y, z + 1.72), (0, 0, rot)), (0.6, 0.12), m["neon_pink"], rot=(90, 0, rot))


def traffic_cone(b, base, m):
    x, y, z = base
    b.box((x, y, z + 0.02), (0.36, 0.36, 0.04), m["black"])
    b.cyl((x, y, z + 0.3), 0.15, 0.55, m["cone"], segs=10, r2=0.03)
    b.cyl((x, y, z + 0.32), 0.115, 0.08, m["white"], segs=10, r2=0.1)


def neon_car_outline(b, origin, m, scale=1.0, rot=0.0, mat="neon_pink"):
    """Duvarda neon tüp araç silueti (yazısız)."""
    pts = [(-1.6, 0.0), (-1.55, 0.35), (-0.8, 0.45), (-0.35, 0.85), (0.6, 0.85), (1.1, 0.45), (1.6, 0.35), (1.65, 0.0)]
    world = [b._xf((p[0] * scale, 0.0, p[1] * scale), origin, (0, 0, rot)) for p in pts]
    b.tube(world, 0.025, m[mat], segs=6)
    for wx in (-0.95, 0.95):
        ring = [b._xf(((wx + 0.28 * math.cos(a)) * scale, 0.0, (0.02 + 0.28 * math.sin(a)) * scale), origin, (0, 0, rot))
                for a in [i * math.tau / 10 for i in range(11)]]
        b.tube(ring, 0.022, m["neon_cyan"], segs=5)


def build_shell(col, m):
    b = Builder("Shell", seed=301)
    soft_box(b, (W / 2, D + T / 2, H / 2), (W + 2 * T, T, H), m["concrete_n2"], radius=0.02)
    soft_box(b, (-T / 2, RAMP_Y[0] / 2, H / 2), (T, RAMP_Y[0], H), m["concrete_n2"], radius=0.02)
    soft_box(b, (-T / 2, (RAMP_Y[1] + D + T) / 2, H / 2), (T, D + T - RAMP_Y[1], H), m["concrete_n2"], radius=0.02)
    soft_box(b, (W / 2, -T / 2, 0.35), (W + 2 * T, T, 0.7), m["concrete_n2"], radius=0.02)
    soft_box(b, (W + T / 2, D / 2, 0.35), (T, D + 2 * T, 0.7), m["concrete_n2"], radius=0.02)
    # iç yüz: kalıp izli beton paneller (döküm sırası) — tek yüz
    for (x0, y0, x1, y1) in ((0.0, D - 0.02, W, D - 0.02), (0.02, RAMP_Y[1], 0.02, D), (0.02, 0.0, 0.02, RAMP_Y[0])):
        length = math.hypot(x1 - x0, y1 - y0)
        yaw = math.degrees(math.atan2(y1 - y0, x1 - x0))
        n = int(length / 1.2)
        r = random.Random(int(length * 10))
        for i in range(n):
            for row in range(3):
                t = (i + 0.5) * length / n
                p = (x0 + math.cos(math.radians(yaw)) * t, y0 + math.sin(math.radians(yaw)) * t, 0.7 + row * 1.4)
                plane(b, p, (length / n - 0.03, 1.37), m["concrete_n"] if r.random() > 0.2 else m["concrete_n2"], rot=(90, 0, yaw))
    # arka yarı: beton kirişler, kolonlar, borular, kanal
    for y in BEAM_Y:
        soft_box(b, (W / 2, y, H + 0.2), (W + 0.4, 0.55, 0.5), m["concrete_n"], radius=0.03)
    for i, (x, y) in enumerate(COLUMNS):
        concrete_column(b, (x, y, 0.0), m, s=0.6 if 0 < i < 3 else 0.5)
        # kafesli kolon lambası (her seviyede: sv.1 de tamamen karanlık kalmasın)
        lamp_y = y - (0.36 if 0 < i < 3 else 0.31)
        b.cyl((x, lamp_y, 3.0), 0.09, 0.22, m["bulb"], axis='Y', segs=10)
        for k in range(4):
            b.cyl((x, lamp_y - 0.02, 3.0 + (k - 1.5) * 0.06), 0.1, 0.008, m["steel_dark"], axis='Y', segs=8)
    b.tube([(0.2, 13.4, H - 0.3), (W - 0.2, 13.4, H - 0.3)], 0.07, m["pipe_red"], segs=8)
    for x in (3.0, 9.0, 15.0, 21.0):
        b.cyl((x, 13.4, H - 0.42), 0.04, 0.12, m["chrome"], segs=6)
    soft_box(b, (W / 2, 14.6, H - 0.3), (W - 0.6, 0.6, 0.4), m["duct"], radius=0.08)
    # rampa: sol duvardan dışarı ve yukarı (sokağa) çıkan eğik zemin + yan duvarlar
    ramp_len, rise = 9.0, 3.4
    pitch = math.degrees(math.atan2(rise, ramp_len))
    cy = sum(RAMP_Y) / 2
    soft_box(b, (-ramp_len / 2 - 0.1, cy, rise / 2 - 0.12), (math.hypot(ramp_len, rise), RAMP_Y[1] - RAMP_Y[0], 0.25),
             m["concrete_n"], radius=0.02, rot=(0, -pitch, 0))
    for y in (RAMP_Y[0] - 0.15, RAMP_Y[1] + 0.15):
        soft_box(b, (-ramp_len / 2, y, rise / 2 + 0.3), (ramp_len, 0.3, rise + 0.6), m["concrete_n2"], radius=0.02)
        for i in range(8):   # sarı-siyah ikaz şeridi
            if i % 2 == 0:
                b.box((-0.5 - i * 0.9, y + (0.16 if y > cy else -0.16), 0.45 + i * 0.32), (0.9, 0.02, 0.2), m["yellow"])
    plane(b, (-ramp_len - 0.4, cy, rise + 1.5), (RAMP_Y[1] - RAMP_Y[0], 3.0), m["street"], rot=(90, 0, 90))   # sokak ışığı
    return b.finish(col)


def static_props(col, m):
    b = Builder("Props", seed=303)
    vending_machine(b, (21.4, D - 0.55, 0.0), m)
    arcade(b, (22.8, D - 0.55, 0.0), m)
    old_sofa(b, (24.6, 12.7, 0.0), m, rot=90)
    tire_stack_g(b, (W - 0.5, 10.7, 0.0), 6, m, seed=31)
    tire_stack_g(b, (W - 0.5, 11.4, 0.0), 4, m, seed=32)
    for i, (x, y) in enumerate(((20.5, 6.0), (20.9, 9.1), (0.8, 4.9), (0.8, 10.3))):
        traffic_cone(b, (x, y, 0.0), m)
    soft_box(b, (0.15, 1.2, 1.4), (0.2, 0.7, 0.9), m["red"], radius=0.03)   # yangın dolabı
    # lounge köşesinde neon tabela (her seviyede): pembe çerçeve + camgöbeği kahve fincanı / şimşek (yazısız)
    b.tube([(20.6, D - 0.08, 2.4), (24.6, D - 0.08, 2.4), (24.6, D - 0.08, 3.4), (20.6, D - 0.08, 3.4), (20.6, D - 0.08, 2.4)],
           0.025, m["neon_pink"], segs=6)
    b.tube([(22.2, D - 0.09, 3.25), (22.7, D - 0.09, 2.95), (22.4, D - 0.09, 2.9), (22.9, D - 0.09, 2.55)], 0.025,
           m["neon_cyan"], segs=6)
    pictogram(b, (0.14, 3.6, 2.6), m, "exit", rot=90)
    return b.finish(col)


def walls_level(col, m, level):
    b = Builder("Walls_L%d" % level, seed=310 + level)
    r = random.Random(level * 3)
    if level == 1:
        for i in range(10):
            blob(b, (r.uniform(0.6, W - 0.6), D - 0.05, r.uniform(1.0, 3.3)), (r.uniform(0.3, 0.9), r.uniform(0.3, 0.8)),
                 m["stain"], seed=i + 40)
        for i in range(5):   # renkli karalama lekeleri (yazısız)
            c = r.choice(["mural_a", "mural_b", "neon_cyan", "yellow"])
            blob(b, (r.uniform(1.0, W - 1.0), D - 0.06, r.uniform(0.6, 1.6)), (r.uniform(0.4, 0.8), r.uniform(0.15, 0.3)),
                 m[c] if c != "neon_cyan" else m["blue"], seed=i + 60, jag=0.6)
    elif level == 2:
        # JDM gün batımı duvar resmi: alttan üste turuncu → pembe → mor şeritler + güneş dairesi
        bands = [("mural_d", 0.0, 0.9), ("mural_c", 0.9, 1.6), ("mural_b", 1.6, 2.3), ("mural_a", 2.3, 2.9), ("mural_d", 2.9, H)]
        for c, z0, z1 in bands:
            plane(b, (W / 2, D - 0.05, (z0 + z1) / 2), (W, z1 - z0), m[c], rot=(90, 0, 0))
        b.cyl((W * 0.62, D - 0.07, 2.7), 1.0, 0.02, m["yellow"], axis='Y', segs=24)
        for k in range(4):
            plane(b, (W * 0.62, D - 0.08, 2.35 + k * 0.15), (2.1, 0.06), m["mural_b"], rot=(90, 0, 0))
        for (y0, y1) in ((0.0, RAMP_Y[0]), (RAMP_Y[1], D)):
            plane(b, (0.05, (y0 + y1) / 2, 1.3), (y1 - y0, 2.6), m["mural_c"], rot=(90, 0, 90))
    else:
        plane(b, (W / 2, D - 0.05, H / 2), (W, H), m["panel_black"], rot=(90, 0, 0))
        for (y0, y1) in ((0.0, RAMP_Y[0]), (RAMP_Y[1], D)):
            plane(b, (0.05, (y0 + y1) / 2, H / 2), (y1 - y0, H), m["panel_black"], rot=(90, 0, 90))
        neon_car_outline(b, (7.0, D - 0.1, 2.0), m, scale=1.1)
        neon_car_outline(b, (16.0, D - 0.1, 2.3), m, scale=0.9, mat="neon_cyan")
        b.tube([(1.0, D - 0.1, 3.6), (W - 1.0, D - 0.1, 3.6)], 0.025, m["neon_purple"], segs=6)
        soft_box(b, (0.2, 12.5, 2.2), (0.3, 3.0, 0.04), m["chrome"], radius=0.01)   # kask rafı
        for k in range(5):
            b.ball((0.22, 11.3 + k * 0.6, 2.42), 0.18, m[["red", "white", "black", "yellow", "blue"][k]], segs=10, rings=7,
                   scale=(1, 1, 0.9))
    return b.finish(col)


def lights_level(col, m, level):
    b = Builder("Lights_L%d" % level, seed=330 + level)
    y = BEAM_Y[0]
    if level == 1:
        for x in (4.0, 13.0, 21.0):
            soft_box(b, (x, y - 0.35, H - 0.1), (1.4, 0.16, 0.06), m["white"], radius=0.01)
            b.cyl((x, y - 0.35, H - 0.16), 0.024, 1.3, m["dim_tube"], axis='X', segs=8)
    else:
        neons = (("neon_pink", -0.3), ("neon_cyan", 0.3)) if level == 2 else \
            (("neon_pink", -0.3), ("neon_purple", 0.0), ("neon_cyan", 0.3))
        for c, dy in neons:
            b.tube([(0.4, y + dy, H - 0.06), (W - 0.4, y + dy, H - 0.06)], 0.03, m[c], segs=6)
        # kesik ön / sağ duvarın üstünde neon çerçeve: ön planı da boyar
        b.tube([(0.0, -0.18, 0.74), (W, -0.18, 0.74), (W + 0.18, D, 0.74)], 0.03, m["neon_pink" if level == 2 else "neon_cyan"],
               segs=6)
        for (x, _y) in COLUMNS[1:3]:   # kolonlarda dikey neon
            b.tube([(x - 0.31, COLUMN_Y - 0.31, 0.9), (x - 0.31, COLUMN_Y - 0.31, 3.8)], 0.025, m["neon_cyan"], segs=6)
        if level == 3:
            for (x, sy, _r) in SLOTS:   # park başlarında zemin ışık şeridi
                plane(b, (x, sy - 2.35, 0.012), (2.0, 0.06), m["neon_cyan" if sy > 8 else "neon_pink"])
            for x in (4.0, 13.0, 21.0):
                led_panel(b, (x, y - 0.6, H - 0.05), m, size=(1.4, 0.5))
        else:
            for x in (4.0, 13.0, 21.0):
                fluorescent(b, (x, y - 0.5, H - 0.3), m, length=1.6)
    return b.finish(col)


def lift_level(col, m, level):
    b = Builder("Lift_L%d" % level, seed=350 + level)
    x, y = LIFT_AT
    if level == 1:
        floor_jack(b, (x - 0.5, y, 0.0), m, rot=30)
        tire_stack_g(b, (x + 1.3, y + 1.2, 0.0), 4, m, seed=51)
        tire_stack_g(b, (x + 1.3, y - 1.0, 0.0), 3, m, seed=52)
        plane(b, (x, y, 0.004), (4.6, 4.6), m["stain"])
    elif level == 2:
        plane(b, (x, y, 0.004), (4.6, 4.8), m["concrete_n2"])
        two_post_lift(b, (x, y, 0.0), m, rot=90.0, width=2.9, height=2.2, bridge=False)
    else:
        plane(b, (x, y, 0.004), (4.8, 5.0), m["panel_black"])
        four_post_lift(b, (x, y, 0.0), m, rot=90.0, length=3.4, width=2.3, lift=0.7)
        for s in (-1, 1):
            plane(b, (x + s * 1.25, y, 0.014), (0.06, 3.6), m["neon_cyan"])
    return b.finish(col)


def clutter_slot(b, m, slot, kind):
    x, y, _r = slot
    r = random.Random(kind * 11 + 3)
    if kind % 3 == 0:
        for k in range(4):
            tire_stack_g(b, (x - 0.6 + (k % 2) * 1.2, y - 0.8 + (k // 2) * 1.6, 0.0), r.randint(3, 6), m, seed=kind * 4 + k)
    elif kind % 3 == 1:
        for k in range(3):
            pallet(b, (x, y - 1.4 + k * 1.4, 0.0), m)
            crate(b, (x, y - 1.4 + k * 1.4, 0.15), (1.0, 0.9, r.uniform(0.5, 0.9)), m, rot=r.uniform(-5, 5))
    else:
        for k in range(4):
            traffic_cone(b, (x - 0.8 + k * 0.55, y - 1.8, 0.0), m)
        crate(b, (x, y + 0.4, 0.0), (1.6, 2.6, 1.1), m, tarp=True)


def park_level(col, m, level):
    b = Builder("Park_L%d" % level, seed=370 + level)
    open_slots = 8 + 2 * (level - 1)
    color = ["white", "neon_cyan", "neon_cyan", "neon_pink"][level - 1]
    for i, slot in enumerate(SLOTS):
        if i < open_slots:
            slot_lines(b, m, slot, color if color in m else "white", ln=5.0, wd=2.7)
        else:
            clutter_slot(b, m, slot, i - 8)
    return b.finish(col)


def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("Neon")
    m = gmats()
    m.update(smats())
    m.update(nmats())
    static = new_col("Static", root)
    build_shell(static, m)
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
    cy = sum(RAMP_Y) / 2
    light_beam(beams, "Beam_Ramp", [(-0.2, RAMP_Y[0] + 0.2, 0.3), (-0.2, RAMP_Y[1] - 0.2, 0.3), (-0.2, RAMP_Y[1] - 0.2, 3.0),
               (-0.2, RAMP_Y[0] + 0.2, 3.0)], (1.0, 0.0, -0.22), 8.0, (1.0, 0.7, 0.4), strength=0.04)
    slots = new_col("Slots", root)
    markers(slots, SLOTS)
    return root, groups


PREVIEW_CARS = ["tofas_sahin", "bmw_e46", "lambo_huracan", "vw_golf_7", "porsche_gt3", "renault_toros", "hyundai_getz",
                "vw_passat_b55", "bmw_f30", "toyota_corolla", "audi_a6", "mercedes_g", "porsche_taycan", "renault_megane_4"]


def preview_lights(level):
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.01, 0.01, 0.02, 1.0)   # yeraltı gecesi
    bg.inputs["Strength"].default_value = 0.5
    cy = sum(RAMP_Y) / 2
    street = bpy.data.lights.new("Street", 'AREA')
    street.shape = 'RECTANGLE'
    street.size, street.size_y = RAMP_Y[1] - RAMP_Y[0], 2.5
    street.energy = 700
    street.color = (1.0, 0.72, 0.42)
    so = bpy.data.objects.new("Street", street)
    scn.collection.objects.link(so)
    so.location = (-1.5, cy, 3.0)
    aim(so, (6.0, cy, 0.0))
    def area(name, loc, size, energy, color):
        l = bpy.data.lights.new(name, 'AREA')
        l.shape = 'RECTANGLE'
        l.size, l.size_y = size
        l.energy = energy
        l.color = color
        o = bpy.data.objects.new(name, l)
        scn.collection.objects.link(o)
        o.location = loc
    y = BEAM_Y[0]
    for i, (x, cy_) in enumerate(COLUMNS):   # kafesli kolon lambaları (her seviyede)
        l = bpy.data.lights.new("ColumnLamp", 'POINT')
        l.energy = 160
        l.color = (1.0, 0.78, 0.5)
        l.shadow_soft_size = 0.1
        o = bpy.data.objects.new("ColumnLamp", l)
        scn.collection.objects.link(o)
        o.location = (x, cy_ - 0.6, 3.0)
    if level == 1:
        for x in (4.0, 13.0, 21.0):
            area("Dim", (x, y - 0.35, H - 0.25), (1.3, 0.2), 220, (0.8, 1.0, 0.85))
    else:
        k = 1.0 if level == 2 else 1.25
        area("Pink", (W / 2, y - 0.3, H - 0.12), (W - 1, 0.08), 1000 * k, (1.0, 0.3, 0.65))
        area("Cyan", (W / 2, y + 0.3, H - 0.12), (W - 1, 0.08), 1000 * k, (0.3, 0.85, 1.0))
        if level == 3:
            area("Purple", (W / 2, y, H - 0.12), (W - 1, 0.08), 800, (0.7, 0.35, 1.0))
        area("FrontNeon", (W / 2, -0.4, 1.0), (W, 0.1), 500, (1.0, 0.3, 0.65) if level == 2 else (0.3, 0.85, 1.0))
        for x in (4.0, 13.0, 21.0):
            area("Tube", (x, y - 0.6, H - 0.4), (1.5, 0.4), 300 if level == 2 else 400, (0.95, 0.97, 1.0))
    # ön yarıyı arkadan doldurur (yeraltı: tavan lambalarının sekmesi)
    area("Fill", (W / 2, 4.0, H + 1.5), (W - 4, 6.0), 260 if level == 1 else 420, (0.55, 0.6, 0.85))


def preview_camera(width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 32
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    co.location = (W * 0.5 + 11.5, -11.8, 13.0)
    aim(co, (W * 0.5 + 0.6, D * 0.55, 0.3))
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        level = int(argv[1]) if len(argv) > 1 else 1
        out = argv[2] if len(argv) > 2 else "/tmp/neon.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 640
        samples = int(argv[5]) if len(argv) > 5 else 48
        root, groups = build(os.path.join(os.path.dirname(out), "tex"))
        park = {1: 1, 2: 2, 3: 4}[level]
        show_levels(groups, {"Floor": level, "Walls": level, "Lights": level, "Lift": level, "Park": park})
        place_cars(SLOTS, PREVIEW_CARS[:8 + 2 * (park - 1)])
        preview_lights(level)
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
