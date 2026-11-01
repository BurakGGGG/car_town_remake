#!/usr/bin/env python3
"""HAZIR AVATARLAR: Emre / Elif portreleriyle aynı çizgide 12 usta portresi (src/preset_XX.svg).

Parçalı kurulur (yüz, gözler, saç, kıyafet, arka plan) ama her avatarın saçı / aksesuarı ayrı çizilir: hepsi
aynı şablondan çıkmış gibi görünmesin. Ölçüler 512 tuvalde, oyunda daireye kırpılır (önemli her şey r=256 içinde).
Çalıştır: python3 tools/avatars/make_presets.py  →  sonra render_avatars.gd ile PNG.
"""
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
INK = "#33262F"

# --- Yüz şekilleri (göz çizgisi ~252, burun ~286, ağız ~318) ------------------------------------------

FACES = {
    "round": "M 160 240 C 156 312, 198 360, 256 362 C 314 360, 356 312, 352 240 C 350 166, 308 128, 256 128 C 204 128, 162 166, 160 240 Z",
    "oval": "M 168 214 C 166 266, 176 302, 196 330 C 214 354, 236 366, 256 366 C 276 366, 298 354, 316 330 C 336 302, 346 266, 344 214 C 340 140, 302 112, 256 112 C 210 112, 172 140, 168 214 Z",
    "square": "M 164 214 C 162 274, 168 314, 190 340 C 212 362, 236 370, 256 370 C 276 370, 300 362, 322 340 C 344 314, 350 274, 348 214 C 344 140, 304 112, 256 112 C 208 112, 168 140, 164 214 Z",
    "heart": "M 162 232 C 160 296, 196 346, 256 362 C 316 346, 352 296, 350 232 C 348 162, 306 124, 256 124 C 206 124, 164 162, 162 232 Z",
}
EAR_X = {"round": (160, 352), "oval": (168, 344), "square": (164, 348), "heart": (162, 350)}

SKINS = {
    "light": ("#F8D3B8", "#E7AE90"),
    "fair": ("#F3C9AC", "#DFA88A"),
    "medium_light": ("#EEBF9A", "#D49B78"),
    "medium": ("#E2A880", "#C4876A"),
    "olive": ("#D9A07A", "#B9805E"),
    "tan": ("#C98A5E", "#A96C45"),
    "dark": ("#8D5A3B", "#6F4229"),
}

L_EYE, R_EYE, EYE_Y = 214, 298, 252


def p(d, fill="none", stroke=None, width=6, extra=""):
    s = f'<path d="{d}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"'
    return s + (f" {extra}" if extra else "") + "/>"


def circle(cx, cy, r, fill, stroke=None, width=5, extra=""):
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"'
    if stroke:
        s += f' stroke="{stroke}" stroke-width="{width}"'
    return s + (f" {extra}" if extra else "") + "/>"


def mirror(d):
    """Yolun x'lerini 256 çizgisine göre aynalar (yalnız mutlak komutlar: M L C Q Z)."""
    tokens = d.replace(",", " ").split()
    i = 0
    res = []
    while i < len(tokens):
        t = tokens[i]
        if t.isalpha():
            res.append(t)
            i += 1
            continue
        x = float(tokens[i]); y = tokens[i + 1]
        res.append(f"{512 - x:g} {y}")
        i += 2
    return " ".join(res)


# --- Arka plan -------------------------------------------------------------------------------------------

def background(kind, c1, c2, accent):
    defs = (f'<radialGradient id="bg" cx="256" cy="220" r="330" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>')
    out = ['<rect width="512" height="512" fill="url(#bg)"/>']
    if kind == "stripes":
        out.append(f'<g stroke="{accent}" stroke-width="26" opacity="0.35">')
        for k in range(-3, 6):
            out.append(f'<path d="M {-120 + k * 130} 640 L {520 + k * 130} 0"/>')
        out.append("</g>")
    elif kind == "dots":
        out.append(f'<g fill="{accent}" opacity="0.35">')
        for row in range(9):
            for col in range(9):
                x = col * 64 + (32 if row % 2 else 0); y = row * 60 + 10
                out.append(circle(x, y, 9, accent))
        out.append("</g>")
    elif kind == "rays":
        out.append(f'<g fill="{accent}" opacity="0.22">')
        import math
        for k in range(12):
            a0 = k * math.pi / 6; a1 = a0 + math.pi / 12
            x0, y0 = 256 + 600 * math.cos(a0), 250 + 600 * math.sin(a0)
            x1, y1 = 256 + 600 * math.cos(a1), 250 + 600 * math.sin(a1)
            out.append(f'<path d="M 256 250 L {x0:.0f} {y0:.0f} L {x1:.0f} {y1:.0f} Z"/>')
        out.append("</g>")
    elif kind == "checker":
        out.append(f'<g fill="{accent}" opacity="0.22">')
        for row in range(8):
            for col in range(8):
                if (row + col) % 2 == 0:
                    out.append(f'<rect x="{col * 64}" y="{row * 64}" width="64" height="64"/>')
        out.append("</g>")
    return defs, out


# --- Gövde -----------------------------------------------------------------------------------------------

SHOULDERS = "M 36 530 C 44 446, 116 406, 212 394 L 300 394 C 396 406, 468 446, 476 530 Z"
NECK = "M 220 320 L 220 410 Q 256 430 292 410 L 292 320 Z"


def body(kind, c1, c2, accent, skin_shade):
    defs = (f'<linearGradient id="suit" x1="0" y1="396" x2="0" y2="512" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>'
            f'<linearGradient id="neck" x1="0" y1="330" x2="0" y2="420" gradientUnits="userSpaceOnUse">'
            f'<stop offset="0" stop-color="{skin_shade}"/><stop offset="1" stop-color="{skin_shade}" stop-opacity="0.75"/></linearGradient>')
    o = ['<g transform="translate(0,-12)">', p(SHOULDERS, "url(#suit)", INK)]
    hl = '<path d="M 70 470 Q 104 432 168 414" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="7" stroke-linecap="round"/>'
    if kind == "coverall":
        o += [p("M 218 396 L 256 446 L 294 396 Z", accent, INK),
              p("M 214 392 L 174 424 L 222 444 L 252 448 Z", c1, INK),
              p("M 298 392 L 338 424 L 290 444 L 260 448 Z", c1, INK),
              p("M 256 450 L 256 520", stroke=c2, width=5),
              '<rect x="249" y="452" width="14" height="22" rx="4" fill="#E9EEF2" stroke="' + INK + '" stroke-width="3"/>',
              f'<rect x="152" y="452" width="66" height="34" rx="10" fill="#FFFFFF" stroke="{c2}" stroke-width="5"/>',
              p("M 166 470 L 204 470", stroke=c2, width=5)]
    elif kind == "hoodie":
        o += [p("M 184 398 C 196 446, 316 446, 328 398 C 306 384, 206 384, 184 398 Z", c2, INK),
              p("M 236 430 L 230 492", stroke="#FFFFFF", width=5), p("M 276 430 L 282 492", stroke="#FFFFFF", width=5),
              circle(230, 494, 5, "#FFFFFF"), circle(282, 494, 5, "#FFFFFF"),
              p("M 150 470 Q 256 500 362 470", stroke=c2, width=5)]
    elif kind == "jacket":
        o += [p("M 200 398 Q 256 444 312 398 L 326 530 L 186 530 Z", accent, INK),
              p("M 198 396 L 156 436 L 196 452 L 236 530 L 214 424 Z", c1, INK),
              p("M 314 396 L 356 436 L 316 452 L 276 530 L 298 424 Z", c1, INK),
              p("M 212 412 Q 256 446 300 412", stroke=accent, width=6)]
    elif kind == "denim":
        o += [p("M 204 398 Q 256 440 308 398 L 318 530 L 194 530 Z", accent, INK),
              p("M 202 394 L 164 420 L 206 446 L 232 530 L 216 424 Z", c1, INK),
              p("M 310 394 L 348 420 L 306 446 L 280 530 L 296 424 Z", c1, INK),
              f'<rect x="130" y="462" width="56" height="40" rx="6" fill="none" stroke="{c2}" stroke-width="5"/>',
              f'<rect x="326" y="462" width="56" height="40" rx="6" fill="none" stroke="{c2}" stroke-width="5"/>',
              circle(158, 474, 4, "#E8C46A"), circle(354, 474, 4, "#E8C46A")]
    elif kind == "racing":
        o += [p("M 206 396 C 220 410, 292 410, 306 396 L 300 386 C 286 398, 226 398, 212 386 Z", c2, INK),
              p("M 60 486 C 150 450, 362 450, 452 486 L 446 506 C 360 472, 152 472, 66 506 Z", accent, INK, 4),
              f'<rect x="300" y="430" width="70" height="30" rx="8" fill="#FFFFFF" stroke="{INK}" stroke-width="4"/>',
              p("M 312 445 L 358 445", stroke=c2, width=5),
              p("M 256 404 L 256 530", stroke=c2, width=4)]
    elif kind == "tee":
        o += [p("M 212 398 Q 256 436 300 398", stroke=c2, width=8)]
    elif kind == "bomber":
        o += [p("M 200 400 C 220 422, 292 422, 312 400 L 306 388 C 288 404, 224 404, 206 388 Z", accent, INK),
              p("M 256 412 L 256 530", stroke=c2, width=5)]
    elif kind == "cardigan":
        o += [p("M 206 398 L 256 470 L 306 398 Z", accent, INK),
              p("M 220 398 Q 256 420 292 398", stroke="#FFFFFF", width=6),
              p("M 206 396 L 256 474 L 256 530", stroke=INK, width=5),
              circle(248, 488, 5, c2, INK, 2.5), circle(248, 512, 5, c2, INK, 2.5)]
    elif kind == "vest":   # reflektif ikaz yeleği (c1) + altında tişört (accent)
        silver = "#ECEFF2"
        o += [p("M 206 396 L 256 452 L 306 396 Z", accent, INK),
              p("M 176 404 L 202 398 L 222 530 L 194 530 Z", silver, INK, 4),
              p(mirror("M 176 404 L 202 398 L 222 530 L 194 530 Z"), silver, INK, 4),
              p("M 52 486 C 120 466, 176 462, 210 466 L 212 488 C 176 484, 120 488, 56 508 Z", silver, INK, 4),
              p(mirror("M 52 486 C 120 466, 176 462, 210 466 L 212 488 C 176 484, 120 488, 56 508 Z"), silver, INK, 4),
              p("M 256 452 L 256 530", stroke=c2, width=5)]
    elif kind == "leather":   # açık deri yelek (c1), altında koyu tişört (accent), yakada perçinler
        o += [p("M 204 396 Q 256 436 308 396 L 318 530 L 194 530 Z", accent, INK),
              p("M 200 394 L 146 432 L 186 448 L 226 530 L 214 424 Z", c1, INK),
              p(mirror("M 200 394 L 146 432 L 186 448 L 226 530 L 214 424 Z"), c1, INK)]
        o += [circle(x, y, 4, "#D9DDE2", INK, 2) for x, y in [(170, 434), (190, 446), (204, 470), (214, 494)]]
        o += [circle(512 - x, y, 4, "#D9DDE2", INK, 2) for x, y in [(170, 434), (190, 446), (204, 470), (214, 494)]]
    elif kind == "windbreaker":   # 80'ler renk bloklu rüzgârlık: c1 gövde, accent ve c2 bantlar
        o += [p("M 56 474 C 140 436, 200 426, 256 436 C 312 426, 372 436, 456 474 L 462 502 C 376 466, 312 458, 256 466 C 200 458, 136 466, 50 502 Z", accent, INK, 4),
              p("M 70 444 C 140 414, 200 410, 228 412 L 226 428 C 196 426, 140 432, 66 462 Z", c2, INK, 3),
              p(mirror("M 70 444 C 140 414, 200 410, 228 412 L 226 428 C 196 426, 140 432, 66 462 Z"), c2, INK, 3),
              p("M 206 398 C 222 416, 290 416, 306 398 L 300 386 C 284 402, 228 402, 212 386 Z", c2, INK),
              p("M 256 414 L 256 530", stroke=INK, width=4)]
    elif kind == "blouse":   # beyaz bluz, yakası çiçek işlemeli (accent: ana nakış rengi)
        o += [p("M 192 398 C 212 446, 300 446, 320 398", stroke=accent, width=12)]
        for k, (x, y) in enumerate([(200, 418), (222, 436), (256, 444), (290, 436), (312, 418)]):
            col = [accent, "#F2C14E", "#3E9E93", "#F2C14E", accent][k]
            o += [circle(x + dx, y + dy, 5.5, col, INK, 2) for dx, dy in [(0, -7), (7, 0), (0, 7), (-7, 0)]]
            o.append(circle(x, y, 4, "#FFFFFF", INK, 2))
    elif kind == "waistcoat":   # beyaz gömlek yakası + koyu yelek (c1), düğmeler
        o += [p("M 206 396 L 256 476 L 306 396 Z", "#FFFFFF", INK),
              p("M 212 390 L 232 424 L 256 404 Z", "#FFFFFF", INK, 4), p(mirror("M 212 390 L 232 424 L 256 404 Z"), "#FFFFFF", INK, 4),
              p("M 206 400 L 256 478", stroke=accent, width=6), p("M 306 400 L 256 478", stroke=accent, width=6),
              circle(256, 496, 5, accent, INK, 2.5), circle(256, 518, 5, accent, INK, 2.5)]
    elif kind == "turtleneck":   # balıkçı yaka kazak (yaka over_body'de: boynun üstünde)
        o += [p("M 120 470 Q 256 500 392 470", stroke=c2, width=5)]
    o.append(hl)
    o.append(p(NECK, "url(#neck)", INK))
    o.append("</g>")
    return defs, o


