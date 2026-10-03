# AUTO YARD — Yayın Kontrol Listesi (2026-10-02)

✅ yapıldı ve doğrulandı · ⚠️ kısmen · ❌ açık · ⛔ test edilemedi

## Kimlik / derleme
- ✅ Uygulama adı AUTO YARD (AAB `godot_project_name_string`)
- ✅ Proje ikonu, launcher, adaptive (ön/arka), monokrom = AUTO YARD (AAB'den görsel doğrulama)
- ✅ targetSdk 36, minSdk 24, arm64-v8a, AAB, versionName 1.0.0 / code 1
- ✅ İzinler: INTERNET, ACCESS_NETWORK_STATE (+ Play Services READ_GSERVICES)
- ❌ Gerçek yükleme anahtarı üret, release env değişkenleriyle AAB'yi yeniden imzala
- ❌ Paket kimliği kararı (`com.cartownBurak.app`) — yayından ÖNCE
- ❌ Play App Signing SHA-1'ini Firebase'e ekle, `google-services.json` yenile
- ❌ Her yüklemede `version/code` artır

## Kod / güvenlik
- ✅ Bozuk kayıt fuzz (520 senaryo) çökme yok
- ✅ Debug kısayolu (`TEST_MONEY`) yalnız debug derlemede; AAB `--export-release`
- ✅ Sahte SES düğmesi gizli
- ✅ Android GERİ tuşu işleyicisi (router testli)
- ⛔ GERİ tuşu gerçek cihazda

## Test
- ✅ `tools/run_tests.sh` → 1289 OK / 0 FAIL (18 paket)
- ✅ Kasa RNG 4×20.000 çekiliş, sapma ≤ 0,0024
- ⛔ Gerçek Android: kur/aç/arka plan/zorla kapat/sil-yeniden kur
- ⛔ 20× sahne döngüsü bellek testi, kare süresi, açılış süresi (cihaz)
- ⛔ Çözünürlük matrisi ekran görüntüleri, metin/yazım taraması, yalnız-renk erişilebilirlik

## Play Console (kullanıcı)
- ❌ Uygulamayı oluştur, AAB yükle (iç test)
- ❌ Data safety (Google hesabı e-posta/kimlik, oyun kaydı; reklam/analitik yok), hesap silme URL'si + beyan
- ❌ Gizlilik politikası URL'si
- ❌ İçerik derecelendirme, hedef kitle, reklam beyanı = yok, uygulama erişimi
- ❌ Mağaza: ad ≤ 30, kısa ≤ 80, tam ≤ 4000 karakter; 512 ikon (hazır), öne çıkan grafik, ekran görüntüleri
- ❌ Kişisel hesap için kapalı test şartı: Play Console'dan doğrula
- ❌ Pre-launch raporunu incele
