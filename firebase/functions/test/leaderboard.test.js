// leaderboard.js testi (internetsiz): sahte Firestore (sorgu + işlem) + sahte messaging. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const lb = require("../leaderboard");
const { catalogClasses } = require("./gen_lb_classes");

const {
  weekOf, weekStart, parseId, bucketOf, checkRun, handleRunWritten, payWeekly, rewardsFrom, tierFor, overtakeMessage,
  DEFAULT_REWARDS, TOP_MAX,
} = lb;

const clone = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));

// Düz yol → belge. Sorgu: koleksiyonun doğrudan belgeleri, where "==" süzgeci, orderBy (eşitlikte belge adı), limit, select.
function fakeDb(initial = {}) {
  const store = clone(initial);
  const stats = { reads: 0, queries: 0, txQueries: 0 };
  const snapOf = (p) => {
    const data = clone(store[p]);
    return { id: p.split("/").pop(), exists: data !== undefined, data: () => clone(data), get: (k) => (data || {})[k], ref: ref(p) };
  };
  function ref(p) {
    return {
      path: p, id: p.split("/").pop(), _doc: true,
      async get() { stats.reads++; return snapOf(p); },
      async set(v) { store[p] = clone(v); },
      async create(v) { if (p in store) throw Object.assign(new Error("ALREADY_EXISTS"), { code: 6 }); store[p] = clone(v); },
      async update(v) { if (!(p in store)) throw new Error("NOT_FOUND"); store[p] = { ...store[p], ...clone(v) }; },
      async delete() { delete store[p]; },
    };
  }
  function query(coll, filters = [], order = null, n = Infinity, fields = null, after = null) {
    const q = {
      _query: true,
      where: (f, op, v) => { assert.strictEqual(op, "=="); return query(coll, [...filters, [f, v]], order, n, fields, after); },
      orderBy: (f) => query(coll, filters, f, n, fields, after),
      limit: (k) => query(coll, filters, order, k, fields, after),
      select: (...fs) => query(coll, filters, order, n, fs, after),
      startAfter: (snap) => query(coll, filters, order, n, fields, snap.ref.path),
      _run() {
        const depth = coll.split("/").length + 1;
        let paths = Object.keys(store).filter((p) => p.startsWith(coll + "/") && p.split("/").length === depth)
          .filter((p) => filters.every(([f, v]) => store[p][f] === v));
        if (order) paths = paths.filter((p) => order in store[p]);
        paths.sort((a, b) => (order ? store[a][order] - store[b][order] : 0) || (a < b ? -1 : a > b ? 1 : 0));
        if (after) paths = paths.slice(paths.indexOf(after) + 1);
        const docs = paths.slice(0, n).map((p) => {
          const s = snapOf(p);
          if (!fields) return s;
          const full = s.data();
          const sub = Object.fromEntries(fields.filter((f) => f in full).map((f) => [f, full[f]]));
          return { ...s, data: () => clone(sub) };
        });
        return { docs, size: docs.length, empty: !docs.length };
      },
      async get() { stats.queries++; return q._run(); },
    };
    return q;
  }
  return {
    store, stats,
    doc: ref,
    collection: (c) => query(c),
    async getAll(...refs) { return refs.map((r) => { stats.reads++; return snapOf(r.path); }); },
    batch() {
      const ops = [];
      return { set: (r, v) => ops.push(() => { store[r.path] = clone(v); }), delete: (r) => ops.push(() => { delete store[r.path]; }),
        async commit() { assert.ok(ops.length <= 500, "toplu yazma 500 sınırı"); for (const op of ops) op(); } };
    },
    // İşlem: okumalar anlık, yazmalar sonda; yazmadan sonra okuma Firestore'daki gibi hata
    async runTransaction(fn) {
      const writes = [];
      const t = {
        async get(x) {
          if (writes.length) throw new Error("okuma yazmadan sonra");
          if (x._query) { stats.txQueries++; return x._run(); }
          stats.reads++;
          return snapOf(x.path);
        },
        set: (r, v) => writes.push(() => { store[r.path] = clone(v); }),
        update: (r, v) => writes.push(() => { if (!(r.path in store)) throw new Error("NOT_FOUND"); store[r.path] = { ...store[r.path], ...clone(v) }; }),
        delete: (r) => writes.push(() => { delete store[r.path]; }),
      };
      const out = await fn(t);
      for (const w of writes) w();
      return out;
    },
  };
}

// FCM veri yükü kuralları (news.test.js ile aynı)
function fakeMessaging({ fail = {} } = {}) {
  const sent = [];
  return {
    sent,
    async send(m) {
      for (const [k, v] of Object.entries(m.data || {})) {
        if (k === "from" || k === "message_type" || k.startsWith("google.") || k.startsWith("gcm.") || typeof v !== "string") {
          throw Object.assign(new Error(`Invalid data payload key: ${k}`), { code: "messaging/invalid-argument" });
        }
      }
      if (fail[m.token]) throw Object.assign(new Error("x"), { code: fail[m.token] });
      sent.push(m);
    },
  };
}

