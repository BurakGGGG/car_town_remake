#!/usr/bin/env python3
"""mesh_probe.gd'nin old/ ve new/ kadrajlarını karşılaştırır (Pillow).

Her kadraj için: farklı piksel sayısı (kanal farkı > 8 / > 24 / > 48, 0–255), farkın olduğu bölgede
PSNR ve yan yana görüntü (eski | yeni | fark ×4) → <OUT>/kiyas/.
Kullanım: python3 qa/size_audit/mesh_compare.py [/home/burak/Projects/ct_shots/mesh_probe] [etiket=new] [taban=old]
"""
import os, sys, math
from PIL import Image, ImageChops

root = sys.argv[1] if len(sys.argv) > 1 else "/home/burak/Projects/ct_shots/mesh_probe"
tag = sys.argv[2] if len(sys.argv) > 2 else "new"
base = sys.argv[3] if len(sys.argv) > 3 else "old"
os.makedirs(os.path.join(root, "kiyas_" + tag), exist_ok=True)
rows = []
for name in sorted(os.listdir(os.path.join(root, tag))):
    po, pn = os.path.join(root, base, name), os.path.join(root, tag, name)
    if not os.path.exists(po):
        continue
    a, b = Image.open(po).convert("RGB"), Image.open(pn).convert("RGB")
    d = ImageChops.difference(a, b)
    r, g, bl = d.split()
    m = ImageChops.lighter(ImageChops.lighter(r, g), bl)      # piksel başına en büyük kanal farkı
    hist = m.histogram()
    over = lambda t: sum(hist[t + 1:])
    box = m.point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        rows.append((name, 0, 0, 0, 99.0))
        continue
    x0, y0, x1, y1 = box
    box = (max(0, x0 - 24), max(0, y0 - 24), min(a.width, x1 + 24), min(a.height, y1 + 24))
    dh = d.crop(box).histogram()
    n = (box[2] - box[0]) * (box[3] - box[1]) * 3
    se = sum(c * (i % 256) ** 2 for i, c in enumerate(dh))
    psnr = 99.0 if se == 0 else 10 * math.log10(255.0 ** 2 / (se / n))
    rows.append((name, over(8), over(24), over(48), psnr))
    ca, cb = a.crop(box), b.crop(box)
    cd = d.crop(box).point(lambda v: min(255, v * 4))
    sheet = Image.new("RGB", (ca.width * 3, ca.height))
    for k, im in enumerate((ca, cb, cd)):
        sheet.paste(im, (ca.width * k, 0))
    sheet.save(os.path.join(root, "kiyas_" + tag, name))

print("%-44s %8s %8s %8s %8s" % ("kadraj", ">8", ">24", ">48", "PSNR dB"))
for name, a8, a24, a48, p in rows:
    print("%-44s %8d %8d %8d %8.1f" % (name[:-4], a8, a24, a48, p))
