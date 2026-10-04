#!/usr/bin/env python3
"""Araç parçalarının ROLLERİNİ (gövde, cam, far, teker…) otomatik çıkarır → CarPartMap kaydı.

Girdi: tools/part_features.gd'nin CSV çıktısı (bir ya da birçok araç). Ayrıntı: docs/VEHICLE_ASSETS.md §2.

  # doğrulama (rolü elle bilinen araçlarla isabet ölçümü; CSV'de rol sütunu dolu olmalı)
  python3 tools/classify_roles.py known.csv
  # yeni araçlar için CarPartMap blokları (glb_adı=tscn_adı eşlemesi)
  python3 tools/classify_roles.py new.csv --emit audi_rs6=audi_rs6 porsche_gt3=porsche_gt3

Kurallar ölçülerek kuruldu (2026-09-27, elle doğrulanmış 7 aracın 421 parçası): işlevsel grup isabeti
%75, teker/stop/ayna %100, far %95, ızgara %94. Kalan hata gövde↔trim ayrımındadır; boya maskesi
aracı (tools/make_paint_mask.gd) bunu texel bazında zaten düzeltir.
"""
import collections
import csv
import math
import sys

ROLE_ORDER = ["body", "mirrors", "wheels", "tires", "rims", "glass", "headlights", "taillights",
              "grille", "black_trim", "plate", "fog_lights", "exhaust", "antenna", "hidden"]


def load(path):
    rows = []
    for r in csv.reader(open(path)):
        if len(r) != 16 or not r[1].isdigit():
            continue
        f = [float(x) for x in r[3:15]]
        rows.append(dict(car=r[0], idx=int(r[1]), tris=int(r[2]), cx=f[0], cy=f[1], cz=f[2],
                         sx=f[3], sy=f[4], sz=f[5], cyl=f[6], r=f[7], g=f[8], b=f[9],
                         sat=f[10], val=f[11], role=r[15]))
    byc = collections.defaultdict(list)
    for x in rows:
        byc[x['car']].append(x)
    for lst in byc.values():
        mx = max(x['cx'] for x in lst)
        mn = min(x['cx'] for x in lst)
        half = (mx + mn) / 2
        for x in lst:
            x['alat'] = abs((x['cx'] - half) / max(mx - half, 1e-6))   # 0 orta .. 1 yan
            x['ltris'] = math.log10(max(x['tris'], 1))
            x['redness'] = x['r'] - (x['g'] + x['b']) / 2
    return rows


def paint_color(parts):
    """Aracın fabrika boyası: parçaları rengine göre kabaca kümele, ALAN bakımından en ağır küme."""
    bins = collections.defaultdict(float)
    acc = collections.defaultdict(lambda: [0.0, 0.0, 0.0])
    for x in parts:
        if x['cy'] < 0.13 and x['alat'] > 0.7:   # tekerler boya değil
            continue
        key = (int(x['r'] * 7), int(x['g'] * 7), int(x['b'] * 7))
        bins[key] += x['tris']
        a = acc[key]
        a[0] += x['r'] * x['tris']
        a[1] += x['g'] * x['tris']
        a[2] += x['b'] * x['tris']
    if not bins:
        return (0.5, 0.5, 0.5)
    key = max(bins, key=lambda k: bins[k])
    w = bins[key]
    a = acc[key]
    return (a[0] / w, a[1] / w, a[2] / w)


def col_dist(x, p):
    """Renk uzaklığı: parlaklık farkı + kromatiklik farkı (koyu araçlarda ton güvenilmez)."""
    dv = abs(x['val'] - max(p))

    def chroma(r, g, b):
        s = max(r + g + b, 1e-6)
        return (r / s, g / s, b / s)
    c1 = chroma(x['r'], x['g'], x['b'])
    c2 = chroma(*p)
    return dv, sum(abs(a - b) for a, b in zip(c1, c2))


def pct(values, q):
    v = sorted(values)
    return v[min(int(len(v) * q), len(v) - 1)] if v else 0.0


