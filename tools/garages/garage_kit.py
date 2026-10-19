"""GARAJLARIM parça kiti — araç garajlarının (docs/GARAJLAR_TASARIM.md §7) ortak modelleri.

Hurdalık kitinin (tools/world/junk_kit.py) üstüne kurulur: aynı Builder, aynı renk düzeni (renk KÖŞE RENGİNDE "Col",
materyal yalnız yüzey türü), aynı yükseklik gölgesi. Burada eklenenler: yumuşak kenarlı kutu (çizgi-film oranı),
garaj eşyaları ve kalem seviyelerinin parçaları.
Birim METRE, Blender eksenleri (X doğu, Y kuzey, Z yukarı). Oyunda 1 birim = 4,39 m (araçlar 1,0 boyuna normalize).

Kullanım: sahne betiği (mahalle.py …) başında exec edilir:
    exec(open(KIT).read())
"""
import bpy, bmesh, math, random, os, json

REPO = globals().get("REPO") or os.getcwd()   # sahne betiği depo kökünden çalıştırılır
exec(open(os.path.join(REPO, "tools", "world", "junk_kit.py")).read())

_junk_surface_for = surface_for


def surface_for(material):
    """Hurdalık kiti ışıyanları üç sıcak aileye topluyor (kor / halka / ampul); garajda neon pembe, LED beyazı, floresan
    gibi her ışıyan KENDİ rengini korur. Materyal adı JYS_emit_<renk>_<güç>: dışa aktarıcı bu yüzlerin köşe rengine
    ışık rengini yazar (oyunda tek ışıksız materyal)."""
    if material is not None and material.get("jy_emit"):
        return surface_mat("emit", 0.5, 0.0, material.get("jy_emit"), float(material.get("jy_strength", 2.0)))
    return _junk_surface_for(material)


# --- Yumuşak kenarlı parçalar -------------------------------------------------------------

def soft_box(b, center, size, material, radius=0.03, segs=2, rot=(0, 0, 0)):
    """Kenarları pahlı kutu (Builder'a eklenir). Çizgi-film dili: keskin kenar yok, ışık kenarda yumuşak döner."""
    r = max(0.0, min(radius, min(size) * 0.45))
    tb = bmesh.new()
    bmesh.ops.create_cube(tb, size=1.0)
    for v in tb.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if r > 0.0005:
        bmesh.ops.bevel(tb, geom=list(tb.edges), offset=r, segments=segs, affect='EDGES', profile=0.5)
    verts = [b._xf(tuple(v.co), center, rot) for v in tb.verts]
    index = {v: i for i, v in enumerate(tb.verts)}
    faces = [tuple(index[v] for v in f.verts) for f in tb.faces]
    tb.free()
    b._add(verts, faces, material)


def plane(b, center, size, material, rot=(0, 0, 0)):
    """Tek yüzlü dikdörtgen (yukarı bakar; rot ile döndürülür): çizgi, poster, ışık paneli."""
    hx, hy = size[0] / 2, size[1] / 2
    v = [b._xf(p, center, rot) for p in [(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)]]
    b._add(v, [(0, 1, 2, 3)], material)


def gmats():
    """Garaj renk paleti (köşe rengine yazılır; yüzey türü pürüzlülük / metalikten)."""
    return {
        "brick": k_mat("g_brick", "#A85A3C", rough=0.95),
        "brick_dark": k_mat("g_brick_dark", "#7E3F2A", rough=0.95),
        "mortar": k_mat("g_mortar", "#C9B9A2", rough=0.95),
        "plaster": k_mat("g_plaster", "#D9CBB0", rough=0.9),
        "plaster_stain": k_mat("g_plaster_stain", "#B8A88A", rough=0.95),
        "paint_cream": k_mat("g_paint_cream", "#EBDDBF", rough=0.85),
        "paint_teal": k_mat("g_paint_teal", "#2E6F73", rough=0.8),
        "wood": k_mat("g_wood", "#9B6B43", rough=0.85),
        "wood_dark": k_mat("g_wood_dark", "#5C3A22", rough=0.85),
        "wood_light": k_mat("g_wood_light", "#C9A06C", rough=0.8),
        "steel": k_mat("g_steel", "#8E9399", rough=0.45, metal=0.75),
        "steel_dark": k_mat("g_steel_dark", "#3D4247", rough=0.6, metal=0.6),
        "chrome": k_mat("g_chrome", "#D5D9DD", rough=0.2, metal=0.95),
        "rubber": k_mat("g_rubber", "#1C1C1E", rough=0.95),
        "red": k_mat("g_red", "#C8372D", rough=0.6, metal=0.2),
        "red_dark": k_mat("g_red_dark", "#8E2620", rough=0.6, metal=0.2),
        "yellow": k_mat("g_yellow", "#F2B630", rough=0.7),
        "blue": k_mat("g_blue", "#2F5DA8", rough=0.6, metal=0.2),
        "green": k_mat("g_green", "#4E7D3A", rough=0.8),
        "black": k_mat("g_black", "#222326", rough=0.8),
        "white": k_mat("g_white", "#F1EEE6", rough=0.8),
        "cardboard": k_mat("g_cardboard", "#B98A55", rough=0.95),
        "fabric": k_mat("g_fabric", "#6F5A86", rough=0.97),
        "concrete": k_mat("g_concrete", "#8F8B84", rough=0.95),
        "concrete_dark": k_mat("g_concrete_dark", "#6C6862", rough=0.95),
        "glass": k_mat("g_glass", "#9FD4E6", rough=0.15, metal=0.0),
        "bulb": k_mat("g_bulb", "#FFE2A6", rough=0.5, emit="#FFC870", strength=6.0),
        "tube": k_mat("g_tube", "#F3F7FF", rough=0.5, emit="#E8F0FF", strength=8.0),
        "led": k_mat("g_led", "#FFFFFF", rough=0.5, emit="#FFFFFF", strength=10.0),
        "neon_pink": k_mat("g_neon_pink", "#FF4FA3", rough=0.5, emit="#FF3D9A", strength=12.0),
        "neon_cyan": k_mat("g_neon_cyan", "#4FE3FF", rough=0.5, emit="#3DDCFF", strength=12.0),
        "sky": k_mat("g_sky", "#FFD9A0", rough=0.9, emit="#FFC780", strength=3.0),
        "plant": k_mat("g_plant", "#4F8A3C", rough=0.9),
        "pot": k_mat("g_pot", "#B5653F", rough=0.9),
        "cat": k_mat("g_cat", "#E08A3A", rough=0.95),
    }


# --- Eşyalar ------------------------------------------------------------------------------

