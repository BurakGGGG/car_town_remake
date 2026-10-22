// İADE EDİLEN SATIN ALMALAR — saf mantık (index.js iapVoided zamanlayıcısına bağlar; test/refunds.test.js sahte db ile sınar).
//
// Google Play Developer API purchases.voidedpurchases.list: iade edilen, ters ibraz (chargeback) olan ya da iptal edilen
// uygulama içi satın almalar. Her biri için doğrulama kaydı iap/{belirteç özeti} (iap.js) aranır:
//   - kayıt yoksa: bu belirteç hiç doğrulanmamış (gem verilmemiş ya da doğrulama öncesi sürüm) → yalnız sayılır
//   - kayıt zaten iade işaretliyse: atlanır (zamanlayıcı aynı pencereyi yeniden okur, işlem tek sefer)
//   - kayıt varsa: {voided, voided_at, voided_reason, voided_source} yazılır; kayıtta hesap (uid) varsa oyuncuya
//     users/{uid}/refunds/{özet} = {product, quantity, order, at} bırakılır. Oyun (PurchaseManager) bunu okur, verdiği
//     gemi düşer (bakiye 0'ın altına inmez), belgeyi siler. Misafir satın almasında hesap yok: geri alınamaz, yalnız işaret.
// Ön kayıt ödülü ücretsizdir (iade edilemez); listede çıksa da oyun gem düşmez (PurchaseManager).

const crypto = require("crypto");

const UID_RE = /^[A-Za-z0-9_-]{1,128}$/;

function tokenKey(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

/**
 * items: voidedPurchases ([{purchaseToken, orderId, voidedTimeMillis, voidedSource, voidedReason}]).
 * db: Firestore benzeri {doc(yol) → {get() → {exists, data()}, set(v, {merge})}}. Dönüş: {seen, unknown, already, marked, notified}.
 */
async function processVoided({ items, db, now }) {
  const out = { seen: 0, unknown: 0, already: 0, marked: 0, notified: 0 };
  const nowS = Math.floor(now / 1000);
  for (const item of Array.isArray(items) ? items : []) {
    const token = item && typeof item.purchaseToken === "string" ? item.purchaseToken : "";
    if (!token) continue;
    out.seen += 1;
    const key = tokenKey(token);
    const ref = db.doc(`iap/${key}`);
    const snap = await ref.get();
    if (!snap.exists) {
      out.unknown += 1;
      continue;
    }
    const rec = snap.data() || {};
    if (rec.voided === true) {
      out.already += 1;
      continue;
    }
    const voidedAt = Math.floor(Number(item.voidedTimeMillis || now) / 1000);
    await ref.set({
      voided: true,
      voided_at: voidedAt,
      voided_reason: Number.isInteger(item.voidedReason) ? item.voidedReason : -1,   // 0 diğer, 1 pişmanlık, 2 sahtekârlık, 3 dostça olmayan ters ibraz…
      voided_source: Number.isInteger(item.voidedSource) ? item.voidedSource : -1,   // 0 kullanıcı, 1 geliştirici, 2 Google
      at: nowS,   // saklama süresi (cleanup.js) iade tarihinden yeniden başlar
    }, { merge: true });
    out.marked += 1;
    const uid = typeof rec.uid === "string" ? rec.uid : "";
    if (UID_RE.test(uid)) {
      await db.doc(`users/${uid}/refunds/${key}`).set({
        product: String(rec.product || ""),
        quantity: Number.isInteger(rec.quantity) && rec.quantity > 0 ? rec.quantity : 1,
        order: String(rec.order || item.orderId || ""),
        at: voidedAt,
      });
      out.notified += 1;
    }
  }
  return out;
}

module.exports = { tokenKey, processVoided };
