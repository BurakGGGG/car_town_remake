// devices.js testi (internetsiz). Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { handleDeviceMetrics, parseRequest, deviceStats, ipAllowsNew, MAX_NEW_PER_IP_HOUR, DAY_S, _ipNew } = require("../devices");

const NOW = Date.parse("2026-11-03T10:00:00Z");   // İstanbul 13:00
const NOW_S = NOW / 1000;
const DEV = "a".repeat(64);
const INST = "b".repeat(32);

function fakeDb(initial = {}) {
  const docs = { ...initial };
  const ref = (path) => ({ path });
  const db = {
    docs,
    doc: (path) => ({ ...ref(path), delete: async () => { delete docs[path]; } }),
    runTransaction: async (fn) => fn({
      get: async (r) => ({ exists: r.path in docs, data: () => ({ ...docs[r.path] }) }),
      set: (r, v, opt) => { docs[r.path] = opt && opt.merge ? { ...(docs[r.path] || {}), ...v } : { ...v }; },
    }),
    collection: (name) => {
      const rows = Object.entries(docs).filter(([p]) => p.startsWith(name + "/")).map(([, v]) => v);
      const query = (list) => ({
        where: (field, op, value) => query(list.filter((r) => r[field] >= value)),
        select: () => query(list),
        get: async () => ({ docs: list.map((r) => ({ data: () => r })) }),
      });
      return query(rows);
    },
  };
  return db;
}

function body(extra = {}) {
  return { dev: DEV, inst: INST, seq: 1, acct: "guest", lang: "tr", model: "SM-A245F", build: 17, sdk: 34, level: 4,
    money: 12000, gems: 80, cars: 2, garages: 1, tut: 2, push: false, push_os: true, push_asked: true, push_race: true,
    push_gift: true, push_news: true, d: { play_s: 300, sess: 1 }, ...extra };
}

test("doğrulama: bozuk alanlar reddedilir", () => {
  assert.throws(() => parseRequest(null), /bad_body/);
  assert.throws(() => parseRequest(body({ dev: "XYZ" })), /bad_dev/);
  assert.throws(() => parseRequest(body({ inst: "kısa" })), /bad_inst/);
  assert.throws(() => parseRequest(body({ seq: 0 })), /bad_seq/);
  assert.throws(() => parseRequest(body({ acct: "admin" })), /bad_acct/);
  assert.throws(() => parseRequest(body({ lang: "ru" })), /bad_lang/);
  assert.throws(() => parseRequest(body({ level: -1 })), /bad_level/);
  assert.throws(() => parseRequest(body({ push: "evet" })), /bad_push/);
  assert.throws(() => parseRequest(body({ model: "x".repeat(61) })), /bad_model/);
  assert.throws(() => parseRequest(body({ d: { play_s: DAY_S + 1 } })), /bad_play_s/);
  assert.throws(() => parseRequest(body({ d: { hack: 1 } })), /bad_d/);
  assert.throws(() => parseRequest(body({ d: [] })), /bad_d/);
  assert.throws(() => parseRequest(body({ uid: undefined, level: 1.5 })), /bad_level/);
  // forget yalnız dev ister
  assert.deepEqual(parseRequest({ dev: DEV, forget: true }), { dev: DEV, forget: true });
  // fazladan alan (ör. uid) belgeye geçmez
  const p = parseRequest(body({ uid: "abc" }));
  assert.equal("uid" in p.snap, false);
});

test("ilk gönderim belge kurar, aynı seq tekrar gelince sayaçlar iki kez eklenmez", async () => {
  _ipNew.clear();
  const db = fakeDb();
  const path = `devices/d_${DEV}`;
  assert.equal((await handleDeviceMetrics({ db, data: body(), ip: "1.1.1.1", now: NOW })).applied, "new");
  let d = db.docs[path];
  assert.equal(d.first_at, NOW_S);
  assert.equal(d.at, NOW_S);
  assert.equal(d.days, 1);
  assert.equal(d.play_s, 300);
  assert.equal(d.sess, 1);
  assert.equal(d.ads, 0);
  assert.equal(d.acct, "guest");
  assert.equal("uid" in d, false);
  // yanıtı kaybolan istek yeniden: anlık alan tazelenir, sayaç aynı
  const again = await handleDeviceMetrics({ db, data: body({ level: 5 }), ip: "1.1.1.1", now: NOW + 5000 });
  assert.equal(again.applied, "snapshot");
  d = db.docs[path];
  assert.equal(d.play_s, 300);
  assert.equal(d.sess, 1);
  assert.equal(d.level, 5);
  // yeni seq: sayaç eklenir
  await handleDeviceMetrics({ db, data: body({ seq: 2, d: { play_s: 60, ads: 1, iap: 1, iap_usd_c: 199 } }), ip: "", now: NOW + 9000 });
  d = db.docs[path];
  assert.deepEqual([d.play_s, d.sess, d.ads, d.iap, d.iap_usd_c, d.seq], [360, 1, 1, 1, 199, 2]);
  // sırası karışmış eski istek hiçbir şey yazmaz
  const stale = await handleDeviceMetrics({ db, data: body({ seq: 1, level: 1, d: { play_s: 999 } }), ip: "", now: NOW + 10000 });
  assert.equal(stale.applied, "stale");
  assert.equal(db.docs[path].play_s, 360);
  assert.equal(db.docs[path].level, 4);   // seq 2 seviye 4 yazdı, eski istek 1 yazmadı
});