# --- Yüz ve yüz parçaları --------------------------------------------------------------------------------

def head(shape, skin, ears=True, ear_fill=None):
    base, shade = SKINS[skin]
    face = FACES[shape]
    lx, rx = EAR_X[shape]
    defs = f'<clipPath id="face"><path d="{face}"/></clipPath>'
    o = []
    if ears:
        o += [f'<ellipse cx="{lx}" cy="266" rx="17" ry="23" fill="{ear_fill or base}" stroke="{INK}" stroke-width="5"/>',
              f'<ellipse cx="{rx}" cy="266" rx="17" ry="23" fill="{shade}" stroke="{INK}" stroke-width="5"/>',
              p(f"M {lx - 4} 254 Q {lx - 10} 266 {lx - 2} 278", stroke=shade, width=4),
              p(f"M {rx + 4} 254 Q {rx + 10} 266 {rx + 2} 278", stroke=INK, width=3, extra='opacity="0.35"')]
    o += [p(face, shade),
          f'<g clip-path="url(#face)"><ellipse cx="236" cy="232" rx="110" ry="146" fill="{base}"/></g>',
          p(face, stroke=INK)]
    return defs, o


def eyes(kind, iris="#6B4426", lashes=False, y=EYE_Y):
    o = []
    for x in (L_EYE, R_EYE):
        if kind == "happy":
            o.append(p(f"M {x - 15} {y + 4} Q {x} {y - 14} {x + 15} {y + 4}", stroke=INK, width=6))
            continue
        if kind == "big":
            o += [f'<ellipse cx="{x}" cy="{y}" rx="18" ry="20" fill="#FFFFFF"/>',
                  circle(x + 2, y + 3, 13, iris), circle(x + 2, y + 6, 8, iris, extra='opacity="0.55" fill-opacity="0.6"'),
                  circle(x + 2, y + 3, 6.5, "#20120B"), circle(x + 8, y - 4, 4.5, "#FFFFFF"), circle(x - 3, y + 9, 2.2, "#FFFFFF"),
                  p(f"M {x - 21} {y + 2} Q {x} {y - 40} {x + 21} {y + 2}", stroke=INK, width=6)]
        else:  # normal
            o += [f'<ellipse cx="{x}" cy="{y}" rx="16" ry="13" fill="#FFFFFF"/>',
                  circle(x + 2, y + 1, 9.5, iris), circle(x + 2, y + 1, 4.8, "#20120B"), circle(x + 6, y - 3, 3, "#FFFFFF"),
                  p(f"M {x - 19} {y + 2} Q {x} {y - 26} {x + 19} {y + 2}", stroke=INK, width=6)]
        if lashes:
            side = -1 if x < 256 else 1
            ox = x + side * 19
            o += [p(f"M {ox} {y - 5} l {side * 9} -5", stroke=INK, width=4),
                  p(f"M {ox - side * 4} {y - 12} l {side * 6} -8", stroke=INK, width=4)]
    return o


def brows(color, width=7, y=218, raise_right=0, tilt=0):
    return [p(f"M {L_EYE - 22} {y + tilt} Q {L_EYE} {y - 12} {L_EYE + 22} {y - 4 - tilt}", stroke=color, width=width),
            p(f"M {R_EYE - 22} {y - 4 - tilt - raise_right} Q {R_EYE} {y - 12 - raise_right} {R_EYE + 22} {y + tilt - raise_right}", stroke=color, width=width)]


def nose(kind, shade):
    if kind == "long":
        return [p("M 260 244 C 264 262, 270 276, 274 286 C 266 294, 252 295, 242 289", stroke=shade, width=5),
                circle(250, 288, 2.8, shade), circle(266, 288, 2.8, shade)]
    if kind == "wide":
        return [p("M 240 280 Q 236 294 248 294 Q 256 300 264 294 Q 276 294 272 280", stroke=shade, width=5)]
    return [p("M 246 284 Q 256 294 266 284", stroke=shade, width=5)]


def mouth(kind, y=316):
    if kind == "grin":
        d = f"M 224 {y - 6} Q 256 {y + 36} 288 {y - 6} Q 256 {y + 4} 224 {y - 6} Z"
        return [p(d, "#8C2F3F"),
                f'<g clip-path="url(#mouth)"><ellipse cx="258" cy="{y + 20}" rx="16" ry="9" fill="#FF7E95"/>'
                f'<path d="M 222 {y - 10} Q 256 {y + 2} 290 {y - 10} L 290 {y} Q 256 {y + 12} 222 {y} Z" fill="#FFFFFF"/></g>',
                p(d, stroke=INK, width=5)]
    if kind == "smirk":
        return [p(f"M 238 {y + 4} Q 258 {y + 10} 280 {y - 2}", stroke=INK, width=5),
                p(f"M 280 {y - 2} q 5 -1 7 -6", stroke=INK, width=4)]
    if kind == "open":  # kahkaha / şaşkın değil: yuvarlak açık gülüş
        return [f'<ellipse cx="256" cy="{y + 6}" rx="18" ry="14" fill="#8C2F3F" stroke="{INK}" stroke-width="5"/>',
                f'<ellipse cx="256" cy="{y + 13}" rx="10" ry="5" fill="#FF7E95"/>']
    return [p(f"M 230 {y} Q 256 {y + 22} 282 {y}", stroke=INK, width=6)]


def mouth_defs(kind, y=316):
    if kind == "grin":
        d = f"M 224 {y - 6} Q 256 {y + 36} 288 {y - 6} Q 256 {y + 4} 224 {y - 6} Z"
        return f'<clipPath id="mouth"><path d="{d}"/></clipPath>'
    return ""


def blush(opacity=0.5, color="#FF8FAA"):
    return [f'<ellipse cx="190" cy="298" rx="22" ry="13" fill="{color}" opacity="{opacity}"/>',
            f'<ellipse cx="322" cy="298" rx="22" ry="13" fill="{color}" opacity="{opacity}"/>']


def freckles(color):
    return [circle(x, y, 2.4, color) for x, y in [(212, 284), (222, 292), (204, 294), (300, 284), (290, 292), (308, 294)]]


def glasses(color, lens="#FFFFFF"):
    o = []
    for x in (L_EYE, R_EYE):
        o.append(circle(x, EYE_Y, 27, lens, color, 6, 'fill-opacity="0.18"'))
    o += [p(f"M {L_EYE + 27} {EYE_Y - 4} Q 256 {EYE_Y - 14} {R_EYE - 27} {EYE_Y - 4}", stroke=color, width=5),
          p(f"M {L_EYE - 27} {EYE_Y - 4} L 168 {EYE_Y - 8}", stroke=color, width=5),
          p(f"M {R_EYE + 27} {EYE_Y - 4} L 344 {EYE_Y - 8}", stroke=color, width=5),
          p(f"M {L_EYE - 12} {EYE_Y - 14} l 10 -8", stroke="#FFFFFF", width=4, extra='opacity="0.8"'),
          p(f"M {R_EYE - 12} {EYE_Y - 14} l 10 -8", stroke="#FFFFFF", width=4, extra='opacity="0.8"')]
    return o


def wrinkles(shade):
    return [p("M 186 262 l -8 4", stroke=shade, width=3), p("M 326 262 l 8 4", stroke=shade, width=3),
            p("M 226 300 Q 218 312 222 326", stroke=shade, width=4), p("M 286 300 Q 294 312 290 326", stroke=shade, width=4)]


# --- Avatarlar -------------------------------------------------------------------------------------------

def build(n, spec):
    defs, layers = [], []
    d, o = background(*spec["bg"]); defs.append(d); layers += o
    layers += spec.get("back", [])
    d, o = body(spec["body"][0], spec["body"][1], spec["body"][2], spec["body"][3], SKINS[spec["skin"]][1])
    defs.append(d); layers += o
    layers += spec.get("over_body", [])
    d, o = head(spec["face"], spec["skin"], spec.get("ears", True))
    defs.append(d); layers += o
    shade = SKINS[spec["skin"]][1]
    layers += spec.get("on_face", [])
    if spec.get("blush"):
        layers += blush(spec["blush"])
    if spec.get("freckles"):
        layers += freckles(spec["freckles"])
    if spec.get("wrinkles"):
        layers += wrinkles(shade)
    layers += eyes(spec.get("eyes", "normal"), spec.get("iris", "#6B4426"), spec.get("lashes", False))
    layers += spec.get("brows", [])
    layers += nose(spec.get("nose", "button"), shade)
    layers += spec.get("under_mouth", [])
    m = spec.get("mouth", "smile")
    defs.append(mouth_defs(m))
    layers += mouth(m)
    layers += spec.get("front", [])
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
           f'  <!-- HAZIR AVATAR {n:02d}: {spec["about"]} (tools/avatars/make_presets.py üretir, elle düzenleme) -->\n'
           "  <defs>" + "".join(defs) + "</defs>\n  " + "\n  ".join(x for x in layers if x) + "\n</svg>\n")
    with open(os.path.join(OUT, f"preset_{n:02d}.svg"), "w") as f:
        f.write(svg)


GRAY = "#B8B4AE"
GRAY_D = "#8E8A84"

