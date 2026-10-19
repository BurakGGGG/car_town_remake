"""BEKLEYENLER — çatı katı otopark (GARAJLARIM'ın bekleme otoparkı, kullanıcı kararı 2026-10-19).
Garajlar dolunca gelen araçlar burada bekler. Perspektif diorama, GÜN BATIMI: alçak turuncu güneş, yanmaya başlayan
direk lambaları, arkada şehir silueti (kamera aşağı baktığı için gök kadraja girmez: sahnenin arkasında tiyatro dekoru
gibi kavisli FON perdesi). Güverte 25 × 17 m.

Yerleşim (X doğu, Y kuzey; kamera güneydoğudan):
  arka sıra  Slot_0..5   burun kameraya        ön sıra  Slot_6..11
  doğu       rampa (aşağı iner) + rampadan yeni çıkmış ÇEKİCİ (kasasında yeni gelen araç: Slot_Tow)
  kuzeybatı  merdiven kulesi (su deposu, anten, kapı lambası)
Çizgiler / oklar / yaya geçidi zemin dokusunda (seviye kalemi yok).

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/rooftop.py -- preview <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

X0, X1, Y0, Y1 = -1.0, 24.5, -1.5, 16.0     # güverte
PARAPET = 1.05
RAMP = (19.2, 23.6, 7.4, 15.7)              # rampa açıklığı (x0, x1, y0, y1): kuzeye doğru iner
SLOTS = [(2.3 + i * 2.8, 12.9, 0.0) for i in range(6)] + [(2.3 + i * 2.8, 4.6, 0.0) for i in range(6)]
TOW = (21.4, 3.3, 0.0)                      # çekici (burun güneye, kasa rampaya bakar)
TOW_BED_Z = 1.22
SUN_DIR = (math.cos(math.radians(10)) * 0.9, 0.42, -math.sin(math.radians(10)))   # batı-güneybatıdan alçak güneş


# --- Dokular -----------------------------------------------------------------------------------

def deck_texture(path, ppm=64):
    """Beton güverte: lekeler, derzler, beyaz park çizgileri, akış okları, yaya geçidi, rampa önü sarı tarama."""
    import numpy as np
    w, h = int((X1 - X0) * ppm), int((Y1 - Y0) * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = X0 + xx / ppm, Y1 - yy / ppm
    n = _fbm((h, w), 70, 31)
    fine = _fbm((h, w), 5, 41, 3)
    col = np.array(_hex("#7D7A76"))[None, None, :] * (0.8 + 0.3 * n[..., None] + 0.1 * fine[..., None])
    rng = np.random.default_rng(9)
    for _ in range(40):   # yağ lekeleri park yerlerinde
        sx, sy, _r = SLOTS[rng.integers(0, len(SLOTS))]
        cx, cy = sx + rng.normal(0, 0.5), sy + rng.normal(0, 1.0)
        r = rng.uniform(0.2, 0.7)
        d = np.sqrt((mx - cx) ** 2 + (my - cy) ** 2)
        a = np.clip(1 - d / r, 0, 1) ** 1.6 * rng.uniform(0.2, 0.5)
        col *= (1 - a[..., None] * 0.7)
    joints = (np.abs(((mx - X0) % 4.0)) < 0.03) | (np.abs(((my - Y0) % 4.0)) < 0.03)
    col[joints] *= 0.62
    white = np.array(_hex("#ECE8DD"))
    yellow = np.array(_hex("#E9B22E"))
    def paint(mask, c):
        col[mask] = c
    for (x, y, _r) in SLOTS:
        for s in (-1.4, 1.4):
            paint((np.abs(mx - (x + s)) < 0.05) & (np.abs(my - y) < 2.5), white)
        back = y + 2.5 if y > 8 else y - 2.5
        paint((np.abs(my - back) < 0.05) & (np.abs(mx - x) < 1.45), white)
    # akış okları (koridor boyunca doğuya: rampaya)
    for ax in (4.0, 9.5, 15.0):
        ay = 8.75
        shaft = (np.abs(my - ay) < 0.16) & (mx > ax - 1.3) & (mx < ax + 0.4)
        head = (mx >= ax + 0.4) & (mx < ax + 1.3) & (np.abs(my - ay) < (ax + 1.3 - mx) * 0.6)
        paint(shaft | head, white)
    # yaya geçidi: merdiven kulesi kapısının önünde
    zebra = (mx > 0.9) & (mx < 3.3) & (my > 9.8) & (my < 10.6 + 0.0) & (((mx * 2.2).astype(int) % 2) == 0)
    paint(zebra, white)
    # rampa önü sarı tarama
    hatch = (mx > RAMP[0]) & (mx < RAMP[1]) & (my > RAMP[2] - 1.6) & (my < RAMP[2]) & ((((mx + my) * 1.6).astype(int) % 2) == 0)
    paint(hatch, yellow)
    _save_image("deck", col[::-1], path)
    return path


def backdrop_texture(path, w=4096, h=1024):
    """Gün batımı fonu: gök geçişi, alçak güneş, pembe bulut şeritleri, üç katman şehir silueti, yanan pencereler."""
    import numpy as np
    v = np.linspace(1.0, 0.0, h, dtype=np.float32)[:, None] * np.ones((1, w), dtype=np.float32)   # 1 üst, 0 alt
    u = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :] * np.ones((h, 1), dtype=np.float32)
    top, mid, low = np.array(_hex("#1B2350")), np.array(_hex("#B24E79")), np.array(_hex("#FFAE57"))
    t = np.clip((v - 0.28) / 0.72, 0, 1)[..., None]
    sky = low * (1 - np.clip(t * 1.8, 0, 1)) + mid * np.clip(t * 1.8, 0, 1)
    sky = sky * (1 - np.clip((t - 0.45) / 0.55, 0, 1)) + top * np.clip((t - 0.45) / 0.55, 0, 1)
    # güneş (sol üçte birde, ufkun hemen üstünde)
    sx, sy = 0.3, 0.33
    d = np.sqrt(((u - sx) * 4.0) ** 2 + (v - sy) ** 2)
    sky += (np.clip(1 - d / 0.05, 0, 1) ** 0.5 * 1.6 + np.clip(1 - d / 0.35, 0, 1) ** 2 * 0.45)[..., None] * np.array(_hex("#FFD27A"))
    # bulut şeritleri
    cloud = _fbm((h, w), 90, 77, 4)
    band = np.exp(-((v - 0.62) / 0.09) ** 2) + 0.6 * np.exp(-((v - 0.78) / 0.05) ** 2)
    c = np.clip((cloud - 0.5) * 3.0, 0, 1) * band
    sky = sky * (1 - c[..., None] * 0.5) + c[..., None] * np.array(_hex("#FF8FA3")) * 0.6
    img = sky
    rng = np.random.default_rng(3)
    # siluet katmanları: uzak (açık, mavimsi) → yakın (koyu, pencereli)
    for layer, (base, var, dark, lit) in enumerate([(0.30, 0.10, "#5A4A78", 0.0), (0.24, 0.16, "#30284A", 0.12),
                                                     (0.14, 0.22, "#1A1528", 0.22)]):
        heights = np.zeros(w, dtype=np.float32)
        x = 0
        while x < w:
            bw = int(rng.uniform(40, 140) * (1 + layer * 0.4))
            hh = base + rng.uniform(0, var) * (1.6 if rng.random() < 0.12 else 1.0)
            heights[x:x + bw] = hh
            x += bw + int(rng.uniform(0, 12))
        mask = v < heights[None, :]
        img[mask] = np.array(_hex(dark))
        if lit > 0:
            win = ((xxw := (np.arange(w)[None, :] % 14)) < 6) & ((np.arange(h)[:, None] % 18) < 8)
            on = rng.random((h // 18 + 1, w // 14 + 1)) < lit
            onmap = np.repeat(np.repeat(on, 18, axis=0), 14, axis=1)[:h, :w]
            lights = mask & win & onmap & (v < heights[None, :] - 0.015)
            img[lights] = np.array(_hex("#FFC86A")) * rng.uniform(0.7, 1.0)
    _save_image("backdrop", img[::-1], path)
    return path


def textured_plane_obj(col, name, verts, uvs, tex_path, emissive=False, strength=1.0):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in verts]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, c in zip(f.loops, uvs):
        loop[uv].uv = c
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    m = bpy.data.materials.new(name + "_mat")
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path)
    if emissive:
        for n in list(nt.nodes):
            if n.type == 'BSDF_PRINCIPLED':
                nt.nodes.remove(n)
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = strength
        out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
        nt.links.new(tex.outputs["Color"], em.inputs["Color"])
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    else:
        bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.9
    me.materials.append(m)
    o["jy_textured"] = True
    return o


def backdrop(col, tex_path, radius=78.0, height=64.0, arc=(55.0, 235.0), segs=36, base_z=-48.0):
    """Kavisli fon perdesi (sahnenin arkasında): iç yüzü sahneye bakar, ışıksız. Kamera ~25° aşağı baktığı için
    gerçek gök kadraja girmez; perde AŞAĞI kaydırılır, kadrajın üst ışınları göğün geçiş bölgesine düşer, siluetler
    3B binaların arkasında kalır (maket hilesi)."""
    cx, cy = (X0 + X1) / 2, (Y0 + Y1) / 2
    me = bpy.data.meshes.new("Backdrop")
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    low, high = [], []
    for i in range(segs + 1):
        a = math.radians(arc[0] + (arc[1] - arc[0]) * i / segs)
        p = (cx + math.cos(a) * radius, cy + math.sin(a) * radius)
        low.append(bm.verts.new((p[0], p[1], base_z)))
        high.append(bm.verts.new((p[0], p[1], base_z + height)))
    for i in range(segs):
        f = bm.faces.new([low[i + 1], low[i], high[i], high[i + 1]])
        u0, u1 = 1 - i / segs, 1 - (i + 1) / segs
        for loop, c in zip(f.loops, [(u1, 0), (u0, 0), (u0, 1), (u1, 1)]):
            loop[uv].uv = c
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Backdrop", me)
    col.objects.link(o)
    m = bpy.data.materials.new("Backdrop_mat")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type == 'BSDF_PRINCIPLED':
            nt.nodes.remove(n)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path)
    tex.extension = 'EXTEND'
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    out = next(n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL')
    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    m.use_backface_culling = False
    me.materials.append(m)
    o["jy_textured"] = True
    o.visible_shadow = False
    return o


# --- Yapılar -----------------------------------------------------------------------------------

def deck_structure(col, m):
    b = Builder("Deck", seed=3)
    # döşeme kalınlığı (ön kenarda beton kesit görünür)
    soft_box(b, ((X0 + X1) / 2, (Y0 + Y1) / 2, -0.4), (X1 - X0, Y1 - Y0, 0.8), m["concrete_dark"], radius=0.04)
    # korkuluk duvarları + üstte boru küpeşte (rampa ağzında ve kule kapısında boşluk)
    def parapet(x0, y0, x1, y1):
        length = math.hypot(x1 - x0, y1 - y0)
        if length < 0.05:
            return
        yaw = math.degrees(math.atan2(y1 - y0, x1 - x0))
        c = ((x0 + x1) / 2, (y0 + y1) / 2, PARAPET / 2)
        soft_box(b, c, (length, 0.25, PARAPET), m["concrete"], radius=0.03, rot=(0, 0, yaw))
        b.box((c[0], c[1], PARAPET + 0.03), (length, 0.3, 0.06), m["concrete_dark"], rot=(0, 0, yaw))
        for i in range(int(length / 2.0) + 1):
            t = min(i * 2.0, length)
            px, py = x0 + math.cos(math.radians(yaw)) * t, y0 + math.sin(math.radians(yaw)) * t
            b.cyl((px, py, PARAPET + 0.45), 0.03, 0.8, m["steel"], segs=6)
        b.tube([(x0, y0, PARAPET + 0.85), (x1, y1, PARAPET + 0.85)], 0.035, m["steel"], segs=6)
    parapet(X0, Y0, X1, Y0)                    # ön (güney)
    parapet(X1, Y0, X1, Y1)                    # doğu
    parapet(X0, Y1, 0.9, Y1)                   # arka (kuzey), kule kapısı boşluğu
    parapet(3.3, Y1, X1, Y1)
    parapet(X0, Y0, X0, Y1)                    # batı
    # rampa: açıklığın kenarlarında duvarlar, içinde aşağı inen eğik döşeme
    x0, x1, y0, y1 = RAMP
    soft_box(b, (x0 - 0.12, (y0 + y1) / 2, 0.5), (0.25, y1 - y0, 1.0), m["concrete"], radius=0.03)
    soft_box(b, (x1 + 0.12, (y0 + y1) / 2, 0.5), (0.25, y1 - y0, 1.0), m["concrete"], radius=0.03)
    for i in range(int((y1 - y0) / 0.6)):   # sarı-siyah ikaz şeritleri duvar başında
        if i % 2 == 0:
            for xx in (x0 - 0.25, x1 + 0.25):
                b.box((xx, y0 + 0.3 + i * 0.6, 0.82), (0.02, 0.6, 0.25), m["yellow"])
    ramp_len = y1 - y0
    drop = 3.2
    pitch = math.degrees(math.atan2(drop, ramp_len))
    soft_box(b, ((x0 + x1) / 2, (y0 + y1) / 2, -drop / 2 - 0.1), (x1 - x0, math.hypot(ramp_len, drop), 0.2),
             m["concrete_dark"], radius=0.02, rot=(-pitch, 0, 0))
    # rampa ağzında bariyer kulübesi + kol
    soft_box(b, (x0 - 0.8, y0 - 0.9, 0.55), (0.5, 0.5, 1.1), m["yellow"], radius=0.05)
    b.box(((x0 + x1) / 2 - 0.4, y0 - 0.9, 1.0), (x1 - x0 + 0.4, 0.08, 0.08), m["white"])
    for i in range(5):
        b.box((x0 - 0.1 + i * 0.95, y0 - 0.9, 1.0), (0.4, 0.085, 0.085), m["red"])
    # zemin altında kalan karanlık iç: rampa çukurunun dibi
    soft_box(b, ((x0 + x1) / 2, y1 + 0.5, -3.4), (x1 - x0, 1.2, 0.2), m["black"], radius=0.0)
    return b.finish(col)


def garage_facade(col, m, floors=7, story=3.1):
    """Güvertenin altındaki katlı otopark: güney ve doğu cephede beton bantlar, karanlık kat açıklıkları, kolonlar,
    içeride yer yer yanan tavan lambaları (güverte bir binanın tepesinde durur; yükseklik hissi)."""
    b = Builder("Facade", seed=17)
    lamp = k_mat("g_park_lamp", "#FFE6B0", rough=0.5, emit="#FFE0A0", strength=4.0)
    r = random.Random(4)
    top = -0.8
    for k in range(floors):
        z_top = top - k * story
        band_h = 0.9
        for face in ("S", "E"):
            if face == "S":
                c, size = ((X0 + X1) / 2, Y0 - 0.15, z_top - band_h / 2), (X1 - X0 + 0.3, 0.3, band_h)
            else:
                c, size = (X1 + 0.15, (Y0 + Y1) / 2, z_top - band_h / 2), (0.3, Y1 - Y0 + 0.3, band_h)
            soft_box(b, c, size, m["concrete"], radius=0.03)
            # açıklık: geride karanlık iç duvar
            oz = z_top - band_h - (story - band_h) / 2
            if face == "S":
                plane(b, ((X0 + X1) / 2, Y0 + 1.6, oz), (X1 - X0, story - band_h), m["black"], rot=(90, 0, 0))
            else:
                plane(b, (X1 - 1.6, (Y0 + Y1) / 2, oz), (Y1 - Y0, story - band_h), m["black"], rot=(90, 0, 90))
            # içerideki tavan lambaları (her açıklıkta birkaç tane)
            for i in range(6):
                if r.random() < 0.55:
                    if face == "S":
                        p = (X0 + 2 + i * (X1 - X0 - 4) / 5, Y0 + 1.2, z_top - band_h - 0.08)
                    else:
                        p = (X1 - 1.2, Y0 + 2 + i * (Y1 - Y0 - 4) / 5, z_top - band_h - 0.08)
                    soft_box(b, p, (0.9, 0.18, 0.06) if face == "S" else (0.18, 0.9, 0.06), lamp, radius=0.01)
    for i in range(6):   # kolonlar
        x = X0 + i * (X1 - X0) / 5
        soft_box(b, (x, Y0 - 0.1, top - floors * story / 2), (0.5, 0.5, floors * story), m["concrete_dark"], radius=0.03)
    for i in range(4):
        y = Y0 + i * (Y1 - Y0) / 3
        soft_box(b, (X1 + 0.1, y, top - floors * story / 2), (0.5, 0.5, floors * story), m["concrete_dark"], radius=0.03)
    return b.finish(col, ao=False)


def stair_tower(col, m):
    b = Builder("Tower", seed=5)
    x0, x1, y0, y1, hgt = -0.8, 4.6, Y1, Y1 + 3.6, 3.4
    soft_box(b, ((x0 + x1) / 2, (y0 + y1) / 2, hgt / 2), (x1 - x0, y1 - y0, hgt), m["paint_cream"], radius=0.05)
    soft_box(b, ((x0 + x1) / 2, (y0 + y1) / 2, hgt + 0.08), (x1 - x0 + 0.2, y1 - y0 + 0.2, 0.16), m["concrete_dark"], radius=0.03)
    # kapı + üstünde lamba + yeşil çıkış piktogramı (yazısız)
    soft_box(b, (2.1, Y1 - 0.02, 1.1), (1.1, 0.1, 2.2), m["steel_dark"], radius=0.02)
    soft_box(b, (2.1, Y1 - 0.08, 1.1), (0.95, 0.06, 2.05), m["blue"], radius=0.02)
    b.cyl((2.1, Y1 - 0.18, 2.45), 0.09, 0.14, m["bulb"], axis='Y', segs=10)
    soft_box(b, (3.4, Y1 - 0.06, 2.3), (0.5, 0.06, 0.25), m["green"], radius=0.02)
    plane(b, (3.4, Y1 - 0.1, 2.3), (0.4, 0.17), m["led"], rot=(90, 0, 0))
    # su deposu + anten + klima kutuları
    b.cyl((0.9, y1 - 1.2, hgt + 1.4), 0.9, 2.2, m["steel"], segs=16)
    b.cyl((0.9, y1 - 1.2, hgt + 2.6), 0.95, 0.2, m["steel_dark"], segs=16)
    for dx in (-0.6, 0.6):
        b.box((0.9 + dx, y1 - 1.2, hgt + 0.15), (0.12, 1.2, 0.3), m["steel_dark"])
    b.cyl((3.8, y1 - 0.8, hgt + 1.8), 0.04, 3.4, m["steel"], segs=6)
    b.ball((3.8, y1 - 0.8, hgt + 3.55), 0.07, m["neon_pink"], segs=6, rings=4)
    for i, x in enumerate((2.6, 3.7)):
        soft_box(b, (x, y1 - 2.0, hgt + 0.55), (0.9, 0.9, 0.75), m["white"], radius=0.05)
        b.cyl((x, y1 - 2.0, hgt + 0.93), 0.32, 0.02, m["black"], segs=14)
    return b.finish(col)


POLE_ARM = 1.3
POLE_H = 6.0


def light_pole(b, base, m, arm_deg):
    """Korkuluğa dikilen direk, tek kol içeri (arm_deg yönüne) uzanır."""
    x, y, z = base
    b.cyl((x, y, z + 0.2), 0.25, 0.4, m["concrete"], segs=10)
    b.cyl((x, y, z + POLE_H / 2), 0.07, POLE_H, m["steel_dark"], segs=8)
    ex, ey = pole_head(x, y, arm_deg)
    b.tube([(x, y, z + POLE_H - 0.1), (ex, ey, z + POLE_H + 0.1)], 0.04, m["steel_dark"])
    soft_box(b, (ex, ey, z + POLE_H + 0.05), (0.55, 0.28, 0.12), m["steel_dark"], radius=0.03, rot=(0, 0, arm_deg))
    plane(b, (ex, ey, z + POLE_H - 0.02), (0.45, 0.2), m["bulb"], rot=(180, 0, arm_deg))


def pole_head(x, y, arm_deg):
    return x + math.cos(math.radians(arm_deg)) * POLE_ARM, y + math.sin(math.radians(arm_deg)) * POLE_ARM


## Direkler korkuluk boyunca: koridorun ortasındayken kamera açısından seçili aracın tam önüne düşüyordu (oyunda, 2026-10-19)
POLES = [(-0.55, 4.0, 0.0), (-0.55, 12.5, 0.0), (6.6, Y1 - 0.45, -90.0), (13.6, Y1 - 0.45, -90.0)]   # (x, y, kol yönü)


def deck_props(col, m):
    b = Builder("Props", seed=7)
    for x, y, arm in POLES:
        light_pole(b, (x, y, 0.0), m, arm)
    for (x, y) in ((-0.2, Y0 + 0.7), (17.6, Y1 - 0.7), (-0.2, 8.75)):
        soft_box(b, (x + 0.4, y, 0.35), (1.3, 1.0, 0.7), m["concrete"], radius=0.05)
        b.cyl((x + 0.4, y, 1.1), 0.06, 1.0, m["wood_dark"], segs=6)
        for k in range(5):
            r = random.Random(k + int(x * 10))
            b.ball((x + 0.4 + r.uniform(-0.35, 0.35), y + r.uniform(-0.3, 0.3), 1.65 + r.uniform(-0.1, 0.35)),
                   r.uniform(0.35, 0.5), m["plant"], segs=8, rings=6)
    # reklam panosu (arka sağ, güneye bakar; yazısız: araç silueti + güneş)
    bx, by = 17.5, Y1 + 6.0
    for dx in (-2.5, 2.5):
        b.cyl((bx + dx, by, 3.0), 0.12, 6.0, m["steel_dark"], segs=8)
    soft_box(b, (bx, by, 7.2), (7.4, 0.35, 3.4), m["steel_dark"], radius=0.05)
    plane(b, (bx, by - 0.19, 7.2), (7.0, 3.0), m["blue"], rot=(90, 0, 0))
    b.ball((bx + 2.0, by - 0.2, 7.9), 0.7, m["yellow"], segs=12, rings=8, scale=(1, 0.05, 1))
    plane(b, (bx - 0.8, by - 0.21, 6.6), (3.6, 0.7), m["red"], rot=(90, 0, 0))
    plane(b, (bx - 1.0, by - 0.22, 7.05), (2.0, 0.5), m["red"], rot=(90, 0, 0))
    for dx in (-2.0, 0.4):
        b.cyl((bx - 0.8 + dx * 0.6, by - 0.23, 6.25), 0.28, 0.02, m["black"], axis='Y', segs=12)
    for dx in (-2.4, 2.4):
        b.tube([(bx + dx, by - 0.7, 9.2), (bx + dx * 0.7, by - 0.3, 8.8)], 0.03, m["steel_dark"])
        b.cyl((bx + dx, by - 0.75, 9.25), 0.12, 0.2, m["bulb"], axis='Y', segs=8)
    return b.finish(col)


def tow_truck(col, m):
    """Düz kasalı çekici: kabin (burun güneye), şasi, 6 teker, kasa, vinç, tepe ikaz lambası."""
    b = Builder("TowTruck", seed=11)
    x, y, _ = TOW
    cab_y = y - 2.4
    white = m["white"]
    soft_box(b, (x, cab_y, 1.55), (2.3, 1.9, 1.6), white, radius=0.18)
    soft_box(b, (x, cab_y - 0.15, 0.85), (2.4, 2.3, 0.5), m["red"], radius=0.1)
    plane(b, (x, cab_y - 0.97, 1.75), (2.0, 0.85), m["glass"], rot=(70, 0, 0))
    for s in (-1, 1):
        plane(b, (x + s * 1.16, cab_y, 1.75), (1.3, 0.7), m["glass"], rot=(90, 0, 90 * s))
    plane(b, (x, cab_y - 1.31, 0.95), (1.4, 0.3), m["steel_dark"], rot=(90, 0, 0))
    for s in (-0.85, 0.85):
        plane(b, (x + s, cab_y - 1.32, 1.0), (0.3, 0.16), m["led"], rot=(90, 0, 0))
    soft_box(b, (x, cab_y + 0.3, 2.42), (1.6, 0.3, 0.14), m["black"], radius=0.04)
    for s in (-0.55, 0.0, 0.55):
        soft_box(b, (x + s, cab_y + 0.3, 2.52), (0.32, 0.22, 0.1), k_mat("g_beacon", "#FF9A1F", rough=0.5, emit="#FF8A10",
                 strength=12.0), radius=0.03)
    # şasi + kasa
    soft_box(b, (x, y + 1.2, 0.7), (1.1, 6.4, 0.25), m["black"], radius=0.03)
    soft_box(b, (x, y + 1.6, TOW_BED_Z - 0.08), (2.5, 5.6, 0.16), m["steel"], radius=0.03)
    for s in (-1.22, 1.22):
        b.box((x + s, y + 1.6, TOW_BED_Z), (0.06, 5.6, 0.12), m["yellow"])
    soft_box(b, (x, y - 1.1, TOW_BED_Z + 0.5), (2.3, 0.18, 1.0), m["steel_dark"], radius=0.03)   # kabin arkası koruma
    b.cyl((x, y - 0.85, TOW_BED_Z + 0.25), 0.18, 1.6, m["red"], axis='X', segs=12)              # vinç tamburu
    # tekerler
    for wy in (cab_y + 0.1, y + 2.6, y + 3.65):
        for s in (-1, 1):
            tire(b, (x + s * 1.05, wy, 0.48), rot=(0, 90, 0), r=0.48, w=0.32, m=m)
    return b.finish(col)


def city(col, m):
    """Çevredeki binalar: arkada / batıda yüksek (güverteye bakan yüzlerde yanan pencereler), kamera tarafında
    güvertenin altında kalan çatılar (yükseklik hissi)."""
    b = Builder("City", seed=13)
    r = random.Random(21)
    wall_cols = ["#5D5A6B", "#6E5E58", "#4F5B66", "#7A6A5C", "#585063"]
    lit = k_mat("g_window_lit", "#FFD38A", rough=0.5, emit="#FFC870", strength=2.0)
    dark = k_mat("g_window_dark", "#2B3140", rough=0.3)
    blocks = []
    # Arka ve batı sırası ALÇAK tutulur: yüksek binalar alçak güneşi kesiyor ve gün batımı fonunu örtüyordu
    for i in range(9):    # arka (kuzey) sıra
        blocks.append((X0 - 4 + i * 4.2 + r.uniform(-0.4, 0.4), Y1 + 10 + r.uniform(0, 6), r.uniform(3.2, 4.2),
                       r.uniform(5, 9), r.uniform(-7, 9) if i % 3 else r.uniform(6, 13)))
    for i in range(5):    # batı sırası
        blocks.append((X0 - 11 - r.uniform(0, 4), Y0 + i * 4.4, r.uniform(5, 8), r.uniform(3.4, 4.3), r.uniform(-12, -2)))
    for i in range(7):    # ön (güney) ve doğu: güvertenin altında kalan çatılar
        blocks.append((X0 + i * 4.6 + r.uniform(-0.5, 0.5), Y0 - 7 - r.uniform(0, 3), r.uniform(3.6, 4.4), r.uniform(4, 6),
                       r.uniform(-14, -5)))
    for i in range(4):
        blocks.append((X1 + 7 + r.uniform(0, 3), Y0 + i * 5.0, r.uniform(4, 6), r.uniform(4.2, 4.9), r.uniform(-13, -4)))
    for (cx, cy, w, d, top) in blocks:
        base = -26.0
        hgt = top - base
        col_m = k_mat("g_bld_%d" % (hash((cx, cy)) % 5), wall_cols[hash((cx, cy)) % 5], rough=0.9)
        soft_box(b, (cx, cy, base + hgt / 2), (w, d, hgt), col_m, radius=0.05)
        soft_box(b, (cx, cy, top + 0.12), (w + 0.2, d + 0.2, 0.24), m["concrete_dark"], radius=0.03)
        if top < -2:   # alçak çatı: klima kutuları
            for k in range(r.randint(1, 3)):
                soft_box(b, (cx + r.uniform(-w / 3, w / 3), cy + r.uniform(-d / 3, d / 3), top + 0.6), (0.8, 0.8, 0.7),
                         m["white"], radius=0.04)
        # güneye ve doğuya bakan yüzlerde pencere ızgarası (yalnız güvertenin üstünde kalan kısım + biraz altı)
        for face in ("S", "E"):
            fw = w if face == "S" else d
            cols_n = max(1, int(fw / 1.1))
            for row in range(int(max(0.0, top - max(base, -10.0)) / 1.6)):
                z = top - 1.0 - row * 1.6
                for c in range(cols_n):
                    t = (c + 0.5) / cols_n - 0.5
                    if face == "S":
                        p = (cx + t * fw, cy - d / 2 - 0.02, z)
                        rot = (90, 0, 0)
                    else:
                        p = (cx + w / 2 + 0.02, cy + t * fw, z)
                        rot = (90, 0, 90)
                    plane(b, p, (0.6, 0.85), lit if r.random() < 0.22 else dark, rot=rot)
    return b.finish(col, ao=False)


# --- Sahne ---------------------------------------------------------------------------------

def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    os.makedirs(tex_dir, exist_ok=True)
    root = new_col("Rooftop")
    m = gmats()
    static = new_col("Static", root)
    deck_path = deck_texture(os.path.join(tex_dir, "rooftop_deck.png"))
    textured_plane_obj(static, "DeckTop", [(X0, Y0, 0.001), (X1, Y0, 0.001), (X1, Y1, 0.001), (X0, Y1, 0.001)],
                       [(0, 0), (1, 0), (1, 1), (0, 1)], deck_path)
    deck_structure(static, m)
    stair_tower(static, m)
    deck_props(static, m)
    tow_truck(static, m)
    garage_facade(static, m)
    city(static, m)
    backdrop(static, backdrop_texture(os.path.join(tex_dir, "rooftop_backdrop.png")))
    beams = new_col("Beams", root)
    for i, (x, y, arm) in enumerate(POLES):   # direk lambalarının hafif konileri
        ex, ey = pole_head(x, y, arm)
        light_beam(beams, "Beam_Pole_%d" % i, [(ex - 0.22, ey - 0.1, 5.95), (ex + 0.22, ey - 0.1, 5.95),
                   (ex + 0.22, ey + 0.1, 5.95), (ex - 0.22, ey + 0.1, 5.95)], (0, 0, -1), 5.6, (1.0, 0.85, 0.6),
                   strength=0.022)
    slots = new_col("Slots", root)
    for i, (x, y, rot) in enumerate(SLOTS + [(TOW[0], TOW[1] + 1.6, 0.0)]):
        e = bpy.data.objects.new("Slot_%d" % i if i < len(SLOTS) else "Slot_Tow", None)
        e.location = (x, y, 0.0 if i < len(SLOTS) else TOW_BED_Z)
        e.rotation_euler = (0, 0, math.radians(rot))
        slots.objects.link(e)
    return root


PREVIEW_CARS = ["renault_toros", "hyundai_getz", "vw_golf_7", "tofas_sahin", "bmw_e46", "porsche_gt3", "lambo_huracan",
                "vw_passat_b55"]


def preview_lights():
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.09, 0.07, 0.13, 1.0)   # alacakaranlık gök: mor-mavi dolgu
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.lights.new("Sun", 'SUN')
    sun.energy = 6.5
    sun.color = (1.0, 0.55, 0.3)
    sun.angle = math.radians(2.0)
    so = bpy.data.objects.new("Sun", sun)
    scn.collection.objects.link(so)
    aim(so, SUN_DIR)
    for x, y, arm in POLES:
        hx, hy = pole_head(x, y, arm)
        for k in (0.0,):
            l = bpy.data.lights.new("Pole", 'SPOT')
            l.energy = 2300
            l.color = (1.0, 0.86, 0.62)
            l.spot_size = math.radians(110)
            l.spot_blend = 0.8
            l.shadow_soft_size = 0.2
            lo = bpy.data.objects.new("Pole", l)
            scn.collection.objects.link(lo)
            lo.location = (hx, hy, 5.85)
            aim(lo, (hx + math.cos(math.radians(arm)) * 1.5, hy + math.sin(math.radians(arm)) * 1.5, 0.0))
    for loc, energy, color in (((2.1, Y1 - 0.4, 2.4), 120, (1.0, 0.8, 0.5)), ((TOW[0], TOW[1] - 2.1, 2.8), 60, (1.0, 0.55, 0.15))):
        l = bpy.data.lights.new("Lamp", 'POINT')
        l.energy = energy
        l.color = color
        lo = bpy.data.objects.new("Lamp", l)
        scn.collection.objects.link(lo)
        lo.location = loc


def preview_camera(width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 30
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    cam.lens = 30
    co.location = (26.5, -15.0, 14.5)
    aim(co, (11.3, 7.9, -0.2))
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        out = argv[1] if len(argv) > 1 else "/tmp/rooftop.png"
        width = int(argv[2]) if len(argv) > 2 else 1280
        height = int(argv[3]) if len(argv) > 3 else 640
        samples = int(argv[4]) if len(argv) > 4 else 48
        build(os.path.join(os.path.dirname(out), "tex"))
        slots = [SLOTS[i] for i in (0, 1, 3, 4, 6, 8, 9)] + [(TOW[0], TOW[1] + 1.6, 0.0, TOW_BED_Z)]
        place_cars(slots, PREVIEW_CARS)
        preview_lights()
        preview_camera(width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):   # export_garage.py sahneyi kurmak için içe yükler
    main()
