# Garaj Düzenleyicisi — Rapor

2026-09-29 · şartname: "CAR TOWN REMAKE — GARAGE EDITOR / DECORATION PLACEMENT SYSTEM" (§1–§40)

**Özet.** Sabit yuvalı avlu dekorasyonunun yerine, ana izometrik dünyadaki gerçek garajda çalışan bir
düzenleme modu geldi. Ayrı sahne ya da önizleme yok. Oyuncu HUD'daki **GARAJI DÜZENLE** plakasıyla
moda girer. Alttaki kategorilerden eşya seçer; eşya yarı saydam hayalet olarak garajın boş bir yerine
gelir. Oyuncu onu sürükler, 45° adımlarla döndürür ve bırakır. Seçtiği eşyayı taşıyabilir, döndürebilir
ya da depoya kaldırabilir, son 10 işlemi geri alabilir. **BİTİR** düzeni hemen diske yazar.

Katalog tek bir JSON dosyasından gelir (74 kayıt, eşya başına kod yok). Aynı eşyadan birden çok kopya
alınabilir ve her kopyanın kendi kimliği vardır (`dec_001`…). Kayıt v9'da konum, dönüş ve ölçek
`{x,y,z}` olarak saklanır; eski v8 kayıtları yüklenirken taşınır. Testlerde bulunan sorunların hepsi düzeltildi:

- Paletin parmakla kaymaması
- Eşya sürüklenirken kameranın birkaç piksel kayması
- Sıkışık dizilişte yanlış eşyanın seçilmesi
- Kilitli tamir alanında yasak örtüsünün görünmemesi
- Duvara yaslı eşyanın dönememesi
- Telefon oranında denetim çubuğunun garajın ön köşesini örtmesi

Otomatik testlerin durumu:

- 24 zorunlu senaryo: 24/24 geçti (169 kontrol)
- Tüm paket: 14 paket, 1.071 kontrol, 0 hata
- Fare (1152×648) ve dokunmatik (1170×540) gerçek girdi oynanış testi: iki aşama da 0 hata
- Görsel QA: 0 hata

---

## 1. Mevcut dekorasyon sistemi (başlangıç)

İşe başlarken (commit `4f5d5dc`) dekorasyon şöyleydi:

| Konu | Eski durum |
|---|---|
| Yerleşim | Avluda **sabit yuvalar**: 64 zemin + 3 duvar yuvası, `gameplay/garage_decor.gd` içinde sabit koordinat tabloları. Her yuva bir garaj seviyesine bağlı, yönü sabit. |
| Katalog | Kodda `ITEMS` dizisi (74 kayıt). Yeni eşya = kod değişikliği. |
| Arayüz | `ui/hud/decor_panel.gd`: avluya dokununca açılan liste. Tek dokunuş satın alır ya da ilk boş yuvaya koyar/kaldırır. Yer seçilemez. |
| Kopya | Eşya başına **tek kopya** ("aynı eşya ikinci kez alınamaz"). |
| Kayıt | v8: `owned` dizi, `placed` yuva → eşya sözlüğü. |
| Eksikler | Serbest yerleşim, döndürme, geri al, depo sayacı ve ayrı düzenleme modu yoktu. Düzenlerken dünya tıklamaları (araç, tabela, tamir alanı) açıktı. |
| Model | Çoğu modelin orijini tabanında değildi. `tree_slim`, `water_tower` ve `garage_sign` zemine 0,157 birim gömülüyordu; ölçüm için §2'ye bakın. |

Garaj değeri kuralı (sahip olunan eşya garaj değerine `value` kadar yazılır, `GarageValue.decor_value`)
ve ekonomi değerleri **aynen korundu**.

## 2. 70+ varlık analizi

`qa/dekor_varlik_analizi.gd` her gövdeyi kurup ölçer. Tablo o betiğin çıktısıdır.

- **74 kayıt:**
  - 4 kaplama (2 zemin, 2 duvar)
  - 66 zemin eşyası
  - 4 duvar eşyası
- **Gövde kaynağı:** 50 eşya `.glb` modelli; 20 eşya `DecorBuilder`'da ilkel şekillerle kurulu. Bu 20 gövde önceden vardı, dokunulmadı.
- **Kategoriler:** ATÖLYE 14, YAŞAM ALANI 14, AVLU DÜZENİ 29, BİTKİ 9, PANO 4, AVLU ZEMİNİ 2, GARAJ DUVARI 2. Palet sekmeleri bu verideki türlerden üretilir; uydurma kategori yok.
- **Orijin sorunu:**
  - 47 gövdenin tabanı orijinin 0,004 birimden fazla altındaydı. Normalleştirilmeseydi zemine gömülürdü; en kötüsü 0,157 birim.
  - 29 gövdenin iz ortası orijinden 0,01 birimden fazla kaçıktı. Döndürünce eşya kendi çevresinde değil bir köşe etrafında dönerdi; en kötüsü araç lifti, 0,175.
  - İkisi de gövde kurulurken bir kez ölçülüp düzeltiliyor (`DecorBuilder.build_placeable`, eşya başına önbellek). JSON'a boyut yazılmıyor, boyut modelden ölçülüyor.
- **Boyut aralığı** (dünya birimi, 1 m ≈ 0,137):
  - En küçük iz: `air_station` / `parking_sign`, 0,05 × 0,03.
  - En büyük iz: `wreck` 0,63 × 0,24 ve `trailer` 0,58 × 0,28.
  - En uzun: `tree_slim`, 0,59.
- **Üçgen sayısı:** en büyüğü `trophy_case` 2.160, ortalama 357, toplam 25.056. Bu sayı hassas seçimi (§4) GDScript'te mümkün kıldı.

