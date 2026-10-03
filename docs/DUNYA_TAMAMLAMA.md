# Dünyanın tamamlanması: yollar ve showroom (2026-09-29)

## Sorun

Telefonda denendi. Garaj büyüdükçe kamera daha geniş alan gösteriyor ve iki eksik görünüyordu:

1. **Yollar dünyanın ortasında bitiyordu.** Dört yol kolunun uçları: batı x = −6, kuzey z = −6, doğu x = 8,4, güney z = 7,2. Kamera ise x −10,8…8,9, z −9,2…10,5 arasını gösterebiliyor. 4. seviye garaj batıda −8,2'ye uzandığı için yol, garajın önünde bitiyordu.
2. **Showroom binası yarımdı.** Eski CSG galerinin yalnızca ön duvarı, batı duvarı ve çatısı vardı. Kameranın gördüğü doğu yüzü açıktı; içeriden beyaz zemin görünüyordu.

## Yapılan

Sahne dosyası elle düzenlenmedi (CLAUDE.md). Hepsi `world/world_dressing.gd` ile kodla kuruluyor; düğümü `GarageSystem._ensure_world_dressing()` ekliyor.

| Parça | Nasıl |
|---|---|
| Yol uzantıları | Dört kol, kamera sınırının ötesine kadar uzar (batı −11,6, doğu 9,7, kuzey −10, güney 11,2). Asfalt ve kaldırım sahnedeki yolların kendi malzemesini kullanır. Şerit çizgileri aynı ölçü (0,2 × 0,05) ve aynı 0,4 adım dizisiyle devam eder; tek MultiMesh, tek çizim çağrısı. Çizgi tonu ölçülerek eşlendi: eski çizgiler ekranda 128, yeniler 131. |
| Trafik uç noktaları | 8 doğma / kaybolma noktası yeni yol uçlarına taşınır; eski yerleri `core_position` meta'sı olarak saklanır. `TrafficManager.hidden_start()` aracı eski noktadan başlayıp dışarı doğru kameranın görmediği İLK yerde doğurur. `can_leave_early()` kaybolma noktasına giden aracı eski noktayı geçip görünmez olunca siler. |
| Showroom | `assets/world/showroom.glb`, Blender'da baştan kuruldu (`tools/world/showroom.py`, ayrı "Showroom" sahnesi): 52 × 42 m parsel, 7.588 üçgen, 23 malzeme, tek düğüm. Eski galerinin CSG görselleri gizlenir. `ShowroomHitbox` yeni binanın gövdesine uydurulur; binaya dokununca showroom ekranı eskisi gibi açılır. |
| Tabelalar | `Label3D` ile oyunun kalın yazısı (ışıktan etkilenmez): çatının güney ve doğu bandında "SHOWROOM", servis kapılarının üstünde "CAR PARTS", köşe toteminin iki yüzünde dikey harfler. |

**Showroom tasarımı (metre).**

| Bölüm | İçerik |
|---|---|
| Ana salon | 26 × 20 m. Güney ve doğu cephesi cam, ince koyu doğramalı. |
| Çatı | Köşeleri yuvarlak, 3 m taşan beyaz yüzen çatı. Alt kenarında kehribar vurgu çizgisi ve sıcak LED; üstünde tepe penceresi ve üç çatı ünitesi. |
| İç mekân | Kehribar halkalı iki kaide üstünde iki sergi aracı, danışma masası. |
| CAR PARTS bloğu | 12 × 20 m krem blok. Kehribar çerçeveli iki kepenkli servis kapısı; çatısında iki ünite. |
| Dış alan | Köşe totemi, üç bayrak, 14 araçlık çizgili otopark ve lambalar, giriş portalı ve saksılar. Doğu şeridinde üç araçlık açık sergi; kuzey ve doğu kenarında ağaçlar, batıda çit. |

## Ölçümler

**Trafik** (`qa/trafik_kenar_qa.gd`, 4. seviye, trafik 3 kat hızlı, görünüm başına 25 sn):

| Görünüm | Doğan (eski noktada) | Görünürken doğan | Silinen | Görünürken silinen |
|---|---|---|---|---|
| Varsayılan | 31 (31) | 0 | 22 | 0 |
| En uzak zum, batı kenarı | 25 (18) | 0 | 24 | 0 |
| En uzak zum, güneydoğu kenarı | 27 (10) | 0 | 26 | 0 |

Varsayılan görünümde eski noktalar ekran dışında, bu yüzden bütün araçlar eski yerinde doğuyor: yolculuk süresi ve müşteri sıklığı değişmedi. Uzaklaşıp kenara bakınca araçlar görünmeyen yerde doğuyor.

**Çizim maliyeti** (`qa/showroom_bina_qa.gd`, 1152×648, varsayılan görünüm): bina ve tabelalar açıkken 193, kapalıyken 168 çizim çağrısı. Bina +25 çizim çağrısı getiriyor.

**Görüntüler:** `qa/dunya_kenar_qa.gd -- <etiket>` her seviyede varsayılan, dört köşe ve düzenleme görünümünü çeker. `-- <etiket>_yakin` showroom'un ve dört yol dikişinin yakın planını çeker.

## Editörde isteğe bağlı temizlik

Eski galerinin CSG düğümleri `Main.tscn` içinde duruyor ve oyunda gizleniyor: `GrassArea/Gallery` altındaki `Floor`, `FrontWall`, `Roof`, `GalleryFloor`, `BackWall`, `GalleryParking*`, `GlassLeft*`, `GallerySign`. Editörde silinebilirler. `ShowroomHitbox` KALMALI; kod onun şeklini yeni binaya uyduruyor.

Trafik noktalarını editörde TAŞIMAYIN. Kod taşıyor ve eski yerlerini hatırlıyor; elle taşınırsa "görünmeyen yerde doğ" mantığı eski noktayı bilemez.

## Modeli yeniden üretmek

Canlı Blender oturumunda (blender-mcp eklentisi):

```
python3 tools/decor/blender_send.py tools/world/showroom.py
godot-4 --headless --path . --import
```

Betik kullanıcının sahnesine dokunmaz. Dışa aktarımda `use_active_scene=True` zorunlu: dışa aktarıcı varsayılan olarak bütün sahneleri gezip her birindeki seçimi alıyor. İlk denemede kullanıcının sahnesinde seçili duran araç parçaları GLB'ye girmişti (500 bin üçgen, 19 MB).
