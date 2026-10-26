// Uçtan uca (YEREL EMÜLATÖR, gerçek projeye dokunmaz): haber belgesi yazılınca raceNewsPush tetiklenir mi, bildirim
// iletisi FCM'nin kabul edeceği biçimde mi (emülatörde FCM yerine _e2e_fcm koleksiyonuna yazılır, index.js), 6 saatlik
// çift kaydı (push_log) yalnızca GÖNDERİLEN bildirimle mi yazılır. 2026-10-21: posta bildirimi (mailPush). 2026-10-25: HABERLER
// bildirimi (newsPush; zamanlayıcı mantığı pushScheduled doğrudan çağrılır). 2026-10-26: haftalık drag tablosu (lbRun).
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

// HABERLER (newsPush): panel news/{id} yazınca görünür + bildirimli haber dil konularına BİR KEZ gider, pushed_at yazılır.
const newsDoc = (over = {}) => ({ kind: "event", title: { tr: "Hafta sonu çifte para!", en: "Double money weekend!" },
  text: { tr: "Cumartesi ve pazar\ntamirden iki kat para." }, image: "", action: { kind: "event", url: "" }, start: 0, end: 0,
  pinned: false, code: 0, target: { langs: [], min_level: 0, max_level: 0, min_code: 0, max_code: 0 }, notify: true, pushed_at: 0,
  at: nowS, ...over });
const newsSent = async (id) => (await db.collection("_e2e_fcm").where("data.id", "==", id).get()).docs.map((d) => d.data());
await db.doc("news/n_e2e_1").set(newsDoc());
check(await waitFor(async () => (await newsSent("n_e2e_1")).length === 5), "haber: newsPush tetiklendi, 5 dil konusu");
const nmsgs = await newsSent("n_e2e_1");
const ntr = nmsgs.find((m) => m.topic === "news_tr") || {};
check(nmsgs.every((m) => badKeys(m.data).length === 0 && m.data.type === "news") && ntr.notification?.title === "Hafta sonu çifte para!"
  && ntr.notification?.body === "Cumartesi ve pazar tamirden iki kat para.", `haber bildirimi FCM'ye uygun, dilinde: ${JSON.stringify(ntr.notification)}`);
check((nmsgs.find((m) => m.topic === "news_de") || {}).notification?.title === "Double money weekend!", "eksik dil (de) → en");
check(await waitFor(async () => (await db.doc("news/n_e2e_1").get()).data()?.pushed_at > 0), "pushed_at yazıldı");
await db.doc("news/n_e2e_1").update({ title: { tr: "Düzenlendi" } });
await db.doc("news/n_e2e_2").set(newsDoc({ start: nowS + 3600 }));
await db.doc("news/n_e2e_3").set(newsDoc({ notify: false }));
await db.doc("news/n_e2e_4").set(newsDoc({ target: { langs: ["de", "fr"], min_level: 0, max_level: 0, min_code: 0, max_code: 0 } }));
check(await waitFor(async () => (await newsSent("n_e2e_4")).length === 2), "hedef diller: yalnız news_de + news_fr");
await sleep(4000);
check((await newsSent("n_e2e_1")).length === 5, "düzenleme bildirimi yeniden göndermez");
check((await newsSent("n_e2e_2")).length === 0 && (await db.doc("news/n_e2e_2").get()).data()?.pushed_at === 0,
  "başlangıcı ileride: şimdi gitmez (zamanlayıcıya kalır)");
check((await newsSent("n_e2e_3")).length === 0, "bildirimsiz haber: gitmez");
// newsPushScheduled emülatörde çalışmaz (pubsub emülatörü yok): aynı mantık gerçek Firestore sorgusuyla doğrudan çağrılır
const { pushScheduled } = require("../news_feed.js");
const early = await pushScheduled({ db, messaging: { send: async () => { throw new Error("erken gönderim"); } }, now: Date.now() });
check(early.pending === 1 && early.sent === 0, `zamanlayıcı: bekleyen 1 haber, başlangıç gelmedi (${JSON.stringify(early)})`);
const sched = [];
const late = await pushScheduled({ db, messaging: { send: async (m) => { sched.push(m); } }, now: (nowS + 3700) * 1000 });
check(late.sent === 1 && sched.length === 5 && sched.every((m) => m.data.id === "n_e2e_2")
  && (await db.doc("news/n_e2e_2").get()).data()?.pushed_at === nowS + 3700, "zamanlayıcı: başlangıçta gönderdi, pushed_at yazıldı");
