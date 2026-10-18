// AUTO YARD Cloud Functions (car-town-remake).
//   raceNewsPush    yarış haberi yazılınca alıcıya telefon bildirimi (mantık news.js)
//   cleanupExpired  saatte bir süresi dolan davet / bildirim kaydı / şikâyet / e-posta kodu silinir (mantık cleanup.js)
//   emailCodeSend   E-POSTA İLE GİRİŞ: 6 haneli kodu oyuncunun e-postasına yollar (mantık email_code.js, gönderim Resend)
//   emailCodeVerify kodu doğrular, Firebase özel jetonu döner (oyun signInWithCustomToken ile girer)
// Test: npm test. Bölge europe-west4: Firestore eur3 (europe-west1 / europe-west4) ile aynı yer.
// Gönderim: firebase/ klasöründen `firebase deploy --only functions --project car-town-remake` (Blaze planı gerekir).

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getAuth } = require("firebase-admin/auth");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { handleRaceNews } = require("./news");
const { cleanupExpired } = require("./cleanup");
const { sendCode, verifyCode, CodeError } = require("./email_code");

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
      if (!res.ok) throw new Error(`Resend ${res.status}: ${(await res.text()).slice(0, 300)}`);
    },
  };
}

// İsteği yapan adres (yalnızca gönderim sınırı için, özeti saklanır). Cloud Run X-Forwarded-For'un ilk öğesi istemcinin
// yazdığı olabilir; yanıltılırsa yalnızca adres sınırı aşılır, e-posta başına sınır (saatte 5) yine geçerli.
function clientIp(req) {
  const forwarded = String(req.rawRequest.headers["x-forwarded-for"] || "").split(",")[0].trim();
  return forwarded || req.rawRequest.ip || "";
}

function toHttpsError(e) {
  if (e instanceof CodeError) return new HttpsError(e.status, e.reason, { reason: e.reason, ...e.extra });
  console.error(e);
  return new HttpsError("internal", "internal", { reason: "internal" });
}

const CODE_OPTS = { region: "europe-west4", maxInstances: 5 };

exports.emailCodeSend = onCall({ ...CODE_OPTS, secrets: [RESEND_API_KEY] }, async (req) => {
  try {
    return await sendCode({
      db: getFirestore(), mail: mailer(), email: req.data && req.data.email, lang: req.data && req.data.lang,
      ip: clientIp(req), now: Date.now(),
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
    console.log(`raceNewsPush ${eventId} → ${event.params.uid}: ${result}`);
  },
);

exports.cleanupExpired = onSchedule(
  { schedule: "every 60 minutes", region: "europe-west4", timeZone: "Europe/Istanbul", maxInstances: 1 },
  async () => {
    const deleted = await cleanupExpired({ db: getFirestore(), now: Date.now() });
    console.log(`cleanupExpired: ${JSON.stringify(deleted)}`);
  },
);