| id | ad | kategori | yerleşim · model | iz (en × derinlik) | boy | orijin sapması (düzeltildi) | rütbe | fiyat ₺ |
|---|---|---|---|---|---|---|---|---|
| floor_tile | KARO AVLU | AVLU ZEMİNİ | kaplama | — | — | — | 1 | 6.000 |
| floor_epoxy | ASFALT AVLU | AVLU ZEMİNİ | kaplama | — | — | — | 3 | 22.000 |
| wall_brick | TUĞLA DUVAR | GARAJ DUVARI | kaplama | — | — | — | 2 | 9.000 |
| wall_panel | PANEL DUVAR | GARAJ DUVARI | kaplama | — | — | — | 4 | 30.000 |
| tool_cabinet | TAKIM DOLABI | ATÖLYE | zemin · kod | 0.22 × 0.12 | 0.21 | — | 1 | 3.000 |
| tyre_rack | LASTİK RAFI | ATÖLYE | zemin · kod | 0.19 × 0.13 | 0.16 | — | 1 | 5.000 |
| compressor | KOMPRESÖR | ATÖLYE | zemin · kod | 0.10 × 0.20 | 0.18 | taban +0.000 · orta 0.005 | 2 | 12.000 |
| tool_trolley | ALET ARABASI | ATÖLYE | zemin · kod | 0.18 × 0.12 | 0.18 | — | 3 | 16.000 |
| sofa | KANEPE | YAŞAM ALANI | zemin · kod | 0.30 × 0.12 | 0.20 | — | 2 | 8.000 |
| coffee_table | SEHPA | YAŞAM ALANI | zemin · kod | 0.16 × 0.11 | 0.11 | — | 1 | 4.000 |
| vending | OTOMAT | YAŞAM ALANI | zemin · glb | 0.13 × 0.11 | 0.26 | taban -0.120 · orta 0.001 | 4 | 26.000 |
| neon_sign | NEON TABELA | PANO | duvar · kod | 0.30 × 0.02 | 0.12 | — | 6 | 60.000 |
| oil_drums | YAĞ VARİLLERİ | ATÖLYE | zemin · kod | 0.18 × 0.16 | 0.14 | taban +0.000 · orta 0.010 | 1 | 3.500 |
| pallet_stack | PALET YIĞINI | ATÖLYE | zemin · kod | 0.19 × 0.16 | 0.10 | taban -0.006 · orta 0.000 | 1 | 2.500 |
| tyre_pile | LASTİK YIĞINI | ATÖLYE | zemin · glb | 0.18 × 0.16 | 0.14 | taban -0.011 · orta 0.020 | 2 | 12.000 |
| jack_stand | KRİKO | ATÖLYE | zemin · kod | 0.12 × 0.19 | 0.12 | taban +0.000 · orta 0.044 | 2 | 9.500 |
| parts_shelf | PARÇA RAFI | ATÖLYE | zemin · kod | 0.24 × 0.12 | 0.34 | — | 4 | 34.000 |
| traffic_cones | TRAFİK KONİLERİ | AVLU DÜZENİ | zemin · kod | 0.21 × 0.10 | 0.09 | — | 1 | 1.500 |
| barrier | BARİYER | AVLU DÜZENİ | zemin · kod | 0.31 × 0.06 | 0.13 | — | 2 | 7.000 |
| dumpster | ÇÖP KONTEYNERİ | AVLU DÜZENİ | zemin · kod | 0.26 × 0.15 | 0.18 | — | 2 | 11.000 |
| container | DEPO KONTEYNERİ | AVLU DÜZENİ | zemin · kod | 0.45 × 0.20 | 0.22 | — | 5 | 48.000 |
| fuel_pump | YAKIT POMPASI | AVLU DÜZENİ | zemin · glb | 0.15 × 0.09 | 0.28 | taban -0.010 · orta 0.000 | 7 | 85.000 |
| bench | BANK | YAŞAM ALANI | zemin · kod | 0.27 × 0.10 | 0.17 | taban +0.000 · orta 0.003 | 1 | 5.500 |
| picnic_table | PİKNİK MASASI | YAŞAM ALANI | zemin · kod | 0.25 × 0.27 | 0.13 | — | 3 | 14.000 |
| potted_plant | SAKSI BİTKİ | YAŞAM ALANI | zemin · kod | 0.13 × 0.11 | 0.25 | taban +0.000 · orta 0.010 | 2 | 6.500 |
| lamp_post | AYDINLATMA DİREĞİ | AVLU DÜZENİ | zemin · kod | 0.10 × 0.07 | 0.40 | — | 5 | 40.000 |
| flagpole | BAYRAK DİREĞİ | AVLU DÜZENİ | zemin · kod | 0.07 × 0.18 | 0.46 | taban +0.000 · orta 0.055 | 8 | 120.000 |
| hedge | ÇİT BİTKİ | BİTKİ | zemin · glb | 0.25 × 0.08 | 0.12 | taban -0.056 · orta 0.000 | 1 | 3.000 |
| tyre_planter | LASTİK SAKSI | BİTKİ | zemin · glb | 0.09 × 0.09 | 0.03 | taban -0.011 · orta 0.000 | 1 | 3.500 |
| planter_box | AHŞAP SAKSI | BİTKİ | zemin · glb | 0.14 × 0.06 | 0.09 | taban -0.029 · orta 0.028 | 1 | 5.000 |
| flower_bed | ÇİÇEK TARHI | BİTKİ | zemin · glb | 0.21 × 0.15 | 0.05 | taban -0.016 · orta 0.096 | 2 | 7.500 |
| vase_large | BÜYÜK VAZO | BİTKİ | zemin · glb | 0.11 × 0.11 | 0.18 | taban -0.011 · orta 0.000 | 2 | 9.000 |
| tree_round | YUVARLAK AĞAÇ | BİTKİ | zemin · glb | 0.22 × 0.21 | 0.41 | taban -0.103 · orta 0.008 | 3 | 18.000 |
| tree_slim | İNCE AĞAÇ | BİTKİ | zemin · glb | 0.12 × 0.13 | 0.59 | taban -0.157 · orta 0.002 | 3 | 20.000 |
| tree_pine | ÇAM | BİTKİ | zemin · glb | 0.26 × 0.26 | 0.49 | taban -0.062 · orta 0.000 | 4 | 24.000 |
| tree_palm | PALMİYE | BİTKİ | zemin · glb | 0.27 × 0.27 | 0.44 | taban -0.029 · orta 0.005 | 5 | 38.000 |
| speed_bump | KASİS | AVLU DÜZENİ | zemin · glb | 0.23 × 0.04 | 0.01 | taban -0.006 · orta 0.093 | 1 | 2.000 |
| warning_sign | UYARI TABELASI | AVLU DÜZENİ | zemin · glb | 0.07 × 0.06 | 0.10 | taban -0.049 · orta 0.019 | 1 | 2.800 |
| jerry_cans | BENZİN BİDONLARI | AVLU DÜZENİ | zemin · glb | 0.07 × 0.06 | 0.05 | taban -0.023 · orta 0.024 | 1 | 3.200 |
| sandbags | KUM TORBALARI | AVLU DÜZENİ | zemin · glb | 0.17 × 0.04 | 0.06 | taban -0.012 · orta 0.062 | 1 | 3.800 |
| wooden_crates | AHŞAP KASALAR | AVLU DÜZENİ | zemin · glb | 0.18 × 0.08 | 0.13 | taban -0.036 · orta 0.006 | 1 | 4.000 |
| bollards | DUBA SIRASI | AVLU DÜZENİ | zemin · glb | 0.17 × 0.02 | 0.09 | taban -0.005 · orta 0.075 | 1 | 4.500 |
| arrow_sign | YÖN OKU | AVLU DÜZENİ | zemin · glb | 0.12 × 0.04 | 0.22 | taban -0.004 · orta 0.029 | 1 | 5.500 |
| cable_reel | KABLO MAKARASI | AVLU DÜZENİ | zemin · glb | 0.11 × 0.06 | 0.11 | taban -0.057 · orta 0.027 | 2 | 6.000 |
| extinguisher_stand | YANGIN TÜPÜ | AVLU DÜZENİ | zemin · glb | 0.05 × 0.03 | 0.10 | taban -0.003 · orta 0.000 | 2 | 7.500 |
| hose_reel | HORTUM MAKARASI | AVLU DÜZENİ | zemin · glb | 0.07 × 0.05 | 0.12 | taban -0.034 · orta 0.013 | 2 | 8.500 |
| car_ramps | ÇIKIŞ RAMPALARI | AVLU DÜZENİ | zemin · glb | 0.15 × 0.16 | 0.06 | taban -0.015 · orta 0.057 | 2 | 9.000 |
| parking_sign | PARK TABELASI | AVLU DÜZENİ | zemin · glb | 0.05 × 0.03 | 0.26 | taban -0.004 · orta 0.000 | 3 | 13.000 |
| air_station | HAVA İSTASYONU | AVLU DÜZENİ | zemin · glb | 0.05 × 0.03 | 0.16 | taban -0.008 · orta 0.006 | 4 | 28.000 |
| spare_doors | YEDEK KAPILAR | ATÖLYE | zemin · glb | 0.17 × 0.05 | 0.14 | taban -0.074 · orta 0.024 | 2 | 11.000 |
| welding_set | KAYNAK TAKIMI | ATÖLYE | zemin · glb | 0.06 × 0.07 | 0.14 | taban -0.004 · orta 0.011 | 3 | 17.000 |
| engine_block | MOTOR BLOĞU | ATÖLYE | zemin · glb | 0.10 × 0.08 | 0.15 | taban -0.036 · orta 0.049 | 3 | 22.000 |
| barrel_rack | VARİL RAFI | ATÖLYE | zemin · glb | 0.18 × 0.07 | 0.16 | taban -0.075 · orta 0.085 | 4 | 26.000 |
| workbench | ÇALIŞMA TEZGÂHI | ATÖLYE | zemin · glb | 0.23 × 0.10 | 0.20 | taban -0.120 · orta 0.002 | 4 | 32.000 |
| cooler | BUZLUK | YAŞAM ALANI | zemin · glb | 0.09 × 0.06 | 0.05 | taban -0.022 · orta 0.001 | 1 | 4.500 |
| deck_chair | ŞEZLONG | YAŞAM ALANI | zemin · glb | 0.08 × 0.19 | 0.09 | taban -0.046 · orta 0.024 | 1 | 6.000 |
| dog_house | KÖPEK KULÜBESİ | YAŞAM ALANI | zemin · glb | 0.11 × 0.13 | 0.11 | taban -0.036 · orta 0.001 | 2 | 8.000 |
| bbq | MANGAL | YAŞAM ALANI | zemin · glb | 0.09 × 0.09 | 0.13 | taban -0.040 · orta 0.027 | 3 | 15.000 |
| parasol_table | ŞEMSİYELİ MASA | YAŞAM ALANI | zemin · glb | 0.26 × 0.26 | 0.25 | taban -0.098 · orta 0.000 | 3 | 21.000 |
| string_lights | IŞIK DİZİSİ | AVLU DÜZENİ | zemin · glb | 0.38 × 0.03 | 0.33 | taban -0.004 · orta 0.178 | 4 | 26.000 |
| floodlight | PROJEKTÖR DİREĞİ | AVLU DÜZENİ | zemin · glb | 0.10 × 0.05 | 0.44 | taban -0.005 · orta 0.001 | 5 | 45.000 |
| garage_sign | GARAJ TABELASI | AVLU DÜZENİ | zemin · glb | 0.30 × 0.02 | 0.41 | taban -0.157 · orta 0.116 | 7 | 110.000 |
| wall_clock | DUVAR SAATİ | PANO | duvar · glb | 0.07 × 0.01 | 0.07 | — | 2 | 6.500 |
| wall_poster | POSTER | PANO | duvar · glb | 0.08 × 0.01 | 0.12 | — | 2 | 8.000 |
| neon_garage | NEON 'GARAJ' | PANO | duvar · glb | 0.27 × 0.02 | 0.12 | taban -0.000 · orta 0.010 | 6 | 75.000 |
| mechanic | TAMİRCİ FİGÜRÜ | AVLU DÜZENİ | zemin · glb | 0.06 × 0.10 | 0.24 | taban -0.057 · orta 0.015 | 3 | 25.000 |
| foosball | LANGIRT MASASI | YAŞAM ALANI | zemin · glb | 0.21 × 0.14 | 0.14 | taban -0.109 · orta 0.000 | 3 | 30.000 |
| jukebox | JUKEBOX | YAŞAM ALANI | zemin · glb | 0.11 × 0.09 | 0.19 | taban -0.049 · orta 0.002 | 4 | 35.000 |
| motorcycle | MOTOSİKLET | AVLU DÜZENİ | zemin · glb | 0.27 × 0.08 | 0.14 | taban -0.047 · orta 0.090 | 5 | 45.000 |
| wreck | HURDA ARAÇ | AVLU DÜZENİ | zemin · glb | 0.63 × 0.24 | 0.17 | taban -0.071 · orta 0.008 | 5 | 55.000 |
| water_tower | SU DEPOSU | AVLU DÜZENİ | zemin · glb | 0.28 × 0.26 | 0.56 | taban -0.157 · orta 0.085 | 6 | 65.000 |
| trophy_case | KUPA VİTRİNİ | YAŞAM ALANI | zemin · glb | 0.16 × 0.07 | 0.26 | taban -0.010 · orta 0.007 | 6 | 70.000 |
| trailer | SERVİS RÖMORKU | AVLU DÜZENİ | zemin · glb | 0.58 × 0.28 | 0.26 | taban -0.139 · orta 0.055 | 7 | 80.000 |
| car_lift | ARAÇ LİFTİ | AVLU DÜZENİ | zemin · glb | 0.43 × 0.17 | 0.40 | taban -0.007 · orta 0.175 | 7 | 95.000 |

