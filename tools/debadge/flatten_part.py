"""3B ARMA SÖKÜCÜ — dokuda değil GEOMETRİDE kabartma olan armayı (ayrı Tripo parçası) düz bir yamaya çevirir.

debadge.py dokudaki logoyu boyar; ama bazı araçlarda arma ayrı bir parçada kabartmadır (VW T1'in önündeki yuvarlak
"VW" amblemi: tripo_part_19). Parça SİLİNEMEZ: arkasındaki gövde panelinde amblem boyunda delik var (denendi, içi
görünüyordu). Bu betik parçayı yamaya çevirir:
  1. Amblemin dış halkasına (gövdeye değdiği kenar) düzlem uydurulur; bütün köşeler o düzleme bastırılır
     (kabartma, harfler gider; delik kapalı kalır).
     Yama %8 geniş ve biraz önde: kavisli gövdedeki deliğin kenarını örter.
  2. Normaller kenar düzleminin normali olur (amblemin oturduğu yüzey; düz gölgelenir).
  3. Bütün UV'ler çevredeki gövde panelinin bir noktasına sabitlenir (adayların doku renklerinin ortancasına en yakın
     nokta): yama panelle aynı renktedir, dokudaki silik arma izi de görünmez. Doku GLB'nin içinden okunur (PIL).
GLB bayt düzeyinde düzenlenir: yalnız o parçanın POSITION / NORMAL / TEXCOORD_0 verisi ve accessor min/max'ı değişir;
doku, ad, materyal, öteki parçalar ve asset.extras (resimplify / lastik dolgusu işaretleri) aynı kalır.
Araç kaynaktan yeniden optimize edilirse tekrar koşulmalı.

Kullanım: python3 tools/debadge/flatten_part.py <araç.glb> <parça_adı> [<parça_adı> ...]
Sonra: godot --import, tools/make_car_thumbs.gd -- <id>, tools/postcards/build.sh <id> (restorasyon aracıysa).
Model ön yönü +Z kabul edilir (projenin araç kuralı).
"""
import io
import json
import math
import struct
import sys

from PIL import Image

LIFT = 0.0012   # yama düzlemden bu kadar öne (model birimi): kavisli gövde kenarda yamanın önüne geçmesin
GROW = 1.08     # yama amblemden bu kadar geniş: gövdedeki deliğin kenarını örter (yoksa içi hilal gibi görünür)


def _read(data, start, stride, count, fmt):
    return [struct.unpack_from(fmt, data, start + i * stride) for i in range(count)]


def _attr(gltf, data, bin_start, prim, name):
    acc = gltf['accessors'][prim['attributes'][name]]
    view = gltf['bufferViews'][acc['bufferView']]
    width = {'VEC3': 12, 'VEC2': 8}[acc['type']]
    stride = view.get('byteStride', width)
    start = bin_start + view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    fmt = '<fff' if acc['type'] == 'VEC3' else '<ff'
    return acc, start, stride, _read(data, start, stride, acc['count'], fmt)


