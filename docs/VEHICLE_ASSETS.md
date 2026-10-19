# ARAÇ ASSET PIPELINE — ikinci parti (9 yeni araç, 2026-09-27)

Katalog **7 → 16 araç**. Bu belge yeni araçların zincirden nasıl geçtiğini ve neyin ölçüldüğünü
anlatır. Zincir ilk partiyle aynıdır:

```
SOURCE GLB → optimize_car.gd → optimized GLB (+albedo) → sarmalayıcı .tscn
   → CarPartMap (roller) → make_paint_mask.gd → cars.json → garaj / showroom / trafik / drag
```

> 2026-10-19'dan beri optimize GLB'ye `strip_tangents.py`'den sonra `tools/resimplify_car.py` de uygulanır
> (tekerler hariç, hata sınırlı ikinci sadeleştirme; araç mesh'i −%18). Yeni araçta: `wheel_parts.gd` →
> `resimplify_car.py` → `--import` → küçük resimler. Ayrıntı: `docs/MESH_BUTCESI.md` "Paket boyutu 3".
>
> 2026-10-18'den beri araç adları kurgusaldır (gerçek marka / model adı yok): yeni araç eklerken
> `docs/ARAC_ADLARI.md` kurallarına göre ad seç. Aşağıdaki gerçek adlar o tarihten önceki kayıttır.

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

---

# Üçüncü parti (6 araç, 2026-10-04) — katalog 16 → 22

alfa_romeo_159, audi_rs6, ferrari_488_pista, lambo_huracan, mercedes_cls, porsche_gt3. Hepsi aynı Tripo
yapısında (tek materyal, 4096² JPEG, 46–82 parça, ~470K üçgen, uzunluk 1,0).

**Sınıflandırıcı artık depoda:** ikinci partideki betikler geçici klasörde kalmış ve kaybolmuştu; oturum
kaydından geri kuruldu → `tools/part_features.gd` (özellik CSV'si) + `tools/classify_roles.py`
(doğrulama / `--emit` ile CarPartMap kaydı). Geri kurulan sürüm eski 7 araçta aynı sonucu verdi
(işlevsel grup %75,5).

```
godot-4 --headless --path . -s res://tools/part_features.gd -- assets/cars/source/<glb>.glb > x.csv
python3 tools/classify_roles.py x.csv --emit <glb_adı>=<tscn_adı>
```

**Elle düzeltilenler** (parça vurgu render'ıyla teşhis): Ferrari'de arka-sağ teker difüzörle tek mesh'e
kaynamıştı → `extract` (yeni parça 59); 9 jant (gövde sanılmış), 18 çamurluk içi ve 41/45 ön hava girişi
teker grubundan çıktı. Lambo'da 39/58 ön tampon, 46/51/61 hava girişi "jant" sanılmıştı. Mercedes'te
8 kapı paneli "ayna", 52 ön çamurluk "jant" sanılmıştı. RS6 19 ve Lambo 33 "far" sanılan tampon parçası.

| Araç | MB (tanjantsız) | Üçgen | Boya maskesi % | Fabrika rengi |
|---|---|---|---|---|
| alfa_romeo_159 | 5,5 | 124.272 | 19,0 | #D8D5D7 |
| audi_rs6 | 5,8 | 125.934 | 16,6 | #8F9599 |
| ferrari_488_pista | 5,6 | 116.946 | 11,9 | #C40003 |
| lambo_huracan | 5,5 | 111.524 | 11,7 | #DBD8DB |
| mercedes_cls | 5,0 | 110.850 | 18,9 | #B7B5B7 |
| porsche_gt3 | 4,6 | 89.316 | 17,2 | #2F4C29 |

Bilinen kusur: Ferrari maviye boyanınca panel kenarlarında ince kırmızı çizgiler kalıyor (dokudaki koyu
kırmızı gölgeler boya sayılmıyor). Maske eşikleri tüm araçları etkilediği için değiştirilmedi.

**Kasa ve sınıf (kullanıcı kararı, 2026-10-04):** yeni **SÜPER KASA** (200 gem, seviye 28): RS6 common ·
GT3 rare · Huracán epic · 488 Pista legendary. Alfa 159 → SPOR kasası (rare), CLS → PRESTİJ kasası (epic;
E60'ın oranı %2,78 → %2,52). Yeni yarış sınıfı **S** (RS6, GT3, Huracán, 488; galibiyet 2.000 ₺ / 100 XP,
AI beceri payı 0,95); Alfa ve CLS A sınıfında. Trafikte yalnızca Alfa ve CLS dolaşır. Yeni setler İTALYAN ve
SÜPER SPOR; CLS PREMIUM setine girdi. KOLEKSİYONCU başarımı 22 araçta biter. Fiyat / seviye kilidi / yarış
statları hâlâ GEÇİCİ. `tools/economy/crate_sim.py` görevler sisteminden beri eski sabitleri arıyor
(TASK_GEMS) ve çalışmıyor — ayrı iş. `model_scale` = gerçek uzunluk / 4,39, boyut
laboratuvarında (tools/size_lab.tscn) ayarlanacak. `make_size_lab.gd` artık sahnenin UID'sini koruyor ve
zemini araç sayısına göre büyütüyor.

---

# Tekerlek dönüşü düzeltmesi (2026-10-04, 22 araç)

Kullanıcı E60 ve Accent'te dönerken teker hatası gördü; 22 aracın hepsi tek tek ölçüldü.

**Teşhis aracı:** `tools/wheel_blur.gd` her tekeri 12 dönüş açısında render edip ORTALAR (uzun pozlama).
Kusursuz teker: lastik çizgisi keskin, jant düzgün disk. Duran parça keskin kalır, gövdeden dönen parça
bulanık leke / hale yapar. Parça teşhisi: `tools/part_highlight.gd`.

**Bulunan üç kusur ve çözüm:**
1. *Dönmeyen jant parçaları* (E60 arka jantın iki kolu, Accent kol dilimleri, Getz/Era/Şahin/RS6/GT3 göbek
   ve halka parçaları): Tripo jantı birkaç parçaya bölüyor, gruba girmeyen parça yerinde kalıyordu; CarRig'in
   eski "eş merkez" elemesi tek kol dilimini de atıyordu. → `tools/wheel_fit.gd` teker silindirinin içindeki
   her parçayı gruba alır; dönme ekseni lastiğin geometrisinden ölçülüp `wheel_axes` olarak haritaya yazılır,
   CarRig bu gruplarda eleme yapmaz.
2. *Dönen fren kaliperleri* (Golf, Volvo, Alfa, RS6, GT3, Huracán, 488): ayrı parça olan fren grupları
   (disk + kaliper) teker grubundan çıkarıldı — disk dönel simetrik, sabit dursa da aynı görünür. Lastiğe
   KAYNAMIŞ kaliperler (Golf sağ-ön, Volvo, Huracán, 488) `extract`'in yeni renk koşuluyla ("hue", "hue_tol",
   "min_sat") optimize adımında ayrı, sabit parçaya alındı.
3. *Lastiğe kaynamış gövde / çöp üçgen* (Volvo sağ-arka, E60 sol-ön, Alfa sağ-ön, GT3 sağ-ön, Huracán
   sağ-arka, 488 sağ-ön / sol-arka): silindir `extract`'i ile lastik ayrıldı, dışarıda kalan sabit kaldı.

GT3 sağ-ön ve 488 sağ-arka ekseni lastikten yanlış ölçülüyordu (lastiğin çamurluk içindeki üst kısmı
modelde yok → merkez aşağı kayıyor); karşı tekerin ekseni aynalandı. Sol-sağ eksen farkı artık her araçta
< 3 mm. Kalan küçük kusur: GT3 ön lastiklerin üstü eksik modellendiği için dönerken altta hafif iz kalıyor.

---

# Boya maskesi ve lastik cilası (2026-10-05)

**Ferrari maviye boyanınca kırmızı kalan yerler — üç ayrı sebep:**
1. *Rol hatası:* Arka kanat (23), arka tampon (25) ve kanat altı panel (30) "stop lambası"; armalı sol ön
   çamurluk (18) "siyah trim"; lastik ayrıldıktan sonra kalan çamurluk kenarları (3, 7) "siyah trim"
   sayılıyordu. Hepsi gövdeye alındı. Fren diski bilerek lastikte kalır: döner, boyanmaz.
2. *Temizlik adımı ince şeritleri siliyordu (bütün araçları etkiliyordu):* Maskeyi pürüzsüzleştiren
   morfolojik kapamada genişletme UV adasının dışına taşamıyordu; daraltma adımı da 1–4 texel kalınlıktaki
   panel kenarı şeritlerini tamamen yiyordu. Kaput çizgilerindeki kırmızı buydu. Artık kapama ve gürültü
   temizliği yalnızca EKLER. Tamamen boyanan parçaların texel'leri korunur. Boyanan alan araç başına
   %3–13 arttı (Ferrari %11,7 → %21,4). Görsel karşılaştırmada cama, lambaya ya da trime taşma yok.
3. *Yumuşak engel:* Teker / trim parçasının boya rengindeki texel'i, gövdeyle paylaşıldığında artık engel
   sayılmaz (yalnızca doygun boyalarda). Cam, far ve stop katı engel olarak kalır.

Ayrıca doygun boyalarda kıvrımdaki koyu gölge (aynı ton, doygun) 5 oktava kadar boya sayılır.

**Fluence:** Sol arka çamurluk + tavan çıtası (12) ve sağ tavan çıtası (28) "cam" sanılmıştı, gövdeye alındı.

**GT3 sağ-ön lastik:** Lastiğin üstündeki ~80°'lik yay kaynakta hiç yok; teker dönünce boşluk alta
geliyordu. Bunun için `optimize_car.gd` "fill_arc" adımı eklendi: eksik yay, karşı yayın 180° döndürülmüş
kopyasıyla doldurulur. 22 aracın 88 lastiği açısal kapsama için tarandı; gerçek boşluk yalnızca buradaydı.

**Araçlar:**
- `tools/paint_preview.gd`: aracı bir renge boyayıp dört açıdan çizer.
- `tools/mask_audit.gd`: boya renginde olup maskede boyanmayan üçgenleri parça ve rol bazında sayar.
- `MASK_DEBUG=1 make_paint_mask.gd`: parça başına texel dağılımını döker.

---

# Dördüncü parti (2026-10-11) — 4 model yenilendi, katalog 22 → 26

**Yenilenen kaynaklar** (aynı id / sahne / kayıt; eski GLB'nin üstüne yazıldı): BMW E46 (artık beyaz,
#CDD3DA), Renault Fluence (#CAD2DC), Hyundai Getz (#E50107), VW Passat B5.5 (#CAD0D7). Parça numaraları
değiştiği için dört aracın CarPartMap kaydı sınıflandırıcıdan BAŞTAN çıkarıldı (eski elle düzeltmeler geçersiz).
**Yeni araçlar:** Chevrolet Camaro (5. nesil, sarı), Mercedes S400 (W222, siyah), Opel Corsa (C, 3 kapı),
Tesla Model Y. Hepsi aynı Tripo yapısında (tek materyal, 4096² JPEG, 44–76 parça, ~480K üçgen).

| Araç | GLB MB (tanjantsız) | Üçgen | Boya maskesi % | Fabrika rengi |
|---|---|---|---|---|
| bmw_e46 | 3,8 | 118.766 | 38,5 | #CDD3DA |
| renault_fluence | 5,4 | 115.464 | 30,4 | #CAD2DC |
| hyundai_getz | 5,4 | 118.602 | 19,8 (2048²) | #E50107 |
| vw_passat_b55 | 5,0 | 111.550 | 20,0 | #CAD0D7 |
| chevrolet_camaro | 5,7 | 123.170 | 23,9 | #F7D122 |
| mercedes_s400 | 5,5 | 123.038 | 21,9 | #3E4243 |
| opel_corsa | 5,6 | 130.602 | 24,3 | #E6E4E8 |
| tesla_model_y | 4,8 | 117.926 | 37,6 | #DFE4E9 |

**Elle düzeltilenler** (vurgu render'ı + `mask_audit` + yeni bölge yoklaması ile):
- Tesla 21/22 ön çamurluk kaplaması "teker" sanılmıştı → teker ekseni 3 cm yukarı kayıyor, ön tekerler
  yalpalıyordu. black_trim'e alındı, ön gruplar gerçek lastikle (19, 2) yeniden ölçüldü.
- "Jant/teker" sanılan ama hiçbir teker grubunda olmayan kaporta parçaları: BMW 38 (sol arka kapı alt paneli,
  maviye boyayınca gümüş kalıyordu), Camaro 17/19/22. Kural: `wheels/tires/rims` rolündeki parça bir teker
  grubunda değilse ya kaliperdir (bilinçli) ya da yanlış sınıflandırılmış kaportadır — bak.
- Boyanın atlandığı gövde parçaları: S400 0/1/3 (iki yan gövde, "siyah trim"), Camaro 14/16/23/25/26 (arka
  panel, tampon, spoyler — "stop"), Getz 12 (spoyler — "stop"), Fluence 2 ve Passat 0 (marşpiyel / çamurluk
  kenarı — "siyah trim").
- **Yeni harita anahtarı `paint_whole`** (tools/make_paint_mask.gd): Getz tavanı (19) dokuda açık pembe
  parlama olarak fırınlanmış, texel anahtarı %3 tutuyordu; parça texel anahtarı atlanıp tamamen boyanır.
  Bedeli: boyanınca tavan parlak görünür (aynı parlama fabrika renginde de var).

Bilinen küçük kusurlar: Getz yan bant şeridinde ve C direğinde birkaç kırmızı benek; Camaro sarı fren
kaliperleri boyanmaz (doğru); Tesla / S400 / BMW cam tavanları cam materyaliyle mavimsi parlar (mevcut davranış).

**Katalog (GEÇİCİ denge):** Corsa C · common · 26.000 ₺ · sv.5 / rütbe 1 (ŞEHİR kasası); Model Y A · rare ·
110.000 · sv.22 / r5 (PRESTİJ); Camaro A · epic · 140.000 · sv.24 / r6 (SPOR); S400 A · epic · 170.000 · sv.27 /
r6 (PRESTİJ). Dördü de trafikte. Yeni set **AMERİKAN** (Camaro + Model Y), S400 → PREMIUM. PRESTİJ kasasında
E60 oranı %2,52 → %1,87; ŞEHİR'de Getz %33,9 → %25,3. KOLEKSİYONCU kademeleri 3/6/10/18/26. `model_scale`
kullanıcının boyut laboratuvarında elle ayarladığı değer (Corsa 0,82 · Model Y 1,00 · Camaro 1,02 · S400 1,20;
aynı turda E46 1,03 · Getz 0,85 · Fluence 1,03 · Passat 1,08 · Şahin 0,97).

Testler: tam paket 0 FAIL (vehicle_asset 528, vehicle_scale 166, crate 91, ui 60 …). ui_test (depo dışı)
kasa oranı beklentileri güncellendi.

**Uzakta kirli görünüm — doku kenar dolgusu (2026-10-11):** Kullanıcı BMW ve Getz'in yakından iyi, uzaktan
çok kötü göründüğünü bildirdi. Sebep: yeni kaynak atlaslarında UV adalarının arası SAF SİYAH (eski kaynaklarda
komşu renkle doluydu). Trafik araçları düşük LOD kademesinde çiziliyor (`LOD_BIAS_NPC`); sadeleşmiş üçgenler ada
sınırını aşıp bu siyahtan örnekliyor, mipmap ve GPU sıkıştırması da siyahı kenara karıştırıyor → beyaz
kaportada siyah lekeler ve koyu dikişler. Çözüm `optimize_car.gd` `_pad_islands`: UV kapsamasında OLMAYAN
texel'ler en yakın adanın rengiyle doldurulur (kullanılan texel'lere dokunulmaz; Getz'te fark görüntüsüyle
doğrulandı). Varsayılan açık, `--no-pad` ile kapanır; araç başına ~45 sn. 8 araç yeniden üretildi; zorlanmış
düşük LOD'da (lod_bias 0,05) BMW'deki siyah lekeler kayboldu.

---

# Beşinci parti — KLASİK / RESTORASYON araçları (2026-10-11), katalog 26 → 50

Hurdalık (docs/HURDALIK_ARASTIRMA.md) için 24 klasik: 12 temel, 8 usta-klasik, 4 usta-yarış (Delta Integrale,
Quattro S1, RS200, Evo VI henüz yok). Kaynaklar `eksik_dosyalar/klasik/` (dosya adı ≠ id; eşleme
`tools/junkyard/klasik_catalog.py` CARS tablosundaki id'lerle), aynı Tripo yapısı (tek materyal, 4096² JPEG,
41–91 parça, ~480K üçgen) → optimize sonrası 82–134K üçgen, 6,7–7,8 MB.

**Katalog:** `tools/junkyard/klasik_catalog.py` üretir (gerçek fabrika verisi; `--colors` maske aracının
renkleri, `--classes` 300 m sınıfları). Kullanıcı kararları: trafikte yok, kasada yok, koleksiyonda ayrı bölüm
(kasa koleksiyonu 26), BOYANAMAZ (`VehicleOwnership.is_paintable`), satış temel 10.000 / usta 25.000 ₺
(fiyat 25.000 / 62.500), yarış rakibi olmaz. Sınıf 300 m kuralıyla, boşluklar ortadan bölündü
(A < 11,0 ≤ B < 11,8 ≤ C < 12,9 ≤ D): 9 A, 3 B, 12 D.

**Elle düzeltilenler:**
- Vosvos 10/4/5/7 çamurluklar "teker" sanılıp teker grubunun BAŞINA girmişti (eksen çamurluktan ölçüldü,
  çamurluk dönüyordu) → gövde. Kural: grubun ilk parçası lastik olmalı (wheel_fit ekseni ondan ölçer).
- Miura sağ-arka: grubun başında çamurluk kemeri (31) → gövde; lastik 5.
- Charger sağ-arka lastik sol alt gövdeye (1) kaynamış → `extract` (sol-arkanın aynası) → parça 66.
- Bel Air (dört teker, 110–130°), T1 arka (60°), Murat 124 arka (20°): lastiğin tepesi kaynakta yok →
  `fill_arc`. Belirti: wheel_blur'da bulanık dış çizgi; teşhis: lastiğin y uzanımı z uzanımından kısa.
  Yoklama betiği `~/Projects/ct_shots/arcprobe.gd` (10°'lik dilim kapsaması).
- Jaguar sağ-ön ekseni yanlış ölçüldü (yarıçap 0,067) → sol-ön aynalandı.
- Sınıflandırıcı çıktısında özet satırı bir kaydın `},` satırına yapışabiliyor (stdout/stderr karışması):
  bloklar haritaya eklenmeden önce `\t},#` ayrılmalı, yoksa sonraki kaydın sınırı kayar.

**Boya maskesi:** klasiklerde cam çoğu yerde kaportayla aynı parçada; Charger / Stratos / Land Rover /
Mustang / Murat 131 / Fiat 500'de bulunan "fabrika rengi" yanlış ton. Araçlar boyanamadığı için oyunda
görünmez; pas efektinde maske ayrıca ele alınacak.

**Wayland:** wheel_blur / paint_preview / pencereli testler örtülü pencerede takılıyordu →
`--display-driver x11` (run_tests.sh pencereli paketlere kendisi ekler).

Testler (depo dışı paketlerde sınırlar gerçek klasiklere göre genişletildi: son hız ≥ 90, uzunluk ≥ 2,8 m,
genişlik ≥ 1,3 m, aks > 1,8 m; ui_test koleksiyon toplamı = kasa koleksiyonu): tam paket 0 FAIL.

---

# Altıncı parti (2026-10-12), katalog 50 → 55

**Yarış dalının son dördü** (restorasyon, usta-yarış): Lancia Delta Integrale '92, Audi Sport Quattro S1
'85, Ford RS200 '86, Mitsubishi Lancer Evo VI '99 (kaynak `eksik_dosyalar/klasik/`: lancia_integrale,
audi_quattro, ford_rs200, 99_lancer). Katalog `tools/junkyard/klasik_catalog.py`; Stratos gibi YOL
(homologasyon) sürümlerinin verisi — Group B ralli sürümleri (~470–550 hp) en hızlı normal araçları da
geçerdi. Dördü de 300 m'de A sınıfı (8,95–10,18 sn).

**Normal araç:** Volkswagen Beetle 2.0 TSI (2016, A5) — `vw_beetle` (klasik `vw_beetle_1967` ile karışmasın).
Kullanıcı kararı: AİLE KASASI, epic, 80.000 ₺, seviye 10, rütbe 2; VW GRUBU setinde. 300 m 10,59 sn → A.

**Elle düzeltilenler:**
- Quattro: 11/12 kutu çamurluk genişletmeleri (boyları tekerin iki katı) ve 27/31 arka yan parçaları
  "teker" sanılmıştı → gövde; sol-arka ekseni yarıçap 0,134 ölçülmüştü (27'den). Düzeltmeden sonra
  wheel_fit sol-arka jantı (3) eksenden 0,003 kaçık diye dışarıda bıraktı (jant dönmüyordu, wheel_blur'da
  keskin) → elle gruba alındı.
- Beetle: sağ kapı (3) "teker" sanılmıştı → boyanmıyordu; 18/39 arka tampon alt köşeleri (gövde renginde)
  stop / siyah trim sanılmıştı → gövde. Cam contası boyunca birkaç piksellik fabrika sarısı kalır (cam
  dokusunun kenarı; maske camı bilerek boyamaz).
- Yeni boya maskelerinin `.import`'u mipmap'siz geliyordu → mevcut maskelerin ayarları kopyalandı
  (`mipmaps/generate=true`). Maske `.import`'u yoksa CarRig boyamayı sessizce kapatır.

---

# Yedinci parti (2026-10-16), katalog 55 → 59 — Togg ve polis araçları, tavan ışık sistemi

Kaynaklar `eksik_dosyalar/yeni/` (togg_t10x, togg_t10f, police_vito, bentley_police → id `police_bentley`); aynı
Tripo yapısı (tek materyal, 4096² JPEG, 52–83 parça, ~480K üçgen). Komut sırası altıncı partiyle aynı.

| Araç | GLB MB (tanjantsız) | Üçgen | Parça | Boya maskesi % | Fabrika rengi | 300 m | Sınıf |
|---|---|---|---|---|---|---|---|
| togg_t10x | 5,8 | 124.514 | 83 | 16,5 | #035060 | 11,10 sn | B |
| togg_t10f | 4,9 | 115.498 | 52 | 28,0 | #9D9FAE | 10,94 sn | A |
| police_vito | 5,6 | 123.773 | 57 | 7,4 | #E3E72F (sarı şerit) | 12,17 sn | C |
| police_bentley | 5,5 | 118.987 | 67 | 23,2 | #D7D9E7 | 8,20 sn | S |

Sınıflar 300 m kuralıyla (bantlar ayrık kalmalı): T10F 10,94 sn A'nın en yavaşı Celica'dan (10,96) hızlı → A.
Performans verisi: Togg'lar resmi V2 RWD Uzun Menzil (218 PS; T10X 7,8 sn / 185 km/sa, T10F 7,5 sn / 177 km/sa),
Bentley Continental GT W12 (635 PS, 3,7 sn, 333 km/sa), Vito 119 CDI 4MATIC (190 PS, son hız 199 km/sa ADAC; 0-100
için resmi değer YOK → 10,0 sn TAHMİN: aynı motorlu, daha hafif arkadan itişli V 250 d ~9,1 sn). İlk tahmin 9,5 sn
Vito'yu C'nin en hızlısı yapıyordu (11,95 sn) ve tam modifiyeyle B'yi atlayıp A'ya (10,925 < 10,958) çıkıyordu —
performance_mod_test'in "hiçbir araç iki sınıf atlamaz" kuralı. 10,0 sn ile 12,17 sn → tam modifiye 11,13 sn (B). Togg'lar `engine: "Elektrik"` → drag'de EV sesi, BATARYA/SOĞUTMA.

**Polis araçları boyanmaz** (`cars.json "paintable": false` → `VehicleOwnership.is_paintable`; trafik NPC'si de
fabrika renginde): boya maskesi Vito'da sarı kaplama şeridini "fabrika boyası" buldu, boyamak kaplamayı bozardı.

**Elle düzeltilenler:**
- T10X: camların hepsi (4 ön, 20 arka, 30/32/40/41 yan, 71/79 üçgen; 46 "ayna") "gövde" sanılmıştı — boyanınca
  tavan camında tırtıklı boya lekesi; 5 koyu tavan, 45 marşpiyel, 53/54/56/62 direkler → black_trim. 16 çamurluk
  iç kaplaması "jant" sanılıp sol-arka grubun başına geçmişti → eksen 2,8 cm yukarı; black_trim.
- T10F: 4 ön cam, 9 arka cam, 30/32/38 yan camlar "gövde" (ön camda boya lekeleri); 22 kaput ön paneli "far".
- Bentley: tekerler jantla tek parça → `wheels`; kırmızı kaliperler renk koşullu extract ile 63–66 (dönmez);
  +X arka eksen wheel_fit'te 4 mm kaçık (wheel_blur'da yalpa) → lastiğin dış çemberine en küçük kareler uydurması
  (`~/Projects/ct_shots/yeni5/circle_fit.gd`). 35 ön çamurluk menfezi "jant" → black_trim.
- Vito: ön ışık çubuğunun sağ yarısı sağ tavan rayına (7) kaynamış, ızgaradaki iki mavi flaşör gövdede (0) →
  `optimize_car.gd extract` artık KUTU bölgesi de alıyor (`box_min` / `box_max`) → 55, 56, 57.

## Polis tavan ışıkları

Yeni rol `police_lights` (CarPartMap; boya maskesinde kesin engel, optimizer'da detay rolü) + harita anahtarı
`beacons` (hale noktaları: araç uzayında konum, renk, yarı). `vehicles/police_lights.gd` (PoliceLights) CarRig
kurulurken oluşur — trafik, garaj, showroom, kasa ve drag aynı rig'i kullandığı için ışıklar her yerde çakar.

- **Lens** (`police_lights.gdshader`): görünüm aracın kendi dokusu; doygun ve parlak KIRMIZI / MAVİ texel ışır,
  renk dokudan (sarı / yeşil kaplama, koyu taban, krom ışımaz). Işıma ton küpüyle doygun tutulur.
- **Desen** (`police_beacon.gdshaderinc`): sol yarı iki kısa çakma, yarım döngü sonra sağ yarı (1,6 döngü/sn);
  araç başına rastgele faz. Yarı = ARAÇ UZAYINDA x işareti; parça kendi yerel uzayında çizildiği için
  `side_plane` parça dönüşümünün X satırıdır → lens parçaları parça birleştirmeye girmez.
- **Hale** (`police_beacon_halo.gdshader`): bütün haleler tek mesh, kameraya dönük toplamalı parlama; sönükken
  sıfır boy. Dinamik ışık (OmniLight) bilerek yok — GL Compatibility'de nesne başına ek geçiş.
- Kare başı betik yok (GPU TIME). Küçük resimde `PoliceLights.Mode.LIT` (iki yarı yanık, hale yok).
  Shader'lar WorldPrewarm'da ısıtılır. QA: `qa/police_lights_qa.gd` (oyun kamerasıyla kareler + çizim ölçümü).

**Katalog (GEÇİCİ):** T10X AİLE KASASI rare 85.000 ₺ sv.12/r3 · T10F PRESTİJ rare 100.000 ₺ sv.20/r5. Yeni set
TOGG; ikisi de trafikte. Kasa oranları: AİLE Passat %37,0 → %32,3; PRESTİJ E60 %1,87 → %1,57. `model_scale` ilk
tahmin (uzunluk / 4,39) — boyut laboratuvarında ayarlanacak.

**Polis araçları edinilemez (kullanıcı kararı 2026-10-16):** satılmaz, kasadan çıkmaz, koleksiyonda / sette / normal
trafikte / yarış rakibi havuzunda yoktur — `cars.json "obtainable": false` (CarCatalog SCHEMA, `CarCatalog.is_obtainable`;
`VehicleOwnership.collection_ids` ve `RaceManager.rival_pool` eler) + `traffic: false`. Yalnızca kovalamacada görünürler.

## Polis kovalamacası

Kullanıcı isteği: şehirde kovalamaca — ilki oyun açıldıktan 15 sn sonra, sonra 2 dakikada bir (önce 3–4 dk idi); şüpheli ve polis normal trafikten hızlı, polis şüpheliden
hızlı, aradaki mesafe kapanır ("harita dışında yakalamış gibi"), polis geçtikçe siren.

- `traffic/police_chase.gd` (PoliceChase, TrafficManager'ın kodla kurulan çocuğu): zamanlayıcı `first_delay` 15 sn, sonra `interval_min/max` 120 sn (bir önceki kovalamacanın bitişinden); bir ekran
  açıkken başlamaz (12 sn sonra yeniden dener). Rastgele boş şeritten (yarış şeridi hariç) ekran dışından şüpheli
  (şehir havuzundan rastgele NPC) girer, 1,9 birim/sn (trafik 0,55–0,9). Polis (Vito ya da Bentley) aynı noktadan
  girer; konumu "şüphelinin ilerleme oranıyla 2,6'dan 0,72'ye küçülen mesafe" kadar geride → hep daha hızlı, asla
  çarpmaz. İkisi de yolun ORTA çizgisinde gider (`TrafficVehicle.Mode.CHASE`, `start_chase / place_on_chase_path`),
  şüpheli hafif zikzak çizer. Yol ucu dünyanın kenarına taşınmışsa görünmez olunca silinirler.
- Kovalamaca araçları `vehicles` listesine girmez: şehir sayacına sayılmaz, müşteri / yarış rakibi olmaz, seçilemez
  (tıklama kutusu kapalı); doğma alanı kontrolü (`_is_clear`) onları da sayar.
- Yol verme: TRAFFIC kipindeki araç arkadan gelen / karşıdan yaklaşan kovalamaca aracını 3,2 birimden görünce sağa
  0,08 kayar ve hızını %35'e indirir (`TrafficManager.chase_pressure`); geçince şeridine döner. Kayma kaldırımdaki
  tamir müşterilerine değmesin diye küçük. Kovalamaca sürerken kavşağa karşı eksen girmez (`holds_crossing`).
- Siren (`traffic/police_siren.gd`, 2026-10-17 yeniden — kullanıcı: "pek hoşuma gitmedi, daha gerçekçi yap"): kodla
  sentez, döngülü, 24 kHz. Gerçek siren zinciri: kaynak → korna hoparlörü rezonansları (her harmonik o anki frekansında
  süzülür) → sürücü doyması (tanh) → binalardan 5 kısa yankı (döngü içinde sarar). Bentley: elektronik siren, 4,6 sn
  uluma (650 → 1.480 Hz, motorlu siren gibi hızlanıp yavaşlayan) + 3 sn yelp (0,3 sn), kare dalga kaynak (doluluk %46),
  7,6 sn döngü. Vito: Martinshorn la / re (440 / 587 Hz) 0,65 sn, her ton hafif farklı akortlu iki kornadan (vuru),
  ton başında basınç oturana kadar perde alttan gelir, 5,2 sn döngü. Her kovalamaca döngünün rastgele yerinden başlar.
  DUYULMA (kullanıcı kararı): polis haritaya girdiği andan çıkana kadar duyulur; düzey ekrandaki konuma göre — tam
  ortada −8 dB, ekran kenarında −21 dB (arası dB'de doğrusal), ekran dışında yarı ekran başına −8 dB ama −31'in altına
  inmez (doğu ucundan gelen polis görünmeden ~2 sn önce kısık duyulur). Uzaklaştıkça alçak geçiren 11 kHz → 1,5 kHz
  (boğuk), ekranın solundaki polis soldan (pan ±0,6), Doppler araç hızından (ses hızı 46 birim/sn, dinleyici ekran
  ortasının 1,2 birim üstünde; kamera kaydırmak perdeyi oynatmaz). Kendi `PoliceSiren` bus'ı (kodla kurulur: LowPass +
  Panner) → SFX. Susarken kısılarak durur (`is_playing` hemen false). Ekran açıkken susar. Sentez masaüstünde 0,2 / 0,4 sn
  (uluma / iki ton); polis modeliyle birlikte 20 sn önceden iş parçacığında hazırlanır. Dinleme dosyaları:
  `PoliceSiren.build(kind).save_to_wav(...)`.
- Test `tests/police_chase_test.gd` (pencereli, 35 kontrol); görsel QA `qa/police_chase_qa.gd` (şerit başına
  kontakt + polisin ekran ortasına en yakın tam kare).

---

# Sekizinci parti (2026-10-19), katalog 59 → 74

Kaynaklar `eksik_dosyalar/yeni 17 araç/` (klasörde 15 GLB vardı; dosya adı ≠ id: `corolla` → `toyota_corolla`, `megane_4`
→ `renault_megane_4`, `passat_b8` → `vw_passat_b8`). Aynı Tripo yapısı (tek materyal, 4096² JPEG, 31–102 parça, ~470–500K
üçgen). Komut sırası altıncı partiyle aynı; ek adımlar: logo söküm (`tools/debadge`, `badges.json`'a 15 araç), bilboard afişi,
boyut laboratuvarına `--add` ile ekleme. Araç adları kurgusal (docs/ARAC_ADLARI.md).

| Oyundaki ad | Kimlik | GLB MB | Üçgen | Parça | Boya maskesi % | Fabrika rengi | 300 m | Sınıf |
|---|---|---|---|---|---|---|---|---|
| VIER SECHS 19 | `audi_a6` | 5,6 | 114.774 | 39 | 26,0 | #2F3C4E | 10,17 sn | A |
| BAVARIA DREI 15 | `bmw_f30` | 5,7 | 125.574 | 61 | 9,6 | #EA525D | 10,83 sn | A |
| OVALE TONNERRE 16 | `bugatti_chiron` | 5,7 | 110.474 | 76 | 16,3 | #0188F2 | 6,79 sn | S |
| OVALE ÉCLAIR 05 | `bugatti_veyron` | 5,8 | 109.176 | 76 | 31,6 | #EAEBF6 | 6,92 sn | S |
| KİRAZ KAPLAN 8 | `chery_tiggo_8` | 5,3 | 111.474 | 56 | 26,5 | #1F2529 | 12,17 sn | C |
| TORNADO HALE 21 | `toyota_corolla` | 5,4 | 109.538 | 56 | 24,5 | #9CA0B3 | 12,59 sn | C |
| IBERO FARO 20 | `cupra_formentor` | 5,7 | 118.674 | 68 | 23,6 | #363E4C | 9,40 sn | A |
| FURIA ASSOLUTA 13 | `ferrari_laferrari` | 5,4 | 98.448 | 68 | 7,9 | #F9545D | 7,07 sn | S |
| FORGE HAMAL 19 | `ford_transit` | 6,5 | 119.807 | 102 | 22,2 | #DCD8DC | 13,78 sn | D |
| ROMBO KAYRA 19 | `renault_megane_4` | 5,2 | 97.267 | 31 | 16,2 | #DFE0EA | 12,06 sn | C |
| STERN FESTUNG 18 | `mercedes_g` | 5,9 | 120.590 | 82 | 9,2 | #858DA1 | 9,08 sn | A |
| STERN DOLMUŞ 19 | `mercedes_sprinter` | 5,2 | 112.435 | 56 | 33,6 | #D9D5DF | 15,58 sn | D |
| WULF KOMBI 16 | `vw_passat_b8` | 5,6 | 112.438 | 62 | 22,3 | #D7D8E2 | 11,42 sn | B |
| STALLION FOHLEN 20 | `porsche_taycan` | 5,4 | 109.986 | 60 | 23,0 | #D6D8E8 | 7,72 sn | S |
| ARROW KANZLER 16 | `skoda_superb` | 5,5 | 108.633 | 51 | 18,0 | #2A3E4F | 11,61 sn | B |

**Performans verisi** (fabrika; kaynaklar: üretici basın bültenleri, ADAC, auto-data): A6 C8 45 TFSI quattro (245 PS, 6,0 sn,
250), 320i F30 LCI (184 PS, 7,3 sn, 235), Chiron (1.500 PS, 420 sınırlı), Veyron 16.4 (1.001 PS, 2,5 sn, 407), Corolla E210
1.8 Hibrit (122 PS, 11,0 sn, 180 — modelin arkasında / yanında HYBRID rozeti vardı), Formentor VZ 2.0 TSI 4Drive (310 PS, 4,9 sn,
250), LaFerrari (963 PS sistem, "<3 sn" → 2,6, ">350" → 350), Megane IV Sedan 1.3 TCe 140 EDC (9,7 sn, 205), AMG G 63 (585 PS,
4,5 sn, 220), Passat B8 1.4 TSI ACT DSG (150 PS, 8,4 sn, 220), Taycan **Turbo** (680 PS overboost, 3,2 sn, 260), Superb III 1.4
TSI ACT DSG (150 PS, 8,8 sn, 218). Ölçüler gerçek (genişlik aynasız).
- **TAHMİN:** Tiggo 8 Pro 1.6 TGDI 183 PS'nin resmi 0-100'ü yok (197 PS sürüm 8,9 sn, 145 PS 10,6 sn) → 10,0 sn; 9,5 sn ile tam
  modifiye C → A iki sınıf atlıyordu (Vito'daki emsal). Transit tek kabin kasalı (2.0 EcoBlue 170 PS, RWD) ve Sprinter uzun
  minibüs (2.1 CDI 163 PS) için 0-100 / son hız yayımlanmıyor → 14,0 sn / 160 ve 19,0 sn / 150 tahmin.
- **Kademe görünürlüğü:** performance_mod_test "her kademe ekranda bir değeri görünür iyileştirir" kuralı (300 m 1/120 sn adımlı,
  ekranda 2 ondalık) üç araçta tutmadı → Chiron 0-100 2,4 yerine **2,42** (resmi değer "< 2,5 sn"), Taycan Turbo S (2,8 sn)
  yerine **Turbo**, Formentor kategori `hatchback` (1,51 m boyuyla binek; `suv` +150 kg kütle demek).

**Kasa ve set (GEÇİCİ — kullanıcıyla netleşecek):** ŞEHİR + Corolla, Transit (common) · AİLE + Megane, Tiggo, Sprinter (common),
Passat B8, Superb (rare) · SPOR + 320i (rare), Formentor (epic) · PRESTİJ + A6 (rare), G 63 (legendary) · SÜPER + Taycan (epic),
LaFerrari, Veyron, Chiron (legendary). Oranlar: ŞEHİR Getz %25,3 → %16,8; PRESTİJ E60 %1,57 → %1,34; SÜPER RS6 %53,8, her
hiper araç %2,2. Yeni setler **HİPER** (Veyron, Chiron, LaFerrari) ve **TİCARİ** (Transit, Sprinter); WULF GRUBU + Passat B8 /
Superb, AİLE SEDANI + Corolla / Megane, BAVYERA + 320i, PREMIUM + A6 / G, İTALYAN + LaFerrari, SÜPER SPOR + Taycan.
Trafik: Chiron / Veyron / LaFerrari `exotic` (trafiğe kapalı, ara sıra geçer; W16 / V12 motor sesi en tiz profil — egzotik
listesi 3 → 6), diğer 12 araç normal trafikte. Fiyat / seviye / rütbe kilitleri sınıf ve emsallere göre (GEÇİCİ).

**Elle düzeltilenler:**
- **Teker eksenleri:** wheel_fit'in yüzdelik ucu lastiğin yere basan ezik tabanına kayıyordu (Corolla 3 mm, Passat B8 1,6 mm,
  Megane 4,6 mm) → wheel_blur'da çift çizgi. 9 araçta eksen lastiğin dış çember uydurmasıyla yazıldı (alt 120° hariç
  sürümü: `~/Projects/ct_shots/yeni17/circle_fit2.gd`).
- Tiggo sağ-arka teker gövdeye (0) kaynamış → silindir `extract` 55; 34/35 egzoz uçları "teker" sanılmıştı → `exhaust`.
- Megane arka lastiklerin alt yayı kaynakta yok → `fill_arc` (152°–208°).
- Grup başında yanlış parça: Formentor sağ-ön (39, kaliper), Corolla sol-arka (29), Transit sağ-arka (12 / 97 çamurluk içi) →
  black_trim (eksen yarıçapı 0,10 ölçülüyordu).
- Cam: A6, Chiron, Tiggo, Corolla, LaFerrari, Taycan, Superb'de sınıflandırıcı hiç cam bulamadı. Boya özelliği kapalı
  (`GameFeatures.PAINT`) olduğu için ayıklanmadı; boya açılırsa paint_preview + rol düzeltmesi gerekir.

**Logo söküm:** 15 aracın ızgara / bagaj armaları, model yazıları, jant göbekleri, yan rozetler (G 63 / F70 / HYBRID / M)
silindi. Kalan: Chiron'un bagaj üstündeki "EB" kabartma (3B parça, doku değil); Megane ön elması siyah gövdesinin silüeti
(ızgaranın biçimi); Formentor bir jant göbeğinde birkaç piksel bakır.

**Trafik takip mesafesi:** stop / follow mesafeleri ~0,6 boylu araca göre ayarlıydı; 7 m'lik Sprinter (trafikte 0,95 birim)
kuyrukta öndekinin içine giriyordu. `TrafficManager.distance_to_vehicle_ahead` artık iki aracın burun uzunluğu (`_front`)
toplamının 0,6'yı aşan kısmını mesafeden düşer (kısa araçlar eskisi gibi).

**Boyut laboratuvarı:** `tools/make_size_lab.gd -- --add` mevcut sahneyi açıp yalnızca eksik araçları sıradaki yerlere ekler
(elle ayarlanmış ölçeklere dokunmaz). `model_scale` değerleri kullanıcının laboratuvarda elle ayarladığı ölçekler
(2026-10-19; Sprinter 1,67, Transit 1,42, A6 1,21, Tiggo 1,15 …); aynı turda sahnede bekleyen 4 eski ayar da yazıldı:
Passat B5.5 1,12 → 1,14, 488 1,10 → 1,07, Corsa 0,82 → 0,84, Model Y 1,24 → 1,14.
İkinci ayar turu (2026-10-19 akşam, kullanıcı laboratuvarda 12 aracı yeniden ayarladı; `read_size_lab.gd` farkı → cars.json):
Golf 7 1,00 → 1,02, A3 1,00 → 0,98, RS6 1,23 → 1,20, 488 1,07 → 1,05, Corsa 0,84 → 0,87, Model Y 1,14 → 1,085,
T10F 1,07 → 1,10, Chiron 1,055 → 1,08, Veyron 1,06 → 1,10, Formentor 1,07 → 1,10, G 63 1,16 → 1,18, Superb 1,12 → 1,16.
vehicle_scale 454, vehicle_asset 1637, vehicle_display 23, traffic_pool 28 — 0 FAIL.

**Bilboard:** Chiron (aurora), LaFerrari (night_city), Taycan (neon_grid), Veyron (studio) afişleri; `CityBillboard.POSTERS`
10 → 14 (süper araçlar araya dağıtıldı).

Testler (hedefli): vehicle_wheel 75, car_thumbs 5, crate 109, performance_mod 102, vehicle_asset 1637, vehicle_scale 454,
exotic_traffic 49, city_life 42, traffic_pool 28, customer_patience 19 — 0 FAIL. Güncellenen beklentiler: egzotik 3 → 6, E60
4/298, tam modifiyede sınıf atlayan 22 → 29 araç; depo dışı ui_test (ŞEHİR Getz %16,8), vehicle_asset_test (son hız ≤ 450),
vehicle_scale_test (uzunluk ≤ 7,5 m).

---

# Uzak zoom'da renk bozulması ve yanlış renkli parçalar (2026-10-19)

Kullanıcı: "zoom out yapınca renkleri bozuluyor (Getz, Transit, Golf, Era); bazı parçalar yanlış renkte (Era camları,
Transit kaputu); Leon ve Lambo'da da var". Bütün katalog oyun kamerasıyla (ortografik, trafik ölçeği, NPC LOD + birleştirme)
en uzak zoom'da (5,0) ve açılış zoom'unda (3,2) tek tek çizildi.

**1) Uzakta renk karışması — sebep mipmap, LOD değil.** Tripo dokusu yüzlerce küçük UV adasından oluşan tek atlas.
Uzaklaşınca GPU derin mipmap kademesine iniyor; 1024² dokunun 64² / 32² kademesinde bir texel komşu adaları kapsıyor:
beyaz araçta gri lekeler, kırmızıda pembe sis, stoplar beyazlıyor. Kanıt: aynı karede mipmapsız çizim temiz, zorlanmış
en düşük geometri LOD'u (lod_bias 0,05) yakından temiz. Godot'nun içe aktarıcıdaki `mipmaps/limit` seçeneği etkisiz
(mip sayısı yine 10), `Viewport.texture_mipmap_bias` Compatibility'de desteklenmiyor → sınır shader'da:
`vehicles/car_texture.gdshaderinc` (`car_texture()`: türevden LOD, en çok 2 = 256²). Dokulu araç artık GLB'nin
StandardMaterial3D'siyle değil `vehicles/car_textured.gdshader` örnekleriyle çizilir (CarRig `_textured` /
`_fill_textured`; aynı görünüm, rol başına uniform). car_paint / wheel_split / police_lights da aynı fonksiyonla okur.
Çizim çağrısı ve materyal sayısı değişmedi. En uzak zoom'da araç biraz daha keskin (hafif titreşim), renk doğru.

**2) Yanlış renkli parçalar — sebep rol haritası.** Işıklar oyunda hiç açılmıyor; fark materyalden geliyor: far rolü
mavimsi ton + metalik 0,45 + parlak, jant rolü metalik 0,25 (koyulaştırır), teker rolü wheel_split shader'ı, cam rolü
(yeni) %70 koyulaşır. Rol render'ı (her rol düz renk) + ışınla parça seçimi (`~/Projects/ct_shots/uzak/pickray.gd`) +
özellik taraması (`rolescan.py`) ile 74 araçta düzeltilen parçalar:
- far → gövde: Transit 27/50 (kaputun iki yarısı), Era 43/47/48 (tampon + farın etrafındaki çamurluk), DB5 22 (kaput
  burnu), Passat B8 16 (alt tampon).
- jant / teker → gövde (hiçbir teker grubunda olmayan kaporta): A3 12/34, F30 10/13/27/28/54 (kapı ve çamurluk; 10/13
  kapıya wheel_split takıyordu), M3 E30 27/30, Veyron 45/46, Corolla 16/30/45, LaFerrari 12/34, Taycan 49/51;
  → siyah trim: T10X 29/34/37, RS200 25/31.
- cam → gövde: E60 6 (tavan), Şahin 7 (arka kapı + camı tek parça), G 63 7 (kaput), RS200 5, Fiat 500 3/6/24;
  → siyah trim (stepne): G 63 12, Land Rover 4, Willys 3.
Bilinçli olarak dokunulmadı: kaliperler (jant rolü, grupsuz: RS6, 488, GT3, Golf, Bentley, Volvo), krom çıtalar far
rolünde (Charger, Mini, Mustang, W123 — metalik krom gibi duruyor), büyük stop rolündeki gövde parçaları (yalnızca pürüz
farkı), ayna rolündeki camlar (gövdeyle aynı materyal). Boya kapalı olduğu için boya maskeleri yeniden üretilmedi.

**3) Cam:** dokulu camlar açık gri pişmiş (Era ortalama 0,6) ve 0,22 pürüzle güneşi yansıtınca beyaz kaportadan
ayrılmıyordu → `CarRig.GLASS_SHADE` 0,7, `GLASS_ROUGHNESS` 0,3. Küçük resimler yeniden çizildi (74).

QA: `qa/uzak_arac_qa.gd` (oyunun kendi kamerasıyla en uzak zoom, trafikteki her modeli ayrı PNG'ye kırpar). Ölçüm /
teşhis betikleri `~/Projects/ct_shots/uzak/` (uzak_probe: varyantlar game / lod0 / nomip / clamp; roles2: rol render'ı).
Testler: vehicle_display 23, vehicle_wheel 75, car_thumbs 5, police_lights 26, vehicle_asset 1637, exotic_traffic 49 — 0 FAIL.
