// HABERLER: bildirim + yayın belgesi — saf mantık (index.js tetikleyicilere bağlar; test/news_feed.test.js sahte db / messaging
// ile sınar; yönetim paneli buildNewsFeed'i admin/lib.mjs üzerinden aynen kullanır).
//
// news/{id} = bir haber (bildirim durumu dahil); YALNIZCA SUNUCUNUNDUR (firebase/admin yazar, buildNewsPost; istemci okuyamaz).
// OYUN koleksiyonu okumaz: tek belge config/news = {items, at} okur (oturumsuz Firestore REST, config kuralı). Okuma maliyeti
// oyuncu başına tek belge; koleksiyon herkese açık listelenseydi her yoklama haber sayısı kadar okuma olurdu.
//   buildNewsFeed   bitmemiş haberler (başlamamışlar DAHİL: oyun start'ı kendisi süzer), at'e göre yeniden eskiye, en çok 40,
//                   yalnız herkese açık alanlar (notify / pushed_at yok). Panel her kaydet / sil / en üste taşı işleminde haberle
//                   AYNI İŞLEMDE yazar (yayın koleksiyondan sapamaz).
//   refreshFeed     newsPushScheduled her 10 dakikada config/news'i okur (1 okuma); içinde bitişi geçmiş haber varsa yayını
//                   koleksiyondan yeniden kurar. Kimse dokunmasa da biten haber en geç 10 dakikada yayından düşer.
//
// BİLDİRİM:
// Belgede notify: true ise haber GÖRÜNÜR olunca (start ≤ şimdi, end 0 ya da ileride) dil konularına (news_<dil>, misafir de
// abone) BİR KEZ telefon bildirimi gider; gönderilince pushed_at (unix sn) yazılır.
//   newsPush            belge yazılınca (panel kaydı): hemen görünür haber anında gider
//   newsPushScheduled   10 dakikada bir: başlangıcı ileri bir saate kurulmuş haberler (zamanlı yayın) + başarısız denemeler
// İki tetik aynı anda gelse de bildirim bir kez gider: pushed_at İŞLEM içinde okunup yazılır (gönderimden ÖNCE ayrılır).
// Hiçbir dile gidemezse pushed_at 0'a döner ve zamanlayıcı yeniden dener. Yalnız pushed_at'i değişen yazma (bu modülün
// kendi kaydı) tetikte yok sayılır: başarısız gönderimden sonra geri alma yazması tetiği döngüye sokmaz.
//
// İleti (dil başına): başlık = haber başlığı, metin = haber metninin ilk ~120 karakteri (satır sonları boşluk). Başlık
// bildirimde zaten kalın görünür, metin özeti dokunmaya değer olup olmadığını söyler; "AUTO YARD" başlığı yalnız başlık
// boşsa (o zaman metin = başlık ya da özet). Dil yoksa en, o da yoksa tr (oyundaki haber kutusuyla aynı geri düşüş).
// Seviye / sürüm hedefli habere bildirim GİTMEZ ("targeted"): konu bildirimi bu hedefleri süzemez (panel de izin vermez).

const { pick } = require("./mail");

const LANGS = ["tr", "en", "es", "de", "fr"];
const BODY_MAX = 120;
const TITLE_MAX = 60;

const oneLine = (s) => String(s || "").replace(/\s+/g, " ").trim();

/** Metin özeti: en çok `max` karakter (kod noktası), sözcük ortasında kesmez, kısaltılınca "…". */
function excerpt(text, max = BODY_MAX) {
  const chars = [...oneLine(text)];
  if (chars.length <= max) return chars.join("");
  let cut = chars.slice(0, max - 1).join("");
  const space = cut.lastIndexOf(" ");
  if (space > max * 0.6) cut = cut.slice(0, space);
  return cut.replace(/[\s.,;:!?…-]+$/, "") + "…";
}

/** Seviye / sürüm hedefi var mı. */
function targeted(target) {
  const t = target && typeof target === "object" ? target : {};
  return !!(t.min_level || t.max_level || t.min_code || t.max_code);
}

/** Bildirimin gideceği diller: target.langs boşsa hepsi. */
function topicLangs(target) {
  const langs = target && Array.isArray(target.langs) ? target.langs : [];
  return langs.length ? LANGS.filter((l) => langs.includes(l)) : LANGS;
}

