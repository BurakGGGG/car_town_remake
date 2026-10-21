// Panel uçtan uca (YEREL EMÜLATÖR, canlı projeye dokunmaz: "demo-" projesi). server.mjs'i çalıştırır, HTTP ile sınar:
// güvenlik kapıları (anahtar / Host / Origin), config/app, tek oyuncuya ve herkese posta, oyuncu arama, kayıt açma, duyuru.
// firebase/ klasöründen: firebase emulators:exec --only firestore,auth --project demo-cartown "node admin/test/panel_e2e.mjs"
import { spawn } from "node:child_process";
import http from "node:http";
import { gzipSync } from "node:zlib";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("emülatör yok: firebase emulators:exec ile çalıştır");
initializeApp({ projectId: "demo-cartown" });
const db = getFirestore();
let fails = 0;
const check = (cond, what) => { console.log((cond ? "  OK   " : "  FAIL ") + what); if (!cond) fails++; };
const PORT = 4499;
const BASE = `http://127.0.0.1:${PORT}`;

// Oyuncular: alice (kodlu, e-postalı), bob (yalnız kayıt)
await getAuth().createUser({ uid: "alice_uid_1", email: "alice@test.dev" }).catch(() => {});
const save = { economy: { money: 1234 }, progress: { gems: 5, level: 3 } };
await db.doc("players/alice_uid_1").set({ save_version: 10, save_json: "gz1:" + gzipSync(JSON.stringify(save)).toString("base64"),
  stats: { money: 1234, gems: 5, level: 3, cars: 2, build: 10 }, updated_at: 1 });
// bob: ESKİ SÜRÜMLE yazılmış kayıt (stats yok, düz JSON): panel değerleri kayıttan hesaplar
await db.doc("players/bob_uid_22").set({ save_version: 10, updated_at: 1,
  save_json: JSON.stringify({ economy: { money: 777 }, progress: { gems: 12, level: 4 }, vehicles: { owned: ["x"] } }) });
await db.doc("codes/ABC234").set({ uid: "alice_uid_1" });
await db.doc("push/p_alice_uid_1").set({ token: "T".repeat(40), lang: "en", at: 1 });