def tire(b, center, rot=(0, 0, 0), r=0.33, w=0.22, m=None):
    """Tek lastik (yan yatık ya da dik): dış lastik + jant göbeği."""
    m = m or gmats()
    b.cyl(center, r, w, m["rubber"], axis='Z', segs=16, rot=rot)
    b.cyl(center, r * 0.55, w * 1.02, m["steel"], axis='Z', segs=12, rot=rot)


def tire_stack_g(b, base, count, m, seed=1):
    r = random.Random(seed)
    for i in range(count):
        tire(b, (base[0] + r.uniform(-0.03, 0.03), base[1] + r.uniform(-0.03, 0.03), base[2] + 0.11 + i * 0.225),
             rot=(0, 0, r.uniform(0, 30)), m=m)


def barrel(b, center, m, color="red", lid=True):
    b.cyl((center[0], center[1], center[2] + 0.44), 0.29, 0.88, m[color], segs=14)
    for z in (0.18, 0.7):
        b.cyl((center[0], center[1], center[2] + z), 0.3, 0.04, m["steel_dark"], segs=14)
    if lid:
        b.cyl((center[0], center[1], center[2] + 0.885), 0.27, 0.02, m["steel"], segs=14)


def cardboard_box(b, center, size, m, rot=0.0):
    soft_box(b, (center[0], center[1], center[2] + size[2] / 2), size, m["cardboard"], radius=0.012, rot=(0, 0, rot))
    plane(b, (center[0], center[1], center[2] + size[2] + 0.002), (size[0] * 0.98, 0.05), m["yellow"], rot=(0, 0, rot))


def tool_cabinet(b, base, m, rot=0.0, color="red", drawers=6, w=0.9, d=0.5, h=1.05):
    """Çekmeceli takım dolabı (tekerlekli)."""
    x, y, z = base
    soft_box(b, (x, y, z + 0.08 + h / 2), (w, d, h), m[color], radius=0.03, rot=(0, 0, rot))
    for i in range(drawers):
        zz = z + 0.2 + i * (h - 0.2) / drawers
        soft_box(b, b._xf((0, -d / 2 - 0.005, 0), (x, y, zz + 0.05), (0, 0, rot)), (w * 0.9, 0.02, (h - 0.25) / drawers * 0.8),
                 m[color + "_dark"] if color + "_dark" in m else m["steel_dark"], radius=0.006, rot=(0, 0, rot))
        b.box(b._xf((0, -d / 2 - 0.025, 0), (x, y, zz + 0.07), (0, 0, rot)), (w * 0.5, 0.02, 0.025), m["chrome"], rot=(0, 0, rot))
    soft_box(b, (x, y, z + h + 0.1), (w + 0.04, d + 0.04, 0.04), m["steel_dark"], radius=0.01, rot=(0, 0, rot))
    for dx in (-w / 2 + 0.08, w / 2 - 0.08):
        for dy in (-d / 2 + 0.08, d / 2 - 0.08):
            b.cyl(b._xf((dx, dy, 0), (x, y, z + 0.05), (0, 0, rot)), 0.045, 0.04, m["rubber"], axis='X', segs=8, rot=(0, 0, rot))


def workbench(b, base, m, length=2.4, rot=0.0):
    """Ahşap tablalı tezgâh + mengene + raf."""
    x, y, z = base
    soft_box(b, (x, y, z + 0.92), (length, 0.75, 0.07), m["wood"], radius=0.015, rot=(0, 0, rot))
    for dx in (-length / 2 + 0.08, length / 2 - 0.08):
        for dy in (-0.3, 0.3):
            b.box(b._xf((dx, dy, 0), (x, y, z + 0.45), (0, 0, rot)), (0.06, 0.06, 0.9), m["steel_dark"], rot=(0, 0, rot))
    soft_box(b, (x, y, z + 0.25), (length - 0.1, 0.65, 0.04), m["wood_dark"], radius=0.01, rot=(0, 0, rot))
    # mengene
    vx = b._xf((length / 2 - 0.35, -0.3, 0), (x, y, z + 1.02), (0, 0, rot))
    soft_box(b, vx, (0.22, 0.16, 0.12), m["blue"], radius=0.02, rot=(0, 0, rot))
    b.cyl(b._xf((length / 2 - 0.35, -0.42, 0), (x, y, z + 1.0), (0, 0, rot)), 0.015, 0.2, m["chrome"], axis='Y', segs=6, rot=(0, 0, rot))


def pegboard(b, center, m, w=1.8, h=1.0, rot=0.0, seed=3):
    """Delikli alet panosu + asılı aletler (anahtar, çekiç, pense)."""
    r = random.Random(seed)
    soft_box(b, center, (w, 0.03, h), m["wood_light"], radius=0.01, rot=(0, 0, rot))
    cols = ["red", "blue", "steel", "yellow", "black"]
    for i in range(14):
        dx = r.uniform(-w / 2 + 0.12, w / 2 - 0.12)
        dz = r.uniform(-h / 2 + 0.15, h / 2 - 0.12)
        p = b._xf((dx, -0.03, dz), center, (0, 0, rot))
        kind = r.random()
        if kind < 0.45:   # anahtar
            b.box(p, (0.03, 0.015, r.uniform(0.18, 0.3)), m["chrome"], rot=(0, r.uniform(-12, 12), rot))
        elif kind < 0.7:  # çekiç
            b.box(p, (0.03, 0.02, 0.26), m["wood"], rot=(0, 0, rot))
            b.box(b._xf((0, 0, 0.13), p, (0, 0, rot)), (0.12, 0.03, 0.04), m["steel_dark"], rot=(0, 0, rot))
        else:             # saplı alet (pense / tornavida)
            b.box(p, (0.025, 0.02, 0.12), m[r.choice(cols)], rot=(0, r.uniform(-8, 8), rot))
            b.box(b._xf((0, 0, 0.1), p, (0, 0, rot)), (0.012, 0.012, 0.12), m["chrome"], rot=(0, 0, rot))


def shelf_unit(b, base, m, w=1.4, d=0.45, h=1.9, rot=0.0, seed=5, fill=True):
    """Metal raf + üstünde kutular, yağ bidonları."""
    r = random.Random(seed)
    x, y, z = base
    for dx in (-w / 2, w / 2):
        for dy in (-d / 2, d / 2):
            b.box(b._xf((dx, dy, 0), (x, y, z + h / 2), (0, 0, rot)), (0.04, 0.04, h), m["steel_dark"], rot=(0, 0, rot))
    levels = [0.12, 0.62, 1.12, 1.62]
    for lz in levels:
        b.box((x, y, z + lz), (w, d, 0.025), m["steel"], rot=(0, 0, rot))
        if not fill:
            continue
        cx = -w / 2 + 0.12
        while cx < w / 2 - 0.15:
            kind = r.random()
            if kind < 0.45:
                bw = r.uniform(0.22, 0.38)
                bh = r.uniform(0.18, 0.34)
                soft_box(b, b._xf((cx + bw / 2, 0, 0), (x, y, z + lz + 0.012 + bh / 2), (0, 0, rot)), (bw, d * 0.8, bh),
                         m["cardboard"], radius=0.01, rot=(0, 0, rot + r.uniform(-4, 4)))
                cx += bw + 0.04
            elif kind < 0.8:
                col = r.choice(["red", "blue", "yellow", "green"])
                b.cyl(b._xf((cx + 0.07, 0, 0), (x, y, z + lz + 0.13), (0, 0, rot)), 0.065, 0.24, m[col], segs=10)
                cx += 0.17
            else:
                cx += 0.2


