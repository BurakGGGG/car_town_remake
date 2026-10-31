"""DEKORASYON v10 — KEDİ EŞYALARI (GARAJ DOSTLARI, 2026-10-31): garaj kedisi Tekir'in kullandığı 6 eşya.

Kullanıcı kararları: Faz 1'de yatak, lastikten kedi kulesi, mama + su kabı; fiyat KARIŞIK (basit ₺, lüks elmas);
lüksler şimdi, Blender'da ben modellerim. Kedi eşyaya gidip kullanır (yatakta uyur, kulenin tepesine çıkar,
kaptan yer) — davranış world/pets/pet_world.gd'de; kedinin konacağı noktalar PET_SPOTS ile aynı ölçüde.

  cat_bed        KEDİ YATAĞI          yuvarlak, petrol kenarlık, krem minder, oyuncak balık       (minder üstü 0,085 m)
  cat_tower      LASTİK KEDİ KULESİ   iki lastik + kontrplak + minder; sisal sarılı egzoz borusu direk,
                                      tepesinde bakış platformu ve sarkan oyuncak top            (0,44 m / 0,89 m)
  cat_bowls      MAMA VE SU KABI      paspas üstünde turuncu seramik iki kap (mama + su), pati izi
  lux_cat_bed    DERİ KEDİ YATAĞI     siyah deri, altın biye, kırmızı kadife minder, altın ayaklar  (0,135 m)
  lux_cat_tower  ALTIN LASTİK KULE    lastiklerde altın şerit, siyah deri minder, altın direk     (0,45 m / 0,90 m)
  lux_cat_bowls  MERMER MAMA KABI     mermer kaide, altın kaplar, önde altın pati arması

Gerçek ölçek (kedi ~0,62 m boy, kıvrılınca ~0,3 m). Kurallar kit.py ile aynı: metre, ÖN = −Y (glTF'de +Z), orijin
tabanın ortası. Dünyada ortam ışığı yok: altın düşük metallik + hafif ışıma (bkz. props_v4_luks.py).
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v10_kedi.py
"""
import math as _m

import bmesh
import mathutils

# Kullanıcı kararı (2026-10-31): garaj ŞEHİR ölçeğinde (DecorBuilder.METER), kedi ×0,8 ile ondan iri kaldı → kedi
# eşyaları ×1,25. Aşağıdaki ölçüler TASARIM metresi; finish() öncesi bütün parçalar SCALE ile büyür. Kedinin konduğu
# noktalar (pet_world.gd PET_FURNITURE) aynı tasarım metresinde, oyunda PET_FURNITURE_SCALE ile çarpılır.
SCALE = 1.25
_finish = finish


def finish(name, export=True):
    m = mathutils.Matrix.Scale(SCALE, 4)
    for o in col().objects:
        o.matrix_world = m @ o.matrix_world
    return _finish(name, export)

# --- Malzemeler ---------------------------------------------------------------------------
TIRE = mat("Lastik", (0.045, 0.045, 0.05), 0.85)
TIRE_GR = mat("LastikDis", (0.07, 0.07, 0.075), 0.9)
PLY = mat("Kontrplak", (0.62, 0.45, 0.25), 0.7)
PLY_D = mat("KontrplakKenar", (0.42, 0.29, 0.14), 0.7)
TEAL = mat("KumasPetrol", (0.03, 0.26, 0.30), 0.95)
CREAM = mat("KremMinder", (0.86, 0.80, 0.68), 0.95)
RED_C = mat("MinderKirmizi", (0.62, 0.12, 0.10), 0.95)
SISAL = mat("Sisal", (0.66, 0.53, 0.33), 0.95)
SISAL_D = mat("SisalKoyu", (0.50, 0.39, 0.22), 0.95)
CHROME = mat("Krom", (0.78, 0.80, 0.84), 0.12, 0.3)
ORANGE = mat("Turuncu", (0.90, 0.38, 0.05), 0.45)
WHITE = mat("Beyaz", (0.90, 0.90, 0.88), 0.35)
KIBBLE = mat("Mama", (0.42, 0.22, 0.08), 0.8)
WATER = mat("Su", (0.12, 0.42, 0.82), 0.1)
NAVY = mat("Paspas", (0.09, 0.20, 0.35), 0.9)
FISH = mat("OyuncakBalik", (0.95, 0.70, 0.10), 0.6)
FISH_B = mat("OyuncakBalikMavi", (0.15, 0.45, 0.85), 0.6)
STRING = mat("Ip", (0.85, 0.82, 0.75), 0.9)
LEATHER_K = mat("SiyahDeri", (0.035, 0.035, 0.04), 0.45)
VELVET_R = mat("KadifeKirmizi", (0.45, 0.03, 0.05), 0.95)
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
MARBLE = mat("Mermer", (0.93, 0.92, 0.89), 0.18)
MARBLE_V = mat("MermerDamar", (0.62, 0.62, 0.64), 0.2)


