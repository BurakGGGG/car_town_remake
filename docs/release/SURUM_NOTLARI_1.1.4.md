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

HESABA KAYDET (kullanıcı kararı: taslak B + C): misafire sv5 ve sv10'da sakin anda bir kez İLERLEMENİ KAYDET kartı
(seviye / para / elmas, GOOGLE / E-POSTA İLE KAYDET, SONRA); kartı görmüş misafir hesaba girip kaydı buluta eşitlenince
+20 gem (bir kez, SaveReminder). Misafirken MARKET'te uyarı şeridi + HESABA KAYDET. Güncellemeyle eşiği geçmiş misafir
kartı bir kez görür. Olaylar: save_prompt_show / save_prompt_choice / save_bonus / save_strip_tap.

MARKET ücretsiz gem kartı: yüklenirken yalnız YÜKLENİYOR (kullanıcı isteği); DE "WERBUNG ANSEHEN" kartta kesiliyordu →
bağlamlı kısa yazılar (Loc.tc "market": ES VER VÍDEO, DE ANSEHEN / LÄDT…, FR VOIR LA PUB / UN INSTANT).

Play Console sınırı dil başına 500 karakter. Fransızcada noktalama öncesi U+00A0.

## tr-TR

```
Düzeltmeler
• Bazı telefonlarda oyun sırasında yaşanan ani kapanma giderildi
• Misafir oyunculara: ilerlemeni hesabına kaydet, 20 gem hediye kazan
• Küçük iyileştirmeler
```

## en-US

```
Fixes
• Fixed a crash that could close the game on some phones during play
• Guest players: save your progress to your account and get 20 gems
• Small improvements
```

## es-419

```
Correcciones
• Se corrigió un cierre inesperado del juego en algunos teléfonos
• Invitados: guarda tu progreso en tu cuenta y llévate 20 gemas
• Pequeñas mejoras
```

## de-DE

```
Korrekturen
• Absturz behoben, der das Spiel auf manchen Handys unerwartet schloss
• Gäste: Fortschritt im Konto sichern und 20 Juwelen erhalten
• Kleine Verbesserungen
```

## fr-FR

```
Corrections
• Correction d’un plantage qui pouvait fermer le jeu sur certains téléphones
• Invités : sauvegarde ta progression sur ton compte et reçois 20 gemmes
• Petites améliorations
```
