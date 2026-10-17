# OTO MANŞET — açılış gazetesi + pasif gelir

2026-10-17, kullanıcıyla soru-cevapla tasarlandı. Oyuna girişte "sen yokken neler oldu" gazetesi; TAMAM ile kapanır.

## Kararlar (kullanıcı)

**Gazete:** renkli magazin (kırmızı başlık bandı, kalın manşet, renkli fotoğraflar), adı **OTO MANŞET**
(EN AUTO HEADLINES · ES TITULARES MOTOR). Ekrana masaya fırlatılmış gibi gelir, birkaç derece yamuk kalır.
Ses: bisiklet zili + "pat" + kâğıt hışırtısı (kodla). Esprili magazin dili, dönüşümlü kalıplar. Manşet = en çarpıcı
haber (seni yenen arkadaş > büyük kazanç > hediye > ziyaret > biten işler). Benzer haberler birleşir, gazete tek
sayfa; KISA KISA iki satıra sığmazsa en önemsizler "+N HABER DAHA" olur. YALNIZ TAMAM düğmesi. Yarış haberinde
arkadaşın aracı + avatarı, kazançta para görseli (karakter yok).
**Ne zaman:** soğuk açılış + arka plandan 30 dakikadan uzun dönüş. Haber yoksa çıkmaz.

**Pasif gelir:** sen yokken tamir alanları çalışır. 8 saatlik yokluk ≈ 30 dakikalık aktif oyun (aktif ₺/dk ÷ 16).
İlk öneri "yarı hız"dı; ölçümle geç oyunda gecede ~600.000 ₺ çıktı (araçlar 15.000–450.000 ₺), kullanıcı 1/16'yı seçti.
- Yalnız PARA (XP, ustalık, görev sayılmaz).
- Kasa 8 saatte dolar ("kepenk iner"). 30 dakikadan kısa aralarda kasa sessizce büyür, sonraki gazetede çıkar.
- Yarım kalan tamirler: sen yokken bitenler tam ödül + XP ile gazeteye (haberde ayrı cümle), bitmeyenler alana döner.
- Arka planda tamir sayaçları geçen süre kadar ilerler.
- Rıza Usta iki kez anlatır: ilk kazançlı gazeteden sonra ve kasa ilk kez 8 saati doldurunca.
- Saat: "girişliyse sunucu saati" seçildi. Firebase eklentisinde sunucu saati okuma yok → Google'ın HTTPS cevabındaki
  Date başlığı (internet varken misafirde de), oyun içinde monoton sayaçla. İnternetsizse cihaz saati; geri alınmışsa 0.
- 8 saat dolunca telefon bildirimi YOK (yerel bildirim altyapısı yok), garaj panelinde bilgi satırı YOK.

