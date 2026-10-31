# AUTO YARD 1.1.5 (sürüm kodu 16) — Play Console "Yenilikler" notları (2026-10-31)

Düzeltme + akış sürümü (1.1.4'ten sonra, kullanıcı oturumu 2026-10-31):

- PROFİL KENDİLİĞİNDEN: hesapla (Google / e-posta) girişte sunucuda profil yoksa rastgele "Usta1234" adı + arkadaş kodu
  sessizce kurulur (SocialManager.auto_profile); ad PROFİL › DÜZENLE ya da ARKADAŞLAR'dan değişir. HUD isim plakası
  takma adı gösterir (yoksa hesap adı). Test: social_test §15.
- KUPON KODU (MARKET › KOD GİR): sonuç büyük renkli plakada (yeşil ✔ / kırmızı ✖), kabul edilen kodun hediyesi HEDİYEN
  GELDİ! ekranıyla hemen açılır (HABERLER'e gitmeden; "HEDİYEN VAR" yazısı çıkmaz, posta gecikirse HABERLER'de duyurulur),
  KULLAN klavyeyi kapatır, yazarken klavye açıksa pano yukarı kayar. Testler: app_config_test, mail_test.
- HAFTALIK TABLO › İZLE: ARKADAŞLAR listesi önbellekteki satırdan koşu kaydını siliyordu → o listeden / kendi satırından
  İZLE bir saat boyunca "Bu koşu şu an açılamadı" (Crashlytics "Parse JSON failed" non-fatal'ları). Leaderboard._fetch
  kopya döndürür; tablodaki süre önbellektekini tutmazsa yeniden indirilir; bu sürümde olmayan araçla koşu → "oyunu
  güncelle". Test: leaderboard_test §6.
- MODİFİYE: sergilenen araç parçası takılırken hem sergide hem liftte iki araç gibi görünüyordu → liftteyken sergisi gizli
  (düzenlerken görünür), alandan çıkınca geri gelir; pişmiş gölge yeniden pişer. Test: performance_mod_test.
- TANILAMA (oyuncuya görünmez): 1.1.4'ün tek çökmesi PowerVR sürücüsünde shader derlerken (RugOne Xever 7 Pro, açılışta,
  3 olay / 1 oyuncu) + Oppo A5s'te sahne shader'ı derlenemiyor. Crashlytics günlüğüne GPU / sürücü sürümü ve açılış
  adımları (oyun sahnesi, ön ısıtma adımları), derlenemeyen shader'ın malzeme kimliği; Analytics oyuncu özelliği `gpu`.
  Düzeltme değil — sonraki raporda hangi shader olduğu görünsün diye.

Modifiye yeniden modelleme / WheelKit işi bu sürümde YOK (git stash "MODIFIYE WIP", ertelendi).

Play Console sınırı dil başına 500 karakter. Fransızcada noktalama öncesi U+00A0.

## tr-TR

```
Yenilikler ve düzeltmeler
• Hesabınla girince profilin hazır gelir, takma adını PROFİL'den değiştirebilirsin
• Kupon kodu: sonuç artık net görünür, hediyen hemen açılır, klavye yazdığın kodu örtmez
• Haftalık tabloda İZLE artık arkadaşlarının koşularını sorunsuz açar
• Modifiye sırasında sergideki araç garajda ikinci kez görünmez
• Kararlılık iyileştirmeleri
```

## en-US

```
What's new and fixes
• Your profile is ready as soon as you sign in; change your nickname in PROFILE
• Coupon codes: clear results, your gift opens right away, and the keyboard no longer hides your code
• WATCH on the weekly board now opens your friends' runs reliably
• A displayed car no longer shows up twice in your garage while it's being tuned
• Stability improvements
```

## es-419

```
Novedades y correcciones
• Tu perfil está listo al iniciar sesión; cambia tu apodo en PERFIL
• Códigos: resultado claro, tu regalo se abre al instante y el teclado ya no tapa el código
• VER en la tabla semanal abre bien las carreras de tus amigos
• El auto en exhibición ya no aparece dos veces en el garaje mientras recibe tuning
• Mejoras de estabilidad
```

## de-DE

```
Neues und Korrekturen
• Dein Profil ist nach der Anmeldung sofort bereit; Spitzname im PROFIL änderbar
• Codes: klares Ergebnis, dein Geschenk öffnet sich sofort, die Tastatur verdeckt den Code nicht mehr
• REPLAY in der Wochentabelle öffnet die Läufe deiner Freunde zuverlässig
• Ein ausgestelltes Auto erscheint beim Tuning nicht mehr doppelt in der Garage
• Stabilitätsverbesserungen
```

## fr-FR

```
Nouveautés et corrections
• Ton profil est prêt dès la connexion ; change ton pseudo dans PROFIL
• Codes : résultat clair, ton cadeau s’ouvre aussitôt et le clavier ne cache plus ton code
• REVOIR dans le classement hebdo ouvre bien les courses de tes amis
• Une voiture exposée n’apparaît plus en double dans le garage pendant son tuning
• Améliorations de stabilité
```
