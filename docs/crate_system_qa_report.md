# KASA SİSTEMİ — Entegrasyon ve Gerçek Oyun QA Raporu

Tarih: 2026-09-29.
- Önceki belgeler: [vehicle_crate_implementation_report.md](vehicle_crate_implementation_report.md), [vehicle_crate_design_v2.md](vehicle_crate_design_v2.md).
- Yeni özellik eklenmedi. Mevcut kasa sistemi gerçek oyun akışında oynandı; bulunan hatalar düzeltilip yeniden test edildi.

## 0. Nasıl test edildi — kod incelemesi değil, oyun

Oyunun kendisi (gerçek `Main.tscn`, pencereli 1170 × 540, telefon oranı) otomatik bir oyuncuyla oynandı. Otomatik oyuncu şunları yaptı:
- müşteri aldı, tamir etti, parayı topladı,
- görev ödüllerini görev panosundaki butonla aldı,
- **kasaya gerçek fare tıklaması ve gerçek dokunmatik olayı** gönderdi (fizik seçimi, diğer dünya nesneleriyle çakışma ve düzenleme modu gerçekten sınandı),
- showroom, garaj ve koleksiyon ekranlarını kendi butonlarıyla kullandı.

Her adımda ekran görüntüsü alındı ve incelendi.

| Betik | Ne yapar | Sonuç |
|---|---|---|
| `qa/crate_playthrough.gd -- play` | Yeni kayıt → Şahin → tamir → sv 2 → İLK KASA → garaja gelen kasaya tıkla → AÇ → araç → koleksiyon → yarış aracı seç → rakip → showroom (yetersiz gem, çift dokunuş, 4 kasa, garaj dolu) → düzenleme modu → dokunmatik → kopya → Legendary → sat → geri al → açılmamış kasalarla **kapat** | 47 / 0 |
| `qa/crate_playthrough.gd -- resume` | **Ayrı süreç**, uygulama yeniden açılmış gibi: gem, koleksiyon, yarış aracı, yıldız, 3 kasanın konumu ve içeriği aynı mı; açılınca kapanmadan önce belirlenen araç mı; açılmış kasa ikinci kez açılıyor mu | 10 / 0 |
| `qa/crate_vehicle_check.gd` | 16 aracın her biri kasadan gerçekten çıkarılır: ölçek, tekerlek–zemin teması, gövde gömülmesi, kasa ekseniyle hizalama, sonuç plakası = katalog; yakın plan görüntü | 80 / 0 |
| `tests/crate_test.gd` | Kayıt güvenliği, kopya, keşif, geri alma, yarış, göç, gem ödülleri (haftalık, ustalık, tamir taşları dahil), saat istismarı, oran istatistiği | 96 / 0 |
| Tam paket `tools/run_tests.sh` | 15 paket | 1.180 / 0 |

Görüntüler:
- `/home/burak/Projects/ct_shots/crate/play/` — oyuncu akışı,
- `…/crate/vehicles/` — 16 araç,
- `…/crate/` — genel.

## 1. Bulunan ve düzeltilen hatalar (bu QA turu)

