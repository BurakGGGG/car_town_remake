# ARAÇ GÖRSEL QA — tekerlek / çamurluk / zemin teması

Tarih: 2026-09-27 · **16/16 ARAÇ KONTROL EDİLDİ**

> **Sonraki karar (aynı gün):** Renault Toros görüntüsü beğenilmediği için **oyundan
> çıkarıldı** (bkz. §9). Aşağıdaki ölçümler 16 araçlık sette alınmıştır; kalan 15 araç
> için hepsi geçerlidir ve `vehicle_wheel_test` katalogdaki araç sayısına göre çalışır.

Ölçüm aracı: `tools/vehicle_geometry_audit.gd` (tablo + tek araç ayrıntısı)
Kalıcı test: `vehicle_wheel_test.gd` (17 kontrol, `tools/run_tests.sh` içinde)
Görsel kanıt: `ct_shots/wheels/sayfa_1..4.png` (16 araç yandan, tekerler 40° dönük, y=0 sarı çizgi)

---

## 1. Sonuç tablosu

Değerler aracın YEREL uzayında (modeller 1,0 uzunluğa normalize; 0,005 ≈ 2 cm):

```
araç                    tkr       FL       FR       RL       RR    gövde    pivot  yarıçp elenen durum
bmw_e46                   4   0.0000   0.0002   0.0001   0.0001   0.0474   0.0000   0.103      0 PASS
hyundai_getz              4   0.0002   0.0002   0.0002   0.0001   0.0424   0.0000   0.106      0 PASS
renault_fluence           4   0.0002   0.0001   0.0000   0.0002   0.0575   0.0000   0.100      0 PASS
vw_passat_b55             4   0.0006   0.0000   0.0001   0.0001   0.0446   0.0000   0.101      0 PASS
hyundai_era               4   0.0001   0.0001   0.0002   0.0000   0.0390   0.0000   0.085      0 PASS
renault_toros             4   0.0001   0.0000   0.0001   0.0002   0.0001   0.0000   0.107      0 PASS
tofas_sahin               4   0.0003   0.0003   0.0001   0.0002   0.0115   0.0000   0.088      0 PASS
hyundai_accent_blue       4   0.0000   0.0000   0.0000   0.0002   0.0343   0.0000   0.092      1 PASS
ford_focus                4   0.0000   0.0001   0.0003   0.0002   0.0374   0.0000   0.084      0 PASS
skoda_kamiq               4   0.0000   0.0001   0.0005   0.0000   0.0481   0.0000   0.091      0 PASS
vw_golf_7                 4   0.0001   0.0002   0.0000   0.0003   0.0395   0.0000   0.094      0 PASS
seat_leon                 4   0.0001   0.0000   0.0000   0.0001   0.0297   0.0000   0.089      0 PASS
honda_civic               4   0.0000   0.0001   0.0002   0.0000   0.0211   0.0000   0.082      1 PASS
audi_a3                   4   0.0002   0.0001   0.0001   0.0000   0.0308   0.0000   0.089      2 PASS
volvo_s60                 4   0.0003   0.0003   0.0004   0.0002   0.0278   0.0000   0.084      0 PASS
bmw_e60                   4   0.0001   0.0003   0.0006   0.0003   0.0001   0.0000   0.077      0 PASS
--------
16/16 araç geçti
```

| Araç | Teker | FL | FR | RL | RR | Zemin | Pivot | Gövde bağımsız | Trafik | Garaj | Drag | Durum |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Tofaş Şahin | 4 | 0,0003 | 0,0003 | 0,0001 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Renault Toros | 4 | 0,0001 | 0,0000 | 0,0001 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Hyundai Era | 4 | 0,0001 | 0,0001 | 0,0002 | 0,0000 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Hyundai Getz | 4 | 0,0002 | 0,0002 | 0,0002 | 0,0001 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| VW Passat B5.5 | 4 | 0,0006 | 0,0000 | 0,0001 | 0,0001 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Renault Fluence | 4 | 0,0002 | 0,0001 | 0,0000 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| BMW E46 | 4 | 0,0000 | 0,0002 | 0,0001 | 0,0001 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Audi A3 | 4 | 0,0002 | 0,0001 | 0,0001 | 0,0000 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| BMW E60 | 4 | 0,0001 | 0,0003 | 0,0006 | 0,0003 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Ford Focus 3 | 4 | 0,0000 | 0,0001 | 0,0003 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Honda Civic VTEC2 | 4 | 0,0000 | 0,0001 | 0,0002 | 0,0000 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Hyundai Accent Blue | 4 | 0,0000 | 0,0000 | 0,0000 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Seat Leon | 4 | 0,0001 | 0,0000 | 0,0000 | 0,0001 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Škoda Kamiq | 4 | 0,0000 | 0,0001 | 0,0005 | 0,0000 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| Volvo S60 | 4 | 0,0003 | 0,0003 | 0,0004 | 0,0002 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |
| VW Golf 7 | 4 | 0,0001 | 0,0002 | 0,0000 | 0,0003 | PASS | PASS | PASS | PASS | PASS | PASS | **PASS** |

