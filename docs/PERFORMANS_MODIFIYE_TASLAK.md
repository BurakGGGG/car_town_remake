# PERFORMANS MODİFİYESİ — Pazar araştırması + öneri taslağı (2026-10-13)

Önceki belge: docs/PERFORMANS_MODIFIYE_ARASTIRMA.md (orijinal Car Town). Bu belge türün diğer oyunlarına
bakar ve bizim simülasyona oturan bir sistem önerir. **Karar değil, taslak**; §6'daki sorular cevaplanınca
tasarım belgesine dönüşür. Kod yok.

Not: web aramasıyla, kaynak sayfaların özetlerinden derlendi (ağ politikası wiki'leri doğrudan açmaya
izin vermiyor). Sayılar oyunların topluluk wiki'lerinden; sürümden sürüme değişebilir.

## 1. Türdeki oyunlar nasıl yapıyor

| Oyun | Kategori sayısı | Kategoriler | Kademe | Kademe adları | Araç sınıfı |
|---|---|---|---|---|---|
| **CSR Racing 2** (drag, mobil) | 7 | Motor, Turbo, Emme, Nitro, Gövde, Lastik, Şanzıman | 5 + S6 + füzyon yuvaları | Kademe numarası, ama her kademenin GERÇEK parça adı var (turbo: temel turbo kiti → baypas valfi → büyük türbin → aktüatör → porlu/parlatılmış gövde) | Tier 1–5 |
| **NFS Most Wanted (2005)** | 7 | Motor, Şanzıman, Süspansiyon, Nitro, Lastik, Fren, Turbo | 4 (+ Street) | Street · Pro · Super Pro · Ultimate | — |
| **NFS Heat** | parça bazlı | Krank, ECU, soğutma, egzoz, turbo, nitro, süspansiyon, lastik… | 5+ | Stock · Sport · Elite · Ultimate · Ultimate+ | Performans puanı |
| **Forza Horizon 5** | 6 grup | Motor, Platform & Yol Tutuş, Şanzıman/Aktarma, Lastik & Jant, Aero, Dönüşüm | parça başına 2–4 | Street · Sport · Race (parça tipine göre) | D · C · B · A · S1 · S2 · X (PI 100–999) |
| **Gran Turismo 7** | dükkân katmanı | ECU, hafifletme, turbo, lastik… | 5 katman | Sports · Club Sports · Semi-Racing · Racing · Extreme | PP puanı |
| **Real Racing 3** | 7 | Motor, Aktarma, Gövde, Süspansiyon, Egzoz, Fren, Lastik & Jant | 1–5 | Seviye; üst kademe daha uzun takılır | R puanı |

Kaynak örnekleri: CSR2'de Stage 1–3 anında takılıyor, üstü bekletiyor. RR3'te üst kademeler daha uzun
sürüyor ve daha pahalı. GT7'de üst katmanlar oyuncu seviyesiyle açılıyor. Forza'da sınıf PI aralığıyla
belirleniyor: yükseltme sınıf atlatıyor. RR3'te McLaren Speedtail full yükseltmeyle 0-60: 2,30 → 1,98 sn
(−%14), son hız 250 → 277 mph (+%11).

**Ortak desen:**
1. **6–7 kategori.** Hemen hepsinde: motor, aşırı besleme (turbo), hava (emme/egzoz), şanzıman, lastik, gövde
   (ağırlık/aero). Drag oyunlarında nitro da var (ayrı mekanik).
