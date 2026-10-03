# Performans Raporu (2026-10-02)

**Bu oturumda yeni performans ölçümü ALINMADI.** Gerçek cihaz yok (adb boş), masaüstü FPS benchmark'ı çalıştırılmadı, 20× sahne döngüsü / bellek sızıntısı testi yapılmadı. Aşağıdakiler önceki oturumlarda kaydedilmiş ölçümler (proje hafızası; bu oturumda tekrar doğrulanmadı):

| Konu | Değer | Kaynak |
|---|---|---|
| Garaj VRAM | 275 → 151 MB (doku sıkıştırma düzeltmesi, 9 araç) | önceki oturum |
| Garaj açılışı | 775 → 99 ms | önceki oturum |
| 2048² albedo | sıkıştırmasız 16 MB → ETC2/DXT 2.67 MB | önceki oturum |
| Garaj çizim bütçesi | ~1150 çizim çağrısı (16 araç sahipken 8 model) | önceki oturum |
| Release AAB | 128.9 MB (bu oturumda ölçüldü) | bu oturum |
| Teslim edilen mimari | arm64-v8a, GL Compatibility | bu oturum |

Gereken ölçümler (yapılmadı): Samsung A24'te garaj/showroom/mastery/profil/kasa/drag için FPS ve kare süresi, tepe RAM, açılış süresi, 20× döngüde bellek eğrisi.