## 3. Mimari

```
decor/decorations.json ──► GarageDecor            katalog (statik, bir kez okunur)
                               │
DecorManager ◄─────────────────┘                  depo (adet) + örnekler + kaplamalar + kayıt
   │ placement_changed
   ▼
GarageDecorView  ──►  DecorArea                   dünya gövdeleri, sahneden ölçüm, geçerlilik,
   ▲                   (saf geometri)             hassas seçim  |  SAT, duvar aralıkları, ızgara
   │
GarageEditor  ◄──►  GarageEditScreen (ui/hud)     düzenleme modu: girdi, hayalet, seçim, geri al
   │                  router: PLACE               |  plakalar, sekmeler, şerit, denetim çubuğu
   ▼
WorldCamera.frame_box / restore_view              DecorThumbs: tembel küçük resim
SaveManager v9  (v8 → DecorLegacySlots ile taşınır)
```

| Dosya | Görev |
|---|---|
| `decor/decorations.json` | Tek veri kaynağı. Alanlar: `id`, `title`, `kind`, `placement`, `price`, `value`, `min_rank`, `desc`; isteğe bağlı olarak `scene_path`, `rotation_step`, `functional` + `gameplay_scene`. `defaults` bloğu varsayılanları verir. |
| `gameplay/garage_decor.gd` | JSON yükleyici; API korundu (`all`, `get_item`, `placement`, `rotation_step`, `scene_path`, `is_functional`, `categories`, `items_in`, `load_from`). |
| `gameplay/decor_manager.gd` | Depo ve örnekler. Geometri bilmez, yalnızca tutarlılığı korur. |
| `world/decor_area.gd` | Saf yerleşim kuralları (`RefCounted`): yönlü iz, SAT, duvar asma, ızgara. |
| `world/garage_decor_view.gd` | Sahneden ölçer (zemin üstü, duvar iç yüzleri, tamir alanları, tabela izi). Gövdeleri eşitler, geçerliliği sınar, üçgen düzeyinde seçer. |
| `world/garage_editor.gd` | Düzenleme modu. Girdi yalıtımı, hayalet, taşı/döndür/sil, geri al. |
| `ui/hud/garage_edit_screen.gd` | Arayüz. Router'a YER (PLACE) olarak kayıtlı, mevcut `ui_router.gd` kullanılır, yeni ESC sistemi yok. |
| `ui/hud/decor_thumbs.gd` | Palet küçük resimleri. SubViewport'ta kare başına 2 tane; statik önbellekte; başsız çalışmada üretilmez. |
| `gameplay/decor_legacy_slots.gd` | Yalnızca v8 taşıma tabloları; yeni kod kullanmaz. |

Temel kararlar:

