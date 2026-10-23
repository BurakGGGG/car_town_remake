# Ödüllü reklam teklifleri

2026-10-23. Kullanıcı kararı: kesinlikle kendiliğinden açılan reklam yok.

- Ara reklam yok.
- Banner yok.
- Açılış reklamı yok.
- Kendiliğinden açılan "reklam izle?" penceresi yok.

Her teklif, oyuncunun kendi açtığı bir ekranda bir düğmedir. Reklamı yalnızca oyuncu basarsa açılır; basmamak hiçbir şeyi
engellemez. Kullanıcı yedi yerin hepsini istedi. Tek farkla: ücretsiz elmas 15 değil, 3 dakikada bir yenilenir.

## Teklifler

| Tür (`AdPolicy`) | Nerede | Ödül | Günde | Not |
|---|---|---|---|---|
| `free_gems` | MARKET › GEM AL, ilk kart "ÜCRETSİZ ELMAS" | +5 elmas | 5 | İki izleme arası 3 dk. Düğme geri sayım yazar. Hak bitince "YARIN YENİLENİR". |
| `offline_double` | OTO MANŞET gazetesi, TAMAM'ın yanında | Sen yokken kazanılan ₺ ×2 | 2 | Kapanışta iki katı sayaca uçar. |
| `time_skip` | Modifiye takma (HEMEN BİTİR altında), depo inşası (BİTİR altında), iç yükseltme (GERİ yanında) | Kalan sürenin yarısı, en çok 30 dk | 8 | İş başına bir kez. 2 dk'dan kısa kalanda teklif yok. |
| `daily_double` | GÖREVLER › GÜNLÜK başında; giriş bildirimine dokununca | Bugünün giriş elması ×2 | 1 | Gün boyu durur. |
| `levelup_double` | SEVİYE ATLADIN, DEVAM ET'in yanında | Seviye ₺ ödülü ×2 | 3 | Elmas katlanmaz. |
| `mission_reroll` | GÖREVLER › GÜNLÜK, bitmemiş görevde küçük "▶ DEĞİŞTİR" | Görev aynı kademede başka görevle değişir | 1 | Yerine görev bulunamıyorsa teklif çıkmaz; reklam boşa gitmez. |
| `junk_refill` | Hurdalık alt şeridi, sayaç yanında | En yakın dolacak boş yığın hemen dolar | 2 | Boş yığın yokken gizli. |
| `race_double` | Yarış sonucu (önceden vardı) | Yarış ₺ ödülü ×2 | 5 | |
| `repair_boost` | Uzun tamir plakası (önceden vardı) | Kalan sürenin yarısı | 8 | Seviye 5'ten itibaren. |

## Genel kurallar

- **Toplam:** bütün teklifler toplamı günde en çok 20 reklam.
- **Ara:** iki reklam arası en az 45 sn (oturum içi).
- **Seviye:** 3. seviyeden önce hiç teklif yok; ilk deneyim reklamsız.
- **Reklam hazır değilse:** teklif gizlenir. MARKET kartı istisna: kalıcıdır, "REKLAM HAZIRLANIYOR" yazar.
- **Sayaçlar ve bekleme kayıtta:**
  - Uygulamayı kapatıp açmak hakkı ya da 3 dk beklemeyi sıfırlamaz.
  - Saat geri alınırsa sayaç sıfırlanmaz.
  - Bekleme gece yarısını da geçer.
- **Ödül yalnızca reklamı başlatan düğmeye gider:** `AdOfferButton.rewarded`. Reklam erken kapatılırsa ödül yok, hak da harcanmaz.
- **Analitik:** her reklam `ad_finished {kind, rewarded}` olayıyla Firebase Analytics'e gider (izin verilmişse).

## Panelden ayar (güncellemesiz)

Yönetim paneli → **Reklamlar**:
- günlük toplam
- reklam başına elmas
- ücretsiz elmas beklemesi (dakika)
- her teklifin günlük sınırı (0 = kapalı)

Ayar Firestore `config/app.ads`'e yazılır. "Oyunun varsayılanına dön" alanı siler. Oyun açılışta, öne gelince ve 15 dakikada
bir okur (`AdPolicy.normalize_remote`, sınırlar panelle aynı).

Örnek: hafta sonu etkinliğinde reklam başına 10 elmas.

## Kod

| Parça | Dosya |
|---|---|
| Kurallar, sınırlar, bekleme, panel ayarı | `ads/ad_policy.gd` |
| Sayaç / bekleme kaydı, gösterim, panel ayarını uygulama | `ads/ad_service.gd` |
| Ortak teklif düğmesi | `ui/hud/ad_offer_button.gd` (`AdOfferButton`) |
| MARKET kartı | `ui/hud/gem_store_screen.gd` (`_free_card`), çizim `GemPackArt.Kind.FREE` |
| OTO MANŞET | `ui/hud/news_screen.gd`, `news_flow.gd`, `OfflineEarnings.collect(money_mult)` |
| Süre kısaltma | `PerformanceModManager.apply_ad_cut`, `CarGarageManager.apply_build_ad_cut` / `apply_job_ad_cut`; ekranlar `mod_workshop.gd`, `car_garages_screen.gd`, `car_garage_upgrade_screen.gd` |
| Giriş ×2 | `GemRewards.login_double_amount` / `double_login`; `Hud._on_login_granted`; `MissionScreen._login_plate` |
| Seviye ×2 | `ui/hud/level_up_screen.gd` |
| Görev değiştir | `MissionGenerator.replacement` / `has_replacement`, `MissionManager.reroll_daily` / `can_reroll` |
| Hurdalık | `JunkyardManager.refill_pile`, `junkyard_screen.gd` |
| Panel | `firebase/admin/lib.mjs` (`buildAds`), `server.mjs` (`/api/ads`), `public/index.html` (Reklamlar) |
| Testler | `tests/ads_test.gd` (kurallar), `tests/ad_offers_test.gd` (yedi teklif uçtan uca), görsel `qa/ad_offers_shots.gd` |
