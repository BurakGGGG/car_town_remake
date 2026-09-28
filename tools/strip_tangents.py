#!/usr/bin/env python3
"""GLB'den TANJANT özniteliğini atar ve tamponu sıkıştırır.

Neden: kaynak Tripo GLB'lerinde tanjant YOK; Godot'un glTF yükleyicisi UV gördüğü için
üretiyor ve `ArrayMesh.add_surface_from_arrays` diziden silinse bile geri ekliyor. Oyunda
hiçbir materyal normal map kullanmadığından vertex başına 16 bayt tamamen boşa gidiyor.
`.glb.import`'taki `ensure_tangents=false` yalnızca EKSİKSE üretmeyi engeller, var olanı atmaz.

Çalıştırma: python3 tools/strip_tangents.py assets/cars/optimized/*.glb
"""
import json, struct, sys, os


def strip(path: str) -> tuple[int, int]:
    with open(path, "rb") as f:
        magic, ver, total = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            raise ValueError("GLB değil: " + path)
        jlen, jtype = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(jlen))
        blen, btype = struct.unpack("<II", f.read(8))
        bin_chunk = f.read(blen)

    removed = 0
    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            if prim["attributes"].pop("TANGENT", None) is not None:
                removed += 1
    if removed == 0:
        return 0, os.path.getsize(path)

    # Yalnızca hâlâ başvurulan bufferView'ları tut, tamponu yeniden kur
    used = set()
    for acc in js.get("accessors", []):
        if "bufferView" in acc:
            used.add(acc["bufferView"])
    for img in js.get("images", []):
        if "bufferView" in img:
            used.add(img["bufferView"])
    referenced = set()
    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            for a in prim["attributes"].values():
                referenced.add(a)
            if "indices" in prim:
                referenced.add(prim["indices"])
    for i, acc in enumerate(js.get("accessors", [])):
        if i in referenced and "bufferView" in acc:
            continue
    keep_bv = set()
    for i, acc in enumerate(js.get("accessors", [])):
        if i in referenced and "bufferView" in acc:
            keep_bv.add(acc["bufferView"])
    for img in js.get("images", []):
        if "bufferView" in img:
            keep_bv.add(img["bufferView"])

    old_bv = js["bufferViews"]
    new_bv, bv_map, out = [], {}, bytearray()
    for i, bv in enumerate(old_bv):
        if i not in keep_bv:
            continue
        off, ln = bv.get("byteOffset", 0), bv["byteLength"]
        while len(out) % 4:                     # glTF: bufferView 4 bayta hizalı
            out.append(0)
        nb = dict(bv)
        nb["byteOffset"] = len(out)
        bv_map[i] = len(new_bv)
        new_bv.append(nb)
        out += bin_chunk[off:off + ln]
    js["bufferViews"] = new_bv
    for acc in js.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = bv_map.get(acc["bufferView"], 0)
    for img in js.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = bv_map.get(img["bufferView"], 0)
    # kullanılmayan accessor'lar JSON'da kalabilir; veri taşımadıkları için maliyetsiz
    js["buffers"] = [{"byteLength": len(out)}]

    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    out += b"\x00" * ((4 - len(out) % 4) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(out)))
        f.write(struct.pack("<II", len(jb), 0x4E4F534A)); f.write(jb)
        f.write(struct.pack("<II", len(out), 0x004E4942)); f.write(out)
    return removed, os.path.getsize(path)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        before = os.path.getsize(p)
        n, after = strip(p)
        print("%-46s %2d yüzeyden tanjant atıldı  %.2f -> %.2f MB (-%.1f%%)" % (
            os.path.basename(p), n, before / 1048576, after / 1048576,
            100.0 * (before - after) / before))
