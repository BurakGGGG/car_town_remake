#!/usr/bin/env python3
"""Lastiğin aracın altında / çamurluğun içinde kalan, MODELLENMEMİŞ iç yanağını ve sırtını otomatik doldurur.

Neden (2026-10-24, kullanıcı: "iç yanaklar — yere değen yer değil, aracın altının içinde kalan yerler"): Tripo
çamurluğun içini göremediği için çoğu araçta lastiğin İÇ yanağının üst yarısı (120–160°'lik yay) hiç yok; içeriden /
önden / alttan bakınca ve teker dönünce o yay boş görünüyordu (qa/teker_tarama.gd bakis=180,0). tools/tire_fill.py
elle verilen yayı doldurur; bu betik eksik yayları kendisi bulur.

Yöntem (teker grubu başına, CarPartMap wheel_axes ekseninde, açı X ekseni etrafında 0° = yukarı, 90° = ön):
  - Üçgenler sınıflanır: İÇ yanak (normal aracın ortasına bakar, merkez ≥ 0,70 R) ve SIRT (normal dışa, radyal, ≥ 0,80 R).
  - Kapsama üçgenler TARANARAK ölçülür (yalnız ağırlık merkezine bakmak iri üçgenlerde sahte boşluk veriyordu): iç yanak
    YZ düzlemine izdüşer, 0,80–0,95 R halkasında 5°'lik dilimin kapladığı oran; sırt silindir açılımında (açı × x),
    dilimde lastik genişliğinin kapladığı oran. Oranı %50'den az ve en az 10° süren dilimler EKSİK.
  - Eksik dilim, sağlam bir kaynak dilimdeki aynı sınıf üçgenlerin teker ekseni etrafında döndürülmüş kopyasıyla dolar:
    önce karşı dilim (180°), o da eksikse 90° / 270° / 135° / 225° / 45° / 315° ötesi (Veyron arka gibi iki yanı da eksik
    lastikler). UV aynı: tools/tire_inner_paint.py'nin koyulaştırdığı iç yanak dokusu kopyaya da gelir. Hiçbir kaynak
    yoksa dilim boş kalır. Dış yanağa dokunulmaz (dış yanak delikleri tools/tire_fill.py).
  - Kopya, tekerin özgün en alt noktasının altına inemez (o üçgen atılır): oval lastikte (Jaguar) yandaki yanağı alta
    döndürmek tekeri zemine 6 mm gömüyordu (vehicle_wheel_test zemin denetimi).
Gömülü doku baytları aynen kalır. GLB asset.extras'a işaret yazılır, ikinci kez uygulanmaz.
Kullanım:
  godot-4 --headless --path . -s res://tools/wheel_parts.gd | grep '^AXES ' | cut -c6- > /tmp/axes.json
  python3 tools/tire_auto_fill.py --axes /tmp/axes.json [--dry] assets/cars/optimized/*.glb
Sonra --import ve küçük resimler (tools/make_car_thumbs.gd; thumbs.json GLB MD5'ini tutar).
"""
import argparse, json, math, os, sys
from array import array

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from resimplify_car import read_glb, write_glb, read_accessor, compact  # noqa: E402
from tire_fill import node_xf, inv3, mul, add_view  # noqa: E402

MARK = "autoyard_tire_auto_fill"
BIN = 5.0
BINS = int(360 / BIN)
FACING = 0.5          # sınıflama: normalin iç (−x · taraf) / radyal bileşeni bundan büyük
INNER_MIN_R = 0.70
TREAD_MIN_R = 0.80
MISSING = 0.5         # dilimin bu oranından azı kaplıysa eksik
MIN_RUN = 2           # en az bu kadar ardışık eksik dilim (tek dilim = üçgen sınırı gürültüsü)
SOURCE_OK = 0.7       # kaynak dilim en az bu oranda kaplı olmalı
OFFSETS = (180, 90, 270, 135, 225, 45, 315)   # kaynak arama sırası (derece)
TREAD_TOP = 100.0     # sırt yalnız tepeye bu kadar açı yakın dilimlerde doldurulur (eksiklik çamurluğun içinde; altta
                      # görülen "eksik" sınıflama kenarı — Tiggo / Huracán arka — ve tepeyi alta kopyalamak yere gömerdi)
