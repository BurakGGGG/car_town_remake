#!/usr/bin/env python3
"""Telefonda EKRANA ÇIKAN kareleri SurfaceFlinger'dan ölçer — oyuna kod eklemeden, release APK'da da çalışır.
Kullanım (telefon adb'ye bağlı, oyun ekranda açık): tools/telefon_kare_olcum.py [saniye=10] [paket=com.autoyard.app]

Yazdığı: ekran yenileme periyodu, ortalama FPS, kare başına kaç yenileme ekranda kaldığı (1 vsync = zamanında),
yüzdelikler ve ardışık kare süresi değişimi. Değişim yüksekse FPS iyi görünse de akış titrer: 90 Hz ekranda 60 kare
11 / 22 ms karışık gelir (2026-10-26 Samsung A24: değişim %55–88; DisplayRate 60 Hz isteğinden sonra %1,4).
Godot'un kendi kare süresi (delta) yenilemeye yuvarlandığı için bu ölçümün yerini tutmaz.
Android 13+ katman adı "RequestedLayerState{<ad> parentId=…}" biçiminde listelenir; --latency'ye <ad> verilir."""
import collections, re, subprocess, sys, time

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 10
pkg = sys.argv[2] if len(sys.argv) > 2 else "com.autoyard.app"
def sh(cmd):
    return subprocess.run(["adb", "shell", cmd], capture_output=True, text=True).stdout


def clean(l):
    l = l.strip()
    m = re.match(r"RequestedLayerState\{(.*?)( parentId=.*)?\}$", l)
    return m.group(1) if m else l
layers = [clean(l) for l in sh("dumpsys SurfaceFlinger --list").splitlines() if pkg in l and "SurfaceView" in l and "Background" not in l]
if not layers:
    sys.exit("oyunun çizim katmanı yok: oyun ekranda açık mı, telefon bağlı mı (adb devices)?")
print("katmanlar:", layers)
layer = next((l for l in layers if "BLAST" in l), layers[0])
print("ölçülen:", layer)
sh("dumpsys SurfaceFlinger --latency-clear")
present = set(); period = 0
end = time.time() + secs
while time.time() < end:
    out = sh("dumpsys SurfaceFlinger --latency '%s'" % layer).split("\n")
    if out and out[0].strip().isdigit():
        period = int(out[0])
    for line in out[1:]:
        p = line.split()
        if len(p) >= 3:
            a = int(p[1])
            if 0 < a < 2**62:
                present.add(a)
    time.sleep(1.0)
ts = sorted(present)
d = [(b - a) / 1e6 for a, b in zip(ts, ts[1:]) if (b - a) < 1e9]
if not d:
    print("kare yok"); sys.exit(1)
vs = period / 1e6
print("ekran periyodu %.2f ms (%.1f Hz), kare sayısı %d, süre %.1f s" % (vs, 1000 / vs, len(d), sum(d) / 1000))
print("ortalama %.1f FPS" % (1000 * len(d) / sum(d)))
hist = collections.Counter(round(x / vs) for x in d)
for k in sorted(hist):
    print("  %d vsync (%.1f ms): %d kare (%%%.1f)" % (k, k * vs, hist[k], 100 * hist[k] / len(d)))
d2 = sorted(d)
print("medyan %.1f ms, %%95 %.1f ms, %%99 %.1f ms, en uzun %.1f ms" % (d2[len(d2)//2], d2[int(len(d2)*.95)], d2[int(len(d2)*.99)], d2[-1]))
# ardışık farklı aralık oranı (titreme göstergesi)
alt = sum(1 for a, b in zip(d, d[1:]) if abs(a - b) > vs * 0.5)
print("ardışık kare süresi değişimi: %%%.1f (yüksek = titrek akış)" % (100 * alt / max(1, len(d) - 1)))