| # | Önem | Hata (nasıl bulundu) | Düzeltme | Doğrulama |
|---|---|---|---|---|
| 1 | P1 | **Çıkan araç tabelanın arkasında kalıyordu.** Garajın havada asılı "GARAJI GENİŞLET" tabelası, kasadan girişe doğru çıkan aracın tam önüne biniyordu; açılışın en önemli anında araç yarı görünüyordu. *16 araç yakın plan görüntüleri.* | Açılış sahnesi boyunca tabela gizlenir, sonra geri gelir (düzenleyicinin kullandığı `set_sign_hidden`). | 16 araç görüntüsü yeniden alındı |
| 2 | P1 | **"Yolda" kasa hiç gelmiyordu.** Garaj doluyken alınan kasa, başka bir kasa açılıp yer boşalınca da teslim edilmiyordu. Sebep: `finish_reveal`, dekor görünümünün engel listesini `claim`'den sonra tazeliyordu. Yeniden teslimat denemesi eski kasanın izini hâlâ dolu görüyordu. *Oyuncu testi, uid 5 PURCHASED'da kaldı.* | Önce engeller tazelenir, sonra `claim`. | Oyuncu testi: "yer boşalınca garaja geldi (durum 2)" |
| 3 | P1 | **Görünmeyen kasalara gem harcanabiliyordu.** Seviye 1 garaja 3 kasa sığıyor ama 6 kasa alınabiliyordu; fazlası görünmeden "yolda" bekliyordu. *Oyuncu testi, 8. bölüm.* | Yolda kasa varken yeni satın alma engellenir; showroom "ÖNCE GARAJDAKİ KASALARI AÇ" der. | Oyuncu testi: PRESTİJ engellendi, gem düşmedi |
| 4 | P1 | **Eski kayda geriye dönük gem ve bedava kasa gidiyordu.** v9 kaydı açılınca geçmiş tamir kilometre taşları (69 tamir → +10, 320 tamir → +30) ve mevcut koleksiyonun taşları bir kez ödeniyor, İLK KASA görevi bedava kasa veriyordu. *Brif §21'e göre kod incelemesi.* | Göç: İLK KASA alınmış sayılır; geçilmiş tamir ve koleksiyon taşları ödenmiş işaretlenir. Yalnızca günün giriş ödülü gelir. | crate_test §13, save_test, quest_test |
| 5 | P2 | **Showroom'da çift dokunuş iki kasa alabiliyordu.** Kapanış animasyonu sırasında ikinci basış da işleniyordu. | Satın alınca buton kilitlenir; kapanırken ya da görünmezken basış yok sayılır. | Oyuncu testi: aynı karede 2 + animasyonda 1 basış → tek kasa |
| 6 | P2 | **Çift TAMAM** kapanış animasyonunu ve kamera dönüşünü iki kez başlatıyordu. | `finish_reveal` tek sefer. | Oyuncu testi |
| 7 | P2 | **İlk kasa görev panosunun arkasına iniyordu.** İLK KASA ödülü görev panosu açıkken alınıyor, kasa panonun arkasında garaja iniyor, kamera gitmiyordu; oyuncu kasanın geldiğini anlamıyordu. | Görev ödülü kasada pano kapanır, kamera kasaya gider, "İLK ARAÇ KASAN GARAJINA GELDİ — KASAYA DOKUN VE AÇ" bildirimi çıkar. | Oyuncu testi 3. bölüm, görüntü 03 |
| 8 | P2 | **Gem–kasa ilişkisi anlatılmıyordu.** | Görev zincirine **KASA SİPARİŞİ** eklendi ("MAĞAZA'dan gemle bir araç kasası sipariş et", ödül yalnızca XP). Gem yetmediğinde kasa plakasında "GEM: GÜNLÜK GİRİŞ · GÖREVLER · SEVİYE · USTALIK" yazar. | quest_test, görüntü 07 |
| 9 | P3 | **Yanlış yönlendiren uyarı.** "Garajda yer yok" uyarısı dekorsuz garajda da "dekoru kaldır" diyordu. | Dekor yoksa "ÖNCE GARAJDAKİ BİR KASAYI AÇ". | Görüntü 08 |
| 10 | P3 | **Showroom oran satırları kırılıyordu** (dar plaka). | Plaka 210 → 250 px, yüzde başta. | ui_test |
| 11 | — | **Simülasyon sabitleri oyunla sessizce ayrışabilirdi.** | `crate_sim.py` artık oyunun `.gd` dosyalarından 16 sabiti okuyup karşılaştırıyor; farklıysa durur. | 16 / 16 aynı |
| 12 | — | **₺ simülasyonunun otomatik oyuncusu** garaj yatırımı için biriktirmiyordu (30. dakikada garaj hâlâ 1, 14.800 ₺ dekora gitmişti). | Dekor ancak sıradaki yatırımın parası ayrıldıktan sonra alınır. | §9 |

Test aracının kendi hatası: oyuncu testinin ilk koşusunda kasaya tıklama "çalışmıyordu". Sebep enjeksiyondu, oyun değil. Görüntü alanı 1404 × 648, pencere 1170 × 540 (canvas_items ölçeği); izdüşüm koordinatı pencereye çevrilmemişti. Aynı yöntemle oyuncuların telefonda kullandığı "GARAJI GENİŞLET" tabelası da "tıklanamıyordu", bu da hatanın testte olduğunu doğruladı. Düzeltilince ikisi de çalıştı (`qa/pick_probe.gd`).

## 2. Oynanan akış — gözlemler

Yeni kayıt, 1170 × 540 pencere, gerçek girdi.