RASTER = 400          # iç yanak izdüşüm görüntüsü (px)
PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def load_parts(js, binc, wanted):
    """Parça → {"node", "m", "t", "prims": [{"prim", "data", "idx", "root"}]}"""
    out = {}
    for node in js["nodes"]:
        name = node.get("name", "")
        if "mesh" not in node or not name.startswith("tripo_part_") or int(name[11:]) not in wanted:
            continue
        m, t = node_xf(node)
        prims = []
        for prim in js["meshes"][node["mesh"]]["primitives"]:
            if prim.get("mode", 4) != 4:
                continue
            data = {k: read_accessor(js, binc, v) for k, v in prim["attributes"].items()}
            idx, _ = read_accessor(js, binc, prim["indices"])
            pos = data["POSITION"][0]
            root = []
            for i in range(0, len(pos), 3):
                q = mul(m, pos[i:i + 3])
                root.append((q[0] + t[0], q[1] + t[1], q[2] + t[2]))
            prims.append({"prim": prim, "data": data, "idx": idx, "root": root})
        out[int(name[11:])] = {"node": node, "m": m, "t": t, "prims": prims}
    return out


def classify(parts, group, side):
    """Grup üçgenleri: [(sınıf, dilim, ağırlık, parça, prim no, üçgen no)]."""
    cy, cz, radius = group["axis"]
    out = []
    for p in group["parts"]:
        if p not in parts:
            continue
        for pi, pr in enumerate(parts[p]["prims"]):
            root, idx = pr["root"], pr["idx"]
            for k in range(len(idx) // 3):
                a, b, c = root[idx[k * 3]], root[idx[k * 3 + 1]], root[idx[k * 3 + 2]]
                u = [b[i] - a[i] for i in range(3)]
                v = [c[i] - a[i] for i in range(3)]
                n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
                ln = math.sqrt(n[0] ** 2 + n[1] ** 2 + n[2] ** 2)
                if ln < 1e-14:
                    continue
                n = [x / ln for x in n]
                ry = (a[1] + b[1] + c[1]) / 3.0 - cy
                rz = (a[2] + b[2] + c[2]) / 3.0 - cz
                rho = math.hypot(ry, rz)
                if rho < 1e-9:
                    continue
                deg = math.degrees(math.atan2(rz, ry)) % 360.0
                b_i = int(deg / BIN) % BINS
                area = ln * 0.5
                if -n[0] * side > FACING and rho >= INNER_MIN_R * radius:
                    out.append(("ic", b_i, (a, b, c), p, pi, k))
                elif (n[1] * ry + n[2] * rz) / rho > FACING and rho >= TREAD_MIN_R * radius:
                    out.append(("sirt", b_i, (a, b, c), p, pi, k))
    return out


def coverage(tris, kind, axis):
    """Dilim başına kaplanan oran (0–1)."""
    cy, cz, radius = axis
    sel = [t[2] for t in tris if t[0] == kind]
    cov = [0.0] * BINS
    if not sel:
        return cov
    if kind == "ic":
        # yandan izdüşüm: piksel = (z, y) teker merkezli
        scale = RASTER / (2.2 * radius)
        img = Image.new("L", (RASTER, RASTER), 0)
        draw = ImageDraw.Draw(img)
        for tri in sel:
            draw.polygon([(RASTER / 2 + (v[2] - cz) * scale, RASTER / 2 - (v[1] - cy) * scale) for v in tri], fill=255)
        px = img.load()
        tot = [0] * BINS
        hit = [0] * BINS
        for y in range(RASTER):
            for x in range(RASTER):
                dz = (x + 0.5 - RASTER / 2) / scale
                dy = (RASTER / 2 - y - 0.5) / scale
                r = math.hypot(dy, dz) / radius
                if r < 0.80 or r > 0.95:
                    continue
                b = int((math.degrees(math.atan2(dz, dy)) % 360.0) / BIN) % BINS
                tot[b] += 1
                if px[x, y]:
                    hit[b] += 1
        return [hit[b] / tot[b] if tot[b] else 0.0 for b in range(BINS)]
    # sırt: silindir açılımı, yatay = açı (0,5°/px), dikey = x
    xs = [v[0] for tri in sel for v in tri]
    x0, x1 = min(xs), max(xs)
    w_px, h_px = 720, 80
    img = Image.new("L", (w_px, h_px), 0)
    draw = ImageDraw.Draw(img)
    for tri in sel:
        degs = [math.degrees(math.atan2(v[2] - cz, v[1] - cy)) % 360.0 for v in tri]
        if max(degs) - min(degs) > 180.0:
            degs = [d + 360.0 if d < 180.0 else d for d in degs]
        for shift in (0.0, -360.0):
            draw.polygon([((d + shift) * 2.0, (v[0] - x0) / max(x1 - x0, 1e-6) * (h_px - 1)) for d, v in zip(degs, tri)],
                         fill=255)
    px = img.load()
    per = w_px // BINS
    for b in range(BINS):
        hit = sum(1 for x in range(b * per, (b + 1) * per) for y in range(h_px) if px[x, y])
        cov[b] = hit / float(per * h_px)
    # sırt genişliğinin kenarları (yanak geçişi) hiçbir yerde tam dolmaz: oranı en iyi dilimlere göre ölçekle
    best = sorted(cov)[int(BINS * 0.8)]
    return [min(c / best, 1.0) if best > 0 else 0.0 for c in cov]


def _near_top(b):
    deg = (b + 0.5) * BIN
    return min(deg, 360.0 - deg) <= TREAD_TOP


def missing_bins(tris, kind, axis):
    cov = coverage(tris, kind, axis)
    low = [cov[b] < MISSING for b in range(BINS)]
    miss = []
    for b in range(BINS):
        if not low[b]:
            continue
        run = 1
        k = (b + 1) % BINS
        while low[k] and run < MIN_RUN:
            run += 1
            k = (k + 1) % BINS
        k = (b - 1) % BINS
        while low[k] and run < MIN_RUN:
            run += 1
            k = (k - 1) % BINS
        if run < MIN_RUN or not (kind == "ic" or _near_top(b)):
            continue
        for off in OFFSETS:
            src = (b - int(off / BIN)) % BINS
            if cov[src] >= SOURCE_OK:
                miss.append((b, src))
                break
    return miss, cov


def runs(bins):
    """Ardışık dilimleri derece yaylarına çevirir (rapor için)."""
    if not bins:
        return ""
    s = sorted(bins)
    groups, start, prev = [], s[0], s[0]
    for b in s[1:]:
        if b != prev + 1:
            groups.append((start, prev))
            start = b
        prev = b
    groups.append((start, prev))
    if len(groups) > 1 and groups[0][0] == 0 and groups[-1][1] == BINS - 1:
        groups[0] = (groups[-1][0], groups[0][1])
        groups.pop()
    return ",".join("%d–%d" % (int(a * BIN), int((b + 1) * BIN) % 360) for a, b in groups)


def process(path, info, dry):
    js, binc = read_glb(path)
    if js.get("asset", {}).get("extras", {}).get(MARK):
        return "zaten uygulanmış"
    wanted = set()
    for g in info["groups"].values():
        wanted.update(g["parts"])
    parts = load_parts(js, binc, wanted)
    adds = {}    # (parça, prim no) → {(üçgen no, cy, cz, φ, özgün en alt y)}
    report = []
    for key in sorted(info["groups"]):
        g = info["groups"][key]
        if len(g["axis"]) < 3 or not g["parts"] or g["parts"][0] not in parts:
            continue
        tyre = [v for pr in parts[g["parts"][0]]["prims"] for v in pr["root"]]
        side = 1.0 if sum(v[0] for v in tyre) > 0 else -1.0
        tris = classify(parts, g, side)
        cy, cz = g["axis"][0], g["axis"][1]
        floor_y = min(v[1] for p in g["parts"] if p in parts for pr in parts[p]["prims"] for v in pr["root"])
        line = []
        for kind in ("ic", "sirt"):
            miss, _ = missing_bins(tris, kind, g["axis"])
            if not miss:
                continue
            # kaynak dilim ± 1 (iri üçgenin ağırlık merkezi komşu dilime düşebilir), dönüş açısı başına bir kez
            wanted_src = {}
            for b, src in miss:
                phi = ((b - src) % BINS) * BIN
                for d in (-1, 0, 1):
                    wanted_src.setdefault((src + d) % BINS, set()).add(phi)
            n = 0
            for t in tris:
                if t[0] == kind and t[1] in wanted_src:
                    for phi in wanted_src[t[1]]:
                        adds.setdefault((t[3], t[4]), set()).add((t[5], cy, cz, phi, floor_y))
                        n += 1
            offs = sorted({int(((b - src) % BINS) * BIN) for b, src in miss})
            line.append("%s %s (%d üçgen, %s°)" % (kind, runs([b for b, _ in miss]), n, "/".join(map(str, offs))))
        if line:
            report.append("%s: %s" % (key, "; ".join(line)))
    if not adds:
        return "eksik yay yok"
    if not dry:
        out = bytearray(binc)
        for (p, pi), items in adds.items():
            _append(js, out, parts[p], pi, items)
        js.setdefault("asset", {}).setdefault("extras", {})[MARK] = True
        js, out = compact(js, out)
        write_glb(path, js, out)
    return " | ".join(report)


def _append(js, out, part, pi, items):
    """Prim'e, verilen üçgenlerin eksen etrafında φ derece döndürülmüş kopyalarını ekler (yeni accessor'lar)."""
    pr = part["prims"][pi]
    prim, data, idx, root = pr["prim"], pr["data"], pr["idx"], pr["root"]
    m, t = part["m"], part["t"]
    mi = inv3(m)
    new = {k: array(a.typecode, a) for k, (a, _) in data.items()}
    new_idx = array("I", idx)
    count = len(root)
    copied = {}   # (köşe, eksen) → yeni köşe
    for tri, cy, cz, phi, floor_y in sorted(items):
        cs, sn = math.cos(math.radians(phi)), math.sin(math.radians(phi))
        low = min(cy + (root[idx[tri * 3 + k]][1] - cy) * cs - (root[idx[tri * 3 + k]][2] - cz) * sn for k in range(3))
        if low < floor_y - 1e-6:
            continue   # zemine gömülürdü
        for k in range(3):
            v = idx[tri * 3 + k]
            if (v, cy, cz, phi) not in copied:
                w = root[v]
                dy, dz = w[1] - cy, w[2] - cz
                turned = [w[0] - t[0], cy + dy * cs - dz * sn - t[1], cz + dy * sn + dz * cs - t[2]]
                for name, (a, n) in data.items():
                    if name == "POSITION":
                        new[name].extend(array("f", mul(mi, turned)))
                    elif name == "NORMAL":
                        nr = mul(m, a[v * 3:v * 3 + 3])
                        nl = mul(mi, [nr[0], nr[1] * cs - nr[2] * sn, nr[1] * sn + nr[2] * cs])
                        ln = math.sqrt(sum(c * c for c in nl)) or 1.0
                        new[name].extend(array("f", [c / ln for c in nl]))
                    else:
                        new[name].extend(a[v * n:(v + 1) * n])
                copied[(v, cy, cz, phi)] = count
                count += 1
            new_idx.append(copied[(v, cy, cz, phi)])
    attrs = prim["attributes"]
    for name, (a, n) in data.items():
        acc = dict(js["accessors"][attrs[name]])
        acc.pop("byteOffset", None)
        arr = new[name]
        acc["count"] = len(arr) // n
        if name == "POSITION":
            acc["min"] = [min(arr[i::3]) for i in range(3)]
            acc["max"] = [max(arr[i::3]) for i in range(3)]
        acc["bufferView"] = add_view(js, out, arr.tobytes(), 34962)
        js["accessors"].append(acc)
        attrs[name] = len(js["accessors"]) - 1
    wide = count >= 65536
    ib = new_idx if wide else array("H", new_idx)
    js["accessors"].append({"bufferView": add_view(js, out, ib.tobytes(), 34963),
                            "componentType": 5125 if wide else 5123, "count": len(new_idx), "type": "SCALAR"})
    prim["indices"] = len(js["accessors"]) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--axes", required=True, help="tools/wheel_parts.gd AXES satırı (JSON)")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("glbs", nargs="+")
    a = ap.parse_args()
    axes = json.load(open(a.axes))
    for path in a.glbs:
        key = os.path.relpath(os.path.abspath(path), PROJ)
        if key not in axes:
            print("%-32s katalogda yok, atlandı" % os.path.basename(path))
            continue
        print("%-32s %s" % (os.path.basename(path), process(path, axes[key], a.dry)))


if __name__ == "__main__":
    sys.exit(main())
