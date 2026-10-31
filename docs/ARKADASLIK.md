# Arkadaşlık — kod, istek, arkadaş garajı ziyareti

Durum: 2026-10-05. Facebook girişi DÜŞÜNÜLDÜ, BIRAKILDI (Meta App Review + işletme doğrulaması; `user_friends`
yalnızca oyunu oynayan arkadaşları döndürür). Yerine: arkadaş kodu + karşılıklı istek (bu belge) ve sonra
Google Play Games arkadaş listesi (henüz yok, bkz. "Sonraki adım").

## Oyuncu ne görür

* Sağ üstte GÖREVLER'in altında **ARKADAŞLAR** plakası. Gelen istek varsa amber olur: `ARKADAŞLAR (1)`.
* Misafir (Google girişi yok): "Google ile giriş yap" + GİRİŞ YAP (PLAYER ekranını açar).
* Profil hesapla girişte KENDİLİĞİNDEN kurulur (2026-10-31, kullanıcı: "profil kurmak için arkadaşlara gitmesi gerekiyor; direkt rastgele isimli açalım, isteyen değiştirsin"): sunucuda profil yoksa rastgele `Usta1234` adı + arkadaş kodu, bildirimsiz (`SocialManager.auto_profile`). Ad PROFİL › DÜZENLE ya da ARKADAŞLAR'dan değişir. Kurulamazsa (ağ) ARKADAŞLAR'daki TAKMA AD SEÇ formu yedektir, sonraki açılışta yeniden denenir. HUD isim plakası takma adı gösterir (yoksa hesap adı). Gerçek ad paylaşılmaz.
* Profil: takma ad (DEĞİŞTİR), arkadaş kodu `AY-7K2Q4M` (KOPYALA), kodla EKLE.
* GELEN İSTEKLER (KABUL / RET), ARKADAŞLARIN (GARAJA GİT / ÇIKAR, çıkarma iki adımlı), GÖNDERDİĞİN İSTEKLER (GERİ AL).
* İki oyuncu birbirine istek atarsa ikinci gönderen doğrudan arkadaş olur.
* GARAJA GİT: kendi garajın **donar**, arkadaşın garajı açılır. Üstte "ARKADAŞ GARAJI · ad · seviye · garaj değeri"
  ve GARAJIMA DÖN (Android GERİ de döndürür). Dönünce her şey kaldığı yerden sürer, ARKADAŞLAR ekranı açıktır.

## Öne çıkan arkadaşlar (Emre Usta · Elif Usta)

