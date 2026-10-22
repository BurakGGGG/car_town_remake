# Özellik Raporu — Auto Yard: Neler Eklenebilir, Neler Değişmeli

Hazırlanma: 22 Ekim 2026 · Kapsam: oyunun bugünkü kodu (HEAD fe5b683 + commit'lenmemiş işler), dokümanlar ve benzer oyunların araştırması (kaynaklar metin içinde).
Evcil hayvan önerisinin ayrıntısı ayrı raporda: [EVCIL_HAYVAN_RAPORU.md](EVCIL_HAYVAN_RAPORU.md).

**Nasıl okunur:** her önerinin yanında **Etki** (★–★★★★★: tutunma / gelir / memnuniyet), **Efor** (S ≈ 1–2 gün, M ≈ 3–7 gün, L ≈ 2–4 hafta, XL > 1 ay) ve **Öncelik** var:
- **P0:** yayından önce / hemen
- **P1:** ilk 1–2 ay
- **P2:** 2–4 ay
- **P3:** sonra

---

## 1. Özet: önce bunlar

| # | Öneri | Neden | Etki | Efor | Öncelik |
|---|---|---|---|---|---|
| 1 | **Çökme raporlama + analitik** (Crashlytics + Firebase Analytics) | Oyunda ikisi de yok: telefonda neyin bozulduğunu ve oyuncunun nerede bıraktığını göremiyorsun | ★★★★★ | S–M | **P0** |
| 2 | **Reklam ağını çalıştır** (AdMob hesabını düzelt ya da Unity Ads / Appodeal) | Ödüllü reklam kodu hazır ama hiçbir ağ reklam vermiyor: bu gelir kalemi şu an sıfır | ★★★★ | M | **P0** |
| 3 | **IAP makbuzunu sunucuda doğrula** | Gerçek parayla elmas satılıyor, doğrulama yalnız cihazda | ★★★★ | M | **P0** |
| 4 | **Koleksiyon setlerine ödül + kilometre taşlarını güncelle** | 13 set ödülsüz; kilometre taşları 16 araçlık eski katalogdan (5/10/14/16), oyunda 72 araç var | ★★★★ | S | **P1** |
| 5 | **Boyayı aç + çıkartma / vinil** | Boya sistemi tamamen yazılmış ama kapalı (`GameFeatures.PAINT`); özelleştirme, araba oyunlarının bir numaralı bağlılık kaynağı | ★★★★★ | M–L | **P1** |
| 6 | **Haftalık sıfırlanan drag lider tablosu** | Rekabet ve geri dönüş sebebi; koşu kaydı altyapısı (Faz 0–2) zaten var | ★★★★ | M | **P1** |
| 7 | **Haftalık "Araç Fuarı" (oylamalı)** | Car Town'un imza özelliği; boya + modifiye + sergiyle birleşir | ★★★★ | L | **P1** |
| 8 | **Etkinlik takvimi + sınırlı süreli etkinlik aracı** | Canlı operasyon altyapısı (config/app, etkinlik tabelası) var ama içerik takvimi yok | ★★★★ | M | **P1** |
| 9 | **Evcil hayvan (Garaj Dostları)** | Türkiye'ye çok uygun, rakiplerde yok, dekor satışına destek | ★★★★ | L | **P1–P2** |
| 10 | **Sezon bileti (gerçek parayla)** | Brawl Stars'ta pass değişiklikleri gelir +%64 ([kaynak](https://www.liquidandgrit.com/february-2024-core-report/)) | ★★★★★ | L | **P2** |
| 11 | **Kulüp / ekip + haftalık ortak hedef** | Tutunma için en güçlü sosyal kaldıraç; geç ve küçük adımlarla kurulmalı ([Naavik](https://naavik.co/f2p-mobile/building-clan-features/)) | ★★★★ | XL | **P2–P3** |
| 12 | **Tamir derinliği: teşhis mini oyunu + müşteri karakterleri** | Çekirdek döngü 7 iş türüyle tekdüzeleşir; günde en çok yapılan şey bu | ★★★★ | L | **P2** |

---

## 2. Oyunun bugünkü hâli (envanter)

**Mimari:**
- Godot 4.7, GDScript, GL Compatibility, yalnız Android (arm64, minSdk 24 / targetSdk 36, yatay).
- Autoload yok: yöneticileri `garage_system.gd` kuruyor, gruplarla bulunuyorlar.
- Ekranlar kodla kuruluyor, UiRouter (PLACE / MODAL / SUB) yönetiyor.
- Ekonomi bilinçli olarak istemcide (melez).

| Alan | Bugün oyunda olan |
|---|---|
| **Tamir** | 7 iş: MOTOR, FREN, LASTİK, KAPORTA, BOYA İŞİ (sv5), DÖŞEME (sv8), FREN REVİZYONU (sv12). 3 tamir alanı. GARAJ SEVİYESİ 1–4, TAMİR HIZI 5 kademe. İş ustalığı (5 yıldız). Çevrimdışı kazanç (aktif gelirin 1/16'sı, 8 saat). Müşteri sabrı (75–110 sn). Elmas / reklamla bitirme |
| **Araç** | 74 araç (72 edinilebilir: 43 kasadan, 28 restorasyondan, 1 hoş geldin kasasından). 5 kasa (40–250 elmas, olasılıklar görünür). GERİ AL. Koleksiyon (13 set, ödülsüz). GARAJIM sergisi, OTOPARK (%5/gün), 5 depo (MAHALLE … HANGAR, 25 M ₺). İsim tabelası |
| **Hurdalık** | Ayrı harita, 9 parça türü, günlük enkazlar, 3 görünümlü restorasyon, Necati ve Cemo |
| **Modifiye** | 6 kategori × 5 kademe, dinamometre, yeni lüks **Modifiye Garajı** (sinematik kamera). Boya kapalı |
| **Yarış** | Drag (gerçek vites simülasyonu), sınıf D–S, rövanş, kaçan rakip, tek kişisel rekor + hayalet. %70 arkadaş aracı, İNTİKAM, iki yönlü skor. Koşu tabanlı eşleştirme ve öğrenen zorluk (commit'lenmedi). Polis kovalamacası yalnız gösteri |
| **Ekonomi** | ₺, elmas, XP / seviye. 7 günlük giriş döngüsü. Garaj değeri 15 rütbe. MARKET: GEM AL / PARAYA ÇEVİR / KOD GİR. 5 IAP ürünü. Ödüllü reklam (çalışmıyor) |
| **İlerleme** | Günlük (5) / haftalık / başarım (38) / REHBER (19). Rıza Usta dersleri. SEVİYE ATLADIN ekranı |
| **Dekor** | 268 eşya (24'ü elmaslı lüks, 16 ofis, 1 özel kurucu ödülü). Serbest ızgara, iç duvarlar, desenler |
| **Sosyal** | Arkadaş kodu, davet linki, ziyaret (depolar dahil), beğeni, parça hediyesi, profil (foto / avatar / çerçeve / bayrak), şikâyet / engel, OTO MANŞET, bildirim, posta |
| **Canlı operasyon** | Zorunlu güncelleme, bakım, duyuru, etkinlik çarpanı (×1–3), kupon kodu, moderasyon, yönetim paneli, gece istatistiği |
| **Dünya** | İzometrik şehir, 37 modelli trafik, ışıklar, dörtlüler, egzotik araçlar, billboard, kodla üretilmiş ortam sesi, 3 müzik |
| **Ayarlar** | 5 dil (~2.270 metin), grafik kalitesi, pil tasarrufu, HUD boyutu, ses, bildirim, gizlilik, NASIL OYNANIR, fotoğraf modu |

---

## 3. Güçlü yönler (korunmalı)

- **Görsel kimlik ve cila.** Pişirilmiş ışıklı iç mekânlar, kodla üretilen sesler, yükleme slaytları, sinematik modifiye garajı. Tutarlı, sıcak, çizgi film dili.
- **Adil ekonomi tercihleri.** Kasa olasılıkları görünür, elmas kısıntısı bilinçli (~35/gün), reklam asla elmas vermiyor, zorunlu reklam yok.
- **Sosyal temel hazır.** Ziyaret, hediye, haber, bildirim, moderasyon, şikâyet. Kulüp ve fuar gibi özellikler bunun üstüne kurulabilir.
- **Canlı operasyon altyapısı.** Uzaktan ayar, etkinlik, kupon, posta, yönetim paneli. Çoğu küçük ekipte yıllar sonra gelir.
- **Test kültürü.** 67 test paketi, 7 oranda ekran taraması, emülatörde kural testleri. Bu raporla birlikte yapılan tam koşu **0 hata** verdi.
- **Türkiye'ye özgü ruh.** Şahin, Murat 124, Rıza Usta, Necati, mahalle garajı, OTO MANŞET.

---

## 4. Hemen düzeltilmesi / kapatılması gerekenler

| Konu | Durum | Öneri | Öncelik |
|---|---|---|---|
| Çökme raporlama yok | Kodda hiç yok | Firebase Crashlytics (Android eklentisi) + Godot hata yakalayıcı | **P0** |
| Analitik yok | Kodda hiç yok | Firebase Analytics (olay listesi §10). En az: tutorial adımları, ilk tamir, ilk kasa, D1/D7, IAP hunisi | **P0** |
| Reklamlar fiilen kapalı | `ADS = true`, ama AdMob hesabı reddedildi; AppLovin anahtarsız ve eklentisi kapalı. Başlık yorumları birbirini tutmuyor (`ads/ad_provider.gd:2`) | Ağı çalıştır; o zamana kadar yorumları düzelt | **P0** |
| IAP sunucu doğrulaması | Yalnız cihazda | Play Developer API + bir Cloud Function; sahte satın alımı ve iadeyi yakalar | **P0** |
| App Check yok | Depo ve API anahtarı açık; tek savunma kurallar | Play Integrity ile App Check; kupon ve e-posta kodu fonksiyonları önce | **P1** |
| API anahtarı kısıtı | Kısıtsız | Konsolda Android uygulamasına kısıtla (dikkatli: yanlış kısıt girişi bozar) | **P1** |
| YENİ RENK görevi takılıyordu | Boya kapalıyken REHBER'in bir yerini sonsuza kadar tutuyordu | **Bu gece düzeltildi** (`QuestCatalog.all()` kapalı özelliğin görevini süzüyor) | ✔ |
| Nadirlik adları İngilizce | Türkçe arayüzde her yerde COMMON / RARE / EPIC / LEGENDARY (kasa verisindeki etiket çevrilmiyordu) | **Bu gece düzeltildi**: YAYGIN / NADİR / EPİK / EFSANEVİ ve 4 dile çeviri | ✔ |
| SES düğmesi gizli | `hud.gd:507 AUDIO_AVAILABLE = false`, "ses yok" varsayımıyla; oysa müzik ve efekt var | Ya düğmeyi aç (tek dokunuşla sessiz), ya da sabiti ve yorumu kaldır | P1 |
| Koleksiyon kilometre taşları eski | 5/10/14/16 araç, `collection_screen.gd` "16 araç" diyor | 72 araca göre yeniden: 10/20/35/50/72 + set ödülleri | **P1** |
| TAMİR plakası işlevsiz | Gizlendi, düğüm duruyor | Kaldır ya da gerçek işlev ver (tamirdeki araca git) | P2 |
| `garage_screen.tscn`'de "BMW E46" yer tutucusu | Kodda üzerine yazılıyor | Editörde metni boşalt (sahne dosyasına el sürmüyoruz) | P2 |
| Bazı araçlarda gerçek marka amblemi ve "GT3" yazısı | Oyunla aynı modellerden alınan Blender çizimlerinde Golf'ün önünde VW amblemi, GT3'ün yanında "GT3" yazısı seçiliyor; yakın çekimli modifiye kamerasında da görünür | `tools/debadge` hattını geometri amblemlerine de uygula | **P1** (hukuki risk) |
| `challenge_spot yarış şeridinde değil` uyarısı | Her açılışta günlüğe düşüyor; kod şerit noktasını kullanıyor | Editörde Main.tscn'deki ChallengeSpot düğümünü şeride taşı ya da sil | P2 |
| `LEVELUP_DOUBLE` reklamı | Kuralı var, ekrana bağlı değil | SEVİYE ATLADIN ekranında "ödülü 2 katına çıkar" (reklam çalışınca) | P2 |
| İşlevsel dekor (ATM, parça rafı) | Tasarlandı, kodlanmadı | §5.6'ya bak | P2 |
| "Müşteri kalitesi" bonusu | `progression_effects.gd:59` yazılmadı | Ya kaldır ya tamir derinliğiyle birlikte yap (§5.1) | P2 |
| KNOWN_ISSUES.md eski | "Ses yok, reklam yok, IAP yok" diyor | Güncelle | S |
| `profileable` bayrağı | Manifest'te | Yayın derlemesinde kapat | **P0** |
| Cihaz testi az | Pek çok özellik "telefonda denenmedi" | 3 cihazlık matris: düşük / orta / yüksek; Play Ön Lansman Raporu | **P0** |

---

## 5. Yeni özellikler (alan alan)

### 5.1 Çekirdek döngü: tamir

Oyuncunun en çok zaman geçirdiği yer. Bugün döngü şöyle: arıza → TAMİRE AL → bekle → topla. Çeşitlilik 7 iş türüyle sınırlı.

| Öneri | Ne | Bağlantı | Etki | Efor | Önc. |
|---|---|---|---|---|---|
| **Teşhis mini oyunu** | Araç gelince 3–5 sn'lik dokunma oyunu: doğru parçaya dokun / sesten arızayı bul / kabloyu bağla. Başarı → tamir süresi −%20 veya bahşiş | RepairManager, CarHitbox, RepairFx; ustalık yıldızlarına sayılır | ★★★★ | L | P2 |
| **Müşteri karakterleri ve hikâyeli işler** | Tekrar gelen karakterler: taksici Hüsnü, dolmuşçu, ünlü bir futbolcu, Emre'nin babası… Kısa diyalog + özel iş (VIP: 3× ödül, sabır kısa) | Müşteri sistemi, OTO MANŞET ("Ünlü futbolcu Şahin'ini bizde yaptırdı") | ★★★★ | M–L | P2 |
| **Filo sözleşmesi** | Bir şirket (kargo, taksi) 7 gün boyunca günde X araç getirir; tamamlanınca büyük ödül | Görev sistemi + müşteri doğumu | ★★★ | M | P2 |
| **Çırak / arkadaş işçi** | Car Town'da arkadaşını "işçi" olarak tutmak çekirdekti ([kaynak](https://www.autoguide.com/auto-news/2010/08/car-town-facebook-game-lets-you-pimp-your-virtual-ride-and-much-much-more.html)). Arkadaşının avatarı bir alanda çalışır, tamiri hızlandırır, o da küçük ödül alır | SocialManager, tamir alanı, profil fotoğrafı | ★★★★ | L | P2 |
| **Parça stoku** | Bazı işler parça ister (fren balatası, akü). Parça hurdalıktan, hediyeden ya da ₺ ile siparişten gelir | Hurdalık parçaları, hediye sistemi | ★★★ | L | P3 |
| **Acil işler / çekici çağrısı** | Haritada yolda kalan araç: çekici animasyonu, ödül ×2, zamanlı | Trafikteki dörtlüler (zaten var) + çekici sahnesi (hurdalıkta var) | ★★★ | M | P2 |
| **Garaj katları** | Car Town'da garaj seviye atladıkça kat kazanıyordu ([ikincil](https://www.supercheats.com/guides/car-town/)). Bizde 4. seviyeden sonra "üst kat ofis / salon" | Dekor v2, GARAJ SEVİYESİ | ★★★ | XL | P3 |
| **Yıkama / detaylı temizlik işi** | Ucuz, kısa, çok tatmin edici (köpük, parlatma efekti) | RepairFx; Car Town'da da vardı | ★★★ | M | P2 |

### 5.2 Araçlar ve koleksiyon

| Öneri | Ne | Etki | Efor | Önc. |
|---|---|---|---|---|
| **Set ödülleri** | 13 set var, ödülü yok. Seti tamamlayana rozet, elmas, özel dekor, profil çerçevesi | ★★★★ | S | **P1** |
| **Kopya araç dönüşümü / "pity"** | Kasada üst üste kopya gelince sonraki kasada nadirlik garantisi. Ya da kopyalardan "parça" biriktirip araç oluşturma | ★★★★ | M | P1 |
| **Etkinlik aracı (ödünç → kazan)** | NFS No Limits modeli: etkinlikte araç ödünç verilir, görevleri bitirirsen senin olur ([kaynak](https://en.wikipedia.org/wiki/Need_for_Speed:_No_Limits)) | ★★★★★ | M | **P1** |
| **Doğrudan araç satın alma** | Tasarımı var, kodu yok. Hem politika (FTC: kutudaki ürün doğrudan da satılmalı, [kaynak](https://www.ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse)) hem kullanıcı dostluğu için | ★★★ | M | P1 |
| **Ahır bulma / müzayede** | Car Mechanic Simulator'daki Barn Find ve Junkyard modülleri, müzayede ([kaynak](https://store.steampowered.com/app/645630)). Haftada bir "ahırda unutulmuş klasik": kilitli, ipuçlu, restorasyona gider | ★★★★ | L | P2 |
| **Haftanın aracı** | Showroom'da 7 gün öne çıkan araç + ilgili görev | ★★★ | S | P1 |
| **Araç geçmişi** | Her araçta km, yarış, tamir sayısı, ilk sahibi ("Elif'ten hediye") | ★★ | S | P3 |
| **Yeni araç partisi ritmi** | 74 araç iyi bir başlangıç. Ayda 3–5 yeni araç + temalı kasa (Yerli Klasikler, Japon Efsaneleri) | ★★★★ | sürekli | P1 |

### 5.3 Özelleştirme (görsel)

Car Town'da tekerlek, şasi, body kit, boya ve oyuncunun yüklediği yan grafikler vardı. CSR2'de boya, jant, kaliper, iç döşeme, kaplama, çıkartma ve plaka ([kaynak](https://apps.apple.com/us/app/app/id887947640)). Pixel Car Racer ve Torque Drift'te kaplama tasarlayıcı var. Bizde görsel özelleştirme fiilen **sıfır** (boya kapalı).

| Öneri | Ne | Etki | Efor | Önc. |
|---|---|---|---|---|
| **Boyayı aç** | 16 renk (6'sı elmaslı) hazır. Maske sorunu (`car_part_map.gd:972`) çözülmeli | ★★★★★ | M | **P1** |
| **Jant seçimi** | 10–20 jant modeli; teker grupları zaten ayrık (CarRig) | ★★★★ | L | P1 |
| **Çıkartma / yarış şeridi** | Hazır desenler (şerit, numara, alev); kapı ve kaputa | ★★★★ | L | P2 |
| **Türk plakası** | 34 ABC 123 biçimi, oyuncu yazar; ad süzgeci | ★★★ | S–M | P2 |
| **Cam filmi, neon, kaliper rengi** | Ucuz, satılabilir (elmas) | ★★★ | M | P2 |
| **Kaplama paylaşım kodu** | Forza'da haftalık kaplama yarışmaları, kazananlar 6 ay öne çıkıyor ([kaynak](https://forums.forza.net/t/official-weekly-fh5-livery-competition-week-043/577239)) | ★★★ | L | P3 |

Not: performans modları zaten derin. Görsel modlar bunu **satılabilir kimliğe** çevirir.

### 5.4 Yarış

| Öneri | Ne | Bağlantı | Etki | Efor | Önc. |
|---|---|---|---|---|---|
| **Haftalık lider tablosu** | 300 m en iyi süre, sınıf bazlı (D–S); her pazartesi sıfırlanır, ilk %10'a ödül. Torque Drift 2 örneği ([kaynak](https://gamespress.com/Torque-Drift-2-adds-new-iconic-Nissan-Toyota-Honda-car-models-in-major)) | Koşu kaydı (Recording) sunucuda yeniden koşulup doğrulanır: hile zorlaşır | ★★★★ | M | **P1** |
| **Turnuva / lig** | 8 haftalık sezon (CSR2 The Circuit), lig atlama | Lider tablosunun üstüne | ★★★★ | L | P2 |
| **Arkadaşa meydan okuma** | "Bu koşumu geç!" linki / bildirimi; arkadaş kendi aracıyla dener | Koşu kaydı + raceNewsPush | ★★★★ | M | P1 |
| **Yarış modları** | Yarım mil, gece yarışı (farlar), yağmurlu pist (tutuş), "1/4 mil efsaneleri" | DragRaceSim parametreleri | ★★★ | M | P2 |
| **Kovalamacaya katılım** | Polis kovalamacası bugün yalnız gösteri. "Kaçağı yakala" mini oyunu (polis aracı kiralanır) ya da yan görev | PoliceChase, trafik | ★★★ | L | P3 |
| **Tekrar paylaşımı** | Yarışın son 5 sn'si dikey video olarak galeriye | Fotoğraf modu altyapısı | ★★★ | M | P2 |

### 5.5 Sosyal

| Öneri | Ne | Etki | Efor | Önc. |
|---|---|---|---|---|
| **Araç Fuarı (oylamalı)** | Haftalık tema ("En iyi klasik", "En lüks sergi"); oyuncu bir aracını sokar, başkaları ikili karşılaştırmayla oylar; kazanana rozet + ödül. Car Town'un "Car Show"u ([ikincil](https://www.supercheats.com/guides/car-town/)) | ★★★★ | L | **P1** |
| **Kulüp / ekip** | 10–30 kişi, kulüp seviyesi, haftalık ortak hedef (toplam tamir / yarış), bağış (parça isteme). Hay Day Derby / Township Regatta modeli ([kaynak](https://play.google.com/store/apps/eventdetails/4829873756313551377)). Naavik: geç kur, seviye + etkinlik + sohbet olmadan etkisi düşük | ★★★★★ | XL | P2–P3 |
| **Hazır mesajlar / çıkartmalar** | Ziyarette "Garajın efsane!", 👍 çıkartması; serbest sohbet yok (moderasyon maliyeti) | ★★★ | S–M | P1 |
| **Davet ödülü** | Davet linki var; davet edilen seviye 5'e gelince ikisine ödül | ★★★★ | S | **P1** |
| **Arkadaş çırağı** | §5.1'deki işçi | ★★★★ | L | P2 |
| **Takas** | Önerilmez (Adopt Me örneği, [kaynak](https://parentzone.org.uk/article/adopt-me)) | — | — | — |

### 5.6 Ekonomi ve dekor

| Öneri | Ne | Etki | Efor | Önc. |
|---|---|---|---|---|
| **Gelir getiren dekor** | Car Town'da bazı dekor gelir üretiyordu ("Kiddie Spaceship 1250 coin/24 sa", [ikincil](https://www.supercheats.com/guides/car-town/jobs)). Bizde tasarımı olan ATM / parça rafı: günlük küçük ₺, bekleme süreli | ★★★★ | M | P2 |
| **Giriş takvimi görünümü** | 7 günlük döngü var. 28 günlük görsel takvim + 7. / 28. gün büyük ödül | ★★★ | S | P1 |
| **Aylık abonelik (VIP)** | Günlük elmas + otopark ücretsiz + tamir hızı +%10 | ★★★★ | M | P2 |
| **Tek seferlik teklifler** | Seviye 10 / 20'de "Usta Paketi" (dekor + elmas + kasa) | ★★★ | S | P1 |
| **Otopark ücreti gözden geçirme** | %5/gün oyuncuya ceza gibi gelebilir; ilk 3 gün ücretsiz ya da depo dolunca bildirim | ★★ | S | P2 |
| **Ekonomi panosu** | Gece istatistiğine (dailyStats) para / elmas kaynak ve harcama dağılımı ekle | ★★★ | M | P1 |

### 5.7 Canlı operasyon ve etkinlikler

Altyapı hazır (etkinlik çarpanı, tabela, kupon, posta). Eksik olan **içerik takvimi**:

- **Tematik haftalar:** Bayram (ikramiye, hediye kutusu), Yılbaşı (karlı şehir, Noel Baba Şahin'i), 29 Ekim (Cumhuriyet: özel tabela ve araç), Ramazan, okul tatili.
- **Etkinlik görevleri + etkinlik aracı** (§5.2).
- **Sezon bileti** (gerçek parayla, yarı uzunlukta sezon, sezon boyu görevler; Brawl Stars verisi). Vitrin ödülü yeni araç / hayvan / lüks dekor.
- **Topluluk hedefi:** "Bu hafta bütün oyuncular 1 milyon tamir yaparsa herkese kasa".
- **A/B testi:** config/app'e deney grubu alanı; analitikle birlikte.

### 5.8 Hikâye ve karakterler

Rıza Usta, Necati, Cemo, Emre, Elif güçlü karakterler ama yalnız derslerde ve yarışta görünüyorlar.

- **Bölüm bölüm hikâye görevleri:** "Rıza Usta'nın kayıp Murat 124'ü", "Necati'nin borcu", "Cemo'nun yarış hayali". Her bölüm 3–5 görev, diyalog kartı, özel ödül.
- **Karakterlerin günlük ziyareti:** OTO MANŞET'te köşe yazısı ("Rıza Usta'nın Tavsiyesi").
- **Rakip garaj:** Dükkânı rakip olan "Turbo Kemal" haftalık yarış ve fuar rakibi.

### 5.9 Dünya ve atmosfer

| Öneri | Ne | Etki | Efor | Önc. |
|---|---|---|---|---|
| **Gün-gece döngüsü** | Gerçek saate bağlı akşam / gece: farlar, sokak lambaları, neon. Trafikte farlar zaten var | ★★★★ | L | P2 |
| **Hava durumu** | Yağmur: ıslak zemin, silecek, yıkama işi talebi artar | ★★★ | L | P3 |
| **Mevsim süslemesi** | Kar, yılbaşı ışıkları, bayram bayrakları (etkinlik takvimiyle) | ★★★ | M | P2 |
| **Yayalar ve evcil hayvanlar** | Kaldırımda yürüyen birkaç insan, sokak kedileri (evcil hayvan raporu) | ★★★ | M–L | P2 |
| **Yeni bölge** | Sanayi sitesi: ikinci tamir dükkânı ya da özel işler | ★★★★ | XL | P3 |

### 5.10 Erişilebilirlik ve kullanılabilirlik

- **Var olan:** HUD boyutu %80–120, 5 dil.
- **Eklenebilir:**
  - Renk körü modu (vites kadranının yeşil / kırmızı dilimi, nadirlik renkleri)
  - Haptik (vites, para toplama)
  - Sol el modu yok, bu oyunda gerek de yok
  - Yazı boyutu ayrı ayar
  - "Tek dokunuşla sessiz" (gizli SES düğmesi)
- **Tutarlılık:** bu gece 7 ekran oranında 99'ar durum tarandı. Sonuçlar ve düzeltmeler §11'de.

### 5.11 Teknik altyapı

| Öneri | Ne | Önc. |
|---|---|---|
| Crashlytics + Analytics | §4 | **P0** |
| IAP sunucu doğrulaması + iade dinleme (RTDN) | Cloud Function + Pub/Sub | **P0** |
| App Check (Play Integrity) | Önce kupon, e-posta kodu, kayıt | P1 |
| CI | `tools/run_tests.sh` + kural testleri her push'ta (self-hosted runner, ekran gerektirenler hariç) | P1 |
| Paket boyutu | 236 MiB indirme. Araç ağları 134 MiB; ilk kurulumda 20 araç, kalanı Play Asset Delivery ile "on-demand" | P2 |
| Kayıt sürümleme | Sürüm 10; yeni bölümler sürüm artırmadan ekleniyor (iyi). Hayvan ve fuar gibi özellikler de böyle eklenmeli | — |
| Sunucu otoritesi | Lider tablosu ve fuar gibi rekabetçi özellikler için koşu kaydı sunucuda yeniden koşulup doğrulanmalı (fizik deterministik) | P1 (lider tablosuyla) |
| Performans | Garaj ve depolarda çizim yükü ölçüldü (HANGAR 1,27 M üçgen). Düşük kademe cihazlar için "uzak araçları gizle" seçeneği | P2 |

### 5.12 Büyüme ve pazarlama

- Davet ödülü (§5.5) + paylaşılabilir fotoğraf / video. Fotoğraf modu var, oyun logosu basılıyor.
- **Play mağaza sayfası:** yeni görseller yalnız en-US girişinde; TR / DE / FR / ES girişlerine de yüklenmeli (notlarda açık).
- **Topluluk:** Discord / Instagram'da haftalık "garaj fotoğrafı yarışması". Kazanan oyun içinde billboard'a çıkar (billboard altyapısı var).
- **Ön kayıt sorunu:** Play'de ön kayıt "yapılamadı" hatası Google tarafında (destek talebi açıktı). İzlemeye devam.

---

## 6. Değişmesi önerilenler (mevcut özellikler)

| Mevcut | Sorun | Öneri |
|---|---|---|
| **Kasalar (gerçek parayla dolaylı)** | Elmas gerçek parayla satılıyor; kasa rastgele → Belçika / FTC hassasiyeti. 1 Mayıs 2026'dan itibaren Türkiye'de yaş sınıflandırması ve ebeveyn onayı ([kaynak](https://www.mondaq.com/turkey/gaming/1786408/new-regulations-in-the-social-network-and-gaming-sector)) | Olasılıklar zaten görünür (iyi). Ek olarak: pity, doğrudan satın alma seçeneği, yaş beyanı ve ebeveyn onayı akışı |
| **Görsel özelleştirme yok** | Boya kapalı; modifiye tamamen performans | Boya + jant + çıkartma (§5.3) |
| **Koleksiyon** | Setler ödülsüz, kilometre taşları eski | Set ödülleri, yeni kilometre taşları, albüm görünümü |
| **Tamir döngüsü** | 7 iş türü, hep aynı ritim | Teşhis, karakterler, acil iş, yıkama (§5.1) |
| **Polis kovalamacası** | Yalnız arka plan gösterisi | Etkileşim ya da görev bağı |
| **Reklam stratejisi** | Ağ yok; yalnız 2 ödüllü yerleşim | Ağ + SEVİYE ATLADIN ×2 + günlük ücretsiz kasa (reklamla) |
| **OTO MANŞET** | Güçlü ama yalnız açılışta | Hikâye köşesi, fuar sonuçları, haftalık lider tablosu |
| **Bildirim izni** | İlk yarıştan sonra isteniyor | İlk değerli an: ilk tamir parası ya da ilk kasa açılışı. A/B ile ölç |
| **Ses** | SES düğmesi gizli | Düğmeyi aç |
| **Otopark ücreti** | Ceza hissi | §5.6 |
| **REHBER görev sayacı** | Profil "GÖREVLER x / 19" diyordu; boya kapalıyken 18 olmalı | **Bu gece düzeltildi** (sayaç süzülmüş listeden geliyor) |

---

## 7. Önceliklendirme matrisi

| Öneri | Etki | Efor | Risk | Öncelik |
|---|---|---|---|---|
| Crashlytics + Analytics | ★★★★★ | S–M | düşük | **P0** |
| Reklam ağı | ★★★★ | M | orta (hesap onayı) | **P0** |
| IAP sunucu doğrulaması | ★★★★ | M | düşük | **P0** |
| Cihaz testi + profileable kapatma | ★★★★ | S | düşük | **P0** |
| Set ödülleri + kilometre taşları | ★★★★ | S | düşük | P1 |
| Boya + jant | ★★★★★ | M–L | orta (maske) | P1 |
| Haftalık lider tablosu | ★★★★ | M | orta (hile) | P1 |
| Etkinlik takvimi + etkinlik aracı | ★★★★ | M | düşük | P1 |
| Davet ödülü | ★★★★ | S | düşük | P1 |
| Araç Fuarı | ★★★★ | L | orta (moderasyon) | P1 |
| Evcil hayvan F1–2 | ★★★★ | M–L | düşük | P1–P2 |
| Amblem temizliği | ★★★ | M | **hukuki** | P1 |
| Sezon bileti | ★★★★★ | L | orta | P2 |
| Tamir derinliği | ★★★★ | L | düşük | P2 |
| Gün-gece | ★★★★ | L | orta (performans) | P2 |
| Kulüp | ★★★★★ | XL | yüksek | P2–P3 |
| Yeni bölge | ★★★★ | XL | orta | P3 |

---

## 8. Yol haritası önerisi

- **0–2 hafta (yayın sağlığı):** Crashlytics, Analytics, reklam ağı, IAP doğrulama, cihaz testi, profileable, KNOWN_ISSUES. Commit'lenmemiş işler (modifiye garajı, koşu eşleştirme, bu gecenin düzeltmeleri) gözden geçirilip commit'lenir.
- **2–6 hafta (bağlılık):** set ödülleri, boya + jant, haftalık lider tablosu, davet ödülü, etkinlik takvimi + ilk etkinlik aracı, giriş takvimi, evcil hayvan Faz 1 (Tekir).
- **6–12 hafta (gelir ve sosyal):** sezon bileti, Araç Fuarı, evcil hayvan Faz 2–3, tamir derinliği (teşhis + karakterler), gün-gece.
- **3–6 ay:** kulüpler, yeni bölge, çıkartma editörü + paylaşım kodu, hikâye bölümleri.

## 9. Riskler

- **Kapsam:** her şey aynı anda yapılamaz. Önce ölçmek (analitik), sonra büyütmek.
- **Hile:** rekabetçi özellikler (lider tablosu, fuar) istemci otoritesiyle zayıf kalır. Koşu kaydının sunucuda doğrulanması şart.
- **Politika:** kasa + gerçek para + Türkiye 2026 düzenlemesi. Yaş beyanı ve ebeveyn onayı akışı.
- **Paket boyutu:** yeni araç / mekân her eklendiğinde artar. Asset Delivery planı.
- **Performans:** düşük kademe telefonlar. Her yeni sistem bir "kapat" ayarıyla gelmeli.

## 10. Ölçüm (analitik olay listesi önerisi)

`tutorial_step`, `first_repair`, `repair_collect`, `crate_open (crate, rarity)`, `race_finish (won, class, arm, chance)`, `mod_install`, `decor_place`, `visit_friend`, `gift_send`, `iap_view`, `iap_purchase`, `ad_offer_shown`, `ad_watched`, `level_up`, `session_start` / `session_end`, `screen_view`.

Hedefler (2024 karşılaştırması, 11,6 bin oyun): D1 üst çeyrek ~%26,5–27,7, D7 üst çeyrek %7–8. Android iOS'tan düşük ([kaynak](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)). Türkiye 2025 IAP geliri 374 M$ (+%6), indirmeler 1,8 milyar (−%4): büyüme yeni kullanıcıdan değil harcamadan geliyor ([kaynak](https://mobilegamer.biz/data-digest-turkiye-us-asia-and-mena-market-stats-pokemon-go-ua-funding-and-more/)).

## 11. Bu gecenin ekran taraması (22 Ekim)

`tools/ekran_tarama.sh` ile 7 oranın hepsi tarandı: 20:9, 16:9 (en küçük, 853×480), 16:10, 4:3, katlanabilir (853×711, en büyük), 21:9, masaüstü. Her profilde 99 ekran durumu var.

**Düzeltilenler:**
- Mağazada SÜPER KASA olasılık listesi alt satıra taşıyordu. 480 yükseklikli ekranlarda GERİ satırı 10 birim ekran dışına çıkıyordu. Satır sıkılaştırıldı ve plaka 250 → 264 birim oldu; artık hepsi tek satırda.
- Araç arıza plakasında, iki satırlı arıza düğmesinde (REVİZYON / 300 sn) anahtar simgesi yazının üstüne biniyordu. Simge artık yazının solunda.
- Nadirlik adları her ekranda Türkçe (§4).
- Modifiye garajı: kategori çekimleri plakaların arasındaki görünür pencereye oturuyor (16:9, 20:9 ve 4:3'te denetlendi).
- **Diğer diller (en küçük ekranda Almanca, Fransızca, İspanyolca, İngilizce taraması):** uzun metinler sığmayınca artık yazı küçülüyor, kesilmiyor:
  - Mağaza olasılık listesi Almanca "GEWÖHNLICH" ile yine taşıyordu (GERİ 27 birim dışarıda). Plaka artık satırları ekrana sığacak kadar küçültüyor.
  - SEVİYE ATLADIN kartlarında Almanca tek sözcük "BREMSENÜBERHOLUNG" kesiliyordu. Fransızca kart açıklamaları da iki satıra sığmıyordu; artık üç satır.
  - DEPOLARIM merdiveninde İngilizce "UNDERGROUND STORAGE" ve Fransızca "17 VOITURES · … PAR JOUR" kesiliyordu.
- **En büyük HUD boyutu (AYARLAR → %120) ile en küçük ekran:**
  - Kasa sorusu açıkken gelen bildirim ("PARÇA HAZIR…") sol üstteki MARKET düğmesinin üstüne biniyordu. Artık alt şerit üstteki bloklara yetişecekse yalnız o an biraz küçülüyor (en fazla %80'e). Sığdığı sürece seçilen boyutta kalıyor.
  - Profil panosu sağdan 3 birim taşıyordu. Pano artık ekranın içinde kalıyor.

**Bilinçli bırakılanlar (otomatik denetim "sorun" diyor ama tasarım):**
- Eğitim ders kartının eğik ikaz şeridi.
- Yarış ekranında süre ile REKOR satırının 4 birimlik bindirmesi.

**Sonra bakılabilecek küçük cilalar:**
- TÜM ARAÇLAR kartlarında uzun model adları iki satıra iniyor ("STALLION RING / 18").
- Depo İÇ YÜKSELTMELER panosunda son satır 480 yükseklikte kaydırmayla görünüyor.
- Büyük ekranlarda (4:3, katlanabilir) panolar 480 yüksekliğe göre tasarlandığı için ortada küçük kalıyor. Kırık değil ama boşluk çok.
- %120 HUD'da en küçük ekranda profil panosu sağ kenara yaslanıyor; profil kartı sabit 544 birim. Kart dar ekranda daraltılabilir.

Sonuç: en küçük ve en büyük ekranda kırık, taşan ya da üst üste binen öğe kalmadı.

---

### Kaynaklar (seçme)
- Car Town: [Game Developer](https://www.gamedeveloper.com/game-platforms/cie-nascar-partner-for-i-car-town-i-racing) · [AutoGuide](https://www.autoguide.com/auto-news/2010/08/car-town-facebook-game-lets-you-pimp-your-virtual-ride-and-much-much-more.html) · [SuperCheats (ikincil)](https://www.supercheats.com/guides/car-town/)
- CSR2: [App Store](https://apps.apple.com/us/app/app/id887947640) · [Elite Tuners](https://www.businesswire.com/news/home/20201124005059/en)
- NFS No Limits: [Wikipedia](https://en.wikipedia.org/wiki/Need_for_Speed:_No_Limits) · Car Parking Multiplayer: [App Store](https://apps.apple.com/app/id1374868881) · Pixel Car Racer: [App Store](https://apps.apple.com/us/app/-/id1068808996) · Torque Drift: [App Store](https://apps.apple.com/app/id1200357146)
- Hay Day Daily Dirt: [wiki](https://hayday.fandom.com/wiki/Daily_Dirt) · Township Regatta: [Play](https://play.google.com/store/apps/eventdetails/4829873756313551377) · Monopoly GO: [Sensor Tower](https://sensortower.com/blog/monopoly-go-app-revenue-milestone)
- Kulüpler: [Naavik](https://naavik.co/f2p-mobile/building-clan-features/) · Battle pass: [Liquid & Grit](https://www.liquidandgrit.com/february-2024-core-report/)
- Politika: [Google Play](https://support.google.com/googleplay/android-developer/answer/9858738) · [FTC](https://www.ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse) · [Türkiye 5651](https://www.mondaq.com/turkey/gaming/1786408/new-regulations-in-the-social-network-and-gaming-sector)
