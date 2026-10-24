#!/usr/bin/env python3
"""Tekerlerin ARACA BAKAN iç yüzlerini (lastik iç yanağı, jantın arkası) albedo dokusunda koyu kauçuğa boyar.

Neden (2026-10-24, kullanıcı: "önden arkadan lastikler yok gibi, modifiye ekranında lastik içleri boş"): Tripo
dokularında görünmeyen yüzler gri / beyazımsı doldurulmuş (iç yanak sRGB parlaklığı 0,2–0,45, jant arkası 0,8'e kadar;
dış yanak ~0,1). Önden / arkadan bakınca karşı tekerin iç yanağı tamponun altından gri bir yay olarak görünüyor ve
jant sanılıyor; lastiğin kendisi tamponun arkasında kaldığı için araç lastiksiz duruyor.

Yöntem: teker grubundaki parçaların, normali aracın ortasına bakan (x · taraf < −0,5) üçgenleri UV uzayında
taranır; YALNIZCA bu üçgenlerin kullandığı texel'ler koyulaştırılır (başka bir üçgenin — dış yanak, sırt, gövde —
kullandığı texel'e dokunulmaz; beyaz yanak şeridi korunur). Çevresindeki kullanılmayan dolgu texel'leri de koyulaşır
(mipmap'te gri hâle kalmasın). Dokusuz kendi materyali olan tekerler (Toros) atlanır.
Doku JPEG'i yerinde yazılır (kalite 95, 4:4:4); JPEG yorumundaki işaretle ikinci kez uygulanmaz. İlk dokunuşta özgün
dosya --backup klasörüne kopyalanır. DİKKAT: tools/debadge "apply" dokuyu kendi sakladığı özgünden yeniden kurar —
sonra bu betik yeniden koşulmalı.

Kullanım:
  godot-4 --headless --path . -s res://tools/wheel_parts.gd | grep '^AXES ' | cut -c6- > /tmp/axes.json
  python3 tools/tire_inner_paint.py --axes /tmp/axes.json [--dry] [--backup <klasör>] assets/cars/optimized/*.glb
Sonra --import, küçük resimler (tools/make_car_thumbs.gd).
"""
import argparse, json, os, shutil, sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resimplify_car import read_glb, read_accessor  # noqa: E402
from tire_fill import node_xf, mul  # noqa: E402

MARK = b"autoyard_tire_inner"
INWARD = 0.5          # normal · (aracın ortasına doğru) bunun üstündeyse iç yüz
RIM_RATIO = 0.72      # merkeze bu orandan yakın iç yüz jant arkası (biraz daha açık koyu)
PAD = 4               # boyanan adanın çevresindeki kullanılmayan texel'ler (mipmap kenarı)
OTHER_GAP = 3         # dolgu başka bir adanın bu kadar texel yakınına girmez
PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def tire_dark(v):
    return int(16 + v * 0.10)     # kauçuk: 16–41


def rim_dark(v):
    return int(24 + v * 0.14)     # jant arkası / fren gölgesi: 24–60


def triangles(js, binc):
    """Dokulu yüzeylerin üçgenleri: parça → [(ROOT köşeleri, UV köşeleri)]."""
    textured = {i for i, m in enumerate(js.get("materials", []))
                if "baseColorTexture" in m.get("pbrMetallicRoughness", {})}
    out = {}
    for node in js["nodes"]:
        name = node.get("name", "")
        if "mesh" not in node or not name.startswith("tripo_part_"):
            continue
        r, t = node_xf(node)
        tris = []
        for prim in js["meshes"][node["mesh"]]["primitives"]:
            if prim.get("material", 0) not in textured or "TEXCOORD_0" not in prim["attributes"]:
                continue
            pos, _ = read_accessor(js, binc, prim["attributes"]["POSITION"])
            uv, _ = read_accessor(js, binc, prim["attributes"]["TEXCOORD_0"])
            idx, _ = read_accessor(js, binc, prim["indices"])
            p = []
            for i in range(0, len(pos), 3):
                q = mul(r, pos[i:i + 3])
                p.append((q[0] + t[0], q[1] + t[1], q[2] + t[2]))
            for k in range(0, len(idx), 3):
                a, b, c = idx[k], idx[k + 1], idx[k + 2]
                tris.append(((p[a], p[b], p[c]), ((uv[a * 2], uv[a * 2 + 1]), (uv[b * 2], uv[b * 2 + 1]),
                                                   (uv[c * 2], uv[c * 2 + 1]))))
        out[int(name[len("tripo_part_"):])] = tris
    return out


