#!/usr/bin/env python3
"""OPTİMİZE araç GLB'sinde lastiğin eksik yayını doldurur (optimize_car.gd "fill_arc"ın optimize çıktıya uygulanan eşi).

Neden (2026-10-24): kaynakta lastiğin tepesi modellenmemiş tekerlere optimize_car.gd fill_arc uyguluyordu ama seçilen
yaylar dar kalmış; dolgunun iki kenarında 10–40°'lik delikler vardı (GT3 sağ-ön, Murat 124 / T1 arka, Bel Air dört
teker). Teker dönünce delik alta geliyor, lastiğin altı boş görünüyordu. Bulan: qa/teker_tarama.gd (ince).

Aracı kaynaktan yeniden üretmek yerine (doku yeniden kodlanır, tools/debadge'in sildiği armalar geri gelebilir)
yalnızca lastik parçasına üçgen eklenir: yay [from, to] içindeki DELİK, karşı yaydaki (açı + 180°) üçgenlerin teker
ekseni etrafında 180° döndürülmüş kopyasıyla dolar. Yalnızca merkezi yarıçapın min_r katından dışarıdaki üçgenler
kopyalanır (lastik; aynı mesh'teki jant kopyalanmaz, üst üste binmez). Açı ROOT uzayında X ekseni etrafında:
0° = yukarı (+Y), 90° = ön (+Z); from > to ise yay 0°'dan geçer. Gömülü doku baytları aynen kalır (içe aktarma dokuyu
yeniden çıkarmaz). CarPartMap'teki fill_arc yayları aynı gün genişletildi: kaynaktan yeniden üretilen araç aynı
sonucu verir, bu betik o zaman gerekmez.

GLB'nin asset.extras'ına uygulanan tanımlar yazılır; aynı tanım ikinci kez uygulanmaz.
Kullanım: python3 tools/tire_fill.py [--dry] assets/cars/optimized/<ad>.glb ...  → sonra --import, küçük resimler
(tools/make_car_thumbs.gd).
"""
import argparse, json, math, os, sys
from array import array

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resimplify_car import read_glb, write_glb, read_accessor, compact  # noqa: E402

MARK = "autoyard_tire_fill"
# GLB adı → [{part, center: [y, z] (ROOT, wheel_axes), radius (wheel_axes), from, to}], delik ölçümü 5°'lik dilimlerle.
FILLS = {
    "porsche_gt3.glb": [   # sağ-ön; mevcut dolgu 318–42, delikler 285–320 ve 40–65
        {"part": 62, "center": [0.0826, 0.2873], "radius": 0.0861, "from": 278, "to": 320},
        {"part": 62, "center": [0.0826, 0.2873], "radius": 0.0861, "from": 40, "to": 68}],
    "tofas_murat_124.glb": [   # arka; mevcut 350–10, delikler 330–350 ve 10–35
        {"part": 3, "center": [0.0927, -0.2812], "radius": 0.0914, "from": 322, "to": 352},
        {"part": 3, "center": [0.0927, -0.2812], "radius": 0.0914, "from": 8, "to": 38},
        {"part": 4, "center": [0.0930, -0.2809], "radius": 0.0906, "from": 322, "to": 352},
        {"part": 4, "center": [0.0930, -0.2809], "radius": 0.0906, "from": 8, "to": 38}],
    "vw_t1_bus.glb": [   # arka; mevcut 330–30, delikler 320–330 ve 30–40
        {"part": 3, "center": [0.0902, -0.2839], "radius": 0.0856, "from": 313, "to": 332},
        {"part": 3, "center": [0.0902, -0.2839], "radius": 0.0856, "from": 28, "to": 45},
        {"part": 2, "center": [0.0903, -0.2853], "radius": 0.0871, "from": 313, "to": 332},
        {"part": 2, "center": [0.0903, -0.2853], "radius": 0.0871, "from": 28, "to": 45}],
    "chevrolet_bel_air_1956.glb": [   # ön mevcut 300–50 (delik 285–300, sol-ön 60), arka 290–60 (delik 280–290, 60–70)
        {"part": 5, "center": [0.0876, 0.3285], "radius": 0.0866, "from": 278, "to": 302},
        {"part": 5, "center": [0.0876, 0.3285], "radius": 0.0866, "from": 48, "to": 68},
        {"part": 6, "center": [0.0876, 0.3286], "radius": 0.0865, "from": 278, "to": 302},
        {"part": 4, "center": [0.0873, -0.2424], "radius": 0.0861, "from": 273, "to": 292},
        {"part": 4, "center": [0.0873, -0.2424], "radius": 0.0861, "from": 58, "to": 72},
        {"part": 3, "center": [0.0876, -0.2427], "radius": 0.0863, "from": 273, "to": 292},
        {"part": 3, "center": [0.0876, -0.2427], "radius": 0.0863, "from": 58, "to": 72}],
}
MIN_R = 0.62   # kopyalanan üçgenin merkezi en az bu kadar yarıçapta (lastik; jant içeride)

COMP_TYPE = {"f": 5126, "I": 5125, "H": 5123, "B": 5121}


def quat_mat(q):
    x, y, z, w = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]


