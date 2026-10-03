# ARAÇ KASASI — Araştırma

Tarih: 2026-09-29. Bu belge **yalnızca araştırmadır**; tasarım kararları
[vehicle_crate_design.md](vehicle_crate_design.md) içindedir. Kod yazılmadı.

Kaynak notu: Car Town 2014'te kapandı; birincil kaynak topluluk wikisidir (Fandom, MediaWiki API
üzerinden okundu). Diğer oyunlar için mümkün olduğunda resmî yardım sayfaları / geliştirici blogu
kullanıldı; topluluk kaynakları "topluluk" diye işaretlendi.

---

## 1. Orijinal Car Town — araç edinme

### 1.1 Doğrudan satın alma ana yoldu

- Araçlar **Buy Cars** menüsünden alınır. Çoğu araç **seviye** ya da **garaj değeri** ile
  kilitlidir. Premium para (**Blue Points**) ile bu kilit **atlanabilir**.
- Her aracın iki fiyatı vardır: altın (gold coin) ve blue point. Örnek: Acura Integra 1993 →
  22.000 altın / 7 BP, seviye 14, D sınıfı. Acura NSX Concept → yalnızca 120 BP, A sınıfı.
  Bazı araçlar hiç altınla satılmaz.
- Blue Points işle **kazanılmaz**. Kaynakları teklifler, reklam, "Game Show", bazen görevler.
  Bir dönem her seviye atlamada 1 BP verilirdi. Satış fiyatı 5 $ = 50 BP, 100 $ = 1.200 BP.
- Seviye tablosu her seviyede altın ödülü verir; yüksek seviye = daha çok iş + daha çok araç.

### 1.2 Car Town'da kasa VARDI: Mystery Box

Tasarım açısından en önemli bulgu budur. Car Town'da rastgele araç kutuları vardı:

| Kutu | Fiyat | Yeniden çevirme | İçerik |
|---|---|---|---|
| Bronze | 5 BP | 1 BP | çoğunlukla düşük seviye, nadiren performans aracı |
| Silver | 10 BP | 3 BP | Bronze'dan iyi |
| Gold | 25 BP | 5 BP | çoğunlukla yüksek performans |
| Lamborghini | 45 BP | 12 BP | yalnızca Lamborghini (kutuya özel araçlar dahil) |
| Ferrari | 100 BP | 20 BP | yalnızca Ferrari |
| Concept (sınırlı süre) | 15 BP | 4 BP | yalnızca konsept araçlar |

Ayrıca High Octane, Convertible, American Muscle, Adventure ve Diamond (liderlik tablosu ödülü)
kutuları vardı.

- Kutulardaki araçların **seviye kısıtı yoktu**. Kutu, seviye kilidini aşmanın bir yoluydu.
- **Tema** vardı: marka kutuları (Lamborghini, Ferrari) ve tür kutuları (Muscle, Convertible).
  Bazı araçlar yalnızca kutudan çıkıyordu.
- **Respin** (yeniden çevirme) ücretliydi: istemediğin sonucu küçük bir ücretle yeniden çekiyordun.
- Kutular yalnızca **premium parayla** alınıyordu. Oyun parası (altın) ile alınmıyordu.

### 1.3 Car Town'da koleksiyon setleri de vardı

Wikide 20'den fazla "Collection" sayfası var. Her set **4 araçtan** oluşur. Tamamlanınca
**altın + XP** verir:

| Set | Araçlar | Ödül |
|---|---|---|
| The Starter Collection | Fiat 500, Ford Pinto, Mustang GT 2005, Mini Cooper | 320 altın + 30 XP |
| Euro Commuters | Opel Corsa, Smart Fortwo, New Beetle, VW Rabbit | 3.400 + 340 XP |
| Work Horses | Silverado, F-150, Ram 1500, Tundra | 5.000 + 550 XP |
| Small but Mighty | S2000, Elise, MX-5, SLK | 8.000 + 800 XP |

Setler **temalıdır** (marka, tür, dönem, film) ve araç sınıflarını keser. Aynı araç birden çok
sette olabilir (ör. "Ford Power" ile başka bir set).

**Çıkarım:** Car Town'da üç katman birlikte çalışıyordu:
1. Doğrudan satın alma (ana yol, seviye/değer kilitli).
2. Premium kutu (kilit aşma + sürpriz + kutuya özel araç).
3. Temalı koleksiyon seti (tamamlama hedefi).