- **Ayrı sahne yok.** Düzenleme ana dünyadaki garajda yapılır; gövdeler `GarageSystem` altında kodla kurulur. `.tscn` / `.tres` düzenlenmedi.
- **Girdi yalıtımı tek yerden.** Düzenleme açılınca kök görünümün `physics_object_picking` kapatılır. Araç, müşteri, mağaza, genişletme tabelası ve tamir alanı tıklamalarının hepsi `input_event` yolundan geçtiği için ölçülerek seçildi. Düzenleyici sahne kökünün son çocuğu olur ve `_unhandled_input`'u kameradan önce alır. Oyun HUD'u router PLACE ile gizlenir.
- **Eşya başına kod yok.** 20 eski ilkel gövde dışında her şey `.glb` + JSON. Yeni eşya = JSON kaydı + `assets/decor/<id>.glb` (ya da `scene_path`).
- **İşlevli eşya ayrımı hazır.** JSON'da `gameplay_scene` verilirse oyun düğümü gövdenin çocuğu olur ve dönüşümü onunla paylaşır. Katalogda şu an işlevli eşya yok.
- **Araç / tamir alanı taşımaya açık.** Engeller `DecorArea.obstacles` listesidir, yerleşim kuralları örnek türünden bağımsızdır. İleride tamir alanları da örnek olursa aynı SAT / geri al / kayıt yolu kullanılır.

## 4. Yerleştirme

