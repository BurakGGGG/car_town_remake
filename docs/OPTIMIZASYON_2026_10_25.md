# Optimizasyon turu — 2026-10-25

İstek: "derin bir optimizasyon turuna çık, hataları çöz, iyileştir" (aynı gün şehre pişmiş gölge eklendikten sonra).
Ölçümler masaüstünde (Intel ADL, GL Compatibility, 1152x648); telefonda süreler ~5–8 kat. Paket boyutu §1–5'te
değişmedi (yeni görsel / mesh dosyası yok); §6'daki araç uzak kademesi kullanıcı onayıyla +4,67 MB.

## 1. Bellek sızıntısı (kritik hata) — `CarMeshMerger`

**Belirti** (`qa/sizinti_olcum.gd`): garaj ekranı her aç-kapa'da ~30 MB RAM + ~20 MB VRAM büyüyordu; bütün ekranlar
4'er kez açılıp kapanınca bellek 245 → 459 MB, VRAM 87 → 276 MB. Telefonda (2–4 GB) uzun oturum = bellekten çökme.

**Kök neden:** araç parçalarını birleştiren arka plan işi `WorkerThreadPool.add_task` ile başlıyor ama hiç
`wait_for_task_completion` çağrılmıyordu. Godot beklenmeyen görevin verisini SALIVERMEZ: göreve bağlı iş sözlüğü
(bütün parça dizileri + birleşik mesh) sonsuza dek bellekte kalıyordu. Yalnız garaj değil: trafikte önbellekte olmayan
her yeni araç modeli de aynı yoldan sızdırıyordu.

**Düzeltme:** görev kimliği saklanır, iş "yükleme" aşamasına geçince beklenir (görev bitmiştir, bekleme anında döner);
parça dizileri birleşmeden hemen sonra bırakılır. Ayrıca `CarRig._rigs` (boya değişikliğini yaymak için tutulan
kayıt) güçlü referanstan ZAYIF referansa çevrildi: silinen araçların rig'leri (materyaller, boya maskesi) yalnız boya
değişince ayıklanıyordu.

| | önce | sonra |
|---|---|---|
| garaj 4 tur aç-kapa sonrası bellek | 405 MB | 231 MB (sabit) |
| aynı, VRAM | 209 MB | ~127 MB (sabit) |
| bütün ekranlar 4'er tur sonrası bellek / VRAM | 459 / 276 MB | 251 / 152 MB |

## 2. Statik toplu çizim — `world/static_batch.gd` (StaticBatch), `vfx/static_batch(_double).gdshader`

Dekorlu kayıtta 67 eşya 187 çizim çağrısı (yalnız 16 bin üçgen); 248 yüzeyin 112 farklı materyali var.
- Dokusuz, opak, varsayılan ayarlı StandardMaterial3D yüzeyleri TEK mesh'te: renk köşe rengine, pürüz / metaliklik
  UV2'ye, specular köşe alfasına (aynı ışık modeli). Çift yüzlüler (cull kapalı) ayrı yüzeyde ayıklamasız shader'la.
- Kalanlar (dokulu, ışık saçan) materyal başına bir mesh; saydam yüzeyli parçalar olduğu gibi kalır.
- Kaynağın gölge ayarı korunur (showroom salonu gölge yazmaz, toplu çizim de yazmaz).
- `build()`: asıl parçalar silinmez, `layers = 0` ile çizimden çıkar: dokunarak seçme, kutular, düzenleyici aynen çalışır.
- `merge_surfaces()`: tek mesh'in yüzeylerini birleştirir (showroom binası 23 → 7 yüzey; otoparkın zemin yüzeyleri, cam,
  ışık bandı ayrı).

Kullanım yerleri: garaj dekoru (düzenleme / zemin odağında kalkar), şehir peyzajında bank / çit / çiçeklik (LOD'lu ağaçlar
HARİÇ: birleşince hep en detaylı kademede çiziliyordu, şehirde 21 bin → 53 bin üçgen ölçüldü), showroom binası, showroom
ekranının salonu (döner platform, araç altı gölge ve saydam parıltı hariç).

Görüntü: önce / sonra piksel kıyasında fark yalnız hareket eden trafikte ve çift yüzlü çalı yapraklarında hafif ton
(`QA_TOPLUSUZ=1 tools/qa_isolated.sh res://qa/gorunum_lab.gd ...`). Test: `tests/decor_batch_test.gd` (pencereli).

**GL Compatibility notu:** ALBEDO sRGB uzayındadır — motor ışıklandırmadan önce `srgb_to_linear` uygular
(drivers/gles3/shaders/scene.glsl); `source_color` uniform'ları da CPU'da çevrilmez. Köşe rengi doğrudan verilir.

