// YARIŞ ÖĞRENMESİ — saf mantık (index.js gece zamanlayıcısına bağlar; test/learning.test.js sahte db ile sınar).
// Tasarım: docs/KOSU_ESLESTIRME.md "Faz 2". Oyun her yarışın sonucunu ve oyuncunun yarıştan SONRA oyunda kalıp
// kalmadığını günlük belgeye yazar (yalnızca hesapla giren oyuncular; kural: firestore.rules race_log):
//   race_log/{uid}_{gün} = {uid, day (UTC gün numarası), events (JSON metni), n, v, at}
//   events: [{t, c (bağlam: new / WW / WL / LW / LL), a (kol: 0 kolay, 1 dengeli, 2 zor; -1 ilk yarış), p (şans), w (kazandı),
//             s (kaldı), d (sn), n (sıradaki yarış), pc, pt, rc, rt, o (f arkadaş / e Emre-Elif / n isimsiz), lv}]
// Gece: dünün ve önceki günün belgeleri (geç gelen yazmalar için iki gün) bağlam × kol başına toplanır →
// race_learning_daily/{gün}; son DAYS günün toplamı config/race_learning'e MERGE ile yazılır (paneldeki off / window /
// weight alanları korunur). Oyun bu tabloyu öğrenmenin önseli olarak okur (AppConfig, oturumsuz).
// SAKLAMA (karar 2026-10-22): ham günlük KEEP_DAYS (180) gün, sonra gece silinir (oyuncuya bağlı veri; sitedeki gizlilik
// metninde yazılı). Kimliksiz günlük özetler (race_learning_daily, config/race_learning) süresiz kalır.

const CONTEXTS = ["new", "WW", "WL", "LW", "LL"];
const ARMS = 3;
const DAYS = 30;
const DAY_MS = 24 * 60 * 60 * 1000;
/** Ham günlüğün saklama süresi (gün) ve bir gecede en çok silinen belge (kalan sonraki geceye). */
const KEEP_DAYS = 180;
const PRUNE_MAX = 5000;
/** Bir belgeden en çok bu kadar olay sayılır (elle şişirilmiş belge tabloyu ele geçirmesin). */
const MAX_EVENTS = 500;
/** Bir oyuncunun bir günde bir hücreye (bağlam × kol) en çok katkısı. Günlüğü oyuncu yazar: tek hesap uydurma olaylarla
 *  (günde 500) tabloyu ele geçirmesin (güvenlik kontrolü 2026-10-22). Gerçek oyuncu bir günde aynı bağlam ve kolda
 *  nadiren bundan çok yarışır; fazlası sayılmaz. */
const PER_PLAYER_CELL = 10;

/** UTC gün numarası (1970-01-01 = 0): kural da aynı sayıyla karşılaştırır. */
function dayNumber(ms) {
  return Math.floor(ms / DAY_MS);
}

function emptyTable() {
  const table = {};
  for (const c of CONTEXTS) {
    table[c] = {};
    for (let a = 0; a < ARMS; a++) table[c][String(a)] = { s: 0, n: 0 };
  }
  return table;
}

/** Belgedeki olaylardan sayılabilenler: bağlam bilinen, kol 0..2, kaldı bilgisi bool; `day` verilirse olayın zamanı (t,
 *  unix sn) o güne düşmeli. Bozuk metin → boş. */
function parseEvents(text, day) {
  let raw;
  try {
    raw = JSON.parse(String(text || "[]"));
  } catch {
    return [];
  }
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, MAX_EVENTS).filter((e) => e && CONTEXTS.includes(e.c) && Number.isInteger(e.a)
    && e.a >= 0 && e.a < ARMS && typeof e.s === "boolean"
    && (day === undefined || (Number.isInteger(e.t) && dayNumber(e.t * 1000) === day)));
}

function addInto(table, other) {
  for (const c of CONTEXTS) {
    for (let a = 0; a < ARMS; a++) {
      const cell = (other[c] || {})[String(a)] || {};
      table[c][String(a)].s += Number(cell.s) || 0;
      table[c][String(a)].n += Number(cell.n) || 0;
    }
  }
  return table;
}

/** Bir günün günlüklerini toplar ve race_learning_daily/{gün}'e yazar. Dönüş: yazılan belge. */
async function aggregateDay({ db, day, now }) {
  const snap = await db.collection("race_log").where("day", "==", day).get();
  const table = emptyTable();
  let events = 0;
  for (const doc of snap.docs) {
    const mine = {};   // bu oyuncunun hücre başına sayılan olayı
    for (const e of parseEvents(doc.get("events"), day)) {
      const key = `${e.c}:${e.a}`;
      mine[key] = (mine[key] || 0) + 1;
      if (mine[key] > PER_PLAYER_CELL) continue;
      const cell = table[e.c][String(e.a)];
      cell.n++;
      if (e.s) cell.s++;
      events++;
    }
  }
  const out = { day, table, events, players: snap.docs.length, at: Math.floor(now / 1000) };
  await db.doc(`race_learning_daily/${day}`).set(out);
  return out;
}

/** KEEP_DAYS günden eski ham günlükleri siler (gecede en çok PRUNE_MAX). Dönüş: silinen sayısı. */
async function pruneLogs({ db, now }) {
  const before = dayNumber(now) - KEEP_DAYS;
  let deleted = 0;
  while (deleted < PRUNE_MAX) {
    const snap = await db.collection("race_log").where("day", "<", before).limit(400).get();
    if (snap.docs.length === 0) break;
    for (const doc of snap.docs) await doc.ref.delete();
    deleted += snap.docs.length;
  }
  return deleted;
}

/** Gece işi: son iki günü toplar, son DAYS günün toplamını config/race_learning'e yazar, eski ham günlüğü siler.
 *  Dönüş: {days, events, pruned}. */
async function writeLearning({ db, now }) {
  const today = dayNumber(now);
  for (const day of [today - 1, today - 2]) {
    await aggregateDay({ db, day, now });
  }
  const snap = await db.collection("race_learning_daily").where("day", ">=", today - DAYS).get();
  const table = emptyTable();
  let events = 0;
  let days = 0;
  for (const doc of snap.docs) {
    addInto(table, doc.get("table") || {});
    events += Number(doc.get("events")) || 0;
    days++;
  }
  await db.doc("config/race_learning").set({ table, events, days, at: Math.floor(now / 1000) }, { merge: true });
  return { days, events, pruned: await pruneLogs({ db, now }) };
}

module.exports = { CONTEXTS, ARMS, DAYS, KEEP_DAYS, MAX_EVENTS, PER_PLAYER_CELL, dayNumber, emptyTable, parseEvents, aggregateDay, pruneLogs,
  writeLearning };
