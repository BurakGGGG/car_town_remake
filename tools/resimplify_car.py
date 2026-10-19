#!/usr/bin/env python3
"""Optimize edilmiş araç GLB'sini HATA SINIRLI olarak yeniden sadeleştirir (pakette mesh küçülür).

Neden: optimize_car.gd sabit oranla (%12,5) sadeleştiriyor; düz kaporta panellerinde bu oran
gereğinden çok üçgen bırakıyor. Burada her parça meshoptimizer ile MUTLAK bir sapma sınırına kadar
sadeleşir (--error, araç uzunluğu = 1 birim; 0,0008 ≈ 4,4 m araçta 3,5 mm, en yakın showroom
zoom'unda ~0,4 piksel). Normal ve UV de hata hesabına girer: dokudaki çizgiler kaymaz, gölgelenme
lekelenmez (asıl sınırı normal toleransı belirliyor; ölçüm qa/size_audit/mesh_probe.gd). Parça
kenarları kilitli (komşu parçayla aralık açılmaz), UV dikişleri korunur.
Ölçüm ve görsel karşılaştırma: docs/MESH_BUTCESI.md "Paket boyutu 3".

Dönen parçalara (tools/wheel_parts.gd çıktısı) dokunulmaz: teker ekseni geometrilerinden ölçüldü.
Düğüm adları, materyal, gömülü doku aynen kalır; CarPartMap indeksleri değişmez.

Kütüphane: Godot kaynağındaki meshoptimizer derlenir (bir kez):
  g++ -O2 -shared -fPIC -o ~/.cache/autoyard/libmeshopt.so ~/godot-build/godot/thirdparty/meshoptimizer/*.cpp

Kullanım:
  godot-4 --headless --path . -s res://tools/wheel_parts.gd | grep '^WHEELS ' | cut -c8- > /tmp/w.json
  python3 tools/resimplify_car.py --skip-json /tmp/w.json [--error 0.0008] assets/cars/optimized/*.glb
Sonra --import, küçük resimler (tools/make_car_thumbs.gd).
"""
import argparse, ctypes, json, os, struct, sys
from array import array

LIB = os.path.expanduser("~/.cache/autoyard/libmeshopt.so")
SIMPLIFY_LOCK_BORDER = 1 << 0
SIMPLIFY_ERROR_ABSOLUTE = 1 << 2

# Normal ve UV toleransı (bu kadar sapma, --error kadar konum sapmasıyla eş tutulur).
# Asıl sınır normal toleransı: Tripo normalleri gürültülü, büyüyen üçgen bu gürültüyü geniş lekeye
# çeviriyor. 0,04: BMW kapı altında üçgen gölge; 0,005: Sprinter kapı kolunda leke; 0,0025 temiz.
NORMAL_TOL = 0.0025
UV_TOL = 0.5 / 1024.0      # yarım texel (araç dokusu 1024²)
MIN_GAIN = 0.10            # %10'dan az üçgen kazandıran parça olduğu gibi kalır
# Araca özel daha sıkı (hata, normal toleransı). Toros: gövde TEK mesh ve başka kaynaktan %8'e inmiş;
# 0,0008 / 0,005 ile −%74 sadeleşip kapı altında kırışıklık bırakıyordu (mesh_probe 35 dB → bununla 41 dB).
TIGHT = {"renault_toros.glb": (0.0003, 0.001)}
# GLB'nin asset.extras'ına yazılan işaret: işaretli dosya atlanır (betik klasörün tamamına güvenle verilebilir).
MARK = "autoyard_resimplify"

COMP = {5126: ("f", 4), 5125: ("I", 4), 5123: ("H", 2), 5121: ("B", 1)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load_lib():
    lib = ctypes.CDLL(LIB)
    f = lib.meshopt_simplifyWithAttributes
    f.restype = ctypes.c_size_t
    f.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t,
                  ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t,
                  ctypes.c_void_p, ctypes.c_size_t, ctypes.c_float, ctypes.c_uint,
                  ctypes.POINTER(ctypes.c_float)]
    lib.meshopt_simplifyScale.restype = ctypes.c_float
    lib.meshopt_simplifyScale.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t]
    lib.meshopt_optimizeVertexFetchRemap.restype = ctypes.c_size_t
    lib.meshopt_optimizeVertexFetchRemap.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t,
                                                     ctypes.c_size_t]
    return lib


def read_glb(path):
    with open(path, "rb") as f:
        magic, _, _ = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            raise ValueError("GLB değil: " + path)
        jlen, _ = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(jlen))
        blen, _ = struct.unpack("<II", f.read(8))
        return js, f.read(blen)