PRESETS = [
    # 1 — yaşlı usta: kasket, gür beyaz bıyık, lacivert tulum
    {"about": "yaşlı usta, kasket, beyaz bıyık", "bg": ("rays", "#FFE29A", "#F5A93C", "#FFFFFF"), "skin": "medium", "face": "square",
     "body": ("coverall", "#4C6FB0", "#33508A", "#E9E3D6"), "eyes": "happy", "wrinkles": True, "nose": "wide",
     "brows": brows(GRAY, 9, 214),
     "on_face": [p("M 166 236 C 162 212, 168 194, 180 182 L 194 198 C 186 210, 182 224, 182 242 Z", GRAY, INK, 4),
                 p(mirror("M 166 236 C 162 212, 168 194, 180 182 L 194 198 C 186 210, 182 224, 182 242 Z"), GRAY, INK, 4)],
     "mouth": "smile",
     "front": [p("M 216 306 C 226 288, 250 290, 256 297 C 262 290, 286 288, 296 306 C 300 318, 290 322, 282 314 C 272 306, 262 306, 256 309 C 250 306, 240 306, 230 314 C 222 322, 212 318, 216 306 Z", "#ECEAE6", INK, 4),
               p("M 156 196 C 154 138, 200 102, 262 102 C 324 102, 364 136, 360 186 C 356 198, 344 202, 328 200 L 180 204 C 168 206, 158 204, 156 196 Z", "#6B5B4E", INK),
               p("M 196 140 Q 256 120 330 136", stroke="#857364", width=5), p("M 182 166 Q 256 146 344 164", stroke="#857364", width=5),
               p("M 172 196 C 208 182, 302 178, 356 188 C 368 198, 364 214, 348 216 C 300 206, 214 208, 180 218 C 166 216, 164 202, 172 196 Z", "#54473C", INK)]},
    # 2 — genç: ters şapka, kapüşonlu, kocaman gülüş
    {"about": "genç, ters şapka, kapüşonlu", "bg": ("dots", "#CDEBFF", "#7CC4F2", "#FFFFFF"), "skin": "medium_light", "face": "oval",
     "body": ("hoodie", "#9AA3B5", "#7A8296", "#FFFFFF"), "eyes": "normal", "iris": "#5A3A22", "mouth": "grin",
     "brows": brows("#4A2E1E", 7, 218, raise_right=4),
     "back": [p("M 160 168 C 126 160, 100 172, 92 190 C 112 200, 140 196, 166 186 Z", "#C93A35", INK)],
     "on_face": [p("M 168 236 C 166 214, 170 200, 178 190 L 190 206 C 186 216, 184 228, 184 244 Z", "#3B2A20"),
                 p(mirror("M 168 236 C 166 214, 170 200, 178 190 L 190 206 C 186 216, 184 228, 184 244 Z"), "#3B2A20")],
     "front": [p("M 164 202 C 160 140, 204 104, 256 104 C 308 104, 352 140, 348 202 C 322 190, 292 186, 256 186 C 220 186, 190 190, 164 202 Z", "#E2483D", INK),
               p("M 226 190 Q 256 160 286 190 Z", "#3B2A20", INK, 4), p("M 236 182 q 6 -10 14 -12", stroke="#5A4232", width=4),
               p("M 200 132 Q 256 116 312 132", stroke="#F07068", width=6),
               circle(256, 106, 7, "#C93A35", INK, 4)]},
    # 3 — kıvırcık saçlı kadın, halka küpe, kot ceket
    {"about": "kıvırcık saçlı kadın, halka küpe, kot ceket", "bg": ("stripes", "#EADFFF", "#B9A2F0", "#FFFFFF"), "skin": "tan", "face": "heart",
     "body": ("denim", "#5B8BD0", "#3E6AAE", "#FFFFFF"), "eyes": "big", "iris": "#4A2E1A", "lashes": True, "mouth": "grin", "blush": 0.35,
     "brows": brows("#2A1A14", 6, 216),
     "back": [circle(x, y, r, "#2A1A14", INK, 5) for x, y, r in
              [(170, 170, 50), (342, 170, 50), (210, 118, 50), (302, 118, 50), (256, 104, 50), (146, 230, 48), (366, 230, 48),
               (150, 292, 44), (362, 292, 44), (168, 340, 38), (344, 340, 38)]],
     "over_body": [circle(162, 300, 13, "none", "#F2C14E", 5), circle(350, 300, 13, "none", "#F2C14E", 5)],
     "front": [circle(x, y, r, "#2A1A14", INK, 4) for x, y, r in
               [(186, 182, 26), (220, 158, 28), (258, 150, 28), (296, 158, 28), (328, 182, 26), (172, 214, 20), (342, 214, 20)]]
     + [p(f"M {x - 10} {y - 6} q 8 -8 18 -2", stroke="#4A3428", width=4) for x, y in [(220, 156), (258, 148), (296, 156), (186, 180)]]},
    # 4 — gözlüklü, atkuyruklu, turuncu yarış ceketi
    {"about": "gözlüklü, atkuyruklu kızıl saç, yarış ceketi", "bg": ("checker", "#DDF9EE", "#8FE0C4", "#FFFFFF"), "skin": "light", "face": "round",
     "body": ("racing", "#FF8A3D", "#E06A20", "#FFFFFF"), "eyes": "big", "iris": "#3E7A5A", "lashes": True, "mouth": "smile", "blush": 0.45,
     "freckles": "#D08060", "brows": brows("#B0502A", 6, 214),
     "back": [p("M 318 150 C 380 124, 430 166, 420 236 C 414 276, 398 306, 384 326 C 380 288, 368 246, 340 206 Z", "#C8602E", INK),
              p("M 360 170 Q 398 200 396 260", stroke="#E07A42", width=5),
              p("M 160 240 C 152 160, 198 118, 256 118 C 314 118, 360 160, 352 240 Z", "#C8602E", INK)],
     "on_face": [],
     "front": [p("M 162 232 C 158 164, 200 126, 256 124 C 312 126, 354 164, 350 232 C 342 200, 328 176, 306 162 C 272 178, 222 184, 188 196 C 176 206, 168 218, 162 232 Z", "#C8602E", INK),
               p("M 200 156 Q 240 140 290 146", stroke="#E07A42", width=5),
               circle(334, 150, 13, "#7FD3F5", INK, 4)] + glasses("#2F3C5A")},
    # 5 — kel, gür sakallı, siyah tişört
    {"about": "kel, gür kızıl sakallı", "bg": ("rays", "#FFCDAA", "#F07A4A", "#FFFFFF"), "skin": "medium_light", "face": "oval",
     "body": ("tee", "#3A3D46", "#262830", "#FFFFFF"), "eyes": "normal", "iris": "#3E5A7A", "mouth": "grin",
     "brows": brows("#8A3E1E", 9, 216, tilt=-3),
     "on_face": [p("M 200 140 Q 232 120 270 124", stroke="#FFFFFF", width=8, extra='opacity="0.45"'),
                 p("M 168 228 C 164 300, 180 360, 210 392 C 230 410, 246 416, 256 416 C 266 416, 282 410, 302 392 C 332 360, 348 300, 344 228 L 330 230 C 330 270, 322 292, 304 304 C 290 300, 270 296, 256 300 C 242 296, 222 300, 208 304 C 190 292, 182 270, 182 230 Z", "#B4532A", INK, 5),
                 p("M 200 330 q 10 22 26 34", stroke="#D06A3A", width=4), p("M 312 330 q -10 22 -26 34", stroke="#D06A3A", width=4),
                 p("M 246 380 q 10 8 20 0", stroke="#D06A3A", width=4)],
     "front": [p("M 216 304 C 228 290, 250 290, 256 296 C 262 290, 284 290, 296 304 C 290 312, 274 312, 256 306 C 238 312, 222 312, 216 304 Z", "#B4532A", INK, 4)]},
    # 6 — başörtülü, sıcak gülüş, turkuaz tulum
    {"about": "başörtülü kadın, tulum", "bg": ("dots", "#FFE8D6", "#FFB892", "#FFFFFF"), "skin": "medium_light", "face": "round", "ears": False,
     "body": ("coverall", "#5BC2B6", "#3E9E93", "#F4F0FF"), "eyes": "big", "iris": "#5A3A22", "lashes": True, "mouth": "grin", "blush": 0.45,
     "brows": brows("#4A2E1E", 6, 216),
     "back": [p("M 140 250 C 128 150, 190 92, 256 92 C 322 92, 384 150, 372 250 C 370 316, 378 360, 402 400 L 110 400 C 134 360, 142 316, 140 250 Z", "#A890E0", INK)],
     "over_body": [p("M 168 320 C 196 376, 230 392, 256 392 C 282 392, 316 376, 344 320 L 380 404 C 330 432, 182 432, 132 404 Z", "#A890E0", INK)],
     "front": [p("M 178 336 C 156 296, 152 254, 158 220 C 168 160, 208 128, 256 128 C 304 128, 344 160, 354 220 C 360 254, 356 296, 334 336", stroke="#A890E0", width=30),
               p("M 172 328 C 150 290, 146 252, 152 220 C 164 152, 206 118, 256 118 C 306 118, 348 152, 360 220 C 366 252, 362 290, 340 328", stroke=INK, width=5),
               p("M 186 330 C 166 294, 164 256, 170 224 C 180 172, 214 144, 256 144 C 298 144, 332 172, 342 224 C 348 256, 346 294, 326 330", stroke="#8F76CC", width=5),
               p("M 210 110 Q 256 96 302 110", stroke="#C6B4F0", width=6),
               circle(338, 360, 9, "#F2C14E", INK, 3)]},
    # 7 — genç, kıvırcık üst + kısa yanlar, boynunda kulaklık, yeşil bomber
    {"about": "genç, kıvırcık üst, kulaklık", "bg": ("stripes", "#C9F5F0", "#5CC9C0", "#FFFFFF"), "skin": "dark", "face": "oval",
     "body": ("bomber", "#4E9A62", "#367A48", "#F2A63B"), "eyes": "normal", "iris": "#2A1A12", "mouth": "grin",
     "brows": brows("#1A1210", 8, 218),
     "on_face": [p("M 170 238 C 166 196, 172 164, 186 146 L 200 160 C 190 182, 186 210, 186 240 Z", "#2A1D18", extra='opacity="0.75"'),
                 p(mirror("M 170 238 C 166 196, 172 164, 186 146 L 200 160 C 190 182, 186 210, 186 240 Z"), "#2A1D18", extra='opacity="0.75"')],
     "over_body": [p("M 196 404 C 196 440, 316 440, 316 404", stroke="#2F3236", width=10),
                   f'<rect x="168" y="388" width="40" height="52" rx="16" fill="#2F3236" stroke="{INK}" stroke-width="4"/>',
                   f'<rect x="304" y="388" width="40" height="52" rx="16" fill="#2F3236" stroke="{INK}" stroke-width="4"/>',
                   circle(188, 414, 10, "#F2A63B"), circle(324, 414, 10, "#F2A63B")],
     "front": [circle(x, y, r, "#1A1210", INK, 4) for x, y, r in
               [(196, 152, 20), (226, 132, 22), (258, 126, 22), (290, 132, 22), (318, 152, 20), (210, 164, 16), (240, 152, 18),
                (272, 152, 18), (304, 166, 16), (184, 176, 14), (330, 178, 14)]]
     + [p(f"M {x - 7} {y - 4} q 6 -6 13 -1", stroke="#3A2C26", width=3) for x, y in [(226, 130), (258, 124), (290, 130)]]},
    # 8 — küt kahküllü kısa siyah saç, kırmızı yarış tulumu
    {"about": "küt kahkül, kırmızı yarış tulumu", "bg": ("checker", "#FFE6E2", "#F49A92", "#FFFFFF"), "skin": "fair", "face": "round",
     "body": ("racing", "#E2483D", "#B8322A", "#FFFFFF"), "eyes": "big", "iris": "#2A1A12", "lashes": True, "mouth": "smile", "blush": 0.5,
     "brows": [],
     "back": [p("M 144 250 C 134 160, 190 110, 256 110 C 322 110, 378 160, 368 250 C 366 300, 364 330, 356 350 L 156 350 C 148 330, 146 300, 144 250 Z", "#1C1A22", INK)],
     "front": [p("M 160 216 C 156 158, 200 124, 256 124 C 312 124, 356 158, 352 216 C 300 222, 212 222, 160 216 Z", "#1C1A22", INK),
               p("M 156 206 C 150 260, 152 316, 160 350 L 182 350 C 180 300, 180 250, 184 214 Z", "#1C1A22", INK, 5),
               p(mirror("M 156 206 C 150 260, 152 316, 160 350 L 182 350 C 180 300, 180 250, 184 214 Z"), "#1C1A22", INK, 5),
               p("M 196 150 Q 256 132 316 150", stroke="#3E3C4A", width=6),
               p("M 214 194 L 214 214 M 250 192 L 250 216 M 290 194 L 290 214", stroke="#3E3C4A", width=4)]},
    # 9 — yaşlı teyze: gri topuz, yuvarlak gözlük, hardal hırka
    {"about": "yaşlı teyze, gri topuz, gözlük", "bg": ("dots", "#EDF7E0", "#B6D69A", "#FFFFFF"), "skin": "fair", "face": "round",
     "body": ("cardigan", "#E0B04C", "#B8862A", "#F7F1E3"), "eyes": "happy", "mouth": "smile", "blush": 0.4, "wrinkles": True,
     "brows": brows(GRAY_D, 5, 214),
     "back": [circle(256, 112, 42, GRAY, INK, 6), p("M 230 98 Q 256 82 282 98", stroke="#D8D4CE", width=5)],
     "front": [p("M 162 236 C 158 166, 202 128, 256 128 C 310 128, 354 166, 350 236 C 342 198, 318 172, 286 164 C 268 168, 244 168, 226 164 C 194 172, 170 198, 162 236 Z", GRAY, INK),
               p("M 196 160 Q 222 150 246 154", stroke="#D8D4CE", width=4), p("M 266 154 Q 292 150 316 160", stroke="#D8D4CE", width=4),
               p("M 216 408 Q 256 440 296 408", stroke="#FFFFFF", width=6, extra='stroke-dasharray="1 12"')] + glasses("#C08A30")},
    # 10 — kask (yüz göstermek istemeyene): göz açıklığı, kalkık vizör
    {"about": "yarış kaskı, yalnız gözler", "bg": ("checker", "#6A7280", "#2E333C", "#FFFFFF"), "skin": "medium", "face": "oval", "ears": False,
     "body": ("racing", "#3E7BE0", "#2A5AB0", "#FFFFFF"), "eyes": "normal", "iris": "#3A2414", "mouth": "smile",
     "brows": brows("#2A1A14", 8, 222, tilt=3),
     "front": [p("M 138 252 C 130 140, 194 84, 256 84 C 318 84, 382 140, 374 252 C 372 322, 352 372, 318 400 L 194 400 C 160 372, 140 322, 138 252 Z M 180 214 C 204 202, 308 202, 332 214 C 338 238, 336 266, 326 280 C 300 290, 212 290, 186 280 C 176 266, 174 238, 180 214 Z",
                 "#F4F4F2", INK, extra='fill-rule="evenodd"'),
               p("M 238 86 L 238 202 M 274 86 L 274 202", stroke="#E2483D", width=14),
               p("M 196 300 L 316 300 L 306 380 L 206 380 Z", "#2F3236", INK, 4),
               p("M 222 320 L 290 320 M 220 340 L 292 340 M 224 360 L 288 360", stroke="#5A5E66", width=5),
               p("M 164 178 C 196 146, 316 146, 348 178 L 342 200 C 304 182, 208 182, 170 200 Z", "#3A4A62", INK),
               p("M 196 168 Q 230 156 262 158", stroke="#9EC4FF", width=5, extra='opacity="0.7"'),
               circle(166, 196, 9, "#C9CED8", INK, 3), circle(346, 196, 9, "#C9CED8", INK, 3)]},
    # 11 — dalgalı saçlı genç, ince bıyık, boynunda bandana
    {"about": "dalgalı saç, ince bıyık, bandana", "bg": ("stripes", "#FFE0B0", "#FF8E6E", "#FFFFFF"), "skin": "olive", "face": "square",
     "body": ("tee", "#F4F1EA", "#D9D4C8", "#FFFFFF"), "eyes": "normal", "iris": "#4A2C1C", "mouth": "smirk", "nose": "long",
     "brows": brows("#2A1C16", 8, 218, raise_right=5),
     "over_body": [p("M 196 392 C 220 420, 292 420, 316 392 L 308 430 L 256 470 L 204 430 Z", "#D8383A", INK),
                   circle(230, 418, 4, "#FFFFFF"), circle(256, 440, 4, "#FFFFFF"), circle(282, 418, 4, "#FFFFFF"), circle(256, 420, 3, "#FFFFFF")],
     "front": [p("M 230 304 Q 243 297 256 301 Q 269 297 282 304", stroke="#2A1C16", width=7),
               p("M 164 226 C 154 160, 196 108, 252 106 C 312 104, 358 146, 350 214 C 340 200, 334 186, 328 172 C 316 188, 296 194, 276 188 C 282 178, 284 168, 282 158 C 262 178, 230 188, 200 186 C 190 198, 176 212, 164 226 Z", "#3A2418", INK),
               p("M 196 132 Q 236 118 270 130", stroke="#5E3E2C", width=5), p("M 284 128 Q 318 130 338 156", stroke="#5E3E2C", width=5),
               p("M 214 156 Q 240 150 262 156", stroke="#5E3E2C", width=4)]},
    # 12 — uzun dalgalı sarı saç, başında güneş gözlüğü, pembe ceket
    {"about": "uzun dalgalı sarı saç, güneş gözlüğü", "bg": ("rays", "#D2F7F8", "#6ED3DC", "#FFFFFF"), "skin": "light", "face": "heart",
     "body": ("jacket", "#FF8FB8", "#E86A98", "#FFFFFF"), "eyes": "big", "iris": "#3E6FA8", "lashes": True, "mouth": "grin", "blush": 0.45,
     "brows": brows("#B58A3C", 6, 214),
     "back": [p("M 144 236 C 130 146, 192 100, 256 100 C 320 100, 382 146, 368 236 C 364 296, 386 356, 400 430 C 364 452, 322 444, 300 420 L 212 420 C 190 444, 148 452, 112 430 C 126 356, 148 296, 144 236 Z", "#EBC062", INK)],
     "front": [p("M 164 232 C 154 160, 198 118, 256 118 C 314 118, 358 160, 348 232 C 338 198, 318 172, 292 160 C 254 190, 212 200, 178 202 Z", "#EBC062", INK),
               p("M 166 208 C 148 262, 148 334, 170 404 C 186 362, 188 300, 190 238 Z", "#EBC062", INK, 5),
               p(mirror("M 166 208 C 148 262, 148 334, 170 404 C 186 362, 188 300, 190 238 Z"), "#EBC062", INK, 5),
               p("M 206 146 Q 252 130 290 140", stroke="#F7DC94", width=5), p("M 162 300 Q 168 340 176 370", stroke="#F7DC94", width=4),
               f'<rect x="190" y="134" width="56" height="34" rx="14" fill="#2F3236" stroke="{INK}" stroke-width="4"/>',
               f'<rect x="266" y="134" width="56" height="34" rx="14" fill="#2F3236" stroke="{INK}" stroke-width="4"/>',
               p("M 246 148 Q 256 142 266 148", stroke=INK, width=5),
               p("M 200 144 l 14 -4", stroke="#9EC4FF", width=4), p("M 276 144 l 14 -4", stroke="#9EC4FF", width=4)]},
]


