// iap.js testi (internetsiz): sahte Play yanıtı + sahte Firestore. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { verifyPurchase, classify, tokenKey, IapError } = require("../iap");

const TOKEN = "abcdefghijklmnopqrstuvwxyz.AO-J1Oz_123456";
const NOW = 1_800_000_000_000;

function fakeDb() {
  const store = {};
  return {
    store,
    doc: (path) => ({ async set(v, opts) { store[path] = opts && opts.merge ? { ...(store[path] || {}), ...v } : v; } }),
  };
}

function play(code, body) {
  const calls = [];
  const fetchPurchase = async (pkg, product, token) => {
    calls.push([pkg, product, token]);
    return { code, body };
  };
  return { calls, fetchPurchase };
}

const req = (over = {}) => ({ package: "com.autoyard.app", product: "gems_pack_2", token: TOKEN, uid: "u1", ...over });

test("ödenmiş, tüketilmemiş satın alma: ok + kayıt", async () => {
  const db = fakeDb();
  const p = play(200, { purchaseState: 0, consumptionState: 0, orderId: "GPA.1", quantity: 1, productId: "gems_pack_2" });
  const r = await verifyPurchase(req(), { fetchPurchase: p.fetchPurchase, db, now: NOW });
  assert.deepStrictEqual(r, { status: "ok", product: "gems_pack_2", order: "GPA.1", quantity: 1, test: false });
  assert.deepStrictEqual(p.calls, [["com.autoyard.app", "gems_pack_2", TOKEN]]);
  const doc = db.store[`iap/${tokenKey(TOKEN)}`];
  assert.strictEqual(doc.status, "ok");
  assert.strictEqual(doc.uid, "u1");
  assert.strictEqual(doc.at, NOW / 1000);
  assert.ok(!JSON.stringify(db.store).includes(TOKEN), "ham belirteç kayda yazılmaz");
});

test("test satın alması (lisans testçisi) işaretlenir, miktar Play'den", async () => {
  const p = play(200, { purchaseState: 0, consumptionState: 0, purchaseType: 0, quantity: 3 });
  const r = await verifyPurchase(req(), { fetchPurchase: p.fetchPurchase, db: fakeDb(), now: NOW });
  assert.strictEqual(r.status, "ok");
  assert.strictEqual(r.test, true);
  assert.strictEqual(r.quantity, 3);
});

test("Play durumları: bekleyen, iptal, tüketilmiş, başka ürün", () => {
  assert.strictEqual(classify({ purchaseState: 2 }, "a"), "pending");
  assert.strictEqual(classify({ purchaseState: 1 }, "a"), "canceled");
  assert.strictEqual(classify({ purchaseState: 0, consumptionState: 1 }, "a"), "consumed");
  assert.strictEqual(classify({ purchaseState: 0, productId: "b" }, "a"), "invalid");
  assert.strictEqual(classify(null, "a"), "invalid");
});

test("Play belirteci tanımıyor (400/404/410): invalid", async () => {
  for (const code of [400, 404, 410]) {
    const r = await verifyPurchase(req(), { fetchPurchase: play(code, {}).fetchPurchase, db: fakeDb(), now: NOW });
    assert.strictEqual(r.status, "invalid", String(code));
  }
});

test("izin / kota / sunucu hatası ve ağ: unavailable (oyuncu reddedilmez)", async () => {
  for (const code of [401, 403, 429, 500, 503]) {
    await assert.rejects(verifyPurchase(req(), { fetchPurchase: play(code, {}).fetchPurchase, db: fakeDb(), now: NOW }),
      (e) => e instanceof IapError && e.reason === "unavailable", String(code));
  }
  const down = async () => { throw new Error("ECONNRESET"); };
  await assert.rejects(verifyPurchase(req(), { fetchPurchase: down, db: fakeDb(), now: NOW }),
    (e) => e instanceof IapError && e.reason === "unavailable");
});

test("bozuk istek Play'e gitmez", async () => {
  const p = play(200, { purchaseState: 0 });
  for (const bad of [req({ package: "com.evil.app" }), req({ product: "GEMS PACK" }), req({ token: "kisa" }),
    req({ token: "a".repeat(30) + "/../x" }), null]) {
    await assert.rejects(verifyPurchase(bad, { fetchPurchase: p.fetchPurchase, db: fakeDb(), now: NOW }),
      (e) => e instanceof IapError && e.reason === "bad_request");
  }
  assert.strictEqual(p.calls.length, 0);
});

test("kayıt yazılamazsa doğrulama yine döner; uydurma uid yazılmaz", async () => {
  const broken = { doc: () => ({ async set() { throw new Error("down"); } }) };
  const ok = play(200, { purchaseState: 0, consumptionState: 0 });
  const r = await verifyPurchase(req(), { fetchPurchase: ok.fetchPurchase, db: broken, now: NOW });
  assert.strictEqual(r.status, "ok");
  const db = fakeDb();
  await verifyPurchase(req({ uid: "../../x" }), { fetchPurchase: ok.fetchPurchase, db, now: NOW });
  assert.strictEqual(db.store[`iap/${tokenKey(TOKEN)}`].uid, "");
});
