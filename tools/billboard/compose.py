#!/usr/bin/env python3
"""BILLBOARD AFİŞİ 2/2 — çizilmiş aracı (render_cars.gd → ct_shots/billboard/raw/<id>.png) efektli bir afişe
dönüştürür: temaya göre zemin (gün batımı güneşi, neon ızgara, hız çizgileri, stüdyo spotu, gece şehri, aurora),
aracın arkasında renkli hale, parlak zeminde yansıma ve gölge, arkasından süzülen hız izleri, parıltı (bloom),
vinyet, ince gren; solda marka + model yazısı, sol altta AUTO YARD logosu.

Çıktı: assets/world/billboard/<id>.jpg (1024×512; oyunda VRAM sıkıştırmalı + mipmap içe aktarılır).
Kullanım: python3 -I tools/billboard/compose.py [<id> ...]      (PIL; numpy gerekmez)
Yazı tipi: BILLBOARD_FONT (varsayılan Poppins Bold, OFL) — yoksa DejaVu Sans Bold.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
RAW = "/home/burak/Projects/ct_shots/billboard/raw/"
OUT = os.path.join(PROJ, "assets", "world", "billboard")
LOGO = os.path.join(PROJ, "assets", "branding", "autoyard_logo.png")
CATALOG = os.path.join(PROJ, "vehicles", "cars.json")
FONTS = [os.environ.get("BILLBOARD_FONT", "/home/burak/uni_app/assets/google_fonts/Poppins-Bold.ttf"),
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
W, H = 2048, 1024          # çalışma boyu (2×), çıktı 1024×512
FINAL = (1024, 512)
HORIZON = 0.66             # ufuk çizgisi (yükseklik oranı)


def rgb(hexcol):
    h = hexcol.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def vertical_gradient(size, top, bottom, ease=1.0):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        col.putpixel((0, y), mix(top, bottom, (y / max(h - 1, 1)) ** ease))
    return col.resize((w, h))


def radial(size, center, radius, color, alpha=255, falloff=2.0):
    """Yumuşak dairesel ışık (RGBA): merkezde `alpha`, kenara doğru söner."""
    w, h = size
    small = (max(w // 8, 1), max(h // 8, 1))
    mask = Image.new("L", small, 0)
    px = mask.load()
    cx, cy, r = center[0] / 8.0, center[1] / 8.0, radius / 8.0
    for y in range(small[1]):
        for x in range(small[0]):
            d = math.hypot(x - cx, y - cy) / max(r, 1e-3)
            if d < 1.0:
                px[x, y] = int(alpha * (1.0 - d) ** falloff)
    mask = mask.resize(size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(4))
    layer = Image.new("RGBA", size, color + (0,))
    layer.putalpha(mask)
    return layer


def screen(base, layer, amount=1.0):
    """Ekran karışımı (parıltı): base RGB, layer RGB."""
    blended = ImageChops.screen(base, layer)
    return Image.blend(base, blended, amount) if amount < 1.0 else blended


def directional_blur(img, length):
    """Yatay hareket bulanıklığı: yatayda küçült-büyüt + hafif gauss."""
    w, h = img.size
    small = img.resize((max(int(w / length), 1), h), Image.BILINEAR)
    return small.resize((w, h), Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.5))


# --- Temalar ---------------------------------------------------------------------------------------

def bg_sunset(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 1.4).convert("RGBA")
    sun_c, sun_r = (int(W * 0.60), int(H * HORIZON) - 40), int(H * 0.36)
    sun = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sun)
    for y in range(sun_c[1] - sun_r, sun_c[1] + 1):
        t01 = (y - (sun_c[1] - sun_r)) / sun_r
        half = math.sqrt(max(sun_r ** 2 - (sun_c[1] - y) ** 2, 0))
        col = mix(rgb(t["accent"]), rgb(t["accent2"]), t01)
        # gün batımı güneşinin alt yarısında yatay boşluklar (kalınlaşarak)
        band = int(t01 * 9)
        if t01 > 0.45 and (y // 7) % 3 == 0 and band > 3:
            continue
        d.line([(sun_c[0] - half, y), (sun_c[0] + half, y)], fill=col + (255,))
    img.alpha_composite(radial((W, H), sun_c, sun_r * 2.0, rgb(t["accent"]), 150))
    img.alpha_composite(sun)
    _floor(img, t, grid=False, rnd=rnd)
    return img


def bg_neon_grid(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 1.2).convert("RGBA")
    _stars(img, rnd, 140)
    img.alpha_composite(radial((W, H), (int(W * 0.6), int(H * HORIZON)), int(W * 0.45), rgb(t["accent"]), 120))
    _floor(img, t, grid=True, rnd=rnd)
    return img


def bg_speed(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 0.8).convert("RGBA")
    streaks = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    vp = (int(W * 0.62), int(H * 0.55))
    for _ in range(170):
        ang = rnd.uniform(-math.pi, math.pi)
        r0 = rnd.uniform(H * 0.25, H * 0.5)
        r1 = r0 + rnd.uniform(H * 0.4, H * 1.4)
        col = rgb(t["accent"]) if rnd.random() < 0.6 else rgb(t["accent2"])
        a = rnd.randint(40, 140)
        d.line([(vp[0] + math.cos(ang) * r0, vp[1] + math.sin(ang) * r0 * 0.6),
                (vp[0] + math.cos(ang) * r1, vp[1] + math.sin(ang) * r1 * 0.6)], fill=col + (a,), width=rnd.randint(2, 5))
    img.alpha_composite(streaks.filter(ImageFilter.GaussianBlur(2)))
    img.alpha_composite(radial((W, H), vp, int(W * 0.35), rgb(t["accent"]), 110))
    _floor(img, t, grid=False, rnd=rnd)
    return img


def bg_studio(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 1.0).convert("RGBA")
    cone = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(cone)
    cx = int(W * 0.62)
    d.polygon([(cx - 90, 0), (cx + 90, 0), (cx + 760, int(H * 0.92)), (cx - 760, int(H * 0.92))], fill=70)
    cone = cone.filter(ImageFilter.GaussianBlur(60))
    light = Image.new("RGBA", (W, H), rgb(t["accent"]) + (0,))
    light.putalpha(cone)
    img.alpha_composite(light)
    for i in range(5):   # ince yatay ışık şeritleri (stüdyo duvarı)
        y = int(H * (0.18 + i * 0.09))
        band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(band).line([(int(W * 0.25), y), (W, y)], fill=rgb(t["accent2"]) + (26,), width=3)
        img.alpha_composite(band.filter(ImageFilter.GaussianBlur(3)))
    _floor(img, t, grid=False, rnd=rnd, gloss=1.3)
    return img


def bg_night_city(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 1.1).convert("RGBA")
    _stars(img, rnd, 60)
    sky = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(sky)
    base_y = int(H * HORIZON)
    x = -20
    while x < W:   # silüet: rastgele kuleler, ışıklı pencereler
        bw = rnd.randint(60, 150)
        bh = rnd.randint(int(H * 0.12), int(H * 0.42))
        shade = mix(rgb(t["bg_top"]), (0, 0, 0), 0.3)
        d.rectangle([x, base_y - bh, x + bw, base_y], fill=shade + (255,))
        for wy in range(base_y - bh + 14, base_y - 10, 22):
            for wx in range(x + 10, x + bw - 10, 18):
                if rnd.random() < 0.32:
                    col = rgb(t["accent2"]) if rnd.random() < 0.7 else rgb(t["accent"])
                    d.rectangle([wx, wy, wx + 8, wy + 10], fill=col + (rnd.randint(110, 220),))
        x += bw + rnd.randint(0, 12)
    img.alpha_composite(sky)
    bokeh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(bokeh)
    for _ in range(46):   # bulanık şehir ışıkları
        r = rnd.randint(14, 46)
        cx, cy = rnd.randint(0, W), rnd.randint(int(H * 0.2), int(H * 0.68))
        col = rgb(t["accent"]) if rnd.random() < 0.5 else rgb(t["accent2"])
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (rnd.randint(50, 120),))
    img.alpha_composite(bokeh.filter(ImageFilter.GaussianBlur(9)))
    _floor(img, t, grid=False, rnd=rnd, gloss=1.2, wet=True)
    return img


def bg_aurora(t, rnd):
    img = vertical_gradient((W, H), rgb(t["bg_top"]), rgb(t["bg_bottom"]), 1.0).convert("RGBA")
    _stars(img, rnd, 180)
    for k, col in enumerate((rgb(t["accent"]), rgb(t["accent2"]), rgb(t["accent"]))):
        band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(band)
        phase = rnd.uniform(0, math.tau)
        for x in range(0, W, 6):
            y = H * (0.22 + 0.08 * k) + math.sin(x / W * math.tau * 1.3 + phase) * H * 0.07
            d.line([(x, y - 120), (x, y + 30)], fill=col + (70,), width=6)
        img.alpha_composite(band.filter(ImageFilter.GaussianBlur(28)))
    _floor(img, t, grid=False, rnd=rnd)
    return img


def _stars(img, rnd, n):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y = rnd.randint(0, W), rnd.randint(0, int(H * HORIZON * 0.9))
        r = rnd.choice((1, 1, 1, 2, 2, 3))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, rnd.randint(70, 200)))
    img.alpha_composite(layer)


def _floor(img, t, grid, rnd, gloss=1.0, wet=False):
    """Ufkun altı: koyu parlak zemin; ufukta ince ışık çizgisi; istenirse perspektif ızgara."""
    y0 = int(H * HORIZON)
    floor = vertical_gradient((W, H - y0), mix(rgb(t["bg_bottom"]), (0, 0, 0), 0.45), (6, 6, 10), 0.7)
    img.paste(floor, (0, y0))
    line = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(line).line([(0, y0), (W, y0)], fill=rgb(t["accent"]) + (int(150 * gloss),), width=4)
    img.alpha_composite(line.filter(ImageFilter.GaussianBlur(6)))
    img.alpha_composite(line)
    if grid:
        g = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(g)
        vp = (W * 0.6, y0 - 4)
        for i in range(-24, 25):
            d.line([vp, (vp[0] + i * W * 0.11, H + 40)], fill=rgb(t["accent2"]) + (90,), width=3)
        for k in range(1, 14):
            yy = y0 + (H - y0) * (k / 13.0) ** 2.1
            d.line([(0, yy), (W, yy)], fill=rgb(t["accent"]) + (110,), width=3)
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(1.2)))
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(8)))
    if wet:
        for _ in range(26):   # ıslak zeminde dikey ışık izleri
            x = rnd.randint(0, W)
            streak = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            col = rgb(t["accent"]) if rnd.random() < 0.5 else rgb(t["accent2"])
            ImageDraw.Draw(streak).line([(x, y0 + 4), (x, H)], fill=col + (rnd.randint(25, 60),), width=rnd.randint(6, 16))
            img.alpha_composite(streak.filter(ImageFilter.GaussianBlur(10)))


STYLES = {"sunset": bg_sunset, "neon_grid": bg_neon_grid, "speed": bg_speed, "studio": bg_studio,
          "night_city": bg_night_city, "aurora": bg_aurora}


# --- Araç ------------------------------------------------------------------------------------------

def load_car(cid):
    im = Image.open(os.path.join(RAW, cid + ".png")).convert("RGBA")
    im = im.crop(im.getbbox())
    return im


def place_car(img, car, t):
    """Araç sağ yarıda, tekerlekleri zeminin biraz altında; arkasında hale, altında gölge + yansıma."""
    target_w = int(W * 0.60)
    scale = target_w / car.width
    pm = car.convert("RGBa").resize((target_w, int(car.height * scale)), Image.LANCZOS)
    car = pm.convert("RGBA")
    cx = int(W * 0.645)
    bottom = int(H * 0.86)
    x, y = cx - car.width // 2, bottom - car.height
    alpha = car.getchannel("A")
    # Hale: alfa genişletilip bulanıklaştırılır, vurgu rengiyle
    halo = Image.new("RGBA", img.size, rgb(t["accent"]) + (0,))
    mask = Image.new("L", img.size, 0)
    mask.paste(alpha, (x, y))
    halo.putalpha(mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(46)).point(lambda v: int(v * 0.75)))
    img.alpha_composite(halo)
    # Gölge: tekerlek hizasında koyu elips
    shadow = Image.new("L", img.size, 0)
    ImageDraw.Draw(shadow).ellipse([x + car.width * 0.06, bottom - car.height * 0.08, x + car.width * 0.96,
                                    bottom + car.height * 0.06], fill=200)
    shadow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow_layer.putalpha(shadow.filter(ImageFilter.GaussianBlur(26)))
    img.alpha_composite(shadow_layer)
    # Yansıma: ters çevrilmiş araç, aşağı doğru sönen
    refl = car.transpose(Image.FLIP_TOP_BOTTOM)
    fade = Image.new("L", refl.size, 0)
    fp = fade.load()
    for yy in range(refl.height):
        v = int(95 * max(0.0, 1.0 - yy / (refl.height * 0.55)) ** 1.6)
        for xx in range(0, refl.width):
            fp[xx, yy] = v
    refl_alpha = ImageChops.multiply(refl.getchannel("A"), fade)
    refl.putalpha(refl_alpha)
    refl = refl.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(refl, (x, bottom - int(car.height * 0.03)))
    # Hız izleri: aracın arkasından (sağ) süzülen yatay çizgiler
    trails = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(trails)
    rnd = random.Random(hash(t["id"]) & 0xFFFF)
    for _ in range(26):
        yy = rnd.uniform(y + car.height * 0.25, bottom - car.height * 0.12)
        x0 = x + car.width * rnd.uniform(0.62, 0.9)
        x1 = x0 + rnd.uniform(W * 0.15, W * 0.45)
        col = rgb(t["accent"]) if rnd.random() < 0.6 else rgb(t["accent2"])
        d.line([(x0, yy), (x1, yy)], fill=col + (rnd.randint(60, 150),), width=rnd.randint(2, 6))
    img.alpha_composite(directional_blur(trails, 6))
    img.alpha_composite(car, (x, y))
    return (x, y, car.width, car.height)


# --- Yazı ve logo ----------------------------------------------------------------------------------

def name_parts(cid):
    data = json.load(open(CATALOG, encoding="utf-8"))
    cars = data.get("cars", data) if isinstance(data, dict) else data
    if isinstance(cars, list):
        cars = {c.get("id"): c for c in cars}
    entry = cars.get(cid, {})
    name = (entry.get("display_name") or cid.replace("_", " ")).upper()
    brand, _, model = name.partition(" ")
    return (brand, model) if model else ("", brand)


def draw_text(img, t, brand, model):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    left, top = int(W * 0.05), int(H * 0.11)
    size = 170
    f_model = font(size)
    while d.textlength(model, font=f_model) > W * 0.52 and size > 80:
        size -= 6
        f_model = font(size)
    f_brand = font(int(size * 0.36))
    brand_spaced = " ".join(brand)
    d.text((left + 6, top), brand_spaced, font=f_brand, fill=rgb(t["accent"]) + (255,))
    my = top + int(size * 0.42)
    d.text((left, my), model, font=f_model, fill=(255, 255, 255, 255))
    bar_y = my + int(size * 1.24)
    bar_w = int(min(d.textlength(model, font=f_model), W * 0.5) * 0.7)
    d.rounded_rectangle([left + 4, bar_y, left + 4 + bar_w, bar_y + 14], radius=7, fill=rgb(t["accent"]) + (255,))
    d.rounded_rectangle([left + 4 + bar_w + 14, bar_y, left + 4 + bar_w + 70, bar_y + 14], radius=7, fill=rgb(t["accent2"]) + (255,))
    # İtalik: sağa yatık (yazı katmanı yatay kaydırılır)
    shear = 0.18
    layer = layer.transform(layer.size, Image.AFFINE, (1, shear, -shear * top * 1.6, 0, 1, 0), Image.BICUBIC)
    glow = Image.new("RGBA", img.size, rgb(t["accent"]) + (0,))
    glow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.8)))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow.putalpha(layer.getchannel("A").filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.7)))
    img.alpha_composite(glow)
    img.alpha_composite(shadow, (6, 8))
    img.alpha_composite(layer)


def draw_logo(img):
    if not os.path.exists(LOGO):
        return
    logo = Image.open(LOGO).convert("RGBA")
    w = int(W * 0.25)
    logo = logo.convert("RGBa").resize((w, int(logo.height * w / logo.width)), Image.LANCZOS).convert("RGBA")
    x, y = int(W * 0.045), int(H * 0.95) - logo.height
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mask = Image.new("L", img.size, 0)
    mask.paste(logo.getchannel("A"), (x + 6, y + 10))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.6)))
    img.alpha_composite(shadow)
    img.alpha_composite(logo, (x, y))


def finish(img, t, rnd):
    rgbimg = img.convert("RGB")
    # Bloom: parlak bölgeler büyük bulanıklıkla ekran karışımı
    # (eşik yüksek: beyaz / gümüş gövdeler parlayıp ayrıntısını kaybetmesin — yalnızca ışık çizgileri, güneş, hale)
    bright = rgbimg.point(lambda v: max(0, v - 214) * 4)
    bloom = bright.filter(ImageFilter.GaussianBlur(26))
    rgbimg = screen(rgbimg, bloom, 0.5)
    # Vinyet
    vig = Image.new("L", (W // 8, H // 8), 0)
    vp = vig.load()
    for y in range(vig.height):
        for x in range(vig.width):
            dx = (x / vig.width - 0.55) * 1.6
            dy = (y / vig.height - 0.5) * 2.0
            vp[x, y] = int(255 * min(1.0, max(0.0, (math.hypot(dx, dy) - 0.55) * 0.9)))
    vig = vig.resize((W, H), Image.BILINEAR).filter(ImageFilter.GaussianBlur(20))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    rgbimg = Image.composite(dark, rgbimg, vig.point(lambda v: int(v * 0.55)))
    rgbimg = ImageEnhance.Contrast(rgbimg).enhance(1.06)
    rgbimg = ImageEnhance.Color(rgbimg).enhance(1.08)
    # İnce gren (küçültmede yumuşar, bantlaşmayı kırar)
    noise = Image.effect_noise((W, H), 18).convert("RGB")
    rgbimg = Image.blend(rgbimg, ImageChops.overlay(rgbimg, noise), 0.06)
    out = rgbimg.resize(FINAL, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    return out


def compose(t):
    rnd = random.Random(t["id"])
    img = STYLES[t["style"]](t, rnd)
    car = load_car(t["id"])
    place_car(img, car, t)
    brand, model = name_parts(t["id"])
    draw_text(img, t, brand, model)
    draw_logo(img)
    out = finish(img, t, rnd)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, t["id"] + ".jpg")
    out.save(path, quality=90, optimize=True, progressive=False)
    print("afiş:", path)


def main():
    wanted = set(sys.argv[1:])
    data = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "posters.json"), encoding="utf-8"))
    for t in data["posters"]:
        if wanted and t["id"] not in wanted:
            continue
        compose(t)


if __name__ == "__main__":
    main()
