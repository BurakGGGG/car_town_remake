// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): Auth kullanıcısı silinince accountCleanup tetiklenir mi, o UID'nin
// kendi belgeleri ve başkalarının listesine yazdıkları (eski arkadaşa gönderilen hediye dahil) silinir mi, başkalarınınki
// kalır mı. firebase/ klasöründen: npm --prefix functions run account-e2e
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

const ali = (await auth.createUser({ email: "ali@example.com", emailVerified: true })).uid;
const veli = (await auth.createUser({ email: "veli@example.com", emailVerified: true })).uid;
const own = [`players/${ali}`, `garages/g_${ali}`, `avatars/a_${ali}`, `push/p_${ali}`, "codes/ABC234", "invites/ABCDEFGHJKLM",
  `users/${ali}/friends/f_${veli}`, `users/${ali}/visits/v_${veli}`];
const authored = [`users/${veli}/friends/f_${ali}`, `users/${veli}/races/e_${ali}`, `users/${veli}/visits/v_${ali}`,
  `users/${veli}/gifts/p_${ali}_20380`, `users/${veli}/inbox/r_${ali}`];
const others = [`players/${veli}`, `garages/g_${veli}`, "codes/XYZ789", `users/${veli}/gifts/p_zzz_20380`, `reports/x_${ali}_${veli}`];
for (const path of [...own, ...authored, ...others]) {
  const uid = path === "codes/XYZ789" ? veli : ali;
  await db.doc(path).set({ uid, name: "Usta Ali", at: 1 });
}

await auth.deleteUser(ali);
const exists = async (paths) => (await Promise.all(paths.map((p) => db.doc(p).get()))).filter((s) => s.exists).map((s) => s.ref.path);
let left = [];
for (let i = 0; i < 40; i++) {   // tetikleyici eşzamansız: en çok ~20 sn bekle
  left = await exists([...own, ...authored]);
  if (left.length === 0) break;
  await new Promise((r) => setTimeout(r, 500));
}
check(left.length === 0, `silinen hesabın kendi + başkalarına yazdığı belgeler gitti (kalan: ${JSON.stringify(left)})`);
const kept = await exists(others);
check(kept.length === others.length, `başkalarının belgeleri ve şikâyet kaldı (${kept.length}/${others.length})`);

console.log(fails ? `FAIL ${fails}` : "TÜMÜ OK");
process.exit(fails ? 1 : 0);