// Yayın belgesi (config/news): zamanlayıcının refreshFeed'i bitişi geçen haberi düşürür (koleksiyondan yeniden kurar)
const { refreshFeed, buildNewsFeed } = require("../news_feed.js");
await db.doc("news/n_e2e_5").set(newsDoc({ notify: false, end: nowS + 1800 }));
const allNews = (await db.collection("news").get()).docs.map((d) => ({ id: d.id, ...d.data() }));
await db.doc("config/news").set(buildNewsFeed(allNews, Date.now()));
const fresh = await refreshFeed({ db, now: Date.now() });
check(fresh.ended === 0, "yayın güncel: yalnız config/news okundu, yazılmadı");
const pruned = await refreshFeed({ db, now: (nowS + 3700) * 1000 });
const feedNow = (await db.doc("config/news").get()).data();
const feedIdsNow = feedNow.items.map((i) => i.id);
check(pruned.ended === 1 && !feedIdsNow.includes("n_e2e_5") && feedIdsNow.includes("n_e2e_1") && feedNow.at === nowS + 3700
  && !("pushed_at" in feedNow.items[0]), `zamanlayıcı biten haberi yayından düşürdü (${JSON.stringify(pruned)})`);

// HAFTALIK DRAG LİDER TABLOSU (lbRun): gerçek tetikleyici + işlem içi sorgu. Hile sınırı lb_limits.json (ford_focus C sınıfı).
const lbWk = Math.floor((Math.floor((Date.now() + 10800000) / 86400000) + 3) / 7);
const lbRun = (uid, time, over = {}) => ({ uid, wk: lbWk, cls: "C", time, car: "ford_focus", paint: "", stage: 1, level: 5,
  name: `Usta ${uid}`, av: "", flag: "TR", run: "{}", at: Math.floor(Date.now() / 1000), ...over });
const lbSum = async (cc = "") => (await db.doc(`lb/${lbWk}_C${cc ? "_" + cc : ""}`).get()).data() || {};
await db.doc("users/lbA/friends/f_lbB").set({ since: 1 });
await db.doc("users/lbB/friends/f_lbA").set({ since: 1 });
await db.doc("push/p_lbB").set({ token: "L".repeat(40), lang: "tr", at: 1 });
await db.doc(`lb_runs/${lbWk}_C_lbB`).set(lbRun("lbB", 11.5));
check(await waitFor(async () => (await lbSum()).count === 1), "lbRun: ilk koşu dünya özetine girdi");
await db.doc(`lb_runs/${lbWk}_C_lbA`).set(lbRun("lbA", 12.0, { flag: "DE" }));
check(await waitFor(async () => (await lbSum()).count === 2), "ikinci oyuncu");
await db.doc(`lb_runs/${lbWk}_C_lbA`).set(lbRun("lbA", 11.2, { flag: "DE" }));
check(await waitFor(async () => (await db.doc(`users/lbB/lbnews/${lbWk}_C_lbA`).get()).exists), "iyileşme: arkadaşa 'seni geçti' haberi");
check(await waitFor(async () => (await sentTo("L".repeat(40))).some((m) => m.data?.type === "lb")), "arkadaşa bildirim");
const lbMsg = (await sentTo("L".repeat(40))).find((m) => m.data?.type === "lb") || {};
check(badKeys(lbMsg.data).length === 0 && lbMsg.notification?.body === "Usta lbA seni C sınıfı haftalık tablosunda geçti! (11.20 sn) 🏁",
  `bildirim metni / veri yükü (${lbMsg.notification?.body})`);
const s2 = await lbSum();
check(s2.count === 2 && s2.top.map((e) => e.uid).join(",") === "lbA,lbB" && Object.values(s2.hist).reduce((a, b) => a + b, 0) === 2
  && !("run" in s2.top[0]), "özet: sayı aynı, sıra değişti, kovalar, koşu kaydı yok");