# --- 2026-11-01: 16 yeni portre (13–28) + 8 yüzsüz simge (29–36) -----------------------------------------
# Kullanıcı kararları: docs/PROFIL_KISISELLESTIRME.md (meslekler, yarış / sokak, gündelik, farklı ülkelerden).

TURBAN_BLUE = "#2E4A8C"


def headphones(band, cup, accent):
    return [p("M 196 404 C 196 440, 316 440, 316 404", stroke=band, width=10),
            f'<rect x="168" y="388" width="40" height="52" rx="16" fill="{cup}" stroke="{INK}" stroke-width="4"/>',
            f'<rect x="304" y="388" width="40" height="52" rx="16" fill="{cup}" stroke="{INK}" stroke-width="4"/>',
            circle(188, 414, 10, accent), circle(324, 414, 10, accent)]


def sunglasses(lens="#22252B", frame=INK, shape="rect"):
    o = []
    for x in (L_EYE, R_EYE):
        if shape == "aviator":
            o.append(p(f"M {x - 32} {EYE_Y - 14} L {x + 30} {EYE_Y - 14} C {x + 32} {EYE_Y + 14}, {x + 14} {EYE_Y + 28}, {x} {EYE_Y + 28} "
                       f"C {x - 18} {EYE_Y + 28}, {x - 34} {EYE_Y + 12}, {x - 32} {EYE_Y - 14} Z", lens, frame, 5))
        else:
            o.append(f'<rect x="{x - 32}" y="{EYE_Y - 18}" width="64" height="38" rx="13" fill="{lens}" stroke="{frame}" stroke-width="5"/>')
        o.append(p(f"M {x - 20} {EYE_Y - 8} l 16 -4", stroke="#FFFFFF", width=4, extra='opacity="0.55"'))
    o += [p(f"M {L_EYE + 30} {EYE_Y - 10} Q 256 {EYE_Y - 20} {R_EYE - 30} {EYE_Y - 10}", stroke=frame, width=5),
          p(f"M {L_EYE - 32} {EYE_Y - 10} L 166 {EYE_Y - 14}", stroke=frame, width=5),
          p(f"M {R_EYE + 32} {EYE_Y - 10} L 346 {EYE_Y - 14}", stroke=frame, width=5)]
    return o


def splat(cx, cy, r, color, seed=0, opacity=0.9):
    """Çamur / boya sıçraması: tırtıklı leke + yanında iki damla."""
    import math
    pts = []
    for k in range(10):
        a = k * math.pi / 5 + seed
        rr = r * (1.0 if k % 2 == 0 else 0.62 + 0.12 * math.sin(k + seed))
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = f"M {pts[0][0]:.1f} {pts[0][1]:.1f} " + " ".join(
        f"Q {cx + (pts[k][0] - cx) * 1.25:.1f} {cy + (pts[k][1] - cy) * 1.25:.1f} {(pts[k][0] + pts[(k + 1) % 10][0]) / 2:.1f} {(pts[k][1] + pts[(k + 1) % 10][1]) / 2:.1f}"
        for k in range(10)) + " Z"
    a1, a2 = seed + 0.6, seed + 2.4
    return [p(d, color, extra=f'opacity="{opacity}"'),
            circle(cx + r * 1.55 * math.cos(a1), cy + r * 1.55 * math.sin(a1), r * 0.22, color, extra=f'opacity="{opacity}"'),
            circle(cx + r * 1.45 * math.cos(a2), cy + r * 1.45 * math.sin(a2), r * 0.15, color, extra=f'opacity="{opacity}"')]


def braid(x0, y0, x1, y1, n, rx, ry, color, tie=None):
    o = []
    for k in range(n):
        t = k / max(n - 1, 1)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        o.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{rx}" ry="{ry}" fill="{color}" stroke="{INK}" stroke-width="4"/>')
        o.append(p(f"M {x - rx * 0.6:.0f} {y - ry * 0.2:.0f} Q {x:.0f} {y + ry * 0.5:.0f} {x + rx * 0.6:.0f} {y - ry * 0.2:.0f}", stroke=INK, width=2.5, extra='opacity="0.35"'))
    if tie:
        o.append(circle(x1, y1 + ry + 4, 6, tie, INK, 3))
    return o


def dots_on(path_points, r, color):
    return [circle(x, y, r, color) for x, y in path_points]