/** Her dil konusuna gidecek ileti (başlık / metin boş kalan dil atlanır). */
function messagesFor(id, item) {
  const out = [];
  for (const lang of topicLangs(item.target)) {
    const title = [...oneLine(pick(item.title, lang))].slice(0, TITLE_MAX).join("");
    const body = excerpt(pick(item.text, lang));
    if (!title && !body) continue;
    out.push({
      topic: `news_${lang}`,
      notification: title && body ? { title, body } : { title: "AUTO YARD", body: title || body },
      // Durum çubuğu ikonu ve vurgu rengi öbür bildirimlerle aynı; tag "news": yeni haber bildirimi eskisinin yerine geçer
      android: { priority: "high", notification: { tag: "news", icon: "icon_monochrome", color: "#F5BE4C" } },
      // FCM ayrılmış anahtarları ("from", "message_type", "google." / "gcm.") kullanma: news.js notu. Değerler metin olmalı.
      data: { type: "news", id: String(id) },
    });
  }
  return out;
}

/**
 * Haber şu an bildirim doğurur mu: "ready" ya da neden gitmediği — "missing" | "no-notify" | "already" | "targeted" |
 * "scheduled" (başlangıç ileride) | "ended" | "empty". nowS: unix sn.
 */
function pushState(item, nowS, id = "") {
  if (!item) return "missing";
  if (item.notify !== true) return "no-notify";
  if (Number(item.pushed_at) > 0) return "already";
  if (targeted(item.target)) return "targeted";
  const start = Number(item.start) || 0;
  const end = Number(item.end) || 0;
  if (start > nowS) return "scheduled";
  if (end && end <= nowS) return "ended";
  if (!messagesFor(id, item).length) return "empty";
  return "ready";
}

/** pushed_at dışında iki belge aynı mı (anahtar sırasından bağımsız). */
function sameExceptPushedAt(a, b) {
  const strip = (o) => {
    const { pushed_at: _p, ...rest } = o || {};
    return rest;
  };
  return deepEqual(strip(a), strip(b));
}

function deepEqual(a, b) {
  if (a === b) return true;
  if (typeof a !== "object" || typeof b !== "object" || a === null || b === null) return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => Object.hasOwn(b, k) && deepEqual(a[k], b[k]));
}

/**
 * Tek haberin bildirimini gönderir. Dönüş: pushState nedeni ya da "sent <başarılı>/<toplam>".
 * db: Firestore (yönetici) benzeri {doc(path) → {get, update}, runTransaction(fn)}; messaging: {send(msg)}. now: unix ms.
 */
async function pushNews({ db, messaging, id, now }) {
  const nowS = Math.floor(now / 1000);
  const ref = db.doc(`news/${id}`);
  // Ayır: belge işlem içinde yeniden okunur; hazırsa pushed_at = şimdi (ikinci tetik "already" görür)
  const reserved = await db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const item = snap.exists ? snap.data() : null;
    const state = pushState(item, nowS, id);
    if (state !== "ready") return { state };
    t.update(ref, { pushed_at: nowS });
    return { state, item };
  });
  if (reserved.state !== "ready") return reserved.state;
  const messages = messagesFor(id, reserved.item);
  let ok = 0;
  let lastError = null;
  for (const msg of messages) {
    try {
      await messaging.send(msg);
      ok++;
    } catch (e) {
      lastError = e;
      console.error(`newsPush ${id} ${msg.topic}: ${e && e.code ? e.code : ""} ${e && e.message ? e.message : e}`);
    }
  }
  if (!ok) {
    // Hiçbir dile gitmedi: ayırma geri alınır (yalnız hâlâ bizimse), zamanlayıcı sonra yeniden dener
    await db.runTransaction(async (t) => {
      const snap = await t.get(ref);
      if (snap.exists && snap.data().pushed_at === nowS) t.update(ref, { pushed_at: 0 });
    });
    throw lastError || new Error("gönderilemedi");
  }
  return `sent ${ok}/${messages.length}`;
}

/** news/{id} yazılınca (onDocumentWritten). before / after: belge verisi ya da null. */
async function handleNewsWritten({ db, messaging, id, before, after, now }) {
  if (!after) return "deleted";
  if (after.notify !== true) return "no-notify";
  if (before && sameExceptPushedAt(before, after)) return "self";   // bu modülün pushed_at yazması / geri alması
  if (Number(after.pushed_at) > 0) return "already";
  return pushNews({ db, messaging, id, now });
}