def classify(parts):
    """Eşikler aracın KENDİ parlaklık dağılımından türetilir: siyah araçta 'koyu' başka şeydir."""
    big = [x for x in parts if x['tris'] > 800]
    vals = [x['val'] for x in (big or parts)]
    v25, v50 = pct(vals, 0.25), pct(vals, 0.5)
    paint = paint_color(parts)
    dark = min(0.32, max(0.10, v25))          # bundan koyu = trim/ızgara adayı
    glass_v = min(0.62, max(0.18, v50))       # cam bu parlaklığın altında
    light_v = max(0.42, v50)                  # far bunun üstünde parlak
    for x in parts:
        lat, cy, cz, val, sat, red = x['alat'], x['cy'], x['cz'], x['val'], x['sat'], x['redness']
        rr = x['sy'] / max(x['sz'], 1e-6)
        # Gövde rengiyle aynı mı? KIRMIZI ARAÇTA arka panel "stop lambası" sanılıyordu; büyük ve
        # gövde renginde olan parça lamba olamaz.
        dv, dc = col_dist(x, paint)
        body_hue = dc < 0.06 and dv < 0.22
        # TEKER: köşede, alçak ve YUVARLAK (yan profilde yükseklik ≈ uzunluk); yuvarlaklık şartı
        # olmadan köşedeki uzun gövde parçaları (marşpiyel, çamurluk) teker sanılıyordu.
        if (lat > 0.72 and cy < 0.155 and x['tris'] > 700
                and 0.55 < rr < 1.9 and x['sx'] < 0.75 * max(x['sy'], x['sz'])):
            x['pred'] = "tires" if (val < 0.22 and x['tris'] > 9000) else ("wheels" if x['tris'] > 6000 else "rims")
        elif (cz < 0.12 and red > 0.10 and val > 0.25 and x['sz'] < 0.16
                and (not body_hue or x['tris'] < 2500)):
            x['pred'] = "taillights"
        elif (cz > 0.85 and val > light_v and sat < 0.30 and cy < 0.30 and x['sz'] < 0.14
                and x['tris'] < 6000 and (not body_hue or x['tris'] < 2500)):
            x['pred'] = "headlights"
        elif cz > 0.90 and val <= dark and x['sz'] < 0.18:
            x['pred'] = "grille"
        elif lat > 0.88 and cy > 0.18 and 0.5 < cz < 0.85:
            x['pred'] = "mirrors"
        # NOT: cam kuralı BİLEREK muhafazakâr. Yanlışlıkla "cam" denen gövde parçası boya
        # maskesinde SERT ENGELdir (hiç boyanmaz); "gövde" denen cam ise maskede texel bazında
        # zaten eleniyor. Yani cam yanlış-pozitifi pahalı, yanlış-negatifi ucuz.
        elif cy > 0.235 and sat < 0.20 and val < glass_v:
            x['pred'] = "glass"
        elif val < dark:
            x['pred'] = "black_trim"
        else:
            x['pred'] = "body"
    return paint


GROUP = {"wheels": "TEKER", "tires": "TEKER", "rims": "TEKER", "glass": "CAM",
         "headlights": "ISIK", "taillights": "ISIK", "fog_lights": "ISIK", "body": "BOYA", "mirrors": "BOYA"}


def grp(r):
    return GROUP.get(r, "TRIM")


def emit(parts, tscn):
    """Tek aracın CarPartMap kaydı (GDScript metni). Teker grubu: her çeyrekte en büyük 3 teker parçası."""
    paint = classify(parts)
    half = (max(x['cx'] for x in parts) + min(x['cx'] for x in parts)) / 2
    roles = collections.defaultdict(list)
    for x in parts:
        roles[x['pred']].append(x['idx'])
    quads = collections.defaultdict(list)
    for x in parts:
        if x['pred'] in ("wheels", "tires", "rims"):
            quads[("f" if x['cz'] > 0.5 else "r") + ("l" if (x['cx'] - half) > 0 else "r")].append(x)
    groups = {k: [q['idx'] for q in sorted(v, key=lambda q: -q['tris'])[:3]] for k, v in quads.items()}
    lines = ['\t"res://assets/cars/%s.tscn": {' % tscn,
             '\t\t"default_paint": Color(%.3f, %.3f, %.3f),  # otomatik sınıflandırma tahmini; maske aracı doğrular' % paint]
    for role in ROLE_ORDER:
        if roles.get(role):
            lines.append('\t\t"%s": %s,' % (role, sorted(roles[role])))
    if groups:
        lines.append('\t\t"wheel_groups": {%s},' % ", ".join('"%s": %s' % (k, sorted(v)) for k, v in sorted(groups.items())))
    lines.append('\t},')
    return "\n".join(lines), sorted(groups.keys()), collections.Counter(x['pred'] for x in parts)


def main():
    rows = load(sys.argv[1])
    bycar = collections.defaultdict(list)
    for x in rows:
        bycar[x['car']].append(x)
    if "--emit" in sys.argv:
        names = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--emit") + 1:])
        for car in sorted(bycar):
            parts = sorted(bycar[car], key=lambda x: x['idx'])
            text, quads, cnt = emit(parts, names.get(car, car))
            print(text)
            print("#  %s: %d parça | %s | teker grupları: %s" % (car, len(parts),
                  " ".join("%s=%d" % kv for kv in sorted(cnt.items())), ",".join(quads) or "YOK"), file=sys.stderr)
        return
    eok = gok = n = 0
    per = collections.defaultdict(lambda: [0, 0, 0])
    conf = collections.Counter()
    for car, parts in sorted(bycar.items()):
        classify(parts)
        ce = sum(1 for x in parts if x['pred'] == x['role'])
        cg = sum(1 for x in parts if grp(x['pred']) == grp(x['role']))
        for x in parts:
            n += 1
            per[x['role']][2] += 1
            if x['pred'] == x['role']:
                eok += 1
                per[x['role']][0] += 1
            if grp(x['pred']) == grp(x['role']):
                gok += 1
                per[x['role']][1] += 1
            else:
                conf[(grp(x['role']), grp(x['pred']))] += 1
        print("%-16s tam %%%3.0f grup %%%3.0f" % (car, 100.0 * ce / len(parts), 100.0 * cg / len(parts)))
    print("TOPLAM tam %%%.1f | grup %%%.1f" % (100.0 * eok / max(n, 1), 100.0 * gok / max(n, 1)))
    for role, (e, g, t) in sorted(per.items(), key=lambda kv: -kv[1][2]):
        print("  %-12s tam %3d / grup %3d / %3d" % (role, e, g, t))
    print("karışmalar:", ", ".join("%s→%s %d" % (a, b, c) for (a, b), c in conf.most_common(6)))


if __name__ == "__main__":
    main()
