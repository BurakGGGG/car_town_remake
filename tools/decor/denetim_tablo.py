"""DEKOR DENETİM TABLOSU: qa/dekor_denetim.gd'nin çizdiği <id>_a.png (oyun açısı) + <id>_b.png (arka) çiftlerini
etiketli tablolara dizer → <klasör>/tablo_NN.png. Gözle taramak için (parçası kaymış / taşmış eşya).
Kullanım: python3 tools/decor/denetim_tablo.py [klasör] [sütun] [satır] [hücre_px]
"""
import os
import sys

from PIL import Image, ImageDraw

DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Projects/ct_shots/dekor_denetim")
COLS = int(sys.argv[2]) if len(sys.argv) > 2 else 4
ROWS = int(sys.argv[3]) if len(sys.argv) > 3 else 5
CELL = int(sys.argv[4]) if len(sys.argv) > 4 else 200
LABEL = 18

ids = sorted(f[:-6] for f in os.listdir(DIR) if f.endswith("_a.png"))
per = COLS * ROWS
for page in range(0, len(ids), per):
    chunk = ids[page:page + per]
    sheet = Image.new("RGB", (COLS * CELL * 2, ROWS * (CELL + LABEL)), (30, 30, 30))
    draw = ImageDraw.Draw(sheet)
    for i, item in enumerate(chunk):
        x, y = (i % COLS) * CELL * 2, (i // COLS) * (CELL + LABEL)
        for j, side in enumerate("ab"):
            path = os.path.join(DIR, f"{item}_{side}.png")
            if os.path.exists(path):
                sheet.paste(Image.open(path).convert("RGB").resize((CELL, CELL)), (x + j * CELL, y + LABEL))
        draw.text((x + 4, y + 3), item, fill=(255, 230, 120))
        draw.line([(x, y), (x, y + CELL + LABEL)], fill=(80, 80, 80))
    out = os.path.join(DIR, f"tablo_{page // per + 1:02d}.png")
    sheet.save(out)
    print(out, len(chunk))
