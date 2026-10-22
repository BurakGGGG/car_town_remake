// refunds.js testi (internetsiz): sahte Firestore. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { processVoided, tokenKey } = require("../refunds");

const NOW = 1_800_000_000_000;

function fakeDb(initial = {}) {
  const store = JSON.parse(JSON.stringify(initial));
  return {
    store,
    doc: (path) => ({
      async get() { return { exists: path in store, data: () => store[path] }; },
      async set(v, opts) { store[path] = opts && opts.merge ? { ...(store[path] || {}), ...v } : v; },
    }),
  };
}

const T1 = "token-hesapli-0123456789abcdefghij";
const T2 = "token-misafir-0123456789abcdefghij";
const T3 = "token-bilinmeyen-0123456789abcdefgh";

test("hesaplı satın alma: kayıt işaretlenir, oyuncuya iade belgesi", async () => {
  const db = fakeDb({ [`iap/${tokenKey(T1)}`]: { product: "gems_pack_2", quantity: 1, order: "GPA.1", uid: "ali", status: "ok" } });
  const r = await processVoided({ db, now: NOW, items: [{ purchaseToken: T1, voidedTimeMillis: NOW - 3600_000, voidedReason: 1, voidedSource: 0 }] });
  assert.deepStrictEqual(r, { seen: 1, unknown: 0, already: 0, marked: 1, notified: 1 });
  const rec = db.store[`iap/${tokenKey(T1)}`];
  assert.strictEqual(rec.voided, true);
  assert.strictEqual(rec.voided_reason, 1);
  assert.strictEqual(rec.voided_at, (NOW - 3600_000) / 1000);
  assert.deepStrictEqual(db.store[`users/ali/refunds/${tokenKey(T1)}`],
    { product: "gems_pack_2", quantity: 1, order: "GPA.1", at: (NOW - 3600_000) / 1000 });
});

test("misafir satın alması yalnız işaretlenir; bilinmeyen belirteç sayılır", async () => {
  const db = fakeDb({ [`iap/${tokenKey(T2)}`]: { product: "gems_pack_1", uid: "" } });
  const r = await processVoided({ db, now: NOW, items: [{ purchaseToken: T2 }, { purchaseToken: T3 }, {}, null] });
  assert.deepStrictEqual(r, { seen: 2, unknown: 1, already: 0, marked: 1, notified: 0 });
  assert.ok(!Object.keys(db.store).some((p) => p.includes("/refunds/")));
});

test("aynı iade ikinci okumada yeniden işlenmez", async () => {
  const db = fakeDb({ [`iap/${tokenKey(T1)}`]: { product: "gems_pack_2", uid: "ali" } });
  const items = [{ purchaseToken: T1, voidedTimeMillis: NOW }];
  await processVoided({ db, now: NOW, items });
  delete db.store[`users/ali/refunds/${tokenKey(T1)}`];   // oyun uyguladı ve sildi
  const r = await processVoided({ db, now: NOW, items });
  assert.deepStrictEqual(r, { seen: 1, unknown: 0, already: 1, marked: 0, notified: 0 });
  assert.ok(!(`users/ali/refunds/${tokenKey(T1)}` in db.store), "oyuncuya ikinci kez iade bırakılmaz");
});

test("bozuk uid yola girmez", async () => {
  const db = fakeDb({ [`iap/${tokenKey(T1)}`]: { product: "gems_pack_2", uid: "../../players/x" } });
  const r = await processVoided({ db, now: NOW, items: [{ purchaseToken: T1 }] });
  assert.strictEqual(r.notified, 0);
  assert.ok(!Object.keys(db.store).some((p) => p.includes("/refunds/")));
});
