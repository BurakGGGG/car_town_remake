# CarTownRemake — Game Design Document

Kaynak: orijinal Car Town (Cie Games, 2010–2014) araştırması + mevcut kod tabanının ölçülen
değerleri. Bu belge **tasarım kararlarını** tutar; kod değişikliği içermez.

Etiketler: **[MEVCUT]** bugün kodda var · **[YENİ]** önerilen · **[VERİ]** yalnızca veri değişikliği
(yeni kod gerekmez) · **[KOD]** yeni kod gerekir.

---

## 0. MEVCUT SİSTEMLERİN ÖLÇÜLEN DURUMU

| Sistem | Değer |
|---|---|
| Başlangıç | 5.000 ₺ · 40 gem · XP 35 · Level 1 · BMW E46 ücretsiz |
| Arızalar | MOTOR 10 sn/150 ₺/10 XP · FREN 8/140/9 · LASTİK 6/100/7 · KAPORTA 12/200/14 (maliyet 0) |
| Müşteri akışı | Her **6–14 sn**'de bir müşteri (ort. 10 sn), aynı anda **en fazla 2 bekleyen** |
| Trafik | `max_vehicles = 4` |
| Tamir alanı | 3 CarSpot · fiyat [0, 8.000, 20.000] · garaj seviyesiyle ortaya çıkar, ayrıca satın alınır |
| Garaj seviyesi | 4 seviye · 25.000 / 50.000 / 100.000 ₺ · zemin 2×1,5 → 4×3 → 6×4,5 → 8×6 |
| Tamir hızı | Lv1-5 · 1.000/2.000/3.500/5.000 ₺ · süre ×1,0 / 0,9 / 0,8 / 0,7 / 0,6 |
| Araçlar | 7 araç, 22.000–125.000 ₺ |
| Görevler | 12 görev, sıralı zincir, aynı anda 3 aktif, ödül **yalnızca XP (20–40) + gem (5–10)** |
| XP eğrisi | `xp_to_next = xp_base × 1,25^(level−1)` |
| Kayıt | savegame.json v6 + CloudSaveManager (aynı snapshot) |

### 0.1 KRİTİK BULGU — kapasite tavanı

Müşteri arzı ortalama **10 sn**'de bir → **dakikada 6 müşteri**.
Tamir süresi ortalama 9 sn olduğu için:

- **1 bay:** darboğaz tamir süresi → ~5 tamir/dk → **~740 ₺/dk**
- **2 bay:** darboğaz **müşteri arzı** → 6 tamir/dk → **~885 ₺/dk**
- **3 bay:** darboğaz yine müşteri arzı → **~885 ₺/dk — 3. bay hiçbir şey kazandırmıyor**

Yani bugünkü haliyle **GARAJ SV.3 (50.000 ₺) + BAY 3 (20.000 ₺) = 70.000 ₺'lik yatırımın geliri
sıfır.** Car Town'da bu sorun yoktu çünkü işler bay menüsünden *sınırsız* başlatılıyordu; bizde
müşteri akışı fiziksel ve sınırlı.

**Bu belgenin en önemli önerisi: garaj seviyesi müşteri arzını da artırmalı.**

---

## 1. NEYİ ALALIM

| # | Car Town mekaniği | Neden bize uyar | Öncelik |
|---|---|---|---|
| 1 | **İş süresi portföyü** (2 dk → 72 saat) | Tek tip 6–12 sn'lik iş var; kısa/orta/uzun ayrımı hem aktif hem offline oyuncuyu tutar | **P0** |
| 2 | **Job Mastery** (iş başına ustalık yıldızı) | Aynı 4 arızayı 500 kez yapmayı anlamlı kılar | **P1** |
| 3 | **Garage Value + 10 rütbe** | XP'den bağımsız ikinci eksen; pahalı araçları kilitler, garaja yatırımı ödüllendirir | **P1** |
| 4 | **Koleksiyon bonusları** | 7 aracımız var, 3 koleksiyon çıkar; tek seferlik büyük ödül | **P2** |
| 5 | **Daily reward serisi** | Geri dönüş kancası; en ucuz sistem | **P1** |
| 6 | **Idle functional item'lar** | Garajı doldurmaya sebep verir, Garage Value'yu besler | **P3** |
| 7 | **İşin yanması / aciliyet** | Toplamayı unutunca ceza → oyuncu dönmek zorunda | **P2** |
| 8 | **Seviyeye bağlı içerik kilidi** | Bizde level hiçbir şeyi açmıyor; Car Town'da her seviye bir şey açıyordu | **P0** |
| 9 | **Araç sınıfı (D/C/B/A)** | Müşteri değerini ve GV kilidini sınıfa bağlamak için | **P2** |
| 10 | **Araç satışı** | SAT plakası ölü; `remove_vehicle()` hazır | **P2** |

## 2. NEYİ ALMAYALIM

