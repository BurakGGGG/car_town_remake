# Koşu tabanlı rakip + öğrenen zorluk (tasarım, 2026-10-21)

Eş zamanlı (canlı) drag yarışından vazgeçildi. Yerine: rakip, birinin GERÇEK bir koşusunu birebir sürer;
hangi koşunun geleceğini oyuncunun kazanma şansına göre bir seçici belirler; arka planda bir öğrenici,
oyuncunun kazanınca mı kaybedince mi oyunda daha çok kaldığını ölçüp bu seçimi kaydırır.

Sahte sonuç yok: pistteki rakip ya arkadaşın gerçekten yaptığı bir koşudur ya da yapay zekânın aynı fizikle
önceden koşulmuş bir koşusu. Ayarlanan tek şey HANGİ koşunun seçildiğidir.

## Kullanıcı kararları (soru-cevap, 2026-10-21)

| Konu | Karar |
|---|---|
| Rakip araç | Oyuncununkiyle AYNI olmak zorunda değil (Tofaş'a karşı arkadaşın Corsa'sı gelebilir): araç bugünkü performans penceresinden (`rival_window`) seçilir; karşılaştırılan şey SÜRELERDİR — oyuncunun kendi aracıyla tipik süresi ile rakip koşunun süresi |
| Arkadaşın aracı nasıl sürer | Gerçek koşusunu BİREBİR tekrar eder (kalkış + her vites; süre aynı çıkar) |
| Arkadaşın o araçla koşusu yoksa | O araç rakip olarak GELMEZ (boşluğu Emre/Elif ve isimsiz rakip doldurur) |
| "Oyunda kalmak" ölçütü | Yarış SONRASI kalış: oyunu kapatmadan oynamaya devam etti mi / sıradaki daveti kabul etti mi |
| Öğrenme verisi | HERKESİN verisi sunucuda toplanır (genel eğri) + her oyuncu kendi davranışıyla kayar |
| Başlangıç kuralı | Karışım + seri kırıcı: çoğu ~%50, ~üçte biri kolay (~%75), ara sıra zor (~%30); üst üste 2 kayıptan sonra kolay |
| Rakip süresi yarıştan ÖNCE | Hiç gösterilmez (davette süre yok) |
| Sonuç panosu | Bugünkü gibi kalır: "SEN 12.25 sn · RAKİP 12.20 sn" |
| Kapsam | BÜTÜN rakipler: arkadaş → gerçek koşuları; Emre/Elif ve isimsiz → yapay zekânın önceden koşulmuş koşuları |
| Ödül | Değişmez (rakibin sınıfına bağlı); zorluk seçimi ekonomiyi etkilemez |
| İNTİKAM AL | Seni yenen koşu değil: sistem arkadaşın o aracındaki koşularından hedef şansa göre YENİDEN seçer |

Bu, 2026-10-16'daki "arkadaş rakip = yapay zekâ + gün formu, hayalet DEĞİL" kararının yerine geçer.

## Varsayılanlar (benim önerim, değiştirilebilir)

* **Rövanş:** İNTİKAM ile tutarlı — aynı rakip araç, koşu yeniden seçilir.
* **Kalış eşiği:** sonuç panosundan sonra 5 dk içinde oyun kapanmadı / arka plana atılmadı (1 dk içinde geri dönüş
  kapanma sayılmaz) YA DA sıradaki yarış daveti kabul edildi → "kaldı". Eşik `config/app` üzerinden uzaktan ayarlanır.
* **Zorluk kolları:** KOLAY ~%75 · DENGELİ ~%50 · ZOR ~%30 kazanma şansı.
* **Bağlam:** son iki sonuç (KK, KY, YK, YY) + ilk 10 yarış ayrı bağlam (yeni oyuncu).
* **Korkuluklar (öğrenme ne derse desin):** seri kırıcı her zaman geçerli; ZOR en çok %25; üst üste 3 ZOR yok;
  `config/app` içinde öğrenmeyi kapatma anahtarı (kapalıyken başlangıç kuralı çalışır).

