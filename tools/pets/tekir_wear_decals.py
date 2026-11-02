"""TEKİR KIYAFETLERİ — yama/çıkartma görüntüleri (sistem python3 + PIL; Blender'ın python'unda PIL yok).
tekir_wear.py bunları 3B'de kıyafetin yüzeyine yansıtır.

  python3 tools/pets/tekir_wear_decals.py <çıktı_klasörü>

  patch_autoyard.png  siyah zemin, beyaz AUTO YARD (yarış montu yan yaması)
  roundel_7.png       beyaz yuvarlak, kırmızı halka, 7 (yarış montu sol omuz)
  roundel_flag.png    damalı bayrak yuvarlağı (yarış montu sağ omuz)
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "ui/theme/fonts/AlfaSlabOne-Regular.ttf")
S = 4   # süper örnekleme


def fit_text(draw, text: str, box_w: int, box_h: int) -> ImageFont.FreeTypeFont:
    size = box_h
    while size > 8:
        font = ImageFont.truetype(FONT, size)
        l, t, r, b = draw.textbbox((0, 0), text, font=font)
        if r - l <= box_w and b - t <= box_h:
            return font
        size -= 2
    return ImageFont.truetype(FONT, size)


def centered(draw, text: str, font, cx: float, cy: float, fill) -> None:
    l, t, r, b = draw.textbbox((0, 0), text, font=font)
    draw.text((cx - (l + r) / 2, cy - (t + b) / 2), text, font=font, fill=fill)


def patch_autoyard(out: str) -> None:
    W, H = 512 * S // 2, 160 * S // 2
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = H // 5
    d.rounded_rectangle((0, 0, W - 1, H - 1), radius=r, fill=(245, 245, 245, 255))
    m = H // 14
    d.rounded_rectangle((m, m, W - 1 - m, H - 1 - m), radius=r - m, fill=(22, 22, 26, 255))
    font = fit_text(d, "AUTO YARD", int(W * 0.84), int(H * 0.56))
    centered(d, "AUTO YARD", font, W / 2, H / 2, (250, 250, 250, 255))
    im.resize((W // S, H // S), Image.LANCZOS).save(out)


def roundel_7(out: str) -> None:
    N = 256 * S // 2
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, N - 1, N - 1), fill=(250, 250, 250, 255))
    ring = N // 11
    d.ellipse((ring, ring, N - 1 - ring, N - 1 - ring), fill=(196, 24, 32, 255))
    inner = ring * 2
    d.ellipse((inner, inner, N - 1 - inner, N - 1 - inner), fill=(250, 250, 250, 255))
    font = fit_text(d, "7", int(N * 0.5), int(N * 0.56))
    centered(d, "7", font, N / 2, N / 2, (22, 22, 26, 255))
    im.resize((N // S, N // S), Image.LANCZOS).save(out)


def roundel_flag(out: str) -> None:
    N = 256 * S // 2
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, N - 1, N - 1), fill=(250, 250, 250, 255))
    ring = N // 11
    # Damalı iç daire: kare kare çiz, sonra daire maskesiyle kırp
    sq = Image.new("RGBA", (N, N), (250, 250, 250, 255))
    ds = ImageDraw.Draw(sq)
    n = 6
    c = (N - 2 * ring * 2) / n
    for i in range(n):
        for j in range(n):
            if (i + j) % 2 == 0:
                x0, y0 = ring * 2 + i * c, ring * 2 + j * c
                ds.rectangle((x0, y0, x0 + c, y0 + c), fill=(22, 22, 26, 255))
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).ellipse((ring * 2, ring * 2, N - 1 - ring * 2, N - 1 - ring * 2), fill=255)
    d.ellipse((ring, ring, N - 1 - ring, N - 1 - ring), fill=(22, 22, 26, 255))
    im.paste(sq, (0, 0), mask)
    im.resize((N // S, N // S), Image.LANCZOS).save(out)


def main() -> None:
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    patch_autoyard(os.path.join(out, "patch_autoyard.png"))
    roundel_7(os.path.join(out, "roundel_7.png"))
    roundel_flag(os.path.join(out, "roundel_flag.png"))
    print("RAPOR çıkartmalar", out)


if __name__ == "__main__":
    main()
