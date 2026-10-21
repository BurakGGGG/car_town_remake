// stats.js testi (internetsiz). Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { dayKey, computeStats, writeDailyStats, DAY_S } = require("../stats");

const NOW = Date.parse("2026-10-21T21:30:00Z");   // İstanbul'da 22 Ekim 00:30
const NOW_S = NOW / 1000;

function fakeDb(players, pushCount) {
  const written = {};
  const query = (rows) => ({
    where: (field, op, value) => query(rows.filter((r) => r[field] >= value)),
    count: () => ({ get: async () => ({ data: () => ({ count: rows.length }) }) }),
  });
  return {
    written,
    collection: (name) => (name === "players" ? query(players) : query(Array(pushCount).fill({}))),
    doc: (path) => ({ set: async (v) => { written[path] = v; } }),
  };
}

const fakeAuth = (creations) => ({
  async listUsers(n, token) {
    const start = token ? Number(token) : 0;
    const users = creations.slice(start, start + 2).map((c) => ({ metadata: { creationTime: new Date(c).toUTCString() } }));
    return { users, pageToken: start + 2 < creations.length ? String(start + 2) : undefined };
  },
});

test("gün anahtarı İstanbul saatiyle", () => {
  assert.equal(dayKey(NOW), "2026-10-22");
  assert.equal(dayKey(Date.parse("2026-10-21T20:59:00Z")), "2026-10-21");
});

test("aktif oyuncu pencereleri, bildirim, yeni hesap (sayfalı)", async () => {
  const players = [{ updated_at: NOW_S - 100 }, { updated_at: NOW_S - 3 * DAY_S }, { updated_at: NOW_S - 20 * DAY_S }, { updated_at: NOW_S - 90 * DAY_S }];
  const auth = fakeAuth([NOW - 1000, NOW - 5000, NOW - 2 * DAY_S * 1000, NOW - 3600 * 1000, NOW - 40 * DAY_S * 1000]);
  const s = await computeStats({ db: fakeDb(players, 2), auth, now: NOW });
  assert.deepEqual({ ...s, at: 0 }, { players: 4, active_1d: 1, active_7d: 2, active_30d: 3, push: 2, new_1d: 3, at: 0 });
});

test("gece işi biten günün belgesini yazar", async () => {
  const db = fakeDb([], 0);
  const { day } = await writeDailyStats({ db, auth: fakeAuth([]), now: Date.parse("2026-10-22T00:10:00Z") });   // İst. 03:10
  assert.equal(day, "2026-10-21");
  assert.equal(db.written["stats_daily/2026-10-21"].players, 0);
});
