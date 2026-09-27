# QA + TASARIM İNCELEMESİ — ilerleme refactor'ü

Tarih: 2026-09-26. Kapsam: `8abe498` commit'indeki ilerleme refactor'ünün bağımsız doğrulaması.
Yöntem: **önce ölç → sonra değiştir → tekrar ölç.** Bütün sayılar gerçek `Main.tscn` koşularından
ya da oyunun kendi sabitleriyle çalışan kesikli olay modelinden gelir.

---

## 1. ÖZET

| Alan | Sonuç |
|---|---|
| Kayıt (yeni oyun, v5/v6/v7 göçü, bozuk dosya) | 33/33 geçti |
| Uç durumlar (14 senaryo) | 44/44 geçti |
| Görev / boya / bulut regresyonu | 3 paket, 0 hata |
| Ekonomi (6 yapılandırma × 6.000 döngü) | ölçüldü, aşağıda |
| 0-120 dk ilerleme (temiz oyuncu) | ölçüldü, aşağıda |
| Bulunan sorun | 5 (3'ü düzeltildi, 2'si öneri) |

## 2. ÖNCEKİ RAPORUN İKİ YANLIŞI (bu QA'de düzeltildi)

1. **"Geç oyunda müşterilerin %45-59'u geri çevriliyor."** Yanlış. O rakam modelin *tamir hızı 1*
   varsayımından geliyordu; gerçek oyuncu ilk 10 dakikada tamir hızını 5'e çıkarıyor. Ayrıca model
   trafik havuzu geri beslemesini görmüyordu (bay'deki araç yoldan çekilir → aday azalır).
   **Gerçek ölçüm: kuyruğun dolu olduğu süre %0,0** (G2+2 ve G3+3, 10'ar dk). Sistem kuyruk değil
   **müşteri arzı** sınırlıdır.
2. **"Tavan 8. rütbe."** Yanlış. Ölçülen tavan 439.500 ₺, 8. rütbe eşiği 440.000 ₺ idi: %100
   tamamlamış oyuncu 8. rütbeye **500 ₺** yetişemiyordu. Eşik 430.000'e çekildi.

## 3. EKONOMİ — gerçek oyun ölçümü

Oyuncu seviyesi her garaj seviyesinin doğal seviyesi, tamir hızı 5 (oyuncu bunu 10. dakikada alıyor).

| Yapılandırma | süre | tamir/dk | ₺/dk | alan doluluğu | kuyruk | müşteri/dk | kuyruk dolu |
|---|---|---|---|---|---|---|---|
| Garaj 1 + 1 alan (sv.4) | 10 dk | 3,10 | 457 | 0,29 | 0,00 | 3,20 | %0,0 |
| Garaj 2 + 1 alan (sv.8) | 10 dk | 3,80 | 568 | 0,30 | 0,00 | 3,90 | %0,0 |
| Garaj 2 + 2 alan (sv.8) | 10 dk | 3,50-4,00 | 936-1.143 | 0,36-0,58 | 0,01 | 3,50 | %0,0 |
| Garaj 3 + 1 alan (sv.13) | 10 dk | 5,30 | 994 | 0,47 | 0,01 | 5,40 | %0,0 |
| Garaj 3 + 2 alan (sv.13) | 20 dk | 3,15 | 1.555 | 0,83 | 1,09 | 3,35 | — |
| Garaj 3 + 3 alan (sv.13) | 20 dk | 3,40 | 2.113 | 0,79 | 0,85 | 3,60 | %0,0 |
| Garaj 3 + 3 alan (sv.15) | 20 dk | 3,90 | 2.021 | 0,68 | 0,43 | 3,90 | %0,0 |
| Garaj 4 + 3 alan (sv.15) **trafik 8** | 20 dk | 3,80 | 2.206 | 0,73 | 0,75 | 3,90 | %0,0 |
| Garaj 4 + 3 alan (sv.15) **trafik 10** | 20 dk | 3,30-3,90 | 2.398-2.798 | 0,82-0,95 | 0,88-1,77 | 3,50-4,15 | %0,0 |

**Amortisman:** 2. alan (5.000 ₺) → +368…575 ₺/dk → 9-14 dk. 3. alan (12.000 ₺) → +558 ₺/dk → 22 dk.
Garaj 4 (60.000 ₺) trafik 8 ile → +185 ₺/dk → **5,4 saat**; trafik 10 ile → +377…777 ₺/dk → 77-160 dk.

## 4. EKONOMİ — model (6 yapılandırma × 6.000 müşteri döngüsü)

Model gerçek koşularla kalibre edilir ve **üst sınırı** gösterir (trafik havuzu geri beslemesi yok).

| Garaj | Alan | Sv | Hız | tamir/dk | ₺/dk | XP/dk | doluluk | red % | kuyruk | ort. bekleme | ort. iş |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 4 | 5 | 2,51 | 369 | 25,1 | 0,23 | 0,0 | 0,00 | 0,0 sn | 5,4 sn |
| 2 | 1 | 8 | 5 | 3,67 | 623 | 36,7 | 0,33 | 0,0 | 0,00 | 0,0 sn | 5,4 sn |
| 2 | 2 | 8 | 5 | 3,42 | 1.294 | 81,1 | 0,69 | 7,2 | 0,65 | 11,4 sn | 24,3 sn |
| 3 | 1 | 13 | 5 | 5,23 | 1.002 | 52,2 | 0,47 | 0,0 | 0,00 | 0,0 sn | 5,4 sn |
| 3 | 2 | 13 | 5 | 4,30 | 1.836 | 101,9 | 0,87 | 17,4 | 1,76 | 24,5 sn | 24,3 sn |
| 3 | 3 | 13 | 5 | 4,23 | 2.488 | 141,8 | 0,87 | 18,4 | 1,73 | 24,5 sn | 37,5 sn |

Tamir hızı 1 ile aynı satırlarda red oranı %26-44'e çıkıyor: **tamir hızı geliştirmesi kuyruk
basıncını yöneten asıl kaldıraçtır.** İçerik etkisi: yalnızca kısa işler varken (sv.4) ek alan geliri
HİÇ değiştirmiyor (5,25 → 5,22 tamir/dk) — alanı değerli yapan şey uzun işlerdir.

## 5. İLERLEME — 0-120 dk, temiz oyuncu

| Dakika | Para | XP | Sv | Garaj | Alan | Araç | Değer | Rütbe | ★ | ₺/dk | doluluk | kuyruk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 4.030 | 326 | 3 | 1 | 1 | 1 | 91.500 | 1 | 0 | 428 | 0,33 | 0,00 |
| 20 | 10.220 | 665 | 5 | 1 | 1 | 1 | 96.500 | 1 | 4 | 469 | 0,28 | 0,00 |
| 30 | 601 | 1.031 | 6 | 2 | 2 | 1 | 113.500 | 2 | 4 | 538 | 0,15 | 0,00 |
| 45 | 11.033 | 2.113 | 9 | 2 | 2 | 2 | 128.500 | 2 | 5 | 1.112 | 0,55 | 0,11 |
| 60 | 9.726 | 3.078 | 10 | 2 | 2 | 3 | 148.500 | 2 | 5 | 980 | 0,51 | 0,07 |
| 90 | 15.478 | 6.467 | 13 | 3 | 3 | 4 | 220.500 | 4 | 10 | 1.792 | 0,60 | 0,71 |
| 120 | 2.405 | 10.051 | 15 | 3 | 3 | 6 | 305.500 | 5 | 12 | 1.898 | 0,68 | 0,49 |

Toplam 413 tamir, 156.405 ₺ tamir geliri. Kilometre taşları: tamir hızı 2-5 (0-10 dk) · Garaj 2
(25,0) · Alan 2 (29,4) · Şahin (37,7) · Toros (55,2) · Garaj 3 (70,5) · Alan 3 (76,0) · Era (84,0) ·
Getz (99,0) · Passat (119,5). **Ortalama 11 dakikada bir satın alma.**

## 6. UÇ DURUMLAR (44 doğrulama)

| Senaryo | Sonuç |
|---|---|
| Garaj yükseltilirken bekleyen müşteri | Müşteri kaybolmuyor, sonra tamire alınabiliyor |
| Aktif tamir varken alan satın alma | Aktif iş bozulmuyor, kapasite anında artıyor |
| Garaj değişirken trafik | Sınır 6→8→10 uygulanıyor, araç sayısı sınırı aşmıyor, bekleme noktası 4'e çıkıyor |
| 3. alan kilitliyken 3. iş | Başlatılamıyor (kapasite = açılmış alan) |
| Uzun iş + tek alan | 60 sn'den uzun iş hiç gelmiyor (`min_bays`) |
| Uzun iş + iki alan | BOYA + DÖŞEME geliyor, REVİZYON (3 alan ister) gelmiyor |
| Kayıt/yükleme + aktif tamir | Aktif tamir bilinçli kaydedilmiyor; açılışta temiz, hayalet araç yok |
| Kayıt/yükleme + garaj seviyesi | Fiziksel seviye, arz ve trafik sınırı geri geliyor |
| Kayıt/yükleme + alan kilidi | Alan sayısı ve kilit görselleri doğru |
| Para yetmezken yükseltme | Reddediliyor, para ve seviye değişmiyor |
| Negatif para | 0'a kırpılıyor, 0 bakiyeden harcama yapılamıyor |
| Maksimum garaj (4) | Fazlası reddediliyor, para harcanmıyor |
| Maksimum alan (3) | Fazlası reddediliyor, kapasite 3'te kalıyor |
| Maksimum garaj değeri | 439.500 ₺ → 8. rütbe; eşik üstü/negatif değerler güvenli |

## 7. OYUNCU DENEYİMİ

| Soru | Cevap | Dayanak |
|---|---|---|
| Garaj seviyesinin önemi anlaşılıyor mu? | **Hayır.** Plakada yalnızca "SEVİYE 2 · 12.000 ₺" yazıyor | Etkisi ölçülü ve büyük (+111 ₺/dk, 3. bekleme noktası, alan 2'nin kilidi) ama hiçbir yerde yazmıyor |
| Alan satın almanın değeri anlaşılıyor mu? | **Hayır.** "TAMİR ALANI 2 · 5.000 ₺ · ALANI AÇ" | Asıl etkisi (BOYA İŞİ'nin açılması + 2 kat gelir) görünmüyor |
| Müşteri arzı artışı fark ediliyor mu? | **Kısmen.** Trafik 4→6→8→10 fiziksel olarak görülüyor | Sayısal geri bildirim yok |
| Uzun işlerin avantajı anlaşılıyor mu? | **Hayır, hatta ters görünüyor.** MOTOR 150 ₺/10 sn = 15 ₺/sn, BOYA 600 ₺/90 sn = 6,7 ₺/sn | Uzun iş saniye başına daha KÖTÜ; değeri "boştaki alanı doldurması" (G3+2: karışık 1.555 ₺/dk, yalnız kısa 1.004) |
| Oyuncu neden araç alsın? | **Zayıf.** Tek getiri garaj değeri → rütbe → yeni araç kilidi | Araçlar gelir üretmiyor; 15.000-50.000 ₺'lik alım yalnızca prestij |
| Garaj değeri anlamlı hedef mi? | **Evet.** Plaka + 10 basamaklı merdiven + duvar tabelası + araç kilitleri | 120 dk'da 85.000 → 305.500 ₺ (1 → 5. rütbe) |
| %45-59 red oyuncuya açıklanıyor mu? | **Soru geçersiz** — gerçek red oranı %0,0 | Kuyruk hiç dolmuyor |

## 8. CAR TOWN PRENSİP KARŞILAŞTIRMASI

| Prensip | Değerlendirme | Not |
|---|---|---|
| Player Level | **DOĞRU** | XP eğrisi, seviye ödülü, içerik kilidi (iş + araç) |
| Garage Expansion | **DOĞRU** | 4 fiziksel seviye, dünyada tabela, arzı ve alanı açıyor |
| Garage Value | **DOĞRU / EKSİK** | Araç + geliştirme + alan + boya var; **dekor yok** (9-10. rütbe onun için ayrıldı) |
| Work Bay Capacity | **DOĞRU** | Ayrı satın alma, dünyada kilitli alan, kapasite = açılmış alan |
| Short/Medium/Long Jobs | **DOĞRU / EKSİK** | 6-300 sn yelpazesi var; Car Town'ın "sonra gel" (offline) boyutu yok |
| Vehicle Progression | **EKSİK** | Araç sahipliği yalnızca garaj değeri; araç başına durum/geliştirme/kullanım yok |
| Long-term Goals | **DOĞRU** | Rütbe merdiveni (8 ulaşılabilir, 9-10 gelecek), 15 görevlik zincir, ustalık yıldızları |
| Job Mastery | **DOĞRU / EKSİK** | Sayaç + 5 yıldız + XP çarpanı + tek seferlik ödül çalışıyor; **kendi ekranı yok**, yalnızca tamir plakasında bir satır |

Hiçbir prensipte **FAZLA** yok: yasaklı sistemlerin (Mystery Box, gacha, worker, fuel, racing,
multiplayer, social) hiçbiri eklenmedi.

## 9. GELECEK ÖZELLİKLER İÇİN MİMARİ UYGUNLUK (yalnızca kontrol, kod yok)

| Özellik | Mimari hazır mı | Gerekecek iş |
|---|---|---|
| Job Mastery ekranı | **Evet** | `mastery_changed` / `mastery_up` sinyalleri + `count/stars/next_threshold` API'si mevcut |
| Araç başına ilerleme | **Evet, örüntü var** | `VehicleOwnership._paint` sözlüğü aynı desende (id → durum) + kayıt alanı (v8) |
| Worker / otomasyon | **Evet** | `start_repair` / `collect` kodla çağrılabiliyor (simülasyonlar bunu yapıyor), `RepairState.bay_index` var |
| Fuel / enerji | **Evet** | Tek giriş noktası `start_repair` |
| Dekor (garaj değeri kalemi) | **Evet** | `GarageValue.compute` toplama tabanlı, yeni kalem bir fonksiyon |
| Racing / multiplayer / social | **Hayır** | Bugün hiçbir altyapı yok (CloudSaveManager'daki Firebase profili tek dayanak) |

## 10. BULUNAN SORUNLAR

| # | Sorun | Kanıt | Karar |
|---|---|---|---|
| 1 | `CarCatalog._normalize` beyaz liste: JSON'a eklenen alan sessizce düşüyor | `min_level` / `min_garage_rank` refactor sırasında çalışmamıştı | **Düzeltildi** (SCHEMA tablosu) |
| 2 | 8. rütbe ulaşılamıyordu (tavan 439.500, eşik 440.000) | Uç durum testi | **Düzeltildi** (eşik 430.000) |
| 3 | Garaj 4 (60.000 ₺) ekonomik olarak anlamsız: +185 ₺/dk, 5,4 saat amorti | 20 dk gerçek koşu, G3 2.021 vs G4 2.206 ₺/dk | **Düzeltildi** (trafik 8 → 10; yeniden ölçüm 2.398-2.798 ₺/dk) |
| 4 | Kilitli alan plakası "TAMİR ALANI Sv.2 GEREKLİ" diyordu — o geliştirme artık yok | Kod okuması | **Düzeltildi** ("ÖNCE GARAJI SEVİYE 2'E GENİŞLET") |
| 5 | Süren işin ödülü plakada güncel çarpanla gösteriliyordu; garaj iş sırasında büyürse yazan ≠ ödenen | Kod okuması | **Düzeltildi** (`set_info(type, state.repair_reward)`) |

## 11. YALNIZCA ÖNERİ (bu aşamada kod yazılmadı)

1. **Yükseltme plakaları somut etkiyi yazsın**: "GARAJ SEVİYE 2 → daha sık müşteri · 3. bekleme
   noktası · 2. tamir alanı açılır". Ölçülen etki var, oyuncuya söylenmiyor.
2. **Alan plakası içerik açtığını söylesin**: "2. ALAN → BOYA İŞİ (90 sn, 600 ₺) gelmeye başlar".
3. **Tamir plakasında ₺/dk gösterilsin**: uzun işin mantığı ("boştaki alanı doldurur") ancak böyle
   okunur; bugün rakamlar tersini ima ediyor.
4. **Araç almanın oyun içi karşılığı olsun** (ör. sahip olunan sınıf müşteri kalitesini etkilesin).
   Bugün araç saf prestij; en büyük para gideri en az hissedilen getiriye sahip.
5. **Rütbe merdiveninde bugünkü tavanın üstü "YAKINDA" işaretlensin** — 9-10 kalıcı kilitli görünüyor.
6. **Ustalık ekranı** (Job Mastery'nin kendi listesi) — veri ve sinyaller hazır.

## 12. KODDA GERÇEKTEN YAPILAN DEĞİŞİKLİKLER

| Dosya | Değişiklik | Neden |
|---|---|---|
| `vehicles/car_catalog.gd` | `SCHEMA` tablosu + şema tabanlı `_normalize` + tanınmayan alan uyarısı | Sessiz alan kaybı (ölçüm: 7 aracın tüm alanları değişiklik öncesi/sonrası **bit bit aynı**) |
| `gameplay/garage_value.gd` | 8. rütbe eşiği 440.000 → 430.000 | Ölçülen tavan 439.500 ₺ |
| `gameplay/repair/repair_manager.gd` | `SUPPLY[4].traffic` 8 → 10 | Garaj 4 amortismanı 5,4 saatten 77-160 dk'ya |
| `ui/hud/hud.gd` | Kilitli alan plakası metni + süren işin ödülü state'ten | Yanlış yönlendiren metin / yazan ≠ ödenen |
| `ui/hud/garage_screen.gd` | Alan satırı "Sv.2" → "GARAJ 2" | Aynı karışıklık |
| `ui/hud/repair_panel.gd` | `set_info(type, fixed_reward)` | Süren işin ödülü sabit |
| `docs/PROGRESSION_REFACTOR.md` | İki yanlış tespitin düzeltilmesi | Bkz. §2 |

Performans (1152×648, vsync kapalı): garaj 1 → 923 FPS / 230 çizim / 83,5 MB · garaj 2 → 578 / 393 /
84,2 · garaj 3 → 487 / 540 / 84,2 · **garaj 4 (trafik 10) → 449 FPS / 568 çizim / 94,8 MB** · garaj
ekranı → 176 FPS / 1.061 çizim / 112,9 MB (açılış 7 ms). Hedefler (60 FPS, <700 çizim, <120 MB) tutuyor.
