# Arkadaş daveti ödülü (tasarım)

2026-10-23. Kullanıcı isteği: "Arkadaşa önerme ekleyeceğiz. Önerdiğin her arkadaş oyunu indirip girerse ödül olacak,
en büyük ödül 10. arkadaşta."

Durum: **TASARIM ONAYLANDI · FAZ 1–3 UYGULANDI (2026-10-23, commit yok; kurallar + fonksiyonlar CANLIDA)**. Görsel taslaklar: https://claude.ai/artifact/7mRspEq7zkk5qvTaPNitya
(A: ARKADAŞLAR'da DAVET ET sekmesi · B: ayrı DAVET MERDİVENİ ekranı · C: DAVET PİSTİ; ortak: davet edilenin karşılaması +
ödül anı). **Seçilen: A**; kararlar en altta.

## Özet

1. A, **ARKADAŞINI DAVET ET**'e basar. Telefonun paylaşım penceresi açılır. Mesajda link ve A'nın arkadaş kodu
   (`AY-K7P2QX`) vardır.
2. B linke dokunur. Oyun yüklü değilse Play'e gider; Play linki A'nın kodunu **yükleme kaynağı** (install referrer)
   olarak taşır. B oyunu kurup açtığında oyun kodu buradan okur. Link kaybolduysa (B oyunu arayıp bulduysa) B kodu elle
   girer.
