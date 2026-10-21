// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): haber belgesi yazılınca raceNewsPush tetiklenir mi, bildirim
// iletisi FCM'nin kabul edeceği biçimde mi (emülatörde FCM yerine _e2e_fcm koleksiyonuna yazılır, index.js), 6 saatlik
// çift kaydı (push_log) yalnızca GÖNDERİLEN bildirimle mi yazılır. 2026-10-21: posta bildirimi (mailPush).
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

// POSTA (mailPush): panel postaya hediye bırakınca "hediyen var" bildirimi; HEDİYELER kapalıysa / notify false ise gitmez.
await db.doc("users/B/mail/m1").set({ title: { tr: "Açılış hediyesi" }, gems: 50, at: 1 });
check(await waitFor(async () => (await sentTo(tokB)).some((m) => m.data?.type === "mail")), "posta: mailPush tetiklendi");
const mailMsg = (await sentTo(tokB)).find((m) => m.data?.type === "mail") || {};
check(badKeys(mailMsg.data).length === 0 && /Açılış hediyesi/.test(mailMsg.notification?.body || ""),
  `posta bildirimi FCM'ye uygun, başlıklı: ${mailMsg.notification?.body}`);
await db.doc("users/B/mail/m2").set({ gems: 1, notify: false, at: 2 });
await db.doc("push/p_C").set({ token: "C".repeat(40), lang: "en", at: 1, prefs: { race: true, gift: false } });
await db.doc("users/C/mail/m3").set({ gems: 1, at: 3 });
await sleep(4000);
check((await sentTo(tokB)).filter((m) => m.data?.type === "mail").length === 1, "notify: false postası bildirim göndermez");
check((await sentTo("C".repeat(40))).length === 0, "HEDİYELER kapalı (prefs.gift false): gönderilmez");
// KUPON (promoRedeem): kod denemesi yazılınca doğrulanır, ödül postaya düşer, sonuç belgeye yazılır.
const nowS = Math.floor(Date.now() / 1000);
await db.doc("promo/REELS50").set({ title: { tr: "Reels hediyesi" }, reward: { gems: 50 }, max_uses: 1, uses: 0, until: 0, active: true });
await db.doc("users/B/redeem/REELS50").set({ at: nowS });
check(await waitFor(async () => (await db.doc("users/B/redeem/REELS50").get()).data()?.status === "ok"), "kupon: promoRedeem tetiklendi, sonuç ok");
check((await db.doc("users/B/mail/p_reels50").get()).data()?.gems === 50, "kupon ödülü postaya düştü");
await db.doc("users/C/redeem/REELS50").set({ at: nowS });
check(await waitFor(async () => (await db.doc("users/C/redeem/REELS50").get()).data()?.status === "used_up"), "kullanım sınırı dolu: used_up");
check((await db.doc("promo/REELS50").get()).data()?.uses === 1, "sayaç 1");
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
