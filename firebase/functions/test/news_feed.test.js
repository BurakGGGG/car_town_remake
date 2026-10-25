// news_feed.js testi (internetsiz): sahte Firestore + sahte messaging. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { excerpt, messagesFor, pushState, sameExceptPushedAt, pushNews, handleNewsWritten, pushScheduled, LANGS, buildNewsFeed,
  refreshFeed, FEED_MAX } = require("../news_feed");

// İşlem: okumalar anlık, yazmalar sonda uygulanır; işlemler sırayla çalışır (yönetici SDK'sının işlemi okuduğu belgeyi
// kilitler: aynı belgeye iki işlem iç içe geçemez). update yalnız var olan belgeye.
function fakeDb(initial = {}) {
  const store = JSON.parse(JSON.stringify(initial));
  const reads = { queries: 0 };
  let lock = Promise.resolve();
  const ref = (path) => ({
    path,
    async get() { return { exists: path in store, data: () => store[path] }; },
    async update(v) {
      if (!(path in store)) throw new Error("NOT_FOUND");
      store[path] = { ...store[path], ...v };
    },
  });
  return {
    store,
    reads,
    doc: ref,
    runTransaction(fn) {
      const run = lock.then(async () => {
        const writes = [];
        const t = { get: (r) => r.get(), update: (r, v) => writes.push([r.path, v, false]), set: (r, v) => writes.push([r.path, v, true]) };
        const out = await fn(t);
        for (const [p, v, replace] of writes) store[p] = replace ? JSON.parse(JSON.stringify(v)) : { ...store[p], ...v };
        return out;
      });
      lock = run.catch(() => {});
      return run;
    },
    collection(name) {
      const filters = [];
      const q = {
        where(field, op, value) { assert.strictEqual(op, "=="); filters.push([field, value]); return q; },
        async get() {
          reads.queries++;
          const docs = Object.keys(store).filter((p) => p.startsWith(name + "/") && !p.slice(name.length + 1).includes("/"))
            .filter((p) => filters.every(([f, v]) => store[p][f] === v))
            .map((p) => ({ id: p.slice(name.length + 1), data: () => store[p] }));
          return { docs, size: docs.length };
        },
      };
      return q;
    },
  };
}

// FCM sunucusunun veri yükü kuralları (news.test.js ile aynı): ayrılmış anahtar ve metin olmayan değer reddedilir.
function fakeMessaging({ failTopics = [] } = {}) {
  const sent = [];
  return {
    sent,
    async send(m) {
      for (const [k, v] of Object.entries(m.data || {})) {
        if (k === "from" || k === "message_type" || k.startsWith("google.") || k.startsWith("gcm.") || typeof v !== "string") {
          throw Object.assign(new Error(`Invalid data payload key: ${k}`), { code: "messaging/invalid-argument" });
        }
      }
      if (failTopics.includes(m.topic) || failTopics.includes("*")) throw Object.assign(new Error("x"), { code: "messaging/internal-error" });
      sent.push(m);
    },
  };
}

const NOW = 1_800_000_000_000;
const S = Math.floor(NOW / 1000);
const item = (over = {}) => ({
  kind: "event", title: { tr: "Hafta sonu çifte para!", en: "Double money weekend!" },
  text: { tr: "Cumartesi ve pazar\ntamirden iki kat para.", en: "Twice the money from repairs." },
  image: "", action: { kind: "event", url: "" }, start: 0, end: 0, pinned: false, code: 0,
  target: { langs: [], min_level: 0, max_level: 0, min_code: 0, max_code: 0 }, notify: true, pushed_at: 0, at: S - 60, ...over,
});

test("özet: kısa metin aynen, uzun metin sözcükte kesilir, satır sonu boşluk", () => {
  assert.equal(excerpt("Kısa\nmetin"), "Kısa metin");
  const long = "Bu çok uzun bir haber metnidir ".repeat(10);
  const e = excerpt(long);
  assert.ok([...e].length <= 120, "en çok 120 karakter");
  assert.ok(e.endsWith("…") && !e.endsWith(" …"), e);
  assert.equal(excerpt("🏁".repeat(130)).length, 119 * 2 + 1, "emoji tek karakter sayılır (oyundaki gibi)");
});

