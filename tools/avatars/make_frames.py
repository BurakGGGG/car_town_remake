#!/usr/bin/env python3
"""PRESTİJ ÇERÇEVE SÜSLERİ (2026-11-01): halkanın dışına taşan taç / defne / kanat / kupa / elmas taç (frames_src/*.svg).

Tuval 512; avatar dairesi (halka dahil) merkez (256, 256), yarıçap 160 — AvatarView süsü dairenin 512/320 = 1,6 katı
kareye çizer (ProfileCatalog.ORNAMENT_SCALE). Süsler dairenin dışına EN ÇOK %20 taşar (her yönde ≤ 64 tuval pikseli,
yani 32..480 kutusu): HUD avatarı ProfileCatalog.ORNAMENT_ROOM kadar küçülünce süs kendi kutusuna sığar (kullanıcı
kararı: "fotoğraf küçük olsun, prestij alan herkese sığsın"). "_back" avatarın ARKASINDA (kanat), "_front" halkanın ÖNÜNDE.
Halkanın kendisi make_rings.py'de. Çalıştır: python3 tools/avatars/make_frames.py → render_avatars.gd ... frames_src.
Render sonrası PNG sınır kutusu 32..480 içinde kalmalı (profile_test denetler).
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames_src")
INK = "#4A2A0C"
LIMIT = (32, 480)   # süsün sığması gereken kutu (her eksende)


def p(d, fill="none", stroke=None, width=6, extra=""):
    s = f'<path d="{d}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"'
    return s + (f" {extra}" if extra else "") + "/>"


def circle(cx, cy, r, fill, stroke=None, width=5, extra=""):
    s = f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width}"'
    return s + (f" {extra}" if extra else "") + "/>"


def lgrad(gid, colors, x1=0, y1=0, x2=0, y2=1, units=False):
    stops = "".join(f'<stop offset="{k / (len(colors) - 1):.2f}" stop-color="{c}"/>' for k, c in enumerate(colors))
    u = ' gradientUnits="userSpaceOnUse"' if units else ""
    return f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"{u}>{stops}</linearGradient>'


def rgrad(gid, cx, cy, r, colors):
    stops = "".join(f'<stop offset="{k / (len(colors) - 1):.2f}" stop-color="{c}"/>' for k, c in enumerate(colors))
    return f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}" gradientUnits="userSpaceOnUse">{stops}</radialGradient>'


def mirror(d):
    out, tokens, i = [], d.replace(",", " ").split(), 0
    while i < len(tokens):
        t = tokens[i]
        if t.isalpha():
            out.append(t); i += 1; continue
        out.append(f"{512 - float(t):g} {tokens[i + 1]}"); i += 2
    return " ".join(out)


def save(name, defs, layers):
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
           f'  <!-- ÇERÇEVE SÜSÜ {name} (tools/avatars/make_frames.py üretir, elle düzenleme) -->\n'
           "  <defs>" + "".join(defs) + "</defs>\n  " + "\n  ".join(layers) + "\n</svg>\n")
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(svg)


def jewel(cx, cy, r, color, light, dark, cut="diamond"):
    """Yontulmuş taş: koyu kenar, açık faset, beyaz parıltı."""
    if cut == "round":
        return [circle(cx, cy, r + 2.5, "#7A5208"), circle(cx, cy, r, color, dark, 2.5),
                p(f"M {cx - r * 0.7} {cy - r * 0.1} Q {cx} {cy - r * 1.1} {cx + r * 0.7} {cy - r * 0.1} Q {cx} {cy - r * 0.4} {cx - r * 0.7} {cy - r * 0.1} Z", light, extra='opacity="0.85"'),
                circle(cx - r * 0.35, cy - r * 0.4, r * 0.22, "#FFFFFF")]
    h, w = r, r * 0.8
    return [p(f"M {cx} {cy - h - 3} L {cx + w + 3} {cy} L {cx} {cy + h + 3} L {cx - w - 3} {cy} Z", "#7A5208"),
            p(f"M {cx} {cy - h} L {cx + w} {cy} L {cx} {cy + h} L {cx - w} {cy} Z", color, dark, 2.5),
            p(f"M {cx} {cy - h} L {cx + w} {cy} L {cx} {cy - h * 0.15} Z", light, extra='opacity="0.9"'),
            p(f"M {cx} {cy + h} L {cx - w} {cy} L {cx} {cy + h * 0.15} Z", dark, extra='opacity="0.5"'),
            circle(cx - w * 0.3, cy - h * 0.35, r * 0.16, "#FFFFFF")]


# --- TAÇ / ELMAS TAÇ: halkanın tepesine oturur, uçlar y ≥ 36 ----------------------------------------------

def crown(name, metal, velvet, diamonds=False):
    light, mid, dark = metal
    defs = [lgrad(name + "_m", [light, mid, dark], units=True, y1=36, y2=132),
            lgrad(name + "_band", [light, mid, dark, mid], units=True, y1=98, y2=134),
            rgrad(name + "_v", 256, 70, 90, velvet)]
    o = [p("M 186 104 C 186 60, 216 44, 256 44 C 296 44, 326 60, 326 104 Z", f"url(#{name}_v)", INK, 5)]   # kadife kubbe
    for x in (214, 256, 298):   # kubbedeki kemer gölgeleri
        o.append(p(f"M {x} 104 C {x} 80, {x + (256 - x) * 0.2} 56, 256 46", stroke=INK, width=2.5, extra='opacity="0.35"'))
    arches = ("M 176 104 L 160 58 Q 182 76, 204 76 L 226 46 Q 241 70, 256 68 Q 271 70, 286 46 L 308 76 Q 330 76, 352 58 L 336 104 Z")
    o += [p(arches, f"url(#{name}_m)", INK, 6),
          p("M 172 92 Q 186 82, 204 86 M 340 92 Q 326 82, 308 86", stroke=light, width=3.5, extra='opacity="0.9"'),
          p("M 230 60 Q 241 76, 256 76 Q 271 76, 282 60", stroke=light, width=3, extra='opacity="0.8"')]
    band = "M 170 132 C 200 120, 312 120, 342 132 L 338 102 C 306 92, 206 92, 174 102 Z"
    o += [p(band, f"url(#{name}_band)", INK, 6),
          p("M 180 108 C 214 99, 298 99, 332 108", stroke=light, width=3, extra='opacity="0.9"'),
          p("M 178 126 C 214 116, 298 116, 334 126", stroke=dark, width=2, extra='opacity="0.7"')]
    o += [circle(x, 117 - abs(x - 256) * 0.035, 2.2, light) for x in range(186, 330, 12)]   # bant üstü inci dizisi
    if diamonds:
        for x, y, r in ((160, 58, 11), (226, 50, 12), (286, 50, 12), (352, 58, 11)):
            o += jewel(x, y, r, "#7FE6FF", "#E8FCFF", "#2E7A98")
        o += jewel(256, 58, 14, "#7FE6FF", "#E8FCFF", "#2E7A98")
        o += jewel(256, 114, 11, "#7FE6FF", "#E8FCFF", "#2E7A98")
        o += jewel(212, 116, 7, "#BFF2FF", "#FFFFFF", "#2E7A98", "round") + jewel(300, 116, 7, "#BFF2FF", "#FFFFFF", "#2E7A98", "round")
        for x, y in ((200, 48), (318, 46), (232, 40)):   # parıltı
            o.append(p(f"M {x} {y - 8} L {x + 1.5} {y - 1.5} L {x + 8} {y} L {x + 1.5} {y + 1.5} L {x} {y + 8} L {x - 1.5} {y + 1.5} L {x - 8} {y} L {x - 1.5} {y - 1.5} Z", "#FFFFFF"))
    else:
        for x, y in ((160, 56), (226, 44), (286, 44), (352, 56)):   # uçlarda inci
            o += [circle(x, y, 8.5, "#F4F0E6", INK, 3.5), circle(x - 2.5, y - 2.5, 2.6, "#FFFFFF")]
        o += [circle(256, 46, 8, mid, INK, 3.5), p("M 256 38 L 256 34 M 252 36 L 260 36", stroke=INK, width=3)]   # tepede küre + haç
        o += jewel(256, 114, 12, "#D8283A", "#FF9AA4", "#6E0A14")
        o += jewel(212, 116, 8, "#2F62C0", "#A8C8FF", "#0E2A6A", "round") + jewel(300, 116, 8, "#2F62C0", "#A8C8FF", "#0E2A6A", "round")
        o += jewel(184, 120, 5.5, "#2E9A5A", "#A8F0C0", "#0E4A2A", "round") + jewel(328, 120, 5.5, "#2E9A5A", "#A8F0C0", "#0E4A2A", "round")
    save(name + "_front", defs, o)


# --- DEFNE: iki yandan yükselen dallar (x ≥ 42), altta kurdele (y ≤ 474) -----------------------------------

def laurel():
    defs = [lgrad("leaf", ["#A8E07A", "#5EA83E", "#2E6A24"], units=True, x1=0, y1=120, x2=0, y2=470),
            lgrad("leaf_d", ["#7EC45A", "#3E7A2A"], units=True, x1=0, y1=120, x2=0, y2=470),
            lgrad("rib", ["#FF6A6A", "#D8283A", "#8A0A14"], units=True, y1=414, y2=474)]
    o = []
    for side in (-1, 1):
        stem = []
        for k in range(16):
            t = k / 15
            a = math.radians(116 - t * 146)
            r = 170 + 4 * math.sin(t * math.pi)
            stem.append((256 + side * r * math.cos(a), 256 + r * math.sin(a)))
        d = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in stem)
        o += [p(d, stroke=INK, width=9), p(d, stroke="#8A6A32", width=4.5)]
        for k in range(1, 15):
            x, y = stem[k]
            x0, y0 = stem[k - 1]
            ang = math.degrees(math.atan2(y - y0, x - x0))
            size = 1.0 - 0.3 * (k / 15)
            for out, grad_id in ((1, "leaf"), (-1, "leaf_d")):
                lean = ang + out * 50 * side * -1
                reach = 20 * size if out == 1 else 15 * size   # içe bakan yaprak kısa (yüze binmesin)
                lx = x + reach * math.cos(math.radians(lean))
                ly = y + reach * math.sin(math.radians(lean))
                rx, ry = (21 * size if out == 1 else 15 * size), 8.5 * size
                o.append(f'<ellipse cx="{lx:.1f}" cy="{ly:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#{grad_id})" '
                         f'stroke="{INK}" stroke-width="3" transform="rotate({lean:.1f} {lx:.1f} {ly:.1f})"/>')
                ex = lx + (rx * 0.8) * math.cos(math.radians(lean))
                ey = ly + (rx * 0.8) * math.sin(math.radians(lean))
                o.append(p(f"M {x:.1f} {y:.1f} L {ex:.1f} {ey:.1f}", stroke="#D8F8B8", width=1.8, extra='opacity="0.85"'))
            if k % 4 == 2:   # meyve
                bx = x + side * 6
                o += [circle(bx, y + 4, 4.5, "#E8B23A", INK, 2), circle(bx - 1.2, y + 2.8, 1.4, "#FFF4C8")]
        tip = stem[-1]
        o.append(f'<ellipse cx="{tip[0]:.1f}" cy="{tip[1] - 12:.1f}" rx="8" ry="17" fill="url(#leaf)" stroke="{INK}" stroke-width="3" '
                 f'transform="rotate({side * 38} {tip[0]:.1f} {tip[1] - 12:.1f})"/>')
    tail = "M 214 424 L 180 458 L 202 461 L 210 474 L 238 438 Z"
    o += [p(tail, "url(#rib)", INK, 5), p(mirror(tail), "url(#rib)", INK, 5),
          p("M 186 456 L 210 432 M 326 456 L 302 432", stroke="#F2C14E", width=2.5),
          p("M 206 410 C 232 424, 280 424, 306 410 L 312 436 C 284 450, 228 450, 200 436 Z", "url(#rib)", INK, 5),
          p("M 210 418 C 234 430, 278 430, 302 418", stroke="#F2C14E", width=2.5),
          circle(256, 430, 14, "#E8B23A", INK, 4), circle(256, 430, 8, "#C8901E"), circle(252, 426, 3, "#FFF4C8")]
    save("laurel_front", defs, o)


# --- KANATLI TEKER: iki yanda kanat (x ≥ 40), avatarın ARKASINDA ------------------------------------------

def wings():
    defs = [lgrad("wing", ["#FFFFFF", "#E6F0FA", "#BCD2E8"], units=True, y1=130, y2=330),
            lgrad("wing_d", ["#F4F8FC", "#C8DAEC"], units=True, y1=150, y2=320)]
    o = []
    for side in (-1, 1):
        root = (256 + side * 138, 232)
        tip = (256 + side * 198, 166)
        rows = [  # (tüy sayısı, (iç uzunluk, dış uzunluk), yarı genişlik, (açı başı, sonu), aşağı kayma, degrade)
            (6, (40, 52), 13, (108, 140), 0, "wing_d"),   # ana tüyler
            (5, (30, 38), 12, (110, 138), 10, "wing"),    # ikincil tüyler
        ]
        for count, (l_in, l_out), half0, (a0, a1), shift, grad_id in rows:
            feathers = []
            for k in range(count):
                t = k / (count - 1)
                bx = root[0] + (tip[0] - root[0]) * t - side * shift * 0.3
                by = root[1] + (tip[1] - root[1]) * t + shift
                deg = a0 + (a1 - a0) * t
                ang = math.radians(deg if side < 0 else 180 - deg)
                length = l_in + (l_out - l_in) * t
                dx, dy = math.cos(ang), math.sin(ang)
                px, py = -dy, dx
                half = half0 - 2 * t
                tx, ty = bx + dx * length, by + dy * length
                tx = max(LIMIT[0] + 6, min(LIMIT[1] - 6, tx))
                d = (f"M {bx + px * half:.1f} {by + py * half:.1f} "
                     f"Q {bx + px * half * 1.15 + dx * length * 0.6:.1f} {by + py * half * 1.15 + dy * length * 0.6:.1f} {tx:.1f} {ty:.1f} "
                     f"Q {bx - px * half * 0.8 + dx * length * 0.6:.1f} {by - py * half * 0.8 + dy * length * 0.6:.1f} {bx - px * half:.1f} {by - py * half:.1f} Z")
                feathers.append((d, bx, by, tx, ty))
            for d, bx, by, tx, ty in reversed(feathers):
                o.append(p(d, f"url(#{grad_id})", "#34445A", 3.5))
                o.append(p(f"M {bx:.1f} {by:.1f} L {bx + (tx - bx) * 0.75:.1f} {by + (ty - by) * 0.75:.1f}", stroke="#9EB6CE", width=2))
        cov = (f"M {root[0]} {root[1] + 22} C {root[0] + side * 26} {root[1] - 38}, {tip[0] - side * 40} {tip[1] - 30}, {tip[0] + side * 2} {tip[1] - 4} "
               f"C {tip[0] - side * 26} {tip[1] + 22}, {root[0] + side * 40} {root[1] + 6}, {root[0]} {root[1] + 22} Z")
        o.append(p(cov, "url(#wing)", "#34445A", 4.5))
        for k in range(5):   # örtü tüyü pulları
            t = (k + 0.5) / 5
            cx = root[0] + (tip[0] - root[0]) * t * 0.9 + side * 2
            cy = root[1] + (tip[1] - root[1]) * t * 0.9 + 4
            o.append(p(f"M {cx - 9:.1f} {cy:.1f} Q {cx:.1f} {cy + 11:.1f} {cx + 9:.1f} {cy:.1f}", stroke="#9EB6CE", width=2))
        o.append(p(f"M {root[0] + side * 12} {root[1] - 8} C {root[0] + side * 40} {root[1] - 40}, {tip[0] - side * 50} {tip[1] - 22}, {tip[0] - side * 14} {tip[1] - 10}",
                   stroke="#FFFFFF", width=4, extra='opacity="0.95"'))
    save("winged_back", defs, o)


# --- ALEVLİ KUPA: altta altın kupa (y ≤ 474); alevler AvatarView'da kodla, hareketli ------------------------

def trophy():
    defs = [lgrad("cup", ["#FFF0B0", "#F2C14E", "#C8901E", "#8A5A0C"], units=True, x1=210, y1=0, x2=302, y2=0),
            lgrad("base", ["#5A3A1E", "#2E1C0C"], units=True, y1=452, y2=474)]
    cup = "M 214 376 L 298 376 C 298 420, 284 440, 256 444 C 228 440, 214 420, 214 376 Z"
    handle = "M 216 386 C 182 380, 180 424, 222 428"
    o = [p(handle, stroke=INK, width=13), p(handle, stroke="#E8B23A", width=6.5), p(handle, stroke="#FFF0B0", width=2),
         p(mirror(handle), stroke=INK, width=13), p(mirror(handle), stroke="#C8901E", width=6.5),
         p(cup, "url(#cup)", INK, 6),
         f'<ellipse cx="256" cy="377" rx="42" ry="7" fill="#FFE68A" stroke="{INK}" stroke-width="4"/>',
         '<ellipse cx="256" cy="378" rx="34" ry="3.5" fill="#B8801A"/>',
         p("M 226 388 C 226 414, 234 430, 246 436", stroke="#FFFFFF", width=5, extra='opacity="0.7"'),
         p("M 256 394 L 261 405 L 273 406 L 264 414 L 267 426 L 256 419 L 245 426 L 248 414 L 239 406 L 251 405 Z", "#FFF3C2", INK, 2.5),
         f'<rect x="246" y="442" width="20" height="12" fill="#C8901E" stroke="{INK}" stroke-width="4"/>',
         f'<rect x="222" y="452" width="68" height="22" rx="5" fill="url(#base)" stroke="{INK}" stroke-width="5"/>',
         f'<rect x="238" y="458" width="36" height="10" rx="2" fill="#F2C14E" stroke="{INK}" stroke-width="2"/>']
    save("flame_cup_front", defs, o)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    crown("crown", ("#FFF0B0", "#E8B23A", "#8A5A0C"), ["#E8485A", "#A8142A", "#5A0614"])
    crown("diamond_crown", ("#FFFFFF", "#C9D3DE", "#6E7A88"), ["#4A6AA8", "#22386E", "#101C3A"], diamonds=True)
    laurel()
    wings()
    trophy()
    print(f"{len([f for f in os.listdir(OUT) if f.endswith('.svg')])} süs → {OUT}")