| Car Town mekaniği | Neden almıyoruz |
|---|---|
| **Mystery box / gacha** | Showroom'umuz (360° inceleme, fiyat, SATIN AL) gacha'dan iyi. Kumar mekaniği oyunun "usta tamirci" temasına ters |
| **Fuel / enerji** | Bizde tamiri sınırlayan şey zaten bay sayısı + müşteri akışı. İkinci bir sınır oyunu keser |
| **Arkadaş sistemi / worker** | Tek oyunculu, çevrimdışı oynanabilir olmalı. Bulut kayıt var ama sosyal katman yok |
| **Yarış / drag race** | Ayrı bir oyun. Tamir simülasyonunun odağını dağıtır |
| **Car Show / oylama** | Sosyal sisteme bağlı |
| **Duplicate araç dönüşümü** | Bizde aynı araçtan iki tane olamaz (gacha yok) → karşılığı yok |
| **Premium para ile seviye atlama** | Gem'lerimiz var ama "parayla level kilidi aşma" oyunu bozar |
| **4. kat / çok katlı garaj** | Fiziksel izometrik garajımızda kat mantığı yok, zemin genişlemesi yeterli |

---

## 3. CORE GAME LOOP

```
        ┌─────────────────────────────────────────────────┐
        │                                                 │
        ▼                                                 │
  Müşteri gelir (yol kenarı, 🔧)                          │
        │                                                 │
        ▼                                                 │
  TAMİRE AL → araç bay'e girer → süre işler               │
        │                                                 │
        ▼                                                 │
  PARA TOPLA → ₺ + XP + iş ustalığı +1                    │
        │                                                 │
        ├──────────────┬──────────────┬───────────────┐   │
        ▼              ▼              ▼               ▼   │
   TAMİR HIZI     GARAJ SEVİYESİ   YENİ ARAÇ      DEKOR   │
   (süre ↓)      (alan + müşteri   (showroom)   (idle ₺)  │
                  arzı + sınıf ↑)      │            │     │
        │              │               │            │     │
        │              ▼               ▼            ▼     │
        │          BAY AÇ  ────► Garage Value ◄─────┘     │
        │        (kapasite ↑)          │                  │
        │              │               ▼                  │
        │              │         GV RÜTBESİ               │
        │              │      (pahalı araç kilidi)        │
        └──────────────┴───────────────┴──────────────────┘
```

**Üç ayrı eksen — birbirine bağlanmayacak:**

| Eksen | Neyi açar | Nasıl artar |
|---|---|---|
| **Player Level (XP)** | Yeni **iş türleri**, showroom'da yeni araçlar | Tamir XP'si |
| **Garage Level (₺)** | **Fiziksel alan** + bay'in *görünmesi* + müşteri arzı + müşteri sınıfı | Satın alma |
| **Repair Bay (₺)** | **Kapasite** (aynı anda tamir) | Ayrı satın alma |
| **Garage Value (türetilmiş)** | GV rütbesi → pahalı araç/dekor kilidi | Sahip olunan varlıkların toplamı |

---

## 4. SİSTEM SİSTEM ANALİZ

### 4.1 Tamir işleri (job portföyü)

- **MEVCUT DURUM:** 4 arıza, 6–12 sn, 100–200 ₺, hepsi Level 1'de açık, maliyet 0. `RepairType`
  zaten `duration / cost / reward / xp / min_level / weight / severity` alanlarına sahip.
- **CAR TOWN REFERANSI:** 25 iş, 2 dk – 72 saat. Kısa iş = yüksek ₺/saat ama sürekli oyunda
  olmayı gerektirir (Fuzzy Dice 600 ₺/saat), uzun iş = yüksek mutlak kâr, offline oyuncu için
  (Body Kit 3.650 ₺ / 72 saat). Her iş bir seviyede açılır.
- **BİZE UYGUNLUĞU:** Çok yüksek. `RepairType.defaults()` bir **veri listesi** — yeni iş eklemek
  kod değil veri. Tek gerçek iş: uzun işlerin oyun kapalıyken ilerlemesi.
- **ÖNERİLEN TASARIM — 3 kademe:**

  | Kademe | Süre | Ödül | Seviye | Örnek |
  |---|---|---|---|---|
  | **Hızlı** | 6–12 sn | 100–200 ₺ | 1 | LASTİK, FREN, MOTOR, KAPORTA (mevcut) |
  | **Orta** | 2–10 dk | 600–2.500 ₺ | 5+ | BOYA (3 dk/900 ₺), DÖŞEME (5 dk/1.400 ₺), FREN REVİZYONU (8 dk/2.200 ₺) |
  | **Uzun** | 1–8 saat | 8.000–45.000 ₺ | 12+ | MOTOR REVİZYONU (2 s/12.000 ₺), KOMPLE KAPORTA (6 s/35.000 ₺), RESTORASYON (8 s/45.000 ₺) |

  Uzun iş bir bay'i **işgal eder** → gerçek bir karar doğar: "bu bay'i hızlı işlere mi ayırayım,
  yoksa gece boyu restorasyona mı?" Oyundan çıkarken uzun iş başlatmak doğal davranış olur.
  **Toplama penceresi = iş süresi kadar**; geçerse iş yanar (hızlı işlerde uygulanmaz).