Hay Day'deki Greg gibi: herkesin ARKADAŞLARIN listesinin başında duran, oyunla gelen iki garaj. Sunucu gerekmez
(misafir, çevrimdışı ve PC'de de gezilir), çıkarılamaz, istek / kod yoktur.

* **Emre Usta — Gece Garajı** (karanlık, 70 eşya): siyah elmas sac zemin, siyah duvarlar, neon tabelalar ve LED
  şeritler; cam bölmeli karbon sergide damalı altlıklar üzerinde Huracán, 488 Pista, GT3 (projektörler, kupa
  vitrinleri, babalar); kauçuk zeminli tehlike şeritli atölye (kaynak, motor bloğu, varil rafı, tamirci); pencereli
  bölmeli koyu parke lounge (jukebox, otomatlar, langırt, kırmızı dama halı); yarış şeritli giriş plazası, yakıt
  pompası, motosiklet, E60, RS6, CLS.
* **Elif Usta — Pamuk Garaj** (ponçik, 73 eşya): şeker çizgili duvarlar, beyaz parke; pastel karolu bahçe kafe
  (ağaçlar, palmiye, şemsiyeli masalar, ışık dizileri, piknik masası, mangal, köpek kulübesi); nane damalı atölye;
  pembe damalı otoparkta Huracán, Golf, Şahin, A3; açık parke lounge'da CLS, Getz, jukebox; çit ve çiçeklerle giriş.
* Araçlar **fabrika renginde** (kullanıcı kararı: boyanmaz); her garajda 6 araç.

Bu tema için kataloğa (mağazada da satılır) 4 pastel zemin deseni (PEMBE DAMA, NANE DAMA, PASTEL KARO, BEYAZ PARKE) ve
4 duvar kaplaması (PEMBE / NANE / LİLA BOYA, ŞEKER ÇİZGİ) eklendi (`vfx/decor_textures.gd`, `decor/decorations.json`).

Garajlar `gameplay/social/featured/<kimlik>.json` (açık garaj biçimi). **Elle düzenlenmez**: tasarım
`tools/featured/featured_designs.gd`'dedir, `tools/featured/run.sh [kimlik] [--export]` garajı GERÇEK oyunda kurar,
her eşyayı oyunun yerleşim kurallarıyla doğrular (hata varsa dışa aktarmaz) ve `~/Projects/ct_shots/featured/`'a
görüntü alır. Kod: `gameplay/social/featured_friends.gd`. Kimlikler `featured_` önekli (Firebase UID'leriyle karışmaz).

Ziyaret açılınca kamera garajın tamamını çerçeveler (`VisitBar._frame_garage`): 4. seviye garaj varsayılan
yakınlıkta ekrana sığmıyordu.

## Profil (2026-10-16)

* **Avatar:** sol üstte seviye rozetinin üstüne binen yuvarlak avatar (dokun → PROFİL). PROFİL panosunun başında
  profil kartı (fotoğraf + çerçeve + piksel bayrak, takma ad, garaj adı, seviye / garaj değeri, yarış / koleksiyon /
  en iyi 300 m, vitrin aracı) ve DÜZENLE. Misafir DÜZENLE yerine GİRİŞ YAP görür (kullanıcı kararı).
* **PROFİLİ DÜZENLE** (alt pano): FOTOĞRAF (GALERİ / KAMERA / GOOGLE + 12 hazır avatar + "Google fotoğrafı açık /
  kapalı"), ÇERÇEVE (PLAKA; BRONZ 5, GÜMÜŞ 10, ALTIN 20, PLATİN 30. seviye; DAMA 100, KARBON 200, NEON 350, ALEV 450,
  GÖKKUŞAĞI 600 GEM), BAYRAK (44 piksel bayrak, kodla çizilir), VİTRİN (sahip olunan araçlar), İSİM (takma ad + garaj
  adı). Galeri / kamera görüntüsü kırpıcıdan geçer (kaydır, iki parmakla yakınlaştır, DÖNDÜR — JPEG'in EXIF yönü
  okunmaz).
* **Google fotoğrafı yalnızca oyuncu açarsa** avatar olur (2026-10-17, gizlilik: önceden varsayılan açıktı): GOOGLE
  düğmesi ya da "GOOGLE: AÇIK" (192 px JPEG'e çevrilip yüklenir). Kayıt anahtarı `google_photo`; eski `use_google`
  okunmaz (oyuncu seçmeden true yazılıyordu), herkes kapalı başlar. Fotoğrafı olmayan / misafir: kask (hazır avatar p10).
* **Fotoğraf kaldırılınca** (hazır avatar, KALDIR, Google kapalı) açık garaj yeni tanımla yazıldıktan sonra
  `avatars/a_{uid}` silinir (`SocialManager._drop_unused_avatar`); önceden hesap silinene kadar kalıyordu.
* **Arkadaş kartı** (satırdaki avatara / ada dokun): GARAJA GİT · ŞİKAYET ET (FOTOĞRAF / TAKMA AD / GARAJ) · ENGELLE ·
  ÇIKAR; gelen istekte KABUL · RET · ŞİKAYET ET · ENGELLE. Emre / Elif'te yalnız GARAJA GİT.
* **Şikâyet:** `reports/x_{şikâyetçi}_{hedef}` (fotoğrafın o anki kopyasıyla); şikâyet edenin ekranında fotoğraf
  hemen gizlenir. İnceleme Firebase konsolundan: uygunsuz fotoğraf için `avatars/a_{uid}` belgesi silinir (oyuncular
  kask görür; sahibi yeni fotoğraf yükleyene kadar).
* **Engelle:** arkadaşlıktan iki taraftan çıkarır, bekleyen istekleri siler, yeni isteklerini sessizce siler,
  fotoğrafını gizler. Liste kayıtta (`profile.blocked`); engellenene kodla istek atılırsa engel kalkar.
* Emre ve Elif'in portreleri / 12 hazır avatar: `tools/avatars/` (SVG kaynak, `make_presets.py` üretici,
  `render_avatars.gd` Godot ile PNG'ye çevirir → `assets/ui/avatars/`, 256 px).

| Yol | İçerik | Kim |
|---|---|---|
| `push/p_{uid}` | token, lang, at | sahibi yazar / okur / siler; Cloud Function okur |
| `push_log/l_{alıcı}_{gönderen}` | at (son bildirim) | yalnız sunucu |
| `users/{alıcı}/races/e_{gönderen}` | name, car, paint, build, their_car, won, revenge, mw, ml, at | arkadaş yazar; alıcı okur / siler |
| `garages/g_{uid}` (+) | av (`""` / `pNN` / `img:<8 hex>`), frame, flag, title, car, stats {wins, races, cars, best, best_car} | sahibi yazar |
| `avatars/a_{uid}` | img (base64 JPEG ≤ 40000), hash, at | giriş yapmış herkes okur, sahibi yazar / siler |
| `reports/x_{şikâyetçi}_{hedef}` | target, reason, av, img, name, at | yalnız yazılır (konsoldan okunur) |

Arkadaşın fotoğrafı `user://avatars/<uid>.jpg` önbelleğinde; hash değişmedikçe yeniden indirilmez. Kendi fotoğrafın
`user://profile/photo.jpg`; yeni cihazda `avatars/a_{uid}` belgesinden geri yüklenir. Test: `tools/run_tests.sh
profile_test` (56); görüntüler `qa/profile_shots.gd`; ekran taraması `profil_*`, `arkadas_karti` durumları.

## Arkadaş rakip (yarış, 2026-10-17)

Orijinal Car Town gibi: yarış şeridinden gelen rakiplerin **%70'i bir arkadaşın aracıyla** gelir
(`RaceManager.friend_chance`), kalan %30 isimsiz NPC.

* **Kim gelir:** önce gerçek arkadaşların, oyuncunun aracına performansça uyan araçları (`RaceManager.rival_window`:
  rakip havuzunun süre penceresi, arkadaşın MODİFİYELİ süresiyle). Uyan yoksa havuzdan seçilen araç Emre ya da
  Elif'le gelir; ikisi yarışta her araca sahiptir. Hangisinin geleceği aracın karakterine göre
  (`FeaturedFriends.EMRE_CARS` / `ELIF_CARS`; listede olmayan araç S / A sınıfıysa Emre). İlk yarışta (eğitim)
  gerçek arkadaş gelmez. Aynı modelden tek araç kuralı geçerli: arkadaşın aracı şehirdeyse o gelmez.
* **Araç:** arkadaşın BOYASIYLA ve PERFORMANS MODİFİYELERİYLE (açık garaja `performance.builds` yayınlanır;
  `PublicGarage.race_data`). Emre / Elif fabrika renginde ve modifiyesiz. Pistte rakip, yoldan gelen aracın
  görünümüyle çıkar (eskiden paylaşılan görünüm = oyuncunun boyası kullanılıyordu).
* **Görünüş:** balonda yuvarlak fotoğraf + damalı bayrak (`CarBubble.show_avatar`, shader glyph 3; isimsiz rakipte
  yalnız bayrak). Davet panosu "ELİF USTA YARIŞMAK İSTİYOR!" + rakip plakasında fotoğraf / ad, modifiyeli araçta
  sınıf / GENEL modifiyeli. Sonuç panosunda fotoğraf + "ELİF USTA'YI YENDİN!" / "ELİF USTA KAZANDI" (Türkçe ek:
  `Loc.accusative`, sayıyla biten adlar dahil). Pistte fotoğraf yok (kullanıcı kararı). Ödüller değişmedi
  (arkadaş bonusu, bildirim, İNTİKAM ve skor 3. aşamada).
* Test: `tools/run_tests.sh friend_race_test` (50). Görüntüler: `qa/friend_race_shots.gd` (sahte Firebase'le Bob +
  Elif turu); ekran taraması `yaris_arkadas_*`.

## Yarış haberleri, İNTİKAM, skor, arkadaş bonusu (aşama 3, 2026-10-17)

* **Haber:** gerçek arkadaşın aracıyla yarış bitince (kazansan da kaybetsen de) ona yazılır:
  `users/{o}/races/e_{ben}` = {name, car (benim aracım), paint, build, their_car (onun aracı), won, revenge, mw, ml, at}.
  Gönderen başına TEK belge (en son yarış üzerine yazılır). Yalnızca arkadaş yazabilir (kural). Emre / Elif'e yazılmaz.
* **Görünüş:** HUD'da kısa bildirim ("BOB USTA, VW GOLF 7 ARACINI YENDİ! · İNTİKAM İÇİN: ARKADAŞLAR" ya da "VW GOLF 7
  ARACIN BOB USTA'YI YENDİ!"), ARKADAŞLAR sayacına eklenir, ARKADAŞLAR'ın başında YARIŞ HABERLERİ bölümü (İNTİKAM AL /
  TAMAM). Aynı haber bir kez bildirilir (`social.json` events_seen).
* **İNTİKAM AL:** arkadaş senin aracını yendiyse; pist DOĞRUDAN açılır (`RaceManager.start_revenge`, yoldaki davet
  kapanır), rakip onun o aracı (boya + modifiye), oyuncu güncel yarış aracıyla. Haber kullanılınca silinir. Sonuç
  panosu başlığı İNTİKAM, rövanş yok; sonuç arkadaşa İNTİKAM haberi olarak gider (o da intikam alabilir).
* **Skor (iki yönlü):** `RaceManager._rivals[uid]` = {mw, ml: ben onun aracına karşı; tw, tl: o benim aracıma karşı}.
  Her yönü yalnızca yarışan sayar ve habere kendi yönünü (mw / ml) yazar; alıcı karşı yönü olduğu gibi alır → iki
  tabela aynı (ör. "SKOR SEN 5 – 5 BOB USTA", arkadaş kartında ve satırında). Emre / Elif'e karşı kendi yönüm sayılır.
* **Arkadaş bonusu:** gerçek arkadaşı yenmek +%20 para (`FRIEND_BONUS`), arkadaş başına UTC günde bir; davet panosunda
  "ARKADAŞ BONUSU +%20 DAHİL", sonuçta "(+X ₺ ARKADAŞ BONUSU)". Skor ve bonus günü kayıtta ("race" bölümü).
* **Hesap silme:** bana gelen haberler ve arkadaşlara yazdıklarım silinir. Engellenen / artık arkadaş olmayanın haberi
  okunurken sessizce silinir.
* Test: `tools/run_tests.sh race_news_test` (34); kurallar emülatörde (`races` bölümü). Görüntüler `qa/race_news_shots.gd`.

## Telefon bildirimi (FCM, 2026-10-17)

* **Ne zaman:** arkadaş senin aracını yenince (haberde `won: true`), oyun kapalıyken de telefona "Bob Usta yarışta aracını
  yendi! İntikam almak için dokun 🏁" (İNTİKAM'da "intikamını aldı…"). Alıcının oyun diline göre TR / EN / ES.
  Kaybeden gönderen bildirim doğurmaz (haber oyun içinde görünür).
* **Sınır (kullanıcı kuralı):** aynı gönderen → aynı alıcı çiftine 6 saatte EN ÇOK BİR: A→B gider, A→B tekrar gitmez,
  A→C gider, C→B gider. Sınır SUNUCUDA (`push_log/l_{alıcı}_{gönderen}`, istemciye kapalı). Hak YALNIZCA gönderilen
  bildirimle tükenir: jetonu olmayan alıcı (bildirimi henüz açmamış) ya da FCM'nin reddettiği gönderim hakkı yemez.
* **Veri yükü anahtarları:** FCM `from`, `message_type`, `google.` / `gcm.` ile başlayan anahtarları reddeder. İlk sürüm
  `from` kullandığı için hiçbir bildirim gitmedi (2026-10-17, logda `Invalid data payload key: from`); artık `sender`.
  Sunucu logu: `firebase functions:log --only raceNewsPush --project car-town-remake` (sonuç: skip / throttled /
  no-token / sent / stale ya da hata).
* **Sunucu:** `firebase/functions` — `raceNewsPush` (Cloud Functions 2. nesil, europe-west4; Firestore eur3).
  Tetik `users/{uid}/races/{eventId}` yazması. Mantık `news.js` (birim testi `npm test`, uçtan uca `npm run e2e`:
  Functions + Firestore emülatörü; emülatörde ileti FCM yerine `_e2e_fcm` koleksiyonuna yazılır). Geçersiz jeton gelince `push/p_{uid}` silinir. Durum çubuğu ikonu
  `mipmap/icon_monochrome` (export_presets adaptive_monochrome), renk amber.
* **İstemci:** `gameplay/social/push_service.gd` — açma / kapama **AYARLAR → SES VE BİLDİRİMLER → YARIŞ BİLDİRİMLERİ**
  (2026-10-17, ARKADAŞLAR ekranından taşındı; Google girişi yoksa kilitli ve nedeni yazılı, son başarısız denemenin
  nedeni satırda). İzin oyun açılışında İSTENMEZ: **ilk yarıştan sonra**, oyuncu şehre dönüp boşta kalınca bir kez
  `ui/hud/push_prompt.gd` açılır ("YARIŞ HABERLERİ — Seni kim yendi, ilk sen duy!"; TAMAM → izin, ŞİMDİ DEĞİL → kapanır;
  bu cihazda bir daha sorulmaz, `push.json` "asked"). Misafire sorulmaz, giriş yapınca bir sonraki yarıştan sonra sorulur.
  QA `qa/bildirim_onerisi_qa.gd`. Akış: rıza (rızasız jeton yazılmaz) → Android 13+ bildirim izni → FirebaseMessaging jetonu (JavaClassWrapper, Task yoklanır;
  eklentide mesajlaşma modülü yok, kütüphane `export_plugin.gd` bağımlılığı) → `push/p_{uid}` = {token, lang, at}.
  KAPAT siler; çıkış yapınca jeton geçersiz kılınır; hesap silmede belge silinir. Oyun açıkken telefon bildirimi
  görünmez: `SocialManager` 2 dakikada bir haberleri yoklar (tek liste okuması) → HUD bildirimi.
* **Gönderim:** proje Blaze planında (2026-10-17). `firebase/` klasöründen
  `firebase deploy --only functions,firestore:rules --project car-town-remake` (Node 22, firebase-functions 7,
  firebase-admin 13 — 14 Node 22 ister, yerel emülatör testleri Node 20'de koşuyor). İlk 2. nesil gönderimde Eventarc
  servis hesabı izni yayılana kadar "Permission denied while using the Eventarc Service Agent" hatası olağan: birkaç
  dakika sonra yeniden gönder. Artifact Registry temizlik politikası kurulmadı (eski kalıplar birikir; az ücret).

## Davet linki (2026-10-17)

Kullanıcı isteği: arkadaş kodu yazmak yerine link. A linki B'ye atar, B açınca A'nın profilini görür ve ekler. A onaylamaz,
çünkü linki kendisi gönderdi. Linkler 1 saat geçerli.

**Akış:**
1. A, ARKADAŞLAR → **DAVET LİNKİ GÖNDER**'e basar. `SocialManager.create_invite` şu belgeyi yazar:
   `invites/{jeton}` = {uid, name, code, at}. Jeton 12 karakter kriptografik rastgele (`SocialNames.random_token`).
   Ardından telefonun paylaşım penceresi açılır (`LinkShare`; PC'de link panoya kopyalanır).
2. Paylaşılan link: `https://autoyard.online/d/<jeton>`. Web sitesindeki `davet.html` + `davet.js`
   (`vercel.json`'daki `/d/:token` yönlendirmesi) Android'de `intent://davet/<jeton>#Intent;scheme=autoyard;…` ile oyunu
   açar. Oyun yüklü değilse sayfa `?yok` ile geri döner ve indirme düğmesi öne çıkar.
3. Oyun linki `gameplay/social/invite_links.gd` ile okur: açılışta ve oyun her öne geldiğinde etkinliğin
   `getIntent().getDataString()` değerine bakar. Masaüstü / QA için `-- --davet=<jeton>`. HUD, oyuncu boşta kalınca
   `ui/hud/invite_screen.gd` ekranını açar.
4. B, **ARKADAŞ EKLE**'ye basar. `accept_invite` iki arkadaşlık belgesini de yazar; belgelerde `inv` (jeton) durur ve
   kural daveti doğrular. Aradaki bekleyen istekler silinir.

**Ekran durumları:** eklenebilir · eklendi (GARAJINA GİT) · zaten arkadaş · kendi linkin · süresi dolmuş · bulunamadı ·
bağlantı hatası (TEKRAR DENE) · giriş gerekli (GİRİŞ YAP) · takma ad yok (ARKADAŞLAR) · PC.

**Giriş:** Google girişi sahneyi yeniler. Bekleyen davet `InviteLinks.pending` (statik) ile kaybolmaz; oturum hazır olunca
ekran bir kez daha açılır. Oyuncu misafir kalırsa ısrar etmez.

**Kurallar (`firebase/firestore.rules`):**
- `invites`: yalnız sahibi oluşturur. `at` sunucu saatine ±10 dk olmalı, böylece ömür istemci saatiyle uzatılamaz.
  Belge jetonla tek tek okunur (`get`), liste kapalı. Yalnız sahibi siler.
- `friends`: yeni bir yol daha var. Geçerli davet (`inv`, diğer taraf oluşturmuş, `at + 3600` dolmamış) varsa linki açan
  iki belgeyi de yazar. Kendini arkadaş ekleme kapalı.
- Emülatör testi `rules_test.mjs`'de "arkadaş daveti" bölümü; bütün kurallar 0 hata.

**Kararlar ve sınırlar:**
- Link 1 saat içinde birden çok kişi tarafından kullanılabilir (A linki kime gönderdiyse).
- Davet belgeleri cihazdaki listeden (`social.json` → "invites") temizlenir: yeni davette süresi dolanlar, hesap silmede
  hepsi. Kalanları (başka cihaz, silinen hesap) sunucudaki `cleanupExpired` süresi dolunca en geç 1 saatte siler.

**Android:**
- Ana etkinlik dışa kapalı (`exported=false`) ve eklentilerin uygulama içeriği birleşik manifest'te etkinlikten önce
  geliyor. Bu yüzden `autoyard://davet` filtresi ayrı bir activity-alias olarak (`.InviteLink`) şablonun ana
  manifest'ine, başlatıcı takma adının ardına yazılır.
- Yazan, Firebase eklentisinin dışa aktarma kancası (`addons/GodotFirebaseAndroid/export_plugin.gd`
  `_ensure_invite_link_alias`). Her dışa aktarımda denetler; android/ git'te olmadığı için şablon yeniden kurulsa da
  geri gelir.
- Doğrulanmış https App Link (linke dokununca tarayıcısız açılış) Play imza SHA-256'sı gerektirir; şimdilik yok.

**Test:** `social_test` §12 (sahte Firebase'le uçtan uca); QA `qa/davet_linki_qa.gd` (1170x540 + 853x480).

## Kod

| Dosya | Görev |
|---|---|
| `gameplay/social/social_manager.gd` | Profil, kod, istekler, liste, açık garaj yayını, ziyaret, hesap silmede temizlik |
| `gameplay/social/public_garage.gd` | Kayıttan yalnızca görsel kısım (para / gem / kasa / görev YOK) |
| `gameplay/social/social_names.gd` | Kod alfabesi, takma ad kuralı, küfür filtresi |
| `gameplay/social/garage_visit.gd` | Ziyaret: kendi sahneyi dondurur, Main.tscn'yi ziyaret kipinde açar |
| `ui/hud/friends_screen.gd` | ARKADAŞLAR ekranı (kodla kurulur, UiRouter MODAL `friends`). 2026-10-17 yeniden tasarım: kaymayan başlık (sekmeler ARKADAŞLAR / İSTEKLER ● / HABERLER ●, ↻, ✕), DAVET LİNKİ + KODLA EKLE (pencere: kodun, arkadaş kodu, takma ad), yalnızca yatay kart vitrini kayar; ustalar başta altın şeritli. Kartta istatistik kutusu (ARANIZDA skor, KAZANMA %, KOLEKSİYON, EN İYİ 300 M); kartın düğmeler dışındaki her yeri profil açar; başlık altın kask rozeti + altın çizgi. QA `qa/arkadaslar_qa.gd` |
| `ui/hud/visit_bar.gd` | Ziyaretteki tek arayüz |
| `gameplay/social/player_profile.gd` | Profil seçimleri, fotoğraf dosyası, Google fotoğrafı, engellenenler (kayıt: "profile") |
| `gameplay/social/profile_catalog.gd` | Hazır avatarlar, çerçeveler, bayraklar, fotoğraf kodlama |
| `ui/hud/profile_card.gd` · `avatar_view.gd` · `avatar_button.gd` · `flag_icon.gd` | Kart, yuvarlak avatar + çerçeve, piksel bayrak |
| `ui/hud/profile_edit_screen.gd` · `avatar_cropper.gd` · `camera_capture.gd` · `photo_picker.gd` | Düzenleme, kırpma, kamera, galeri |
| `ui/hud/friend_card_screen.gd` | Arkadaş kartı (şikâyet / engel) |
| `gameplay/social/invite_links.gd` · `ui/hud/invite_screen.gd` · `ui/hud/link_share.gd` | Davet linki: okuma, ekran, paylaşım |

`SocialManager`'ı `GarageSystem` kodla kurar ("social" grubu). Oturum `CloudSaveManager`'ındır: sosyal yalnızca
bulut kaydı **SYNCED** iken başlar ve açık garaj yalnızca o zaman yayınlanır (kayıt seçimi sürerken cihazdaki kayıt
henüz bu hesabın olmayabilir).

## Firestore

Kurallar: `firebase/firestore.rules`. Test: `firebase/rules_test` (yerel emülatör, gerçek projeye dokunmaz):

```
cd firebase && (cd rules_test && npm install)   # ilk sefer
firebase emulators:exec --only firestore --project demo-cartown "node rules_test/rules_test.mjs"
```

| Yol | İçerik | Kim |
|---|---|---|
| `garages/g_{uid}` | name, code, level, value, garage_json, updated_at | herkes (girişli) okur, sahibi yazar |
| `codes/{KOD}` | uid | bir kez alınır, üzerine yazılamaz |
| `users/{alıcı}/inbox/r_{gönderen}` | name, code, at | gönderen yazar; iki taraf okur / siler |
| `users/{gönderen}/outbox/o_{alıcı}` | name, code, at | sahibi yazar; alıcı kabul / ret ederken siler |
| `users/{a}/friends/f_{b}` | since | iki belgeyi de KABUL EDEN yazar (o an gelen kutusunda istek olmalı) |

**Belge kimlikleri hiçbir zaman çıplak UID değildir** (`g_ / r_ / o_ / f_`). Firebase eklentisi sonuçları
yalnızca belge kimliğiyle bildirir (koleksiyon yok) ve `CloudSaveManager` kendi sonucunu "kimlik == UID" diye tanır.
Önek kaldırılırsa bulut kaydı sosyal yazmanın sonucunu kendi sonucu sanar. `SocialManager` isteklerini sırayla
gönderir; koleksiyon listesinin sonucunda kimlik yoktur (bulut kaydı liste istemez).

Okuma maliyeti: açılışta 3 liste + arkadaş başına 1 okuma; ekran 30 sn'den sık yenilenmez. Ziyaret 1 okuma.

## Ziyaret kipi

`GarageVisit.begin`: kendi sahne `root`'tan çıkarılır (silinmez), Main.tscn'nin yeni kopyasında:
`SaveManager.visit_mode = true` (diskten okumaz, arkadaşın açık garajını uygular, `save_game` / `new_game` /
`apply_snapshot` reddedilir), HUD ve CloudSaveManager çıkarılır, `GarageSystem` kasa / görev / reklam / sosyal /
düzenleyici kurmaz. SaveManager işaretlenemezse ziyaret açılmaz. Gruplar ağaca bağlı olduğu için kendi sahnenin
yöneticileri ziyaret boyunca bulunmaz. Ziyaretten önce kendi kayıt diske yazılır; bulut yazması sürüyorsa ziyaret
reddedilir ("birazdan tekrar dene").

## Hesap silme

`CloudSaveManager` Google doğrulamasından sonra, bulut kaydından ÖNCE `SocialManager.delete_all(uid)` çağırır:
arkadaşlıklar iki taraftan, istekler, açık garaj ve kod silinir. Silinemezse hesap silinmez.
Sosyal oturum hiç açılmamışsa (oyun internetsiz açıldı / bulut kaydı ERROR) silme yine Google hesabının uid'iyle yapılır,
kod bu cihazda yoksa açık garajdan okunur (2026-10-17; önceden bu durumda sosyal veriler silinmeden kalıyordu).
Test: social_test §13.

## Sunucu temizliği (Cloud Function `cleanupExpired`, 2026-10-17)

Saatte bir (europe-west4, Cloud Scheduler) süresi dolan kayıtlar silinir — gizlilik politikasındaki süreler:
`invites` 1 saat dolunca, `push_log` 1 gün, `reports` 180 gün. Mantık `firebase/functions/cleanup.js`
(test: `npm test`, emülatör: `npm run cleanup-e2e`).

## Testler

* `tools/run_tests.sh social_test` — sahte Firebase (sırasız gecikmeli yanıtlar, sadeleştirilmiş kurallar),
  profil, kod çakışması, yayın + bulut kaydı birlikte, istek / kabul / ret / geri alma / çıkarma, çevrimdışı,
  zaman aşımı, hesap silme. `SOCIAL_SEED=<n>` ile farklı yanıt sırası.
* `tools/run_tests.sh visit_test` — gerçek Main.tscn: donma, ziyaret sahnesi içeriği, ziyarette hiçbir dosya /
  buluta yazma olmaması, dönüş.
* `qa/social_shots.gd` — ekran görüntüleri (`~/Projects/ct_shots/social/`).

## Sonraki adım: Play Games arkadaşları

Ön koşul (Play Console, kullanıcı): Play Games Services projesi + Oyun Kimliği (Game ID), OAuth istemcisi, yükleme
ve Play imza anahtarının SHA-1'leri. Sonra: `godot-sdk-integrations/godot-play-game-services` eklentisi (autoload
yok, singleton doğrudan), "Play Games arkadaşlarını getir" butonunda izin, `pgs/p_{playerId} → uid` eşlemesi.
Google kuralı: arkadaş listesi saklanırsa düzenli yeniden doğrulanmalı → saklanmaz, her açılışta yüklenir.
