# Haftalık drag lider tablosu (2026-10-26)

Özellik raporu P1 #3. Kararlar kullanıcıyla soru-cevapla verildi (hafıza: p1-koleksiyon-lider-etkinlik). Görünüm taslak
**B "podyum + liste"**, satırlarda A'nın **İZLE** düğmesi; haritada şehrin kuzeybatısında **DRAG PİSTİ** noktası (tuval:
https://claude.ai/artifact/JawMeeZcKSp29o7oT5Hf9e).

## Kurallar (kullanıcı kararları)

- **Her drag yarışı sayılır**; ayrı bir mod yok. Tabloda oyuncunun o hafta, o sınıftaki **en iyi 300 m süresi** durur.
- **Sınıf başına tablo:** D, C, B, A, S. Sınıf, yarışılan aracın katalog sınıfıdır (`CarCatalog` `class`).
- **Listeler:** DÜNYA, ÜLKE (profildeki bayrak) ve ARKADAŞLAR.
- **Hile:**
  - Makul sınır: aracın en yüksek modifiyeyle kuramsal en iyi süresinin altı reddedilir (`firebase/functions/lb_limits.json`).
  - Yönetim panelinden kayıt silinebilir.
- **Ödüller:** her sınıf ayrı; elmas + kasa; tutarlar panelden değiştirilebilir (`config/app.leaderboard`). Kademeler:
  - İLK 3;
  - İLK %10;
  - İLK %50.
- **Sıfırlama:** Pazartesi 00:00 (Türkiye). Ödül HABERLER'e posta olarak gelir; postanın bildirimini mevcut `mailPush` gönderir.
- **Tablodaki koşu YALNIZ İZLENİR** (hayalete karşı yarış yok).
- **Arkadaşın seni geçince:** telefon bildirimi + OTO MANŞET haberi. Çift başına haftada bir.
- **Misafir:** tabloyu görür ama giremez (hesap önerisi).
- **Satır:** avatar + bayrak + ad, araç ve boyası, modifiye kademesi, seviye, süre, İZLE.
- **Girişler:** HARİTA'daki DRAG PİSTİ noktası ve yarış sonucu ekranı (sıra değişimi + TABLO düğmesi).

## Hafta

`wk` = Pazartesi'den başlayan hafta numarası, Türkiye saatiyle (UTC+3, yaz saati yok):
- `gün = floor((unix + 10800) / 86400)`
- `wk = floor((gün + 3) / 7)`. Unix 0 bir Perşembe; böylece hafta Pazartesi 00:00 TR'de döner.

Örnek: 2026-10-26 Pazartesi 00:00 TR (25 Ekim 21:00 UTC) → `wk = 2965`; bir saniye önce 2964. Oyun (`Leaderboard.week_of`) ve sunucu aynı hesabı yapar.

## Firestore

### `lb_runs/{wk}_{cls}_{uid}`: oyuncunun haftalık en iyi koşusu (o sınıfta)