// 2026-10-26 Pazartesi 12:00 TR → hafta 2965
const NOW = Date.UTC(2026, 9, 26, 9, 0, 0);
const WK = 2965;
const LIMITS = { ford_focus: 9.0, bugatti_chiron: 5.89 };
const CLASSES = { ford_focus: "C", bugatti_chiron: "S" };
const run = (uid, time, over = {}) => ({ uid, wk: WK, cls: "C", time, car: "ford_focus", paint: "", stage: 2, level: 7,
  name: `Usta ${uid}`, av: "p03", flag: "TR", run: "{\"v\":3}", at: 1_792_000_000, ...over });
const rid = (uid, cls = "C", wk = WK) => `${wk}_${cls}_${uid}`;
const quiet = async (fn) => {
  const [log, err] = [console.log, console.error];
  console.log = () => {};
  console.error = () => {};
  try { return await fn(); } finally { console.log = log; console.error = err; }
};

/** Oyuncunun belge yazması + tetikleyici (olay öncesi / sonrası belgeyle, gerçek tetikleyici gibi). */
async function write(db, messaging, uid, data, { cls = "C", now = NOW } = {}) {
  const id = rid(uid, cls, data ? data.wk : WK);
  const before = clone(db.store[`lb_runs/${id}`]) || null;
  if (data) db.store[`lb_runs/${id}`] = clone(data);
  else delete db.store[`lb_runs/${id}`];
  return quiet(() => handleRunWritten({ db, messaging, id, before, after: data ? clone(data) : null, now, limits: LIMITS, classes: CLASSES }));
}
const del = (db, messaging, uid, cls = "C") => write(db, messaging, uid, null, { cls });

test("hafta: Pazartesi 00:00 TR döner (dokümandaki örnek)", () => {
  const monday = Date.UTC(2026, 9, 25, 21, 0, 0) / 1000;
  assert.equal(weekOf(monday), 2965);
  assert.equal(weekOf(monday - 1), 2964, "Pazar 23:59:59 TR önceki hafta");
  assert.equal(weekOf(monday + 7 * 86400 - 1), 2965);
  assert.equal(weekStart(2965), monday);
  assert.equal(weekOf(Math.floor(NOW / 1000)), WK);
});

test("kimlik, kova, doğrulama: sınır, sınıf, 4 sn tabanı", () => {
  assert.deepEqual(parseId("2965_A_abcDEF123"), { wk: 2965, cls: "A", uid: "abcDEF123" });
  assert.equal(parseId("2965_X_abc"), null);
  assert.equal(parseId("2965_A_a/b"), null);
  assert.equal(bucketOf(7.25), "145");
  assert.equal(bucketOf(7.2999), "145");
  const p = parseId(rid("ali"));
  assert.equal(checkRun(run("ali", 9.5), p, LIMITS, CLASSES), "");
  assert.equal(checkRun(run("ali", 8.99), p, LIMITS, CLASSES), "limit", "aracın hile sınırının altı");
  assert.equal(checkRun(run("ali", 9.0), p, LIMITS, CLASSES), "", "tam sınır kabul");
  assert.equal(checkRun(run("ali", 6.0, { car: "bugatti_chiron" }), p, LIMITS, CLASSES), "class", "S aracı C tablosunda");
  assert.equal(checkRun(run("ali", 4.0, { car: "yeni_arac" }), p, LIMITS, CLASSES), "", "listede olmayan araç: yalnız 4 sn tabanı");
  assert.equal(checkRun(run("ali", 3.99, { car: "yeni_arac" }), p, LIMITS, CLASSES), "time");
  assert.equal(checkRun(run("ali", 30.01), p, LIMITS, CLASSES), "time");
  assert.equal(checkRun(run("veli", 9.5), p, LIMITS, CLASSES), "id", "belgedeki uid kimlikle aynı olmalı");
  assert.equal(checkRun(run("ali", 9.5, { wk: WK - 1 }), p, LIMITS, CLASSES), "id");
  assert.equal(checkRun(run("ali", "9.5"), p, LIMITS, CLASSES), "time", "metin süre");
});

test("sınıf haritası (lb_classes.json) araç kataloğuyla aynı: değiştiyse npm run lb-classes", () => {
  const file = JSON.parse(readFileSync(path.join(__dirname, "../lb_classes.json"), "utf8"));
  assert.deepEqual(file, catalogClasses());
  assert.ok(Object.keys(file).length > 50 && !("police_vito" in file), "edinilemeyen araç yok");
  assert.ok(Object.values(file).every((c) => lb.CLASSES.includes(c)));
  // Hile sınırı dosyası (tools/lb_limits.gd): her sınır mutlak tabanın üstünde, sınıflı araçlardan
  const limits = JSON.parse(readFileSync(path.join(__dirname, "../lb_limits.json"), "utf8"));
  for (const [car, sec] of Object.entries(limits)) {
    assert.ok(typeof sec === "number" && sec >= lb.TIME_MIN && sec <= lb.TIME_MAX, `${car} sınırı ${sec}`);
  }
  assert.deepEqual(lb.LIMITS, limits, "fonksiyon dosyayı yükler");
});

