"""HURDALIK ZEMİNİ + ARAZİ — junkyard.py'den exec edilir (W, D, GATE, PLAZA orada tanımlı).

ZEMİN DOKUSU (numpy ile üretilir, assets/world/junkyard_ground.png): sahayı, kapıdan doğuya giden yolu ve
çitin dışındaki şeridi kaplayan tek düzlem. Katmanlar:
  toprak (3 oktav gürültü, açık / koyu yamalar) · çakıl benekleri · lastik izleri (giriş → meydan → vinç /
  pres / batıdaki iskeletler) · çatlaklı, lekeli, derzli beton meydan + solgun park çizgileri · yağ lekeleri
  (gürültüyle bozulmuş kenarlar) · duvar / dağ / konteyner diplerinde koyulaşma · çit diplerinde kuru ot.
ARAZİ: kameraya bakmayan kuzey ve batıda yükselen, tabakalı (mesa) kuru tepeler; güney ve doğu düz.
Renk köşe renginde (oyunda doku gerektirmez), yumuşak gölgeli.
"""
import bpy, bmesh, math, random
import numpy as np

GROUND_PNG = "/home/burak/Projects/car-town-remake/assets/world/junkyard_ground.png"
DESERT = (0.66, 0.56, 0.43)   # çöl düzlüğünün tek rengi (sRGB): dokunun kenarı ve arazinin düz kısmı aynı → dikiş yok
G_X0, G_Y0, G_X1, G_Y1 = -8.0, -12.0, 100.0, 56.0     # dokulu düzlemin kapsadığı alan (m)
G_W, G_H = 3072, 1934                                 # ~3,5 cm / piksel


def _smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def value_noise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    gh, gw = int(h / cell) + 3, int(w / cell) + 3
    g = rng.random((gh, gw)).astype(np.float32)
    ys = np.arange(h, dtype=np.float32) / cell
    xs = np.arange(w, dtype=np.float32) / cell
    y0 = ys.astype(np.int32)
    x0 = xs.astype(np.int32)
    fy = _smooth(ys - y0)[:, None]
    fx = _smooth(xs - x0)[None, :]
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(h, w, cells, seed):
    out = np.zeros((h, w), np.float32)
    total = 0.0
    amp = 1.0
    for k, cell in enumerate(cells):
        out += value_noise(h, w, cell, seed + k * 17) * amp
        total += amp
        amp *= 0.55
    return out / total


