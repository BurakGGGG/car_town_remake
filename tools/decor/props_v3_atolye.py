"""DEKORASYON v3 — ATÖLYE partisi: lastik sökme, balans, motor vinci, sütunlu matkap, arıza tespit...
Orijinal Car Town'un Misc sekmesindeki atölye eşyaları (lavabo, takoz) ve gerçek tamirhane ekipmanı.

Kurallar kit.py ile aynı: metre, ÖN = −Y, orijin tabanın ortası.
Kullanım: CT_DECOR_OUT=assets/decor python tools/decor/run_bpy.py tools/decor/props_v3_atolye.py
"""
import math as _m

R90 = _m.radians(90)
DARK = mat("Koyu", (0.045, 0.048, 0.055), 0.7)
STEEL = mat("Celik", (0.34, 0.35, 0.37), 0.4, 0.7)
CHROME = mat("Krom", (0.62, 0.64, 0.68), 0.14, 0.95)
RED = mat("Kirmizi", (0.52, 0.05, 0.04), 0.5)
BLUE = mat("Mavi", (0.05, 0.18, 0.50), 0.5)
YEL = mat("Sari", (0.72, 0.50, 0.04), 0.5)
ORANGE = mat("Turuncu", (0.70, 0.22, 0.03), 0.5)
GREEN = mat("Yesil", (0.06, 0.30, 0.14), 0.55)
WHITE = mat("Beyaz", (0.82, 0.81, 0.78), 0.55)
RUBBER = mat("Lastik", (0.03, 0.03, 0.035), 0.9)
SCREEN = mat("Ekran", (0.10, 0.35, 0.25), 0.3, emit=(0.10, 0.55, 0.30))
WOOD = mat("Ahsap", (0.30, 0.165, 0.07), 0.85)


def wheel(r, w, loc, rot=(R90, 0, 0), rim=CHROME):
    """Lastik + jant: ön yüz rot ile döner (varsayılan −Y'ye bakar)."""
    torus(r * 0.72, r * 0.28, loc, RUBBER, rot=rot, seg=18, mseg=7)
    cyl(r * 0.52, w * 0.8, loc, rim, rot=rot, seg=14)