PRESETS_V2 = {
    # 13 — BOYACI (K): mavi bandana, kısa kızıl saç, yanağında boya, boynunda toz maskesi, boya lekeli açık tulum
    13: {"about": "boyacı: bandana, boya lekeleri, boynunda maske", "bg": ("dots", "#DDF0FF", "#8EC5F0", "#FFFFFF"),
         "skin": "fair", "face": "heart", "body": ("coverall", "#ECE7DD", "#C2BAAA", "#3E7BE0"),
         "eyes": "big", "iris": "#4E7A3A", "lashes": True, "mouth": "grin", "blush": 0.4,
         "brows": brows("#7A3B2A", 6, 214),
         "back": [p("M 156 236 C 146 170, 190 120, 256 118 C 322 120, 366 170, 356 236 C 358 264, 352 286, 344 300 L 168 300 C 160 286, 154 264, 156 236 Z", "#7A3B2A", INK)],
         "over_body": [circle(x, y, r, c) for x, y, r, c in [(118, 486, 11, "#E2483D"), (136, 504, 5, "#E2483D"), (100, 506, 4, "#E2483D"),
                                                            (384, 474, 12, "#F2C14E"), (404, 494, 5, "#F2C14E"), (330, 506, 8, "#4E9A62"),
                                                            (176, 420, 6, "#3E7BE0")]]
                      + [p("M 210 392 C 192 382, 182 368, 178 350", stroke="#8C95A6", width=4), p(mirror("M 210 392 C 192 382, 182 368, 178 350"), stroke="#8C95A6", width=4),
                         p("M 204 396 C 208 378, 304 378, 308 396 C 304 428, 208 428, 204 396 Z", "#F6F5F1", INK, 4),
                         circle(232, 404, 9, "#C9CED8", INK, 3), circle(280, 404, 9, "#C9CED8", INK, 3)],
         "on_face": [circle(198, 300, 6.5, "#3E7BE0"), circle(211, 309, 3.5, "#3E7BE0"), circle(318, 230, 4, "#F2C14E")],
         "front": [p("M 162 228 C 154 162, 200 122, 258 122 C 316 122, 358 162, 350 228 C 340 196, 322 176, 296 166 C 266 186, 218 190, 178 198 Z", "#7A3B2A", INK),
                   p("M 158 196 C 196 168, 316 168, 354 196 L 350 216 C 312 192, 200 192, 162 216 Z", "#3E7BE0", INK),
                   circle(214, 186, 3.5, "#FFFFFF"), circle(256, 181, 3.5, "#FFFFFF"), circle(298, 186, 3.5, "#FFFFFF"), circle(236, 192, 3, "#FFFFFF"), circle(278, 192, 3, "#FFFFFF"),
                   p("M 346 196 L 384 176 L 376 204 Z", "#3E7BE0", INK, 4), p("M 348 206 L 382 222 L 356 228 Z", "#3E7BE0", INK, 4),
                   circle(352, 204, 9, "#2F62C0", INK, 4),
                   circle(290, 150, 5, "#F2C14E")]},
    # 17 — DRİFTÇİ (K): siyah asimetrik kesim, mor uçlar, boynunda kulaklık, siyah bomber
    17: {"about": "driftçi: asimetrik siyah saç, mor uçlar, kulaklık", "bg": ("stripes", "#EDE2FF", "#9A7BEA", "#FFFFFF"),
         "skin": "fair", "face": "oval", "body": ("bomber", "#2A2D36", "#1A1C22", "#B07CFF"),
         "eyes": "normal", "iris": "#2A1A12", "lashes": True, "mouth": "smirk", "blush": 0.3,
         "brows": brows("#1C1A22", 6, 216, raise_right=4),
         "back": [p("M 150 240 C 140 156, 194 108, 258 108 C 322 108, 374 156, 364 240 C 362 292, 366 330, 374 362 L 300 352 L 214 352 L 140 362 C 146 330, 152 292, 150 240 Z", "#1C1A22", INK),
                  p("M 140 362 C 144 342, 148 326, 150 312 L 188 318 L 190 354 Z", "#B07CFF", INK, 4),
                  p(mirror("M 140 362 C 144 342, 148 326, 150 312 L 188 318 L 190 354 Z"), "#B07CFF", INK, 4)],
         "over_body": headphones("#2F3236", "#2F3236", "#B07CFF"),
         "front": [p("M 160 230 C 150 158, 200 118, 262 118 C 320 118, 360 158, 352 226 C 332 194, 302 176, 270 170 C 242 198, 198 218, 160 230 Z", "#1C1A22", INK),
                   p("M 230 140 Q 268 126 302 140", stroke="#B07CFF", width=7), p("M 194 172 Q 226 152 252 150", stroke="#3A3846", width=5),
                   circle(352, 290, 5, "#B07CFF", INK, 2)]},
    # 19 — MOTORCU (E): siyah bandana, koyu güneş gözlüğü, uzun gri sakal, deri yelek
    19: {"about": "motorcu: bandana, güneş gözlüğü, uzun gri sakal, deri yelek", "bg": ("checker", "#FFE3C4", "#F0A060", "#FFFFFF"),
         "skin": "light", "face": "square", "body": ("leather", "#3A2E2A", "#241C19", "#4A505A"),
         "eyes": "normal", "iris": "#3E5A7A", "mouth": "smile", "nose": "long", "wrinkles": True,
         "brows": brows(GRAY_D, 9, 212),
         "back": [p("M 344 194 C 380 196, 402 220, 408 250 C 388 244, 368 230, 352 214 Z", "#2B2E36", INK),
                  p("M 346 204 C 372 222, 384 250, 382 282 C 366 268, 354 246, 348 222 Z", "#2B2E36", INK)],
         "on_face": [p("M 168 238 C 164 320, 184 404, 218 456 C 234 480, 246 488, 256 488 C 266 488, 278 480, 294 456 C 328 404, 348 320, 344 238 L 330 240 C 330 280, 322 300, 304 310 C 290 304, 270 300, 256 304 C 242 300, 222 304, 208 310 C 190 300, 182 280, 182 240 Z", "#CFCBC4", INK, 5),
                     p("M 204 340 q 8 40 30 76", stroke="#AAA59E", width=4), p("M 308 340 q -8 40 -30 76", stroke="#AAA59E", width=4),
                     p("M 256 372 L 256 452", stroke="#AAA59E", width=4), p("M 230 360 q 2 40 12 70", stroke="#AAA59E", width=3), p("M 282 360 q -2 40 -12 70", stroke="#AAA59E", width=3)],
         "front": [p("M 212 306 C 226 288, 250 290, 256 297 C 262 290, 286 288, 300 306 C 304 318, 292 320, 282 312 C 272 304, 262 305, 256 308 C 250 305, 240 304, 230 312 C 220 320, 208 318, 212 306 Z", GRAY, INK, 4),
                   p("M 156 214 C 150 146, 200 102, 256 102 C 312 102, 362 146, 356 214 C 306 196, 206 196, 156 214 Z", "#2B2E36", INK)]
                  + dots_on([(196, 160), (230, 140), (270, 134), (306, 148), (330, 176), (214, 186), (252, 172), (292, 180), (182, 196), (330, 200)], 4.5, "#E9E6E0")
                  + sunglasses()},
    # 25 — SARIKLI (E): lacivert katlı sarık, düzgün siyah sakal, ceket
    25: {"about": "sarıklı: lacivert katlı sarık, düzgün siyah sakal", "bg": ("rays", "#FFE6B8", "#F2A13A", "#FFFFFF"),
         "skin": "tan", "face": "oval", "ears": False, "body": ("jacket", "#6A7A8C", "#4E5C6C", "#F4F1EA"),
         "eyes": "normal", "iris": "#2A1A12", "mouth": "smile", "nose": "long",
         "brows": brows("#1A1412", 9, 216),
         "on_face": [p("M 170 232 C 166 300, 184 356, 214 384 C 230 398, 244 404, 256 404 C 268 404, 282 398, 298 384 C 328 356, 346 300, 342 232 L 330 234 C 330 270, 322 292, 304 304 C 290 300, 270 296, 256 300 C 242 296, 222 300, 208 304 C 190 292, 182 270, 182 234 Z", "#1E1614", INK, 5),
                     p("M 206 334 q 10 24 26 38", stroke="#3A2C28", width=4), p("M 306 334 q -10 24 -26 38", stroke="#3A2C28", width=4)],
         "front": [p("M 214 304 C 228 292, 250 292, 256 298 C 262 292, 284 292, 298 304 C 290 312, 274 312, 256 306 C 238 312, 222 312, 214 304 Z", "#1E1614", INK, 4),
                   p("M 148 222 C 136 132, 194 72, 256 72 C 318 72, 376 132, 364 222 C 334 204, 300 196, 256 196 C 212 196, 178 204, 148 222 Z", TURBAN_BLUE, INK),
                   p("M 158 196 C 196 148, 286 116, 356 156", stroke="#4A68AE", width=9), p("M 166 158 C 214 112, 296 98, 344 122", stroke="#4A68AE", width=8),
                   p("M 156 210 C 196 178, 252 166, 300 166", stroke="#1E3466", width=5), p("M 190 110 C 236 94, 292 92, 326 104", stroke="#1E3466", width=5),
                   p("M 230 198 L 256 160 L 282 198", stroke="#1E3466", width=6)]},
    # 14 — KAYNAKÇI (E): kaynak maskesi alnına kaldırılmış, isli yanak, kısa sakal, koyu tulum, arkada kıvılcımlar
    14: {"about": "kaynakçı: maske alnında, isli yanak, kısa sakal", "bg": ("rays", "#FFE0B0", "#F08A3A", "#FFFFFF"),
         "skin": "medium", "face": "square", "body": ("coverall", "#56626E", "#3C4652", "#E9E3D6"),
         "eyes": "normal", "iris": "#4A2C1C", "mouth": "smile", "nose": "wide",
         "brows": brows("#2A1C16", 9, 218, tilt=-2),
         "back": [p(f"M {x} {y - 12} L {x + 4} {y - 4} L {x + 12} {y} L {x + 4} {y + 4} L {x} {y + 12} L {x - 4} {y + 4} L {x - 12} {y} L {x - 4} {y - 4} Z", "#FFF3B0")
                  for x, y in [(96, 120), (420, 96), (446, 210), (70, 230), (380, 52)]],
         "on_face": [p("M 168 234 C 166 290, 186 340, 216 364 C 232 376, 246 380, 256 380 C 266 380, 280 376, 296 364 C 326 340, 346 290, 344 234 L 332 236 C 330 280, 318 300, 300 308 C 286 304, 268 300, 256 304 C 244 300, 226 304, 212 308 C 194 300, 182 280, 180 236 Z", "#3A2A22", extra='opacity="0.85"'),
                     f'<ellipse cx="196" cy="300" rx="20" ry="11" fill="#5A5E66" opacity="0.35"/>', f'<ellipse cx="300" cy="226" rx="16" ry="8" fill="#5A5E66" opacity="0.3"/>'],
         "front": [p("M 218 304 C 230 292, 250 292, 256 298 C 262 292, 282 292, 294 304 C 288 312, 272 312, 256 306 C 240 312, 224 312, 218 304 Z", "#3A2A22", INK, 4),
                   p("M 164 226 C 160 190, 170 168, 184 156 L 196 176 C 186 190, 180 206, 180 228 Z", "#2A1C16"),
                   p(mirror("M 164 226 C 160 190, 170 168, 184 156 L 196 176 C 186 190, 180 206, 180 228 Z"), "#2A1C16"),
                   p("M 166 156 C 168 96, 208 60, 256 60 C 304 60, 344 96, 346 156 L 334 196 C 302 184, 210 184, 178 196 Z", "#3B3F47", INK),
                   f'<rect x="208" y="104" width="96" height="42" rx="9" fill="#2C5E50" stroke="{INK}" stroke-width="5"/>',
                   p("M 218 116 l 22 0", stroke="#8FD3B8", width=5, extra='opacity="0.8"'),
                   p("M 200 82 Q 256 68 312 82", stroke="#5A5F6A", width=6),
                   p("M 164 198 C 200 184, 312 184, 348 198", stroke="#24272D", width=12),
                   circle(170, 200, 11, "#8E97A3", INK, 4), circle(342, 200, 11, "#8E97A3", INK, 4)]},
    # 15 — LASTİKÇİ (E): turuncu örgü bere, kulağında kurşun kalem, koyu ten, gri-mavi tulum
    15: {"about": "lastikçi: örgü bere, kulağında kalem", "bg": ("stripes", "#FFF0C2", "#F2C14E", "#FFFFFF"),
         "skin": "dark", "face": "round", "body": ("coverall", "#5D7389", "#43566A", "#F2C14E"),
         "eyes": "normal", "iris": "#2A1A12", "mouth": "grin", "nose": "wide",
         "brows": brows("#1A1210", 9, 218),
         "front": [p("M 156 214 C 150 136, 200 92, 256 92 C 312 92, 362 136, 356 214 Z", "#E0623A", INK),
                   p("M 194 124 Q 256 104 318 124", stroke="#F08A5E", width=6),
                   p("M 150 216 C 194 192, 318 192, 362 216 L 358 244 C 316 222, 196 222, 154 244 Z", "#B8452A", INK)]
                  + [p(f"M {x} {202 if abs(x - 256) < 70 else 210} L {x} {228 if abs(x - 256) < 70 else 236}", stroke="#8E3420", width=4) for x in range(176, 344, 16)]
                  + [p("M 340 214 L 354 208 L 392 292 L 380 300 Z", "#F2C14E", INK, 4), p("M 340 214 L 354 208 L 348 196 L 336 202 Z", "#FF8FA8", INK, 4),
                     p("M 380 300 L 392 292 L 392 312 Z", "#E8C9A0", INK, 3), circle(390, 306, 2.5, INK)]},
    # 16 — ÇEKİCİ ŞOFÖRÜ (K): lacivert kep (çekici kancalı arma), at kuyruğu, turuncu reflektif yelek
    16: {"about": "çekici şoförü: kep, at kuyruğu, reflektif yelek", "bg": ("checker", "#DDF5F3", "#7CCFC6", "#FFFFFF"),
         "skin": "medium", "face": "oval", "body": ("vest", "#FF7A1C", "#D85E0A", "#2F3B4E"),
         "eyes": "big", "iris": "#4A2E1A", "lashes": True, "mouth": "smile", "blush": 0.35,
         "brows": brows("#3A2418", 6, 216),
         "back": [p("M 326 186 C 384 190, 404 250, 392 322 C 386 362, 368 384, 350 396 C 356 352, 356 300, 342 252 Z", "#4A2E1E", INK),
                  p("M 360 220 Q 384 268 378 330", stroke="#6A4630", width=5)],
         "front": [p("M 166 238 C 162 214, 166 202, 176 196 L 194 204 C 186 214, 182 226, 182 244 Z", "#4A2E1E"),
                   p(mirror("M 166 238 C 162 214, 166 202, 176 196 L 194 204 C 186 214, 182 226, 182 244 Z"), "#4A2E1E"),
                   p("M 162 202 C 158 136, 204 100, 256 100 C 308 100, 354 136, 350 202 C 320 190, 192 190, 162 202 Z", "#2F3B4E", INK),
                   p("M 200 132 Q 256 116 312 132", stroke="#4A5A74", width=6), circle(256, 102, 7, "#24304A", INK, 4),
                   p("M 158 200 C 200 184, 312 184, 354 200 C 362 216, 342 224, 322 218 C 282 208, 230 208, 190 218 C 170 224, 150 216, 158 200 Z", "#24304A", INK),
                   circle(256, 156, 21, "#F2C14E", INK, 4),
                   p("M 256 142 L 271 167 L 241 167 Z", "none", "#E2483D", 5)]},   # arıza üçgeni (yol yardımı)
    # 18 — RALLİ PİLOTU (E): kısa dağınık saç, yüzde çamur, beyaz-mavi yarış tulumu
    18: {"about": "ralli pilotu: dağınık saç, yüzde çamur, ralli tulumu", "bg": ("rays", "#F5E6C8", "#D6A85E", "#FFFFFF"),
         "skin": "medium_light", "face": "square", "body": ("racing", "#F4F4F2", "#C9CCD2", "#2F62C0"),
         "eyes": "normal", "iris": "#3E5A7A", "mouth": "grin",
         "brows": brows("#6A4226", 8, 218, raise_right=4),
         "over_body": splat(124, 482, 18, "#8F6239", 0.3) + splat(388, 474, 20, "#8F6239", 1.7),
         "on_face": splat(200, 306, 20, "#8F6239", 0.9, 0.85) + splat(312, 212, 13, "#8F6239", 2.2, 0.8),
         "front": [p("M 164 216 C 156 150, 200 108, 256 108 C 312 108, 356 150, 348 216 C 338 198, 324 186, 306 180 L 294 162 L 274 178 L 254 156 L 236 178 L 214 162 L 202 186 C 186 192, 172 202, 164 216 Z", "#8A5A32", INK),
                   p("M 214 138 Q 256 124 300 138", stroke="#A8784A", width=5)]},
    # 20 — RETRO TUNER (K): 80'ler kabarık perma, pembe camlı pilot gözlüğü, renk bloklu rüzgârlık
    20: {"about": "retro tuner: kabarık perma, pilot gözlüğü, rüzgârlık", "bg": ("rays", "#FFE0F0", "#FF8FC4", "#FFFFFF"),
         "skin": "medium_light", "face": "heart", "body": ("windbreaker", "#3BC6C9", "#FFD23F", "#FF5FA2"),
         "eyes": "big", "iris": "#4A2E1A", "lashes": True, "mouth": "grin", "blush": 0.4,
         "brows": brows("#7A4A24", 6, 214),
         "back": [circle(x, y, r, "#B5703A", INK, 5) for x, y, r in
                  [(150, 180, 56), (362, 180, 56), (196, 112, 56), (316, 112, 56), (256, 92, 56), (122, 252, 54), (390, 252, 54),
                   (126, 322, 50), (386, 322, 50), (150, 376, 42), (362, 376, 42)]],
         "over_body": [p("M 158 320 L 170 346 L 146 346 Z", "#3BC6C9", INK, 3), p("M 354 320 L 366 346 L 342 346 Z", "#FFD23F", INK, 3)],
         "front": [circle(x, y, r, "#B5703A", INK, 4) for x, y, r in
                   [(180, 176, 30), (216, 146, 32), (256, 136, 32), (296, 146, 32), (332, 176, 30), (164, 212, 22), (348, 212, 22)]]
                  + [p(f"M {x - 12} {y - 8} q 10 -10 22 -2", stroke="#D08E52", width=4) for x, y in [(216, 144), (256, 134), (296, 144), (180, 174), (332, 174)]]
                  + sunglasses("#FF8FC4", "#C9A23A", "aviator")},
    # 21 — TAKSİCİ (E): ekoseli kasket, gür siyah bıyık, beyaz gömlek + koyu yelek, yelekte taksi tepeliği
    21: {"about": "taksici: kasket, gür bıyık, yelek", "bg": ("dots", "#FFF4C2", "#F5C842", "#FFFFFF"),
         "skin": "olive", "face": "square", "body": ("waistcoat", "#2F3236", "#1E2024", "#C9A23A"),
         "eyes": "normal", "iris": "#3A2414", "mouth": "smile", "nose": "wide",
         "brows": brows("#1A1210", 10, 216, tilt=-2),
         "over_body": [f'<rect x="146" y="452" width="56" height="26" rx="6" fill="#F5C842" stroke="{INK}" stroke-width="4"/>',
                       p("M 154 465 L 194 465", stroke=INK, width=4, extra='stroke-dasharray="6 5"')],
         "front": [p("M 212 302 C 222 284, 248 286, 256 294 C 264 286, 290 284, 300 302 C 304 316, 294 320, 284 312 C 274 304, 262 304, 256 307 C 250 304, 238 304, 228 312 C 218 320, 208 316, 212 302 Z", "#1A1210", INK, 4),
                   p("M 166 230 C 162 210, 166 194, 176 184 L 192 198 C 184 208, 182 220, 182 236 Z", "#1A1210"),
                   p(mirror("M 166 230 C 162 210, 166 194, 176 184 L 192 198 C 184 208, 182 220, 182 236 Z"), "#1A1210"),
                   p("M 156 196 C 154 138, 200 102, 262 102 C 324 102, 364 136, 360 186 C 356 198, 344 202, 328 200 L 180 204 C 168 206, 158 204, 156 196 Z", "#7E848E", INK),
                   p("M 196 116 L 206 196 M 236 106 L 240 200 M 276 104 L 278 200 M 316 110 L 312 198", stroke="#5E646E", width=4),
                   p("M 168 156 Q 256 132 352 150", stroke="#5E646E", width=4), p("M 160 184 Q 256 160 358 176", stroke="#5E646E", width=4),
                   p("M 172 196 C 208 182, 302 178, 356 188 C 368 198, 364 214, 348 216 C 300 206, 214 208, 180 218 C 166 216, 164 202, 172 196 Z", "#5E646E", INK)]},
    # 22 — KURYE (K): yeşil kep, iki yanda örgüler, koyu ten, rüzgârlık, göğüste çanta askısı
    22: {"about": "kurye: kep, örgüler, çanta askısı", "bg": ("stripes", "#DFF7D8", "#86D07A", "#FFFFFF"),
         "skin": "dark", "face": "oval", "body": ("windbreaker", "#3FA34D", "#2C7A38", "#F2F2F2"),
         "eyes": "big", "iris": "#2A1A12", "lashes": True, "mouth": "grin", "blush": 0.25,
         "brows": brows("#1A1210", 6, 216),
         "back": braid(146, 214, 140, 384, 9, 13, 12, "#1A1210", "#F2C14E") + braid(170, 224, 168, 368, 8, 12, 11, "#1A1210")
                 + braid(366, 214, 372, 384, 9, 13, 12, "#1A1210", "#F2C14E") + braid(342, 224, 344, 368, 8, 12, 11, "#1A1210"),
         "over_body": [p("M 132 412 L 162 400 L 396 530 L 350 530 Z", "#2B2E36", INK),
                       f'<rect x="232" y="452" width="34" height="26" rx="5" fill="#C9CED8" stroke="{INK}" stroke-width="4" transform="rotate(28 249 465)"/>',
                       circle(162, 300, 6, "#F2C14E", INK, 2), circle(350, 300, 6, "#F2C14E", INK, 2)],
         "front": [p("M 166 236 C 162 214, 166 202, 176 196 L 194 204 C 186 214, 182 226, 182 244 Z", "#1A1210"),
                   p(mirror("M 166 236 C 162 214, 166 202, 176 196 L 194 204 C 186 214, 182 226, 182 244 Z"), "#1A1210"),
                   p("M 162 202 C 158 136, 204 100, 256 100 C 308 100, 354 136, 350 202 C 320 190, 192 190, 162 202 Z", "#2E8C3C", INK),
                   p("M 200 132 Q 256 116 312 132", stroke="#58B866", width=6), circle(256, 102, 7, "#226E2E", INK, 4),
                   p("M 158 200 C 200 184, 312 184, 354 200 C 362 216, 342 224, 322 218 C 282 208, 230 208, 190 218 C 170 224, 150 216, 158 200 Z", "#226E2E", INK),
                   p("M 238 168 L 262 150 L 262 162 L 278 162 L 278 174 L 262 174 L 262 186 Z", "#F2F2F2", INK, 3)]},
    # 23 — YENİ EHLİYETLİ (E): diş telli kocaman gülüş, dikleşmiş sarı saç, boynunda araba anahtarlı ip
    23: {"about": "yeni ehliyetli: diş teli, boynunda araba anahtarı", "bg": ("rays", "#E2F8D2", "#9ADB72", "#FFFFFF"),
         "skin": "fair", "face": "round", "body": ("hoodie", "#5B8BD0", "#3E6AAE", "#FFFFFF"),
         "eyes": "big", "iris": "#3E6FA8", "mouth": "grin", "freckles": "#D9A07A", "blush": 0.35,
         "brows": brows("#B58A3C", 6, 212, raise_right=3),
         "over_body": [p("M 214 398 L 246 468 M 298 398 L 266 468", stroke="#E2483D", width=8),
                       f'<rect x="234" y="462" width="44" height="30" rx="10" fill="#2F3236" stroke="{INK}" stroke-width="4"/>',
                       circle(256, 477, 6, "#E2483D"), p("M 256 492 L 256 520 M 256 506 L 266 506 M 256 516 L 264 516", stroke="#C9CED8", width=6)],
         "front": [p("M 230 312 Q 256 320 282 312", stroke="#9AA3AF", width=3)]
                  + [f'<rect x="{x - 3}" y="{311 + abs(x - 256) * -0.12 + 3:.1f}" width="6" height="5" fill="#C9CED8" stroke="#7A828E" stroke-width="1"/>' for x in (236, 249, 263, 276)]
                  + [p("M 160 222 C 152 156, 196 116, 256 116 L 236 84 L 266 110 L 278 76 L 292 114 L 322 90 L 314 124 C 344 140, 360 176, 352 222 C 340 196, 320 178, 296 170 C 264 186, 220 190, 184 196 C 174 202, 166 212, 160 222 Z", "#E0B24A", INK),
                     p("M 206 146 Q 240 132 276 138", stroke="#F2D27E", width=5)]},
    # 24 — HEVESLİ EMEKLİ (K): ak saç, puantiyeli ipek eşarp (çenede düğüm), inci kolye, pembe hırka
    24: {"about": "hevesli emekli: ak saç, ipek eşarp, inci kolye", "bg": ("dots", "#EEE6FF", "#B8A4EE", "#FFFFFF"),
         "skin": "light", "face": "round", "body": ("cardigan", "#E96F86", "#C44E68", "#F7F1E3"),
         "eyes": "happy", "mouth": "smile", "blush": 0.4, "wrinkles": True,
         "brows": brows("#B8B4AE", 5, 214),
         "back": [p("M 148 232 C 140 146, 196 98, 256 98 C 316 98, 372 146, 364 232 C 366 288, 352 332, 330 362 L 182 362 C 160 332, 146 288, 148 232 Z", "#3E6FC4", INK)],
         "over_body": [circle(x, y, 6, "#F7F4EC", INK, 2) for x, y in [(212, 404), (226, 418), (242, 426), (258, 428), (274, 426), (290, 418), (304, 404)]],
         "front": [p("M 168 234 C 170 194, 206 168, 256 168 C 306 168, 342 194, 344 234 C 322 214, 292 204, 256 204 C 220 204, 190 214, 168 234 Z", "#EFEDEA", INK),
                   p("M 196 186 Q 226 176 252 178", stroke="#FFFFFF", width=4),
                   p("M 146 236 C 136 146, 194 96, 256 96 C 318 96, 376 146, 366 236 C 352 196, 316 172, 256 170 C 196 172, 160 196, 146 236 Z", "#3E6FC4", INK),
                   p("M 146 236 C 150 300, 176 350, 220 382 L 232 368 C 196 338, 176 294, 170 240 Z", "#3E6FC4", INK, 5),
                   p(mirror("M 146 236 C 150 300, 176 350, 220 382 L 232 368 C 196 338, 176 294, 170 240 Z"), "#3E6FC4", INK, 5),
                   p("M 238 380 L 210 420 L 236 414 Z", "#3E6FC4", INK, 4), p("M 274 380 L 304 418 L 278 414 Z", "#3E6FC4", INK, 4),
                   circle(256, 380, 16, "#3360B0", INK, 4)]
                  + dots_on([(200, 130), (240, 116), (282, 116), (320, 132), (176, 168), (338, 168), (216, 150), (258, 140), (298, 150), (162, 206), (350, 206), (164, 262), (348, 262), (178, 312), (334, 312)], 5, "#FFFFFF")},
    # 26 — LATİN (K): orta ayrımlı uzun siyah saç, omuzdan inen kalın örgü, saçta kırmızı çiçek, işlemeli bluz
    26: {"about": "Latin: uzun örgü, saçta çiçek, işlemeli yaka", "bg": ("stripes", "#FFE2EC", "#F58FB0", "#FFFFFF"),
         "skin": "tan", "face": "heart", "body": ("blouse", "#FFFFFF", "#E8E2D8", "#E2483D"),
         "eyes": "big", "iris": "#3A2414", "lashes": True, "mouth": "grin", "blush": 0.35,
         "brows": brows("#1E1410", 6, 214),
         "back": [p("M 146 240 C 136 152, 194 104, 256 104 C 318 104, 376 152, 366 240 C 364 290, 360 320, 352 340 L 160 340 C 152 320, 148 290, 146 240 Z", "#2A1A14", INK)],
         "over_body": [f'<ellipse cx="{x}" cy="{y}" rx="24" ry="19" fill="#2A1A14" stroke="{INK}" stroke-width="4" transform="rotate(-20 {x} {y})"/>'
                       for x, y in [(338, 330), (346, 360), (352, 390), (356, 420), (358, 450)]]
                      + [circle(358, 474, 10, "#E2483D", INK, 3), circle(162, 300, 13, "none", "#F2C14E", 5), circle(350, 300, 13, "none", "#F2C14E", 5)],
         "front": [p("M 160 232 C 152 160, 198 118, 256 118 C 314 118, 360 160, 352 232 C 334 196, 298 168, 256 160 C 214 168, 178 196, 160 232 Z", "#2A1A14", INK),
                   p("M 256 122 L 256 160", stroke="#4A3428", width=4), p("M 206 146 Q 230 134 250 132", stroke="#4A3428", width=4), p("M 262 132 Q 290 134 310 148", stroke="#4A3428", width=4)]
                  + [circle(186 + dx, 176 + dy, 11, "#E2483D", INK, 3) for dx, dy in [(0, -12), (11, -4), (7, 10), (-7, 10), (-11, -4)]]
                  + [circle(186, 176, 7, "#F2C14E", INK, 2.5)]},
    # 27 — DOĞU ASYALI (E): yandan ayrımlı düzgün siyah saç, kalın turkuaz çerçeveli gözlük, hardal balıkçı yaka
    27: {"about": "Doğu Asyalı: düzgün saç, renkli gözlük, balıkçı yaka", "bg": ("checker", "#E6F4FF", "#9CC8EE", "#FFFFFF"),
         "skin": "light", "face": "oval", "body": ("turtleneck", "#E0A93A", "#BF8A22", "#FFFFFF"),
         "eyes": "normal", "iris": "#2A1A12", "mouth": "smile",
         "brows": brows("#1C1A22", 7, 216),
         "over_body": [p("M 206 366 C 214 398, 298 398, 306 366 L 316 400 C 296 428, 216 428, 196 400 Z", "#E0A93A", INK)]
                      + [p(f"M {x} {378 + abs(x - 256) * 0.1:.0f} L {x} {412 - abs(x - 256) * 0.05:.0f}", stroke="#BF8A22", width=4) for x in range(214, 304, 14)],
         "front": [p("M 162 224 C 154 152, 204 108, 258 108 C 316 108, 358 152, 350 224 C 342 190, 324 166, 300 154 C 262 146, 222 152, 198 168 C 182 182, 170 202, 162 224 Z", "#1C1A22", INK),
                   p("M 218 118 C 210 136, 206 150, 206 166", stroke="#3A3846", width=4), p("M 228 128 Q 276 116 320 136", stroke="#3A3846", width=5)]
                  + glasses("#2BB3A8")},
    # 28 — KUZEYLİ (K): ponponlu kırmızı örgü bere, iki sarı örgü, çil, mavi kazak (beyaz desen bandı)
    28: {"about": "Kuzeyli: ponponlu bere, sarı örgüler, çil", "bg": ("dots", "#E2F2FF", "#9ED0F2", "#FFFFFF"),
         "skin": "light", "face": "round", "body": ("tee", "#3E6FA8", "#2E5A8C", "#FFFFFF"),
         "eyes": "big", "iris": "#3E6FA8", "lashes": True, "mouth": "grin", "blush": 0.5, "freckles": "#D08060",
         "brows": brows("#B58A3C", 6, 214),
         "over_body": [p("M 120 446 C 196 482, 316 482, 392 446", stroke="#F4F1EA", width=20)]
                       + [p(f"M {x - 7} {465 + (x - 256) ** 2 * 0.0004:.0f} l 7 -7 l 7 7 l -7 7 Z", "#D8383A") for x in range(160, 360, 28)]
                       + [f'<ellipse cx="{x}" cy="{y}" rx="17" ry="15" fill="#EBC062" stroke="{INK}" stroke-width="4"/>'
                          for x, y in [(164, 300), (160, 328), (158, 356), (158, 384), (160, 412), (352, 412), (354, 384), (354, 356), (352, 328), (348, 300)]]
                       + [circle(160, 434, 8, "#D8383A", INK, 3), circle(352, 434, 8, "#D8383A", INK, 3)],
         "front": [p("M 166 232 C 166 196, 204 170, 256 170 C 308 170, 346 196, 346 232 C 322 212, 290 206, 256 206 C 222 206, 190 212, 166 232 Z", "#EBC062", INK),
                   p("M 156 210 C 150 132, 200 92, 256 92 C 312 92, 362 132, 356 210 Z", "#D8383A", INK),
                   p("M 150 212 C 194 188, 318 188, 362 212 L 358 240 C 316 218, 196 218, 154 240 Z", "#F4F1EA", INK)]
                  + [p(f"M {x - 8} 214 l 8 -8 l 8 8 l -8 8 Z", "#D8383A") for x in range(178, 340, 24)]
                  + [p("M 196 150 l 10 -10 l 10 10 M 236 136 l 10 -10 l 10 10 M 276 136 l 10 -10 l 10 10 M 306 150 l 10 -10 l 10 10", stroke="#F4F1EA", width=5),
                     circle(256, 86, 26, "#F4F1EA", INK, 5), p("M 240 78 q 14 -10 28 0", stroke="#D9D4C8", width=4)]},
}