def _seg_dist(X, Y, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy or 1e-6
    t = np.clip(((X - ax) * dx + (Y - ay) * dy) / L2, 0.0, 1.0)
    px, py = ax + t * dx, ay + t * dy
    return np.hypot(X - px, Y - py)


def _poly_dist(X, Y, pts):
    d = None
    for a, b in zip(pts[:-1], pts[1:]):
        s = _seg_dist(X, Y, a, b)
        d = s if d is None else np.minimum(d, s)
    return d


def _offset(pts, off):
    """Kırık çizgiyi yan tarafa kaydırır (lastik izinin iki tekerleği)."""
    out = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        out.append((p[0] - dy / L * off, p[1] + dx / L * off))
    return out


def make_ground_texture(W, D, GATE, PLAZA, mounds, stains, tracks, seed=3):
    """Zemin dokusunu üretir ve PNG'ye yazar; Blender image döndürür (sRGB)."""
    h, w = G_H, G_W
    mpp_x = (G_X1 - G_X0) / w
    mpp_y = (G_Y1 - G_Y0) / h
    X = (G_X0 + (np.arange(w, dtype=np.float32) + 0.5) * mpp_x)[None, :].repeat(h, 0)
    Y = (G_Y0 + (np.arange(h, dtype=np.float32) + 0.5) * mpp_y)[:, None].repeat(w, 1)
    rng = np.random.default_rng(seed)
    px_per_m = 1.0 / mpp_x
    # Toprak: büyük yamalar + orta + ince doku
    big = fbm(h, w, [14 * px_per_m, 6 * px_per_m], seed)
    mid = fbm(h, w, [1.6 * px_per_m, 0.6 * px_per_m], seed + 50)
    fine = value_noise(h, w, 0.12 * px_per_m, seed + 90)
    light = np.array((0.70, 0.61, 0.49), np.float32)
    midc = np.array((0.58, 0.49, 0.38), np.float32)
    dark = np.array((0.44, 0.36, 0.28), np.float32)
    t = np.clip(big * 1.3 - 0.15 + (mid - 0.5) * 0.35, 0, 1)[..., None]
    col = dark * (1 - t) + light * t
    col = col * (0.9 + 0.2 * fine[..., None])
    # Saha içi biraz daha koyu ve çiğnenmiş; çit dışı açık çöl
    inside = ((X > 0) & (X < W) & (Y > 0) & (Y < D)).astype(np.float32)[..., None]
    col = col * (1 - 0.12 * inside) + midc * 0.12 * inside
    # Çakıl benekleri
    speck = rng.random((h, w)).astype(np.float32)
    col = np.where((speck > 0.985)[..., None], col * 1.35 + 0.05, col)
    col = np.where((speck < 0.012)[..., None], col * 0.6, col)
    # Yol (kapıdan doğuya) — sıkışmış koyu toprak, kenarlar gürültülü
    road_d = np.abs(Y - (GATE[0] + GATE[1]) / 2)
    road = (_smooth((5.5 - road_d + (mid - 0.5) * 2.0) / 1.5) * (X > W - 2)).astype(np.float32)[..., None]
    col = col * (1 - road * 0.25) + np.array((0.50, 0.42, 0.33), np.float32) * road * 0.25
    # Lastik izleri: her iz iki teker çizgisi
    for pts in tracks:
        for off in (-0.8, 0.8):
            d = _poly_dist(X, Y, _offset(pts, off))
            band = _smooth((0.22 - d) / 0.08) * (0.55 + 0.45 * mid)
            col = col * (1 - 0.28 * band[..., None])
    # Beton meydan: derzler, çatlaklar, lekeler, kırık kenar
    x0, y0, x1, y1 = PLAZA
    edge = np.minimum.reduce([X - x0, x1 - X, Y - y0, y1 - Y])
    plaza = _smooth((edge + (mid - 0.5) * 1.4) / 0.25)
    conc = np.array((0.64, 0.62, 0.58), np.float32) * (0.88 + 0.22 * big[..., None]) * (0.94 + 0.12 * fine[..., None])
    joints = (np.minimum(np.abs(((X - x0) % 4.0) - 2.0), np.abs(((Y - y0) % 4.0) - 2.0)) > 1.97)
    conc = np.where(joints[..., None], conc * 0.72, conc)
    crack_noise = value_noise(h, w, 1.6 * px_per_m, seed + 130)
    crack_mask = value_noise(h, w, 3.0 * px_per_m, seed + 150) > 0.62      # yalnız bazı bölgelerde
    cracks = (np.abs(crack_noise - 0.5) < 0.006) & crack_mask & (fine > 0.3)
    conc = np.where(cracks[..., None], conc * 0.55, conc)
    stain = _smooth((fbm(h, w, [2.5 * px_per_m, 0.8 * px_per_m], seed + 170) - 0.58) / 0.12)
    conc = conc * (1 - 0.35 * stain[..., None])
    # Solgun park çizgileri (3 yer)
    line = np.zeros((h, w), np.float32)
    for i in range(3):
        cx = x0 + 4.0 + i * 8.0
        cy = (y0 + y1) / 2
        for dx in (-2.8, 2.8):
            m = (np.abs(X - (cx + dx)) < 0.08) & (np.abs(Y - cy) < 2.6)
            line = np.maximum(line, m.astype(np.float32))
    line *= (0.55 + 0.45 * fine)
    conc = conc * (1 - line[..., None] * 0.7) + np.array((0.86, 0.70, 0.30), np.float32) * line[..., None] * 0.7
    col = col * (1 - plaza[..., None]) + conc * plaza[..., None]
    # Yağ lekeleri
    for (sx, sy, r) in stains:
        d = np.hypot(X - sx, (Y - sy) * 1.3) / r
        blob = _smooth((1.0 - d + (mid - 0.5) * 0.6) / 0.35)
        col = col * (1 - 0.75 * blob[..., None]) + np.array((0.10, 0.08, 0.07), np.float32) * 0.75 * blob[..., None]
    # Diplerde koyulaşma (AO): dağlar / tepeler, konteyner duvarı, çitler
    ao = np.ones((h, w), np.float32)
    for (mx, my, r) in mounds:
        d = np.hypot(X - mx, Y - my)
        ao *= 1 - 0.45 * _smooth((r + 2.5 - d) / 3.5)
    ao *= 1 - 0.35 * _smooth((Y - (D - 6.0)) / 3.0) * ((X > 0) & (X < W))
    ao *= 1 - 0.25 * _smooth((1.4 - np.abs(Y)) / 1.4) * ((X > 0) & (X < W))
    ao *= 1 - 0.25 * _smooth((1.4 - np.abs(X - W)) / 1.4) * ((Y > 0) & (Y < D))
    col *= ao[..., None]
    # Çit diplerinde ve saha dışında kuru ot tutamları
    tuft = value_noise(h, w, 0.25 * px_per_m, seed + 210)
    near_fence = (np.abs(Y) < 2.5) | (np.abs(X - W) < 2.5) | ~((X > 0) & (X < W) & (Y > 0) & (Y < D))
    grass = (tuft > 0.82) & near_fence & (speck > 0.6) & (road[..., 0] < 0.5)
    col = np.where(grass[..., None], np.array((0.50, 0.48, 0.27), np.float32) * (0.8 + 0.4 * fine[..., None]), col)
    border = np.minimum.reduce([X - G_X0, G_X1 - X, Y - G_Y0, G_Y1 - Y])
    fade = _smooth((10.0 - border) / 10.0)[..., None]
    col = col * (1 - fade) + np.array(DESERT, np.float32) * fade
    col = np.clip(col, 0, 1)
    rgba = np.concatenate([col, np.ones((h, w, 1), np.float32)], axis=2)
    img = bpy.data.images.get("JY_Ground")
    if img is not None and (img.size[0] != w or img.size[1] != h):
        bpy.data.images.remove(img)
        img = None
    if img is None:
        img = bpy.data.images.new("JY_Ground", w, h, alpha=False)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    img.filepath_raw = GROUND_PNG
    img.file_format = 'PNG'
    img.save()
    return img


def ground_plane(col, img):
    """Dokulu zemin düzlemi (UV 0..1 = G_X0..G_X1, G_Y0..G_Y1)."""
    me = bpy.data.meshes.new("JY_GroundPlane")
    v = [(G_X0, G_Y0, 0.0), (G_X1, G_Y0, 0.0), (G_X1, G_Y1, 0.0), (G_X0, G_Y1, 0.0)]
    me.from_pydata(v, [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap")
    for li, (u, vv) in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[li].uv = (u, vv)
    m = bpy.data.materials.get("JY_GroundTex") or bpy.data.materials.new("JY_GroundTex")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = next((n for n in nt.nodes if n.type == 'TEX_IMAGE'), None) or nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = 'Linear'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    bsdf.inputs["Metallic"].default_value = 0.0
    me.materials.append(m)
    o = bpy.data.objects.new("Ground", me)
    col.objects.link(o)
    o.visible_shadow = False      # alttaki araziye gölge düşürmesin (kenarda koyu çizgi yapıyordu); oyunda da kapalı
    o["jy_textured"] = True
    return o


def terrain(col, W, D, seed=11):
    """Kuzey ve batıda yükselen tabakalı kuru tepeler; güney / doğu düz. Köşe renkli, yumuşak gölgeli."""
    step = 6.0   # uzak arazi: 4 m → 6 m (üçgen ~%55 az)
    xs = np.arange(-170.0, 240.0 + step, step)
    ys = np.arange(-150.0, 200.0 + step, step)
    r = random.Random(seed)
    # Basit 2B gürültü (köşe başına): birkaç sinüs + rastgele faz (dikiş yok, ucuz)
    phases = [(r.uniform(0, 6.28), r.uniform(0, 6.28), r.uniform(0.6, 1.4)) for _ in range(6)]

    def n2(x, y, f):
        s = 0.0
        for k, (px, py, a) in enumerate(phases):
            fk = f * (1.0 + k * 0.73)
            s += math.sin(x * fk + px) * math.cos(y * fk * 0.87 + py) * a / (1 + k)
        return s * 0.5 + 0.5

    def height(x, y):
        north = max(0.0, min(1.0, (y - (D + 8.0)) / 38.0))
        west = max(0.0, min(1.0, (-8.0 - x) / 38.0))
        rise = max(north, west)
        rise = rise * rise * (3 - 2 * rise)
        hgt = rise * (7.0 + 18.0 * n2(x, y, 0.035))
        # mesa: tepeler basamaklı (tabaka hissi)
        if hgt > 2.0:
            step_h = 3.2
            q = math.floor(hgt / step_h) * step_h
            hgt = q + (hgt - q) ** 2 / step_h
        hgt += 0.35 * n2(x, y, 0.25) - 0.4
        return hgt
    bm = bmesh.new()
    cl = bm.loops.layers.float_color.new("Col")
    grid = []
    for j, y in enumerate(ys):
        row = []
        for i, x in enumerate(xs):
            row.append(bm.verts.new((x, y, height(x, y))))
        grid.append(row)
    sand = DESERT
    band_l = (0.72, 0.57, 0.41)
    band_d = (0.52, 0.39, 0.28)

    def lin(c):
        return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            vs = [grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]]
            f = bm.faces.new(vs)
            f.smooth = True
            for loop in f.loops:
                z = loop.vert.co.z
                b = (z / 3.2) % 1.0
                k = 0.0 if z < 1.0 else min(1.0, (z - 1.0) / 3.0)
                bandc = band_l if b < 0.5 else band_d
                c = [sand[q] * (1 - k) + bandc[q] * k for q in range(3)]
                v = 1.0 + (0.08 * (n2(loop.vert.co.x, loop.vert.co.y, 0.045) - 0.5)) * k
                loop[cl] = (*lin([min(1.0, cc * v) for cc in c]), 1.0)
    me = bpy.data.meshes.new("JY_Terrain")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(surface_mat("rough", 0.97, 0.0))
    o = bpy.data.objects.new("Terrain", me)
    col.objects.link(o)
    o.location.z = -0.05
    o["jy_vc"] = True
    return o
