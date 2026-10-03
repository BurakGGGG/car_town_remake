# ARAÇ TESLİMAT KASASI — Uygulama Raporu

Tarih: 2026-09-29.
- Tasarım: [vehicle_crate_design_v2.md](vehicle_crate_design_v2.md).
- Araştırma: [vehicle_crate_research.md](vehicle_crate_research.md).

Kasa **büyük fiziksel araç teslimat kasasıdır**, UI kutusu değildir. Oyuncunun yaşadığı akış:

> SHOWROOM → kasa sipariş → kasa garaja gelir → oyuncu kasaya dokunur → AÇ → kilitler/kapak/paneller
> açılır → araç 3D dünyada kasadan çıkar → sonuç plakası → KOLEKSİYONA EKLENDİ

- Kasa modellerini kullanıcı üretecek. Bu sürüm **kodla kurulan yer tutucu** kasa kullanır; gerçek GLB `vehicles/crates.json` üzerinden bağlanır (§4).
- Gerçek parayla gem satışı yoktur.

---

## 1. Uygulanan kararlar

| Karar | Nerede |
|---|---|
| Başlangıç aracı ücretsiz **Tofaş Şahin** (bir kez) | `VehicleOwnership.starting_vehicle_id` |
| İlk kasa Sv 2'de görev ödülü (İLK KASA, ŞEHİR) | `QuestCatalog` "first_crate", `QuestManager.claim` → `CrateManager.grant_free` |
| 4 kasa: ŞEHİR 30 · AİLE 50 · SPOR 80 · PRESTİJ 120 gem; Sv 1 / 10 / 14 / 20 | `vehicles/crates.json` |
| Nadirlik: Common / Rare / Epic / Legendary; sınıftan bağımsız | `cars.json` "rarity", `CarCatalog.SCHEMA` |
| Oran = nadirlik ağırlığı (100/40/15/4) / havuz toplamı; sahiplik oranı DEĞİŞTİRMEZ | `CrateCatalog.odds / roll` |
| Kopya olabilir, tekrar koruması yok, pity yok | `CrateManager.open` |
| Kopya → araç yıldızı (1/3/6/10/15 → ★1–5) + gem hurdası (2/5/12/30); ikinci araç oluşmaz | `VehicleOwnership.add_duplicate`, `CrateManager.DUP_SCRAP` |
| Showroom araç SATMAZ; kasa satar + yalnızca keşfedilmiş (satılmış) aracı ₺ ile geri satar | `ShowroomScreen`, `VehicleOwnership.status/purchase_vehicle` |
| Yarışa seçilen araç çıkar; varsayılan Şahin | `VehicleOwnership.race_vehicle_id`, `RaceManager.player_vehicle_id` |
| Oranlar açık: kasa plakasında her aracın yüzdesi | Showroom bilgi plakası, kasa AÇ plakası, koleksiyon kartları |

## 2. Mimari

```
vehicles/crates.json ──► CrateCatalog (statik; oran, havuz, görsel metadata)
                              │
Showroom ─buy()─► CrateManager ("crates")  ── state/save ──► SaveManager v10 (atomik yazım)
                   │   PURCHASED → DELIVERED → WAITING_TO_OPEN → OPENING → REVEALED → CLAIMED
                   │   sonuç SATIN ALMADA çekilir; ödül open()'da bir kez
                   ▼
          CrateDelivery ("crate_delivery", dünya) ── teslimat noktası, kasa kurulumu, açılış sahnesi
                   │                                   dekor görünümüne kasa izlerini engel olarak verir
                   ▼
          CrateVisual (tek kasa) ── yer tutucu ya da scene_path modeli, play_arrival/play_open/vehicle_anchor
HUD: CratePanel (AÇ / sonuç) · CollectionScreen · gem bildirimleri      GemRewards ("gem_rewards")
```

- **Sahne dosyası değişmedi.** Üç yeni yönetici `GarageSystem._ensure_crate_system()` içinde, `DecorManager` gibi kodla kurulur.
- Kurulum **senkrondur**. HUD bağlantılarını Gameplay düğümünden önce kuruyor; ertelenmiş kurulumda yöneticileri bulamazdı.

### 2.1 Kasa durumları ve güvenlik