Kutu tek başına bir sistem değildi, doğrudan satın almanın **yanındaydı**.

## 2. CSR Racing 2 (Zynga)

- Resmî "Car Rarity Chances" sayfası: **kasa başına 1 araç**, 5★ %20 · 4★ %30 · 3★ %50. Bazı
  kasa türlerinde 5★ %10 · 4★ %30 · 3★ %60.
- Resmî "Drop Rates" bölümü kasa türlerine göre olasılık tabloları yayımlıyor. Parça kasaları
  3 eşya içerir; Stage 6 parça olasılığı %10.
- Topluluk kaynakları:
  - **Loyalty** sistemi: bir etkinlik penceresinde yeterince kasa açılırsa belirli bir araç
    garanti.
  - Tekrar çıkan araçlar "stripping" ile parçalarına ayrılıyor, yani tekrar bir kaynağa dönüşüyor.
- Eleştiri (topluluk): markaya ve modele kilitli parçalar yüzünden rastgele çekişler sürekli
  işe yaramayan tekrarlar veriyor.

**Çıkarım:** CSR2'de kasa, derin bir yükseltme ekonomisinin (parça, fusion, yıldız) girdisidir.
Bizde bu ekonomi yok ve Drag 2.0 tasarımı bilinçli olarak dışarıda bıraktı
([drag_racing_2_design.md](drag_racing_2_design.md) §I). CSR2'nin kasa modelini almak, olmayan
bir ekonomi için tekrar üretmek demektir.

## 3. Asphalt 9 / Legends Unite (Gameloft)

- Araçlar **blueprint** (kart) ile açılır. Yeterli blueprint → araç 1 yıldızda açılır; daha
  fazlası → yıldız atlatma.
- Blueprint türleri: Uncommon, Rare, Epic. Kaynaklar: kariyer, günlük etkinlikler
  (Daily Car Loot), 4 saatte bir ücretsiz paket, reklam paketleri, çok oyunculu kupa, kulüp,
  Legend Store (kredi ya da token ile).
- Örnek: Lamborghini Centenario (S sınıfı) için 40 blueprint, yani günlük etkinlikle yaklaşık
  40 gün.
- Paketten ne çıkacağını seçemezsin, bu yüzden birkaç aracı aynı anda yavaşça toplarsın.

**Çıkarım:** Blueprint, tekrar sorununu "tekrar = ilerleme" diye çözer. Ama bir aracın açılması
haftalar sürer. Bizim 16 araçlık, ~5 saatlik içeriğimiz için bu fazla uzun ve yapay olur.

## 4. Real Racing 3 (EA)

- Araçlar doğrudan alınır: R$ (oyun parası) ya da Gold (premium). Olasılık yok.
- Eleştiri (topluluk/blog): üst düzey araçlar ~500 gold iken bir etkinlik 30–70 gold veriyor.
  Premium paraya bağlı araçlar ücretsiz oyuncu için duvar oluşturuyor.

**Çıkarım:** Tamamen deterministik bir model de adaletsiz olabilir. Sorun rastgelelikte değil,
**kaynak/fiyat oranındadır**. Bu, bizim gem ekonomimiz için doğrudan uyarıdır (tasarım §15).

## 5. Forza Horizon (Wheelspin)

- Wheelspin'den araç çıkabilir. Tekrar çıkarsa oyuncu şunlardan birini seçer:
  - garaja ekler,
  - kredi karşılığı satar (topluluğa göre autoshow fiyatının yarısı),
  - "barn find" olarak başka oyuncuya hediye eder.
- Topluluk gözlemi: bir kategoride eksik araç varken tekrar çıkması **çok nadir**. Kategori
  tamamlanınca tekrarlar başlar.

**Çıkarım:** Kategori bazlı yumuşak tekrar koruması + tekrarın paraya dönüşmesi.

## 6. Top Drives (Hutch)

- Kart paketleri: Plastic → Steel → Aluminium → Ceramic → Carbon Fiber. Pahalı paket = nadir
  araç. Carbon Fiber ≈ 1.499 gold (~13 $).
