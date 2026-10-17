// news.js testi (internetsiz): sahte Firestore + sahte messaging. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { handleRaceNews, messageFor, shouldNotify, PAIR_INTERVAL_MS } = require("../news");

function fakeDb(initial = {}) {
  const store = { ...initial };
  const ref = (path) => ({
    path,
    async get() {
      return { exists: path in store, data: () => store[path] };
    },
    async set(v) { store[path] = v; },
    async delete() { delete store[path]; },
  });
  return {
    store,
    doc: ref,
    async runTransaction(fn) {
      const writes = [];
      const t = { get: (r) => r.get(), set: (r, v) => writes.push([r.path, v]) };
      const out = await fn(t);
      for (const [p, v] of writes) store[p] = v;
      return out;
    },
  };
}

function fakeMessaging(fail) {
  const sent = [];
  return { sent, async send(m) { if (fail) { const e = new Error("x"); e.code = fail; throw e; } sent.push(m); } };
}

const win = (over = {}) => ({ name: "Bob Usta", car: "seat_leon", their_car: "vw_golf_7", won: true, revenge: false, at: 1, ...over });
const H = 60 * 60 * 1000;

test("yalnız kazanan gönderen bildirim doğurur", () => {
  assert.equal(shouldNotify(null, win()), true);
  assert.equal(shouldNotify(null, win({ won: false })), false);
  assert.equal(shouldNotify(win(), win()), false, "aynı yarış (at değişmedi)");
  assert.equal(shouldNotify(win(), win({ at: 2 })), true);
  assert.equal(shouldNotify(win(), null), false, "silme");
});

test("kullanıcının örneği: A→B, A→B tekrar, A→C, C→B (6 saat kuralı çift başına)", async () => {
  const db = fakeDb({ "push/p_B": { token: "tokB", lang: "tr" }, "push/p_C": { token: "tokC", lang: "en" } });
  const m = fakeMessaging();
  const t0 = 1_000_000_000;
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "A", before: null, after: win({ at: 1 }), now: t0 }), "sent");
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "A", before: win({ at: 1 }), after: win({ at: 2 }), now: t0 + H }), "throttled");
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "C", sender: "A", before: null, after: win({ at: 3 }), now: t0 + H }), "sent");
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "C", before: null, after: win({ name: "Cem", at: 4 }), now: t0 + 2 * H }), "sent");
  assert.equal(m.sent.length, 3);
  assert.deepEqual(m.sent.map((x) => x.token), ["tokB", "tokC", "tokB"]);
  assert.equal(m.sent[0].android.notification.icon, "icon_monochrome", "tek renkli durum çubuğu ikonu");
  assert.equal(m.sent[0].data.from, "A");
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "A", before: win({ at: 2 }), after: win({ at: 5 }), now: t0 + PAIR_INTERVAL_MS }), "sent", "6 saat dolunca yine gider");
});

test("kaybeden gönderen bildirim doğurmaz ve sınırı tüketmez", async () => {
  const db = fakeDb({ "push/p_B": { token: "tokB", lang: "tr" } });
  const m = fakeMessaging();
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "A", before: null, after: win({ won: false }), now: 5 }), "skip");
  assert.equal(await handleRaceNews({ db, messaging: m, recipient: "B", sender: "A", before: null, after: win({ at: 9 }), now: 6 }), "sent");
});

test("jetonu olmayan alıcı: gönderilmez", async () => {
  const db = fakeDb();
  assert.equal(await handleRaceNews({ db, messaging: fakeMessaging(), recipient: "B", sender: "A", before: null, after: win(), now: 1 }), "no-token");
});

test("geçersiz jeton silinir", async () => {
  const db = fakeDb({ "push/p_B": { token: "old", lang: "es" } });
  const r = await handleRaceNews({ db, messaging: fakeMessaging("messaging/registration-token-not-registered"), recipient: "B", sender: "A", before: null, after: win(), now: 1 });
  assert.equal(r, "stale");
  assert.equal("push/p_B" in db.store, false);
});

test("dile göre metin; İNTİKAM metni; bilinmeyen dil İngilizce", () => {
  assert.match(messageFor("tr", "Bob Usta", false).body, /^Bob Usta yarışta aracını yendi!/);
  assert.match(messageFor("tr", "Bob Usta", true).body, /intikamını aldı/);
  assert.match(messageFor("es", "Bob", false).body, /le ganó a tu coche/);
  assert.match(messageFor("de", "Bob", false).body, /beat your car/);
  assert.equal(messageFor("en", "x".repeat(40), false).body.startsWith("x".repeat(16) + " "), true, "ad 16 karakterle sınırlı");
});

test("kendine / eksik kimlik: atlanır", async () => {
  const db = fakeDb({ "push/p_B": { token: "t", lang: "tr" } });
  assert.equal(await handleRaceNews({ db, messaging: fakeMessaging(), recipient: "B", sender: "B", before: null, after: win(), now: 1 }), "skip");
});