def hanging_bulb(b, top, m, drop=1.0):
    """Tavandan kabloyla sarkan çıplak ampul (IŞIKLAR sv.1)."""
    x, y, z = top
    b.cyl((x, y, z - drop / 2), 0.008, drop, m["black"], segs=5)
    b.cyl((x, y, z - drop - 0.03), 0.035, 0.06, m["black"], segs=8)
    b.ball((x, y, z - drop - 0.11), 0.065, m["bulb"], segs=10, rings=7)


def fluorescent(b, center, m, length=1.5, rot=0.0):
    """Çift tüplü floresan armatür (IŞIKLAR sv.2)."""
    x, y, z = center
    soft_box(b, (x, y, z + 0.04), (length + 0.1, 0.22, 0.06), m["white"], radius=0.012, rot=(0, 0, rot))
    for dy in (-0.05, 0.05):
        b.cyl(b._xf((0, dy, 0), (x, y, z - 0.015), (0, 0, rot)), 0.022, length, m["tube"], axis='X', segs=8, rot=(0, 0, rot))
    for s in (-1, 1):
        b.cyl(b._xf((s * length * 0.35, 0, 0), (x, y, z + 0.4), (0, 0, rot)), 0.004, 0.7, m["steel_dark"], segs=4)


def led_panel(b, center, m, size=(1.2, 0.6), rot=0.0):
    """Gömme LED panel (IŞIKLAR sv.3)."""
    x, y, z = center
    soft_box(b, (x, y, z + 0.025), (size[0] + 0.06, size[1] + 0.06, 0.05), m["white"], radius=0.01, rot=(0, 0, rot))
    plane(b, (x, y, z - 0.002), size, m["led"], rot=(180, 0, rot))


def spot_lamp(b, mount, aim, m):
    """Raya asılı spot (IŞIKLAR sv.3): gövde aim yönüne bakar, ağzında ışıklı mercek."""
    dx, dy, dz = aim[0] - mount[0], aim[1] - mount[1], aim[2] - mount[2]
    yaw = math.degrees(math.atan2(dy, dx))
    pitch = -math.degrees(math.atan2(dz, math.hypot(dx, dy)))
    b.cyl(mount, 0.07, 0.2, m["black"], axis='X', segs=10, rot=(0, pitch, yaw), r2=0.09)
    lens = b._xf((0.105, 0, 0), mount, (0, pitch, yaw))
    b.cyl(lens, 0.082, 0.01, m["led"], axis='X', segs=10, rot=(0, pitch, yaw))


def floor_jack(b, base, m, rot=0.0):
    """Timsah kriko (LİFT sv.1)."""
    x, y, z = base
    soft_box(b, (x, y, z + 0.1), (0.9, 0.32, 0.14), m["red"], radius=0.03, rot=(0, 0, rot))
    b.box(b._xf((0.45, 0, 0), (x, y, z + 0.2), (0, 0, rot)), (0.18, 0.18, 0.08), m["red_dark"], rot=(0, 25, rot))
    b.tube([b._xf((-0.4, 0, 0), (x, y, z + 0.16), (0, 0, rot)), b._xf((-1.1, 0, 0), (x, y, z + 0.75), (0, 0, rot))],
           0.02, m["chrome"])
    for dx, dy in ((0.35, 0.18), (0.35, -0.18), (-0.35, 0.18), (-0.35, -0.18)):
        b.cyl(b._xf((dx, dy, 0), (x, y, z + 0.05), (0, 0, rot)), 0.05, 0.04, m["rubber"], axis='Y', segs=8, rot=(0, 0, rot))


def jack_stand(b, base, m):
    x, y, z = base
    b.cyl((x, y, z + 0.18), 0.03, 0.36, m["red"], segs=8)
    for a in (0, 120, 240):
        b.tube([(x, y, z + 0.2), (x + 0.22 * math.cos(math.radians(a)), y + 0.22 * math.sin(math.radians(a)), z + 0.01)],
               0.018, m["red_dark"])
    b.box((x, y, z + 0.38), (0.1, 0.06, 0.04), m["steel_dark"])


def two_post_lift(b, center, m, rot=0.0, width=3.0, height=2.9, bridge=True):
    """İki kolonlu lift (LİFT sv.2): kolonlar, kollar, (isteğe bağlı) üst köprü. Maket kamerasında köprü öndeki
    aracın önüne kapı gibi düşüyordu: bridge=False ile taban plakalı köprüsüz model."""
    x, y, z = center
    for s in (-1, 1):
        p = b._xf((0, s * width / 2, 0), (x, y, z), (0, 0, rot))
        soft_box(b, (p[0], p[1], z + height / 2), (0.32, 0.32, height), m["red"], radius=0.03, rot=(0, 0, rot))
        soft_box(b, (p[0], p[1], z + 0.04), (0.6, 0.6, 0.08), m["steel_dark"], radius=0.02, rot=(0, 0, rot))
        for k in (-1, 1):
            arm = b._xf((k * 0.55, s * (width / 2 - 0.55), 0), (x, y, z + 0.22), (0, 0, rot))
            soft_box(b, arm, (1.1, 0.12, 0.08), m["steel"], radius=0.015, rot=(0, 0, rot + k * s * 20))
            b.cyl(b._xf((k * 1.05, s * (width / 2 - 0.75), 0), (x, y, z + 0.3), (0, 0, rot)), 0.07, 0.08, m["rubber"], segs=10)
    if bridge:
        top = b._xf((0, 0, 0), (x, y, z + height + 0.05), (0, 0, rot))
        soft_box(b, top, (0.22, width + 0.3, 0.2), m["red_dark"], radius=0.02, rot=(0, 0, rot))
        b.box(b._xf((0, 0, 0), (x, y, z + height - 0.15), (0, 0, rot)), (0.05, width, 0.05), m["yellow"], rot=(0, 0, rot))
    else:   # taban plakası: iki kolonu yerden bağlar
        soft_box(b, b._xf((0, 0, 0), (x, y, z + 0.03), (0, 0, rot)), (0.5, width, 0.06), m["yellow"], radius=0.02, rot=(0, 0, rot))


