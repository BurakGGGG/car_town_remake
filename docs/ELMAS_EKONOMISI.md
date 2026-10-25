# Elmas (gem) ekonomisi ve gerçek parayla gem satışı — 2026-10-11

## Karar
- Gem kazanmak zorlaştı: düzenli oyuncu (7.–30. gün) günde **~31–37 gem** kazanıyor (önce 84–127).
- Gerçek parayla gem satışı eklendi (Google Play Billing, tüketilebilir ürünler).
- Ödüllü reklam gem VERMEZ. "Reklamları kaldır" ürünü YOK.
- Giriş ödülü (`GemRewards.LOGIN_CYCLE`) korundu; kasa fiyatları (30–200) ve boya fiyatları değişmedi.
- 2026-10-22: satın almalar sunucuda doğrulanıyor (aşağıda "Sunucu doğrulaması").

## Kısıntılar
| Kaynak | Önce | Sonra | Yer |
|---|---|---|---|
| Günlük 5/5 bonusu | 40 | 10 | `MissionCatalog.DAILY_BONUS_GEMS` |
| Haftalık görev başına | 10 | 0 (₺ / XP kalır) | `MissionCatalog.WEEKLY_GEMS` |
| Haftalık büyük ödül | 120 + kasa | 40 + kasa | `MissionCatalog.WEEKLY_BONUS_GEMS` |
| Başarım yıldızı | 5·15·30·60·100 | değerin %20'si (1·3·6·12·20) | `MissionCatalog.ACH_GEM_SHARE` |
| Tamir bahşişi | 20 tamirde 1, günde ≤40 | 50 tamirde 1, günde ≤3 | `GemRewards.TIP_*` |
| Ustalık yıldızı | 10 | 3 | `GemRewards.MASTERY_STAR_GEMS` |
| Seviye | 5, her 5.'de +25 | 2, her 5.'de +10 | `PlayerProgress.LEVEL_GEMS*` |
| Keşif (C/R/E/L) | 3/8/20/40 | 1/3/8/15 | `CrateManager.DISCOVERY_GEMS` |
| Kopya hurdası | 2/5/12/30 | 1/2/5/12 | `CrateManager.DUP_SCRAP` |
| Koleksiyon taşları | 15/30/50/100 | 5/10/20/40 → 2026-10-25: 10/20/40/80/150 (10/20/35/50/72 araç) + set ödülleri | `CollectionRewards.MILESTONES` (docs/KOLEKSIYON.md) |

Başarımların ₺ ve XP ödülü DEĞİŞMEDİ: artık gemden değil başarımın "değer"inden türer
(`ach_value × 60 ₺`, `× 6 XP`). Başlangıç gemi (40) ve hikâye görevleri (125) ilk kasalar için aynen kaldı.

Ölçüm: `python3 tools/economy/crate_sim.py days` (oyundaki sabitleri okur, uyuşmazsa durur).
Başarımların yalnızca dakikadan ölçülebilen çizgileri sayılır → gerçek gelir biraz daha yüksektir
(tahmin +3–6 gem/gün, ilk ay). Hedefe tam inmek gerekirse sıradaki kaldıraç giriş ödülü (~15/gün).

