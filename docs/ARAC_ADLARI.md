# Araç adları (kurgusal)

2026-10-18: telif / marka riski yüzünden oyundaki tüm araç adları kurgusal marka + model oldu (liste kullanıcıyla
birlikte seçildi). Araç **kimlikleri değişmedi** (`tofas_sahin`, `bmw_e46` …): kayıtlar, bulut verisi, Firestore
kuralları, sahne / model dosya adları aynı kalır; oyuncuya hiçbir yerde gösterilmezler.

## Kurallar (yeni araç eklerken)
* Gerçek marka adı, marka adını taşıyan kelime (BENZ, ALFA…) ya da tek harf değiştirilmiş hali (TOFOS, RENO) yok.
* Gerçek **model adı / tescilli kelime** de yok: Mustang, Stingray, Bel Air, Camaro, Stratos, Delta, Cooper,
  Vito, GT3, S1, Q30, Avant, Variant, Samba, VTEC, GT-Four, Evo, Taurus, Falcon, Cinquecento, Pista, HEMI, Quattro…
* Ortası sıfırlı üç haneli sayı (404, 508) yok: Peugeot bunları sahiplenir.
* Gerçek başka bir şirketin adı yok (Nikola, Volta Trucks, Iberia, Anadolu Isuzu…).
* GTA'nın uydurma markaları da tescillidir: Bravado, Grotti, Pegassi, Übermacht, Declasse, Vapid, Karin, Dinka,
  Benefactor kullanılmaz.
* Biçim: `brand` ve `model` BÜYÜK HARF ve Türkçe büyük harfle yazılır (ERCİYES, HİTİT: `to_upper()` İ üretmez);
  `display_name` = "MARKA MODEL", `label` (varsa) = "MARKA\nMODEL", `performance.variant` = karışık harf
  ("Bavaria Club 46"). Marka tek kelime olmalı: bilboard afişi (`tools/billboard/compose.py`) adı ilk boşluktan böler.

## Adın geçtiği yerler
* `vehicles/cars.json` (brand, model, display_name, label, performance.variant) — oyunun tek kaynağı; ekranlar,
  bildirim metinleri, koleksiyon, profil kartı adı buradan alır.