test("ileti: her dil konusuna, dilinde; eksik dil en → tr; veri yükü FCM'ye uygun", () => {
  const msgs = messagesFor("n_abc_123456", item());
  assert.deepEqual(msgs.map((m) => m.topic), LANGS.map((l) => `news_${l}`));
  const tr = msgs[0];
  assert.deepEqual(tr.notification, { title: "Hafta sonu çifte para!", body: "Cumartesi ve pazar tamirden iki kat para." });
  assert.equal(msgs[3].notification.title, "Double money weekend!", "de → en");
  assert.deepEqual(tr.data, { type: "news", id: "n_abc_123456" });
  assert.deepEqual(tr.android, { priority: "high", notification: { tag: "news", icon: "icon_monochrome", color: "#F5BE4C" } });
  const only = messagesFor("n1", item({ title: { tr: "Yalnız Türkçe" }, text: { tr: "Metin" } }));
  assert.equal(only[1].notification.title, "Yalnız Türkçe", "en yoksa tr");
  const noText = messagesFor("n1", item({ text: {} }))[0];
  assert.deepEqual(noText.notification, { title: "AUTO YARD", body: "Hafta sonu çifte para!" }, "metin yoksa başlık metne iner");
});

test("hedef diller: yalnız seçilen konular", () => {
  const msgs = messagesFor("n1", item({ target: { langs: ["de", "tr"] } }));
  assert.deepEqual(msgs.map((m) => m.topic), ["news_tr", "news_de"]);
});

test("ne zaman gider: görünür, bildirimli, gönderilmemiş, hedefsiz", () => {
  assert.equal(pushState(item(), S), "ready");
  assert.equal(pushState(null, S), "missing");
  assert.equal(pushState(item({ notify: false }), S), "no-notify");
  assert.equal(pushState(item({ pushed_at: S - 5 }), S), "already");
  assert.equal(pushState(item({ start: S + 60 }), S), "scheduled");
  assert.equal(pushState(item({ start: S }), S), "ready", "başlangıç anı dahil");
  assert.equal(pushState(item({ end: S }), S), "ended");
  assert.equal(pushState(item({ end: S + 1 }), S), "ready");
  assert.equal(pushState(item({ target: { langs: [], min_level: 5 } }), S), "targeted", "seviye hedefi konu bildirimiyle süzülemez");
  assert.equal(pushState(item({ target: { max_code: 20 } }), S), "targeted");
  assert.equal(pushState(item({ title: {}, text: {} }), S), "empty");
});

test("yalnız pushed_at değişen yazma tanınır (anahtar sırası önemsiz)", () => {
  const a = item();
  const b = { ...item({ pushed_at: S }) };
  const reordered = Object.fromEntries(Object.entries(b).reverse());
  assert.equal(sameExceptPushedAt(a, reordered), true);
  assert.equal(sameExceptPushedAt(a, item({ title: { tr: "Başka" } })), false);
  assert.equal(sameExceptPushedAt(a, item({ target: { langs: ["tr"], min_level: 0, max_level: 0, min_code: 0, max_code: 0 } })), false);
});

test("panel kaydı: hemen görünür haber gider, pushed_at yazılır; ikinci yazma göndermez", async () => {
  const db = fakeDb({ "news/n1": item() });
  const m = fakeMessaging();
  const r = await handleNewsWritten({ db, messaging: m, id: "n1", before: null, after: db.store["news/n1"], now: NOW });
  assert.equal(r, "sent 5/5");
  assert.equal(m.sent.length, 5);
  assert.equal(db.store["news/n1"].pushed_at, S);
  // Fonksiyonun kendi pushed_at yazması tetiği yeniden çalıştırır: okuma yapmadan atlanır
  const self = await handleNewsWritten({ db, messaging: m, id: "n1", before: item(), after: db.store["news/n1"], now: NOW + 1000 });
  assert.equal(self, "self");
  // Panelde düzenleme (başlık değişti): bildirim yeniden gitmez
  const edited = { ...db.store["news/n1"], title: { tr: "Yeni başlık" } };
  db.store["news/n1"] = edited;
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "n1", before: item({ pushed_at: S }), after: edited, now: NOW + 2000 }), "already");
  assert.equal(m.sent.length, 5);
});

