# Şehir çevre sesleri (2026-10-17)

Kullanıcı isteği: "bazen korna, kuş sesleri, lastik sesleri. Çok kafa ağrıtmasın ama canlı hissettirsin şehir."

Kod: `traffic/city_ambience.gd` (CityAmbience). TrafficManager onu kodla kurar, sahne dosyası değişmedi. Ses dosyası yok: banka açılışta arka plan iş parçacığında kodla sentezlenir (masaüstünde 0,3 sn) ve hazır olunca yavaşça açılır.

## Katmanlar

| Katman | Ne zaman | Nereden | Düzey (sabit) |
|---|---|---|---|
| Uğultu | sürekli, 12 sn döngü | konumsuz | `HUM_DB` −24 |
| Lastik / yol sesi | her hareketli araç, hızıyla | aracın kendisi (3B) | `TIRE_DB` −19, kovalamacada en çok +5 dB |
| Kuşlar | 6–16 sn arayla bir kuş, 1–3 cümle | ekrandaki / yakın ağaç kümesi (3B) | `BIRD_DB` −15 |
| Korna | 22–55 sn'de bir | ekrandaki hareketli bir araç; yoksa uzak yol | `HORN_DB` −14 |
| Uzak cıyaklama | 60–140 sn'de bir | ekran dışındaki bir yol, 8–12 birim uzak | `SQUEAL_DB` −14 |

- Kuş türleri: serçe, büyük baştankara ("ti-tüü"), trill, karatavuk, güvercin; her biri 3 varyant. Her olayda perde ve konum değişir.
- Korna: kısa, çift, uzun, kamyon ve sabırsız kornası (`TrafficSfx.horn_stream`). Cıyaklama `TrafficSfx.squeal_stream` ile üretilir.
- Duran araç (kırmızıda bekleyen, tamirdeki, yol kenarındaki) sessizdir.

## Konum ve düzey

- AudioListener3D kameranın baktığı zemin noktasının (`WorldCamera.ground_point`) 1,2 birim üstünde durur ve kameranın yönündedir. Ekranın sağındaki ses sağ kulaktan gelir.
- Uzaklık sesi hem kısar hem boğar: `UNIT_SIZE` 2,5, hava süzgeci 3,5 kHz.
- `Ambience` bus'ı kodla kurulur ve SFX'e gider, yani ayarlardaki efekt düzeyi uygulanır.
  - Dünyayı örten YER ekranlarında (`Hud.WORLD_COVERING_PLACES`: garaj, mağaza, yarış, harita, hurdalık, ayarlar) ses susar.
  - Pano açıkken −9 dB kısılır.
  - Garaj düzenleyici ve fotoğraf modunda tam düzeyde çalar.

## Ölçüm (QA, varsayılan görünüm, 75 sn)

Komut: `qa/sehir_sesleri_qa.gd`

- 14 kuş cümlesi, 2 korna, aynı anda en çok 7 aracın lastik sesi duyuldu (ilk kovalamaca dahil).
- Çevre sesi Master çıkışında ortalama ~−38 dBFS. Müzikle birlikte tüm karışım ~−28 dBFS; yani çevre sesi müziğin ~10 dB altında kalıyor.
- Dinleme kayıtları `~/Projects/ct_shots/cevre/` altında:
  - `oyun_kaydi.wav`: her şey bir arada.
  - `cevre_yalniz.wav`: yalnız şehir sesleri.
  - Bankadaki her ses ayrı WAV olarak.

## Ayar

Fazla ya da az gelirse yalnızca `city_ambience.gd` başındaki sabitler değişir:

- Düzeyler: `*_DB`.
- Seyreklik: `BIRD_GAP`, `HORN_GAP`, `SQUEAL_GAP`.
- Kuş türlerinin sıklığı: `BIRD_WEIGHTS`.