- **GELİŞTİRME ZORLUĞU:** Hızlı/orta işler **[VERİ]** (düşük). Uzun işler **[KOD]** (orta):
  `RepairState` gerçek zaman damgası tutmalı ve SaveManager'a yazılmalı (offline ilerleme).
- **MEVCUT SİSTEMLERE ETKİSİ:** RepairManager state machine **değişmez**. Yalnızca
  `RepairState` + save şeması genişler.
- **ÖNCELİK: P0** (hızlı+orta) / **P1** (uzun).

### 4.2 Müşteri arzı ve müşteri değeri

- **MEVCUT DURUM:** Sabit 6–14 sn, en fazla 2 bekleyen, `max_vehicles = 4`. Ödül müşterinin
  aracından bağımsız.
- **CAR TOWN REFERANSI:** Doğrudan karşılığı yok (orada iş menüden sınırsız başlatılıyordu).
- **BİZE UYGUNLUĞU:** Zorunlu — bölüm 0.1'deki kapasite tavanı başka türlü çözülmüyor.
- **ÖNERİLEN TASARIM:**

  | Garaj Sv. | Müşteri aralığı | Bekleyen limiti | Trafik | Müşteri sınıfı | Ödül çarpanı |
  |---|---|---|---|---|---|
  | 1 | 6–14 sn | 2 | 4 | D | ×1,0 |
  | 2 | 5–11 sn | 3 | 5 | D–C | ×1,15 |
  | 3 | 4–9 sn | 4 | 6 | C–B | ×1,35 |
  | 4 | 3–7 sn | 4 | 6 | B–A | ×1,6 |

  Böylece garaj seviyesi **üç şey birden** verir: alan + yeni bay'in görünmesi + daha çok/daha
  değerli müşteri. 3. bay'in ekonomik anlamı doğar.
