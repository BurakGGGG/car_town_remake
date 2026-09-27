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