- **Başlatma.** Kart → depoda kopya varsa hayalet; yoksa iki dokunuşta satın alma. Tek dokunuşta alım 120.000 ₺'lik eşyayı kazayla aldırıyordu. Hayalet, ekranın ortasına en yakın geçerli ızgara noktasına gelir: halka arama, en çok 24 adım, `FREE_SPOT_RINGS`. Yer yoksa ortada kırmızı bekler ve "YER YOK" bildirimi çıkar.
- **Hayalet.** Hayalet %40 saydamdır (`GeometryInstance3D.transparency`). Geçersiz yerde soluk kiremit rengine döner (`material_overlay`, `Color(0.86, 0.32, 0.26, 0.5)`, neon değil).
- **Taşıma.** Sürükle, ya da boş zemine dokun (hayalet oraya gelir).
- **Bırakma.** Bırakınca hayalet yerleşir; ayrıca YERLEŞTİR düğmesi var. VAZGEÇ hayaleti kaldırır.
- **Y otomatik.** Zemin eşyası zemin gövdesinin ölçülen üst yüzüne (y = 0,01) oturur, asla altına inmez. Duvar eşyası duvar yüksekliğinin %62'sine asılır.
- **Seçim ve taşıma.** Eşyaya dokun → seçilir; sürükle → taşınır. Taşıma sırasında eşya 0,012 kalkar, soluklaşır ve geçersizse kiremit rengine döner. Geçersiz yere bırakılırsa eski yerine döner ("BURAYA SIĞMIYOR — ESKİ YERİNE DÖNDÜ"). Taşıma `GarageEditor.move_to` ile kaydedilir ve geri alınabilir.
- **Hassas seçim (görsel QA'dan).**
  - Eski yöntem gövde kutusuna bakıyordu. Sıkışık dizilişte uzun ya da içi boş eşyaların (araç lifti, su deposu) kutusu arkadakinin üstüne biniyor ve 29 eşyanın 15'i ekrandaki ortasından seçilemiyordu.
  - Şimdi ışın eşyanın **üçgenleriyle** sınanıyor (`Geometry3D.ray_intersects_triangle`, parça başına kutu ön elemesi, `.glb` ağları önbellekte).
  - Hiçbir eşyaya değmiyorsa en küçük kenarı 0,16 olan şişirilmiş kutu devreye girer; böylece küçük ve ince eşya parmakla da tutulur.
- **Arkada kalan eşya.** Sıkışık dizilişte öndekilerin **tamamen** örttüğü eşyaya aynı noktaya yeniden dokununca sıradaki (arkadaki) eşya seçilir. O noktadan sürükleme artık o eşyayı taşır. Seçim çerçevesinin örtülen kısmı soluk görünür (`next_pass`, derinlik testi yok), böylece arkadaki eşyanın yeri belli olur.
- **Duvar eşyası.** İşaret noktasına en yakın duvara asılır. Sürüklenirken duvardan kopmaz, duvar değiştirebilir.

## 5. Döndürme

- **Adım.** Varsayılan 45°, eşya başına JSON'da `rotation_step` ile değişir. Uygulama:
  - Mobil: iki yuvarlak tabela (sol ikon aynalı).
  - PC: **R** / **Shift+R**.
- **Neden 45° (15° değil).**
  - Ortografik izometrik kamerada 15° komşu yönler neredeyse aynı görünüyor.
  - Tam tur mobilde 24 dokunuş istiyor.
  - 45°'nin verdiği 8 yön (düz + çapraz) açıkça okunuyor ve Car Town'ın yön diline yakın.
  - Oyun testinde tabela 2 dokunuşta 90°, şezlong 1 dokunuşta 45° döndü.
- **Eksen.** Dönme ekseni izin ortası: normalleştirme sayesinde, testte 66 zemin eşyasında 0° kutu ortası konumla çakışıyor.
- **Geçerlilik.** Dönüş yönlü izle sınanır. Yerinde sığmıyorsa en çok 2 ızgara adımı öteye kayarak döner (tek geri al adımı). Önceden duvara ya da komşuya yaslı her uzun eşyanın dönüşü reddediliyordu. Yakında hiç yer yoksa reddedilir ve "DÖNÜNCE SIĞMIYOR" bildirimi çıkar; 3×3 sıkışık blokla test edildi.
- **Duvar eşyası dönmez.** Yönü asıldığı duvardan gelir.

## 6. Izgara

- Görünen ızgara gözü **0,175** birim, tamir alanının uzun kenarının dörtte biri (`GRID_CELL`). Yerleşim adımı bunun yarısı, **0,0875**: eşya merkezi ya göz ortasına ya çizgiye düşer, böylece her boydaki eşyanın kenarı bir çizgiyle hizalanabilir.
- Izgaranın başlangıcı sahnedeki `BuildGrid` düğümünden okunur. Eşyalar çizilen ızgarayla birebir hizalıdır ve ızgara garajla birlikte büyür.
- **IZGARA** düğmesi ızgarayı aç/kapa yapar; varsayılan açık. Kapalıyken yerleşim serbesttir.
- Izgara ve yasak alan örtüsü yalnızca düzenleme modunda görünür.

## 7. Çarpışma ve sınır

- **Yerleşim alanı.** Sahneden ölçülür: duvarların gerçek iç yüzleri + 0,012 pay, açık ön/sağ kenarlar − 0,006. Formül yok; duvar kalınlığı değişirse kurallar izler.
- **Zemin çakışması.** Eşyaların izi **yönlü dikdörtgendir** ve ayırıcı eksen teoremiyle (SAT) sınanır. Eksene hizalı kutu 45° dönük eşyayı şişirirdi. Yan yana değmek (tam temas) çakışma sayılmaz.
- **Engeller.**
  - Düzenleyici garaj seviyesinin inşa ettiği tamir alanlarını engel sayar; kilitli olanlar da dahildir, çünkü ileride araç alacaklar. Alan başına pay 0,03.
  - Genişletme tabelasının izi (0,46 × 0,46) de engeldir. Tabela düzenlemede gizlenir ama izi engel kalır.
  - Böylece eşya bir aracın park yerine konamaz.
- **Yasak alan örtüsü.** Düzenlemede yasak alanlar zeminde soluk kiremit dikdörtgenlerle görünür. Görsel QA'da örtünün kilitli tamir alanının koyu zemininin **altında** kaldığı görüldü; örtü onun üstüne alındı.
- **Duvar eşyaları.** Her duvarda 1B aralık olarak sınanır: aynı duvarda üst üste binemez, duvarın ucundan taşamaz.
- **Seviye 1–4.** Alan `GarageSystem`'in seviye genişlik/derinlik dizilerinden ve ölçülen duvarlardan gelir; kodda `if level ==` yok. Garaj büyüyünce:
  - Duvar eşyaları yeni duvara yeniden asılır.
  - Zemin eşyaları yerinde kalır.
  - Yeni alan açılır.
  - Test: 4 seviyenin hepsi, 21. senaryo.

## 8. Envanter / depo

- **Sayaçlar:** `owned_of` (sahip), `placed_of` (garajda) ve `available_of` (depoda = sahip − yerleşik).
- **Satın alma** kopyayı **depoya** ekler. **DEPOYA KALDIR** örneği kaldırır, kopya depoya döner ve sahiplik silinmez.
- **Kart durumları:** `DEPODA n` / fiyat / `n. RÜTBE` (kilitli) / `SATIN AL? … ₺` (onay) / kaplamada `KULLANILIYOR` / `UYGULA` / `VARSAYILAN`.
- **Kaplamalar** (zemin / duvar) bir kez alınır ve uygulanır, yerleştirilmez.
- **Kopya sınırı:** eşya başına 99 (`MAX_COPIES`), kayıt dosyası akıl dışı büyümesin.
- **Garaj değeri:** sahip olunan her kopya katalog `value` kadar yazılır. Kural ve fiyat/değer rakamları değişmedi; değişen tek şey artık birden çok kopya alınabilmesi.

## 9. Kayıt / yükleme

`SAVE_VERSION = 9`. `decor` bloğu:

```json
{
  "owned": {"deck_chair": 2, "floor_tile": 1},
  "instances": [
    {"instance_id": "dec_001", "catalog_id": "deck_chair",
     "position": {"x": -0.9375, "y": 0.01, "z": -0.425},
     "rotation": {"x": 0, "y": 270, "z": 0},
     "scale": {"x": 1, "y": 1, "z": 1}}
  ],
  "surfaces": {"floor": "floor_tile"},
  "next_instance": 2
}
```

- **Kaydetme zamanı:** her yerleşim değişikliği otomatik kaydı tetikler (`placement_changed` → `request_save`, 0,5 s gecikmeli). **BİTİR** hemen yazar.
- **v8 → v9 taşıma** (`DecorManager._migrate_v8`):
  - Sahiplik dizisi adede çevrilir.
  - Yuvadaki eşya, eski yerleştiricinin hesabıyla gerçek konuma çevrilir: yuva noktası 0,175'lik göz ortasına oturtulur ve yuvanın yönü korunur.
  - Garaj seviyesinde açılmamış yuvadaki eşya depoda kalır; v8'de de görünmüyordu.
  - `zemin` / `duvar` yuvaları kaplamaya çevrilir.
- **Bozuk kayıt dayanıklılığı** (hepsi testli):
  - Katalogda olmayan eşya atlanır.
  - Yinelenen kimlik atlanır.
  - Sahip olunandan fazla yerleşim atlanır.
  - Sayı olmayan konum atlanır.
  - Adet sınıra çekilir.
  - Yanlış yüzeydeki kaplama uygulanmaz.
  - Yeni kimlik eskilerle çakışmaz (`next_instance` ile en büyük kimlikten büyük olanı).

## 10. Geri al

- **Kapsam:** son **10** işlem (`GarageEditor.HISTORY`). **GERİ AL** düğmesi ya da **Ctrl+Z** ile. İşlem türleri: yerleştir, taşı (konum + yön), döndür, sil, kaplama.
- **Silme** geri alınınca eşya **aynı kimlikle** aynı yer ve yönde geri gelir.
- **Kayarak dönüş** tek taşıma işlemidir; tek GERİ AL yeri ve yönü birlikte geri getirir.
- **Oturum sınırı:** geçmiş BİTİR ile biter; kayıtlı düzenin üstüne eski oturumun işlemleri uygulanmaz.

## 11. Mobil kontroller

| Hareket | Sonuç |
|---|---|
| Eşyaya dokun | Seçilir. Aynı noktaya tekrar dokunulursa arkadaki eşya seçilir. |
| Eşyayı tek parmakla sürükle | Eşya taşınır, **kamera kıpırdamaz** |
| Boş zemini tek parmakla sürükle | Kamera kayar (pan) |
| İki parmak aç/kapa | Kamera yakınlaşır/uzaklaşır |
| Eşya sürüklerken ikinci parmak | Sürükleme biter: eşya geçerliyse yeni yerinde kalır, değilse eski yerine döner. Hayalet hayalet olarak bekler. Kalan parmak eşyayı yeniden kapmaz. |
| Paletteki kartı parmakla kaydır | Şerit kayar, kart basılmaz |
| Döndür / YERLEŞTİR / VAZGEÇ / DEPOYA KALDIR | Sekmelerin hemen üstündeki sabit çubuk (başparmak bölgesi) |

Mobil testte bulunan ve düzeltilen sorunlar:

1. **Palet parmakla kaymıyordu.** Kartlar `MOUSE_FILTER_STOP` olduğu için sürükleme kaydırma kabına ulaşmıyordu. Ölçüm: 12 kartlık şeritte 240 birim sürükleme, STOP ile 0, PASS ile 884 birim kaydırma. Kartlar PASS yapıldı. Kaydırma başlayınca kabın gönderdiği bildirim kartın basışını iptal ediyor, yani kaydırırken yanlışlıkla satın alma olmuyor. Şeridin paneli STOP oldu, dokunuş dünyaya sızmıyor.
2. **Eşya sürüklemenin başında kamera birkaç piksel kayıyordu.** Parmak yavaş hareket edince eşik (8 birim) aşılana kadarki hareketler kameraya gidiyordu. Kamera bu basışı hiç görmediği için onu eski bir basış noktasına göre sürükleme sanıyordu. Şimdi eşyaya basılıyken bütün hareket düzenleyicide kalıyor.
3. **Telefon oranında (19,5:9) denetim çubuğu garajın ön köşesini örtüyordu.** Kamera artık garajı arayüzün bıraktığı boş banda sığdırıyor. Bu bant başlık grubunun ve alt grup + çubuk yüksekliğinin gerçek minimum boylarından hesaplanıyor (`GarageEditScreen._view_band`).
4. **Küçük eşya telefonda küçük görünüyor** (≈3 mm). Düzenlerken kamera normalden daha yakına gelebiliyor (`EDIT_MIN_ZOOM` 1,5; normal oyunda 2,2) ve BİTİR normal sınırı geri koyuyor.

Denetim çubuğu artık mutlak konumlu değil: alt kabın (VBox) ilk çocuğudur. Önce seçili eşyanın üstünde
yüzüyordu, ama komşu eşyayı örtüp yanlış silmeye yol açıyordu. Plakaların dokunma alanı en az 72 tuval
birimidir (48 dp), `PlateButton._has_point` ile sağlanır.

## 12. PC kontrolleri

- **Fare:**
  - Sol tık seçer; sürükleme taşır; boş zemini sürükleme kamerayı kaydırır.
  - Tekerlek yakınlaştırır.
  - Palet şeridi tekerlekle ve kaydırma çubuğuyla kayar.
- **Klavye:**
  - **R** / **Shift+R**: döndür.
  - **Delete** / **Backspace**: depoya kaldır.
  - **Ctrl+Z**: geri al.
  - **Enter**: hayaleti yerleştir.
  - **ESC**: router üzerinden normal oyuna döner.
- **Test:** 1152×648'de gerçek fare ve klavye olaylarıyla denendi (`qa/garaj_editor_oyun.gd`, 13e adımı).

## 13. Performans

Ölçümler masaüstünde, 3. seviye garajda, 29 eşya varken alındı (`qa/garaj_gorsel_qa.gd`):

| İşlem | Süre |
|---|---|
| En yavaş yerleştirme (hayalet kur + boş yer ara + YERLEŞTİR), 29. eşya | 15,5 ms |
| Seçim (üçgen düzeyinde) | 0,17–0,28 ms |
| Gövde eşitleme (`refresh`) | 0,4–0,6 ms |

- **Tembel yükleme:** yalnızca garajdaki örnekler kurulur. Model ilk kez gerektiğinde yüklenir; normalleştirme ölçüsü eşya başına bir kez yapılır.
- **Artımlı eşitleme:** bir değişiklik bütün gövdeleri yeniden kurmaz; yeni örnek eklenir, silinen kaldırılır.
- **Küçük resimler:** tembel üretilir. Yalnızca paletin görünen kartları ister, kare başına 2 tane, statik önbellek; başsız çalışmada hiç üretilmez. Normal oyunda 14 kartlık sekme 20 karede doluyor.
- **Düzenleme görselleri** yalnızca düzenleme modunda var: ızgara, yasak alan örtüsü, seçim çerçevesi, hayalet. Normal modda hiçbiri kurulu değil.
- **Arama sınırı:** boş yer araması en çok 24 halka ile sınırlı; dolu bir garajda bütün alanı taramaz.
- **Seçim önbelleği:** seçimde `.glb` ağlarının üçgenleri önbellekte tutulur; en çok model sayısı kadar kayıt.

## 14. Test sonuçları

| Test | Sonuç |
|---|---|
| `tests/garage_decoration_placement_test.gd` (şartname §33, 24 senaryo) | **24/24 GEÇTİ**, 169 kontrol, 0 hata |
| `decor_test` (yeni modele göre yeniden yazıldı; eskisi `decor_test.gd.v8.bak`) | 118 kontrol, 0 hata |
| Tüm paket `tools/run_tests.sh` (14 paket) | **1.071 kontrol, 0 hata** |
| `qa/garaj_editor_oyun.gd -- kur` / `dogrula`, fare, 1152×648 | 0 hata / 0 hata |
| `qa/garaj_editor_oyun.gd -- kur dokun` / `dogrula dokun`, dokunmatik, 1170×540 | 0 hata / 0 hata |
| `qa/garaj_gorsel_qa.gd -- 3` | 0 hata |
| `qa/garaj_odak_qa.gd` (1170×540, §18) | 0 hata |

24 senaryo: 01 katalog · 02 spawn · 03 taşı · 04 döndür · 05 sil · 06 silinen depoya döner ·
07 çok kopya · 08 konum kaydı · 09 dönüş kaydı · 10 yüklemede konum · 11 yüklemede dönüş · 12 sınır ·
13 zemine oturma · 14 duvar verisi · 15 normal girdi etkilenmez · 16 düzenleme girdisi yalıtılır ·
17–20 geri al (yerleştir / taşı / döndür / sil) · 21 seviye büyümesi · 22 yeniden yüklemede yinelenme
yok · 23 geçersiz yerleşim reddi · 24 v8 taşıma. Test sonunda kendi GEÇTİ/KALDI tablosunu basar.

**Gerçek oynanış testi (§34).** Taze kayıtla, gerçek girdiyle şu sıra oynanır:

1. Garajı aç → GARAJI DÜZENLE.
2. Şezlong al (iki dokunuş), sürükle-bırak, taşı.
3. Döndür 45° / 90°.
4. İkinci şezlong (ayrı kimlik), sehpa, uyarı tabelası.
5. Sehpayı sil → depoya döner → geri al (aynı kimlik) → depodaki sehpayı başka yere koy.
6. Tamir alanına bırakmayı dene → eski yerine döner.
7. Pan; PC'de klavye ve tekerlek, mobilde pinch ve palet kaydırma.
8. BİTİR → çık → yeni süreçte aç → düzen birebir aynı (4 örnek, konum ±0,0002, yön ±0,01°).

Dünya tıklamalarının yalıtımı da aynı testte ölçülür: düzenlerken genişletme tabelasının ve tamir
alanının yerine dokunmak `expand_clicked` sinyalini hiç yaymadı (0). Fare yolunda ayrıca ESC ile çıkış
denenir (router üzerinden).

**Mobil test (§35):** yukarıdaki akışın tamamı dokunmatik olaylarla (ScreenTouch / ScreenDrag) koşar.
Ek olarak eşya sürüklerken ikinci parmakla pinch ve paleti parmakla kaydırma denenir. Masaüstünde
kaydırma kaplarının dokunmatik sürüklemeyi işlemesi için test `Input.emulate_touch_from_mouse`'u açar.

**Test altyapısı düzeltmesi.** `tools/run_tests.sh`, sonuç satırı olmayan (derlenemeyen, çöken, zaman
aşımına uğrayan) paketi artık **hata** sayıyor. Eski `decor_test` v9'dan sonra derlenmiyordu ama "0 OK
0 FAIL" gösterip toplamı 0 hata tutuyordu. Koşucu ayrıca paketi önce depodaki `tests/` klasöründe arıyor.

## 15. Görsel QA ve Car Town hissi (§37–§38)

`qa/garaj_gorsel_qa.gd` her gruptan temsilci eşyayı düzenleyicinin kendi yoluyla koyar:

| Grup | Eşyalar |
|---|---|
| Küçük | bidon, koni, yangın tüpü |
| Orta | dolap, lastik rafı, kompresör |
| Büyük | konteyner, araç lifti, su deposu |
| Uzun | bank, bariyer, kasis, duba sırası |
| Masa | sehpa, piknik masası, langırt |
| Sandalye | şezlong, kanepe |
| Tabela | uyarı, yön oku, park tabelası |
| Garaj eşyası | tezgâh, motor bloğu, tamirci figürü, motosiklet |
| Duvar | saat, poster, iki neon |

Önce sıkışık, sonra aralıklı dizilişte ölçer ve fotoğraflar. Görüntüler: `ct_shots/editor/qa/` (depo dışında).

| Bakılan | Sonuç |
|---|---|
| Zemine oturma / havada durma | 29 eşyada ve testte 66 zemin eşyasının hepsinde (0° ve 45°) taban zemin üstünde: gömülme < 0,001, havada durma < 0,004 |
| Dönme ekseni | İz ortası (0°'de kutu ortası konumda, sapma < 0,004) |
| Garaj dışı / duvara girme | Hiçbiri; sınır testi 12. senaryoda |
| Araç park yerine konma | Engel: garaj seviyesinin bütün tamir alanları (kilitli olanlar dahil) |
| Duvar yüzeyi | Duvar eşyasının arka yüzü duvara 0,002 boşlukla yaslı; iki duvarda da, 4. seviyede de |
| Seçilebilirlik (aralıklı) | 29/29 eşya görünen yüzeyinden seçiliyor |
| Seçilebilirlik (sıkışık) | Önce kutu ortasından 14/29. Hassas seçimden sonra görünen her eşya (26) seçiliyor. Tamamen örtülen 3 küçük eşya aynı noktaya 2–3 dokunuşta seçilip sürüklenebiliyor. |
| Kaplamalar | Karo zemin + tuğla duvar uygulandı; normal modda da görünüyor |

Görsel QA'da bulunup düzeltilenler:

- Kutu seçimi → üçgen seçimi.
- Art arda dokunuşla arkadaki eşyaya geçiş.
- Yasak alan örtüsü kilitli tamir alanının altındaydı.
- Duvara yaslı eşya dönemiyordu → kayarak dönüş.

**Car Town hissi (§38).** Car Town'ın "Edit Garage" modu ana ekrandaki garajın üstünde açılırdı:

- ızgaralı zemin
- satın alınabilir zemin ve duvar kaplamaları
- eşyayı döndürme
- depoya kaldırma ("Item Storage")

Buradaki düzenleyici aynı akışı izliyor:

- Mod aynı dünyada açılıyor; kamera garaja yumuşakça odaklanıyor, BİTİR eski görünüme döndürüyor.
- Arayüz oyunun geri kalanıyla aynı fiziksel plaka dilinde: krem plakalar, vida başları, turuncu vurgu. Modern bir uygulama düzenleyicisi gibi durmuyor.
- Ağır 3B tutamaç yok: seçim zeminde ince kehribar bir çerçeve.
- Geçersiz durum neon kırmızı değil, soluk kiremit rengi.
- Eşyalar izometrik bakışta okunuyor: 45° adımlar, gölgeler, küçük resimlerde dünya kamerasıyla aynı bakış yönü.

Car Town'dan bilinçli farklar:

- Eşyalar para üretmiyor; gider olarak garaj değerine yazılıyor. Bu mevcut ekonomi kararıydı, değişmedi.
- Eşyayı döndürmek yerinde sığmıyorsa bir iki göz kaydırıyor.

## 16. Değişen dosyalar

**Yeni:**

| Dosya | Açıklama |
|---|---|
| `decor/decorations.json` | Katalog verisi (74 kayıt) |
| `world/decor_area.gd` | Yerleşim geometrisi |
| `world/garage_editor.gd` | Düzenleme modu |
| `ui/hud/garage_edit_screen.gd` | Düzenleme arayüzü |
| `ui/hud/decor_thumbs.gd` | Palet küçük resimleri |
| `gameplay/decor_legacy_slots.gd` | v8 taşıma tabloları |
| `tests/garage_decoration_placement_test.gd` | 24 senaryo |
| `qa/garaj_editor_oyun.gd` | Gerçek girdi oynanış testi, fare + dokunmatik |
| `qa/garaj_gorsel_qa.gd` | Görsel QA |
| `qa/dekor_varlik_analizi.gd` | §2 tablosu |
| `qa/dekor_katman.gd`, `qa/garaj_geometri.gd` | Veri/geometri katmanı hızlı sınamaları |
| `world/garage_focus.gd`, `vfx/garage_focus.gdshader` | Düzenleme odağı (§18) |
| `qa/garaj_odak_qa.gd` | Odak, araç/balon gizleme ölçümü (§18) |
| `docs/garage_editor_report.md` | Bu rapor |

**Değişen:**

| Dosya | Değişiklik |
|---|---|
| `gameplay/garage_decor.gd` | JSON yükleyici; API korundu |
| `gameplay/decor_manager.gd` | Depo + örnekler + v9 kayıt + v8 taşıma |
| `gameplay/save_manager.gd` | `SAVE_VERSION` 9; yerleşim değişince otomatik kayıt |
| `gameplay/repair_bay_manager.gd` | `revealed_spots()`; kilitli alan fiyat plakası dünya plakası katmanında (§18) |
| `garage_system.gd` | Düzenleyiciyi kurar; tabela izi / gizleme |
| `world/garage_decor_view.gd` | Yeniden yazıldı: ölçüm, gövde eşitleme, geçerlilik, üçgen seçimi, düzenleme görselleri |
| `world_camera.gd` | `frame_box`, `restore_view`; dünya plakası katmanı `LAYER_WORLD_UI` (§18) |
| `vfx/car_bubble.gd` | Balon ve yazısı dünya plakası katmanında (§18) |
| `vfx/decor_builder.gd` | `build_placeable`, normalleştirme, `local_size`, `model_path` |
| `ui/hud/hud.gd` | GARAJI DÜZENLE plakası, router kaydı; eski pano yolu kaldırıldı; test derlemesi para kısayolu (§18) |
| `tools/run_tests.sh` | `tests/` klasörü, bitmeyen paket = hata |
| `export_presets.cfg` | `exclude_filter` = `"qa/*, tests/*"`; test betikleri APK'ya girmesin |
| `qa/dokunma_testi.gd` | GÖREVLER'in altındaki pay artık GARAJI DÜZENLE plakasının görünür alanı; pay testi sütunun en altındaki bu plakaya taşındı (4/4 geçti) |
| `docs/AUDIT_2026_09.md` | "Garaj avlusu boş" maddesi (#9, §10-1) bu rapora bağlanarak kapatıldı |

**Silinen (git rm):**

- `ui/hud/decor_panel.gd`
- `qa/decor_check.gd`
- `qa/lot_decor.gd`
- `qa/slot_clear.gd`
- ve her birinin `.uid` dosyası

**Depo dışında:** `~/snap/godot-4/common/cloudtest/decor_test.gd` yeni modele göre yazıldı. Eski sürümü
aynı klasörde `decor_test.gd.v8.bak` olarak duruyor.

Aynı çalışma ağacında bu işten önce yapılmış, henüz commit'lenmemiş **dokunma hedefleri** değişiklikleri de
var: `ui/hud/plate_button.gd`, `ui/hud/garage_screen.gd`, `qa/ui_audit.gd`, `docs/AUDIT_2026_09.md`
ve dokunma QA betikleri.

## 17. Kalan sorunlar

1. **Gerçek cihazda denenmedi.** Dokunmatik olaylar masaüstünde `Input.parse_input_event` ile üretildi. Telefonda parmak titremesi, çok hızlı sürükleme ve gerçek pinch hissi ayrıca denenmeli.
2. **Diğer kaydırma şeritleri.** Garaj ekranındaki araç şeridinde ve showroom listesinde kartlar muhtemelen hâlâ STOP (aynı kalıp). Palette ölçülen "parmakla kaymıyor" sorunu orada da olabilir; ölçülmedi, bu işin kapsamı dışında. Düzeltme aynı: kartlar PASS, altlarındaki panel STOP.
3. **Küçük eşya boyu.** Telefonda garajın tamamı sığdırılınca en küçük eşyalar (hava istasyonu, yangın tüpü: 0,05 × 0,03) birkaç milimetre kalıyor. Yakınlaşma, şişirilmiş seçim kutusu ve art arda dokunuş bunu karşılıyor; yine de gerçek cihazda bakılmalı.
4. **İşlevli eşya denenmedi.** Katalogda işlevli eşya yok (`functional: false`). `gameplay_scene` yolu hazır ama gerçek bir işlevli eşyayla sınanmadı.
5. **Araç / tamir alanı taşıma yok** (şartname gereği). Mimari buna açık (§3), ama yapılmadı.
6. **İlkel gövdeler.** 20 eşya hâlâ kodla kurulan ilkel gövde. Modelleri gelirse JSON'a `scene_path` yazmak yetiyor.
7. **Kategori adları.** Kaplama kategorileri "AVLU ZEMİNİ" / "GARAJ DUVARI" adını koruyor; garajın zemini oyunda avlu olarak geçiyor.
8. **`.uid` dosyaları.** Yeni betikler için (`tests/…`, `qa/garaj_*`, `qa/dekor_varlik_analizi.gd`) editör açılınca üretilecek. Elle oluşturulmadı.
9. **`export_presets.cfg`.** `tests/*` hariç tutma filtresi elle eklendi. Editörün Export penceresinde bir kez bakılmalı.

## 18. Telefon geri bildirimi (2026-09-29): düzenleme odağı

Test sürümü telefonda denendi. Geri bildirim:

- Düzenlerken yarış rakibinin 🏁 balonu önü kapatıyor.
- Tamirdeki araç önü kapatıyor.
- "Garaj ekranın ortasında olsun, diğer her şey silik / bulanık olsun."

Yapılanlar:

| Sorun | Çözüm |
|---|---|
| Garajın çevresi (yol, trafik, mağaza) garaj kadar göze batıyor | **Odak efekti** (`world/garage_focus.gd` + `vfx/garage_focus.gdshader`). Garajın ekrandaki dış çizgisinin dışı bulanıklaşır, rengini yitirir ve kararır; garaj ve eşyalar pikseli pikseline net kalır. Dış çizgi, garaj kutusunun (zemin, duvarlar ve en uzun eşyanın boyu) izdüşümünün dışbükey zarfıdır; kamera kaydıkça her kare güncellenir. Açılış ve kapanış 0,35 sn yumuşak geçişlidir. Katman dünya ile HUD arasında (5), yani düzenleme plakaları etkilenmez. Kapalıyken çizilmez. |
| Araç balonları (🔧 / ₺ / 🏁) ve kilitli tamir alanının fiyat plakası eşyaların önünde | Hepsi ayrı bir görüntü katmanında (`WorldCamera.LAYER_WORLD_UI`); düzenlerken kamera bu katmanı göstermez. Balonun araç mantığındaki görünürlüğüne dokunulmaz (tıklama kutusu ve durum makinesi onu kullanıyor). |
| Tamir alanındaki araç garajın içinde duruyor | Düzenlerken **bütün araçlar gizlenir**. Yoldakiler de gizlenir, çünkü yarış rakibi duruş noktasında tam garajın ön köşesinde bekliyor ve odak çizgisinin içinde net kalıyordu. Araç mantığı (trafik, tamir sayacı, ödül, davet) çalışmaya devam eder; BİTİR hepsini geri getirir. Görünmez araç gölge de düşürmez. |
| "Para yok, deneyemiyorum" | **Test derlemesi kısayolu:** sol üstteki paraya 1,5 sn basılı tutmak +10.000.000 ₺ ekler. Yalnızca debug derlemede kurulur (`OS.is_debug_build()`); sürüm derlemesinde yoktur. |

Ölçümler (`qa/garaj_odak_qa.gd`, 1170×540). Senaryo: rakip daveti açık, bir araç 1. tamir alanında.

- Düzenlemede:
  - Tamirdeki ve yoldaki araç gizli.
  - Balon katmanı kapalı; rakibin balonu mantıkta açık kalıyor.
  - Tamirin mantığı sürüyor.
- Odak aynı karede kapalı / açık ölçüldü:
  - Garajın dışı %46 koyulaştı; ayrıntı %40 azaldı (bulanıklık).
  - Garaj zemininin ortası birebir aynı kaldı (fark 0,0000).
- BİTİR sonrası: araçlar, balon katmanı geri geldi; odak katmanı kapandı.
- Görsel düzeltme: ilk sürümde duvarların arkasında net, parlak bir çimen şeridi kalıyordu. Geçiş kenara ortalandı ve pay duvarların gerçek dış yüzüne indirildi.

Para kısayolu gerçek girdiyle sınanır (`qa/garaj_editor_oyun.gd` 0. adım, fare ve dokunmatik): kısa dokunuş para vermiyor, 1,5 sn basılı tutmak 1.000.000 → 11.000.000.

---

## Kabul ölçütleri — GEÇTİ / KALDI

| # | Ölçüt | Sonuç | Kanıt |
|---|---|---|---|
| 1 | Ana izometrik dünyada gerçek düzenleme; ayrı sahne / sahte önizleme yok | GEÇTİ | §3; gövdeler `GarageSystem` altında, `.tscn` değişmedi |
| 2 | GARAJI DÜZENLE plakasıyla moda giriş | GEÇTİ | Oyun testi adım 2 |
| 3 | Ekle / seç / sürükle / döndür / sil / geri al / kaydet-çık | GEÇTİ | Senaryo 02–06, 17–20; oyun testi |
| 4 | Döndürme: düğme + R / Shift+R; adım testle seçildi (45°) | GEÇTİ | §5; oyun testi 7, 13e |
| 5 | Veri güdümlü katalog, eşya başına kod / sabit konum yok | GEÇTİ | Senaryo 01 (başka JSON, `scene_path`, `rotation_step`, `functional`) |
| 6 | Palet kategorileri mevcut veriden | GEÇTİ | Senaryo 01, 16 |
| 7 | Hayalet: geçerli / geçersiz, neon değil | GEÇTİ | §4; senaryo 23 |
| 8 | X/Z yerleşim, Y otomatik, zeminin altına inmez | GEÇTİ | Senaryo 13 (66 eşya × 2 yön) |
| 9 | Izgara aç/kapa, varsayılan açık | GEÇTİ | Senaryo 13 |
| 10 | Çakışma, garajda kalma, duvara girmeme | GEÇTİ | Senaryo 12, 23; görsel QA |
| 11 | Duvar eşyası duvara oturur | GEÇTİ | Senaryo 14; görsel QA |
| 12 | Çok kopya, her birine örnek kimliği | GEÇTİ | Senaryo 07, 22 |
| 13 | Kayıt biçimi (instance_id, catalog_id, position, rotation, scale) + eski kayıt taşıma | GEÇTİ | Senaryo 08–11, 24 |
| 14 | Depo: sahip / yerleşik / depoda | GEÇTİ | Senaryo 06; `decor_test` |
| 15 | İşlevli nesne ayrımı; mevcutlar bozulmadı | GEÇTİ (kısmen sınandı) | §3; katalogda işlevli eşya yok (§17-4) |
| 16 | Araçlar ve tamir alanlarına dokunulmadı, mimari taşımaya açık | GEÇTİ | Tamir alanları engel; §3 |
| 17 | Sınırlar garaj seviyesi 1–4'ü izler, `if level ==` yok | GEÇTİ | Senaryo 21 |
| 18 | Düzenlemede zoom / pan; eşya sürüklenirken kamera kıpırdamaz | GEÇTİ | Oyun testi 5, 6, 13b, 13c |
| 19 | Düzenlemede girdi yalıtımı (müşteri / araç / menü tıklanmaz) | GEÇTİ | Senaryo 16; oyun testi 3 (`expand_clicked` = 0) |
| 20 | Mevcut `ui_router` kullanıldı, yeni ESC sistemi yok | GEÇTİ | `router.register(&"garage_edit", …, PLACE)` |
| 21 | Arayüz ekranı kaplamıyor, Control + container ile | GEÇTİ | Denetim çubuğu alt kapta; kamera arayüzsüz banda sığdırılıyor |
| 22 | Performans: tembel yükleme, küçük resim, yalnızca yerleşik örnekler | GEÇTİ | §13 |
| 23 | Garaj değeri entegrasyonu, ekonomi değerleri değişmedi | GEÇTİ | `decor_test` 3–6 |
| 24 | §33 testleri (24 senaryo) | GEÇTİ | 24/24, 169 kontrol |
| 25 | §34 gerçek oynanış testi | GEÇTİ | `kur` + `dogrula`, 0 hata |
| 26 | §35 mobil test | GEÇTİ (masaüstü emülasyonu) | `dokun`, 1170×540, 0 hata; gerçek cihaz: §17-1 |
| 27 | §36 PC testi 1152×648 | GEÇTİ | Fare + klavye + tekerlek, 0 hata |
| 28 | §37 görsel QA, bulunan sorunlar düzeltildi | GEÇTİ | §15; 4 düzeltme |
| 29 | Tüm paket kırılmadı | GEÇTİ | 14 paket, 1.071 kontrol, 0 hata |
| 30 | §39 "yapma" listesi (ayrı dünya, ağır gizmo, kaynak GLB değişikliği, yeni ekonomi, HUD/router yeniden yazımı…) | GEÇTİ | Hiçbiri yapılmadı; kaynak `.glb`'lere dokunulmadı |
