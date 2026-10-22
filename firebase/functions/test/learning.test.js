// learning.js testi (internetsiz). Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { dayNumber, parseEvents, aggregateDay, writeLearning, pruneLogs, MAX_EVENTS, KEEP_DAYS, PER_PLAYER_CELL } = require("../learning");

const NOW = Date.parse("2026-10-22T01:00:00Z");
const TODAY = dayNumber(NOW);

/** Sahte Firestore: koleksiyon → [{id, data}]; where("day", op, değer)[.limit(n)].get(); doc(yol).set(veri, seçenek). */
function fakeDb(collections) {
  const written = {};
  const ops = { "==": (a, b) => a === b, ">=": (a, b) => a >= b, "<": (a, b) => a < b };
  const docOf = (name, row) => ({
    id: row.id,
    get: (k) => row.data[k],
    ref: { delete: async () => { collections[name] = collections[name].filter((r) => r !== row); } },
  });
  const query = (name, field, op, value, limit) => ({
    limit: (n) => query(name, field, op, value, n),
    get: async () => ({
      docs: (collections[name] || []).filter((r) => ops[op](r.data[field], value)).slice(0, limit ?? Infinity).map((r) => docOf(name, r)),
    }),
  });
  return {
    written,
    collections,
    collection: (name) => ({ where: (field, op, value) => query(name, field, op, value) }),
    doc: (path) => ({
      set: async (data, opts) => {
        written[path] = { data, merge: Boolean(opts && opts.merge) };
        const [name, id] = path.split("/");
        if (name === "race_learning_daily") {
          collections[name] = (collections[name] || []).filter((r) => r.id !== id).concat([{ id, data }]);
        }
      },
    }),
  };
}

/** Olay; zamanı `day` gününün içinde (toplama başka güne düşen olayı saymaz). */
const ev = (c, a, s, extra = {}, day = TODAY - 1) => ({ t: day * 86400 + 600, c, a, p: 0.5, w: true, s, d: 300, n: false, ...extra });

test("gün numarası UTC", () => {
  assert.equal(dayNumber(Date.parse("2026-10-22T00:00:00Z")) - dayNumber(Date.parse("2026-10-21T23:59:59Z")), 1);
});

test("bozuk / bilinmeyen olaylar sayılmaz", () => {
  assert.deepEqual(parseEvents("bozuk{"), []);
  assert.deepEqual(parseEvents(JSON.stringify({ c: "WW" })), []);
  const ok = parseEvents(JSON.stringify([ev("WW", 1, true), ev("XX", 1, true), ev("LL", 3, true), ev("LL", 0, "evet"), ev("new", -1, true)]));
  assert.equal(ok.length, 1);
  assert.equal(parseEvents(JSON.stringify(Array(MAX_EVENTS + 50).fill(ev("WL", 2, false)))).length, MAX_EVENTS);
});

test("günün olayları bağlam × kol başına toplanır", async () => {
  const db = fakeDb({
    race_log: [
      { id: "a_1", data: { day: TODAY - 1, events: JSON.stringify([ev("LL", 0, true), ev("LL", 0, false), ev("WW", 2, true)]) } },
      { id: "b_1", data: { day: TODAY - 1, events: JSON.stringify([ev("LL", 0, true)]) } },
      { id: "c_1", data: { day: TODAY - 5, events: JSON.stringify([ev("LL", 0, true)]) } },
    ],
  });
  const out = await aggregateDay({ db, day: TODAY - 1, now: NOW });
  assert.deepEqual(out.table.LL["0"], { s: 2, n: 3 });
  assert.deepEqual(out.table.WW["2"], { s: 1, n: 1 });
  assert.equal(out.events, 4);
  assert.equal(out.players, 2);
  assert.ok(db.written[`race_learning_daily/${TODAY - 1}`]);
});

test("gece işi: son günlerin toplamı config/race_learning'e MERGE ile", async () => {
  const db = fakeDb({
    race_log: [
      { id: "a_1", data: { day: TODAY - 1, events: JSON.stringify([ev("WL", 1, true), ev("WL", 1, false)]) } },
      { id: "a_2", data: { day: TODAY - 2, events: JSON.stringify([ev("WL", 1, true, {}, TODAY - 2)]) } },
    ],
    race_learning_daily: [
      { id: String(TODAY - 10), data: { day: TODAY - 10, events: 5, table: { WL: { 1: { s: 4, n: 5 } } } } },
      { id: String(TODAY - 40), data: { day: TODAY - 40, events: 9, table: { WL: { 1: { s: 9, n: 9 } } } } },
    ],
  });
  const result = await writeLearning({ db, now: NOW });
  const doc = db.written["config/race_learning"];
  assert.ok(doc.merge, "paneldeki off / window alanları korunur");
  assert.deepEqual(doc.data.table.WL["1"], { s: 6, n: 8 });   // dün 1/2 + önceki gün 1/1 + 10 gün önce 4/5; 40 gün önce dışarıda
  assert.deepEqual(result, { days: 3, events: 8, pruned: 0 });
});

test("saklama: KEEP_DAYS günden eski ham günlük silinir, yenisi ve kimliksiz özet kalır", async () => {
  const old = Array.from({ length: 450 }, (_, i) => ({ id: `u${i}_1`, data: { day: TODAY - KEEP_DAYS - 1 - (i % 3), events: "[]" } }));
  const db = fakeDb({
    race_log: [...old, { id: "a_keep", data: { day: TODAY - KEEP_DAYS, events: "[]" } }, { id: "b_keep", data: { day: TODAY - 1, events: "[]" } }],
    race_learning_daily: [{ id: "1", data: { day: 1, events: 3, table: {} } }],
  });
  assert.equal(await pruneLogs({ db, now: NOW }), 450, "400'lük sayfalarla hepsi");
  assert.deepEqual(db.collections.race_log.map((r) => r.id).sort(), ["a_keep", "b_keep"]);
  assert.equal(db.collections.race_learning_daily.length, 1, "kimliksiz özet silinmez");
});

test("tek oyuncunun uydurma olayları tabloyu ele geçiremez: hücre başına tavan, başka güne düşen olay sayılmaz", async () => {
  const forged = Array(MAX_EVENTS).fill(ev("new", 0, true));
  const db = fakeDb({
    race_log: [
      { id: "mallory_1", data: { day: TODAY - 1, events: JSON.stringify(forged.concat([ev("LL", 2, true, { t: 5 })])) } },
      { id: "ali_1", data: { day: TODAY - 1, events: JSON.stringify([ev("new", 0, false), ev("new", 0, false)]) } },
    ],
  });
  const out = await aggregateDay({ db, day: TODAY - 1, now: NOW });
  assert.deepEqual(out.table.new["0"], { s: PER_PLAYER_CELL, n: PER_PLAYER_CELL + 2 });
  assert.deepEqual(out.table.LL["2"], { s: 0, n: 0 }, "zamanı 1970'e düşen olay");
  assert.equal(out.events, PER_PLAYER_CELL + 2);
});
