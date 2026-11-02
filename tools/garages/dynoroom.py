"""DİNO ATÖLYESİ — DİNAMOMETRE ekranının 3D mekânı (kullanıcı 2026-11-02: gaz verme ekranı "C DİNAMOMETRE olsun, çizimini
iyi yap, dinamometre gerçekçi olsun"; sahne: modifiye garajının siyah-altını DEĞİL, ayrı GERÇEK DİNO ATÖLYESİ).
Girişler: garajda araca dokun → YAKINDAN İNCELE; modifiye garajında 3. kart DİNAMOMETRE.

Gerçek bir şasi dinamometresi hücresi (Dynojet / Mustang tipi tuner atölyesi):
  DİNO     zeminden yükseltilmiş sarı çelik gövde, baklava desenli sac döşeme ve iki uçta rampa; her aksta bir tırtıllı
           çelik merdane (dört teker de merdanede: önden / arkadan / dört çeker hepsi), merdane yuvalarının sarı kenarı,
           yatak gövdeleri; aracı dört köşeden zemindeki halkalara bağlayan turuncu cırcırlı gergi kayışları.
  FAN      aracın önünde tekerlekli dev soğutma fanı (ızgara halkaları, kanatlar, gövde).
  EGZOZ    tavandaki makaradan egzoz ucuna inen körüklü emiş hortumu, ucunda huni.
  KONTROL  doğu duvarında masa + iki ekran (güç / tork eğrisi) + duvarda büyük ekran, hava istasyonu, sandalye.
  ODA      akustik duvar panelleri, güneyde (fanın arkasında) hava giriş panjuru, kuzeyde sarmal kepenk, tavanda LED
           paneller ve kablo kanalları; epoksi zemin, dinonun çevresinde sarı-siyah ikaz şeridi, gider ızgarası.
  EŞYA     alet dolabı, lastik yığını, yangın tüpü, bidonlar, kriko, kompresör, uyarı levhaları.

Eksenler: X doğu, Y kuzey (metre). Araç burnu GÜNEYE (-Y; place_cars yaw 0), fan güneyde, egzoz hortumu kuzeyde.

Çalıştırma (depo kökünden):
  blender -b --factory-startup --python tools/garages/dynoroom.py -- preview <dyno|side|rear|wheel|desk> <çıktı.png> [genişlik yükseklik örnek] [araç_id]
"""
import bpy, bmesh, math, random, os, sys, json

REPO = os.getcwd()
exec(open(os.path.join(REPO, "tools", "garages", "garage_kit.py")).read())

W, D, H = 13.0, 15.0, 5.2
DECK = 0.36                 # döşeme üstü
FRAME_W = 2.8
RAMP_L = 1.5
DRUM_R = 0.55
DRUM_LEN = 2.5
CX = 6.2                    # dinonun boyuna ekseni (X)
## Arka merdane SABİT; ön merdane taşıyıcıyla kanal boyunca kayar (dingil mesafesi: Fiat 500 1,84 m … Sprinter ~4,5 m).
REAR_Y = 9.6
WB_MIN, WB_MAX, WB_DEFAULT = 1.75, 4.7, 2.6
FRAME_Y0 = REAR_Y - WB_MAX - 1.4
FRAME_Y1 = REAR_Y + 1.7
FRAME_L = FRAME_Y1 - FRAME_Y0
DYNO = (CX, (FRAME_Y0 + FRAME_Y1) / 2)
CHANNEL = (REAR_Y - WB_MAX - 0.5, REAR_Y - WB_MIN + 0.5)
COVER = 0.95                # taşıyıcının iki yanındaki sürgülü kapak boyu
INTERIOR = (W / 2, D / 2, 2.0)   # pişirmede açık yüzeyler buraya döner
PREVIEW_CAR = "toyota_supra"


def mats():
    return {
        "dyno_yellow": k_mat("d_yellow", "#F0B21C", rough=0.45, metal=0.15),
        "dyno_yellow_dark": k_mat("d_yellow_dark", "#B98410", rough=0.5, metal=0.15),
        "drum": k_mat("d_drum", "#7C8188", rough=0.32, metal=0.9),
        "drum_rib": k_mat("d_drum_rib", "#A4AAB1", rough=0.25, metal=0.95),
        "pit": k_mat("d_pit", "#1A1B1E", rough=0.8),
        "strap": k_mat("d_strap", "#E8701A", rough=0.7),
        "ratchet": k_mat("d_ratchet", "#B9BEC4", rough=0.3, metal=0.9),
        "fan_body": k_mat("d_fan_body", "#25282D", rough=0.5, metal=0.4),
        "fan_blade": k_mat("d_fan_blade", "#3A3E44", rough=0.4, metal=0.5),
        "fan_grill": k_mat("d_fan_grill", "#B5BAC0", rough=0.3, metal=0.9),
        "hose": k_mat("d_hose", "#1D1E21", rough=0.7),
        "hose_band": k_mat("d_hose_band", "#D2391F", rough=0.6),
        "reel": k_mat("d_reel", "#C8372D", rough=0.5, metal=0.3),
        "acoustic": k_mat("d_acoustic", "#2B2F35", rough=0.98),
        "acoustic_light": k_mat("d_acoustic_light", "#353A41", rough=0.98),
        "wall_low": k_mat("d_wall_low", "#4A5058", rough=0.85),
        "wall_paint": k_mat("d_wall_paint", "#C9CDD2", rough=0.85),
        "ceiling": k_mat("d_ceiling", "#3A3E44", rough=0.9),
        "tray": k_mat("d_tray", "#9EA3A9", rough=0.5, metal=0.7),
        "louver": k_mat("d_louver", "#6F757C", rough=0.5, metal=0.6),
        "desk": k_mat("d_desk", "#2D3036", rough=0.6, metal=0.3),
        "desk_top": k_mat("d_desk_top", "#1E2024", rough=0.4),
        "screen_frame": k_mat("d_screen_frame", "#111214", rough=0.4),
        "led_cool": k_mat("d_led_cool", "#F4F8FF", rough=0.5, emit="#EAF2FF", strength=14.0),
        "sign_yellow": k_mat("d_sign_yellow", "#F5C518", rough=0.6),
        "sign_black": k_mat("d_sign_black", "#151515", rough=0.6),
        "jerry": k_mat("d_jerry", "#B8261F", rough=0.6, metal=0.2),
        "chair": k_mat("d_chair", "#1F2226", rough=0.7),
        "door": k_mat("d_door", "#8C9298", rough=0.5, metal=0.6),
    }


