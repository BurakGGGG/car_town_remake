#!/usr/bin/env python3
"""ARMA SÖKÜCÜ yardımcısı: debadge.py görünümlerine koordinat ızgarası basar (logo bölgesi buradan okunur) ve
önce / sonra karşılaştırma sayfası çıkarır. PIL ister (sistem Python'u).

  python3 -I tools/debadge/grid.py grid <id> [görünüm ...]     → ct_shots/debadge/<id>/grid_<görünüm>.png
  python3 -I tools/debadge/grid.py crop <id> <görünüm> x0 y0 x1 y1 [ölçek]  → yakın çekim (ızgaralı)
  python3 -I tools/debadge/grid.py compare <id> [görünüm ...]  → compare.jpg (üst: önce, alt: sonra)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.expanduser("~/Projects/ct_shots/debadge")
VIEWS = ["a", "b", "a_top", "b_top", "side_p", "side_n", "top", "a_low"]
BG = (236, 229, 214)


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def flat(path):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGB", im.size, BG)
    bg.paste(im, mask=im.getchannel("A"))
    return bg


def gridify(im, x0=0, y0=0, scale=1.0, step=50):
    d = ImageDraw.Draw(im)
    f = font(max(10, int(11 * min(scale, 2))))
    w, h = im.size
    gx = (x0 // step) * step
    while (gx - x0) * scale < w:
        X = (gx - x0) * scale
        if X >= 0:
            strong = gx % 100 == 0
            d.line([(X, 0), (X, h)], fill=(255, 0, 160) if strong else (255, 140, 200), width=1)
            if strong:
                d.text((X + 2, 2), str(gx), fill=(160, 0, 100), font=f)
        gx += step
    gy = (y0 // step) * step
    while (gy - y0) * scale < h:
        Y = (gy - y0) * scale
        if Y >= 0:
            strong = gy % 100 == 0
            d.line([(0, Y), (w, Y)], fill=(0, 150, 255) if strong else (140, 200, 255), width=1)
            if strong:
                d.text((2, Y + 2), str(gy), fill=(0, 80, 160), font=f)
        gy += step
    return im


def cmd_grid(cid, views):
    for v in views or VIEWS:
        p = os.path.join(ROOT, cid, f"{v}.png")
        if not os.path.exists(p):
            continue
        im = gridify(flat(p))
        im.save(os.path.join(ROOT, cid, f"grid_{v}.png"))
        print(os.path.join(ROOT, cid, f"grid_{v}.png"))


def cmd_crop(cid, view, x0, y0, x1, y1, scale=3.0, suffix=""):
    im = flat(os.path.join(ROOT, cid, f"{view}{suffix}.png")).crop((x0, y0, x1, y1))
    im = im.resize((int((x1 - x0) * scale), int((y1 - y0) * scale)), Image.NEAREST)
    step = 10 if scale >= 3 else 25
    im = gridify(im, x0, y0, scale, step)
    out = os.path.join(ROOT, cid, f"crop_{view}{suffix}_{x0}_{y0}.png")
    im.save(out)
    print(out)


def cmd_sheet(cid):
    """İki özet sayfası (koordinatlar özgün piksel): sheet1 = a, b, a_top, b_top (%50); sheet2 = yanlar (%70)."""
    def tile(v, s):
        p = os.path.join(ROOT, cid, f"{v}.png")
        im = flat(p)
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        return gridify(im, 0, 0, s, 50)
    t = [tile(v, 0.5) for v in ("a", "b", "a_top", "b_top")]
    W = max(t[0].width + t[1].width, t[2].width + t[3].width) + 10
    H = max(t[0].height, t[1].height) + max(t[2].height, t[3].height) + 10
    s1 = Image.new("RGB", (W, H), (255, 255, 255))
    s1.paste(t[0], (0, 0)); s1.paste(t[1], (t[0].width + 10, 0))
    y = max(t[0].height, t[1].height) + 10
    s1.paste(t[2], (0, y)); s1.paste(t[3], (t[2].width + 10, y))
    d = ImageDraw.Draw(s1); f = font(16)
    for (x, yy), name in (((4, 14), "a"), ((t[0].width + 14, 14), "b"), ((4, y + 14), "a_top"), ((t[2].width + 14, y + 14), "b_top")):
        d.text((x + 30, yy), name, fill=(200, 0, 0), font=f)
    s1.save(os.path.join(ROOT, cid, "sheet1.png"))
    t = [tile(v, 0.7) for v in ("side_p", "side_n")]
    s2 = Image.new("RGB", (max(x.width for x in t), sum(x.height for x in t) + 10), (255, 255, 255))
    s2.paste(t[0], (0, 0)); s2.paste(t[1], (0, t[0].height + 10))
    d = ImageDraw.Draw(s2)
    d.text((40, 14), "side_p", fill=(200, 0, 0), font=f); d.text((40, t[0].height + 24), "side_n", fill=(200, 0, 0), font=f)
    s2.save(os.path.join(ROOT, cid, "sheet2.png"))
    print(os.path.join(ROOT, cid, "sheet1.png"))


def cmd_verify(ids, out):
    """badges.json'daki her bölgenin önce / sonra kırpıntısı tek sayfada (araç başına bir satır)."""
    import json
    spec = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "badges.json"), encoding="utf-8"))
    rows = []
    for cid in ids:
        tiles = []
        for view, regions in spec.get(cid, {}).items():
            if view.startswith("_"):
                continue
            a = os.path.join(ROOT, cid, f"{view}.png"); b = os.path.join(ROOT, cid, f"{view}_after.png")
            if not (os.path.exists(a) and os.path.exists(b)):
                continue
            A, B = flat(a), flat(b)
            for r in regions:
                if isinstance(r, dict) and "p" in r:
                    xs = [q[0] for q in r["p"]]; ys = [q[1] for q in r["p"]]
                    box = [min(xs), min(ys), max(xs), max(ys)]
                elif isinstance(r, dict):
                    cx, cy, rx, ry = r["e"]
                    box = [cx - rx, cy - ry, cx + rx, cy + ry]
                else:
                    box = r[:4]
                x0, y0, x1, y1 = box
                pad = max(14, int(0.35 * max(x1 - x0, y1 - y0)))
                c = (max(0, x0 - pad), max(0, y0 - pad), min(A.width, x1 + pad), min(A.height, y1 + pad))
                ca, cb = A.crop(c), B.crop(c)
                s = min(2.0, 110 / ca.height, 220 / ca.width)
                ca = ca.resize((max(1, int(ca.width * s)), max(1, int(ca.height * s))))
                cb = cb.resize(ca.size)
                t = Image.new("RGB", (ca.width, ca.height * 2 + 2), (255, 0, 0))
                t.paste(ca, (0, 0)); t.paste(cb, (0, ca.height + 2))
                tiles.append(t)
        if tiles:
            rows.append((cid, tiles))
    W = 1600
    lines = []
    for cid, tiles in rows:
        x, line, h = 0, [], 0
        for t in tiles:
            if x + t.width > W and line:
                lines.append((cid, line, h)); cid = ""; line, x, h = [], 0, 0
            line.append(t); x += t.width + 6; h = max(h, t.height)
        lines.append((cid, line, h))
    H = sum(h + 18 for _, _, h in lines)
    sheet = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(sheet); f = font(13)
    y = 0
    for cid, line, h in lines:
        d.text((2, y + 1), cid, fill=(0, 0, 0), font=f)
        x = 0
        for t in line:
            sheet.paste(t, (x, y + 16)); x += t.width + 6
        y += h + 18
    sheet.save(out, quality=88)
    print(out, sheet.size)


