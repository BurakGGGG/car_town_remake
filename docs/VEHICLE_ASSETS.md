# ARAÇ ASSET PIPELINE — ikinci parti (9 yeni araç, 2026-09-27)

Katalog **7 → 16 araç**. Bu belge yeni araçların zincirden nasıl geçtiğini ve neyin ölçüldüğünü
anlatır. Zincir ilk partiyle aynıdır:

```
SOURCE GLB → optimize_car.gd → optimized GLB (+albedo) → sarmalayıcı .tscn
   → CarPartMap (roller) → make_paint_mask.gd → cars.json → garaj / showroom / trafik / drag
```

## 1. Bulunan dosyalar

`assets/cars/source/` taranınca 16 GLB çıktı; 7'si zaten entegre (biri `renault_r12.glb` →
`renault_toros`), **9'u yeni**. Hepsi ilk partiyle AYNI yapıda: tek materyal, tek 4096² JPEG
albedo, 44-80 parça mesh, POS/NRM/UV (tanjant, skin, animasyon yok), uzunluk 1,0'e normalize.

| Araç | Kaynak MB | Parça | Vertex | Üçgen | Doku |
|---|---|---|---|---|---|
| audi_a3 | 18,0 | 80 | 373.987 | 470.855 | 4096² |
| bmw_e60 | 19,2 | 53 | 385.924 | 493.726 | 4096² |
| ford_focus_3 | 18,5 | 57 | 365.222 | 475.760 | 4096² |
| honda_civic_vtec2 | 18,5 | 44 | 354.515 | 490.092 | 4096² |
| hyundai_accent_blue | 18,7 | 53 | 375.022 | 499.164 | 4096² |
| seat_leon | 19,4 | 46 | 391.414 | 497.542 | 4096² |
| skoda_kamiq | 18,8 | 54 | 377.537 | 491.058 | 4096² |
| volvo_s60 | 18,6 | 44 | 378.555 | 478.916 | 4096² |
| vw_golf_7 | 18,3 | 46 | 376.635 | 484.817 | 4096² |

## 2. Rol sınıflandırıcı (yeni)

İlk 7 aracın rolleri ELLE eşlenmişti (parça parça render). 9 araç × ~55 parça için bu yöntem
uygun değil; bunun yerine **ölçülebilir bir sınıflandırıcı** yazıldı:

