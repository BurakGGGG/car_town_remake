"""EVCİL HAYVAN konsept çizimleri (rapor için, 2026-10-22): oyunun çizgi-film dilinde (yumuşak, yuvarlak, köşe rengi)
üç evcil hayvan ve MAHALLE garajında nasıl duracakları. Üretim modeli değil: oranlar, renkler ve yerleşim kararı için.

  TEKİR       turuncu tekir garaj kedisi (mahalle kedisi: araç tavanında uyur)
  VAN KEDİSİ  beyaz, bir gözü mavi bir gözü kehribar (nadir / prestij)
  KARABAŞ     Kangal tipi çoban köpeği: krem gövde, siyah maske, kırmızı tasma (kapıda müşteriyi karşılar)
  Köşe eşyaları: mini garaj biçiminde köpek kulübesi (kepenkli), lastik yığınından kedi kulesi, mama / su kabı, top.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/pets/pet_concepts.py -- <lineup|garage|close> <çıktı.png> [genişlik yükseklik örnek]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
EXPORTING = True   # mahalle.py'nin kendi önizlemesi çalışmasın: yalnız kurulum işlevleri
exec(open(os.path.join(REPO, "tools", "garages", "mahalle.py")).read())


def pmats():
    return {
        "tabby": k_mat("p_tabby", "#E38B3B", rough=0.9),
        "tabby_dark": k_mat("p_tabby_dark", "#A9561E", rough=0.9),
        "cream": k_mat("p_cream", "#F4EBDD", rough=0.9),
        "van": k_mat("p_van", "#F7F4EE", rough=0.9),
        "van_spot": k_mat("p_van_spot", "#D9A05C", rough=0.9),
        "dog": k_mat("p_dog", "#DCC59A", rough=0.9),
        "dog_light": k_mat("p_dog_light", "#EFE1C3", rough=0.9),
        "mask": k_mat("p_mask", "#2B2622", rough=0.85),
        "eye": k_mat("p_eye", "#141414", rough=0.2),
        "eye_blue": k_mat("p_eye_blue", "#3E7BD8", rough=0.2),
        "eye_amber": k_mat("p_eye_amber", "#E0A030", rough=0.2),
        "shine": k_mat("p_shine", "#FFFFFF", rough=0.2),
        "pink": k_mat("p_pink", "#E79AA6", rough=0.7),
        "collar": k_mat("p_collar", "#C0332B", rough=0.5),
        "tag": k_mat("p_tag", "#E2B341", rough=0.3, metal=0.9),
        "bed": k_mat("p_bed", "#3F6FB0", rough=0.95),
        "bed_in": k_mat("p_bed_in", "#E9DCC2", rough=0.95),
        "bowl": k_mat("p_bowl", "#C8372D", rough=0.4),
        "kibble": k_mat("p_kibble", "#8A5A2B", rough=0.9),
        "water": k_mat("p_water", "#7FC4E8", rough=0.1),
        "ball": k_mat("p_ball", "#C9E34A", rough=0.8),
        "house": k_mat("p_house", "#F2B630", rough=0.7),
        "roof": k_mat("p_roof", "#C8372D", rough=0.6),
        "rope": k_mat("p_rope", "#C9A877", rough=0.95),
    }


def _p(b, base, rot, dx, dy, dz, s):
    return b._xf((dx * s, dy * s, dz * s), base, (0, 0, rot))


def eyes(b, base, rot, s, m, y, z, spread, r, left="eye", right="eye"):
    for side, mat in ((-1, left), (1, right)):
        b.ball(_p(b, base, rot, side * spread, y, z, s), r * s, m[mat], segs=10, rings=7)
        b.ball(_p(b, base, rot, side * spread + 0.008, y - r * 0.8, z + r * 0.45, s), r * 0.32 * s, m["shine"], segs=6, rings=4)


def cat_sit(b, base, m, rot=0.0, s=1.0, coat="tabby", stripe="tabby_dark", belly="cream", eye_l="eye", eye_r="eye"):
    """Oturan kedi (burun -Y'ye, rot ile döner). s: ölçek (1 ≈ 0,5 m oturma boyu; oyunda okunur olsun diye iri)."""
    P = lambda dx, dy, dz: _p(b, base, rot, dx, dy, dz, s)
    b.ball(P(0, 0.02, 0.17), 0.15 * s, m[coat], segs=12, rings=9, scale=(0.95, 0.9, 1.25), rot=(-12, 0, rot))   # gövde
    b.ball(P(0, -0.06, 0.16), 0.1 * s, m[belly], segs=10, rings=7, scale=(0.85, 0.6, 1.25), rot=(0, 0, rot))     # göğüs
    for side in (-1, 1):
        b.ball(P(side * 0.09, 0.07, 0.07), 0.085 * s, m[coat], segs=10, rings=7, scale=(0.8, 1.2, 0.85), rot=(0, 0, rot))  # but
        b.limb(P(side * 0.05, -0.07, 0.16), P(side * 0.055, -0.1, 0.02), 0.03 * s, 0.032 * s, m[coat], segs=8)       # ön bacak
        b.ball(P(side * 0.055, -0.115, 0.02), 0.034 * s, m[belly], segs=8, rings=5, scale=(1.0, 1.3, 0.6))         # pati
    head = (0, -0.07, 0.4)
    b.ball(P(*head), 0.115 * s, m[coat], segs=12, rings=9, scale=(1.1, 0.95, 0.92), rot=(0, 0, rot))
    b.ball(P(0, -0.17, 0.37), 0.05 * s, m[belly], segs=10, rings=6, scale=(1.35, 0.8, 0.8), rot=(0, 0, rot))     # ağız
    b.ball(P(0, -0.205, 0.39), 0.016 * s, m["pink"], segs=6, rings=4)                                              # burun
    eyes(b, base, rot, s, m, -0.165, 0.425, 0.045, 0.024, eye_l, eye_r)
    for side in (-1, 1):
        ear = P(side * 0.07, -0.05, 0.5)
        b.cyl(ear, 0.04 * s, 0.08 * s, m[coat], segs=6, r2=0.004 * s, rot=(side * -12, 0, rot))
        b.cyl(P(side * 0.068, -0.058, 0.495), 0.022 * s, 0.05 * s, m["pink"], segs=6, r2=0.002 * s, rot=(side * -12, 0, rot))
    if stripe:
        for k in range(3):   # tekir çizgileri: alında "M", sırtta ve yanlarda halkalar
            b.ball(P((k - 1) * 0.03, -0.165, 0.475), 0.012 * s, m[stripe], segs=6, rings=4, scale=(0.7, 0.5, 2.4))
        for k in range(4):
            z = 0.3 - k * 0.055
            for side in (-1, 1):
                b.ball(P(side * 0.112, 0.04 + k * 0.012, z), 0.022 * s, m[stripe], segs=8, rings=5, scale=(0.35, 2.2, 0.55),
                       rot=(0, 0, rot))
            b.ball(P(0, 0.15 - k * 0.005, z + 0.02), 0.022 * s, m[stripe], segs=8, rings=5, scale=(2.6, 0.5, 0.55), rot=(0, 0, rot))
    tail = [P(0.04, 0.14, 0.05), P(0.17, 0.12, 0.03), P(0.2, -0.02, 0.03), P(0.13, -0.12, 0.04)]
    b.tube(tail, 0.03 * s, m[coat], segs=8)
    if stripe:
        b.ball(tail[-1], 0.032 * s, m[stripe], segs=8, rings=5)


def cat_sleep(b, base, m, rot=0.0, s=1.0, coat="tabby", stripe="tabby_dark", belly="cream"):
    """Kıvrılmış uyuyan kedi (araç tavanında / yatağında)."""
    P = lambda dx, dy, dz: _p(b, base, rot, dx, dy, dz, s)
    b.ball(P(0, 0, 0.08), 0.19 * s, m[coat], segs=12, rings=8, scale=(1.0, 0.78, 0.48), rot=(0, 0, rot))
    head = P(0.15, -0.07, 0.11)
    b.ball(head, 0.1 * s, m[coat], segs=11, rings=8, scale=(1.1, 0.95, 0.85))
    b.ball(P(0.2, -0.13, 0.09), 0.045 * s, m[belly], segs=8, rings=5, scale=(1.2, 0.9, 0.7))
    for side in (-1, 1):   # kapalı gözler: ince koyu çizgi
        b.ball(P(0.15 + side * 0.04, -0.155, 0.125), 0.016 * s, m["mask"], segs=6, rings=4, scale=(1.6, 0.5, 0.35))
        b.cyl(P(0.15 + side * 0.06, -0.04, 0.19), 0.035 * s, 0.07 * s, m[coat], segs=6, r2=0.004 * s, rot=(side * -18, 0, rot))
    if stripe:
        for k in range(4):
            b.ball(P(-0.08 + k * 0.06, 0.04, 0.15), 0.018 * s, m[stripe], segs=6, rings=4, scale=(0.6, 3.5, 0.6))
    b.tube([P(-0.17, 0.02, 0.05), P(-0.12, -0.15, 0.04), P(0.05, -0.18, 0.05), P(0.13, -0.17, 0.06)], 0.032 * s, m[coat], segs=8)


def dog_sit(b, base, m, rot=0.0, s=1.0):
    """Karabaş (Kangal tipi): krem gövde, siyah maske, kıvrık kuyruk, kırmızı tasma + altın künye."""
    P = lambda dx, dy, dz: _p(b, base, rot, dx, dy, dz, s)
    b.ball(P(0, 0.04, 0.3), 0.24 * s, m["dog"], segs=14, rings=10, scale=(0.9, 1.0, 1.25), rot=(-15, 0, rot))
    b.ball(P(0, -0.1, 0.3), 0.15 * s, m["dog_light"], segs=12, rings=8, scale=(0.95, 0.6, 1.3), rot=(0, 0, rot))
    for side in (-1, 1):
        b.ball(P(side * 0.15, 0.13, 0.12), 0.13 * s, m["dog"], segs=10, rings=7, scale=(0.75, 1.3, 0.9), rot=(0, 0, rot))
        b.limb(P(side * 0.08, -0.12, 0.3), P(side * 0.09, -0.15, 0.03), 0.05 * s, 0.05 * s, m["dog"], segs=8)
        b.ball(P(side * 0.09, -0.18, 0.03), 0.055 * s, m["dog_light"], segs=8, rings=5, scale=(1.0, 1.35, 0.6))
    # tasma + künye
    collar = [P(math.cos(a) * 0.115, -0.04 + math.sin(a) * 0.1, 0.55) for a in [i * math.tau / 16 for i in range(17)]]
    b.tube(collar, 0.022 * s, m["collar"], segs=6)
    b.cyl(P(0, -0.15, 0.5), 0.03 * s, 0.01 * s, m["tag"], axis='Y', segs=10, rot=(0, 0, rot))
    # baş
    b.ball(P(0, -0.08, 0.72), 0.17 * s, m["dog"], segs=14, rings=10, scale=(1.05, 1.0, 0.95), rot=(0, 0, rot))
    b.ball(P(0, -0.22, 0.66), 0.09 * s, m["mask"], segs=12, rings=8, scale=(1.05, 1.15, 0.82), rot=(0, 0, rot))   # siyah maske
    b.ball(P(0, -0.31, 0.68), 0.032 * s, m["eye"], segs=8, rings=5, scale=(1.3, 1.0, 0.9))                          # burun
    b.ball(P(0, -0.27, 0.6), 0.03 * s, m["pink"], segs=8, rings=5, scale=(1.2, 0.8, 1.4), rot=(25, 0, rot))     # dil
    eyes(b, base, rot, s, m, -0.215, 0.78, 0.07, 0.028)
    for side in (-1, 1):   # sarkık kulaklar (koyu): başın yanından aşağı
        b.ball(P(side * 0.155, -0.06, 0.66), 0.07 * s, m["mask"], segs=10, rings=7, scale=(0.4, 0.85, 1.45),
               rot=(0, side * -12, rot))
    # yukarı kıvrık kuyruk
    b.tube([P(0, 0.26, 0.2), P(0.03, 0.36, 0.38), P(0.02, 0.3, 0.52), P(-0.05, 0.2, 0.5)], 0.045 * s, m["dog"], segs=8)


def dog_house(b, base, m, rot=0.0, s=1.0):
    """Mini garaj biçiminde kulübe: sarı gövde, kırmızı çatı, yarı açık kepenk, üstünde kemik tabelası (yazısız)."""
    P = lambda dx, dy, dz: _p(b, base, rot, dx, dy, dz, s)
    soft_box(b, P(0, 0, 0.45), (1.1 * s, 0.95 * s, 0.9 * s), m["house"], radius=0.05, rot=(0, 0, rot))
    for side in (-1, 1):
        soft_box(b, P(side * 0.3, 0.0, 1.02), (0.62 * s, 1.08 * s, 0.07 * s), m["roof"], radius=0.02,
                 rot=(side * 0, side * 28, rot))
    soft_box(b, P(0, -0.48, 0.38), (0.62 * s, 0.03 * s, 0.6 * s), m["black"], radius=0.01, rot=(0, 0, rot))       # kapı boşluğu
    for k in range(4):   # kepenk (yarı açık)
        b.box(P(0, -0.5, 0.62 + k * 0.045), (0.64 * s, 0.03 * s, 0.035 * s), m["steel"], rot=(0, 0, rot))
    soft_box(b, P(0, -0.49, 0.93), (0.42 * s, 0.03 * s, 0.13 * s), m["white"], radius=0.02, rot=(0, 0, rot))      # tabela
    for side in (-1, 1):   # kemik simgesi
        b.ball(P(side * 0.1, -0.51, 0.95), 0.025 * s, m["kibble"], segs=6, rings=4)
        b.ball(P(side * 0.1, -0.51, 0.91), 0.025 * s, m["kibble"], segs=6, rings=4)
    b.box(P(0, -0.51, 0.93), (0.18 * s, 0.02 * s, 0.03 * s), m["kibble"], rot=(0, 0, rot))


def cat_tower(b, base, m, s=1.0):
    """Lastik yığınından kedi kulesi: üç lastik + halat sarılı direk + tepede minder."""
    x, y, z = base
    for k in range(3):
        tire(b, (x, y, z + 0.13 * s + k * 0.24 * s), r=0.34 * s, w=0.24 * s, m=m)
    b.cyl((x, y, z + 0.9 * s), 0.07 * s, 0.6 * s, m["rope"], segs=12)
    b.cyl((x, y, z + 1.22 * s), 0.3 * s, 0.08 * s, m["bed"], segs=20)
    b.cyl((x, y, z + 1.27 * s), 0.25 * s, 0.04 * s, m["bed_in"], segs=20)
    b.ball((x + 0.18 * s, y - 0.25 * s, z + 0.75 * s), 0.05 * s, m["ball"], segs=8, rings=6)   # asılı top
    b.cyl((x + 0.18 * s, y - 0.25 * s, z + 0.95 * s), 0.004 * s, 0.35 * s, m["rope"], segs=4)


def bowls(b, base, m, s=1.0):
    x, y, z = base
    for dx, fill in ((-0.18, "kibble"), (0.18, "water")):
        b.cyl((x + dx * s, y, z + 0.05 * s), 0.13 * s, 0.1 * s, m["bowl"], segs=16, r2=0.16 * s)
        b.cyl((x + dx * s, y, z + 0.095 * s), 0.13 * s, 0.01 * s, m[fill], segs=16)
    soft_box(b, (x, y, z + 0.005), (0.75 * s, 0.4 * s, 0.01), m["bed_in"], radius=0.0)


def pet_bed(b, base, m, s=1.0):
    x, y, z = base
    b.cyl((x, y, z + 0.08 * s), 0.42 * s, 0.16 * s, m["bed"], segs=24)
    b.cyl((x, y, z + 0.13 * s), 0.34 * s, 0.08 * s, m["bed_in"], segs=24)


def smooth(obj):
    """Konsept çiziminde yumuşak gölgeleme (oyunda da evcil hayvanlar araçlar gibi yumuşak çizilir)."""
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


# --- Sahneler ---------------------------------------------------------------------------------

def lineup(out, w, h, samples):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    m = gmats()
    m.update(pmats())
    col = new_col("Lineup")
    b = Builder("Studio", seed=3)
    soft_box(b, (0, 0, -0.05), (8, 6, 0.1), k_mat("p_floor", "#3A3A40", rough=0.6), radius=0.0)
    # kavisli fon
    for i in range(16):
        a0, a1 = math.radians(i * 180 / 16), math.radians((i + 1) * 180 / 16)
        r = 3.0
        v = [(math.cos(a0) * r, math.sin(a0) * r, 0), (math.cos(a1) * r, math.sin(a1) * r, 0),
             (math.cos(a1) * r, math.sin(a1) * r, 3), (math.cos(a0) * r, math.sin(a0) * r, 3)]
        b._add(v, [(0, 1, 2, 3)], k_mat("p_back", "#2B2B31", rough=0.9))
    b.finish(col, ao=False)
    p = Builder("Pets", seed=5)
    cat_sit(p, (-1.25, 0.2, 0.0), m, rot=18, s=1.5)
    cat_sit(p, (0.0, 0.0, 0.0), m, rot=0, s=1.5, coat="van", stripe="van_spot", belly="van", eye_l="eye_blue", eye_r="eye_amber")
    dog_sit(p, (1.35, 0.25, 0.0), m, rot=-20, s=1.1)
    smooth(p.finish(col))
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.08, 0.08, 0.1, 1.0)
    for name, loc, energy, size in (("Key", (2.5, -3.0, 3.5), 900, 3.0), ("Fill", (-3.0, -2.5, 2.0), 350, 4.0),
                                    ("Rim", (0.0, 2.5, 3.0), 500, 2.0)):
        l = bpy.data.lights.new(name, 'AREA')
        l.size = size
        l.energy = energy
        l.color = (1.0, 0.94, 0.86) if name != "Rim" else (0.85, 0.9, 1.0)
        lo = bpy.data.objects.new(name, l)
        scn.collection.objects.link(lo)
        lo.location = loc
        aim(lo, (0, 0, 0.4))
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 45
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
    co.location = (0.4, -4.6, 1.6)
    aim(co, (0.05, 0.1, 0.48))
    scn.camera = co
    scn.render.resolution_x = w
    scn.render.resolution_y = h
    render(out, w, h, samples)