test("iki tetik aynı anda: işlem yalnız birine gönderdirir", async () => {
  const db = fakeDb({ "news/n1": item() });
  const m = fakeMessaging();
  const results = await Promise.all([pushNews({ db, messaging: m, id: "n1", now: NOW }), pushNews({ db, messaging: m, id: "n1", now: NOW })]);
  assert.deepEqual(results.sort(), ["already", "sent 5/5"]);
  assert.equal(m.sent.length, 5);
});

test("zamanlı haber: tetikte beklemede, zamanlayıcı başlangıçta gönderir", async () => {
  const db = fakeDb({ "news/n1": item({ start: S + 600 }), "news/n2": item({ notify: false }), "news/n3": item({ pushed_at: S - 99 }) });
  const m = fakeMessaging();
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "n1", before: null, after: db.store["news/n1"], now: NOW }), "scheduled");
  assert.deepEqual(await pushScheduled({ db, messaging: m, now: NOW }), { pending: 1, sent: 0, failed: 0 }, "bekleyen 1, henüz erken");
  assert.equal(m.sent.length, 0);
  assert.deepEqual(await pushScheduled({ db, messaging: m, now: NOW + 600_000 }), { pending: 1, sent: 1, failed: 0 });
  assert.equal(m.sent.length, 5);
  assert.equal(db.store["news/n1"].pushed_at, S + 600);
  assert.deepEqual(await pushScheduled({ db, messaging: m, now: NOW + 1_200_000 }), { pending: 0, sent: 0, failed: 0 }, "bir kez");
});

test("hiçbir dile gidemezse: ayırma geri alınır, hata yükselir; zamanlayıcı sonra gönderir", async () => {
  const db = fakeDb({ "news/n1": item({ target: { langs: ["tr", "en"] } }) });
  await assert.rejects(pushNews({ db, messaging: fakeMessaging({ failTopics: ["*"] }), id: "n1", now: NOW }));
  assert.equal(db.store["news/n1"].pushed_at, 0, "yeniden denenebilir");
  // Geri alma yazması yalnız pushed_at'i değiştirir: tetik döngüye girmez
  assert.equal(await handleNewsWritten({ db, messaging: fakeMessaging(), id: "n1", before: { ...db.store["news/n1"], pushed_at: S },
    after: db.store["news/n1"], now: NOW }), "self");
  const m = fakeMessaging();
  assert.deepEqual(await pushScheduled({ db, messaging: m, now: NOW + 600_000 }), { pending: 1, sent: 1, failed: 0 });
  assert.deepEqual(m.sent.map((x) => x.topic), ["news_tr", "news_en"]);
});

test("bir dil başarısız, öbürleri gitti: pushed_at kalır (gidenlere ikinci kez gitmez)", async () => {
  const db = fakeDb({ "news/n1": item() });
  const m = fakeMessaging({ failTopics: ["news_es"] });
  assert.equal(await pushNews({ db, messaging: m, id: "n1", now: NOW }), "sent 4/5");
  assert.equal(db.store["news/n1"].pushed_at, S);
});

test("gitmeyenler: bildirimsiz, bitmiş, hedefli, silinmiş", async () => {
  const m = fakeMessaging();
  const db = fakeDb({ "news/a": item({ end: S - 1 }), "news/b": item({ target: { langs: [], min_level: 3 } }) });
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "x", before: null, after: item({ notify: false }), now: NOW }), "no-notify");
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "a", before: null, after: db.store["news/a"], now: NOW }), "ended");
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "b", before: null, after: db.store["news/b"], now: NOW }), "targeted");
  assert.equal(await handleNewsWritten({ db, messaging: m, id: "c", before: item(), after: null, now: NOW }), "deleted");
  assert.equal(await pushNews({ db, messaging: m, id: "yok", now: NOW }), "missing");
  assert.equal(m.sent.length, 0);
  assert.equal(db.store["news/a"].pushed_at, 0, "gitmeyen haber işaretlenmez");
});

