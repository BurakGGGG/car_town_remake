"""HURDALIK KARTPOSTALI — 2. adım: eski, sararmış kartpostal fotoğrafları + ortak kırışık katmanı.

Girdi (render_cars.gd çıktısı, <work>): car_<id>.png (saydam, 2400x1560), scene_<ad>.png (1242x702).
Çıktı (depoda):
  assets/ui/postcards/<id>.jpg   kartın İÇ fotoğrafı 1242x702: kademe manzarası + temiz araç + gölge, sonra eskitme
                                 (renk solar, sepyaya kayar, siyahlar kalkar, sararır, kenarlar kararır, leke, gren, toz)
  assets/ui/postcards/kirisik.png bütün kart 1290x750 saydam katman: dikey + yatay kat izi, yumuşak kağıt dalgası,
                                 kenar aşınması ve kararması, sol üst kıvrık köşe (kesik üçgen tamamen saydam)
Oyunda (JunkyardPostcard) kart 637x370 tuval birimi: kağıt kenarı 16/860, kesik köşe 30/860 (fotoğrafa değmez).
Arka yüzde aynı katman yatay aynalanır (kat izleri kartın arkasından görünür, kıvrık köşe sağ üstte).

Kullanım: python3 tools/postcards/make_postcards.py <work> [<araç_id> ...]   (hepsi: tools/postcards/build.sh)
Yalnız PIL gerekir (numpy yok).
"""
import json
import math
import random
import sys
import zlib
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/ui/postcards"
PW, PH = 1242, 702          # iç fotoğraf
CW, CH = 1290, 750          # bütün kart (oran 860:500)
BORDER = 24                 # 16/860 × CW
DOG = 45                    # kesik köşe: 30/860 × CW
SCENE_OF_TIER = {"basic": "mahalle", "classic": "sahil", "race": "ralli"}
# Araç fotoğrafta: en çok bu kadar geniş / yüksek, tabanı bu satırda, ortası bu sütunda (sol üst yazıya yer kalır)
CAR_MAX_W, CAR_MAX_H = 0.71 * PW, 0.60 * PH
CAR_BOTTOM, CAR_CENTER_X = 0.935 * PH, 0.585 * PW


def tiers() -> dict:
    data = json.loads((ROOT / "vehicles/restorations.json").read_text(encoding="utf-8"))
    return {c["id"]: c["tier"] for c in data["cars"]}


def compose(work: Path, car_id: str, tier: str) -> Image.Image:
    base = Image.open(work / f"scene_{SCENE_OF_TIER[tier]}.png").convert("RGBA")
    car = Image.open(work / f"car_{car_id}.png").convert("RGBA")
    car = car.crop(car.getbbox())
    k = min(CAR_MAX_W / car.width, CAR_MAX_H / car.height)
    car = car.resize((round(car.width * k), round(car.height * k)), Image.LANCZOS)
    left = round(CAR_CENTER_X - car.width / 2)
    top = round(CAR_BOTTOM - car.height)
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sw, sh = car.width * 0.86, max(car.width * 0.08, 40)
    cx = left + car.width * 0.5
    ImageDraw.Draw(shadow).ellipse((cx - sw / 2, CAR_BOTTOM - sh * 0.62, cx + sw / 2, CAR_BOTTOM + sh * 0.38), fill=(20, 16, 12, 130))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12)))
    # temas gölgesi: tekerlerin altında daha koyu, dar şerit (araç havada durmasın)
    contact = Image.new("RGBA", base.size, (0, 0, 0, 0))
    cw2, ch2 = car.width * 0.72, max(car.width * 0.03, 14)
    ImageDraw.Draw(contact).ellipse((cx - cw2 / 2, CAR_BOTTOM - ch2 * 0.7, cx + cw2 / 2, CAR_BOTTOM + ch2 * 0.3), fill=(14, 10, 8, 150))
    base.alpha_composite(contact.filter(ImageFilter.GaussianBlur(5)))
    base.alpha_composite(car, (left, top))
    return base.convert("RGB")


