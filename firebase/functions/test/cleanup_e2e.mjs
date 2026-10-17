// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): cleanupExpired gerçek Firestore sorgusuyla (sayısal `at`
// alanında "<") doğru belgeleri siliyor mu. firebase/functions: npm run cleanup-e2e
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { cleanupExpired } = require("../cleanup");

initializeApp({ projectId: "demo-cartown" });
const db = getFirestore();
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };
const now = Date.now();
const s = Math.floor(now / 1000);
await db.doc("invites/ESKIABCDEFGH").set({ uid: "a", name: "Ali", code: "ABC234", at: s - 4000 });
await db.doc("invites/YENIABCDEFGH").set({ uid: "a", name: "Ali", code: "ABC234", at: s - 100 });
await db.doc("push_log/l_b_a").set({ at: now - 2 * 86400 * 1000 });
await db.doc("push_log/l_c_a").set({ at: now - 3600 * 1000 });
await db.doc("reports/x_a_b").set({ target: "b", reason: "name", av: "", name: "Bob", at: s - 200 * 86400 });
await db.doc("reports/x_a_c").set({ target: "c", reason: "name", av: "", name: "Cem", at: s - 86400 });
const deleted = await cleanupExpired({ db, now });
check(deleted.invites === 1 && deleted.push_log === 1 && deleted.reports === 1, `silinen: ${JSON.stringify(deleted)}`);
const exists = async (p) => (await db.doc(p).get()).exists;
check(!(await exists("invites/ESKIABCDEFGH")) && (await exists("invites/YENIABCDEFGH")), "davet: süresi dolan gitti, geçerli kaldı");
check(!(await exists("push_log/l_b_a")) && (await exists("push_log/l_c_a")), "bildirim kaydı: 1 günden eski gitti");
check(!(await exists("reports/x_a_b")) && (await exists("reports/x_a_c")), "şikâyet: 180 günden eski gitti");
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
