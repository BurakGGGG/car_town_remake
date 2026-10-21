// AUTO YARD Cloud Functions (car-town-remake).
//   raceNewsPush    yarış haberi yazılınca alıcıya telefon bildirimi (mantık news.js)
//   mailPush        yönetim paneli postaya hediye bırakınca alıcıya "hediyen var" bildirimi (mantık mail.js)
//   promoRedeem     oyuncu kupon kodu girince doğrular, ödülü postaya bırakır (mantık promo.js)
//   dailyStats      her gece günlük sayılar stats_daily/{gün}: hesaplı oyuncu, aktif 1/7/30 gün, bildirim, yeni hesap (stats.js)
//   cleanupExpired  saatte bir süresi dolan davet / bildirim kaydı / şikâyet / e-posta kodu silinir (mantık cleanup.js)
//   emailCodeSend   E-POSTA İLE GİRİŞ: 6 haneli kodu oyuncunun e-postasına yollar (mantık email_code.js, gönderim Resend)
//   emailCodeVerify kodu doğrular, Firebase özel jetonu döner (oyun signInWithCustomToken ile girer)
//   accountCleanup  Firebase hesabı silinince o UID'nin bütün verisi silinir (mantık account_cleanup.js)
// Test: npm test. Bölge europe-west4: Firestore eur3 (europe-west1 / europe-west4) ile aynı yer.
// Gönderim: firebase/ klasöründen `firebase deploy --only functions --project car-town-remake` (Blaze planı gerekir).

const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getAuth } = require("firebase-admin/auth");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { handleRaceNews } = require("./news");
const { handleMailCreated } = require("./mail");
const { handleRedeem } = require("./promo");
const { writeDailyStats } = require("./stats");
const { cleanupExpired } = require("./cleanup");
const { sendCode, verifyCode, CodeError, clientIp } = require("./email_code");
const { cleanupAccount } = require("./account_cleanup");
const functionsV1 = require("firebase-functions/v1");

// Resend API anahtarı (Secret Manager; kodda / depoda YOK). Kurulum: firebase functions:secrets:set RESEND_API_KEY
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const MAIL_FROM = "Auto Yard <noreply@autoyard.online>";

initializeApp();

// Yerel emülatörde (npm run e2e) bildirim FCM'ye GİTMEZ: gönderilecek ileti _e2e_fcm koleksiyonuna yazılır, test/e2e.mjs
// içeriğini denetler. FUNCTIONS_EMULATOR yalnızca Functions emülatöründe "true"dur; canlıda her zaman gerçek FCM.
function messaging() {
  if (process.env.FUNCTIONS_EMULATOR !== "true") return getMessaging();
  return { send: (msg) => getFirestore().collection("_e2e_fcm").add(msg) };
}

// E-posta gönderimi: canlıda Resend (alan adı autoyard.online doğrulanmış olmalı). Emülatörde (npm run email-e2e) e-posta
// GİTMEZ: ileti _e2e_mail koleksiyonuna yazılır, test/email_e2e.mjs kodu oradan okur.
function mailer() {
  if (process.env.FUNCTIONS_EMULATOR === "true") {
    return { send: (msg) => getFirestore().collection("_e2e_mail").add({ ...msg, at: Date.now() }) };
  }
  return {
    async send({ to, subject, text, html }) {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${RESEND_API_KEY.value()}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from: MAIL_FROM, to: [to], subject, text, html }),
      });
      // Günlüğe yalnızca durum + hata türü (validation_error, rate_limit_exceeded…): Resend'in iletisi alıcı adresini içerebilir
      if (!res.ok) {
        const kind = await res.json().then((b) => String((b && b.name) || "?").slice(0, 40), () => "?");
        throw new Error(`Resend ${res.status} ${kind}`);
      }
    },
  };
}

function toHttpsError(e) {
  if (e instanceof CodeError) return new HttpsError(e.status, e.reason, { reason: e.reason, ...e.extra });
  console.error(e);
  return new HttpsError("internal", "internal", { reason: "internal" });
}

// cors: false — oyun yerel HTTP ile çağırır (Origin yok, CORS'a ihtiyacı yok). Varsayılan (true) her siteye izin veriyordu:
// başka bir sayfa ziyaretçilerinin tarayıcısından kod gönderip her ziyaretçinin ayrı adresiyle adres sınırını aşabilirdi.
const CODE_OPTS = { region: "europe-west4", maxInstances: 5, cors: false };

