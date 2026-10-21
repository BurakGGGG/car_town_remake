// GÜNLÜK İSTATİSTİK — saf mantık (index.js gece zamanlayıcısına bağlar, yönetim paneli de anlık hesap için kullanır;
// test/stats.test.js sahte db / auth ile sınar). stats_daily/{YYYY-MM-DD} (İstanbul günü) = {players, active_1d, active_7d,
// active_30d, push, new_1d, at}. Yalnızca HESAPLI oyuncular sayılır (misafirin Firebase kaydı yok): players.updated_at son
// bulut yazması = son oynama. Sayımlar Firestore count() ile (belge okumaz, binde bir okuma ücreti).

const DAY_S = 24 * 60 * 60;

/** İstanbul saatiyle gün anahtarı ("2026-10-21"). */
function dayKey(nowMs) {
  return new Date(nowMs + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

async function countOf(query) {
  return (await query.count().get()).data().count;
}

/** Son 24 saatte açılan Firebase hesabı sayısı (Auth sayfa sayfa listelenir). */
async function newAccounts(auth, nowMs, sinceMs) {
  let total = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const u of page.users) {
      const created = Date.parse(u.metadata && u.metadata.creationTime);
      if (created >= sinceMs && created <= nowMs) total++;
    }
    pageToken = page.pageToken;
  } while (pageToken);
  return total;
}

/** O anın sayıları. db: Firestore (yönetici) benzeri; auth: {listUsers(n, token)}. */
async function computeStats({ db, auth, now }) {
  const nowS = Math.floor(now / 1000);
  const players = db.collection("players");
  return {
    players: await countOf(players),
    active_1d: await countOf(players.where("updated_at", ">=", nowS - DAY_S)),
    active_7d: await countOf(players.where("updated_at", ">=", nowS - 7 * DAY_S)),
    active_30d: await countOf(players.where("updated_at", ">=", nowS - 30 * DAY_S)),
    push: await countOf(db.collection("push")),
    new_1d: await newAccounts(auth, now, now - DAY_S * 1000),
    at: nowS,
  };
}

/** Gece işi (03:10): geçen 24 saat BİTEN günün belgesine yazılır (6 saat geriye bakılır), yeniden çalışırsa üzerine yazar.
 *  Dönüş: {day, stats}. */
async function writeDailyStats({ db, auth, now }) {
  const stats = await computeStats({ db, auth, now });
  const day = dayKey(now - 6 * 60 * 60 * 1000);
  await db.doc(`stats_daily/${day}`).set(stats);
  return { day, stats };
}

module.exports = { DAY_S, dayKey, computeStats, writeDailyStats };
