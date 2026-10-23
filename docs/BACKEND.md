# Backend (Firebase) — 2026-10-21

Kullanıcı kararları (2026-10-21): yönetim **yerel panelden** (internete açık yönetici kapısı yok), posta / hediye
**yalnız hesaplı** oyuncuya, **genel bildirim izni** (yarış + hediye + duyuru), ekonomi **melez** (tam sunucu
otoritesi yok; kayıt bulutta, görünür özet alanları, düzeltme posta yoluyla, satın alma makbuzu sunucuda doğrulanır).

## Oyuncu kaydı — `players/{uid}`

| Alan | |
|---|---|
| `save_json` | kaydın tamamı, **sıkışık**: `gz1:` + base64(gzip(JSON)) — `CloudPack`. Eski düz JSON da okunur. |
| `stats` | `{money, gems, level, cars, build}` yalnızca gösterim (panel); oyun okumaz |
| `profile`, `save_version`, `updated_at` | değişmedi |

Neden sıkışık: kural `save_json` < 20.000 karakterdi; dekorlu bir kayıt düz JSON'da 17,3 KB'ı geçiyordu ve sınırı
aşan kayıt sessizce reddediliyordu (oyun OFFLINE'da kalıyordu). Sıkışınca ~3 KB; kural sınırı 100 KB'a çıktı.
Açılamayan sıkışık kayıt "bulut yok" sayılmaz (üzerine yazılırdı): ERROR, bulut korunur. Açık garaj
(`garages.garage_json`) da aynı biçimde.

## Uzaktan ayar — `config/app` (`AppConfig`, `AppGate`)

Oyun açılışta, öne gelince ve 15 dakikada bir **oturumsuz** okur (Firestore REST; misafir de). Son belge cihazda
kalır: internet yokken de son kural geçerli. Geliştirme sürümü (sürüm kodu 0) kapıya takılmaz.

| Alan | Etki |
|---|---|
| `min_code` | sürüm kodu bunun altındaysa **GÜNCELLEME GEREKLİ** (kapanmaz, mağazaya gider) |
| `latest_code` | altındakilere **YENİ SÜRÜM VAR** (sürüm başına bir kez, kapatılabilir) |
| `update_text` | `{tr, en, es, de, fr}` güncelleme açıklaması |
| `maintenance`, `maintenance_text`, `maintenance_until` | **BAKIMDAYIZ** (kapanmaz, TEKRAR DENE) |
| `notice` | `{id, title, text, until}` **DUYURU** penceresi, kimlik başına bir kez |

Sürüm kodu pakete dışa aktarma anında gömülür (`addons/autoyard_android` → `res://build_info.json` → `AppInfo`);
AYARLAR'daki sürüm yazısı `1.0.9 (10)` biçimindedir, telefonda buradan doğrulanır.

## Posta / hediye — `users/{uid}/mail/{id}` (`MailService`, `MailNotice`)

Yalnızca sunucu (panel) yazar; sahibi listeler ve aldıktan sonra siler.
`{title, text, from, money, gems, crates: {kasa: adet}, decor: {eşya: adet}, at, expires, notify}`.
Akış: oturum açılınca / öne gelince / 10 dakikada bir listelenir → oyun sakinken **POSTA** penceresi → **AL** →
ödül hesaba, kimlik kayda (`mail.claimed`), kayıt diske, belge silinir. Silme başarısız olsa da kimlik kayıtta
olduğundan ikinci kez verilmez. Değerler oyunda da sınırlanır (50 M ₺, 50.000 elmas, 20 adet).

## Bildirimler (`PushService`)

| Tür | Kim alır | Nasıl |
|---|---|---|
| YARIŞ | hesaplı | `raceNewsPush` (news.js), `push/p_{uid}.prefs.race` false ise gitmez |
| HEDİYE | hesaplı | `mailPush` (mail.js), posta yazılınca; `prefs.gift` false ya da `notify: false` ise gitmez |
| DUYURU | herkes (misafir dahil) | panel → FCM konusu `news_<dil>`; cihaz bildirimleri açınca abone olur |

İzin ilk yarıştan sonra genel öneriyle istenir; AYARLAR → SES VE BİLDİRİMLER: ana anahtar + üç tür. Çıkışta cihaz
jetonu yenilenir (eski hesabın bildirimleri gelmez, duyuru sürer).

## Moderasyon — `moderation/m_{uid}` (`ModerationWatch`, `BanNotice`)

Yalnızca panel yazar; sahibi okur (kimlik `m_` önekli: bulut kaydı kimlik == UID sonucunu kendi belgesi sanar).
`{ban: {kind, reason, text, until, at}, name, name_reset, photo_reset}`.

| Karar | Sunucu (firestore.rules) | Oyun |
|---|---|---|
| **Sosyal yasak** | `socialAllowed()`: garaj, fotoğraf, şikâyet, kod, davet, istek, arkadaşlık, hediye, yarış haberi, ziyaret yazılamaz | oynar; sosyal işlemde yasak metni; panel açık garajı / fotoğrafı gizler |
| **Tam yasak** | ayrıca `saveAllowed()`: bulut kaydı ve bildirim jetonu yazılamaz | pencere → TAMAM → oturum kapanır (misafir; ilerleme yedeklenir) |
| **Adı sıfırla** | panel garajı `UstaNNNN` yapar | oyun `moderation.name`'i kendi adı yapar (bir kez) |
| **Fotoğrafı kaldır** | panel avatar belgesini siler | oyun kaska döner (bir kez) |

Süre: `until` (unix sn), 0 = kalıcı; süresi dolan yasak kurallarda kendiliğinden düşer. Oyuncu sebep + bitiş
penceresini görür (kullanıcı kararı), İTİRAZ ET iletişim sayfasını açar. Oyun çevrimdışı oynanabildiği için yasak
yalnızca çevrimiçi özellikleri kapatır. Kontrol: girişte, öne gelince (5 dk), 30 dakikada bir.
Hesap silinince `moderation` ve `admin_notes` de silinir (account_cleanup.js).

## Destek: kayıt geçmişi, geri yükleme, bakiye düzeltme

- **Kayıt geçmişi** `players/{uid}/history/{dilim}`: başarılı bulut yazmasından sonra saat başına `h00`–`h23`, gün başına
  `d0`–`d6` (üzerine yazılır: son 24 saat + son 7 gün, silme gerekmez). İstemci okumaz; panel listeler.
- **Geri yükleme**: panel seçilen dilimi POSTA olarak gönderir (`restore`); oyuncu KAYDI GERİ YÜKLE deyince
  `CloudSaveManager.restore_snapshot` (şimdiki kayıt `savegame.before_cloud.json`'a yedeklenir, dünya yeniden kurulur,
  postanın kimliği geri yüklenen kayda da yazılır). Oyun açıkken de güvenli, çakışma penceresi çıkmaz.
- **Bakiye düzeltme**: posta `adjust {money, gems}`, eksi de olabilir (0'ın altına inmez, harcama sayılmaz).

## Canlı oyun

| Özellik | Sunucu | Oyun |
|---|---|---|
| **Kupon kodu** | panel `promo/{KOD}` yazar; oyuncu `users/{uid}/redeem/{KOD}` = `{at}` yazar (kod başına bir kez) → `promoRedeem` (promo.js) işlemle doğrular (açık, süresi dolmamış, hesap başına bir kez, sınır, saatte 10 deneme) → ödül POSTA'ya | MARKET › KOD GİR (kullanıcı kararı); `PromoService` sonucu okur |
| **Canlı etkinlik** (2026-10-23 modüllü) | `config/app.event {id, title, text, start, end, money_mult, xp_mult, sale, crate_boost, missions, rival, pack}` + `config/app.packs [{id, url, sha256, size}]`; panel **Etkinlik** sekmesi (`POST /api/event`, öbür alanlara dokunmaz) | `LiveEvent` doğrular (sınırlar panelle aynı); çarpan tamir iş BAŞLARKEN / yarış `reward_for`'da; indirim fiyat kaynaklarında; etkinlik kasası `CrateCatalog.odds`; görevler `MissionManager`; özel rakip `RaceManager.start_event_rival`; içerik paketi `LivePacks`. Tabela + ETKİNLİK PANOSU. Ayrıntı: `docs/CANLI_ETKINLIK.md` |
| **Hedefli gönderim** | panel `players` özetinden süzer: seviye, son oynama, oynamama süresi, sürüm kodu, dil (`stats.lang`) | posta / telefon jetonu (misafir süzülemez) |
| **İstatistik** | `dailyStats` her gece 03:10 → `stats_daily/{gün}` (hesaplı oyuncu, aktif 1/7/30 gün, bildirim, yeni hesap); panel anlık sayıları da hesaplar | — |
| **Yarış öğrenmesi** (2026-10-22) | oyun `race_log/{uid}_{UTC gün}` = `{uid, day, events (JSON), n, v, at}` yazar (yalnız sahibi; kimse okumaz; son 2 gün); `raceLearning` (learning.js) her gece 03:30 → `race_learning_daily/{gün}` + son 30 günün toplamı `config/race_learning.table` (MERGE); panel aynı belgeye `off / window / weight` yazar; hesap silinince `race_log` de silinir | `RaceLearning` kolu seçer, yarış sonrası kalışı ölçer, günlüğü yükler; tabloyu `AppConfig` okur. Tasarım: `docs/KOSU_ESLESTIRME.md` |

**Sıra uyarısı:** `stats.lang` kuralı yayında değilken bu alanı yazan yeni sürüm bulut kaydını yazamaz → yeni AAB'den
ÖNCE kurallar deploy edilmeli.

## Satın alma doğrulaması — `iapVerify`, `iap/{özet}`

Oyun gemi vermeden önce satın almayı Play'e doğrulatır; ayrıntı ve kurulum: `docs/ELMAS_EKONOMISI.md`
"Sunucu doğrulaması". Kayıt 1 yıl (`cleanupExpired`), hesap silinince hemen (`accountCleanup`).

## Analitik + çökme raporu (`Telemetry`)

`gameplay/telemetry/telemetry.gd`: Firebase Analytics (oyun olayları + `screen_view`) ve Crashlytics (Java / motor
çökmeleri kendiliğinden, GDScript hataları `Logger` ile ölümcül olmayan kayıt). Kütüphaneler Gradle bağımlılığı
(`addons/GodotFirebaseAndroid/export_plugin.gd`, BoM 33.13.0 sürümleri + Crashlytics Gradle eklentisi 3.0.3),
bağlantı JavaClassWrapper ile. Olaylar: `repair_collect`, `repair_gem_finish`, `customer_left`, `crate_open`,
`race_finish`, `level_up`, `mod_install`, `vehicle_buy`, `decor_buy`, `mastery_up`, `restoration_complete`,
`iap_result`, `ad_finished`, `tutorial_complete`, `script_error`, `screen_view`; oyuncu özellikleri `lang`, `level`.
Rıza: AYARLAR → HESAP VE GİZLİLİK → KULLANIM İSTATİSTİKLERİ / HATA RAPORLARI (varsayılan açık, Firebase'in toplama
anahtarına yazılır). Reklam kimliği toplanmaz, reklam onay sinyalleri reddedilmiş başlar. UID yalnız Crashlytics'e
(destek için), Analytics hesaba bağlanmaz. Test: `tools/run_tests.sh telemetry_test`.

## Yönetim paneli

`firebase/admin/` — kurulum ve kullanım: `firebase/admin/README.md`. İşlemler `admin_log`'a yazılır
(istemciye kapalı).

## Testler

| Ne | Komut |
|---|---|
| Kurallar (emülatör) | `firebase/` içinden `firebase emulators:exec --only firestore --project demo-cartown "node rules_test/rules_test.mjs"` |
| Functions (birim / emülatör) | `firebase/functions`: `npm test`, `npm run e2e` |
| Panel | `firebase/admin`: `npm test`, `npm run e2e` |
| Oyun | `tools/run_tests.sh app_config_test mail_test moderation_test login_flow_test social_test race_news_test settings_test gem_exchange_test race_learning_test purchase_test telemetry_test` |

## Açık

- İade edilen siparişlerin (voided purchases) gemi geri alması — doğrulama var, iade takibi yok.
- AB (AEA) için ilk açılışta analitik onayı sorulmuyor (varsayılan açık, AYARLAR'dan kapatılır) — gerekirse onay penceresi.
- Süresi dolup alınmamış posta belgeleri (hiç açılmayan hesaplar) temizlenmiyor; gerekirse `cleanupExpired`'a
  koleksiyon grubu dizini ile eklenir.
