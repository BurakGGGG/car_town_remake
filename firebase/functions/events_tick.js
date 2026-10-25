// ETKİNLİK TAKVİMİ — saf mantık (index.js zamanlayıcıya bağlar; test/events_tick.test.js sahte db / messaging ile sınar;
// yönetim paneli mirrorEvent'i admin/lib.mjs üzerinden aynen kullanır). Ayrıntı: docs/CANLI_ETKINLIK.md "Takvim ve etkinlik aracı".
//
// config/app.events = panelin planladığı etkinlikler (en çok 12, başlangıca göre sıralı, zaman pencereleri çakışmaz; her öğe
// admin/lib.mjs buildEvent biçiminde, isteğe bağlı car / notify / reveal_days ile). Yeni sürümler listeyi okur.
// ESKİ SÜRÜMLER yalnız config/app.event okur: event = mirrorEvent(events) AYNASI — şu an süren etkinlik, yoksa sıradaki
// (en küçük start > şimdi), o da yoksa alan silinir. Panel listeyi yazarken aynayı aynı işlemde yazar; aynayı zamanla
// ilerletmek (etkinlik bitince sıradakine geçmek) eventsTick'in işidir.
//
// eventsTick (10 dakikada bir):
//   (a) config/app okunur (1 okuma). events listesi yoksa (takvim hiç kaydedilmemiş: eski tek etkinlik düzeni) HİÇBİR ŞEYE
//       dokunulmaz. Ayna değiştiyse İŞLEM içinde yeniden okunup yalnız event + updated_at güncellenir (panelin aynı anda
//       yazdığı listeyi ezmez).
//   (b) notify: true olan, başlamış (start ≤ şimdi < end) ve en çok 6 saat önce başlamış etkinliğe dil konularına
//       (news_<dil>, misafir de abone) BİR KEZ bildirim gider. Gönderilenler ops/event_push = {etkinlikKimliği: unix sn}
//       belgesinde (istemciye kapalı: firestore.rules "başka her yol kapalı"). En az bir dile gidince işaretlenir; hiçbir dile
//       gidemezse sonraki turda yeniden denenir. 6 saat sınırı: dağıtımdan hemen sonra eski etkinliğe bildirim gitmesin.
//       ops/event_push yalnız bildirim adayı varken okunur.

const { pick } = require("./mail");

const LANGS = ["tr", "en", "es", "de", "fr"];
const CONFIG_DOC = "config/app";
const PUSH_DOC = "ops/event_push";
const NOTIFY_LATE_MAX = 6 * 3600;
// ops/event_push'ta bundan eski kayıt silinir (biten etkinliğin kimliği bir daha başlamaz; belge büyümesin)
const PUSH_KEEP = 120 * 86400;
const TITLE_MAX = 60;

// Bildirim metni (dil başına): araçlı etkinlikte araç vurgulanır
const BODY = {
  car: {
    tr: "Etkinlik başladı! Görevleri bitir, etkinlik aracı senin olsun.",
    en: "The event has started! Finish the missions and the event car is yours.",
    es: "¡El evento ha empezado! Completa las misiones y el coche del evento será tuyo.",
    de: "Das Event hat begonnen! Schließe die Aufgaben ab und das Event-Auto gehört dir.",
    fr: "L'événement a commencé ! Termine les missions et la voiture de l'événement est à toi.",
  },
  plain: {
    tr: "Etkinlik başladı! Kaçırma.",
    en: "The event has started! Don't miss it.",
    es: "¡El evento ha empezado! No te lo pierdas.",
    de: "Das Event hat begonnen! Verpass es nicht.",
    fr: "L'événement a commencé ! Ne le manque pas.",
  },
};

const num = (v) => (Number.isFinite(Number(v)) ? Math.trunc(Number(v)) : 0);

/**
 * Eski sürümlerin okuduğu config/app.event: penceresi şimdiyi içeren etkinlik (start ≤ şimdi < end), yoksa sıradaki (en küçük
 * start > şimdi), o da yoksa null. events: buildEvent biçiminde liste (sırasız da olabilir); nowS: unix sn.
 */
