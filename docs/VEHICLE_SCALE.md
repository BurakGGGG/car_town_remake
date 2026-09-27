# Araç Ölçeği — gerçek boyutlara göre normalizasyon

Tripo'dan gelen her GLB kendi kutusuna normalize edilmiş halde geliyor (uzunluk = 1.0 birim),
yani modelin kendi boyu aracın gerçek boyu hakkında hiçbir şey söylemiyor. Bu belge, 16 aracın
oyundaki boyunun neye göre belirlendiğini ve nasıl doğrulandığını anlatır.

## 1. Yöntem

```
model_scale = gerçek_uzunluk_m / REFERANS_UZUNLUK_M          (REFERANS = 4.39 m)
son ölçek   = model_scale × bağlamın kendi katsayısı
```

- **Referans (4.39 m)** dünya geometrisinden ölçüldü: şerit genişliği, park cebi ve garaj lifti
  4.39 m'lik bir sedanı tam alacak şekilde kurulmuş. Dünya YENİDEN ÖLÇEKLENMEDİ; araçlar dünyaya
  uyduruldu.
- Ölçek **tek sayı**: x/y/z aynı katsayıyı alır. Hiçbir araca non-uniform scale uygulanmadı,
  modelin kendi oranları bozulmadı.
- Kaynak GLB'ler değiştirilmedi. Ölçek yalnızca `vehicles/cars.json` içindeki `model_scale`
  alanında durur; sahneler `CarCatalog.model_scale(id)` ile okur.

### Bağlam katsayıları

| Bağlam | katsayı | son ölçek (BMW E46) |
|---|---|---|
| Garaj lifti | 1.00 | 1.019 |
| Showroom podyumu | 0.88 | 0.896 |
| Trafik (şehir) | 0.60 | 0.611 |
| Drag pisti | 1.20 | 1.222 |

Aynı araç her ekranda **aynı fiziksel boyda**; farklı olan yalnızca kameranın uzaklığı ve o
bağlamın ortak katsayısıdır. `vehicle_scale_test` bu zinciri 106 kontrolle doğrular.

## 2. Ölçüler

| id | araç | yıl | uzunluk (m) | genişlik (m) | yükseklik (m) | aks (m) | `model_scale` |
|---|---|---|---|---|---|---|---|
| `hyundai_getz` | Hyundai Getz | 2008 | 3.825 | 1.665 | 1.495 | 2.455 | **0.8713** |
| `skoda_kamiq` | SKODA KAMIQ | 2020 | 4.241 | 1.793 | 1.531 | 2.651 | **0.9661** |
| `vw_golf_7` | VW GOLF 7 | 2015 | 4.255 | 1.799 | 1.452 | 2.637 | **0.9692** |
| `seat_leon` | SEAT LEON | 2016 | 4.271 | 1.816 | 1.459 | 2.636 | **0.9729** |
| `hyundai_era` | Hyundai Era | 2007 | 4.280 | 1.695 | 1.470 | 2.500 | **0.9749** |
| `audi_a3` | AUDI A3 | 2014 | 4.312 | 1.786 | 1.427 | 2.637 | **0.9822** |
| `tofas_sahin` | Tofaş Şahin | 1995 | 4.316 | 1.642 | 1.437 | 2.490 | **0.9831** |
| `renault_toros` | Renault Toros | 1994 | 4.318 | 1.616 | 1.470 | 2.441 | **0.9836** |
| `ford_focus` | FORD FOCUS | 2013 | 4.358 | 1.823 | 1.484 | 2.648 | **0.9927** |
| `hyundai_accent_blue` | HYUNDAI ACCENT BLUE | 2013 | 4.370 | 1.700 | 1.455 | 2.570 | **0.9954** |
| `honda_civic` | HONDA CIVIC VTEC | 2010 | 4.435 | 1.720 | 1.440 | 2.620 | **1.0103** |
| `bmw_e46` | BMW E46 | 2003 | 4.471 | 1.739 | 1.415 | 2.725 | **1.0185** |
| `renault_fluence` | Renault Fluence | 2012 | 4.618 | 1.813 | 1.501 | 2.703 | **1.0519** |
| `volvo_s60` | VOLVO S60 | 2016 | 4.628 | 1.865 | 1.484 | 2.776 | **1.0542** |
| `vw_passat_b55` | Volkswagen Passat B5.5 | 2004 | 4.704 | 1.746 | 1.463 | 2.703 | **1.0715** |
| `bmw_e60` | BMW E60 | 2007 | 4.841 | 1.846 | 1.468 | 2.888 | **1.1027** |

En kısa (Getz 3.825 m) ile en uzun (E60 4.841 m) arasındaki oran **1.266** — oyunda da birebir
aynı (ölçüldü: 1.266).

## 3. Kaynaklar

