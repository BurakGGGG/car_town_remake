#!/usr/bin/env python3
"""DETAYLI ÇERÇEVE HALKALARI (2026-11-01, kullanıcı: "biraz daha detaylı ve güzel yap"): 15 yeni çerçevenin halkası
SVG'de çizilir (degrade, eğim, malzeme dokusu, parlaklık) → rings_src/<kimlik>.svg → render_avatars.gd ile
assets/ui/frames/ring_<kimlik>.png (mipmap'li içe aktarılır; dosya adı rings_src/ring_<kimlik>.svg). Hareketli kısımlar (gösterge ibresi, krom parıltısı,
alevler) AvatarView'da kodla bunun üstüne çizilir.

Tuval 512: halkanın DIŞ yarıçapı R = 254 (tuvali doldurur), İÇ yarıçapı RI = 212 → kalınlık çapın ~%8'i
(ProfileCatalog.RING_INNER = RI / 256). AvatarView dokuyu dairenin tam karesine çizer.
Çalıştır: python3 tools/avatars/make_rings.py
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rings_src")
C = 256
R = 254
RI = 212
MID = (R + RI) / 2


def pol(r, a):
    return C + r * math.cos(a), C + r * math.sin(a)


def circ(r, fill="none", stroke=None, width=1, extra=""):
    s = f'<circle cx="{C}" cy="{C}" r="{r:.2f}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width:.2f}"'
    return s + (f" {extra}" if extra else "") + "/>"


def dot(x, y, r, fill, extra=""):
    return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.2f}" fill="{fill}" {extra}/>'


def path(d, fill="none", stroke=None, width=1, extra=""):
    s = f'<path d="{d}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width:.2f}" stroke-linecap="round" stroke-linejoin="round"'
    return s + (f" {extra}" if extra else "") + "/>"


def arc_path(r, a0, a1):
    x0, y0 = pol(r, a0)
    x1, y1 = pol(r, a1)
    large = 1 if (a1 - a0) % (2 * math.pi) > math.pi else 0
    return f"M {x0:.1f} {y0:.1f} A {r:.1f} {r:.1f} 0 {large} 1 {x1:.1f} {y1:.1f}"


def sector(r0, r1, a0, a1, steps=6):
    """Halka dilimi (iç / dış yarıçap, açı aralığı) çokgeni."""
    pts = [pol(r1, a0 + (a1 - a0) * k / steps) for k in range(steps + 1)]
    pts += [pol(r0, a1 - (a1 - a0) * k / steps) for k in range(steps + 1)]
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"


ANN = (f"M {C} {C - R} A {R} {R} 0 1 1 {C - 0.01} {C - R} Z "
       f"M {C} {C - RI} A {RI} {RI} 0 1 0 {C + 0.01} {C - RI} Z")


def tube(gid, edge, mid, light=None):
    """Silindir gibi gölgelenmiş halka: kenarlar koyu, ortası açık (radyal degrade)."""
    a, b = RI / R, MID / R
    stops = [(a, edge), (a + (b - a) * 0.55, mid), (b, light or mid), (1 - (1 - b) * 0.45, mid), (1.0, edge)]
    s = "".join(f'<stop offset="{o:.3f}" stop-color="{c}"/>' for o, c in stops)
    return f'<radialGradient id="{gid}" cx="{C}" cy="{C}" r="{R}" gradientUnits="userSpaceOnUse">{s}</radialGradient>'


COMMON_DEFS = [
    f'<clipPath id="ann"><path d="{ANN}" clip-rule="evenodd"/></clipPath>',
    # üstten ışık: üst yarı parlak, alt yarı hafif koyu (bütün halkanın üstüne)
    '<linearGradient id="toplight" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
    '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.38"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/>'
    '<stop offset="0.6" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.28"/></linearGradient>',
    # dış kenarın üstünde ince parlak çizgi, iç kenarın üstünde gölge
    '<linearGradient id="rim" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
    '<stop offset="0" stop-color="#FFFFFF" stop-opacity="0.9"/><stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>',
    '<linearGradient id="innershade" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
    '<stop offset="0" stop-color="#000000" stop-opacity="0.55"/><stop offset="0.55" stop-color="#000000" stop-opacity="0"/></linearGradient>',
]


def finish(edge_color, light=True):
    """Ortak bitiş: üstten ışık, kenar parıltısı, iç gölge, ince kenar çizgileri."""
    o = []
    if light:
        o.append(f'<path d="{ANN}" fill="url(#toplight)" fill-rule="evenodd"/>')
    o += [circ(R - 4, stroke="url(#rim)", width=3.5),
          circ(RI + 4, stroke="url(#innershade)", width=6),
          circ(R - 1.2, stroke=edge_color, width=2.4),
          circ(RI + 1.2, stroke=edge_color, width=2.4)]
    return o


def save(name, defs, body):
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
           f'  <!-- ÇERÇEVE HALKASI {name} (tools/avatars/make_rings.py üretir, elle düzenleme) -->\n'
           "  <defs>" + "".join(COMMON_DEFS + defs) + "</defs>\n  " + "\n  ".join(body) + "\n</svg>\n")
    with open(os.path.join(OUT, "ring_" + name + ".svg"), "w") as f:
        f.write(svg)


def clipped(items):
    return ['<g clip-path="url(#ann)">'] + items + ["</g>"]


def rivet(x, y, r, base, light, dark):
    gid = f"rv{int(x)}_{int(y)}"
    return [f'<radialGradient id="{gid}" cx="{x - r * 0.35:.1f}" cy="{y - r * 0.35:.1f}" r="{r * 1.3:.1f}" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{light}"/><stop offset="0.6" stop-color="{base}"/><stop offset="1" stop-color="{dark}"/></radialGradient>',
            dot(x + r * 0.15, y + r * 0.25, r, "#000000", 'opacity="0.35"'),
            dot(x, y, r, f"url(#{gid})", f'stroke="{dark}" stroke-width="1.2"')]


def split_defs(items):
    defs = [i for i in items if i.startswith("<radialGradient") or i.startswith("<linearGradient")]
    rest = [i for i in items if i not in defs]
    return defs, rest


# --- 1. İKAZ BANDI -----------------------------------------------------------------------------------

def hazard():
    defs = [tube("base", "#C8961A", "#FFD84A", "#FFE68A")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    n = 20
    shear = 0.16
    stripes = []
    for i in range(n):
        a = 2 * math.pi * i / n
        span = 2 * math.pi / n * 0.46
        pts = [pol(RI - 2, a), pol(RI - 2, a + span), pol(R + 2, a + span + shear), pol(R + 2, a + shear)]
        stripes.append(path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z", "#1C1D21"))
    rnd = random.Random(3)
    scratches = []
    for _ in range(26):   # aşınma: kısa açık çizikler
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(RI + 6, R - 6)
        scratches.append(path(arc_path(r, a, a + rnd.uniform(0.02, 0.07)), stroke="#FFF4C8", width=1.2, extra='opacity="0.55"'))
    body += clipped(stripes + scratches)
    rv = []
    for k in range(4):
        x, y = pol(MID, math.pi / 4 + k * math.pi / 2)
        rv += rivet(x, y, 7, "#B8C0CA", "#FFFFFF", "#5E6670")
    d2, r2 = split_defs(rv)
    save("hazard", defs + d2, body + r2 + finish("#3A2C08"))


# --- 2. LASTİK -----------------------------------------------------------------------------------------

def tire():
    defs = [tube("base", "#121316", "#33363C", "#454950")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    items = []
    n = 34
    for i in range(n):   # sırt dişleri: dış bantta zikzak bloklar, üst yüzü açık
        a = 2 * math.pi * i / n
        span = 2 * math.pi / n * 0.56
        off = 3 if i % 2 == 0 else -3
        r0, r1 = 233 + off, R + 1
        items.append(path(sector(r0, r1, a, a + span, 3), "#3F434A", "#0E0F11", 1.6))
        items.append(path(sector(r1 - 6, r1, a + span * 0.1, a + span * 0.9, 3), "#5A5F68"))
        items.append(path(arc_path(r0 + 1, a + span * 0.05, a + span * 0.95), stroke="#16171A", width=2))
    for r in (219, 227):   # yanak çizgileri
        items.append(circ(r, stroke="#25272C", width=2.2))
        items.append(circ(r - 1.5, stroke="#4A4E56", width=0.9, extra='opacity="0.6"'))
    rnd = random.Random(8)
    for k in range(12):   # yanak yazısı gibi kısa kabartmalar
        a = 2 * math.pi * k / 12 + 0.12
        for j in range(4):
            aa = a + j * 0.028
            items.append(path(f"M {pol(214.5, aa)[0]:.1f} {pol(214.5, aa)[1]:.1f} L {pol(224, aa)[0]:.1f} {pol(224, aa)[1]:.1f}",
                              stroke="#5A5F68", width=2.4 if rnd.random() < 0.7 else 1.4, extra='opacity="0.55"'))
    body += clipped(items)
    body.append(path(arc_path(MID + 8, math.pi * 1.08, math.pi * 1.42), stroke="#FFFFFF", width=6, extra='opacity="0.18"'))
    save("tire", defs, body + finish("#08090A", light=False))


# --- 3. DİREKSİYON -------------------------------------------------------------------------------------

def wheel():
    defs = [tube("base", "#16181C", "#353941", "#4A4F58"),
            '<linearGradient id="redg" x1="0" y1="0" x2="0" y2="60" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#FF7A6A"/><stop offset="1" stop-color="#B82A20"/></linearGradient>']
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    items = []
    for a0 in (math.pi * 1.2, math.pi * 1.8):   # başparmak tutamakları: kabartma
        items.append(path(sector(RI - 1, R + 1, a0 - 0.22, a0 + 0.22, 10), "#3E434C"))
        for k in range(7):
            aa = a0 - 0.18 + k * 0.06
            items.append(path(f"M {pol(RI + 3, aa)[0]:.1f} {pol(RI + 3, aa)[1]:.1f} L {pol(R - 3, aa)[0]:.1f} {pol(R - 3, aa)[1]:.1f}",
                              stroke="#22252B", width=2.2))
    for ri, step in ((223, 0.034), (233, 0.031), (243, 0.029)):   # delikli deri
        k = 0
        a = 0.0
        while a < 2 * math.pi:
            x, y = pol(ri, a + (step / 2 if k % 2 else 0))
            items.append(dot(x, y, 1.7, "#121417"))
            a += step
            k += 1
    items.append(circ(216.5, stroke="#C3CAD4", width=2, extra='stroke-dasharray="5 4"'))   # dikişler
    items.append(circ(249.5, stroke="#C3CAD4", width=2, extra='stroke-dasharray="5 4"'))
    items.append(path(sector(RI - 1, R + 1, -math.pi / 2 - 0.09, -math.pi / 2 + 0.09, 4), "url(#redg)", "#6E140C", 1.6))
    items.append(path(arc_path(R - 8, -math.pi / 2 - 0.07, -math.pi / 2 + 0.07), stroke="#FFC2B8", width=3, extra='opacity="0.8"'))
    body += clipped(items)
    body.append(circ(RI + 2.5, stroke="#C9D1DA", width=3))   # iç krom kenar
    save("wheel", defs, body + finish("#0A0B0D"))


# --- 4. YARIŞ ŞERİDİ -----------------------------------------------------------------------------------

def stripe():
    defs = [tube("base", "#0A2E6E", "#1A58C0", "#3A7CE8")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    for r in (225.5, 240.5):   # ince beyaz şeritler: küçük boyda mavi baskın kalsın (geniş şerit soluk gösteriyordu)
        body += [circ(r, stroke="#06204A", width=7), circ(r, stroke="#FFFFFF", width=4.5)]
    body.append(circ(MID, stroke="#FF8A1C", width=2.4))   # ortada ince turuncu şerit
    body.append(path(arc_path(MID, math.pi * 1.06, math.pi * 1.62), stroke="#FFFFFF", width=14, extra='opacity="0.28"'))
    body.append(path(arc_path(MID + 4, math.pi * 1.14, math.pi * 1.36), stroke="#FFFFFF", width=4, extra='opacity="0.7"'))
    save("stripe", defs, body + finish("#06204A"))


# --- 5. GÖSTERGE (ibre kodla, hareketli) ---------------------------------------------------------------

def gauge():
    defs = [tube("face", "#08090B", "#1C1F24", "#262A30"),
            '<linearGradient id="chrome" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.3" stop-color="#9AA4B0"/><stop offset="0.5" stop-color="#F0F4F7"/>'
            '<stop offset="0.75" stop-color="#5E6670"/><stop offset="1" stop-color="#C9D1DA"/></linearGradient>']
    body = [f'<path d="{ANN}" fill="url(#face)" fill-rule="evenodd"/>',
            circ(R - 5, stroke="url(#chrome)", width=10), circ(R - 10.5, stroke="#05060A", width=1.5)]
    start, sweep = math.pi * 0.75, math.pi * 1.5
    body.append(path(arc_path(236, start + sweep * 0.8, start + sweep), stroke="#E2483D", width=7))
    for i in range(41):
        a = start + sweep * i / 40
        long = i % 5 == 0
        col = "#FF6A55" if i >= 32 else "#EEF2F5"
        x0, y0 = pol(240, a)
        x1, y1 = pol(240 - (17 if long else 9), a)
        body.append(path(f"M {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f}", stroke=col, width=3.2 if long else 1.8))
    for i in range(0, 41, 10):   # büyük çentiklerin dibinde nokta
        x, y = pol(219, start + sweep * i / 40)
        body.append(dot(x, y, 2.4, "#FF6A55" if i >= 32 else "#C9D1DA"))
    body.append(path(arc_path(MID, math.pi * 1.1, math.pi * 1.45), stroke="#FFFFFF", width=16, extra='opacity="0.12"'))   # cam yansıması
    save("gauge", defs, body + finish("#000000", light=False))


# --- 6. AHŞAP --------------------------------------------------------------------------------------------

def wood():
    defs = [tube("base", "#5A3318", "#8E5530", "#A86A3C")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    rnd = random.Random(21)
    items = []
    for i in range(46):   # damarlar: dalgalı ince yaylar
        r = rnd.uniform(RI + 2, R - 2)
        a0 = rnd.uniform(0, 2 * math.pi)
        length = rnd.uniform(0.5, 2.2)
        amp = rnd.uniform(0.6, 2.4)
        freq = rnd.uniform(6, 14)
        pts = []
        for k in range(40):
            a = a0 + length * k / 39
            pts.append(pol(r + amp * math.sin(a * freq), a))
        col = rnd.choice(["#4A2812", "#5E3418", "#B8824C", "#C99460", "#6E3E1C"])
        items.append(path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts), stroke=col,
                          width=rnd.uniform(0.9, 2.6), extra=f'opacity="{rnd.uniform(0.55, 0.95):.2f}"'))
    for a in (1.1, 4.0):   # budaklar
        x, y = pol(MID + 2, a)
        for k, (rx, col) in enumerate(((11, "#4A2812"), (8, "#7A4A26"), (5, "#4A2812"), (2.5, "#A06A3A"))):
            items.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx}" ry="{rx * 0.6:.1f}" fill="{col}" '
                         f'transform="rotate({math.degrees(a) + 90:.0f} {x:.1f} {y:.1f})"/>')
    body += clipped(items)
    body += [circ(RI + 5, stroke="#D9A84A", width=2.4), circ(R - 5, stroke="#D9A84A", width=2.4)]   # pirinç kakma
    body.append(path(arc_path(MID, math.pi * 1.08, math.pi * 1.7), stroke="#FFF2DC", width=10, extra='opacity="0.25"'))
    save("wood", defs, body + finish("#2E1808"))


# --- 7. PAS ---------------------------------------------------------------------------------------------

def rust():
    defs = [tube("base", "#5E2C12", "#9A4E24", "#B05A2A")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    rnd = random.Random(11)
    items = []
    for _ in range(140):   # pas lekeleri
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(RI, R)
        x, y = pol(r, a)
        col = rnd.choice(["#C46A2C", "#E08A3A", "#5A2810", "#8E4A22", "#D97A34", "#F2A65A"])
        items.append(dot(x, y, rnd.uniform(1.5, 7), col, f'opacity="{rnd.uniform(0.5, 0.95):.2f}"'))
    for _ in range(5):   # kalmış eski boya (camgöbeği), kenarı kırık
        a = rnd.uniform(0, 2 * math.pi)
        pts = []
        for k in range(12):
            aa = a + 0.18 * k / 11
            pts.append(pol(rnd.uniform(MID + 2, R - 3), aa))
        for k in range(12):
            aa = a + 0.18 * (11 - k) / 11
            pts.append(pol(rnd.uniform(RI + 3, MID - 2), aa))
        items.append(path("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z", "#3E7A78", "#24504E", 1.2))
    for _ in range(70):   # oyuklar
        x, y = pol(rnd.uniform(RI + 2, R - 2), rnd.uniform(0, 2 * math.pi))
        items.append(dot(x, y, rnd.uniform(0.8, 1.8), "#3A1A08"))
    body += clipped(items)
    rv = []
    for k in range(8):
        x, y = pol(MID, 2 * math.pi * k / 8 + 0.2)
        rv += rivet(x, y, 6.5, "#8E4A22", "#E8A060", "#3A1A08")
    d2, r2 = split_defs(rv)
    save("rust", defs + d2, body + r2 + finish("#2A1004"))


# --- 8. BAKIR -------------------------------------------------------------------------------------------

def copper():
    defs = [tube("base", "#7A3A1A", "#D07A44", "#F7B98A")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    rnd = random.Random(5)
    items = []
    for _ in range(90):   # dövme izleri: açık / koyu nokta çiftleri
        x, y = pol(rnd.uniform(RI + 4, R - 4), rnd.uniform(0, 2 * math.pi))
        rr = rnd.uniform(2.5, 5)
        items.append(dot(x + 1, y + 1, rr, "#8A4422", 'opacity="0.35"'))
        items.append(dot(x - 0.6, y - 0.6, rr * 0.7, "#FFD2AE", 'opacity="0.35"'))
    for _ in range(8):   # pas yeşili (patina) lekeleri ve akıntıları
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(RI + 8, R - 8)
        x, y = pol(r, a)
        for k in range(7):
            items.append(dot(x + rnd.uniform(-9, 9), y + rnd.uniform(-9, 9), rnd.uniform(3, 8), rnd.choice(["#4FAF8F", "#3E9A7C", "#7FD3B5"]),
                             f'opacity="{rnd.uniform(0.6, 0.95):.2f}"'))
        items.append(path(f"M {x:.1f} {y:.1f} L {x + rnd.uniform(-2, 2):.1f} {y + rnd.uniform(10, 18):.1f}", stroke="#4FAF8F", width=3, extra='opacity="0.7"'))
    body += clipped(items)
    rv = []
    for k in range(6):
        x, y = pol(MID, 2 * math.pi * k / 6 + 0.5)
        rv += rivet(x, y, 6, "#B8693A", "#FFD2AE", "#5E2C12")
    d2, r2 = split_defs(rv)
    body.append(path(arc_path(MID, math.pi * 1.1, math.pi * 1.55), stroke="#FFFFFF", width=10, extra='opacity="0.3"'))
    save("copper", defs + d2, body + r2 + finish("#4A200A"))


# --- 9. KROM (parıltı kodla, hareketli) -----------------------------------------------------------------

def chrome():
    defs = ['<linearGradient id="refl" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.18" stop-color="#C9D3DE"/><stop offset="0.34" stop-color="#6E7884"/>'
            '<stop offset="0.48" stop-color="#F4F8FB"/><stop offset="0.6" stop-color="#8A949F"/><stop offset="0.78" stop-color="#3E4650"/>'
            '<stop offset="0.9" stop-color="#B8C2CC"/><stop offset="1" stop-color="#F0F4F7"/></linearGradient>',
            tube("shade", "#000000", "#FFFFFF", "#FFFFFF")]
    body = [f'<path d="{ANN}" fill="url(#refl)" fill-rule="evenodd"/>',
            f'<path d="{ANN}" fill="url(#shade)" fill-rule="evenodd" opacity="0.18"/>',
            circ(MID + 9, stroke="#FFFFFF", width=2, extra='opacity="0.7"'),
            circ(MID - 9, stroke="#3E4650", width=1.5, extra='opacity="0.6"'),
            path(arc_path(MID, math.pi * 1.12, math.pi * 1.3), stroke="#FFFFFF", width=8, extra='opacity="0.9"')]
    save("chrome", defs, body + finish("#2E343C", light=False))


# --- 10. KADİFE -----------------------------------------------------------------------------------------

def velvet():
    defs = [tube("base", "#3A0612", "#7E1434", "#9E2448"),
            '<linearGradient id="gold" x1="0" y1="0" x2="1" y2="1">'
            '<stop offset="0" stop-color="#FFF0B0"/><stop offset="0.5" stop-color="#E8B23A"/><stop offset="1" stop-color="#8A5F0A"/></linearGradient>']
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    rnd = random.Random(2)
    items = []
    for _ in range(260):   # kadife havı: çok kısa açık / koyu çizgiler
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(RI + 2, 236)
        x0, y0 = pol(r, a)
        x1, y1 = pol(r + 2.5, a + 0.004)
        items.append(path(f"M {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f}", stroke=rnd.choice(["#B0305A", "#5A0A20"]), width=1, extra='opacity="0.5"'))
    items.append(path(arc_path(226, math.pi * 1.05, math.pi * 1.75), stroke="#E06088", width=12, extra='opacity="0.22"'))
    body += clipped(items)
    n = 56   # burgulu altın kordon (dış kenar)
    for i in range(n):
        a = 2 * math.pi * i / n
        x0, y0 = pol(239, a)
        x1, y1 = pol(R - 2, a + 2 * math.pi / n * 1.1)
        body.append(path(f"M {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f}", stroke="#5A3A06", width=7.5))
        body.append(path(f"M {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f}", stroke="#E8B23A" if i % 2 == 0 else "#C8901E", width=5.5))
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        body.append(dot(mx - 0.8, my - 0.8, 1.4, "#FFF0B0"))
    body += [circ(RI + 4, stroke="#5A3A06", width=5), circ(RI + 4, stroke="#E8B23A", width=3), circ(RI + 3.2, stroke="#FFF0B0", width=0.8)]
    save("velvet", defs, body + finish("#24030A", light=False))


# --- PRESTİJ HALKALARI ----------------------------------------------------------------------------------

def gold_ring(name, gems):
    defs = [tube("base", "#8A5A0C", "#E8B23A", "#FFF0A8")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    items = []
    n = 24   # oyma: karşılıklı kıvrımlar
    for i in range(n):
        a = 2 * math.pi * i / n
        x0, y0 = pol(MID, a)
        x1, y1 = pol(MID, a + 2 * math.pi / n)
        cx, cy = pol(MID + (8 if i % 2 == 0 else -8), a + math.pi / n)
        items.append(path(f"M {x0:.1f} {y0:.1f} Q {cx:.1f} {cy:.1f} {x1:.1f} {y1:.1f}", stroke="#9A6A10", width=2.2))
        items.append(dot(*pol(MID + (4 if i % 2 == 0 else -4), a + math.pi / n), 1.8, "#FFF4C8"))
    items += [circ(RI + 7, stroke="#9A6A10", width=1.5), circ(R - 7, stroke="#9A6A10", width=1.5)]
    body += clipped(items)
    for k in range(gems):
        a = -math.pi / 2 + 2 * math.pi * k / gems
        x, y = pol(MID, a)
        col, light = (("#D8283A", "#FF9AA4") if k % 2 == 0 else ("#2F62C0", "#A8C8FF"))
        body += [dot(x, y, 10.5, "#8A5A0C"), dot(x, y, 9, "#FFE08A"),
                 path(f"M {x} {y - 7} L {x + 6} {y} L {x} {y + 7} L {x - 6} {y} Z", col, "#3A1A0A", 1.2),
                 path(f"M {x} {y - 7} L {x + 6} {y} L {x} {y} Z", light, extra='opacity="0.8"')]
    save(name, defs, body + finish("#5A3A06"))


def laurel_ring():
    defs = [tube("base", "#7A5208", "#D9A520", "#FFE68A")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    items = []
    n = 36   # oyma defne yaprakları
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = pol(MID, a)
        items.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="7" ry="3" fill="none" stroke="#8A5F0A" stroke-width="1.6" '
                     f'transform="rotate({math.degrees(a) + 90 + 35:.0f} {x:.1f} {y:.1f})"/>')
    body += clipped(items)
    save("laurel", defs, body + finish("#5A3A06"))


def winged_ring():
    defs = [tube("rub", "#0E0F11", "#2E3136", "#40444B"),
            '<linearGradient id="rim_c" x1="0" y1="0" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#FFFFFF"/><stop offset="0.35" stop-color="#8E98A4"/><stop offset="0.55" stop-color="#EEF2F6"/>'
            '<stop offset="0.8" stop-color="#5E6670"/><stop offset="1" stop-color="#C9D1DA"/></linearGradient>']
    body = [f'<path d="{ANN}" fill="url(#rub)" fill-rule="evenodd"/>',
            circ(221, stroke="url(#rim_c)", width=18), circ(230.5, stroke="#14161A", width=1.6), circ(212.5, stroke="#3E4650", width=1.6)]
    for k in range(10):   # bijon somunları
        x, y = pol(221, 2 * math.pi * k / 10)
        body += [dot(x, y, 3.6, "#5E6670"), dot(x - 0.8, y - 0.8, 1.6, "#FFFFFF")]
    for i in range(36):   # lastik dişi çentikleri
        a = 2 * math.pi * i / 36
        body.append(path(f"M {pol(240, a)[0]:.1f} {pol(240, a)[1]:.1f} L {pol(R - 1, a + 0.03)[0]:.1f} {pol(R - 1, a + 0.03)[1]:.1f}",
                         stroke="#08090A", width=3))
    body.append(path(arc_path(244, math.pi * 1.1, math.pi * 1.45), stroke="#FFFFFF", width=5, extra='opacity="0.2"'))
    save("winged", defs, body + finish("#06070A", light=False))


def ember_ring():
    defs = [tube("base", "#2A0602", "#6E1206", "#8A1A08")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    rnd = random.Random(17)
    items = []
    for _ in range(14):   # kor çatlakları: zikzak, dışı turuncu içi sarı
        a = rnd.uniform(0, 2 * math.pi)
        pts = []
        r = rnd.uniform(RI + 4, R - 4)
        for k in range(7):
            pts.append(pol(r + rnd.uniform(-8, 8), a + k * 0.035))
        d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts)
        items += [path(d, stroke="#FF5A1C", width=5, extra='opacity="0.7"'), path(d, stroke="#FFD24A", width=1.8)]
    items.append(circ(RI + 6, stroke="#FF8A1C", width=6, extra='opacity="0.35"'))   # içten kızıl parıltı
    body += clipped(items)
    save("flame_cup", defs, body + finish("#1A0300"))


def diamond_ring():
    defs = [tube("base", "#6E8296", "#D8E6F0", "#FFFFFF")]
    body = [f'<path d="{ANN}" fill="url(#base)" fill-rule="evenodd"/>']
    n = 30   # pavé pırlantalar
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = pol(MID, a)
        s = 7.2
        rot = math.degrees(a) + 45
        body.append(f'<rect x="{x - s:.1f}" y="{y - s:.1f}" width="{2 * s:.1f}" height="{2 * s:.1f}" fill="#BFF2FF" stroke="#4E7A98" stroke-width="1.4" transform="rotate({rot:.0f} {x:.1f} {y:.1f})"/>')
        body.append(f'<rect x="{x - s * 0.45:.1f}" y="{y - s * 0.45:.1f}" width="{s * 0.9:.1f}" height="{s * 0.9:.1f}" fill="#FFFFFF" transform="rotate({rot:.0f} {x:.1f} {y:.1f})"/>')
        body.append(path(f"M {x - s * 0.7:.1f} {y:.1f} L {x + s * 0.7:.1f} {y:.1f}", stroke="#7FE6FF", width=1, extra=f'transform="rotate({rot - 45:.0f} {x:.1f} {y:.1f})"'))
    for a in (math.pi * 1.25, math.pi * 1.6, math.pi * 0.2):   # parıltı yıldızları
        x, y = pol(MID, a)
        body.append(path(f"M {x} {y - 11} L {x + 2} {y - 2} L {x + 11} {y} L {x + 2} {y + 2} L {x} {y + 11} L {x - 2} {y + 2} L {x - 11} {y} L {x - 2} {y - 2} Z", "#FFFFFF"))
    save("diamond_crown", defs, body + finish("#3E5A70"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in (hazard, tire, wheel, stripe, gauge, wood, rust, copper, chrome, velvet, laurel_ring, winged_ring, ember_ring, diamond_ring):
        f()
    gold_ring("crown", 8)
    print(f"{len([x for x in os.listdir(OUT) if x.endswith('.svg') and not x.startswith('_')])} halka → {OUT}")