function mirrorEvent(events, nowS) {
  const list = (Array.isArray(events) ? events : []).filter((e) => e && typeof e === "object" && e.id);
  const running = list.filter((e) => num(e.start) <= nowS && nowS < num(e.end))
    .sort((a, b) => num(a.start) - num(b.start));
  if (running.length) return running[0];
  const next = list.filter((e) => num(e.start) > nowS).sort((a, b) => num(a.start) - num(b.start) || num(a.end) - num(b.end));
  return next.length ? next[0] : null;
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

/** Etkinliğin başlangıç bildirimi şimdi gitmeli mi (gönderilmiş mi bakılmaz). */
function shouldNotify(event, nowS) {
  if (!event || event.notify !== true || !event.id) return false;
  const start = num(event.start);
  return start <= nowS && nowS < num(event.end) && start >= nowS - NOTIFY_LATE_MAX;
}

/** Her dil konusuna bir ileti: başlık = etkinlik başlığı (dil yoksa en, o da yoksa tr), metin şablondan. */
function messagesFor(event) {
  const body = event.car && typeof event.car === "object" && event.car.id ? BODY.car : BODY.plain;
  return LANGS.map((lang) => ({
    topic: `news_${lang}`,
    notification: { title: [...pick(event.title, lang).replace(/\s+/g, " ")].slice(0, TITLE_MAX).join("") || "AUTO YARD",
      body: body[lang] },
    // tag "event": yeni etkinlik bildirimi eskisinin yerine geçer; ikon / renk öbür bildirimlerle aynı
    android: { priority: "high", notification: { tag: "event", icon: "icon_monochrome", color: "#F5BE4C" } },
    // FCM ayrılmış anahtarları ("from", "message_type", "google." / "gcm.") kullanma: news.js notu. Değerler metin olmalı.
    data: { kind: "event", id: String(event.id) },
  }));
}

/**
 * Zamanlayıcı turu. db: Firestore (yönetici) benzeri {doc(path) → {get, set}, runTransaction(fn)}; messaging: {send(msg)};
 * now: unix ms; deleteField: alan silme işareti (varsayılan FieldValue.delete(); test kendi işaretini verir). Dönüş: günlüğe
 * yazılacak özet {managed, mirror: "same" | "set" | "deleted", mirror_id, pushed: ["kimlik başarılı/toplam"], failed}.
 */
async function eventsTick({ db, messaging, now, deleteField = () => require("firebase-admin/firestore").FieldValue.delete() }) {
  const nowS = Math.floor(now / 1000);
  const ref = db.doc(CONFIG_DOC);
  const snap = await ref.get();
  const data = snap.exists ? snap.data() || {} : {};
  const result = { managed: Array.isArray(data.events), mirror: "same", mirror_id: "", pushed: [], failed: 0 };
  if (!result.managed) return result;   // takvim hiç kaydedilmemiş: eski config/app.event'e dokunulmaz

  // (a) Ayna: değiştiyse işlem içinde yeniden okunur (panelin yazdığı yeni liste esas alınır)
  const mirror = mirrorEvent(data.events, nowS);
  result.mirror_id = mirror ? String(mirror.id) : "";
  if (!deepEqual(mirror, data.event ?? null)) {
    result.mirror = await db.runTransaction(async (t) => {
      const fresh = await t.get(ref);
      const cur = fresh.exists ? fresh.data() || {} : {};
      if (!Array.isArray(cur.events)) return "same";
      const next = mirrorEvent(cur.events, nowS);
      result.mirror_id = next ? String(next.id) : "";
      if (deepEqual(next, cur.event ?? null)) return "same";
      t.update(ref, { event: next || deleteField(), updated_at: nowS });
      return next ? "set" : "deleted";
    });
  }

  // (b) Başlangıç bildirimi
  const due = data.events.filter((e) => shouldNotify(e, nowS));
  if (!due.length) return result;
  const pushRef = db.doc(PUSH_DOC);
  const pushSnap = await pushRef.get();
  const sent = pushSnap.exists ? { ...(pushSnap.data() || {}) } : {};
  let changed = false;
  for (const event of due) {
    const id = String(event.id);
    if (num(sent[id]) > 0) continue;
    let ok = 0;
    const messages = messagesFor(event);
    for (const msg of messages) {
      try {
        await messaging.send(msg);
        ok++;
      } catch (e) {
        console.error(`eventsTick ${id} ${msg.topic}: ${e && e.code ? e.code : ""} ${e && e.message ? e.message : e}`);
      }
    }
    if (ok) {
      sent[id] = nowS;
      changed = true;
      result.pushed.push(`${id} ${ok}/${messages.length}`);
    } else {
      result.failed++;   // hiçbir dile gitmedi: işaretlenmez, sonraki turda yeniden denenir
    }
  }
  if (changed) {
    for (const [id, at] of Object.entries(sent)) if (num(at) < nowS - PUSH_KEEP) delete sent[id];
    await pushRef.set(sent);
  }
  return result;
}

module.exports = { LANGS, CONFIG_DOC, PUSH_DOC, NOTIFY_LATE_MAX, BODY, mirrorEvent, shouldNotify, messagesFor, eventsTick };
