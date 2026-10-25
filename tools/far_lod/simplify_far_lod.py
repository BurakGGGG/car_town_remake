#!/usr/bin/env python3
"""ARAÇ UZAK LOD'u — make_far_lod.gd'nin döktüğü parça dizilerini meshoptimizer ile sadeleştirir.

Godot'nun içe aktarıcısı LOD zincirini parça kenarları KİLİTLİ üretiyor (SIMPLIFY_LOCK_BORDER): Tripo parçaları açık
kabuk olduğu için en kaba kademe 19–61 bin üçgende tıkanıyor. Burada kenar kilidi yok ve "permissive" kip açık
(öznitelik dikişlerinin üstünden de çöker); sınır MUTLAK sapma (--error, mesh birimi; araç uzunluğu = 1). Sonuç yalnız
uzak kademede çizilir: Godot kademeyi ekrandaki sapmaya göre seçer (bkz. CarMeshMerger), bu yüzden sapma pikselin
altındayken devreye girer.

Girdi make_far_lod.gd'nin dökümü (FLI1: parça başına anahtar, köşe / indeks / en kaba kademe sayısı, konum, normal,
UV, indeks); çıktı (FLO1: sapma sınırı; parça başına anahtar, köşe sayısı, ilk köşe, sadeleşmiş indeksler) aynı betiğin
"pack" kipine gider. Kütüphane resimplify_car.py ile aynı (Godot'nun meshoptimizer'ı, 1.1):
  g++ -O2 -shared -fPIC -o ~/.cache/autoyard/libmeshopt.so ~/godot-build/godot/thirdparty/meshoptimizer/*.cpp
Kullanım: tools/far_lod/make_far_lod.sh (bu betiği her araç için çağırır).
"""
import argparse, ctypes, os, struct, sys
from array import array

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import resimplify_car as R  # noqa: E402  (kütüphane yükleyici)

SIMPLIFY_LOCK_BORDER = 1 << 0
SIMPLIFY_ERROR_ABSOLUTE = 1 << 2
SIMPLIFY_PRUNE = 1 << 3
SIMPLIFY_PERMISSIVE = 1 << 5
# Normal / UV toleransı: bu kadar sapma --error kadar konum sapmasıyla eş tutulur. Tripo normalleri gürültülü: 0,05'te
# büyüyen üçgenler gürültüyü koyu lekeye çeviriyordu (otopark, 2026-10-25; resimplify_car.py'deki dersin aynısı); 0,01'de
# lekeler gidiyor, üçgen kazancı yine ~%55. Dokuda 2 texel kayma görünmez (1024² doku, uzakta küçük mip).
NORMAL_TOL = 0.01
UV_TOL = 2.0 / 1024.0
MIN_GAIN = 0.10   # içe aktarıcının sapması --error'a sığan en kaba kademesinden %10'dan az kazandıran parça yazılmaz


def load_lib():
    lib = R.load_lib()
    lib.meshopt_optimizeVertexCache.restype = None
    lib.meshopt_optimizeVertexCache.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t]
    return lib


def read_input(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"FLI2":
        raise ValueError("girdi değil: " + path)
    at = 4
    (count,) = struct.unpack_from("<I", data, at); at += 4
    out = []
    for _ in range(count):
        (klen,) = struct.unpack_from("<H", data, at); at += 2
        key = data[at:at + klen].decode("utf-8"); at += klen
        vc, ic, coarse, flags = struct.unpack_from("<IIII", data, at); at += 16
        pos = array("f"); pos.frombytes(data[at:at + vc * 12]); at += vc * 12
        nrm = array("f"); nrm.frombytes(data[at:at + vc * 12]); at += vc * 12
        uv = array("f"); uv.frombytes(data[at:at + vc * 8]); at += vc * 8
        idx = array("I"); idx.frombytes(data[at:at + ic * 4]); at += ic * 4
        out.append((key, vc, ic, coarse, flags, pos, nrm, uv, idx))
    return out


def simplify(lib, vc, ic, pos, nrm, uv, idx, error, lock=False, normal_tol=NORMAL_TOL, permissive=True):
    attrs = array("f", [0.0]) * (vc * 5)
    for v in range(vc):
        attrs[v * 5:v * 5 + 3] = nrm[v * 3:v * 3 + 3]
        attrs[v * 5 + 3:v * 5 + 5] = uv[v * 2:v * 2 + 2]
    scale = lib.meshopt_simplifyScale(pos.buffer_info()[0], vc, 12)
    rel = error / max(scale, 1e-9)
    w = array("f", [rel / normal_tol] * 3 + [rel / UV_TOL] * 2)
    dst = array("I", [0]) * ic
    err = ctypes.c_float(0.0)
    n = lib.meshopt_simplifyWithAttributes(
        dst.buffer_info()[0], idx.buffer_info()[0], ic, pos.buffer_info()[0], vc, 12,
        attrs.buffer_info()[0], 20, w.buffer_info()[0], 5, None, 3, ctypes.c_float(error),
        SIMPLIFY_ERROR_ABSOLUTE | (SIMPLIFY_PERMISSIVE if permissive else 0) | (SIMPLIFY_LOCK_BORDER if lock else SIMPLIFY_PRUNE),
        ctypes.byref(err))
    dst = dst[:n]
    if n:
        lib.meshopt_optimizeVertexCache(dst.buffer_info()[0], dst.buffer_info()[0], n, vc)
    return dst, err.value


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--error", type=float, default=0.004)
    ap.add_argument("--wheel-error", type=float, default=0.0)   # 0 = dönen parçalar yazılmaz
    ap.add_argument("--normal-tol", type=float, default=NORMAL_TOL)
    ap.add_argument("--no-permissive", action="store_true")
    ap.add_argument("input")
    ap.add_argument("output")
    a = ap.parse_args()
    lib = load_lib()
    rows = []
    base = coarse_total = far_total = 0
    for key, vc, ic, coarse, flags, pos, nrm, uv, idx in read_input(a.input):
        spin = bool(flags & 1)
        if spin and a.wheel_error <= 0.0:
            continue
        base += ic // 3
        coarse_total += coarse // 3
        # Dönen parçalar (lastik açık kabuk): kenar kilitli, sıkı sapma — kilitsiz uzak kademe lastikte boşluk açıyordu
        # (qa/teker_tarama.gd lod=0 merge)
        dst, err = simplify(lib, vc, ic, pos, nrm, uv, idx, a.wheel_error if spin else a.error, lock=spin,
                            normal_tol=a.normal_tol, permissive=not a.no_permissive)
        if len(dst) >= coarse * (1.0 - MIN_GAIN):
            far_total += coarse // 3
            continue
        far_total += len(dst) // 3
        rows.append((key, vc, pos[0:3], dst, err))
    with open(a.output, "wb") as f:
        f.write(b"FLO1" + struct.pack("<If", len(rows), a.error))
        for key, vc, first, dst, err in rows:
            kb = key.encode("utf-8")
            f.write(struct.pack("<H", len(kb)) + kb + struct.pack("<I3fIf", vc, *first, len(dst), err))
            f.write(dst.tobytes())
    print("FARLOD %s taban %d, kaba %d, uzak %d (%d parça)" % (os.path.basename(a.input), base, coarse_total,
                                                               far_total, len(rows)))


if __name__ == "__main__":
    main()