| alan | tür | not |
|---|---|---|
| `uid` | string | belge kimliğinin sonu ile aynı, `request.auth.uid` |
| `wk` | int | şimdiki hafta (kural `request.time`'dan hesaplar) |
| `cls` | string | `D` `C` `B` `A` `S` |
| `time` | number | sn, 4–30; güncellemede yalnız daha küçük |
| `car` | string | araç kimliği (`^[a-z0-9_]{1,40}$`) |
| `paint` | string | `#RRGGBB` ya da `""` (fabrika) |
| `stage` | int | 0–5, modifiye kategorilerinin en yükseği |
| `level` | int | 1–99 |
| `name` | string | oyuncunun görünen adı; kural `isValidName` (3–16, harf / rakam / boşluk / `._-`, garajla aynı) |
| `av` | string | ≤ 40; profil avatarı başvurusu (`garages.av` ile aynı biçim: `pNN`, `img:<hash>` ya da `""`) |
| `flag` | string | `""` ya da iki büyük harf ülke kodu |
| `run` | string | ≤ 2000 karakter: `DragRaceSim.Recording.to_dict()`'in JSON METNİ (İZLE için; Android eklentisi iç içe diziyi bozduğu için harita değil). Sunucu / panel içine bakmaz, özetlere hiç girmez |
| `at` | int | unix sn |

- Yazar: yalnız sahibi (eklentiyle `set`). Okuma: `get` herkese açık (REST, misafir İZLE'yi açabilsin); `list` kapalı.
  İstemci silemez (panel siler).
- Bütün alanlar zorunlu, başka alan yok; kimlik `{wk}_{cls}_{auth.uid}`, `wk` sunucu saatinin haftası (cihaz saati pazartesi
  dönümünde ileri / geri ise yazma reddedilir: geçen haftaya yazılamaz).
- Yasaklı (moderation, sosyal ya da tam) oyuncu yazamaz (garaj kuralıyla aynı `socialAllowed()`).

### `lb/{wk}_{cls}` ve `lb/{wk}_{cls}_{CC}`: özet (YALNIZ sunucu yazar, herkes kimlikle okur)

`{wk, cls, cc ("" dünya), count, hist: {"<int(time*20)>": n}, top: [{uid, name, av, flag, level, car, paint, stage,
time, at}] (en çok 50, süreye, eşitlikte UID'ye göre), updated (unix sn)}`; ödenen haftada ayrıca `paid: true, paid_at,
paid_count`.
- Kural yalnız `get` açar (oturumsuz da); `list` kapalı: oyun özeti kimliğiyle ister.
- Oyuncunun sırası `hist`'ten hesaplanır: daha hızlı kovaların toplamı + kendi kovasında yaklaşık yer.
- Yüzdelik = sıra / `count`.

### Arkadaş geçti haberi: `users/{uid}/lbnews/{wk}_{cls}_{diğer}`

`{uid (geçen), name, av, car, time, my_time, cls, wk, at}`. YALNIZ sunucu yazar; sahibi okur / siler (OTO MANŞET).

### Ödül postası

Ödül, mevcut posta biçiminde `users/{uid}/mail/lb_{wk}_{cls}` olarak yazılır (`MailService` okur, `mailPush` bildirir).

## Sunucu (functions)

Kod: `firebase/functions/leaderboard.js` (saf mantık; `index.js` bağlar), testler `test/leaderboard.test.js` (birim) ve
`test/e2e.mjs` (emülatörde gerçek tetikleyici). Bölge `europe-west4`.

### Veri dosyaları (functions klasörüyle birlikte dağıtılır)

- **`lb_limits.json`** `{araç: en düşük kabul edilen sn}`: `tools/lb_limits.gd` üretir (aracın en yüksek modifiyeyle kusursuz
  koşusu × 0,93). Listede olmayan araçta yalnız mutlak 4 sn tabanı geçerli.
- **`lb_classes.json`** `{araç: sınıf}`: `vehicles/cars.json`'dan (`cd firebase/functions && npm run lb-classes`).
  Koşunun `cls`'si aracın katalog sınıfı değilse kayıt reddedilir; listede olmayan araçta sınıf denetlenmez. Birim test dosyanın
  katalogla aynı olduğunu sınar (araç eklenip dosya yenilenmezse `npm test` düşer).
- Fizik / araç verisi değişince ikisini de yenile ve functions'ı yeniden dağıt.

### `lbRun` (`onDocumentWritten lb_runs/{runId}`, en çok 3 örnek)

1. **Doğrulama** (yazmada): kimlikle tutarlılık (`uid` / `wk` / `cls`), 4–30 sn, aracın sınırı, sınıf. Geçersizse belge
   silinir, günlüğe `lbRun: reddedildi <sebep> <kimlik> araç=… süre=… sınır=…` yazılır (sebep `limit` / `class` / `time` / `id`).
   Daha önce geçerli bir kaydı olan oyuncunun reddedilen iyileşmesinde o eski kayıt da gider (belge tektir).
2. **Özet eşitleme (tek işlem):** koşu belgesinin ŞİMDİKİ hâli okunur ve sunucu defteriyle karşılaştırılır:
   **`lb_counted/{runId}`** = özetlerde şu an sayılan satır (+ `pushed`), istemciye kapalı. Fark varsa dünya ve eski / yeni ülke
   özetinde `count` (yalnız yeni kayıtta +1, silmede −1), `hist` (eski kova −1, yeni kova +1; boşalan kova silinir), `top` (ilk
   50) güncellenir; `wk, cls, cc, updated` yazılır, `paid` korunur. Böylece tetikleyici iki kez gelse (en az bir kez teslim) ya
   da sırası karışsa, reddedilen (hiç sayılmamış) kayıt silinse de sayı kaymaz. Ülke değişince eski ülkeden düşer, yenisine girer.
3. **İlk 50'yi yeniden doldurma:** listedeki oyuncu silinince / kötüleşince ya da liste sayıdan kısaysa işlem içinde sorgu:
   `lb_runs where wk ==, cls ==, (flag ==), orderBy time, limit 50`. Sorgu 50'den az getirirse bütün kayıtlar bilinir: `count`
   ve `hist` de bundan kurulur (eski bir kayma burada düzelir).
4. **Arkadaş geçti** (yalnız iyileşmede ya da tabloya ilk girişte): `users/{uid}/friends` (kimlik `f_{diğer}`) → her arkadaşın
   `lb_runs/{wk}_{cls}_{diğer}` belgesi (`getAll`). Eski süreden hızlı olup yeni süreden yavaş kalan arkadaşa
   `users/{arkadaş}/lbnews/{wk}_{cls}_{uid}` yazılır (her geçişte güncellenir; sahibi silip yeniden geçilirse yeniden oluşur).
   **Bildirim çift başına haftada bir** (sınıf başına): gönderilenler geçen oyuncunun defterinde (`lb_counted.pushed`), işlemle
   ayrılır. `push/p_{arkadaş}` jetonu yoksa / `prefs.race` false ise / FCM reddederse hak tükenmez (`news.js` ilkesi);
   geçersiz jeton silinir. Metin alıcının dilinde (tr / en / es / de / fr, bilinmeyen dil en), süre oyundaki gibi iki ondalık:
   tr "{ad} seni {sınıf} sınıfı haftalık tablosunda geçti! ({süre} sn) 🏁". Veri yükü `{type: "lb", wk, cls, sender}`,
   Android etiketi `lb_{cls}`.
- Maliyet: koşu yazması başına okuma = koşu + defter + 1–3 özet (+ seyrek 50 belgelik sorgu); iyileşmede + arkadaş listesi +
  arkadaş sayısı kadar koşu + geçilen arkadaş sayısı kadar jeton. Bir sınıfın bütün koşuları aynı özet belgesine yazar
  (Firestore'da belge başına ~1 yazma/sn sürekli): yarışan işlemler kendiliğinden yeniden denenir; oyuncu sayısı çok büyürse
  özet parçalanmalı (shard).

### `lbWeekly` (zamanlanmış `10 0 * * 1`, Europe/Istanbul; en çok 540 sn)

- Ödenmemiş son iki hafta (`wk-2`, `wk-1`; bir tur kaçsa da sonrakinde öder) × her sınıf: DÜNYA özeti `lb/{wk}_{cls}` yoksa ya
  da `paid` ise geçilir.
- `count` = özetteki sayı. `lb_runs where wk ==, cls ==, orderBy time, limit ceil(count × 0,5) + 20` (yalnız gerekli alanlar);
  bugünkü sınırın altında kalan koşu (dosya sonradan sıkılaştıysa) atlanır, sıra kaymaz. Kademe (`tierFor`): sıra ≤ 3 → `top3`;
  ≤ ceil(count × 0,10) → `p10`; ≤ ceil(count × 0,50) → `p50`; oyuncu yalnız en iyisini alır. Örnek: 1 oyuncu → 1. İLK 3;
  4 oyuncu → yalnız ilk 2 (İLK %50 = 2); 25 oyuncu → 1–3 İLK 3, 4–13 İLK %50.
- Posta `users/{uid}/mail/lb_{wk}_{cls}` (kimlik sabit; toplu yazma): `{title, text (5 dil), from: "AUTO YARD", money: 0, gems,
  crates: {kasa: 1} | {}, decor: {}, at, expires: 0, notify: true, lb: {wk, cls, rank, count, tier}}`. Başlık tr
  "HAFTALIK DRAG TABLOSU · A SINIFI"; metin tr "Geçen haftayı 3. bitirdin! Ödülün burada." / "Geçen hafta İLK %10'dasın (7. sıra)!
  Ödülün burada." / "… İLK %50'desin …". Bildirimi `mailPush` gönderir (`prefs.gift`).
- Sonda özete `paid: true, paid_at, paid_count`: iki kez çalışsa da tek posta.
- Ödüller `config/app.leaderboard.rewards = {top3: {gems, crate}, p10: {…}, p50: {…}}` (elmas 0–1000, kasa yalnız SATILAN
  kasalardan; ikisi de boş kademeye posta gitmez). Kayıt yoksa / alan bozuksa varsayılan: İLK 3 150 elmas + `super_crate`, İLK
  %10 50 elmas + `sport_crate`, İLK %50 15 elmas. Oyun aynı alanı `config/app`'ten okuyup kademe çubuğunda gösterebilir.

### Budama ve profildeki dereceler (kullanıcı kararı 2026-10-26: "yalnız ilk 100'ün kayıtları profillerinde dursun")

- `lbWeekly` ödemeden sonra (ya da önceden ödenmiş ama budanmamış haftada) `pruneWeek` çalıştırır.
  - Koşular süreye göre 300'lük sayfalarla okunur (`startAfter`).
  - Geçerli ilk 100 (`KEEP`, DÜNYA sırası) kalır: koşu kaydı İZLE için durur.
  - Bu 100 oyuncunun derecesi `lb_hist/{uid}`'ye yazılır.
  - Gerisi ve sınırı sonradan sıkılaşan geçersizler, defterleriyle (`lb_counted`) aynı toplu yazmada silinir.
  - Özete `pruned: true, pruned_at, kept` yazılır.
- `lb_hist/{uid}` = `{uid, recs: [{wk, cls, rank, count, tier ("top3" | "p10" | "p50" | ""), time, car, paint, stage}],
  updated}`.
  - En yeni hafta önce (aynı haftada iyi sıra önce), en çok 40 (`HIST_MAX`).
  - Aynı hafta + sınıf yenisiyle değişir: iki kez çalışsa da tek satır.
  - Yalnız sunucu yazar, herkes okur, liste kapalı.
- **Ödenmiş hafta donar:** `lbRun` silme olayında DÜNYA özeti `paid` ise sayıyı / kovaları değiştirmez.
  - Budamanın sildiği koşunun defteri de silinmiştir: iş yok.
  - Defteri olan, ilk 100'de kalmış koşu panelden ya da hesap silmeyle gidiyorsa `forgetFrozen` çalışır: profildeki derece ve
    dünya / ülke `top` listesindeki satırı düşer, defter silinir.
- Hesap silme `lb_hist/{uid}`'yi de siler.

### Dizinler (`firebase/firestore.indexes.json`, `firebase.json` → `firestore.indexes`)

- `lb_runs`: (`wk` ↑, `cls` ↑, `time` ↑) — dünya listesi, `lbWeekly`, `top` yeniden doldurma, panel.
- `lb_runs`: (`wk` ↑, `cls` ↑, `flag` ↑, `time` ↑) — ülke listesi / ülke özeti, panel.
- Tek alan dizini kapalı: `lb_runs.run`, `lb.top`, `lb.hist` (gereksiz dizin girdisi / yazma gecikmesi).
- Emülatör dizin istemez; canlıda dizin yoksa sorgu `FAILED_PRECONDITION` verir (özet güncellemesi ve ödeme durur).

### Hesap silme

`accountCleanup`: `lb_runs` (`uid` alanıyla; her silme `lbRun`'ı tetikler → özetlerden ve `lb_counted`'dan düşer) ve
başkalarının `users/{x}/lbnews/{wk}_{cls}_{uid}` haberleri silinir.

### Panel (`firebase/admin`, sekme **Lider tablosu**)

- `POST /api/lb/list` `{wk?, cls, cc?}` → hafta (varsayılan bu hafta; son 52 hafta), sınıf, kapsam (boş = DÜNYA, iki harf ülke).
  İlk 100 doğrudan `lb_runs`'tan (yönetici SDK'sı, `run` okunmaz): sıra, ad, kısa UID, bayrak, aracın katalog adı ve boyası,
  kademe, seviye, süre, tarih; aracın sınırının %2 yakınındaki süre "sınırda" işaretli. Özet: oyuncu sayısı, güncellenme,
  ödül kesimi (İLK %10 / %50 kaçıncı sıraya kadar), ödendi mi.
- `POST /api/lb/delete` `{id}` → onaylı silme, `admin_log`'a `lb_delete` (kimlik, uid, ad, araç, süre, bayrak). Özeti `lbRun`
  düzeltir.
- `GET` / `POST /api/lb/rewards` → ödül düzenleyici (elmas 0–1000, kasa satılan kasalardan ya da yok; "Varsayılana dön" alanı
  siler). İşlemle yazılır, `config/app`'in öbür alanları korunur; "Sürüm ve bakım" kaydı da `leaderboard`'u korur. Günlük `lb_rewards`.

### Dağıtım

`firebase/` klasöründen (proje HER ZAMAN açıkça `car-town-remake`):

```
firebase deploy --only firestore:rules,firestore:indexes --project car-town-remake
firebase deploy --only functions:lbRun,functions:lbWeekly,functions:accountCleanup --project car-town-remake
```

- Dizinler birkaç dakikada kurulur (konsol › Firestore › Dizinler); oyun kayıt yazmaya başlamadan önce hazır olmalı.
- `firestore:indexes` dosyada olmayan (konsoldan elle açılmış) dizinleri silmeyi sorar: silme.
- `lbWeekly` Cloud Scheduler işi oluşturur (Blaze planı zaten açık).

## Oyun

- **`Leaderboard`** (`gameplay/social/leaderboard.gd`, GarageSystem kurar, grup `leaderboard`):
  - Hafta hesabı (`week_of`, `current_week`, `week_end`) sunucuyla aynı.
  - Yazım: `RaceManager.run_recorded` ile yarış bitince en iyi süreyi yazar (`SocialManager.write_lb_run`). Yalnız hesaplıysa
    ve haftanın o sınıftaki en iyisiyse; etkinlik aracı yarışı ve İZLE kaydı sinyal vermez.
  - Cihazdaki en iyiler `user://leaderboard.json`'da. Yeni cihazda ilk yarışta sunucudaki kayıttan öğrenilir.
  - Sonuç `submitted` ile duyurulur: `{cls, wk, time, best, improved, old_rank, rank, count, pct, next_tier, gap, guest,
    failed}`. Yazılamazsa (`failed`: ağ yok, Pazartesi dönümünde eski hafta, kural reddi) en iyi değişmez.
  - Okuma: özetleri ve tek koşuları oturumsuz REST ile okur (misafir de). Önbellek 60 sn.
  - Arkadaş listesi: arkadaşların kayıtları tek tek okunur.
  - Sıra: `rank_in`, özetin süre kovalarından (`hist`); aynı kovadakiler eşit sayılır.
  - Kademe: `tier_of`. Bir üst kademeye kalan fark: `chase` (hedef sıra `top` listesindeyse kesin süre, değilse kova
    sınırı, 0,05 sn çözünürlük).
  - İZLE için koşuyu indirir (`recording_of`).
- **`LeaderboardScreen`** (`ui/hud/leaderboard_screen.gd`, UiRouter `leaderboard`, MODAL; taslak B + A'nın İZLE düğmesi):
  - üstte başlık + Pazartesi geri sayımı, DÜNYA / ÜLKEM / ARKADAŞLAR;
  - solda plaka sınıflar (D C B A S, açılışta yarış aracının sınıfı);
  - ortada podyum (ilk 3: avatar + bayrak, ad, süre, aracın resmi, basamak, İZLE);
  - sağda liste (4. sıradan: ad, SV, boya noktası, KADEME / FABRİKA, araç resmi, süre, İZLE) ve altta sabit kendi
    satırın (misafire HESAP AÇ);
  - en altta ödül kademeleri + oyuncunun yeri çubuğu.
  - Uzun dilde (EN / DE / FR) satırlar ekrana sığmazsa listenin İZLE düğmeleri yalnız ▶ olur (`_fit_width`).
- **İZLE** (`DragRaceScreen.watch_recording`): yalnız o koşu kayıttan birebir oynar, oyuncu girdisi yok, tabloya / rekora
  yazılmaz; bitince tablo yeniden açılır.
- **Girişler:**
  - HARİTA'da şehrin kuzeybatısında DRAG PİSTİ (`MapScreen.DRAG`). Resim `tools/world/map_render.py` `drag_strip()`
    çizer (tribün, ışık ağacı, bitiş takı). Ağaç / ev seçimleri pistin yerine düşünce rastgele sayılar yine çekilir;
    haritanın geri kalanı değişmez. Noktanın altında "A SINIFI · SEN 41." ya da HAFTALIK TABLO; dokununca tablo açılır.
  - Yarış sonucu (`RaceResultScreen.show_leaderboard`): koyu şerit.
    - "HAFTALIK TABLO · A SINIFI", "128. → 97. ↑ 31" (ilk kayıtta YENİ);
    - haftalık en iyi süre ve "İLK %10'A 0,22 sn KALDI";
    - TABLO düğmesi yarıştan çıkıp tabloyu açar.
    - Misafire "HESAP AÇ, TABLOYA GİR". Koşu yazımı ağ beklediği için bilgi sonuç ekranından önce ya da sonra gelebilir;
      HUD süreyi eşleyip şeride verir.
- **OTO MANŞET:** `SocialManager` girişte `users/{uid}/lbnews`'i okur (`lb_news`). Engellenen / artık arkadaş olmayanın
  ve iki haftadan eski haberi siler.
  - Gazetede `NewsDigest.LB_PASSED`: "ELİF SENİ TABLODA GEÇTİ!", açıklamada iki süre.
  - Önemi seni yenen arkadaşın altında, büyük kazancın üstünde.
  - Gösterilince sunucudan silinir.
- **Profildeki dereceler** (taslak A, kullanıcı 2026-10-26):
  - `ProfileCard` (kendi profilin + arkadaş kartı) istatistiklerin altında koyu TABLO DERECELERİ şeridi gösterir: en iyi
    derece + sınıf + hafta ("1. A 12–18 EKİM"), "6 KEZ İLK 100 · 3 KEZ İLK 3", "TÜMÜ ›".
  - Veri `Leaderboard.history_of(uid)` (`lb_hist/{uid}`, REST). Derecesi olmayanda, öne çıkan kişide ve listeyi açan ekranı
    olmayan kartta (davet) şerit yok.
  - Şeridin tamamı dokunulur (kendi profilinde bilgi sütunu dar: plaka düğme yazıları kesiyordu) → `LbRecordsScreen`
    (ALT PANO `lb_records`): madalya sıralı satırlar (1–3 altın / gümüş / bronz, İLK %10 koyu-amber, diğerleri mavi), sınıf,
    hafta + kaç oyuncu arasında, kademe, araç, süre, İZLE.
  - İZLE bitince ana pano (PROFİL / ARKADAŞLAR) ve liste yeniden açılır.
- **Testler:**
  - `tests/leaderboard_test.gd` (`tools/run_tests.sh leaderboard_test`): hafta, sıra, kademe, kalan fark, yazım, belgenin
    13 alanı, gazete haberi.
  - Görsel denetim: `qa/lider_tablosu_qa.gd`, kipler `hesap | misafir | izle | harita | sonuc | profil`; `QA_LANG=de` ile
    dil.
- **Hile sınırı dosyası:** `tools/lb_limits.gd` → `firebase/functions/lb_limits.json`. Fizik / araç verisi değişince
  yeniden üret ve functions'ı yeniden dağıt.
