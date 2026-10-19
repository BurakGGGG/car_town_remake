# Araç mesh / doku bütçesi — ölçüm ve iyileştirme payı (2026-09-28)

Soru: "araçlar 500k üçgen, Blender'a alıp düz yerlerdeki üçgenleri azaltsak boyut düşer mi?"
Kısa yanıt: **evet, ve mesh gerçekten en büyük kalem** — ama kazanç üçgen SİLMEKTEN değil,
kopya vertex'leri birleştirmekten ve kullanılmayan tanjantı atmaktan geliyor.

## 1. Bugünkü durum

Oyuna GLB değil, **içe aktarılmış** kaynak girer. Android'e iki doku formatından yalnızca
`etc2` gider (`s3tc` masaüstü içindir, APK'ya girmez).

| kalem | 16 araç | araç başına |
|---|---|---|
| mesh (`.scn`) | **75,7 MB** | 4,73 MB |
| doku, Android (`etc2.ctex`) | **42,7 MB** | 2,67 MB |
| boya maskesi | 0,8 MB | 0,05 MB |
| _(doku, masaüstü `s3tc` — APK'ya girmez)_ | _(42,7 MB)_ | _(2,67 MB)_ |

Yani Android araç maliyetinin **%64'ü mesh**. (APK 180,4 MB'tı; "Play sınırı 150 MB" varsayımı yanlış çıktı, bkz. §7.)

## 2. Kaynakta ne var

Tripo modelleri binlerce **kopuk geometri adasından** oluşuyor:

| araç | kaynak üçgen | kaynak vertex | v/ü |
|---|---|---|---|
| bmw_e46 | 478.606 | 360.673 | 0,75 |
| audi_a3 | 470.855 | 373.987 | 0,79 |
| renault_r12 (Toros) | 971.345 | 620.222 | 0,64 |

BMW E46'da **14.326 kopuk ada** sayıldı. Sağlıklı bir mesh'te v/üçgen ≈ 0,5 olur; sadeleştirme
sonrası ÇIKTIDA bu oran **0,99'a** çıkıyor — çünkü meshoptimizer ada SINIRLARINI çökertmez,
geriye kalan vertex'lerin neredeyse hepsi sınır vertex'i oluyor. Sadeleştirici erken tıkanıyor.

## 3. Ölçülen üç kaldıraç

Hepsi `bmw_e46` üzerinde, İÇE AKTARILMIŞ boyutla ölçüldü (APK'ya giren sayı):

| | mesh | doku (etc2) | not |
|---|---|---|---|
| **şimdiki** | 4,80 MB | 2,67 MB | 116.750 üçgen |
| + kaynaştırma (0,9 mm) | 4,18 MB | — | 99.702 üçgen, **görsel fark yok** |
| + tanjant atma | **3,14 MB** | — | **görsel fark yok** |

> **DÜZELTME (aynı gün, uygulama sırasında):** yukarıdaki iki satırdaki 99.702 üçgen ve
> 3,14 MB değerleri GEÇERSİZ. O deneydeki kaynaştırılmış GLB'de parça adları Blender ad
> çakışması yüzünden `tripo_part_0.001` biçimindeydi; `--map` eşleşmediği için DETAIL_ROLES
> parçaları (far, stop, jant, ızgara) 2x koruma almadı ve fazladan sadeleşti. Adlar
> düzeltilince aynı araç 119.642 üçgen / 3,77 MB veriyor. Filo geneli sonuçlar §5'te.
| + doku 1024² | 3,14 MB | **0,67 MB** | yakın planda **görünür bozulma** |
| (agresif sadeleştirme, oran 0,06) | 2,1 MB | — | 53.320 üçgen, **kaporta çöküyor** |

### 3a. Kaynaştırma — DENENDİ, BIRAKILDI (bkz. §5)
`bmesh.ops.remove_doubles` 0,0002 (model 1,0'a normalize → ~0,9 mm) ile aynı noktadaki kopya
vertex'leri birleştirir. **Üçgen silmez** (478.606 → 478.488), yalnızca kopyaları atar. Özel
bölünmüş normaller korunduğu için gölgeleme değişmez. Altı araçta ölçüldü, hepsi tutarlı:

```
bmw_e46       vertex -30,9%      audi_a3       vertex -34,1%
hyundai_getz  vertex -31,4%      seat_leon     vertex -34,4%
tofas_sahin   vertex -30,5%      vw_golf_7     vertex -33,5%
```

Yan etkisi: sadeleştirici artık ada sınırına takılmadığı için aynı oranda **%15 daha az üçgen**
üretiyor (116.750 → 99.702) ve görüntü aynı kalıyor.

### 3b. Tanjant — tamamen boşa giden 16 bayt/vertex
Kaynak GLB'lerde tanjant YOK. Godot'un glTF yükleyicisi UV gördüğü için üretiyor; diziden
silmek işe yaramıyor, `ArrayMesh.add_surface_from_arrays` geri ekliyor.
`.glb.import`'taki `ensure_tangents=false` yalnızca EKSİKSE üretmeyi engeller, var olanı atmaz —
bu yüzden içe aktarılmış mesh'te de duruyor (ölçüldü). Oyunda hiçbir materyal normal map
kullanmıyor, yani veri hiç okunmuyor.

Çözüm: `tools/strip_tangents.py` — GLB'yi ayrıştırır, TANGENT özniteliğini atar, tamponu
yeniden kurar (yetim bufferView bırakmaz). Tek araçta GLB 6,33 → 4,71 MB.

### 3c. Doku 1024² — ödünleşmeli, önerilmez
Oyundakinin iki katı ölçekte yan yana bakıldığında 1024 gözle seçiliyor: arka cam ve kaporta
lekeleniyor, stoplar bulanıklaşıyor (`ct_shots/kiyas/doku.png`). Oyun ölçeğinde fark çok
küçülüyor ama sıfır değil. Ara basamak (1536²) denenmedi.

> **2026-10-17 GÜNCELLEME — uygulandı.** Bu kıyas masaüstü penceresinde ve iki kat büyütmede yapılmıştı.
> Telefonda garaj / showroom SubViewport'u yalnızca ~1067x480 çiziliyor; o çözünürlükte ölçülünce 2048'in
> en ince mip'i neredeyse hiç okunmuyor ve 1024² ile fark gözle seçilmiyor. 1536² ise 1024'ten KÖTÜ
> çıktı. Ayrıntı: "Paket boyutu 2".

### 3d. Agresif sadeleştirme — önerilmez
Kaynaştırılmış kaynakta oran 0,06'ya inince 53.320 üçgen çıkıyor ve **kaporta bozuluyor**:
arka kapı/çamurluk çöküyor, marşpiyel kırılıyor (`ct_shots/kiyas/kiyas.png`). Hasar küçük
parçalardan değil, gövde kabuğundan geliyor; `--min-tris 300` küçük parçaları zaten koruyor.
Oran 0,04 ile 0,06 aynı sonucu veriyor — LOD zinciri ve min-tris taban oluşturuyor.

## 4. Filoya uygulandı — gerçek sonuç

16 aracın hepsi yeniden üretildi (`tools/rebuild_cars.sh`). İçe aktarılmış, yani APK'ya giren
boyutlar:

| | önce | sonra | fark |
|---|---|---|---|
| araç mesh | 75,65 MB | **65,59 MB** | **−10,1 MB (−%13,3)** |
| doku (android etc2) | 42,67 MB | 42,67 MB | — |
| **Android araç toplamı** | **119,0 MB** | **109,0 MB** | −10,1 MB |

Geometri denetimi **16/16 PASS**, test paketi **895 kontrol / 0 hata**, boya maskeleri sağlıklı
(aday texel 126k–623k, ölçülen fabrika rengi haritadakiyle eşleşiyor), görsel karşılaştırmada
fark yok (`ct_shots/kiyas/`, `ct_shots/wheels/`, `ct_shots/onden/`).

Pipeline'a eklenen tek adım, optimize'dan sonra çalışan `python3 tools/strip_tangents.py <glb>`;
tamamı `tools/rebuild_cars.sh` içinde.

## 5. Kaynaştırma: negatif sonuç

§3a'daki "bedava kazanç" beklentisi **doğrulanmadı**. Kaynaştırma kopya vertex'leri gerçekten
siliyor (kaynakta −%13…−%35) ama sadeleştiriciden SONRAKİ sonuç daha büyük çıkıyor: daha iyi
bağlantılı mesh'te meshoptimizer'ın LOD zinciri farklı basamaklar üretiyor ve
`_simplify_surface` hedefin üstündeki en küçük basamağı seçtiği için daha yüksek bir seviyeye
düşüyor.

`bmw_e46`, içe aktarılmış mesh:

| varyant | üçgen | vertex | mesh |
|---|---|---|---|
| eski (tanjantlı) | 116.750 | 117.943 | 4,80 MB |
| kaynaştırılmış + tanjantsız | 119.642 | 121.860 | 3,77 MB |
| **ham kaynak + sadece tanjantsız** | 116.750 | 117.943 | **3,63 MB** |

Görsel olarak da ayırt edilemiyorlar (`ct_shots/kiyas/oncesonra_bmw_e46.png`, oyundakinin iki
katı ölçekte).

Filo geneli ölçüldüğünde fark **gürültü düzeyinde**: kaynaştırılmış toplam 65,04 MB, ham kaynak
65,59 MB. Ama araç bazında ±%25 oynuyor (seat_leon 4,27 vs 5,25; bmw_e60 4,72 vs 3,50) — çünkü
`_simplify_surface` hedefin üstündeki en küçük LOD basamağını seçiyor ve basamaklar iki mesh'te
farklı yerlere düşüyor. Yani buradaki asıl kayıp kaynaştırma değil, **LOD basamaklarının kaba
olması**; meshoptimizer'ı tam hedefe sadeleştirmeye zorlamak (LOD zinciri yerine doğrudan
`simplify`) araç başına 0,5–1 MB daha kazandırabilir — ölçülmedi.

Sonuç: **kaynaştırma adımı pipeline'dan çıkarıldı** (fazladan Blender bağımlılığına değmiyor),
kazancın tamamı tanjant atmaktan geliyor. `tools/decor/mesh_kaynastir.py` ölçüm kaydı olarak
duruyor, kullanılmıyor.

Yan bulgu: ilk kaynaştırma denemesinde Blender ad çakışması yüzünden parçalar
`tripo_part_0.001` adını almıştı. `--map` eşleşmediği için DETAIL_ROLES parçaları (far, stop,
jant, ızgara) 2x korumayı kaybetti ve fazladan sadeleşti — o yüzden ilk ölçüm yanıltıcı biçimde
küçük çıktı (99.702 üçgen / 3,14 MB). `mesh_kaynastir.py` artık ad çakışmasını yakalayıp o aracı
atlıyor; bu sessizce her aracın rollerini bozabilecek bir hataydı.

## 6. Yapılmayanlar

- **Doku 1024²:** ek ~32 MB getirir ama oyundakinin iki katı ölçekte gözle seçiliyor (arka cam
  ve kaporta lekeleniyor, `ct_shots/kiyas/doku.png`). 1536² ara yol denenmedi.
  *(2026-10-17: telefon çözünürlüğünde yeniden ölçüldü ve uygulandı — "Paket boyutu 2".)*
- **Sadeleştirme oranını düşürmek:** 0,06'da kaporta çöküyor (arka kapı/marşpiyel kırılıyor).
- **Vertex sıkıştırma:** içe aktarılmış mesh'lerde `COMPRESS_ATTRIBUTES` kapalı; açılırsa normal
  ve UV küçülür, ölçülmedi.
- **LOD basamağı yerine tam hedefe sadeleştirme:** §5'e bakınız, araç başına 0,5–1 MB.

## 7. APK boyutu Play için engel DEĞİL (2026-09-28)

Mesh küçültmesinden sonra debug APK **175,6 MB** (arm64). Dökümü:

| kalem | APK içinde | sıkıştırılmış (≈ indirme) |
|---|---|---|
| motor `.so` | 74,2 MB | **24,8 MB** |
| araç mesh `.scn` | 66,1 MB | **65,2 MB** |
| doku (etc2) | 44,4 MB | 27,0 MB |
| diğer | 18,8 MB | 7,1 MB |
| **toplam** | 203,4 MB (açık) | **~124 MB** |

- **Sınır:** denetimdeki "Play 150 MB" varsayımı güncel değil. APK yüklemesi 100 MB ile sınırlı ve
  yeni uygulamalar AAB zorunlu; AAB'de sınır taban modülün cihaz başına SIKIŞTIRILMIŞ indirme
  boyutudur — eski kaynaklarda 200 MB, güncel resmî sayfada 500 MB. ~124 MB ikisinin de altında.
  Kaynak: <https://support.google.com/googleplay/android-developer/answer/9859372>
- **Motor:** `.so` APK'da mmap için sıkıştırılmadan durduğu için büyük görünüyor; indirmede %67
  küçülüyor. Release şablonu yalnızca 4,85 MB kazandırıyor (72,88 → 68,03) — hata ayıklama sembolü
  yok, boyut koddan geliyor. Şablon **mono** sürümü (.NET köprüsü içeride), proje C# kullanmıyor;
  standart şablona geçmek biraz daha kazandırabilir, ölçülmedi.
- **Mesh artık indirmenin en büyük kalemi (%53)** ve neredeyse hiç sıkışmıyor (66,1 → 65,2).
  Yani mesh'teki her MB kazanç indirmeye birebir yansır; §5'teki "LOD basamağı yerine tam hedefe
  sadeleştirme" (araç başına 0,5–1 MB) bu yüzden en verimli sonraki adım.

Sürüm için yapılacak tek zorunlu şey derlemeyi **AAB** olarak almak (`export_presets.cfg`,
`gradle_build/export_format`). Bu, Play hesabına bağlı bir **yükleme anahtarı** gerektirir —
kalıcı bir kimlik olduğu için sahibi tarafından oluşturulmalı.

---

## Paket boyutu (2026-10-05)

Ölçüm: release APK, arm64 (MiB, APK içindeki sıkıştırılmış boyut; native kütüphane sıkıştırılmadan durur).

| Kalem | Önce | Sonra | Not |
|---|---|---|---|
| Araç + dekor modelleri | ~92 | 50,0 | Teğet ve ayrı gölge mesh'i artık üretilmiyor |
| Dokular | 38,8 | 37,2 | Boya maskeleri pakette değil (boya MVP'de kapalı) |
| Motor (libgodot_android.so) | 66,4 | 49,6 | Projeye özel derlenmiş motor, aşağıda |
| Java (Firebase, AdMob) | 9,4 | 9,4 | R8 küçültme kapalı |
| Diğer | 4,5 | 4,4 | `tools/`, `locale/strings.json` hariç |
| **APK** | **~215** | **152,1** | AAB (Play'e giden): 118,9 MiB |

**Kayıpsızlık (modeller):** 22 araç gölgeli güneş altında önce/sonra çizildi. 1,2 milyon pikselin 88'i farklı
çıktı; bunlar tek tük gölge kenarı pikselleri, gözle görülmüyor. Teğetler yalnızca normal haritası için gerekir:
araç malzemelerinde ve shader'larda normal haritası yok. Ayrı gölge mesh'i yalnızca gölge geçişini hızlandıran
bir kopyadır. LOD'lar BİLEREK duruyor: trafikteki uzak araçları hızlandırıyorlar; kapatılsaydı araç başına
~1 MB daha kazanılırdı.

### Özel motor (tools/engine/)

`tools/engine/build_engine.sh` Godot 4.7.2 kaynağından Android release şablonunu (arm64) derleyip
`android/build/libs/release/godot-lib.template_release.aar` içindeki `.so`'yu değiştirir. Resmi aar
`~/godot-build/out/` altında saklanır; `--restore` geri koyar. **android/ git'te değil:** editörden
"Android Build Template" yeniden kurulursa `tools/engine/build_engine.sh --install` çalıştırılmalı, yoksa
paket sessizce resmi (büyük) motora döner. Debug şablonuna dokunulmadı (`--export-debug` resmi motoru kullanır).

Çıkarılanlar (`autoyard_profile.py`): Vulkan / RenderingDevice çizicisi (oyun GL Compatibility), XR, 2B/3B
navigasyon, 2B fizik, Godot 3B fiziği (oyun Jolt), GridMap, ağ (ENet/WebRTC/WebSocket/UPnP/JSON-RPC),
video, MP3, etkileşimli müzik, gürültü, kamera, GLTF/FBX çalışma anı yükleyicisi, yedek metin sunucusu,
MSDF, Basis/DDS/KTX/TGA/BMP/HDR yükleyicileri, VHACD, VisualShader, .NET. **Kalanlar ve nedenleri:**
CSG (Main.tscn ve şehir dekoru), SVG (varsayılan tema ikonları çalışma anında SVG'den çiziliyor), RegEx
(AdMob eklentisi `plugin_version.gd`), ZIP, JPG/WebP, Jolt.

Derleme seçenekleri: `lto=full`, `optimize=speed_trace` (-O2). `-O3` + LTO 53,5 MiB verdi (kod şişiyor);
-O2 49,6 MiB ve Godot'da -O3'ten ölçülebilir yavaş değil. `-Os` daha küçük olurdu ama GDScript yorumlayıcısı
belirgin yavaşlar; telefonda kare hızı ölçülmeden seçilmemeli.

**Doğrulama (masaüstü):** aynı profille Linux şablonu (`disable_path_overrides=no`, yalnızca test için)
derlendi. 22 araç ve garaj arayüzü resmi motorla **piksel piksel aynı** (fark 0). Tam test paketi bu motorla
`GODOT=<ikili> tools/run_tests.sh` ile koştu: 26/27 paket temiz. `ads_test`'in 10 hatası beklenen:
paket debug derleme davranışını (test reklam kimliği, masaüstü sahte sağlayıcı) denetliyor, release motorunda
`OS.is_debug_build()` false. Başsız testlerdeki "Initializing already initialized RID" / DummyMesh hataları
Godot'nun başsız sahte çizicisine özgü (`RID_Owner<DummyMesh>` iş parçacığına korumasız; GLES3'te
`RID_Owner<Mesh, true>`), telefonu etkilemez.

**Kalan büyük kalemler (yapılmadı):**
1. *Java:* R8 küçültmeyle ~4–5 MiB kazanılabilir. Firebase / AdMob yansıma kullandığı için telefonda
   denenmesi şart.
2. *Motor, sınıf düzeyi:* derleme profiliyle (`build_profile`) kullanılmayan düğüm sınıfları da (TileMap,
   2B parçacıklar, SoftBody, VoxelGI…) çıkarılabilir; sınıf adıyla çalışma anında örnekleme yapan kod / eklenti
   varsa çöker, bu yüzden ayrı ve telefonda denenecek iş.
3. *Sıkıştırılmış native kütüphane* (`gradle_build/compress_native_libraries`): APK küçülür ama kurulu boyut
   büyür; mağaza indirmesi zaten sıkıştırılıyor. Önerilmez.


---

## Paket boyutu 2 (2026-10-17)

Ölçüm: Play'e giden AAB (`--export-release`, ölçüm için debug anahtarıyla imzalı), MiB. "Sıkıştırılmış"
≈ indirme, "açık" ≈ telefondaki kurulu boyut. 2026-10-14 AAB'sinde 55 araç vardı; aynı 59 araçlık
içeriğin önceki hâli o AAB'den araç başına ölçülerle hesaplandı.

| Kalem | Önce (59 araç) | Sonra | Not |
|---|---|---|---|
| Araç dokuları | ~107 / 157 | **29,6 / 39,4** | 2048² → 1024² (`process/size_limit=1024`) |
| Mesh (.glb sahneleri) | 138,2 / 144,7 | 138,2 / 144,7 | dokunulmadı, aşağıdaki seçeneğe bakın |
| Motor (.so) | 23,4 / 69,3 | 23,4 / 69,3 | Play AAB'si hâlâ resmi motorla; özel motor: 17,3 / 50,9 |
| Java (dex) | 10,0 / 26,4 | 10,0 / 26,4 | R8 kapalı |
| Diğer varlıklar | ~22,5 / ~28 | 20,4 / 25,9 | AdMob demo dosyaları pakette değil (~2 MiB) |
| **Toplam** | **~303 / ~429** | **223,0 / 308,5** | özel motorla ~217 / ~290 |

### Araç dokuları 1024² — neden kayıpsız sayıldı

Garaj, showroom ve drag ekranları kendi SubViewport'larında çizilir; `SubViewportContainer.stretch`
SubViewport'u kabın **tuval** boyutuna kurar (`get_size() / shrink`, Godot 4.7
`scene/gui/subviewport_container.cpp`). Telefonda tuval mobil ölçekle (1,35) 1067x480 olduğu için bu
ekranlar 2400x1080'lik telefonda bile ~1067x480 çiziliyor. Şehir tam çözünürlükte, ama araçlar trafik
ölçeğinde küçük.

`qa/mip_probe.gd` telefonu birebir taklit eder (Xephyr 2400x1080 + `content_scale_factor` 1,35), araç
piksellerinin hangi mip'ten okunduğunu boyar ve aynı kareyi kaynak JPEG'den üretilmiş 2048 / 1536 / 1024
ETC2 dokularla çizer. lod ≥ 1 olan piksel 2048'in en ince mip'ine hiç dokunmaz, yani 1024 ile aynıdır.

| Kadraj | lod ≥ 1 | 1024 PSNR | 1536 PSNR |
|---|---|---|---|
| Şehir, oyuncunun en yakın zoom'u (2,2) | %95 | 42 dB | 32 dB |
| Kasa açılışı yakın çekim (1,35) | %89 | 41 dB | 33 dB |
| Garaj lifti | %98–100 | — (sahnede canlı öğe) | — |
| Showroom açılış kadrajı | %65–97 | 38–47 dB | 32–35 dB |
| Showroom en yakın pinch-zoom (0,62) | %25–75 | 33–42 dB | 33–37 dB |

En kötü durum (Lamborghini ve W123, en yakın pinch-zoom, görüntü 2 kat büyütülmüş) yan yana bakınca
güçlükle seçiliyor (`ct_shots/mip_probe/`). **1536² bir ara yol değil:** mip zinciri (1536, 768, …)
2048'inkiyle (1024, 512, …) hizalanmadığı için neredeyse her kadrajda 1024'ten daha uzak çıktı.

Yan etkiler: araç başına VRAM 2,67 → 0,67 MB (garajda 8 araç ~16 MB daha az). Geri almak için
`assets/cars/optimized/*_albedo.jpg.import` içinde `process/size_limit=0` + `--import`.
`tools/make_paint_mask.gd` içe aktarılmış dokuyu okur: boya açılıp maske yeniden üretilirse 1024'ten
okur (1024² maskeler 1:1; 2048'lik Getz maskesi büyütülmüş dokudan okunur). Boya şu an kapalı.

### AdMob demo dosyaları

`export_presets.cfg` `exclude_filter`: eklentinin örnek sahnesi (`addons/admob/gdscript/sample/*`),
örnek müzik (`music.ogg`, 1,8 MiB), Çince yazı tipi, örnek tema ve büyük ikonlar. Masaüstü sahte reklam
sağlayıcısının (`internal/mock`) kullandığı ikonlar pakette kalır.

### Özel motor: kamera modülü açıldı

5 Ekim profili `module_camera_enabled = "no"` idi; o tarihten sonra gelen profil fotoğrafı kamerası
(`ui/hud/camera_capture.gd`) `CameraServer` / `CameraFeed` kullanıyor, kapalı profille betik
derlenmezdi. Profil güncellendi, motor yeniden derlendi (.so 49,6 MiB, kamera +30 KB). Release kipinde
test APK'sı telefonda denendi ve onaylandı; **1.0.7'den itibaren Play AAB'si özel motorla**
(`tools/engine/build_engine.sh --install`; indirme −5,7 MiB, kurulu −18 MiB). 1.0.7 doğrulama AAB'si:
217,3 MiB sıkıştırılmış / 290,1 MiB açık. Sorun çıkarsa resmi motora dönüş: `--restore`.

### Görünmeyen üçgenleri silme — denendi, değmez

Fikir: materyal tek yüzlü, camlar opak, kameralar hep ufkun üstünde → taban sacı ve kabuk içindeki
parçalar hiçbir karede görünmez. Üçgenler kimlik rengiyle 1585 açıdan çizildi (ortografik 0–90° ×
360°, showroom'un en yakın uzaklığından da yakın perspektif; teker/jant/gizli rol örtücü sayılmadı).
Şahin'de taranan üçgenlerin **%94'ü** en az bir açıdan görünüyor; alt sınır gerçekçi 7°'ye çekilince
%88. Deliklere karşı bırakılması gereken 1 halkalık payla kazanç aracın ~%3–5'i (filoda ~5–7 MiB).
Karmaşıklık ve risk (ileride alçak açıdan çekilecek tanıtım videoları) yüzünden bırakıldı.

### Açık seçenek: taban mesh'i bir LOD kademesi sadeleştirmek (~−55 MiB)

Showroom ve garaj lifti `LOD_BIAS_GARAGE = 4` ile LOD0'ı zorlar. Taban mesh yerine her parçanın LOD1'i
kullanılsaydı araç mesh verisi 168,9 → ~102 MiB (−%40; pakette ~−55 MiB) olurdu. Telefon
çözünürlüğünde showroom'da bias 4 / bias 1 karşılaştırması (`ct_shots/lod_bias_probe/`): kare başına
32–2.162 piksel (>8 seviye) farklı, yan yana bakınca seçilmiyor; fark jantlarda ve panel
gölgelenmesinde. Ancak en yakın zoom'da Godot bias 1'de de çoğu parçada LOD0'ı seçiyor (kendi "<1 px
hata" ölçütü LOD1'i yetersiz buluyor) ve §3d'de agresif sadeleştirmede kaporta çökmüştü. Kayıpsız
DEĞİL; kullanıcı 2026-10-17'de istemedi (mevcut hâli yeterli buldu). Uygulanırsa teker parçaları hariç tutulmalı (wheel_axes geometriden
ölçülü), küçük resimler yeniden üretilmeli (`tools/make_car_thumbs.gd`).

### Kalan küçük kalemler (yapılmadı)

- *Java R8:* dex 26,4 MiB açık / 10 MiB sıkıştırılmış; en büyükleri Play Services, Tink (`com.google.crypto`,
  2.287 sınıf), Guava, gRPC / protobuf (Firestore). Godot kütüphanesi ve Firebase / Billing eklentileri
  ProGuard kuralı taşımıyor → elle `-keep` gerekir ve her akış (giriş, bulut kaydı, reklam, satın alma,
  bildirim, arkadaşlar) telefonda denenmeli. Tahmini −4–6 MiB indirme.
- *Müzik:* üç tema QOA (5,9 MiB). Vorbis'e çevirmek ~3 MiB kazandırır ama dikişsiz döngü yeniden
  doğrulanmalı (bkz. oyun müziği notları); değmez.


---

## Paket boyutu 3 (2026-10-19)

İstek: "grafik kalitesini çok düşürmeden boyutu düşür". 74 araçla (8. parti dahil) araç mesh'i paketin en
büyük kalemiydi: içe aktarılmış `.scn` toplamı **170,9 MiB**, AAB'nin ~%66'sı.

| Kalem (AAB, MiB) | Önce (hesaplanan) | Sonra (ölçülen) | Not |
|---|---|---|---|
| Mesh (.glb → .scn) | ~173,7 / 179,4 | **133,6 / 138,0** | sadeleştirme −30,5 + zstd 19 −10,9 (açık) |
| Araç dokuları | 37,4 / 49,3 | 37,4 / 49,3 | dokunulmadı (1024², bkz. "Paket boyutu 2") |
| Motor, Java, diğer | 52,1 / 110,9 | 52,1 / 110,9 | dokunulmadı |
| **Toplam** | **~263 / ~340** | **223,1 / 298,2** | sıkıştırılmış (≈ indirme) / açık (≈ kurulu) |

"Sonra" debug anahtarıyla imzalı doğrulama AAB'si (`~/Projects/ct_builds/AutoYard_1.0.8_boyut3_dogrulama_debug_imzali.aab`).
"Önce" aynı AAB'ye eski `.scn`'lerin farkı eklenerek hesaplandı (`.scn` zaten sıkıştırılmış, AAB'de ~1:1 durur).

### Önce kayıpsız yollar ölçüldü

`qa/size_audit/mesh_audit.gd` (BMW, ham 2,60 MB): vertex verisi %37, UV %12, taban indeks %27, LOD indeksleri %24.
- Vertex sıkıştırma ZATEN açık (`ARRAY_FLAG_COMPRESS_ATTRIBUTES`: konum+normal 12 B, UV 4 B); §6'daki
  "kapalı" notu eskimiş. İndeksler 16 bit, Godot vertex cache + fetch sıralamasını kendisi yapıyor.
- `.scn` = RSCC: 4 KB bloklar hâlinde zstd. Aynı veri: zstd-3 (Godot varsayılanı) 2,17 MB, **zstd-19
  1,99 MB (−%8,5)**, gzip-9 2,00, xz 1,62 (Godot okuyamaz). → `project.godot`
  `compression/formats/zstd/compression_level=19`. Seviye yalnızca SIKIŞTIRMAYI etkiler (içe aktarma
  bilgisayarda biraz yavaşlar); açma hızı aynı, oyun kodu çalışma anında zstd ile sıkıştırmıyor.
  Ayar değişince içe aktarma kendiliğinden yenilenmez: `.godot/imported/<x>.md5` içinde `source_md5`
  bozulup kaynak `touch`lanınca `--import` yeniden üretir (296 sahne böyle yenilendi).

### Hata sınırlı ikinci sadeleştirme (`tools/resimplify_car.py`)

`optimize_car.gd` sabit oranla (%12,5) sadeleştiriyor; düz panellerde gereğinden çok üçgen kalıyor. Araç,
her parçayı Godot'nun kendi meshoptimizer'ıyla (1.1, `thirdparty/` derlenip ctypes) MUTLAK sapma sınırına
kadar sadeleştirir: konum `0,0008` araç boyu (4,4 m araçta 3,5 mm; telefon tuvalinde en yakın showroom
zoom'unda ~0,4 px), normal ve UV de hata hesabında, parça kenarları kilitli (komşu parçayla aralık açılmaz),
UV dikişleri korunur. Dönen parçalar (`tools/wheel_parts.gd`: wheels / tires / rims + wheel_groups)
hariç — 674 teker parçası bayt bayt aynı kaldı, `wheel_axes` geçerli. Düğüm adları / materyal / doku
aynı → CarPartMap değişmez. Filoda üçgen 8,39 M → 6,72 M (−%20), `.scn` 170,9 → 140,4 MiB (zstd 19 ile 130,2).

Godot'nun LOD1'ini taban yapmak (önceki açık seçenek) daha kaba: yarıya bölen basamak yüzünden teker hariç
tümüne uygulanınca −%28, hata ≤ 2/1000 boy sınırıyla yalnız −%15 (`qa/size_audit/lod_audit.gd`).

**Ayar seçimi** — `qa/size_audit/mesh_probe.gd` oyunun showroom'unu telefon tuvalinde (Xephyr 2400x1080,
content_scale 1,35 → 1067x480) en yakın zoom'da yan ve arka 3/4'ten çizer; aynı kadraj eski / yeni
içe aktarmayla iki kez çekilip `mesh_compare.py` ile kıyaslanır. Aynı karenin iki çalıştırması 62–71 dB
(çizim deterministik). BMW + Ferrari + Getz:

| konum / normal toleransı | `.scn` (3 araç) | PSNR | 2× büyütmede |
|---|---|---|---|
| önce | 6,92 MB | — | — |
| 0,0008 / 0,04 | 4,52 (−%35) | 33,5–38,7 | BMW kapı altında üçgen gölge |
| 0,0008 / 0,01 | 4,84 (−%30) | 35,9–42,6 | hâlâ seçiliyor |
| 0,0008 / 0,005 | 5,13 (−%26) | 39,2–43,6 | bu üçünde temiz, AMA filo taramasında Sprinter kapı kolunda leke |
| **0,0008 / 0,0025** | ~5,5 (−%20) | 41–50 | temiz |

Asıl sınırı NORMAL toleransı belirliyor: Tripo normalleri gürültülü (komşu köşeler sık sık > 8° ayrışıyor);
üçgen büyüyünce bu gürültü geniş lekeye dönüşüyor. Denenip bırakılanlar: kıvrım köşelerini kilitlemek
(8°'de kazanç −%2'ye iniyor, 30°'de 0,0025 toleransından kötü).

**Toros istisnası:** gövde TEK mesh ve başka kaynaktan %8'e inmiş; varsayılanla −%67 sadeleşip kapı altında
kırışıklık bırakıyor → araca özel `TIGHT` (0,0003 / 0,001, −%32; 35 → 41 dB).

**Filo doğrulaması** (74 araç × 2 açı, en yakın zoom, eski içe aktarmaya karşı): polisler hariç ortalama
44,0 dB, en düşük 36,0 (Seat Leon — 2× büyütmede seçilmiyor). Polis araçlarındaki düşük değer (24–30 dB)
tepe lambasının çekim anındaki fazı; gövde aynı. Kıyas görüntüleri `~/Projects/ct_shots/mesh_probe/`.
Testler: car_thumbs / vehicle_wheel / vehicle_display / vehicle_asset / vehicle_scale 2.194 OK, 0 FAIL.
`tools/vehicle_geometry_audit.gd`'deki 22 "PİVOT" FAIL'i önceden de var (yeni araçlar ölçülmüş `wheel_axes`
kullanıyor; denetim yalnız teker geometrisine bakıyor, o değişmedi).

**Yeni araç eklerken:** `strip_tangents.py`'den sonra `wheel_parts.gd` → `resimplify_car.py` (CarPartMap'te
teker rolleri yazılmış olmalı) → `--import` → küçük resimler (`tools/make_car_thumbs.gd`). Aykırı sadeleşen
araç (filonun gerisinden belirgin fazla, ör. > %40) varsa `mesh_probe.gd` ile bakılmalı. `tools/rebuild_cars.sh`
adımı içeriyor. Geri alma: `git checkout assets/cars/optimized/*.glb` (8. partinin 15 aracı o gün git'te
değildi; eskileri `~/Projects/ct_builds/glb_yedek_2026-10-19_sadelestirme_oncesi/`).

### Bilerek yapılmayanlar
- Daha gevşek ayar (0,0008 / 0,04): mesh'te ~12 MiB daha, ama en yakın zoom'da beyaz kaportada gölgelenme
  fasetleri seçiliyor.
- LOD1 kademesini atmak: görüntü aynı kalır (Godot o mesafede LOD0'ı çizer), ama şehirde orta mesafede
  üçgen artar; telefonda kare hızı ölçülmeden yapılmamalı.