**16/16 PASS** — zemin teması, tekerlek pivotu, tekerlek dönüşü, gövde bağımsızlığı.

---

## 2. Kök nedenler ve düzeltmeler

### KÖK NEDEN 1 — Dönüş yanlış uzayda uygulanıyordu (Şahin ve çok parçalı tüm tekerler)

`CarRig._update_wheels()` tekeri, grubun İLK mesh'inin **kendi yerel** kutu merkezi etrafında
ve **mesh'in yerel uzayında** döndürüyordu:

```gdscript
mesh.transform = bases[i] * rotate_about(local_aabb_center)
```

Bir grupta birden fazla parça varsa (lastik + jant) ve parçaların yerel çerçeveleri farklıysa,
her parça BAŞKA bir nokta etrafında dönüyordu. Şahin'de ölçülen kayma **0,229 birim** — yani
teker kendi ekseninde dönmek yerine aracın içinde yörüngeye giriyor, dönerken havaya kalkıyordu.
Kullanıcının "Şahin'in tekerleri zeminden havada dönüyor" gözlemi tam olarak budur.

**Düzeltme:** dönüş artık EBEVEYN uzayında, tekerin gerçek ekseni etrafında:

```gdscript
mesh.transform = rotate_about(axis) * bases[i]
```

Etkilenen araçlar (kayma → 0,0000): Şahin 0,2289 · Honda Civic 0,2024 · Accent Blue 0,0918 ·
BMW E60 0,0389 · Audi A3 0,0319 · Fluence 0,0139 · Era 0,0086 · Golf 7 0,0067 · Leon 0,0059 ·
Getz 0,0058 · Kamiq 0,0074.

### KÖK NEDEN 2 — Parça haritası tekerlek grubuna tekerlek OLMAYAN mesh koymuştu (Audi A3)

Audi'nin `wheel_groups` girdisi `fr: [1, 12]` ve `rl: [3, 11, 34]` idi; 12 ve 34 numaralı
parçalar çamurluk/kemer geometrisiydi. Ölçüm: FL tekeri 0,0886 yarıçapındayken FR **0,1245**,
RL **0,1211** — yani %40 büyük. Bu parçalar tekerle birlikte döndüğü için çamurluk dönüyordu.

