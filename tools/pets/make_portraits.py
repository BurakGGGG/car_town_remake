"""HAYVANLAR ekranı portreleri (2026-11-03): qa/pet_portraits.gd'nin karelerinden (oturan kedi, gözler açık,
aksesuarsız; 1200x900 pencere → 1440x831 kare) tam boy fotoğraf ve yuvarlak yüz keser.

  QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_portraits.gd --resolution 1200x900
  python3 tools/pets/make_portraits.py [~/Projects/ct_shots/pets/portre]

Çıktı assets/pets/portraits/<çeşit>.jpg (400x490) + <çeşit>_face.png (256², yuvarlak, saydam köşeler).
Kesim kutuları kedinin kadrajdaki yerine göre (kamera qa/pet_portraits.gd'de sabit).
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/pets/portraits")
BODY = (505, 262, 905, 752)
FACE = (620, 268, 800, 448)


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Projects/ct_shots/pets/portre")
    os.makedirs(OUT, exist_ok=True)
    for name in ("orange", "white", "black"):
        im = Image.open(os.path.join(src, name + ".png")).convert("RGB")
        im.crop(BODY).save(os.path.join(OUT, name + ".jpg"), quality=90)
        face = im.crop(FACE).resize((256, 256), Image.LANCZOS)
        mask = Image.new("L", (1024, 1024), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, 1023, 1023), fill=255)
        mask = mask.resize((256, 256), Image.LANCZOS)   # yumuşak kenar
        out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        out.paste(face, (0, 0), mask)
        out.save(os.path.join(OUT, name + "_face.png"))
        print("RAPOR portre", name)


if __name__ == "__main__":
    main()