test("sınırın altındaki koşu silinir, hiçbir özet değişmez; silme olayı da bir şey eksiltmez", async () => {
  const db = fakeDb();
  const m = fakeMessaging();
  assert.equal(await write(db, m, "ali", run("ali", 8.5)), "rejected:limit");
  assert.ok(!(`lb_runs/${rid("ali")}` in db.store), "belge silindi");
  assert.equal(await del(db, m, "ali"), "same", "sayılmamış kaydın silinmesi: değişiklik yok");
  assert.ok(!(`lb/${WK}_C` in db.store), "özet hiç oluşmadı");
  assert.equal(await write(db, m, "ali", run("ali", 6.0, { car: "bugatti_chiron" })), "rejected:class");
});

test("yeni kayıt, iyileşme, ülke özeti: count / hist / top", async () => {
  const db = fakeDb();
  const m = fakeMessaging();
  assert.match(await write(db, m, "ali", run("ali", 10.0)), /^improved/);
  await write(db, m, "veli", run("veli", 9.5, { flag: "DE" }));
  await write(db, m, "ayse", run("ayse", 11.2, { flag: "" }));
  let w = db.store[`lb/${WK}_C`];
  assert.equal(w.count, 3);
  assert.deepEqual(w.hist, { 200: 1, 190: 1, 224: 1 });
  assert.deepEqual(w.top.map((e) => e.uid), ["veli", "ali", "ayse"]);
  assert.deepEqual(Object.keys(w.top[0]).sort(), ["at", "av", "car", "flag", "level", "name", "paint", "stage", "time", "uid"],
    "satır alanları (koşu kaydı run özete girmez)");
  assert.equal(w.cc, "");
  assert.equal(w.wk, WK);
  assert.equal(w.cls, "C");
  assert.equal(w.updated, Math.floor(NOW / 1000));
  assert.deepEqual(db.store[`lb/${WK}_C_TR`].top.map((e) => e.uid), ["ali"]);
  assert.equal(db.store[`lb/${WK}_C_DE`].count, 1);
  assert.ok(!(`lb/${WK}_C_` in db.store), "bayraksız oyuncu ülke özetine girmez");
  // İyileşme: eski kova −1, yeni kova +1, sayı aynı
  await write(db, m, "ali", run("ali", 9.2));
  w = db.store[`lb/${WK}_C`];
  assert.equal(w.count, 3, "iyileşme sayıyı artırmaz");
  assert.deepEqual(w.hist, { 184: 1, 190: 1, 224: 1 });
  assert.deepEqual(w.top.map((e) => [e.uid, e.time]), [["ali", 9.2], ["veli", 9.5], ["ayse", 11.2]]);
  assert.deepEqual(db.store[`lb/${WK}_C_TR`].hist, { 184: 1 });
  assert.equal(db.store[`lb_counted/${rid("ali")}`].time, 9.2, "defter");
  // Aynı olay iki kez gelirse (en az bir kez teslim): değişiklik yok
  const before = clone(db.store);
  assert.equal(await quiet(() => handleRunWritten({ db, messaging: m, id: rid("ali"), before: run("ali", 10.0), after: run("ali", 9.2),
    now: NOW, limits: LIMITS, classes: CLASSES })), "same");
  assert.deepEqual(db.store, before);
  // Eski olay sonra gelirse (sıra karışık): özet belgenin ŞİMDİKİ hâline göre kalır
  assert.equal(await quiet(() => handleRunWritten({ db, messaging: m, id: rid("ali"), before: null, after: run("ali", 10.0),
    now: NOW, limits: LIMITS, classes: CLASSES })), "same");
  assert.equal(db.store[`lb/${WK}_C`].top[0].time, 9.2);
  // Ülke değişti: eski ülkeden düşer, yenisine girer
  await write(db, m, "ali", run("ali", 9.1, { flag: "DE" }));
  assert.equal(db.store[`lb/${WK}_C_TR`].count, 0);
  assert.deepEqual(db.store[`lb/${WK}_C_TR`].top, []);
  assert.deepEqual(db.store[`lb/${WK}_C_TR`].hist, {});
  assert.deepEqual(db.store[`lb/${WK}_C_DE`].top.map((e) => e.uid), ["ali", "veli"]);
  assert.equal(db.store[`lb/${WK}_C`].count, 3);
});