- Her parça için: normalize konum (yükseklik / ön-arka / yanallık), p05-p95 boyut (çöp üçgenler
  AABB'yi şişirdiği için yüzdelik kullanılır), üçgen sayısı, yuvarlaklık ve **UV'den okunan doku
  rengi** (parlaklık, doygunluk, kırmızılık).
- Eşikler aracın KENDİ parlaklık dağılımından türetilir (siyah araçta "koyu" başka şeydir).
- Kırmızı araçta arka panelin "stop lambası" sanılmaması için lamba kuralları aracın baskın
  gövde rengiyle karşılaştırılır.

**Doğrulama:** sınıflandırıcı, elle doğrulanmış 7 aracın 421 parçasına uygulandı.

| Grup | İsabet |
|---|---|
| Teker (wheels/tires/rims) | %100 |
| Stop lambası | %100 |
| Ayna | %100 |
| Far | %95 |
| Izgara | %94 |
| Cam | %67 (yanlış-pozitif düşük tutuldu) |
| Gövde | %83 |
| **İşlevsel grup toplamı** | **%75** |

Kalan hata gövde↔trim ayrımındadır ve **boya maskesi aracı bunu texel bazında zaten düzeltir**
(boya renginde olan trim parçası boyaya yükseltilir, boya olmayan gövde texel'i elenir). Cam
kuralı bilerek muhafazakârdır: yanlışlıkla "cam" denen gövde parçası maskede SERT ENGELdir.

## 3. Optimizasyon (mevcut pipeline, araç başına aynı ayar)

`--ratio 0.125 --min-tris 300 --map <tscn> --tex-size 2048 --quality 0.85`

| Araç | MB (kaynak→çıkış) | Üçgen (kaynak→çıkış) | Doku |
|---|---|---|---|
| audi_a3 | 18,0 → 7,4 | 470.855 → 116.173 | 2048² |
| bmw_e60 | 19,2 → 6,2 | 493.726 → 92.180 | 2048² |
| ford_focus | 18,5 → 7,5 | 475.760 → 118.952 | 2048² |
| honda_civic | 18,5 → 6,9 | 490.092 → 122.482 | 2048² |
| hyundai_accent_blue | 18,7 → 7,3 | 499.164 → 125.096 | 2048² |
| seat_leon | 19,4 → 7,9 | 497.542 → 127.834 | 2048² |
| skoda_kamiq | 18,8 → 7,2 | 491.058 → 114.092 | 2048² |
| volvo_s60 | 18,6 → 6,8 | 478.916 → 105.676 | 2048² |
| vw_golf_7 | 18,3 → 6,8 | 484.817 → 110.783 | 2048² |
| **Toplam** | **168,0 → 64,0 MB** | **4,38M → 1,03M** | |

Mevcut 7 araç 4,8-7,6 MB / 113-130K üçgen aralığındaydı; yeni parti aynı bantta.

## 4. Boya

`make_paint_mask.gd` her araç için 1024² maske üretti ve fabrika rengini ÖLÇTÜ; `default_paint`
(CarPartMap) ve `default_color` (cars.json) bu ölçümle eşitlendi (araç artık "← GÜNCELLE"
uyarısı vermiyor).

Boyanın gerçekten çalıştığı **görsel olarak ölçüldü**: her araç fabrika renginde ve #1A43B8 mavide
render edilip değişen piksel oranı sayıldı.

| Araç | Maske beyaz % | Renk değiştiren piksel % |
|---|---|---|
| audi_a3 | 11,6 | 48,8 |
| bmw_e60 | 19,5 | 70,4 |
| ford_focus | 16,4 | 56,3 |
| honda_civic | 22,5 | 63,2 |
| hyundai_accent_blue | 20,0 | 61,7 |
| seat_leon | 12,5 | 65,0 |
| skoda_kamiq | 16,8 | 60,5 |
| volvo_s60 | 13,9 | 52,1 |
| vw_golf_7 | 14,2 | 65,9 |
| *referans: hyundai_getz* | 20,3 | 65,7 |
| *referans: tofas_sahin* | 18,0 | 39,7 |

Yeni araçlar mevcutların bandında (Şahin %39,7 ile en düşük referans). Cam, lastik, jant, far,
stop ve krom boya ALMIYOR (rol render'ları ve mavi testte doğrulandı). Bazı araçlarda tavan
cam mesh'ine kaynadığı için boyasız kalıyor — kontrast tavan gibi duruyor, hata değil.

## 5. Sarmalayıcı sahneler

`tools/make_car_scene.gd` (yeni) optimize GLB'yi miras alan 4 satırlık `.tscn`'i UID'leriyle
birlikte yazar. Not: başsız Godot'ta `PackedScene.pack()` bir GLB örneğini gömerek kaydediyor
(8 MB'lık sahne dosyası çıkıyor), bu yüzden dosya doğrudan metin olarak üretiliyor.

## 6. Katalog (PROVISIONAL denge)

Fiyat/sınıf/seviye/rütbe ve yarış statları mevcut merdivene oturtuldu ama **geçicidir** —
araç ilerlemesi fazında yeniden dengelenecek.

| id | sınıf | fiyat | yıl | seviye/rütbe | hız/ivme/tepki/tutuş |
|---|---|---|---|---|---|
| hyundai_accent_blue | C | 38.000 | 2013 | 8 / 2 | 120 / 68 / 62 / 64 |
| ford_focus | C | 45.000 | 2013 | 10 / 2 | 125 / 72 / 66 / 68 |
| skoda_kamiq | B | 55.000 | 2020 | 12 / 3 | 128 / 74 / 70 / 74 |
| vw_golf_7 | B | 65.000 | 2015 | 15 / 4 | 134 / 80 / 74 / 76 |
| seat_leon | B | 68.000 | 2016 | 16 / 4 | 138 / 82 / 74 / 78 |
| honda_civic | B | 72.000 | 2010 | 18 / 4 | 140 / 83 / 76 / 78 |
| audi_a3 | A | 95.000 | 2014 | 20 / 5 | 148 / 86 / 80 / 82 |
| volvo_s60 | A | 105.000 | 2016 | 22 / 5 | 150 / 85 / 78 / 84 |
| bmw_e60 | A | 120.000 | 2007 | 25 / 6 | 155 / 88 / 80 / 82 |

`world_node` boştur (yeni araçlar `Main.tscn`'de fiziksel olarak durmuyor; katalog bunu zaten
destekliyor). Hepsi `traffic: true`.

## 7. Ölçülen performans

| Durum | FPS ort/min | Çizim | VRAM |
|---|---|---|---|
| Dünya (7 araçlık katalog, önce) | 957 / 647 | 154 | 87,8 MB |
| Dünya (16 araçlık katalog, sonra) | 1.207 / 6 | 160 | **87,3 MB** |
| Garaj (1 araç sahibi) | 138 / 7 | 1.125 | 274,7 MB |
| Garaj (16 araç sahibi) | 139 / 6 | 1.125 | 273,3 MB |
| Showroom | 179 / 7 | 500 | 246,6 MB |
| Drag pisti | 289 / 6 | 227 | 282,1 MB* |

- **Dünya VRAM'i büyümedi**: trafik havuzu tembel/threaded yükleme yapıyor, 16 aday arasından
  aynı anda yalnızca 4 model bellekte.
- **Garaj/showroom maliyeti araç sayısından BAĞIMSIZ**: 1 araç sahibiyken de 16 araç sahibiyken
  de 1.125 çizim / ~274 MB. Yani bu maliyet yeni araçlardan gelmiyor, ekranın kendisinden geliyor
  (MEVCUT durum). <120 MB hedefi bu iki ekranda zaten aşılıyordu; ayrı bir optimizasyon işi.
- *Drag ölçümü aynı süreçte garaj ve showroom açıldıktan sonra alındı (VRAM birikiyor); tek
  başına açıldığında drag pisti 105,9 MB.

## 8. Testler

Yeni `vehicle_asset_test.gd` (328 kontrol): her araç için sahne var/yükleniyor, optimize GLB var,
CarPartMap kaydı var, haritadaki BÜTÜN parça indeksleri sahnede mevcut, dört teker grubu var ve
parçaları sahnede, CarRig kuruluyor ve teker döndürülebiliyor, boya maskesi var, `default_paint`
= `default_color`, yarış statları ve ilerleme alanları geçerli, id/sahne/dünya düğümü benzersiz.

Tüm paket: **race 49 · ui 47 · progression 32 · save 27 · edge 34 · quest 28 · paint 28 ·
cloud 50 · vehicle_asset 328 = 623 kontrol, 0 FAIL.**

`edge_test`'in "içerik tavanı 8. rütbe" iddiası güncellendi: 16 araçla tavan 10. rütbeye çıktı
(araç değeri 330K → 958K). Kural artık "en az 8. rütbeye ulaşmalı"; kesin değer araç ilerlemesi
fazında yeniden konacak.