- **ZORLUK:** Düşük **[KOD]** — RepairManager'daki iki export ve `MAX_REPAIR_WAITING` sabiti
  garaj seviyesinden okunur; yeni bekleme noktası gerekir (şu an 2 tane var, 4'e çıkmalı).
- **ETKİ:** RepairManager'ın müşteri seçim algoritması aynı kalır.
- **ÖNCELİK: P0.**

### 4.3 Garage Level (fiziksel genişleme) — **DOKUNMA, SADECE BESLE**

- **MEVCUT DURUM:** 4 seviye, 25.000/50.000/100.000 ₺, zemin+duvar fiziksel büyüyor, yeni bay
  kilitli olarak beliriyor, dünyadaki tabeladan satın alınıyor. **Bu sistem yeni bitti ve doğru
  çalışıyor.**
- **CAR TOWN REFERANSI:** Land Expansion 15×15 → 40×40, seviye şartı + coin, **atlanamaz**,
  premium ile seviye şartı aşılabilir.
- **BİZE UYGUNLUĞU:** Zaten uyguladık ve Car Town'dan daha iyi (bizimki gerçekten fiziksel).
- **ÖNERİLEN TASARIM:** Yapıyı değiştirme; yalnızca **fiyatları** (bölüm 10) ve **müşteri arzı
  etkisini** (4.2) ekle. `repair_capacity` geliştirmesinin geri gelmemesi kuralı korunur.
- **ZORLUK:** Yok (veri) · **ETKİ:** Yok · **ÖNCELİK: P0 (yalnızca fiyat).**

### 4.4 Repair Bay (kapasite) — **DOKUNMA**

- **MEVCUT DURUM:** `RepairBayManager`, iki aşamalı açılış (garaj seviyesi gösterir → ayrı ücret
  açar), fiyat [0, 8.000, 20.000], kilitli alan dünyada fiziksel görünür.
- **CAR TOWN REFERANSI:** Work Bay $800, 14 kozmetik varyant, faydalı üst sınır 8 (worker sayısı).
- **ÖNERİLEN TASARIM:** Mimari aynı. Yalnızca fiyat ayarı. İleride 4. bay istenirse
  `PARK_SLOTS` + `BAY_PRICES` dizilerine satır eklemek yeterli.
- **ZORLUK:** Yok · **ÖNCELİK: P0 (yalnızca fiyat).**

### 4.5 Job Mastery

- **MEVCUT DURUM:** Yok. Aynı arızayı 1000. kez yapmakla 1. kez yapmak aynı.
- **CAR TOWN REFERANSI:** İş başına 5 yıldız; kademeler (ör. Fuzzy Dice 250/750/1500/2750 iş)
  **XP/iş**'i artırır, her kademe tek seferlik 5.000–20.000 coin verir, 5. yıldızda o işin
  "Mastery Sign" dekoru gelir.
- **BİZE UYGUNLUĞU:** Yüksek — 4 arızanın tekrar hissini anlamlı kılar, yeni içerik gerektirmez.
- **ÖNERİLEN TASARIM:** Arıza türü başına sayaç. Kademeler **10 / 50 / 150 / 400 / 1000 tamir**.
  Her kademe: `+%10 XP` (kümülatif, 5. yıldızda +%50) ve tek seferlik **1.000 / 3.000 / 8.000 /
  20.000 / 50.000 ₺**. 5. yıldızda garajda o arızanın **ustalık plakası** (dekor + Garage Value).
  HUD: tamir plakasında arıza adının yanında yıldız.
- **ZORLUK:** Düşük-orta **[KOD]** — yeni `JobMasteryManager` (grup `job_mastery`), save alanı
  `job_mastery: {engine: 42, ...}`, RepairManager `collect()` içinde tek satır sayaç artışı.
- **ETKİ:** RepairManager'a tek çağrı eklenir; ödül hesabı XP çarpanı alır.
- **ÖNCELİK: P1.**

### 4.6 Garage Value + rütbe

- **MEVCUT DURUM:** Yok. Garajın "değeri" kavramı yok.
- **CAR TOWN REFERANSI:** GV = garajdaki varlıkların dolar değeri; 10 isimli rütbe
  ($60K Flimsy → $60M Exalted); **pahalı araçlar GV8/GV9/GV10 ile kilitli**; 4. kat GV9 istiyor.
- **BİZE UYGUNLUĞU:** Yüksek. XP'den bağımsız, "koleksiyoncu" hedefi verir ve garaja yatırımı
  ödüllendirir. **Türetilmiş** bir değer olduğu için yeni kayıt alanı bile gerekmez.
- **ÖNERİLEN TASARIM:**
  `GV = Σ(sahip olunan araçların katalog fiyatı) + Σ(garaj seviyesi için ödenen) + Σ(açılan bay
  ücretleri) + Σ(dekor eşya değeri)`

  | # | Rütbe | Eşik (Normal senaryo) |
  |---|---|---|
  | 1 | DERME ÇATMA GARAJ | 0 |
  | 2 | VASAT GARAJ | 100.000 |
  | 3 | MÜTEVAZI GARAJ | 175.000 |
  | 4 | GÖZE ÇARPAN GARAJ | 275.000 |
  | 5 | İYİ GARAJ | 400.000 |
  | 6 | ETKİLEYİCİ GARAJ | 600.000 |
  | 7 | SAYGIN GARAJ | 850.000 |
  | 8 | HARİKA GARAJ | 1.200.000 |
  | 9 | GÖZ KORKUTAN GARAJ | 1.700.000 |
  | 10 | EFSANE GARAJ | 2.500.000 |

  (Başlangıçta BMW 85.000 + garaj = ~85.000 → 1. rütbe. Tüm araçlar + tüm yükseltmeler ≈ 600.000
  → 6. rütbe. 7–10 arası **dekor ve ustalık plakalarıyla** doldurulur → idle eşya sisteminin
  varlık sebebi bu.)

  Kullanımı: HUD'da level rozetinin altında rütbe çubuğu (tıklayınca 10 basamaklı merdiven —
  Car Town'daki gibi); showroom'da en pahalı 2 araç **GV rütbe 4/5 şartı** ile kilitli.
- **ZORLUK:** Düşük **[KOD]** — saf hesap + bir UI plakası + showroom'da kilit kontrolü.
- **ETKİ:** VehicleOwnership/GarageUpgradeManager'dan okur, hiçbirini değiştirmez.
- **ÖNCELİK: P1.**

### 4.7 Araç ilerlemesi ve sınıf

- **MEVCUT DURUM:** 7 araç, 22.000–125.000 ₺, `category` (sedan/hatchback) ve `condition` var,
  sınıf yok, seviye kilidi yok. BMW ücretsiz başlangıç.
- **CAR TOWN REFERANSI:** Class D→C→B→A→★; her araçta coin fiyatı + **level şartı** + GV şartı;
  araçların "XP Gain" değeri var.
- **ÖNERİLEN TASARIM:** `cars.json`'a iki alan: `class` (D/C/B/A) ve `min_level`.

  | Araç | Sınıf | Fiyat (Normal) | Seviye | GV rütbesi |
  |---|---|---|---|---|
  | Tofaş Şahin | D | 15.000 | 1 | – |
  | Renault Toros | D | 20.000 | 3 | – |
  | Hyundai Era | C | 30.000 | 6 | – |
  | Hyundai Getz | C | 35.000 | 8 | – |
  | VW Passat B5.5 | B | 50.000 | 12 | 3 |
  | Renault Fluence | B | 60.000 | 15 | 4 |
  | **BMW E46** (başlangıç) | A | 85.000 | – | – |

  Sınıf ayrıca **müşteri ödülü çarpanını** belirler (4.2) ve ileride yeni araç eklendiğinde
  tek satırlık veri olur.
- **ZORLUK:** Düşük **[VERİ]** + showroom'da kilit rozeti **[KOD]**.
- **ETKİ:** CarCatalog yapısı korunur (yalnızca yeni alanlar), Showroom akışı aynı.
- **ÖNCELİK: P2.**

### 4.8 Araç satışı

- **MEVCUT DURUM:** Garajda **SAT plakası var ama ölü** (`action_selected` dinleyicisi yok).
  `VehicleOwnership.remove_vehicle()` hazır, son aracı çıkarmayı reddediyor.
- **CAR TOWN REFERANSI:** Recycling Box — eşya/araç atınca coin verir, kalıcı kayıp.
- **ÖNERİLEN TASARIM:** SAT → onay plakası ("ŞAHİN'İ SAT — 6.000 ₺ · VAZGEÇ") → fiyatın **%40**'ı.
  Boyalı araçta boya bedeli iade edilmez. Son araç satılamaz. Satış **Garage Value'yu düşürür**
  → rütbe kaybı riski, anlamlı bir karar.
- **ZORLUK:** Düşük **[KOD]** · **ETKİ:** Yalnızca GarageScreen + VehicleOwnership · **ÖNCELİK: P2.**

### 4.9 Idle / functional garaj eşyaları

- **MEVCUT DURUM:** Yok. Garaj zemini genişliyor ama boş kalıyor.
- **CAR TOWN REFERANSI:** Kiddie ride / vending machine / gas pump — her biri "X saatte Y coin"
  üretir, tıklayınca toplanır; Garage Value'ya yazılır. (Kiddie Spaceship 24 s/1.250 coin,
  Air Hockey 10 dk/13 coin.)
