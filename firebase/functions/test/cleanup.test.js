// cleanup.js testi (internetsiz): sahte Firestore. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { cleanupExpired, cutoffFor, RULES } = require("../cleanup");

function fakeDb(store) {
  return {
    store,
    collection(name) {
      const q = { field: null, value: null, n: Infinity };
      const api = {
        where(field, op, value) { assert.strictEqual(op, "<"); q.field = field; q.value = value; return api; },
        limit(n) { q.n = n; return api; },
        async get() {
          const docs = Object.keys(store)
            .filter((p) => p.startsWith(name + "/") && store[p][q.field] < q.value)
            .slice(0, q.n)
            .map((p) => ({ ref: { path: p } }));
          return { docs, size: docs.length, empty: docs.length === 0 };
        },
      };
      return api;
    },
    batch() {
      const dels = [];
      return { delete: (ref) => dels.push(ref.path), async commit() { for (const p of dels) delete store[p]; } };
    },
  };
}

const NOW = Date.UTC(2026, 9, 17, 12, 0, 0);
const S = Math.floor(NOW / 1000);

test("süresi dolanlar silinir, geçerliler kalır", async () => {
  const db = fakeDb({
    "invites/ESKI00000000": { uid: "a", at: S - 3601 },
    "invites/YENI00000000": { uid: "a", at: S - 60 },
    "push_log/l_b_a": { at: NOW - 25 * 3600 * 1000 },
    "push_log/l_c_a": { at: NOW - 5 * 3600 * 1000 },
    "reports/x_a_b": { target: "b", at: S - 181 * 86400 },
    "reports/x_a_c": { target: "c", at: S - 10 * 86400 },
    "garages/g_a": { at: 0 },
    "email_codes/eski": { hash: "", at: NOW - 61 * 60 * 1000 },
    "email_codes/yeni": { hash: "h", at: NOW - 5 * 60 * 1000 },
    "email_ips/eski": { at: NOW - 2 * 3600 * 1000 },
    "email_ips/yeni": { at: NOW - 59 * 60 * 1000 },
  });
  const deleted = await cleanupExpired({ db, now: NOW });
  assert.deepStrictEqual(deleted, { invites: 1, push_log: 1, reports: 1, email_codes: 1, email_ips: 1 });
  assert.deepStrictEqual(Object.keys(db.store).sort(), ["email_codes/yeni", "email_ips/yeni", "garages/g_a",
    "invites/YENI00000000", "push_log/l_c_a", "reports/x_a_c"]);
});

test("birim: push_log ve e-posta kodları milisaniye, diğerleri saniye", () => {
  const byName = Object.fromEntries(RULES.map((r) => [r.collection, r]));
  assert.strictEqual(cutoffFor(byName.push_log, NOW), NOW - 86400 * 1000);
  assert.strictEqual(cutoffFor(byName.invites, NOW), S - 3600);
  assert.strictEqual(cutoffFor(byName.reports, NOW), S - 180 * 86400);
  assert.strictEqual(cutoffFor(byName.email_codes, NOW), NOW - 3600 * 1000);
  assert.strictEqual(cutoffFor(byName.email_ips, NOW), NOW - 3600 * 1000);
});

test("çok sayıda belge parti parti silinir", async () => {
  const store = {};
  for (let i = 0; i < 950; i++) store[`invites/T${String(i).padStart(11, "0")}`] = { at: S - 7200 };
  const deleted = await cleanupExpired({ db: fakeDb(store), now: NOW });
  assert.strictEqual(deleted.invites, 950);
  assert.strictEqual(Object.keys(store).length, 0);
});
