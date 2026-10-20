"""DEKORASYON v6 — KURUCU EŞYASI: ön kayıt ödülü TAŞTAKİ ALTIN ANAHTAR (founder_wrench).

Mağazada satılmaz; yalnızca ön kayıt yaptıran ilk oyunculara verilir (FounderReward). Kılıç-taşta esprisi:
Rıza Usta'nın ilk ustalara bıraktığı anahtar — kızgın çatlaklarla yarılmış taşa saplı altın anahtar, kırmızı
fiyonk, süzülen altın / mavi halkalar, kaidede oyunun GERÇEK logosu (assets/branding/autoyard_logo.png, dokudan).
Uzak oyun kamerasında bile "bu herkeste yok" okunmalı. Yazı yok (logo dilden bağımsız).
2026-10-20 üç taslaktan (direk tabela / anahtar / duvar plaketi) kullanıcı bunu seçti, "biraz daha küçük" →
bütün eşya SCALE ile küçültülür (taslak 2,24 m'ydi).

Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v6_kurucu.py
"""
import math as _m
import os as _os
import random as _random

import bmesh
import mathutils
import numpy as _np

R90 = _m.radians(90)
## Taslak ölçüsüne göre küçültme (kullanıcı: "biraz daha küçük"): 2,24 m → ~1,68 m yükseklik.
SCALE = 0.75
LOGO_PATH = _os.path.join(_os.path.dirname(OUT_DIR.rstrip("/")), "branding", "autoyard_logo.png")

# --- Malzemeler ---------------------------------------------------------------------------
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
GOLD_D = mat("KoyuAltin", (0.62, 0.34, 0.04), 0.35, 0.35, emit=(0.06, 0.03, 0.003))
MARBLE_K = mat("KaraMermer", (0.035, 0.035, 0.042), 0.12)
ENAMEL = mat("LacivertEmaye", (0.03, 0.09, 0.32), 0.15, emit=(0.01, 0.03, 0.12))
# Kit ışımayı ×2 yazar: tam değerli neon oyunda BEYAZA patlıyordu (halkalar renksiz) → yarım, doygun.
N_GOLD = mat("NeonAltin", (1.0, 0.70, 0.15), 0.3, emit=(0.60, 0.34, 0.03))
N_BLUE = mat("NeonMavi", (0.20, 0.50, 1.0), 0.3, emit=(0.03, 0.20, 0.70))
LAVA = mat("KizginCatlak", (1.0, 0.50, 0.08), 0.3, emit=(0.70, 0.26, 0.02))
STONE = mat("Tas", (0.20, 0.19, 0.19), 0.95)
RIBBON = mat("Kurdele", (0.70, 0.03, 0.06), 0.45)


# --- Logo dokusu --------------------------------------------------------------------------

def logo_image(name, w, h, pad=0.07, top=(0.12, 0.26, 0.62), bottom=(0.03, 0.08, 0.27)):
    """Logo, lacivert degrade zemin üstüne ortalanmış RGB doku (sRGB değerleri; satır 0 = ALT)."""
    src = bpy.data.images.load(LOGO_PATH, check_existing=True)
    sw, sh = src.size
    scale = min(w * (1.0 - 2.0 * pad) / sw, h * (1.0 - 2.0 * pad) / sh)
    lw, lh = int(sw * scale), int(sh * scale)
    logo = src.copy()
    logo.scale(lw, lh)
    lp = _np.array(logo.pixels[:], dtype=_np.float32).reshape(lh, lw, 4)
    t = _np.linspace(0.0, 1.0, h, dtype=_np.float32)[:, None]
    out = _np.ones((h, w, 4), dtype=_np.float32)
    for c in range(3):
        out[..., c] = bottom[c] * (1.0 - t) + top[c] * t
    # kenara doğru hafif kararma (ışıklı kutu camı gibi)
    yy, xx = _np.mgrid[0:h, 0:w].astype(_np.float32)
    edge = _np.minimum(_np.minimum(xx, w - 1 - xx) / (0.10 * w), _np.minimum(yy, h - 1 - yy) / (0.18 * h))
    out[..., :3] *= (0.72 + 0.28 * _np.clip(edge, 0.0, 1.0))[..., None]
    x0, y0 = (w - lw) // 2, (h - lh) // 2
    a = lp[..., 3:4]
    region = out[y0:y0 + lh, x0:x0 + lw, :3]
    out[y0:y0 + lh, x0:x0 + lw, :3] = lp[..., :3] * a + region * (1.0 - a)
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.pixels.foreach_set(out.ravel())
    img.pack()
    return img


