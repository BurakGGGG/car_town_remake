// CİHAZ METRİKLERİ (2026-11-03) — saf mantık (index.js `deviceMetrics` callable'ına bağlar; test/devices.test.js sahte db
// ile sınar). Misafir oyuncunun Firebase kaydı yok: oyuncuların çoğu (~%62) hiçbir sayıma girmiyordu. Her cihaz (misafir ya
// da hesaplı) burada TEK belgedir: devices/d_{dev}. İlerlemenin kendisi tutulmaz, yalnız özet sayılar.
//
// dev  = ANDROID_ID'nin tuzlu SHA-256 özeti (oyunda DeviceMetrics.device_id; davet sisteminin özetinden AYRI tuz →
//        iki kayıt birbirine bağlanamaz). Yeniden kurulumda değişmez → bir telefon bir kez sayılır.
// UID YAZILMAZ: kullanım istatistikleri hesaba bağlanmaz (gizlilik politikası). Hesap türü (misafir / google / e-posta)
// kırılım için yazılır.
//
// Belge: {acct, lang, build, model, sdk, push, push_os, push_asked, push_race, push_gift, push_news, level, money, gems, cars,
//        garages, tut, play_s, sess, ads, iap, iap_usd_c, first_at, at, days, day, inst, seq}
//   ANLIK alanlar (son değer yazılır): hesap türü … tut.
//   SAYAÇLAR (artırılır): play_s oyun süresi sn, sess açılış, ads izlenen ödüllü reklam, iap satın alma, iap_usd_c liste
//   fiyatı (ABD senti, GemProducts.usd). İstemci FARKI yollar.
//   SUNUCU alanları: first_at ilk görülme, at son görülme (sn; cleanup.js 13 ay sonra siler), days farklı gün sayısı
//   (İstanbul günü), day son gün anahtarı.
//
// TEKRAR KORUMASI: istemci her gönderime (inst, seq) koyar. inst kurulum verisine özel rastgele kimlik (veriler silinince
// yenisi), seq her yeni gönderimde +1. Aynı inst'te seq <= kayıtlı seq ise SAYAÇLAR yeniden eklenmez (yanıtı kaybolup
// yeniden gönderilen istek iki kez sayılmaz); seq eşitse yalnız anlık alanlar tazelenir, küçükse (sırası karışmış eski
// istek) hiçbir şey yazılmaz.
//
// RIZA: oyuncu AYARLAR'da kullanım istatistiklerini kapatınca oyun {dev, forget: true} yollar → belge silinir.
// Oturum gerekmez (misafirin oturumu yok): kötüye kullanıma karşı sıkı alan doğrulaması + örnek başına IP'den saatlik yeni
// cihaz sınırı + maxInstances (index.js).

const DAY_S = 24 * 60 * 60;
const LANGS = ["tr", "en", "es", "de", "fr"];
const ACCOUNTS = ["guest", "google", "email", "facebook", "other"];
const HEX64 = /^[0-9a-f]{64}$/;
const HEX32 = /^[0-9a-f]{32}$/;
/** Bir örnekte bir IP'den saatte en çok bu kadar YENİ cihaz belgesi (operatör NAT'ı arkasında çok oyuncu olabilir). */
const MAX_NEW_PER_IP_HOUR = 60;

/** Anlık sayı alanları: [ad, en büyük]. */
const SNAP_INTS = [["build", 1_000_000], ["sdk", 100], ["level", 10_000], ["money", 1e12], ["gems", 1e9], ["cars", 10_000],
  ["garages", 100], ["tut", 100]];
const SNAP_BOOLS = ["push", "push_os", "push_asked", "push_race", "push_gift", "push_news"];
/** Sayaç farkları: [ad, tek gönderimde en çok]. */
const DELTAS = [["play_s", DAY_S], ["sess", 50], ["ads", 500], ["iap", 50], ["iap_usd_c", 500_000]];

class DeviceError extends Error {
  constructor(status, reason) {
    super(reason);
    this.status = status;
    this.reason = reason;
  }
}