| Durum | Anlamı | Kayıtta |
|---|---|---|
| PURCHASED | Gem düştü, **sonuç çekildi**; garajda yer bekliyor ("yolda") | evet (araç id'si dahil) |
| DELIVERED | Teslimat noktasına kondu, geliş animasyonu | evet (konum + yön) |
| WAITING_TO_OPEN | Oyuncu açabilir | evet |
| OPENING | `open()` içinde geçici | hiç yazılmaz |
| REVEALED | Ödül verildi, açılış sahnesi sürüyor | evet; yüklemede ödülsüz kapanır |
| CLAIMED | Kasa listeden ve dünyadan kalktı | — |

Güvenlik kuralları:
- **Sonuç satın alma anında belirlenir.** Gem düşümü, kasa + sonuç kaydı ve dosya yazımı aynı çağrıdadır (`CrateManager.buy` → `SaveManager.save_game`).
- **Kayıt atomik yazılır.** `SaveManager.save_game` önce `.tmp` dosyasına yazar, sonra `rename_absolute` ile asıl dosyanın üstüne taşır. `rename_absolute`'un var olan dosyanın üzerine yazdığı Godot 4.7'de denendi. Yazım yarıda kalırsa eski kayıt sağlam kalır.
- **Kapat-aç, kayıt yükleme ve bulut geri yükleme** sonucu değiştirmez: sonuç kasanın verisidir. Test: `crate_test` §7, üç kez yeniden açılış + `apply_snapshot`.
- **Açılış sırasında uygulama kapanırsa** ödül bir kez verilmiştir. REVEALED kasa yüklemede kapanır; çift ödül olmaz. Test: `crate_test` §9.
- **Kopya satılabilir ikinci araç üretmez.** Sahiplik bir kümedir, garaj değeri şişmez. Test: `crate_test` §10.
- **Keşif kalıcıdır.** Satılan araç keşfedilmiş kalır, showroom'dan geri alınır. Hiç keşfedilmemiş araç showroom'da görünmez ve alınamaz. Test: `crate_test` §11, `ui_test` §5.

### 2.2 Teslimat noktası (dekordan ayrı)

- Kasalar `DecorManager`'a **hiç girmez**; Garage Editor onları seçemez ya da taşıyamaz.
- Teslimat noktası garaj zemininde taranır. Kasa izi zemine sığmalı; dekor eşyalarına, tamir alanlarına, genişletme tabelasına ve diğer kasalara değmemeli.
- Bu koşulları sağlayan noktalardan garajın **arka-sol köşesine** en yakın olanı seçilir. Burası izometrik kameranın baktığı iç köşe. İlk QA'de girişe yakın konan kasa, ön-sağda havada asılı "GARAJI GENİŞLET" tabelasının arkasında kalıyordu.
- Ters yönde: `GarageDecorView._rebuild_area` dünyadaki kasa izlerini engel sayar. Dekor kasanın üstüne konamaz (test: `crate_test` §6).
- Yer yoksa kasa PURCHASED ("yolda") kalır ve HUD "garajda yer yok" der. Dekor ya da garaj seviyesi değişince yeniden denenir.
- Seviye 1 garajda (2 × 1,5) iki kasa yan yana sığıyor, ekran görüntüsünde doğrulandı. `MAX_PENDING` = 6.

### 2.3 Seviye ve yarış

- Seviye kısıtı **kasa kapısıyla**: ŞEHİR 1 · AİLE 10 · SPOR 14 · PRESTİJ 20. v1'deki araç başına "−2 seviye" kuralı kullanılmadı (oranları seviyeye göre değiştirip ekrandaki tabloyu yanlış yapardı; tasarım v2 §11).
- **Yarış hatası düzeldi:** `RaceManager.player_vehicle_id()` artık seçili yarış aracını döndürüyor, sahip olunan ilk aracı değil.
  - Garaj ekranına **YARIŞ ARACI YAP** plakası eklendi.
  - Seçili araç satılırsa Şahin'e, o da yoksa ilk araca düşülür.
  - Test: `crate_test` §12.

## 3. Gem ekonomisi (uygulanan)

| Kaynak | Kural | Nerede | Mevcut sisteme bağlantı |
|---|---|---|---|
| Başlangıç + 7 hikâye görevi | 40 + 125 | (vardı) | — |
| İLK KASA görevi | Sv 2 → 1 ücretsiz ŞEHİR kasası | QuestCatalog | QuestManager |
| Seviye | seviye başına 5, her 5.'de +25 | `PlayerProgress.LEVEL_GEMS` | LEVEL_REWARDS akışı |
| Günlük giriş | 10·10·15·10·15·10·40 | `GemRewards.LOGIN_CYCLE` | — |
| Günlük görev (Sv 3+) | 3 görev × 10 + üçü +20 (tamir / tamirden ₺ / yarışa katıl) | `GemRewards.TASKS` | RepairManager, RaceManager sinyalleri |
| Haftalık hedef | haftada 12 görev → 100 | `GemRewards.WEEKLY_*` | — |
| Bahşiş | her 20 tamirde 1, günde en çok 40 | `GemRewards.TIP_*` | repair_collected |
| Ustalık yıldızı | yıldız başına 10 | `GemRewards.MASTERY_STAR_GEMS` | JobMastery.mastery_up |
| Tamir kilometre taşı | 50/250/1.000/2.500/5.000 → 10/20/30/50/75 | `GemRewards.REPAIR_MILESTONES` | JobMastery sayaçlarının toplamı |
| İlk keşif | C 3 · R 8 · E 20 · L 40 | `CrateManager.DISCOVERY_GEMS` | — |
| Koleksiyon kilometre taşı | 5/10/14/16 araç → 15/30/50/100 | `CrateManager.COLLECTION_MILESTONES` | — |
| Kopya hurdası | C 2 · R 5 · E 12 · L 30 | `CrateManager.DUP_SCRAP` | — |

### 3.1 Saat ve kayıt istismarı korumaları

- **Gün numarası yalnızca ileri gider.** Yerel tarihin epoch'tan gün numarası kullanılır.
- **Saat geri alınırsa:** hiçbir günlük ödül verilmez, görevler sıfırlanmaz (yeniden yapılamaz), "saat geri alındı" tespit edilir.
- **Saat ileri alınırsa:** yalnızca o günün girişi alınır; kaçırılan günler telafi edilmez ve seri 1'e döner. Gerçek güne dönülünce o günlere kadar kilit kalır.
- **Her ödül kayıtta işaretlidir** (giriş, görev, görev bonusu, haftalık, bahşiş sayacı). Aynı gün ya da hafta ikinci kez verilmez. İşaretler gemle aynı dosyada durur: eski bir kayda dönmek gemleri de geri alır.
- **Eski kayıtlar:** tamir kilometre taşlarını ilk kontrolde bir kez geriye dönük alır (örnek: 69 tamirlik v7 kaydı → +10). O günün girişi de bir kez verilir.
- **Bulut kaydı:** yeni kurulumda ilk günün giriş gemi başlangıç değerine dahil edilir ve `has_progress()` gem ödülü durumunu karşılaştırmaz. Aksi halde yeni cihaz "ilerleme var" sayılır, Google girişinde bulut kaydı otomatik gelmez, çakışma sorulurdu.
- Test: `crate_test` §14 (giriş, iki kez yok, geri/ileri saat, görevler, bonus, bahşiş tavanı, kayıt turu).

Gem harcama yerleri: kasalar, özel boya (mevcut; `GameFeatures.PAINT` kapalı). İleride dekor/kozmetik için yer bırakıldı; yeni harcama eklenmedi.

## 4. Kasa görselleri — kullanıcının GLB'lerini bağlama

`vehicles/crates.json`, kasa başına:

| Alan | Anlamı | Şu an |
|---|---|---|
| `id` | `city_crate` / `family_crate` / `sport_crate` / `prestige_crate` | — |
| `display_name`, `short_name` | Gösterim adı | ŞEHİR KASASI … |
| `scene_path` | Kasa modeli (.glb / .tscn). **Boşsa yer tutucu** | "" |
| `icon` | Showroom listesi ikonu (Texture2D) | "" (gem simgeli plaka) |
| `open_effect` | Açılışta kasanın üstünde kurulacak sahne | "" (nadirlik renginde ışık patlaması) |
| `color` | Yer tutucu kasanın rengi | kasa başına farklı |
| `scale` | Model farklı ölçekte üretildiyse düzeltme | 1.0 |

Model sözleşmesi (`crates.json` "_readme", `world/crate_visual.gd`):
- kök Node3D; orijin zeminde ve kasanın ortasında; uzun kenar yerel +X boyunca;
- dış ölçü `world_size` = **0,72 × 0,38 × 0,46** dünya birimi. Dünyadaki araç izi 0,37 × 0,60; araç kasaya sığar;
- **isteğe bağlı** `AnimationPlayer` içinde `open` animasyonu → açılışta o oynar;
- **isteğe bağlı** `Marker3D "VehicleAnchor"` → aracın belireceği nokta.

Model bağlandığında ekonomi, RNG, kayıt ve açılış akışı kodu **değişmez**: `CrateDelivery` yalnızca `play_arrival()`, `play_open()` ve `vehicle_anchor()` çağırır. Model yalnızca o kasa dünyaya konduğunda (tembel) yüklenir; metadata açılışta okunur.

Yer tutucu kodla kurulur, yeni asset yoktur. Parçalar: palet, dört yan panel (alt kenardan menteşeli, açılışta dışa yatar), çıtalar, köşe dikmeleri, kapak, iki metal kayış + kilit, havada krem "KASA ADI · DOKUN · AÇ" plakası (dünya-UI katmanı; garaj düzenleme odağında gizlenir).

## 5. Koleksiyon ekranı

`ui/hud/collection_screen.gd` — showroom ve garaj ekranındaki **KOLEKSİYON** plakasından açılır.

- **Başlık:** "KOLEKSİYON n / 16". Gruplar: BAŞLANGIÇ + dört kasa, her biri "k / m".
- **Kartlar:**
  - nadirlik + sınıf,
  - küçük render,
  - ad ("???" keşfedilmemişse),
  - durum: GARAJINDA / ★ ve kopya sayısı / "SATILDI · SHOWROOM'DA GERİ AL" / "ŞEHİR · %5,1".
- **Siluet:** aracın mevcut küçük render'ı tamamen siyaha boyanır. İlk sürümde kırmızı araçların rengi sızıyordu; düzeltildi.
- **Render:** mevcut `CarGallery` üreticisi kullanılır (ayrı bir render sistemi yok).
- **Nadirlik çerçevesi:** Epic 3 px, Legendary 4 px + nabız gibi parlayan altın çerçeve. "Son parça" kartı 5 px ve "SON PARÇA" etiketi taşır.
- **Setler:** 7 koleksiyon seti ilerlemesiyle listelenir. **Set ödülleri henüz verilmiyor** (plaket / XP / garaj değeri; §9).

## 6. Değişen / eklenen dosyalar (bu görev)

| Dosya | Değişiklik |
|---|---|
| `vehicles/crates.json` (yeni) | 4 kasa, nadirlik ağırlıkları, dünya ölçüsü, görsel metadata, 7 set |
| `vehicles/cars.json` | 16 araca `rarity` (yalnızca ekleme; biçim korundu) |
| `vehicles/car_catalog.gd` | SCHEMA'ya `rarity` |
| `gameplay/crate_catalog.gd` (yeni) | Kasa/nadirlik/set kataloğu, oranlar, `roll` |
| `gameplay/crate_manager.gd` (yeni) | Satın alma, sonuç, durumlar, açılış, kopya/keşif/koleksiyon gemi, kayıt |
| `gameplay/gem_rewards.gd` (yeni) | Giriş, günlük/haftalık görev, bahşiş, ustalık, tamir taşları, saat koruması |
| `gameplay/vehicle_ownership.gd` | Şahin başlangıcı, keşif kümesi, kopya/yıldız, yarış aracı, geri alma, `UNDISCOVERED` |
| `gameplay/save_manager.gd` | v10, atomik yazım, crates/gem_rewards/koleksiyon alanları, göç, `has_progress` |
| `gameplay/player_progress.gd` | Seviye gemi; kasa açılış metinleri |
| `gameplay/quest_catalog.gd`, `quest_manager.gd` | İLK KASA görevi, "crate" ödülü |
| `gameplay/race/race_manager.gd`, `ui/hud/drag_race_screen.gd` | Seçili yarış aracı; E46 yedekleri kaldırıldı |
| `garage_system.gd` | Kasa yöneticilerinin kodla kurulumu |
| `world/crate_delivery.gd` (yeni) | Teslimat noktası, kasa kurulumu, açılış sahnesi, araç çıkışı, kamera |
| `world/crate_visual.gd` (yeni) | Yer tutucu / GLB kasa, geliş/açılış animasyonu, dokunma kutusu, plaka |
| `world/garage_decor_view.gd` | Kasa izleri dekor engeli |
| `ui/hud/showroom_screen.gd` | Kasa listesi + GERİ AL, kasa önizlemesi, açık oranlar, KOLEKSİYON |
| `ui/hud/crate_panel.gd` (yeni) | AÇ ve sonuç plakası (içerik açılmadan gizli) |
| `ui/hud/collection_screen.gd` (yeni) | Koleksiyon panosu |
| `ui/hud/hud.gd` | Kasa akışı, gem bildirimleri, koleksiyon kaydı, seviye gemi bildirimi |
| `ui/hud/garage_screen.gd` | YARIŞ ARACI YAP ve KOLEKSİYON plakaları |
| `ui/hud/car_gallery.gd` | Thumbnail önbelleğine dış erişim + sinyal |
| `ui/hud/quest_screen.gd` | Kasa ödülü metni |
| `tests/crate_test.gd` (yeni) | 87 kontrol |
| `tools/economy/crate_sim.py` (yeni) | 100.000 oyunculuk simülasyon (gerçek JSON'u okur) |
| `qa/sim_progress.gd` | Kasa ekonomisiyle otomatik oyuncu, ₺ harcaması kalem kalem |
| `qa/crate_qa.gd`, `qa/crate_perf.gd` (yeni) | Görsel QA ve performans ölçümü |
| `tools/run_tests.sh` | `crate_test` listede |
| `docs/vehicle_crate_research.md` | v2 eki (kopya ekonomileri, Kore/Brezilya/Hollanda) |

Depo dışı test paketleri (`~/snap/godot-4/common/cloudtest`, bilinçli davranış değişikliği için güncellendi, `.v9.bak` kopyaları duruyor):
- `save_test`: 40+10 gem, Şahin, v7 karşılaştırması.
- `quest_test`: İLK KASA sırası.
- `cloud_test`: başlangıç aracı Şahin.
- `decor_test`: kayıt v10.
- `ui_test`: §5 showroom kasa plakası, §9 kasa satın al → teslimat → AÇ → sonuç → garaj → koleksiyon.

Depodaki `tests/garage_decoration_placement_test.gd`: sürüm kontrolü `SAVE_VERSION`'a bağlandı.

## 7. Test sonuçları

`tools/run_tests.sh` (yalıtılmış kullanıcı dizini, her paket temiz kayıtla):

| Paket | Önce (bu görevden önce) | Sonra |
|---|---|---|
| save_test | 27 / 0 | 29 / 0 |
| edge_test | 34 / 0 | 34 / 0 |
| quest_test | 28 / 0 | 28 / 0 |
| paint_test | 27 / 0 | 27 / 0 |
| cloud_test | 50 / 0 | 50 / 0 |
| drag_transmission_test | 38 / 0 | 38 / 0 |
| vehicle_wheel_test | 17 / 0 | 17 / 0 |
| decor_test | 118 / 0 | 118 / 0 |
| garage_decoration_placement_test | 169 / 0 | 169 / 0 |
| **crate_test (yeni)** | — | **87 / 0** |
| ui_test | 47 / 0 | 57 / 0 |
| race_test | 49 / 0 | 49 / 0 |
| progression_test | 33 / 0 | 33 / 0 |
| vehicle_asset_test | 328 / 0 | 328 / 0 |
| vehicle_scale_test | 106 / 0 | 106 / 0 |
| **Toplam** | **1.071 / 0** | **1.170 / 0** |

**Değişikliklerden sonraki ilk tam koşuda 15 hata çıktı.** Hepsi bilinçli davranış değişikliğine dayanan eski beklentilerdi:
- başlangıç aracı E46,
- 40 gem,
- görev listesinin sırası,
- sabit kayıt sürümü 9,
- v7 kaydının birebir geri yazılması.

Test beklentileri yeni davranışa göre güncellendi; oyun kodunda bunlar için değişiklik yapılmadı. `crate_test` ise ilk koşusunda **gerçek bir hata** buldu: günlük görev metninde `%d` biçimine metin veriliyordu. Görev sayılıyordu ama metin boş çıkıyordu; kodda düzeltildi.

İstenen kontroller → test:

| İstenen | Test |
|---|---|
| 30 gem ile ŞEHİR kasası, gem doğru düşüyor | crate_test §4, ui_test §9 |
| Büyük fiziksel kasa garaja geliyor | crate_test §4 (dünyada CrateVisual, ölçü ≥ araç), ui_test §9, ekran görüntüleri |
| Kasa kaydediliyor, kapat-aç sonrası hâlâ orada, sonuç değişmiyor | crate_test §4 (aynı yazımda diskte), §7 (3 yeniden açılış + aynı konum) |
| Kasa açılıyor, doğru araç çıkıyor, araç 3D dünyada | crate_test §8, ui_test §9 |
| Koleksiyona ve garaj değerine doğru ekleniyor | crate_test §8 |
| Kasa kaldırılıyor | crate_test §8, ui_test §9 |
| Kopya çıkabiliyor, ödülü doğru | crate_test §10 (★1, +2 gem, araç sayısı ve garaj değeri aynı) |
| İki kasa aynı anda bekleyebiliyor | crate_test §5 (ayrı, çakışmayan noktalar) |
| Dekor düzenleme sistemine girmiyor | crate_test §6, decor_test, garage_decoration_placement_test |
| Yarış bozulmuyor, seçili aracı kullanıyor | crate_test §12, race_test |
| Showroom bozulmuyor | ui_test §1, §5, §9 |
| SaveManager doğru; eski kayıt göçü | crate_test §7, §9, §13; save_test; cloud_test |
| Şahin ilk açılışta var, ikinci kez verilmiyor | crate_test §1–2, save_test |
| İlk ücretsiz kasa bir kez | crate_test §3 |
| Oranlar istatistiksel olarak tutarlı | crate_test §15: kasa başına 200.000 çekiliş, en büyük sapma 1,74 σ (sınır 4,5 σ) |
| Satılan araç keşfedilmiş kalıyor | crate_test §11 |
| Bulut geri yükleme sonucu değiştirmiyor | crate_test §7 (`apply_snapshot`) |
| Günlük/haftalık ödül iki kez yok, saat istismarı yok, tavanlar | crate_test §14 |
| Garaj değeri kopyayla şişmiyor | crate_test §10 |

Görsel QA (`qa/crate_qa.gd`, 1170 × 540, `/home/burak/Projects/ct_shots/crate/`):
- geliş,
- teslim edilmiş kasa,
- yan yana iki kasa,
- AÇ plakası,
- kapak ve panel açılışı,
- ortaya çıkan araç,
- showroom ŞEHİR / PRESTİJ,
- koleksiyon.

QA'de bulunup düzeltilenler:
- kasa havadaki genişletme tabelasının arkasında kalıyordu (teslimat noktası arka-sol köşeye alındı);
- sonuç plakası çıkan aracı örtüyordu (açılış kadrajı ekranın üst yarısına alındı);
- kasa etiketi okunmuyordu (krem tabela plakası yapıldı);
- siluetlerde kırmızı araçların rengi sızıyordu (tam siyah yapıldı).

## 8. Ekonomi simülasyonu

### 8.1 Gem ve koleksiyon — 100.000 oyuncu

`python3 tools/economy/crate_sim.py all --players 100000`. Oyunun gerçek `cars.json` / `crates.json` verisini okur; sonuçlar tasarım v2 ile birebir aynı.

Açılan kasa sayısına göre koleksiyon (16 araç, Şahin dahil):

| Kasa | Medyan | P25 | P75 | P90 | P95 | 16/16 | E60 | E46 | Kopya | Gem |
|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 8 | 7 | 9 | 10 | 10 | 0,0 % | 1,2 % | 3,5 % | 3,0 | 456 |
| 25 | 12 | 11 | 13 | 13 | 14 | 0,1 % | 7,8 % | 10,9 % | 14,3 | 1.319 |
| 50 | 14 | 13 | 15 | 15 | 16 | 7,2 % | 15,3 % | 36,0 % | 37,2 | 2.912 |
| 100 | 16 | 15 | 16 | 16 | 16 | 50,2 % | 52,5 % | 79,8 % | 85,7 | 7.647 |
| 200 | 16 | 16 | 16 | 16 | 16 | 94,2 % | 94,3 % | 99,1 % | 185,1 | 19.333 |

16/16 için gereken kasa: medyan 100, P75 136, P90 178. En şanssız %5,8 200 kasada bile bitiremiyor.

Günlük ilerleme (medyan araç, 16'da):

| Profil | 1. gün | 3. gün | 7. gün | 14. gün | 30. gün | 30. gün E60 | 30. gün 16/16 | 30 günde kazanılan / harcanan gem |
|---|---|---|---|---|---|---|---|---|
| CASUAL (20 dk) | 4 | 7 | 10 | 12 | 14 | 11,5 % | 3,0 % | 2.580 / 2.526 |
| ACTIVE (60 dk) | 7 | 10 | 12 | 14 | 15 | 20,4 % | 14,7 % | 4.044 / 3.857 |
| HEAVY (150 dk) | 9 | 11 | 13 | 14 | 15 | 25,8 % | 21,2 % | 4.662 / 4.362 |

ACTIVE, 30. gün:
- açılan kasa 65,4;
- kopya 51,8 (Common 43,2 · Rare 7,0 · Epic 1,6 · Legendary 0,06);
- gem kaynakları: günlük görev 1.500 · giriş 460 · haftalık 400 · bahşiş 330 · ustalık 320 · seviye 300 · tamir taşları 185 · hikâye 165 · kopya hurdası 142 · keşif 137 · koleksiyon 105.

### 8.2 ₺ ekonomisi — gerçek oyun, 600 dakika

Gerçek oyun 600 dakikalık ₺ simülasyonu QA raporunda: [crate_system_qa_report.md](crate_system_qa_report.md) §10.2.

## 9. Performans

QA turundaki iyileştirmelerden sonraki ölçümler (`qa/crate_perf.gd`). Ayrıntı: [crate_system_qa_report.md](crate_system_qa_report.md) §11.

| Durum | En uzun kare | Çizim | VRAM |
|---|---|---|---|
| Kasasız | 22,3 ms | 287 | 84,2 MB |
| 6 kasa (seviye 4 garaj) | 18,1 ms | 536 | 84,3 MB |
| Açılış sahnesi | 17,5 ms | 730 | 92,7 MB |

- `buy()` 2,5 ms (önce 73,9 ms).
- AÇ → sonuç plakası 2,07 sn.
- Bekleyen kasa kare başına iş yapmaz.

## 10. Kalan sorunlar ve yapılmayanlar

1. **Kasa modelleri yer tutucu.** Kullanıcının GLB'leri `vehicles/crates.json` `scene_path` alanına bağlanacak (§4). `icon` ve `open_effect` de boş. Showroom listesi gem simgeli plaka, açılış efekti nadirlik renginde ışık patlaması.
2. **Koleksiyon seti ödülleri verilmiyor.** Setlerin ilerlemesi koleksiyon ekranında görünüyor. Plaket (dekor ödül eşyası), XP ve garaj değeri bonusu ayrı bir iş.
3. **Legendary kuyruğu:** E60'ı %95 olasılıkla görmek 107 PRESTİJ kasası istiyor (aktif oyuncuda ~116 gün). Kullanıcı kararıyla pity yok; tasarım v2 §18'deki pity olmayan seçenekler (haftalık PRESTİJ anahtarı, indirim haftası) bekliyor.
4. **Açılış sonrası boş kasa kalmıyor.** Kasa ve araç küçülerek kayboluyor ("araç garaja gitti"). Aracın garaja sürerek girmesi ve boş kasanın depoya dönüşmesi sonraki animasyon işi.
5. **Seviye 1 garajda "GARAJI GENİŞLET" tabelası** ikinci kasanın alt kenarına hâlâ biraz biniyor (tabela havada ve kameraya dönük). İlk kasa arka-sol köşede tamamen açık.
6. **Teslimat yeri garaja bağlı:** zemin dekorla doluysa kasa "yolda" bekler ve HUD uyarır. Ayrı bir depo alanı yok (brif "yoksa büyük sistem kurma" diyordu).
7. **Günlük görev ve giriş gemi cihaz saatine bağlı.** Geri alma ve ileri alma korumaları var (§3.1). Saati her gün bir gün ileri alan bir oyuncu, geri dönene kadar fazladan giriş gemi alabilir; dönünce o günler kilitlenir. Sunucu saati yok.
8. **Hukuki:** gem gerçek parayla satılmıyor, bu yüzden kasalar "ücretli loot box" değil. Brezilya ECA Digital (2026-03-17) çocukların erişebileceği oyunlarda loot box'ı yasaklıyor; kazanılan parayla açılan kutunun kapsamda olup olmadığı net değil. Yayından önce hukuki görüş alınmalı.
9. **Koleksiyon ekranı ilk açılışta** 16 aracın küçük render'ını kare başına 2 araç olarak üretir. Tek seferlik kısa yükleme; sonra önbellekten gelir.
10. **Depo dışı test paketleri güncellendi** (`~/snap/godot-4/common/cloudtest`): bunlar git'te değil, `.v9.bak` kopyaları duruyor.