## 2b. HUD toplu 2B çizimi — `ui/hud/tri_batch.gd` (TriBatch)

Compatibility'nin 2B çizicisi her poligonu / kenar yumuşatma şeridini ayrı çizim çağrısı yapıyor: HudIcon ikonu 3–12
çağrı, alt sıradaki plaka 17 (11'i ikon, 4'ü cıvata). TriBatch, CanvasItem'ın draw_circle / line / polyline / arc /
colored_polygon / rect / dashed_line çağrılarını aynı imzalarla alıp tek üçgen dizisinde toplar; geometri Godot 4.7'nin
kendi tessellation'ının kopyası (kenar yumuşatma 1,25, kalın çizgi telafisi, köşe birleşimleri, StyleBoxFlat yuvarlak köşe).
`qa/hud_icon_sheet.gd`: 176 ikon 1017 → 173 çağrı, önce / sonra en büyük piksel farkı 1/255. PlateButton cıvata + ikon +
rozet dairesi tek dizide: plaka 17 → 3 çağrı. Avatar halkası (statik çerçeveler) de tek dizide. **HUD 185 → 70 çağrı**
(`qa/hud_draw_census.gd`).

## 2c. Toplam çizim çağrısı (perf_bench, önce → sonra)

| senaryo | dekorlu kayıt | geliştirme kaydı |
|---|---|---|
| dünya (varsayılan kamera) | 530 → 226 | 331 → 188 |
| garaj ekranı | 125 → 71 | 618 → 405 |
| showroom | 362 → 309 | 374 → 291 |
| koleksiyon | 494 → 267 | 268 → 227 |
| görevler | 547 → 312 | 317 → 262 |
| garaj düzenleme | 646 → 531 | 338 → 223 |
| tamir sürerken | 589 → 269 | 359 → 214 |

## 3. Ekran açılış takılmaları ve birleştirme yükü

| | önce | sonra | nasıl |
|---|---|---|---|
| Koleksiyon ilk açılış, araç resimleri | 72 resim ana iş parçacığında (31 ms) | 3 ms | `CarGallery._use_baked` resmi arka planda yükler (ResourceLoader iş parçacığı), gelince plakalar yenilenir |
| Koleksiyon ilk açılış, open() | 33 ms | 7 ms | ilk 2 bölüm hemen, kalan bölümler kare başına bir |
| Koleksiyon sonraki açılışlar | 27 ms | 2 ms | içerik özeti (dil + araç durumları) aynıysa 72 kart yeniden kurulmaz |
| Görevler açılışı (başarımlar) | ~44 ms | 8 ms + sonraki karelere yayılır | ilk 8 plaka hemen, kalanı kare başına 8 |
| Garaj açılışı en uzun kare | 103 ms | ~65 ms → ~20 ms (§7) | `GarageInteriorView` 13 aracı tek karede değil kare başına 1 kurar (kameraya yakın önce; odak / boya önizlemesi isterse hemen). Kalan ~65 ms'lik karenin nedeni §7'de (shader yeniden derlemesi) |
| Garaj açılışı sonrası birleştirme (1. / 2. açılış) | 485 / 357 kare (2,8 / 2,1 sn) | 165 / 14 kare | aşağıda |
| Drag yarışı açılışı sonrası birleştirme | 131 kare | 13–15 kare | aşağıda |