def build_icon(n, spec):
    defs, layers = [], []
    d, o = background(*spec["bg"]); defs.append(d); layers += o
    if spec.get("defs"):
        defs.append(spec["defs"])
    layers += spec["icon"]
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">\n'
           f'  <!-- HAZIR AVATAR {n:02d} (yüzsüz simge): {spec["about"]} (tools/avatars/make_presets.py üretir, elle düzenleme) -->\n'
           "  <defs>" + "".join(defs) + "</defs>\n  " + "\n  ".join(x for x in layers if x) + "\n</svg>\n")
    with open(os.path.join(OUT, f"preset_{n:02d}.svg"), "w") as f:
        f.write(svg)


def _wheel_icon():
    import math
    o = [circle(262, 266, 168, "#000000", extra='opacity="0.18"')]   # gölge
    spoke = "M 232 256 L 112 238 L 112 290 L 226 300 Z"
    o += [p(spoke, "#A7AFBC", INK, 6), p(mirror(spoke), "#A7AFBC", INK, 6),
          p("M 226 290 L 230 404 L 282 404 L 286 290 Z", "#A7AFBC", INK, 6),
          circle(256, 256, 156, "none", INK, 54), circle(256, 256, 156, "none", "#2E3138", 42),
          circle(256, 256, 156, "none", "#4A4E58", 8, 'stroke-dasharray="3 14"'),
          p("M 140 160 A 156 156 0 0 1 228 104", stroke="#6E7480", width=10, extra='opacity="0.8"'),
          p("M 238 96 L 274 96 L 274 124 L 238 124 Z", "#E2483D", INK, 5),
          circle(256, 264, 58, "#3A3D46", INK, 6), circle(256, 264, 34, "none", "#F2C14E", 7),
          circle(256, 264, 10, "#F2C14E")]
    for a in (200, 340):   # parmak tutma çıkıntıları
        r = math.radians(a)
        o.append(circle(256 + 156 * math.cos(r), 256 + 156 * math.sin(r), 9, "#5A5E68", INK, 3))
    return o