def read_accessor(js, binc, idx):
    acc = js["accessors"][idx]
    bv = js["bufferViews"][acc["bufferView"]]
    code, size = COMP[acc["componentType"]]
    n = NCOMP[acc["type"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride", size * n)
    a = array(code)
    if stride == size * n:
        a.frombytes(binc[start:start + acc["count"] * stride])
    else:
        for i in range(acc["count"]):
            a.frombytes(binc[start + i * stride:start + i * stride + size * n])
    return a, n


def write_glb(path, js, binc):
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    binc = bytes(binc) + b"\x00" * ((4 - len(binc) % 4) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binc)))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A)); f.write(jb)
        f.write(struct.pack("<II", len(binc), 0x004E4942)); f.write(binc)


def simplify_prim(lib, pos, nrm, uv, idx, error, normal_tol=NORMAL_TOL):
    vc, ic = len(pos) // 3, len(idx)
    attrs = array("f", [0.0]) * (vc * 5)
    for v in range(vc):
        attrs[v * 5:v * 5 + 3] = nrm[v * 3:v * 3 + 3]
        attrs[v * 5 + 3:v * 5 + 5] = uv[v * 2:v * 2 + 2]
    # meshoptimizer konumu parça boyutuna normalize ederek öznitelikle kıyaslar: ağırlık, tolerans
    # kadar normal / UV sapmasını --error kadar konum sapmasına eşitler.
    scale = lib.meshopt_simplifyScale(pos.buffer_info()[0], vc, 12)
    rel = error / max(scale, 1e-9)
    w = array("f", [rel / normal_tol] * 3 + [rel / UV_TOL] * 2)
    src = array("I", idx)
    dst = array("I", [0]) * ic
    err = ctypes.c_float(0.0)
    n = lib.meshopt_simplifyWithAttributes(
        dst.buffer_info()[0], src.buffer_info()[0], ic, pos.buffer_info()[0], vc, 12,
        attrs.buffer_info()[0], 20, w.buffer_info()[0], 5, None, 0, ctypes.c_float(error),
        SIMPLIFY_LOCK_BORDER | SIMPLIFY_ERROR_ABSOLUTE, ctypes.byref(err))
    if n == 0 or n > ic * (1.0 - MIN_GAIN):
        return None
    dst = dst[:n]
    remap = array("I", [0]) * vc
    nv = lib.meshopt_optimizeVertexFetchRemap(remap.buffer_info()[0], dst.buffer_info()[0], n, vc)
    npos, nnrm, nuv = array("f", [0.0]) * (nv * 3), array("f", [0.0]) * (nv * 3), array("f", [0.0]) * (nv * 2)
    for v in range(vc):
        r = remap[v]
        if r == 0xFFFFFFFF:
            continue
        npos[r * 3:r * 3 + 3] = pos[v * 3:v * 3 + 3]
        nnrm[r * 3:r * 3 + 3] = nrm[v * 3:v * 3 + 3]
        nuv[r * 2:r * 2 + 2] = uv[v * 2:v * 2 + 2]
    nidx = array("I", (remap[i] for i in dst))
    return npos, nnrm, nuv, nidx, err.value


