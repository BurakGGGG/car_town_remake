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