def four_post_lift(b, center, m, rot=0.0, length=5.2, width=2.6, lift=0.9):
    """Dört kolonlu sergileme lifti (LİFT sv.3): sürüş rampaları, LED şerit."""
    x, y, z = center
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = b._xf((sx * length / 2, sy * width / 2, 0), (x, y, z), (0, 0, rot))
            soft_box(b, (p[0], p[1], z + 1.2), (0.26, 0.26, 2.4), m["blue"], radius=0.03, rot=(0, 0, rot))
            soft_box(b, (p[0], p[1], z + 2.42), (0.32, 0.32, 0.05), m["steel_dark"], radius=0.01, rot=(0, 0, rot))
    for sy in (-1, 1):
        rail = b._xf((0, sy * 0.62, 0), (x, y, z + lift), (0, 0, rot))
        soft_box(b, rail, (length - 0.2, 0.55, 0.1), m["steel"], radius=0.02, rot=(0, 0, rot))
        plane(b, b._xf((0, sy * 0.62 - sy * 0.28, 0), (x, y, z + lift + 0.051), (0, 0, rot)), (length - 0.3, 0.03), m["led"],
              rot=(0, 0, rot))
    for sx in (-1, 1):
        cross = b._xf((sx * (length / 2 - 0.15), 0, 0), (x, y, z + lift - 0.05), (0, 0, rot))
        soft_box(b, cross, (0.25, width, 0.14), m["blue"], radius=0.02, rot=(0, 0, rot))


def roll_shutter(b, origin, width, height, open_frac, m, rot=0.0):
    """Kepenk: üstte sarılı kutu + aşağı inen oluklu perde (open_frac 1 = tamamen açık)."""
    x, y, z = origin
    soft_box(b, b._xf((width / 2, 0, 0), (x, y, z + height + 0.18), (0, 0, rot)), (width + 0.3, 0.42, 0.36), m["steel_dark"],
             radius=0.04, rot=(0, 0, rot))
    curtain = height * (1.0 - open_frac)
    if curtain > 0.05:
        b.corrugated(b._xf((0, 0.05, 0), (x, y, z + height - curtain), (0, 0, rot)), width, curtain, m["steel"],
                     period=0.12, depth=0.015, rot=(0, 0, rot), along='X')
        soft_box(b, b._xf((width / 2, 0.05, 0), (x, y, z + height - curtain), (0, 0, rot)), (width, 0.08, 0.06), m["steel_dark"],
                 radius=0.01, rot=(0, 0, rot))


def potted_plant(b, base, m, h=0.9, seed=2):
    r = random.Random(seed)
    x, y, z = base
    b.cyl((x, y, z + 0.18), 0.2, 0.36, m["pot"], segs=12, r2=0.24)
    for i in range(9):
        a = r.uniform(0, math.tau)
        rr = r.uniform(0.05, 0.22)
        b.ball((x + math.cos(a) * rr, y + math.sin(a) * rr, z + 0.36 + r.uniform(0.15, h - 0.2)), r.uniform(0.12, 0.2),
               m["plant"], segs=7, rings=5)


def sleeping_cat(b, base, m, rot=0.0):
    """Mahalle kedisi: kıvrılmış uyuyan gövde + baş + kuyruk."""
    x, y, z = base
    b.ball((x, y, z + 0.09), 0.17, m["cat"], segs=10, rings=7, scale=(1.0, 0.75, 0.55), rot=(0, 0, rot))
    head = b._xf((0.15, 0.08, 0), (x, y, z + 0.12), (0, 0, rot))
    b.ball(head, 0.085, m["cat"], segs=9, rings=6)
    for s in (-1, 1):
        ear = b._xf((0.17, 0.08 + s * 0.045, 0), (x, y, z + 0.2), (0, 0, rot))
        b.cyl(ear, 0.025, 0.05, m["cat"], segs=4, r2=0.002)
    b.tube([b._xf((-0.15, -0.05, 0), (x, y, z + 0.05), (0, 0, rot)), b._xf((-0.05, -0.17, 0), (x, y, z + 0.04), (0, 0, rot)),
            b._xf((0.1, -0.15, 0), (x, y, z + 0.04), (0, 0, rot))], 0.03, m["cat"], segs=6)


def old_sofa(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.25), (1.9, 0.85, 0.32), m["fabric"], radius=0.08, rot=(0, 0, rot))
    soft_box(b, b._xf((0, 0.33, 0), (x, y, z + 0.6), (0, 0, rot)), (1.9, 0.22, 0.6), m["fabric"], radius=0.08, rot=(0, 0, rot))
    for s in (-1, 1):
        soft_box(b, b._xf((s * 0.88, 0, 0), (x, y, z + 0.48), (0, 0, rot)), (0.22, 0.85, 0.36), m["fabric"], radius=0.07,
                 rot=(0, 0, rot))
    for dx in (-0.45, 0.45):
        soft_box(b, b._xf((dx, -0.02, 0), (x, y, z + 0.46), (0, 0, rot)), (0.86, 0.66, 0.12), m["fabric"], radius=0.05,
                 rot=(0, 0, rot))


def poster(b, center, size, m, colors, rot=0.0, seed=1):
    """Duvar posteri: zemin + basit araç silueti / şerit (yazısız; oyun dili bağımsız)."""
    r = random.Random(seed)
    plane(b, center, size, m[colors[0]], rot=(90, 0, rot))
    off = b._xf((0, -0.004, 0), center, (0, 0, rot))
    plane(b, b._xf((0, 0, -size[1] * 0.18), off, (0, 0, rot)), (size[0] * 0.7, size[1] * 0.22), m[colors[1]], rot=(90, 0, rot))
    plane(b, b._xf((0, 0, -size[1] * 0.02), off, (0, 0, rot)), (size[0] * 0.42, size[1] * 0.16), m[colors[1]], rot=(90, 0, rot))
    plane(b, b._xf((0, 0, size[1] * 0.3), off, (0, 0, rot)), (size[0] * 0.8, size[1] * 0.08), m[colors[2]], rot=(90, 0, rot))


def blob(b, center, radius, material, rot=(90, 0, 0), seed=1, points=11, jag=0.35):
    """Düzensiz kenarlı yama (dökülmüş sıva, nem lekesi): yıldızımsı çokgen, tek yüz."""
    r = random.Random(seed)
    pts = []
    for i in range(points):
        a = math.tau * i / points
        k = 1.0 + r.uniform(-jag, jag)
        pts.append((math.cos(a) * radius[0] * k, math.sin(a) * radius[1] * k, 0.0))
    v = [b._xf(p, center, rot) for p in [(0.0, 0.0, 0.0)] + pts]
    f = [(0, 1 + i, 1 + (i + 1) % points) for i in range(points)]
    b._add(v, f, material)


