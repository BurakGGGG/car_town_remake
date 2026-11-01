# Araç adları (kurgusal)

2026-10-18: telif / marka riski yüzünden oyundaki tüm araç adları kurgusal marka + model oldu (liste kullanıcıyla
birlikte seçildi). Araç **kimlikleri değişmedi** (`tofas_sahin`, `bmw_e46` …): kayıtlar, bulut verisi, Firestore
kuralları, sahne / model dosya adları aynı kalır; oyuncuya hiçbir yerde gösterilmezler.

## Kurallar (yeni araç eklerken) — 2026-11-01 v3
Geri bildirim "adlar hiç çağrıştırıcı değil" → kullanıcı: "benzer olsun (Toyota → Tokota gibi)", sonra "yine
çağrıştırsın ama biraz daha uzak olsun". 2026-10-18'in logo / anlam tabanlı adları (BAVARIA, STERN, WULF…) bırakıldı.
* **Marka:** gerçek markanın ilk hecesi / sesi kalır, gerisi 2–3 harf değişir; mümkünse doğal okunan bir kelime
  (TOKAYA, MERIDES, VOLKAN, RENOIR, FERRAZZI, LAMBERTINI). TEK harf değişmiş hal (TOKOTA, BMV) çok yakın bulundu.
* **Model:** aynı yaklaşım (SUPREMA, CORALIA, PASSAGE, URAGANO); kodlar biraz değişir (E46 → 3.46, T10X → TX-10, A6 → AX6).
* **Anlam çevirisi YOK (2026-11-01):** ad, asıl model adından ya da aracın Türkiye'deki lakabından SESLE türer
  (Vosvos → VASVAS, Transporter → TRANSPO, Huracán → HURACO). Kelimenin anlamını çevirmek (Beetle → BÖCÜK,
  hippi otobüsü → HİPPİ, martı kanadı → GULL, Cinquecento → PICCOLA, Huracán → URAGANO) zayıf bulundu.
* Tescilli model kodu aynen geçmez (M3 → MX 3.30); iki harfin yer değiştirmesi (TESLA → TELSA) fazla yakın.
* Ortası sıfırlı üç haneli sayı (404, 308) yok: Peugeot bunları sahiplenir (404 → PERGEOT 44). GTA markaları yok.
* Biçim: `brand` ve `model` BÜYÜK HARF; Türkçe kelimede Türkçe büyük harf (ŞAHAN, MİRAT); `display_name` =
  "MARKA MODEL", `label` (varsa) = "MARKA\nMODEL", `performance.variant` = karışık harf ("Tokaya Suprema"; rakamlı ve
  ≤ 2 harfli kelime ile BMR / CLX büyük kalır). Marka tek kelime (bilboard adı ilk boşluktan böler). En uzun ad 20 harf
  (CHEVALIER CAMARGO SS) — showroom kasa oran plakası buna göre 290 px.
* Dokulardaki gerçek logolar sökülmüş kalır (aşağıda); yeni araçta da sökülür.

## Adın geçtiği yerler
* `vehicles/cars.json` (brand, model, display_name, label, performance.variant) — oyunun tek kaynağı; ekranlar,
  bildirim metinleri, koleksiyon, profil kartı adı buradan alır.
