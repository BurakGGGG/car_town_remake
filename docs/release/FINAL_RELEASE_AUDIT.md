# AUTO YARD FINAL RELEASE AUDIT

Tarih: 2026-10-02 · Dal: `ilerleme-refactor` · Kapsam: bu oturumda masaüstünde çalıştırılan testler + gerçek release AAB derlemesi.

## Overall Status

**NOT RELEASE READY**

Neden: (1) gerçek yükleme (upload) anahtarı yok, AAB debug anahtarıyla imzalı → Play'e yüklenemez; (2) gerçek Android cihazda hiçbir test yapılmadı (cihaz bağlı değil); (3) paket kimliği kararı bekliyor; (4) Play Console formları ve Firebase SHA-1 işleri açık. Kod tarafında bulunan crash/ikon/kimlik hataları düzeltildi.

## Test Summary

Total tests: **1289 kontrol / 18 paket** (`tools/run_tests.sh`, yalıtılmış kayıt)
Passed: 1289
Failed: 0
Skipped: Android cihaz testleri, Play pre-launch, performans (cihaz), 10–20 dk bellek sızıntısı testi — **NOT TESTED**

| Paket | OK | FAIL |
|---|---|---|
| save_test | 29 | 0 |
| edge_test | 34 | 0 |
| quest_test | 29 | 0 |
| paint_test | 27 | 0 |
| account_delete_test | 53 | 0 |
| login_flow_test | 49 | 0 |
| drag_transmission_test | 38 | 0 |
| vehicle_wheel_test | 17 | 0 |
| decor_test | 118 | 0 |
| garage_decoration_placement_test | 169 | 0 |
| crate_test | 96 | 0 |
| **release_test (YENİ)** | 43 | 0 |
| ui_test | 57 | 0 |
| login_reload_test | 14 | 0 |
| race_test | 49 | 0 |
| progression_test | 33 | 0 |
| vehicle_asset_test | 328 | 0 |
| vehicle_scale_test | 106 | 0 |

Önceki toplam 1246 (düzeltmelerden önce, 0 hata). "600+ QA" iddiası bu oturumda yeniden sayıldı: bu 18 paket. `qa/` altındaki görsel/ölçüm betikleri (ekran görüntüsü, perf) çalıştırılmadı.

Ek model testi: `tools/economy/scalability_test.py` → **91.544 kontrol, 0 hata** (16 gerçek + 20/50/100/200 sentetik araç × 8 dağılım). Bu **Python tasarım modeli**; doğrudan satın alma oyun kodunda henüz uygulanmış değil (belge: "TASARIM, oyun kodu değişmedi").

## P0

**P0-1 — Yükleme anahtarı yok / AAB debug imzalı. (AÇIK, kullanıcı işi)** `keytool` ile bir upload keystore üretilip `GODOT_ANDROID_KEYSTORE_RELEASE_*` ortam değişkenleriyle verilmeli; Play App Signing açılmalı. Anahtar kimliği/parolası kullanıcıya ait olduğu için oturumda üretilmedi.

**P0-2 — Eski Godot ikonu (DÜZELTİLDİ).** Proje ikonu varsayılan Godot `icon.svg` idi; Android launcher'da Godot logosu çıkacaktı. Ayrıca Android 13+ "temalı ikon" (monokrom katman) otomatik Godot robot başı olarak paketleniyordu (AAB içinde görüldü). Düzeltme: AUTO YARD ikonu proje/launcher/adaptive (ön+arka) + logodan türetilmiş monokrom siluet; AAB'den çıkarılıp görsel doğrulandı.

**P0-3 — Bozuk kayıt oyunu çökertiyordu (DÜZELTİLDİ).** 52 alan × 10 kötü değer fuzz'ı: `int(null)`, `int([])`, `String({})`, `bool(null)` GDScript çalışma zamanı hatası verip yüklemeyi yarıda kesiyordu (SaveManager, VehicleOwnership, GemRewards, DecorManager, CrateManager). Yeni `gameplay/save_safe.gd` ile tüm yükleme yolları güvenli. Sonra: 520 bozuk kayıt, 0 değişmez ihlali, 0 SCRIPT ERROR.

