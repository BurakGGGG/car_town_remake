"""MODİFİYE GARAJI — ARAÇLAR → MODİFİYE'nin kendi 3D mekânı (kullanıcı isteği 2026-10-22: "depolar gibi bir modifiye
garajı, aşırı lüks ve güzel"; taslaklardan A SİYAH & ALTIN seçildi, "etrafa daha kaliteli dekorlar koy, dolu dursun").

Tek araç ortadaki döner tablada. Kamera kategoriye göre parçaya gider (kaput, teker, egzoz…) ve tabla aracı kameraya
çevirir: kamera hep odanın güneydoğu yarısında, kuzey / batı duvarlarına bakar. Yine de oda her yönden kapalı ve dolu
(depolardaki kesik diorama değil): pişirme yüzleri kameraya değil ODANIN İÇİNE çevirir (export_garage.py modgarage).

Yerleşim (X doğu, Y kuzey; metre): oda 20 × 16 × 5,6; döner tabla (10, 8.4) r 2,7.
  KUZEY  üç arkadan aydınlatılmış parça vitrini, aralarda altın aplikler, ortada altın amblem halkası
  BATI   ışıklı jant duvarı, siyah-altın alet takımı + altın alet panosu, kask / kupa rafları
  DOĞU   konyak deri salon (kanepe, iki berjer, halı, mermer sehpa, ayaklı lamba, tablo), kuzeydoğuda bar
  GÜNEY  siyah seksiyonel kapı (altın çerçeve), cam fanuslarda altın V8 ve maket araç, saksılar
  TAVAN  kasetli tavan + altın kenarlar, tablanın üstünde altın halka ışık, spotlar, bar sarkıtları
  ZEMİN  siyah mermer, altın damarlar ve kakma halkalar; tablanın arkasında kadife kordonlu direkler

Oyun düğümleri (export): Shell / Props / Ceiling / TableBody (köşe rengi), TableTop (oyunda yarı saydam parlak siyah:
altında aracın aynalı kopyası = yansıma), Floor (tablanın altı delik; floor.png), Car (araç yeri, burun +Z).

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/modgarage.py -- preview <wide|hood|wheel|west|north|east|rear> <çıktı.png> [genişlik yükseklik örnek]
  blender -b --factory-startup --python tools/garages/export_garage.py -- modgarage [--fast]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 20.0, 16.0, 5.6
TABLE = (10.0, 8.4)
TABLE_R = 2.7
TABLE_TOP = 0.16
CAR_YAW = 35.0
PREVIEW_CAR = "porsche_gt3"
INTERIOR = (W / 2, D / 2, 2.2)   # pişirmede açık yüzeyler buraya döner


def mats():
    return {
        "a_wall": k_mat("a_wall", "#1C1D21", rough=0.55),
        "a_panel": k_mat("a_panel", "#2A2B31", rough=0.45),
        "a_ceiling": k_mat("a_ceiling", "#141417", rough=0.8),
        "a_coffer": k_mat("a_coffer", "#1E1E22", rough=0.7),
        "gold": k_mat("a_gold", "#D2A64B", rough=0.28, metal=0.95),
        "gold_dark": k_mat("a_gold_dark", "#8C6A2C", rough=0.35, metal=0.9),
        "gloss_black": k_mat("a_gloss_black", "#0E0E10", rough=0.12),
        "marble_black": k_mat("a_marble_black", "#19191C", rough=0.2),
        "marble_white": k_mat("a_marble_white", "#E6E1D8", rough=0.25),
        "leather": k_mat("a_leather", "#8A4A2A", rough=0.55),
        "leather_dark": k_mat("a_leather_dark", "#5E301B", rough=0.6),
        "velvet": k_mat("a_velvet", "#5A1420", rough=0.9),
        "rug": k_mat("a_rug", "#34101A", rough=0.95),
        "rug_field": k_mat("a_rug_field", "#4D1824", rough=0.95),
        "warm": k_mat("a_warm", "#FFE2B0", rough=0.5, emit="#FFD08A", strength=9.0),
        "warm_soft": k_mat("a_warm_soft", "#FFE9C8", rough=0.5, emit="#FFDDB0", strength=4.0),
        "shade": k_mat("a_shade", "#F2D9A8", rough=0.6, emit="#FFD9A0", strength=2.5),
        "niche": k_mat("a_niche", "#B89B6A", rough=0.5, emit="#E8C27F", strength=0.7),
        "glass_shelf": k_mat("a_glass", "#B9D3D6", rough=0.1),
        "glass_case": k_mat("a_glass_case", "#AFC6C9", rough=0.05),
        "visor": k_mat("a_visor", "#1A2228", rough=0.1, metal=0.4),
        "red": k_mat("a_red", "#B3221E", rough=0.4, metal=0.2),
        "white_gloss": k_mat("a_white_gloss", "#ECE9E2", rough=0.2),
        "canvas_a": k_mat("a_canvas_a", "#C9A24A", rough=0.8),
        "canvas_b": k_mat("a_canvas_b", "#7E1F24", rough=0.8),
        "canvas_c": k_mat("a_canvas_c", "#EDE6D8", rough=0.8),
        "canvas_d": k_mat("a_canvas_d", "#2D3A4A", rough=0.8),
        "bottle_amber": k_mat("a_bottle_amber", "#9A5E1C", rough=0.15),
        "bottle_green": k_mat("a_bottle_green", "#2F5B3A", rough=0.15),
        "bottle_clear": k_mat("a_bottle_clear", "#CFD8D6", rough=0.1),
        "plant": k_mat("a_plant", "#3F6E37", rough=0.9),
        "plant_dark": k_mat("a_plant_dark", "#2E5229", rough=0.9),
        "trunk": k_mat("a_trunk", "#5A4632", rough=0.9),
        "book_a": k_mat("a_book_a", "#6B1E22", rough=0.8),
        "book_b": k_mat("a_book_b", "#1F3048", rough=0.8),
    }


# --- Geometri yardımcıları -------------------------------------------------------------------------

def side_cyl(b, center, radius, z0, z1, material, segs=64):
    """Kapaksız silindir yüzü (dışa bakar)."""
    v, f = [], []
    for i in range(segs):
        a = math.tau * i / segs
        v.append((center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius, z0))
        v.append((center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius, z1))
    for i in range(segs):
        j = (i + 1) % segs
        f.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    b._add(v, f, material)


def disc(b, center, radius, z, material, segs=64):
    v = [(center[0], center[1], z)]
    for i in range(segs):
        a = math.tau * i / segs
        v.append((center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius, z))
    f = [(0, 1 + i, 1 + (i + 1) % segs) for i in range(segs)]
    b._add(v, f, material)


def ring(b, center, radius, z, thick, material, segs=48):
    pts = [(center[0] + math.cos(a) * radius, center[1] + math.sin(a) * radius, z)
           for a in [i * math.tau / segs for i in range(segs + 1)]]
    b.tube(pts, thick, material, segs=6)


def vring(b, center, radius, thick, material, axis='Y', segs=40):
    """Duvara dik halka (jant çerçevesi, amblem)."""
    x, y, z = center
    if axis == 'Y':
        pts = [(x + math.cos(a) * radius, y, z + math.sin(a) * radius) for a in [i * math.tau / segs for i in range(segs + 1)]]
    else:
        pts = [(x, y + math.cos(a) * radius, z + math.sin(a) * radius) for a in [i * math.tau / segs for i in range(segs + 1)]]
    b.tube(pts, thick, material, segs=5)


def turbo(b, c, m, s=1.0, mat="chrome"):
    x, y, z = c
    b.cyl((x, y, z), 0.22 * s, 0.18 * s, m[mat], axis='Y', segs=18)
    b.cyl((x, y + 0.13 * s, z), 0.14 * s, 0.12 * s, m["steel"], axis='Y', segs=16)
    b.cyl((x + 0.2 * s, y, z + 0.08 * s), 0.07 * s, 0.25 * s, m[mat], axis='X', segs=10)
    b.cyl((x, y - 0.1 * s, z), 0.1 * s, 0.06 * s, m["black"], axis='Y', segs=14)


def rim(b, c, m, r=0.36, mat="chrome", tyre=True, axis='Y', spokes=5, face=-1.0):
    """Jant (+lastik). face: jant yüzünün baktığı yön (eksen boyunca işaret)."""
    x, y, z = c
    if tyre:
        b.cyl((x, y, z), r + 0.12, 0.24, m["rubber"], axis=axis, segs=24)
    b.cyl((x, y, z), r, 0.26, m[mat], axis=axis, segs=24)
    off = 0.14 * face
    if axis == 'Y':
        b.cyl((x, y + off, z), r * 0.22, 0.04, m["steel_dark"], axis='Y', segs=12)
        for k in range(spokes):
            a = k * math.tau / spokes
            b.box((x + math.cos(a) * r * 0.55, y + off, z + math.sin(a) * r * 0.55), (0.07, 0.035, r * 0.75), m[mat],
                  rot=(0, -math.degrees(a) + 90, 0))
    else:
        b.cyl((x + off, y, z), r * 0.22, 0.04, m["steel_dark"], axis='X', segs=12)
        for k in range(spokes):
            a = k * math.tau / spokes
            b.box((x + off, y + math.cos(a) * r * 0.55, z + math.sin(a) * r * 0.55), (0.035, 0.07, r * 0.75), m[mat],
                  rot=(math.degrees(a) - 90, 0, 0))


def exhaust_tips(b, c, m, mat="chrome"):
    x, y, z = c
    for dx in (-0.1, 0.1):
        b.cyl((x + dx, y, z), 0.075, 0.3, m[mat], axis='Y', segs=14)
        b.cyl((x + dx, y - 0.152, z), 0.06, 0.01, m["black"], axis='Y', segs=14)


def caliper(b, c, m, color="red"):
    soft_box(b, c, (0.32, 0.12, 0.18), m[color], radius=0.04)


def helmet(b, c, m, color, yaw=0.0):
    x, y, z = c
    b.ball((x, y, z), 0.17, m[color], segs=12, rings=8, scale=(1.0, 1.15, 0.95), rot=(0, 0, yaw))
    b.ball(b._xf((0, -0.09, 0.0), (x, y, z), (0, 0, yaw)), 0.13, m["visor"], segs=10, rings=6, scale=(1.05, 0.6, 0.55),
           rot=(0, 0, yaw))
    b.box(b._xf((0, 0.0, 0.05), (x, y, z), (0, 0, yaw)), (0.05, 0.36, 0.02), m["gold"], rot=(0, 0, yaw))


def trophy(b, base, m, s=1.0):
    x, y, z = base
    b.box((x, y, z + 0.05 * s), (0.16 * s, 0.16 * s, 0.1 * s), m["gloss_black"])
    b.cyl((x, y, z + 0.16 * s), 0.025 * s, 0.12 * s, m["gold"], segs=8)
    b.cyl((x, y, z + 0.3 * s), 0.05 * s, 0.18 * s, m["gold"], segs=14, r2=0.11 * s)
    for sx in (-1, 1):
        b.tube([(x + sx * 0.08 * s, y, z + 0.36 * s), (x + sx * 0.15 * s, y, z + 0.32 * s), (x + sx * 0.08 * s, y, z + 0.25 * s)],
               0.012 * s, m["gold"], segs=5)


def bottle(b, base, m, mat, h=0.32):
    x, y, z = base
    b.cyl((x, y, z + h * 0.32), 0.045, h * 0.64, m[mat], segs=10)
    b.cyl((x, y, z + h * 0.72), 0.045, h * 0.16, m[mat], segs=10, r2=0.018)
    b.cyl((x, y, z + h * 0.9), 0.018, h * 0.2, m[mat], segs=8)


def book_row(b, origin, length, m, seed=1, axis='X'):
    r = random.Random(seed)
    x, y, z = origin
    t = 0.0
    while t < length:
        w = r.uniform(0.03, 0.06)
        hh = r.uniform(0.18, 0.26)
        mat = m[r.choice(["book_a", "book_b", "gold_dark", "leather_dark"])]
        if axis == 'X':
            b.box((x + t + w / 2, y, z + hh / 2), (w, 0.16, hh), mat)
        else:
            b.box((x, y + t + w / 2, z + hh / 2), (0.16, w, hh), mat)
        t += w + 0.004


def sofa(b, base, m, rot=0.0, length=2.6, mat="leather", tufted=True):
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.24), (length, 0.95, 0.34), m[mat], radius=0.12, rot=(0, 0, rot))
    soft_box(b, p(0, 0.38, 0.62), (length, 0.24, 0.62), m[mat], radius=0.11, rot=(0, 0, rot))
    for s in (-1, 1):
        soft_box(b, p(s * (length / 2 - 0.12), 0, 0.5), (0.26, 0.95, 0.42), m[mat], radius=0.11, rot=(0, 0, rot))
    n = max(2, int(round(length / 0.9)))
    for i in range(n):
        cx = -length / 2 + 0.25 + (i + 0.5) * (length - 0.5) / n
        soft_box(b, p(cx, -0.02, 0.45), ((length - 0.5) / n - 0.05, 0.8, 0.14), m["leather_dark" if mat == "leather" else mat],
                 radius=0.06, rot=(0, 0, rot))
    if tufted:   # kapitone düğmeler (arkalık)
        for i in range(int(length / 0.3)):
            for k in range(2):
                b.ball(p(-length / 2 + 0.25 + i * 0.3, 0.255, 0.55 + k * 0.2), 0.018, m["leather_dark"], segs=6, rings=4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(p(sx * (length / 2 - 0.15), sy * 0.35, 0.04), 0.035, 0.08, m["gold"], segs=8)


def armchair(b, base, m, rot=0.0):
    sofa(b, base, m, rot=rot, length=1.05, tufted=False)


def rug(b, center, size, m, rot=0.0):
    x, y = center
    sx, sy = size
    soft_box(b, (x, y, 0.006), (sx, sy, 0.012), m["rug"], radius=0.004, rot=(0, 0, rot))
    soft_box(b, (x, y, 0.009), (sx - 0.3, sy - 0.3, 0.012), m["gold_dark"], radius=0.0, rot=(0, 0, rot))
    soft_box(b, (x, y, 0.012), (sx - 0.4, sy - 0.4, 0.012), m["rug_field"], radius=0.0, rot=(0, 0, rot))
    b.cyl((x, y, 0.016), min(sx, sy) * 0.22, 0.01, m["gold_dark"], segs=32)
    b.cyl((x, y, 0.019), min(sx, sy) * 0.18, 0.01, m["rug"], segs=32)


def floor_lamp(b, base, m, rot=0.0):
    """Altın kavisli ayaklı lamba: mermer taban, yay, kubbe (alt yüzü ışıyan)."""
    x, y, z = base
    b.cyl((x, y, 0.04), 0.22, 0.08, m["marble_white"], segs=20)
    pts = []
    for i in range(9):
        t = i / 8
        pts.append(b._xf((t * 1.2, 0, 0.08 + math.sin(t * math.pi * 0.85) * 1.9 + t * 0.2), (x, y, 0), (0, 0, rot)))
    b.tube(pts, 0.022, m["gold"], segs=6)
    tip = pts[-1]
    b.cyl((tip[0], tip[1], tip[2] - 0.12), 0.26, 0.2, m["gold"], segs=18, r2=0.08)
    disc(b, (tip[0], tip[1]), 0.24, tip[2] - 0.225, m["shade"], segs=18)


def pendant(b, top, m, drop=1.4):
    x, y, z = top
    b.cyl((x, y, z - drop / 2), 0.006, drop, m["black"], segs=4)
    b.cyl((x, y, z - drop - 0.08), 0.06, 0.18, m["gold"], segs=14, r2=0.2)
    disc(b, (x, y), 0.19, z - drop - 0.175, m["shade"], segs=14)


def planter(b, base, m, seed=1, h=0.7, tall=True):
    r = random.Random(seed)
    x, y, z = base
    soft_box(b, (x, y, h / 2), (0.6, 0.6, h), m["marble_black"], radius=0.04)
    soft_box(b, (x, y, h - 0.02), (0.64, 0.64, 0.04), m["gold"], radius=0.01)
    if tall:   # zeytin ağacı: gövde + yuvarlak taç
        b.tube([(x, y, h), (x + 0.05, y, h + 0.7), (x - 0.04, y + 0.03, h + 1.3)], 0.045, m["trunk"], segs=6)
        for k in range(16):
            a = r.uniform(0, math.tau)
            rr = r.uniform(0.0, 0.45)
            b.ball((x + math.cos(a) * rr, y + math.sin(a) * rr, h + 1.4 + r.uniform(-0.2, 0.55)), r.uniform(0.17, 0.27),
                   m["plant" if k % 3 else "plant_dark"], segs=7, rings=5)
    else:
        for k in range(12):
            a = r.uniform(0, math.tau)
            b.ball((x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, h + 0.15 + r.uniform(0, 0.35)), r.uniform(0.14, 0.22),
                   m["plant"], segs=7, rings=5)


def framed_art(b, center, size, m, rot=0.0, palette=("canvas_a", "canvas_b", "canvas_c"), seed=1, light=True):
    """Altın çerçeveli soyut tablo (yazısız: yarış şeritleri) + üstünde resim lambası. rot: 0 = güneye bakar."""
    r = random.Random(seed)
    x, y, z = center
    w, h = size
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0), (w + 0.16, 0.06, h + 0.16), m["gold"], radius=0.02, rot=(0, 0, rot))
    soft_box(b, p(0, -0.032, 0), (w, 0.02, h), m["canvas_c"], radius=0.0, rot=(0, 0, rot))
    k = 0
    for i in range(r.randint(3, 4)):   # çapraz yarış şeritleri
        off = (i - 1.5) * w * 0.16
        soft_box(b, p(off, -0.045, 0), (w * 0.09, 0.01, h * 0.95), m[palette[k % len(palette)]], radius=0.0, rot=(0, 0, rot))
        k += 1
    if light:
        soft_box(b, p(0, -0.12, h / 2 + 0.16), (w * 0.6, 0.12, 0.05), m["gold"], radius=0.02, rot=(0, 0, rot))
        plane(b, p(0, -0.12, h / 2 + 0.13), (w * 0.56, 0.06), m["warm_soft"], rot=(180, 0, rot))


def glass_case(b, base, m, size=(0.9, 0.9, 1.0), plinth=0.9):
    """Siyah mermer kaide + fanus (saydamlık yok: kenarları altın profil, tavanı ışıklı)."""
    x, y, z = base
    sx, sy, sz = size
    soft_box(b, (x, y, plinth / 2), (sx + 0.1, sy + 0.1, plinth), m["marble_black"], radius=0.03)
    soft_box(b, (x, y, plinth + 0.02), (sx + 0.14, sy + 0.14, 0.04), m["gold"], radius=0.01)
    for cx in (-1, 1):
        for cy in (-1, 1):
            b.box((x + cx * sx / 2, y + cy * sy / 2, plinth + sz / 2), (0.025, 0.025, sz), m["gold"])
    soft_box(b, (x, y, plinth + sz), (sx + 0.03, sy + 0.03, 0.03), m["gold"], radius=0.01)
    plane(b, (x, y, plinth + sz - 0.02), (sx * 0.8, sy * 0.8), m["warm_soft"], rot=(180, 0, 0))


def engine_v8(b, base, m, s=1.0, rot=0.0):
    """Altın kaplama V8: blok, iki silindir sırası, kapaklar, emme manifoldu."""
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx * s, dy * s, dz * s), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.16), (0.42 * s, 0.6 * s, 0.3 * s), m["steel_dark"], radius=0.03, rot=(0, 0, rot))
    for side in (-1, 1):
        soft_box(b, p(side * 0.16, 0, 0.38), (0.18 * s, 0.58 * s, 0.2 * s), m["steel"], radius=0.03, rot=(0, side * 30, rot))
        soft_box(b, p(side * 0.22, 0, 0.5), (0.13 * s, 0.6 * s, 0.07 * s), m["gold"], radius=0.025, rot=(0, side * 30, rot))
    soft_box(b, p(0, 0, 0.52), (0.16 * s, 0.5 * s, 0.12 * s), m["gold"], radius=0.03, rot=(0, 0, rot))
    b.cyl(p(0, -0.34, 0.2), 0.11 * s, 0.05 * s, m["chrome"], axis='Y', segs=16, rot=(0, 0, rot))


def scale_car(b, base, m, s=0.32, color="red", rot=0.0):
    """Maket araç (sade: gövde + kabin + teker). s: gerçek boya oran."""
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx * s, dy * s, dz * s), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, 0.32), (1.75 * s, 4.2 * s, 0.5 * s), m[color], radius=0.12 * s, rot=(0, 0, rot))
    soft_box(b, p(0, 0.3, 0.72), (1.45 * s, 2.0 * s, 0.42 * s), m["visor"], radius=0.14 * s, rot=(0, 0, rot))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(p(sx * 0.82, sy * 1.35, 0.3), 0.3 * s, 0.22 * s, m["rubber"], axis='X', segs=12, rot=(0, 0, rot))


def stanchion(b, base, m):
    x, y, z = base
    b.cyl((x, y, 0.02), 0.17, 0.04, m["gold"], segs=16)
    b.cyl((x, y, 0.49), 0.028, 0.94, m["gold"], segs=10)
    b.ball((x, y, 0.98), 0.05, m["gold"], segs=10, rings=6)


def tool_chest(b, base, m, rot=0.0, w=1.1, h=1.1):
    """Siyah lake alet dolabı (altın kulplar). rot 0: önü güneye."""
    x, y, z = base
    def p(dx, dy, dz):
        return b._xf((dx, dy, dz), (x, y, z), (0, 0, rot))
    soft_box(b, p(0, 0, h / 2), (w, 0.6, h), m["gloss_black"], radius=0.04, rot=(0, 0, rot))
    soft_box(b, p(0, 0, h + 0.02), (w + 0.04, 0.64, 0.04), m["marble_black"], radius=0.01, rot=(0, 0, rot))
    for k in range(5):
        zz = 0.18 + k * (h - 0.3) / 4
        b.box(p(0, -0.305, zz), (w * 0.62, 0.02, 0.025), m["gold"], rot=(0, 0, rot))
        b.box(p(0, -0.302, zz - 0.07), (w - 0.08, 0.01, 0.004), m["a_panel"], rot=(0, 0, rot))
    for sx in (-1, 1):
        b.cyl(p(sx * (w / 2 - 0.08), -0.2, 0.04), 0.04, 0.05, m["gold"], axis='X', segs=8, rot=(0, 0, rot))


def coffers(b, m):
    """Kasetli tavan: ızgara kirişler (altın alt kenar)."""
    zb = H - 0.32
    step = 2.5
    xs = [1.25 + i * step for i in range(int((W - 2.5) / step) + 1)]
    ys = [1.25 + j * step for j in range(int((D - 2.5) / step) + 1)]
    for x in xs:
        b.box((x, D / 2, zb), (0.22, D - 2.5, 0.32), m["a_coffer"])
        b.box((x, D / 2, zb - 0.165), (0.12, D - 2.5, 0.015), m["gold_dark"])
    for y in ys:
        b.box((W / 2, y, zb), (W - 2.5, 0.22, 0.32), m["a_coffer"])
        b.box((W / 2, y, zb - 0.165), (W - 2.5, 0.12, 0.015), m["gold_dark"])


def floor_with_hole(col, name, tex_path, size, center, radius, segs=72):
    """Dokulu zemin, döner tablanın altı delik (oyunda tablanın yarı saydam üstünden aracın aynalı kopyası görünür;
    zemin araya girmesin). UV = XY / boyut. Köşelerde ışın tam köşeye düşsün diye dört köşe açısı eklenir."""
    w, d = size
    cx, cy = center
    angles = sorted(set([i * math.tau / segs for i in range(segs)] +
                        [math.atan2(py - cy, px - cx) % math.tau for px, py in ((0, 0), (w, 0), (w, d), (0, d))]))
    def rect_hit(a):
        dx, dy = math.cos(a), math.sin(a)
        ts = []
        if abs(dx) > 1e-9:
            ts += [(0 - cx) / dx, (w - cx) / dx]
        if abs(dy) > 1e-9:
            ts += [(0 - cy) / dy, (d - cy) / dy]
        t = min(t for t in ts if t > 0 and -1e-6 <= cx + dx * t <= w + 1e-6 and -1e-6 <= cy + dy * t <= d + 1e-6)
        return (cx + dx * t, cy + dy * t)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    inner = [bm.verts.new((cx + math.cos(a) * radius, cy + math.sin(a) * radius, 0.0)) for a in angles]
    outer = [bm.verts.new((*rect_hit(a), 0.0)) for a in angles]
    n = len(angles)
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new([inner[i], inner[j], outer[j], outer[i]])
        for loop in f.loops:
            loop[uv].uv = (loop.vert.co.x / w, loop.vert.co.y / d)
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    mt = bpy.data.materials.new(name + "_mat")
    mt.use_nodes = True
    nt = mt.node_tree
    bsdf = next(nd for nd in nt.nodes if nd.type == 'BSDF_PRINCIPLED')
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(tex_path)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    me.materials.append(mt)
    o["jy_textured"] = True
    return o


# --- Zemin dokusu ----------------------------------------------------------------------------------

def floor_texture(out_dir, ppm=80):
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    n = _fbm((h, w), 70, 801)
    warp = _fbm((h, w), 30, 811, 4)
    veins = np.abs(np.sin((mx * 0.7 - my * 0.45 + warp * 7.0) * 2.4))
    vein = np.clip(1.0 - veins / 0.05, 0, 1) * (0.4 + 0.6 * _fbm((h, w), 18, 821, 2))
    veins2 = np.abs(np.sin((mx * 0.3 + my * 0.8 + warp * 5.0) * 3.1))
    vein2 = np.clip(1.0 - veins2 / 0.03, 0, 1) * 0.5
    base = np.array(_hex("#141416"))[None, None, :] * (0.9 + 0.2 * n[..., None])
    base = base * (1 - vein[..., None] * 0.7) + vein[..., None] * np.array(_hex("#B8913F")) * 0.7
    base = base * (1 - vein2[..., None] * 0.5) + vein2[..., None] * np.array(_hex("#55555A")) * 0.5
    slab = (np.abs(mx % 2.0) < 0.01) | (np.abs(my % 2.0) < 0.01)
    base[slab] = np.array(_hex("#2A2A2E"))
    r = np.sqrt((mx - TABLE[0]) ** 2 + (my - TABLE[1]) ** 2)
    band = (np.abs(r - (TABLE_R + 0.45)) < 0.035) | (np.abs(r - (TABLE_R + 1.1)) < 0.02)
    # iki halka arasında sekiz kollu altın pusula gülü kakması
    ang = np.arctan2(my - TABLE[1], mx - TABLE[0])
    frac = (ang * 8 / (2 * np.pi)) % 1.0
    star = (r > TABLE_R + 0.5) & (r < TABLE_R + 1.08) & (np.minimum(frac, 1 - frac) * 2 * np.pi * r / 8 < 0.02)
    base[band | star] = np.array(_hex("#C99E45"))
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "modgarage_floor.png")
    _save_image("mg_floor", base[::-1], path)
    return path


# --- Oda ---------------------------------------------------------------------------------------------

def room_box(b, m):
    plane(b, (W / 2, D, H / 2), (W, H), m["a_wall"], rot=(90, 0, 0))
    plane(b, (W / 2, 0.0, H / 2), (W, H), m["a_wall"], rot=(90, 0, 180))
    plane(b, (0.0, D / 2, H / 2), (D, H), m["a_wall"], rot=(90, 0, 90))
    plane(b, (W, D / 2, H / 2), (D, H), m["a_wall"], rot=(90, 0, -90))
    plane(b, (W / 2, D / 2, H), (W, D), m["a_ceiling"], rot=(180, 0, 0))
    for (cx, cy, sx, sy) in ((W / 2, D - 0.04, W, 0.08), (W / 2, 0.04, W, 0.08), (0.04, D / 2, 0.08, D), (W - 0.04, D / 2, 0.08, D)):
        b.box((cx, cy, 0.06), (sx, sy, 0.12), m["gold_dark"])


def wall_panels(b, m, wall, skip=()):
    """Koyu paneller + aralarda dikey altın kanatlar. skip: (başlangıç, bitiş) aralıkları panelsiz."""
    length = W if wall in "NS" else D
    step = 1.6
    for i in range(int(length / step)):
        t = step / 2 + i * step
        if any(a <= t <= b_ for a, b_ in skip):
            continue
        if wall == "N":
            c, rot, fin = (t, D - 0.03, 2.6), (90, 0, 0), (t - step / 2, D - 0.06, 2.6)
        elif wall == "S":
            c, rot, fin = (t, 0.03, 2.6), (90, 0, 180), (t - step / 2, 0.06, 2.6)
        elif wall == "W":
            c, rot, fin = (0.03, t, 2.6), (90, 0, 90), (0.06, t - step / 2, 2.6)
        else:
            c, rot, fin = (W - 0.03, t, 2.6), (90, 0, -90), (W - 0.06, t - step / 2, 2.6)
        plane(b, c, (step - 0.1, 4.6), m["a_panel"], rot=rot)
        if i > 0:
            b.box(fin, (0.05, 0.05, 4.6), m["gold"])


def shell(col, m):
    b = Builder("Shell", seed=601)
    room_box(b, m)
    wall_panels(b, m, "N", skip=[(W / 2 - 6.2, W / 2 + 6.2)])
    wall_panels(b, m, "W")
    wall_panels(b, m, "E", skip=[(4.0, 12.0)])
    wall_panels(b, m, "S", skip=[(W / 2 - 3.2, W / 2 + 3.2)])
    # tavan kenarı: alçak bant + gizli ışık (cove)
    for (cx, cy, sx, sy) in ((W / 2, D - 0.6, W, 1.2), (W / 2, 0.6, W, 1.2), (0.6, D / 2, 1.2, D), (W - 0.6, D / 2, 1.2, D)):
        b.box((cx, cy, H - 0.25), (sx, sy, 0.5), m["a_ceiling"])
    for (cx, cy, sx, sy) in ((W / 2, D - 1.22, W - 2.4, 0.04), (W / 2, 1.22, W - 2.4, 0.04), (1.22, D / 2, 0.04, D - 2.4),
                             (W - 1.22, D / 2, 0.04, D - 2.4)):
        b.box((cx, cy, H - 0.52), (sx, sy, 0.04), m["warm"])
    # süpürgelik ışığı
    for (cx, cy, sx, sy) in ((W / 2, D - 0.12, W - 0.4, 0.03), (W / 2, 0.12, W - 0.4, 0.03), (0.12, D / 2, 0.03, D - 0.4),
                             (W - 0.12, D / 2, 0.03, D - 0.4)):
        b.box((cx, cy, 0.14), (sx, sy, 0.03), m["warm_soft"])
    # köşe pilastrları: siyah mermer + altın başlık / kaide
    for (px, py) in ((0.35, 0.35), (W - 0.35, 0.35), (0.35, D - 0.35), (W - 0.35, D - 0.35)):
        soft_box(b, (px, py, H / 2), (0.7, 0.7, H), m["marble_black"], radius=0.03)
        soft_box(b, (px, py, 0.15), (0.8, 0.8, 0.3), m["gold_dark"], radius=0.02)
        soft_box(b, (px, py, H - 0.62), (0.8, 0.8, 0.18), m["gold"], radius=0.02)
    return b.finish(col)


def north_wall(b, m):
    """Üç arkadan aydınlatılmış vitrin (turbo / jant / egzoz + kaliper), aralarda altın aplikler, amblem halkası."""
    xs = (W / 2 - 4.4, W / 2, W / 2 + 4.4)
    plane(b, (W / 2, D - 0.02, 2.6), (12.4, 4.6), m["a_panel"], rot=(90, 0, 0))
    for i, x in enumerate(xs):
        for dz in (-1.5, 1.5):
            soft_box(b, (x, D - 0.25, 2.3 + dz), (3.0, 0.5, 0.16), m["gold_dark"], radius=0.03)
        for dx in (-1.42, 1.42):
            soft_box(b, (x + dx, D - 0.25, 2.3), (0.16, 0.5, 3.16), m["gold_dark"], radius=0.03)
        plane(b, (x, D - 0.05, 2.3), (2.7, 2.85), m["niche"], rot=(90, 0, 0))
        b.box((x, D - 0.3, 3.68), (2.6, 0.06, 0.03), m["warm"])   # üst LED
        for row in range(3):
            z = 1.18 + row * 0.88
            soft_box(b, (x, D - 0.3, z), (2.6, 0.42, 0.03), m["glass_shelf"], radius=0.0)
            b.box((x, D - 0.51, z), (2.6, 0.02, 0.035), m["gold"])
            if i == 0:
                for k in range(3):
                    turbo(b, (x - 0.8 + k * 0.8, D - 0.32, z + 0.24), m, s=0.85, mat="gold" if (k + row) % 2 else "chrome")
            elif i == 1:
                for k in range(2):
                    rim(b, (x - 0.55 + k * 1.1, D - 0.3, z + 0.38), m, r=0.25, mat="chrome" if (k + row) % 2 else "gold", tyre=False)
            else:
                for k in range(3):
                    if row == 1:
                        caliper(b, (x - 0.8 + k * 0.8, D - 0.32, z + 0.12), m, "red" if k != 1 else "gold")
                    else:
                        exhaust_tips(b, (x - 0.8 + k * 0.8, D - 0.25, z + 0.12), m, mat="chrome" if k % 2 else "gold")
        # vitrin önü kaide
        soft_box(b, (x, D - 0.35, 0.35), (3.0, 0.7, 0.7), m["gloss_black"], radius=0.04)
        soft_box(b, (x, D - 0.35, 0.72), (3.06, 0.76, 0.04), m["gold"], radius=0.01)
    for x in (W / 2 - 2.2, W / 2 + 2.2):   # aplikler
        soft_box(b, (x, D - 0.1, 2.4), (0.14, 0.16, 1.6), m["gold"], radius=0.03)
        plane(b, (x, D - 0.19, 2.4), (0.06, 1.4), m["warm"], rot=(90, 0, 0))
    vring(b, (W / 2, D - 0.08, 4.55), 0.5, 0.05, m["gold"])
    b.cyl((W / 2, D - 0.06, 4.55), 0.42, 0.04, m["gloss_black"], axis='Y', segs=32)
    vring(b, (W / 2, D - 0.1, 4.55), 0.26, 0.03, m["gold"])
    for k in range(8):   # amblem: sekiz altın ışın (yazısız)
        a = k * math.tau / 8
        b.box((W / 2 + math.cos(a) * 0.36, D - 0.1, 4.55 + math.sin(a) * 0.36), (0.035, 0.02, 0.13), m["gold"],
              rot=(0, -math.degrees(a) + 90, 0))


def west_wall(b, m):
    """Işıklı jant duvarı, alet takımı + altın alet panosu, kask / kupa rafları."""
    for row in range(2):   # ışıklı jant duvarı (2 × 4): altın halka + arkasında ışık diski
        for k in range(4):
            y, z = 9.8 + k * 1.3, 1.25 + row * 1.35
            b.cyl((0.07, y, z), 0.66, 0.02, m["gloss_black"], axis='X', segs=28)
            vring(b, (0.09, y, z), 0.62, 0.022, m["warm"], axis='X')     # arkadan halka ışık
            vring(b, (0.11, y, z), 0.68, 0.025, m["gold"], axis='X')
            rim(b, (0.35, y, z), m, r=0.34, mat="gold" if (k + row) % 2 else "chrome", axis='X', face=1.0)
    for i, y in enumerate((2.6, 3.75, 4.9)):   # alet takımı
        tool_chest(b, (0.5, y, 0.0), m, rot=90)
    soft_box(b, (0.5, 3.75, 1.16), (0.7, 3.5, 0.06), m["marble_black"], radius=0.01)
    soft_box(b, (0.06, 3.75, 2.25), (0.05, 3.4, 1.6), m["gloss_black"], radius=0.01)
    b.box((0.09, 3.75, 3.07), (0.02, 3.42, 0.03), m["gold"])
    b.box((0.09, 3.75, 1.43), (0.02, 3.42, 0.03), m["gold"])
    r = random.Random(17)
    for k in range(22):   # altın el aletleri
        y = 2.25 + (k % 11) * 0.3
        z = 2.65 - (k // 11) * 0.7
        ln = r.uniform(0.32, 0.52)
        soft_box(b, (0.11, y, z), (0.03, 0.045, ln), m["gold" if k % 3 else "chrome"], radius=0.015, rot=(r.uniform(-8, 8), 0, 0))
        b.ball((0.11, y, z + ln / 2), 0.04, m["gold" if k % 3 else "chrome"], segs=8, rings=5)
    plane(b, (0.12, 3.75, 3.3), (3.3, 0.05), m["warm"], rot=(90, 0, 90))
    for z in (3.65, 4.35):   # kask + kupa rafları
        soft_box(b, (0.22, 3.75, z), (0.4, 3.4, 0.04), m["gold"], radius=0.01)
    for k in range(4):
        helmet(b, (0.25, 2.5 + k * 0.85, 3.84), m, ["red", "gloss_black", "white_gloss", "gold"][k], yaw=90)
    for k in range(5):
        trophy(b, (0.25, 2.35 + k * 0.7, 4.37), m, s=0.9 + 0.15 * (k % 2))
    planter(b, (0.65, 7.0, 0.0), m, seed=21)
    planter(b, (0.65, D - 1.2, 0.0), m, seed=22)


def east_wall(b, m):
    """Konyak deri salon + tablolar + bar (kuzeydoğu)."""
    rug(b, (W - 2.3, 6.4), (3.4, 4.6), m)
    sofa(b, (W - 0.85, 6.4, 0.0), m, rot=-90, length=3.0)   # arkalık duvarda (+X), oturak batıya
    armchair(b, (W - 2.4, 3.9, 0.0), m, rot=165)            # kuzeye, sehpaya
    armchair(b, (W - 2.4, 8.9, 0.0), m, rot=15)             # güneye, sehpaya
    b.cyl((W - 2.35, 6.4, 0.24), 0.62, 0.05, m["marble_white"], segs=28)
    b.cyl((W - 2.35, 6.4, 0.12), 0.1, 0.22, m["gold"], segs=10)
    b.cyl((W - 2.35, 6.4, 0.025), 0.4, 0.05, m["gold"], segs=20)
    book_row(b, (W - 2.55, 6.2, 0.265), 0.35, m, seed=3)
    scale_car(b, (W - 2.2, 6.6, 0.265), m, s=0.07, color="red", rot=30)
    for y in (4.2, 8.6):   # yan sehpalar
        b.cyl((W - 0.6, y, 0.28), 0.25, 0.04, m["marble_white"], segs=18)
        b.cyl((W - 0.6, y, 0.14), 0.03, 0.28, m["gold"], segs=8)
    floor_lamp(b, (W - 0.55, 3.3, 0.0), m, rot=150)
    framed_art(b, (W - 0.06, 6.4, 2.75), (2.6, 1.6), m, rot=-90, palette=("canvas_a", "canvas_b", "gold"), seed=5)
    for y in (4.4, 8.4):
        framed_art(b, (W - 0.06, y, 2.6), (0.9, 1.2), m, rot=-90, palette=("canvas_d", "canvas_a"), seed=int(y))
    # BAR (kuzeydoğu köşe)
    bx, by = W - 1.9, D - 2.6
    soft_box(b, (bx, by, 0.56), (0.75, 3.2, 1.12), m["marble_black"], radius=0.05)
    soft_box(b, (bx, by, 1.15), (0.9, 3.35, 0.06), m["gold"], radius=0.02)
    plane(b, (bx - 0.385, by, 0.6), (3.0, 0.05), m["warm"], rot=(90, 0, 90))
    for k in range(6):
        b.box((bx - 0.38, by - 1.4 + k * 0.56, 0.6), (0.01, 0.04, 1.0), m["gold"])
    soft_box(b, (W - 0.15, by, 2.4), (0.3, 3.4, 2.6), m["niche"], radius=0.01)
    for z in (1.55, 2.25, 2.95):
        soft_box(b, (W - 0.32, by, z), (0.36, 3.3, 0.03), m["glass_shelf"], radius=0.0)
        for k in range(11):
            bottle(b, (W - 0.3, by - 1.5 + k * 0.3, z + 0.015), m, ["bottle_amber", "bottle_green", "bottle_clear"][k % 3],
                   h=0.28 + 0.06 * ((k * 7) % 3))
    soft_box(b, (W - 0.32, by, 3.75), (0.5, 3.6, 0.12), m["gold_dark"], radius=0.02)
    for k in range(3):
        y = by - 1.0 + k * 1.0
        b.cyl((bx - 0.75, y, 0.4), 0.025, 0.8, m["gold"], segs=8)
        b.cyl((bx - 0.75, y, 0.02), 0.2, 0.03, m["gold"], segs=14)
        b.cyl((bx - 0.75, y, 0.82), 0.2, 0.08, m["leather"], segs=16)
        pendant(b, (bx, y, H - 0.3), m, drop=2.0)


def south_wall(b, m):
    """Siyah seksiyonel kapı (altın çerçeve), fanuslarda altın V8 + maket araç, saksılar, iki tablo."""
    x0 = W / 2
    soft_box(b, (x0, 0.12, 2.0), (6.4, 0.24, 4.0), m["gold"], radius=0.03)
    soft_box(b, (x0, 0.16, 1.95), (6.0, 0.2, 3.8), m["gloss_black"], radius=0.02)
    for k in range(6):
        b.box((x0, 0.27, 0.35 + k * 0.62), (5.9, 0.02, 0.025), m["gold_dark"])
    for k in range(5):
        plane(b, (x0 - 2.4 + k * 1.2, 0.275, 3.4), (0.9, 0.35), m["glass_case"], rot=(90, 0, 180))
    plane(b, (x0, 0.29, 4.1), (6.2, 0.06), m["warm"], rot=(90, 0, 180))
    glass_case(b, (x0 - 4.6, 1.3, 0.0), m)
    engine_v8(b, (x0 - 4.6, 1.3, 0.92), m, s=1.1, rot=30)
    glass_case(b, (x0 + 4.6, 1.3, 0.0), m)
    scale_car(b, (x0 + 4.6, 1.3, 0.92), m, s=0.17, color="gold", rot=-30)
    planter(b, (x0 - 3.6, 0.55, 0.0), m, seed=31, tall=False)
    planter(b, (x0 + 3.6, 0.55, 0.0), m, seed=32, tall=False)
    for x in (2.6, W - 2.6):
        framed_art(b, (x, 0.06, 2.8), (1.6, 1.1), m, rot=180, palette=("canvas_b", "canvas_a", "canvas_c"), seed=int(x))


def props(col, m):
    b = Builder("Props", seed=603)
    north_wall(b, m)
    west_wall(b, m)
    east_wall(b, m)
    south_wall(b, m)
    # tablanın arkasında kadife kordonlu altın direkler (yay, kuzey yarısı: kameranın önüne düşmez)
    x, y = TABLE
    posts = [(x + math.cos(math.radians(a)) * (TABLE_R + 1.35), y + math.sin(math.radians(a)) * (TABLE_R + 1.35))
             for a in (60, 90, 120, 150)]
    for px, py in posts:
        stanchion(b, (px, py, 0.0), m)
    for (ax, ay), (cx, cy) in zip(posts[:-1], posts[1:]):
        b.tube([(ax, ay, 0.9), ((ax + cx) / 2, (ay + cy) / 2, 0.68), (cx, cy, 0.9)], 0.024, m["velvet"], segs=6)
    return b.finish(col)


def ceiling(col, m):
    b = Builder("Ceiling", seed=605)
    coffers(b, m)
    x, y = TABLE
    ring(b, (x, y), 3.2, H - 0.7, 0.09, m["warm"], segs=64)
    ring(b, (x, y), 3.45, H - 0.7, 0.03, m["gold"], segs=64)
    ring(b, (x, y), 2.95, H - 0.7, 0.02, m["gold"], segs=64)
    for a in (0, 90, 180, 270):
        b.cyl((x + math.cos(math.radians(a)) * 3.3, y + math.sin(math.radians(a)) * 3.3, H - 0.4), 0.01, 0.6, m["gold"], segs=4)
    for i in range(8):
        a = i * math.tau / 8 + 0.3
        spot_lamp(b, (x + math.cos(a) * 5.0, y + math.sin(a) * 5.0, H - 0.55), (x, y, 0.6), m)
    for (sx, sy, tx, ty) in WALL_SPOTS:
        spot_lamp(b, (sx, sy, H - 0.55), (tx, ty, 2.2), m)
    return b.finish(col)


WALL_SPOTS = ((4.5, D - 2.0, W / 2 - 4.4, D), (W / 2, D - 2.0, W / 2, D), (W - 4.5, D - 2.0, W / 2 + 4.4, D),
              (2.0, 3.8, 0, 3.8), (2.0, 11.4, 0, 11.4), (W - 2.6, 6.4, W, 6.4))


def table_parts(col, m):
    """Döner tabla: gövde (yan yüz + altın kenar + alttan ışıma) ve ayrı üst disk (oyunda yarı saydam, altında yansıma)."""
    x, y = TABLE
    b = Builder("TableBody", seed=607)
    side_cyl(b, (x, y), TABLE_R, 0.0, TABLE_TOP, m["gloss_black"], segs=72)
    ring(b, (x, y), TABLE_R + 0.01, TABLE_TOP - 0.015, 0.04, m["gold"], segs=72)
    ring(b, (x, y), TABLE_R + 0.05, 0.03, 0.035, m["warm"], segs=72)
    body = b.finish(col)
    t = Builder("TableTop", seed=609)
    disc(t, (x, y), TABLE_R, TABLE_TOP, m["gloss_black"], segs=72)
    ring(t, (x, y), TABLE_R - 0.35, TABLE_TOP + 0.002, 0.012, m["gold_dark"], segs=72)
    top = t.finish(col, ao=False)
    return body, top


def car_marker(col):
    e = bpy.data.objects.new("Car", None)
    e.empty_display_type = 'ARROWS'
    e.location = (TABLE[0], TABLE[1], TABLE_TOP)
    e.rotation_euler = (0, 0, math.radians(CAR_YAW))
    col.objects.link(e)
    return e


def build(tex_dir):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("ModGarage")
    m = gmats()
    m.update(mats())
    static = new_col("Static", root)
    shell(static, m)
    props(static, m)
    ceiling(static, m)
    table = new_col("Table", root)
    body, top = table_parts(table, m)
    floor = floor_with_hole(new_col("FloorCol", root), "Floor", floor_texture(tex_dir), (W, D), TABLE, TABLE_R)
    markers = new_col("Markers", root)
    car_marker(markers)
    return {"root": root, "static": static, "table_body": body, "table_top": top, "floor": floor}


# --- Önizleme ----------------------------------------------------------------------------------------

def preview_lights():
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.05, 0.05, 0.06, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    x, y = TABLE
    def area(name, loc, target, size, energy, color, shape='DISK', size_y=None):
        l = bpy.data.lights.new(name, 'AREA')
        l.shape = shape
        l.size = size
        if size_y:
            l.size_y = size_y
        l.energy = energy
        l.color = color
        o = bpy.data.objects.new(name, l)
        scn.collection.objects.link(o)
        o.location = loc
        aim(o, target)
    def spot(loc, target, energy, color, size=38):
        l = bpy.data.lights.new("Spot", 'SPOT')
        l.energy = energy
        l.color = color
        l.spot_size = math.radians(size)
        l.spot_blend = 0.7
        l.shadow_soft_size = 0.2
        o = bpy.data.objects.new("Spot", l)
        scn.collection.objects.link(o)
        o.location = loc
        aim(o, target)
    area("Halo", (x, y, H - 0.8), (x, y, 0), 6.0, 1800, (1.0, 0.86, 0.66))
    for i in range(8):
        a = i * math.tau / 8 + 0.3
        spot((x + math.cos(a) * 5.0, y + math.sin(a) * 5.0, H - 0.7), (x, y, 0.6), 650, (1.0, 0.88, 0.7))
    for (sx, sy, tx, ty) in WALL_SPOTS:
        spot((sx, sy, H - 0.7), (tx, ty, 2.2), 260, (1.0, 0.86, 0.66), size=55)
    area("Fill", (W / 2, D / 2, H - 0.35), (W / 2, D / 2, 0), 14.0, 700, (1.0, 0.88, 0.75), shape='RECTANGLE', size_y=10.0)
    area("Bar", (W - 1.9, D - 2.6, H - 1.2), (W - 1.9, D - 2.6, 0), 3.0, 220, (1.0, 0.8, 0.55), shape='RECTANGLE', size_y=3.0)


SHOTS = {
    # ad: (konum, hedef, lens) — Blender metresi
    "wide": ((TABLE[0] + 5.9, TABLE[1] - 7.0, 2.5), (TABLE[0] - 0.5, TABLE[1] + 1.4, 1.45), 24),
    "west": ((TABLE[0] + 2.5, TABLE[1] - 2.5, 2.2), (0.0, 6.0, 2.2), 24),
    "north": ((TABLE[0] + 1.0, TABLE[1] - 4.5, 2.2), (TABLE[0], D, 2.3), 22),
    "east": ((TABLE[0] - 4.0, TABLE[1] - 2.0, 2.0), (W, 6.5, 1.8), 22),
    "rear": ((TABLE[0] - 1.0, TABLE[1] + 4.5, 2.2), (TABLE[0], 0.0, 2.0), 22),
}


def preview_camera(shot, width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    x, y = TABLE
    a = math.radians(CAR_YAW)
    if shot == "hood":
        cam.lens = 30
        nose = (x + math.sin(a) * 1.9, y - math.cos(a) * 1.9)
        co.location = (nose[0] + math.sin(a) * 2.2 + 0.9, nose[1] - math.cos(a) * 2.2 - 0.3, 2.3)
        aim(co, (nose[0] - math.sin(a) * 0.6, nose[1] + math.cos(a) * 0.6, 0.85))
    elif shot == "wheel":
        cam.lens = 32
        wheel = (x + math.sin(a) * 1.3 + math.cos(a) * 0.95, y - math.cos(a) * 1.3 + math.sin(a) * 0.95)
        side = (math.cos(a), math.sin(a))
        co.location = (wheel[0] + side[0] * 2.6 + 0.6, wheel[1] + side[1] * 2.6 - 1.2, 0.9)
        aim(co, (wheel[0], wheel[1], 0.45))
    else:
        loc, target, lens = SHOTS[shot]
        cam.lens = lens
        co.location = loc
        aim(co, target)
    scn.camera = co
    scn.render.resolution_x = width
    scn.render.resolution_y = height


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    if mode == "preview":
        shot = argv[1] if len(argv) > 1 else "wide"
        out = argv[2] if len(argv) > 2 else "/tmp/modgarage.png"
        width = int(argv[3]) if len(argv) > 3 else 1280
        height = int(argv[4]) if len(argv) > 4 else 720
        samples = int(argv[5]) if len(argv) > 5 else 48
        parts = build(os.path.join(os.path.dirname(out), "tex"))
        bsdf = next(n for n in parts["floor"].data.materials[0].node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs["Roughness"].default_value = 0.22   # cilalı zemin (oyunda: tablada aynalı araç)
        place_cars([(TABLE[0], TABLE[1], CAR_YAW, TABLE_TOP)], [PREVIEW_CAR])
        preview_lights()
        preview_camera(shot, width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):
    main()