def extinguisher(b, base, m):
    x, y, z = base
    b.cyl((x, y, z + 0.3), 0.09, 0.5, m["red"], segs=12)
    b.ball((x, y, z + 0.56), 0.09, m["red"], segs=10, rings=5)
    b.cyl((x, y, z + 0.66), 0.03, 0.08, m["black"], segs=8)
    b.tube([(x, y, z + 0.68), (x + 0.12, y - 0.05, z + 0.62), (x + 0.12, y - 0.06, z + 0.3)], 0.012, m["black"])


def wall_clock(b, center, m, rot=0.0):
    b.cyl(center, 0.2, 0.05, m["white"], axis='Y', segs=20, rot=(0, 0, rot))
    b.cyl(b._xf((0, 0.0, 0), center, (0, 0, rot)), 0.215, 0.04, m["black"], axis='Y', segs=20, rot=(0, 0, rot), r2=0.215)
    plane(b, b._xf((0.0, -0.03, 0.05), center, (0, 0, rot)), (0.015, 0.12), m["black"], rot=(90, 0, rot))
    plane(b, b._xf((0.04, -0.03, 0.0), center, (0, 0, rot)), (0.09, 0.012), m["black"], rot=(90, 0, rot))


def hose_reel(b, center, m, rot=0.0):
    b.cyl(center, 0.26, 0.12, m["yellow"], axis='Y', segs=16, rot=(0, 0, rot))
    b.cyl(center, 0.18, 0.13, m["black"], axis='Y', segs=16, rot=(0, 0, rot))
    b.tube([b._xf((0.1, -0.1, -0.2), center, (0, 0, rot)), b._xf((0.25, -0.3, -0.9), center, (0, 0, rot)),
            b._xf((0.1, -0.5, -1.4), center, (0, 0, rot))], 0.015, m["black"])


def radio(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.11), (0.38, 0.14, 0.22), m["red_dark"], radius=0.03, rot=(0, 0, rot))
    b.cyl(b._xf((-0.08, -0.075, 0), (x, y, z + 0.1), (0, 0, rot)), 0.065, 0.02, m["black"], axis='Y', segs=12, rot=(0, 0, rot))
    plane(b, b._xf((0.09, -0.072, 0), (x, y, z + 0.12), (0, 0, rot)), (0.12, 0.06), m["bulb"], rot=(90, 0, rot))
    b.tube([b._xf((0.15, 0, 0.2), (x, y, z), (0, 0, rot)), b._xf((0.3, 0.05, 0.55), (x, y, z), (0, 0, rot))], 0.006, m["chrome"])


def broom(b, base, m, lean=12.0, rot=0.0):
    x, y, z = base
    b.cyl(b._xf((0, 0, 0.7), (x, y, z), (lean, 0, rot)), 0.015, 1.3, m["wood_light"], segs=6, rot=(lean, 0, rot))
    soft_box(b, (x, y, z + 0.07), (0.3, 0.06, 0.14), m["yellow"], radius=0.01, rot=(lean, 0, rot))