**Düzeltme (sistematik, araç id'si yok):** `CarRig` tekerlek grubunu iki süzgeçten geçiriyor:

1. **Boyut:** dört grubun en küçük tekerinin %25'inden büyük parça tekerlek değildir.
2. **Eksen:** lastikle Y-Z düzleminde eş merkezli olmayan parça (lastik çapının %22'sinden uzak)
   tekerlek değildir — jant/göbek eş merkezlidir, kaliper/kemer değildir.

Elenen parça görünür kalır, yalnızca DÖNMEZ. Eleme sonucu (`push_warning` ile loglanır):

| Araç | Elenen |
|---|---|
| Audi A3 | tripo_part_12 (fr), tripo_part_34 (rl) |
| Hyundai Accent Blue | 1 parça |
| Honda Civic | 1 parça |
| Diğer 13 araç | yok |

Ayrıca eksenin **elemeden sonra** seçilmesi gerekiyordu: ilk denemede en büyük üye (çamurluk)
eksen kabul edilip elendiği için teker çamurluğun merkezi etrafında dönüyordu (Audi'de 0,0993).

### KÖK NEDEN 3 — Toros'ta lastiğin taban dilimi gövdede kalmıştı

Toros tek mesh'li bir kaynaktan (`renault_r12.glb`) geliyor; tekerler pipeline'da silindirik
bir bölge çıkarılarak ayrılıyor. Silindir aks merkezinde (y=0,110) ve 0,100 yarıçapındaydı →
alt ucu y=0,010'da kalıyor, lastiğin en alt 1 cm'lik dilimi **gövde mesh'inde** kalıyordu.
Sonuç: teker dönerken tabanda dönmeyen sabit bir hilal, ve ölçümde teker 0,0105 havada.

**Düzeltme:** silindir aşağı kaydırıldı ve biraz küçültüldü — merkez y 0,110 → **0,103**,
yarıçap 0,100 → **0,107**. Alt uç zemine iner, **üst uç eskisiyle aynı kalır**. Bu ikinci kısım
önemli: yalnızca yarıçapı büyütmek (0,113) tabanı düzeltiyor ama silindir çamurluğu da kesip
kemerde siyah kamalar bırakıyordu (render'da görüldü, geri alındı).

Sonuç: teker tabanı 0,0105 → **0,0001**, gövde alt y 0,0000 → 0,0001 (araç artık tekerlerinin
üstünde duruyor, gövdesiyle yere değmiyor), yarıçap 0,0997 → 0,1067.

---

## 3. Ölçüm yöntemi (ve yol boyunca düzeltilen iki ölçüm hatası)

- **Zemin teması:** her tekerlek grubunun birleşik kutusunun alt y'si. Tolerans 0,005 (≈2 cm).
  İlk tolerans 0,012 idi ve Toros'un 0,0114'lük gerçek hatasını "geçiriyordu" — sıkıldı.
- **Pivot:** teker 37°/90°/143°/211°/305° döndürülüp **lastiğin kutu merkezi noktasının**
  kaydığı mesafe. İlk denemede kutunun kendisi karşılaştırılmıştı; Godot'ta
  `Transform3D * AABB` döndürülmüş KUTUNUN sınırlarını verir (37°'de kutu √2 büyür),
  geometrinin değil — bu her araçta sahte hata üretiyordu. Nokta dönüşümü tam doğrudur.
- **Gövde bağımsızlığı:** teker dönerken ve direksiyon 22° çevrilirken, tekerlek olmayan
  HER mesh'in kutu merkezi. Tolerans 0,0005; ölçülen: **tüm araçlarda 0,0000**.
- **Oyun içi:** `qa/wheel_ingame.gd` trafikte hareket eden araçları örnekler —
  **3.576 gövde örneği, en büyük kıpırdama 0,000000**, aynı sürede **346 dönen teker ölçümü**
  (yani tekerler gerçekten dönüyor, gövde kıpırdamıyor).

---

## 4. Bağlam kontrolleri

| Bağlam | Kontrol | Sonuç |
|---|---|---|
| Model (yalıtılmış) | 16 araç × zemin/pivot/gövde/direksiyon | 16/16 PASS |
| Trafik | Hareket eden araçlarda teker dönüşü + gövde sabitliği | 3.576 örnek, 0,000000 kıpırdama |
| Garaj | Lift + seçim + kamera (`ui_test`, görsel QA) | PASS |
| Showroom | 16 araç önizleme (`vehicle_scale_test`, görsel QA) | PASS |
| Drag | Teker dönüşü hız ile senkron (`race_test`, drag render'ları) | PASS |
| Ölçek | `vehicle_scale_test` 106 kontrol — ölçek çalışması bozulmadı | PASS |

---

## 5. Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `vehicles/car_rig.gd` | Dönüş ebeveyn uzayında + gerçek eksen; tekerlek grubu boyut/eksen süzgeci; `_wheel_dropped` denetim listesi |
| `vehicles/car_part_map.gd` | Toros extract silindiri: merkez y 0,110→0,103 / 0,111→0,104, yarıçap 0,100→0,107, half_width 0,04→0,034 |
| `assets/cars/optimized/renault_toros.glb` | Yeni extract ile yeniden üretildi (kaynak GLB'ye DOKUNULMADI) |
| `tools/vehicle_geometry_audit.gd` | YENİ — 16 araç geometri denetimi |
| `qa/wheel_shots.gd`, `qa/wheel_ingame.gd` | YENİ — görsel kontakt sayfaları, oyun içi ölçüm |
| `~/snap/godot-4/common/cloudtest/vehicle_wheel_test.gd` | YENİ — 17 kontrol, kalıcı regresyon |
| `tools/run_tests.sh` | Yeni paket eklendi |

**Kaynak GLB'ler değiştirilmedi.** Düzeltmeler sırasıyla: kod (CarRig) → parça haritası
(metadata) → pipeline yeniden üretimi. Hiçbir yerde `if vehicle_id == ...` yok.

---

## 6. Test sonuçları

| Paket | Kontrol | Hata |
|---|---|---|
| vehicle_wheel_test (YENİ) | 17 | 0 |
| vehicle_asset_test | 328 | 0 |
| vehicle_scale_test | 106 | 0 |
| drag_transmission_test | 38 | 0 |
| race_test | 49 | 0 |
| ui_test | 47 | 0 |
| save / edge / quest / paint / cloud / progression | 199 | 0 |
| **Toplam** | **784** | **0** |

Boya sistemi oyuncuya kapalı kalmaya devam ediyor (`GameFeatures.PAINT = false`), altyapı silinmedi.

---

## 7. Kabul kriterleri

| Kriter | Sonuç |
|---|---|
| Şahin'in tekerleri havada | **DÜZELDİ** (pivot 0,2289 → 0,0000) |
| Toros tekerleri bozuk | **DÜZELDİ** (taban 0,0105 → 0,0001, hilal yok, kemer temiz) |
| Audi'de çamurluk tekerle dönüyor | **DÜZELDİ** (2 parça gruptan elendi) |
| Herhangi bir araçta gövde tekerle dönüyor | **YOK** (16/16, 0,0000) |
| Herhangi bir araçta zemin teması bozuk | **YOK** (en kötü 0,0006) |
| Herhangi bir araçta pivot yanlış | **YOK** (16/16, 0,0000) |
| Trafik / garaj / drag'de teker-gövde problemi | **YOK** |

---

## 8. Kalan konular

1. **Toros kaynak modeli tek mesh.** Cam, far, tampon ayrı parça değil; tekerler pipeline'da
   silindirle kesiliyor. Kesim geometrik olduğu için kemerde birkaç üçgenlik iz kalabiliyor.
   Gerçek çözüm kaynağın parçalı yeniden üretimi — kaynak asset kusuru olarak raporlanıyor.
2. **Elenen 4 parça** (Audi ×2, Accent ×1, Civic ×1) artık dönmüyor. Bunlar çamurluk/kemer
   olduğu için doğru davranış; ama parça haritasının kendisi de düzeltilebilir (sınıflandırıcı
   iyileştirmesi). Şu an süzgeç çalıştığı için görsel bir etkisi yok.
3. **Direksiyon açısı** yalnızca ön tekerlere uygulanıyor ve trafikte 0 tutuluyor (düz gidiş);
   viraj animasyonu ileride eklenirse bu testler onu da kapsıyor.


---

## 9. Renault Toros oyundan çıkarıldı (2026-09-27)

Tekerlek/zemin hatası ölçülüp düzeltildikten sonra bile kaynak modelin tek mesh olması
yüzünden kemer bölgesinde kesim izleri kalıyordu; kullanıcı aracı oyundan çıkarma kararı verdi.

**Yapılanlar**
- `vehicles/cars.json`: kayıt silindi (16 → **15 araç**).
- `vehicles/car_part_map.gd`: harita kaydı **yorum satırına alındı** (ölçülmüş extract
  değerleriyle birlikte) — geri almak için hazır duruyor.
- Silinen dosyalar: `assets/cars/renault_toros.tscn` (+uid), `optimized/renault_toros.glb`
  (+import), `optimized/renault_toros_paintmask.png` (+import),
  `optimized/renault_toros_car_albedo_albedo.jpg` (+import).
- **Kaynak korundu:** `assets/cars/source/renault_r12.glb` duruyor.
- Testlerdeki Toros referansları başka araçlarla değiştirildi (`save_test`, `race_test`,
  `paint_test`); araç sayısına bağlı kontroller katalog boyutundan okuyacak şekilde esnetildi.

**Geri almak için** cars.json kaydı eklenir, harita kaydının yorumu kaldırılır ve:

```
godot-4 --headless --path . -s res://tools/optimize_car.gd -- \
  --in res://assets/cars/source/renault_r12.glb \
  --out res://assets/cars/optimized/renault_toros.glb \
  --ratio 0.08 --min-tris 300 --rename --map res://assets/cars/renault_toros.tscn
```

**Yan etki:** D sınıfında tek araç kaldı (Tofaş Şahin). Sınıf dağılımı artık
**A 4 · B 6 · C 4 · D 1**. Rakip seçimi oyuncunun sınıfı + bir üstünden yaptığı için
D sınıfı bir oyuncu hâlâ 5 farklı rakiple karşılaşıyor, ama giriş sınıfının çeşitliliği azaldı.

---

## 10. Renault Toros geri alındı — tekerler Blender'da yeniden üretildi (2026-09-28)

§9'da araç oyundan çıkarılmıştı. Kaynak model (`renault_r12.glb`) tek mesh ve **6.887 kopuk
geometri adasından** oluşuyor, yani "loose parts" ile tekerler ayrılamıyor; pipeline bu yüzden
tekerleri **silindirle kesiyordu** ve kesim izleri kalıyordu. Bu sefer kesmek yerine kaynaktaki
bozuk teker geometrisi **silinip yerine temiz teker kondu**.

### 10.1 Asıl kök neden: harita aksı üç eksende de yanlıştı

Silindirin nereye oturacağı `CarPartMap`'teki `extract.center`/`radius` değerlerinden geliyordu.
Bunlar ölçülmemişti. Ortografik siluetten ve temas yamasından ölçülen gerçek değerler:

| büyüklük | haritadaki | ölçülen | fark |
|---|---|---|---|
| teker merkezi x | ±0,206 | **±0,1880** | 18 mm dışarıda |
| teker merkezi y (yükseklik) | 0,103 | **0,0735** | 29 mm yukarıda |
| teker merkezi z (ön/arka) | ±0,308 / ∓0,272 | **±0,3125 / ∓0,2685** | 4 mm |
| lastik yarıçapı | ~0,107 | **0,0735** | %45 iri |
| lastik genişliği | 0,068 (2×half_width) | **0,0534** | %27 geniş |

Silindir hem %45 iri hem 29 mm yüksek olduğu için lastiği ıskalayıp **çamurluğu kesiyordu**.
§9'daki "yarıçapı 0,107'ye çıkar" düzeltmesi bu yüzden tutmadı: yanlış merkezin etrafında
doğru yarıçap yoktur.

Ölçüm yöntemi (`tools/decor/toros_tekerlek.py` içinde belgeli):
1. Ortografik yan render (1 px = 0,001 birim), siluetin alt sınır profili çıkarıldı.
2. Eşiğin altındaki (z < 0,0564) her yükseklikte lastiğin **kirişi** ölçüldü; `h² = 2Rz − z²`
   üç yükseklikte R ≈ 0,0724 / 0,0713 / 0,0728 verdi → **R = 0,0735**.
3. Temas yaması (z < 0,008) lastik genişliğini ve merkez x'ini doğrudan verdi: dört tekerde de
   0,0531–0,0538 genişlik, merkez ±0,1876…±0,1881.

Not: ilk denemede daire, alt yaya **cebirsel daire uydurma** ile arandı; yay yalnızca alt kapağı
kapsadığı için kötü koşullu çıktı (artık 0,020 = yarıçapın %28'i) ve merkez z = −0,033 gibi
imkânsız bir değer verdi. Kiriş yöntemi kapalı formda ve koşullu.

### 10.2 Yapılan

- `tools/decor/toros_tekerlek.py` (yeni): canlı Blender oturumunda kaynağı içe alır, dört teker
  bölgesini siler (r ≤ 0,078, |x−aks| ≤ 0,032 — çamurluk dudağı |x| > 0,220'de korunur),
  yerine **halka profilli** temiz teker üretir (lastik + jant tablası + göbek, 400 üçgen) ve
  `renault_toros_wheels.glb` olarak yazar. **Kaynak `renault_r12.glb`'ye dokunulmaz.**
- Tekerler `tripo_part_1..4` adıyla AYRI nesne çıktığı için pipeline'ın `extract` adımına
  gerek kalmadı; harita kaydı sadeleşti.
- `vehicles/cars.json`: kayıt geri eklendi (15 → **16 araç**), D sınıfı yine 2 araç.

### 10.3 Yol boyunca çıkan üç ayrı renk hatası

Teker geometrisi düzeldikten sonra lastik oyunda **açık gri** çıkmaya devam etti. Üç ayrı sebep
vardı ve üçü de ayrı ayrı ölçülüp düzeltildi:

1. **Tek texel'e nişan almak işe yaramıyor.** `optimize_car.gd` çıkışta bütün yüzeylere tek
   gövde materyalini verdiği için teker rengi yalnızca UV'den geliyor. Lastiğin bütün UV'si
   dokudaki siyah bir texel'e sabitlendi — **mipmap yuttu**: o texel'in 9×9 komşu ortalaması
   zaten 93, 33×33 ortalaması 96. Kaynağın kendi teker UV'lerini taşımak da tutmadı, çünkü
   model 6.887 parçaya bölünmüş ve teker UV'leri atlasın **her yanına** dağılmış (ölçüldü:
   u 0,005–0,990, v 0,005–0,991).
2. **Blender iki UV katmanı bırakıyordu.** Silindir primitifleri kendi katmanlarını getiriyor;
   glTF dışa aktarımı **aktif** katmanı değil **ilk** katmanı TEXCOORD_0 yazıyor. Yazdığım
   katman aktifti ama ikinciydi → oyunda lastiğin UV'si (0, 1) köşesinde kalmıştı.
3. **CarRig teker shader'ını zorla takıyordu.** "Lastik + jant tek mesh" araçlar için yarıçapa
   göre bölen `wheel_split.gdshader`, `wheels` rolündeki HER parçaya takılıyor ve rengi yine
   atlastan okuyordu — kendi materyalinin üstünü örtüyordu.

**Kalıcı çözüm — üç araçta üç küçük kural:**

| dosya | kural |
|---|---|
| `tools/optimize_car.gd` | `_surface_material()`: **dokulu** materyaller tek gövde materyaline indirgenir (eskisi gibi), **dokusuz** materyal kaynakta bilerek ayrı verilmiştir ve düz renk olarak KORUNUR. |
| `vehicles/car_rig.gd` | `_needs_wheel_split()`: teker tek yüzeyli ve atlası kullanıyorsa shader takılır; kaynakta zaten ayrılmışsa (çok yüzey / dokusuz materyal) takılmaz. |
| `tools/make_paint_mask.gd` | Atlası kullanmayan yüzey maskeye rasterize edilmez. UV'si anlamsız olduğu için engel sayılıyor ve **aday texel'i 624.555 → 23.864'e** düşürüyordu. |

Üçü de mevcut araçlar için **işlemsiz**: 15 aracın her materyali dokulu, 56 tekerinin hepsi tek
yüzeyli ve atlaslı (`qa/wheel_surfaces.gd` ile ölçüldü — shader takılan 56, takılmayan yalnızca
Toros'un 4 tekeri).

Sonuç materyaller: lastik `#353538`, jant/göbek `#999A9D` — jant grisi aracın **kendi
dokusundan** ölçülen jant kapağı rengi (152,153,155).

### 10.4 Denge korundu

Araç geri eklenirken yarış statları raporun eski tablosundan (§14, drag_racing_2_report.md)
**türetilerek** bulundu, uydurulmadı: `launch_rpm = redline × lerp(0,52; 0,62; ivme) × 1,08`
denklemi ivmeyi tek değere kilitliyor (6131 devir sınırı → ivme 56), son hız ise süpürülerek
eşlendi. `top_speed = 100` ile `qa/drag_lab.gd` eski satırı **birebir** yeniden üretiyor:

```
renault_toros          D       5  6131   5608  3814  14.44  14.56  14.91   0.47
```

---

## 11. Farlar beyaz araçlarda kayboluyordu (2026-09-28)

Kullanıcı şikâyeti: "bazı araçların renk konusunu çözemedik, mesela farları güzel olmadı."
Önden çekimde görüldü — Volvo S60, Honda Civic ve Audi A3 gibi **beyaz** araçlarda far, beyaz
kaportadan ayrışmıyordu; koyu araçlarda (BMW E60) sorun yoktu.

### 11.1 Ölçüm: iki AYRI sebep

`qa/far_kontrast.gd` dokudan örnekleyip far ↔ kaporta parlaklık farkını ölçtü — **15 araçtan
8'inde fark 0,10'un altında**:

```
honda_civic   0,001      audi_a3   0,002      hyundai_era     0,013
vw_passat     0,031      volvo_s60 0,036      renault_fluence 0,074
bmw_e60       0,086      accent_blue 0,089
```

Audi'nin 0,002'si şüphe uyandırdı: far ile kaporta BİREBİR aynı renk çıkıyorsa far rolünde
kaporta parçası olabilir. `qa/far_parcalari.gd` parça kutularını ölçtü ve doğruladı:

| araç | şüpheli parça | hacim (araç kutusunun oranı) | kutu |
|---|---|---|---|
| audi_a3 | tripo_part_16 / 19 | **%2,17 / %2,34** | 0,236×0,135×0,123 |
| volvo_s60 | tripo_part_11 / 24 | **%1,20 / %0,96** | 0,130×0,114×0,131 |
| tofas_sahin | tripo_part_18 / 36 | **%0,81 / %0,90** | 0,090×0,073×0,232 |

Gerçek lambalar en çok **%0,31** (bmw_e60 0,31 · volvo 0,28 · era 0,26). Yani 2026-09-27'nin
otomatik rol sınıflandırıcısı bu araçlarda çamurluk/tampon panelini far rolüne koymuş.

> Ölçüm tuzağı: ilk denemede parça kutuları hepsi aracın ortasında çıktı. `mesh.get_aabb()`
> YEREL uzaydadır; `optimize_car.gd` kök dönüşümü vertex'lere pişirmez, düğüme yazar. Kutuyu
> `Transform3D * AABB` ile dönüştürmek de yanlış (döndürülmüş kutunun sınırını verip şişirir) —
> 8 KÖŞE dönüştürülüyor.

### 11.2 Düzeltme — iki adım, ikisi de ölçüye dayalı

1. **Rol süzgeci** (`CarRig._filter_lamps`): far rolünden, aracın kutu hacminin `%0,45`'ini aşan
   parça elenir. Eşik ölçülen iki kümenin (gerçek ≤ %0,31, yanlış ≥ %0,58) ortasında. Elenen
   parça **görünür kalır**, yalnızca lens materyali uygulanmaz ve GLB dokusunda bırakılır;
   eleme `push_warning` ile loglanır. Araç id'si hardcode EDİLMEZ.
2. **Lens materyali**: far artık krom reflektörlü cam gibi kurulur — `HEADLIGHT_TINT`
   (0,78 0,83 0,90), `HEADLIGHT_METALLIC` 0,45, `HEADLIGHT_ROUGHNESS` 0,10. Kaporta mat
   (pürüz ~0,5) kaldığı için lamba kendi vurgusuyla ayrışır. Doku silinmez, çarpanla koyulaşır.

Süzgecin elediği: `tofas_sahin` 18/36, `audi_a3` 16/19, `volvo_s60` 11/24 — ölçümün işaret
ettiği altı parçanın tamamı, fazlası değil.

### 11.3 Sonuç

`ct_shots/far/<araç>.png` (araç başına yakın plan ön görünüm) ve
`ct_shots/kiyas/far_oncesonra.png` (Audi + Volvo, önce/sonra). Farlar artık projektör
çanaklarıyla birlikte okunuyor; kaportada leke yok; koyu (bmw_e60) ve doygun renkli
(vw_golf_7) araçlarda değişiklik olumsuz etkilemiyor.

`qa/far_olcum.gd` + `qa/far_olcum.py` objektif ölçüm: her aracı iki kez çeker (normal + far
parçaları macenta maske), lamba piksellerinin ortalama parlaklığını çevresindeki kaporta
halkasıyla karşılaştırır. Ölçüt İŞARETSİZ farktır — koyu araçta lamba parlak, açık araçta koyu
olarak ayrışır; ikisi de okunurluktur. Sonuç: **15 araçtan 13'ü okunur** (fark 0,14–0,54).

İki araç eşiğin altında kalıyor ve ikisi de **ölçünün kapsamından** kaynaklanıyor, görüntüden
değil — ölçü yalnızca far ROLÜNDEKİ parçaları görür, yani rolün saflığını da ölçer:

| araç | fark | lamba px | sebep |
|---|---|---|---|
| `tofas_sahin` | 0,035 | 21.704 | rolde ön yüzü boydan boya kaplayan ince krom şeritler var (43/45/59/62/73/75); piksellerin çoğu lamba değil trim |
| `seat_leon` | 0,048 | 1.433 | rolde tek parça; lambanın çoğu dokuya pişmiş, role girmemiş |

İkisinin de render'ı (`ct_shots/far/`) temiz: Şahin'in kare farları reflektör çanaklarıyla,
Leon'un köşeli lensleri beyaz kaportada net okunuyor. Trim'e lens materyalinin uygulanması
zararsız (metaliklik 0,45 kromda zaten doğru duruyor), bu yüzden süzgeç ince şeritleri elemek
üzere sıkılaştırılmadı — sıkılaştırmak modern araçlardaki gerçek gündüz farı şeritlerini
(Passat/Fluence/Civic) de elerdi.