- Paketler hem oyun parası hem premium parayla alınabilir. Ücretsiz oyuncu istemediği aracı
  satıp yeni paket alabilir.
- PocketGamer.biz analizi: kart azlığı nadiren sorun. Asıl baskı **garaj yeri** (21 → 160,
  premium ile genişletilir).

**Çıkarım:** Paket kademeleri = fiyat kademeleri. Tekrar/istenmeyen araç satılarak kaynağa döner.

## 7. Kart / koleksiyon oyunlarından tekrar ve garanti tasarımı

### Hearthstone (Blizzard)
- **Legendary pity:** en geç 40 pakette bir Legendary. Yeni bir setin **ilk 10 paketinde**
  Legendary garanti. Epic en geç 10 pakette.
- **Tekrar koruması:** o setin bütün Legendary'lerini almadan aynı Legendary'den ikinci kopya
  gelmez. Common/Rare/Epic'te her kartın 2 kopyası tamamlanmadan üçüncüsü gelmez.
  Parçalanan (disenchant) kart da "sahip olundu" sayılır.

### Marvel Snap (Second Dinner)
- 2025'te gelen **Snap Pack**: her pakette **1 sahip olunmayan kart garanti** (tekrar yok) ve
  oyuncunun seçtiği havuzdan 2 bonus ödül.
- Öncesinde "Spotlight Cache" sistemi tekrar üretiyordu ve eleştiriliyordu. Tekrarsız paket bu
  eleştiriye cevaptı.

### Clash Royale (Supercell)
- Sandık dizisi **önceden belirlenmiş** 240 sandıklık bir döngü (topluluk analizi).
- Supercell drop oranlarını arena bazlı tablolarla yayımlıyor. Bazı sandıklarda "en az N farklı
  kart" ve "Legendary garanti" var.

### Brawl Stars (Supercell) — karşı örnek
- Aralık 2022'de loot box'lar kaldırıldı, yerine deterministik **Starr Road** geldi.
  Gerekçe: "No more probabilities, no more random rewards".
- Deconstructor of Fun analizi: sonraki 5 ayda gelir %14 düştü; açma heyecanı kayboldu.
  Haziran 2023'te maçla kazanılan rastgele **Starr Drops** geri geldi. Analize göre asıl hata
  kavram değil, geçişin ani yapılmasıydı.

