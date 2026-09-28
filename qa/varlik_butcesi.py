#!/usr/bin/env python3
"""ARAÇ VARLIK BÜTÇESİ: APK'ya giren içe aktarılmış kaynakların dökümü.

Android'e iki doku formatından yalnızca etc2 gider; s3tc masaüstü içindir.
Çalıştırma: python3 qa/varlik_butcesi.py
"""
import os, re, glob, collections

def dest(imp):
    m = re.findall(r'dest_files=\[([^\]]*)\]', open(imp, encoding="utf-8", errors="replace").read(), re.S)
    return [p for p in re.findall(r'"res://([^"]+)"', m[0])] if m else []

tot = collections.Counter()
per_car = collections.defaultdict(lambda: collections.Counter())
for imp in glob.glob("assets/cars/optimized/*.import"):
    src = imp[:-7]
    base = os.path.basename(src)
    car = base.split("_car_albedo")[0].split("_paintmask")[0]
    car = car[:-4] if car.endswith((".glb", ".png", ".jpg")) else car
    for p in dest(imp):
        if not os.path.exists(p):
            continue
        sz = os.path.getsize(p)
        if p.endswith(".scn"):
            k = "mesh"
        elif ".etc2." in p:
            k = "doku (android)"
        elif ".s3tc." in p:
            k = "doku (masaüstü)"
        else:
            k = "maske"
        tot[k] += sz
        per_car[car][k] += sz

print("%-24s %9s %9s %9s %9s" % ("araç", "mesh MB", "doku MB", "maske", "android"))
for car in sorted(per_car, key=lambda c: -per_car[c]["mesh"]):
    d = per_car[car]
    print("%-24s %9.2f %9.2f %9.2f %9.2f" % (car, d["mesh"]/1048576, d["doku (android)"]/1048576,
        d["maske"]/1048576, (d["mesh"]+d["doku (android)"]+d["maske"])/1048576))
print("-"*66)
android = tot["mesh"] + tot["doku (android)"] + tot["maske"]
print("%-24s %9.2f %9.2f %9.2f %9.2f" % ("TOPLAM", tot["mesh"]/1048576,
    tot["doku (android)"]/1048576, tot["maske"]/1048576, android/1048576))
print("(masaüstü s3tc dokuları %.1f MB — Android APK'ya girmez)" % (tot["doku (masaüstü)"]/1048576))
