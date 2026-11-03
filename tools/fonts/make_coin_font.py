"""ALTIN PARA GLİFİ (2026-11-03): oyunun para birimi yazılarda "₺" yerine ALTIN PARA simgesi görünsün (kullanıcı:
"paramızın adı TL olmasın, direkt gold simgesi olsun, yabancı oyuncularım da var").

Metinlere dokunulmaz: oyun yazı tipinde (Godot'nun gömülü Open Sans'ı) ₺ yok, karakter yedek yazı tipinden geliyor
(ui/theme/font_fallback.gd). Bu betik YALNIZ U+20BA'yı taşıyan küçük bir RENKLİ yazı tipi üretir
(ui/theme/fonts/autoyard_coin.ttf); FontFallback onu sembol yazı tipinin ÖNÜNE bağlar → her etiket, düğme, bildirim ve
çeviride ₺ altın para olarak çizilir.

Çizim HUD'daki para simgesinin aynısı (ui/hud/hud_icon.gd _coin): aşağı kaymış koyu altın taban, altın disk, koyu iç
halka, sol üstte beyaz parıltı yayı. Renkli katmanlar COLR v0 + CPAL; renkli glifi desteklemeyen ortamda temel glif
(halka oyuklu disk) tek renk para olarak görünür. Katmanlar yazının rengine boyanmaz (içe aktarma
modulate_color_glyphs=false), koyu ve beyaz yazıda aynı altın.

  python3 -m venv /tmp/fontenv && /tmp/fontenv/bin/pip install fonttools
  /tmp/fontenv/bin/python tools/fonts/make_coin_font.py
"""
import math
import os

from fontTools.colorLib.builder import buildCOLR, buildCPAL
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ui/theme/fonts/autoyard_coin.ttf")

UPM = 2048
ASCENT, DESCENT = 1901, -483          # autoyard_symbols.ttf (DejaVu) ile aynı: satır yüksekliği değişmesin
S = 1720.0                            # simge kutusu (hud_icon _coin.deki s): görünen disk rakam boyunda
SIDE = 80                             # yan boşluk
CX = SIDE + S * 0.48
CY = 745.0                            # rakamların ortası (Open Sans rakam boyu ~1462), taban hafif aşağı taşar
ADV = int(SIDE * 2 + S * 0.96)
SEG = 96                              # daire = 96 kenarlı çokgen (yazı boyunda pürüzsüz)

# CPAL renkleri (0..1): HudPalette.COIN_DARK B27A1C, COIN F5BE4C, parıltı beyaz %70
PALETTE = [
    (0xB2 / 255, 0x7A / 255, 0x1C / 255, 1.0),
    (0xF5 / 255, 0xBE / 255, 0x4C / 255, 1.0),
    (1.0, 1.0, 1.0, 0.7),
]


def circle(pen, cx: float, cy: float, r: float, clockwise: bool = True) -> None:
    """TrueType: dış kontur saat yönünde, delik saat tersine."""
    pts = []
    for i in range(SEG):
        a = 2 * math.pi * i / SEG
        a = -a if clockwise else a
        pts.append((round(cx + r * math.cos(a)), round(cy + r * math.sin(a))))
    pen.moveTo(pts[0])
    for p in pts[1:]:
        pen.lineTo(p)
    pen.closePath()


def ring(pen, cx: float, cy: float, r_out: float, r_in: float) -> None:
    circle(pen, cx, cy, r_out, True)
    circle(pen, cx, cy, r_in, False)


def arc_band(pen, cx: float, cy: float, r: float, width: float, a0: float, a1: float) -> None:
    """Yay şeridi (açılar Godot 2B'deki gibi, y aşağı) → yazı tipi koordinatında y yukarı; uçlar yuvarlak."""
    n = 24
    outer, inner = [], []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        dx, dy = math.cos(a), -math.sin(a)
        outer.append((cx + (r + width / 2) * dx, cy + (r + width / 2) * dy))
        inner.append((cx + (r - width / 2) * dx, cy + (r - width / 2) * dy))
    pts = outer + inner[::-1]
    # Saat yönü denetimi (alan işareti): TrueType dış kontur saat yönünde
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area > 0:
        pts = pts[::-1]
    pen.moveTo((round(pts[0][0]), round(pts[0][1])))
    for p in pts[1:]:
        pen.lineTo((round(p[0]), round(p[1])))
    pen.closePath()


def glyph(draw) -> object:
    pen = TTGlyphPen(None)
    draw(pen)
    return pen.glyph()


def main() -> None:
    w = S * 0.08                       # hud_icon çizgi kalınlığı (w * 0.7 yaylar için)

    def mono(p) -> None:
        """Temel glif (renk desteklenmezse tek renk): disk, içinde halka oyuğu."""
        circle(p, CX, CY, S * 0.48, True)
        circle(p, CX, CY, S * 0.30 + w * 0.35, False)   # oyuk (saat tersine)
        circle(p, CX, CY, S * 0.30 - w * 0.35, True)    # oyuğun içi yine dolu

    glyphs = {
        ".notdef": glyph(lambda p: None),
        "coin": glyph(mono),
        "coin.base": glyph(lambda p: circle(p, CX, CY - S * 0.04, S * 0.48)),
        "coin.face": glyph(lambda p: circle(p, CX, CY, S * 0.44)),
        "coin.ring": glyph(lambda p: ring(p, CX, CY, S * 0.30 + w * 0.35, S * 0.30 - w * 0.35)),
        "coin.shine": glyph(lambda p: arc_band(p, CX, CY, S * 0.36, w * 0.7, math.pi * 1.15, math.pi * 1.55)),
    }
    order = list(glyphs)
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({0x20BA: "coin"})
    fb.setupGlyf(glyphs)
    metrics = {}
    for name, g in glyphs.items():
        xs = [x for x, _y in g.coordinates] if g.numberOfContours > 0 else [0]
        metrics[name] = (ADV if name != ".notdef" else 0, min(xs))   # lsb = glifin gerçek sol kenarı
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({"familyName": "AutoYard Coin", "styleName": "Regular"})
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT, usWinAscent=ASCENT, usWinDescent=-DESCENT)
    fb.setupPost()
    fb.font["COLR"] = buildCOLR({"coin": [("coin.base", 0), ("coin.face", 1), ("coin.ring", 0), ("coin.shine", 2)]})
    fb.font["CPAL"] = buildCPAL([PALETTE])
    fb.save(OUT)
    print("RAPOR yazıldı", OUT, os.path.getsize(OUT), "bayt, ilerleme", ADV)


if __name__ == "__main__":
    main()
