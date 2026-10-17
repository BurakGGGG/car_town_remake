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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for i, spec in enumerate(PRESETS, 1):
        build(i, spec)
    print(f"{len(PRESETS)} avatar → {OUT}")
