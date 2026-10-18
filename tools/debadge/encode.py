#!/usr/bin/env python3
"""debadge.py'nin ham çıktısını (uint8, üst satır önce) JPEG / PNG'ye kodlar (PIL).

  python3 -I tools/debadge/encode.py <girdi.raw> <çıktı> RGB|L <genişlik> <yükseklik>
"""
import sys

from PIL import Image

src, dst, mode, w, h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
with open(src, "rb") as f:
    img = Image.frombytes(mode, (w, h), f.read())
if dst.lower().endswith((".jpg", ".jpeg")):
    img.save(dst, quality=90, optimize=True)
else:
    img.save(dst, optimize=True)
