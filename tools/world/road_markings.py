#!/usr/bin/env python3
"""KAVŞAK YOL ÇİZGİLERİ DOKUSU — yaya geçidi (zebra), dur çizgisi, düz orta çizgi, ileri ok ve yağ / lastik izi;
her biri yeni / aşınmış / solmuş boya hâlleriyle tek bir atlasta (assets/world/road/markings.png, 1024×1024 RGBA).

Aşınma gerçek yoldaki gibi: tekerleklerin geçtiği iki iz boyunca boya daha çok kalkmış, kenarlar pürüzlü,
yüzeyde küçük kopmalar; solmuş boya asfalta yakın gri. Alfa = boya var / yok (oyunda alpha scissor: saydam
sıralama yok, ışık ve gölge yolla aynı). Atlas yerleşimi world/intersection_markings.gd ATLAS ile AYNI tutulmalı.

Kullanım: python3 -I tools/world/road_markings.py    (PIL; numpy gerekmez) → sonra godot --headless --import
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(PROJ, "assets", "world", "road", "markings.png")
SIZE = 1024
PX_PER_UNIT = 1024 / 1.2      # yaya geçidi yolun tam eni (1,2 birim) = atlas eni

# Atlas dikdörtgenleri (x, y, w, h) — intersection_markings.gd ile aynı
CROSSWALKS = [(0, 0, 1024, 256), (0, 256, 1024, 256), (0, 512, 1024, 256)]   # yeni · aşınmış · solmuş
STOP_LINES = [(0, 776, 512, 40), (0, 824, 512, 40)]                            # yeni · aşınmış
CENTER_LINES = [(0, 880, 512, 56), (0, 944, 512, 56)]                          # yeni · aşınmış
STAINS = [(528, 776, 112, 112), (656, 776, 112, 112), (528, 900, 112, 112), (656, 900, 112, 112)]
ARROWS = [(784, 776, 104, 240), (904, 776, 104, 240)]                          # yeni · aşınmış

PAINT = {"fresh": (186, 186, 181), "worn": (158, 158, 153), "faded": (128, 128, 124)}
WEAR = {"fresh": 0.05, "worn": 0.22, "faded": 0.36}       # kopan boya eşiği (lekeli alanın kabaca oranı)
TRACK = {"fresh": 0.22, "worn": 0.5, "faded": 0.7}        # tekerlek izindeki ek aşınma
CHIPS = {"fresh": 6, "worn": 16, "faded": 26}            # küçük kopmalar (gürültü eşiği, 0–255)


def blobs(size, scale, rnd, octaves=3):
    """0–255 yumuşak lekeli gürültü (L): küçük çözünürlükte gürültü büyütülür, katmanlar toplanır."""
    w, h = size
    acc = Image.new("L", size, 128)
    for o in range(octaves):
        s = max(2, int(scale / (2 ** o)))
        small = Image.effect_noise((max(w // s, 2), max(h // s, 2)), 64)
        layer = small.resize(size, Image.BICUBIC)
        acc = Image.blend(acc, layer, 0.5 if o == 0 else 0.35)
    # kontrastı aç (ortalama 128 çevresinde)
    return acc.point(lambda v: max(0, min(255, int((v - 128) * 2.2 + 128))))


def wear_mask(size, level, rnd, tracks=(), track_sigma=0.0):
    """255 = boya kalır, 0 = kalkmış. Yumuşak lekeler + tekerlek izleri (u konumları px) + seyrek küçük kopmalar."""
    w, h = size
    field = blobs(size, 40, rnd)
    if tracks:
        track_img = Image.new("L", size, 0)
        tp = track_img.load()
        for x in range(w):
            v = 0.0
            for tx in tracks:
                v = max(v, math.exp(-((x - tx) ** 2) / (2 * track_sigma ** 2)))
            col = int(255 * v * TRACK[level])
            for y in range(h):
                tp[x, y] = col
        field = ImageChops.subtract(field, track_img)
    cut = int(255 * WEAR[level])
    keep = field.point(lambda v: 255 if v > cut else 0)
    # küçük kopmalar: kaba (3 px) gürültünün en uç değerleri
    coarse = Image.effect_noise((max(w // 3, 1), max(h // 3, 1)), 48).resize(size, Image.NEAREST)
    chips = coarse.point(lambda v: 0 if v < CHIPS[level] else 255)
    return ImageChops.multiply(keep, chips)


def paint_layer(size, alpha, level, rnd):
    """Boya rengi + kir lekeleri; alfa verilen maske."""
    base = Image.new("RGB", size, PAINT[level])
    grime = blobs(size, 26, rnd, octaves=2).point(lambda v: int(205 + (v - 128) * 0.22))
    grime_rgb = Image.merge("RGB", (grime, grime, grime))
    base = ImageChops.multiply(base, grime_rgb).point(lambda v: min(255, int(v * 1.25)))
    out = base.convert("RGBA")
    out.putalpha(alpha)
    return out


def rough(mask, rnd, amount=1.2):
    """Yalnızca KENARLARI pürüzlendir: bulanık kenar (geçiş bölgesi) + ortalı gürültü, sonra eşik. İç dolu kalır."""
    noise = Image.effect_noise(mask.size, 40).filter(ImageFilter.GaussianBlur(1.0))
    soft = mask.filter(ImageFilter.GaussianBlur(amount))
    mixed = ImageChops.add(soft, noise, scale=1.0, offset=-128)
    return mixed.point(lambda v: 255 if v > 118 else 0)


def crosswalk(level, rnd):
    w, h = 1024, 256
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    margin_v = 10                                  # mipmap taşmasın: üst / alt boş şerit
    stripe_w = 0.07 * PX_PER_UNIT
    pitch = 0.13 * PX_PER_UNIT
    count = int(math.floor((1.2 - 0.08) / 0.13))
    start = w / 2 - pitch * (count - 1) / 2
    for i in range(count):
        cx = start + i * pitch + rnd.uniform(-2, 2)
        half = stripe_w / 2 + rnd.uniform(-1.5, 1.5)
        top = margin_v + rnd.uniform(0, 3)
        bottom = h - margin_v - rnd.uniform(0, 3)
        skew = rnd.uniform(-2.5, 2.5)
        d.polygon([(cx - half + skew, top), (cx + half + skew, top), (cx + half - skew, bottom), (cx - half - skew, bottom)], fill=255)
    mask = rough(mask, rnd)
    # tekerlek izleri: her şeritte iki iz (şerit merkezi ± 0,09 birim)
    tracks = []
    for lane_center in (0.3, 0.9):
        for off in (-0.09, 0.09):
            tracks.append((lane_center + off) * PX_PER_UNIT)
    keep = wear_mask((w, h), level, rnd, tracks, 0.035 * PX_PER_UNIT)
    alpha = ImageChops.multiply(mask, keep)
    return paint_layer((w, h), alpha, level, rnd)


def bar(size, level, rnd, wear_level=None):
    w, h = size
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rectangle([6, h * 0.22, w - 6, h * 0.78], fill=255)
    mask = rough(mask, rnd, 0.9)
    keep = wear_mask(size, wear_level or level, rnd)
    return paint_layer(size, ImageChops.multiply(mask, keep), level, rnd)


def arrow(level, rnd):
    w, h = 104, 240
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    cx = w / 2
    d.polygon([(cx, 10), (cx + 40, 82), (cx + 14, 82), (cx + 14, h - 10), (cx - 14, h - 10), (cx - 14, 82), (cx - 40, 82)], fill=255)
    mask = rough(mask, rnd, 1.0)
    keep = wear_mask((w, h), level, rnd, (cx,), 10)
    return paint_layer((w, h), ImageChops.multiply(mask, keep), level, rnd)


def stain(rnd):
    w = h = 112
    blob = blobs((w, h), 18, rnd, octaves=2)
    radial = Image.new("L", (w, h), 0)
    rp = radial.load()
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2 * rnd.uniform(0.6, 1.0))
            rp[x, y] = max(0, int(255 * (1.0 - math.hypot(dx, dy) * 1.15)))
    alpha = ImageChops.multiply(blob, radial).point(lambda v: 255 if v > 70 else 0)
    shade = rnd.randint(36, 46)
    img = Image.new("RGBA", (w, h), (shade, shade, shade + 2, 0))
    img.putalpha(alpha)
    return img


def main():
    rnd = random.Random(1907)
    random.seed(1907)
    atlas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for rect, level in zip(CROSSWALKS, ("fresh", "worn", "faded")):
        atlas.alpha_composite(crosswalk(level, rnd), (rect[0], rect[1]))
    for rect, level in zip(STOP_LINES, ("fresh", "worn")):
        atlas.alpha_composite(bar((rect[2], rect[3]), level, rnd), (rect[0], rect[1]))
    for rect, level in zip(CENTER_LINES, ("fresh", "worn")):
        atlas.alpha_composite(bar((rect[2], rect[3]), level, rnd), (rect[0], rect[1]))
    for rect in STAINS:
        atlas.alpha_composite(stain(rnd), (rect[0], rect[1]))
    for rect, level in zip(ARROWS, ("fresh", "worn")):
        atlas.alpha_composite(arrow(level, rnd), (rect[0], rect[1]))
    # Saydam piksellerin rengi boya rengine yakın kalsın: mipmap / filtre kenarda koyu hale çizmesin
    r, g, b, a = atlas.split()
    fill = Image.new("RGB", atlas.size, PAINT["worn"])
    rgb = Image.composite(Image.merge("RGB", (r, g, b)), fill, a)
    out = Image.merge("RGBA", (*rgb.split(), a))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("atlas:", OUT)


if __name__ == "__main__":
    main()
