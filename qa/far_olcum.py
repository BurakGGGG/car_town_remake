#!/usr/bin/env python3
"""FAR OKUNURLUĞU özeti — qa/far_olcum.gd'nin çektiği normal + maske çiftlerini karşılaştırır.

Maskedeki macenta pikseller lamba, lambanın çevresindeki (maskede siyah ama araca ait) pikseller
kaporta kabul edilir. Ölçüt, ikisinin ortalama parlaklık FARKIDIR — işaretsiz, çünkü koyu araçta
lamba parlak, açık araçta koyu olarak ayrışır; ikisi de okunurluktur.

DİKKAT: ölçü yalnızca FAR ROLÜNDEKİ parçaları görür, yani rolün SAFLIĞINI de ölçer. Düşük puan
iki şeyden gelebilir ve ikisi ayırt edilmelidir:
  • lamba gerçekten kaportadan ayrışmıyor  → düzeltilmeli
  • rolde lamba olmayan parça var (ince krom şerit, ızgara çerçevesi) ya da lambanın çoğu
    dokuya pişmiş, role girmemiş  → görüntü sorunsuz olabilir
Ölçüldü: `tofas_sahin` 0,035 (rolünde ön yüzü boydan boya kaplayan krom şeritler var, 21.704
lamba pikselinin çoğu onlar) ve `seat_leon` 0,048 (rolde tek parça) düşük çıkıyor ama
render'ları temiz. Bu yüzden karar her zaman `ct_shots/far/<araç>.png` ile birlikte verilir.

Kullanım: python3 qa/far_olcum.py [dizin]   (varsayılan ct_shots/far)
"""
import os, sys, glob
from PIL import Image

DIR = sys.argv[1] if len(sys.argv) > 1 else "/home/burak/Projects/ct_shots/far"
HALO = 10          # lamba çevresinde kaç piksellik kaporta halkası ölçülsün
ZAYIF = 0.06       # bu farkın altında lamba kaportadan ayrışmıyor sayılır


def lum(p):
    return (0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]) / 255.0


def main():
    rows = []
    for mask_path in sorted(glob.glob(os.path.join(DIR, "*_maske.png"))):
        car = os.path.basename(mask_path)[: -len("_maske.png")]
        shot_path = os.path.join(DIR, car + ".png")
        if not os.path.exists(shot_path):
            continue
        mask = Image.open(mask_path).convert("RGB")
        shot = Image.open(shot_path).convert("RGB")
        mp, sp = mask.load(), shot.load()
        w, h = mask.size
        lamp, car_px = [], []
        lamp_xy = []
        for y in range(h):
            for x in range(w):
                r, g, b = mp[x, y]
                if r > 150 and b > 150 and g < 90:
                    lamp.append(lum(sp[x, y]))
                    lamp_xy.append((x, y))
        if not lamp:
            rows.append((car, None, None, None, 0))
            continue
        # lambaların çevresindeki halka: maskede SİYAH ama araç gövdesi (arka plan da siyah
        # olduğu için gövdeyi normal çekimdeki parlaklıktan ayırt edemeyiz; bu yüzden halkayı
        # lambaya yakın tutup arka planı parlaklık eşiğiyle eliyoruz)
        lamp_set = set(lamp_xy)
        ring = set()
        for (x, y) in lamp_xy:
            for dy in range(-HALO, HALO + 1):
                for dx in range(-HALO, HALO + 1):
                    p = (x + dx, y + dy)
                    if 0 <= p[0] < w and 0 <= p[1] < h and p not in lamp_set:
                        ring.add(p)
        for (x, y) in ring:
            r, g, b = mp[x, y]
            if r > 150 and b > 150 and g < 90:
                continue
            l = lum(sp[x, y])
            if l > 0.02:          # saf siyah = arka plan
                car_px.append(l)
        if not car_px:
            rows.append((car, None, None, None, 0))
            continue
        a = sum(lamp) / len(lamp)
        b2 = sum(car_px) / len(car_px)
        rows.append((car, a, b2, abs(a - b2), len(lamp)))

    print("%-22s %8s %8s %9s %9s  %s" % ("araç", "lamba", "kaporta", "|fark|", "lamba px", "durum"))
    weak = 0
    for car, a, b, d, px in sorted(rows, key=lambda r: (r[3] is None, r[3])):
        if d is None:
            print("%-22s %8s %8s %9s %9s  far rolü yok" % (car, "-", "-", "-", "-"))
            continue
        note = "okunur"
        if d < ZAYIF:
            note = "ZAYIF — rolü ve render'ı kontrol et"
            weak += 1
        print("%-22s %8.3f %8.3f %9.3f %9d  %s" % (car, a, b, d, px, note))
    print("--- zayıf: %d ---" % weak)


if __name__ == "__main__":
    main()