2. **4–5 kademe.** Kademeler bir "nadirlik" renk diliyle gösteriliyor (gri → yeşil → mavi → mor → altın).
3. **Kademe adı + gerçek parça adı.** "Motor 3" yok: oyuncu "YARIŞ · Dövme Piston" görüyor.
4. **Her kategori farklı bir değeri yükseltiyor.** Hızlanma, son hız, tutuş, vites. Oyuncu aracının zayıf
   yönünü seçerek kapatıyor (CSR2 / NFS'de bazı parçalar bir değeri artırıp başka birini düşürüyor).
5. **Üst kademeler zaman ve kilit istiyor.** Seviye, bekleme süresi ya da premium para.

## 2. Bizim simülasyonda neye karşılık gelir

`DragRaceSim.EngineSpec`'teki her değer gerçek bir fiziksel karşılık; modifiye doğrudan bunları değiştirir,
böylece 0-100 ve son hız **ölçülerek** değişir (bugün gerçek 0-100 tablosu nasıl kalibre ediliyorsa öyle):

| Kategori | Değiştirdiği değer | Oyuncunun gördüğü |
|---|---|---|
| MOTOR | `peak_torque_nm` ↑ | Beygir ↑, 0-100 ↓ |
| TURBO | tork ↑, tepe tork devri yukarı | Beygir ↑↑, 0-100 ↓ (orta-üst devirde) |
| HAVA AKIŞI | `redline_rpm` / `peak_power_rpm` ↑, az tork | Son hız ↑, 0-100 ↓ az |
| ŞANZIMAN | son vites / `final_drive`, `SHIFT_TIME` ↓ | Son hız ↑, vites geçişi hızlanır |
| LASTİK | `grip_mu` ↑ | Kalkış patinajı ↓ (önden çekişlide en çok) |
| GÖVDE | `mass` ↓, `frontal_area` × Cd ↓ | 0-100 ↓, son hız ↑ |
| (sonra) NİTRO | yeni mekanik: basılı tut → kısa itiş | Ayrı bir buton ve beceri; ilk sürüme önerilmez |

Bonus: bugün çekiş tipi gerçek fark yaratıyor (FWD kalkış payı 0,55, RWD 0,68, AWD 0,95). **LASTİK** önden
çekişli bir Passat için anlamlı bir seçim olur, AWD Audi RS6 için neredeyse boşa harcanmış para. Oyuncunun
"benim araca ne lazım" diye düşünmesi istenen şey bu.

## 3. Öneri: 6 kategori × 5 kademe

### Kademeler (renkli)

| # | Kademe | Renk | Fikir |
|---|---|---|---|
| 1 | **SOKAK** | gri | Gündelik bolt-on: ucuz, anında |
| 2 | **SPOR** | yeşil | Tanınmış spor parça |
| 3 | **YARIŞ** | mavi | Pist parçası |
| 4 | **PRO** | mor | Profesyonel yarış parçası |
| 5 | **EFSANE** | altın | Tavan; nadir, pahalı |

### Parça adları (kademe × kategori)

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| **MOTOR** | Stage 1 Yazılım | Spor Eksantrik | Dövme Piston | Stroker Krank | Yarış Bloğu |
| **TURBO** | Turbo Yükseltme | Büyük İntercooler | Hibrit Türbin | Büyük Turbo | Twin-Turbo |
| **HAVA AKIŞI** | Spor Hava Filtresi | Soğuk Hava Emişi | Downpipe | Paslanmaz Manifold | Titanyum Yarış Egzozu |
| **ŞANZIMAN** | Kısa Vites Kolu | Spor Debriyaj | Hafif Volan | Yakın Oranlı Kutu | Sıralı Yarış Şanzımanı |
| **LASTİK** | Spor Lastik | Yarı Slik | Drag Radial | Slik | Pro Drag Slik |
| **GÖVDE** | Hafif Jant | Karbon Kaput | Kova Koltuk & İç Söküm | Karbon Panel & Spoiler | Tam Karbon Gövde |

Hepsi `Loc.t` ile çevrilir (İngilizce: STREET / SPORT / RACE / PRO / LEGEND).

### Etki hedefleri (kalibrasyonla tutturulur)

Full yükseltme = her kategorinin 5 kademesi. Hedef payı kademelere azalarak dağılır (ilk kademe hissedilir,
son kademe pahalı ama küçük). Toplam hedef: **0-100 −%20, son hız +%12** (RR3'ün −%14 / +%11'ine yakın,
Car Town'un +320 hp'sinden çok daha ölçülü).

| Kategori | Full etki | Kademe başına (yaklaşık) |
|---|---|---|
| MOTOR | 0-100 −%8 | −%2,0 · −%1,8 · −%1,6 · −%1,4 · −%1,2 |
| TURBO | 0-100 −%6 | |
| HAVA AKIŞI | 0-100 −%2, son hız +%2 | |
| ŞANZIMAN | son hız +%8, vites geçişi 0,085 → 0,060 sn | |
| LASTİK | kalkış: FWD 0-100 −%4, RWD −%2, AWD −%1 | |
| GÖVDE | 0-100 −%3, son hız +%2 | |

### Örnek: VW Passat B5.5 1.9 TDI (C sınıfı, FWD)

| Adım | 0-100 | Son hız | Beygir (gösterge) |
|---|---|---|---|
| Fabrika | 9,9 sn | 208 km/sa | 130 |
| + MOTOR · Stage 1 Yazılım | **9,7** | 208 | ~136 |
| + ŞANZIMAN · Kısa Vites Kolu | 9,7 | **~211** | ~136 |
| Full (6 × 5) | **~7,9** | **~233** | ~170 |

Full Passat ≈ fabrika Seat Leon (8,0 sn, B). Yani bir C aracı full yükseltmeyle B'nin alt ucuna çıkar,
ama A'ya (E46 6,5 sn) yetişemez. Sınıflar anlamını korur. (Sayılar hedef; gerçek değerler simülasyonda
ölçülerek tutturulur, bugünkü 0-100 kalibrasyonu gibi.)

## 4. Ekranda nasıl görünür (taslak)

- Garajda araç seçili → **PERFORMANS** sekmesi: 6 kategori kartı, her birinde 5 kademe çentiği, bir
  sonraki parçanın adı, fiyatı ve **önce → sonra** değeri ("0-100  9,9 → 9,7 sn").
