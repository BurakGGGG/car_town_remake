# AUTO YARD 1.1.4 (sürüm kodu 15) — Play Console "Yenilikler" notları (2026-10-28)

Düzeltme sürümü. Crashlytics (1.1.2–1.1.3, son 7 gün 47 olay / 17 oyuncu; TCL, Tecno, Xiaomi, Samsung; çökmesiz
kullanıcı %70): ses iş parçacığında SIGSEGV — OpenSL _buffer_callbacks → AudioDriver::audio_server_process →
AudioStreamPlaybackResampled::mix → AudioStreamPlaybackWAV::_mix_internal, hata adresi sayfa başı. Godot 4.7 WAV verisine
pay bırakmıyor ve döngüde loop_end karesini de okuyor; kodla üretilen beş döngülü ses (yarış / trafik / egzotik motor,
siren, şehir ortamı) loop_end = kare sayısı veriyordu → verinin bir kare dışı okunuyordu, Android'in bellek ayırıcısı
(Scudo) büyük tamponu koruma sayfasının önüne koyduğundan telefonda çöküş. Düzeltme: LoopedWav.loop_forward (sona ilk
karenin kopyası, loop_end eski kare sayısı; döngü dikişsiz). Test: looped_wav_test.

Ölçüm: ad_offer_view (reklam teklifi göründü), login_gate_show / login_choice / login_done (giriş ekranı hunisi),
oyuncu özelliği account (guest / google / email / facebook).

Play Console sınırı dil başına 500 karakter. Fransızcada noktalama öncesi U+00A0.

## tr-TR

```
Düzeltmeler
• Bazı telefonlarda oyun sırasında yaşanan ani kapanma giderildi
• Küçük iyileştirmeler
```

## en-US

```
Fixes
• Fixed a crash that could close the game on some phones during play
• Small improvements
```

## es-419

```
Correcciones
• Se corrigió un cierre inesperado del juego en algunos teléfonos
• Pequeñas mejoras
```

## de-DE

```
Korrekturen
• Absturz behoben, der das Spiel auf manchen Handys unerwartet schloss
• Kleine Verbesserungen
```

## fr-FR

```
Corrections
• Correction d’un plantage qui pouvait fermer le jeu sur certains téléphones
• Petites améliorations
```
