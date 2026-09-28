"""AYDINLATMA + TABELA partisi."""
import math as _m
STEEL = mat("Celik", (0.30, 0.31, 0.33), 0.45, 0.6)
DARK = mat("Koyu", (0.055, 0.058, 0.065), 0.75)
WHITE = mat("Beyaz", (0.82, 0.80, 0.74), 0.6)
CREAM = mat("Krem", (0.78, 0.72, 0.58), 0.7)
GLOW = mat("Isik", (0.95, 0.88, 0.62), 0.2, 0.0, emit=(1.0, 0.92, 0.66))
NEON_P = mat("NeonPembe", (0.85, 0.12, 0.42), 0.2, 0.0, emit=(1.0, 0.25, 0.55))
NEON_B = mat("NeonMavi", (0.10, 0.62, 0.88), 0.2, 0.0, emit=(0.22, 0.80, 1.0))
RED = mat("Kirmizi", (0.52, 0.055, 0.045), 0.6)

# 1) Projektör direği
clear()
box((0.36, 0.36, 0.08), (0, 0, 0.04), DARK)
cyl(0.055, 3.10, (0, 0, 1.59), STEEL, seg=8)
box((0.70, 0.12, 0.10), (0, 0, 3.16), STEEL)
for i in range(2):
    box((0.26, 0.20, 0.22), (-0.22 + i * 0.44, 0.05, 3.04), DARK, rot=(_m.radians(24), 0, 0))
    box((0.22, 0.03, 0.18), (-0.22 + i * 0.44, 0.14, 2.99), GLOW, rot=(_m.radians(24), 0, 0))
finish("floodlight")

# 2) Işık dizisi (iki direk arası)
clear()
for s in range(2):
    x = (1 if s else -1) * 1.30
    cyl(0.10, 0.06, (x, 0, 0.03), DARK, seg=10)
    cyl(0.035, 2.40, (x, 0, 1.22), STEEL, seg=8)
for i in range(9):
    t = i / 8.0
    x = -1.26 + t * 2.52
    sag = _m.sin(t * _m.pi) * 0.22
    cyl(0.012, 0.07, (x, 0, 2.36 - sag), DARK, seg=6)
    ball(0.055, (x, 0, 2.30 - sag), GLOW, seg=7, ring=4)
finish("string_lights")

# 3) Yön oku tabelası
clear()
cyl(0.11, 0.06, (0, 0, 0.03), DARK, seg=10)
cyl(0.035, 1.35, (0, 0, 0.70), STEEL, seg=8)
box((0.70, 0.04, 0.22), (0.10, 0, 1.44), mat("OkGovde", (0.58, 0.40, 0.03), 0.6))
cone(0.20, 0.0, 0.26, (0.53, 0, 1.44), mat("OkUc", (0.58, 0.40, 0.03), 0.6),
     rot=(0, _m.radians(90), 0), seg=3)
finish("arrow_sign")

# 4) Garaj tabelası (direkli, yazılı pano)
clear()
for s in range(2):
    x = (1 if s else -1) * 0.85
    box((0.14, 0.14, 2.30), (x, 0, 1.15), STEEL)
box((2.10, 0.10, 0.85), (0, 0, 2.60), CREAM)
box((2.16, 0.06, 0.09), (0, 0.02, 2.99), RED)
box((2.16, 0.06, 0.09), (0, 0.02, 2.21), RED)
for i in range(5):
    box((0.22, 0.05, 0.34), (-0.72 + i * 0.36, 0.06, 2.58), DARK)
finish("garage_sign")

# 5) Neon "GARAJ" tabelası (duvar) — kodla üretilenin yerine geçer
clear()
box((1.80, 0.10, 0.78), (0, 0, 0.39), DARK)
box((1.66, 0.04, 0.64), (0, -0.06, 0.39), mat("NeonZemin", (0.06, 0.03, 0.08), 0.4))
# G A R A J: her harf dikey çubuk + karakteristik kollar
letters = [
    [(-0.62, 0.20, 0.03, 0.44), (-0.72, 0.42, 0.22, 0.03), (-0.52, 0.0, 0.03, 0.20)],
    [(-0.26, 0.20, 0.03, 0.44), (-0.06, 0.20, 0.03, 0.44), (-0.16, 0.22, 0.22, 0.03)],
    [(0.16, 0.20, 0.03, 0.44), (0.30, 0.34, 0.03, 0.18), (0.24, 0.42, 0.18, 0.03),
     (0.30, 0.08, 0.03, 0.20)],
    [(0.56, 0.20, 0.03, 0.44), (0.76, 0.20, 0.03, 0.44), (0.66, 0.22, 0.22, 0.03)],
    [(1.06, 0.26, 0.03, 0.34), (0.94, 0.06, 0.03, 0.14), (1.00, 0.0, 0.14, 0.03)],
]
for li, parts in enumerate(letters):
    color = NEON_P if li % 2 == 0 else NEON_B
    for (lx, lz, sx, sz) in parts:
        box((sx, 0.03, sz), (lx - 0.22, -0.10, lz), color)
finish("neon_garage")

# 6) Duvar saati
clear()
cyl(0.24, 0.06, (0, 0, 0.0), DARK, rot=(_m.radians(90), 0, 0), seg=16)
cyl(0.21, 0.02, (0, -0.04, 0.0), WHITE, rot=(_m.radians(90), 0, 0), seg=16)
box((0.02, 0.02, 0.15), (0, -0.06, 0.05), DARK)
box((0.11, 0.02, 0.02), (0.05, -0.06, 0.0), DARK)
finish("wall_clock")

# 7) Poster (duvar)
clear()
box((0.62, 0.03, 0.86), (0, 0, 0.0), mat("PosterCer", (0.10, 0.10, 0.12), 0.6))
box((0.56, 0.02, 0.80), (0, -0.02, 0.0), mat("PosterYuz", (0.52, 0.16, 0.10), 0.5))
box((0.40, 0.01, 0.20), (0, -0.03, 0.22), CREAM)
box((0.34, 0.01, 0.10), (0, -0.03, -0.20), mat("PosterYazi", (0.85, 0.78, 0.30), 0.5))
finish("wall_poster")

print("isik + tabela partisi tamam")