# --- Dokular -----------------------------------------------------------------------------------------------

def floor_texture(out_dir, ppm=90):
    """Epoksi zemin: hafif benekli gri, döküm derzleri, dinonun çevresinde sarı-siyah ikaz şeridi, rampa önlerinde lastik
    izleri, gider ızgarası."""
    import numpy as np
    w, h = int(W * ppm), int(D * ppm)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    mx, my = xx / ppm, (h - 1 - yy) / ppm
    n = _fbm((h, w), 60, 901)
    speck = (_noise((h, w), 2, 907) > 0.93).astype(np.float32)
    base = np.array(_hex("#6A6F76"))[None, None, :] * (0.92 + 0.12 * n[..., None])
    base = base * (1 - speck[..., None] * 0.18) + speck[..., None] * np.array(_hex("#9AA0A7")) * 0.18
    joint = (np.abs(mx % 3.25) < 0.012) | (np.abs(my % 3.75) < 0.012)
    base[joint] = base[joint] * 0.7
    # ikaz şeridi: dino gövdesinin 0,7 m çevresinde 0,16 m eğik sarı-siyah
    cx, cy = DYNO
    hx, hy = FRAME_W / 2 + 0.7, FRAME_L / 2 + RAMP_L + 0.5
    dx, dy = np.abs(mx - cx), np.abs(my - cy)
    outer = (dx < hx + 0.16) & (dy < hy + 0.16)
    inner = (dx < hx) & (dy < hy)
    band = outer & ~inner
    stripe = ((mx + my) * 4.0) % 1.0 < 0.5
    base[band & stripe] = np.array(_hex("#E8B019"))
    base[band & ~stripe] = np.array(_hex("#1C1C1C"))
    # lastik izleri: iki rampanın önünde koyu, kesik çizgiler
    for end in (-1, 1):
        y0 = cy + end * (FRAME_L / 2 + RAMP_L)
        for tx in (-0.78, 0.78):
            mark = (np.abs(mx - cx - tx) < 0.11) & (np.abs(my - y0 - end * 1.2) < 1.2)
            fade = np.clip(1.0 - np.abs(my - y0) / 2.4, 0, 1) * (0.35 + 0.4 * _fbm((h, w), 8, 931, 2))
            base = np.where(mark[..., None], base * (1 - fade[..., None] * 0.6), base)
    # gider ızgarası: fanın önünde enine
    grate = (np.abs(my - (cy - FRAME_L / 2 - RAMP_L - 1.6)) < 0.14) & (np.abs(mx - cx) < 1.6)
    slots = ((mx * 30.0) % 1.0) < 0.45
    base[grate] = np.array(_hex("#3A3D42"))
    base[grate & slots] = np.array(_hex("#15161A"))
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "dyno_floor.png")
    _save_image("dyno_floor", base[::-1], path)
    return path


def diamond_texture(out_dir, size=512):
    """Baklava desenli çelik sac (karo, tekrarlanır): eğik uzun kabartmalar, ışık yanı açık / gölge yanı koyu."""
    import numpy as np
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    cells = 4
    u, v = xx * cells, yy * cells
    out = np.ones((size, size, 3), np.float32) * np.array(_hex("#8E949B"))
    n = _fbm((size, size), 40, 951)
    out *= (0.9 + 0.15 * n[..., None])
    for k, (ox, oy, ang) in enumerate(((0.0, 0.0, 0.7), (0.5, 0.5, -0.7))):
        cu = (u - ox) % 1.0 - 0.5
        cv = (v - oy) % 1.0 - 0.5
        ca, sa = math.cos(ang), math.sin(ang)
        a = cu * ca + cv * sa
        b = -cu * sa + cv * ca
        lug = (a / 0.32) ** 2 + (b / 0.07) ** 2 < 1.0
        light = lug & (b > 0)
        dark = lug & (b <= 0)
        out[light] = out[light] * 1.35
        out[dark] = out[dark] * 0.62
    scuff = _fbm((size, size), 10, 961, 3)
    out *= (0.85 + 0.25 * scuff[..., None])
    path = os.path.join(out_dir, "dyno_diamond.png")
    _save_image("dyno_diamond", np.clip(out, 0, 1)[::-1], path)
    return path