def age(img: Image.Image, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    # 1) renk solar, sepyaya kayar (araç rengi yine tanınır)
    img = ImageEnhance.Color(img).enhance(0.74)
    sepia = ImageOps.colorize(ImageOps.grayscale(img), black="#3B2A16", white="#FFF1D2")
    img = Image.blend(img, sepia, 0.30)
    # 2) baskı solgunluğu: siyahlar kalkar, kontrast düşer
    img = img.point(lambda v: int(30 + v * 0.84))
    # 3) sararma (çarpma)
    img = Image.blend(img, ImageChops.multiply(img, Image.new("RGB", img.size, (247, 226, 178))), 0.75)
    # 4) kenar kararması: kahverengi vinyet
    mask = Image.radial_gradient("L").resize(img.size, Image.BICUBIC)
    mask = mask.point(lambda v: int(min(255, max(0, (v - 120) * 1.5))))
    img = Image.composite(ImageChops.multiply(img, Image.new("RGB", img.size, (176, 132, 82))), img, mask)
    # 5) lekeler: soluk kahve halkası (köşelerden birinde) + iki yumuşak leke
    stain = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(stain)
    rx, ry = rnd.choice([(1010, 470), (40, 470), (1000, 30), (60, 40)])
    d.ellipse((rx, ry, rx + 200, ry + 180), outline=150, width=9)
    for _ in range(2):
        x, y = rnd.uniform(0, PW - 220), rnd.uniform(0, PH - 150)
        d.ellipse((x, y, x + rnd.uniform(120, 240), y + rnd.uniform(90, 170)), fill=rnd.randint(60, 90))
    stain = stain.filter(ImageFilter.GaussianBlur(10))
    brown = ImageChops.multiply(img, Image.new("RGB", img.size, (205, 160, 104)))
    img = Image.composite(brown, img, stain.point(lambda v: int(v * 0.55)))
    # 6) gren
    noise = Image.effect_noise(img.size, 9).filter(ImageFilter.GaussianBlur(0.5))
    img = ImageChops.add(img, Image.merge("RGB", (noise, noise, noise)), 1.0, -128)
    # 7) toz / ince çizik (açık)
    specks = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(specks)
    for _ in range(140):
        x, y, r = rnd.uniform(0, PW), rnd.uniform(0, PH), rnd.uniform(0.6, 1.8)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 248, 232, rnd.randint(60, 150)))
    for _ in range(14):
        x, y, a, ln = rnd.uniform(0, PW), rnd.uniform(0, PH), rnd.uniform(0, math.pi), rnd.uniform(20, 70)
        d.line((x, y, x + math.cos(a) * ln, y + math.sin(a) * ln), fill=(255, 246, 228, rnd.randint(50, 110)), width=1)
    out = img.convert("RGBA")
    out.alpha_composite(specks)
    return out.convert("RGB")


def _jitter(p0, p1, step, amp, rnd):
    (x0, y0), (x1, y1) = p0, p1
    n = max(2, int(math.dist(p0, p1) / step))
    nx, ny = -(y1 - y0), x1 - x0
    ln = math.hypot(nx, ny) or 1.0
    nx, ny = nx / ln, ny / ln
    pts = []
    for i in range(n + 1):
        t = i / n
        o = 0.0 if i in (0, n) else rnd.uniform(-amp, amp)
        pts.append((x0 + (x1 - x0) * t + nx * o, y0 + (y1 - y0) * t + ny * o))
    return pts, (nx, ny)


def _crease(layer, p0, p1, rnd, strength=1.0, step=46, amp=5, soft=1.0):
    """Kat izi: koyu çukur + yanında ışık alan sırt."""
    pts, (nx, ny) = _jitter(p0, p1, step, amp, rnd)
    dark = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(dark).line(pts, fill=(52, 34, 12, int(120 * strength)), width=max(2, int(4 * soft)), joint="curve")
    light = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    shifted = [(x + nx * 3.5 * soft, y + ny * 3.5 * soft) for x, y in pts]
    ImageDraw.Draw(light).line(shifted, fill=(255, 250, 236, int(150 * strength)), width=max(2, int(3 * soft)), joint="curve")
    layer.alpha_composite(dark.filter(ImageFilter.GaussianBlur(2.2 * soft)))
    layer.alpha_composite(light.filter(ImageFilter.GaussianBlur(1.3 * soft)))


