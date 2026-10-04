# DEKORASYON v2 — Araştırma raporu

Durum: 2026-10-04. Konu: orijinal Car Town'ın (Cie Games, Facebook, 2010–2014) garaj dekorasyonu.
Üç başlığa odaklanıldı: garaj içine örülen duvarlar, karo karo boyanan zemin ve duvara asılan eşyalar.
Ardından bizim v1 sistemimizle karşılaştırma ve v2 için tasarım önerisi geliyor.

Referans görüntüler depo dışında: `~/Projects/ct_shots/dekorasyon_referans/`. Wiki tablolarının ham
metni de aynı klasörde (`Garage_-_*.txt`).

---

## 1. Özet

- **İç duvarlar:** Car Town'da garajın içine **duvar örülebiliyordu**. Oyuncu duvarın yerini değiştirip
  **oda ekleyebiliyordu**. Duvar segmentleri ızgara çizgilerine oturuyor, duvarlarda **kapı** var, yüzleri
  farklı kaplamalarda: beyaz sıva, ahşap lambri, gri tuğla, sarı boya, siyah ve cam bölme. Oyuncular
  duvarı hem odalara bölmek hem de para kazandıran makineleri (jukebox, langırt) **gizlemek** için
  kullanıyordu.
- **Zemin:** Zemin **karo karo** kaplanıyordu. Ekran görüntülerinde aynı garajda yan yana siyah-beyaz
  dama, mavi-siyah dama, düz açık mavi, siyah karbon/elmas desen, ahşap parke ve krem beton
  görülüyor. Oyuncular bunlarla bölge çiziyordu: araç sergisinin altına dama, yaşam odasına parke,
  geçitlere düz renk.
- **Duvar eşyaları:** Duvara çerçeveli resim (araç fotoğrafı), poster, sponsor afişleri ("Signage"
  kategorisi; örnek HRE afişleri) ve dikey bantlar asılıyordu. Ayrıca yere dikilen marka tabelaları
  (lastik markası tabelası gibi) vardı.
- **Bizde (v1):**
  - **Zemin ve duvar kaplaması:** Tüm garaja tek seçim olarak uygulanıyor, ikişer seçenek var.
  - **İç duvar:** Yok.
  - **Duvar eşyası:** Yalnızca 4 tane var; sadece sol ve arka dış duvarın iç yüzüne asılıyor.
- **Öneri:** Üç yeni yetenek:
  1. **Duvar örme:** Izgara kenarına segment segment, kapı, pencere ve cam bölme çeşitleriyle.
  2. **Zemin boyama:** Fırça, dikdörtgen, kova ve damlalıkla, 15+ desen.
  3. **Genişletilmiş duvar eşyası kataloğu:** ~30 eşya; iç duvarların iki yüzüne de asılabilir.

  Teknik olarak üçü de mobilde tek çizim çağrısına yakın tutulabilir (bkz. §5.6).

---

## 2. Kaynaklar ve yöntem