def normal(v):
    a, b, c = v
    u = [b[i] - a[i] for i in range(3)]
    w = [c[i] - a[i] for i in range(3)]
    n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
    ln = (n[0] ** 2 + n[1] ** 2 + n[2] ** 2) ** 0.5
    return [x / ln for x in n] if ln > 1e-14 else None


def process(glb, info, dry, backup):
    base = os.path.basename(glb)[:-4]
    tex_path = os.path.join(PROJ, "assets", "cars", "optimized", base + "_car_albedo_albedo.jpg")
    img = Image.open(tex_path)
    if img.info.get("comment", b"").startswith(MARK):
        return "zaten boyanmış"
    img = img.convert("RGB")
    w, h = img.size
    js, binc = read_glb(glb)
    tris = triangles(js, binc)
    tire = Image.new("L", (w, h), 0)
    rim = Image.new("L", (w, h), 0)
    other = Image.new("L", (w, h), 0)
    dt, dr, do = ImageDraw.Draw(tire), ImageDraw.Draw(rim), ImageDraw.Draw(other)
    group_of = {}
    for g in info["groups"].values():
        if len(g["axis"]) < 3:
            continue
        for p in g["parts"]:
            group_of[p] = g
    sides = {}
    for g in info["groups"].values():
        verts = [v for p in g["parts"][:1] for tri, _ in tris.get(p, []) for v in tri]
        sides[id(g)] = 1.0 if verts and sum(v[0] for v in verts) > 0 else -1.0
    inner_count = 0
    for part, items in tris.items():
        g = group_of.get(part)
        for verts, uvs in items:
            poly = [(u * w, v * h) for u, v in uvs]
            n = normal(verts)
            if g is not None and n is not None and -n[0] * sides[id(g)] > INWARD:
                cy, cz, radius = g["axis"]
                ry = sum(v[1] for v in verts) / 3.0 - cy
                rz = sum(v[2] for v in verts) / 3.0 - cz
                (dr if (ry * ry + rz * rz) ** 0.5 < RIM_RATIO * radius else dt).polygon(poly, fill=255, outline=255)
                inner_count += 1
            else:
                do.polygon(poly, fill=255, outline=255)
    paint_tire = ImageChops.subtract(tire, other)
    paint_rim = ImageChops.subtract(ImageChops.subtract(rim, other), paint_tire)
    used = ImageChops.lighter(ImageChops.lighter(tire, rim), other)
    painted = ImageChops.lighter(paint_tire, paint_rim)
    # dolgu yalnız boş texel'e ve başka adaya OTHER_GAP texel'den uzakta: yoksa komşu adanın kenarı mipmap / süzgeçle koyulaşır
    free = ImageChops.subtract(ImageChops.invert(used), other.filter(ImageFilter.MaxFilter(OTHER_GAP * 2 + 1)))
    pad = ImageChops.multiply(painted.filter(ImageFilter.MaxFilter(PAD * 2 + 1)), free)
    paint_tire = ImageChops.lighter(paint_tire, ImageChops.subtract(pad, paint_rim))
    n_tire = paint_tire.histogram()[255]
    n_rim = paint_rim.histogram()[255]
    if os.environ.get("TIRE_DEBUG"):   # boyanacak bölge: lastik yeşil, jant arkası mavi
        view = Image.composite(Image.new("RGB", (w, h), (0, 255, 0)), img, paint_tire)
        view = Image.composite(Image.new("RGB", (w, h), (0, 80, 255)), view, paint_rim)
        view.save(os.path.join(os.environ["TIRE_DEBUG"], base + "_boya.jpg"), quality=80)
    if not dry and (n_tire or n_rim):
        if backup:
            os.makedirs(backup, exist_ok=True)
            dst = os.path.join(backup, os.path.basename(tex_path))
            if not os.path.exists(dst):
                shutil.copy2(tex_path, dst)
        out = Image.composite(img.point(tire_dark), img, paint_tire)
        out = Image.composite(img.point(rim_dark), out, paint_rim)
        out.save(tex_path, quality=95, subsampling=0, comment=MARK)
    return "iç üçgen %5d  boyanan texel: lastik %6d  jant arkası %6d" % (inner_count, n_tire, n_rim)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--axes", required=True, help="tools/wheel_parts.gd AXES satırı (JSON)")
    ap.add_argument("--backup", default="", help="özgün dokuların kopyalanacağı klasör")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("glbs", nargs="+")
    a = ap.parse_args()
    axes = json.load(open(a.axes))
    for path in a.glbs:
        key = os.path.relpath(os.path.abspath(path), PROJ)
        if key not in axes:
            print("%-32s katalogda yok, atlandı" % os.path.basename(path))
            continue
        print("%-32s %s" % (os.path.basename(path), process(path, axes[key], a.dry, a.backup)))


if __name__ == "__main__":
    sys.exit(main())
