# Optimizasyon turu — 2026-10-10

Hedef: zayıf telefonda (tester cihazı Oppo A15: Helio P35, PowerVR GE8320, GL Compatibility)
akıcılık. Yöntem: önce ölç, en büyük darboğazı düzelt, yeniden ölç. Ölçümler masaüstünde
(Intel ADL tümleşik GPU); mutlak süreler telefonla aynı değil, kıyas ÖNCE/SONRA içindir.
Telefonda belirleyici olanlar: çizim çağrısı (GLES'te sürücü CPU maliyeti), üçgen, VRAM, takılmalar.

## Ölçüm araçları

| araç | ne ölçer |
|---|---|
| `qa/perf_bench.gd` | 10 senaryoda kare süresi, en uzun kare, çizim, nesne, üçgen, VRAM, bellek, düğüm |
| `qa/draw_census.gd` | görünür geometriyi kaynağına göre (dekor / trafik / şehir…) sayar |
| `qa/decor_census.gd` | dekor eşyası başına mesh / yüzey / materyal / üçgen |
| `qa/open_profile.gd`, `qa/open_repeat.gd` | ekran açılış maliyeti, ilk açılış mı her seferinde mi |
| `qa/startup_profile.gd` | Main.tscn yükle / örnekle / _ready / ilk kareler |
| `qa/merge_visual_check.gd` | aynı kare birleşik ve parçalı: piksel farkı |
| `qa/lod_scale_probe.gd` | birleşik mesh LOD çarpanı kalibrasyonu |
| `qa/glyph_audit.gd` | oyun metinlerinde varsayılan yazı tipinde OLMAYAN karakterler |
| `qa/place_shots.gd` | tam ekran (PLACE) ekranların görüntüsü |

Hepsi `tools/qa_isolated.sh` ile çalışır; `QA_SAVE=<kayıt>` gerçek bir kaydın kopyasıyla başlatır
(profiller: `~/Projects/ct_shots/bench_saves/featured.json` — seviye 45, 73 dekor, 6 sergi aracı;
`dev.json` — 18 araç). Geliştirme kaydına dokunulmaz.

## Bulgular ve düzeltmeler

### 1. Araç parçaları (en büyük kalem)
Her araç GLB'si 47–80 parça mesh'i ama CarRig'in atadığı yalnızca 5–11 materyal var. Dekorlu
garajda 6 sergi aracı tek başına 413 çizim çağrısı / 685k üçgen (dekorun %62'si).
**Çözüm:** `vehicles/car_mesh_merger.gd` + `CarRig.optimize(include_wheels)` — aynı materyali
kullanan parçalar tek yüzeyde birleşir; dönen tekerler (trafik, yarış) ayrı kalır.
- LOD korunur: parçaların LOD indeksleri RenderingServer'dan okunur, 4 ortak eşikte kademe kurulur.
  Birleşik mesh tek büyük kutu olduğu için Godot daha detaylı kademe seçiyordu: `MERGED_LOD_SCALE`
  0,7 ile üçgen sayısı birleştirme öncesine eşitlendi (ölçüldü).
- GPU çağrıları yalnızca ana iş parçacığında (arka planda yapılınca GL Compatibility'de işler
  takılıyordu); okuma kare başına ~2 ms bütçeyle, birleştirme WorkerThreadPool'da, yükleme kare
  başına bir yüzey. 16 bit indeks için büyük gruplar 65 536 köşeden bölünür.
- Önbellek: model başına bir kez, en son kullanılan 8 model.
- Görsel denetim: büyük fark pikselleri %0,005 (yalnızca LOD kenarları).

### 2. Görünmeyen dünya çiziliyordu
Garaj / showroom / ayarlar / drag yarışı tam ekranken arkadaki şehir ~500 çizim çağrısı
harcıyordu. **Çözüm:** `Hud._sync_world_rendering` — bu ekranlar açıkken ana viewport `disable_3d`
(açılış geçişi bitince, 0,4 sn). Dekorasyon düzenleyici dünyayı gösterdiği için hariç.

### 3. Yazı tipinde eksik karakterler (ekran açılış takılmalarının asıl nedeni)
Oyunun yazı tipi (Godot'nun gömülü Open Sans'ı) ₺ ★ ☆ → ← ↔ ↗ ✓ ✔ ↻ ≡ içermiyor; her eksik
karakterde Godot sistem yazı tiplerini tarıyordu. Başarım sekmesi 175 ms (bu karakterler olmadan
32 ms). **Çözüm:** `ui/theme/fonts/autoyard_symbols.ttf` (DejaVu Sans Bold alt kümesi, 16 KB,
yeniden adlandırıldı, lisans yanında) gömülü yazı tipinin yedeği (`FontFallback.install`, Hud).
Yeni bir sembol eklenirse `qa/glyph_audit.gd` ile denetle, eksikse alt kümeye ekle.

### 4. İlk açılış takılmaları (shader derleme)
Showroom ilk açılışta 151 ms, drag yarışı 126 ms (sonrakilerde 17 ms): GL Compatibility shader'ları
ilk kullanımda derler. **Çözüm:** `prewarm()` — iki ekranın sahnesi oyun yüklenirken görünmeden
bir kez küçük boyutta çizilir. Açılışa ~190 ms ekler (logo ekranında), oyun içi ~280 ms'yi kaldırır.

### 5. Küçük
- `DecorBuilder.local_size` ölçüm kopyası artık parça birleştirme istemez.

## Sonuç (dekorlu kayıt, masaüstü)

| senaryo | çizim | üçgen | en uzun kare |
|---|---|---|---|
| dünya | 855 → 495 | 598k → 575k | aynı |
| garaj paneli | 1403 → 449 | 918k → 292k | 31 → 26 ms |
| showroom | 1232 → 361 | 745k → 41k | 107 → 17 ms |
| görevler | 1223 → 640 | 821k → 637k | 272 → 38 ms |
| dekor düzenleyici | 960 → 600 | 531k → 555k | 116 → 47 ms |
| drag yarışı | 1254 → 114 | 973k → 192k | 7 → 5 ms |
| tamir | 1196 → 558 | 869k → 823k | 13 → 6 ms |

**Bedel:** VRAM dünyada 108 → ~160 MB (~30 MB birleşik araç mesh'leri, ~20 MB showroom/yarış
varlıklarının öne çekilmesi — oturum tepesi değişmez).

## İncelenip dokunulmayanlar
- **Kare başı betik maliyeti:** trafik / kamera / yöneticiler hafif (fizik + betik ~1-2 ms).
- **Açılış:** Main.tscn yüklemesi soğuk önbellekte ~950 ms = kod tabanının (106 dosya, 33k satır)
  zincirleme derlenmesi; dışa aktarımda ikili token (`script_export_mode=2`) zaten açık. Kalan ilk
  kare (~600 ms) dünya shader derleme + doku yükleme. Azaltmanın yolu ekranları gerektiğinde
  yüklemek (büyük yeniden yapılandırma) — bu turda yapılmadı.
- **Telefonda doğrulama:** yapılmadı. Bakılacaklar: zayıf cihazda FPS, ilk açılışta takılma,
  ₺/★ görünümü, bellek uyarısı.
