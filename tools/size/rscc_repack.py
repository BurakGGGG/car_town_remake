#!/usr/bin/env python3
"""RSCC YENİDEN PAKETLEME — kayıpsız paket küçültme (2026-10-23, paket boyutu 4).

Godot ikili kaynakları (.scn / .res; içe aktarılmış araç / dünya / dekor mesh'leri) `RSCC` kabında, 4 KB'lık
bloklar hâlinde ayrı ayrı zstd ile sıkıştırılır (FileAccessCompressed, blok boyu motorda sabit 4096). Mesh verisi
küçük blokta neredeyse sıkışmıyor; 2 MiB blokla zstd-19'da ~%13,5 küçülür (tüm kaynaklar: 4 KB 207,2 → 1 MiB 170,2 →
2 MiB 168,3 → tek blok 166,8 MiB). Okuyucu blok boyunu dosya başlığından alır (her boyutu okur): yalnız YAZAN taraf
değişir, oyunun motoru aynıdır, açılan bayt dizisi aynıdır. Blok 2 MiB ile sınırlı: FileAccessCompressed yüklerken dosya
başına bir blokluk arabellek + sıkışık blok tutar; tek blokta bu en büyük araçta ~14 MB'a çıkıyordu (trafik / hurdalık
modelleri paralel yüklenir, düşük RAM'li telefonda tepe bellek), 2 MiB'te ≤ ~4 MB.

Bu betik `.godot/imported` içindeki RSCC dosyalarını büyük blokla yeniden yazar ve her birinin `.md5` kaydındaki
`dest_md5`'i günceller (yoksa editör dosyayı bozulmuş sayıp yeniden içe aktarır ve 4 KB'a döner). Her dosya için
yeni kabın açılmış içeriği eskisiyle bayt bayt karşılaştırılır; farklıysa dosyaya dokunulmaz.

Kullanım (proje kökünden; dışa aktarmadan ÖNCE — tools/build_release_aab.sh ve build_debug_apk.sh çağırır):
    python3 tools/size/rscc_repack.py            # yeniden yaz
    python3 tools/size/rscc_repack.py --check    # yalnız ölç, yazma
Yeni içe aktarma (araç ekleme, ayar değişimi) o dosyayı yine 4 KB'a döndürür; betik sonraki dışa aktarmada onu da yakalar.
"""
import ctypes
import glob
import hashlib
import os
import re
import struct
import sys

MAX_BLOCK = 2 << 20      # küçük dosya tek blok, büyüğü 2 MiB bloklar (yükleme arabelleği sınırlı)
LEVEL = 19               # project.godot compression/formats/zstd/compression_level ile aynı
MODE_ZSTD = 2
IMPORTED = ".godot/imported"
## İçe aktarılmayan, ResourceSaver.FLAG_COMPRESS ile kaydedilen proje kaynakları (pişirme araçları yeniden yazınca 4 KB'a döner).
EXTRA = ["vfx/decor_patterns.res"] + sorted(glob.glob("assets/cars/far_lod/*.res"))

_z = ctypes.CDLL("libzstd.so.1")
_z.ZSTD_compressBound.restype = ctypes.c_size_t
_z.ZSTD_compress.restype = ctypes.c_size_t
_z.ZSTD_decompress.restype = ctypes.c_size_t
_z.ZSTD_isError.restype = ctypes.c_uint


def _compress(data: bytes) -> bytes:
    cap = _z.ZSTD_compressBound(ctypes.c_size_t(len(data)))
    out = ctypes.create_string_buffer(cap)
    n = _z.ZSTD_compress(out, ctypes.c_size_t(cap), data, ctypes.c_size_t(len(data)), ctypes.c_int(LEVEL))
    if _z.ZSTD_isError(ctypes.c_size_t(n)):
        raise RuntimeError("zstd sıkıştırma hatası")
    return out.raw[:n]


def _decompress(data: bytes, size: int) -> bytes:
    out = ctypes.create_string_buffer(max(size, 1))
    n = _z.ZSTD_decompress(out, ctypes.c_size_t(size), data, ctypes.c_size_t(len(data)))
    if _z.ZSTD_isError(ctypes.c_size_t(n)) or n != size:
        raise RuntimeError("zstd açma hatası")
    return out.raw[:n]