**Birleştirme yükü** (`qa/birlesim_olcum.gd`): CarMeshMerger parçaları GPU'dan geri okuyor (Compatibility:
glGetBufferSubData / glMapBufferRange); her okuma sürücüyü GPU'nun sıradaki işini bitirmesini beklemeye zorluyor. Kare
bütçesi (2 ms) bu beklemeyi de saydığı için her karede tek parça okunuyor, model başına 40–60 kare senkron oluyordu.
Bütçe artık ilk okumadan (bekleme ödendikten) sonra başlıyor: aynı karede birkaç parça okunur. Önbellek de kaliteye göre:
DÜŞÜK 8, ORTA 12, YÜKSEK 16 model (garajda 13 model var; 8'de her açılışta 5+ model yeniden birleşiyordu).

Boya ile yükleme yarışı: resim yüklenirken araç boyanırsa fabrika resmi kullanılmaz (render'a düşer).

## 3b. Gölge haritası: bölge pişirmesi ve disk önbelleği
Dekor / tamir alanı değişince bütün harita değil, yalnız garaj parselinin (pay ile) izdüşümünü kapsayan piksel dikdörtgeni
yeniden çizilip haritanın CPU kopyasına yapıştırılır (o dikdörtgene izdüşen bütün dökücülerle). Ana iş parçacığı: bütün
harita 15,5 ms → bölge 6,9 ms (masaüstü); geri okunan görüntü ~124×125 (1024² yerine). `tests/world_shadow_test.gd`: bölge
sonucu bütün haritanın yeniden pişirilmesiyle piksel piksel aynı. Disk yazması 2 sn ertelenir (uygulama arka plana
geçerken / kapanırken hemen).

`WorldShadow` haritayı `user://world_shadow.bin`'e (1 MB) haritayı belirleyen durumun özetiyle yazar (dekor örnekleri +
duvarlar, garaj seviyeleri, tamir alanları, güneş, boyut, sürüm). Açılışta durum aynıysa yeniden çizilmez: açılıştaki
pişirme karesi 226 → ~150 ms (gölgesiz hâldeki düzey). Showroom materyalleri GLB'de "SR_" önekli — otoparkın zemin
yüzeyleri bu yüzden tanınmıyordu (gölge almıyor, haritaya blok olarak çiziliyordu); düzeltildi (`is_showroom_ground`).

## 4. Hata avı
- Ekran taraması (p16x9, ~100 durum): betik hatası yok. Kalan "çakışma" satırları bilinçli: ders kartı ikaz şeridi,
  yarış süresi / rekor, avatarın bayrak rozeti (yarış daveti ekranları).
- Bugatti Veyron'un parça haritası iki büyük parçayı far rolüne koyuyordu (çalışma anında elenip her oturumda uyarı
  basılıyordu): haritadan çıkarıldı, görünüm aynı.
- `qa/crate_playthrough.gd` HEAD'de de takılıyor: betik, öndeki kasanın örttüğü kasaya tıklıyor (oyun hatası değil;
  `tests/crate_test`, `welcome_crate_test` geçiyor).

## 5. Bakılıp yapılmayanlar
- Araç uzak LOD'u ve garaj iç mekânının arka planda yüklenmesi: kullanıcı onayıyla yapıldı (§6, §7).
- Trafik aracı havuzlama: doğuş masaüstünde 1,7 ms (`qa/trafik_dogum_olcum.gd`), riskine değmez.
- Kare başı betik: dünyada ~0,25 ms/kare (profilleyiciyle); her karede yeniden çizilen arayüzler yalnız eğitim / açılır
  pencerelerde.

## 6. Araç uzak kademesi (kullanıcı onayı: "3ü de yap") — `vehicles/car_far_lod.gd`, `tools/far_lod/`

**Sorun:** sergi araçları dünyada üçgenlerin %80+'ı. İçe aktarıcının LOD zinciri parça kenarları KİLİTLİ
(SIMPLIFY_LOCK_BORDER) üretiliyor; Tripo parçaları açık kabuk olduğu için sapma sınırı araç boyunun %0,4'ü olsa bile
4,50 → 3,94 milyon üçgene inebiliyor (74 araç, teker hariç), en kaba kademe 19–61 bin üçgende tıkanıyor.