exports.emailCodeSend = onCall({ ...CODE_OPTS, secrets: [RESEND_API_KEY] }, async (req) => {
  try {
    return await sendCode({
      db: getFirestore(), mail: mailer(), email: req.data && req.data.email, lang: req.data && req.data.lang,
      ip: clientIp(req.rawRequest.headers, req.rawRequest.ip), now: Date.now(),
    });
  } catch (e) {
    throw toHttpsError(e);
  }
});

exports.emailCodeVerify = onCall(CODE_OPTS, async (req) => {
  try {
    const result = await verifyCode({
      db: getFirestore(), auth: getAuth(), email: req.data && req.data.email, code: req.data && req.data.code,
      now: Date.now(),
    });
    console.log(`emailCodeVerify: ${result.created ? "yeni hesap" : "var olan hesap"}`);
    return result;
  } catch (e) {
    throw toHttpsError(e);
  }
});

exports.raceNewsPush = onDocumentWritten(
  { document: "users/{uid}/races/{eventId}", region: "europe-west4", maxInstances: 5 },
  async (event) => {
    const eventId = event.params.eventId || "";
    if (!eventId.startsWith("e_")) return;
    const before = event.data && event.data.before.exists ? event.data.before.data() : null;
    const after = event.data && event.data.after.exists ? event.data.after.data() : null;
    const result = await handleRaceNews({
      db: getFirestore(),
      messaging: messaging(),
      recipient: event.params.uid,
      sender: eventId.slice(2),
      before,
      after,
      now: Date.now(),
    });
    console.log(`raceNewsPush: ${result}`);   // kimin kimi yendiği (UID çifti) günlüğe yazılmaz
  },
);

// Herkese gönderilen hediyede panel her oyuncuya bir belge yazar: aynı anda çok sayıda tetikleme (örnek başına 80 eşzamanlı).
exports.mailPush = onDocumentCreated(
  { document: "users/{uid}/mail/{mailId}", region: "europe-west4", maxInstances: 10 },
  async (event) => {
    const result = await handleMailCreated({
      db: getFirestore(),
      messaging: messaging(),
      uid: event.params.uid,
      mail: event.data ? event.data.data() : null,
    });
    console.log(`mailPush: ${result}`);
  },
);

exports.promoRedeem = onDocumentCreated(
  { document: "users/{uid}/redeem/{code}", region: "europe-west4", maxInstances: 5 },
  async (event) => {
    const result = await handleRedeem({ db: getFirestore(), uid: event.params.uid, code: event.params.code, now: Date.now() });
    console.log(`promoRedeem: ${result}`);   // kod / UID günlüğe yazılmaz
  },
);

// Auth "kullanıcı silindi" olayı yalnızca 1. nesilde var (2. nesil Auth olaylarını desteklemiyor, ikisi aynı dosyada
// yan yana çalışır). 1. nesil europe-west4'ü desteklemiyor → europe-west1 (Firestore eur3 bu bölgeyi de kapsar).
exports.accountCleanup = functionsV1.region("europe-west1").runWith({ timeoutSeconds: 300, memory: "512MB" })
  .auth.user().onDelete(async (user) => {
    const deleted = await cleanupAccount({ db: getFirestore(), uid: user.uid });
    console.log(`accountCleanup: ${JSON.stringify(deleted)}`);   // yalnızca sayılar
  });

exports.dailyStats = onSchedule(
  { schedule: "10 3 * * *", region: "europe-west4", timeZone: "Europe/Istanbul", maxInstances: 1 },
  async () => {
    const { day, stats } = await writeDailyStats({ db: getFirestore(), auth: getAuth(), now: Date.now() });
    console.log(`dailyStats ${day}: ${JSON.stringify(stats)}`);   // yalnızca sayılar
  },
);

exports.cleanupExpired = onSchedule(
  { schedule: "every 60 minutes", region: "europe-west4", timeZone: "Europe/Istanbul", maxInstances: 1 },
  async () => {
    const deleted = await cleanupExpired({ db: getFirestore(), now: Date.now() });
    console.log(`cleanupExpired: ${JSON.stringify(deleted)}`);
  },
);