def cmd_compare(cid, views):
    rows = []
    for v in views or VIEWS:
        a = os.path.join(ROOT, cid, f"{v}.png")
        b = os.path.join(ROOT, cid, f"{v}_after.png")
        if os.path.exists(a) and os.path.exists(b):
            rows.append((flat(a), flat(b)))
    if not rows:
        return
    W = 700
    tiles = []
    for a, b in rows:
        s = W / a.width
        tiles.append((a.resize((W, int(a.height * s))), b.resize((W, int(b.height * s)))))
    H = sum(t[0].height for t in tiles)
    sheet = Image.new("RGB", (W * 2 + 10, H), (255, 255, 255))
    y = 0
    for a, b in tiles:
        sheet.paste(a, (0, y)); sheet.paste(b, (W + 10, y)); y += a.height
    out = os.path.join(ROOT, cid, "compare.jpg")
    sheet.save(out, quality=88)
    print(out)


if __name__ == "__main__":
    mode, cid = sys.argv[1], sys.argv[2]
    rest = sys.argv[3:]
    if mode == "grid":
        cmd_grid(cid, rest)
    elif mode == "crop":
        view = rest[0]
        x0, y0, x1, y1 = map(int, rest[1:5])
        scale = float(rest[5]) if len(rest) > 5 else 3.0
        cmd_crop(cid, view, x0, y0, x1, y1, scale, rest[6] if len(rest) > 6 else "")
    elif mode == "compare":
        cmd_compare(cid, rest)
    elif mode == "sheet":
        cmd_sheet(cid)
    elif mode == "verify":
        # verify <çıktı.jpg> <id> [<id> ...]
        cmd_verify(rest, cid)
