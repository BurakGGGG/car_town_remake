// SATIN ALMA DOĞRULAMASI — saf mantık (index.js iapVerify çağrısına bağlar; test/iap.test.js sahte Play ve db ile sınar).
//
// Oyun Play'den "PURCHASED" alınca elması VERMEDEN önce bu fonksiyonu çağırır: {package, product, token}. Fonksiyon
// satın almayı Google Play Developer API'den sorar (purchases.products.get) ve oyuna kesin bir durum döner:
//   ok        gerçek, ödenmiş, henüz tüketilmemiş satın alma → oyun elması verir, kaydeder, sonra tüketir
//   pending   ödeme bekliyor (kapıda ödeme vb.) → elmas yok, Play tamamlanınca yeniden gelir
//   canceled  iptal / iade edilmiş → elmas yok
//   consumed  daha önce tüketilmiş belirteç (başka cihazda / kayıtta yeniden kullanma) → elmas yok
//   invalid   Play böyle bir satın alma tanımıyor (sahte belirteç, yanlış ürün / paket) → elmas yok
// Sunucuya / Play'e ULAŞILAMAZSA (izin, kota, ağ) fonksiyon "unavailable" hatası atar: oyun elmas VERMEZ ve sonra
// yeniden dener (Play tüketilmeyen satın almayı 3 gün içinde onaylanmazsa iade eder; oyuncu parasını kaybetmez).
// Her doğrulama iap/{belirteç özeti} belgesine yazılır (istemciye kapalı; yönetim / iade incelemesi için). Saklama: 1 yıl
// (cleanup.js `at`), hesap silinince hemen (account_cleanup.js, uid alanı).
//
// KURULUM (bir kez, kullanıcı): Google Cloud'da "Google Play Android Developer API" açılır; Play Console → Kullanıcılar
// ve izinler → fonksiyonun hizmet hesabı (1027985902163-compute@developer.gserviceaccount.com) davet edilir: "Uygulama
// bilgilerini görüntüle" + "Finansal verileri görüntüle" + "Siparişleri ve abonelikleri yönet". İzin 24 saate kadar
// yayılmayabilir: o sürede Play 401/403 döner → "unavailable" (oyuncunun satın alması bekler, kaybolmaz).

const crypto = require("crypto");

const PACKAGES = ["com.autoyard.app"];
const PRODUCT_RE = /^[a-z0-9_.]{1,64}$/;
const TOKEN_RE = /^[A-Za-z0-9._:-]{20,4096}$/;
const UID_RE = /^[A-Za-z0-9_-]{1,128}$/;

class IapError extends Error {
  constructor(status, reason) {
    super(reason);
    this.status = status;   // HttpsError kodu
    this.reason = reason;
  }
}

function tokenKey(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

/** Play yanıtı → oyunun durumu. p: ProductPurchase (purchaseState 0 ödendi / 1 iptal / 2 bekliyor, consumptionState 0 / 1). */
function classify(p, productId) {
  if (!p || typeof p !== "object") return "invalid";
  if (p.productId && p.productId !== productId) return "invalid";
  const state = Number.isInteger(p.purchaseState) ? p.purchaseState : 0;
  if (state === 1) return "canceled";
  if (state === 2) return "pending";
  if (state !== 0) return "invalid";
  if (p.consumptionState === 1) return "consumed";
  return "ok";
}

/**
 * Tek doğrulama. deps: {fetchPurchase(pkg, product, token) → {code, body}, db: Firestore benzeri {doc(yol).set(v, {merge})},
 * now: ms}. Dönüş: {status, product, order, quantity, test}. Play'e ulaşılamazsa IapError("unavailable").
 */
async function verifyPurchase(data, { fetchPurchase, db, now }) {
  const pkg = String((data && data.package) || "");
  const product = String((data && data.product) || "");
  const token = String((data && data.token) || "");
  const uid = String((data && data.uid) || "");
  if (!PACKAGES.includes(pkg) || !PRODUCT_RE.test(product) || !TOKEN_RE.test(token)) {
    throw new IapError("invalid-argument", "bad_request");
  }
  let res;
  try {
    res = await fetchPurchase(pkg, product, token);
  } catch (e) {
    console.error("iap: Play'e ulaşılamadı", e && e.message);
    throw new IapError("unavailable", "unavailable");
  }
  // 400 / 404 / 410: Play bu belirteci tanımıyor (sahte ya da başka ürün). Diğerleri (401/403 izin, 429 kota, 5xx) bizim
  // tarafın sorunu: oyuncunun gerçek satın alması reddedilmesin diye "unavailable" (oyun sonra yeniden sorar).
  let status;
  let body = {};
  if (res.code === 200) {
    body = res.body || {};
    status = classify(body, product);
  } else if (res.code === 400 || res.code === 404 || res.code === 410) {
    status = "invalid";
  } else {
    console.error(`iap: Play ${res.code}`, JSON.stringify(res.body || {}).slice(0, 300));
    throw new IapError("unavailable", "unavailable");
  }
  const result = {
    status,
    product,
    order: typeof body.orderId === "string" ? body.orderId : "",
    quantity: Number.isInteger(body.quantity) && body.quantity > 0 ? body.quantity : 1,
    test: body.purchaseType === 0,
  };
  const nowS = Math.floor(now / 1000);
  try {
    await db.doc(`iap/${tokenKey(token)}`).set({
      product, status, order: result.order, quantity: result.quantity, test: result.test,
      type: Number.isInteger(body.purchaseType) ? body.purchaseType : -1,
      uid: UID_RE.test(uid) ? uid : "",   // istemcinin söylediği (doğrulanmamış; misafirde boş)
      at: nowS,
    }, { merge: true });
  } catch (e) {
    console.error("iap: kayıt yazılamadı", e && e.message);   // doğrulama sonucu yine döner
  }
  return result;
}

module.exports = { PACKAGES, IapError, tokenKey, classify, verifyPurchase };
