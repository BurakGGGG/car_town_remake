# Motor sesleri ve MOTOR SES LABORATUVARI (2026-11-02)

Kullanıcı isteği: "Araç sesleri üzerine aşırı detaylı bir özellik yapmak istiyorum. Sesler çok yapay ve neredeyse hepsi
birbirinin aynısı. Bana bir ses yapıcı program yapsan, ben yapsam daha iyi olur."

Kullanıcı kararları:
- Araç Godot'un içinde çalışır; oyunla aynı sentezi ve aynı oynatıcıyı kullanır.
- Sesler yalnız sentezle üretilir, kayıt aktarılmaz.
- Sesler önceden pişirilir; paketi yaklaşık 9,5 MB büyütmesi kabul edildi.
- Kapsam: drag yarışı, şehir trafiği ve araç ekranındaki "MOTORU DİNLE". Garaj anları istenmedi.

## Neden yapay ve hep aynıydı

1. **79 araç 15 döngüyü paylaşıyordu.** Trafikte 8 tip vardı (`TrafficEngine`), egzotiklerde 3 (`ExoticEngine`), drag
   yarışında 4 karakter (`RaceAudio`). Aynı tipteki her araç birebir aynı sesi çıkarıyordu.
2. **Tek döngünün perdesi değiştiriliyordu (`pitch_scale`).** Devir artınca egzoz ve susturucu rezonansları da tizleşiyor,
   ses "sincap" gibi oluyordu. Gerçek motorda bu rezonanslar Hz cinsinden sabit kalır, yalnız ateşleme hızlanır.
3. **Gaz açık ile gaz kesik arasındaki fark yalnız ses düzeyiydi.** Gerçekte tını da değişir: gazda ses sert ve
   parlaktır; gaz kesince boğuklaşır, tekler, patlar.
4. **0,6 saniyelik döngü kendini tekrar ediyordu.** 22 kHz örnekleme ve tek kutuplu süzgeç de sesi boğuyordu.
5. **Bazı katmanlar hiç yoktu:** turbo ıslığı, blow-off, kompresör, emme, supap tıkırtısı, marş.

## Yapı

```
EnginePreset (parametre sözlüğü; JSON ya da cars.json'dan otomatik)
   │  EngineSynth: her devir noktasında ayrı sentez (gaz açık + gaz kesik), marş, kapatma, patlama, blow-off, ıslık
   ▼
EngineBank (res://vehicles/sound/banks/<id>.res, QOA, araç başına ~120 KB)
   │  EngineVoice: AudioStreamPolyphonic; en yakın iki devir katmanı + yük karışımı, turbo, patlama, kesici
   ▼
RaceAudio (drag) · TrafficEngine / ExoticEngine (şehir) · ModGarageView (modifiye gaz sesi)
```

| Dosya | Görev |
|---|---|
| `vehicles/sound/engine_preset.gd` | Parametrelerin tek tanımı (`PARAMS`, 70 satır), 19 şablon, `KNOWN` (araca özgü dizilim ve karakter), `auto()` |
| `vehicles/sound/engine_synth.gd` | Sentez zinciri (aşağıda) |
| `vehicles/sound/engine_bank.gd` | Pişirme işleri (`jobs_for` / `run_job` / `assemble`), QOA, kayıt / yükleme önbelleği |
| `vehicles/sound/engine_voice.gd` | Oyundaki oynatıcı |
| `vehicles/sound/presets/<id>.json` | Laboratuvarda KAYDET ile yazılır ("elle ayarlı"); yoksa otomatik ayar kullanılır |
| `vehicles/sound/banks/<id>.res` | Oyunun dosyası (PİŞİR ile) |
| `tools/engine_lab/` | MOTOR SES LABORATUVARI (`engine_lab_ui.gd`, `lab_sim.gd`, `lab_gauge.gd`, `lab_spectrum.gd`, `bake_all.gd`) |