def light_beam(col, name, start_rect, direction, length, color, strength=0.6):
    """Görünür ışık huzmesi: dikdörtgen ağızdan `direction` boyunca uzanan, uca doğru solan saydam prizma.
    Oyunda ışıksız KATKILI çizilir (köşe alfası = yoğunluk); önizlemede ışıyan + saydam karışım."""
    import mathutils
    d = mathutils.Vector(direction).normalized()
    bm = bmesh.new()
    alpha = bm.loops.layers.float_color.new("Col")
    a = [mathutils.Vector(p) for p in start_rect]
    bpts = [p + d * length for p in a]
    va = [bm.verts.new(p) for p in a]
    vb = [bm.verts.new(p) for p in bpts]
    for i in range(4):
        j = (i + 1) % 4
        f = bm.faces.new([va[i], va[j], vb[j], vb[i]])
        for loop in f.loops:
            t = 1.0 if loop.vert in va else 0.0
            loop[alpha] = (color[0], color[1], color[2], t * strength)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    mat = bpy.data.materials.get("G_Beam") or bpy.data.materials.new("G_Beam")
    if not mat.get("g_beam"):
        mat.use_nodes = True
        nt = mat.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        vc = nt.nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.6
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        add = nt.nodes.new("ShaderNodeAddShader")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(vc.outputs["Color"], em.inputs["Color"])
        nt.links.new(vc.outputs["Alpha"], mix.inputs["Fac"])
        nt.links.new(tr.outputs["BSDF"], mix.inputs[1])
        nt.links.new(em.outputs["Emission"], add.inputs[0])
        nt.links.new(tr.outputs["BSDF"], add.inputs[1])
        nt.links.new(add.outputs["Shader"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        mat.use_backface_culling = False
        mat["g_beam"] = True
    me.materials.append(mat)
    o["g_beam"] = True
    o.visible_shadow = False
    return o


# --- Önizleme ortakları (mahalle.py, rooftop.py …) ----------------------------------------------

def new_col(name, parent=None):
    col = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(col)
    return col


def _save_image(name, rgb, path):
    """Doğrusal renk → sRGB kodlu PNG (oyunda da standart renkli doku olarak içe aktarılır)."""
    import numpy as np
    h, w, _ = rgb.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    lin = np.clip(rgb, 0, 1)
    srgb = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = srgb
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def _noise(shape, scale, seed):
    import numpy as np
    rng = np.random.default_rng(seed)
    h, w = shape
    gh, gw = max(2, int(h / scale) + 2), max(2, int(w / scale) + 2)
    grid = rng.random((gh, gw)).astype(np.float32)
    ys = np.linspace(0, gh - 1.001, h)
    xs = np.linspace(0, gw - 1.001, w)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]; b_ = grid[y0][:, x0 + 1]; c = grid[y0 + 1][:, x0]; d = grid[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b_ * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def _fbm(shape, base, seed, octaves=4):
    out = 0.0
    amp = 1.0
    total = 0.0
    for i in range(octaves):
        out = out + _noise(shape, base / (2 ** i), seed + i) * amp
        total += amp
        amp *= 0.5
    return out / total


def _hex(h):
    return [c for c in k_srgb(h)]


def aim(obj, target):
    """Işık / kamera yerel -Z'si hedefe baksın."""
    from mathutils import Vector
    d = Vector(target) - Vector(obj.location)
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def place_cars(slots, ids, col_name="Cars_Preview"):
    """Oyunun gerçek araçlarını (optimized GLB) park yerlerine gerçek boyutta koyar (önizleme). slots: (x, y, yön°)."""
    cars = {c["id"]: c for c in json.load(open(os.path.join(REPO, "vehicles", "cars.json")))["cars"]}
    col = new_col(col_name)
    for i, cid in enumerate(ids):
        entry = cars[cid]
        path = os.path.join(REPO, entry["optimized_path"].replace("res://", ""))
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        holder = bpy.data.objects.new("Car_%s" % cid, None)
        col.objects.link(holder)
        for o in new:
            for c in o.users_collection:
                c.objects.unlink(o)
            col.objects.link(o)
            if o.parent is None:
                o.parent = holder
        x, y, rot = slots[i][0], slots[i][1], slots[i][2]
        z = slots[i][3] if len(slots[i]) > 3 else 0.0
        s = float(entry.get("model_scale", 1.0)) * 4.39
        holder.scale = (s, s, s)
        holder.location = (x, y, z)
        holder.rotation_euler = (0, 0, math.radians(rot))
    return col




def render(out, width, height, samples):
    scn = bpy.context.scene
    scn.render.engine = 'CYCLES'
    scn.cycles.device = 'CPU'
    scn.cycles.samples = samples
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 4
    scn.view_settings.view_transform = 'AgX'
    scn.view_settings.look = 'AgX - Punchy' if 'AgX - Punchy' in [i.identifier for i in
        bpy.types.ColorManagedViewSettings.bl_rna.properties["look"].enum_items] else 'None'
    scn.render.filepath = out
    bpy.ops.render.render(write_still=True)




# --- Seviyeli garaj sahneleri ortakları (mahalle.py, sanayi.py …) ----------------------------------

def floor_object(col, name, tex_path, size):
    """Dokulu zemin düzlemi (0,0)–size, UV 0..1 (zemin dokusu doğrusal üretilip sRGB kaydedilir)."""
    W, D = size
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in [(0, 0, 0), (W, 0, 0), (W, D, 0), (0, D, 0)]]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, c in zip(f.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop[uv].uv = c
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    m = bpy.data.materials.new(name + "_mat")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    me.materials.append(m)
    o["jy_textured"] = True
    return o


def slot_lines(b, m, slot, color="white", ln=5.0, wd=2.65):
    """Park yeri çizgileri: iki yan + arka (araç burnu -Y'ye; arka çizgi +Y'de)."""
    x, y, rot = slot[0], slot[1], slot[2]
    for s in (-1, 1):
        p = b._xf((s * wd / 2, 0, 0), (x, y, 0.006), (0, 0, rot))
        plane(b, p, (0.08, ln), m[color], rot=(0, 0, rot))
    plane(b, b._xf((0, ln / 2, 0), (x, y, 0.006), (0, 0, rot)), (wd, 0.08), m[color], rot=(0, 0, rot))


def markers(col, slots):
    """Park yerleri: Slot_<i> boş nesneleri (oyunda araç burnu düğümün +Z'sine = Blender -Y'sine bakar)."""
    for i, (x, y, rot) in enumerate(slots):
        e = bpy.data.objects.new("Slot_%d" % i, None)
        e.empty_display_type = 'ARROWS'
        e.location = (x, y, 0.0)
        e.rotation_euler = (0, 0, math.radians(rot))
        col.objects.link(e)


def show_levels(groups, levels):
    """levels: {"Floor": 1, "Walls": 2, ...} — her kalemden yalnız o seviye görünür (render)."""
    for (item, level), col in groups.items():
        hidden = levels.get(item, 1) != level
        col.hide_render = hidden
        col.hide_viewport = hidden




# --- Sanayi eşyaları (sanayi.py) -------------------------------------------------------------------

def smats():
    """Sanayi garajı ek renkleri."""
    return {
        "sheet_rust": k_mat("s_sheet_rust", "#7E5A44", rough=0.9, metal=0.3),
        "sheet_grey": k_mat("s_sheet_grey", "#8A8F93", rough=0.7, metal=0.4),
        "sheet_navy": k_mat("s_sheet_navy", "#2C3E5C", rough=0.7, metal=0.3),
        "panel_white": k_mat("s_panel_white", "#E4E6E8", rough=0.75),
        "block": k_mat("s_block", "#9C978E", rough=0.95),
        "beam_yellow": k_mat("s_beam_yellow", "#E8AE21", rough=0.6, metal=0.3),
        "beam_grey": k_mat("s_beam_grey", "#4A5057", rough=0.6, metal=0.5),
        "orange": k_mat("s_orange", "#E2702A", rough=0.6, metal=0.2),
        "sodium": k_mat("s_sodium", "#FFB257", rough=0.5, emit="#FF9A3A", strength=8.0),
        "pallet": k_mat("s_pallet", "#B58B57", rough=0.9),
        "crate": k_mat("s_crate", "#8D6B43", rough=0.9),
        "tarp": k_mat("s_tarp", "#3D5F7A", rough=0.95),
        "rim": k_mat("s_rim", "#C7CCD1", rough=0.3, metal=0.85),
        "glass_dark": k_mat("s_glass_dark", "#3E5664", rough=0.15),
        "window_day": k_mat("s_window_day", "#DCEBFF", rough=0.5, emit="#E6F0FF", strength=3.0),
    }


def i_column(b, base, height, m, color="beam_grey", rot=0.0, w=0.3):
    """Çelik I-profil kolon + sarı-siyah taban koruması."""
    x, y, z = base
    for s in (-1, 1):
        b.box(b._xf((0, s * w * 0.45, 0), (x, y, z + height / 2), (0, 0, rot)), (w, 0.03, height), m[color], rot=(0, 0, rot))
    b.box((x, y, z + height / 2), (0.03, w * 0.9, height), m[color], rot=(0, 0, rot))
    for i in range(4):
        b.box((x, y, z + 0.12 + i * 0.25), (w + 0.06, w + 0.06, 0.12), m["beam_yellow"] if i % 2 == 0 else m["black"],
              rot=(0, 0, rot))


def gantry_crane(b, y, x0, x1, height, m, hook_x=None):
    """Tavan vinci: iki yan ray kirişi üstünde enine sarı köprü, araba, halat, kanca bloğu."""
    span = x1 - x0
    soft_box(b, ((x0 + x1) / 2, y, height), (span, 0.5, 0.55), m["beam_yellow"], radius=0.03)
    for s in (-1, 1):
        soft_box(b, (x0 + 0.3 if s < 0 else x1 - 0.3, y, height - 0.05), (0.6, 1.2, 0.4), m["beam_yellow"], radius=0.03)
    hx = hook_x if hook_x is not None else x0 + span * 0.62
    soft_box(b, (hx, y, height - 0.45), (0.7, 0.8, 0.45), m["black"], radius=0.04)
    for s in (-0.08, 0.08):
        b.cyl((hx + s, y, height - 1.6), 0.012, 2.3, m["steel"], segs=5)
    soft_box(b, (hx, y, height - 2.85), (0.32, 0.22, 0.4), m["beam_yellow"], radius=0.05)
    b.tube([(hx, y, height - 3.05), (hx + 0.08, y, height - 3.25), (hx, y, height - 3.38), (hx - 0.07, y, height - 3.28)], 0.03,
           m["steel_dark"])


def forklift(b, base, m, rot=0.0):
    """Forklift: gövde, kabin kafesi, direk, çatallar, tekerler."""
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.62), (1.15, 2.0, 0.7), m["orange"], radius=0.1, rot=(0, 0, rot))
    soft_box(b, p(0, 0.75, 0.75), (1.05, 0.55, 0.9), m["black"], radius=0.12, rot=(0, 0, rot))   # karşı ağırlık
    soft_box(b, p(0, 0.05, 1.08), (0.5, 0.5, 0.18), m["black"], radius=0.06, rot=(0, 0, rot))     # koltuk
    for sx in (-0.5, 0.5):
        for sy in (-0.55, 0.55):
            b.cyl(p(sx, sy, 1.55), 0.035, 1.6, m["black"], segs=6)
    soft_box(b, p(0, 0.0, 2.33), (1.1, 1.25, 0.06), m["black"], radius=0.02, rot=(0, 0, rot))
    for sx in (-0.32, 0.32):
        b.box(p(sx, -1.05, 1.4), (0.09, 0.12, 2.6), m["steel_dark"], rot=(0, 0, rot))
    soft_box(b, p(0, -1.12, 0.35), (0.9, 0.08, 0.5), m["steel_dark"], radius=0.01, rot=(0, 0, rot))
    for sx in (-0.28, 0.28):
        b.box(p(sx, -1.7, 0.08), (0.12, 1.15, 0.05), m["steel_dark"], rot=(0, 0, rot))
    for sx in (-0.55, 0.55):
        for sy, r in ((-0.6, 0.32), (0.7, 0.26)):
            tire(b, p(sx, sy, r), rot=(0, 90, rot), r=r, w=0.22, m=m)