def tex_mat(name, img, glow=1.0, rough=0.3):
    """Dokulu malzeme: aynı doku hem renk hem ışıma (glTF emissiveTexture)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = img
    nt.links.new(t.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(t.outputs['Color'], b.inputs['Emission Color'])
    b.inputs['Emission Strength'].default_value = glow
    b.inputs['Roughness'].default_value = rough
    return m


def picture(w, h, loc, material, back=False):
    """Dokulu düz yüz (UV 0..1). Ön (−Y) ya da arka (+Y) yüze bakar; arkadan bakınca da düz okunur."""
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc, rotation=(R90, 0, _m.pi if back else 0))
    o = bpy.context.object
    o.scale = (w, h, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _place(o, material)


# --- Yardımcılar --------------------------------------------------------------------------

def plinth(w, d, h, z=0.0, material=MARBLE_K, band=GOLD):
    """Lüks kaide: kara mermer blok, altın taban ve üst bandı (lüks partisiyle aynı dil)."""
    box((w + 0.08, d + 0.08, 0.05), (0, 0, z + 0.025), band)
    box((w, d, h - 0.1), (0, 0, z + 0.05 + (h - 0.1) / 2), material)
    box((w + 0.06, d + 0.06, 0.05), (0, 0, z + h - 0.025), band)


def star_pts(r, inner=0.45, cx=0.0, cz=0.0, spin=0.0):
    """Beş köşeli yıldız dış hattı (x, z), tepe yukarıda."""
    pts = []
    for k in range(10):
        a = R90 + spin + k * _m.pi / 5.0
        rr = r if k % 2 == 0 else r * inner
        pts.append((cx + rr * _m.cos(a), cz + rr * _m.sin(a)))
    return pts


def star(r, y, cz, material, depth=0.04, cx=0.0, inner=0.45):
    return prism(star_pts(r, inner, cx, cz), depth, 'xz', material, offset=y)


def new_objects(before):
    return [o for o in col().objects if o not in before]


def transform_objects(objs, matrix):
    for o in objs:
        o.matrix_world = matrix @ o.matrix_world


# ================================================================ TAŞTAKİ ALTIN ANAHTAR
clear()
LOGO_B = tex_mat("LogoRozet", logo_image("kurucu_logo_rozet", 512, 160), glow=0.55)
PL_H = 0.40
plinth(1.00, 1.00, PL_H)
box((0.66, 0.025, 0.21), (0, -0.515, PL_H / 2 + 0.01), GOLD)               # kaide rozeti
picture(0.60, 0.1875, (0, -0.529, PL_H / 2 + 0.01), LOGO_B)
# kaya: düşük çokgenli, tepesi düzleşmiş taş; anahtarın girdiği yerden yayılan kızgın çatlaklar
_random.seed(2026)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0))
rock = bpy.context.object
ROCK_TOP = 0.30
for v in rock.data.vertices:
    j = 1.0 + _random.uniform(-0.16, 0.16)
    x, y, z = v.co.x * 0.42 * j, v.co.y * 0.37 * j, v.co.z * 0.34 * j
    v.co = (x, y, min(max(z, -0.02), ROCK_TOP * 0.85) + 0.02)
rock.location = (0, 0, PL_H)
_place(rock, STONE)
rock.data.update()
top_z = PL_H + ROCK_TOP * 0.85 + 0.02
cyl(0.09, 0.012, (0, 0, top_z + 0.004), LAVA, seg=12)


def surface_point(x, y):
    """Kayanın (x, y) üstündeki yüzey noktası, yüzeyden biraz dışarıda (dünya koordinatı) ya da None."""
    hit, loc, normal, _i = rock.ray_cast((x, y, 3.0), (0.0, 0.0, -1.0))
    if not hit:
        return None
    return mathutils.Vector((loc.x, loc.y, loc.z + PL_H)) + normal * 0.006


for a0, ln in ((0.3, 0.44), (1.3, 0.36), (2.2, 0.46), (3.3, 0.34), (4.3, 0.42), (5.3, 0.38)):
    pts = []
    a = a0
    for k in range(7):
        r = 0.07 + ln * k / 6.0
        a += _random.uniform(-0.16, 0.16)
        p = surface_point(_m.cos(a) * r, _m.sin(a) * r)
        if p is None:
            break
        pts.append(p)
    for k in range(len(pts) - 1):
        rod(tuple(pts[k]), tuple(pts[k + 1]), 0.011 * (1.0 - 0.5 * k / 6.0), LAVA, seg=5)
# anahtar: sap + açık ağız (önden profil, kalınlık Y'de), hafif eğik saplanmış
before = set(col().objects)
W_BASE = top_z - 0.25                                                      # sapın taşa gömülen ucu
SHAFT_TOP = W_BASE + 1.45
prism([(-0.075, W_BASE), (0.075, W_BASE), (0.092, SHAFT_TOP), (-0.092, SHAFT_TOP)], 0.06, 'xz', GOLD)
R_HEAD, JAW_W, JAW_D = 0.24, 0.19, 0.22
zc = SHAFT_TOP + R_HEAD * 0.55
th_r = _m.atan2(_m.sqrt(R_HEAD ** 2 - (JAW_W / 2) ** 2), JAW_W / 2)
head = []
n_arc = 18
for i in range(n_arc + 1):
    a = th_r - (_m.pi + 2.0 * th_r) * i / n_arc
    head.append((R_HEAD * _m.cos(a), R_HEAD * _m.sin(a)))
slot_c = R_HEAD - JAW_D
head.append((-JAW_W / 2, slot_c))
for i in range(1, 8):
    a = _m.pi + _m.pi * i / 8
    head.append((JAW_W / 2 * _m.cos(a), slot_c + JAW_W / 2 * _m.sin(a)))
head.append((JAW_W / 2, slot_c))
tilt = _m.radians(-15)
head = [(x * _m.cos(tilt) - z * _m.sin(tilt), zc + x * _m.sin(tilt) + z * _m.cos(tilt)) for (x, z) in head]
prism(head, 0.075, 'xz', GOLD)
box((0.07, 0.006, 1.10), (0, -0.033, W_BASE + 0.30 + 0.55), ENAMEL)        # sapta lacivert emaye şerit
for sx in (-0.042, 0.042):
    box((0.008, 0.008, 1.10), (sx, -0.034, W_BASE + 0.30 + 0.55), GOLD_D)
star(0.05, -0.038, W_BASE + 1.20, N_GOLD, depth=0.006)
star(0.035, -0.038, W_BASE + 0.62, N_GOLD, depth=0.006)
# Rıza Usta'nın kurdelesi: sapı saran halka, fiyonk, iki uç
RZ = SHAFT_TOP - 0.12
box((0.205, 0.075, 0.045), (0, 0, RZ), RIBBON)
ball(0.032, (0, -0.06, RZ), RIBBON, seg=8, ring=5)
for s in (-1, 1):
    loop = torus(0.050, 0.014, (s * 0.075, -0.062, RZ + 0.03), RIBBON, rot=(R90, -s * 0.45, 0), seg=12, mseg=4)
    loop.scale = (1.7, 1.0, 1.0)
    box((0.045, 0.010, 0.17), (s * _m.sin(0.5) * 0.10, -0.062, RZ - _m.cos(0.5) * 0.10), RIBBON,
        rot=(0, -s * 0.5, 0))
wrench = new_objects(before)
pivot = mathutils.Vector((0.0, 0.0, top_z))
transform_objects(wrench, mathutils.Matrix.Translation(pivot) @ mathutils.Matrix.Rotation(_m.radians(7), 4, 'Y')
                  @ mathutils.Matrix.Rotation(_m.radians(-4), 4, 'X') @ mathutils.Matrix.Translation(-pivot))
# süzülen halkalar: biri altın, biri marka mavisi
torus(0.34, 0.018, (0.128, 0, top_z + 1.05), N_GOLD, rot=(_m.radians(12), _m.radians(6), 0), seg=26, mseg=4)
torus(0.42, 0.015, (0.088, 0, top_z + 0.72), N_BLUE, rot=(_m.radians(-9), _m.radians(-5), 0), seg=26, mseg=4)
transform_objects(list(col().objects), mathutils.Matrix.Scale(SCALE, 4))
finish("founder_wrench")