def _solve3(m, v):
    """3x3 doğrusal sistem (Cramer)."""
    def det(a):
        return (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
                + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
    d = det(m)
    out = []
    for k in range(3):
        mk = [row[:] for row in m]
        for r in range(3):
            mk[r][k] = v[r]
        out.append(det(mk) / d)
    return out


def _plane(points):
    """En küçük kareler: z = a·x + b·y + c (araç önü +Z, yüzey ona dönük)."""
    sxx = sum(p[0] * p[0] for p in points); sxy = sum(p[0] * p[1] for p in points); sx = sum(p[0] for p in points)
    syy = sum(p[1] * p[1] for p in points); sy = sum(p[1] for p in points); n = float(len(points))
    sxz = sum(p[0] * p[2] for p in points); syz = sum(p[1] * p[2] for p in points); sz = sum(p[2] for p in points)
    return _solve3([[sxx, sxy, sx], [sxy, syy, sy], [sx, sy, n]], [sxz, syz, sz])


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    path = sys.argv[1]
    names = set(sys.argv[2:])
    data = bytearray(open(path, 'rb').read())
    json_len, = struct.unpack_from('<I', data, 12)
    gltf = json.loads(bytes(data[20:20 + json_len]))
    bin_start = 20 + json_len + 8
    image_view = gltf['bufferViews'][gltf['images'][0]['bufferView']]
    texture = Image.open(io.BytesIO(bytes(data[bin_start + image_view.get('byteOffset', 0):
                                               bin_start + image_view.get('byteOffset', 0) + image_view['byteLength']]))).convert('RGB')
    # Gövde köşeleri (model uzayı) + normal + UV: yamanın rengi buradan seçilir
    body = []
    for node in gltf['nodes']:
        if 'mesh' not in node or node.get('name') in names:
            continue
        t = node.get('translation', [0.0, 0.0, 0.0])
        for prim in gltf['meshes'][node['mesh']]['primitives']:
            if 'TEXCOORD_0' not in prim['attributes'] or 'NORMAL' not in prim['attributes']:
                continue
            pos = _attr(gltf, data, bin_start, prim, 'POSITION')[3]
            nor = _attr(gltf, data, bin_start, prim, 'NORMAL')[3]
            uvs = _attr(gltf, data, bin_start, prim, 'TEXCOORD_0')[3]
            for p, q, uv in zip(pos, nor, uvs):
                body.append(((p[0] + t[0], p[1] + t[1], p[2] + t[2]), q, uv))
    done = []
    for node in gltf['nodes']:
        if node.get('name') not in names or 'mesh' not in node:
            continue
        t = node.get('translation', [0.0, 0.0, 0.0])
        for prim in gltf['meshes'][node['mesh']]['primitives']:
            pacc, pstart, pstride, local = _attr(gltf, data, bin_start, prim, 'POSITION')
            pts = [(p[0] + t[0], p[1] + t[1], p[2] + t[2]) for p in local]
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            radial = [math.hypot(p[0] - cx, p[1] - cy) for p in pts]
            rmax = max(radial)
            rim = [p for p, r in zip(pts, radial) if r > 0.85 * rmax]
            a, b, c = _plane(rim)
            norm = math.sqrt(a * a + b * b + 1.0)
            n = (-a / norm, -b / norm, 1.0 / norm)
            center = (cx, cy, a * cx + b * cy + c)
            # Yama normali: amblemin oturduğu yüzeyin (kenar düzleminin) normali. Çevredeki gövde normallerinin
            # ortalaması bir yana kayıyordu (yama ışığa fazla dönük, açık kalıyordu).
            shade = n
            flat = []
            for p in pts:
                dist = (p[2] - (a * p[0] + b * p[1] + c)) / norm   # düzleme işaretli uzaklık (n yönünde)
                q = [p[k] - n[k] * (dist - LIFT) for k in range(3)]
                flat.append(tuple(center[k] + (q[k] - center[k]) * GROW for k in range(3)))
            for i, p in enumerate(flat):
                struct.pack_into('<fff', data, pstart + i * pstride, p[0] - t[0], p[1] - t[1], p[2] - t[2])
            pacc['min'] = [min(p[k] - t[k] for p in flat) for k in range(3)]
            pacc['max'] = [max(p[k] - t[k] for p in flat) for k in range(3)]
            nacc, nstart, nstride, _ = _attr(gltf, data, bin_start, prim, 'NORMAL')
            for i in range(nacc['count']):
                struct.pack_into('<fff', data, nstart + i * nstride, *shade)
            if 'min' in nacc:
                nacc['min'] = list(shade)
                nacc['max'] = list(shade)
            # Renk: deliğin kenarındaki gövde noktalarının (0,95–1,3 yarıçap) doku renkleri; ortanca renge en yakını
            # seçilir (daha geniş halka alttaki kırmızı "V"ye taşıyordu; tek texel'deki kir / iz de yama olmasın)
            candidates = [(p, q, uv) for p, q, uv in body if 0.95 * rmax < math.dist(p, center) < 1.3 * rmax
                          and q[0] * shade[0] + q[1] * shade[1] + q[2] * shade[2] > 0.85]
            if not candidates:
                sys.exit('yakında aynı yöne bakan gövde noktası bulunamadı: ' + node['name'])
            colors = [texture.getpixel((min(int(uv[0] * texture.width), texture.width - 1),
                                        min(int(uv[1] * texture.height), texture.height - 1))) for _, _, uv in candidates]
            median = tuple(sorted(col[k] for col in colors)[len(colors) // 2] for k in range(3))
            # Atlasın kenarındaki UV mip'te komşu adalarla karışır: kenardan uzak adaylar öne alınır
            def edge_penalty(i: int) -> float:
                u, v = candidates[i][2]
                return 0.0 if 0.05 < u < 0.95 and 0.05 < v < 0.95 else 1.0e6
            pick = min(range(len(candidates)),
                       key=lambda i: edge_penalty(i) + sum((colors[i][k] - median[k]) ** 2 for k in range(3)))
            best = (0.0, candidates[pick][2], candidates[pick][0])
            uacc, ustart, ustride, _ = _attr(gltf, data, bin_start, prim, 'TEXCOORD_0')
            for i in range(uacc['count']):
                struct.pack_into('<ff', data, ustart + i * ustride, *best[1])
            if 'min' in uacc:
                uacc['min'] = list(best[1])
                uacc['max'] = list(best[1])
            print('%s: %d köşe düzleme (normal %.3f %.3f %.3f), %d aday, ortanca renk %s, uv %s'
                  % (node['name'], len(pts), shade[0], shade[1], shade[2], len(candidates), median,
                     tuple(round(v, 4) for v in best[1])))
        done.append(node['name'])
    missing = names - set(done)
    if missing:
        sys.exit('bulunamadı: ' + ', '.join(sorted(missing)))
    new_json = json.dumps(gltf, separators=(',', ':')).encode('utf-8')
    new_json += b' ' * ((4 - len(new_json) % 4) % 4)   # glTF: JSON parçası 4 bayta hizalı, boşlukla doldurulur
    out = bytearray(data[:12])
    out += struct.pack('<II', len(new_json), 0x4E4F534A) + new_json
    out += data[20 + json_len:]
    struct.pack_into('<I', out, 8, len(out))
    open(path, 'wb').write(out)


if __name__ == '__main__':
    main()