## Teknik plan

### Önkoşul — sabit adımlı fizik (ölçüldü)
`DragRaceScreen._process` fiziği değişken kare adımıyla ilerletiyor; aynı sürüş 60 Hz'de 120 Hz'e göre 17–25 ms
farklı bitiyor ve bitiş anı kare adımına yuvarlanıyor (ölçüm: `~/Projects/ct_shots/canli_yaris/fps_probe.gd`).
Birebir tekrar için: `DragRaceSim.STEP` (1/120) ile biriktirici + bitiş anı adım içinde enterpolasyon. Aynı girdi
aynı adımla zaten birebir aynı süreyi veriyor.

### Koşu kaydı
`{car, build (modifiye anlık görüntüsü), jitter, launch_step, shift_steps[], false_start, time, at, sim_v}` —
girdiler adım numarası olarak (~40–60 bayt). Süre kayıtta durur ama asıl kaynak girdidir: tekrar eden istemci süreyi
YENİDEN HESAPLAR (uydurma süre yazılamaz; en fazla kusursuz girdi yazılabilir, o da insanın ulaşabileceği bir sınır).
`sim_v`: fizik / cars.json dengesi değişince eski koşular elenir (ya da yeniden hesaplanır).

* **Kayıt:** araç başına son 15 koşu (bulut kaydıyla senkron). "Hep tutalım" isteğinin kalıcı karşılığı Faz 2'nin sunucu
  yarış günlüğüdür (her yarış).
* **Arkadaşlar:** açık garaj JSON'unda araç başına son 8 koşu (arkadaş listesi garajı zaten okuyor; kural değişmedi).

### Seçici
Oyuncunun o araç + modifiye ile son koşularından süre dağılımı (≥10 koşuda deneysel dağılım, azsa sınıfına göre
varsayılan). Kazanma şansı = P(benim sürem < rakip koşunun süresi). Rakip ARAÇ bugünkü `rival_window` ile seçilir;
o aracın koşu havuzundan hedef şansa en yakın koşu alınır. Arkadaşın hedefe yakın koşusu yoksa (±%15) başka arkadaş,
o da yoksa Emre/Elif/isimsiz (yapay zekâ havuzu her hedefi tutturabilir).

### Yapay zekâ havuzu (Emre/Elif/isimsiz)
Fabrika aracı için gün formu tohumları önceden koşulur (araç başına ~200 tohum → süre). Seçilen tohum pistte aynı
sabit adımla aynı süreyi verir. Tohum tablosu araçla birlikte pişirilir; denge değişince yeniden pişirilir.

### Öğrenici
Bağlam × kol başına Thompson örneklemesi (Beta dağılımı, ödül = "kaldı"). Önsel = sunucudaki genel tablo (ağırlığı
~20 yarışa eşdeğer), üstüne oyuncunun kendi sonuçları. Yarış günlüğü yerelde biriktirilip günde bir belge olarak
yazılır (`race_log/{uid}_{gün}`); gece Cloud Function'ı toplayıp `config/race_learning`'e yazar; oyun bunu
`AppConfig` gibi REST ile okur. Yönetim panelinde tablo (bağlam × kol: deneme, kalış oranı) + kapatma anahtarı.
**Play Data safety:** "Uygulama etkinliği" beyanı (kullanıcı, konsolda).

## Faz 0 — UYGULANDI (2026-10-21)
* `DragRaceSim.Recording`: girdiler adım numarasıyla (`launch_step`, `shift_steps`; "kaç adım TAMAMLANINCA"), sapma ve
  güç milyonda bir tamsayıdan, kalkış devri tam sayı → `to_dict` / `from_dict` gidiş-dönüşünde bit kaybı yok;
  `from_dict` sürüm / araç / sıra / aralık denetler. `SIM_VERSION`, `MAX_STEPS`.
