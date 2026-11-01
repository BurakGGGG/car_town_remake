"""HURDALIK KARTPOSTALI MANZARALARI: kademe başına bir düz renkli manzara (SVG, 800x500).

  mahalle.svg  → RESTORASYON (temel)   ·  sahil.svg → USTA · KLASİK   ·  ralli.svg → USTA · YARIŞ

Çıktı bu klasörün scenes/ alt klasörüdür (kaynak olarak depoda durur). Araç ortada-altta durur, manzara
kenarlarda ve üstte ilgi taşır. Sonraki adım: render_cars.gd (araçlar + bu SVG'lerin pikselleri), sonra
make_postcards.py. Hepsi: tools/postcards/build.sh
"""
import random
from pathlib import Path

OUT = Path(__file__).parent / "scenes"
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 500" width="800" height="500">'


def sahil() -> str:
    s = [HEAD, """<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5E9CC6"/><stop offset="0.55" stop-color="#F4DCA8"/><stop offset="0.95" stop-color="#F3B074"/></linearGradient>
<linearGradient id="sea" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#E5A27A"/><stop offset="0.2" stop-color="#5D94B6"/><stop offset="1" stop-color="#2C6A8F"/></linearGradient>
<radialGradient id="sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFF6D8"/><stop offset="0.35" stop-color="#FFE7AE" stop-opacity="0.8"/><stop offset="1" stop-color="#FFE7AE" stop-opacity="0"/></radialGradient>
</defs>
<rect width="800" height="270" fill="url(#sky)"/>
<circle cx="590" cy="255" r="160" fill="url(#sun)"/>
<circle cx="590" cy="255" r="40" fill="#FFF3CF"/>
<g fill="#FFF4E0" opacity="0.8"><ellipse cx="150" cy="80" rx="72" ry="13"/><ellipse cx="196" cy="70" rx="40" ry="12"/><ellipse cx="430" cy="128" rx="62" ry="9"/><ellipse cx="700" cy="60" rx="50" ry="9"/></g>
<path d="M0 266 L0 210 C40 200 90 186 140 192 C190 198 232 230 292 250 L334 266 Z" fill="#A58494"/>
<path d="M0 266 L0 236 C50 226 100 224 150 234 C190 242 222 256 246 266 Z" fill="#8B6F82"/>
<rect y="264" width="800" height="110" fill="url(#sea)"/>
<g fill="#FFE9B8" opacity="0.85"><rect x="548" y="272" width="84" height="3" rx="1.5"/><rect x="562" y="283" width="56" height="3" rx="1.5"/><rect x="540" y="296" width="100" height="3" rx="1.5"/><rect x="570" y="310" width="40" height="3" rx="1.5"/><rect x="552" y="325" width="76" height="3" rx="1.5"/></g>
<path d="M300 300 L300 266 L320 298 Z" fill="#FFF7E6"/><path d="M290 302 L328 302 L321 309 L297 309 Z" fill="#7A4E3A"/>
<path d="M590 374 C632 330 700 298 800 284 L800 374 Z" fill="#B88A5C"/>
<g fill="#F3E3C4"><rect x="676" y="290" width="28" height="22"/><rect x="708" y="282" width="22" height="30"/><rect x="734" y="286" width="30" height="26"/></g>
<g fill="#C4654A"><path d="M673 291 L690 279 L707 291 Z"/><path d="M705 283 L719 271 L733 283 Z"/><path d="M731 287 L749 275 L767 287 Z"/></g>
<g fill="#5C4A3E"><rect x="684" y="298" width="5" height="7"/><rect x="714" y="292" width="5" height="7"/><rect x="744" y="296" width="5" height="7"/></g>
<rect y="372" width="800" height="128" fill="#D9BD8F"/>
<rect y="360" width="800" height="16" fill="#EADCC0"/><rect y="374" width="800" height="5" fill="#C7AE85"/>
<rect y="394" width="800" height="106" fill="#6E6862"/>
<path d="M0 450 L800 450" stroke="#F3E8CF" stroke-width="5" stroke-dasharray="40 30"/>
<path d="M736 362 C724 318 730 266 744 236 C758 266 764 318 752 362 Z" fill="#3C5A3C"/>
<path d="M770 362 C760 328 764 288 775 264 C786 288 790 328 780 362 Z" fill="#2F4B33"/>
<path d="M54 364 C58 322 64 292 74 262" stroke="#6B4A33" stroke-width="7" fill="none" stroke-linecap="round"/>
<g fill="#4C7A45"><path d="M74 262 C50 250 30 256 16 270 C40 262 56 264 74 266 Z"/><path d="M74 262 C96 246 118 250 132 264 C110 258 92 260 74 266 Z"/><path d="M74 262 C64 240 46 232 30 234 C50 242 62 252 72 266 Z"/><path d="M74 262 C88 240 104 234 120 236 C100 244 88 254 76 266 Z"/></g>
</svg>"""]
    return "\n".join(s)