- Üstte dinamometre benzeri bir şerit: beygir / 0-100 / son hız / GENEL puan; değişen değer yeşil
  yanıp söner.
- Sınıf atlayınca (§6) "C → B SINIFI" rozeti.
- Yarış ekranındaki egzoz alevi, motor sesi ve pist akışı zaten `performance_ratio`'ya bağlı; yükseltilen
  araçta kendiliğinden güçlenir.

## 5. Bilerek ilk sürüme alınmayanlar

- **NİTRO:** yeni bir girdi mekaniği (basılı tut / doğru anda bas). Ayrı bir iş, ikinci aşamaya.
- **Ayar (tuning):** CSR2'deki son oran, nitro süresi, lastik basıncı gibi ince ayarlar ve dyno testi.
  Önce parça sistemi otursun.
- **Füzyon / nadir parça yuvaları** (CSR2): loot sistemi gerektirir. Kasa sistemimizle ileride bağlanabilir.

## 6. Karar gereken sorular

1. **Sınıf atlama:** Yükseltilen araç GENEL puanına göre sınıf atlasın mı (Forza gibi), yoksa katalog
   sınıfında mı kalsın? Atlarsa rakip havuzu (`RaceManager`, performansa göre rakip) yükseltilmiş araca göre
   seçilir; kalırsa oyuncu kendi sınıfında ezer geçer.
2. **Takma süresi:** SOKAK ve SPOR anında; YARIŞ, PRO ve EFSANE tamir alanında süreyle mi takılsın (CSR2 /
   RR3 deseni + bizim tamir alanı döngümüz)? Gem ile hızlandırma?
3. **Para:** Hepsi ₺ mi, yoksa EFSANE kademe gem mi? Orijinal Car Town'da premium kademeler şikâyet
   konusuydu (önceki belge §1.3).
4. **Kilit:** Kademeler oyuncu seviyesiyle mi (GT7), garaj rütbesiyle mi açılsın?
5. **Fiyat:** Araç değerine oranlı mı (pahalı araçta pahalı parça), sabit mi?
6. **Kategori sayısı:** 6 uygun mu, yoksa ilk sürümde 4 mü (MOTOR, ŞANZIMAN, LASTİK, GÖVDE)?

## Kaynaklar

- CSR Racing 2 Wiki — Car Upgrades: https://csrracing-2.fandom.com/wiki/Car_Upgrades?oldid=1235
- Pocket Gamer — CSR2 ayar (lastik, nitro, son oran): https://www.pocketgamer.co.uk/csr-racing-2/how-to-tune-your-car-in-csr-racing-2-tires-nitro-and-final-drive/
- NFS Wiki — Most Wanted Performance Tuning: https://nfs.fandom.com/wiki/Need_for_Speed:_Most_Wanted/Performance_Tuning
- Gameswelt — NFS Most Wanted ipuçları (7 kategori, 4 kademe): https://www.gameswelt.de/need-for-speed-most-wanted/komplettloesung/need-for-speed-most-wanted-einsteigertipps-971/4
- Xbox Wire — NFS Carbon paketleri (Street / Pro): https://news.xbox.com/en-us/2006/11/02/need-for-speed-carbon-content/
- NFS Wiki — Heat motor parçaları: https://nfs.fandom.com/wiki/Used_225_bhp_2.0L_I4
- GTPlanet — NFS Heat tartışması: https://www.gtplanet.net/forum/threads/need-for-speed-heat-general-discussion.381038/post-12973494
- Windows Central — Forza Horizon 5 yükseltme rehberi (PI sınıfları): https://www.windowscentral.com/forza-horizon-5-upgrading-guide
- Forza Support — Performance Index and Classes: https://support.forza.net/hc/en-us/articles/360005372033-FH3-Performance-Index-and-Classes
- HackerNoon — FH5 yükseltme menüsü: https://sia.hackernoon.com/forza-horizon-5-cars-guide-how-to-build-and-tune-for-optimal-road-race-performance
- RacingGames.gg — GT7 tuning: https://racinggames.gg/gran-turismo/how-to-tune-cars-in-gran-turismo-7/
- Red Bull — GT7 tuning rehberi: https://www.redbull.com/ca-en/gran-turismo-7-tuning-setup-tips-guide
- GTPlanet — GT7 1.34 (Ultimate sekmesi): https://www.gtplanet.net/?p=125596
- Real Racing 3 Wiki — McLaren Speedtail: https://rr3.fandom.com/wiki/McLAREN_SPEEDTAIL_(2020)
- iMore — Real Racing 3 rehberi: https://www.imore.com/real-racing-3-gameplay-guide-use-these-tips-and-tricks-get-top-step-podium
- CM Games — Nitro Nation World Tour Dev Diary #1: https://cm.games/stories/nnwt-devdiary-1