| Kaynak | Ne verdi | Sınır |
|---|---|---|
| Car Town Wiki (cartown.fandom.com), MediaWiki API ile ham sayfa metni | Garaj menüsü kategorileri; Functional / Misc / Chairs & Tables / Land Expansion / Work Bays tabloları (isim + fiyat) | **Flooring, Walls, Signage sayfaları hiç yazılmamış.** Bu üç kategorinin eşya listesi kaynaklarda yok |
| Wiki görsel arşivi (678 dosya, 428'i indirildi ve tarandı) | Garaj içi ekran görüntüleri: Rusty'nin garajı, oyuncu garajları, tamir alanı kataloğu görselleri | Duvar, zemin ve tabela eşyalarının adları görsellerde yazmıyor; teşhis görsel |
| Jalopnik, 2010 rehberi (arşiv kopyası; geliştiricinin katkısıyla yazılmış) | "Edit Garage: work bays, tile flooring, decorated walls, land expansion"; "build additional walls… hide your money making enterprises" | — |
| SuperCheats rehberi (2021 arşiv kopyası) | "You can also reposition walls and add rooms"; 2.–4. kat; 4. katı ziyaretçilere kapatma | — |
| GameYum incelemesi | "tables, chairs, flooring, walls, different decorations, and signs" | — |

Sonuç: **mekanik** (ne yapılabildiği) kaynaklarla kesin. **Duvar, zemin ve tabela eşyalarının tam listesi**
kayıp. Bu üçü için aşağıdaki listeler ekran görüntülerinden teşhis, katalog değil.

---

## 3. Orijinal Car Town'da garaj düzenleme

### 3.1 Menü yapısı (Edit Garage)

Dükkan sekmesi 9 kategori: **Work Bays, Shop Items, Functional, Misc, Chairs & Tables, Flooring, Walls,
Signage, Land Expansion.** Yanında **Storage** sekmesi var; iki alt bölümü var: Item Storage
(kaldırılmış eşyalar) ve Car Storage (garajda durmayan araçlar). Eşyalar seviyeyle açılıyor. Para
birimi ikili: altın (oyun parası) ve mavi puan (premium).

### 3.2 İç duvarlar

Görsellerden çıkanlar (`rusty_garaj_odalar.png`, `ic_duvar_kapi_cerceve.jpg`, `cam_bolme_bariyer.jpg`):

- **Yerleşim:** Duvarlar izometrik ızgaranın **çizgileri** üzerinde duruyor (hücrenin içine değil,
  kenarına). Düz koşular ve 90° köşeler var; çapraz duvar görülmedi.
- **Yükseklik:** İç duvarlar dış duvarlarla aynı boyda. Kamera yüksek açılı olduğu için arkasındaki
  odayı tamamen kapatmıyor. Rusty'nin garajında sarı boyalı oda, servis alanından tek duvarla ayrılmış.
- **Kapı:** Duvarın içinde koyu gri kapı panelleri var (`ic_duvar_kapi_cerceve.jpg`, sağ üst). Kapı
  segmenti duvarın bir parçası.
- **Yüz kaplamaları** (görülenler):
  - beyaz/gri sıva
  - ahşap lambri (yatay tahta)
  - gri tuğla (dış duvarda)
  - sarı boyalı iç yüz
  - siyah duvar
  - cam bölme (çerçeveli büyük camlar)
  - kırmızı-siyah damalı yüzey (Rusty, sağ üst)

  Aynı duvarın iki yüzü farklı olabiliyor.
- **Kullanım:**
  - Odalara bölmek: servis, yaşam köşesi, sergi.
  - Fonksiyonel eşyaları (para üreten makineleri) ziyaretçinin gözünden saklamak. Jalopnik: *"…you can
    create walls that effectively hide your money making enterprises from view."*
- **Genişleme ilişkisi:** Arsa büyüdükçe yeni duvar alanı açılıyor. 40×40'tan sonra garaj **kat**
  ekliyor; 4. kat kilitlenip ziyaretçilere kapatılabiliyor.

### 3.3 Zemin (Flooring)

Görsellerden çıkanlar (`oyuncu_garaji_karo_zemin.jpg`, `ic_duvar_kapi_cerceve.jpg`, `rusty_garaj_odalar.png`):

- **Birim:** Zemin karosu **tek ızgara hücresi**. Oyuncu karo karo döşüyor, yani aynı garajda istediği
  kadar farklı desen var.
- **Görülen desenler:**
  - siyah-beyaz dama (küçük kare)
  - mavi-siyah dama (büyük kare)
  - düz açık mavi
  - siyah karbon / elmas sac
  - ahşap parke (yaşam odası)
  - krem / beyaz beton (varsayılan)
  - koyu gri asfalt (tamir alanı çevresi)
- **Kullanım:**
  - **Sergi bölgesi:** Araçların altına dama ya da karbon, etrafına bariyer ve kordon direkleri.
  - **Yol / şerit:** Düz renkli karolarla geçit çizgisi.
  - **Oda kimliği:** Her odaya ayrı zemin.
- **Tamir alanı:** Lift kendi zemin plakasını getiriyor (sarı-siyah tehlike şeritli zemin), zemin
  karosunun üstüne oturuyor. Tamir alanı kataloğundaki 14 stilin farkı zaten bu plaka ve lift rengi.

### 3.4 Duvar eşyaları ve tabelalar (Signage)

- **Çerçeveli resim:** Duvara asılı araç fotoğrafı (`ic_duvar_kapi_cerceve.jpg`: ahşap duvarda altın
  çerçeve).
- **Poster ve dikey bant:** Rusty'nin garajında siyah arka duvarda mavi dikey bantlar; sarı odada
  posterler.
- **Sponsor afişleri:** "Signage" kategorisi lisanslı marka afişleri (HRE jant gibi); oyun bunları
  promosyon olarak dağıttı.
- **Yere dikili tabela:** Lastik markası tabelası, ayaklı (`oyuncu_garaji_karo_zemin.jpg`, sağ).
- **Reklam panosu:** Garaj dışında, yol kenarında marka panosu (Honda CR-Z). Bu promosyon içeriği,
  oyuncunun aldığı eşya değil.

### 3.5 Diğer kategoriler (wiki tablolarından)

**Work Bays: 14 stil, hepsi 800 altın, işlevleri aynı.** Kule lift ve direk lift, her biri 7 renk
(standart, siyah-pembe, siyah-sarı, pembe, lacivert-siyah, kırmızı, beyaz). En çok 8 tamir alanı
(işçi sınırı 8, seviye 26'da tamamlanıyor).

**Functional: 32 eşya; para üretir.** Örnekler: langırt 750 altın (15 dk'da 8 altın), telefon kulübesi
15 mavi (60 dk'da 5), atari, otomat, soda makinesi, basket makinesi, pinball, jukebox, top yuvarlama,
air hockey, benzin pompası (3 renk), çocuk binekleri (araba, midilli, yunus, uzay gemisi, tren: 4 saatte
125–1.250 altın). Cadılar Bayramı eşyaları süreli satıldı ("Expired on November 1, 2010").

**Misc: 67 eşya, çoğu 50–250 altın.**
- **Yol ve inşaat:** kasa, beton bariyer, renkli bariyerler, koni, A-tipi bariyer.
- **Variller ve çöp:** 12 renk/şerit varyantı varil, çöp kovası.
- **Atölye ve dekor:** lavabo, park takozu, dur levhası, ayaklı trafik lambası, yarış başlangıç ışığı,
  spot ışıkları.
- **Gösteri:** düz ekran TV, kupa vitrini, kitaplık, vitrinde yarış tulumu.
- **Müzik:** gitar, bas, davul, klavye, amfi, DJ masası, kuyruklu piyano, mikrofon, hoparlör.

**Chairs & Tables: 27 eşya.** Ahşap ve metal sandalye, diner koltuğu (siyah, kırmızı), bar taburesi,
yuvarlak masalar (ahşap, siyah, cam), uzun masa, deri kanepe, masa tenisi, "Kaptan" koltuğu ve masası
(10.000 altın, lüks uç).

**Land Expansion:** 15×15 (sv. 4), 20×20 (sv. 10, 15.000), 25×25 (sv. 17), 30×30 (sv. 25, 40.000),
35×35 (sv. 34, 75.000), 40×40 (sv. 42). Ardından 2. kat (sv. 50), 3. kat (sv. 62), 4. kat (garaj
değeri 9). Atlanamıyor, sırayla alınıyor.

**Ekonomi notu:** Car Town'da eşyalar **para üretirdi**, bizde bilinçli olarak **üretmez**. Ölü para
sorunu ve garaj değeri modeli için bkz. `gameplay/garage_decor.gd` başlığı ve docs/AUDIT_2026_09.md
§6. v2 bu kararı korumalı.

---

## 4. Bizdeki durum (dekorasyon v1)

Kaynak: `decor/decorations.json` (74 eşya), `gameplay/garage_decor.gd`, `gameplay/decor_manager.gd`,
`world/decor_area.gd`, `world/garage_decor_view.gd`, `world/garage_editor.gd`, `vfx/decor_builder.gd`.

| Tür | Adet | Yerleşim |
|---|---|---|
| floor_surface | 2: KARO AVLU (açık gri), ASFALT AVLU | Tüm zemine tek malzeme (`material_override`) |
| wall_surface | 2: TUĞLA DUVAR, PANEL DUVAR | Sol ve arka dış duvara tek malzeme |
| wall_item | 4: neon tabela, duvar saati, poster, neon 'GARAJ' | Yalnızca sol ve arka dış duvarın iç yüzü |
| workshop | 14 | Zemin, serbest X/Z, 45° dönüş |
| lounge | 14 | Zemin |
| yard | 29 | Zemin |
| plant | 9 | Zemin |
| vehicle (sergi) | sahip olunan araçlar | Zemin |

- **Garaj geometrisi:**
  - Sağ ön köşe sabit (x = −0,2, z = −0,2); garaj −x ve −z yönüne büyüyor.
  - Boyutlar: seviye 1 2,0×1,5; seviye 2 3,6×2,2; seviye 3 4,6×2,9; seviye 4 5,6×3,6 birim.
  - Izgara gözü 0,175 birim; seviye 1'de 11×9, seviye 4'te 32×21 göz.
  - Dünyada araç ~0,6 birim, yani ~3,4 göz.
- **Düzenleyici:**
  - Serbest yerleşim, ızgara aç/kapa (yarım göze yapışma), 45° dönüş.
  - Taşıma, depoya kaldırma, son 10 işlemi geri alma.
  - Eşya paleti, odak modu (garajın dışı bulanık).
  - Tamir alanları da taşınabiliyor.
- **Ekonomi:** Eşya para üretmez. Fiyatın ~%40'ı garaj değerine yazılır, `min_rank` rütbe kilidi var.
- **Kayıt:** `savegame.json` v10. Dekor "decor" anahtarında örnek listesi; kaplamalar slot → id.

### Fark tablosu

| Özellik | Car Town | Bizde v1 | v2 için |
|---|---|---|---|
| İç duvar örme | Var, kapılı, yeri değişir | Yok | **Yeni:** kenar tabanlı duvar segmentleri |
| Oda oluşturma | Var | Yok | Duvarlarla kendiliğinden |
| Zemin | Karo karo, çok desen | Tüm garaja tek malzeme (2 seçenek) | **Yeni:** göz başına boyama, 15+ desen |
| Duvar kaplaması | Segment yüzü başına | Tüm dış duvara tek (2 seçenek) | Segment yüzü başına, 8+ kaplama |
| Duvar eşyası | Resim, poster, afiş, bant | 4 eşya, yalnızca dış duvar | ~30 eşya, iç duvarların iki yüzü |
| Tabela (yere dikili) | Marka tabelaları | Var (avlu) | Kurgusal markalarla genişlet |
| Kat | 4 kat, özel kat | Yok | Kapsam dışı (öneri: sonra) |
| Para üreten eşya | Var | Bilinçli olarak yok | Yok (karar korunur) |
| Süreli / sezonluk eşya | Var (Cadılar Bayramı) | Yok | Sonraki aşamada görevlerle bağlanabilir |

---

## 5. v2 tasarım önerisi

### 5.1 İç duvarlar

**Veri modeli: kenar tabanlı.** Duvar, ızgaranın bir göz kenarını kaplayan segmenttir:
`{x, z, yön: "x" | "z", tür, kaplama_a, kaplama_b}`. Koordinat sabit **ön-sağ köşeye göre** göz
indeksi olur. Garaj −x/−z'ye büyüdüğü için eski duvarların indeksi genişlemede değişmez; bu bizim
geometrimizin hazır bir avantajı.

**Segment türleri:**

| Tür | Görünüm | Not |
|---|---|---|
| Düz duvar | Tam yükseklik | Temel |
| Kapı | Duvar içinde kapı paneli (açık geçit ya da kapalı kanat) | Oda girişleri |
| Pencere | Alt yarı duvar, üstü cam | Oda içini gösterir |
| Cam bölme | Çerçeveli tam cam | Sergi odası (Rusty görseli) |
| Yarım duvar | 1/2 yükseklik | Görüşü kapatmaz, alçak ayırıcı |
| Kemer / açıklık | Üstü kapalı, altı boş | Geniş geçit |

- **Kaplamalar** (her yüz ayrı): beyaz sıva, ahşap lambri, kırmızı tuğla, gri tuğla, beton blok,
  oluklu sac, siyah mat, renkli boya (palet), dama karo, beyaz fayans.
- **Çizim:**
  - Duvar aracını seçip ızgara çizgisi boyunca **sürükleyerek** bir koşu çizilir. Kenar yakalama
    toleransı geniş tutulur (parmak için göz boyunun yarısı).
  - Köşeler ve uç direkleri kendiliğinden oluşur.
  - Tek dokunuşla segment seçilir; türü ve kaplaması değiştirilir ya da kaldırılır.
  - Hepsi geri alma yığınına girer.
- **Kurallar:**
  - Duvar, tamir alanının ve teslimat kasasının izinden geçemez.
  - Zemin eşyası duvar segmentiyle çakışamaz (DecorArea'nın SAT çakışmasına ince kutu olarak girer).
  - Duvar eşyası artık her segmentin iki yüzüne asılabilir.
- **Görünürlük (izometrik kamera):** Bizim kamera 3B, Car Town 2B'ydi. Ön tarafa (kameraya bakan
  yöne) düşen iç duvarlar arkasını kapatabilir. Çözüm katmanları, ucuzdan pahalıya:
  1. ~~İç duvar yüksekliği dış duvardan biraz alçak~~ — karar: dış duvarla aynı (§7).
  2. Düzenleme modunda kameraya bakan iç duvarlar yarı saydam.
  3. Oyun modunda seçili ya da tamirdeki aracın önündeki duvar silikleşir.

  Telefonda denenmeli.
- **Fiyat:** Segment başına ucuz: düz 300 ₺, kapı 1.500 ₺, cam bölme 2.500 ₺; kaplamalar ayrıca
  alınır. Garaj değerine yazılır.

### 5.2 Zemin boyama

**Veri modeli:** Göz başına desen indeksi (0 = varsayılan). Seviye 4'te en çok 32×21 = 672 göz,
kayıtta satır satır sıkıştırılmış dize (RLE), yalnızca birkaç yüz bayt.

**Araçlar** (düzenleyici paletinde "ZEMİN" sekmesi):

| Araç | Davranış |
|---|---|
| Fırça | Dokunulan / sürüklenen gözleri boyar |
| Dikdörtgen | Sürükle → dikdörtgen alanı doldurur (sergi alanı için) |
| Kova | Aynı desenli bağlı bölgeyi doldurur (oda zemini için) |
| Damlalık | Gözün desenini seçer |
| Silgi | Varsayılana döndürür |

**Desen kataloğu** (öneri, 16):

- **Damalı:** siyah-beyaz dama (küçük ve büyük), mavi-siyah dama, kırmızı-siyah dama
- **Beton ve sac:** düz beton (açık, koyu), elmas sac (gümüş, siyah), karbon desen
- **Ahşap ve karo:** ahşap parke (açık, koyu), beyaz fayans
- **Kaplama ve işaret:** epoksi (gri, mavi, kırmızı), sarı-siyah tehlike şeridi, yarış şeridi (yön
  çizgili), kauçuk mat

Fiyat göz başına 50–400 ₺: ucuz ve geniş alanda anlamlı, garaj değerine katkılı. Desen bir kez
"satın alınır" (kilit), sonra göz başına küçük ücret mi, yoksa bir kez alınıp sınırsız mı kullanılır?
Bu bir ekonomi kararı (bkz. §7).

### 5.3 Duvar eşyaları (katalog genişletme)

**Mevcut 4 eşyaya ~26 ekleme:**

| Grup | Eşyalar |
|---|---|
| Tabela / levha | Emaye yağ tabelası, "SERVİS" levhası, "PERSONEL HARİCİ GİRİLMEZ", sokak tabelası, oto yıkama okları |
| Poster | Yarış posteri (3 çeşit), **oyuncunun kendi aracının posteri** (araç kartı render'ından; sahip olunan araç seçilir) |
| Neon | Neon şimşek, neon "OPEN", neon damalı bayrak, neon piston, neon araç silueti; renk seçilebilir |
| Atölye duvarı | Takım panosu (asılı aletlerle), duvar rafı (kutularla), lastik askısı, egzoz / jant duvar dekoru, hortum makarası, yangın tüpü, ilk yardım dolabı, havalandırma ızgarası |
| Gösteri | Çerçeveli plaka, damalı bayrak çifti, **ödül plaketleri** (başarım yıldızlarından otomatik açılır), TV ekranı, iş listesi tahtası |
| Işık | Duvar apliki (endüstriyel), şerit LED |

İki "bizim oyuna özel" fikir, Car Town'da olmayan:
1. **Araç posteri:** Garaj ekranındaki araç thumbnail render'ı posterin dokusu olur; oyuncu kendi
   koleksiyonunu duvara asar.
2. **Başarım plaketleri:** GÖREVLER başarımlarından alınan yıldızlar duvar eşyası olarak açılır.
   Satılmaz, kazanılır.

**Marka uyarısı:** Car Town'ın afişleri lisanslıydı (HRE vb.). Bizde gerçek marka logosu kullanılmamalı.
Tabela ve afişler kurgusal markalarla yapılmalı (araç adlarındaki gibi özel isim istisnası yok).

### 5.4 Palet / menü düzeni

Car Town'ın kategorilerini bizim düzene uyarlayan öneri:
**ZEMİN (boyama) · DUVAR (örme + kaplama) · DUVAR EŞYASI · ATÖLYE · DİNLENME · AVLU · BİTKİ ·
TABELA · SERGİ (araçlar) · DEPO.**
"Kaplama" ayrı kategori olmaktan çıkar, ZEMİN ve DUVAR araçlarının içine girer.

### 5.5 Ekonomi

- **Para üretimi:** Eşyalar para üretmez; v1 kararı ve gerekçesi aynen geçerli.
- **Fiyat yapısı:** Duvar segmenti, zemin gözü ve desen kilidi ucuz ama hacimli bir gider. Geniş garajı
  baştan sona döşemek seviye 4'te ölü parayı emen sağlıklı bir gider olur. Örnek: 672 göz × ~150 ₺ ≈
  100.000 ₺ ve 40 segment × ~800 ₺ ≈ 32.000 ₺.
- **Rütbe kilidi:** Premium desenler ve kaplamalar `min_rank` ile açılır.

### 5.6 Teknik yaklaşım (mobil öncelikli)

- **Zemin:**
  - Tek mesh + desen atlası (tek doku, 16 desen) + göz başına desen indeksi taşıyan küçük bir veri
    dokusu (32×21, R8).
  - Shader gözü bulur, indeksle atlastan örnekler. **Tek çizim çağrısı**, göz sayısından bağımsız.
  - Boyarken yalnızca veri dokusu güncellenir (`Image.set_pixel` + `ImageTexture.update`).
  - Alternatif (MultiMesh, göz başına bir karo) daha basit ama 672 örnek ve desen başına malzeme
    gerektirir; atlas yolu daha ucuz.
- **Duvarlar:**
  - Koşu başına birleştirilmiş tek mesh (SurfaceTool).
  - Kaplamalar bir duvar atlasında; segment yüzünün UV'si atlasta kaydırılır.
  - Kapı, pencere, cam gibi özel segmentler ayrı küçük modeller.
  - Değişiklikte yalnızca etkilenen koşu yeniden kurulur.
- **Çakışma:** Duvar segmentleri `DecorArea.obstacles` listesine ince dikdörtgen olarak girer. Duvar
  eşyası yüzeyleri, `back_face_z` / `left_face_x` gibi her segment yüzü için hesaplanır; DecorArea'ya
  "duvar yüzü listesi" eklenir.
- **Kayıt:** v10 → v11. Yeni anahtarlar `walls` (segment listesi) ve `floor_tiles` (RLE dizi). Eski
  kayıt: duvar yok; zemin, eski tek kaplama seçimi tüm gözlere yayılarak taşınır. Bulut kaydı aynı
  JSON içinde gider; boyut artışı < 2 KB.
- **Geri al:** Mevcut 10 adımlık yığına "fırça darbesi" (tek işlem = bir sürükleme) ve "duvar koşusu"
  işlemleri eklenir.
- **Test:**
  - `decor_test` / `garage_decoration_placement_test` genişler: duvarla çakışma, kapı geçişi, duvar
    eşyasının iç duvar yüzüne asılması, genişlemede indekslerin korunması, RLE gidiş-dönüş, v10 göçü.
  - Görsel QA: telefonda duvarın görüşü kapatması.

### 5.7 Aşamalar

| Aşama | İçerik | Bağımlılık |
|---|---|---|
| 1 | **Zemin boyama:** veri modeli, shader + atlas (16 desen, kodla üretilmiş dokular), fırça / dikdörtgen / kova / damlalık, kayıt v11, testler | Yok, en bağımsız ve en görünür kazanç |
| 2 | **İç duvarlar:** segment modeli, sürükleyerek çizim, düz / kapı / yarım duvar, iki yüz kaplaması, çakışma, görünürlük (yarı saydam düzenleme) | 1'in kayıt göçü |
| 3 | **Duvar eşyaları:** iç duvar yüzlerine asma, katalog +26, araç posteri, başarım plaketleri | 2 |
| 4 | **Cam bölme / pencere / kemer**, oyun modunda duvar silikleştirme, sezonluk eşya altyapısı | 2, 3 |

---

## 6. Varlık (asset) ihtiyacı

| Ne | Kaç | Kim üretebilir |
|---|---|---|
| Zemin desen dokuları (atlas) | 16 | Kodla üretilebilir (dama, şerit, sac, karbon prosedürel); parke ve fayans için foto doku daha iyi |
| Duvar kaplama dokuları | 10 | Kodla ya da serbest lisanslı doku (Poly Haven) |
| Kapı / pencere / cam segment modelleri | 4–5 | Blender (basit), script ile üretilebilir |
| Duvar eşyası modelleri | ~26 | Çoğu düz pano + doku (poster, tabela, neon); takım panosu, raf ve lastik askısı modelleme ister |
| Kurgusal marka logoları | 6–8 | Tasarım işi (kullanıcı) |

---

## 7. Kararlar (kullanıcı, 2026-10-04)

1. **İç duvar yüksekliği = dış duvarla aynı** (orijinal oyundaki gibi). Görüş sorunu çıkarsa yalnızca
   düzenleme modunda kameraya bakan duvarlar yarı saydam yapılır; yükseklik değişmez.
2. **Zemin: her karo için küçük ücret.** Desen ayrıca kilitlenmez (rütbe kilidi hariç); fırça her
   boyanan göz için ücret alır, varsayılana döndürmek ücretsizdir. Ücret garaj değerine yazılır.
3. **Katlar ayrı iş**, v2'ye girmez.
4. **Bütün varlıkları (desen dokuları, duvar kaplamaları, kapı/pencere/cam segmentleri, ~26 duvar
   eşyası, kurgusal logolar) ben üretirim.** Blender arka planda (`blender --background`) kit
   script'leriyle çalışıyor (denendi: 5.2.2 LTS, GLB çıktı); kullanıcının Blender açması gerekmez.
   Düz pano tipi eşyalar (poster, tabela, neon) ve dokular Godot tarafında kodla da üretilebilir.

## Kaynaklar

- Car Town Wiki: [Garage](https://cartown.fandom.com/wiki/Garage), Garage - Functional, Garage - Misc,
  Garage - Chairs & Tables, Garage - Land Expansion, Work Bays, Level, Workers (MediaWiki API ile ham
  metin; görseller static.wikia.nocookie.net)
- Jalopnik, *Car Town How To: Tips & Tricks For Building The Ultimate Facebook Garage* (2010):
  https://www.jalopnik.com/car-town-how-to-tips-tricks-for-building-the-ultimat-5626041/ (web.archive.org
  kopyasından okundu)
- SuperCheats, *Car Town Guide — Garage*: https://www.supercheats.com/guides/car-town/garage (2021 arşiv
  kopyası)
- GameYum, *Facebook Game Reviews: Car Town*: https://www.gameyum.com/facebook-games/82508-game-reviews-car-town/

---

## 8. Uygulama (2026-10-04)

Dört aşamanın üçü ve dördüncünün cam / pencere / geçit kısmı uygulandı (oyun modunda duvar silikleştirme ve
sezonluk eşya yapılmadı).

| Parça | Dosya |
|---|---|
| Ortak ızgara (sabit ön-sağ köşe, göz / düğüm / kenar) | `world/decor_grid.gd` |
| Zemin desenleri (20) ve duvar kaplamaları (13), kodla üretilen dokular | `vfx/decor_textures.gd` |
| Zemin: tek shader + Texture2DArray + 32×21 veri dokusu (tek çizim çağrısı) | `vfx/floor_tiles.gdshader` |
| İç duvarlar: düz, yarım, kapılı, açık geçit, pencereli, cam bölme; tek ArrayMesh | `world/interior_walls.gd` |
| Veri: karolar (göz → desen), duvarlar (kenar → parça + kaplama), depo mantığı, ücret / iade | `gameplay/decor_manager.gd` |
| Kurallar: duvar izi engel, iç duvar yüzlerine eşya asma, kova sınırı, dış duvara yakınlık | `world/decor_area.gd`, `world/garage_decor_view.gd` |
| Araçlar: fırça · dikdörtgen · kova · damlalık · silgi, ör · sök, kaplama; tek vuruş = tek geri al | `world/garage_editor.gd` |
| Arayüz: ZEMİN / DUVAR ÖR / DUVAR KAPLAMASI / DUVAR EŞYASI sekmeleri, araç çubuğu, kayan sekmeler | `ui/hud/garage_edit_screen.gd` |
| 28 yeni duvar eşyası (Blender, arka planda) | `tools/decor/props_duvar.py` → `assets/decor/*.glb` |

**Kurallar:**
- **Karo ücreti:** Göz başına desenin fiyatı (50–320 ₺). Aynı desene yeniden boyamak ve silmek ücretsiz.
  Para yetmezse yetecek kadar göz boyanır. Geri al parayı iade eder. Karolar garaj değerine sayılır.
- **Duvar parçaları:** Depo mantığıyla çalışır. Örerken depodaki kopya kullanılır, eksiği satın alınır;
  sökülen parça depoya döner. Değiştirilen parça da depoya döner.
- **Kaplama:** Bir kez alınır, hem dış duvarlara hem iç segmentlere uygulanır.
- **Geçersiz yerler:** Tamir alanı, teslimat kasası ve zemin eşyasının içinden duvar geçmez. Zemin eşyası
  ve tamir alanı duvarın üstüne konamaz.
- **Duvar eşyası:** İç duvarlarda yalnızca DÜZ duvar koşusunun kameraya bakan yüzüne asılır. Üstünde
  eşya olan segment sökülemez.
- **İki parmak:** Araç açıkken tek parmak çizer; kamera iki parmakla kayar ve yakınlaşır (`world_camera.gd`).
- **Eski kayıt:** v1 tüm-zemin kaplaması, karo kaydı olmayan dosyada bütün gözlere aynı desen olarak
  yayılır, ücret alınmaz. Kayıt sürümü değişmedi: yeni anahtarlar (`decor.tiles`, `decor.walls`) eski
  sürümde yoktur ve yoksa boş kabul edilir.

**Test:** `tests/decor_v2_test.gd` (59 kontrol, run_tests listesinde). `decor_test` ve
`garage_decoration_placement_test` yeni kurallara göre güncellendi. Görsel QA gerçek fare olaylarıyla
yapıldı (telefon 1040×480 ve masaüstü): `qa/dekor_v2_qa.gd`; görüntüler `~/Projects/ct_shots/dekor_v2/`.