def ralli() -> str:
    rnd = random.Random(7)
    pines = []
    x = -10.0
    while x < 820:
        h = rnd.uniform(34, 62)
        base = 296 + rnd.uniform(-6, 4)
        w = h * 0.42
        col = rnd.choice(["#2F4F3A", "#3B5E44", "#355640"])
        pines.append(f'<path d="M{x:.1f} {base:.1f} L{x + w:.1f} {base - h:.1f} L{x + 2 * w:.1f} {base:.1f} Z" fill="{col}"/>')
        x += w * rnd.uniform(1.1, 1.6)
    near = []
    for x0, h in [(8, 120), (60, 150), (700, 140), (752, 170)]:
        w = h * 0.36
        near.append(f'<path d="M{x0} 380 L{x0 + w} {380 - h} L{x0 + 2 * w} 380 Z" fill="#284634"/>')
        near.append(f'<path d="M{x0 + w - 3} 380 L{x0 + w - 3} 392 L{x0 + w + 3} 392 L{x0 + w + 3} 380 Z" fill="#5A3E2B"/>')
    dust = []
    for cx, cy, r, o in [(70, 420, 70, 0.55), (150, 400, 56, 0.5), (40, 380, 50, 0.45), (230, 425, 44, 0.4), (110, 360, 38, 0.35)]:
        dust.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#EEDFC4" opacity="{o}"/>')
    posts = []
    for px, py in [(120, 372), (260, 362), (520, 360), (660, 368)]:
        posts.append(f'<rect x="{px}" y="{py - 26}" width="4" height="28" fill="#F2EDE4"/>')
    tape = ('<path d="M122 352 Q190 344 262 342 Q390 336 522 340 Q590 342 662 348" stroke="#F7F2E8" stroke-width="5" fill="none"/>'
            '<path d="M122 352 Q190 344 262 342 Q390 336 522 340 Q590 342 662 348" stroke="#D2483A" stroke-width="5" fill="none" stroke-dasharray="12 12"/>')
    return "\n".join([HEAD, """<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7DB7DD"/><stop offset="1" stop-color="#E4EEF0"/></linearGradient></defs>
<rect width="800" height="320" fill="url(#sky)"/>
<g fill="#FFFFFF" opacity="0.85"><ellipse cx="560" cy="70" rx="80" ry="16"/><ellipse cx="610" cy="58" rx="46" ry="14"/><ellipse cx="180" cy="110" rx="56" ry="10"/></g>
<path d="M0 236 L90 160 L150 196 L240 112 L330 188 L410 146 L500 204 L590 122 L680 182 L800 136 L800 270 L0 270 Z" fill="#A3B4C4"/>
<path d="M240 112 L262 132 L250 130 L240 140 L230 131 L220 132 Z" fill="#F4F7F8"/>
<path d="M590 122 L612 142 L600 140 L590 150 L580 141 L568 142 Z" fill="#F4F7F8"/>
<path d="M0 270 C120 240 220 258 320 246 C430 234 520 258 640 244 C720 236 770 242 800 246 L800 310 L0 310 Z" fill="#6F9168"/>""",
                      *pines,
                      '<rect y="300" width="800" height="200" fill="#B98E62"/>',
                      '<path d="M0 340 C200 330 600 326 800 334 L800 500 L0 500 Z" fill="#D7BB8D"/>',
                      '<g stroke="#C3A273" stroke-width="3" fill="none" opacity="0.8"><path d="M0 420 C200 400 520 392 800 398"/><path d="M0 470 C220 448 520 440 800 446"/></g>',
                      *posts, tape, *dust, *near,
                      '<g fill="#7F9A55"><path d="M380 500 l6 -16 l4 16 Z"/><path d="M394 500 l4 -12 l5 12 Z"/><path d="M640 500 l5 -14 l5 14 Z"/></g>',
                      "</svg>"])


