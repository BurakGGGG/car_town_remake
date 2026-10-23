// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): davet talebi yazılınca referralJoin, seviye işareti yazılınca
// referralQualify tetiklenir mi; arkadaşlık, hoş geldin postası, sayaç, 1. basamak postası, aynı cihazda ikinci hesap.
// firebase/ klasöründen: npm --prefix functions run referral-e2e
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

initializeApp({ projectId: "demo-cartown" });
const db = getFirestore();
const auth = getAuth();
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };
const nowS = () => Math.floor(Date.now() / 1000);

/** Belgede alan belirene dek bekler (tetikleyici eşzamansız; en çok ~20 sn). */
async function until(path, field) {
  for (let i = 0; i < 40; i++) {
    const snap = await db.doc(path).get();
    if (snap.exists && (!field || snap.data()[field] !== undefined)) return snap.data();
    await new Promise((r) => setTimeout(r, 500));
  }
  return null;
}

const ali = (await auth.createUser({ email: "ali@example.com", emailVerified: true })).uid;
const bob = (await auth.createUser({ email: "bob@example.com", emailVerified: true })).uid;
const can = (await auth.createUser({ email: "can@example.com", emailVerified: true })).uid;
await db.doc("codes/ABC234").set({ uid: ali });
await db.doc(`garages/g_${ali}`).set({ name: "Usta Ali" });
await db.doc(`garages/g_${bob}`).set({ name: "Bobo" });
const phone = "b".repeat(64);

console.log("== katılma ==");
await db.doc(`users/${bob}/referral/ref_claim`).set({ code: "ABC234", src: "link", dev: phone, at: nowS() });
const claim = await until(`users/${bob}/referral/ref_claim`, "status");
check(claim && claim.status === "ok" && claim.referrer === ali, `referralJoin tetiklendi: ${JSON.stringify(claim)}`);
check((await db.doc(`users/${ali}/friends/f_${bob}`).get()).exists && (await db.doc(`users/${bob}/friends/f_${ali}`).get()).exists,
  "otomatik arkadaşlık");
const welcome = (await db.doc(`users/${bob}/mail/ref_welcome`).get()).data();
check(welcome && welcome.gems === 50 && welcome.money === 5000 && /Usta Ali/.test(welcome.text.tr), "hoş geldin postası");
check(((await db.doc(`referrals/r_${ali}`).get()).data() || {}).joined === 1, "sayaç: 1 katıldı");

console.log("== 3. seviye ==");
await db.doc(`users/${bob}/referral/ref_lvl3`).set({ at: nowS() });
const lvl = await until(`users/${bob}/referral/ref_lvl3`, "status");
check(lvl && lvl.status === "ok" && lvl.tier === 1, `referralQualify tetiklendi: ${JSON.stringify(lvl)}`);
const tier = (await db.doc(`users/${ali}/mail/ref_1`).get()).data();
check(tier && tier.gems === 50 && tier.friend === bob && tier.referral === "tier_1" && /^Bobo katıldı/.test(tier.title.tr),
  "1. basamak postası davet edene");
check(((await db.doc(`referrals/r_${ali}`).get()).data() || {}).count === 1, "sayaç: 1 sayıldı");

console.log("== aynı telefonda ikinci hesap ==");
await db.doc(`users/${can}/referral/ref_claim`).set({ code: "ABC234", src: "code", dev: phone, at: nowS() });
const second = await until(`users/${can}/referral/ref_claim`, "status");
check(second && second.status === "device_used", `device_used: ${JSON.stringify(second)}`);
check(!(await db.doc(`users/${can}/mail/ref_welcome`).get()).exists, "ikinci hesaba hediye yok");

console.log(fails ? `FAIL ${fails}` : "TÜMÜ OK");
process.exit(fails ? 1 : 0);
