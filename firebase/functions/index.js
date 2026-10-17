// AUTO YARD Cloud Functions (car-town-remake). Tek fonksiyon: yarış haberi yazılınca alıcıya telefon bildirimi.
// Mantık news.js'te (test: npm test). Bölge europe-west4: Firestore eur3 (europe-west1 / europe-west4) ile aynı yer.
// Gönderim: firebase/ klasöründen `firebase deploy --only functions --project car-town-remake` (Blaze planı gerekir).

const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { handleRaceNews } = require("./news");

initializeApp();

exports.raceNewsPush = onDocumentWritten(
  { document: "users/{uid}/races/{eventId}", region: "europe-west4", maxInstances: 5 },
  async (event) => {
    const eventId = event.params.eventId || "";
    if (!eventId.startsWith("e_")) return;
    const before = event.data && event.data.before.exists ? event.data.before.data() : null;
    const after = event.data && event.data.after.exists ? event.data.after.data() : null;
    const result = await handleRaceNews({
      db: getFirestore(),
      messaging: getMessaging(),
      recipient: event.params.uid,
      sender: eventId.slice(2),
      before,
      after,
      now: Date.now(),
    });
    console.log(`raceNewsPush ${eventId} → ${event.params.uid}: ${result}`);
  },
);