def garage(out, w, h, samples, close=False):
    root, groups = build(os.path.join(os.path.dirname(out), "tex"))
    show_levels(groups, {"Floor": 2, "Walls": 2, "Lights": 2, "Lift": 2, "Park": 2})
    cars = ["tofas_sahin", "bmw_e46", "lambo_huracan", "vw_golf_7", "porsche_gt3"]
    place_cars(SLOTS, cars)
    bpy.context.view_layer.update()
    m = gmats()
    m.update(pmats())
    col = new_col("Pets")
    b = Builder("PetsGarage", seed=9)
    # Tekir: 2. park yerindeki aracın tavanında uyur (tavan yüksekliği modelden)
    holder = bpy.data.objects["Car_bmw_e46"]
    top = max((o.matrix_world @ v.co).z for o in holder.children_recursive if o.type == 'MESH' for v in o.data.vertices)
    sx, sy, _r = SLOTS[1]
    cat_sleep(b, (sx, sy + 0.25, top - 0.02), m, rot=60, s=1.25)
    # Karabaş: kepenk girişinde, müşteriyi karşılar
    dog_sit(b, (1.4, 4.2, 0.0), m, rot=-60, s=1.0)
    # evcil hayvan köşesi: kulübe + kedi kulesi + kaplar + yatak (ön orta)
    dog_house(b, (9.6, 3.6, 0.0), m, rot=-20, s=1.0)
    cat_tower(b, (8.3, 3.9, 0.0), m, s=1.0)
    cat_sit(b, (8.3, 3.9, 1.29), m, rot=-30, s=1.2, coat="van", stripe="van_spot", belly="van", eye_l="eye_blue", eye_r="eye_amber")
    bowls(b, (9.0, 2.6, 0.0), m)
    b.ball((6.9, 2.9, 0.07), 0.07, m["ball"], segs=8, rings=6)
    smooth(b.finish(col))
    preview_lights(2)
    if close:
        scn = bpy.context.scene
        cam = bpy.data.cameras.new("Cam")
        cam.lens = 30
        co = bpy.data.objects.new("Cam", cam)
        scn.collection.objects.link(co)
        co.location = (11.6, -2.6, 3.6)
        aim(co, (6.6, 4.4, 0.9))
        scn.camera = co
        scn.render.resolution_x = w
        scn.render.resolution_y = h
    else:
        preview_camera(w, h)
    render(out, w, h, samples)


def main_pets():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mode = argv[0] if argv else "lineup"
    out = argv[1] if len(argv) > 1 else "/tmp/pets.png"
    w = int(argv[2]) if len(argv) > 2 else 1280
    h = int(argv[3]) if len(argv) > 3 else 720
    samples = int(argv[4]) if len(argv) > 4 else 48
    if mode == "lineup":
        lineup(out, w, h, samples)
    else:
        garage(out, w, h, samples, close=mode == "close")


main_pets()