test("veriler silinince (yeni inst) seq baştan başlar, sayaçlar birikmeye devam eder; gün sayısı", async () => {
  _ipNew.clear();
  const db = fakeDb();
  const path = `devices/d_${DEV}`;
  await handleDeviceMetrics({ db, data: body({ seq: 7 }), ip: "", now: NOW });
  await handleDeviceMetrics({ db, data: body({ inst: "c".repeat(32), seq: 1, d: { play_s: 100, sess: 1 } }), ip: "",
    now: NOW + DAY_S * 1000 });
  const d = db.docs[path];
  assert.deepEqual([d.play_s, d.sess, d.seq, d.inst, d.days, d.first_at], [400, 2, 1, "c".repeat(32), 2, NOW_S]);
  // aynı gün yeniden: gün sayısı artmaz
  await handleDeviceMetrics({ db, data: body({ inst: "c".repeat(32), seq: 2 }), ip: "", now: NOW + DAY_S * 1000 + 60000 });
  assert.equal(db.docs[path].days, 2);
});

test("forget belgeyi siler", async () => {
  const db = fakeDb({ [`devices/d_${DEV}`]: { at: NOW_S } });
  assert.equal((await handleDeviceMetrics({ db, data: { dev: DEV, forget: true }, ip: "", now: NOW })).applied, "forgot");
  assert.equal(`devices/d_${DEV}` in db.docs, false);
});

test("IP başına saatlik yeni cihaz sınırı (var olan cihaz etkilenmez)", async () => {
  _ipNew.clear();
  for (let i = 0; i < MAX_NEW_PER_IP_HOUR; i++) assert.equal(ipAllowsNew("9.9.9.9", NOW + i), true);
  assert.equal(ipAllowsNew("9.9.9.9", NOW + 100), false);
  assert.equal(ipAllowsNew("8.8.8.8", NOW + 100), true);
  assert.equal(ipAllowsNew("9.9.9.9", NOW + 61 * 60 * 1000), true);   // bir saat sonra açılır
  _ipNew.clear();
  for (let i = 0; i < MAX_NEW_PER_IP_HOUR; i++) ipAllowsNew("7.7.7.7", NOW);
  const db = fakeDb({ [`devices/d_${DEV}`]: { inst: INST, seq: 1, day: "2026-11-03", days: 1, play_s: 0 } });
  await assert.rejects(handleDeviceMetrics({ db, data: body({ dev: "d".repeat(64) }), ip: "7.7.7.7", now: NOW }), /too_many/);
  assert.equal((await handleDeviceMetrics({ db, data: body({ seq: 2 }), ip: "7.7.7.7", now: NOW })).applied, "update");
});

test("gecelik cihaz özeti: misafir, bildirim, telefon izni kapalı", async () => {
  const row = (id, v) => [`devices/d_${id}`, v];
  const db = fakeDb(Object.fromEntries([
    row(1, { at: NOW_S - 100, first_at: NOW_S - 200, acct: "guest", push: true, push_os: true }),
    row(2, { at: NOW_S - 2 * DAY_S, first_at: NOW_S - 9 * DAY_S, acct: "google", push: true, push_os: true }),
    row(3, { at: NOW_S - 3 * DAY_S, first_at: NOW_S - 9 * DAY_S, acct: "guest", push: true, push_os: false }),
    row(4, { at: NOW_S - 10 * DAY_S, first_at: NOW_S - 20 * DAY_S, acct: "guest", push: false, push_os: true }),
    row(5, { at: NOW_S - 40 * DAY_S, first_at: NOW_S - 50 * DAY_S, acct: "guest", push: false, push_os: true }),
  ]));
  assert.deepEqual(await deviceStats({ db, now: NOW }), { active_1d: 1, active_7d: 3, active_30d: 4, new_1d: 1, guest_7d: 2,
    push_7d: 2, push_guest_7d: 1, push_os_off_7d: 1 });
});
