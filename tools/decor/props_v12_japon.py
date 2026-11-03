"""DEKORASYON v12 — JAPON TARZI (2026-11-03): 21 eşya, var olan sekmelere dağılır (yeni sekme yok).

Kullanıcı isteği: "japon tarzında en az 15-20 dekorasyon". Zemin deseni TATAMİ ve duvar kaplaması SHOJİ kodla
üretilir (vfx/decor_textures.gd); buradakiler model:

  YAŞAM ALANI   jp_kotatsu, jp_byobu, jp_andon, jp_maneki, jp_daruma, jp_taiko, jp_vending
  AVLU          jp_torii, jp_stone_lantern, jp_koi_pond, jp_zen_garden, jp_shishi_odoshi, jp_ramen_stall,
                jp_koinobori, jp_bamboo_fence
  BİTKİ         jp_maple
  DUVAR EŞYASI  jp_lanterns, jp_noren, jp_scroll, jp_neon_kanji, jp_fan

Yazı yok (dilden bağımsız) — tek istisna neon 車 ("araba"), süs olarak. Kurallar kit.py ile aynı: metre, ÖN = −Y,
duvar eşyasının arkası +Y'de duvara yaslanır.
Kullanım: CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py \
            -- tools/decor/props_v12_japon.py
"""
import math as _m
import os
import random

import bmesh
import mathutils

exec(open(os.path.join(os.path.dirname(__file__), "kit_torna.py"), encoding="utf-8").read())

R90 = _m.pi / 2

# --- Malzemeler ---------------------------------------------------------------------------
VERMIL = mat("Vermilyon", (0.80, 0.14, 0.06), 0.45)
LACQ = mat("SiyahLake", (0.035, 0.03, 0.035), 0.3)
DWOOD = mat("KoyuAhsap", (0.24, 0.14, 0.07), 0.75)
LWOOD = mat("Hinoki", (0.78, 0.60, 0.38), 0.7)
MWOOD = mat("Ahsap", (0.50, 0.32, 0.16), 0.75)
PAPER_E = mat("PirincKagidiIsik", (0.98, 0.92, 0.78), 0.9, emit=(0.42, 0.33, 0.17))
PAPER = mat("PirincKagidi", (0.93, 0.89, 0.80), 0.9)
PAPER_D = mat("KagitKoyu", (0.84, 0.79, 0.68), 0.9)
STONE = mat("Tas", (0.55, 0.55, 0.53), 0.95)
STONE_D = mat("TasKoyu", (0.38, 0.38, 0.37), 0.95)
MOSS = mat("Yosun", (0.22, 0.36, 0.10), 0.95)
GRAVEL = mat("Cakil", (0.80, 0.79, 0.74), 0.95)
GRAVEL_L = mat("CakilAcik", (0.91, 0.90, 0.86), 0.95)
WATER = mat("HavuzSuyu", (0.06, 0.24, 0.30), 0.06)
WATER_L = mat("AkanSu", (0.55, 0.78, 0.95), 0.1)
KOI_O = mat("KoiTuruncu", (0.98, 0.42, 0.04), 0.4)
KOI_W = mat("KoiBeyaz", (0.96, 0.95, 0.92), 0.4)
KOI_K = mat("KoiSiyah", (0.04, 0.04, 0.05), 0.4)
LEAF = mat("NiluferYaprak", (0.18, 0.48, 0.16), 0.7)
LOTUS = mat("Lotus", (0.98, 0.62, 0.78), 0.6)
GOLD = mat("Altin", (1.0, 0.62, 0.10), 0.28, 0.35, emit=(0.16, 0.09, 0.008))
GOLDLEAF = mat("AltinVaraK", (0.88, 0.66, 0.26), 0.4, 0.25, emit=(0.08, 0.05, 0.01))
GOLDLEAF_L = mat("AltinVarakAcik", (0.98, 0.84, 0.50), 0.5, 0.15, emit=(0.08, 0.06, 0.02))
INDIGO = mat("Indigo", (0.07, 0.11, 0.30), 0.9)
WHITE = mat("Beyaz", (0.93, 0.92, 0.89), 0.6)
RED = mat("Kirmizi", (0.75, 0.07, 0.05), 0.5)
DARK = mat("Karanlik", (0.03, 0.03, 0.035), 0.9)
BLACK = mat("Siyah", (0.04, 0.04, 0.045), 0.6)
PINK = mat("Pembe", (0.95, 0.55, 0.62), 0.7)
ORANGE = mat("Turuncu", (0.95, 0.45, 0.05), 0.6)
GREEN = mat("CamYesili", (0.10, 0.30, 0.14), 0.85)
GREEN_L = mat("AcikYesil", (0.30, 0.55, 0.18), 0.85)
FUJI = mat("FujiMavi", (0.20, 0.36, 0.66), 0.8)
SUN = mat("GunesKirmizi", (0.85, 0.10, 0.08), 0.6)
WAVE = mat("DalgaMavi", (0.10, 0.26, 0.55), 0.8)
FUTON = mat("KotatsuYorgan", (0.66, 0.16, 0.12), 0.95)
FUTON_B = mat("YorganBiye", (0.10, 0.14, 0.35), 0.95)
ZABUTON = mat("Zabuton", (0.12, 0.20, 0.45), 0.95)
ZABUTON2 = mat("ZabutonHardal", (0.80, 0.58, 0.16), 0.95)
SKIN = mat("DavulDerisi", (0.90, 0.84, 0.68), 0.8)
BARREL = mat("DavulGovde", (0.42, 0.13, 0.07), 0.45)
STEEL = mat("Celik", (0.62, 0.64, 0.68), 0.25, 0.6)
BAMBOO = mat("Bambu", (0.66, 0.68, 0.32), 0.7)
BAMBOO_D = mat("BambuKoyu", (0.48, 0.52, 0.20), 0.7)
BAMBOO_Y = mat("BambuSari", (0.80, 0.70, 0.40), 0.7)
ROPE = mat("SiyahIp", (0.05, 0.05, 0.05), 0.9)
BARK = mat("AkcaagacKabuk", (0.22, 0.15, 0.11), 0.9)
MAPLE_R = mat("AkcaagacKirmizi", (0.82, 0.12, 0.05), 0.85)
MAPLE_O = mat("AkcaagacTuruncu", (0.93, 0.36, 0.06), 0.85)
MAPLE_D = mat("AkcaagacBordo", (0.58, 0.06, 0.05), 0.85)
SOIL = mat("Toprak", (0.25, 0.17, 0.10), 0.95)
LANTERN = mat("FenerKirmizi", (0.86, 0.13, 0.07), 0.6, emit=(0.42, 0.05, 0.02))
GLOW = mat("FenerIsigi", (1.0, 0.82, 0.45), 0.6, emit=(0.95, 0.62, 0.20))
BACK_N = mat("NeonZemin", (0.06, 0.03, 0.08), 0.4)
N_RED = mat("NeonKirmizi", (1.0, 0.15, 0.20), 0.3, emit=(1.0, 0.10, 0.16))
N_CYAN = mat("NeonCamgobegi", (0.2, 1.0, 0.95), 0.3, emit=(0.15, 0.95, 0.9))
GLASS = mat("Cam", (0.70, 0.85, 0.95), 0.08, 0.1, alpha=0.25)
PANEL_E = mat("OtomatIsik", (0.92, 0.95, 0.98), 0.5, emit=(0.55, 0.58, 0.62))
BTN = mat("OtomatDugme", (0.20, 0.55, 1.0), 0.4, emit=(0.10, 0.35, 0.80))
VEND = mat("OtomatGovde", (0.90, 0.91, 0.92), 0.4)
VEND_R = mat("OtomatKirmizi", (0.80, 0.08, 0.10), 0.45)
NOODLE = mat("Eriste", (0.95, 0.86, 0.55), 0.7)
BROTH = mat("RamenSuyu", (0.72, 0.45, 0.18), 0.3)
BROCADE = mat("Brokar", (0.20, 0.32, 0.22), 0.7)
CAN_COLORS = [mat("Kutu%d" % i, c, 0.35) for i, c in enumerate(
    ((0.85, 0.10, 0.10), (0.10, 0.35, 0.85), (0.15, 0.62, 0.25), (0.98, 0.55, 0.05), (0.95, 0.95, 0.92),
     (0.45, 0.25, 0.10), (0.98, 0.85, 0.12)))]


