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
| Egzotik motor | yalnız egzotik araç şehirdeyken | aracın kendisi (3B) | `ExoticEngine.ENGINE_DB` −12, gazda +4 |

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

## Egzotik araçlar ve motor sesi (2026-10-17)

Kullanıcı isteği: "trafikte tek tük egzotik araç geçsin, 20'de 1. Bu egzotik araçlara trafikte motor uğultusu ekle."

**Hangi araçlar:** `cars.json`'da `"exotic": true` olanlar: 911 GT3, Huracán, 488 Pista. Bunlar normal trafiğe kapalı S sınıfı
süper araçlar (`traffic: false`); yarış rakibi olarak zaten geliyorlardı. RS6 ve Camaro egzotik sayılmadı. Bir araç eklemek ya da
çıkarmak için yalnız bu alan değişir.

**Sıklık (`TrafficManager`):** rastgele doğan araçların ortalama 20'de biri egzotiktir (`EXOTIC_EVERY`). Art arda gelmesin diye
arada en az 8 normal araç olur (`EXOTIC_MIN_GAP`); sonraki her doğumda 1/12 şansla sıra gelir, böylece ortalama aralık tam 20
kalır (testte 8000 doğumda ortalama 20,4, en kısa 9). Sıra gelince model hemen arka planda yüklenir ve bir sonraki doğumda
araç gelir. Araç doğunca model listeden düşer, sahnesini araç tutar. Aynı modelden tek araç kuralı geçerlidir. Egzotik araç
yalnızca geçer, tamir müşterisi olmaz (`RepairManager._candidates`).

**Motor (`traffic/exotic_engine.gd`):** CityAmbience her egzotik araca bir `ExoticEngine` (AudioStreamPlayer3D, `Ambience`
bus'ı) kurar ve lastik sesinin ölçtüğü hızla her fizik karesinde besler.
- Tını: silindir sayısı `performance.engine`'den okunur. Huracán V10 (tiz), 488 V8 (dolgun), GT3 düz altı (metalik; motor
  metninde sayı yok, varsayılan 6). Döngü RaceAudio'nun ateşleme darbesi yöntemiyle, 2000 d/dk'da 0,6 sn olarak üretilir.
  Döngüdeki her bileşen tam tur sayısında, yani dikiş yok.
- Sanal vites: devir = hız × vites oranı. Gaz verirken vites 4300 d/dk'da, sabit hızda 2700'de büyür; 1500'ün altında küçülür.
  Kalkışta "vrrom-vrrom" vites atışları duyulur, seyir ~2800 d/dk, frende vites küçülürken hafif devir sıçraması olur.
- Düzey: gaz verirken +4 dB, yavaşlarken −6 dB, kırmızıda rölanti −7 dB. 6 sn'den uzun duran aracın (yol kenarında bekleyen yarış
  daveti) rölantisi de söner.
- Dinleme dosyaları: `~/Projects/ct_shots/exotic/` (`render.gd`; kırmızı → kalkış → seyir → fren → rölanti).

**Test:** `tests/exotic_traffic_test.gd` (pencereli, `tools/run_tests.sh exotic_traffic_test`): katalog, oran, gerçek doğum,
müşteri olmama, motorun kurulması ve kaldırılması, vites / devir / düzey davranışı, döngü dikişi. Aynı test tamir seslerini
(`ui/hud/hud_sfx.gd`) de denetler.

## Tamir sesleri (2026-10-17)

Kullanıcı isteği: "tamirdeki aracın altınını toplama sesi ve elmasla geçme sesi ekle."

Kod: `ui/hud/hud_sfx.gd` (HudSfx). HUD kurar; sesler açılışta arka plan iş parçacığında kodla üretilir ve SFX bus'ında çalar.
- **Para toplama** (`RepairManager.repair_collected`): "ka-çın-çın" (kasa tıkı + iki çan), ardından araçtan fışkıran altınların
  yere düşüp sekme şıngırtısı. Şıngırtılar `RepairFx.coins` animasyonundaki düşüş aralığına (0,4–0,9 sn) denk gelir.
- **Elmasla bitirme** (`RepairManager.gem_finished`, `PerformanceModManager.gem_finished`): yükselen hışırtı + kristal arpej,
  0,4 sn'de parlak akor ve ışıltı. Uzun tamirde de parça takmada da çalar. Elmas yetmezse çalmaz (performance_mod_test).
- Düzey: `COLLECT_DB` −6, `GEM_DB` −5. Dinleme: `~/Projects/ct_shots/exotic/para_toplama.wav`, `elmasla_bitirme.wav`.
