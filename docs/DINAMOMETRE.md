# DİNAMOMETRE (dino atölyesi) — 2026-11-02

Kullanıcı isteği: "Gaz verme ekranı da garajda aracın üzerine basınca yakından incele butonu olsun, orada gaz pedalı falan
olsun, daha mükemmel bir ekran istiyorum." Üç taslaktan **C DİNAMOMETRE** seçildi ("çizimini iyi yap, dinamometre gerçekçi
olsun"). Taslak tuvali: https://claude.ai/artifact/QLcyqVWPyizpjLwfRQTWC2

## Kullanıcı kararları
- **Giriş yolları:**
  1. Garajda araca dokununca aracın üstünde **YAKINDAN İNCELE** plakası belirir.
  2. Modifiye garajının menüsünde **DİNAMOMETRE** kartı vardır (PERFORMANS ile KOZMETİK arasında).
  - "Parça takınca dinoya çık" önerisi ve şehirde ayrı bina İSTENMEDİ.
- **Sahne:** ayrı, **gerçek dino atölyesi**. Modifiye garajının siyah-altın teması değil.
- **İlk denemeden sonra (aynı gün):**
  1. START/STOP yok; araç atölyeye ÇALIŞIR hâlde gelir (3. tur: marş sesi de yok, rölanti 0,25 sn'de açılır —
     `EngineVoice.resume`).
  2. Vites yok.
  3. Kamera yalnız GENEL ve EGZOZ; tek düğme, her basışta öbürüne geçer (TEKER kamerası kalktı).
  4. Dinoda oyun müziği kısılır, motor sesi açılır (3. tur, telefonda "çok az": kendi bus'ı + sınırlayıcı, +6 dB).
  5. Dinodayken arka planda korna duyulmaz.
  6. (İkinci tur) DİNO KOŞUSU düğmesi kalktı. Kamera düğmesi de kalktı: tek kamera (GENEL, sağ ön 3/4).
  7. Araçlar katalogdaki çekişe göre: önden çekişte yalnız ön, arkadan itişte yalnız arka aks döner, 4 çekerde ikisi
     birden (merdane + tekerler). Künyede çekiş yazar.

## Atölye (`tools/garages/dynoroom.py` → `assets/garages/dynoroom/`)
- **Dinamometre:** zeminden yükseltilmiş sarı çelik gövde, baklava desenli sac döşeme ve iki rampa.
  - Her aksta tırtıllı bir çelik merdane vardır; dört teker de merdanede durur, böylece önden, arkadan ve dört çeker
    araçlar aynı dinoda çalışır.
  - **Arka merdane sabittir.** Ön merdane, taşıyıcısıyla birlikte kanalda kayar ve sürgülü kapaklarla örtülür. Kanal 1,75–4,7 m
    dingil mesafesini karşılar (Fiat 500'den Sprinter'a kadar).
- **Atölye donanımı:**
  - Tekerlekli soğutma fanı.
  - Tavanda egzoz emiş hortumu makarası.
  - Zeminde kayış halkaları: önde üç çift, arkada bir çift.
  - Kontrol masası ve ekranlar, kuzey duvarında güç eğrisi ekranı.
- **Oda:** akustik paneller, hava giriş panjuru, kepenk, ikaz şeritli epoksi zemin.
- **Önizleme render'ı:**
  `blender -b --factory-startup --python tools/garages/dynoroom.py -- preview <dyno|side|rear|wheel|desk|wide> <png> [w h örnek] [araç]`
  (önizlemede araç, kayışlar ve hortum da çizilir).
- **Oyuna aktarma:** `blender -b --factory-startup --python tools/garages/export_garage.py -- dynoroom` (yaklaşık 2 dk, 39 bin
  üçgen, 2,6 MB). Işık köşe rengine pişer; zemin `floor.png`'ye pişer. `Deck_*` ve `Ramp_*` nesnelerine yalnız ışık pişer,
  oyun bunu `diamond.png` ile çarpar. Ekranlar `dyno_graph.png` ve `dyno_gauges.png` ile çizilir.
- **Düğüm sözleşmesi:**
  - `DrumRear` dönen parçadır.
  - `FrontCarriage` kayan parçadır; altında `CarriageBody` ve dönen `DrumFront` vardır.
  - `Fan` taşınan parçadır; altında `FanBody` ve dönen `FanBlades` vardır.
  - İşaretçiler: `RearAxle`, `HoseStart`, `Anchor_F0..2_L/R`, `Anchor_R0_L/R`.
  - İç içe düğümler `DynoView.node()` ile (find_child) bulunur; `GarageInterior.part` yalnız üst düzeye bakar.

## Fizik (`gameplay/dyno/dyno_sim.gd`, DynoSim)
- **Motor:** yarış fiziğinin künyesi kullanılır (`PerformanceMods.spec_for`, modifiyeli).
- **Vites yok:** motor çalışınca ölçüm vitesinde (oranı 1'e en yakın) durur; oyuncu vites seçmez.
- **GAZ VERME (yük dinosu gibi):** devir pedalı izler. Basınca `HOLD_RISE` ile çıkar (tam gazla kesiciye 0,8 sn), bırakınca
  `HOLD_FALL` ile iner (rölantiye 1,2 sn); yarım gazda devir yarıda durur. Merdaneler frenle devre bağlı döner, rölantide
  debriyaj açıktır (merdane durur).
  - Neden: viteste atalet çekişiyle rölantiden kesiciye 9–16 sn, bırakınca rölantiye 19–30 sn sürüyordu; gaz verirken
    çok ağır (`qa/dino_his_olcum.gd`).
- Devir kesici kırmızı çizgide devreye girer; kesicide gösterge kırmızı çizgideki gücü okur.
- **Çekiş:** `drives_front` / `drives_rear`, katalogdaki `performance.drivetrain` (FWD / RWD / AWD; 22 / 38 / 19 araç).
  Yalnız çeken aksın merdanesi ve tekerleri döner (`CarRig.set_axle_spin`).
- **Ölçüm:** gösterge ölçeğinde yapılır (`power_curve.scale`). Fabrika aracında tepe güç kataloğun beygirine eşittir (test
  ±%1,5); modifiye takınca artar. Ölçüme koşudan koşuya ±%0,8 fark eklenir.
- **Ölçüm = tam gaz çekiş:** pedal dibe (≥ 0,95) basılınca eğri baştan kaydedilir; çekiş rölanti yakınından (aralığın
  ilk %45'i) başlayıp kesiciye varırsa bir ölçüm sayılır (`DynoSim.pulls`). Tepe güç en iyi ölçüm adayıdır; fabrika
  aracında katalog beygirine %1,5 içinde denk (test). Ayrı DİNO KOŞUSU (atalet çekişi) kaldırıldı.
- **En iyi ölçüm:** `PerformanceModManager.dyno_best` / `record_dyno` ile tutulur (`DynoView.pull_measured`). Kayıtta `performance.dyno` alanında
  saklanır (isteğe bağlı alan, kayıt sürümü değişmedi). `dyno_record_changed` sinyali kaydı tetikler.

## Sahne denetleyicisi (`ui/hud/dyno_view.gd`, DynoView) ve arayüz (`ui/hud/dyno_screen.gd`, DynoScreen)
- **Sahne:** ModGarageView ile aynı yolu izler. Garaj ekranının SubViewport'una oda ve `DynoStage` kurulur. Kamera ve ışık
  ayarları kaydedilip çıkışta geri verilir.
- **Araç yerleşimi:** sınır kutusu köşe noktalarından hesaplanır. Arka teker arka merdanenin tepesine oturur; ön taşıyıcı
  ön tekerin altına kayar.
- **Araca göre kurulanlar:**
  - Fan aracın burnunun önüne konur; uzun araçta rampanın önünde zemine iner.
  - Kayışlar (kutu mesh) en yakın halkalara bağlanır.
  - Hortum kübik Bézier eğrisiyle iner ve egzozun arkasından yatay gelip huniye girer.
- **Dönen parçalar** (merdaneler, fan kanatları) gerçek zamanlı ışıklı metalle çizilir. Pişmiş ışık geometriyle birlikte
  döndüğü için merdanenin karanlık alt yüzü üste geliyordu.
- **Ses:** aracın pişmiş bankası EngineVoice ile çalar; devir RaceAudio ile aynı şekilde oranla eşlenir.
  - Yüksek motor sesi bus'ı `EngineLoud` (`EngineVoice.loud_bus()`; AudioEffectHardLimiter, tavan −1 dB, çıkışı SFX →
    ayarlardaki efekt düzeyi uygulanır; drag yarışı da kullanır).
    Oynatıcı +6 dB (`ENGINE_DB`), katman farklarının %60'ı çalınır (`DYNAMICS` 0,6): rölanti dolgun, tam gaz / patlama
    kırpılmaz. Önceki −1 dB (SFX'e doğrudan) telefonda çok kısıktı. Egzoz patlaması `EngineVoice.popped` sinyaliyle `DragFx` alevini tetikler (Supra'nın
  "pat pat pat"ı alevle birlikte).
  - Atölye açıkken garaj teması `GameMusic.DYNO_DB` (−19 dB, taban −4) düzeyine kısılır (`GameMusic.dyno`), çıkışta geri gelir.
  - Trafik kornası / lastik cıyaklaması (`TrafficSfx`) dünyayı örten bir yer açıkken çalmaz. Şehrin kamerası arkada aracı
    "görüyor" sayıldığı için garajda ve dinoda korna duyuluyordu. CityAmbience ve polis sireni orada zaten susuyordu.
- **Görsel:** fan dönüşü, motor titremesi (araç çalışır hâlde gelir).
- **Kamera:** tek, sağ ön 3/4 (`_shot`).
- **Arayüz:** container'larla kuruludur.
  - Üstte solda GERİ, ortada araç adı ve künyesi (motor · beygir · çekiş).
  - Solda panel: devir ışıkları, devir, hız, tork, büyük GÜÇ değeri ve `DynoGraph` (güç, tork, soluk fabrika eğrisi,
    en iyi ölçüm çizgisi).
  - Sağda `DynoPedal` (dokunmatik; basılan noktaya göre %35–100 gaz).
  - Altta düğme yok. Rekor kırılınca panelin EN İYİ satırı 3 sn altın renkte "YENİ REKOR! … bg" yazar.
- **Garaj bağlantısı** (`garage_screen.gd`):
  - `open_dyno` / `close_dyno`. Modifiyeden girildiyse çıkışta modifiye menüsüne, garajdan girildiyse garaja dönülür.
  - Dino açıkken garajın plakaları gizlenir. 3B girdi kapalıdır. GERİ dinoyu kapatır.
  - YAKINDAN İNCELE plakası her karede aracın tepesine yerleşir (`unproject_position`); yalnız bu çapa mutlak konumludur,
    junkyard_screen ile aynı yöntem.
- **Modifiye menüsü** (`mod_workshop.gd`):
  - Üçüncü kart `Menu_dyno` (`dyno_requested` sinyali) eklendi. Kartlar en dar tuvale sığsın diye 330 → 268 piksele indi.
  - Kart resimleri `ui/hud/art/parts/dyno_roller.png` ve `dyno_fan.png` (`tools/parts/part_icons.py`).
  - Çip: en iyi ölçüm varsa onu, yoksa "YENİ" yazar.

## Test / QA
- `tests/dyno_sim_test.gd`: beş araçta tam gaz çekiş ölçüm sayılıyor mu, tepe güç kataloğa denk mi; yüksek devirden
  başlayan çekiş sayılmaz; çekiş tipi; gaz verme (devir pedalı izler, merdane bağlı, kesici, bırakınca rölanti); modifiye.
- `tests/dyno_view_test.gd`: oda, düğümler, merdaneye oturma, ön merdane (Supra, Sprinter, Fiat 500, Tesla), fan,
  kameranın oda içinde kalması, kendiliğinden marş, gaz, yalnız çeken aksın dönmesi (Supra, Sprinter, Fiat 500, Tesla,
  Golf), tam gaz çekişin en iyi ölçüm olması, müzik kısılıp geri gelmesi, motor düzeyi,
  garaj açıkken korna susması, en iyi ölçüm kaydı, çıkışta geri verme.
- `tests/performance_mod_test.gd`: DİNAMOMETRE kartı → dino → GERİ → modifiye menüsü.
- QA betikleri:
  - `qa/dino_qa.gd`: yalnız sahne, üç kamera.
  - `qa/dino_ekran_qa.gd`: oyun içi akışın tamamı (16:9 ve 4:3 denendi); ayrıca müzik düzeyi, SFX tepe düzeyi ve dinodayken
    dışarıdan çalmaya başlayan ses listesi.
  - `qa/dino_his_olcum.gd`: gaz verme hissi (kesiciye / rölantiye süre) araç başına.
  - Çıktılar: `~/Projects/ct_shots/dino/`.
- Çeviriler: EN/ES/DE/FR'ye 13 anahtar eklendi (kalkan düğme / kart metinleri silindi). Çıkarıcıya `SKIP_FILES` (laboratuvarın parametre metinleri) ve birim
  kalıpları (`%d bg`, `%s d/dk`, tork, fabrika) eklendi.

## Açık
- Telefonda denenmedi: girişteki köşe taraması ve GLB yükleme takılması ölçülmedi.