- **BİZE UYGUNLUĞU:** Orta-yüksek. Genişleyen garajın **boş kalma sorununu** çözer ve GV 7–10
  rütbelerini doldurur. Ama en pahalı iş.
- **ÖNERİLEN TASARIM:** 5–6 sabit eşya (otomat, kahve makinesi, lastik rafı, alet dolabı,
  neon tabela, ustalık plakaları). Garaj ekranından satın alınır, **boş CarSpot olmayan** garaj
  hücresine yerleşir, üstünde geri sayım + dolunca ₺ balonu; dünyada tıklanınca toplanır.
  Üretim: 10 dk/150 ₺ … 8 saat/6.000 ₺ aralığı.
- **ZORLUK:** Yüksek **[KOD]** — yerleştirme, zamanlayıcı, kayıt, dünya tıklaması.
- **ETKİ:** Yeni manager; garaj sahnesine node ekler. Mevcut sistemlere dokunmaz.
- **ÖNCELİK: P3** (garaj Sv.3'ten sonra anlamlı).

### 4.10 Koleksiyonlar

- **MEVCUT DURUM:** Yok.
- **CAR TOWN REFERANSI:** Onlarca koleksiyon; tamamlayınca tek seferlik büyük ödül
  (1970 Muscle Car: 4 araç → 35.000 coin + 3.500 XP).
- **ÖNERİLEN TASARIM:** 3 koleksiyon:
  - **TÜRK KLASİKLERİ** — Şahin + Toros → 15.000 ₺ + 500 XP
  - **HATCHBACK** — Getz + Era → 20.000 ₺ + 700 XP
  - **SEDAN** — BMW + Fluence + Passat → 60.000 ₺ + 2.000 XP + garaj plaketi (dekor, GV)
  Garaj ekranında araç listesinin üstünde küçük bir rozet satırı.
- **ZORLUK:** Düşük **[VERİ + KOD]** — `collections.json` + VehicleOwnership'te kontrol.
- **ETKİ:** Yok · **ÖNCELİK: P2.**

### 4.11 Görev sistemi (QuestManager)

- **MEVCUT DURUM:** 12 sıralı görev, 3 aktif, ödül yalnızca **XP + gem**. Oyuncuya "şimdi ne
  yapmalıyım" sorusunu cevaplayan tek sistem bu.
- **CAR TOWN REFERANSI:** Görev vardı ama zayıftı; asıl yönlendirme **seviye ödülleriydi**.
- **ÖNERİLEN TASARIM:** Görev zincirini **ilk 60 dakikanın senaryosuna** göre yeniden yaz
  (bölüm 6) ve ödüllere **coin** ekle — ilk 5 görev oyuncunun ilk yükseltmelerini finanse etsin.
  Görev metni her zaman **tek bir eylem** söylesin ("GARAJI SEVİYE 2 YAP" gibi).
- **ZORLUK:** Düşük **[VERİ]** — `quest_catalog.gd` bir liste.
- **ETKİ:** QuestManager kodu değişmez (coin ödülü varsa EconomyManager çağrısı eklenir).
- **ÖNCELİK: P0.**

### 4.12 Daily reward + geri dönüş kancaları

- **MEVCUT DURUM:** Yok.
- **CAR TOWN REFERANSI:** Üst üste giriş serisi; 7. günde araç.
- **ÖNERİLEN TASARIM:** 7 günlük seri: 500 ₺ · 1.000 ₺ · 5 gem · 2.500 ₺ · 10 gem · 5.000 ₺ ·
  **ücretsiz araç (Şahin)**. Seri bozulursa 1. güne döner. Giriş ekranında fiziksel plaka.
  İkinci kanca: **uzun işler** (4.1) ve **idle eşyalar** (4.9).
- **ZORLUK:** Düşük **[KOD]** — save alanı `daily: {last_day, streak}`.
- **ETKİ:** Yok · **ÖNCELİK: P1.**

### 4.13 Player Level'ın anlamı

- **MEVCUT DURUM:** Level artıyor ama **hiçbir şey açmıyor** (tüm arızalar Lv1, tüm araçlar
  serbest). `min_level` alanı RepairType'ta var ama hep 1.
- **CAR TOWN REFERANSI:** Her seviye bir şey açardı: iş türü, alan, worker, araç, coin ödülü.
- **ÖNERİLEN TASARIM:** Seviye ödül tablosu (bölüm 7) — her seviye **coin ödülü** + belirli
  seviyelerde **yeni iş türü / yeni araç / yeni dekor**. Level atlayınca fiziksel bildirim plakası.
- **ZORLUK:** Düşük **[VERİ]** · **ÖNCELİK: P0.**

---

## 5. FIRST 60 MINUTES

Hedef: oyuncu hiçbir anda "şimdi ne yapacağım?" demesin; **her ~10 dakikada bir satın alma**.

| Dakika | Oyuncu ne yapar | Ne açılır / hisseder | Sistem |
|---|---|---|---|
| 0–1 | Oyun açılır, BMW garajda, ilk müşteri 6–14 sn içinde gelir. Görev: **"İLK MÜŞTERİNİ TAMİR ET"** | Döngüyü öğrenir (tıkla → TAMİRE AL → PARA TOPLA) | Quest + Repair |
| 1–5 | 8–12 tamir, ~1.500 ₺. Görev: **"5 TAMİR YAP"** → +1.000 ₺ | Para akıyor hissi | Quest ödülü **coin** |
| 5–10 | **TAMİR HIZI Lv2** (1.000 ₺) alınır. Görev: **"TAMİR HIZINI YÜKSELT"** | İlk yükseltme; tamirler gözle görülür hızlanır | GarageUpgrade |
| 10–15 | Level 3–4. **ORTA İŞLER açılır (Lv5)** hedefi görünür | "Daha büyük iş" merakı | Level ödülü |
| 15–25 | ~12.000 ₺ birikir → dünyadaki **GARAJI GENİŞLET** tabelası hedefe döner | Garaj fiziksel olarak büyür — en güçlü görsel ödül | GarageSystem |
| 25–30 | Garaj Sv.2 → **BAY 2 kilitli belirir** + müşteri arzı artar | "Yeni alanım var ama kilitli" gerilimi | RepairBay |
| 30–40 | **BAY 2 açılır** (5.000 ₺) → kapasite 2 → gelir ~%50 artar | Yatırımın karşılığını anında görür | RepairBay |
| 40–50 | İlk **ORTA İŞ** (BOYA, 3 dk/900 ₺) gelir → bay seçimi kararı doğar | Taktik derinlik | RepairType |
| 50–60 | ~15.000 ₺ → showroom'dan **ilk yeni araç (Şahin)** | Koleksiyon başlar; GV artar | Showroom |

**İlk 60 dakikanın sonunda:** 2 araç, 2 bay, garaj Sv.2, tamir hızı Lv2, ~10. seviye, ilk
koleksiyon görünür durumda.

---

## 6. FIRST 10 HOURS

| Süre | Hedef | Açılan |
|---|---|---|
| **1 saat** | 2 bay + ilk araç | Orta işler, koleksiyon rozetleri |
| **2 saat** | Tamir Hızı Lv3–4, Garaj Sv.3 (30.000 ₺) | 3. bay görünür, müşteri arzı 9/dk |
| **3 saat** | **BAY 3 açılır** (12.000 ₺) → tam kapasite | **UZUN İŞLER (Lv12)**: gece bırakılan restorasyon |
| **4 saat** | 2. ve 3. araç (Toros, Era) | **TÜRK KLASİKLERİ koleksiyonu** tamamlanır (+15.000 ₺) |
| **5 saat** | Job Mastery 2–3 yıldızlar, Garaj Sv.4 (60.000 ₺) | Müşteri sınıfı B–A, ödül ×1,6 |
| **6–7 saat** | Getz + Passat | **HATCHBACK koleksiyonu**, GV rütbe 4–5 |
| **8–10 saat** | Fluence, idle dekorlar, ustalık plakaları | **SEDAN koleksiyonu** (+60.000 ₺), GV rütbe 6–7 |

**10 saat sonrası (endgame):** 7 aracın tamamı → GV 7–10 rütbeleri yalnızca **dekor + ustalık
plakaları + boya** ile doldurulur; Job Mastery 5 yıldızları (1000 tamir) uzun vadeli hedef;
uzun işler günlük ritüel olur. **Yeni içerik gerektiğinde tek satır veri**: yeni araç, yeni iş
türü, yeni koleksiyon.

---

## 7. PLAYER LEVEL PROGRESSION (öneri)

| Seviye | Coin ödülü | Açılan |
|---|---|---|
| 2 | 500 | — |
| 3 | 750 | Araç: Toros |
| 5 | 1.250 | **ORTA İŞLER** (BOYA, DÖŞEME) |
| 6 | 1.500 | Araç: Era |
| 8 | 2.000 | Orta iş: FREN REVİZYONU · Araç: Getz |
| 10 | 2.500 | Dekor: otomat (idle) |
| 12 | 3.000 | **UZUN İŞLER** (MOTOR REVİZYONU) · Araç: Passat |
| 15 | 3.750 | Uzun iş: KOMPLE KAPORTA · Araç: Fluence |
| 18 | 4.500 | Dekor seti 2 |
| 20 | 5.000 | Uzun iş: RESTORASYON (8 saat) |
| 25+ | +250/seviye | Kozmetik + ustalık hedefleri |

---

## 8. EKONOMİ — 3 SENARYO

Gelir modeli (ölçülen): 1 bay ≈ **740 ₺/dk** teorik, %60 aktiflikle **~26.000 ₺/saat**;
2 bay + Sv.2 arz ≈ **~40.000 ₺/saat**; 3 bay + Sv.3 ≈ **~58.000 ₺/saat**.

| | **A) CASUAL** | **B) NORMAL** *(önerilen)* | **C) HARD** |
|---|---|---|---|
| Başlangıç parası | 7.500 ₺ | **5.000 ₺** (mevcut) | 3.000 ₺ |
| Tamir ödülleri | ×1,4 → 140/196/210/280 | **mevcut** → 100/140/150/200 | ×0,8 → 80/112/120/160 |
| 1. saat geliri (tahmini) | ~36.000 ₺ | **~26.000 ₺** | ~21.000 ₺ |
| Garaj Sv.2 | 8.000 ₺ | **12.000 ₺** | 20.000 ₺ (mevcut 25.000) |
| BAY 2 | 3.500 ₺ | **5.000 ₺** | 8.000 ₺ (mevcut) |
| Garaj Sv.3 | 20.000 ₺ | **30.000 ₺** | 50.000 ₺ (mevcut) |
| BAY 3 | 8.000 ₺ | **12.000 ₺** | 20.000 ₺ (mevcut) |
| Garaj Sv.4 | 40.000 ₺ | **60.000 ₺** | 100.000 ₺ (mevcut) |
| En ucuz araç (Şahin) | 10.000 ₺ | **15.000 ₺** | 22.000 ₺ (mevcut) |
| Araç aralığı | 10.000–55.000 | **15.000–85.000** | 22.000–125.000 (mevcut) |
| **Bay 2 açılma süresi** | ~20 dk | **~35 dk** | ~70 dk |
| **İlk yeni araç** | ~25 dk | **~50 dk** | ~100 dk |
| Tüm araçlar | ~4 saat | **~8 saat** | ~15 saat |