* `tools/junkyard/klasik_catalog.py` CARS tablosu (28 klasiği cars.json'a yazar; burası eski kalırsa eski ad geri gelir).
* `vehicles/restorations.json` "name" (hurdalık; display_name yoksa yedek).
* `vehicles/crates.json` koleksiyon setleri (VOLKAN GRUBU, TOGRA) + `locale/*.json` çevirileri.
* Eğitim metni (hoş geldin kutusu: "Bu Tofan Şahan artık senin!") + `locale/*.json`.
* Bilboard afişleri `assets/world/billboard/*.jpg` (adı resmin içine basar): `python3 -I tools/billboard/compose.py`
  sonra `godot-4 --headless --import`.
* Web sitesi (`~/Projects/auto_yard_website`): `src/partials/cars-*.html`, `src/pages/*/home.html`, kullanım
  şartlarındaki "araç adları kurgusaldır" maddesi, ekran görüntüleri (`tools/make_images.py`).
* Play mağaza metni (`docs/release/MAGAZA_DE_FR.md` + Play Console'daki TR/EN/ES metinleri), mağaza görselleri.

## Logolar (arma söküm, 2026-10-18)
Tripo dokularında basılı gerçek logolar (ızgara / kaput / bagaj arması, jant göbeği, model yazısı) çevrelerinin
rengiyle dolduruldu: `tools/debadge/` (Blender'ın Python'u + numpy; ayrıntı `debadge.py` başında).
* `badges.json`: araç → görünüm → bölge (görünüm pikseli). Dikdörtgen / elips `{"e"}` / çokgen `{"p"}`; sonuna
  `"h"` yazılan bölge satır satır yatay doldurulur (ızgara çıtası, krom şerit, lambaya değen yazı), diğerleri
  difüzyonla. Eğik görünümler (`a_top` / `b_top`) yalnız kaput ÜSTÜNDEKİ arma için: dik yüzeydeki armada komşu
  parçaya (lamba, tampon) taşıyordu.
* Akış: `render <id>` → `python3 -I tools/debadge/grid.py sheet <id>` (ızgaralı özet) → bölgeyi yaz →
  `apply <id>` → `grid.py verify <çıktı.jpg> <id> ...` (önce / sonra). apply dokuyu VE boya maskesini yerinde yazar,
  her seferinde `~/Projects/ct_shots/debadge/<id>/orig_*`'den başlar (tekrar çalıştırmak güvenli).
* TUZAK: Blender `save_render` görüntü dönüşümü uygulayıp dokuyu koyulaştırıyordu (ortalama 97 → 86) → kodlamayı
  PIL yapar (`encode.py`).
* TUZAK: `optimize_car.gd` bir aracı kaynaktan yeniden üretirse logolu doku geri gelir: önce
  `ct_shots/debadge/<id>/orig_*` sil, sonra `render` + `apply`. GLB'nin İÇİNE gömülü doku hâlâ eskidir; Godot
  çıkarılmış JPEG'i kullanır ve gömülü verinin MD5'i değişmedikçe onu yeniden yazmaz (`.import` generator_parameters).
* Logo sökümünden sonra yeniden üretilenler: araç küçük resimleri (`tools/make_car_thumbs.gd`), bilboard çizimleri
  (`tools/billboard/render_cars.gd` + `compose.py`), sitenin araç portreleri ve oyun kareleri.
* `willys_jeep_mb`'de üretici logosu yok (yalnız askerî işaretler), dokunulmadı.

## Açık
* `ui/hud/garage_screen.tscn` CarNameLabel yer tutucusu 2026-11-01'de "BMR 3.46" yapıldı (kullanıcı "sen değiştir"; locale anahtarı da).
* W123'ün kaput yıldızı gibi 3B çıkıntılı armalar doku değil mesh: renk silindi, biçim duruyor.
* Kasa tasarımları gerçek araçlara benzer (ızgara biçimleri vb.); isim ve logo değişikliği bunu çözmez.
* Hurdalık enkaz modelleri (`assets/world/junk_wrecks/`) dokusuz, köşe renkli; logo okunmuyor, dokunulmadı.

## Liste (2026-11-01 v3 + anlam çevirisi düzeltmesi)

| Oyundaki ad | Kimlik | 2026-10-18 adı | Esin |
|---|---|---|---|
| ANADUR A-67 | `anadol_a1` | HİTİT A-67 CLASSIC | Anadol A1 |
| ASTOR MARTEN D5 | `aston_martin_db5` | AGENT SPY 005 | Aston Martin DB5 |
| AUDEX AX3 | `audi_a3` | VIER KOMPAKT 14 | Audi A3 |
| AUDEX AX6 | `audi_a6` | VIER SECHS 19 | Audi A6 (C8) 45 TFSI |
| AUDEX QUARTO S1 | `audi_quattro_s1` | VIER SPORT 85 | Audi Sport Quattro |
| AUDEX RX6 | `audi_rs6` | VIER KOMBI R 20 | Audi RS6 |
| BENTON CONTINA GT | `police_bentley` | MONARCH PATROL GT | Bentley Continental GT W12 |
| BMR 3.30 | `bmw_f30` | BAVARIA DREI 15 | BMW 320i (F30) |
| BMR 3.46 | `bmw_e46` | BAVARIA CLUB 46 | BMW E46 330i |
| BMR 5.60 | `bmw_e60` | BAVARIA FÜNF 07 | BMW E60 530i |
| BMR MX 3.30 | `bmw_m3_e30` | BAVARIA LEGEND 90 | BMW M3 E30 Evolution |
| BUGANTI CHIRAL | `bugatti_chiron` | OVALE TONNERRE 16 | Bugatti Chiron |
| BUGANTI VERION | `bugatti_veyron` | OVALE ÉCLAIR 05 | Bugatti Veyron 16.4 |
| CHERA TIGRO 8 | `chery_tiggo_8` | KİRAZ KAPLAN 8 | Chery Tiggo 8 Pro |
| CHEVALIER BELMAR 56 | `chevrolet_bel_air_1956` | CROSSBOW SUNSET 56 | Chevrolet Bel Air 265 V8 |
| CHEVALIER CAMARGO SS | `chevrolet_camaro` | CROSSBOW BRUTE SS | Chevrolet Camaro SS |
| CHEVALIER CORVINA 63 | `chevrolet_corvette_c2` | CROSSBOW RAZORBACK 63 | Chevrolet Corvette Sting Ray 327 |
| CUPRUM FORMENTA | `cupra_formentor` | IBERO FARO 20 | Cupra Formentor VZ |
| DODSON CHARGO 70 | `dodge_charger_1970` | BLACKTOP BRUISER 70 | Dodge Charger R/T 440 |
| FERRAZZI 488 PISTO | `ferrari_488_pista` | FURIA CIRCUITO 19 | Ferrari 488 Pista |
| FERRAZZI LAFERRA | `ferrari_laferrari` | FURIA ASSOLUTA 13 | Ferrari LaFerrari |
| FIORA NOVA 50 | `fiat_500_1965` | FITO PICCOLO 65 | Fiat Nuova 500 D |
| FJORD ESCORTA RS | `ford_escort_rs1600` | FORGE RALLYE 72 | Ford Escort RS1600 |
| FJORD FOCAL 3 | `ford_focus` | FORGE FOCAL 13 | Ford Focus |
| FJORD MUSTANO 67 | `ford_mustang_1967` | FORGE WILD PONY 67 | Ford Mustang Fastback GT 390 |
| FJORD RZ 200 | `ford_rs200` | FORGE GROUP B 200 | Ford RS200 |
| FJORD TRANSA | `ford_transit` | FORGE HAMAL 19 | Ford Transit tek kabin kamyonet |
| HONZA CIVITA | `honda_civic` | ZENITH REV 10 | Honda Civic VTEC |
| HONZA NZX | `honda_nsx` | — | Honda NSX (NA1) 3.0 V6 VTEC |
| HYUNGA ASCENT BLU | `hyundai_accent_blue` | HYPER CYAN 13 | Hyundai Accent Blue |
| HYUNGA ASCENT ERO | `hyundai_era` | HYPER KENT 07 | Hyundai Accent Era |
| HYUNGA GETTA | `hyundai_getz` | HYPER POCKET Z | Hyundai Getz |
| JAGORA E-TIPO | `jaguar_e_type` | OCELOT CLASSIC 61 | Jaguar E-Type 3.8 |
| LAMBERTINI HURACO | `lambo_huracan` | BULL MONSOON | Lamborghini Huracán |
| LAMBERTINI MIRUNA | `lamborghini_miura` | BULL MATADOR 400 | Lamborghini Miura P400 |
| LANDRIDER SERIA 3 | `land_rover_series3` | MOORLAND TREK III | Land Rover Series III 88 |
| LANZA DELTIA HF | `lancia_delta_integrale` | ASTA SEDICI 92 | Lancia Delta HF Integrale Evoluzione |
| LANZA STRATIA | `lancia_stratos` | ASTA COMETA 74 | Lancia Stratos HF Stradale |
| MAZURA RZ-7 | `mazda_rx7` | — | Mazda RX-7 (FD) Twin Turbo |
| MERIDES 123 D | `mercedes_w123` | STERN TANK 123 | Mercedes-Benz 240 D |
| MERIDES CLX 35 | `mercedes_cls` | STERN COUPÉ 350 | Mercedes CLS 350 |
| MERIDES GD 63 | `mercedes_g` | STERN FESTUNG 18 | Mercedes-AMG G 63 |
| MERIDES S-40 | `mercedes_s400` | STERN KAISER S | Mercedes S400 |
| MERIDES SL-30 | `mercedes_300sl` | STERN GULLWING 55 | Mercedes-Benz 300 SL |
| MERIDES SPRINTO | `mercedes_sprinter` | STERN DOLMUŞ 19 | Mercedes-Benz Sprinter minibüs |
| MERIDES VITA | `police_vito` | STERN SQUAD VAN | Mercedes-Benz Vito 119 CDI 4MATIC |
| MINKO COPPA 65 | `mini_cooper_1965` | MICRO BULLDOG 65 | Mini Cooper 998 |
| MITSUKO EVOLTA 6 | `mitsubishi_evo6` | TRIDIA RALLY VI | Mitsubishi Lancer Evolution VI GSR |
| NISKA SKYRISE 34 | `nissan_skyline_r34` | RISING KAIJU 99 | Nissan Skyline GT-R R34 |
| OPAR CORSIA | `opel_corsa` | DONNER C-PULSE | Opel Corsa |
| PERGEOT 44 | `peugeot_404` | LION QUATRE 68 | Peugeot 404 |
| PORSTEN 991 GT | `porsche_gt3` | STALLION RING 18 | Porsche 911 GT3 |
| PORSTEN CARRA RS | `porsche_911_1973` | STALLION RS-73 | Porsche 911 Carrera RS 2.7 |
| PORSTEN TAYGAN | `porsche_taycan` | STALLION FOHLEN 20 | Porsche Taycan Turbo |
| RENOIR FLUVIA | `renault_fluence` | ROMBO FLOW 12 | Renault Fluence |
| RENOIR MEGARA 4 | `renault_megane_4` | ROMBO KAYRA 19 | Renault Megane IV Sedan |
| RENOIR TORUS 12 | `renault_toros` | ROMBO ERCİYES 94 | Renault Toros |
| ROMANO 159 | `alfa_romeo_159` | SERPENTA LUSSO 08 | Alfa Romeo 159 |
| SEDRA LEONA | `seat_leon` | IBERO LINCE 16 | Seat Leon |
| SKOVA KAMIKO | `skoda_kamiq` | ARROW SUMMIT 20 | Skoda Kamiq |
| SKOVA SUPERBA | `skoda_superb` | ARROW KANZLER 16 | Skoda Superb III |
| TESSORA MODO Y | `tesla_model_y` | ARCLINE RANGE Y | Tesla Model Y Long Range AWD |
| TOFAN MİRAT 124 | `tofas_murat_124` | BURSAN HACI 124 | Tofaş Murat 124 |
| TOFAN MİRAT 131 | `tofas_murat_131` | BURSAN M-131 BOX | Tofaş Murat 131 |
| TOFAN ŞAHAN | `tofas_sahin` | BURSAN ATMACA 95 | Tofaş Şahin |
| TOGRA TF-10 | `togg_t10f` | ŞİMŞEK F-VOLT | Togg T10F V2 RWD Uzun Menzil |
| TOGRA TX-10 | `togg_t10x` | ŞİMŞEK X-VOLT | Togg T10X V2 RWD Uzun Menzil |
| TOKAYA CELESTA GT4 | `toyota_celica_gt4` | TORNADO QUAD 93 | Toyota Celica GT-Four ST185 |
| TOKAYA CORALIA | `toyota_corolla` | TORNADO HALE 21 | Toyota Corolla 1.8 Hybrid (E210) |
| TOKAYA SUPREMA | `toyota_supra` | TORNADO APEX 97 | Toyota Supra A80 3.0 Twin Turbo |
| TOKAYA TRUENZO 86 | `toyota_ae86` | — | Toyota Sprinter Trueno GT-APEX (AE86) |
| VOLDA SV60 | `volvo_s60` | SHIELD ARMOR 16 | Volvo S60 |
| VOLKAN GOLFER 7 | `vw_golf_7` | WULF MK7 HATCH | VW Golf 7 |
| VOLKAN PASSAGE B5 | `vw_passat_b55` | WULF KOMBI 04 | VW Passat B5.5 |
| VOLKAN PASSAGE B8 | `vw_passat_b8` | WULF KOMBI 16 | VW Passat B8 |
| VOLKAN TRANSPO T1 | `vw_t1_bus` | WULF FLOWER BUS 65 | Volkswagen T1 1500 |
| VOLKAN VASVAS 2.0 | `vw_beetle` | WULF TURBO BUG | Volkswagen Beetle 2.0 TSI |
| VOLKAN VASVAS 67 | `vw_beetle_1967` | WULF BUG 67 | Volkswagen Beetle 1500 |
| WILLOW MV | `willys_jeep_mb` | VETERAN WW2 CLASSIC | Willys MB |