def process(lib, path, skip, error, dry, normal_tol=NORMAL_TOL):
    js, binc = read_glb(path)
    if MARK in js.get("asset", {}).get("extras", {}):
        return None    # zaten sadeleştirilmiş: ikinci geçiş hata payını katlar
    out = bytearray(binc)
    tris_before = tris_after = 0
    changed = 0

    def add_view(data, target):
        while len(out) % 4:
            out.append(0)
        js["bufferViews"].append({"buffer": 0, "byteOffset": len(out), "byteLength": len(data), "target": target})
        out.extend(data)
        return len(js["bufferViews"]) - 1

    def add_accessor(view, ctype, count, typ, extra=None):
        acc = {"bufferView": view, "componentType": ctype, "count": count, "type": typ}
        acc.update(extra or {})
        js["accessors"].append(acc)
        return len(js["accessors"]) - 1

    for node in js["nodes"]:
        if "mesh" not in node:
            continue
        name = node.get("name", "")
        part = int(name[len("tripo_part_"):]) if name.startswith("tripo_part_") and name[11:].isdigit() else -1
        for prim in js["meshes"][node["mesh"]]["primitives"]:
            attrs = prim["attributes"]
            pos, _ = read_accessor(js, binc, attrs["POSITION"])
            idx, _ = read_accessor(js, binc, prim["indices"])
            tris_before += len(idx) // 3
            if part in skip or "NORMAL" not in attrs or "TEXCOORD_0" not in attrs or prim.get("mode", 4) != 4 \
                    or set(attrs) - {"POSITION", "NORMAL", "TEXCOORD_0"}:
                tris_after += len(idx) // 3
                continue
            nrm, _ = read_accessor(js, binc, attrs["NORMAL"])
            uv, _ = read_accessor(js, binc, attrs["TEXCOORD_0"])
            res = simplify_prim(lib, pos, nrm, uv, idx, error, normal_tol)
            if res is None:
                tris_after += len(idx) // 3
                continue
            npos, nnrm, nuv, nidx, _ = res
            tris_after += len(nidx) // 3
            changed += 1
            nv = len(npos) // 3
            mn = [min(npos[i::3]) for i in range(3)]
            mx = [max(npos[i::3]) for i in range(3)]
            attrs["POSITION"] = add_accessor(add_view(npos.tobytes(), 34962), 5126, nv, "VEC3", {"min": mn, "max": mx})
            attrs["NORMAL"] = add_accessor(add_view(nnrm.tobytes(), 34962), 5126, nv, "VEC3")
            attrs["TEXCOORD_0"] = add_accessor(add_view(nuv.tobytes(), 34962), 5126, nv, "VEC2")
            if nv < 65536:
                prim["indices"] = add_accessor(add_view(array("H", nidx).tobytes(), 34963), 5123, len(nidx), "SCALAR")
            else:
                prim["indices"] = add_accessor(add_view(nidx.tobytes(), 34963), 5125, len(nidx), "SCALAR")

    if not dry:
        js.setdefault("asset", {}).setdefault("extras", {})[MARK] = {"error": error, "normal_tol": normal_tol}
        js, out = compact(js, out)
        write_glb(path, js, out)
    return tris_before, tris_after, changed


def compact(js, binc):
    """Başvurulmayan accessor / bufferView'ları atıp tamponu yeniden kurar."""
    used_acc = set()
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            used_acc.update(prim["attributes"].values())
            if "indices" in prim:
                used_acc.add(prim["indices"])
    acc_map, new_acc = {}, []
    for i, acc in enumerate(js["accessors"]):
        if i in used_acc:
            acc_map[i] = len(new_acc)
            new_acc.append(acc)
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = acc_map[prim["indices"]]
    keep = {a["bufferView"] for a in new_acc if "bufferView" in a}
    keep.update(img["bufferView"] for img in js.get("images", []) if "bufferView" in img)
    bv_map, new_bv, out = {}, [], bytearray()
    for i, bv in enumerate(js["bufferViews"]):
        if i not in keep:
            continue
        while len(out) % 4:
            out.append(0)
        nb = dict(bv)
        off = bv.get("byteOffset", 0)
        nb["byteOffset"] = len(out)
        out += binc[off:off + bv["byteLength"]]
        bv_map[i] = len(new_bv)
        new_bv.append(nb)
    for acc in new_acc:
        if "bufferView" in acc:
            acc["bufferView"] = bv_map[acc["bufferView"]]
    for img in js.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = bv_map[img["bufferView"]]
    js["accessors"], js["bufferViews"] = new_acc, new_bv
    js["buffers"] = [{"byteLength": len(out)}]
    return js, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-json", required=True, help="tools/wheel_parts.gd çıktısı")
    ap.add_argument("--error", type=float, default=0.0008, help="mutlak sapma sınırı (araç uzunluğu = 1)")
    ap.add_argument("--normal-tol", type=float, default=NORMAL_TOL, help="--error'a eş tutulan normal sapması")
    ap.add_argument("--dry", action="store_true", help="yalnızca ölç, yazma")
    ap.add_argument("glbs", nargs="+")
    a = ap.parse_args()
    skip_all = json.load(open(a.skip_json))
    lib = load_lib()
    tb = ta = 0
    for p in a.glbs:
        key = os.path.relpath(os.path.abspath(p), os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
        if key not in skip_all:
            print("ATLANDI (katalogda yok): " + p)
            continue
        error, normal_tol = TIGHT.get(os.path.basename(p), (a.error, a.normal_tol))
        res = process(lib, p, set(skip_all[key]), error, a.dry, normal_tol)
        if res is None:
            print("%-40s zaten sadeleştirilmiş, atlandı" % os.path.basename(p))
            continue
        b, t, c = res
        tb += b
        ta += t
        print("%-40s %7d -> %7d üçgen (-%4.1f%%)  %d parça" % (os.path.basename(p), b, t, 100.0 * (b - t) / max(b, 1), c))
    print("TOPLAM %d -> %d üçgen (-%.1f%%)" % (tb, ta, 100.0 * (tb - ta) / max(tb, 1)))


if __name__ == "__main__":
    sys.exit(main())