**Çıkarım:** Başarılı sistemler rastgeleliği **tamamen kaldırmıyor, sınırlıyor**:
- tekrar koruması (Hearthstone, Snap Pack, Forza),
- sert pity (Hearthstone 40 / 10),
- öngörülebilir dizi (Clash Royale),
- deterministik yol + küçük rastgele ödül (Brawl Stars'ın vardığı nokta).

## 8. Gacha terminolojisi ve düzenleme

- **Soft pity:** eşikten sonra olasılık kademeli artar. **Hard pity:** N çekişte kesin.
  **Spark:** her çekiş puan verir, puanla istenen öğe doğrudan alınır.
- **Japonya 2012:** "kompu gacha" yasaklandı. Rastgele ücretli öğelerden bir **seti tamamlayınca**
  ödül veren düzen. Bizim koleksiyon seti fikrimiz için doğrudan ilgili (tasarım §16).
- **Çin:** olasılıkların açıklanması zorunlu.
- **Belçika (2018):** ücretli loot box'lar kumar sayıldı, lisanssız sunulamaz. Hollanda da
  benzer tutum aldı.
- **ABD (2025):** HoYoverse, olasılıkları küçüklerden gizleme ve COPPA ihlali nedeniyle FTC ile
  20 M $'lık uzlaşma yaptı.
- **Google Play:** rastgele sanal öğe satan uygulamalar olasılıkları **satın almadan önce**
  açıklamak zorunda. Apple App Store'da 2017'den beri aynı kural var.
- **Birleşik Krallık (2023, Ukie ilkeleri):** 18 yaş altı için ebeveyn onayı olmadan ücretli loot
  box alınamamalı. Olasılıklar açıkça gösterilmeli.

**Çıkarım:** Bugün gemler gerçek parayla satılmıyor. Yine de sistem baştan "ücretli loot box"
kurallarına uygun tasarlanmalı: olasılıklar açık, tekrar koruması var, set ödülü rastgele ücretli
çekişe bağlı değil. Yarın gem satışı eklenirse mağaza politikası ve Belçika riski hemen devreye
girer.

## 9. Özet — araştırmadan tasarıma taşınanlar

| İlke | Kaynak |
|---|---|
| Kasa doğrudan satın almanın **yanında** durur, onu tamamen yok etmez | Car Town (Buy Cars + Mystery Box) |
| Kasa **temalı / kademeli** olur | Car Town kutuları, Top Drives paket kademeleri |
| Tekrar ya hiç gelmez ya da kaynağa dönüşür | Hearthstone, Snap Pack, Forza, Top Drives |
| En kötü durum **sınırlı ve açık** olmalı | Hearthstone pity, Clash Royale dizisi, CSR2 loyalty |
| Koleksiyon seti temalı, küçük (4 araç), ödül XP + kaynak | Car Town Collections |
| Olasılık açıklaması zorunlu | Google Play, Apple, UK ilkeleri, Çin |
| Set tamamlamayı rastgele ücretli çekişe bağlama | Japonya kompu gacha yasağı |
| Rastgeleliği tamamen kaldırmak heyecanı öldürebilir | Brawl Stars 2022–2023 |

---

## 10. Ek (v2, 2026-09-29) — kopya ekonomileri ve güncel düzenlemeler

Tasarım v2'de ([vehicle_crate_design_v2.md](vehicle_crate_design_v2.md)) tekrar koruması
kaldırıldı. Bu yüzden kopyanın başka oyunlarda neye dönüştüğü yeniden incelendi:

| Oyun | Kopya neye dönüşür | Etkisi |
|---|---|---|
| Hearthstone | Toz (dust). Tozla istenen kart üretilir | Kopya → hedefli edinme ("spark") |
| Asphalt 9 | Blueprint. Kopya = yıldız/yükseltme | Kopya → ilerleme; araç açmak haftalar sürer |
| Clash Royale | Kart seviyesi (güç) | Kopya → **güç**; pay-to-win eleştirisinin kaynağı |
| CSR2 | Araç parçalanır (stripping), parça çıkar | Kopya → yükseltme ekonomisi |
| Forza Horizon | Sat (krediye), garaja ekle ya da hediye et | Kopya → para |
| Top Drives | Satılır, yeni pakete yatırılır | Kopya → para |

Güncel düzenlemeler (v1'dekilere ek):
- **Güney Kore:** Oyun Endüstrisi Kanunu değişikliği 22 Mart 2024'te yürürlüğe girdi.
  - Yerli ve yabancı bütün oyunlar her öğenin olasılığını satın alma ekranında, web sitesinde ve
    reklamda göstermek zorunda. Anahtar/bilet gibi dolaylı alımlar da kapsamda.
  - Ceza: 20 M ₩'ye kadar para cezası ya da 2 yıla kadar hapis.
  - İlk aylarda 266 ihlal bulundu, %60'ı yabancı oyun.
- **Brezilya:** ECA Digital (Kanun 15.211/2025), 17 Mart 2026'da yürürlüğe girdi. "Çocuklara
  yönelik ya da onların erişebileceği" oyunlarda loot box'ı yaş derecelendirmesine göre yasaklıyor.
  Ceza 50 M R$'ye kadar. Kazanılan parayla açılan kutuların kapsama girip girmediği kaynaklarda
  net değil; **hukuki görüş gerekir**.
- **Hollanda:** Danıştay (Raad van State) 9 Mart 2022'de EA'nın FIFA paketlerini "kendi başına
  şans oyunu değil" saydı ve düzenleyicinin cezasını kaldırdı. Ülkede loot box'ları yasaklayan
  bir yasa girişimi sürüyor.

---

## Kaynaklar

Car Town
- Cars (Car Town Wiki) — https://cartown.fandom.com/wiki/Cars
- Blue Points — https://cartown.fandom.com/wiki/Blue_Points
- Mystery Box — https://cartown.fandom.com/wiki/Mystery_Box
- Level — https://cartown.fandom.com/wiki/Level
- Garage — https://cartown.fandom.com/wiki/Garage
- The Starter Collection — https://cartown.fandom.com/wiki/The_Starter_Collection
- Euro Commuters Collection — https://cartown.fandom.com/wiki/Euro_Commuters_Collection
- Work Horses Collection — https://cartown.fandom.com/wiki/Work_Horses_Collection
- Small but Mighty Collection — https://cartown.fandom.com/wiki/Small_but_Mighty_Collection
- Car Town (genel) — https://cartown.fandom.com/wiki/Car_Town

CSR Racing 2
- Car Rarity Chances (resmî) — https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/15556-car-rarity-chances/
- Drop Rates bölümü (resmî) — https://zyngasupport.helpshift.com/hc/en/55-csr-2/section/953-drop-rates/
- Parts Crate Drop Rates (resmî) — https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/12744-parts-crate-drop-rates-1607603441/
- Gold Crates / loyalty (topluluk) — https://csr2modding.com/blog/csr2-gold-crates

Asphalt
- Blueprint (Asphalt Wiki) — https://asphalt.fandom.com/wiki/Blueprint
- BlueStacks rehberi — https://www.bluestacks.com/blog/game-guides/asphalt-9-legend-2018-new-concept-arcade-racing-game/asphalt9-cars-guide-en.html

Real Racing 3
- Wikipedia — https://en.wikipedia.org/wiki/Real_Racing_3
- "The ridiculous economics of Real Racing 3" — https://robservatory.com/the-ridiculous-economics-of-real-racing-3/

Forza Horizon
- Wheelspin tekrarları (Steam topluluğu) — https://steamcommunity.com/app/1551360/discussions/0/3193611175967370738/
- Forza forumu — https://forums.forza.net/t/no-duplicate-wheelspin-cars/79585

Top Drives
- PocketGamer.biz IAP Inspector — https://www.pocketgamer.biz/the-iap-inspector/66611/how-does-top-drives-monetise/
- Packs (wiki) — https://top-drives.fandom.com/wiki/Packs

Kart / koleksiyon
- Hearthstone Card pack — https://hearthstone.wiki.gg/wiki/Card_pack
- Hearthstone Card pack statistics — https://hearthstone.fandom.com/wiki/Card_pack_statistics
- Clash Royale drop oranları (Supercell) — https://supercell.com/en/games/clashroyale/blog/news/clash-royale-chest-info-2/
- Clash Royale chest cycle — https://mobi.gg/en/tips/clash-royale-chest-cycle/
- Marvel Snap Snap Packs — https://cardgamer.com/games/digital-card-games/marvel-snap/marvel-snap-do-snap-packs-fix-card-acquisition-woes/
- Brawl Stars loot box kaldırma — https://www.gamedeveloper.com/business/supercell-pulls-loot-boxes-from-brawl-stars-in-favor-of-deterministic-rewards-
- Deconstructor of Fun analizi — https://www.deconstructoroffun.com/blog/why-removing-loot-boxes-in-brawlstars-failed

Düzenleme
- Gacha game (Wikipedia) — https://en.wikipedia.org/wiki/Gacha_game
- Google Play olasılık zorunluluğu — https://www.gamedeveloper.com/business/games-on-the-google-play-store-now-required-to-disclose-loot-box-odds
- Fenwick özeti — https://www.fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds
- Belçika Oyun Komisyonu raporu — https://www.mygamecounsel.com/2018/05/articles/gambling/belgium-gaming-commission-loot-box-report/
- Ukie loot box ilkeleri — https://ukie.org.uk/news/new-loot-box-principles-agreed-by-industry
- Güney Kore olasılık yasası — https://gameworldobserver.com/2023/02/28/south-korea-loot-boxes-probability-disclosure-law
- Güney Kore uygulama/ihlaller — https://gameworldobserver.com/2024/07/08/266-games-violated-loot-box-rules-south-korea
- Brezilya ECA Digital (PC Gamer) — https://www.pcgamer.com/gaming-industry/brazils-president-has-signed-a-ban-on-selling-loot-boxes-to-minors-as-part-of-a-larger-online-child-safety-law/
- ECA Digital yürürlük — https://igamingbrazil.com/en/legislation-en/2026/03/17/eca-digital-comes-into-force-with-rules-for-betting-games-and-protection-of-minors-in-the-online-environment/
- Hollanda Danıştay kararı — https://mediawrites.twobirds.com/post/102j3d2/fifa-22-loot-boxes-no-longer-regarded-as-gambling-in-the-netherlands-as-ban-overt