* `DragRaceSim.replay(kayıt)` başsız tekrar; `ai_recording(araç, modifiye, form, rng)` rakip yapay zekâsını sürüp kaydeder
  (`run_rival` de bu yoldan — başsız ölçüm = pistteki rakip).
* `Runner`: bitiş anı adımın içinde (yol oranıyla), `prev_distance` (çizim ara değeri), `jitter` artık açık alan.
* `DragRaceScreen`: `_run_steps` / `_sim_step` sabit adım; girdi adımlar ARASINDA uygulanır ve adım numarasıyla
  kaydedilir; rakip açılışta üretilen kaydın OYNATILMASIDIR (süresi koşudan önce belli — Faz 1 seçici bunu kullanacak);
  araçlar `_drawn_distance` ile iki adım arasında ara değerlenerek çizilir (foto finişte kare başına adım düşmüyor);
  kare başına en çok `MAX_FRAME_SIM` (1 sn) yarış saati. `player_recording()` / `rival_recording()`.
* `vehicles/race_specs.json` yeniden pişirildi: `base_time` ortalama −4 ms (adım içi bitiş), başka alan değişmedi.
* Test `tests/race_replay_test.gd` (33): pistte 30 / 60 / 144 / titrek / takılmalı kare düzenlerinde oyuncu ve rakip
  kaydı = başsız tekrar (birebir), hatalı çıkış kaydı, JSON gidiş-dönüşü, bozuk kayıt reddi.

## Faz 1 — UYGULANDI (2026-10-22)
**Ek kullanıcı kararı (2026-10-21):** arkadaşın koşuları hedefe uymuyorsa YİNE ARKADAŞ gelir — uyan koşusu olan arkadaşlardan
biri rastgele, hiçbiri uymuyorsa bütün arkadaşların koşularından hedefe en yakını (şans hedeften sapabilir; arkadaş oranı
korunur). Tek istisna seri kırıcı: üst üste iki kayıptan sonra kolay koşusu olmayan arkadaş gelmez, yapay zekânın kolay
koşusu gelir. Neden: gerçek koşular kümelenir — ölçümde Bob'un 8 Leon koşusu yeni oyuncuya karşı 0,00…0,23 ve 0,79 şans
verdi, DENGELİ (%50) hiç tutmadı; katı kuralda Bob 20 yarışın 9'unda geliyordu.

* `RivalSelector` (gameplay/race/rival_selector.gd): kol (başlangıç kuralı, seri kırıcı, üç ZOR yok), `win_chance`
  (oyuncu örnekleri üzerinde lojistik çekirdek), `samples_for` (aynı araç + modifiye ≥5 koşu → süreleri; yoksa kusursuz
  süreye oranla taşınan koşular; hiç yoksa PRIOR_RATIOS), `closest`.
* `RivalPool` (gameplay/race/rival_pool.gd) + `tools/bake_rival_pool.gd` → `vehicles/rival_pool.json` (74 araç × 48 tohum,
  ~32 KB): Emre / Elif / isimsiz rakibin koşuları. Eskiyse çalışma anında 12 koşu + uyarı. Anahtar: tuning_key + SIM_VERSION
  + RivalPool.VERSION (yapay zekâ sürüşü değişince artır, yeniden pişir).
* `RaceManager`: kayıtta `runs` (araç başına son 15) ve `recent` (son 20 yarış: kazandı mı, kol, şans); kol `pick_rival`'da,
  koşu `rival_recording(oyuncu aracı)`'nda (DragRaceScreen açılışta çağırır); arkadaş koşusu yalnız arkadaşın ŞU ANKİ
  modifiyeleriyle olanlardan (davetteki sınıf = pistteki araç), süresi bu cihazda yeniden koşularak alınır; İNTİKAM arkadaş
  listesindeki koşulardan yeniden seçer (yoksa eski yol: yapay zekâ + onun modifiyeleri); ilk yarışta seçici çalışmaz.
  `add_run` (DragRaceScreen oyuncu bitirince).