| Adım | Gözlem | Sonuç |
|---|---|---|
| Başlangıç | Tek araç **Tofaş Şahin**, yarış aracı Şahin, 5.000 ₺, 50 gem (40 + ilk gün giriş). Görev panosunda İLK KASA ("+1 ŞEHİR KASASI"), İLK MÜŞTERİ, ÇIRAK. Günlük görevler plakası "SEVİYE 3'TE AÇILIR" (görüntü 01) | ✔ |
| Showroom | Doğrudan araç satışı yok. Sol listede 4 kasa, platformda kasa, sağda her aracın yüzdesi ve nadirliği. Keşfedilmemiş araç satışı ya da plakası yok (görüntü 02) | ✔ |
| Tamir → seviye 2 | 5 tamirde seviye 2, seviye gemi +5 (50 → 55), görev "İLK KASA" tamamlandı | ✔ |
| İLK KASA | Ödül alınınca görev panosu kapandı, kamera garaja döndü, büyük kasa arka-sol köşeye indi, "İLK ARAÇ KASAN GARAJINA GELDİ" bildirimi (görüntü 03) | ✔ (düzeltme #7) |
| Kasaya tıkla | Gerçek fare tıklaması: AÇ plakası açıldı. Başlık yalnızca "ŞEHİR KASASI", içerik gizli, nadirlik yüzdeleri görünür | ✔ |
| AÇ | Kayışlar düşer → kapak kalkıp yana kayar → paneller dışa yatar → araç kasanın devrilmiş ön panelinden yavaşça iner, zemine oturur. Nadirlik renginde ışık, kamera kasaya odaklı, sonuç plakası ekranın alt yarısında, araç üst yarıda (görüntü 04) | ✔ |
| Sonuç | "HYUNDAI ACCENT BLUE · COMMON · C SINIFI · YENİ! KOLEKSİYONA EKLENDİ · +3 GEM". Garaj değeri +38.000 ₺. TAMAM → araç ve boş kasa küçülerek kalkar, kamera geri döner | ✔ |
| Koleksiyon | "KOLEKSİYON 2 / 16"; Şahin ve Accent kartlı, diğerleri siyah siluet + nadirlik çerçevesi + "ŞEHİR · %33,9" (görüntü 05) | ✔ |
| Yarış | Garajda YARIŞ ARACI YAP → yarış daveti "SENİN ARACIN FORD FOCUS · C SINIFI"; rakipler C ya da B (görüntü 06b) | ✔ |
| Gem yetmez | 20 gemde ŞEHİR: buton "30 GEM · GEM YETERSİZ", plakada gemin nereden kazanıldığı yazıyor (görüntü 07) | ✔ (düzeltme #8) |
| Satın alma | 100 gemde aynı kare 2 + kapanışta 1 basış → tek kasa, gem 100 → 70, showroom kapandı, kamera teslimat noktasına gitti | ✔ (düzeltme #5) |
| 4 kasa türü | ŞEHİR −30, AİLE −50, SPOR −80 gem; garaj doluyken PRESTİJ engellendi, gem düşmedi | ✔ (düzeltme #3) |
| Düzenleme modu | Kasalar görünür, altları "yasak" ızgarayla işaretli, etiketleri gizli. Kasaya tıklama AÇ plakası açmıyor, dekor sayısı 0 (görüntü 09) | ✔ |
| Dokunmatik | `InputEventScreenTouch` kasayı seçti | ✔ |
| Kopya | "KOPYA ★☆☆☆☆ · ARAÇ YILDIZI İLERLEDİ · +2 GEM". Araç / keşif sayısı ve garaj değeri değişmedi (görüntü 11) | ✔ |
| Legendary | BMW E60: altın ışık daha güçlü ve geniş, sonuç plakası altın nabızla parlıyor; slot makinesi efekti yok (görüntü 12) | ✔ |
| Sat / geri al | E60 satıldı → koleksiyonda "SATILDI · SHOWROOM'DA GERİ AL" (görüntü 13) → showroom GERİ AL listesinde → ₺ ile geri alındı (görüntü 13b) | ✔ |
| Kapat / aç | Ayrı süreç: gem, koleksiyon, yarış aracı, yıldız ve 3 kasanın yeri + içeriği aynı. Açılan kasadan kapanmadan önce kaydedilmiş araç (Volvo S60) çıktı; açılmış kasa ikinci kez açılamadı (görüntü 15, 16) | ✔ |

İlk 15 dakikada oyuncunun anlaması gerekenler:
- **İlk araç Şahin** → garaj ve yarışta Şahin.
- **Gem** → ilk girişte "GÜNLÜK GİRİŞ +10 GEM", seviye bildiriminde "+5 GEM", gem yetmezken showroom kaynağını yazıyor.
- **Kasa ve yeri** → İLK KASA görevi "ilk araç kasan garajına gelsin" diyor; ödülde kamera kasaya gidiyor.
- **Açma** → kasanın üstündeki tabela "DOKUN · AÇ".
- **Koleksiyon** → sonuç plakası "KOLEKSİYONA EKLENDİ", KOLEKSİYON plakası showroom ve garajda.
- **Satın alma** → görev zincirindeki KASA SİPARİŞİ gemle kasa almayı öğretiyor.

Ayrı bir tutorial sistemi kurulmadı; mevcut görev zinciri kullanıldı.

## 3. 16 araç — kasadan çıkış

`qa/crate_vehicle_check.gd`. Her araç normal açılış akışıyla kasadan çıkarıldı.

| Araç | Kasa | Nadirlik | Ölçek (= trafik 0,6 × model) | Tekerlek alt − zemin | Gövde alt − zemin | Hizalı | Plaka = katalog |
|---|---|---|---|---|---|---|---|
| BMW E46 | SPOR | Legendary | 0,611 | −0,0000 | −0,0000 | ✔ | ✔ |
| Hyundai Getz | ŞEHİR | Common | 0,523 | +0,0001 | +0,0001 | ✔ | ✔ |
| Renault Fluence | AİLE | Common | 0,631 | +0,0000 | +0,0000 | ✔ | ✔ |
| VW Passat B5.5 | AİLE | Common | 0,643 | +0,0000 | +0,0000 | ✔ | ✔ |
| Hyundai Era | ŞEHİR | Rare | 0,585 | +0,0000 | +0,0000 | ✔ | ✔ |
| Tofaş Şahin | (başlangıç) | Common | 0,590 | +0,0000 | +0,0000 | ✔ | ✔ |
| Renault Toros | ŞEHİR | Epic | 0,590 | +0,0000 | +0,0000 | ✔ | ✔ |
| Hyundai Accent Blue | ŞEHİR | Common | 0,597 | +0,0000 | +0,0000 | ✔ | ✔ |
| Ford Focus | ŞEHİR | Rare | 0,596 | +0,0000 | +0,0000 | ✔ | ✔ |
| Skoda Kamiq | AİLE | Rare | 0,580 | −0,0000 | −0,0000 | ✔ | ✔ |
| VW Golf 7 | AİLE | Epic | 0,582 | +0,0000 | +0,0000 | ✔ | ✔ |
| Seat Leon | SPOR | Common | 0,584 | +0,0000 | +0,0000 | ✔ | ✔ |
| Honda Civic | SPOR | Epic | 0,606 | −0,0000 | −0,0000 | ✔ | ✔ |
| Audi A3 | PRESTİJ | Common | 0,589 | +0,0000 | +0,0000 | ✔ | ✔ |
| Volvo S60 | PRESTİJ | Rare | 0,633 | +0,0001 | +0,0001 | ✔ | ✔ |
| BMW E60 | PRESTİJ | Legendary | 0,662 | +0,0001 | +0,0001 | ✔ | ✔ |

- Tolerans ±4 mm (araç boyu ~0,6 birim). En büyük sapma 0,1 mm.
- Model ve renk: her araç katalogdaki `scene_path` ile ve oyuncunun `CarAppearance`'ıyla kuruldu (boyalıysa boyasıyla).
- Yakın planlarda Şahin ve Toros tekerlekleri zemine oturuyor. Audi A3'te çamurluk ya da tekerlek taşması yok.

## 4. Kayıt ve kalıcılık

| Senaryo | Test | Sonuç |
|---|---|---|
| A) Kasa al → kapat → aç: kasa duruyor | playthrough resume (ayrı süreç), crate_test §7 | ✔ |
| B) Kasa al → sonuç belirlenir → kaydet → kapat → aç: sonuç aynı | crate_test §4 (gem ve kasa aynı yazımda diskte), §7 (3 yeniden açılış) | ✔ |
| C) Kasa al → kapat → aç → aç: aynı araç | playthrough resume ("volvo_s60" kapanmadan önce kaydedilmişti, o çıktı) | ✔ |
| D) Açılmış kasayı tekrar aç | playthrough resume, crate_test §8 ("açılırken ikinci kez açılamaz") | ✔ |
| Açılış sırasında uygulama kapanır | crate_test §9 (REVEALED yüklemede ödülsüz kapanır, araç bir kez) | ✔ |
| Bulut geri yükleme | crate_test §7 (`apply_snapshot` sonucu değiştirmez); cloud_test | ✔ |
| Sahne yeniden yükleme | crate_test (her bölüm sahneyi baştan kurar) | ✔ |
| Birden çok kasa | Oyuncu testi: 3 kasa dünyada, 1 yolda. Her biri ayrı uid, ayrı sonuç, ayrı konum. Birini açmak diğerlerini bozmuyor; kapat-aç sonrası hepsi yerinde | ✔ |
| Kayıt sürümü | v10. v9 ve öncesi: sahiplik korunur, sahip olunanlar keşfedilmiş sayılır, bekleyen kasa yok, bedava İLK KASA yok, geriye dönük gem yok (yalnızca günün girişi) | ✔ (düzeltme #4) |

## 5. Kopya

Test için sonuç sahip olunan araca sabitlendi (`CrateManager._find(uid)["vehicle"]`, yalnızca testte).

- Kopya **yeni araç sayılmıyor:** sahiplik, keşif sayısı ve koleksiyon "n / 16" değişmiyor.
- **Garaj değeri iki kez artmıyor.** Sahiplik bir küme, kopya satılabilir ikinci araç üretmiyor.
- **Yıldız:** 1 / 3 / 6 / 10 / 15 kopyada ★1–5. Getz × 3 senaryosunda ilki yeni, sonraki ikisi kopya: ★1 (2. kopyada ★1 kalır, 3.'de ★2).
- **Gem hurdası:** Common 2 · Rare 5 · Epic 12 · Legendary 30. Kopya plakası "KOPYA ★☆☆☆☆ · +2 GEM".
- Satılmış bir araç tekrar çıkarsa kopya değil, "GARAJINA GERİ DÖNDÜ"; keşif gemi verilmiyor.

## 6. Nadirlik — ekrandaki oran = koddaki oran

- Showroom plakası, kasa AÇ plakası ve koleksiyon kartları aynı fonksiyondan okur: `CrateCatalog.odds`.
- Çekilişi yapan `CrateCatalog.roll` da aynı tabloyu kullanır; ayrı bir oran kaynağı yok.
- crate_test §15: kasa başına 200.000 çekiliş; gözlenen ile ilan edilen arasındaki en büyük sapma 1,74 σ (sınır 4,5 σ).

| Kasa | Common | Rare | Epic | Legendary |
|---|---|---|---|---|
| ŞEHİR | %67,8 (Getz, Accent) | %27,1 (Era, Focus) | %5,1 (Toros) | — |
| AİLE | %78,4 (Passat, Fluence) | %15,7 (Kamiq) | %5,9 (Golf 7) | — |
| SPOR | %84,0 (Leon) | — | %12,6 (Civic) | %3,4 (E46) |
| PRESTİJ | %69,4 (A3) | %27,8 (S60) | — | %2,8 (E60) |

Nadirlik yapısı brifle aynı: ŞEHİR ve AİLE Common/Rare/Epic, SPOR Common/Epic/Legendary, PRESTİJ Common/Rare/Legendary.

## 7. Yarış

- `RaceManager.player_vehicle_id()` artık seçili yarış aracını döndürüyor (önceki hata: sahip olunan ilk araç, yani ilk dakikadan E46).
- Yeni oyunda Şahin; garaj ekranında YARIŞ ARACI YAP ile sahip olunan başka bir araç seçiliyor.
- Sahip olunmayan araç seçilemiyor. Seçili araç satılırsa Şahin'e düşülüyor.
- Rakip havuzu oyuncunun sınıfı + bir üstü; 20 örnekte hepsi C ya da B (C sınıfı araçla).
- D → C → B → A: başlangıç D (Şahin); kasa kapıları A sınıfını en erken seviye 14'e (E46 %3,4) ve seviye 20'ye (PRESTİJ) koyuyor.
- Testler: race_test, crate_test §12, oyuncu testi 6. bölüm.

## 8. Garaj değeri ve koleksiyon

- **Yeni keşif** → garaj değerine katalog fiyatı eklenir (oyuncu testi: Accent +38.000).
- **Kopya** → eklenmez.
- **Satış** → araç sahiplikten çıkar, değeri düşer; araç keşfedilmiş kalır. Tasarım: değer "garajında olan" araçların toplamı.
- Koleksiyon sayacı "sahip olunan" değil **keşfedilen** araçlar: satılan E60 "SATILDI · SHOWROOM'DA GERİ AL" olarak kalır ve 16'da n'e dahildir.
- Hiç görülmeyenler siyah siluet + "???" + nadirlik çerçevesi + kasa ve yüzde.
- **DISCOVERED ≠ CURRENTLY OWNED** ayrımı doğrulandı:
  - `is_discovered` ≠ `is_owned`,
  - showroom yalnızca keşfedilmiş ama sahip olunmayanı satar,
  - kopya yalnızca sahip olunan araçta sayılır.

## 9. Gem ekonomisi — oyunda gerçekten çalışıyor mu

| Kaynak | Miktar | Zaman / periyot | Doğrulama |
|---|---|---|---|
| Seviye | 5, her 5.'de +25 | her seviye atlamada bir kez | Oyuncu testi (sv 2: 50 → 55); seviye bildirimi "+5 GEM" |
| 7 günlük giriş | 10·10·15·10·15·10·40 | günde bir | crate_test §14: 1. gün +10, aynı gün yok, 2. gün +10 (seri 2), yeniden açılışta tekrar yok (resume) |
| Günlük görev | 3 × 10 + üçü +20 | gün başına bir kez | crate_test §14: +10, ikinci kez yok, bonus bir kez |
| Haftalık hedef | 12 görev → 100 | hafta başına bir kez | crate_test §14 |
| Ustalık yıldızı | 10 | yıldız başına | crate_test §14 |
| Tamir kilometre taşları | 50/250/1.000/2.500/5.000 → 10/20/30/50/75 | bir kez | crate_test §14 (+30, ikinci kez yok); eski kayıtta geriye dönük yok (§13) |
| Bahşiş | 20 tamirde 1 | günde en çok 40 | crate_test §14 (tavan 40 / 40) |
| İlk keşif | C 3 · R 8 · E 20 · L 40 | araç başına bir kez | Oyuncu testi (Accent +3); 16 araç kontrolü (Toros +20, E60 +40) |
| Koleksiyon kilometre taşı | 5/10/14/16 → 15/30/50/100 | bir kez | 16 araç kontrolü (5., 10., 14., 16. keşiflerde; E60 = 16. → +40 + 100 = 140) |
| Kopya hurdası | C 2 · R 5 · E 12 · L 30 | kopya başına | Oyuncu testi (+2), crate_test §10 |

### 9.1 Gem istismarı denemeleri

| Deneme | Sonuç |
|---|---|
| Aynı gün kapat / aç (ayrı süreç) | Giriş ödülü tekrar gelmedi (resume: gem 45 = 45) |
| Sahne yeniden yükleme (crate_test her bölümde) | Tekrar yok |
| Çift / üçlü dokunuş (showroom, AÇ, TAMAM) | Tek işlem (düzeltme #5, #6) |
| Görev ödülünü tekrar alma | `claim` reddeder; kayıttan sonra da (crate_test §3) |
| Saati geri almak | Ödül yok, görevler sıfırlanmaz, tespit edilir (crate_test §14) |
| Saati ileri almak | Yalnızca o günün girişi, seri 1'e döner; gerçek güne dönünce kilit (crate_test §14) |
| Bulut / eski kayda dönmek | Ödül işaretleri gemle aynı dosyada: eski kayda dönen gemi de geri verir; kasa sonucu değişmez (crate_test §7) |
| Açılış sırasında uygulamayı öldürmek | Ödül bir kez (crate_test §9) |
| Sat → aynı aracı kasadan tekrar çek | Kopya değil "geri döndü", keşif gemi yok; gem → ₺ dönüşümü (sat %40) çok kötü takas |
| Yeni oyun başlatıp giriş gemi almak | Yeni oyun gemleri 40'a sıfırlar, +10 giriş = temiz başlangıçla aynı |

Bilinen sınır (P3): cihaz saatini **her gün** bir gün ileri alan oyuncu, geri dönene kadar fazladan giriş gemi toplayabilir; dönünce o günler kilitlenir. Sunucu saati yok.

## 10. Ekonomi

### 10.1 100.000 oyunculuk simülasyon (yeniden koşuldu)

`python3 tools/economy/crate_sim.py all --players 100000`:
- oyunun gerçek `cars.json` / `crates.json` verisini okur;
- **yeni:** oyunun `.gd` dosyalarından 16 gem sabitini okuyup kendi sabitleriyle karşılaştırır. Hepsi aynı; farklı olsa çalışmayı durdurur.

Sonuç önceki raporla **birebir aynı**: veri, sabitler ve tohum değişmedi, bu beklenen durum. Büyük fark yok.

| Profil (30. gün) | Kazanılan gem | Açılan kasa | Araç medyanı | Kopya | E46 | E60 | 16/16 |
|---|---|---|---|---|---|---|---|
| CASUAL 20 dk | 2.580 | 46,9 | 14 | 34,3 | %30,0 | %11,5 | %3,0 |
| ACTIVE 60 dk | 4.044 | 65,4 | 15 | 51,8 | %54,7 | %20,4 | %14,7 |
| HEAVY 150 dk | 4.662 | 71,3 | 15 | 57,5 | %63,7 | %25,8 | %21,2 |

Nadirlik dağılımı (ACTIVE, 30 gün, kopya): Common 43,2 · Rare 7,0 · Epic 1,6 · Legendary 0,06.

Açılan kasa sayısına göre (tüm kasalar açık):

| Kasa | Medyan araç | E60 | E46 | 16/16 |
|---|---|---|---|---|
| 10 | 8 | %1,2 | %3,5 | %0 |
| 25 | 12 | %7,8 | %10,9 | %0,1 |
| 50 | 14 | %15,3 | %36,0 | %7,2 |
| 100 | 16 | %52,5 | %79,8 | %50,2 |
| 200 | 16 | %94,3 | %99,1 | %94,2 |

### 10.2 ₺ ekonomisi — gerçek oyun, 600 dakika

`qa/sim_progress.gd -- 600`: gerçek `Main.tscn`, 12 kat hız, otomatik oyuncu.
- ₺ harcama sırası: tamir alanı > garaj seviyesi > tamir hızı > dekor. Dekor ancak sıradaki yatırımın parası ayrıldıktan sonra alınır.
- Gem en verimli kasaya gider.
- Takvim günü değişmediği için giriş ve günlük görev gemi **gelmez**; tek günde 10 saat oynayan oyuncu gibidir.

| dk | Bakiye | Tamir kazancı | Alan | Garaj | Hız | Dekor | Sv | Garaj sv | Alan | Eşya | Araç | Garaj değeri | Rütbe | Kasa |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 784 | 7.284 | 0 | 0 | 11.500 | 0 | 3 | 1 | 1 | 0 | 3 | 94.500 | 1 | 2 |
| 30 | 6.383 | 29.883 | 5.000 | 12.000 | 11.500 | 0 | 7 | 2 | 2 | 0 | 4 | 146.500 | 2 | 6 |
| 60 | 38.342 | 103.842 | 17.000 | 42.000 | 11.500 | 0 | 11 | 3 | 3 | 0 | 6 | 283.500 | 5 | 10 |
| 120 | 6.567 | 320.867 | 17.000 | 102.000 | 11.500 | 188.800 | 16 | 4 | 3 | 34 | 7 | 439.020 | 8 | 14 |
| 300 | 11.937 | 944.237 | 17.000 | 102.000 | 11.500 | 806.800 | 21 | 4 | 3 | 61 | 8 | 746.220 | 10 | 18 |
| 600 | 138.156 | 2.023.456 | 17.000 | 102.000 | 11.500 | 1.759.800 | 25 | 4 | 3 | 74 | 8 | 1.127.420 | 10 | 20 |

**Önceki sistemle karşılaştırma** (AUDIT §6, araçlar ₺ ile):

| | Eski (araç ₺) | Yeni (kasa gem) |
|---|---|---|
| 10 saatte kazanç | 2,10 M | 2,02 M (yalnızca tamir) |
| Araç harcaması | 873 k | 0 |
| Dekor harcaması | yoktu | 1,76 M (74 eşyanın tamamı) |
| 10. saatte harcanamayan para | **1,10 M** | **138 k** |
| Garaj 2 / 3 / 4 | 23 / 75 dk / … | 20–30 / 30–60 / 60–120 dk |

- **Ekonomiyi dekor, garaj ve alanlar taşıyor:** araç harcamasının kalkması parasızlık da para yığılması da yaratmıyor.
- Garaj geliştirmeleri **daha erken** geliyor. Para araçlara gitmediği için 4. garaj seviyesi 2. saatte alınıyor.
- **İlk koşuda yanlış sonuç çıktı** (garaj 2 → 300. dakika). Sebep otomatik oyuncuydu: `can_buy()` "parası yetiyor mu"yu da sorduğu için sıradaki yatırımın parası kenara ayrılmıyordu. Düzeltilip yeniden koşuldu; oyun hatası değil.
- **Açık:** dekor kataloğu 10. saat civarında tükeniyor. Sonrası için ₺ harcama yeri yok (P2, eski sistemde de 5. saatte tükeniyordu).

## 11. Performans

`qa/crate_perf.gd`, 1152 × 648. Seviye 4 garaj, 6 kasa. Masaüstünde dikey senkron kapanmadığı için FPS 60 tavanında; asıl ölçü "en uzun kare" ve çizim çağrısı.

| Durum | FPS | En uzun kare | Çizim çağrısı | VRAM |
|---|---|---|---|---|
| Kasasız | 60 | 22,3 ms | 287 | 84,2 MB |
| 2 kasa | 60 | 20,3 ms | 410* | 84,3 MB |
| 6 kasa | 60 | 18,1 ms | 536 | 84,3 MB |
| Açılış sahnesi | 61 | 17,5 ms | 730 | 92,7 MB |
| Araç çıktı | 60 | 18,1 ms | 764 | 92,7 MB |
| Kasa kalktı | 60 | 17,8 ms | 628 | 87,3 MB |

\* Çizim sayısı trafiğe göre ±60 oynuyor.

| Çağrı | Önce | Sonra |
|---|---|---|
| `buy()` (gem + çekiliş + atomik kayıt + teslimat taraması) | **73,9 ms** | **2,5 ms** |
| Açılış sahnesinin en uzun karesi | **62 ms** | **17,5 ms** |
| `open_crate()` (ödül + kayıt yazımı) | 17,5 ms | 17,1 ms |
| AÇ → sonuç plakası | — | 2,07 sn |

- **`buy()` düzeltmesi:** teslimat taraması tüm zemin yerine arka-sol köşeden çapraz halkalarla ilerliyor ve ilk boş yerde duruyor.
- **Açılış düzeltmesi:** araç modeli kasaya dokunulduğunda (AÇ plakası okunurken) arka planda yüklenmeye başlıyor.
- **Yer tutucu kasanın çizim maliyeti:** detay parçalar (çıta, dikme, kayış, kilit) gölge çizmiyor. Kasa başına ~40 çizim çağrısı hâlâ yüksek; gerçek GLB tek birleşik mesh olursa bu 2–4'e iner (§13 P2).
- **Bekleyen kasa ucuz:** `_process` yok, fizik yalnızca tıklama kutusu, animasyon yalnızca geliş ve açılışta. GemRewards'ın 30 sn'lik gün kontrolü dışında periyodik iş yok.

## 12. Mobil ve PC

| | Yapılan | Sonuç |
|---|---|---|
| Telefon oranı | Bütün oyuncu testleri 1170 × 540 (19,5:9) pencerede, canvas_items ölçeğiyle | Plakalar ekranda; showroom oran plakası genişletildi |
| Dokunmatik | Gerçek `InputEventScreenTouch` kasayı seçti | ✔ |
| Mobil işlemci | Cihazda ölçülmedi. Masaüstünde en uzun kare 17–22 ms, çizim 536–764 | Bir sonraki test sürümüyle telefonda doğrulanmalı (P2) |
| PC | 1152 × 648, fare | ✔ |

## 13. Test matrisi

| Durum | Nerede | Sonuç |
|---|---|---|
| Yeni kayıt | playthrough play, crate_test §1–3 | ✔ |
| Eski kayıt (v3 / v5 / v7 / v9) | save_test, quest_test, crate_test §13 | ✔ |
| Az gem / yeterli gem | playthrough §7, crate_test §4 | ✔ |
| Birden çok kasa (dünyada 3 + yolda 1) | playthrough §8, crate_test §5 | ✔ |
| Kopya | playthrough §11, crate_test §10 | ✔ |
| Rare / Epic / Legendary | 16 araç kontrolü (Era, Focus, Kamiq, S60 / Toros, Golf, Civic / E46, E60), playthrough §12 | ✔ |
| Kaydet / yükle, uygulama yeniden açılışı | playthrough resume (ayrı süreç), crate_test §7, §9 | ✔ |
| Sahne yeniden yükleme | crate_test (her bölüm) | ✔ |
| Garage Editor | playthrough §9, decor_test, garage_decoration_placement_test | ✔ |
| Showroom | playthrough §1, §7, §8, §13; ui_test §5 | ✔ |
| Yarış | playthrough §6, race_test, crate_test §12 | ✔ |
| Koleksiyon | playthrough §5, §13; ui_test §9 | ✔ |
| Mobil (telefon oranı + dokunmatik) | 1170 × 540, `InputEventScreenTouch` | ✔ (cihazda değil) |
| PC | 1152 × 648, fare | ✔ |

Tam paket (son koşu, bütün düzeltmelerden sonra): **15 paket, 1.180 kontrol, 0 hata**.

| Paket | Sonuç |
|---|---|
| save_test | 29 / 0 |
| edge_test | 34 / 0 |
| quest_test | 29 / 0 |
| paint_test | 27 / 0 |
| cloud_test | 50 / 0 |
| drag_transmission_test | 38 / 0 |
| vehicle_wheel_test | 17 / 0 |
| decor_test | 118 / 0 |
| garage_decoration_placement_test | 169 / 0 |
| crate_test | 96 / 0 |
| ui_test | 57 / 0 |
| race_test | 49 / 0 |
| progression_test | 33 / 0 |
| vehicle_asset_test | 328 / 0 |
| vehicle_scale_test | 106 / 0 |

Ek QA betikleri: oyuncu akışı 47 / 0, yeniden açılış 10 / 0, 16 araç 80 / 0.

## CRATE SYSTEM STATUS: **PASS**

Mevcut kasa sistemi oyunun ana döngüsüne oturuyor. Oyuncu akışı baştan sona gerçek girdiyle oynandı:

Şahin → tamir → seviye → İLK KASA → garaja gelen kasa → aç → araç → koleksiyon → yarış → showroom'dan kasa → kopya → sat / geri al → kapat / aç.

Bulunan 10 oyun hatası düzeltildi ve yeniden test edildi. Eski doğrudan araç satın alma akışı hiçbir yerde görünmüyor. Yalnızca keşfedilmiş aracın ₺ ile geri alınması kaldı; bu tasarım gereği.

## REMAINING ISSUES

**P0** — yok.

**P1**
1. **Mobil cihazda performans ölçülmedi.** Masaüstünde en uzun kare 17–22 ms, açılışta 730–764 çizim çağrısı. Bir sonraki test APK'sıyla telefonda FPS ve açılış takılması ölçülmeli.
2. **Hukuki (yayından önce):** Brezilya ECA Digital (2026-03-17) çocukların erişebileceği oyunlarda loot box'ı yasaklıyor. Kazanılan gemle açılan kasanın kapsamda olup olmadığı için görüş alınmalı. Gem gerçek parayla satılmıyor.

**P2**
1. **Yer tutucu kasa ~40 çizim çağrısı** (22 parça). Gerçek GLB tek birleşik mesh ya da az malzemeyle gelirse kasa başına 2–4'e iner. 6 kasalık garaj mobil bütçeyi zorlayabilir.
2. **₺ harcama yeri 10. saatte tükeniyor** (dekor kataloğu bitince). Sonrası için ₺ hedefi yok.
3. **Legendary kuyruğu:** E60 P95 = 107 PRESTİJ kasası (~116 gün aktif oyuncu). Pity yok (kullanıcı kararı); izlenmeli.
4. **Koleksiyon seti ödülleri** verilmiyor; yalnızca ilerleme görünüyor.

**P3**
1. Seviye 1 garajda üç kasa varken havadaki "GARAJI GENİŞLET" tabelası bir kasanın alt kenarına biniyor. Açılış sırasında gizleniyor.
2. Cihaz saatini her gün ileri alan oyuncu fazladan giriş gemi alabilir; dönünce o günler kilitlenir.
3. Tek günde çok uzun oynayan oyuncunun gem geliri günlük tavanlı kaynaklar yüzünden sınırlı: 10 saatte 20 kasa, 8/16 araç. Tasarım gereği (grindi ödüllendirmemek).
4. Araç kasadan çıkarken devrilmiş ön panelle hafifçe iç içe geçiyor; rampa gibi görünüyor, bozmuyor.
5. Yarış rakibi oyuncunun kendi modeliyle aynı olabiliyor (Focus – Focus). Mevcut rakip havuzu davranışı.
6. Koleksiyon ekranı ilk açılışta 16 küçük render'ı kare başına 2 araç olarak üretir (tek seferlik).
7. "İLK ARAÇ KASAN GARAJINA GELDİ" bildirimi, görev ve seviye bildirimlerinin arkasında kuyrukta bekliyor; birkaç saniye geç çıkıyor.