def screen_texture(out_dir, name, kind="graph", w=512, h=300):
    """Ekran görüntüsü: koyu zemin, ızgara, güç (yeşil) ve tork (turuncu) eğrileri; kind="gauges": iki kadran."""
    import numpy as np
    img = np.ones((h, w, 3), np.float32) * np.array(_hex("#0C1420"))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    grid = ((xx % 40) < 1.2) | ((yy % 30) < 1.2)
    img[grid] = np.array(_hex("#1E2C3E"))
    if kind == "graph":
        t = np.linspace(0, 1, w)
        power = 0.12 + 0.78 * np.sin(np.clip(t * 1.85, 0, math.pi / 2)) * (1 - np.clip(t - 0.86, 0, 1) * 1.8)
        torque = 0.45 + 0.35 * np.sin(np.clip(t * 2.6, 0, math.pi)) * 0.9 + 0.1 * t
        for curve, col, thick in ((power, "#46E06A", 3.2), (torque, "#FF8A2A", 2.6)):
            py = (1 - curve) * (h - 40) + 20
            for x in range(w):
                y0 = int(py[x])
                img[max(0, y0 - int(thick)):min(h, y0 + int(thick)), x] = np.array(_hex(col))
        img[h - 34:h - 10, 20:200] = np.array(_hex("#46E06A")) * 0.9   # alt bilgi çubuğu
        img[h - 34:h - 10, 220:330] = np.array(_hex("#FF8A2A")) * 0.9
    else:
        for cx in (w * 0.28, w * 0.72):
            r = np.sqrt((xx - cx) ** 2 + (yy - h * 0.52) ** 2)
            img[(r > 95) & (r < 102)] = np.array(_hex("#C9D3E0"))
            ang = np.arctan2(yy - h * 0.52, xx - cx)
            redz = (r > 80) & (r < 95) & (ang > -0.6) & (ang < 0.6)
            img[redz] = np.array(_hex("#E04A3A"))
        img[int(h * 0.52) - 3:int(h * 0.52) + 3, int(w * 0.28):int(w * 0.28) + 80] = np.array(_hex("#FFD24A"))
    path = os.path.join(out_dir, name + ".png")
    _save_image(name, img[::-1], path)
    return path


def textured_quad(col, name, tex_path, center, size, rot=(0, 0, 0), repeat=(1.0, 1.0), rough=0.6, metal=0.0, emit=0.0,
                  bake_white=False):
    """Dokulu dikdörtgen (yukarı bakar; rot ile döner). repeat: doku tekrarı (sac, ızgara)."""
    from mathutils import Euler, Vector
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    hx, hy = size[0] / 2, size[1] / 2
    e = Euler(tuple(math.radians(a) for a in rot), 'XYZ')
    vs = []
    for p in ((-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)):
        v = Vector(p)
        v.rotate(e)
        vs.append(bm.verts.new(Vector(center) + v))
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new("UVMap")
    for loop, c in zip(f.loops, [(0, 0), (repeat[0], 0), (repeat[0], repeat[1]), (0, repeat[1])]):
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
    tex.image = bpy.data.images.get(os.path.basename(tex_path)) or bpy.data.images.load(tex_path)
    tex.extension = 'REPEAT'
    if bake_white:   # dışa aktarma: köşe rengine yalnız ışık pişsin (oyun dokuyla çarpar)
        bsdf.inputs["Base Color"].default_value = (0.8, 0.8, 0.8, 1.0)
    else:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    me.materials.append(m)
    o["jy_textured"] = True
    return o


# --- Dinamometre ---------------------------------------------------------------------------------------------
# Hareketli parçalar YEREL koordinatta kurulur, nesnenin kökü dönme / kayma noktasındadır:
#   DrumRear     arka merdane, kök = mil ekseni                 (oyun döndürür)
#   FrontCarriage boş düğüm, kök = ön mil ekseninin döşemedeki izdüşümü (oyun Y boyunca kaydırır); çocukları:
#     DrumFront  ön merdane, kök = mil ekseni (oyun döndürür)
#     CarriageBody yuva kenarları, çukur, sürgülü kapaklar
#   Deck_* / Ramp_* baklava sac (UV tekrarlı; oyunda pişmiş ışık × diamond.png)

def drum_local(b, m):
    """Tırtıllı çelik merdane + mil başları (kök = mil ekseni)."""
    # telefon bütçesi: merdane başına ~3 bin üçgen (önce 56 kenar × 46 tırtıl ≈ 10 bin)
    b.cyl((0, 0, 0), DRUM_R, DRUM_LEN, m["drum"], axis='X', segs=40)
    ribs = 30
    for i in range(ribs):
        x = -DRUM_LEN / 2 + 0.05 + i * (DRUM_LEN - 0.1) / (ribs - 1)
        b.cyl((x, 0, 0), DRUM_R + 0.006, 0.022, m["drum_rib"], axis='X', segs=40)
    # dönüşü görünür kılan boyalı işaret (yanlarda sarı çizgi)
    for s_ in (-1, 1):
        b.box((s_ * (DRUM_LEN / 2 - 0.03), 0, DRUM_R - 0.01), (0.05, 0.12, 0.03), m["dyno_yellow"])
        b.cyl((s_ * (DRUM_LEN / 2 + 0.08), 0, 0), 0.16, 0.12, m["steel_dark"], axis='X', segs=20)


def slot_local(b, m):
    """Merdane yuvası (kök = mil ekseninin döşemedeki izdüşümü, z = 0 zemin): çukur, sarı kenarlar, yatak gövdeleri."""
    b.box((0, 0, DECK - 0.25), (DRUM_LEN + 0.2, 0.9, 0.02), m["pit"])
    for s_ in (-1, 1):
        soft_box(b, (0, s_ * 0.47, DECK + 0.005), (DRUM_LEN + 0.24, 0.06, 0.03), m["dyno_yellow"], radius=0.01)
        b.box((0, s_ * 0.44, DECK - 0.12), (DRUM_LEN + 0.2, 0.02, 0.26), m["pit"])
        soft_box(b, (s_ * (DRUM_LEN / 2 + 0.16), 0, DECK - 0.2), (0.16, 0.5, 0.34), m["fan_body"], radius=0.02)


