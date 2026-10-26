// ÜRETİM SIFIRLAMASI (2026-10-26, kullanıcı: "üretime çıkınca tüm hesaplar silinecek, herkes sıfırdan başlayacak"):
// test döneminin bütün hesaplarını ve oyuncu verisini siler; config/app (zorunlu güncelleme, etkinlik) ve admin_log kalır.
// Telefondaki eski kayıt 1.1.2'nin ilk açılışında silinir (gameplay/backend/launch_reset.gd).
//
// SIRA: 1.1.2 Play'de yayına girince panelden min_code=13 (1.1.1'de kalan buluta eski kayıt yazamasın), SONRA bu betik.
//
//   node launch_wipe.mjs                     yalnız listeler (hesaplar e-postasıyla, koleksiyonlar sayısıyla), hiçbir şey silmez
//   node launch_wipe.mjs --keep=UID,UID      listede tutulacak hesaplar (ör. üretimden sonra açılmış gerçek oyuncu)
//   node launch_wipe.mjs --run [--keep=…]    siler
//
// Hesaplar toplu deleteUsers ile silinir: bu yol accountCleanup'ı TETİKLEMEZ — gerek de yok, oyuncu koleksiyonlarının
// tamamı aşağıda recursiveDelete ile silinir (hesabı olmayan "hayalet" belgelerin alt koleksiyonları dahil). --keep
// verilirse o hesapların belgeleri korunur ve paylaşılan koleksiyonlara (race_learning, stats_daily…) dokunulmaz.
// Yetki: service-account.json (server.mjs ile aynı kural: project_id car-town-remake olmalı).

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT = "car-town-remake";
const sa = JSON.parse(readFileSync(resolve(process.env.AUTOYARD_SA || resolve(HERE, "service-account.json")), "utf8"));
if (sa.project_id !== PROJECT) throw new Error(`hizmet hesabı ${sa.project_id}, beklenen ${PROJECT}`);
initializeApp({ credential: cert(sa), projectId: PROJECT });
const auth = getAuth();
const db = getFirestore();

const RUN = process.argv.includes("--run");
const KEEP = new Set((process.argv.find((a) => a.startsWith("--keep=")) || "--keep=").slice(7).split(",").filter(Boolean));

// Kök koleksiyonlar: oyuncu başına belgeler (kimlik belge adında) ve paylaşılan tablolar.
const PER_PLAYER = ["players", "garages", "avatars", "push", "users", "moderation", "lb_hist", "lbnews", "referrals"];
const SHARED = ["codes", "invites", "iap", "race_log", "race_learning_daily", "stats_daily", "reports", "lb", "lb_runs"];
const SHARED_DOCS = ["config/race_learning"];
const KEPT = ["config/app", "config/news", "admin_log"];

const day = (ms) => new Date(Number(ms)).toISOString().slice(0, 16).replace("T", " ");

// --- Hesaplar ---
const users = [];
let page;
do {
  const res = await auth.listUsers(1000, page);
  users.push(...res.users);
  page = res.pageToken;
} while (page);
users.sort((a, b) => Date.parse(a.metadata.creationTime) - Date.parse(b.metadata.creationTime));
console.log(`== HESAPLAR (${users.length}) — açılış / son giriş UTC ==`);
for (const u of users) {
  const prov = u.providerData.map((p) => p.providerId.replace(".com", "")).join(",") || "kod";
  console.log(`${KEEP.has(u.uid) ? "KALIR" : "SİL  "} ${day(Date.parse(u.metadata.creationTime))}  son ${day(Date.parse(u.metadata.lastSignInTime || u.metadata.creationTime))}  ${prov.padEnd(16)} ${u.email || "-"}  ${u.uid}`);
}
const doomed = users.filter((u) => !KEEP.has(u.uid)).map((u) => u.uid);

// --- Firestore ---
const keeps = (id) => [...KEEP].some((uid) => id.includes(uid));
console.log("== FIRESTORE ==");
const plan = [];
for (const name of [...PER_PLAYER, ...SHARED]) {
  if (KEEP.size && SHARED.includes(name)) {
    console.log(`  ${name}: --keep verildi, dokunulmaz`);
    continue;
  }
  const refs = await db.collection(name).listDocuments();   // hayalet (alanı olmayan, yalnız alt koleksiyonlu) belgeler dahil
  const del = refs.filter((r) => !keeps(r.id));
  if (refs.length) console.log(`  ${name}: ${del.length} / ${refs.length} silinir`);
  plan.push(...del);
}
if (!KEEP.size) {
  for (const path of SHARED_DOCS) {
    const snap = await db.doc(path).get();
    if (snap.exists) {
      console.log(`  ${path}: silinir`);
      plan.push(db.doc(path));
    }
  }
}
console.log(`  kalır: ${KEPT.join(", ")}`);
const iap = await db.collection("iap").where("test", "==", false).get();
for (const d of iap.docs) {
  const v = d.data();
  if (v.status === "ok" || v.status === "consumed") console.log(`  DİKKAT gerçek satın alma: iap/${d.id.slice(0, 12)}… ${v.product} ${v.order} ${day(v.at * 1000)}`);
}

if (!RUN) {
  console.log(`\nLİSTE: ${doomed.length} hesap + ${plan.length} belge (alt koleksiyonlarıyla). Silmek için --run.`);
  process.exit(0);
}

console.log("\n== SİLİNİYOR ==");
for (let i = 0; i < doomed.length; i += 1000) {
  const res = await auth.deleteUsers(doomed.slice(i, i + 1000));
  console.log(`  hesap: ${res.successCount} silindi, ${res.failureCount} hata`);
  for (const e of res.errors) console.log(`    ${doomed[i + e.index]}: ${e.error.message}`);
}
let n = 0;
for (const ref of plan) {
  await db.recursiveDelete(ref);
  n += 1;
}
console.log(`  firestore: ${n} belge (alt koleksiyonlarıyla) silindi`);