/** İstanbul saatiyle gün anahtarı ("2026-11-03"); stats.js ile aynı. */
function dayKey(nowMs) {
  return new Date(nowMs + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function bad(field) {
  return new DeviceError("invalid-argument", `bad_${field}`);
}

function intIn(v, max) {
  return Number.isInteger(v) && v >= 0 && v <= max;
}

/** İstek gövdesini doğrular. Dönüş {dev, forget} ya da {dev, inst, seq, snap, deltas}; bozuksa DeviceError. */
function parseRequest(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) throw bad("body");
  const dev = data.dev;
  if (typeof dev !== "string" || !HEX64.test(dev)) throw bad("dev");
  if (data.forget === true) return { dev, forget: true };
  if (typeof data.inst !== "string" || !HEX32.test(data.inst)) throw bad("inst");
  if (!Number.isInteger(data.seq) || data.seq < 1 || data.seq > 1e9) throw bad("seq");
  const snap = {};
  if (!ACCOUNTS.includes(data.acct)) throw bad("acct");
  snap.acct = data.acct;
  if (!LANGS.includes(data.lang)) throw bad("lang");
  snap.lang = data.lang;
  if (typeof data.model !== "string" || data.model.length > 60) throw bad("model");
  snap.model = data.model.replace(/[^\x20-\x7e]/g, "?");
  for (const [name, max] of SNAP_INTS) {
    if (!intIn(data[name], max)) throw bad(name);
    snap[name] = data[name];
  }
  for (const name of SNAP_BOOLS) {
    if (typeof data[name] !== "boolean") throw bad(name);
    snap[name] = data[name];
  }
  const deltas = {};
  const d = data.d === undefined ? {} : data.d;
  if (!d || typeof d !== "object" || Array.isArray(d)) throw bad("d");
  for (const key of Object.keys(d)) {
    if (!DELTAS.some(([name]) => name === key)) throw bad("d");
  }
  for (const [name, max] of DELTAS) {
    const v = d[name] === undefined ? 0 : d[name];
    if (!intIn(v, max)) throw bad(name);
    deltas[name] = v;
  }
  return { dev, forget: false, inst: data.inst, seq: data.seq, snap, deltas };
}

/** Örnek içi IP sınırı (bellekte; örnek yeniden başlarsa sıfırlanır — kaba ama ücretsiz bir fren). */
const ipNew = new Map();

function ipAllowsNew(ip, nowMs) {
  if (!ip) return true;
  const since = nowMs - 60 * 60 * 1000;
  const list = (ipNew.get(ip) || []).filter((t) => t > since);
  if (list.length >= MAX_NEW_PER_IP_HOUR) {
    ipNew.set(ip, list);
    return false;
  }
  list.push(nowMs);
  ipNew.set(ip, list);
  if (ipNew.size > 5000) {
    for (const [key, times] of ipNew) if (!times.some((t) => t > since)) ipNew.delete(key);
  }
  return true;
}

/** Bir gönderimi işler. db: Firestore (yönetici); data: istek gövdesi; ip: istemci IP'si (yalnız bellekte sınır için);
 *  now: ms. Dönüş {ok: true, applied: "new"|"update"|"snapshot"|"stale"|"forgot"}. */
async function handleDeviceMetrics({ db, data, ip, now }) {
  const req = parseRequest(data);
  const ref = db.doc(`devices/d_${req.dev}`);
  if (req.forget) {
    await ref.delete();
    return { ok: true, applied: "forgot" };
  }
  const nowS = Math.floor(now / 1000);
  const today = dayKey(now);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const old = snap.exists ? snap.data() : null;
    if (old === null && !ipAllowsNew(ip, now)) throw new DeviceError("resource-exhausted", "too_many");
    const sameInst = old !== null && old.inst === req.inst;
    const oldSeq = sameInst && Number.isInteger(old.seq) ? old.seq : 0;
    if (sameInst && req.seq < oldSeq) return { ok: true, applied: "stale" };
    const fresh = !sameInst || req.seq > oldSeq;
    const doc = { ...req.snap, at: nowS, day: today, inst: req.inst, seq: req.seq };
    if (old === null) {
      doc.first_at = nowS;
      doc.days = 1;
      for (const [name] of DELTAS) doc[name] = req.deltas[name];
      tx.set(ref, doc);
      return { ok: true, applied: "new" };
    }
    if (old.day !== today) doc.days = (Number.isInteger(old.days) ? old.days : 0) + 1;
    if (fresh) {
      for (const [name] of DELTAS) doc[name] = (Number.isFinite(old[name]) ? old[name] : 0) + req.deltas[name];
    }
    tx.set(ref, doc, { merge: true });
    return { ok: true, applied: fresh ? "update" : "snapshot" };
  });
}

/** dailyStats için cihaz özeti (son 30 günde görülen belgeler okunur; select ile yalnız gereken alanlar).
 *  Dönüş {active_1d, active_7d, active_30d, new_1d, guest_7d, push_7d, push_guest_7d, push_os_off_7d}. */
async function deviceStats({ db, now }) {
  const nowS = Math.floor(now / 1000);
  const rows = await db.collection("devices").where("at", ">=", nowS - 30 * DAY_S)
    .select("at", "first_at", "acct", "push", "push_os").get();
  const out = { active_1d: 0, active_7d: 0, active_30d: 0, new_1d: 0, guest_7d: 0, push_7d: 0, push_guest_7d: 0,
    push_os_off_7d: 0 };
  for (const row of rows.docs) {
    const r = row.data();
    out.active_30d++;
    if (r.at >= nowS - DAY_S) out.active_1d++;
    if (r.first_at >= nowS - DAY_S) out.new_1d++;
    if (r.at < nowS - 7 * DAY_S) continue;
    out.active_7d++;
    const guest = r.acct === "guest";
    const pushOn = r.push === true && r.push_os !== false;
    if (guest) out.guest_7d++;
    if (pushOn) out.push_7d++;
    if (pushOn && guest) out.push_guest_7d++;
    if (r.push === true && r.push_os === false) out.push_os_off_7d++;
  }
  return out;
}

module.exports = { DAY_S, LANGS, ACCOUNTS, DELTAS, MAX_NEW_PER_IP_HOUR, DeviceError, dayKey, parseRequest, ipAllowsNew,
  handleDeviceMetrics, deviceStats, _ipNew: ipNew };
