// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): haber belgesi yazılınca raceNewsPush tetiklenir mi, 6 saatlik
// çift kaydı (push_log) yazılır mı, kaybeden gönderen / tekrar kaydı değiştirmez mi.
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

await db.doc("users/B/races/e_A").set(ev({ at: 1 }));
const logged = await waitFor(async () => (await db.doc("push_log/l_B_A").get()).exists);
check(logged, "A→B kazanma: fonksiyon tetiklendi, çift kaydı yazıldı");
const first = (await db.doc("push_log/l_B_A").get()).data()?.at;
await db.doc("users/B/races/e_A").set(ev({ at: 2 }));
await sleep(4000);
check((await db.doc("push_log/l_B_A").get()).data()?.at === first, "6 saat dolmadan ikinci A→B kaydı değiştirmez");
await db.doc("users/C/races/e_A").set(ev({ won: false, at: 3 }));
await sleep(4000);
check(!(await db.doc("push_log/l_C_A").get()).exists, "kaybeden gönderen: bildirim / kayıt yok");
await db.doc("users/B/races/e_C").set(ev({ name: "Cem", at: 4 }));
check(await waitFor(async () => (await db.doc("push_log/l_B_C").get()).exists), "C→B: ayrı çift, kayıt yazıldı");
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