const server = spawn(process.execPath, [new URL("../server.mjs", import.meta.url).pathname], {
  env: { ...process.env, ADMIN_PORT: String(PORT) }, stdio: ["ignore", "pipe", "inherit"],
});
const key = await new Promise((resolve, reject) => {
  let out = "";
  server.stdout.on("data", (d) => { out += d; const m = /#k=([A-Za-z0-9_-]+)/.exec(out); if (m) resolve(m[1]); });
  setTimeout(() => reject(new Error("panel açılmadı: " + out)), 15000);
});
const call = async (method, path, body, headers = {}) => {
  const res = await fetch(BASE + path, { method, headers: { "x-admin-key": key, "content-type": "application/json", ...headers },
    body: body ? JSON.stringify(body) : undefined });
  return { status: res.status, data: await res.json().catch(() => ({})) };
};

try {
  console.log("== güvenlik ==");
  check((await call("GET", "/api/info", null, { "x-admin-key": "yanlis" })).status === 401, "yanlış anahtar: 401");
  check((await fetch(BASE + "/api/info")).status === 401, "anahtarsız: 401");
  check((await call("GET", "/api/info", null, { origin: "https://kotu.site" })).status === 403, "yabancı Origin: 403");
  check((await call("POST", "/api/config", {}, { "content-type": "text/plain" })).status === 415, "JSON olmayan gövde: 415");
  const rebind = await new Promise((resolve) => {
    http.get({ host: "127.0.0.1", port: PORT, path: "/api/info", headers: { host: "kotu.site", "x-admin-key": key } },
      (res) => resolve(res.statusCode)).on("error", () => resolve(0));
  });
  check(rebind === 403, "yabancı Host (DNS rebinding): 403");
  const page = await fetch(BASE + "/");
  check(page.status === 200 && /frame-ancestors 'none'/.test(page.headers.get("content-security-policy") || ""), "sayfa + CSP");

  console.log("== özet / ayar ==");
  const info = await call("GET", "/api/info");
  check(info.data.project === "demo-cartown" && info.data.players === 2 && info.data.build.code > 0, `özet: ${info.data.players} oyuncu, derleme ${info.data.build?.code}`);
  const cfg = await call("POST", "/api/config", { min_code: 10, latest_code: 11, maintenance: false,
    notice: { id: "n_test", text: { tr: "Etkinlik" } } });
  const stored = (await db.doc("config/app").get()).data();
  check(cfg.status === 200 && stored.min_code === 10 && stored.notice.text.tr === "Etkinlik", "config/app yazıldı");
  check((await call("POST", "/api/config", { min_code: 12, latest_code: 11 })).status === 400, "tutarsız sürüm: 400, yazılmaz");

  console.log("== posta ==");
  const one = await call("POST", "/api/mail/send", { target: "one", query: "abc234",
    mail: { title: { tr: "Hediye" }, gems: 50, crates: { city_crate: 1 } } });
  const mailDoc = one.data.id ? (await db.doc(`users/alice_uid_1/mail/${one.data.id}`).get()).data() : null;
  check(one.status === 200 && mailDoc?.gems === 50 && mailDoc?.crates.city_crate === 1, `koda gönderildi (${one.data.id})`);
  check((await call("POST", "/api/mail/send", { target: "one", query: "alice@test.dev", mail: { text: "Selam" } })).status === 200, "e-postaya gönderildi");
  check((await call("POST", "/api/mail/send", { target: "one", query: "ZZZ999", mail: { text: "x" } })).status === 400, "bilinmeyen kod: 400");
  check((await call("POST", "/api/mail/send", { target: "one", query: "abc234", mail: { text: "x", gems: 999999 } })).status === 400, "sınır dışı elmas: 400");
  const dry = await call("POST", "/api/mail/send", { target: "all", dry: true, mail: { text: "x" } });
  check(dry.data.count === 2, "herkes (deneme): 2 alıcı, yazılmadı");
  const all = await call("POST", "/api/mail/send", { target: "all", mail: { title: { tr: "Açılış" }, money: 1000 } });
  const bobMail = (await db.collection("users/bob_uid_22/mail").get()).docs.map((d) => d.id);
  check(all.data.count === 2 && bobMail.includes(all.data.id) && all.data.id.startsWith("c_"), "herkese kampanya: her oyuncuya aynı kimlik");

  console.log("== oyuncu ==");
  const p = await call("POST", "/api/player", { query: "ABC234" });
  check(p.data.uid === "alice_uid_1" && p.data.stats.money === 1234 && p.data.mail.length === 3 && p.data.push.lang === "en",
    "oyuncu özeti: stats, 3 posta, bildirim dili");
  const old = await call("POST", "/api/player", { query: "bob_uid_22" });
  check(old.data.stats_from === "save" && old.data.stats.money === 777 && old.data.stats.gems === 12 && old.data.stats.cars === 1,
    "eski sürüm kaydı (stats yok): para / elmas / araç kayıttan");
  const s = await call("POST", "/api/player/save", { query: "alice_uid_1" });
  check(s.data.save?.economy?.money === 1234, "sıkışık kayıt açıldı");
  const del = await call("POST", "/api/mail/delete", { uid: "alice_uid_1", id: one.data.id });
  check(del.status === 200 && !(await db.doc(`users/alice_uid_1/mail/${one.data.id}`).get()).exists, "posta silindi");

  console.log("== moderasyon ==");
  await db.doc("garages/g_alice_uid_1").set({ name: "Kötü Ad", code: "ABC234", level: 3, value: 1, garage_json: "{}", updated_at: 1, av: "img:0011aabb" });
  await db.doc("avatars/a_alice_uid_1").set({ img: "x", hash: "0011aabb", at: 1 });
  await db.doc("reports/x_bob_uid_22_alice_uid_1").set({ target: "alice_uid_1", reason: "photo", av: "img:0011aabb",
    img: "A".repeat(40), name: "Kötü Ad", at: 100 });
  await db.doc("reports/x_carol_uid_3_alice_uid_1").set({ target: "alice_uid_1", reason: "name", av: "", name: "Kötü Ad", at: 200 });
  const reports = await call("GET", "/api/reports");
  check(reports.data.groups?.[0]?.target === "alice_uid_1" && reports.data.groups[0].count === 2 && reports.data.groups[0].img,
    "şikâyet kuyruğu: hedefe göre, görselli");
  const rn = await call("POST", "/api/mod/reset-name", { uid: "alice_uid_1" });
  const g1 = (await db.doc("garages/g_alice_uid_1").get()).data();
  const m1 = (await db.doc("moderation/m_alice_uid_1").get()).data();
  check(/^Usta\d{4}$/.test(rn.data.name) && g1.name === rn.data.name && m1.name === rn.data.name && m1.name_reset > 0,
    `ad sıfırlandı: garaj + moderasyon (${rn.data.name})`);
  await call("POST", "/api/mod/reset-photo", { uid: "alice_uid_1" });
  check(!(await db.doc("avatars/a_alice_uid_1").get()).exists && (await db.doc("garages/g_alice_uid_1").get()).data().av === ""
    && (await db.doc("moderation/m_alice_uid_1").get()).data().photo_reset > 0, "fotoğraf kaldırıldı");
  const closed = await call("POST", "/api/reports/close", { target: "alice_uid_1", action: "reset-name" });
  check(closed.data.closed === 2 && (await db.collection("reports").get()).empty, "şikâyetler kapatıldı");
  check((await call("POST", "/api/mod/ban", { uid: "alice_uid_1", kind: "social", reason: "__proto__", days: 7 })).status === 400, "geçersiz sebep: 400");
  check((await call("POST", "/api/mod/ban", { uid: "../x", kind: "social", reason: "name", days: 7 })).status === 400, "geçersiz UID: 400");
  const ban = await call("POST", "/api/mod/ban", { uid: "alice_uid_1", kind: "social", reason: "name", text: "Küfürlü ad", days: 7 });
  const m2 = (await db.doc("moderation/m_alice_uid_1").get()).data();
  check(ban.status === 200 && m2.ban.kind === "social" && m2.ban.until > m2.ban.at && m2.name === rn.data.name,
    "sosyal yasak yazıldı (önceki ad kararı korunur)");
  check(!(await db.doc("garages/g_alice_uid_1").get()).exists && (await db.doc("push/p_alice_uid_1").get()).exists,
    "sosyal yasak: açık garaj gizlendi, bildirim jetonu duruyor");
  const pb = await call("POST", "/api/player", { query: "alice_uid_1" });
  check(pb.data.moderation?.ban_active === true, "oyuncu özetinde yasak görünür");
  await call("POST", "/api/mod/ban", { uid: "alice_uid_1", kind: "full", reason: "cheat", days: 0 });
  const m3 = (await db.doc("moderation/m_alice_uid_1").get()).data();
  check(m3.ban.kind === "full" && m3.ban.until === 0 && !(await db.doc("push/p_alice_uid_1").get()).exists, "tam kalıcı yasak: jeton silindi");
  await call("POST", "/api/mod/unban", { uid: "alice_uid_1" });
  const m4 = (await db.doc("moderation/m_alice_uid_1").get()).data();
  check(!("ban" in m4) && m4.name === rn.data.name, "yasak kaldırıldı (ad kararı kalır)");
  await call("POST", "/api/notes", { uid: "alice_uid_1", text: "18 Ekim elmas iadesi" });
  const pn = await call("POST", "/api/player", { query: "alice_uid_1" });
  check(pn.data.note?.text === "18 Ekim elmas iadesi" && pn.data.moderation.ban_active === false, "oyuncu notu kaydedildi");
  await db.doc("push/p_alice_uid_1").set({ token: "T".repeat(40), lang: "en", at: 1 });   // duyuru denemesi için geri

  console.log("== destek ==");
  const oldSave = "gz1:" + gzipSync(JSON.stringify({ economy: { money: 900 }, progress: { gems: 3, level: 2 }, vehicles: { owned: [] } })).toString("base64");
  await db.doc("players/alice_uid_1/history/h05").set({ save_json: oldSave, updated_at: 500 });
  await db.doc("players/alice_uid_1/history/d2").set({ save_json: oldSave, stats: { money: 800, gems: 2, level: 2, cars: 0, build: 10 }, updated_at: 900 });
  const hist = await call("POST", "/api/history", { uid: "alice_uid_1" });
  check(hist.data.items?.map((i) => i.slot).join(",") === "d2,h05" && hist.data.items[1].stats.money === 900,
    "geçmiş: yeniden eskiye, stats yoksa kayıttan");
  check((await call("POST", "/api/history/restore", { uid: "alice_uid_1", slot: "h99" })).status === 400, "geçersiz dilim: 400");
  const rs = await call("POST", "/api/history/restore", { uid: "alice_uid_1", slot: "h05" });
  const rdoc = rs.data.id ? (await db.doc(`users/alice_uid_1/mail/${rs.data.id}`).get()).data() : null;
  check(rdoc?.restore?.save_json === oldSave && rdoc.restore.at === 500, "geri yükleme postası: o dilimin kaydı");
  const adj = await call("POST", "/api/adjust", { uid: "alice_uid_1", money: -500, gems: 25, text: { tr: "Hile iadesi" } });
  const adoc = adj.data.id ? (await db.doc(`users/alice_uid_1/mail/${adj.data.id}`).get()).data() : null;
  check(adoc?.adjust?.money === -500 && adoc.adjust.gems === 25 && adoc.notify === false, "bakiye düzeltme postası (eksi, bildirimsiz)");
  check((await call("POST", "/api/adjust", { uid: "alice_uid_1", money: 0, gems: 0 })).status === 400, "boş düzeltme: 400");

  console.log("== canlı oyun ==");
  const pc = await call("POST", "/api/promo", { create: true, code: "reels50", title: { tr: "Reels" }, gems: 50, max_uses: 10 });
  const pdoc = (await db.doc("promo/REELS50").get()).data();
  check(pc.data.code === "REELS50" && pdoc.reward.gems === 50 && pdoc.uses === 0 && pdoc.active === true, "kupon oluşturuldu (büyük harf)");
  check((await call("POST", "/api/promo", { create: true, code: "REELS50", gems: 5 })).status === 400, "aynı kod ikinci kez oluşturulamaz");
  await db.doc("promo/REELS50").update({ uses: 3 });
  await call("POST", "/api/promo", { code: "REELS50", title: { tr: "Reels 2" }, gems: 60, max_uses: 10 });
  check((await db.doc("promo/REELS50").get()).data().uses === 3, "güncellemede kullanım sayacı korunur");
  await call("POST", "/api/promo/toggle", { code: "REELS50", active: false });
  const plist = await call("GET", "/api/promo");
  check(plist.data.codes?.[0]?.active === false && plist.data.codes[0].reward.gems === 60, "kod kapatıldı, listede");
  await db.doc("players/alice_uid_1").update({ "stats.lang": "en", updated_at: Math.floor(Date.now() / 1000) });
  const segDry = await call("POST", "/api/mail/send", { target: "segment", dry: true, segment: { lang: "en", level_min: 2 }, mail: { text: "x" } });
  check(segDry.data.count === 1, "filtreli posta (deneme): dili en, seviye ≥2 → 1 hesap");
  const seg = await call("POST", "/api/mail/send", { target: "segment", segment: { lang: "en" }, mail: { title: { tr: "Geri dön" }, gems: 5 } });
  check(seg.data.count === 1 && (await db.doc(`users/alice_uid_1/mail/${seg.data.id}`).get()).exists
    && !(await db.doc(`users/bob_uid_22/mail/${seg.data.id}`).get()).exists, "filtreli posta yalnız uyan hesaba");
  check((await call("POST", "/api/mail/send", { target: "segment", segment: { lang: "fr" }, mail: { text: "x" } })).status === 400, "uyan yoksa gönderilmez");
  const nseg = await call("POST", "/api/news/send", { body: { tr: "Filtreli", en: "Filtered" }, segment: { lang: "en" } });
  const fcmSeg = (await db.collection("_e2e_fcm").where("notification.body", "==", "Filtered").get()).docs.map((d) => d.data());
  check(nseg.data.sent === 1 && fcmSeg.length === 1 && fcmSeg[0].token === "T".repeat(40), "filtreli duyuru: o hesabın telefonuna, kendi dilinde");
  await db.doc("stats_daily/2026-10-19").set({ players: 1, active_1d: 1, active_7d: 1, active_30d: 1, push: 1, new_1d: 0, at: 1 });
  await db.doc("stats_daily/2026-10-20").set({ players: 1, active_1d: 1, active_7d: 1, active_30d: 1, push: 1, new_1d: 1, at: 2 });
  const st = await call("GET", "/api/stats");
  check(st.data.live?.players === 2 && st.data.live.push === 1 && st.data.days?.map((d) => d.day).join(",") === "2026-10-19,2026-10-20" && st.data.langs.en === 1,
    "istatistik: anlık sayılar, gecelik kayıt, dil dağılımı");
  const ev = await call("POST", "/api/config", { min_code: 0, latest_code: 0, event: { id: "hs1", money_mult: 2, xp_mult: 1, start: 1, end: 4_000_000_000 } });
  check(ev.status === 200 && (await db.doc("config/app").get()).data().event?.money_mult === 2, "etkinlik config/app'e yazıldı");

  console.log("== duyuru ==");
  const test = await call("POST", "/api/news/send", { body: { tr: "Deneme", en: "Test" }, test_query: "abc234" });
  const fcmTest = (await db.collection("_e2e_fcm").where("token", "==", "T".repeat(40)).get()).docs.map((d) => d.data())
    .filter((m) => m.data?.type === "news" && ["Test", "Deneme"].includes(m.notification?.body));
  check(test.status === 200 && fcmTest.length === 1 && fcmTest[0].notification.body === "Test", "deneme: yalnız o oyuncuya, kendi dilinde");
  const news = await call("POST", "/api/news/send", { body: { tr: "Herkese" } });
  const topics = (await db.collection("_e2e_fcm").where("data.type", "==", "news").get()).docs.map((d) => d.data().topic).filter(Boolean);
  check(news.data.sent === 5 && topics.length === 5 && topics.includes("news_de"), "herkese: 5 dil konusu");
  const log = await call("GET", "/api/log");
  check(log.data.log.some((e) => e.kind === "mail_all") && log.data.log.some((e) => e.kind === "news"), "işlem günlüğü");
  const builds = await call("GET", "/api/builds");
  check(builds.data.builds["10"] === 1 && builds.data.total === 2, "sürüm dağılımı");
} finally {
  server.kill();
}
console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