**P0-4 — Android GERİ tuşu uygulamayı her yerde kapatıyordu (DÜZELTİLDİ, cihazda doğrulanmadı).** `quit_on_go_back=false` + `UiRouter` işleyicisi: açık pano kapanır, kasa "hazır" panosu kapanır, kasa sonuç panosu GERİ ile geçilmez, kök garajda 2 sn içinde ikinci GERİ ile çıkış ("Çıkmak için tekrar GERİ'ye bas"). Router mantığı 5 testle doğrulandı; gerçek `NOTIFICATION_WM_GO_BACK_REQUEST` yolu cihazda **denenmedi**.

## P1

1. **Sahte SES düğmesi (DÜZELTİLDİ).** Projede hiç ses dosyası / AudioStreamPlayer yok; HUD'daki SES düğmesi hiçbir şeyi susturmuyordu. `hud.gd` `AUDIO_AVAILABLE=false` ile düğmeyi gizliyor (sahne dosyasına dokunulmadı). Ayar/Settings düğmesi zaten yok.
2. **Firebase / Play SHA-1 (AÇIK, konsol).** Mağaza sürümü Play App Signing anahtarıyla imzalanır; o SHA-1 Firebase'e eklenmezse Google girişi `DEVELOPER_ERROR (10)` verir.
3. **Paket kimliği `com.cartownBurak.app` (AÇIK, karar).** Eski/test adı taşıyor; Play'de yayınlandıktan sonra değiştirilemez. Değiştirilirse: yeni Firebase Android uygulaması + yeni `google-services.json` + SHA-1. Henüz yayında olmadığı için en ucuz an şimdi. Otomatik değiştirilmedi (Firebase kimlik doğrulamasını bozar).
4. **Hesap silme gerçek telefonda denenmedi** (Google yeniden doğrulaması). Play politikası zorunlu tutuyor.
5. **Gerçek cihaz testi yok** (aşağıda).
6. **Çökme raporlama yok** — yayından sonra çökmeleri görmek için yalnız Play Console vitals kalır.

## P2

1. `<profileable android:shell="true">` Godot şablonundan geliyor; yayında gereksiz (performans profilleme izni). Şablon özelleştirmesi gerekir.
2. `qa/dokunma_testi.gd` SES düğmesine dokunma senaryosu içeriyor; düğme gizli olduğundan o senaryo artık anlamsız (suite dışı).
3. Doğrudan araç satın alma yalnızca tasarım; oyunda yok. Direktif "mevcut sistemleri koru, yeni özellik yok" olduğundan uygulanmadı.
4. Tüm kullanıcı metinleri için otomatik yazım/Türkçe karakter taraması yapılmadı (**NOT TESTED**).
5. `export_presets.cfg` export yolu `../AutoYard_release/AutoYard.aab` olarak değiştirildi (önceden `../../Desktop/TamirciOyunu.apk`).

## P3

- Kilitsiz ekonomi geç oyun ₺ çıkışı: `tools/economy` modeli 10 saat sonunda 20.314 ₺ bakiye veriyor (tasarım raporu); gerçek 10 saatlik oyun testi bu oturumda yapılmadı → **ECONOMY DESIGN RISK**, bug değil.
- Final kasa modeli placeholder (kodla kurulan kutu); `crates.json` `scene_path` boş bırakıldığında placeholder kurulur — gerçek asset hook'u mevcut, sistem bozulmadı.
- Erişilebilirlik: yarış vites göstergesinde yalnızca renk mi kullanılıyor? **İncelenmedi.**

## Build

Godot: 4.7.2.stable.mono (GL Compatibility)
Target SDK: 36
Min SDK: 24
Package: com.cartownBurak.app
Version: 1.0.0
Version Code: 1
AAB: `~/Projects/AutoYard_release/AutoYard.aab` — 128.9 MB, derleme **PASS**, hata yok (yalnızca zararsız "EditorSettings not instantiated" günlüğü)
Signing: **FAIL için Play** — yalnızca debug anahtarı (CN=Android Debug)

## Logo