| Profil | İlk hafta gem/gün | 7.–30. gün gem/gün | 30. günde kasa | 30. günde araç (22'den) |
|---|---|---|---|---|
| CASUAL 20 dk | 66 | 31 | 24 | 12 |
| ACTIVE 60 dk | 72 | 37 | 24 | 13 |
| HEAVY 150 dk | 60 | 37 | 25 | 14 |

## Paketler (`gameplay/purchases/gem_products.gd`)
Kimlikler Play Console'daki **tek seferlik ürün** kimlikleriyle birebir aynı olmalı. Fiyat oyunda yazmaz,
Play'den oyuncunun para biriminde gelir; aşağıdaki USD konsola girilecek taban fiyattır.

| Kimlik | Gem | Taban fiyat | Gem / $ | Not |
|---|---|---|---|---|
| `starter_pack` | 400 | 1,99 $ | 201 | tek seferlik (oyun gizler) |
| `gems_pack_1` | 100 | 0,99 $ | 101 | |
| `gems_pack_2` | 550 | 4,99 $ | 110 | +%10 |
| `gems_pack_3` | 1200 | 9,99 $ | 120 | +%20 |
| `gems_pack_4` | 2600 | 19,99 $ | 130 | +%30 |

0,99 $ ≈ 3 günlük ücretsiz kazanç; en ucuz kasa (30 gem) ≈ 0,30 $.

## Kod
- `addons/GodotGooglePlayBilling/` — resmi eklenti 3.3.0 (Billing Library 9.1.0), editör eklentisi
  `project.godot`'ta açık; yalnızca dışa aktarmaya AAR ekler, autoload kurmaz.
- `gameplay/purchases/purchase_manager.gd` — ödeme sözleşmesi (gem → kayıt diske → tüket), defter,
  cihaz defteri, bulut kaydında taşıma (`carry_over`). Ayrıntı dosya başında.
- `gameplay/purchases/mock_billing_client.gd` — masaüstü / test için sahte Play.
- `ui/hud/gem_store_screen.gd` — GEM MAĞAZASI (UiRouter `&"gem_store"`); gem sayacına dokununca ve
  showroom'da "GEM YETERSİZ · GEM AL" plakasından açılır.
- Kayıt: `"purchases": {"ledger": {...}}` (sürüm artmadı; eski kayıtta boş defter).
- Test: `tests/purchase_test.gd` (run_tests listesinde).

## Play tarafı (kullanıcı)
1. ✅ Ödeme profili, lisans testçisi, dahili test kullanıcıları.
2. Eklentili AAB'yi dahili teste yükle (`tools/build_release_aab.sh`, sürüm kodu artırılmış).
3. Para kazanma → Ürünler → Tek seferlik ürünler: yukarıdaki 5 kimliği oluştur, fiyat gir, ETKİNLEŞTİR.
4. Dahili testten indirip test kartıyla dene (lisans testçisi para ödemez).
5. Yayından önce: Veri güvenliği formuna "Satın alma geçmişi", içerik derecelendirmede "uygulama içi
   satın alma", gizlilik politikası (web sitesi) güncellemesi. Kasa oranları satın almadan önce kasa
   ekranında görünür (Play'in rastgele ürün oranı kuralı).

## Sunucu doğrulaması (2026-10-22)
Play "PURCHASED" deyince oyun gemi vermeden `iapVerify`'a sorar (`PurchaseManager._verify`, düz HTTP callable).
Fonksiyon (`firebase/functions/iap.js`) Google Play Developer API `purchases.products.get` ile bakar:

| Play'in cevabı | Oyun |
|---|---|
| ödendi, tüketilmemiş → `ok` | gem verilir, kaydedilir, sonra tüketilir (miktar Play'den) |
| bekliyor → `pending` | gem yok, ödeme tamamlanınca yeniden gelir |
| iptal / tüketilmiş / tanınmıyor → `canceled` · `consumed` · `invalid` | gem yok, tüketilmez, MARKET "GOOGLE PLAY BU ÖDEMEYİ ONAYLAMADI" |
| izin / kota / ağ hatası → `unavailable` | gem yok, tüketilmez; 20 sn → 10 dk aralıkla ve oyuna dönünce yeniden sorulur |

- Sunucuya ulaşılamazsa gem VERİLMEZ (sahte satın alma aracı ağı keserek geçemesin). Play onaylanmayan satın
  almayı 3 gün içinde iade eder: oyuncu parasını kaybetmez.
- ÖN KAYIT ÖDÜLÜ istisna: Play'in ödül belirteçlerini tanıdığı yayından önce denenemiyor; `invalid` gelirse ödül
  yine verilir (sahtesi kayıt başına bir kez 100 gem).
- Sahte Play (`MockBillingClient`, masaüstü / testler) doğrulamasız geçer; testler `use_verifier` ile taklit eder
  (`tests/purchase_test.gd` bölüm 12–14).
- Kayıt: `iap/{belirteç özeti}` (istemciye kapalı) 1 yıl (`cleanup.js`), hesap silinince hemen (`account_cleanup.js`).
- KURULUM (bir kez): Google Cloud'da "Google Play Android Developer API" açılır; Play Console → Kullanıcılar ve
  izinler → `1027985902163-compute@developer.gserviceaccount.com` davet edilir (uygulama bilgisi + finansal veri +
  sipariş yönetimi). İzin 24 saate kadar yayılmayabilir; o sürede satın almalar "doğrulanamadı" der, kaybolmaz.
- Sonraki adım: iade edilen siparişler (voided purchases API) ile verilen gemin geri alınması.