def mahalle() -> str:
    houses = []
    spec = [  # x, w, h, duvar, çatı
        (-10, 120, 190, "#EBD9B5", "#C2654A"), (110, 96, 230, "#E7B98A", "#A9533D"), (206, 130, 170, "#A9C9B6", "#C2654A"),
        (520, 120, 200, "#F0E0C0", "#B85C44"), (640, 110, 240, "#E9A98C", "#A9533D"), (750, 90, 180, "#EBD9B5", "#C2654A"),
    ]
    base = 372
    for x, w, h, wall, roof in spec:
        top = base - h
        houses.append(f'<rect x="{x}" y="{top}" width="{w}" height="{h}" fill="{wall}"/>')
        houses.append(f'<path d="M{x - 8} {top + 2} L{x + w / 2} {top - 26} L{x + w + 8} {top + 2} Z" fill="{roof}"/>')
        rows = int((h - 60) // 52)
        cols = max(1, int(w // 40))
        for r in range(rows):
            for c in range(cols):
                wx = x + (w - cols * 40) / 2 + c * 40 + 10
                wy = top + 22 + r * 52
                houses.append(f'<rect x="{wx:.0f}" y="{wy}" width="20" height="28" fill="#5A4A3E"/>')
                houses.append(f'<rect x="{wx - 3:.0f}" y="{wy + 28}" width="26" height="4" fill="#F7EFE0"/>')
    awning = ''.join(f'<rect x="{214 + i * 16}" y="300" width="16" height="16" fill="{"#C8463A" if i % 2 == 0 else "#F7EFE0"}"/>' for i in range(7))
    cobbles = []
    for row, y in enumerate(range(404, 500, 16)):
        off = 0 if row % 2 == 0 else 14
        for x in range(-28 + off, 820, 28):
            cobbles.append(f'<rect x="{x + 1}" y="{y + 1}" width="26" height="14" rx="4" fill="#9A9086"/>')
    return "\n".join([HEAD, """<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8CC6E6"/><stop offset="1" stop-color="#F3E7CE"/></linearGradient></defs>
<rect width="800" height="380" fill="url(#sky)"/>
<g fill="#FFFFFF" opacity="0.85"><ellipse cx="420" cy="70" rx="70" ry="14"/><ellipse cx="460" cy="60" rx="40" ry="12"/></g>
<path d="M330 372 L330 230 C370 210 470 210 510 230 L510 372 Z" fill="#B7C79A"/>
<circle cx="420" cy="232" r="52" fill="#D8CDB8"/><rect x="368" y="232" width="104" height="140" fill="#D8CDB8"/>
<rect x="414" y="168" width="12" height="16" fill="#C9BFA9"/><rect x="486" y="150" width="14" height="222" fill="#E6DCC8"/><path d="M486 150 L493 120 L500 150 Z" fill="#9AA6AE"/>
<g fill="#7B8C6A"><circle cx="350" cy="320" r="34"/><circle cx="380" cy="300" r="30"/><circle cx="488" cy="318" r="30"/></g>""",
                      *houses, awning,
                      '<rect x="214" y="316" width="112" height="56" fill="#6D5446"/>',
                      '<g fill="#5E8C4E"><circle cx="470" cy="300" r="40"/><circle cx="500" cy="280" r="34"/><circle cx="520" cy="310" r="30"/></g>',
                      '<rect x="492" y="320" width="8" height="54" fill="#6B4A33"/>',
                      '<rect y="372" width="800" height="22" fill="#D9CCB1"/><rect y="392" width="800" height="8" fill="#B8A98C"/>',
                      '<rect y="400" width="800" height="100" fill="#7E756C"/>', *cobbles,
                      '<rect x="604" y="250" width="6" height="124" fill="#3E4246"/><path d="M596 252 L618 252 L612 240 L602 240 Z" fill="#3E4246"/><rect x="600" y="252" width="14" height="8" fill="#FFE7A0"/>',
                      "</svg>"])


OUT.mkdir(parents=True, exist_ok=True)
for name, fn in (("sahil.svg", sahil), ("ralli.svg", ralli), ("mahalle.svg", mahalle)):
    (OUT / name).write_text(fn(), encoding="utf-8")
    print(name, len(fn()))
