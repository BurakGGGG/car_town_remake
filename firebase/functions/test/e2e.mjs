// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): haber belgesi yazılınca raceNewsPush tetiklenir mi, bildirim
// iletisi FCM'nin kabul edeceği biçimde mi (emülatörde FCM yerine _e2e_fcm koleksiyonuna yazılır, index.js), 6 saatlik
// çift kaydı (push_log) yalnızca GÖNDERİLEN bildirimle mi yazılır.
// firebase/ klasöründen: firebase emulators:exec --only firestore,functions --project demo-cartown "node functions/test/e2e.mjs"
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp({ projectId: "demo-cartown" });
const db = getFirestore();
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await fn()) return true; await sleep(300); }
  return false;
}
const ev = (over = {}) => ({ name: "Bob Usta", car: "seat_leon", paint: "", build: {}, their_car: "vw_golf_7",
  won: true, revenge: false, mw: 1, ml: 0, at: 1, ...over });
const tokB = "B".repeat(40);
const sentTo = async (token) => (await db.collection("_e2e_fcm").where("token", "==", token).get()).docs.map((d) => d.data());
// FCM'nin reddettiği veri anahtarları (2026-10-17: "from" bütün bildirimleri düşürdü).
const badKeys = (data) => Object.keys(data || {}).filter((k) => k === "from" || k === "message_type"
  || k.startsWith("google.") || k.startsWith("gcm.") || typeof data[k] !== "string");

await db.doc("push/p_B").set({ token: tokB, lang: "tr", at: 1 });
await db.doc("push/p_C").set({ token: "C".repeat(40), lang: "en", at: 1 });

await db.doc("users/B/races/e_A").set(ev({ at: 1 }));
check(await waitFor(async () => (await sentTo(tokB)).length === 1), "A→B kazanma: fonksiyon tetiklendi, bildirim gönderildi");
const msg = (await sentTo(tokB))[0] || {};
check(badKeys(msg.data).length === 0 && msg.data?.sender === "A", `veri yükü FCM'ye uygun: ${JSON.stringify(msg.data)}`);
check(/^Bob Usta yarışta aracını yendi!/.test(msg.notification?.body || ""), "alıcının dilinde metin (tr)");
check((await db.doc("push_log/l_B_A").get()).exists, "gönderilen bildirim çift kaydını yazdı");
const first = (await db.doc("push_log/l_B_A").get()).data()?.at;

await db.doc("users/B/races/e_A").set(ev({ at: 2 }));
await sleep(4000);
check((await db.doc("push_log/l_B_A").get()).data()?.at === first && (await sentTo(tokB)).length === 1,
  "6 saat dolmadan ikinci A→B: gönderilmez, kayıt değişmez");

await db.doc("users/C/races/e_A").set(ev({ won: false, at: 3 }));
await sleep(4000);
check(!(await db.doc("push_log/l_C_A").get()).exists && (await sentTo("C".repeat(40))).length === 0,
  "kaybeden gönderen: bildirim / kayıt yok");

await db.doc("users/B/races/e_C").set(ev({ name: "Cem", at: 4 }));
check(await waitFor(async () => (await sentTo(tokB)).length === 2), "C→B: ayrı çift, bildirim gönderildi");

await db.doc("users/D/races/e_A").set(ev({ at: 5 }));
await sleep(4000);
check(!(await db.doc("push_log/l_D_A").get()).exists, "jetonu olmayan alıcı: hak tükenmez (kayıt yok)");
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