def unpack(blob: bytes) -> tuple[bytes, int]:
    """RSCC → (açılmış içerik, blok boyu). FileAccessCompressed düzeni: magic, kip, blok, toplam, blok boyları, bloklar,
    sonda yine magic."""
    if blob[:4] != b"RSCC":
        raise ValueError("RSCC değil")
    mode, block, total = struct.unpack_from("<III", blob, 4)
    if mode != MODE_ZSTD:
        raise ValueError("zstd değil (kip %d)" % mode)
    count = total // block + 1
    sizes = struct.unpack_from("<%dI" % count, blob, 16)
    pos = 16 + 4 * count
    out = bytearray()
    for i, size in enumerate(sizes):
        out += _decompress(blob[pos:pos + size], min(block, total - i * block))
        pos += size
    if len(out) != total or blob[pos:] != b"RSCC":
        raise ValueError("bozuk RSCC")
    return bytes(out), block


def block_for(raw: bytes) -> int:
    """2 MiB'e kadar dosya tek blok (4 KB'ın katına yuvarlanmış), büyüğü 2 MiB bloklar."""
    if len(raw) > MAX_BLOCK:
        return MAX_BLOCK
    return max(4096, (len(raw) + 4095) // 4096 * 4096)


def pack(raw: bytes, block: int = 0) -> bytes:
    block = block or block_for(raw)
    total = len(raw)
    count = total // block + 1   # motor da son (boş olabilen) bloğu sayar
    chunks = [_compress(raw[i * block:min((i + 1) * block, total)]) for i in range(count)]
    head = b"RSCC" + struct.pack("<III", MODE_ZSTD, block, total)
    return head + struct.pack("<%dI" % count, *[len(c) for c in chunks]) + b"".join(chunks) + b"RSCC"


def _md5_path(dest: str) -> str:
    # <ad>.<uzantı>-<karma>.<scn|res> → <ad>.<uzantı>-<karma>.md5
    return re.sub(r"\.[^.]+$", ".md5", dest)


def main() -> int:
    check_only = "--check" in sys.argv
    if not os.path.isdir(IMPORTED):
        print("proje kökünden çalıştır (.godot/imported yok)")
        return 1
    before = after = changed = skipped = 0
    for name in sorted(os.listdir(IMPORTED)):
        if not name.endswith((".scn", ".res")):
            continue
        path = os.path.join(IMPORTED, name)
        blob = open(path, "rb").read()
        if blob[:4] != b"RSCC":
            continue
        raw, block = unpack(blob)
        before += len(blob)
        if block == block_for(raw):
            after += len(blob)
            continue
        md5_file = _md5_path(path)
        record = open(md5_file, encoding="utf-8").read() if os.path.exists(md5_file) else ""
        old_md5 = hashlib.md5(blob).hexdigest()
        if 'dest_md5="%s"' % old_md5 not in record:
            # Çok hedefli içe aktarma ya da kayıt eski: dokunma (editör kendi hesabına güvenir)
            skipped += 1
            after += len(blob)
            continue
        new = pack(raw)
        if unpack(new)[0] != raw:
            raise RuntimeError("geri açılan içerik farklı: " + name)
        if len(new) >= len(blob) and block == 4096:
            after += len(blob)   # Godot'nun çıktısından büyüğünü yazma (bloğu sınırlamak için büyüyebilir)
            continue
        after += len(new)
        changed += 1
        if check_only:
            continue
        tmp = path + ".tmp"
        open(tmp, "wb").write(new)
        os.replace(tmp, path)
        open(md5_file, "w", encoding="utf-8").write(record.replace(old_md5, hashlib.md5(new).hexdigest()))
    for path in EXTRA:
        if not os.path.exists(path):
            continue
        blob = open(path, "rb").read()
        if blob[:4] != b"RSCC":
            continue
        raw, block = unpack(blob)
        before += len(blob)
        new = pack(raw) if block != block_for(raw) else blob
        if unpack(new)[0] != raw:
            raise RuntimeError("geri açılan içerik farklı: " + path)
        grow_ok: bool = block != 4096 and block != block_for(raw)
        after += len(new) if (len(new) < len(blob) or grow_ok) else len(blob)
        if len(new) < len(blob) or grow_ok:
            changed += 1
            if not check_only:
                open(path, "wb").write(new)
    print("RSCC: %.2f → %.2f MiB (−%.2f), %d dosya %s, %d atlandı" % (before / 2**20, after / 2**20,
          (before - after) / 2**20, changed, "küçülür" if check_only else "yeniden yazıldı", skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