# --- Yardımcılar --------------------------------------------------------------------------

def frustum(w0, d0, w1, d1, z0, z1, material, cx=0.0, cy=0.0):
    """Alt w0 × d0, üst w1 × d1 kesik piramit (kotatsu yorganı)."""
    bm = bmesh.new()
    lo = [bm.verts.new((cx + sx * w0 / 2, cy + sy * d0 / 2, z0)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    hi = [bm.verts.new((cx + sx * w1 / 2, cy + sy * d1 / 2, z1)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    return _obj_from_bm(bm, "kesik", material)


def disc_front(r, x, y, z, material, d=0.004, seg=20, sx=1.0, sz=1.0):
    """Önden (−Y) bakan daire / elips."""
    return ecyl(r * sx, r * sz, d, (x, y, z), material, seg=seg, rot=(R90, 0, 0))


def chochin(x, y, z, r=0.17, h=0.42, material=LANTERN, emblem=True):
    """Kırmızı kâğıt fener (alt ucu z'de): şişkin gövde, kaburgalar, siyah kapaklar, önde beyaz daire."""
    prof = [(r * 0.60, 0.0), (r * 0.88, h * 0.14), (r, h * 0.42), (r * 0.97, h * 0.62), (r * 0.82, h * 0.86),
            (r * 0.60, h)]
    lathe(prof, material, (x, y, z), seg=18)
    for k in range(1, 8):
        t = k / 8.0
        zz = h * t
        rr = r * (0.60 + 0.40 * _m.sin(_m.pi * min(t * 1.05, 1.0)))
        torus(rr * 1.005, 0.003, (x, y, z + zz), DARK, seg=18, mseg=3)
    cyl(r * 0.62, 0.035, (x, y, z - 0.012), BLACK, seg=14)
    cyl(r * 0.62, 0.035, (x, y, z + h + 0.012), BLACK, seg=14)
    if emblem:
        ball(r * 0.36, (x, y - r * 0.93, z + h * 0.48), WHITE, scale=(1.0, 0.18, 1.0), seg=14, ring=8)
        ball(r * 0.26, (x, y - r * 0.97, z + h * 0.48), material, scale=(1.0, 0.16, 1.0), seg=14, ring=8)
    cone(0.02, 0.0, 0.06, (x, y, z - 0.06), GOLD, rot=(_m.pi, 0, 0), seg=8)   # püskül


def bamboo_pole(x, y, z0, z1, r, material=BAMBOO, node=0.28, seed=0):
    cyl(r, z1 - z0, (x, y, (z0 + z1) / 2), material, seg=6)
    rng = random.Random(seed)
    z = z0 + rng.uniform(0.08, node)
    while z < z1 - 0.04:
        cyl(r * 1.12, 0.012, (x, y, z), BAMBOO_D, seg=6)
        z += node * rng.uniform(0.85, 1.15)
    cyl(r * 0.8, 0.004, (x, y, z1 + 0.002), BAMBOO_Y, seg=8)


# --- YAŞAM ALANI ----------------------------------------------------------------------------

def jp_kotatsu():
    frustum(1.12, 1.12, 0.96, 0.96, 0.02, 0.39, FUTON)
    frustum(1.14, 1.14, 1.10, 1.10, 0.0, 0.07, FUTON_B)                # alt biye
    frustum(1.125, 1.125, 1.105, 1.105, 0.085, 0.13, WHITE)            # beyaz şerit
    frustum(1.10, 1.10, 1.08, 1.08, 0.13, 0.175, FUTON_B)              # lacivert şerit
    box((0.84, 0.84, 0.03), (0, 0, 0.405), LWOOD)                     # masa tablası
    box((0.86, 0.86, 0.012), (0, 0, 0.396), DWOOD)
    lathe([(0.05, 0.0), (0.09, 0.03), (0.11, 0.06), (0.10, 0.06), (0.0, 0.01)], INDIGO, (0.14, 0.10, 0.42), seg=16)
    for (dx, dy, dz) in ((0.0, 0.0, 0.07), (0.04, 0.03, 0.065), (-0.04, 0.025, 0.065), (0.0, -0.04, 0.065),
                         (0.01, 0.0, 0.11)):
        ball(0.038, (0.14 + dx, 0.10 + dy, 0.42 + dz), ORANGE, seg=10, ring=6)   # mikan
    for (x, y) in ((-0.18, -0.14), (-0.05, -0.22)):                  # çay fincanları
        lathe([(0.025, 0.0), (0.032, 0.05), (0.028, 0.05), (0.0, 0.006)], GREEN_L, (x, y, 0.42), seg=12)
    ball(0.06, (-0.20, 0.14, 0.47), STONE_D, scale=(1.0, 1.0, 0.8), seg=12, ring=7)   # demlik
    rod((-0.15, 0.14, 0.48), (-0.10, 0.12, 0.51), 0.008, STONE_D, seg=6)
    torus(0.05, 0.006, (-0.20, 0.14, 0.53), BLACK, rot=(R90, 0, 0), seg=12, mseg=3)
    for (x, y, m) in ((0.0, -0.86, ZABUTON), (-0.86, 0.0, ZABUTON2), (0.86, 0.0, ZABUTON)):
        box((0.52, 0.52, 0.07), (x, y, 0.035), m)
        box((0.48, 0.48, 0.012), (x, y, 0.075), m)
        for sx in (-1, 1):
            for sy in (-1, 1):
                ball(0.012, (x + sx * 0.25, y + sy * 0.25, 0.05), GOLD, seg=6, ring=4)
        box((0.03, 0.03, 0.006), (x, y, 0.083), WHITE)                # ortadaki dikiş
    finish("jp_kotatsu")


def jp_byobu():
    w, h, n = 0.46, 1.55, 4
    angles = [0.42 if i % 2 == 0 else -0.42 for i in range(n)]   # 0 ve 2. panel kameraya bakar
    x, y = 0.0, 0.0
    pts = [(x, y)]
    for a in angles:
        x += w * _m.cos(a)
        y += w * _m.sin(a)
        pts.append((x, y))
    ox = pts[-1][0] / 2.0
    oy = sum(p[1] for p in pts) / len(pts)

    def panel(i):
        def build():
            box((w, 0.03, h), (0, 0, h / 2 + 0.04), LACQ)                     # çerçeve
            box((w - 0.05, 0.03, h - 0.05), (0, -0.004, h / 2 + 0.04), GOLDLEAF)
            for zz in (0.04, h + 0.04):
                box((w + 0.004, 0.035, 0.02), (0, 0, zz), GOLD)
            for zz, ww, dx in ((0.95, 0.32, 0.05), (1.30, 0.26, -0.06), (0.62, 0.22, 0.08)):   # altın bulutlar
                if (i + int(zz * 10)) % 2 == 0:
                    box((ww, 0.004, 0.07), (dx, -0.02, zz), GOLDLEAF_L)
            if i in (0, 1):                                                   # dalgalar
                box((w - 0.05, 0.004, 0.16), (0, -0.021, 0.16), WAVE)
                for k in range(4):
                    xx = -0.16 + k * 0.11
                    disc_front(0.06, xx, -0.023, 0.24, WAVE, d=0.004)
                    disc_front(0.025, xx + 0.03, -0.026, 0.285, WHITE, d=0.004)
            if i == 0:                                                        # Fuji
                prism([(-0.20, 0.32), (0.20, 0.32), (0.055, 0.86), (-0.055, 0.86)], 0.004, 'xz', FUJI,
                      offset=-0.022)
                prism([(-0.105, 0.66), (-0.06, 0.62), (-0.03, 0.67), (0.0, 0.61), (0.03, 0.67), (0.06, 0.62),
                       (0.105, 0.66), (0.055, 0.86), (-0.055, 0.86)], 0.004, 'xz', WHITE, offset=-0.025)
            if i == 2:                                                        # kırmızı güneş
                disc_front(0.11, 0.0, -0.023, 1.18, SUN, d=0.004, seg=24)
            if i in (1, 3):                                                   # çam dalı
                branch([(0.20, -0.025, 0.55), (0.05, -0.03, 0.78), (-0.12, -0.03, 0.92)], 0.012, 0.008, DWOOD, seg=5)
                for (bx, bz) in ((0.08, 0.80), (-0.05, 0.90), (-0.15, 0.94), (0.14, 0.66)):
                    ball(0.07, (bx, -0.035, bz), GREEN, scale=(1.0, 0.18, 0.5), seg=10, ring=5)
            for sx in (-1, 1):
                box((0.05, 0.05, 0.04), (sx * (w / 2 - 0.04), 0, 0.02), LACQ)      # ayaklar
        return build

    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        local(panel(i), ((x0 + x1) / 2 - ox, (y0 + y1) / 2 - oy, 0.0), yaw=angles[i])
    finish("jp_byobu")


def jp_andon():
    box((0.36, 0.36, 0.04), (0, 0, 0.02), DWOOD)
    box((0.27, 0.27, 0.62), (0, 0, 0.43), PAPER_E)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box((0.028, 0.028, 0.88), (sx * 0.14, sy * 0.14, 0.48), DWOOD)
    for z in (0.12, 0.43, 0.74):
        for sy in (-1, 1):
            box((0.30, 0.016, 0.016), (0, sy * 0.138, z), DWOOD)
            box((0.016, 0.30, 0.016), (sy * 0.138, 0, z), DWOOD)
    for sy in (-1, 1):                                                 # dikey ince kafes
        box((0.012, 0.014, 0.62), (0, sy * 0.138, 0.43), DWOOD)
        box((0.014, 0.012, 0.62), (sy * 0.138, 0, 0.43), DWOOD)
    box((0.32, 0.32, 0.025), (0, 0, 0.93), DWOOD)
    rod((-0.10, 0, 0.94), (-0.10, 0, 1.00), 0.01, DWOOD, seg=6)
    rod((0.10, 0, 0.94), (0.10, 0, 1.00), 0.01, DWOOD, seg=6)
    box((0.22, 0.025, 0.025), (0, 0, 1.005), DWOOD)
    finish("jp_andon")


def jp_maneki():
    def cat():
        box((0.38, 0.38, 0.07), (0, 0, 0.035), RED)                    # kırmızı minder
        box((0.36, 0.36, 0.012), (0, 0, 0.075), RED)
        for sx in (-1, 1):
            for sy in (-1, 1):
                cone(0.016, 0.0, 0.05, (sx * 0.19, sy * 0.19, 0.04), GOLD, rot=(_m.pi, 0, 0), seg=6)
        z0 = 0.08
        ball(0.15, (0, 0.02, z0 + 0.15), WHITE, scale=(1.0, 0.85, 1.12), seg=16, ring=10)    # gövde
        for sx in (-1, 1):                                             # arka bacaklar
            ball(0.07, (sx * 0.10, -0.04, z0 + 0.05), WHITE, scale=(0.9, 1.3, 0.7), seg=10, ring=6)
        ball(0.135, (0, -0.01, z0 + 0.38), WHITE, scale=(1.12, 0.95, 0.92), seg=18, ring=10)  # baş
        for sx in (-1, 1):                                             # kulaklar
            cone(0.05, 0.0, 0.08, (sx * 0.085, 0.0, z0 + 0.50), WHITE, rot=(0, sx * 0.30, 0), seg=8)
            cone(0.032, 0.0, 0.05, (sx * 0.083, -0.022, z0 + 0.495), PINK, rot=(0, sx * 0.30, 0), seg=8)
            box((0.045, 0.012, 0.012), (sx * 0.052, -0.125, z0 + 0.395), BLACK, rot=(0, sx * 0.25, 0))   # gülen göz
            for k in (-1, 1):                                          # bıyık
                box((0.07, 0.003, 0.003), (sx * 0.10, -0.115, z0 + 0.345 + k * 0.012), BLACK, rot=(0, sx * k * 0.2, 0))
        ball(0.014, (0, -0.137, z0 + 0.36), PINK, seg=8, ring=5)
        box((0.03, 0.004, 0.004), (0, -0.132, z0 + 0.335), BLACK)
        ball(0.06, (0.05, 0.02, z0 + 0.49), ORANGE, scale=(1.0, 1.0, 0.35), seg=10, ring=6)   # benekler
        ball(0.05, (-0.07, 0.08, z0 + 0.43), BLACK, scale=(0.8, 1.0, 0.6), seg=10, ring=6)
        ball(0.07, (0.08, 0.10, z0 + 0.20), ORANGE, scale=(0.7, 1.0, 0.9), seg=10, ring=6)
        torus(0.088, 0.016, (0, -0.005, z0 + 0.275), RED, seg=20, mseg=5)   # tasma + çıngırak
        ball(0.024, (0, -0.095, z0 + 0.255), GOLD, seg=10, ring=7)
        branch([(0.10, -0.02, z0 + 0.26), (0.14, -0.07, z0 + 0.38), (0.13, -0.08, z0 + 0.50)], 0.036, 0.034,
               WHITE, seg=10)                                          # sallanan pati
        ball(0.042, (0.13, -0.085, z0 + 0.53), WHITE, seg=12, ring=7)
        ball(0.018, (0.13, -0.122, z0 + 0.525), PINK, scale=(1.0, 0.4, 1.0), seg=8, ring=5)
        ball(0.04, (-0.07, -0.11, z0 + 0.13), WHITE, scale=(1.0, 0.9, 1.4), seg=10, ring=6)   # koban tutan pati
        ecyl(0.055, 0.085, 0.014, (-0.05, -0.155, z0 + 0.17), GOLD, seg=18, rot=(R90, 0, 0))   # altın koban
        for k in (-1, 0, 1):
            box((0.05, 0.004, 0.004), (-0.05, -0.164, z0 + 0.17 + k * 0.035), DWOOD)
        ball(0.04, (0.0, 0.15, z0 + 0.06), WHITE, scale=(1.6, 0.8, 0.6), seg=10, ring=6)       # kuyruk
    local(cat, scale=1.35)
    finish("jp_maneki")


def jp_daruma():
    box((0.86, 0.34, 0.03), (0, 0, 0.135), DWOOD)                     # alçak sehpa
    for sx in (-1, 1):
        box((0.04, 0.30, 0.12), (sx * 0.38, 0, 0.06), DWOOD)
    for (x, hgt, body, face) in ((-0.25, 0.32, RED, WHITE), (0.04, 0.26, WHITE, RED), (0.28, 0.20, RED, WHITE)):
        z = 0.15
        ball(hgt / 2, (x, 0, z + hgt / 2), body, scale=(0.92, 0.88, 1.0), seg=18, ring=10)
        ball(hgt * 0.30, (x, -hgt * 0.30, z + hgt * 0.60), face, scale=(1.0, 0.45, 0.85), seg=14, ring=8)
        for sx in (-1, 1):
            ball(hgt * 0.07, (x + sx * hgt * 0.11, -hgt * 0.42, z + hgt * 0.63), WHITE, scale=(1.0, 0.3, 1.0), seg=10,
                 ring=6)
            box((hgt * 0.16, 0.006, hgt * 0.035), (x + sx * hgt * 0.12, -hgt * 0.40, z + hgt * 0.74), BLACK,
                rot=(0, sx * -0.3, 0))                                 # kaşlar
            box((hgt * 0.12, 0.006, hgt * 0.025), (x + sx * hgt * 0.07, -hgt * 0.42, z + hgt * 0.50), BLACK,
                rot=(0, sx * 0.35, 0))                                 # bıyık
        ball(hgt * 0.035, (x - hgt * 0.11, -hgt * 0.445, z + hgt * 0.63), BLACK, scale=(1.0, 0.3, 1.0), seg=8, ring=5)
        torus(hgt * 0.14, hgt * 0.02, (x, -hgt * 0.40, z + hgt * 0.24), GOLD, rot=(R90, 0, 0), seg=14, mseg=3)
        box((hgt * 0.20, 0.006, hgt * 0.03), (x, -hgt * 0.43, z + hgt * 0.24), GOLD)
    finish("jp_daruma")


def jp_taiko():
    def drum():
        lathe([(0.33, -0.27), (0.36, -0.17), (0.385, 0.0), (0.36, 0.17), (0.33, 0.27)], BARREL, seg=28)
        for s in (-1, 1):
            cyl(0.338, 0.012, (0, 0, s * 0.27), SKIN, seg=28)
            torus(0.335, 0.012, (0, 0, s * 0.268), DWOOD, seg=28, mseg=4)
            for k in range(20):
                a = k * _m.tau / 20
                ball(0.011, (0.345 * _m.cos(a), 0.345 * _m.sin(a), s * 0.245), GOLD, seg=6, ring=4)
        for k in range(3):                                            # mitsudomoe (üç virgül)
            a = k * _m.tau / 3
            cx, cy = 0.075 * _m.cos(a), 0.075 * _m.sin(a)
            ecyl(0.06, 0.06, 0.006, (cx, cy, 0.279), BLACK, seg=16)
            ecyl(0.03, 0.06, 0.006, (cx + 0.06 * _m.cos(a + 1.6), cy + 0.06 * _m.sin(a + 1.6), 0.279), BLACK, seg=12,
                 rot=(0, 0, a + 0.4))
        for sx in (-1, 1):                                            # yan halkalar
            torus(0.05, 0.01, (sx * 0.385, 0, 0), GOLD, rot=(0, R90, 0), seg=12, mseg=4)
    local(drum, (0, 0, 0.66), pitch=_m.radians(70))
    for sx in (-1, 1):                                                # ahşap beşik
        box((0.08, 0.60, 0.08), (sx * 0.42, 0, 0.04), DWOOD)
        for sy in (-1, 1):
            rod((sx * 0.42, sy * 0.24, 0.06), (sx * 0.42, sy * 0.06, 0.58), 0.03, DWOOD, seg=8)
        box((0.07, 0.16, 0.06), (sx * 0.42, 0.0, 0.60), DWOOD)
    box((0.90, 0.07, 0.06), (0, 0.22, 0.10), DWOOD)
    box((0.90, 0.07, 0.06), (0, -0.22, 0.10), DWOOD)
    for dx in (-0.10, 0.06):                                          # bachi
        rod((dx, -0.24, 0.135), (dx + 0.08, -0.24 + 0.38, 0.14), 0.015, LWOOD, seg=6)
    finish("jp_taiko")


def jp_vending():
    W, D, H = 0.95, 0.72, 1.82
    box((W, D, H), (0, 0, H / 2 + 0.04), VEND)
    box((W + 0.01, D + 0.01, 0.04), (0, 0, 0.02), BLACK)
    box((W + 0.012, D + 0.012, 0.125), (0, 0, H - 0.0175), VEND_R)   # gövde tepesinden 5 mm yüksek
    for sx in (-1, 1):
        box((0.004, D * 0.9, 0.08), (sx * (W / 2 + 0.002), 0, 1.20), INDIGO)
    fy = -D / 2
    box((0.82, 0.01, 0.82), (0, fy - 0.002, 1.24), PANEL_E)
    for row, z in enumerate((0.92, 1.18, 1.44)):
        box((0.80, 0.03, 0.012), (0, fy - 0.02, z - 0.008), STEEL)
        for k in range(7):
            x = -0.33 + k * 0.11
            m = CAN_COLORS[(k + row * 3) % len(CAN_COLORS)]
            if (k + row) % 3 == 0:
                lathe([(0.032, 0.0), (0.034, 0.10), (0.018, 0.14), (0.016, 0.16), (0.0, 0.16)], m, (x, fy - 0.03, z),
                      seg=10)                                          # şişe
                cyl(0.018, 0.012, (x, fy - 0.03, z + 0.166), WHITE, seg=8)
            else:
                cyl(0.032, 0.12, (x, fy - 0.03, z + 0.06), m, seg=10)     # kutu
                cyl(0.026, 0.006, (x, fy - 0.03, z + 0.123), STEEL, seg=10)
            box((0.05, 0.012, 0.022), (x, fy - 0.02, z - 0.04), BTN)
    box((0.84, 0.012, 0.84), (0, fy - 0.07, 1.24), GLASS)
    box((0.86, 0.02, 0.02), (0, fy - 0.07, 0.82), VEND)
    box((0.86, 0.02, 0.02), (0, fy - 0.07, 1.66), VEND)
    box((0.30, 0.012, 0.16), (0.24, fy - 0.006, 0.66), STEEL)           # para paneli
    box((0.10, 0.006, 0.04), (0.24, fy - 0.014, 0.70), BLACK)
    box((0.03, 0.006, 0.05), (0.33, fy - 0.014, 0.64), BLACK)
    box((0.62, 0.02, 0.20), (0, fy - 0.005, 0.24), BLACK)               # alma bölmesi
    box((0.58, 0.02, 0.10), (0, fy - 0.02, 0.28), STEEL, rot=(-0.25, 0, 0))
    finish("jp_vending")


# --- AVLU -----------------------------------------------------------------------------------

def jp_torii():
    for sx in (-1, 1):
        cyl(0.12, 2.25, (sx * 0.92, 0, 1.125), VERMIL, seg=14)
        cyl(0.155, 0.24, (sx * 0.92, 0, 0.12), BLACK, seg=14)
    box((2.55, 0.12, 0.16), (0, 0, 1.86), VERMIL)                      # nuki
    box((0.10, 0.10, 0.36), (0, 0, 2.12), VERMIL)                      # gakuzuka
    box((0.34, 0.07, 0.44), (0, -0.07, 2.10), BLACK)                   # levha
    box((0.36, 0.075, 0.03), (0, -0.07, 2.32), GOLD)
    box((0.36, 0.075, 0.03), (0, -0.07, 1.88), GOLD)
    for zz in (2.05, 2.17):
        box((0.12, 0.08, 0.02), (0, -0.075, zz), GOLD)
    box((2.75, 0.20, 0.13), (0, 0, 2.36), VERMIL)                      # shimaki
    n = 14
    L = 1.78
    bottom = [(-L + 2 * L * i / n, 2.43 + 0.14 * (abs(-L + 2 * L * i / n) / L) ** 3) for i in range(n + 1)]
    top = [(x, z + 0.15 + 0.05 * (abs(x) / L) ** 2) for (x, z) in reversed(bottom)]
    prism(bottom + top, 0.28, 'xz', BLACK)                              # kasagi (kalkık uçlu)
    finish("jp_torii")


def jp_stone_lantern():
    cyl(0.25, 0.10, (0, 0, 0.05), STONE, seg=6)
    cyl(0.19, 0.06, (0, 0, 0.13), STONE, seg=6)
    cyl(0.075, 0.42, (0, 0, 0.37), STONE, seg=10)
    torus(0.08, 0.012, (0, 0, 0.37), STONE_D, seg=10, mseg=3)
    cone(0.10, 0.20, 0.06, (0, 0, 0.61), STONE, seg=6)
    cyl(0.21, 0.07, (0, 0, 0.675), STONE, seg=6)
    cyl(0.15, 0.24, (0, 0, 0.83), STONE, seg=6, rot=(0, 0, _m.pi / 6))
    for yaw in (0.0, _m.radians(60), _m.radians(-60), _m.pi):
        local(lambda: box((0.10, 0.02, 0.13), (0, -0.126, 0), GLOW), (0, 0, 0.83), yaw=yaw)
    cyl(0.31, 0.03, (0, 0, 0.965), STONE_D, seg=6)
    cone(0.31, 0.09, 0.15, (0, 0, 1.055), STONE, seg=6)
    for k in range(6):                                                 # kalkık köşeler
        a = k * _m.tau / 6
        ball(0.04, (0.31 * _m.cos(a), 0.31 * _m.sin(a), 1.0), STONE, scale=(1.0, 1.0, 0.7), seg=8, ring=5)
    cyl(0.07, 0.04, (0, 0, 1.15), STONE, seg=6)
    ball(0.06, (0, 0, 1.21), STONE, seg=10, ring=6)
    cone(0.035, 0.0, 0.07, (0, 0, 1.28), STONE, seg=8)
    for (x, y, z, r) in ((0.18, -0.12, 0.10, 0.06), (-0.12, 0.14, 1.02, 0.07), (0.15, 0.10, 1.03, 0.05),
                         (-0.17, -0.05, 0.69, 0.05)):
        ball(r, (x, y, z), MOSS, scale=(1.0, 1.0, 0.35), seg=8, ring=5)
    finish("jp_stone_lantern")


def jp_koi_pond():
    rng = random.Random(5)
    outline = []
    for k in range(40):
        a = k * _m.tau / 40
        r = 1.0 + 0.12 * _m.sin(2 * a) + 0.07 * _m.cos(3 * a + 0.5)
        outline.append((0.95 * r * _m.cos(a), 0.62 * r * _m.sin(a)))
    prism(outline, 0.03, 'xy', WATER, offset=0.065)
    prism([(x * 1.02, y * 1.02) for (x, y) in outline], 0.02, 'xy', SOIL, offset=0.01)
    # Kenar taşları (yay boyu ~0,16 m'de bir)
    per = 0.0
    last = None
    for (x, y) in outline + [outline[0]]:
        if last is not None:
            per += _m.hypot(x - last[0], y - last[1])
        last = (x, y)
        if per >= 0.15 or len(outline) == 0:
            per = 0.0
            d = _m.hypot(x, y)
            ux, uy = x / d, y / d
            r = rng.uniform(0.085, 0.12)
            ball(r, (x + ux * 0.04, y + uy * 0.04, 0.05), STONE if rng.random() < 0.6 else STONE_D,
                 scale=(rng.uniform(1.0, 1.4), rng.uniform(0.9, 1.2), rng.uniform(0.5, 0.75)), seg=8, ring=5)
    for (x, y, r) in ((0.85, 0.35, 0.20), (1.02, 0.10, 0.14), (-0.95, -0.25, 0.16)):   # iri kayalar
        ball(r, (x, y, r * 0.6), STONE_D, scale=(1.3, 1.0, 0.9), seg=10, ring=6)
        ball(r * 0.6, (x, y, r * 1.1), MOSS, scale=(1.3, 1.0, 0.35), seg=8, ring=5)

    def koi(col1, col2, spots):
        def build():
            ball(0.10, (0, 0, 0), col1, scale=(1.0, 0.36, 0.20), seg=12, ring=6)
            prism([(0.08, 0.0), (0.17, 0.05), (0.16, 0.0), (0.17, -0.05)], 0.008, 'xy', col1)
            for (sx, r) in spots:
                ball(r, (sx, 0, 0.008), col2, scale=(1.0, 0.33, 0.22), seg=10, ring=5)
            for sy in (-1, 1):
                ball(0.006, (-0.075, sy * 0.025, 0.006), KOI_K, seg=6, ring=4)
        return build

    for (x, y, yaw, c1, c2, sp) in ((0.30, 0.10, 0.6, KOI_W, KOI_O, ((-0.04, 0.04), (0.04, 0.03))),
                                    (-0.25, -0.15, 2.5, KOI_O, KOI_W, ((0.02, 0.035),)),
                                    (-0.10, 0.25, -0.4, KOI_W, KOI_K, ((-0.03, 0.03), (0.05, 0.025))),
                                    (0.45, -0.25, 3.6, KOI_O, KOI_K, ((0.0, 0.03),)),
                                    (-0.50, 0.10, 1.4, KOI_W, KOI_O, ((-0.05, 0.035),))):
        local(koi(c1, c2, sp), (x, y, 0.082), yaw=yaw)
    for (x, y, r) in ((0.05, -0.30, 0.09), (0.18, -0.38, 0.07), (-0.62, 0.30, 0.10), (0.62, 0.05, 0.08)):
        cyl(r, 0.006, (x, y, 0.083), LEAF, seg=12)                     # nilüfer yaprakları
    for k in range(6):                                                 # lotus
        a = k * _m.tau / 6
        cone(0.025, 0.0, 0.06, (-0.62 + 0.02 * _m.cos(a), 0.30 + 0.02 * _m.sin(a), 0.105), LOTUS,
             rot=(0.5 * _m.sin(a), -0.5 * _m.cos(a), 0), seg=5)
    ball(0.015, (-0.62, 0.30, 0.10), GOLD, seg=6, ring=4)
    finish("jp_koi_pond")


def jp_zen_garden():
    W, D = 1.80, 1.20
    for sy in (-1, 1):
        box((W, 0.08, 0.12), (0, sy * (D / 2 - 0.04), 0.06), DWOOD)
    for sx in (-1, 1):
        box((0.08, D - 0.16, 0.12), (sx * (W / 2 - 0.04), 0, 0.06), DWOOD)
    box((W - 0.16, D - 0.16, 0.08), (0, 0, 0.04), GRAVEL)
    rocks = [(-0.45, 0.10, 0.16, 0.34), (0.40, -0.15, 0.12, 0.27), (0.58, 0.28, 0.08, 0.18)]
    xmin, xmax = -W / 2 + 0.09, W / 2 - 0.09
    y = -D / 2 + 0.11
    while y < D / 2 - 0.09:                                            # tırmık çizgileri, halkaların dışında
        cuts = []
        for (cx, cy, r, R) in rocks:
            if abs(y - cy) < R:
                dx = _m.sqrt(R * R - (y - cy) ** 2)
                cuts.append((cx - dx, cx + dx))
        cuts.sort()
        x = xmin
        for (a, b) in cuts + [(xmax, xmax)]:
            if a - x > 0.02:
                box((a - x, 0.012, 0.006), ((a + x) / 2, y, 0.082), GRAVEL_L)
            x = max(x, b)
        y += 0.05
    rng = random.Random(9)
    for (cx, cy, r, R) in rocks:
        rr = r + 0.05
        while rr <= R:
            o = torus(rr, 0.007, (cx, cy, 0.082), GRAVEL_L, seg=28, mseg=3)
            o.scale = (1.0, 1.0, 0.6)
            rr += 0.05
        ball(r, (cx, cy, 0.08 + r * 0.45), STONE_D, scale=(1.3, 1.0, 1.0), seg=10, ring=7)
        o = bpy.context.object
        o.rotation_euler = (rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(0, _m.pi))
        ball(r * 0.55, (cx - r * 0.2, cy + r * 0.1, 0.08 + r * 0.95), MOSS, scale=(1.3, 1.0, 0.35), seg=8, ring=5)
    finish("jp_zen_garden")


def jp_shishi_odoshi():
    ecyl(0.48, 0.30, 0.02, (0, 0, 0.01), GRAVEL, seg=24)
    rng = random.Random(3)
    for k in range(14):
        a = rng.uniform(0, _m.tau)
        ball(0.025, (0.40 * _m.cos(a) * rng.uniform(0.6, 1.0), 0.25 * _m.sin(a) * rng.uniform(0.6, 1.0), 0.025),
             STONE if k % 2 else STONE_D, scale=(1.2, 1.0, 0.6), seg=6, ring=4)
    # Tsukubai (taş yalak) + kepçe
    lathe([(0.17, 0.0), (0.20, 0.06), (0.19, 0.20), (0.17, 0.22), (0.11, 0.22), (0.10, 0.17), (0.0, 0.16)], STONE,
          (-0.22, -0.06, 0.0), seg=14)
    cyl(0.105, 0.004, (-0.22, -0.06, 0.205), WATER, seg=14)
    rod((-0.36, -0.06, 0.23), (-0.08, -0.06, 0.23), 0.006, BAMBOO_Y, seg=5)
    cyl(0.025, 0.04, (-0.10, -0.06, 0.24), BAMBOO_Y, seg=8)
    # Su borusu: dik bambu direk + yatay oluk
    bamboo_pole(0.32, 0.12, 0.0, 0.62, 0.032, seed=1)
    rod((0.32, 0.12, 0.56), (0.14, 0.05, 0.53), 0.018, BAMBOO, seg=8)
    rod((0.14, 0.05, 0.53), (0.12, 0.04, 0.43), 0.004, WATER_L, seg=5)     # akan su
    # Tahterevalli bambu: iki kazık arasında pim
    for sy in (-1, 1):
        rod((0.02, sy * 0.05 + 0.04, 0.0), (0.02, sy * 0.05 + 0.04, 0.32), 0.016, BAMBOO_D, seg=6)
    rod((0.02, -0.02, 0.28), (0.02, 0.10, 0.28), 0.006, DWOOD, seg=5)
    rod((-0.24, 0.04, 0.16), (0.14, 0.04, 0.40), 0.03, BAMBOO, seg=10)
    cyl(0.025, 0.004, (0.142, 0.04, 0.402), BAMBOO_Y, seg=10, rot=(0, 0.56, 0))
    ball(0.07, (-0.27, 0.04, 0.06), STONE_D, scale=(1.2, 1.0, 0.8), seg=8, ring=5)   # vurduğu taş
    finish("jp_shishi_odoshi")


def jp_ramen_stall():
    box((1.60, 0.74, 0.62), (0, 0.04, 0.47), LWOOD)                   # tezgâh gövdesi
    for x in (-0.79, -0.27, 0.27, 0.79):
        box((0.04, 0.76, 0.64), (x, 0.04, 0.47), DWOOD)
    box((1.62, 0.76, 0.04), (0, 0.04, 0.17), DWOOD)
    for sy in (-1, 1):                                                # tekerlekler (yanlarda)
        yy = 0.04 + sy * 0.40
        torus(0.24, 0.025, (-0.50, yy, 0.25), DWOOD, rot=(R90, 0, 0), seg=18, mseg=4)
        cyl(0.05, 0.06, (-0.50, yy, 0.25), BLACK, rot=(R90, 0, 0), seg=10)
        for k in range(6):
            a = k * _m.pi / 6
            box((0.46, 0.02, 0.02), (-0.50, yy, 0.25), DWOOD, rot=(0, a, 0))
    box((1.80, 0.36, 0.04), (0, -0.46, 0.86), DWOOD)                  # müşteri tezgâhı
    box((1.66, 0.80, 0.03), (0, 0.04, 0.795), MWOOD)
    for x in (-0.55, 0.0, 0.55):                                      # ramen kâseleri
        lathe([(0.05, 0.0), (0.09, 0.03), (0.10, 0.07), (0.093, 0.07), (0.0, 0.012)], RED, (x, -0.50, 0.88), seg=16)
        cyl(0.088, 0.006, (x, -0.50, 0.94), BROTH, seg=16)
        torus(0.04, 0.012, (x + 0.02, -0.50, 0.946), NOODLE, seg=12, mseg=4)
        cyl(0.025, 0.004, (x - 0.035, -0.47, 0.947), WHITE, seg=10)
        rod((x + 0.06, -0.58, 0.95), (x + 0.12, -0.40, 0.95), 0.004, LWOOD, seg=4)
        rod((x + 0.075, -0.585, 0.95), (x + 0.135, -0.405, 0.95), 0.004, LWOOD, seg=4)
    cyl(0.17, 0.26, (0.45, 0.12, 0.94), STEEL, seg=18)                # kazan
    cyl(0.175, 0.02, (0.45, 0.12, 1.08), STEEL, seg=18)
    ball(0.025, (0.45, 0.12, 1.10), BLACK, seg=8, ring=5)
    for sx in (-1, 1):                                                # direkler + çatı
        for sy in (-1, 1):
            box((0.06, 0.06, 1.14), (sx * 0.78, 0.04 + sy * 0.32, 1.38), DWOOD)
    for sy in (-1, 1):
        box((1.95, 0.62, 0.035), (0, 0.04 + sy * 0.27, 2.06), DWOOD, rot=(-sy * 0.36, 0, 0))
    box((1.98, 0.06, 0.06), (0, 0.04, 2.17), BLACK)
    box((1.70, 0.05, 0.07), (0, -0.30, 1.92), DWOOD)                  # noren çıtası
    for k in range(5):                                                # noren
        x = -0.64 + k * 0.32
        box((0.30, 0.012, 0.36), (x, -0.33, 1.73), INDIGO)
        box((0.30, 0.013, 0.02), (x, -0.331, 1.56), WHITE)
    disc_front(0.09, 0.0, -0.338, 1.76, WHITE, d=0.004, seg=20)
    disc_front(0.065, 0.0, -0.341, 1.76, INDIGO, d=0.004, seg=20)
    for sx in (-1, 1):                                                # fenerler
        rod((sx * 0.88, -0.30, 1.92), (sx * 0.88, -0.30, 1.80), 0.004, BLACK, seg=4)
        chochin(sx * 0.88, -0.30, 1.40, r=0.13, h=0.36)
    for k in range(3):                                                # menü tahtaları
        box((0.12, 0.012, 0.22), (-0.30 + k * 0.16, 0.36, 1.68), PAPER)
        box((0.012, 0.014, 0.16), (-0.30 + k * 0.16, 0.355, 1.68), BLACK)
    for x in (-0.55, 0.0, 0.55):                                      # tabureler
        cyl(0.13, 0.04, (x, -0.86, 0.54), MWOOD, seg=14)
        for k in range(3):
            a = k * _m.tau / 3 + 0.5
            rod((x + 0.07 * _m.cos(a), -0.86 + 0.07 * _m.sin(a), 0.52),
                (x + 0.12 * _m.cos(a), -0.86 + 0.12 * _m.sin(a), 0.0), 0.016, DWOOD, seg=6)
    rod((0.98, -0.20, 0.0), (0.98, -0.20, 1.80), 0.015, BAMBOO, seg=6)   # nobori bayrağı
    box((0.012, 0.28, 0.95), (0.98, -0.06, 1.24), RED)
    rod((0.98, -0.20, 1.71), (0.98, 0.10, 1.71), 0.008, BAMBOO, seg=5)
    for k in range(3):
        box((0.014, 0.10, 0.10), (0.985, -0.06, 1.55 - k * 0.22), WHITE)
    finish("jp_ramen_stall")


def jp_koinobori():
    box((0.42, 0.42, 0.10), (0, 0, 0.05), STONE)
    for (x, y) in ((0.15, 0.15), (-0.15, -0.15)):
        box((0.12, 0.10, 0.08), (x, y, 0.14), STONE_D)
    cyl(0.04, 3.25, (0, 0, 1.725), WHITE, seg=12)
    cyl(0.05, 0.10, (0, 0, 0.15), STEEL, seg=12)
    for k in range(8):                                                 # yaguruma
        a = k * _m.tau / 8
        box((0.16, 0.012, 0.02), (0.08 * _m.cos(a), 0.08 * _m.sin(a), 3.30), GOLD, rot=(0, 0, a))
    torus(0.16, 0.008, (0, 0, 3.30), GOLD, seg=16, mseg=3)
    ball(0.05, (0, 0, 3.40), GOLD, seg=10, ring=6)
    # Fukinagashi (beş renkli flama)
    for k, m in enumerate((WAVE, RED, WHITE, CAN_COLORS[6], CAN_COLORS[2])):
        z = 3.20 - k * 0.035
        sheet_xz(lambda x, zz: 0.03 * _m.sin(x * 7.0), 0.05, 1.05 - k * 0.04, z - 0.017, z + 0.017, 10, 1, m)

    def carp(body, belly, length, r, z):
        n = 12
        path = [(0.06 + length * i / (n - 1), 0.0, z + 0.04 * _m.sin(i * 0.9)) for i in range(n)]

        def rad(i, nn):
            t = i / (nn - 1)
            return r * (0.88 + 0.5 * _m.sin(_m.pi * min(t * 1.6, 1.0))) * (1.0 - 0.55 * t)
        o = tube(path, rad, body, seg=12)
        solidify(o, 0.006)
        for i in (3, 5, 7, 9):
            p = path[i]
            torus(rad(i, n) * 1.01, 0.006, p, belly, rot=(0, R90, 0), seg=12, mseg=3)
        tx, _, tz = path[-1]
        for s in (-1, 1):                                              # kuyruk
            prism([(tx - 0.02, tz), (tx + 0.22, tz + s * 0.20), (tx + 0.12, tz)], 0.01, 'xz', body)
        torus(rad(0, n), 0.016, path[0], GOLD, rot=(0, R90, 0), seg=12, mseg=4)   # ağız halkası
        cyl(rad(0, n) * 0.9, 0.004, (path[0][0] + 0.03, 0.0, path[0][2]), DARK, rot=(0, R90, 0), seg=12)
        ex, ez = path[1][0] + 0.04, path[1][2] + r * 0.25
        for s in (-1, 1):                                              # gözler
            yy = s * rad(1, n) * 0.95
            ecyl(r * 0.30, r * 0.30, 0.01, (ex, yy, ez), WHITE, seg=14, rot=(R90, 0, 0))
            ecyl(r * 0.15, r * 0.15, 0.012, (ex, yy + s * 0.003, ez), BLACK, seg=10, rot=(R90, 0, 0))

    carp(BLACK, GOLD, 1.25, 0.17, 2.85)
    carp(RED, WHITE, 1.05, 0.145, 2.35)
    carp(WAVE, WHITE, 0.85, 0.12, 1.90)
    finish("jp_koinobori")


def jp_bamboo_fence():
    L, Hh = 1.80, 0.95
    for sx in (-1, 1):
        cyl(0.05, Hh + 0.08, (sx * L / 2, 0.0, (Hh + 0.08) / 2), DWOOD, seg=10)
        cone(0.055, 0.02, 0.05, (sx * L / 2, 0.0, Hh + 0.105), DWOOD, seg=10)
    rng = random.Random(4)
    x = -L / 2 + 0.07
    k = 0
    while x < L / 2 - 0.05:
        top = Hh - rng.uniform(0.0, 0.03)
        bamboo_pole(x, 0.0, 0.0, top, 0.021, BAMBOO if k % 3 else BAMBOO_Y, node=0.42, seed=k)
        x += 0.044
        k += 1
    for z in (0.18, 0.50, 0.82):                                       # yatay oluklar + siyah ip
        for dz in (-0.024, 0.024):
            rod((-L / 2, -0.035, z + dz), (L / 2, -0.035, z + dz), 0.02, BAMBOO_D, seg=8)
        for xx in (-0.66, -0.22, 0.22, 0.66):
            box((0.05, 0.02, 0.012), (xx, -0.058, z), ROPE, rot=(0, 0.6, 0))
            box((0.05, 0.02, 0.012), (xx, -0.058, z), ROPE, rot=(0, -0.6, 0))
            ball(0.012, (xx, -0.062, z - 0.035), ROPE, seg=6, ring=4)
    finish("jp_bamboo_fence")


# --- BİTKİ ----------------------------------------------------------------------------------

def jp_maple():
    o = torus(0.42, 0.06, (0, 0, 0.04), STONE, seg=20, mseg=5)
    o.scale = (1.0, 1.0, 0.7)
    ecyl(0.42, 0.42, 0.06, (0, 0, 0.04), SOIL, seg=20)
    ball(0.30, (0.05, -0.05, 0.07), MOSS, scale=(1.2, 1.0, 0.18), seg=10, ring=5)
    branch([(0, 0, 0.0), (0.06, 0.02, 0.55), (-0.05, 0.0, 0.95), (0.04, -0.03, 1.25)], 0.085, 0.05, BARK, seg=8)
    rng = random.Random(21)
    tips = []
    for (dx, dy, dz) in ((0.65, -0.20, 1.35), (-0.60, -0.15, 1.45), (0.20, 0.50, 1.55), (-0.30, 0.40, 1.30),
                         (0.30, -0.45, 1.65), (-0.15, -0.35, 1.85), (0.05, 0.10, 1.95)):
        base = (0.0, -0.01, rng.uniform(0.95, 1.25))
        mid = (dx * 0.5, dy * 0.5, (base[2] + dz) / 2 + 0.08)
        branch([base, mid, (dx, dy, dz)], 0.04, 0.02, BARK, seg=6)
        tips.append(((dx, dy, dz), mid))
    for (tip, mid) in tips:
        for p in (tip, mid):
            for k in range(3):
                ball(rng.uniform(0.16, 0.24), (p[0] + rng.uniform(-0.15, 0.15), p[1] + rng.uniform(-0.15, 0.15),
                                               p[2] + rng.uniform(0.0, 0.12)),
                     (MAPLE_R, MAPLE_O, MAPLE_D)[(k + int(p[2] * 10)) % 3], scale=(1.25, 1.25, 0.55), seg=8, ring=5)
    for k in range(16):                                                # düşmüş yapraklar
        a = rng.uniform(0, _m.tau)
        d = rng.uniform(0.15, 0.40)
        cyl(0.025, 0.004, (d * _m.cos(a), d * _m.sin(a), 0.072), (MAPLE_R, MAPLE_O)[k % 2], seg=5)
    finish("jp_maple")


# --- DUVAR EŞYASI ---------------------------------------------------------------------------

def jp_lanterns():
    box((1.00, 0.06, 0.06), (0, -0.16, 0.98), DWOOD)
    for sx in (-1, 1):
        box((0.06, 0.16, 0.06), (sx * 0.47, -0.08, 0.98), DWOOD)
        prism([(0.0, 0.95), (-0.13, 0.95), (0.0, 0.80)], 0.04, 'yz', DWOOD, offset=sx * 0.47)
        box((0.10, 0.02, 0.24), (sx * 0.47, -0.01, 0.88), DWOOD)
        rod((sx * 0.27, -0.16, 0.95), (sx * 0.27, -0.16, 0.83), 0.005, BLACK, seg=4)
        chochin(sx * 0.27, -0.20, 0.38, r=0.17, h=0.42)
    finish("jp_lanterns")


def jp_noren():
    rod((-0.55, -0.05, 1.02), (0.55, -0.05, 1.02), 0.016, DWOOD, seg=8)
    for sx in (-1, 1):
        box((0.04, 0.06, 0.06), (sx * 0.50, -0.025, 1.02), DWOOD)
        ball(0.02, (sx * 0.56, -0.05, 1.02), BLACK, seg=8, ring=5)
    for (x0, x1) in ((-0.48, -0.165), (-0.155, 0.155), (0.165, 0.48)):
        sheet_xz(lambda x, z: -0.07 + 0.006 * _m.sin(x * 25.0 + z * 3.0), x0, x1, 0.18, 0.99, 4, 6, INDIGO, t=0.006)
        for k in range(3):
            xx = x0 + (x1 - x0) * (k + 0.5) / 3
            torus(0.022, 0.006, (xx, -0.05, 1.0), INDIGO, rot=(0, R90, 0), seg=8, mseg=3)
        box((x1 - x0, 0.004, 0.03), ((x0 + x1) / 2, -0.081, 0.22), WHITE)
    o = torus(0.13, 0.016, (0, -0.082, 0.66), WHITE, rot=(R90, 0, 0), seg=28, mseg=3)
    o.scale = (1.0, 0.25, 1.0)
    for k in range(3):                                                 # beyaz dalga kıvrımları
        x = -0.06 + 0.06 * k
        o = torus(0.03, 0.006, (x, -0.082, 0.62 - 0.005 * k), WHITE, rot=(R90, 0, 0), seg=14, mseg=3)
        o.scale = (1.0, 0.25, 1.0)
    for x in (-0.32, 0.32):
        disc_front(0.03, x, -0.081, 0.40, WHITE, d=0.003, seg=12)
    finish("jp_noren")


def jp_scroll():
    rod((0.0, -0.012, 1.34), (-0.20, -0.02, 1.20), 0.003, BLACK, seg=4)
    rod((0.0, -0.012, 1.34), (0.20, -0.02, 1.20), 0.003, BLACK, seg=4)
    ball(0.012, (0.0, -0.012, 1.34), GOLD, seg=6, ring=4)
    cyl(0.012, 0.50, (0, -0.02, 1.19), DWOOD, rot=(0, R90, 0), seg=8)
    box((0.48, 0.008, 1.14), (0, -0.02, 0.62), BROCADE)
    box((0.38, 0.008, 0.84), (0, -0.026, 0.64), PAPER)
    for x in (-0.06, 0.06):                                            # fûtai şeritleri
        box((0.025, 0.004, 0.30), (x, -0.032, 1.03), GOLDLEAF)
    box((0.38, 0.004, 0.02), (0, -0.031, 1.05), GOLDLEAF)
    box((0.38, 0.004, 0.02), (0, -0.031, 0.23), GOLDLEAF)
    prism([(-0.17, 0.35), (0.17, 0.35), (0.04, 0.70), (-0.04, 0.70)], 0.003, 'xz', FUJI, offset=-0.031)
    prism([(-0.085, 0.585), (-0.05, 0.56), (-0.025, 0.59), (0.0, 0.55), (0.025, 0.59), (0.05, 0.56), (0.085, 0.585),
           (0.04, 0.70), (-0.04, 0.70)], 0.003, 'xz', WHITE, offset=-0.034)
    disc_front(0.06, 0.09, -0.032, 0.86, SUN, d=0.003, seg=20)
    for (x, z0, z1) in ((-0.13, 0.98, 0.80), (-0.10, 0.95, 0.84)):     # fırça vuruşları
        box((0.012, 0.003, z0 - z1), (x, -0.032, (z0 + z1) / 2), BLACK)
    box((0.03, 0.003, 0.03), (-0.115, -0.032, 0.76), SUN)              # mühür
    cyl(0.018, 0.56, (0, -0.02, 0.04), DWOOD, rot=(0, R90, 0), seg=10)
    for sx in (-1, 1):
        cyl(0.024, 0.03, (sx * 0.29, -0.02, 0.04), BLACK, rot=(0, R90, 0), seg=10)
    finish("jp_scroll")


def jp_neon_kanji():
    box((0.82, 0.03, 0.84), (0, -0.015, 0.42), BACK_N)
    for (x, z) in ((-0.36, 0.06), (0.36, 0.06), (-0.36, 0.78), (0.36, 0.78)):
        cyl(0.015, 0.04, (x, -0.04, z), STEEL, rot=(R90, 0, 0), seg=8)
    y = -0.05
    for (a, b) in (((-0.36, 0.05), (0.36, 0.05)), ((0.36, 0.05), (0.36, 0.79)), ((0.36, 0.79), (-0.36, 0.79)),
                   ((-0.36, 0.79), (-0.36, 0.05))):
        seg_xz(a, b, y, N_CYAN, t=0.02, d=0.02)
    t = 0.034
    for (a, b) in (((-0.17, 0.67), (0.17, 0.67)),                     # 車
                   ((-0.17, 0.58), (0.17, 0.58)), ((-0.17, 0.30), (0.17, 0.30)), ((-0.17, 0.44), (0.17, 0.44)),
                   ((-0.17, 0.58), (-0.17, 0.30)), ((0.17, 0.58), (0.17, 0.30)),
                   ((-0.27, 0.19), (0.27, 0.19)), ((0.0, 0.73), (0.0, 0.10))):
        seg_xz(a, b, y - 0.01, N_RED, t=t, d=0.03)
    finish("jp_neon_kanji")


def jp_fan():
    n, r0, r1 = 18, 0.13, 0.62
    a0, a1 = _m.radians(14), _m.radians(166)
    bm_paper = bmesh.new()
    bm_dark = bmesh.new()
    bm_blue = bmesh.new()
    for i in range(n):
        aa, ab = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        ya, yb = (-0.02, -0.045) if i % 2 == 0 else (-0.045, -0.02)
        for (bm, ra, rb, dy) in ((bm_paper if i % 2 == 0 else bm_dark, r0 + 0.06, r1, 0.0),
                                 (bm_blue, r1 - 0.10, r1 - 0.01, -0.004)):
            v = [bm.verts.new((ra * _m.cos(aa), ya + dy, ra * _m.sin(aa))),
                 bm.verts.new((rb * _m.cos(aa), ya + dy, rb * _m.sin(aa))),
                 bm.verts.new((rb * _m.cos(ab), yb + dy, rb * _m.sin(ab))),
                 bm.verts.new((ra * _m.cos(ab), yb + dy, ra * _m.sin(ab)))]
            bm.faces.new(v)
    for bm, m, name in ((bm_paper, PAPER, "yelpaze"), (bm_dark, PAPER_D, "yelpaze2"), (bm_blue, WAVE, "dalga")):
        solidify(_obj_from_bm(bm, name, m), 0.004)
    for i in range(n + 1):                                             # kaburgalar
        a = a0 + (a1 - a0) * i / n
        y = -0.02 if i % 2 == 0 else -0.045
        rr = r1 + 0.01 if i in (0, n) else r0 + 0.07
        rod((0.0, y + 0.006, 0.0), (rr * _m.cos(a), y + 0.006, rr * _m.sin(a)), 0.006, DWOOD, seg=4)
    disc_front(0.10, 0.0, -0.056, 0.40, SUN, d=0.004, seg=24)
    disc_front(0.022, 0.0, -0.05, 0.0, GOLD, d=0.01, seg=10)
    rod((0.0, -0.04, -0.01), (0.03, -0.04, -0.14), 0.004, RED, seg=4)    # püskül
    cone(0.02, 0.006, 0.08, (0.035, -0.04, -0.18), RED, rot=(_m.pi, 0, 0), seg=8)
    finish("jp_fan")


for build in (jp_kotatsu, jp_byobu, jp_andon, jp_maneki, jp_daruma, jp_taiko, jp_vending,
              jp_torii, jp_stone_lantern, jp_koi_pond, jp_zen_garden, jp_shishi_odoshi, jp_ramen_stall,
              jp_koinobori, jp_bamboo_fence, jp_maple,
              jp_lanterns, jp_noren, jp_scroll, jp_neon_kanji, jp_fan):
    build()
    clear()
print("v12 japon partisi tamam")