# ---------------------------------------------------------------- 1) TEKER TAKOZLARI
clear()
for i in range(4):
    x = -0.45 + (i % 2) * 0.24 + (i // 2) * 0.55
    prism([(-0.12, 0.0), (0.12, 0.0), (0.04, 0.12), (-0.04, 0.12)], 0.18, 'yz', YEL if i % 2 else RED,
          offset=x)
    box((0.02, 0.20, 0.02), (x, 0, 0.13), DARK)
finish("wheel_chocks")

# ---------------------------------------------------------------- 2) YAĞ BOŞALTMA KABI
clear()
cyl(0.36, 0.14, (0, 0, 0.19), YEL, seg=18)
torus(0.36, 0.025, (0, 0, 0.26), YEL, seg=18, mseg=5)
cyl(0.33, 0.01, (0, 0, 0.26), mat("Yag", (0.04, 0.03, 0.01), 0.1), seg=18)
for i in range(3):
    a = _m.tau * i / 3.0
    cyl(0.025, 0.12, (_m.cos(a) * 0.28, _m.sin(a) * 0.28, 0.06), STEEL, seg=6)
    ball(0.035, (_m.cos(a) * 0.28, _m.sin(a) * 0.28, 0.035), RUBBER, seg=6, ring=4)
cyl(0.05, 0.75, (0.20, 0.10, 0.62), YEL, seg=10)                     # dikili huni borusu
cone(0.16, 0.05, 0.16, (0.20, 0.10, 1.06), YEL, seg=12)
finish("oil_drain")

# ---------------------------------------------------------------- 3) SÜRÜNGEÇ (mekanik yatağı)
clear()
box((0.48, 1.00, 0.04), (0, 0, 0.11), RED)
box((0.44, 0.94, 0.03), (0, 0, 0.14), DARK)                          # minder
box((0.36, 0.22, 0.05), (0, 0.38, 0.17), DARK)                       # başlık
for x in (-0.20, 0.20):
    for y in (-0.42, 0.0, 0.42):
        ball(0.04, (x, y, 0.045), RUBBER, seg=8, ring=5)
        cyl(0.02, 0.05, (x, y, 0.08), STEEL, seg=6)
finish("creeper")

# ---------------------------------------------------------------- 4) ATÖLYE LAVABOSU
clear()
for x in (-0.36, 0.36):
    for y in (-0.22, 0.22):
        box((0.04, 0.04, 0.82), (x, y, 0.41), STEEL)
box((0.82, 0.52, 0.04), (0, 0, 0.22), STEEL)                         # alt raf
box((0.86, 0.56, 0.24), (0, 0, 0.88), CHROME)                        # tekne
box((0.74, 0.44, 0.20), (0, 0, 0.92), mat("TekneIc", (0.30, 0.31, 0.33), 0.3, 0.8))
box((0.86, 0.06, 0.40), (0, 0.25, 1.20), CHROME)                     # arka sıçrama paneli
cyl(0.018, 0.30, (0, 0.18, 1.14), CHROME, seg=8)                     # musluk
cyl(0.018, 0.16, (0, 0.10, 1.29), CHROME, rot=(R90, 0, 0), seg=8)
for s in (-1, 1):
    cyl(0.03, 0.04, (s * 0.10, 0.18, 1.08), BLUE if s < 0 else RED, seg=8)
box((0.12, 0.08, 0.16), (0.30, 0.16, 1.10), mat("Sabun", (0.10, 0.45, 0.20), 0.5))
cyl(0.10, 0.36, (0.20, -0.05, 0.42), BLUE, seg=10)                   # kova
finish("utility_sink")

# ---------------------------------------------------------------- 5) AKÜ ŞARJ ARABASI
clear()
box((0.46, 0.34, 0.62), (0, 0, 0.45), RED)
box((0.40, 0.02, 0.18), (0, -0.175, 0.62), DARK)                     # gösterge paneli
cyl(0.06, 0.02, (-0.10, -0.19, 0.62), WHITE, rot=(R90, 0, 0), seg=14)
box((0.004, 0.006, 0.05), (-0.09, -0.20, 0.64), RED, rot=(0, _m.radians(30), 0))
cyl(0.03, 0.02, (0.10, -0.19, 0.62), DARK, rot=(R90, 0, 0), seg=10)
for s in (-1, 1):
    wheel(0.12, 0.06, (s * 0.26, 0.10, 0.12), rot=(0, R90, 0), rim=STEEL)
    box((0.04, 0.04, 0.26), (s * 0.20, -0.12, 0.13), STEEL)
cyl(0.015, 0.50, (0, 0.20, 0.90), STEEL, rot=(0, R90, 0), seg=6)     # sap
for s in (-1, 1):
    box((0.02, 0.02, 0.24), (s * 0.24, 0.20, 0.78), STEEL)
for s, m in ((-1, RED), (1, DARK)):                                  # maşalar
    cyl(0.012, 0.30, (s * 0.12, -0.20, 0.30), m, rot=(_m.radians(20), 0, 0), seg=6)
    box((0.05, 0.03, 0.08), (s * 0.12, -0.25, 0.14), m)
finish("battery_charger")

# ---------------------------------------------------------------- 6) LASTİK SÖKME MAKİNESİ
clear()
box((0.90, 0.80, 0.70), (0, 0, 0.35), BLUE)
box((0.80, 0.72, 0.04), (0, 0, 0.72), STEEL)
cyl(0.30, 0.06, (0, -0.05, 0.77), STEEL, seg=16)                     # döner tabla
for i in range(4):
    a = _m.tau * i / 4.0
    box((0.06, 0.06, 0.06), (_m.cos(a) * 0.26, -0.05 + _m.sin(a) * 0.26, 0.83), DARK)
wheel(0.34, 0.20, (0, -0.05, 0.94), rot=(0, 0, 0))                   # yatık lastik
box((0.14, 0.14, 1.20), (0, 0.36, 1.10), BLUE)                       # kule
box((0.50, 0.10, 0.10), (0, 0.18, 1.62), BLUE)                       # kol
cyl(0.03, 0.46, (0, 0.0, 1.38), CHROME, seg=8)                       # sökme demiri
box((0.10, 0.08, 0.08), (0, 0.0, 1.13), DARK)
for x in (-0.25, 0.0, 0.25):                                         # pedallar
    box((0.10, 0.18, 0.04), (x, -0.46, 0.04), DARK)
box((0.10, 0.12, 0.30), (0.50, 0.0, 0.85), STEEL)                    # boncuk kırıcı
finish("tire_changer")

# ---------------------------------------------------------------- 7) BALANS MAKİNESİ
clear()
box((0.70, 0.60, 0.80), (0, 0.10, 0.40), RED)
prism([(-0.30, 0.80), (0.30, 0.80), (0.30, 0.86), (-0.30, 1.04)], 0.70, 'yz', DARK, offset=0.0)
box((0.40, 0.02, 0.26), (0, 0.38, 1.18), DARK)                       # ekran kutusu
box((0.70, 0.30, 0.30), (0, 0.32, 1.06), DARK)
box((0.60, 0.02, 0.20), (0, 0.165, 1.08), SCREEN)
for k in range(3):
    box((0.12, 0.012, 0.06), (-0.18 + k * 0.18, 0.155, 1.10), mat("Rakam", (1.0, 0.4, 0.1), 0.3, emit=(1.0, 0.35, 0.05)))
cyl(0.04, 0.50, (0.55, 0.0, 0.58), CHROME, rot=(0, R90, 0), seg=10)  # mil
wheel(0.32, 0.20, (0.62, 0.0, 0.58), rot=(0, R90, 0))
box((0.70, 0.40, 0.30), (0.55, 0.0, 0.94), mat("Kapak", (0.52, 0.05, 0.04), 0.5), rot=(_m.radians(-70), 0, 0))
cyl(0.012, 0.40, (0.55, 0.0, 0.80), STEEL, rot=(0, R90, 0), seg=6)
finish("wheel_balancer")

# ---------------------------------------------------------------- 8) SÜTUNLU MATKAP
clear()
box((0.46, 0.40, 0.06), (0, 0, 0.03), GREEN)
cyl(0.045, 1.55, (0, 0.12, 0.81), CHROME, seg=10)                    # sütun
box((0.36, 0.30, 0.04), (0, -0.04, 0.82), GREEN)                     # tabla
box((0.08, 0.20, 0.08), (0, 0.06, 0.78), GREEN)
box((0.26, 0.48, 0.26), (0, 0.02, 1.48), GREEN)                      # kafa
cyl(0.10, 0.30, (0, 0.22, 1.66), GREEN, seg=12)                      # motor
cyl(0.02, 0.22, (0, -0.10, 1.26), CHROME, seg=8)                     # mandren
cone(0.01, 0.0, 0.06, (0, -0.10, 1.12), DARK, seg=6)
for i in range(3):                                                   # kollar
    a = _m.tau * i / 3.0
    cyl(0.01, 0.22, (0.16 + _m.cos(a) * 0.08, 0.02, 1.42 + _m.sin(a) * 0.08), CHROME,
        rot=(0, a + R90, 0), seg=6)
    ball(0.02, (0.16 + _m.cos(a) * 0.18, 0.02, 1.42 + _m.sin(a) * 0.18), RUBBER, seg=6, ring=4)
box((0.30, 0.04, 0.14), (0, -0.27, 1.48), YEL)                       # uyarı etiketi
finish("drill_press")

# ---------------------------------------------------------------- 9) MOTOR VİNCİ
clear()
for s in (-1, 1):                                                    # açık ayaklar
    box((0.08, 1.20, 0.08), (s * 0.34, -0.30, 0.10), RED)
    wheel(0.05, 0.04, (s * 0.34, -0.86, 0.05), rot=(0, R90, 0), rim=STEEL)
    wheel(0.05, 0.04, (s * 0.34, 0.24, 0.05), rot=(0, R90, 0), rim=STEEL)
box((0.76, 0.10, 0.08), (0, 0.28, 0.10), RED)
box((0.12, 0.12, 1.40), (0, 0.28, 0.80), RED)                        # direk
box((0.10, 1.30, 0.12), (0, -0.22, 1.56), RED, rot=(_m.radians(-12), 0, 0))   # bom
cyl(0.04, 0.70, (0, 0.10, 1.10), CHROME, rot=(_m.radians(35), 0, 0), seg=8)   # hidrolik piston
box((0.08, 0.08, 0.30), (0, 0.18, 0.80), DARK)
cyl(0.012, 0.40, (0, -0.83, 1.48), STEEL, seg=6)                     # zincir
box((0.08, 0.02, 0.08), (0, -0.83, 1.26), STEEL)
box((0.40, 0.34, 0.30), (0, -0.83, 1.05), mat("Motor", (0.18, 0.19, 0.22), 0.5, 0.5))   # asılı motor
box((0.36, 0.30, 0.04), (0, -0.83, 1.22), mat("Kapak", (0.52, 0.05, 0.04), 0.5))
cyl(0.015, 0.36, (0.10, 0.36, 0.62), STEEL, rot=(_m.radians(-40), 0, 0), seg=6)   # pompa kolu
finish("engine_hoist")

# ---------------------------------------------------------------- 10) ARIZA TESPİT ARABASI
clear()
box((0.62, 0.50, 0.80), (0, 0, 0.50), mat("Antrasit", (0.12, 0.13, 0.15), 0.4, 0.3))
for k in range(3):
    box((0.56, 0.02, 0.20), (0, -0.255, 0.26 + k * 0.23), DARK)
    box((0.16, 0.02, 0.025), (0, -0.27, 0.32 + k * 0.23), CHROME)
for x in (-0.25, 0.25):
    for y in (-0.19, 0.19):
        ball(0.05, (x, y, 0.05), RUBBER, seg=8, ring=5)
box((0.66, 0.54, 0.04), (0, 0, 0.92), RED)
box((0.06, 0.06, 0.62), (0, 0.18, 1.22), DARK)                       # monitör kolu
box((0.62, 0.05, 0.40), (0, 0.12, 1.55), DARK, rot=(_m.radians(-8), 0, 0))
box((0.56, 0.02, 0.34), (0, 0.09, 1.55), SCREEN, rot=(_m.radians(-8), 0, 0))
for k in range(5):                                                   # ekran grafiği çizgileri
    h = 0.05 + 0.18 * abs(_m.sin(k * 1.1 + 0.4))
    box((0.06, 0.012, h), (-0.20 + k * 0.10, 0.075, 1.43 + h / 2), mat("Grafik", (1.0, 0.75, 0.15), 0.3, emit=(1.0, 0.7, 0.1)))
box((0.44, 0.16, 0.02), (0, -0.12, 0.95), DARK)                      # klavye
cyl(0.018, 0.80, (0.36, -0.10, 0.70), mat("Kablo", (0.70, 0.40, 0.04), 0.6), rot=(_m.radians(25), 0, 0), seg=6)
box((0.10, 0.06, 0.14), (0.36, -0.28, 0.32), DARK)                   # OBD fişi
finish("diagnostic_cart")

# ---------------------------------------------------------------- 11) JANT YIĞINI
clear()
for i in range(4):                                                   # yatık jant kulesi
    z = 0.12 + i * 0.22
    cyl(0.26, 0.18, (-0.28, 0, z), STEEL, seg=12)                    # jant gövdesi (içe çekik)
    for dz in (-0.085, 0.085):
        torus(0.28, 0.025, (-0.28, 0, z + dz), CHROME, seg=14, mseg=4)   # jant dudakları
    cyl(0.10, 0.19, (-0.28, 0, z), DARK, seg=10)
for k in range(2):                                                   # dik duran iki jant, 5 kollu
    y = -0.18 + k * 0.30
    m = [mat("Bronz", (0.55, 0.36, 0.10), 0.25, 0.9), DARK][k]
    torus(0.27, 0.035, (0.30, y, 0.30), m, rot=(R90, 0, 0), seg=18, mseg=5)
    cyl(0.29, 0.18, (0.30, y + 0.02, 0.30), STEEL, rot=(R90, 0, 0), seg=16)
    cyl(0.06, 0.04, (0.30, y - 0.09, 0.30), m, rot=(R90, 0, 0), seg=10)
    for j in range(5):
        box((0.045, 0.02, 0.50), (0.30, y - 0.08, 0.30), m, rot=(0, _m.tau * j / 5.0, 0))
finish("rim_stack")

print("v3 atolye partisi tamam")