Kaynak (kullanıcı onaylı): `~/Projects/ct_shots/store/final/logo_plaka_512_seffaf.png` — 512×512 RGBA, şeffaf arka plan, AUTO YARD plaka logosu. Piksel değiştirilmedi.
512x512 source: `assets/branding/icon_512.png` (birebir kopya) — PASS
Project icon: `res://assets/branding/icon_512.png` — PASS; eski Godot `icon.svg` silindi
Launcher icon: `launcher_192.png` = logo (yalnızca küçültüldü) logodaki mavi blok renginde (#2464CD) düz zemin üzerinde (şeffaf PNG legacy ikonda siyah çıkmasın diye); adaptive ön plan = logo %60 ölçekte güvenli bölgede; adaptive arka plan = aynı düz mavi; monokrom = plaka siluet maskesi — PASS
Release AAB icon: PASS (xxxhdpi `icon`, `icon_foreground`, `icon_background`, `icon_monochrome` AAB'den çıkarılıp görsel doğrulandı; AAB yeniden derlendi 128,9 MB)
Not: düz mavi zemin logoya eklenen bir tasarım kararıdır (logo şeffaf olduğu için adaptive ikon zemin ister); rengi değiştirmek isterseniz `adaptive_background_432.png`/`launcher_192.png`. Monokrom harfler hafif tırtıklı. 192 px okunabilirliği cihazda denenmedi.

## Save

43 paket-içi kontrol (release_test) + save_test 29 + edge_test 34. Kasa satın alma/bekleme/açma, tamir, dekor, satış, geri alma, yarış, görev, ustalık için **kullanıcı akışları "kaydet → zorla kapat → aç" cihazda denenmedi**; yerine kaydet→yükle tur testleri (kasa durumu birebir aynı kalıyor) ve atomik yazım (`.tmp` → rename) kod incelemesi var. Fuzz: 520 bozuk kayıt / 0 ihlal; v1–v9 göç: 9/9; kök bozuk kayıt: 9/9 reddedildi, çökme yok.

## Economy

`EconomyManager`: negatif `add` yok sayılır, yetersiz harcama bakiyeyi değiştirmez, `set_money` negatifi 0'a çeker, çift 100 ₺ harcaması ikincisinde başarısız (test). Tüm `add_money` çağrıları (tamir, görev, yarış, ustalık, satış, seviye ödülü) kod olarak tarandı. Çift ödül senaryoları (yarış/tamir/görev/ustalık tekrarı) için yalnızca mevcut paketlerin (race/quest/progression/crate) kapsadığı kadar doğrulandı; her biri ayrı ayrı yeniden yazılmadı.

## Vehicles

16 araç: `cars.json` zorunlu alanlar (id, marka, model, yıl, fiyat, nadirlik, sınıf, seviye, scene/optimized yolu, boyutlar, model_scale, yarış değerleri, renk) → **16/16 tam, dosyalar mevcut, kimlik tekrarı yok**. Nadirlik: 7 common, 4 rare, 3 epic, 2 legendary. `vehicle_asset_test` 328 + `vehicle_scale_test` 106 kontrol geçti. Ekonomi/gameplay klasörlerinde `e46/sahin/toros` gibi araç-id sabit kodu **bulunmadı** (grep). Şahin/Toros/Audi A3'ün GARAGE/SHOWROOM/TRAFFIC/DRAG/CRATE ekranlarında yakın plan görsel kontrolü bu oturumda **yapılmadı** (NOT TESTED).

## Crates

crate_test 96 + release_test: 4 kasa × 20.000 çekiliş, beklenen ağırlıktan en kötü sapma 0,0024; havuz dışı araç çıkmadı; sonuç satın almada kaydediliyor ve kaydet→yükle sonrası aynı; aynı kasa iki kez açılamıyor, `claim` tekrarı gem vermiyor. Uygulama öldürme/arka plan/gerçek cihaz **NOT TESTED**.

## Repairs

Mevcut paketler (progression, edge, save) kapsamında. Her tamir türü için süre/ödül/XP tek tek bu oturumda yeniden ölçülmedi. Boya altyapısı: paint_test 27 geçti; boya arayüzünün oyuncuya kapalı olduğu `paint_panel` varlığına rağmen **bu oturumda UI'dan doğrulanmadı**.

## Garage / Garage Editor / Mastery / Quests

garage_decoration_placement_test 169, decor_test 118, quest_test 29, progression_test 33 geçti (yerleştirme, sınır, kayıt, seviye). Fare/dokunma + UI giriş yalıtımı ve hızlı yerleştirme sömürüsü için ek test yazılmadı.

## Drag Race

drag_transmission_test 38, race_test 49 geçti. "RaceManager ilk katalog aracını seçmiyor, seçili sahip olunan aracı kullanıyor" ayrıca incelenmedi (NOT TESTED). Gerçek Android dokunma testi yok. Hata ayıklama katmanı yalnız `DRAG_DEBUG` env / editör+`--drag-debug` ile açılıyor, release'te kapalı.

## UI

ui_test 57 geçti. `UiRouter` max 2 katman, tek ESC/GERİ işleyicisi, 5 yeni GERİ testi. Çözünürlük matrisi (1040×480, 1152×648, 1170×540 …) için ekran görüntüsü taraması bu oturumda **çalıştırılmadı**.

## Touch

Cihaz yok → **NOT TESTED**. `tests`/`qa` içindeki masaüstü dokunma emülasyonu çalıştırılmadı.

## Android Lifecycle

INSTALL / LAUNCH / BACKGROUND / RESUME / FORCE CLOSE / UNINSTALL: **NOT TESTED** — `adb devices` boş; emülatör yüklü değil (`~/Android/Sdk/emulator` yok; `/dev/kvm` var, kurulabilir).

## Performance

Bkz. PERFORMANCE_REPORT.md. Bu oturumda **yeni ölçüm alınmadı**; yalnızca önceki oturumların kayıtlı ölçümleri aktarıldı.

## Memory

20× sahne döngüsü sızıntı testi: **NOT TESTED**. Headless test çıkışında "ObjectDB instances were leaked at exit" uyarısı var (test kapanışında, oyun akışında değil; oyun içi sızıntı kanıtı değil).

## Audio

Projede ses varlığı yok. Sahte düğme gizlendi. Gerçek ses eklenmeden "ses" vaadi yok.

## Privacy / Data

Firebase Auth (Google, opsiyonel) + Firestore `players/{uid}`; reklam/analitik/IAP yok. Hesap silme uygulama içinde var (53 test). Web sitesi ayrı repoda. Data safety formu konsolda doldurulmalı: toplanan veri = hesap kimliği/e-posta (Google girişi), oyun kaydı.

## Google Play

Bkz. GOOGLE_PLAY_REQUIREMENTS.md. Hedef API 36 ✅, 64-bit ✅, AAB ✅, boyut ✅; imza ❌; konsol formları açık; pre-launch raporu **NOT TESTED** (AAB henüz yüklenmedi).

## Remaining Risks

1. Cihazda hiç koşulmamış release derlemesi (özellikle GERİ tuşu, ikon, Google girişi, hesap silme).
2. Paket kimliği kararı.
3. Doku/VRAM ve kare süresi için güncel cihaz ölçümü yok (önceki ölçümler: garaj ~1150 çizim çağrısı).
4. Yazım/Türkçe karakter, çözünürlük matrisi, erişilebilirlik (yalnız-renk) taramaları yapılmadı.

## Exact Files Changed

MODIFIED (bu oturumda dokunulanlar; depoda zaten başka değişiklikler vardı):
project.godot
export_presets.cfg
ui/hud/ui_router.gd
ui/hud/hud.gd
ui/hud/crate_panel.gd
gameplay/save_manager.gd
gameplay/vehicle_ownership.gd
gameplay/gem_rewards.gd
gameplay/decor_manager.gd
gameplay/crate_manager.gd
gameplay/quest_manager.gd
gameplay/job_mastery.gd
gameplay/garage_upgrade_manager.gd
tools/run_tests.sh
tests/login_flow_test.gd
tests/login_reload_test.gd
tests/account_delete_test.gd

ADDED:
gameplay/save_safe.gd (+ .uid)
tests/release_test.gd (+ .uid)
assets/branding/icon_512.png, launcher_192.png, adaptive_foreground_432.png, adaptive_background_432.png, adaptive_monochrome_432.png (+ .import)
docs/release/FINAL_RELEASE_AUDIT.md
docs/release/RELEASE_CHECKLIST.md
docs/release/KNOWN_ISSUES.md
docs/release/GOOGLE_PLAY_REQUIREMENTS.md
docs/release/PROJECT_INVENTORY.md
docs/release/PERFORMANCE_REPORT.md
(depo dışı: ~/Projects/AutoYard_release/AutoYard.aab)

DELETED:
icon.svg
icon.svg.import