def node_xf(node):
    """Düğümün yerel → ROOT dönüşümü (3x3, öteleme). Parçalar ROOT'un doğrudan çocuğu."""
    if "matrix" in node:
        m = node["matrix"]
        return [[m[0], m[4], m[8]], [m[1], m[5], m[9]], [m[2], m[6], m[10]]], [m[12], m[13], m[14]]
    r = quat_mat(node.get("rotation", [0, 0, 0, 1]))
    s = node.get("scale", [1, 1, 1])
    return [[r[i][j] * s[j] for j in range(3)] for i in range(3)], list(node.get("translation", [0, 0, 0]))


def inv3(m):
    a, b, c = m[0]
    d, e, f = m[1]
    g, h, i = m[2]
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    return [[(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
            [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
            [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det]]


def mul(m, v):
    return [m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
            m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
            m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2]]


def in_arc(deg, lo, hi):
    return lo <= deg <= hi if lo <= hi else (deg >= lo or deg <= hi)


def fill(js, binc, out, spec):
    node = next((n for n in js["nodes"] if n.get("name") == "tripo_part_%d" % spec["part"] and "mesh" in n), None)
    if node is None:
        raise SystemExit("parça yok: %d" % spec["part"])
    m, t = node_xf(node)
    mi = inv3(m)
    cy, cz = spec["center"]
    lo = (spec["from"] + 180.0) % 360.0   # kaynak: karşı yay
    hi = (spec["to"] + 180.0) % 360.0
    min_r = MIN_R * spec["radius"]
    added = 0
    for prim in js["meshes"][node["mesh"]]["primitives"]:
        attrs = prim["attributes"]
        data = {k: read_accessor(js, binc, v) for k, v in attrs.items()}
        idx, _ = read_accessor(js, binc, prim["indices"])
        pos = data["POSITION"][0]
        root = []
        for v in range(len(pos) // 3):
            p = mul(m, pos[v * 3:v * 3 + 3])
            root.append([p[0] + t[0], p[1] + t[1], p[2] + t[2]])
        copied = {}
        new_idx = array("I", idx)
        new = {k: array(a.typecode, a) for k, (a, _) in data.items()}
        count = len(pos) // 3
        for tri in range(len(idx) // 3):
            vs = idx[tri * 3:tri * 3 + 3]
            cy_t = sum(root[v][1] for v in vs) / 3.0 - cy
            cz_t = sum(root[v][2] for v in vs) / 3.0 - cz
            if math.hypot(cy_t, cz_t) < min_r or not in_arc(math.degrees(math.atan2(cz_t, cy_t)) % 360.0, lo, hi):
                continue
            for v in vs:
                if v not in copied:
                    w = root[v]
                    turned = [w[0] - t[0], 2.0 * cy - w[1] - t[1], 2.0 * cz - w[2] - t[2]]
                    for k, (a, n) in data.items():
                        if k == "POSITION":
                            new[k].extend(array("f", mul(mi, turned)))
                        elif k == "NORMAL":
                            nr = mul(m, a[v * 3:v * 3 + 3])
                            nl = mul(mi, [nr[0], -nr[1], -nr[2]])
                            ln = math.sqrt(sum(c * c for c in nl)) or 1.0
                            new[k].extend(array("f", [c / ln for c in nl]))
                        else:
                            new[k].extend(a[v * n:(v + 1) * n])
                    copied[v] = count
                    count += 1
                new_idx.append(copied[v])
            added += 1
        for k, (a, n) in data.items():
            acc = dict(js["accessors"][attrs[k]])
            arr = new[k]
            acc.pop("byteOffset", None)
            acc.pop("bufferView", None)
            acc["count"] = len(arr) // n
            if k == "POSITION":
                acc["min"] = [min(arr[i::3]) for i in range(3)]
                acc["max"] = [max(arr[i::3]) for i in range(3)]
            acc["bufferView"] = add_view(js, out, arr.tobytes(), 34962)
            js["accessors"].append(acc)
            attrs[k] = len(js["accessors"]) - 1
        wide = count >= 65536
        ib = new_idx if wide else array("H", new_idx)
        js["accessors"].append({"bufferView": add_view(js, out, ib.tobytes(), 34963),
                                "componentType": 5125 if wide else 5123, "count": len(new_idx), "type": "SCALAR"})
        prim["indices"] = len(js["accessors"]) - 1
    return added


def add_view(js, out, data, target):
    while len(out) % 4:
        out.append(0)
    js["bufferViews"].append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data), "target": target})
    out.extend(data)
    return len(js["bufferViews"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true", help="yalnızca say, yazma")
    ap.add_argument("glbs", nargs="+")
    a = ap.parse_args()
    for path in a.glbs:
        specs = FILLS.get(os.path.basename(path))
        if not specs:
            print("%-32s tanım yok, atlandı" % os.path.basename(path))
            continue
        js, binc = read_glb(path)
        done = js.get("asset", {}).get("extras", {}).get(MARK, [])
        out = bytearray(binc)
        applied = []
        for spec in specs:
            if spec in done:
                continue
            n = fill(js, binc, out, spec)
            # sonraki tanım güncel accessor'ları (yeni tampona eklendi) okusun diye tampon tazelenir
            binc = bytes(out)
            applied.append(spec)
            print("%-32s parça %d  %3d–%3d°  %d üçgen eklendi" % (os.path.basename(path), spec["part"], spec["from"],
                                                                   spec["to"], n))
        if not applied:
            print("%-32s zaten uygulanmış" % os.path.basename(path))
            continue
        if not a.dry:
            js.setdefault("asset", {}).setdefault("extras", {})[MARK] = done + applied
            js, out = compact(js, out)
            write_glb(path, js, out)


if __name__ == "__main__":
    sys.exit(main())