/** Zamanlayıcı: bildirimi bekleyen (notify, pushed_at 0) haberlerden görünür olanları gönderir. Dönüş: sayılar. */
async function pushScheduled({ db, messaging, now }) {
  const nowS = Math.floor(now / 1000);
  const snap = await db.collection("news").where("notify", "==", true).where("pushed_at", "==", 0).get();
  const result = { pending: snap.size, sent: 0, failed: 0 };
  for (const doc of snap.docs) {
    if (pushState(doc.data(), nowS, doc.id) !== "ready") continue;
    try {
      const r = await pushNews({ db, messaging, id: doc.id, now });
      if (r.startsWith("sent")) result.sent++;
    } catch (e) {
      result.failed++;   // ayrıntı pushNews'te günlüğe yazıldı; öbür haberler yine denenir
    }
  }
  return result;
}

// --- Yayın belgesi: config/news ------------------------------------------------------------------------------------

const FEED_DOC = "config/news";
const FEED_MAX = 40;
// Firestore belge sınırı 1 MiB: 40 haber pratikte ~50 KB; uç durumda (5 dilde 600 karakter emoji) sığmayan eski haber atlanır
const FEED_BYTES_MAX = 900_000;

const num = (v) => (Number.isFinite(Number(v)) ? Math.trunc(Number(v)) : 0);
const byAtDesc = (a, b) => b.at - a.at || (a.id < b.id ? 1 : a.id > b.id ? -1 : 0);

/** Haber belgesinin oyuna giden (herkese açık) kısmı. */
function feedItem(id, d) {
  const action = d.action && typeof d.action === "object" ? d.action : {};
  const t = d.target && typeof d.target === "object" ? d.target : {};
  return {
    id: String(id), kind: String(d.kind || ""), title: d.title && typeof d.title === "object" ? d.title : {},
    text: d.text && typeof d.text === "object" ? d.text : {}, image: String(d.image || ""),
    action: { kind: String(action.kind || ""), url: String(action.url || "") },
    start: num(d.start), end: num(d.end), pinned: d.pinned === true, code: num(d.code),
    target: { langs: Array.isArray(t.langs) ? t.langs.map(String) : [], min_level: num(t.min_level), max_level: num(t.max_level),
      min_code: num(t.min_code), max_code: num(t.max_code) },
    at: num(d.at),
  };
}

/**
 * Yayın belgesi config/news = {items, at}. docs: [{id, ...haber}]; now: unix ms. Bitmiş haber (end ≠ 0 ve end ≤ şimdi) atılır,
 * başlamamış haber kalır. En çok 40: önce SABİT haberler (eski olsalar da sınırda düşmesinler), kalan yer en yenilerle; sonuç
 * at'e göre yeniden eskiye.
 */
function buildNewsFeed(docs, now) {
  const nowS = Math.floor(now / 1000);
  const live = (docs || []).filter((d) => d && d.id && !(num(d.end) > 0 && num(d.end) <= nowS))
    .map((d) => feedItem(d.id, d)).sort(byAtDesc);
  const items = [];
  let bytes = 0;
  for (const pinned of [true, false]) {
    for (const it of live) {
      if (it.pinned !== pinned || items.length >= FEED_MAX) continue;
      const size = Buffer.byteLength(JSON.stringify(it));
      if (bytes + size > FEED_BYTES_MAX) continue;
      items.push(it);
      bytes += size;
    }
  }
  return { items: items.sort(byAtDesc), at: nowS };
}

/** Zamanlayıcı: yayında bitişi geçmiş haber varsa config/news koleksiyondan (işlem içinde) yeniden kurulur. Yoksa yalnız 1 okuma. */
async function refreshFeed({ db, now }) {
  const nowS = Math.floor(now / 1000);
  const ref = db.doc(FEED_DOC);
  const snap = await ref.get();
  const items = snap.exists && Array.isArray(snap.data().items) ? snap.data().items : [];
  const ended = items.filter((it) => it && num(it.end) > 0 && num(it.end) <= nowS).length;
  if (!ended) return { ended: 0 };
  const feed = await db.runTransaction(async (t) => {
    const all = await t.get(db.collection("news"));
    const next = buildNewsFeed(all.docs.map((d) => ({ id: d.id, ...d.data() })), now);
    t.set(ref, next);
    return next;
  });
  return { ended, items: feed.items.length };
}

module.exports = { LANGS, BODY_MAX, excerpt, targeted, messagesFor, pushState, sameExceptPushedAt, pushNews, handleNewsWritten,
  pushScheduled, FEED_DOC, FEED_MAX, buildNewsFeed, refreshFeed };