test("silme (panel): hist / count / top düşer, ilk 50 sorguyla yeniden dolar", async () => {
  const db = fakeDb();
  const m = fakeMessaging();
  for (let i = 0; i < 60; i++) {
    const uid = `u${String(i).padStart(2, "0")}`;
    await write(db, m, uid, run(uid, 9.0 + i * 0.1, { flag: i % 2 ? "TR" : "DE" }));
  }
  let w = db.store[`lb/${WK}_C`];
  assert.equal(w.count, 60);
  assert.equal(w.top.length, TOP_MAX);
  assert.equal(w.top[49].uid, "u49");
  assert.equal(db.store[`lb/${WK}_C_TR`].count, 30);
  const tx = db.stats.txQueries;
  await del(db, m, "u03");
  w = db.store[`lb/${WK}_C`];
  assert.equal(w.count, 59);
  assert.equal(w.hist[bucketOf(9.3)], undefined, "kovası boşaldı");
  assert.equal(w.top.length, TOP_MAX, "liste 50'ye tamamlandı");
  assert.ok(!w.top.some((e) => e.uid === "u03"));
  assert.equal(w.top[49].uid, "u50", "51. oyuncu listeye girdi");
  assert.ok(db.stats.txQueries > tx, "yeniden doldurma sorgusu");
  assert.ok(!(`lb_counted/${rid("u03")}` in db.store), "defterden silindi");
  const tr = db.store[`lb/${WK}_C_TR`];
  assert.equal(tr.count, 29, "u03 TR: ülke özetinden de düştü");
  assert.ok(tr.top.every((e) => e.flag === "TR") && !tr.top.some((e) => e.uid === "u03"));
  // Listede olmayan oyuncunun silinmesi sorgu gerektirmez
  const tx2 = db.stats.txQueries;
  await del(db, m, "u58");
  assert.equal(db.stats.txQueries, tx2);
  assert.equal(db.store[`lb/${WK}_C`].count, 58);
  // Az kayıtlı tablo: silmede sorgu bütün kayıtları getirir, sayı / kovalar kesinleşir
  const small = fakeDb();
  await write(small, m, "a", run("a", 9.5));
  await write(small, m, "b", run("b", 9.6));
  small.store[`lb/${WK}_C`].count = 7;   // eski bir kayma
  await del(small, m, "a");
  assert.equal(small.store[`lb/${WK}_C`].count, 1);
  assert.deepEqual(small.store[`lb/${WK}_C`].hist, { [bucketOf(9.6)]: 1 });
  assert.deepEqual(small.store[`lb/${WK}_C`].top.map((e) => e.uid), ["b"]);
});

test("reddedilen iyileşme: belge silinir, eski geçerli kaydın katkısı defterden düşer", async () => {
  const db = fakeDb();
  const m = fakeMessaging();
  await write(db, m, "ali", run("ali", 9.4));
  await write(db, m, "veli", run("veli", 9.8));
  assert.equal(await write(db, m, "ali", run("ali", 8.0)), "rejected:limit");
  assert.equal(await del(db, m, "ali"), "synced", "silme olayı");
  const w = db.store[`lb/${WK}_C`];
  assert.equal(w.count, 1);
  assert.deepEqual(w.hist, { [bucketOf(9.8)]: 1 });
  assert.deepEqual(w.top.map((e) => e.uid), ["veli"]);
});