**Öneri: B) NORMAL.** Başlangıç parası ve tamir ödülleri **hiç değişmez** (kod riski sıfır),
yalnızca garaj/bay/araç fiyatları düşer. Mevcut değerler aslında **C) HARD** senaryosudur.

---

## 9. ŞU AN KODA DOKUNMAMIZ GEREKEN 5 ŞEY

| # | İş | Dosya | Tür | Neden şimdi |
|---|---|---|---|---|
| 1 | **Fiyat dengesi** (garaj Sv.2-4, bay 2-3, araç fiyatları) | `garage_upgrade.gd`, `repair_bay_manager.gd`, `cars.json` | **[VERİ]** | Bugün ilk satın alma 70 dakikada geliyor; oyuncu oraya varamaz |
| 2 | **Garaj seviyesi müşteri arzını artırsın** | `repair_manager.gd` (2 export + waiting limiti) + 2 yeni bekleme noktası | **[KOD]** düşük | 3. bay'in ekonomik anlamı yok (bölüm 0.1) |
| 3 | **Orta süreli işler + seviye kilidi** | `repair_type.gd` `defaults()` | **[VERİ]** | Tek tip 6–12 sn'lik iş oyunu 20 dakikada tüketiyor |
| 4 | **Görev zinciri + seviye ödülleri** (coin ekle, ilk saati yönlendir) | `quest_catalog.gd`, `player_progress.gd` | **[VERİ]** | "Şimdi ne yapmalıyım" sorusunu cevaplayan tek sistem |
| 5 | **Garage Value + rütbe göstergesi** | yeni küçük hesap + HUD plakası + showroom kilidi | **[KOD]** düşük | İkinci ilerleme ekseni; 10 saat sonrasını taşıyan şey bu |