### Sentez zinciri (içten yanmalı)
1. **Ateşleme.** Dizilimin ateşleme açıları (`EngineSynth.geometry`) kullanılır: sıra 1–6, V6 (eşit ve tek-çift),
   çapraz ve düz krank V8, V10, V12, W12, W16, boksör 4/6, Wankel 2/3 ve elektrik. Krank açısı devir eğrisiyle ilerler.
   Her ateşleme bir olaydır ve şunları taşır: silindir farkı, yanma düzensizliği, rölantide kam dalgalanması, gaz
   kesikte tekleme, zamanlama titremesi ve taraf etkileşimi (çapraz krank V8'in "gurultusu" buradan gelir).
2. **Darbe.** Egzoz basınç darbesi krank açısı cinsinden tarif edilir (`pulse_deg`), yani devirle kısalır. Darbe
   silindirin manifold gecikmesiyle kendi tarafının tamponuna eklenir; ardından manifolddan iki ters yansıma gelir.
   Manifold borularının boy farkı boksörün "gurul gurul" sesini verir.
3. **Kolektör.** Taraf başına doyum uygulanır (darbelerin çarpışması), sonra X-boru karışımı.
4. **Boru.** Taraf başına sönümlü yansımalı gecikme hattı kullanılır; iki taraf farklı boydadır. Rezonanslar Hz
   cinsinden sabittir.
5. **Akış.** Darbe zarfıyla değişen gürültü eklenir: hırıltı (tiz) ve yanma gürültüsü (orta).
6. **Susturucu.** Alçak geçiren (gaz kesikte daha kapalı, turboda boğuk), oda uğultusu, bas rafı, alt kesim.
7. **Ek katmanlar.** Emme, blok çınlaması, supap tıkırtısı, dizel tıkırtısı, kompresör vınlaması ve düz dişli vınlaması.
8. **Düzey.** Pişirmede her katman ön ayara tam oturtulur. Gaz açık katmanlar devirle yükselme eğrisini izler (kırmızı
   çizgide 0 dB). Gaz kesik katmanlar aynı devirde `off_db` kadar kısıktır. Marş ve kapatma, rölanti katmanının
   ölçeğiyle çalar.

**Elektrik (2. tur: "elektrikliler aşırı ince"):**
- Devirle yükselen bütün tonlar `ev_pitch` ile ölçeklenir (varsayılan 0,45).
- Gövde: elektriksel frekans ve 2. / 3. harmoniği, kalın uğultu verir.
- Fütüristik akor: kök, beşli ve oktav; her biri akordu hafif farklı iki testere dalgası (dalga tablosu) ve sıcak
  alçak geçiren. Kök devirle 3,5 katına çıkar; Taycan ve Togg'da belirgin, Tesla ve Corolla'da kapalı.
- Yol / rüzgâr: hızla açılan süzülmüş gürültü.
- Vınlama (motorun 6. mertebesi, redüktör dişlisi, invertör tonu) `ev_tone_hz` ile iki kez süzülür.
- Nyquist'e yaklaşan bileşen yumuşakça kısılır.
- İlk sürümde enerji 2–6 kHz'deydi; şimdi 100–600 Hz'de toplanıyor.

**Döngüler:** her devir noktasında yaklaşık 8 motor çevrimi alınır (0,45–1,1 sn, tam çevrim sayısı). Sondan başa
60 ms çapraz geçiş yapılır, süzgeçler 0,25 sn ısınır. Devirden bağımsız tonlar döngüde tam tur olacak şekilde yuvarlanır.
`LoopedWav` kuralına uyulur: sona ilk iki örneğin kopyası eklenir ve `loop_end` eski örnek sayısı kalır.

### Oynatıcı (EngineVoice)
- Devire en yakın iki katman log-devir aralığında eşit güçle karışır. Her katmanın perdesi devir / katman devri kadar
  değişir; bu oran en çok yarım katman aralığıdır (7 katmanda ±%17).
- Gaz açık ve gaz kesik takımlar gaz oranıyla eşit güçle karışır. Lite modda (trafik) yalnız baskın takım çalar ve
  eşikte gecikmeli geçilir; böylece çoğu an iki akış çalar.
- **Turbo:** basınç gecikmeyle dolar (`spool_lag`), ıslığın perdesi ve düzeyi basınçla değişir. Gaz bırakınca
  blow-off çalar, sonra basınç düşer.
- **Patlama:** gaz bırakınca `crackle` oranında patlama dizisi gelir; uzun gaz kesikte ve devir kesicide ara ara
  çıtırtı olur.
- **İnerken patlama** (2026-11-02, kullanıcı: "Supra'da pat pat pat diye yüksek devirden inerken"): gaz kesik ve
  devir düşerken her `pop_interval`'da bir vuruş olur, vuruşta `decel_pops` olasılıkla patlama gelir. Devir
  `pop_rpm`'nin altına inince ya da gaz açılınca biter. Hızlı düşüşte ritim sıklaşır, devir indikçe patlamalar
  seyrekleşir ve kısılır. Açık olduğu araçta gaz bırakmanın rastgele çıtırtısı kapanır, üst üste binmesin diye.
  Şimdilik yalnız Supra'da açık (0,88 / 0,12 sn / 0,28). Ölçüm için `qa/motor_patlama_olcum.gd`: Supra boşta
  hızlı inişte 6 patlama (0,10 sn ara), vitesteki yavaş inişte ~24 patlama (0,12–0,18 sn).
- **Devir kesici:** gaz açık takım `limiter_hz` hızında `limiter_duty` oranında kesilir.
- **Marş:** `start_engine()` çevirmeyi, yakalamayı ve rölantiye oturmayı çalar; döngüler rölantide açılır.
  `stop_engine()` kontağı kapatır.
- **`dynamics`:** katmanlar arası gürlük farkının çalınan payı. 1 = drag yarışı ve laboratuvar; 0,65 = egzotik
  trafik; 0,5 = trafik ("kafa ağrıtmasın").

## MOTOR SES LABORATUVARI

Çalıştırmak için: `tools/engine_lab.sh [-- <araç_id>]` (ya da `godot-4 --path . -s res://tools/engine_lab/engine_lab.gd`).

- **Sol:** araç listesi ve arama. ● elle ayarlı, ○ otomatik, ✓ pişmiş.
- **Orta:** 3B araç ve "yanından geçiş" sahnesi (Doppler, uzaklık); devir saati, gaz ve turbo çubukları, çalan devir
  katmanları; canlı spektrum (40 Hz–10 kHz).
  - **Senaryolar:** MARŞ, KONTAK KAPAT, GAZ PATLAT, ÜÇ POMPA, DEVİR KESİCİ, KALKIŞ + VİTES, ŞEHİR SÜRÜŞÜ, YANINDAN
    GEÇİŞ.
  - **Kip:** boşta (pedal), vitesli sürüş (otomatik ya da Boşluk ile vites), elle (devir ve gaz sürgüsü).
- **Sağ:** 70 parametre, 14 grupta: Motor, Ateşleme, Manifold, Egzoz, Susturucu, Emme, Turbo, Kompresör, Mekanik,
  Elektrik, Gaz kesik, Devir kesici, Marş, Karışım. Her satırda sürgü, sayı, birim ve ↺ (kaydedilmiş değere dön)
  vardır; açıklamalar ipucu olarak görünür. Elektrikte yanmalı motor grupları gizlenir. Kaydedilmiş değerden farklı
  olan parametrenin adı sarı yazılır.
- **Üst çubuk:**
  - **Ayar:** Şablondan başla (19 şablon), Otomatik (cars.json'dan), Varyasyon (yeni tohum), Geri al / Yinele.
  - **Kıyas ve kayıt:** A'ya al / A↔B kıyas, ● KAYIT (duyulanı `~/Projects/ct_shots/motor_sesleri/` altına WAV yazar).
  - **Dosya:** Diskten geri yükle, Kaydı sil, KAYDET (JSON), PİŞİR (kaydet + `.res`), TÜMÜNÜ PİŞİR.
- **Kısayollar:** W basılı = gaz, Boşluk = vites, B = gaz patlat, M = marş, K = kontak kapat, Ctrl+S = kaydet,
  Ctrl+Z / Ctrl+Y = geri al / yinele.
- **Yeniden üretim:** her değişiklikte bütün katmanlar iş parçacıklarında yeniden üretilir; bu masaüstünde 0,5–1 sn
  sürer. Ses kesilmeden yenisine geçilir.

**İş akışı:** araç seç → şablondan ya da otomatikten başla → ayarla ve dinle → KAYDET → PİŞİR. Editör dosya sistemini
taradığında oyun yeni sesi kullanır. Başsız toplu pişirme için:
`godot-4 --headless --path . -s res://tools/engine_lab/bake_all.gd [-- <araç_id> …]` (79 araç yaklaşık 35 sn).

### Otomatik ön ayar (79 aracın başlangıcı)
- **Şablon seçimi:** `EnginePreset.auto` önce motor metninden şablon seçer: elektrik / hibrit, dizel (kamyonet
  ayrı), W16, V12 / W12, V10, V8 ya da ≥ 5 L, V6, ≥ 2,8 L sıra 6, Wankel, 1990 öncesi karbüratörlü, turbo,
  küçük benzinli.
- **Elle seçilen araçlar:** motor metninin söylemediği dizilim ve karakter `KNOWN` tablosundadır. Örnekler: E46 sıra 6,
  Getz 3 silindir dizel, Volvo ve Quattro sıra 5, 488 düz krank V8 turbo, GT3 boksör 6, Beetle 1967 hava soğutmalı
  boksör, Fiat 500 iki silindir, RX-7 Wankel, ralli turbolar, Supra / R34 turbolu sıra 6.
- **Hacim ve yıl:** büyük motorda uğultu daha pes, bas daha çok, boru daha uzun olur. 1985 öncesi araçta yanma daha
  düzensiz, supap tıkırtısı daha belirgindir.
- **Araca özgü tohum:** kimlikten türeyen tohumla 7 alan ±%8–15 oynatılır. Böylece aynı şablondaki iki araç bile
  farklı çıkar.

## Oyundaki yerler
- **Drag yarışı (`race/race_audio.gd`):** `set_vehicles(oyuncu, rakip)` iki aracın sesini kurar.
  - **Devir:** fiziğin devri bankanın rölanti–kırmızı aralığına oranla taşınır.
  - **Gaz:** geri sayımda 0,55, yarışta 1, vites geçişinde ve çizgiden sonra 0.
  - **Diğer:** kesici fizikten gelir. Vites patlaması aracın kendi patlamasıdır (`backfire`). Oyuncu −6 dB,
    rakip −15 dB.
- **Şehir trafiği (`traffic/traffic_engine.gd`):** sürüş tipi (`kind_of`) yalnız devir, vites ve kornayı belirler;
  sesi aracın bankası verir.
  - **Gaz:** seyirde 0,25 yük, hızlanma bunun üstüne eklenir, dururken rölanti.
  - **Oynatıcı:** Lite, dinamik 0,5.
  - **Düzey:** `DRIVES[*][0]`, bankanın en gür katmanına göre. Ölçüm (`qa/sehir_sesleri_qa.gd`, motorlu ve
    `-- motorsuz`): çevre katmanı −28,4 / −33,4 dBFS, yani +5,0 dB; eski motorlarla +4,6 dB idi. Müzikli karışımda
    +0,9 dB (eskiden +0,7). İlk denemede yeni bankalar 11 dB kısık kalmıştı, `DRIVES` +10 dB yükseltildi.
    Kullanıcı "fazla" ya da "az" derse yalnız `DRIVES[*][0]` değiştirilir.
- **Egzotik trafik (`traffic/exotic_engine.gd`):** tam kalite, dinamik 0,65, `ENGINE_DB` −2. Işıktan kalkışta
  gürler, gaz kesince patlar.
- **Modifiye garajı (`ui/hud/mod_garage_view.gd`):** `_rev(tepe, süre)` aracın kendi sesiyle bir gaz zarfı çalar.
  Önce tam gazla tepeye çıkar, sonra gaz kesilir ve rölantiye iner; ses söner. Patlama sesi bankadan gelir.
- **DİNAMOMETRE (dino atölyesi):** garajda araca dokununca YAKINDAN İNCELE, ya da modifiye menüsünde DİNAMOMETRE kartı.
  Aracın sesi gaz pedalı, vites ve DİNO KOŞUSU ile çalar; egzoz patlamasında alev çıkar. Ayrıntı: `docs/DINAMOMETRE.md`.

## Yeni araç eklerken
`cars.json`'a kayıt eklendikten sonra laboratuvarda aracı seç, gerekirse ayarla, PİŞİR. Pişmemiş araç trafikte
sessiz kalır, drag yarışında sesi bellekte üretilir (bir saniyelik takılma ve uyarı olur). `traffic_sound_test`
pişmemiş aracı FAIL sayar.

## Test / QA
- `tests/traffic_sound_test.gd`: her aracın bankası var mı, trafik sürüşü ve elektrikli araç.
- `tests/exotic_traffic_test.gd`: egzotiklerin dizilimi, döngü dikişi ve düzeyi, sürüş.
- `tests/looped_wav_test.gd`: üç aracın PCM bankası `LoopedWav` kuralına uyuyor mu.
- `qa/motor_sesi_dinle.gd -- <klasör> <id>…`: sürekli devir eğrisiyle sürüş, katmanlar, marş, patlama WAV'ları;
  süre ve boyut ölçümü.
- `qa/motor_lab_qa.gd`: laboratuvarı açar, senaryoları çalıştırır, ekran görüntüsü alır.
- `qa/motor_banka_olcum.gd`: 79 bankanın yükleme süresi (ortalama 0,55 ms) ve katman düzeyleri.

## Tuzaklar
- Snap'teki Godot `/tmp`'ye erişemez; QA betikleri proje içinde (`qa/`) olmalı.
- Yeni `class_name` eklenince editör kapalıysa `godot-4 --headless --path . --import` sınıf önbelleğini günceller.
- Laboratuvarın pencere genişliği: uzun tek satırlık `Label` ve `OptionButton.fit_to_longest_item` en küçük
  genişliği büyütüp sağ paneli ekran dışına itiyordu. Bu yüzden ipucu satır kaydırmalı, açılır listeler
  `fit_to_longest_item = false`.
- İş parçacıklarından sonuç dizisine yazarken `Mutex` kullanılmalı. `EngineSynth.prepare()` ana iş parçacığında bir
  kez çağrılmalı (paylaşılan gürültü tablosu).
- Paketlenmiş GDScript dizileri (`PackedFloat32Array`) işlevlere başvuruyla geçer; `finish()` gibi yerinde değiştiren
  çağrılardan önce `duplicate()` yapılmalı (`assemble` yapıyor).