def wrinkles() -> Image.Image:
    rnd = random.Random(11)
    layer = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    # kenar kararması (kağıt kodla düz renk çizilir; eskime burada)
    edge = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(edge)
    for i in range(30):
        d.rectangle((i, i, CW - 1 - i, CH - 1 - i), outline=(110, 72, 30, int(80 * (1 - i / 30) ** 2)))
    layer.alpha_composite(edge.filter(ImageFilter.GaussianBlur(3)))
    # ana kıvrımlar: cüzdanda katlanmış kart
    _crease(layer, (470, -10), (520, CH + 10), rnd, 1.0, amp=4)
    _crease(layer, (-10, 300), (CW + 10, 470), rnd, 0.75, amp=6)
    _crease(layer, (880, CH + 10), (CW + 10, 470), rnd, 0.7, amp=5)
    # yumuşak buruşukluk: düşük frekanslı açık / koyu lekeler (kağıt dalgalanması)
    blot = Image.effect_noise((30, 18), 46).resize((CW, CH), Image.BICUBIC).filter(ImageFilter.GaussianBlur(18))
    dark = Image.new("RGBA", (CW, CH), (60, 40, 14, 0))
    dark.putalpha(blot.point(lambda v: int(max(0, 128 - v) * 0.55)))
    light = Image.new("RGBA", (CW, CH), (255, 249, 232, 0))
    light.putalpha(blot.point(lambda v: int(max(0, v - 128) * 0.5)))
    layer.alpha_composite(dark)
    layer.alpha_composite(light)
    # birkaç ince, kavisli buruşuk izi (sert çizik değil)
    for _ in range(16):
        x, y, a, ln = rnd.uniform(0, CW), rnd.uniform(0, CH), rnd.uniform(0, math.pi), rnd.uniform(70, 200)
        _crease(layer, (x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln), rnd, rnd.uniform(0.12, 0.24), step=24, amp=6, soft=1.8)
    # kenar aşınması: kenar boyunca açık lif noktaları
    d = ImageDraw.Draw(layer)
    for _ in range(900):
        side, t, depth = rnd.randrange(4), rnd.uniform(0, 1), abs(rnd.gauss(0, 4))
        x, y = [(t * CW, depth), (t * CW, CH - depth), (depth, t * CH), (CW - depth, t * CH)][side]
        r = rnd.uniform(0.6, 2.0)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(250, 242, 222, rnd.randint(90, 200)))
    # kesik köşe: tamamen saydam (ImageDraw RGBA'ya karıştırmadan yazar); kanadın altına düşen gölge, sonra kanat
    d.polygon([(0, 0), (DOG + 2, 0), (0, DOG + 2)], fill=(0, 0, 0, 0))
    shade = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon([(DOG, 0), (0, DOG), (DOG + 4, DOG + 4)], fill=(0, 0, 0, 90))
    layer.alpha_composite(shade.filter(ImageFilter.GaussianBlur(3)))
    d = ImageDraw.Draw(layer)
    d.polygon([(0, 0), (DOG, 0), (0, DOG)], fill=(0, 0, 0, 0))
    d.polygon([(DOG, 0), (0, DOG), (DOG, DOG)], fill=(226, 210, 172, 255))
    d.line([(DOG, 0), (0, DOG)], fill=(150, 120, 80, 255), width=2)
    return layer


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("kullanım: make_postcards.py <work> [<araç_id> ...]")
    work = Path(sys.argv[1]).expanduser()
    wanted = set(sys.argv[2:])
    OUT.mkdir(parents=True, exist_ok=True)
    made = 0
    for car_id, tier in tiers().items():
        if wanted and car_id not in wanted:
            continue
        if not (work / f"car_{car_id}.png").exists():
            print("ATLANDI (çizim yok)", car_id)
            continue
        photo = age(compose(work, car_id, tier), zlib.crc32(car_id.encode()))
        photo.save(OUT / f"{car_id}.jpg", quality=90)
        made += 1
    # Ortak katman yalnız tam üretimde (ya da yoksa) yazılır: gürültüsü rastgele, tek araç için her koşu değiştirmesin
    overlay = OUT / "kirisik.png"
    if not wanted or not overlay.exists():
        wrinkles().save(overlay, optimize=True)
    print(f"kartpostal: {made} fotoğraf{' + kirisik.png' if not wanted else ''} → {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