**Çözüm:** her parça çevrimdışı, kenar kilitsiz + "permissive" (öznitelik dikişlerinin üstünden de çöker) meshoptimizer
ile MUTLAK sapma sınırına (araç boyunun %0,4'ü, 4,4 m araçta ~1,8 cm; normal toleransı 0,01) sadeleşir: aynı sınırda
3,94 → **1,77 milyon** üçgen (−%55). Yalnız İNDEKSLER saklanır (köşeler içe aktarılmış mesh'in kendisi): araç başına bir
`CarFarLod` kaynağı (`assets/cars/far_lod/<model>.res`), 16 bit fark + zigzag kodlu, zstd-19 tek blok — **toplam 4,67 MB**.
- **Yalnız şehir araçları** (`CarRig.optimize(…, far_lod = true)`: trafik, dekor sergisi, kasa, hurdalık). Kenarlar
  kilitsiz olduğu için parçalar arasında ≤ sapma kadar çatlak açılabiliyor: ekranda büyükçe duran araçta aracın koyu içi
  benek benek görünüyordu. İlk sürümde garaj / otopark da alıyordu — oradaki uzak araçlar ekran boyutundan bağımsız zorla
  en kaba kademede (lod_bias 0) çizildiği için ~200 piksellik araçlar lekeli ve benekliydi (kullanıcı: "otoparkta araçlar
  uzaktan çok kötü duruyor"). Garaj, otopark, showroom, yarış, modifiye artık eskisi gibi (otopark görüntüsü uzak
  kademeden önceki hâliyle piksel piksel aynı, `qa/garaj3d_shot.gd waiting 1`, `QA_UZAKSIZ=1` ile kıyas).
- Normal toleransı 0,01: 0,05'te Tripo'nun gürültülü normalleri büyüyen üçgenlerde koyu lekeye dönüyordu (+1,2 MB).
- `CarMeshMerger` birleşik mesh'e kademeyi KENDİ sapma eşiğinde koyar (× `CarFarLod.SWITCH_MARGIN` = 2): bu eşikten büyük
  içe aktarıcı kademeleri düşer. En sonda eski en kaba kademe kalır. Pay 2: paysız kademe şehrin en yakın zoom'unda
  (araç ~250 piksel) seçiliyor, Lambo'nun yanında / Golf'ün kaputunda 1–2 piksellik iz bırakıyordu.
- Tekerler YOK: kenar kilitsiz kademe lastikte boşluk açıyordu (`qa/teker_tarama.gd lod=0 merge`: dıştan 10 → 14,
  içten 36 → 45 satır); kenar kilitli + sıkı sapmayla araç başına yalnız −%5–7 üçgen, +0,55 MB — değmez
  (`FAR_LOD_WHEEL_ERROR` ile denenebilir, varsayılan kapalı). Son hâlde lastik taraması tabanla birebir aynı.
- Köşe sırası doğrulanır (köşe sayısı + ilk köşe): model yeniden içe aktarılıp sıra değişirse parça kademeyi kullanmaz;
  `tests/far_lod_test.gd` eskimiş dosyayı FAIL verir → `tools/far_lod/make_far_lod.sh <araç_id>`.
- Dosya önbelleği (son 8): önbelleksiz her parça dosyayı yeniden yüklüyordu (garaj açılışında 123 parça ~41 ms).

| üçgen (perf_bench, dekorlu kayıt) | önce | sonra |
|---|---|---|
| dünya (varsayılan kamera) | 497k | 324k |
| dünya (en uzak zoom) | 578k | 400k |
| koleksiyon / görevler (dünya arkada) | 560k / 593k | 361k / 404k |
| garaj düzenleme | 487k | 325k |
| tamir sürerken | 721k | 430k |
| garaj ekranı, showroom, drag | — | değişmez (uzak kademe yok) |

Çizim çağrısı ve birleştirme yükü değişmedi (`qa/birlesim_olcum.gd` QA_UZAKSIZ ile kıyas, fark gürültü içinde).

## 7. Garaj açılışı — shader yeniden derlemesi + iç mekânın arka planda yüklenmesi

**Ölçüm** (`qa/garaj_acilis_olcum.gd`, kare çizim / süreç ayrımı): açılıştan sonraki ilk tam ÇİZİM her açılışta
41–52 ms. Eleme: iç mekân gizliyken 13–17 ms; MSAA / gölge etkisiz. **Neden:** `BaseMaterial3D` aynı ayarlı son
materyal silinince shader'ını da siler; iç mekân kapanınca bütün materyalleri gidiyor, her açılışta dört shader
yeniden derleniyordu. (Önceki notta "her açılışta ~25 MB doku yükleniyor" yazıyordu: açılış başına +26 MB'ın çoğu
çizim hedefi + MSAA tamponları; iç mekânın dokusu ~5 MB, yüklemesi masaüstünde ~9 ms.)

- `GarageInterior` her materyal türünün DOKUSUZ ikizini statik tutar (shader anahtarı dokuya bağlı değil, dokular yine
  kapanışta bellekten çıkar); ilk derleme oyun yüklenirken (`GarageInterior.prewarm_nodes` → `GarageScreen.prewarm`).
- Dosyalar arka planda, paralel (`ResourceLoader.load_threaded_request`): sahne + o seviyelerde görünen dokular. Gizli
  seviyelerin zemin gölgeleri (her kalemde 2–3) artık hiç yüklenmez, görünür olunca yüklenir.
- **DEPOLARIM'da garaj seçilince** iç mekân dosyaları arka planda yüklenmeye başlar (`GarageInterior.prefetch`); GİT'e
  basılınca ana iş parçacığında yalnız sahne kurulumu kalır. Pano kapanınca bırakılır (kare sonunda: UiRouter garaj
  ekranını açmadan önce panoyu kapatıyor).
- `GarageScreen._set_title` her açılışta `find_child` ile bütün ekran ağacını tarıyordu: başlık düğümü saklanır.

| garaj açılışı (geliştirme kaydı) | önce | sonra |
|---|---|---|
| açılıştan sonraki en uzun çizim | 41–52 ms (her açılış) | ~3 ms (soğuk ilk açılış 14 ms) |
| open() — doğrudan | 27–42 ms (soğuk 52–60) | 26–30 ms (soğuk ~52) |
| open() — DEPOLARIM → GİT | aynı | 19–22 ms (soğuk 26–29) |