def _turbo_icon():
    import math
    pts = []
    for k in range(0, 73):   # salyangoz gövde: tepeden saat yönünde dışa açılan spiral (r 96 → 150)
        t = k / 72 * 2 * math.pi * 1.04
        rr = 96 + 54 * (k / 72)
        pts.append((240 + rr * math.cos(t - math.pi / 2), 280 + rr * math.sin(t - math.pi / 2)))
    spiral = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"
    o = [p(spiral, "#000000", extra='opacity="0.18" transform="translate(8,10)"'),
         p("M 236 130 L 404 130 L 404 202 L 300 202 Z", "#000000", extra='opacity="0.18" transform="translate(8,10)"'),
         p("M 236 130 L 404 130 L 404 202 L 300 202 Z", "#B8C0CA", INK, 6),   # çıkış borusu gövdenin arkasından çıkar
         f'<rect x="392" y="116" width="34" height="100" rx="8" fill="#9AA3AF" stroke="{INK}" stroke-width="6"/>',
         p("M 300 146 L 386 146", stroke="#E6EAEE", width=7),
         p(spiral, "#C7CED6", INK, 7),
         p("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts[30:66]), stroke="#E9EDF1", width=8, extra='opacity="0.9"'),
         circle(240, 280, 90, "#8E97A3", INK, 6), circle(240, 280, 68, "#3A3D46", INK, 6)]
    for k in range(9):   # kompresör kanatları
        a = k * 2 * math.pi / 9
        x0, y0 = 240 + 14 * math.cos(a), 280 + 14 * math.sin(a)
        x1, y1 = 240 + 62 * math.cos(a + 0.55), 280 + 62 * math.sin(a + 0.55)
        cx, cy = 240 + 44 * math.cos(a + 0.05), 280 + 44 * math.sin(a + 0.05)
        o.append(p(f"M {x0:.1f} {y0:.1f} Q {cx:.1f} {cy:.1f} {x1:.1f} {y1:.1f}", stroke="#D3D9E0", width=6))
    o += [circle(240, 280, 16, "#E6EAEE", INK, 5), circle(240, 280, 5, INK)]
    o += [circle(240 + 116 * math.cos(a), 280 + 116 * math.sin(a), 7, "#E6EAEE", INK, 3) for a in (2.3, 3.2, 4.1)]
    return o


CHROME = "#C7CED6"
CHROME_L = "#E9EDF1"
CHROME_D = "#8E97A3"


def _wrench(angle):
    """Dikey İngiliz anahtarı (üstte açık ağız, altta halka) `angle` derece döndürülmüş."""
    head = "M 230 156 L 230 136 C 204 128, 192 106, 196 82 L 222 58 L 238 88 L 274 88 L 290 58 L 316 82 C 320 106, 308 128, 282 136 L 282 156 Z"
    ring = "M 210 404 a 46 46 0 1 0 92 0 a 46 46 0 1 0 -92 0 Z M 236 404 a 20 20 0 1 1 40 0 a 20 20 0 1 1 -40 0 Z"
    g = [f'<g transform="rotate({angle} 256 256)">',
         f'<rect x="232" y="140" width="48" height="236" rx="16" fill="{CHROME}" stroke="{INK}" stroke-width="7"/>',
         p(head, CHROME, INK, 7), p(ring, CHROME, INK, 7, 'fill-rule="evenodd"'),
         p("M 244 160 L 244 360", stroke=CHROME_L, width=7), p("M 268 170 L 268 350", stroke=CHROME_D, width=4, extra='opacity="0.6"'),
         "</g>"]
    return g


def _wrench_icon():
    shadow = [f'<g transform="translate(8,10)" opacity="0.18">'] + [x.replace(CHROME, "#000000") for x in _wrench(45) + _wrench(-45)] + ["</g>"]
    return shadow + _wrench(45) + _wrench(-45) + [circle(256, 256, 16, CHROME_D, INK, 5)]


def _piston_icon():
    rod = "M 230 236 L 222 380 L 290 380 L 282 236 Z"
    big = "M 196 410 a 60 60 0 1 0 120 0 a 60 60 0 1 0 -120 0 Z M 226 410 a 30 30 0 1 1 60 0 a 30 30 0 1 1 -60 0 Z"
    o = [f'<g transform="translate(8,10)" opacity="0.18"><rect x="150" y="92" width="212" height="190" rx="24" fill="#000"/>'
         f'<path d="{rod}" fill="#000"/><path d="{big}" fill="#000" fill-rule="evenodd"/></g>',
         p(rod, CHROME_D, INK, 7), p(big, CHROME_D, INK, 7, 'fill-rule="evenodd"'),
         p("M 240 250 L 236 372", stroke="#B5BDC7", width=6),
         f'<rect x="150" y="92" width="212" height="190" rx="24" fill="{CHROME}" stroke="{INK}" stroke-width="7"/>',
         f'<rect x="150" y="92" width="212" height="34" rx="16" fill="{CHROME_L}" stroke="{INK}" stroke-width="6"/>']
    o += [p(f"M 152 {y} L 360 {y}", stroke="#4A505A", width=7) for y in (146, 168, 190)]
    o += [p("M 170 210 L 170 268", stroke=CHROME_L, width=8), circle(256, 236, 26, CHROME_D, INK, 6), circle(256, 236, 11, "#5A606A")]
    return o


def _shifter_icon():
    defs = ('<radialGradient id="knob" cx="220" cy="150" r="140" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#5A5E68"/><stop offset="1" stop-color="#16181C"/></radialGradient>')
    boot = "M 186 420 C 196 360, 222 318, 238 300 L 274 300 C 290 318, 316 360, 326 420 Z"
    o = [f'<ellipse cx="264" cy="430" rx="110" ry="22" fill="#000" opacity="0.18"/>',
         p(boot, "#6B4632", INK, 7),
         p("M 246 308 C 236 340, 224 380, 218 416", stroke="#E9D6B8", width=4, extra='stroke-dasharray="7 7"'),
         p("M 266 308 C 276 340, 288 380, 294 416", stroke="#E9D6B8", width=4, extra='stroke-dasharray="7 7"'),
         p("M 214 372 Q 256 362 300 372", stroke="#4E3224", width=5), p("M 204 400 Q 256 388 310 400", stroke="#4E3224", width=5),
         f'<rect x="218" y="276" width="76" height="30" rx="8" fill="{CHROME}" stroke="{INK}" stroke-width="6"/>',
         p("M 226 286 L 286 286", stroke=CHROME_L, width=5),
         circle(256, 184, 104, "url(#knob)", INK, 7),
         p("M 196 128 Q 220 104 252 98", stroke="#FFFFFF", width=8, extra='opacity="0.35"')]
    o += [p("M 216 150 L 216 214 M 256 150 L 256 214 M 296 150 L 296 214 M 216 182 L 296 182", stroke="#F4F1EA", width=8)]
    o += [circle(x, y, 6, "#F4F1EA") for x, y in [(216, 150), (256, 150), (296, 150), (216, 214), (256, 214), (296, 214)]]
    return defs, o


def _jack_icon():
    red, red_d = "#D8383A", "#A82628"
    top, bot, left, right = (256, 140), (256, 356), (160, 248), (352, 248)
    o = [f'<g transform="translate(8,10)" opacity="0.18"><rect x="166" y="356" width="180" height="40" rx="8" fill="#000"/>'
         f'<path d="M 256 140 L 160 248 L 256 356 L 352 248 Z" fill="none" stroke="#000" stroke-width="34"/></g>']
    for a, b in ((top, left), (top, right), (bot, left), (bot, right)):
        o.append(p(f"M {a[0]} {a[1]} L {b[0]} {b[1]}", stroke=INK, width=36))
        o.append(p(f"M {a[0]} {a[1]} L {b[0]} {b[1]}", stroke=red, width=24))
        o.append(p(f"M {a[0]} {a[1] - 6} L {b[0]} {b[1] - 6}", stroke="#F06A62", width=5))
    o += [f'<rect x="104" y="238" width="300" height="20" rx="6" fill="{CHROME}" stroke="{INK}" stroke-width="6"/>']
    o += [p(f"M {x} 240 L {x + 8} 256", stroke=CHROME_D, width=3) for x in range(186, 330, 12)]
    o += [circle(96, 248, 22, "none", INK, 12), circle(96, 248, 22, "none", CHROME, 6),
          f'<rect x="166" y="356" width="180" height="40" rx="8" fill="#2F3236" stroke="{INK}" stroke-width="6"/>',
          f'<rect x="206" y="110" width="100" height="32" rx="6" fill="#2F3236" stroke="{INK}" stroke-width="6"/>',
          p("M 214 124 L 298 124", stroke="#5A5E68", width=5)]
    o += [circle(x, y, 13, CHROME_D, INK, 5) for x, y in (top, bot, left, right)]
    return o


def _oilcan_icon():
    body = "M 140 420 L 150 314 C 150 300, 166 292, 186 290 L 326 290 C 346 292, 362 300, 362 314 L 372 420 C 372 434, 360 440, 340 440 L 172 440 C 152 440, 140 434, 140 420 Z"
    cone = "M 166 292 C 180 250, 220 226, 256 222 C 292 226, 332 250, 346 292 Z"
    spout = "M 280 236 L 420 92 L 432 104 L 300 254 Z"
    o = [f'<ellipse cx="262" cy="446" rx="130" ry="18" fill="#000" opacity="0.18"/>',
         p(spout, "#E0B04C", INK, 6), p("M 290 240 L 416 104", stroke="#F7DC94", width=4),
         p("M 422 90 C 432 72, 448 72, 446 92 C 444 104, 432 108, 424 100 Z", "#F2A63B", INK, 4),
         p("M 436 120 C 440 134, 444 142, 438 150 C 430 152, 426 142, 436 120 Z", "#F2A63B", INK, 4),
         p(body, "#D8383A", INK, 7),
         f'<rect x="164" y="336" width="184" height="52" rx="10" fill="#F4ECD8" stroke="{INK}" stroke-width="5"/>',
         p("M 186 352 L 326 352 M 200 372 L 312 372", stroke="#B8B0A0", width=6),
         p(cone, "#E0B04C", INK, 7), p("M 196 268 Q 226 244 256 240", stroke="#F7DC94", width=5),
         circle(256, 222, 16, "#C8962E", INK, 5),
         p("M 150 330 L 112 318 L 106 300 L 120 296 L 150 306", "#9AA3AF", INK, 5),
         p("M 160 404 L 166 330", stroke="#FF8A84", width=7, extra='opacity="0.7"')]
    return o


def _flags_icon():
    def flag(mirror_x):
        tf = "translate(330,452) rotate(-24)" if not mirror_x else "translate(182,452) scale(-1,1) rotate(-24)"
        g = [f'<g transform="{tf}">', p("M 0 0 L 0 -372", stroke=INK, width=18), p("M 0 0 L 0 -372", stroke="#5A3A2A", width=10),
             circle(0, -376, 11, "#F2C14E", INK, 4)]
        cols, rows, sq = 5, 4, 30
        for c in range(cols):
            off = 8 * __import__("math").sin(c * 1.1)   # dalga: sütunlar kayık
            for r in range(rows):
                col = "#1E2024" if (c + r) % 2 == 0 else "#FFFFFF"
                x = -(c + 1) * sq
                y = -364 + r * sq + off
                g.append(f'<rect x="{x}" y="{y:.1f}" width="{sq + 0.6}" height="{sq + 0.6}" fill="{col}"/>')
        pts_top = " ".join(f"L {-(c + 1) * sq} {-364 + 8 * __import__('math').sin(c * 1.1):.1f} L {-c * sq} {-364 + 8 * __import__('math').sin(c * 1.1):.1f}" for c in range(cols))
        g.append(f'<path d="M 0 -364 {pts_top}" fill="none" stroke="{INK}" stroke-width="5"/>')
        pts_bot = " ".join(f"L {-(c + 1) * sq} {-364 + rows * sq + 8 * __import__('math').sin(c * 1.1):.1f} L {-c * sq} {-364 + rows * sq + 8 * __import__('math').sin(c * 1.1):.1f}" for c in range(cols))
        g.append(f'<path d="M 0 {-364 + rows * sq} {pts_bot}" fill="none" stroke="{INK}" stroke-width="5"/>')
        last = cols - 1
        y0 = -364 + 8 * __import__("math").sin(last * 1.1)
        g.append(p(f"M {-cols * sq} {y0:.1f} L {-cols * sq} {y0 + rows * sq:.1f}", stroke=INK, width=5))
        g.append("</g>")
        return g
    return [f'<g transform="translate(6,8)" opacity="0.15"><path d="M 330 452 L 180 112 M 182 452 L 332 112" stroke="#000" stroke-width="18"/></g>'] + flag(False) + flag(True)


_SHIFTER_DEFS, _SHIFTER = _shifter_icon()

ICONS = {
    29: {"about": "spor direksiyon", "bg": ("rays", "#D8E6FF", "#7FA6E8", "#FFFFFF"), "icon": _wheel_icon()},
    30: {"about": "çapraz İngiliz anahtarı", "bg": ("rays", "#E0F4E6", "#7CC79A", "#FFFFFF"), "icon": _wrench_icon()},
    31: {"about": "piston", "bg": ("dots", "#FFE6E2", "#F2867A", "#FFFFFF"), "icon": _piston_icon()},
    32: {"about": "vites topuzu", "bg": ("checker", "#F0E6FF", "#B49AE8", "#FFFFFF"), "icon": _SHIFTER, "defs": _SHIFTER_DEFS},
    33: {"about": "makaslı kriko", "bg": ("stripes", "#FFF0C2", "#F2C14E", "#FFFFFF"), "icon": _jack_icon()},
    34: {"about": "yağdanlık", "bg": ("dots", "#E3F4FF", "#8EC5F0", "#FFFFFF"),
         "icon": ['<g transform="translate(-14,-38)">'] + _oilcan_icon() + ["</g>"]},
    35: {"about": "turbo salyangozu", "bg": ("dots", "#FFE2C2", "#F28A3C", "#FFFFFF"), "icon": _turbo_icon()},
    36: {"about": "çapraz dama bayrakları", "bg": ("rays", "#FFE9A8", "#F5B83C", "#FFFFFF"), "icon": _flags_icon()},
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, spec in enumerate(PRESETS, 1):
        build(i, spec)
    for n, spec in PRESETS_V2.items():
        build(n, spec)
    for n, spec in ICONS.items():
        build_icon(n, spec)
    print(f"{len(PRESETS) + len(PRESETS_V2) + len(ICONS)} avatar → {OUT}")