def new_empty(col, name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = 'ARROWS'
    e.location = loc
    col.objects.link(e)
    return e


def parent_keep(child, parent):
    """Dünya konumunu koruyarak bağla (matrix_world henüz güncellenmemiş olabilir: matrix_basis'ten)."""
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_basis.inverted()


def dyno(col, m, tex, front_y, preview):
    """Sabit gövde + arka merdane + ön taşıyıcı. front_y: ön mil ekseninin Y'si (önizlemede araca göre)."""
    b = Builder("Dyno", seed=701)
    cx = CX
    y0, y1 = FRAME_Y0, FRAME_Y1
    cy = (y0 + y1) / 2
    for s_ in (-1, 1):
        soft_box(b, (cx + s_ * (FRAME_W / 2 - 0.08), cy, DECK / 2), (0.16, FRAME_L, DECK), m["dyno_yellow"], radius=0.02)
        b.box((cx + s_ * (FRAME_W / 2 + 0.002), cy, DECK * 0.45), (0.01, FRAME_L - 0.3, 0.05), m["dyno_yellow_dark"])
    for y in (y0 + 0.08, y1 - 0.08):
        soft_box(b, (cx, y, DECK / 2), (FRAME_W, 0.16, DECK), m["dyno_yellow"], radius=0.02)
    # arka yuva (sabit)
    sb = Builder("RearSlot", seed=711)
    slot_local(sb, m)
    # ön kanal: taşıyıcının kaydığı çukur + kanal boyunca ray
    c0, c1 = CHANNEL
    # kanal: döşemeden 4 cm aşağıda çelik yatak (taşıyıcı ve kapakları üstünde kayar), kenarlarda ray
    b.box((cx, (c0 + c1) / 2, DECK - 0.05), (DRUM_LEN + 0.2, c1 - c0, 0.02), m["steel_dark"])
    for k in range(int((c1 - c0) / 0.5)):
        b.box((cx, c0 + 0.25 + k * 0.5, DECK - 0.038), (DRUM_LEN + 0.16, 0.02, 0.004), m["pit"])
    for s_ in (-1, 1):
        b.box((cx + s_ * (DRUM_LEN / 2 + 0.11), (c0 + c1) / 2, DECK - 0.02), (0.04, c1 - c0, 0.06), m["steel"])
        soft_box(b, (cx, c0 if s_ < 0 else c1, DECK + 0.005), (DRUM_LEN + 0.24, 0.06, 0.03), m["dyno_yellow"], radius=0.01)
    b.finish(col)
    sb.finish(col, loc=(cx, REAR_Y, 0.0)).name = "RearSlot"
    rd = Builder("DrumRear", seed=712)
    drum_local(rd, m)
    rd.finish(col, loc=(cx, REAR_Y, DECK + 0.03 - DRUM_R))
    # ön taşıyıcı
    carriage = new_empty(col, "FrontCarriage", (cx, front_y, 0.0))
    cb = Builder("CarriageBody", seed=713)
    slot_local(cb, m)
    for s_ in (-1, 1):
        yy = s_ * (0.5 + COVER / 2)
        soft_box(cb, (0, yy, DECK + 0.012), (DRUM_LEN + 0.16, COVER, 0.02), m["steel"], radius=0.006)
        for k in range(1, 4):
            cb.box((0, s_ * (0.5 + COVER * k / 4), DECK + 0.024), (DRUM_LEN + 0.1, 0.012, 0.006), m["steel_dark"])
    body = cb.finish(col, loc=(cx, front_y, 0.0))
    parent_keep(body, carriage)
    fd = Builder("DrumFront", seed=714)
    drum_local(fd, m)
    drum = fd.finish(col, loc=(cx, front_y, DECK + 0.03 - DRUM_R))
    parent_keep(drum, carriage)
    # baklava sac döşeme: sabit parçalar (yuva ve kanal dışında)
    spans = [(y0 + 0.16, c0), (c1, REAR_Y - 0.5), (REAR_Y + 0.5, y1 - 0.16)]
    for i, (a, c) in enumerate(spans):
        if c - a > 0.05:
            textured_quad(col, "Deck_%d" % i, tex, (cx, (a + c) / 2, DECK + 0.002), (FRAME_W - 0.32, c - a),
                          repeat=((FRAME_W - 0.32) / 0.4, (c - a) / 0.4), rough=0.38, metal=0.8, bake_white=not preview)
    rb = Builder("Ramps", seed=702)
    slope = math.degrees(math.atan2(DECK, RAMP_L))
    for end in (-1, 1):
        yc = (y1 + RAMP_L / 2) if end > 0 else (y0 - RAMP_L / 2)
        ang = -end * slope
        textured_quad(col, "Ramp_%d" % (0 if end < 0 else 1), tex, (cx, yc, DECK / 2 + 0.003),
                      (FRAME_W - 0.3, math.hypot(RAMP_L, DECK)), rot=(ang, 0, 0),
                      repeat=((FRAME_W - 0.3) / 0.4, RAMP_L / 0.4), rough=0.38, metal=0.8, bake_white=not preview)
        for s_ in (-1, 1):
            rb.box((cx + s_ * (FRAME_W / 2 - 0.12), yc, DECK / 2 + 0.01), (0.05, math.hypot(RAMP_L, DECK), 0.05),
                   m["dyno_yellow"], rot=(ang, 0, 0))
    rb.finish(col)


## Kayış halkaları (zeminde, dinonun iki yanında): önde üç çift (araç boyuna göre en yakını kullanılır), arkada bir çift.
ANCHORS = {
    "Anchor_F0": (-1, REAR_Y - 5.4), "Anchor_F1": (-1, REAR_Y - 4.0), "Anchor_F2": (-1, REAR_Y - 2.6),
    "Anchor_R0": (-1, REAR_Y + 2.3),
}


def anchor_points():
    out = {}
    for name, (_, y) in ANCHORS.items():
        for side, sx in (("L", -1), ("R", 1)):
            out["%s_%s" % (name, side)] = (CX + sx * 1.85, y, 0.06)
    return out


def anchors(col, m, markers):
    """Zemin plakası + D halkası (sabit); her halkanın merkezine işaretçi (oyun kayışı buraya bağlar)."""
    b = Builder("Anchors", seed=703)
    for name, (x, y, z) in anchor_points().items():
        b.cyl((x, y, 0.015), 0.09, 0.03, m["steel_dark"], segs=16)
        ring_pts = [(x + math.cos(a) * 0.06, y, 0.06 + math.sin(a) * 0.06) for a in [i * math.tau / 12 for i in range(13)]]
        b.tube(ring_pts, 0.012, m["ratchet"], segs=5)
        new_empty(markers, name, (x, y, z))
    b.finish(col)


def straps(col, m, c):
    """ÖNİZLEME: aracı dört köşeden en yakın halkalara bağlayan turuncu cırcırlı kayışlar (oyunda kodla kurulur)."""
    b = Builder("Straps", seed=716)
    points = anchor_points()
    for end, yy in ((-1, c["ymin"] + 0.35), (1, c["ymax"] - 0.35)):
        for side, sx in (("L", -1), ("R", 1)):
            top = (CX + sx * 0.55, yy, c["zmin"] + 0.22)
            names = [n for n in points if n.endswith("_" + side) and ((n.startswith("Anchor_F") and end < 0) or
                                                                      (n.startswith("Anchor_R") and end > 0))]
            best = min(names, key=lambda n: abs(points[n][1] - (yy + end * 1.4)))
            anchor = points[best]
            mid = tuple(top[k] + (anchor[k] - top[k]) * 0.45 for k in range(3))
            b.tube([top, mid, anchor], 0.032, m["strap"], segs=6)
            soft_box(b, mid, (0.1, 0.16, 0.07), m["ratchet"], radius=0.015,
                     rot=(0, 0, math.degrees(math.atan2(anchor[1] - top[1], anchor[0] - top[0])) + 90))
    b.finish(col)


FAN_ZC = 0.95
FAN_R = 0.82


def cooling_fan(col, m, base):
    """Tekerlekli dev soğutma fanı. Fan (boş düğüm) kökü taban ortasında (oyun aracın burnuna göre taşır); FanBody gövde,
    ızgara, ayak; FanBlades kanatlar + göbek, kökü göbekte (oyun Y ekseninde döndürür)."""
    root = new_empty(col, "Fan", base)
    b = Builder("FanBody", seed=704)
    R, zc = FAN_R, FAN_ZC
    b.cyl((0, 0, zc), R + 0.06, 0.42, m["fan_body"], axis='Y', segs=48)
    b.cyl((0, 0, zc), R, 0.44, m["pit"], axis='Y', segs=48)
    for face in (-0.23, 0.23):
        for k in range(1, 7):
            pts = [(math.cos(a) * R * k / 6.5, face, zc + math.sin(a) * R * k / 6.5)
                   for a in [i * math.tau / 40 for i in range(41)]]
            b.tube(pts, 0.008, m["fan_grill"], segs=4)
        for k in range(8):
            a = k * math.tau / 8
            b.tube([(0, face, zc), (math.cos(a) * R, face, zc + math.sin(a) * R)], 0.008, m["fan_grill"], segs=4)
    for s_ in (-1, 1):
        b.box((s_ * (R + 0.1), 0, zc / 2 + 0.05), (0.07, 0.07, zc), m["steel_dark"])
    b.box((0, 0, 0.12), (2 * R + 0.4, 0.1, 0.07), m["steel_dark"])
    for s_ in (-1, 1):
        b.box((s_ * (R + 0.1), 0, 0.1), (0.1, 0.9, 0.07), m["steel_dark"])
        for t in (-1, 1):
            b.cyl((s_ * (R + 0.1), t * 0.4, 0.05), 0.05, 0.04, m["rubber"], axis='X', segs=12)
    parent_keep(b.finish(col, loc=base), root)
    bb = Builder("FanBlades", seed=715)
    for k in range(5):
        a = k * 72.0 + 12.0
        bb.box((math.cos(math.radians(a)) * 0.36, 0.02, math.sin(math.radians(a)) * 0.36), (0.6, 0.03, 0.2),
               m["fan_blade"], rot=(0, -a, 18))
    bb.cyl((0, 0.08, 0), 0.14, 0.26, m["fan_body"], axis='Y', segs=24)
    parent_keep(bb.finish(col, loc=(base[0], base[1], base[2] + zc)), root)
    return root


HOSE_REEL = (CX + 1.05, REAR_Y + 3.0, H - 0.45)


def hose_reel(col, m, markers):
    """Tavandaki egzoz emiş hortumu makarası (sabit) + HoseReel işaretçisi (hortum oyunda kodla iner)."""
    b = Builder("HoseReel", seed=717)
    reel = HOSE_REEL
    b.cyl(reel, 0.45, 0.5, m["reel"], axis='X', segs=32)
    b.cyl(reel, 0.2, 0.56, m["steel_dark"], axis='X', segs=20)
    b.box((reel[0], reel[1], H - 0.08), (0.6, 0.3, 0.16), m["steel_dark"])
    b.finish(col)
    new_empty(markers, "HoseStart", (reel[0], reel[1] - 0.3, reel[2] - 0.35))


def exhaust_hose(col, m, tail):
    """ÖNİZLEME: makaradan egzoz ucuna körüklü emiş hortumu + huni (oyunda kodla kurulur)."""
    b = Builder("Exhaust", seed=705)
    tx, ty, tz = tail
    reel = HOSE_REEL
    p0 = (reel[0], reel[1] - 0.3, reel[2] - 0.35)
    p3 = (tx, ty + 0.55, tz + 0.05)
    pts = []
    n = 120
    for i in range(n + 1):
        t = i / n
        x = p0[0] + (p3[0] - p0[0]) * t
        y = p0[1] + (p3[1] - p0[1]) * (t ** 1.6)
        z = p0[2] + (p3[2] - p0[2]) * (1 - (1 - t) ** 2.2) - math.sin(t * math.pi) * 0.35
        pts.append((x, y, z))
    for i in range(n):
        mat = m["hose_band"] if i % 30 == 15 else m["hose"]
        b.tube([pts[i], pts[i + 1]], 0.082 if i % 2 == 0 else 0.074, mat, segs=14)
    b.cyl((tx, ty + 0.38, tz), 0.075, 0.3, m["hose"], axis='Y', segs=20, r2=0.14)
    b.tube([p3, (tx, ty + 0.5, tz)], 0.07, m["hose"], segs=12)
    b.finish(col)


def control_desk(col, m, tex_graph, tex_gauges):
    """Doğu duvarı: masa, iki ekran, duvarda büyük ekran, hava istasyonu, sandalye, klavye."""
    b = Builder("Desk", seed=706)
    x = W - 0.75
    y = DYNO[1] - 0.6
    soft_box(b, (x, y, 0.74), (0.8, 2.4, 0.05), m["desk_top"], radius=0.01)
    for s in (-1, 1):
        b.box((x, y + s * 1.12, 0.37), (0.7, 0.06, 0.74), m["desk"])
    b.box((x + 0.3, y, 0.45), (0.04, 2.2, 0.5), m["desk"])
    for dy in (-0.55, 0.55):
        b.box((x + 0.1, y + dy, 0.85), (0.06, 0.06, 0.2), m["screen_frame"])
        soft_box(b, (x + 0.08, y + dy, 1.12), (0.05, 0.98, 0.6), m["screen_frame"], radius=0.01)
    soft_box(b, (x - 0.15, y, 0.775), (0.18, 0.5, 0.02), m["screen_frame"], radius=0.005)
    # sandalye
    cxh, cyh = x - 0.75, y - 0.1
    b.cyl((cxh, cyh, 0.25), 0.03, 0.4, m["steel"], segs=10)
    soft_box(b, (cxh, cyh, 0.48), (0.5, 0.5, 0.08), m["chair"], radius=0.03)
    soft_box(b, (cxh - 0.22, cyh, 0.8), (0.07, 0.48, 0.6), m["chair"], radius=0.03, rot=(0, -8, 0))
    for k in range(5):
        a = k * math.tau / 5
        b.tube([(cxh, cyh, 0.06), (cxh + math.cos(a) * 0.3, cyh + math.sin(a) * 0.3, 0.04)], 0.02, m["steel_dark"], segs=4)
    # hava istasyonu (duvarda küçük kutu)
    soft_box(b, (W - 0.06, y + 1.6, 1.6), (0.1, 0.3, 0.4), m["white"], radius=0.02)
    b.finish(col)
    screens = []
    for i, dy in enumerate((-0.55, 0.55)):
        screens.append(textured_quad(col, "Screen_%d" % i, tex_graph if i == 0 else tex_gauges, (x + 0.05, y + dy, 1.12),
                                     (0.9, 0.52), rot=(90, 0, -90), emit=2.2, rough=0.3))
    sx = DYNO[0] - 3.7
    b2 = Builder("WallScreenFrame", seed=709)
    soft_box(b2, (sx, D - 0.05, 2.6), (2.5, 0.06, 1.45), m["screen_frame"], radius=0.02)
    b2.box((sx, D - 0.1, 1.75), (0.08, 0.06, 0.3), m["steel_dark"])
    b2.finish(col)
    screens.append(textured_quad(col, "WallScreen", tex_graph, (sx, D - 0.085, 2.6), (2.3, 1.3), rot=(90, 0, 0), emit=2.6,
                                 rough=0.3))
    return screens


def room(col, m):
    b = Builder("Room", seed=707)
    # duvarlar: alt boyalı bant + üstte akustik paneller
    plane(b, (W / 2, D, H / 2), (W, H), m["wall_low"], rot=(90, 0, 0))
    plane(b, (W / 2, 0.0, H / 2), (W, H), m["wall_low"], rot=(90, 0, 180))
    plane(b, (0.0, D / 2, H / 2), (D, H), m["wall_low"], rot=(90, 0, 90))
    plane(b, (W, D / 2, H / 2), (D, H), m["wall_low"], rot=(90, 0, -90))
    plane(b, (W / 2, D / 2, H), (W, D), m["ceiling"], rot=(180, 0, 0))
    rnd = random.Random(7)
    def panels(wall, length, skip=()):
        step = 1.2
        for i in range(int(length / step)):
            for j in range(3):
                t = step / 2 + i * step
                if any(a <= t <= c for a, c in skip):
                    continue
                z = 1.6 + j * 1.15
                mat = m["acoustic"] if (i + j) % 2 else m["acoustic_light"]
                th = 0.08 + 0.02 * rnd.random()
                if wall == "W":
                    soft_box(b, (th / 2 + 0.01, t, z), (th, step - 0.06, 1.09), mat, radius=0.03)
                elif wall == "E":
                    soft_box(b, (W - th / 2 - 0.01, t, z), (th, step - 0.06, 1.09), mat, radius=0.03)
                elif wall == "N":
                    soft_box(b, (t, D - th / 2 - 0.01, z), (step - 0.06, th, 1.09), mat, radius=0.03)
                else:
                    soft_box(b, (t, th / 2 + 0.01, z), (step - 0.06, th, 1.09), mat, radius=0.03)
    panels("W", D)
    panels("E", D, skip=[(DYNO[1] - 2.2, DYNO[1] + 1.3)])
    panels("N", W, skip=[(DYNO[0] - 2.1, DYNO[0] + 2.1), (DYNO[0] - 5.0, DYNO[0] - 2.4)])
    panels("S", W, skip=[(DYNO[0] - 1.9, DYNO[0] + 1.9)])
    # süpürgelik: sarı çarpma bandı
    for (cx, cy, sx, sy) in ((W / 2, D - 0.05, W, 0.1), (W / 2, 0.05, W, 0.1), (0.05, D / 2, 0.1, D), (W - 0.05, D / 2, 0.1, D)):
        b.box((cx, cy, 0.5), (sx, sy, 0.12), m["sign_yellow"])
    # güney: hava giriş panjuru (fanın arkası)
    gx = DYNO[0]
    soft_box(b, (gx, 0.08, 2.0), (3.6, 0.16, 2.6), m["steel_dark"], radius=0.02)
    for k in range(16):
        b.box((gx, 0.2, 0.86 + k * 0.15), (3.3, 0.03, 0.09), m["louver"], rot=(-35, 0, 0))
    # kuzey: sarmal kepenk
    soft_box(b, (DYNO[0], D - 0.06, 1.85), (3.9, 0.12, 3.7), m["door"], radius=0.02)
    for k in range(22):
        b.box((DYNO[0], D - 0.13, 0.12 + k * 0.165), (3.7, 0.03, 0.02), m["steel_dark"])
    soft_box(b, (DYNO[0], D - 0.2, 3.85), (4.2, 0.4, 0.4), m["steel_dark"], radius=0.03)
    # tavan: LED paneller + kablo kanalı
    for (lx, ly) in ((DYNO[0] - 1.6, DYNO[1] - 2.4), (DYNO[0] + 1.6, DYNO[1] - 2.4), (DYNO[0] - 1.6, DYNO[1] + 1.2),
                     (DYNO[0] + 1.6, DYNO[1] + 1.2), (DYNO[0] - 1.6, DYNO[1] + 4.6), (DYNO[0] + 1.6, DYNO[1] + 4.6),
                     (W - 1.6, DYNO[1] - 0.6), (2.0, DYNO[1] - 0.6)):
        soft_box(b, (lx, ly, H - 0.04), (1.25, 0.62, 0.05), m["steel"], radius=0.01)
        b.box((lx, ly, H - 0.07), (1.15, 0.52, 0.01), m["led_cool"])
    for s in (-1, 1):
        b.box((DYNO[0] + s * 3.2, D / 2, H - 0.35), (0.3, D, 0.06), m["tray"])
        for k in range(8):
            b.box((DYNO[0] + s * 3.2, 1.0 + k * 1.8, H - 0.18), (0.03, 0.03, 0.34), m["tray"])
    b.finish(col)


def props(col, m):
    b = Builder("Props", seed=708)
    # batı: alet dolabı, lastik yığını, bidonlar, kompresör, yangın tüpü
    tool_cabinet(b, (0.55, 3.6, 0.0), m, rot=90.0, color="red")
    tool_cabinet(b, (0.55, 4.6, 0.0), m, rot=90.0, color="red", drawers=8)
    tire_stack_g(b, (0.8, 11.2, 0.0), 5, m, seed=4)
    tire_stack_g(b, (1.55, 11.6, 0.0), 3, m, seed=8)
    for k in range(3):
        soft_box(b, (0.45, 7.2 + k * 0.42, 0.3), (0.2, 0.36, 0.6), m["jerry"], radius=0.04)
        b.box((0.45, 7.2 + k * 0.42, 0.64), (0.06, 0.16, 0.06), m["black"])
    compressor(b, (1.0, 9.0, 0.0), m, rot=90.0)
    extinguisher(b, (W - 0.3, 12.4, 0.0), m)
    extinguisher(b, (0.3, 2.1, 0.0), m)
    floor_jack(b, (2.1, 12.6, 0.0), m, rot=30.0)
    # uyarı levhaları (sarı üçgen, siyah çerçeve + ünlem)
    for (sx, sy, rot) in ((DYNO[0] - 2.6, D - 0.03, 0), (DYNO[0] + 2.6, D - 0.03, 0), (0.03, DYNO[1], 90)):
        if rot == 0:
            c = (sx, sy, 2.4)
            soft_box(b, c, (0.7, 0.02, 0.62), m["sign_yellow"], radius=0.02)
            b.box((sx, sy - 0.02, 2.48), (0.07, 0.01, 0.28), m["sign_black"])
            b.box((sx, sy - 0.02, 2.24), (0.07, 0.01, 0.07), m["sign_black"])
        else:
            c = (sx, sy, 2.4)
            soft_box(b, c, (0.02, 0.7, 0.62), m["sign_yellow"], radius=0.02)
            b.box((sx + 0.02, sy, 2.48), (0.01, 0.07, 0.28), m["sign_black"])
            b.box((sx + 0.02, sy, 2.24), (0.01, 0.07, 0.07), m["sign_black"])
    b.finish(col)


# --- Araç --------------------------------------------------------------------------------------------------

def car_contacts(holder):
    """İçe aktarılan aracın tekerlerinin yere değdiği ön / arka Y'leri ve gövde sınırları (en alttaki köşelerden)."""
    from mathutils import Vector
    pts = []
    for o in holder.children_recursive:
        if o.type != 'MESH':
            continue
        mw = o.matrix_world
        for v in o.data.vertices:
            pts.append(mw @ v.co)
    zmin = min(p.z for p in pts)
    low = [p for p in pts if p.z < zmin + 0.04]
    cy = sum(p.y for p in pts) / len(pts)
    front = [p.y for p in low if p.y < cy]
    rear = [p.y for p in low if p.y >= cy]
    return {"zmin": zmin, "front": sum(front) / max(len(front), 1), "rear": sum(rear) / max(len(rear), 1),
            "ymin": min(p.y for p in pts), "ymax": max(p.y for p in pts),
            "tail_z": zmin + 0.32, "x": sum(p.x for p in pts) / len(pts)}


def build(tex_dir, car_id=None):
    """car_id verilirse ÖNİZLEME: araç arka teker arka merdaneye oturur, ön taşıyıcı ön tekerin altına kayar, kayışlar
    ve hortum araca göre çizilir. Verilmezse DIŞA AKTARMA: araçsız, taşıyıcı WB_DEFAULT'ta, kayış / hortum yok."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    root = new_col("DynoRoom")
    m = gmats()
    m.update(mats())
    os.makedirs(tex_dir, exist_ok=True)
    c = None
    front_y = REAR_Y - WB_DEFAULT
    if car_id:
        place_cars([(CX, REAR_Y - 1.3, 0.0, 0.0)], [car_id])
        holder = bpy.data.objects["Car_%s" % car_id]
        bpy.context.view_layer.update()
        c = car_contacts(holder)
        holder.location.z += (DECK + 0.03) - c["zmin"]
        holder.location.x += CX - c["x"]
        holder.location.y += REAR_Y - c["rear"]
        bpy.context.view_layer.update()
        c = car_contacts(holder)
        front_y = c["front"]
    static = new_col("Static", root)
    markers = new_col("Markers", root)
    floor = textured_quad(static, "Floor", floor_texture(tex_dir), (W / 2, D / 2, 0.0), (W, D), rough=0.35)
    diamond = diamond_texture(tex_dir)
    dyno(static, m, diamond, front_y, preview=car_id is not None)
    anchors(static, m, markers)
    nose = c["ymin"] if c else front_y - 0.95
    fan_y = nose - 1.25
    fan_base = (CX - 0.35, fan_y, DECK) if fan_y > FRAME_Y0 + 0.5 else (CX - 0.35, FRAME_Y0 - RAMP_L - 0.7, 0.0)
    cooling_fan(static, m, fan_base)
    hose_reel(static, m, markers)
    if c:
        straps(static, m, c)
        exhaust_hose(static, m, (CX + 0.45, c["ymax"] + 0.05, c["tail_z"]))
    screens = control_desk(static, m, screen_texture(tex_dir, "dyno_graph"), screen_texture(tex_dir, "dyno_gauges", "gauges"))
    room(static, m)
    props(static, m)
    new_empty(markers, "RearAxle", (CX, REAR_Y, DECK + 0.03))
    return {"root": root, "static": static, "floor": floor, "car": c, "markers": markers, "screens": screens,
            "tex_dir": tex_dir}


# --- Önizleme ----------------------------------------------------------------------------------------

def preview_lights():
    scn = bpy.context.scene
    world = scn.world or bpy.data.worlds.new("World")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.03, 0.035, 0.04, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    x, y = CAR_C
    def area(name, loc, target, size, energy, color, size_y=None):
        l = bpy.data.lights.new(name, 'AREA')
        l.shape = 'RECTANGLE'
        l.size = size
        l.size_y = size_y or size
        l.energy = energy
        l.color = color
        o = bpy.data.objects.new(name, l)
        scn.collection.objects.link(o)
        o.location = loc
        aim(o, target)
    # tavan LED'leri (soğuk beyaz), dinonun üstünde güçlü
    for (lx, ly) in ((x - 1.6, y - 2.4), (x + 1.6, y - 2.4), (x - 1.6, y + 1.2), (x + 1.6, y + 1.2), (x - 1.6, y + 4.6),
                     (x + 1.6, y + 4.6)):
        area("LED", (lx, ly, H - 0.12), (lx, ly, 0), 1.2, 520, (0.92, 0.96, 1.0), size_y=0.6)
    area("Fill", (W / 2, D / 2, H - 0.3), (W / 2, D / 2, 0), 9.0, 650, (0.9, 0.95, 1.0), size_y=11.0)
    area("Desk", (W - 1.6, y - 0.6, H - 0.2), (W - 1.0, y - 0.6, 0), 1.2, 260, (0.95, 0.97, 1.0))
    # fanın arkasından panjurdan sızan gün ışığı (sıcak)
    area("Vent", (x, 0.6, 2.0), (x, y, 0.8), 3.0, 260, (1.0, 0.85, 0.65), size_y=2.2)


CAR_C = (CX, REAR_Y - WB_DEFAULT / 2)
SHOTS = {
    # ad: (konum, hedef, lens) — oyunun ekran açısına yakın: güneydoğudan, aracın sağ ön 3/4'ü
    "dyno": ((CAR_C[0] + 5.6, CAR_C[1] - 6.2, 2.6), (CAR_C[0] - 0.4, CAR_C[1] + 0.3, 0.75), 24),
    "side": ((CAR_C[0] + 4.9, CAR_C[1] + 2.2, 1.15), (CAR_C[0], CAR_C[1] + 0.4, 0.55), 22),
    "rear": ((CAR_C[0] + 3.0, CAR_C[1] + 6.4, 1.6), (CAR_C[0] + 0.2, CAR_C[1] + 1.6, 0.7), 24),
    "wheel": ((CAR_C[0] + 2.9, CAR_C[1] - 3.0, 0.85), (CAR_C[0] + 0.85, CAR_C[1] - 1.2, 0.35), 30),
    "desk": ((CAR_C[0] - 2.5, CAR_C[1] - 4.5, 2.0), (W - 0.6, CAR_C[1] - 0.4, 1.4), 24),
    "wide": ((W - 1.2, 1.2, 3.4), (CX - 1.0, REAR_Y - 1.0, 0.6), 20),
}


def preview_camera(shot, width, height):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.sensor_width = 36
    co = bpy.data.objects.new("Cam", cam)
    scn.collection.objects.link(co)
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
        shot = argv[1] if len(argv) > 1 else "dyno"
        out = argv[2] if len(argv) > 2 else "/tmp/dynoroom.png"
        width = int(argv[3]) if len(argv) > 3 else 1152
        height = int(argv[4]) if len(argv) > 4 else 648
        samples = int(argv[5]) if len(argv) > 5 else 48
        car_id = argv[6] if len(argv) > 6 else PREVIEW_CAR
        parts = build(os.path.join(os.path.dirname(out), "tex"), car_id)
        print("DYNO car contacts:", parts["car"])
        preview_lights()
        preview_camera(shot, width, height)
        render(out, width, height, samples)


if not globals().get("EXPORTING"):
    main()