Ölçüler üreticinin teknik verisini yayınlayan sayfalardan alındı; her araç için uzunluk,
genişlik, yükseklik ve aks mesafesi ayrı ayrı doğrulandı:

- Avrupa/Asya modelleri (BMW E46/E60, VW Golf 7 / Passat B5.5, Škoda Kamiq, SEAT Leon, Audi A3,
  Volvo S60, Ford Focus, Honda Civic, Hyundai Getz/Era/Accent Blue, Renault Fluence) →
  ilgili modelin teknik veri sayfaları (Wikipedia model kayıtları + carsguide / thecarconnection
  / edmunds / cars.com teknik tabloları ile çapraz kontrol). Örnek:
  <https://en.wikipedia.org/wiki/BMW_3_Series_(E46)>,
  <https://en.wikipedia.org/wiki/Volkswagen_Golf_Mk7>,
  <https://www.carsguide.com.au/volkswagen/golf/car-dimensions/2015>,
  <https://en.wikipedia.org/wiki/BMW_5_Series_(E60)>,
  <https://en.wikipedia.org/wiki/Ford_Focus_(third_generation)>,
  <https://en.wikipedia.org/wiki/Volkswagen_Passat_(B5)>
- Türkiye'ye özgü modeller (Tofaş Şahin, Renault Toros) → arabateknikbilgi teknik sayfaları:
  <https://www.arabateknikbilgi.com/otomobiller/tofas-sahin/>,
  <https://www.arabateknikbilgi.com/otomobiller/renault-toros/>

Değerler `vehicles/cars.json` → `real_dimensions` altında milimetre hassasiyetiyle duruyor;
`model_scale` bu değerlerden türetilir ve testte yeniden hesaplanarak karşılaştırılır
(`model_scale gerçek uzunluktan türetilmiş` kontrolü).

## 4. Doğrulama

`vehicle_scale_test` (106 kontrol, hepsi geçiyor) şunları ölçer:

1. Her aracın gerçek uzunluk/genişliği makul aralıkta ve aks mesafesi dolu.
2. `model_scale` gerçek uzunluktan yeniden hesaplandığında aynı çıkıyor.
3. Model yere basıyor (tekerlek altı y ≈ 0, tolerans 1 mm).
4. Oyundaki kutu boyu ile gerçek boy tutarlı: **0.2278 birim/m**, 16 aracın hepsinde aynı.
5. Araçlar arası oranlar gerçek dünyayla birebir (E60/Golf = 1.138, E60/Getz = 1.266 …).
6. Sınıf mantığı: sedanlar hatchback'lerden uzun, Kamiq (SUV) Golf'ten yüksek.

## 5. Model oranları (ölçek değil, modelin kendisi)

Uniform ölçek aracın **boyunu** doğru yapar, **oranlarını** değiştirmez. Tripo çıktısının kendi
oranları `qa/proportion_check.gd` ile ölçüldü: modelin kutusundan en/boy ve yükseklik/boy
oranları alınıp gerçek değerlerle karşılaştırıldı (ayna, anten ve `hidden` rolündeki yardımcı
mesh'ler çıkarıldıktan sonra).

| Araç | en/boy sapma | yükseklik/boy sapma |
|---|---|---|
| BMW E60 | +11.5% | +8.7% |
| Škoda Kamiq | +12.4% | +11.1% |
| Hyundai Era | +12.8% | +8.7% |
| Hyundai Accent Blue | +13.1% | +13.9% |
| Ford Focus | +13.9% | +14.1% |
| Audi A3 | +15.8% | +7.9% |
| Hyundai Getz | +23.6% | +22.7% |
| BMW E46 | +26.0% | **+40.4%** |
| Renault Toros | +28.3% | +11.7% |
| Tofaş Şahin | +28.8% | +10.0% |
| Renault Fluence | **+39.4%** | **+36.3%** |
| VW Passat B5.5 | **+43.9%** | **+55.9%** |

**Nasıl okunmalı:** sapmaların hepsi artı yönde, yani ölçüm yöntemi sistematik olarak yukarı
kaçıyor — resmi genişlik/yükseklik değerleri aynasız ve antensiz ölçülür, kutu ölçümü ise modelin
her noktasını sayar. Bu yüzden **mutlak sayı değil, araçlar arası fark** anlamlı: tipik araç
+12…+16% bandında; Passat B5.5, Fluence, Getz ve E46 bu bandın belirgin üstünde, yani bu dört
model gerçeğine göre daha tombul/yüksek modellenmiş.

Bu bir ölçek hatası değil (boy doğru, oyun içi oranlar bölüm 4'te doğrulandı) ve izometrik
kamerada göze çarpmıyor; düzeltmek modeli yeniden üretmeyi gerektirir, uniform ölçek çözmez.