def engine_hoist(b, base, m, rot=0.0):
    """Motor vinci (kırmızı): ayaklar, kolon, kol, zincir, asılı motor bloğu."""
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    for sx in (-0.4, 0.4):
        b.box(p(sx, -0.5, 0.06), (0.09, 1.4, 0.09), m["red"], rot=(0, 0, rot))
        b.cyl(p(sx, -1.15, 0.05), 0.05, 0.05, m["rubber"], axis='X', segs=8, rot=(0, 0, rot))
    b.box(p(0, 0.15, 0.06), (0.9, 0.1, 0.09), m["red"], rot=(0, 0, rot))
    b.box(p(0, 0.15, 0.85), (0.1, 0.1, 1.6), m["red"], rot=(0, 0, rot))
    b.tube([p(0, 0.15, 1.6), p(0, -0.9, 1.95)], 0.05, m["red"], segs=6)
    b.tube([p(0, 0.15, 0.7), p(0, -0.35, 1.75)], 0.035, m["chrome"], segs=6)
    b.cyl(p(0, -0.9, 1.6), 0.01, 0.6, m["steel"], segs=4)
    soft_box(b, p(0, -0.9, 1.05), (0.55, 0.5, 0.5), m["steel_dark"], radius=0.05, rot=(0, 0, rot))


def engine_stand(b, base, m, rot=0.0):
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    b.box(p(0, 0, 0.05), (0.7, 0.1, 0.08), m["blue"], rot=(0, 0, rot))
    b.box(p(0, 0.3, 0.05), (0.1, 0.7, 0.08), m["blue"], rot=(0, 0, rot))
    b.box(p(0, 0, 0.45), (0.08, 0.08, 0.8), m["blue"], rot=(0, 0, rot))
    soft_box(b, p(0, -0.35, 0.75), (0.5, 0.6, 0.45), m["engine_rust"] if "engine_rust" in m else m["steel_dark"], radius=0.05,
             rot=(0, 0, rot))


def compressor(b, base, m, rot=0.0):
    x, y, z = base
    b.cyl(b._xf((0, 0, 0), (x, y, z + 0.45), (0, 0, rot)), 0.32, 1.3, m["red"], axis='X', segs=14, rot=(0, 0, rot))
    soft_box(b, (x, y, z + 0.95), (0.5, 0.4, 0.3), m["black"], radius=0.04, rot=(0, 0, rot))
    for dx in (-0.45, 0.45):
        b.box(b._xf((dx, 0, 0), (x, y, z + 0.08), (0, 0, rot)), (0.08, 0.5, 0.16), m["black"], rot=(0, 0, rot))


def welding_cart(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.5), (0.5, 0.7, 0.6), m["blue"], radius=0.04, rot=(0, 0, rot))
    for dy in (-0.15, 0.15):
        b.cyl(b._xf((0.0, dy, 0), (x, y, z + 1.2), (0, 0, rot)), 0.11, 1.0, m["green"] if dy < 0 else m["steel"], segs=10)
    b.tube([b._xf((0.25, 0.3, 0.7), (x, y, z), (0, 0, rot)), b._xf((0.6, 0.6, 0.2), (x, y, z), (0, 0, rot)),
            b._xf((0.9, 0.3, 0.02), (x, y, z), (0, 0, rot))], 0.015, m["black"])


def pallet(b, base, m, rot=0.0):
    x, y, z = base
    for dy in (-0.45, 0.0, 0.45):
        b.box(b._xf((0, dy, 0), (x, y, z + 0.05), (0, 0, rot)), (1.2, 0.1, 0.1), m["pallet"], rot=(0, 0, rot))
    for dx in range(7):
        b.box(b._xf((-0.55 + dx * 0.183, 0, 0), (x, y, z + 0.12), (0, 0, rot)), (0.12, 1.0, 0.025), m["pallet"], rot=(0, 0, rot))


def crate(b, center_base, size, m, rot=0.0, tarp=False):
    x, y, z = center_base
    soft_box(b, (x, y, z + size[2] / 2), size, m["tarp"] if tarp else m["crate"], radius=0.02 if not tarp else 0.08,
             rot=(0, 0, rot))
    if not tarp:
        for s in (-1, 1):
            b.box(b._xf((s * (size[0] / 2 - 0.05), -size[1] / 2 - 0.01, 0), (x, y, z + size[2] / 2), (0, 0, rot)),
                  (0.08, 0.02, size[2] - 0.04), m["wood_dark"], rot=(0, 0, rot))
        b.box(b._xf((0, -size[1] / 2 - 0.012, 0), (x, y, z + size[2] / 2), (0, 0, rot)), (size[0] - 0.1, 0.02, 0.08),
              m["wood_dark"], rot=(0, 0, rot))