// --- Yayın belgesi config/news ---------------------------------------------------------------------------------------

test("yayın: bitmemiş haberler (başlamamış dahil), yeniden eskiye, yalnız herkese açık alanlar", () => {
  const docs = [
    { id: "n_a", ...item({ at: S - 300 }) },
    { id: "n_b", ...item({ at: S - 100, start: S + 3600 }) },          // başlamamış: oyun süzer, yayında kalır
    { id: "n_c", ...item({ at: S - 200, end: S }) },                   // bitti (end ≤ şimdi)
    { id: "n_d", ...item({ at: S - 50, end: S + 60, pushed_at: S }) },
  ];
  const feed = buildNewsFeed(docs, NOW);
  assert.equal(feed.at, S);
  assert.deepEqual(feed.items.map((i) => i.id), ["n_d", "n_b", "n_a"]);
  assert.deepEqual(Object.keys(feed.items[0]), ["id", "kind", "title", "text", "image", "action", "start", "end", "pinned", "code",
    "target", "at"], "notify / pushed_at yayına girmez");
  assert.deepEqual(feed.items[2].action, { kind: "event", url: "" });
  assert.deepEqual(buildNewsFeed([], NOW), { items: [], at: S });
});

test("yayın: en çok 40; SABİT haber eski olsa da sınırda düşmez", () => {
  const docs = Array.from({ length: 45 }, (_, i) => ({ id: `n_${String(i).padStart(2, "0")}`, ...item({ at: S - i }) }));
  docs.push({ id: "n_old_pin", ...item({ at: 5, pinned: true }) });
  const feed = buildNewsFeed(docs, NOW);
  assert.equal(feed.items.length, FEED_MAX);
  assert.ok(feed.items.some((i) => i.id === "n_old_pin"), "sabit haber sınırda kalır");
  assert.equal(feed.items[0].id, "n_00", "yeniden eskiye");
  assert.equal(feed.items[FEED_MAX - 1].id, "n_old_pin", "sabit de at sırasında (oyun sabitleri başa alır)");
  assert.ok(!feed.items.some((i) => i.id === "n_39"), "41. ve sonrası (sabit olmayan) düşer");
});

test("yayın: en kötü durum (40 haber × 5 dil × 600 emoji) belge sınırının (1 MiB) altında", () => {
  const huge = { tr: "🏁".repeat(600), en: "🏁".repeat(600), es: "🏁".repeat(600), de: "🏁".repeat(600), fr: "🏁".repeat(600) };
  const docs = Array.from({ length: 40 }, (_, i) => ({ id: `n_${i}`, ...item({ at: S - i, text: huge }) }));
  const feed = buildNewsFeed(docs, NOW);
  assert.ok(Buffer.byteLength(JSON.stringify(feed)) < 1_000_000, "belge sınırın altında");
  assert.equal(feed.items.length, 40, "hepsi sığar (900 KB güvenlik sınırına ulaşılmaz)");
});

test("zamanlayıcı yayını: biten haber yoksa yalnız 1 okuma; varsa koleksiyondan yeniden kurulur", async () => {
  const db = fakeDb({
    "news/n_a": item({ at: S - 10 }),
    "news/n_b": item({ at: S - 20, end: S + 600 }),
  });
  db.store["config/news"] = buildNewsFeed([{ id: "n_a", ...db.store["news/n_a"] }, { id: "n_b", ...db.store["news/n_b"] }], NOW);
  assert.deepEqual(await refreshFeed({ db, now: NOW }), { ended: 0 });
  assert.equal(db.reads.queries, 0, "koleksiyon okunmadı");
  const r = await refreshFeed({ db, now: NOW + 600_000 });
  assert.deepEqual(r, { ended: 1, items: 1 });
  assert.equal(db.reads.queries, 1);
  assert.deepEqual(db.store["config/news"].items.map((i) => i.id), ["n_a"]);
  assert.equal(db.store["config/news"].at, S + 600);
  assert.deepEqual(await refreshFeed({ db: fakeDb(), now: NOW }), { ended: 0 }, "yayın belgesi yoksa dokunulmaz");
});
