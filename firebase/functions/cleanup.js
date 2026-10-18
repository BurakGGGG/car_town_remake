// SÜRESİ DOLAN KAYITLARIN TEMİZLİĞİ — saf mantık (index.js saatlik zamanlayıcıya bağlar; test/cleanup.test.js sahte db
// ile, test/cleanup_e2e.mjs emülatörde sınar). Gizlilik politikasındaki saklama süreleri burada uygulanır (2026-10-17):
//   invites/{jeton}         `at` (sn) + 1 saat  → davet linki 1 saat geçerli; süresi dolan ilk saatlik turda silinir
//                           (oluşturan cihaz değişmiş ya da hesap silinmiş olsa da kalmaz)
//   push_log/l_{alıcı}_{g}  `at` (ms) + 1 gün   → yalnızca 6 saatlik bildirim sınırı için gerekir
//   reports/x_{ş}_{hedef}   `at` (sn) + 180 gün → şikâyet incelemesi ve kötüye kullanımı önleme süresi
//   email_codes/{özet}      `at` (ms) + 1 saat  → giriş kodu (10 dk geçerli) + saatlik gönderim sınırı (email_code.js)
//   email_ips/{özet}        `at` (ms) + 1 saat  → adres başına saatlik gönderim sınırı
// Belgeler istemciye kapalı ya da yalnızca sahibine açık; silmeyi yönetici yetkisiyle bu fonksiyon yapar.

const DAY_S = 24 * 60 * 60;
const RULES = [
  { collection: "invites", unit: "s", maxAgeS: 60 * 60 },
  { collection: "push_log", unit: "ms", maxAgeS: DAY_S },
  { collection: "reports", unit: "s", maxAgeS: 180 * DAY_S },
  { collection: "email_codes", unit: "ms", maxAgeS: 60 * 60 },
  { collection: "email_ips", unit: "ms", maxAgeS: 60 * 60 },
];
const BATCH = 400;

/** Kuralın kesim değeri (alanın kendi biriminde): `at` bundan küçükse belge süresini doldurmuştur. */
function cutoffFor(rule, nowMs) {
  return rule.unit === "ms" ? nowMs - rule.maxAgeS * 1000 : Math.floor(nowMs / 1000) - rule.maxAgeS;
}

/**
 * Süresi dolan belgeleri siler. db: Firestore (yönetici) benzeri
 * {collection(ad).where(alan, "<", değer).limit(n).get() → {docs[{ref}], size, empty}, batch() → {delete(ref), commit()}}.
 * Dönüş: koleksiyon → silinen belge sayısı.
 */
async function cleanupExpired({ db, now }) {
  const deleted = {};
  for (const rule of RULES) {
    const cutoff = cutoffFor(rule, now);
    let total = 0;
    for (;;) {
      const snap = await db.collection(rule.collection).where("at", "<", cutoff).limit(BATCH).get();
      if (snap.empty) break;
      const batch = db.batch();
      for (const doc of snap.docs) batch.delete(doc.ref);
      await batch.commit();
      total += snap.size;
      if (snap.size < BATCH) break;
    }
    deleted[rule.collection] = total;
  }
  return deleted;
}

module.exports = { RULES, cutoffFor, cleanupExpired };