## 10. ŞU AN KESİNLİKLE DOKUNMAMAMIZ GEREKEN SİSTEMLER

| Sistem | Neden |
|---|---|
| **RepairManager state machine** (TRAFFIC→…→TRAFFIC) | Defalarca test edildi, kırılgan; yalnızca **veri** ve **sayı** girişleri değişsin |
| **TrafficManager / TrafficVehicle** | Waypoint, kavşak kilidi, bubble mantığı oturdu |
| **CloudSaveManager** | Firebase + plugin zinciri kırılgan; SaveManager'ın snapshot'ını kullanıyor, kendiliğinden taşır |
| **SaveManager formatı** | Yalnızca **alan ekle** + v7 migration; mevcut alanların anlamını değiştirme |
| **GarageSystem fiziksel genişleme + RepairBayManager iki aşamalı açılış** | Bu turda bitti ve doğrulandı |
| **Showroom 3D** | Yeni tasarlandı, performansı ölçüldü (158 FPS) |
| **Paint pipeline / CarRig / paint mask** | Asset boru hattına dokunmak = günler |
| **CarCatalog yapısı** | Yalnızca **yeni alan** ekle (`class`, `min_level`), şemayı bozma |
| **`repair_capacity` geliştirmesi** | Kaldırıldı; fiziksel genişlemenin yerine geri getirilmeyecek |

