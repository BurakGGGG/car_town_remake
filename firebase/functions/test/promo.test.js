// promo.js testi (internetsiz): sahte Firestore. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { handleRedeem, RATE_MAX } = require("../promo");

function fakeDb(initial = {}) {
  const store = JSON.parse(JSON.stringify(initial));
  const ref = (path) => ({
    path,
    async get() { return { exists: path in store, data: () => store[path] }; },
    async set(v, opts) { store[path] = opts && opts.merge ? { ...(store[path] || {}), ...v } : v; },
  });
  return {
    store,
    doc: ref,
    collection: (col) => ({
      where: (field, op, value) => {
        const query = (max) => ({
          limit: (n) => query(n),
          async get() {
            const docs = Object.keys(store).filter((p) => p.startsWith(col + "/") && !p.slice(col.length + 1).includes("/")
              && store[p][field] > value);
            return { size: Math.min(docs.length, max) };
          },
        });
        return query(Infinity);
      },
    }),
    async runTransaction(fn) {
      const writes = [];
      const t = {
        get: (r) => r.get(),
        set: (r, v) => writes.push([r.path, v, false]),
        update: (r, v) => writes.push([r.path, v, true]),
      };
      const out = await fn(t);
      for (const [p, v, merge] of writes) store[p] = merge ? { ...store[p], ...v } : v;
      return out;
    },
  };
}

const NOW = 1_800_000_000_000;
const NOW_S = NOW / 1000;
const promo = (over = {}) => ({ title: { tr: "Reels hediyesi" }, reward: { gems: 50, money: 1000, crates: { city_crate: 1 } },
  max_uses: 2, uses: 0, until: 0, active: true, ...over });
const redeem = (db, uid, code) => { db.store[`users/${uid}/redeem/${code}`] = { at: NOW_S }; return handleRedeem({ db, uid, code, now: NOW }); };

test("geçerli kod: ödül postası, kullanım +1, sonuç ok", async () => {
  const db = fakeDb({ "promo/REELS50": promo() });
  assert.equal(await redeem(db, "ali", "REELS50"), "ok");
  const mail = db.store["users/ali/mail/p_reels50"];
  assert.equal(mail.gems, 50);
  assert.deepEqual(mail.crates, { city_crate: 1 });
  assert.deepEqual(mail.title, { tr: "Reels hediyesi" });
  assert.equal(db.store["promo/REELS50"].uses, 1);
  assert.ok(db.store["promo/REELS50/used/ali"]);
  assert.equal(db.store["users/ali/redeem/REELS50"].status, "ok");
});

test("aynı hesap ikinci kez kullanamaz", async () => {
  const db = fakeDb({ "promo/REELS50": promo(), "promo/REELS50/used/ali": { at: 1 } });
  assert.equal(await redeem(db, "ali", "REELS50"), "already");
  assert.equal(db.store["promo/REELS50"].uses, 0);
  assert.equal("users/ali/mail/p_reels50" in db.store, false);
});

test("kullanım sınırı, süre, kapalı kod, olmayan kod", async () => {
  const db = fakeDb({ "promo/FULL": promo({ max_uses: 1, uses: 1 }), "promo/OLDCODE": promo({ until: NOW_S - 1 }),
    "promo/OFFCODE": promo({ active: false }), "promo/OPEN": promo({ max_uses: 0, uses: 999 }) });
  assert.equal(await redeem(db, "ali", "FULL"), "used_up");
  assert.equal(await redeem(db, "ali", "OLDCODE"), "expired");
  assert.equal(await redeem(db, "ali", "OFFCODE"), "inactive");
  assert.equal(await redeem(db, "ali", "NOPE"), "not_found");
  assert.equal(await redeem(db, "ali", "OPEN"), "ok", "max_uses 0 = sınırsız");
  assert.equal(await redeem(db, "ali", "bad-code"), "not_found", "biçimsiz kod");
});

test("iki oyuncu aynı kodu, sınır 2: üçüncüsü dolu", async () => {
  const db = fakeDb({ "promo/REELS50": promo() });
  assert.equal(await redeem(db, "ali", "REELS50"), "ok");
  assert.equal(await redeem(db, "veli", "REELS50"), "ok");
  assert.equal(await redeem(db, "ayse", "REELS50"), "used_up");
  assert.equal(db.store["promo/REELS50"].uses, 2);
});

test("kaba deneme sınırı: saatte en çok RATE_MAX kod", async () => {
  const init = { "promo/REELS50": promo() };
  for (let i = 0; i < RATE_MAX + 1; i++) init[`users/ali/redeem/TRY${i}`] = { at: NOW_S - 10 };
  const db = fakeDb(init);
  assert.equal(await redeem(db, "ali", "REELS50"), "rate");
  assert.equal("users/ali/mail/p_reels50" in db.store, false);
});

test("olay iki kez teslim edilirse ilk sonuç korunur (ikinci çalışma 'already' yazmaz)", async () => {
  const db = fakeDb({ "promo/REELS50": promo() });
  assert.equal(await redeem(db, "ali", "REELS50"), "ok");
  assert.equal(await handleRedeem({ db, uid: "ali", code: "REELS50", now: NOW }), "ok");
  assert.equal(db.store["users/ali/redeem/REELS50"].status, "ok");
  assert.equal(db.store["promo/REELS50"].uses, 1);
});
