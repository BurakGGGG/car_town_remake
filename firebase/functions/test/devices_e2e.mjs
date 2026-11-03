// deviceMetrics uçtan uca (emülatör): oyunun düz HTTP callable biçimi (DeviceMetrics._http_call) ile.
// Çalıştırma: npm --prefix functions run devices-e2e
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
initializeApp({ projectId: "demo-cartown" });
const db = getFirestore();
const URL = `http://${process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001"}/demo-cartown/europe-west4/deviceMetrics`;
const DEV = "e".repeat(64);
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };
async function call(data) {
  const res = await fetch(URL, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ data }) });
  return { status: res.status, body: await res.json() };
}
const body = (extra = {}) => ({ dev: DEV, inst: "f".repeat(32), seq: 1, acct: "guest", lang: "tr", model: "SM-A245F",
  build: 17, sdk: 34, level: 3, money: 5000, gems: 40, cars: 1, garages: 1, tut: 1, push: false, push_os: true,
  push_asked: false, push_race: true, push_gift: true, push_news: true, d: { sess: 1.0, play_s: 120.0 }, ...extra });

let r = await call(body());
check(r.status === 200 && r.body.result && r.body.result.applied === "new", `ilk gönderim 200 new (${JSON.stringify(r.body)})`);
let doc = (await db.doc(`devices/d_${DEV}`).get()).data();
check(doc && doc.sess === 1 && doc.play_s === 120 && doc.acct === "guest" && !("uid" in doc), "belge yazıldı, uid yok");
r = await call(body());
check(r.body.result && r.body.result.applied === "snapshot", "aynı seq: yalnız anlık");
doc = (await db.doc(`devices/d_${DEV}`).get()).data();
check(doc.play_s === 120, "sayaç iki kez eklenmedi");
r = await call(body({ lang: "ru" }));
check(r.status === 400 && r.body.error && r.body.error.details && r.body.error.details.reason === "bad_lang",
  `bozuk dil 400 bad_lang (${JSON.stringify(r.body)})`);
r = await call({ dev: DEV, forget: true });
check(r.body.result && r.body.result.applied === "forgot", "forget");
check(!(await db.doc(`devices/d_${DEV}`).get()).exists, "belge silindi");
console.log(`RESULT fails=${fails}`);
process.exit(fails ? 1 : 0);
