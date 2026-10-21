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
| Trafik motoru | her trafik aracı; aynı anda en yakın 6 | aracın kendisi (3B) | tipe göre −34 … −25 (`TrafficEngine.DRIVES`) |
| Bağlamlı korna | dörtlü / sıkışma | sıkışan aracın kendisi | `HORN_DB` −14 |

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


## Motor çeşitleri, korna ve dörtlü (2026-10-20)

Kullanıcı isteği: "araç seslerini çeşitlendir ve daha da güzel olsun. Sokakta trafikte bazen korna sesleri olsun. Araçlar
bazı yerlerde durup dörtlü yaksınlar, 3–5 saniye sonra devam etsinler. Nadir olarak."

### Motorlar (`traffic/traffic_engine.gd`, TrafficEngine)
Egzotik olmayan her trafik aracına tipine göre motor (egzotikler ExoticEngine'de kaldı, polis aracında motor yok: siren var).
Tip `cars.json`'dan çıkarılır (`TrafficEngine.kind_of`):

| Tip | Nasıl seçilir | Örnek | Ses |
|---|---|---|---|
| ELECTRIC | "Elektrik" / "Hibrit" | Togg, Tesla, Taycan, Corolla | invertör vınlaması, hızla incelir; dururken sessiz |
| DIESEL | TDI, CDI, CRDi, Dizel, EcoBlue… | Getz, Passat B5.5, Kamiq | tıkırtılı dizel |
| VAN | dizel + kategori `van` | Transit, Sprinter | iri, pes dizel |
| V8 | V8 / V10 / V12 / W / ≥ 5,0 L | Camaro, G-Serisi | kalın, düzensiz "burble" (çapraz krank) |
| SIX | V6 ya da ≥ 2,8 L | E46, E60, CLS, S400 | pürüzsüz altı |
| CLASSIC | 2000 öncesi, ≤ 1,8 L | Şahin, Toros | hırıltılı eski karbüratör |
| FAMILY | ≥ 1,8 L | A6, F30, Formentor, Fluence | dolgun, sakin dört |
| SMALL | diğerleri | Golf 1.4, Corsa, Accent | vızıltılı küçük dört |

- Sentez ExoticEngine'in ateşleme darbesi yöntemi (döngü 2000 d/dk, 0,6 sn, dikişsiz) + dizelde darbe başı tıkırtısı, eskide egzoz
  hırıltısı, V8'de düzensiz darbe gücü. Her tipin rölantisi, vites atma devirleri ve düzeyi ayrı (`DRIVES`).
- Aynı anda yalnız dinleyiciye en yakın `ENGINE_VOICES` (6) aracın motoru duyulur (`_pick_engine_voices`, 0,25 sn'de bir); diğerleri
  susar ve duraklar (telefonda ses kanalı maliyeti). Kırmızıda rölanti −8 dB; 12 sn'den uzun duran (yol kenarındaki müşteri)
  ve tamirdeki aracın motoru söner.
- Lastik sesi araç boyuna göre üç çeşit (`_tire_key`): < 4,1 m tiz, ≥ 5,0 m ya da kamyonet pes ve gövde uğultulu.
- **Düzey ölçümü** (`qa/sehir_sesleri_qa.gd`, 75 sn; `-- motorsuz` karşılaştırma): ilk denemede motorlar çevre katmanını 10 dB
  artırıyordu (döngüler sıkışık, lastik gürültüsünden çok daha gür) → 9 dB kısıldı. Şimdi çevre katmanı motorlu −28,7 / motorsuz
  −33,3 dBFS (+4,6 dB), müzikli tüm karışım −27,1 / −27,8 (+0,7 dB).
- Ses bankası (kuşlar, lastikler, 8 motor, 24 korna) masaüstünde 0,61 sn'de arka planda üretilir.

### Korna
- Her aracın kornası motor tipine göre (`TrafficEngine.horn_kind`): küçük → ince tek ton, aile / dizel → klasik çift ton,
  altı / V8 → kalın çift ton, kamyonet → pes, eski → vızıltılı tek ton ("mıık"), elektrikli → temiz çift ton.
- Basış desenleri: dıt, dıt-dıt, uzun, sabırsız. Sentez dalga tablosuyla: harmonik dizisi + borunun rezonans tepesi, basışta perde
  %4 aşağıdan oturur, diyafram vızıltısı, yumuşak doyum.
- Ne zaman: rastgele korna 28–65 sn'de bir (ekrandaki hareketli araçtan, kendi kornasıyla). Bağlamlı: önündeki araç dörtlü
  yakmışsa arkadaki 1–2,2 sn sonra %65 olasılıkla dıt / dıt-dıt; başka sebeple sıkışan araç 4,5–8 sn sonra %30 olasılıkla uzun
  / sabırsız. Kırmızıda bekleyen korna çalmaz (`TrafficVehicle.waiting_light`). Kornalar arası en az 1,6 sn, iki korna kanalı.

### Dörtlü (`TrafficManager.start_hazard`, `TrafficVehicle.hazard_stop`, `vehicles/hazard_lights.gd`)
- 50–110 sn'de bir, ekranda görünen ve düz yolda giden bir araç 3–5 sn durur (yumuşak frenle şeridinde), dörtlüleri yanar, süre
  bitince söner ve yola devam eder. Kavşakta, kavşağa yaklaşırken ve kavşak çıkışından 1,2 birim uzaklaşmadan durmaz (arkadaki
  kavşağın içinde beklemesin). Kovalamaca sürerken ya da dünya örtülüyken olmaz; kovalamaca yaklaşırsa dörtlü biter. Araç müşteri
  / rakip olursa dörtlü söner.
- Görünüm: farların ve stopların üstünde dört sarı hale, dakikada ~87 kez yanıp söner. Konum (`HazardLights.corners`, 2026-10-20
  kullanıcı: "dörtlü bazı araçlara uymuyor, far çizgilerinde olsun"): parça haritasında (`CarPartMap`) elle ölçülmüş `hazards`
  varsa o; yoksa far / stop parçalarından her yanın EN GENİŞ parçasının ortası (haritada aynı role eklenmiş sis lambası, tampon
  sinyali, üçüncü stop seçilmez; iki yan tutarsızsa büyük yan aynalanır); o da yoksa gövde kutusu. 13 araçta harita yanlış ya da
  eksikti, ölçüldü (Accent, Era, Golf, Leon, Togg T10X, Camaro, Sprinter ön; Corsa, Formentor, Alfa, Civic, Transit, Focus, Golf,
  Leon arka). Kameradan uzağa bakan uçtaki haleler görünmez (mesh normali + shader), gövdenin dışında havada parlamaz.
  Denetim: `qa/dortlu_konum_qa.gd` (37 trafik aracının ön / arka temas sayfası; `-- yakin <araç>` ızgaralı dik ölçüm). Polis halesiyle aynı yöntem: tek mesh, kameraya dönük, yanıp sönme shader'da (`hazard_halo.gdshader`), dinamik ışık yok.
  WorldPrewarm shader'ı önceden derler.

### Dinleme ve QA
- `godot-4 --headless --path . --script res://qa/trafik_sesleri_dinle.gd` → `~/Projects/ct_shots/trafik_sesleri/`: her motor tipi
  için rölanti → kalkış → seyir → fren → rölanti (lastikle), 24 korna dosyası.
- `qa/dortlu_qa.gd` (pencereli) dörtlüyü kareyle denetler → `~/Projects/ct_shots/dortlu/`.
- Test: `tests/traffic_sound_test.gd` (pencereli, run_tests WINDOWED).

## Süper araç kalkışı (2026-10-20)

Kullanıcı isteği: "Ana ekranda ara sıra geçen süper araçlar, önleri boş olunca ışıktan çıkarken dümdüz hızlıca basıp gitsinler.
Çok nadir olmasın, 4'te 1 falan olsun."

- `TrafficVehicle`: egzotik araç (`CarCatalog.is_exotic`) kırmızıda en önde durur ve önü `LAUNCH_CLEAR` (3,5 birim) kadar boşsa,
  yeşil yanınca `LAUNCH_CHANCE` (%25) ile gaza basar. 2,0 birim/sn² ivmeyle 2,0 birim/sn'ye çıkar (normal trafik 0,8), kavşaktan
  düz geçer (şehirdeki bütün yollar zaten düz; dallanma olursa burnuna en yakın kol seçilir), `LAUNCH_DISTANCE` (7 birim) sonra
  normal hıza süzülür. Önüne 2,6 birimden yakın araç çıkarsa, sonraki kavşağa yaklaşırsa ya da kovalamaca gelirse erken biter
  (önünde araç / ışık varsa sert, yoksa yavaşça yavaşlar). Kalkıştaki araç dörtlüye seçilmez.
- Gaza basarken gövde hafifçe arkaya oturur (kaçaklardaki `_drive_flair` eğilmesi), ExoticEngine ivmeden tam gazı ve vites
  atışlarını çalar, CityAmbience arka lastiklerden kısa cıyak çalar (`TrafficManager.vehicle_launched`, `CHIRP_DB` −13).
- Ölçüm (`qa/superarac_kalkis_qa.gd`, kamera araçta): kalkışta Ambience bus'ı ~1,2 sn boyunca −22'den −10 dBFS'e çıkar, araç
  uzaklaştıkça söner. Kareler ve ses `~/Projects/ct_shots/kalkis/`.
- Test: `tests/traffic_sound_test.gd` (zar oranı, yalnız egzotik, hızlanma, cıyak, kalkışın bitmesi).