---

## 11. 10 AŞAMALI UYGULAMA ROADMAP

| Aşama | İçerik | Tür | Risk | Süre |
|---|---|---|---|---|
| **1** | **Ekonomi dengesi** — garaj/bay/araç fiyatları (NORMAL senaryo) | [VERİ] | Yok | Kısa |
| **2** | **Müşteri arzı garaj seviyesine bağlansın** + 2 yeni bekleme noktası + ödül sınıf çarpanı | [KOD] düşük | Düşük | Kısa |
| **3** | **Orta süreli işler** (3 yeni RepairType) + `min_level` gerçekten uygulansın | [VERİ] | Düşük | Kısa |
| **4** | **Seviye ödül tablosu** (coin + açılış bildirimi) | [VERİ+KOD] | Düşük | Kısa |
| **5** | **Görev zinciri yeniden yazımı** (ilk 60 dakika senaryosu, coin ödülleri) | [VERİ] | Yok | Orta |
| **6** | **Garage Value + 10 rütbe** (HUD plakası + merdiven modalı + showroom kilidi) | [KOD] | Düşük | Orta |
| **7** | **Daily reward** (7 günlük seri, save alanı) | [KOD] | Düşük | Kısa |
| **8** | **Job Mastery** (sayaç, yıldız, XP çarpanı, tek seferlik ödüller) | [KOD] | Orta | Orta |
| **9** | **Koleksiyonlar + araç satışı** (SAT plakasını canlandır) | [KOD] | Düşük | Orta |
| **10** | **Uzun işler (offline ilerleme) + idle dekor eşyaları** | [KOD] | **Yüksek** | Uzun |

**Sıra mantığı:** 1–5 arası neredeyse tamamen **veri** — oyunu oynanabilir yapan ve en çok
kazandıran kısım orası. 6–9 ilerleme derinliği. 10 en riskli olduğu için en sonda (kayıt şeması
ve zaman damgası işleri).

---

## 12. AÇIK SORULAR (karar bekliyor)

1. **Ekonomi senaryosu:** A / B / C hangisi? (öneri: **B**)
2. Garage Value eşikleri yukarıdaki gibi mi, yoksa tüm araçlar toplandığında 10. rütbeye
   ulaşılsın mı? (öneri: **ulaşılmasın** — dekor sistemi için yer kalsın)
3. Uzun işler gerçekten offline ilerlesin mi, yoksa yalnızca oyun açıkken mi? (offline = doğru
   his ama kayıt riski)
4. Araç satışı %40 mı? Boyalı araçta boya bedeli iade edilsin mi? (öneri: %40, iade yok)
5. `min_level` uygulanınca mevcut oyuncuların (kayıtlı oyunların) işleri kilitlenmesin —
   migration'da mevcut seviye korunuyor, sorun yok; onay yeterli.