def high_bay(b, top, m, kind, drop=1.2):
    """Yüksek tavan lambası: sodyum (turuncu çan), floresan (çift tüp), LED (yassı daire)."""
    x, y, z = top
    b.cyl((x, y, z - drop / 2), 0.012, drop, m["black"], segs=5)
    if kind == "sodium":
        b.cyl((x, y, z - drop - 0.2), 0.12, 0.35, m["steel_dark"], segs=10, r2=0.08)
        b.cyl((x, y, z - drop - 0.45), 0.36, 0.25, m["steel_dark"], segs=14, r2=0.14)
        b.cyl((x, y, z - drop - 0.58), 0.33, 0.02, m["sodium"], segs=14)
    elif kind == "tube":
        soft_box(b, (x, y, z - drop - 0.05), (2.2, 0.32, 0.08), m["white"], radius=0.015)
        for dy in (-0.07, 0.07):
            b.cyl((x, y + dy, z - drop - 0.11), 0.026, 2.1, m["tube"], axis='X', segs=8)
    else:
        b.cyl((x, y, z - drop - 0.05), 0.45, 0.08, m["white"], segs=20)
        b.cyl((x, y, z - drop - 0.1), 0.4, 0.02, m["led"], segs=20)


def scissor_lift(b, center, m, rot=0.0, length=4.8, width=2.2, up=0.55):
    """Makaslı rot-balans lifti (LİFT sv.3): iki platform, makas kolları, LED kenar."""
    x, y, z = center
    for s in (-1, 1):
        plat = b._xf((0, s * 0.62, 0), (x, y, z + up), (0, 0, rot))
        soft_box(b, plat, (length, 0.6, 0.12), m["steel"], radius=0.02, rot=(0, 0, rot))
        plane(b, b._xf((0, s * 0.62 + s * 0.31, 0), (x, y, z + up + 0.02), (0, 0, rot)), (length - 0.2, 0.025), m["led"],
              rot=(90, 0, rot + (180 if s < 0 else 0)))
        for k in (-1, 1):
            a = b._xf((-length * 0.3, s * 0.62, 0), (x, y, z + 0.05), (0, 0, rot))
            c = b._xf((length * 0.3, s * 0.62, 0), (x, y, z + up - 0.05), (0, 0, rot))
            if k > 0:
                a, c = (a[0], a[1], c[2]), (c[0], c[1], a[2])
            b.tube([a, c], 0.05, m["red"], segs=6)
    soft_box(b, (x, y, z + 0.03), (length + 0.3, width + 0.2, 0.06), m["steel_dark"], radius=0.02, rot=(0, 0, rot))


def wheel_balancer(b, base, m, rot=0.0):
    x, y, z = base
    soft_box(b, (x, y, z + 0.45), (0.8, 0.7, 0.9), m["blue"], radius=0.06, rot=(0, 0, rot))
    soft_box(b, b._xf((0, 0.1, 0), (x, y, z + 1.0), (0, 0, rot)), (0.7, 0.4, 0.25), m["white"], radius=0.05, rot=(0, 0, rot))
    shaft = b._xf((0.55, 0, 0), (x, y, z + 0.75), (0, 0, rot))
    b.cyl(shaft, 0.03, 0.4, m["chrome"], axis='X', segs=8, rot=(0, 0, rot))
    tire(b, b._xf((0.75, 0, 0), (x, y, z + 0.75), (0, 0, rot)), rot=(0, 90, rot), r=0.32, w=0.22, m=m)


def wheel_rack(b, base, m, rot=0.0, count=8, seed=3):
    """Jant vitrini (DUVAR sv.3): duvara monte raf, dik duran parlak jantlar."""
    r = random.Random(seed)
    x, y, z = base
    for row in range(2):
        rz = z + 0.9 + row * 0.9
        soft_box(b, b._xf((0, 0, 0), (x, y, rz - 0.36), (0, 0, rot)), (count / 2 * 0.62, 0.35, 0.04), m["black"], radius=0.01,
                 rot=(0, 0, rot))
        for i in range(count // 2):
            cx = b._xf((-count / 4 * 0.62 + 0.31 + i * 0.62, 0.0, 0), (x, y, rz), (0, 0, rot))
            b.cyl(cx, 0.3, 0.18, m["rim"] if r.random() > 0.3 else m["black"], axis='Y', segs=16, rot=(0, 0, rot))
            b.cyl(cx, 0.12, 0.2, m["red"] if r.random() > 0.5 else m["steel_dark"], axis='Y', segs=8, rot=(0, 0, rot))


def office_box(b, origin, size, m, rot=0.0):
    """Camlı usta ofisi: alt bant, cam üst yarı, kapı, içeride masa + lamba ışığı."""
    x, y, z = origin
    w, d, h = size
    soft_box(b, (x, y, z + 0.5), (w, d, 1.0), m["block"], radius=0.03)
    for (dx, dy, sw, sd) in ((0, -d / 2, w, 0.06), (-w / 2, 0, 0.06, d)):
        soft_box(b, (x + dx, y + dy, z + 1.0 + (h - 1.0) / 2), (sw, sd, h - 1.0), m["glass_dark"], radius=0.0)
    for i in range(5):
        b.box((x - w / 2 + i * w / 4, y - d / 2, z + h / 2), (0.06, 0.08, h), m["beam_grey"])
    soft_box(b, (x, y, z + h + 0.05), (w + 0.1, d + 0.1, 0.1), m["beam_grey"], radius=0.02)
    soft_box(b, (x + 0.3, y + 0.2, z + 0.75), (1.2, 0.6, 0.05), m["wood"], radius=0.01)
    b.cyl((x + 0.6, y + 0.3, z + 0.95), 0.12, 0.25, m["bulb"], segs=10, r2=0.04)


def pictogram(b, center, m, kind, rot=0.0):
    """İkaz levhası (yazısız): sarı üçgen ünlem / mavi daire / yeşil kare."""
    x, y, z = center
    if kind == "warn":
        v = [b._xf(p, center, (90, 0, rot)) for p in [(-0.25, -0.22, 0), (0.25, -0.22, 0), (0.0, 0.22, 0)]]
        b._add(v, [(0, 1, 2)], m["yellow"])
        plane(b, b._xf((0, -0.004, 0.02), center, (0, 0, rot)), (0.04, 0.16), m["black"], rot=(90, 0, rot))
    elif kind == "info":
        b.cyl(center, 0.22, 0.02, m["blue"], axis='Y', segs=16, rot=(0, 0, rot))
        plane(b, b._xf((0, -0.012, 0), center, (0, 0, rot)), (0.06, 0.22), m["white"], rot=(90, 0, rot))
    else:
        soft_box(b, center, (0.44, 0.02, 0.32), m["green"], radius=0.01, rot=(0, 0, rot))
        plane(b, b._xf((0, -0.012, 0), center, (0, 0, rot)), (0.2, 0.06), m["white"], rot=(90, 0, rot))
