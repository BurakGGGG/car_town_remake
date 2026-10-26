# AUTO YARD 1.1.3 (sürüm kodu 14) — Play Console "Yenilikler" notları (2026-10-27)

Düzeltme sürümü. Crashlytics (1.1.2, Xiaomi / Oppo): arkadaş garajı ziyaretinde (Emre Usta) oyun çöküyordu. Ziyarette
kendi sahne ağaçtan çıkar; o sırada arkadan yüklenen reklam → AdService.readiness_changed → AdOfferButton.refresh →
AdService._level → get_tree() boş → SceneTree.get_first_node_in_group. Yayın derlemesinde GDScript boş nesneye metot
çağrısını denetlemediği için (gdscript_vm.cpp, kontrol yalnız DEBUG_ENABLED) masaüstünde hata, telefonda çöküş. Aynı
sınıftan üç yol daha kapatıldı: ARKADAŞLAR rozeti (sosyal / davet / posta cevabı), HUD bildirim plakası, değerlendirme
penceresi zamanlayıcısı (oturumun 3. dakikası), davet ödülü posta okuması. Test: visit_test 8. bölüm.

Play Console sınırı dil başına 500 karakter. Fransızcada noktalama öncesi U+00A0.

## tr-TR

```
Düzeltmeler
• Arkadaş garajı ziyaretinde bazı telefonlarda yaşanan çökme giderildi
• Küçük iyileştirmeler
```

## en-US

```
Fixes
• Fixed a crash on some phones when visiting a friend's garage
• Small improvements
```

## es-419

```
Correcciones
• Se corrigió un cierre inesperado en algunos teléfonos al visitar el taller de un amigo
• Pequeñas mejoras
```

## de-DE

```
Korrekturen
• Absturz auf manchen Handys beim Besuch der Werkstatt eines Freundes behoben
• Kleine Verbesserungen
```

## fr-FR

```
Corrections
• Correction d’un plantage sur certains téléphones lors de la visite du garage d’un ami
• Petites améliorations
```