check((await lbSum("DE")).count === 1 && (await lbSum("TR")).count === 1, "ülke özetleri");
await db.doc(`lb_runs/${lbWk}_C_lbC`).set(lbRun("lbC", 9.0));   // ford_focus sınırının altı
check(await waitFor(async () => !(await db.doc(`lb_runs/${lbWk}_C_lbC`).get()).exists), "hile sınırının altı: belge silindi");
await sleep(3000);
check((await lbSum()).count === 2 && !(await lbSum()).top.some((e) => e.uid === "lbC"), "reddedilen kayıt özete girmedi");
await db.doc(`lb_runs/${lbWk}_C_lbB`).delete();
check(await waitFor(async () => (await lbSum()).count === 1), "panel silmesi: özetten düştü");
check((await lbSum()).top.map((e) => e.uid).join(",") === "lbA" && (await lbSum("TR")).count === 0, "ilk 50 ve ülke özeti düzeldi");
await db.doc(`lb/${lbWk}_C`).update({ count: 5 });   // eski bir kayma: liste sayıdan kısa → işlem içi sorguyla yeniden kurulur
await db.doc(`lb_runs/${lbWk}_C_lbA`).set(lbRun("lbA", 11.1, { flag: "DE" }));
check(await waitFor(async () => (await lbSum()).count === 1 && (await lbSum()).top[0]?.time === 11.1), "kayma: sorguyla sayı / liste düzeldi");
// lbWeekly emülatörde çalışmaz (pubsub yok): aynı mantık gelecek pazartesi saatiyle doğrudan çağrılır (gerçek sorgu + toplu yazma)
const { payWeekly, weekStart } = require("../leaderboard.js");
const nextMonday = (weekStart(lbWk + 1) + 600) * 1000;
const paid = await payWeekly({ db, now: nextMonday });
const prize = (await db.doc(`users/lbA/mail/lb_${lbWk}_C`).get()).data();
check(paid.mails === 1 && prize?.gems === 150 && prize.crates?.super_crate === 1 && prize.lb?.rank === 1 && (await lbSum()).paid === true,
  `haftalık ödül postası + paid (${JSON.stringify(paid)})`);
check((await payWeekly({ db, now: nextMonday })).mails === 0, "ikinci çalışma: ödenmiş tablo atlanır");
// Budama (2026-10-26: ödenen haftada yalnız ilk 100 kalır): eski bir haftada 3 koşu, ilk 1 kalsın, sayfa 2 (startAfter sınanır)
const oldWk = lbWk - 3;
const oldSum = async () => (await db.doc(`lb/${oldWk}_C`).get()).data() || {};
for (const [uid, t] of [["lbP1", 11.0], ["lbP2", 11.3], ["lbP3", 11.6]]) {
  await db.doc(`lb_runs/${oldWk}_C_${uid}`).set(lbRun(uid, t, { wk: oldWk }));
}
check(await waitFor(async () => (await oldSum()).count === 3), "budama: eski haftanın özeti 3");
await db.doc(`lb/${oldWk}_C`).update({ paid: true });
const { pruneWeek } = require("../leaderboard.js");
const cut = await pruneWeek({ db, wk: oldWk, cls: "C", count: 3, nowS: Math.floor(Date.now() / 1000), keep: 1, pageSize: 2 });
check(cut.kept === 1 && cut.deleted === 2, `budama: 1 kaldı, 2 silindi (${JSON.stringify(cut)})`);
const hist1 = (await db.doc("lb_hist/lbP1").get()).data() || {};
check(hist1.recs?.[0]?.rank === 1 && hist1.recs[0].wk === oldWk && !(await db.doc("lb_hist/lbP2").get()).exists, "ilk 1'in derecesi profilde");
await sleep(3000);
const frozen = await oldSum();
check(!(await db.doc(`lb_runs/${oldWk}_C_lbP2`).get()).exists && frozen.count === 3 && frozen.top.length === 3,
  "silme tetikleyicisi donmuş özeti değiştirmedi (sayı 3, liste 3)");
await db.doc(`lb_runs/${oldWk}_C_lbP1`).delete();   // panel / hesap silme: ilk 100'deki koşu
check(await waitFor(async () => ((await db.doc("lb_hist/lbP1").get()).data()?.recs || [1]).length === 0),
  "ilk 100'deki koşu silinince profildeki derece düştü");
const after = await oldSum();
check(after.count === 3 && !after.top.some((e) => e.uid === "lbP1"), "listedeki adı düştü, sayı aynı");

console.log(fails === 0 ? "RESULT fails=0" : "RESULT fails=" + fails);
process.exit(fails === 0 ? 0 : 1);