Benim kararlarım (kullanıcıya söylendi): usta temel ders (Rıza Usta'nın ilk dersi) bitmeden çalışmaz; 10 dakikadan
kısa birikim haber olmaz; ödeme kayda hemen yazılır (gazete açıkken kapanırsa ya hiç ya bir kez ödenmiştir); eğitim,
kasa açılışı, yükleme ekranı ya da bulut kayıt seçimi sürerken gazete açılmaz.

## Gelir tablosu

`OfflineEarnings.active_rate` — ölçülmüş aktif gelir (docs/PROGRESSION_REFACTOR.md §8), ₺/dk:

| Garaj | yalnız kısa işler | 1 alan | 2 alan | 3 alan (orta işler açık) |
|---|---|---|---|---|
| 1 | 372 | 372 | 372 | 372 |
| 2 | 626 | 626 | 991 | 1.258 |
| 3 | 1.008 | 1.008 | 1.234 | 1.666 |
| 4 | 1.441 | 1.441 | 1.441 | 1.877 |

Tamir hızı 5 (süre ×0,6) +%48 (ölçüm), aradakiler süre çarpanıyla orantılı. Pasif = ×1/16. 8 saat dolu kasa:
başlangıç ~11.000 ₺, garaj 3 / 3 alan / hız 3 ~59.000 ₺, geç oyun ~83.000 ₺. "Kaç araç" = kasa ÷ açık işlerin
ortalama ödülü (garajın müşteri çarpanıyla).

## Kod

| Dosya | Görev |
|---|---|
| `gameplay/offline_earnings.gd` | OfflineEarnings: saat (HTTP Date + monoton), yokluk, kasa, biten yarım işler, ödeme (`collect`), kayıt "away" |
| `gameplay/repair/repair_manager.gd` | `jobs_state` / `load_jobs` (kayıt "repairs"), `resume_saved_jobs`, `advance_all`, `settle_finished`; kare süresi en çok 0,5 sn sayaca işler (dönüşteki dev kare yokluğu iki kez saymasın) |
| `ui/hud/news_digest.gd` | NewsDigest: ham haber türleri, birleştirme, ağırlık, metinler |
| `ui/hud/news_screen.gd` | NewsScreen: gazete (UiRouter MODAL "news"; açıkken sol üst HUD gizli) |
| `ui/hud/news_sfx.gd` | NewsSfx: zil / pat / hışırtı sentezi |
| `ui/hud/news_flow.gd` | NewsFlow: ne zaman açılır, TAMAM'da ödeme + para uçuşu, Rıza Usta |
| `ui/hud/coin_flight.gd` | CoinFlight: para / gem uçuşu (RewardPopup da kullanır) |
| `ui/tutorial/tutorial_director.gd` | `say()`: tek seferlik konuşma (GEÇ yok) |

Kayıt: `"away"` {last_seen, bank {money, minutes, jobs, full}, finished [{type, reward, xp}], issue, told {first, full}},
`"repairs"` [{vehicle, colors, type, severity, bay, elapsed, duration_scale, reward_scale, boosted, saved_at}]. İkisi de
`has_progress` karşılaştırmasına girmez. Eski kayıtta yoktur: son görülme bilinmez, ilk açılışta yokluk sayılmaz.
Dil değişiminde işler zaten devirle (carry_over) gelir; yeni sahne kayıttakileri almaz (`_skip_saved`).

## Test / QA

- `tests/offline_earnings_test.gd` (run_tests listesinde): tablo, HTTP Date, 8 saat sınırı, kısa aralar, gösterilen
  payın ödenmesi, saat geri alma, kayıt turu, temel ders şartı, metinler, gerçek sahnede açılış + yarım işler.
- `qa/oto_manset_qa.gd`: sahte veriyle görünüm (853x480 / 1067x480, QA_LANG=es).
- `qa/pasif_gelir_qa.gd`: gerçek oyunda 6 sa / 10 sa yokluk, para uçuşu, Rıza Usta, arka plandan dönüş (gerçek ağ saati).
- Kareler: `~/Projects/ct_shots/oto_manset/`, `~/Projects/ct_shots/pasif_gelir/`.
- Telefon tuvali masaüstünde: pencere 1152x648 + `content_scale_factor = 1,35` (853x480). `--resolution 853x480` DEĞİL.

## Haber kaynakları (adım 3)

| Haber | Kaynak | "Sen yokken" nasıl anlaşılır |
|---|---|---|
| Yarış (seni yendi / aracın kazandı) | `SocialManager.race_events` (gönderen başına tek belge, toplam skor mw / ml) | Skorun son gazetedeki tabandan farkı. Tabanı olmayan arkadaş: olay son gazeteden (ya da yokluğun başından) yeniyse 1 |
| Hediye parça | `collect_gifts` | Toplama sürerken (quiet) bildirim yerine `gift_log`'a yazılır |
| Yeni arkadaş / gelen istek | `friends` / `incoming` | Son gazetedeki listede olmayanlar (ilk gazetede liste taban olur, haber çıkmaz) |
| Arkadaş parça istiyor | `friends[].ask_part / ask_at` | İstek son gazeteden yeni ve bugün göndermedinse |
| Hurda yığını doldu | `JunkyardManager.pile_ready_at` | Dolma anı yokluk aralığında (hurdalık açıksa) |
| Modifiye bitti | `PerformanceModManager.jobs()` | Bitiş anı yokluk aralığında |
| Görevler yenilendi | `GemRewards.day_key / week_key` | Yokluk aralığı gün / hafta değiştirdi (görevler açıksa) |

Taban `user://social.json` "news" {scores, friends, requests, asks, at} — cihaza özel; gazete kapanınca (`news_shown`)
ilerler. Oyun açıkken bildirimi görülen yarış haberi tabana hemen işlenir (gazete tekrarlamaz). Toplama sürerken
(`NewsFlow.is_gathering`) yarış / hediye bildirimi çıkmaz. Açılışta arkadaş verisi en çok 6 sn beklenir (bulut senkronu
sayılmaz); misafir / eklentisiz / profilsiz oyuncuda beklenmez. Arka plandan uzun dönüşte liste yeniden okunur.
Yokluk aralığı `OfflineEarnings.window_from / window_to` (kayda girmez, gazete gösterilince sıfırlanır).
Tekil cümleler ayrı anahtar (Türkçede "1 kez yarıştı, hepsinde kaybetti" olmaz); "SPOR|gazete" bağlamı (araç sınıfı
"SPOR" İspanyolcada DEPORTIVA, gazete sayfası DEPORTES).

Test: `tests/news_sources_test.gd` (run_tests listesinde). QA: `qa/haber_kaynaklari_qa.gd` (gerçek açılış, taklit arkadaş
verisi; kareler `~/Projects/ct_shots/haber_kaynaklari/`).

## Ziyaret + beğeni (adım 4)

Kullanıcı kararı: ziyaretçi kalp bırakabilir, arkadaş başına GÜNDE 1; toplam beğeni profil kartında ve ARKADAŞLAR
kartında; beğenisiz ziyaret de haber olur.

- **Ziyaretçi:** gerçek arkadaşın garajında üst çubukta BEĞEN (VisitBar, HudIcon.HEART); basınca amber BEĞENDİN.
  Ustalarda (Emre / Elif) yok. Ziyaret sırasında kendi sahne ağaç dışında (zamanlayıcılar durur) → kayıt DÖNÜŞTE
  yazılır: GarageVisit.end `_last` {uid, liked} → kendi SocialManager ağaca girince (`NOTIFICATION_ENTER_TREE`)
  `users/{sahip}/visits/v_{ben}` = {name, at, day (UTC gün), liked}. Bugün beğendiğin cihazda hatırlanır
  (social.json "likes_sent"), düğme dolu gelir.
- **Sahip:** liste okunurken ve 2 dk'lık haber yoklamasında `_load_visits`: beğeni ziyaretçi başına günde bir sayılır
  (social.json "likes_counted"), toplam `PlayerProfile.likes` (kayıtta "profile.likes", açık garajda `stats.likes` —
  YALNIZ > 0 iken yazılır: beğeni kuralı yüklenmeden önceki sunucu bu alanı reddederdi). Ziyaret gazete toplanıyorsa
  "visit_log"a (gazetede VISIT), değilse küçük bildirim ("ELİF GARAJINI BEĞENDİ"); belge okununca silinir.
- **Gösterim:** profil kartında 4. sütun BEĞENİ; ARKADAŞLAR kartında seviyenin yanında kalp + sayı (kart boyu
  değişmez — istatistik kutusuna satır eklemek 16:9 telefonda zaten taşan vitrini 17 birim daha taşırıyordu).
- **Kural:** `firestore.rules` users/{uid}/visits (yalnız arkadaş, kendi adına, day == sunucu günü, liked bool, ek alan
  yok; sahip okur / siler, ziyaretçi kendi belgesini siler) + isValidStats'a isteğe bağlı `likes` (int ≥ 0). Emülatör
  testi `firebase/rules_test` (17 yeni kontrol). Hesap silme gelen ziyaretleri ve arkadaşlara yazdıklarımı da siler.
  2026-10-17 kullanıcı onayıyla car-town-remake'e YÜKLENDİ.
- **Test / QA:** news_sources_test §4b (sahte sunucu: sayma, günde bir, bildirim, gönderme, ustalar), qa/begeni_qa.gd.

## Bilinen / açık

- Davetle eklenen arkadaş "yeni arkadaş" haberi olarak çıkar (ayrı "davet linkinle" ayrımı yok).
- Araç fotoğrafı fabrika renginde (boyalı değil).
- 2026-10-17 düzeltildi (önceden kalan taşma): telefon tuvalinde (480 yükseklik) ARKADAŞLAR penceresi 598 birimdi →
  kısa ekranda sıkı kart (FriendsScreen.COMPACT_*: avatar adın solunda 54, araç 140x60, dar paylar; istek + GÖNDER tek
  düğme "CIVATA GÖNDER") → 468. Arkadaş kartı sol üst bloğun sağına itiliyordu → HUD_FREE_SCREENS'e friend_card.
  Ekran taraması 7 profil 0 sorun; qa/arkadaslar_qa.gd "-- mobil" ile telefon tuvalinde ölçer.