# --- Yardımcılar --------------------------------------------------------------------------

def _obj_from_bm(bm, name, material):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col().objects.link(o)
    return _place(o, material)


def lathe(profile, material, loc=(0.0, 0.0, 0.0), seg=24, smooth=True, closed=False):
    """(yarıçap, yükseklik) hattını Z çevresinde döndürür. closed=True: hat kapalı halka (lastik kesiti),
    kapak yok; değilse uçlardaki yarıçap > 0 ise kapak."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = [bm.verts.new((loc[0] + r * _m.cos(2 * _m.pi * k / seg), loc[1] + r * _m.sin(2 * _m.pi * k / seg),
                              loc[2] + z)) for k in range(seg)]
        rings.append(ring)
    n = len(rings)
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((a[k], a[j], b[j], b[k]))
            f.smooth = smooth
    if not closed:
        if profile[0][0] > 0.0:
            bm.faces.new(list(reversed(rings[0])))
        if profile[-1][0] > 0.0:
            bm.faces.new(rings[-1])
    return _obj_from_bm(bm, "torna", material)


def tyre(z0, material=TIRE, od=0.60, width=0.19, loc=(0.0, 0.0), seg=24):
    """Yatık lastik (ekseni dikey): sırt dışta, yanaklar alt / üstte, ortası boş (jant yeri)."""
    ro, ri = od / 2, od / 2 - 0.10
    w = width
    prof = [(ri, 0.035), (ri + 0.018, 0.004), (ro - 0.03, 0.0), (ro - 0.006, 0.02), (ro, 0.05),
            (ro + 0.003, w * 0.5), (ro, w - 0.05), (ro - 0.006, w - 0.02), (ro - 0.03, w), (ri + 0.018, w - 0.004),
            (ri, w - 0.035)]
    lathe(prof, material, (loc[0], loc[1], z0), seg=seg, closed=True)
    # Sırt dişleri: sırt boyunca sığ çizgiler (uzaktan lastik okunsun)
    for k in range(seg):
        a = 2 * _m.pi * (k + 0.5) / seg
        box((0.012, 0.03, w * 0.62), (loc[0] + (ro + 0.002) * _m.cos(a), loc[1] + (ro + 0.002) * _m.sin(a),
                                      z0 + w * 0.5), TIRE_GR, rot=(0, 0, a))


def paw(cx, cy, z, s, material, face="up", depth=0.006):
    """Pati izi: büyük taban yastığı + dört parmak. face='up' zemine yatık, 'front' önden (−Y) bakan."""
    parts = [((0.0, -0.10), 0.42, 0.34), ((-0.30, 0.22), 0.15, 0.17), ((-0.11, 0.38), 0.15, 0.17),
             ((0.11, 0.38), 0.15, 0.17), ((0.30, 0.22), 0.15, 0.17)]
    for (dx, dy), rx, ry in parts:
        if face == "up":
            o = cyl(1.0, depth, (cx + dx * s, cy + dy * s, z + depth / 2), material, seg=14)
            o.scale = (rx * s, ry * s, 1.0)
        else:
            o = cyl(1.0, depth, (cx + dx * s, cy - depth / 2, z + dy * s), material, rot=(_m.pi / 2, 0, 0), seg=14)
            o.scale = (rx * s, ry * s, 1.0)          # yerel X/Y = disk yarıçapları (dönüşten önce), Z = kalınlık
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def toy_fish(x, y, z, yaw=0.3, s=1.0):
    def build():
        ball(0.045 * s, (0, 0, 0.022 * s), FISH, scale=(1.0, 0.45, 0.42), seg=12, ring=6)
        cone(0.028 * s, 0.0, 0.035 * s, (0.055 * s, 0, 0.022 * s), FISH_B, rot=(0, -_m.pi / 2, 0), seg=8)
        ball(0.006 * s, (-0.03 * s, -0.019 * s, 0.03 * s), NAVY, seg=6, ring=4)
    local(build, (x, y, z), yaw)


def local(build, loc=(0.0, 0.0, 0.0), yaw=0.0):
    before = {o.name for o in col().objects}
    build()
    m = mathutils.Matrix.Translation(loc) @ mathutils.Matrix.Rotation(yaw, 4, 'Z')
    for o in col().objects:
        if o.name not in before:
            o.matrix_world = m @ o.matrix_world


def sisal_post(x, y, z0, z1, wrap0, wrap1, pipe=CHROME, r=0.045):
    """Egzoz borusu direk: krom boru, ortası sisal halat sarılı (halka halka)."""
    cyl(r * 0.8, z1 - z0, (x, y, (z0 + z1) / 2), pipe, seg=14)
    cyl(r, wrap1 - wrap0, (x, y, (wrap0 + wrap1) / 2), SISAL, seg=14)
    z = wrap0 + 0.02
    k = 0
    while z < wrap1 - 0.01:
        torus(r, 0.0065, (x, y, z), SISAL_D if k % 2 else SISAL, seg=10, mseg=3)
        z += 0.045
        k += 1
    # Egzoz ağzı (üst uçta değil, altta yere oturan flanş)
    cyl(r * 1.6, 0.012, (x, y, z0 + 0.006), pipe, seg=14)


def bowl(cx, cy, outer, inner, fill, fill_h, r=0.08, h=0.06, base_z=0.0):
    prof = [(r * 0.78, 0.0), (r * 0.92, 0.008), (r, h * 0.85), (r * 1.04, h), (r * 0.93, h), (r * 0.80, h * 0.4),
            (0.0, h * 0.30)]
    lathe(prof, outer, (cx, cy, base_z), seg=24)
    lathe([(r * 0.90, h * 0.97), (r * 0.80, h * 0.45), (0.0, h * 0.34)], inner, (cx, cy, base_z + 0.001), seg=24)
    # Dolgu kabın iç yüzünün ÜSTÜNDE kalmalı (ilk sürümde beyaz sırın altında kalıp kap boş görünüyordu)
    if fill == "water":
        cyl(r * 0.88, 0.004, (cx, cy, base_z + fill_h), WATER, seg=24)
    elif fill == "food":
        rng = __import__("random").Random(7)
        lathe([(r * 0.88, 0.0), (r * 0.65, 0.010), (0.0, 0.016)], KIBBLE, (cx, cy, base_z + fill_h - 0.004), seg=16)
        for _k in range(22):
            a, d = rng.uniform(0, 2 * _m.pi), rng.uniform(0, r * 0.7)
            ball(0.008, (cx + d * _m.cos(a), cy + d * _m.sin(a), base_z + fill_h + 0.002 + rng.uniform(0, 0.006)),
                 KIBBLE, seg=6, ring=4)


# --- Eşyalar ------------------------------------------------------------------------------

def cat_bed(lux=False):
    lift = 0.05 if lux else 0.0
    shell = LEATHER_K if lux else TEAL
    cushion = VELVET_R if lux else CREAM
    # Kenarlık + taban tek torna: dış yanak, yuvarlak üst, içe inen kenar, iç zemin
    prof = [(0.0, 0.0), (0.235, 0.0), (0.258, 0.025), (0.268, 0.085), (0.258, 0.140), (0.232, 0.162),
            (0.200, 0.158), (0.182, 0.130), (0.175, 0.090), (0.168, 0.070), (0.0, 0.066)]
    lathe(prof, shell, (0, 0, lift), seg=32)
    # Minder: hafif kabarık disk
    lathe([(0.172, 0.0), (0.168, 0.012), (0.150, 0.019), (0.0, 0.020)], cushion, (0, 0, lift + 0.066), seg=32)
    if lux:
        torus(0.232, 0.008, (0, 0, lift + 0.160), GOLD, seg=40, mseg=6)     # altın biye
        torus(0.262, 0.006, (0, 0, lift + 0.030), GOLD, seg=40, mseg=6)
        for k in range(4):
            a = _m.pi / 4 + k * _m.pi / 2
            cone(0.022, 0.014, lift, (0.17 * _m.cos(a), 0.17 * _m.sin(a), lift / 2), GOLD, seg=10)
        # Önde altın taç arması (kenarlığın ön yüzünde)
        def crown():
            box((0.07, 0.008, 0.022), (0, 0, 0.011), GOLD)
            for dx in (-0.03, 0.0, 0.03):
                cone(0.012, 0.0, 0.03, (dx, 0, 0.037), GOLD, seg=4)
        local(crown, (0, -0.262, lift + 0.07))
        finish("lux_cat_bed")
    else:
        # Kenarlıkta dikiş şeridi + minderde oyuncak balık
        torus(0.262, 0.004, (0, 0, 0.085), CREAM, seg=40, mseg=4)
        toy_fish(0.10, -0.07, 0.086, yaw=0.6)
        finish("cat_bed")


def cat_tower(lux=False):
    tire_m = TIRE
    stripe = GOLD if lux else None
    for i in range(2):
        z = i * 0.19
        tyre(z, tire_m)
        if stripe is not None:
            torus(0.255, 0.006, (0, 0, z + 0.190), stripe, seg=40, mseg=4)   # yanakta altın şerit (beyaz yanak gibi)
            torus(0.255, 0.006, (0, 0, z + 0.001), stripe, seg=40, mseg=4)
    # Kontrplak tabla + minder (kedinin ilk konağı)
    cyl(0.28, 0.025, (0, 0, 0.3925), LEATHER_K if lux else PLY, seg=32)
    torus(0.28, 0.0125, (0, 0, 0.3925), GOLD if lux else PLY_D, seg=36, mseg=4)
    lathe([(0.23, 0.0), (0.225, 0.02), (0.20, 0.034), (0.0, 0.036)], VELVET_R if lux else RED_C,
          (0, 0, 0.405), seg=28)
    # Egzoz borusu direk + bakış platformu
    px = 0.36
    sisal_post(px, 0.0, 0.0, 0.85, 0.08, 0.70, pipe=GOLD if lux else CHROME)
    cyl(0.16, 0.025, (px, 0.0, 0.8625), LEATHER_K if lux else PLY, seg=24)
    torus(0.16, 0.0125, (px, 0.0, 0.8625), GOLD if lux else PLY_D, seg=28, mseg=4)
    lathe([(0.135, 0.0), (0.13, 0.016), (0.11, 0.026), (0.0, 0.028)], VELVET_R if lux else RED_C,
          (px, 0.0, 0.875), seg=24)
    # Sarkan oyuncak top (platformun ön kenarından)
    hx, hy = px - 0.08, -0.12
    rod((hx, hy, 0.86), (hx, hy, 0.62), 0.003, STRING, seg=4)
    ball(0.035, (hx, hy, 0.59), GOLD if lux else ORANGE, seg=12, ring=8)
    for k in range(3):
        a = k * 2 * _m.pi / 3
        cone(0.012, 0.0, 0.05, (hx + 0.012 * _m.cos(a), hy + 0.012 * _m.sin(a), 0.535), FISH_B if not lux else VELVET_R,
             rot=(_m.pi, 0, 0), seg=5)
    finish("lux_cat_tower" if lux else "cat_tower")


def cat_bowls(lux=False):
    if lux:
        # Mermer kaide, kapların yuvası, damarlar, önde altın pati
        box((0.46, 0.24, 0.07), (0, 0, 0.035), MARBLE)
        box((0.48, 0.26, 0.012), (0, 0, 0.006), MARBLE_V)
        for dx, dy, l, a in ((-0.12, 0.05, 0.16, 0.4), (0.08, -0.06, 0.20, -0.3), (0.15, 0.07, 0.10, 1.0)):
            box((l, 0.004, 0.0015), (dx, dy, 0.0705), MARBLE_V, rot=(0, 0, a))
        for (sx, sy, lx, ly) in ((0, -0.12, 0.46, 0.008), (0, 0.12, 0.46, 0.008), (-0.23, 0, 0.008, 0.24),
                                 (0.23, 0, 0.008, 0.24)):
            box((lx, ly, 0.008), (sx, sy, 0.07), GOLD)      # üst kenarda altın çıta
        bowl(-0.11, 0.0, GOLD, GOLD, "food", 0.048, base_z=0.03)
        bowl(0.11, 0.0, GOLD, GOLD, "water", 0.05, base_z=0.03)
        paw(0.0, -0.121, 0.035, 0.045, GOLD, face="front")
        finish("lux_cat_bowls")
    else:
        # Paspas (yuvarlatılmış köşeler: iki kutu + dört disk) ve pati izi
        box((0.46, 0.20, 0.008), (0, 0, 0.004), NAVY)
        box((0.40, 0.26, 0.008), (0, 0, 0.004), NAVY)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cyl(0.03, 0.008, (sx * 0.20, sy * 0.10, 0.004), NAVY, seg=12)
        paw(0.0, -0.085, 0.008, 0.032, ORANGE)
        bowl(-0.11, 0.015, ORANGE, WHITE, "food", 0.048, base_z=0.008)
        bowl(0.11, 0.015, ORANGE, WHITE, "water", 0.05, base_z=0.008)
        finish("cat_bowls")


for lux in (False, True):
    cat_bed(lux)
    clear()
    cat_tower(lux)
    clear()
    cat_bowls(lux)
    clear()