3. B **hesapla** giriş yapınca (Google / Facebook / e-posta; misafirin UID'si yok) sunucu daveti doğrular:
   - B ile A otomatik **arkadaş** olur.
   - B'ye **hoş geldin hediyesi** postayla gelir.
   - A'nın listesinde B "KATILDI" olarak görünür.
4. B **3. seviyeye** ulaşınca davet **sayılır** (öneri, bkz. kararlar). A'nın sayacı bir artar ve o basamağın ödülü A'ya
   postayla gelir. A'ya telefon bildirimi gider.
5. 10. arkadaşta en büyük ödül verilir. Merdiven 10'da biter.

## Ödül merdiveni (öneri)

₺ ödülleri giriş merdiveniyle aynı kuralla verilir: oyuncunun o anki **aktif gelirinin dakikası**
(`OfflineEarnings.current_active_rate`). Taslaklardaki tutarlar "garaj 2" oyuncusuna (≈991 ₺/dk) göredir.

| Arkadaş | Ödül | Not |
|---|---|---|
| 1 | 50 💎 | |
| 2 | 12 dk gelir ₺ | garaj 2'de ≈12.000 ₺ |
| 3 | SPOR KASASI | 100 💎 değerinde |
| 4 | 75 💎 | |
| 5 | **NEON "DOSTLAR" TABELASI** + **DAVETÇİ** gümüş profil çerçevesi | dekor ve çerçeve mağazada yok, satılmaz |
| 6 | 30 dk gelir ₺ | ≈30.000 ₺ |
| 7 | PRESTİJ KASASI | 150 💎 değerinde |
| 8 | 120 💎 | |
| 9 | 45 dk gelir ₺ | ≈45.000 ₺ |
| 10 | **EFSANEVİ ARACINI SEÇ** + **ELÇİ** altın profil çerçevesi | SÜPER KASA havuzundan, sahip olmadığın biri |

Toplam elmas 245 (≈7 günlük kazanç), kasaların değeri 250 💎. 10 gerçek oyuncu getiren biri için cömert ama ekonomiyi
bozmayan bir miktar. **10'dan sonra** ödül yok. Profildeki "davet ettiği" sayısı artmaya devam eder. Davet edilen yine hoş
geldin hediyesini alır.

**Davet edilenin hoş geldin hediyesi:** 50 💎 + 5.000 ₺. Başlangıç parası 5.000 ₺ olduğu için bu iki katı demek. Ön kayıt
ödülü (10.000 ₺ + 100 💎) bundan büyük kalır. Hediye 3. seviyeyi beklemez, katılınca gelir: linkin çekiciliği buradan
gelir.

## Bağlantı ve kaynak (attribution)

**Link:** `https://autoyard.online/d/<JETON>?r=<KOD>`. Bugünkü 1 saatlik davet jetonuna kalıcı `r=` eklenir:

- Oyunu yüklü **eski oyuncu** 1 saat içinde açarsa bugünkü gibi anında arkadaş olur. Davet ödülü yalnız yeni oyunculara
  verilir.
- Oyunu **yüklemek zorunda olan** yeni oyuncu jetonun ömrüne takılmaz, çünkü `r=` kalıcıdır.
- Profilde/Instagram'da paylaşmak için ayrıca `https://autoyard.online/r/<KOD>` (yalnız kod) var.

Paylaşım metni (5 dil): *"Auto Yard'da garajıma gel, ikimiz de hediye kazanalım! Davet kodum: AY-K7P2QX
https://autoyard.online/d/…?r=K7P2QX"*

**Site (`auto_yard_website`, `davet.js`):**

- Android'de oyun yüklüyse `intent://davet/<JETON>?r=<KOD>` ile açılır.
- Yüklü değilse (`browser_fallback_url`) doğrudan
  `https://play.google.com/store/apps/details?id=com.autoyard.app&referrer=ref%3D<KOD>%26inv%3D<JETON>` adresine gider.
  Bugünkü `?yok` sayfası yerine bu kullanılır.
- Masaüstünde kod ve Play QR'ı gösterilir.
- `/r/<KOD>` de aynı akıştır, yalnız jetonsuz.
- Not: `playStoreLive` şu an false. Play'de yükleme kaynağı ancak gerçek kurulumda gelir; ön kayıtla gelen otomatik
  kurulumda gelmez.

**Oyun, kodu üç yoldan alır:**

1. **Play Install Referrer**, yalnız ilk açılışta. Kütüphane: `com.android.installreferrer:installreferrer:2.2`. Gradle
   bağımlılığı `addons/autoyard_android/plugin.gd` → `_get_android_dependencies` ile eklenir (Appodeal'deki gibi, eklenti
   AAR'ı yok).
   - `InstallReferrerStateListener` arayüzü Godot 4.7'deki **`JavaClassWrapper.create_proxy`** ile GDScript'te yazılır
     (godot-docs MCP ile doğrulandı).
   - Okunan `ref=` kodu `user://referral.json`'a yazılır: `{code, src:"play", at}`.
   - Okumayı kaç kez denediğimiz kayıtta tutulur. Kaynak 90 gün geçerlidir.
2. **Derin link:** `InviteLinks` `?r=` parametresini de ayıklar (`src:"link"`).
3. **Elle kod:**
   - ARKADAŞLAR › DAVET ET'te "DAVET KODUN VAR MI?" alanı. Yalnız uygun hesaplarda görünür: hesap 7 günden yeni ve
     daveti henüz yok.
   - Ayrıca uygun yeni oyuncu **KODLA EKLE** ile birini eklerse "Seni MERT mi davet etti?" sorusu çıkar (EVET / HAYIR).
     Kodu linksiz paylaşanları da yakalar.

**Misafir B:** kod cihazda bekler. Ekranda "Hediyeni almak için GİRİŞ YAP" yazar. Giriş yapınca hesap 7 günden yeniyse
talep gönderilir. Misafirken 3. seviyeyi geçtiyse katılma ve sayılma aynı anda olur.

## Sunucu (Cloud Functions + Firestore)

Kupon (`promo.js`) ile aynı desen kullanılır: istemci bir **talep belgesi** yazar, tetikleyici fonksiyon doğrular, ödül
**posta** ile gider. Posta kimliği sabit olduğu için ödül iki kez verilemez.

| Yol | Yazan | İçerik |
|---|---|---|
| `users/{B}/referral/ref_claim` | B oluşturur (bir kez) | `{code, src, dev, at}` + fonksiyonun `status`, `referrer` alanları |
| `users/{B}/referral/ref_lvl3` | B oluşturur (bir kez, talep varken) | `{at}` + fonksiyonun `status`, `tier` alanları |
| `users/{A}/referral/ref_owner` | her hesap, oturum açılınca (cihaz değişince yeniden) | `{dev, at}`: hesabın şu anki cihaz özeti (kendi kendine davete karşı) |
| `referrals/r_{A}` | yalnız fonksiyon; A okur | `{joined, count, last_at}` |
| `referrals/r_{A}/invited/f_{B}` | yalnız fonksiyon; A okur | `{at, state: joined\|qualified, tier, src}` (ad/avatar `garages/g_{B}`'den okunur) |
| `ref_devices/{özet}` | yalnız fonksiyon | `{at}` (bir cihaz = bir davet) |
| `users/{B}/mail/ref_welcome` | fonksiyon | hoş geldin hediyesi |
| `users/{A}/mail/ref_{n}` | fonksiyon | n. basamak ödülü (n = 1…10) |

### `referralJoin` (onCreate `users/{B}/referral/ref_claim`)

Tek işlemde doğrular. İlk tutmayan kural sonuç olarak `status`'a yazılır:

- `codes/{KOD}` var → A bulunur (`no_code`).
- A ≠ B (`self`).
- B'nin Auth hesabı **7 günden yeni** (`old_account`): `getUser(B).metadata.creationTime`.
- B daha önce davetle gelmemiş (`already`): belge yalnız bir kez oluşturulabilir.
- Cihaz özeti daha önce kullanılmamış ve A'nın kendi cihazı değil (`device_used`).
- A yasaklı değil (`moderation/m_{A}`, `banned`).

Geçerse:

- `ref_devices/{özet}` yazılır.
- `referrals/r_{A}/invited/f_{B}` yazılır, `state: joined`.
- `referrals/r_{A}.joined` +1.
- İki arkadaşlık belgesi yazılır (yönetici yetkisi, kural dışı).
- B'ye `ref_welcome` postası gider.
- (Katılma anında davet edene ayrı bildirim yok: ödülsüz posta "hediyen var" bildirimi verirdi; bildirim sayılınca
  basamak postasıyla gider.)
- `status: ok`.

### `referralQualify` (onCreate `users/{B}/referral/ref_lvl3`)

- Seviye sunucuda ayrıca denetlenmez: oyun işareti yalnız 3. seviyede yazar. `players/{B}.stats.level` de istemcinin
  yazdığı bir değer; denetlemek güvenlik katmaz, bulut kaydı gecikirse daveti boşuna bekletirdi. Asıl önlemler hesap
  yaşı, cihaz özeti ve 10 tavanı.
- Liste belgesi `joined` olmalı.
- A'nın `count`'u 10'dan küçükse işlem içinde +1 yapılır, `state: qualified`, `tier: n`.
- `users/{A}/mail/ref_{n}` postası sabit kimlikle yazılır. Sayaç yalnız artar, kimlik tekrarlanmaz; oyun alınan
  kimliği kayıtta tutar.
- `mailPush` bildirimi kendiliğinden gönderir: "🎁 Ece katıldı! 4. davet ödülün seni bekliyor".
- 10'dan sonra yalnız sayaç artar.

**Kurallar:** `users/{uid}/referral/*` için:

- yalnız sahibi oluşturur; `ref_claim` ve `ref_lvl3` bir kez (üzerine yazılamaz), `ref_lvl3` yalnız `ref_claim` varken;
- `code` 6 harf (kod alfabesi), `src ∈ {play, link, code}`, `dev` 64 onaltılık karakter, `at` sunucu saatine ±10 dk;
- `ref_owner` güncellenebilir (telefon değişince);
- silme yok (hesap silmede fonksiyon siler); tam yasakta yazılamaz.

`referrals/**`'u yalnız sahibi okur, istemci yazamaz. Emülatör testi `rules_test.mjs`'e eklenir.

**Hesap silme (`accountCleanup`):** şunlar silinir:

- `users/{uid}/referral/*`
- `referrals/r_{uid}` ve alt listesi
- başka davetçilerin listesindeki `invited/f_{uid}` (davet edenin sayacı ve aldığı ödül kalır)

`ref_devices` kalır. İçinde UID yok, yalnız tuzlu özet ve tarih var. Hesabını silip yeniden açan aynı cihazdan ikinci kez
davetle gelemez. Gizlilik metninde yazılmalı.

## Sahte hesaba karşı

Ödülün **10'da bitmesi** zaten tavan koyar: bir davetçinin sahte hesapla kazanabileceği en çok değer bellidir. Önlemler:

| Önlem | Neyi keser |
|---|---|
| Yalnız 7 günden yeni hesap | eski hesapları birbirine "davet" etmek |
| Hesap başına bir davet | aynı kişiyi iki kez saymak |
| **Cihaz özeti**: `ANDROID_ID` (SSAID) | aynı telefonda hesap değiştirip tekrar tekrar katılmak |
| A'nın cihaz özeti ≠ B'nin | kendi telefonunda ikinci hesapla kendini davet etmek |
| **3. seviye şartı** (~10 dk gerçek oyun, ölçülecek) | kur-gir-sil çiftliği |
| Yasaklı davetçiye ödül yok, panelden geri alma | kötüye kullanım |
| Panel uyarısı: günde 5'ten çok sayılan davetçi | toplu sahtecilik izleme |

Cihaz özeti hakkında:

- `ANDROID_ID` Android 8+ cihazda uygulama imzası ve kullanıcı başına sabittir. Yeniden kurulumda değişmez, fabrika
  ayarlarında değişir.
- `JavaClassWrapper` + `Settings.Secure.getString(…, "android_id")` ile okunur.
- İstemci SHA-256 ile özetler. Sunucu gizli bir tuzla bir kez daha özetleyip saklar. Ham değer hiçbir yere yazılmaz.

**Gerekirse (Faz 2+):** Play Integrity API. B'nin talebine bütünlük jetonu eklenir, `MEETS_DEVICE_INTEGRITY` olmayan
(emülatör) sayılmaz. Kurulumu ve sunucu çözümü ayrı iştir; sahtecilik görülmeden eklemeye gerek yok.

## Oyun tarafı

**`gameplay/social/referral_manager.gd` (yeni, "referral" grubu, SocialManager'ın yanında kurulur):**

- Kaynağı okur.
- Uygunsa talebi yazar.
- `level_up` ≥ 3 olunca `lvl3` işaretler.
- A için `referrals/r_{A}` ve listeyi okur.
- Sinyal: `referral_changed`.

**`gameplay/social/install_referrer.gd`:** yalnız Android, ilk açılış.

**`MailService` genişlemesi:**

- `money_min`: dakika × aktif gelir.
- `frame`: özel profil çerçevesi, `ProfileCatalog`'a `exclusive`.
- `decor` içinde özel eşya: `DecorManager.grant_exclusive`.
- `choice: "legendary_car"`: postayı alınca araç seçme penceresi açılır. Havuz SÜPER KASA'dan sahip olunmayanlardır.
  Hepsine sahipse yerine 600 💎 verilir.

**UI (taslak A):**

- `friends_screen.gd`'de 4. sekme DAVET ET.
- İçeriği ayrı bir dosyada kurulur: `ui/hud/referral_tab.gd`. friends_screen zaten 962 satır.
- QA, en kalabalık hâlin (yol + liste) 853x480'e sığdığını ölçer.

Ortak ekranlar:

- `ui/hud/referral_welcome.gd`: davet edilenin karşılaması. Sakin anda açılır, Rıza Usta'nın ilk dersinden sonra.
- Ödül anı: postanın RewardPopup'ı, başlık "N. DAVET ÖDÜLÜ".
- Kod alanı ve "Seni X mi davet etti?" penceresi.

**Kayıt:** `"referral": {src, code, sent, lvl3_sent}` (bulut kaydında da). Ödüller postadan geldiği için kayıt ödül
tutmaz.

**Telemetri:** `referral_share`, `referral_join`, `referral_qualify`, `referral_tier_claim`.

**Metinler:** 5 dil (`locale/*.json`), bildirim metni `mail.js`/`news.js` sözlükleri.

## Uygulama sırası

1. **Faz 1, sunucu + oyun mantığı:**
   - `functions/referral.js` (`referralJoin`, `referralQualify`) + birim testleri;
   - kurallar + emülatör testi;
   - `accountCleanup`;
   - `ReferralManager`, MailService eklemeleri;
   - masaüstü/QA için `-- --ref=<KOD>`;
   - `tests/referral_test.gd` (sahte Firebase ile uçtan uca).
2. **Faz 2, UI:** seçilen taslak, karşılama, ödül anı, kod girişi, efsanevi araç seçici. QA: `qa/davet_odul_qa.gd`
   (853x480 + 1170x540, CT_LANG).
3. **Faz 3, Android:** Install Referrer bağımlılığı + proxy, cihaz özeti, derin link `?r=`. Telefonda denenecek: dahili
   test linkine `&referrer=` eklenerek.
4. **Faz 4, site:** `/d/<jeton>?r=`, `/r/<KOD>`, Play'e yönlendirme, 5 dil metin; gizlilik politikasına cihaz özeti
   (dolandırıcılık önleme); Play **Veri güvenliği** formu: "Cihaz veya diğer kimlikler → dolandırıcılık önleme".
5. **Faz 5, varlıklar:** NEON "DOSTLAR" TABELASI (Blender hattı, `tools/decor/props_v8_davet.py`), DAVETÇİ/ELÇİ
   çerçeveleri.
6. **Deploy (kullanıcı `!` ile):** kurallar + `referralJoin`, `referralQualify`, `accountCleanup`.

## Kullanıcı kararları (2026-10-23, soru-cevap)

1. **Taslak A:** ARKADAŞLAR ekranında 4. sekme **DAVET ET**. İçinde:
   - yatay ödül yolu, Şahin ilerler;
   - 10. ödül sağda koyu altın kart;
   - altta DAVET KODUN + KOPYALA + DAVET LİNKİ PAYLAŞ;
   - yanında DAVET ETTİKLERİN listesi (KATILDI ✓ / N. ÖDÜL HAZIR / SEVİYE 2 / 3).

   Sekmede ödül hazırken kırmızı rozet çıkar. Alt sıradaki ARKADAŞLAR plakası da rozet gösterir.
2. **Sayılma şartı:** davet edilen hesapla girer ve **3. seviyeye** ulaşır.
3. **10. ödül:** seçilebilir efsanevi araç (SÜPER KASA havuzundan sahip olunmayan) + ELÇİ altın çerçevesi.
4. **Davet edilene:** katılınca 50 💎 + 5.000 ₺.
5. Benim varsayılanlarım, kullanıcıya söylendi, değiştirilebilir: otomatik arkadaşlık **evet**; 10'dan sonra ödül
   **yok**; ₺ ödülleri **aktif gelire bağlı**.

## Faz 1: UYGULANDI (2026-10-23, commit yok)

Sunucu ve oyun mantığı tamam; arayüz (Faz 2), Android yükleme kaynağı (Faz 3), site (Faz 4), varlıklar (Faz 5) bekliyor.

**Sunucu (`firebase/`):**

- `functions/referral.js`: `handleJoin`, `handleQualify`, `TIERS`, `WELCOME`, beş dilli posta metinleri.
- `functions/index.js`: `referralJoin` (onCreate `ref_claim`), `referralQualify` (onCreate `ref_lvl3`). Hesap yaşı
  `getAuth().getUser(uid).metadata.creationTime`'dan (Auth'ta yoksa eski sayılır).
- Talebin sonucu işlemin içinde yazılır: aynı olay iki kez aynı anda çalışırsa ikincisi ilkinin "ok"unu ezmez.
  Sayılma, davetin `state` alanıyla tek seferdir (katılma sonrası ve seviye tetikleyicisi yarışsa da).
- `functions/account_cleanup.js`: `referrals/r_{uid}` + alt listesi, başkalarının listesindeki `invited/f_{uid}`.
  `ref_devices` kalır (UID yok).
- `firestore.rules`: `users/{uid}/referral/{ref_claim | ref_lvl3 | ref_owner}`, `referrals/r_{uid}` + `invited` (sahibi
  okur), `ref_devices` kapalı.

**Oyun:**

- `gameplay/social/referral_rewards.gd` (`ReferralRewards`): tablo. `functions/test/referral.test.js` iki tabloyu
  karşılaştırır.
- `gameplay/social/referral_manager.gd` (`ReferralManager`, "referral"; GarageSystem kurar):
  - cihazda bekleyen kod (`user://referral.json`), talep + sonuç bekleme, seviye işareti, `ref_owner`;
  - `submit_code`, `load_progress` (sayaç + liste), `car_pool` / `choose_car` / `take_fallback`;
  - kayıt "referral";
  - `-- --ref=<KOD>`.
- `SocialManager`: `write_referral`, `read_referral`, `read_referrals`. Sosyal yasakta da yazılır; kural yalnız tam yasakta
  reddeder.
- `InviteLinks.parse_ref`: `?r=KOD` ve `davet/r/KOD`.
- `MailService`: `money_min` (`income_money`), `frame` (yalnız `exclusive` çerçeve), `choice` (ReferralManager'a hak).
  `MailNotice` bu satırları gösterir. Ödül özetinde `choice` varsa Faz 2'de araç seçimi açılacak.
- `ProfileCatalog`: `inviter` (DAVETÇİ, gümüş + turkuaz) ve `envoy` (ELÇİ, altın + 6 elmas) `exclusive` çerçeveleri.
  `PlayerProfile.grant_frame`. Seçicide yalnız sahibine görünür, seviye açılışında yok. `AvatarView` çizer; görüntü
  QA'sı Faz 2'de.
- 13 yeni metin 4 dile çevrildi (`tools/i18n/check.py` 0 eksik).

**Testler (hepsi geçti):**

- `functions` npm test 70; `referral.test.js` 13 senaryo (yarış, 10 basamak, parite dahil).
- Kurallar emülatörde 0 hata (31 yeni denetim).
- `tests/referral_test.gd` 62 (`run_tests.sh`'e eklendi).
- Etkilenen paketler: mail_test 48, profile_test 63, save_test 29, level_up_test 34, social_test 141.
- Tam paket koşulmadı (kullanıcı başlatır).

**Bekleyen:**

- Deploy (kullanıcı `!`):
  `cd firebase && firebase deploy --only firestore:rules,functions:referralJoin,functions:referralQualify,functions:accountCleanup --project car-town-remake`
- Fonksiyonların emülatörde uçtan uca testi (e2e) yazılmadı; mantık birim testli.
- `referral_neon` dekoru katalogda yok: Faz 5'e kadar 5. basamak postası yalnız çerçeveyi verir (posta katalogda olmayan
  eşyayı atar). Faz 5 bitmeden yayına çıkılmamalı.

## Faz 2: UYGULANDI (2026-10-23, commit yok)

**ARKADAŞLAR › DAVET ET** (`ui/hud/referral_tab.gd`, taslak A):

- 4. sekme, rozet = AL bekleyen basamak + kullanılmamış araç seçimi (`ReferralManager.attention`). Alt sıradaki
  ARKADAŞLAR plakasının rozeti de bunu sayar.
- Haber yokken rozet varsa ekran bu sekmede açılır. Sekmede eylem satırı ve kart vitrini gizlenir.
- Kural satırı + sayaç "4 / 10".
- 9 basamak: alındı (yeşil onay), postası bekliyor (altın parıltı, basamağın tamamı dokunulur, AL etiketi), SIRADAKİ,
  kilitli. Altında yol, Şahin sayaç kadar ilerler.
- 10. kart koyu altın: AL ya da ARACINI SEÇ.
- ARKADAŞINI ÇAĞIR: davet kodu + KOPYALA, üç adımlı "nasıl çalışır" (kısa ekranda gizli), DAVET LİNKİ PAYLAŞ.
- DAVET ETTİKLERİN: avatar + ad (arkadaş listesinden), KATILDI / N. ÖDÜL HAZIR / SEVİYE x / 3. Kimse yoksa yeni
  hesapta "SENİ BİR ARKADAŞIN MI ÇAĞIRDI?" + kod + GİR, değilse kısa açıklama.
- Basamağın AL'ı → `FriendsScreen.reward_claim_requested` → `Hud.mail_notice.claim_now(id)`.

**Paylaşım:** ARKADAŞLAR'daki iki davet düğmesi de aynı linki gönderir: `…/d/<jeton>?r=<KOD>` + metinde
"Davet kodum: AY-…". Eski "1 saat geçerli" metinleri kalktı.

**Dar ekran:** telefon tuvalinde (853 genişlik) dört sekmeyle başlık taşıyordu. `FriendsScreen.NARROW_WIDTH` altında
başlıktaki "ARKADAŞLAR" yazısı gizlenir, kask rozeti kalır.

**KODLA EKLE:** davet talebi olmayan hesap biriyle kodla arkadaş olunca "Seni X mi davet etti? EVET / HAYIR" sorulur.
EVET `submit_code`'u çağırır, sonuç pencerenin bildiriminde görünür.

**POSTA penceresinin davet görünümü** (`MailNotice`, postada `referral` + `friend`):

- Tabela DAVETLE GELDİN! / N. DAVET ÖDÜLÜ.
- Davet edenin ya da sayılan arkadaşın avatarı, başlık, metin, `ReferralDots` (9 nokta + "10").
- Altta "3. seviyeye ulaştığında X davet ödülünü kazanacak" ya da "Sıradaki: N. arkadaşta …" (`ReferralRewards.label`).
- 10. basamak alınınca ödül penceresi kapanınca `legendary_pick` açılır.

**EFSANEVİ ARACINI SEÇ** (`ui/hud/legendary_pick_screen.gd`, UiRouter SUB):

- Havuzdaki araçlar 4 sütun kart (resim + ad). Seçilen altın kenarlı, "X AL" ile verilir, ödül penceresi açılır.
- SONRA SEÇ hakkı saklar.
- Havuzun hepsine sahipse "+600 GEM AL".

**Çerçeveler:** DAVETÇİ turkuaz metal + iki elmas (gümüşten ayrılsın diye), ELÇİ altın + altı elmas.

**Sunucu:** basamak postasına `friend` (sayılan arkadaşın UID'si). ES metni oyunla aynı terim ("recompensa").

**Metinler:** 45 yeni metin 4 dile çevrildi, eski paylaşım metinleri silindi (`check.py` 0 eksik / 0 eskimiş).

**Testler (hepsi geçti):**

- `referral_test` 67.
- mail_test 48, social_test 141, profile_test 63, level_up_test 34.
- functions 70.
- QA `qa/davet_odul_qa.gd` 0 hata: 1152x648 TR, telefon tuvali 853x480 TR + DE. Kareler `~/Projects/ct_shots/davet/`.
- `qa/arkadaslar_qa.gd` 14 OK (dar başlık).

**Bilinen / bekleyen:**

- DAVET ET yalnız takma ad seçilmişken (sosyal profil hazır) görünür: davetle gelen yeni oyuncu kodu elle girmek
  için önce takma ad seçer.
- Faz 4'e kadar sitenin `/d/<jeton>` sayfası `?r=`'yi oyuna geçirmez (`davet.js` yalnız jetonu taşır). Kod paylaşım
  metninde olduğu için elle girilebilir.
- DE'de "PRESTIGE-KISTE" telefonda dar basamakta bölünüyor (okunuyor).
- "Seni X mi davet etti?" sorusu otomatik testte yok.

## Faz 3: UYGULANDI, telefonda denendi (2026-10-23, commit yok)

**Kod:**

- `gameplay/social/install_referrer.gd` (`InstallReferrer`): Play Install Referrer.
  - `InstallReferrerClient.newBuilder(activity).build()`, dinleyici `JavaClassWrapper.create_proxy` ile GDScript
    `_Listener` nesnesinden.
  - Sonuç Android UI iş parçacığından `call_deferred` ile Godot'ya aktarılır.
  - Kesin sonuçta bir daha sorulmaz; servis yoksa en çok 3 deneme. Durum cihaz dosyasında `play_ref`.
  - `parse`: `ref=` (URL kodlu da).
- ReferralManager açılışta çağırır, kod `receive(kod, "play")`.
- Bağımlılık: `addons/autoyard_android/plugin.gd` → `com.android.installreferrer:installreferrer:2.2` (her zaman).
- Debug derlemede günlük satırları: `ReferralManager: cihaz özeti …`, `davet kodu bekliyor`,
  `InstallReferrer: yanıt …`.

**Telefon (Samsung A24, debug APK `~/Projects/ct_builds/AutoYard_davet_test.apk`, `adb install -r`; telefondaki
1.0.9 aynı debug anahtarlı, veri korundu):**

- ANDROID_ID okundu, özet açılıştan açılışa aynı.
- Install Referrer yanıt 0 (OK). USB kurulumunda kaynak `utm_source=(not%20set)&utm_medium=(not%20set)`, kod yok.
  Gerçek kod yalnız Play kurulumunda gelir (dahili test izi).
- `autoyard://davet/r/KOD` (uygulama açıkken, yeni intent) ve `autoyard://davet/<jeton>?r=AY-KOD` (soğuk açılış) →
  kod beklemeye alındı.
- Kullanıcı DAVET ET'ten paylaştı: mesaj `Davet kodum: AY-8YMCLX` + `…/d/<jeton>?r=8YMCLX`.
- Kurallar yüklenmeden önce `ref_owner` / `ref_claim` PERMISSION_DENIED aldı, oyun etkilenmedi. Test kodu telefondan
  silindi (`run-as … files/referral.json`).
- Yükleme sonrası `referrals/r_{uid}/invited` okundu.

**Deploy (kullanıcı `!`, 2026-10-23):** `firestore:rules`, `referralJoin`, `referralQualify` (europe-west4, yeni),
`accountCleanup` (güncelleme), hepsi başarılı.

**Emülatör uçtan uca** `npm --prefix functions run referral-e2e` (`functions/test/referral_e2e.mjs`), 9 OK:

- referralJoin tetiklenir (Auth emülatöründen hesap yaşı), otomatik arkadaşlık, hoş geldin postası, sayaç.
- referralQualify, 1. basamak postası (`friend`, `referral`).
- Aynı cihazda ikinci hesap `device_used`.

**Henüz denenmeyen:**

- Gerçek iki cihazla canlı akış: ikinci telefonda YENİ hesap + kod.
- Play'den gelen gerçek yükleme kaynağı (dahili teste yükleme gerekir).

**Derleme notu:**

- `GRADLE_USER_HOME=/home/burak/snap/godot-4/common/gradle`
- `GODOT_ANDROID_KEYSTORE_DEBUG_*` = `~/godot-debug.keystore` / `androiddebugkey` / `android`
- `export_presets.cfg` `gradle_build/export_format` geçici 0 → `godot-4 --headless --export-debug Android <apk>` →
  geri 1 (yedek `~/Projects/ct_builds/export_presets.pre_davet_apk.cfg`).