test("arkadaş geçti: haber + bildirim, çift başına haftada bir, hak tüketmeyen durumlar", async () => {
  const db = fakeDb({
    "users/ali/friends/f_veli": { since: 1 }, "users/ali/friends/f_ayse": { since: 1 }, "users/ali/friends/f_cem": { since: 1 },
    "users/ali/friends/f_dan": { since: 1 }, "users/ali/friends/f_eda": { since: 1 },
    "push/p_veli": { token: "tokV".repeat(10), lang: "tr", at: 1 },
    "push/p_ayse": { token: "tokA".repeat(10), lang: "de", at: 1 },
    "push/p_cem": { token: "tokC".repeat(10), lang: "en", at: 1, prefs: { race: false } },
    "push/p_dan": { token: "tokD".repeat(10), lang: "fr", at: 1 },
  });
  const m = fakeMessaging({ fail: { ["tokD".repeat(10)]: "messaging/registration-token-not-registered" } });
  await write(db, m, "veli", run("veli", 9.6));
  await write(db, m, "ayse", run("ayse", 9.9));
  await write(db, m, "cem", run("cem", 9.7));
  await write(db, m, "dan", run("dan", 9.65));
  await write(db, m, "eda", run("eda", 9.3));   // jetonsuz, hep önde
  await write(db, m, "ali", run("ali", 10.5));   // ilk kayıt: kimseyi geçmedi
  assert.equal(m.sent.length, 0);
  // 10.5 → 9.62: veli 9.6 hâlâ önde; dan 9.65, cem 9.7, ayse 9.9 geçildi
  assert.equal(await write(db, m, "ali", run("ali", 9.62, { name: "Ali Usta" })), "improved news=3 pushed=1");
  const news = db.store[`users/ayse/lbnews/${rid("ali")}`];
  assert.deepEqual(news, { uid: "ali", name: "Ali Usta", av: "p03", car: "ford_focus", time: 9.62, my_time: 9.9, cls: "C", wk: WK,
    at: Math.floor(NOW / 1000) });
  assert.ok(db.store[`users/cem/lbnews/${rid("ali")}`], "bildirimi kapalı olana da haber");
  assert.ok(db.store[`users/dan/lbnews/${rid("ali")}`]);
  assert.ok(!db.store[`users/veli/lbnews/${rid("ali")}`], "hâlâ önde: haber yok");
  assert.equal(m.sent.length, 1);
  assert.equal(m.sent[0].token, "tokA".repeat(10));
  assert.equal(m.sent[0].notification.body, "Ali Usta hat dich in der Wochentabelle der Klasse C überholt! (9.62 s) 🏁");
  assert.deepEqual(m.sent[0].data, { type: "lb", wk: String(WK), cls: "C", sender: "ali" });
  assert.equal(m.sent[0].android.notification.icon, "icon_monochrome");
  assert.ok(!("push/p_dan" in db.store), "geçersiz jeton silindi");
  assert.deepEqual(db.store[`lb_counted/${rid("ali")}`].pushed, ["ayse"], "yalnız giden bildirim hak tüketir");
  // ayse yeniden öne geçer, ali yine geçer: haber güncellenir, ikinci bildirim YOK
  await write(db, m, "ayse", run("ayse", 9.5));
  await write(db, m, "ali", run("ali", 9.45, { name: "Ali Usta" }));
  assert.equal(m.sent.filter((x) => x.token === "tokA".repeat(10)).length, 1, "aynı çift aynı hafta: tek bildirim");
  assert.equal(db.store[`users/ayse/lbnews/${rid("ali")}`].my_time, 9.5, "haber yeni süreyle");
  // Bu arada veli de geçildi (9.6 > 9.45): ilk kez → bildirim (tr)
  assert.equal(m.sent.filter((x) => x.token === "tokV".repeat(10)).length, 1);
  assert.equal(m.sent.find((x) => x.token === "tokV".repeat(10)).notification.body,
    "Ali Usta seni C sınıfı haftalık tablosunda geçti! (9.45 sn) 🏁");
  // dan bildirimi yeniden açtı ve tekrar geçildi: hakkı tükenmemişti → gider
  db.store["push/p_dan"] = { token: "tokE".repeat(10), lang: "fr", at: 2 };
  await write(db, m, "dan", run("dan", 9.44));
  await write(db, m, "ali", run("ali", 9.43, { name: "Ali Usta" }));
  assert.equal(m.sent.at(-1).token, "tokE".repeat(10));
  assert.match(m.sent.at(-1).notification.body, /t'a dépassé .* classe C ! \(9\.43 s\)/);
  assert.deepEqual(db.store[`lb_counted/${rid("ali")}`].pushed.sort(), ["ayse", "dan", "veli"]);
});

test("bildirim metni: dil seçimi, bilinmeyen dil İngilizce, ad 16 karakter", () => {
  assert.equal(overtakeMessage("es", "Bob", "A", 7.1).body, "¡Bob te superó en la tabla semanal de la clase A! (7.10 s) 🏁");
  assert.equal(overtakeMessage("xx", "Bob", "S", 6).body, "Bob passed you on the class S weekly board! (6.00 s) 🏁");
  assert.equal(overtakeMessage("__proto__", "Bob", "S", 6).body, "Bob passed you on the class S weekly board! (6.00 s) 🏁");
  assert.match(overtakeMessage("tr", "x".repeat(30), "D", 12).body, /^x{16} seni D/);
});

test("ödül kademesi: 1, 4, 25 oyuncu", () => {
  assert.equal(tierFor(1, 1), "top3", "tek oyuncu: ilk 3");
  assert.deepEqual([1, 2, 3, 4].map((r) => tierFor(r, 4)), ["top3", "top3", "", ""], "4 oyuncu: ilk %50 = 2");
  const t25 = Array.from({ length: 25 }, (_, i) => tierFor(i + 1, 25));
  assert.deepEqual(t25.slice(0, 3), ["top3", "top3", "top3"]);
  assert.ok(t25.slice(3, 13).every((t) => t === "p50"), "ceil(2,5)=3: İLK %10 ilk 3'te kalır; 4–13 İLK %50");
  assert.ok(t25.slice(13).every((t) => t === ""));
  assert.deepEqual([3, 4, 10, 11, 50, 51].map((r) => tierFor(r, 100)), ["top3", "p10", "p10", "p50", "p50", ""]);
  assert.equal(tierFor(0, 10), "");
});

test("ödül ayarı: varsayılan, kısmi, bozuk değer", () => {
  assert.deepEqual(rewardsFrom({}), DEFAULT_REWARDS);
  assert.deepEqual(DEFAULT_REWARDS, { top3: { gems: 150, crate: "super_crate" }, p10: { gems: 50, crate: "sport_crate" }, p50: { gems: 15, crate: "" } });
  const r = rewardsFrom({ leaderboard: { rewards: { top3: { gems: 300, crate: "prestige_crate" }, p10: { gems: 5000, crate: "Bad Crate" } } } });
  assert.deepEqual(r.top3, { gems: 300, crate: "prestige_crate" });
  assert.deepEqual(r.p10, { gems: 50, crate: "sport_crate" }, "sınır dışı / bozuk → varsayılan");
  assert.deepEqual(r.p50, DEFAULT_REWARDS.p50);
  assert.deepEqual(rewardsFrom({ leaderboard: { rewards: { p50: { gems: 0, crate: "" } } } }).p50, { gems: 0, crate: "" }, "ödülsüz kademe");
});

/** Hafta WK-1, sınıf A: n oyuncu (sırayla hızlanan), dünya özeti count = n. */
function weekWorld(n, extra = {}) {
  const store = { ...extra };
  for (let i = 1; i <= n; i++) {
    const uid = `p${String(i).padStart(3, "0")}`;
    store[`lb_runs/${rid(uid, "A", WK - 1)}`] = run(uid, 7 + i * 0.01, { wk: WK - 1, cls: "A", car: "audi_rs6" });
  }
  store[`lb/${WK - 1}_A`] = { wk: WK - 1, cls: "A", cc: "", count: n, hist: {}, top: [], updated: 1 };
  return store;
}
const mailOf = (db, uid, wk = WK - 1, cls = "A") => db.store[`users/${uid}/mail/lb_${wk}_${cls}`];
const pay = (db, now = NOW) => payWeekly({ db, now, limits: { audi_rs6: 6.5 }, classes: { audi_rs6: "A" } });

test("haftalık ödül: 25 oyuncu, posta biçimi, paid, iki kez çalışınca tek posta", async () => {
  const db = fakeDb(weekWorld(25));
  const r = await pay(db);
  assert.equal(r.mails, 13);
  assert.deepEqual(r.paid, [`${WK - 1}_A:13/25`]);
  const first = mailOf(db, "p001");
  assert.deepEqual(first, {
    title: { tr: "HAFTALIK DRAG TABLOSU · A SINIFI", en: "WEEKLY DRAG BOARD · CLASS A", es: "TABLA SEMANAL DE DRAG · CLASE A",
      de: "WÖCHENTLICHE DRAG-TABELLE · KLASSE A", fr: "CLASSEMENT DRAG HEBDO · CLASSE A" },
    text: { tr: "Geçen haftayı 1. bitirdin! Ödülün burada.", en: "You finished last week in place 1! Your reward is here.",
      es: "¡Terminaste la semana pasada en el puesto 1! Aquí tienes tu premio.",
      de: "Du hast letzte Woche Platz 1 belegt! Hier ist deine Belohnung.",
      fr: "Tu as fini la semaine dernière à la place 1 ! Voici ta récompense." },
    from: "AUTO YARD", money: 0, gems: 150, crates: { super_crate: 1 }, decor: {}, at: Math.floor(NOW / 1000), expires: 0,
    notify: true, lb: { wk: WK - 1, cls: "A", rank: 1, count: 25, tier: "top3" },
  });
  assert.equal(mailOf(db, "p003").lb.tier, "top3");
  const p4 = mailOf(db, "p004");
  assert.deepEqual([p4.gems, p4.crates, p4.lb.tier], [15, {}, "p50"]);
  assert.equal(p4.text.tr, "Geçen hafta İLK %50'desin (4. sıra)! Ödülün burada.");
  assert.ok(mailOf(db, "p013") && !mailOf(db, "p014"), "ilk ceil(12,5) = 13");
  const sum = db.store[`lb/${WK - 1}_A`];
  assert.equal(sum.paid, true);
  assert.equal(sum.paid_count, 13);
  // İkinci çalışma: paid → dokunulmaz (posta alınıp silinmiş olsa da yeniden yazılmaz)
  delete db.store[`users/p001/mail/lb_${WK - 1}_A`];
  const again = await pay(db);
  assert.equal(again.mails, 0);
  assert.ok(!mailOf(db, "p001"));
});

test("haftalık ödül: 1 ve 4 oyuncu, İLK %10 kademesi, ödülsüz kademe, ayar", async () => {
  const one = fakeDb(weekWorld(1));
  await pay(one);
  assert.equal(mailOf(one, "p001").lb.tier, "top3");
  const four = fakeDb(weekWorld(4));
  await pay(four);
  assert.ok(mailOf(four, "p001") && mailOf(four, "p002") && !mailOf(four, "p003"), "4 oyuncu: ilk 2");
  const big = fakeDb(weekWorld(40, { "config/app": { min_code: 3, leaderboard: { rewards: {
    top3: { gems: 200, crate: "prestige_crate" }, p10: { gems: 60, crate: "city_crate" }, p50: { gems: 0, crate: "" } } } } }));
  const r = await pay(big);
  assert.equal(r.mails, 4, "ilk 3 + İLK %10 (ceil(4)=4); İLK %50 ödülsüz → posta yok");
  assert.deepEqual([mailOf(big, "p001").gems, mailOf(big, "p001").crates], [200, { prestige_crate: 1 }]);
  const p4 = mailOf(big, "p004");
  assert.deepEqual([p4.gems, p4.crates, p4.lb.tier], [60, { city_crate: 1 }, "p10"]);
  assert.equal(p4.text.tr, "Geçen hafta İLK %10'dasın (4. sıra)! Ödülün burada.");
  assert.ok(!mailOf(big, "p005"));
});

test("haftalık ödül: özet yok / bu hafta / sınırı sonradan sıkılaşan koşu / kaçmış önceki hafta", async () => {
  const store = weekWorld(3);
  store[`lb_runs/${rid("cheat", "A", WK - 1)}`] = run("cheat", 6.0, { wk: WK - 1, cls: "A", car: "audi_rs6" });
  store[`lb/${WK - 1}_A`].count = 4;
  // Bu haftanın tablosu ödenmez; iki hafta önceki ödenmemiş tablo ödenir
  store[`lb_runs/${rid("now1", "A", WK)}`] = run("now1", 7.5, { wk: WK, cls: "A", car: "audi_rs6" });
  store[`lb/${WK}_A`] = { wk: WK, cls: "A", cc: "", count: 1, hist: {}, top: [] };
  store[`lb_runs/${rid("old1", "S", WK - 2)}`] = run("old1", 6.0, { wk: WK - 2, cls: "S", car: "x_car" });
  store[`lb/${WK - 2}_S`] = { wk: WK - 2, cls: "S", cc: "", count: 1, hist: {}, top: [] };
  const db = fakeDb(store);
  const r = await pay(db);
  assert.ok(!mailOf(db, "cheat"), "hile sınırının altındaki koşu ödül almaz");
  assert.equal(mailOf(db, "p001").lb.rank, 1, "sıra kaymaz");
  assert.ok(mailOf(db, "p002") && !mailOf(db, "p003"), "4 sayılır: ilk 2");
  assert.ok(!db.store[`users/now1/mail/lb_${WK}_A`] && !db.store[`lb/${WK}_A`].paid, "bu hafta ödenmez");
  assert.ok(db.store[`users/old1/mail/lb_${WK - 2}_S`], "kaçmış hafta ödendi");
  assert.equal(r.paid.length, 2);
  const empty = fakeDb({});
  assert.deepEqual(await pay(empty), { week: WK, paid: [], mails: 0, pruned: [] }, "özet yoksa hiçbir şey");
});


test("budama: ödenen haftada ilk 100 kalır, dereceleri profile yazılır, gerisi defteriyle silinir", async () => {
  const store = weekWorld(260);
  for (let i = 0; i < 260; i++) {
    const uid = `p${String(i + 1).padStart(3, "0")}`;
    store[`lb_counted/${rid(uid, "A", WK - 1)}`] = { uid, time: 7 + i * 0.01 };
  }
  store[`lb/${WK - 1}_A`].count = 261;
  store[`lb_runs/${rid("cheat", "A", WK - 1)}`] = run("cheat", 6.0, { wk: WK - 1, cls: "A", car: "audi_rs6" });
  store["lb_hist/p001"] = { uid: "p001", recs: [{ wk: WK - 1, cls: "A", rank: 9, count: 5 }, { wk: WK - 3, cls: "B", rank: 4, count: 50 }] };
  const db = fakeDb(store);
  const r = await pay(db);
  assert.deepEqual(r.pruned, [`${WK - 1}_A:100+161`]);
  const runs = Object.keys(db.store).filter((p) => p.startsWith("lb_runs/"));
  assert.equal(runs.length, 100, "yalnız ilk 100'ün koşusu kaldı (İZLE için)");
  assert.ok(db.store[`lb_runs/${rid("p100", "A", WK - 1)}`] && !db.store[`lb_runs/${rid("p101", "A", WK - 1)}`]);
  assert.ok(!db.store[`lb_runs/${rid("cheat", "A", WK - 1)}`], "sınırı sonradan sıkılaşan geçersiz koşu da silindi");
  assert.ok(db.store[`lb_counted/${rid("p100", "A", WK - 1)}`] && !db.store[`lb_counted/${rid("p101", "A", WK - 1)}`],
    "silinenin defteri de silindi (silme tetikleyicisi özeti değiştirmez)");
  const h1 = db.store["lb_hist/p001"];
  assert.deepEqual(h1.recs[0], { wk: WK - 1, cls: "A", rank: 1, count: 261, tier: "top3", time: 7.01, car: "audi_rs6", paint: "", stage: 2 });
  assert.equal(h1.recs.length, 2, "aynı hafta + sınıfın eski satırı yenisiyle değişti, eski hafta kaldı");
  assert.equal(db.store["lb_hist/p100"].recs[0].rank, 100);
  assert.equal(db.store["lb_hist/p100"].recs[0].tier, "p50");
  assert.ok(!db.store["lb_hist/p101"], "101. profile yazılmaz");
  const sum = db.store[`lb/${WK - 1}_A`];
  assert.equal(sum.pruned, true);
  assert.equal(sum.kept, 100);
  // İkinci çalışma: budanmış → dokunulmaz; ödenmiş ama budanmamış hafta (bu sürümden önce ödenen) budanır
  assert.deepEqual((await pay(db)).pruned, []);
  const old = fakeDb(weekWorld(3));
  old.store[`lb/${WK - 1}_A`].paid = true;
  const r2 = await pay(old);
  assert.deepEqual([r2.mails, r2.pruned], [0, [`${WK - 1}_A:3+0`]]);
  assert.equal(old.store["lb_hist/p003"].recs[0].rank, 3);
});

test("profil dereceleri: en yeni hafta önce, en çok HIST_MAX", () => {
  const recs = [];
  for (let w = 1; w <= lb.HIST_MAX; w++) recs.push({ wk: w, cls: "A", rank: 5 });
  const out = lb.mergeHist(recs, [{ wk: 100, cls: "S", rank: 2 }, { wk: 100, cls: "B", rank: 1 }]);
  assert.equal(out.length, lb.HIST_MAX);
  assert.deepEqual(out.slice(0, 2).map((r) => r.cls), ["B", "S"], "aynı haftada iyi sıra önce");
  assert.ok(!out.some((r) => r.wk === 1 || r.wk === 2), "en eski iki hafta düştü");
  assert.deepEqual(lb.mergeHist(undefined, [{ wk: 3, cls: "A", rank: 1 }]), [{ wk: 3, cls: "A", rank: 1 }]);
});

test("donmuş hafta: budanan koşunun silinmesi özeti değiştirmez; ilk 100'deki koşu silinince derece ve satırı düşer", async () => {
  const id = rid("p002", "A", WK - 1);
  const store = {
    [`lb/${WK - 1}_A`]: { wk: WK - 1, cls: "A", cc: "", count: 7, hist: { 140: 7 }, paid: true, pruned: true,
      top: [{ uid: "p001", time: 7 }, { uid: "p002", time: 7.01 }] },
    [`lb/${WK - 1}_A_DE`]: { wk: WK - 1, cls: "A", cc: "DE", count: 2, hist: { 140: 2 }, paid: false,
      top: [{ uid: "p002", time: 7.01 }, { uid: "p009", time: 7.2 }] },
    [`lb_counted/${id}`]: { uid: "p002", time: 7.01 },
    "lb_hist/p002": { uid: "p002", recs: [{ wk: WK - 1, cls: "A", rank: 2 }, { wk: WK - 2, cls: "A", rank: 8 }] },
  };
  const db = fakeDb(store);
  const before = run("p002", 7.01, { wk: WK - 1, cls: "A", car: "audi_rs6", flag: "DE" });
  // Budanmış (defteri yok) koşu: hiçbir şey değişmez
  const pruned = await handleRunWritten({ db, messaging: fakeMessaging(), id: rid("p300", "A", WK - 1),
    before: run("p300", 9, { wk: WK - 1, cls: "A", car: "audi_rs6" }), after: null, now: NOW, limits: {}, classes: {} });
  assert.equal(pruned, "frozen");
  assert.equal(db.store[`lb/${WK - 1}_A`].count, 7);
  // İlk 100'deki koşu (panel / hesap silme): derece ve listelerdeki satır düşer, sayı / kovalar aynı
  const r = await handleRunWritten({ db, messaging: fakeMessaging(), id, before, after: null, now: NOW, limits: {}, classes: {} });
  assert.equal(r, "frozen:forgot");
  const sum = db.store[`lb/${WK - 1}_A`];
  assert.deepEqual([sum.count, sum.hist, sum.top.map((e) => e.uid)], [7, { 140: 7 }, ["p001"]]);
  assert.deepEqual(db.store[`lb/${WK - 1}_A_DE`].top.map((e) => e.uid), ["p009"]);
  assert.deepEqual(db.store["lb_hist/p002"].recs, [{ wk: WK - 2, cls: "A", rank: 8 }]);
  assert.ok(!db.store[`lb_counted/${id}`]);
});