* `PublicGarage`: `race.runs` (sahip olunan araç başına son 8; sınır aşılırsa önce depolar, sonra araç başına 3, yine
  sığmazsa koşusuz — garaj hiç yayınlanmamaktan iyi) → `race_data(...).runs`. Kural değişikliği / ek okuma yok. Ölçüm:
  25 araç × 8 koşu sıkışık 9 120 karakter (sınır 19 000).
* **Güven (güvenlik kontrolü 2026-10-22):** açık garaj oyuncunun kendi yazdığı belgedir. Arkadaştan gelen koşu yalnızca
  `Recording.is_player_run()` ise rakip olur: güç 1 (gün formu yok), sapma ±VARIANCE, kalkış devri aracın optimumu.
  Elle yazılmış kayıt (güç +%50 → yenilmez rakip, arkadaşa karşı skor şişirme) `public_runs` ve `_runs_with_build`'de
  atılır. Kalan pay: kusursuz oyuna denk girdiler (tepki ~0, her vites kusursuz) — gerçek oyuncu da yapabilir.
* Testler: `rival_select_test` (26), `friend_race_test` güncellendi (59: koşusuz / başka modifiyeli araç gelmez, uymayan
  arkadaş yine gelir, seri kırıcıda gelmez, pistteki koşu Bob'un gerçek koşusu).

## Faz 2 — UYGULANDI (2026-10-22; kural + raceLearning + accountCleanup kullanıcı tarafından DEPLOY EDİLDİ)
* **Oyun — `RaceLearning`** (gameplay/race/race_learning.gd; RaceManager `_init`'te kurar):
  * Kol: bağlam (son iki sonuç WW / WL / LW / LL, eskisi önce; ilk 10 yarış "new") × kol Thompson örneklemesi. Önsel
    `config/race_learning.table` (ağırlık `weight`, varsayılan 20 yarış), üstüne kişisel sayılar (kayıt `race.learn`).
    Bağlamın her kolunda genel 30 deneme yoksa / `off` → başlangıç kuralı. Korkuluklar: seri kırıcı, son 20'de ZOR ≤ %25,
    üç ZOR üst üste yok.
  * Kalış: sonuçtan sonra `window` (varsayılan 300 sn) oyunda ya da sıradaki yarış başladı → kaldı. Arka plan ≥ 60 sn →
    ayrıldı (ayrılma anı). Oyun kapanınca bekleyen sonuç `user://race_learning.json`'da; sonraki açılışta ayrılma anına
    göre. Sahne yenilenince (bulut kaydı) bekleme sürer. Ayrılma anı bilinmeyen + 1 saatten eski (çökme) sayılmaz.
  * Günlük: olay `{t, c, a, p, w, s, d, n, pc, pt, rc, rt, o, lv}` → `race_log/{uid}_{UTC gün}` (günün tamamı tek belge,
    `SocialManager.write_race_log`); misafirinki cihazdan çıkmaz; yazılamayan gün sonra, iki günden eskisi atılır.
  * `AppConfig` ikinci belge olarak `config/race_learning`'i 6 saatte bir okur, cihazda saklar (çevrimdışı son tablo).
* **Sunucu:** kural `race_log` (yalnız sahibi yazar, kimse okumaz, son 2 gün, alan / boyut sınırı); `raceLearning`
  (learning.js) gece 03:30 → `race_learning_daily/{gün}` (dün + önceki gün, geç gelen yazmalar) + son 30 gün toplamı
  `config/race_learning` (MERGE); `accountCleanup` artık `race_log`'u da siler.
  **Zehirlenmeye karşı (güvenlik kontrolü 2026-10-22, deploy edildi):** günlüğü oyuncu yazdığı için tek hesap günde
  500 uydurma olayla tabloyu ele geçirebiliyordu → toplama oyuncu başına günde hücre (bağlam × kol) başına en çok
  `PER_PLAYER_CELL` (10) olay sayar, zamanı (t) o güne düşmeyen olay sayılmaz; kural tam yasaklıya yazdırmaz
  (`saveAllowed`). Kalan risk: çok hesap (App Check yok) — acil fren paneldeki "öğrenme kapalı".
* **Panel:** İstatistik › Yarış öğrenmesi — bağlam × kol kalış oranı tablosu, öğrenmeyi kapat / kalış penceresi / ağırlık
  (`POST /api/learning`, MERGE).
* **Testler:** `race_learning_test` (34; sanal nüfus: "kaybedince çıkan" → KOLAY %33'ten %81'e, "kazanınca sıkılan" →
  KOLAY %4), functions `npm test` 43 (learning 4 + temizlik), kurallar emülatörde +13, panel `npm test` 19 + `npm run e2e`.
* **Saklama (kullanıcı kararı bana bıraktı, 2026-10-22):** ham `race_log` 180 gün (oyuncuya bağlı; ayarlamaya yeter,
  şikâyet kayıtlarıyla aynı süre) → `raceLearning` gece `pruneLogs` ile siler (gecede en çok 5000); kimliksiz özetler
  (`race_learning_daily`, `config/race_learning`) süresiz. Silme kodu 2026-10-22 kullanıcı tarafından DEPLOY EDİLDİ.
* **Gizlilik:** açık garaja giden koşulardan zaman (`at`) çıkarılır (`PublicGarage.public_runs`). Site gizlilik + hesap
  silme sayfaları 5 dilde güncellendi ve yayında (site main def1e92): yarış günlüğü bölümü, "üçüncü taraf analiz aracı
  yok", amaç tablosu (meşru menfaat, itiraz), saklama, silme listesi; son 8 koşu garaj profilinde.
* **Kullanıcının işi:** Play Console › Veri güvenliği: "Uygulama etkinliği → uygulama içi etkileşimler" (toplanır,
  paylaşılmaz, analiz + uygulama işlevi).
* **Açık:** Faz 3 = gerçek veriyle ayar (pencere, ağırlık, MIN_TRIALS).

## Çevrimdışı
Yarış internet istemez: oyuncunun koşuları kayda yazılır (bulut kaydı ve açık garaj bağlantı gelince), Emre / Elif / isimsiz
rakibin havuzu cihazda. Gerçek arkadaş rakibi, arkadaş listesi okunabildiyse gelir — Firestore Android SDK'sı çevrimdışıyken
okumayı son görülen önbellekten verir (eklenti varsayılan `get()` kullanıyor; telefonda denenmedi); liste hiç okunmadıysa
boşluğu Emre / Elif / isimsiz rakip doldurur. İNTİKAM haberleri bağlantı gelince okunur. Faz 2'nin yarış günlüğü cihazda
biriktirilip bağlantı gelince yazılacak; genel öğrenme tablosu son okunan (yoksa oyunla gelen varsayılan) haliyle çalışır.

## Sıra
* **Faz 0** — sabit adımlı fizik + girdi kaydı + birebir tekrar (UYGULANDI, yukarıda).
* **Faz 1** — koşu deposu (yerel + açık garaj; kural değişmedi), arkadaş koşusunu pistte tekrar, yapay zekâ tohum
  havuzu, seçici + başlangıç kuralı (UYGULANDI, yukarıda).
* **Faz 2** — kalış ölçümü, yarış günlüğü, gece toplama, öğrenici, kapatma anahtarı, panel tablosu (UYGULANDI, yukarıda; deploy bekliyor).
* **Faz 3** — sanal oyuncularla öğrenme testi (ör. "kaybedince çıkan" sanal oyuncu → sistem KOLAY'a kaymalı),
  denge ölçümü, Data safety formu.