* `tools/junkyard/klasik_catalog.py` CARS tablosu (28 klasiği cars.json'a yazar; burası eski kalırsa eski ad geri gelir).
* `vehicles/restorations.json` "name" (hurdalık; display_name yoksa yedek).
* `vehicles/crates.json` koleksiyon setleri (WULF GRUBU, ŞİMŞEK) + `locale/*.json` çevirileri.
* Eğitim metni (hoş geldin kutusu: "Bu Bursan Atmaca artık senin!") + `locale/*.json`.
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
* `ui/hud/garage_screen.tscn` CarNameLabel'in editör yer tutucu metni hâlâ "BMW E46" (çalışırken katalogdan
  doldurulur ama sahne dosyasıyla APK'ya girer). Editörde boşaltılmalı / değiştirilmeli, sonra `tools/i18n/extract.py`
  (çevirilerdeki "BMW E46" anahtarı o zaman eskimiş olur, silinebilir).
* W123'ün kaput yıldızı gibi 3B çıkıntılı armalar doku değil mesh: renk silindi, biçim duruyor.
* Kasa tasarımları gerçek araçlara benzer (ızgara biçimleri vb.); isim ve logo değişikliği bunu çözmez.
* Hurdalık enkaz modelleri (`assets/world/junk_wrecks/`) dokusuz, köşe renkli; logo okunmuyor, dokunulmadı.

## Liste

| Oyundaki ad | Kimlik | Esin (eski ad) |
|---|---|---|
| AGENT SPY 005 | `aston_martin_db5` | Aston Martin DB5 |
| ARCLINE RANGE Y | `tesla_model_y` | Tesla Model Y Long Range AWD |
| ARROW KANZLER 16 | `skoda_superb` | Skoda Superb III |
| ARROW SUMMIT 20 | `skoda_kamiq` | Skoda Kamiq |
| ASTA COMETA 74 | `lancia_stratos` | Lancia Stratos HF Stradale |
| ASTA SEDICI 92 | `lancia_delta_integrale` | Lancia Delta HF Integrale Evoluzione |
| BAVARIA CLUB 46 | `bmw_e46` | BMW E46 330i |
| BAVARIA DREI 15 | `bmw_f30` | BMW 320i (F30) |
| BAVARIA FÜNF 07 | `bmw_e60` | BMW E60 530i |
| BAVARIA LEGEND 90 | `bmw_m3_e30` | BMW M3 E30 Evolution |
| BLACKTOP BRUISER 70 | `dodge_charger_1970` | Dodge Charger R/T 440 |
| BULL MATADOR 400 | `lamborghini_miura` | Lamborghini Miura P400 |
| BULL MONSOON | `lambo_huracan` | Lamborghini Huracán |
| BURSAN ATMACA 95 | `tofas_sahin` | Tofaş Şahin |
| BURSAN HACI 124 | `tofas_murat_124` | Tofaş Murat 124 |
| BURSAN M-131 BOX | `tofas_murat_131` | Tofaş Murat 131 |
| CROSSBOW BRUTE SS | `chevrolet_camaro` | Chevrolet Camaro SS |
| CROSSBOW RAZORBACK 63 | `chevrolet_corvette_c2` | Chevrolet Corvette Sting Ray 327 |
| CROSSBOW SUNSET 56 | `chevrolet_bel_air_1956` | Chevrolet Bel Air 265 V8 |
| DONNER C-PULSE | `opel_corsa` | Opel Corsa |
| FITO PICCOLO 65 | `fiat_500_1965` | Fiat Nuova 500 D |
| FORGE FOCAL 13 | `ford_focus` | Ford Focus |
| FORGE GROUP B 200 | `ford_rs200` | Ford RS200 |
| FORGE HAMAL 19 | `ford_transit` | Ford Transit tek kabin kamyonet |
| FORGE RALLYE 72 | `ford_escort_rs1600` | Ford Escort RS1600 |
| FORGE WILD PONY 67 | `ford_mustang_1967` | Ford Mustang Fastback GT 390 |
| FURIA ASSOLUTA 13 | `ferrari_laferrari` | Ferrari LaFerrari |
| FURIA CIRCUITO 19 | `ferrari_488_pista` | Ferrari 488 Pista |
| HİTİT A-67 CLASSIC | `anadol_a1` | Anadol A1 |
| HYPER CYAN 13 | `hyundai_accent_blue` | Hyundai Accent Blue |
| HYPER KENT 07 | `hyundai_era` | Hyundai Accent Era |
| HYPER POCKET Z | `hyundai_getz` | Hyundai Getz |
| IBERO FARO 20 | `cupra_formentor` | Cupra Formentor VZ |
| IBERO LINCE 16 | `seat_leon` | Seat Leon |
| KİRAZ KAPLAN 8 | `chery_tiggo_8` | Chery Tiggo 8 Pro |
| LION QUATRE 68 | `peugeot_404` | Peugeot 404 |
| MICRO BULLDOG 65 | `mini_cooper_1965` | Mini Cooper 998 |
| MONARCH PATROL GT | `police_bentley` | Bentley Continental GT W12 |
| MOORLAND TREK III | `land_rover_series3` | Land Rover Series III 88 |
| OCELOT CLASSIC 61 | `jaguar_e_type` | Jaguar E-Type 3.8 |
| OVALE TONNERRE 16 | `bugatti_chiron` | Bugatti Chiron |
| OVALE ÉCLAIR 05 | `bugatti_veyron` | Bugatti Veyron 16.4 |
| ROMBO ERCİYES 94 | `renault_toros` | Renault Toros |
| ROMBO FLOW 12 | `renault_fluence` | Renault Fluence |
| ROMBO KAYRA 19 | `renault_megane_4` | Renault Megane IV Sedan |
| SERPENTA LUSSO 08 | `alfa_romeo_159` | Alfa Romeo 159 |
| SHIELD ARMOR 16 | `volvo_s60` | Volvo S60 |
| STALLION FOHLEN 20 | `porsche_taycan` | Porsche Taycan Turbo |
| STALLION RING 18 | `porsche_gt3` | Porsche 911 GT3 |
| STALLION RS-73 | `porsche_911_1973` | Porsche 911 Carrera RS 2.7 |
| STERN COUPÉ 350 | `mercedes_cls` | Mercedes CLS 350 |
| STERN DOLMUŞ 19 | `mercedes_sprinter` | Mercedes-Benz Sprinter minibüs |
| STERN FESTUNG 18 | `mercedes_g` | Mercedes-AMG G 63 |
| STERN GULLWING 55 | `mercedes_300sl` | Mercedes-Benz 300 SL |
| STERN KAISER S | `mercedes_s400` | Mercedes S400 |
| STERN SQUAD VAN | `police_vito` | Mercedes-Benz Vito 119 CDI 4MATIC |
| STERN TANK 123 | `mercedes_w123` | Mercedes-Benz 240 D |
| ŞİMŞEK F-VOLT | `togg_t10f` | Togg T10F V2 RWD Uzun Menzil |
| ŞİMŞEK X-VOLT | `togg_t10x` | Togg T10X V2 RWD Uzun Menzil |
| TORNADO HALE 21 | `toyota_corolla` | Toyota Corolla 1.8 Hybrid (E210) |
| TORNADO QUAD 93 | `toyota_celica_gt4` | Toyota Celica GT-Four ST185 |
| TRIDIA RALLY VI | `mitsubishi_evo6` | Mitsubishi Lancer Evolution VI GSR |
| VETERAN WW2 CLASSIC | `willys_jeep_mb` | Willys MB |
| VIER KOMBI R 20 | `audi_rs6` | Audi RS6 |
| VIER KOMPAKT 14 | `audi_a3` | Audi A3 |
| VIER SECHS 19 | `audi_a6` | Audi A6 (C8) 45 TFSI |
| VIER SPORT 85 | `audi_quattro_s1` | Audi Sport Quattro |
| WULF BUG 67 | `vw_beetle_1967` | Volkswagen Beetle 1500 |
| WULF FLOWER BUS 65 | `vw_t1_bus` | Volkswagen T1 1500 |
| WULF KOMBI 04 | `vw_passat_b55` | VW Passat B5.5 |
| WULF KOMBI 16 | `vw_passat_b8` | VW Passat B8 |
| WULF MK7 HATCH | `vw_golf_7` | VW Golf 7 |
| WULF TURBO BUG | `vw_beetle` | Volkswagen Beetle 2.0 TSI |
| ZENITH REV 10 | `honda_civic` | Honda Civic VTEC |
