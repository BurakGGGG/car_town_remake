// events_tick.js testi (internetsiz): sahte Firestore + sahte messaging. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { mirrorEvent, shouldNotify, messagesFor, eventsTick, LANGS, BODY, NOTIFY_LATE_MAX, PUSH_DOC } = require("../events_tick");

const DELETE = Symbol("delete");

// İşlem: okumalar anlık, yazmalar sonda uygulanır. update DELETE işaretli alanı siler; okuma / yazma sayılır.
function fakeDb(initial = {}) {
  const store = JSON.parse(JSON.stringify(initial));
  const stats = { reads: 0, writes: [], transactions: 0 };
  const apply = (path, v, replace) => {
    if (replace) {
      store[path] = JSON.parse(JSON.stringify(v));
      return;
    }
    if (!(path in store)) throw new Error("NOT_FOUND");
    const next = { ...store[path] };
    for (const [k, val] of Object.entries(v)) {
      if (val === DELETE) delete next[k];
      else next[k] = JSON.parse(JSON.stringify(val));
    }
    store[path] = next;
  };
  const ref = (path) => ({
    path,
    async get() {
      stats.reads++;
      const copy = path in store ? JSON.parse(JSON.stringify(store[path])) : undefined;   // okuma anındaki hâl
      return { exists: path in store, data: () => copy };
    },
    async set(v) {
      stats.writes.push([path, Object.keys(v)]);
      apply(path, v, true);
    },
  });
  return {
    store,
    stats,
    doc: ref,
    async runTransaction(fn) {
      stats.transactions++;
      const writes = [];
      const t = { get: (r) => r.get(), update: (r, v) => writes.push([r.path, v, false]), set: (r, v) => writes.push([r.path, v, true]) };
      const out = await fn(t);
      for (const [p, v, replace] of writes) {
        stats.writes.push([p, Object.keys(v)]);
        apply(p, v, replace);
      }
      return out;
    },
  };
}

// FCM sunucusunun veri yükü kuralları (news.test.js ile aynı): ayrılmış anahtar ve metin olmayan değer reddedilir.
function fakeMessaging({ failTopics = [] } = {}) {
  const sent = [];
  return {
    sent,
    async send(m) {
      for (const [k, v] of Object.entries(m.data || {})) {
        if (k === "from" || k === "message_type" || k.startsWith("google.") || k.startsWith("gcm.") || typeof v !== "string") {
          throw Object.assign(new Error(`Invalid data payload key: ${k}`), { code: "messaging/invalid-argument" });
        }
      }
      if (failTopics.includes(m.topic) || failTopics.includes("*")) throw Object.assign(new Error("x"), { code: "messaging/internal-error" });
      sent.push(m);
    },
  };
}

const NOW = 1_800_000_000_000;
const S = Math.floor(NOW / 1000);
const H = 3600;
const D = 86400;
const ev = (id, start, end, over = {}) => ({ id, title: { tr: `Etkinlik ${id}`, en: `Event ${id}` }, text: {}, start, end,
  money_mult: 2, xp_mult: 1, ...over });
const tick = (db, messaging = fakeMessaging(), now = NOW) => eventsTick({ db, messaging, now, deleteField: () => DELETE });
// Sessiz console.error (başarısız gönderim günlüğü testte gürültü yapmasın)
const quiet = async (fn) => {
  const orig = console.error;
  console.error = () => {};
  try { return await fn(); } finally { console.error = orig; }
};

test("ayna: süren etkinlik, yoksa sıradaki, o da yoksa null", () => {
  const past = ev("past", S - 3 * D, S - 2 * D);
  const live = ev("live", S - H, S + H);
  const next = ev("next", S + D, S + 2 * D);
  const later = ev("later", S + 5 * D, S + 6 * D);
  assert.equal(mirrorEvent([later, past, live, next], S).id, "live", "pencere şimdiyi içeriyor");
  assert.equal(mirrorEvent([later, past, next], S).id, "next", "süren yok: en küçük start > şimdi (sırasız liste)");
  assert.equal(mirrorEvent([past], S), null, "yalnız biten etkinlik: ayna yok");
  assert.equal(mirrorEvent([], S), null);
  assert.equal(mirrorEvent(undefined, S), null, "liste yok");
  assert.equal(mirrorEvent([null, { start: S - 1, end: S + 1 }], S), null, "kimliksiz öğe sayılmaz");
  // Sınırlar: start dahil, end hariç; art arda iki etkinlik (a.end == b.start) o anda b'yi gösterir
  const a = ev("a", S - D, S);
  const b = ev("b", S, S + D);
  assert.equal(mirrorEvent([a, b], S).id, "b", "bitiş anı: sıradaki başlamış");
  assert.equal(mirrorEvent([a], S), null, "end == şimdi: bitmiş");
  assert.equal(mirrorEvent([b], S - 1).id, "b", "başlamadan bir saniye önce: sıradaki");
  assert.strictEqual(mirrorEvent([live], S), mirrorEvent([live], S), "öğenin kendisi döner (kopya değil)");
});

test("bildirim adayı: notify, başlamış, bitmemiş, en çok 6 saat önce başlamış", () => {
  assert.equal(shouldNotify(ev("x", S - 60, S + H, { notify: true }), S), true);
  assert.equal(shouldNotify(ev("x", S - 60, S + H), S), false, "notify yok");
  assert.equal(shouldNotify(ev("x", S - 60, S + H, { notify: "true" }), S), false, "yalnız gerçek true");
  assert.equal(shouldNotify(ev("x", S + 60, S + H, { notify: true }), S), false, "başlamadı");
  assert.equal(shouldNotify(ev("x", S - 2 * H, S, { notify: true }), S), false, "bitti");
  assert.equal(shouldNotify(ev("x", S - NOTIFY_LATE_MAX, S + H, { notify: true }), S), true, "tam 6 saat: gider");
  assert.equal(shouldNotify(ev("x", S - NOTIFY_LATE_MAX - 1, S + H, { notify: true }), S), false, "6 saatten eski: gitmez (dağıtım sonrası)");
});

test("ileti: 5 dil konusu, başlık dilde yoksa en sonra tr, araçlı / araçsız metin", () => {
  const plain = messagesFor(ev("k1", S, S + D, { title: { tr: "KIŞ  ETKİNLİĞİ", en: "WINTER EVENT" } }));
  assert.deepEqual(plain.map((m) => m.topic), LANGS.map((l) => `news_${l}`));
  assert.deepEqual(plain.map((m) => m.notification.title), ["KIŞ ETKİNLİĞİ", "WINTER EVENT", "WINTER EVENT", "WINTER EVENT", "WINTER EVENT"]);
  assert.deepEqual(plain.map((m) => m.notification.body), LANGS.map((l) => BODY.plain[l]));
  assert.equal(plain[0].notification.body, "Etkinlik başladı! Kaçırma.");
  assert.deepEqual(plain[2].data, { kind: "event", id: "k1" });
  assert.equal(plain[0].android.notification.tag, "event");
  const car = messagesFor(ev("k2", S, S + D, { title: { tr: "SÜPER HAFTA" }, car: { id: "ford_focus", owned_gems: 50, owned_crate: "" } }));
  assert.deepEqual(car.map((m) => m.notification.title), Array(5).fill("SÜPER HAFTA"), "yalnız tr varsa hepsi tr");
  assert.equal(car[0].notification.body, "Etkinlik başladı! Görevleri bitir, etkinlik aracı senin olsun.");
  assert.equal(car[3].notification.body, "Das Event hat begonnen! Schließe die Aufgaben ab und das Event-Auto gehört dir.");
  assert.equal(car[4].notification.body, "L'événement a commencé ! Termine les missions et la voiture de l'événement est à toi.");
  assert.equal(messagesFor(ev("k3", S, S + D, { title: {} }))[0].notification.title, "AUTO YARD", "başlıksız");
});

test("takvim yok (eski tek etkinlik düzeni): hiçbir şeye dokunulmaz, tek okuma", async () => {
  const legacy = ev("old", S - D, S - H);   // bitmiş ama eski panelin yazdığı: dokunulmaz
  const db = fakeDb({ "config/app": { min_code: 11, event: legacy } });
  const r = await tick(db);
  assert.equal(r.managed, false);
  assert.deepEqual(db.store["config/app"].event, legacy);
  assert.equal(db.stats.reads, 1);
  assert.equal(db.stats.writes.length, 0);
  const none = fakeDb({});
  assert.equal((await tick(none)).managed, false, "config/app hiç yok");
  assert.equal(none.stats.writes.length, 0);
});

test("ayna aynıysa yazılmaz (tek okuma, işlem yok)", async () => {
  const live = ev("live", S - H, S + H);
  const db = fakeDb({ "config/app": { events: [live], event: live, min_code: 3, updated_at: 5 } });
  const r = await tick(db);
  assert.deepEqual([r.managed, r.mirror, r.mirror_id], [true, "same", "live"]);
  assert.equal(db.stats.reads, 1);
  assert.equal(db.stats.transactions, 0);
  assert.equal(db.store["config/app"].updated_at, 5);
});

test("ayna ilerler: biten etkinlikten sıradakine, sonra silinir; yalnız event + updated_at yazılır", async () => {
  const a = ev("a", S - D, S - 60);
  const b = ev("b", S + H, S + D, { car: { id: "ford_focus", owned_gems: 100, owned_crate: "city_crate" }, reveal_days: 3,
    missions: [{ id: "m1", metric: "event_car_wins", target: 3, money: 0, gems: 10, xp: 0, crate: "", decor: "" }] });
  const db = fakeDb({ "config/app": { events: [a, b], event: a, min_code: 11, notice: { id: "n1" }, ads: { total_cap: 9 }, packs: [], updated_at: 1 } });
  const r = await tick(db);
  assert.deepEqual([r.mirror, r.mirror_id], ["set", "b"]);
  const doc = db.store["config/app"];
  assert.deepEqual(doc.event, b, "sıradaki (başlamamış) etkinlik aynada: eski sürüm başlangıçta kendisi açar");
  assert.equal(doc.updated_at, S);
  assert.deepEqual([doc.min_code, doc.notice.id, doc.ads.total_cap, doc.events.length], [11, "n1", 9, 2], "öbür alanlar korunur");
  assert.deepEqual(db.stats.writes, [["config/app", ["event", "updated_at"]]], "yalnız event + updated_at güncellendi");
  // b de bitince ayna silinir
  const later = S + 2 * D;
  const r2 = await tick(db, fakeMessaging(), later * 1000);
  assert.deepEqual([r2.mirror, r2.mirror_id], ["deleted", ""]);
  assert.ok(!("event" in db.store["config/app"]), "event alanı silindi");
  assert.equal(db.store["config/app"].events.length, 2, "liste korunur (panel 30 gün sonra düşürür)");
  const r3 = await tick(db, fakeMessaging(), later * 1000);
  assert.equal(r3.mirror, "same", "ayna yok + alan yok: yazılmaz");
});

test("ayna: işlem içinde yeniden okunur (panelin aynı anda yazdığı liste esas)", async () => {
  const a = ev("a", S - D, S - 60);
  const c = ev("c", S - 60, S + D);
  const db = fakeDb({ "config/app": { events: [a], event: a } });
  // İlk okumadan sonra panel listeyi değiştirmiş gibi: işlemdeki okuma yeni listeyi görür
  const origDoc = db.doc;
  let first = true;
  db.doc = (path) => {
    const r = origDoc(path);
    if (path !== "config/app") return r;
    return { ...r, async get() {
      const snap = await r.get();
      if (first) { first = false; db.store["config/app"] = { events: [c], event: c }; }
      return snap;
    } };
  };
  const r = await tick(db);
  assert.equal(r.mirror, "same", "panel aynayı zaten doğru yazmış: ezilmez");
  assert.deepEqual(db.store["config/app"].event, c);
});

test("başlangıç bildirimi: bir kez, 5 dile, ops/event_push'a işaretlenir", async () => {
  const live = ev("live", S - 120, S + D, { notify: true, title: { tr: "YAZ", en: "SUMMER" } });
  const db = fakeDb({ "config/app": { events: [live], event: live } });
  const m = fakeMessaging();
  const r = await tick(db, m);
  assert.deepEqual(r.pushed, ["live 5/5"]);
  assert.equal(m.sent.length, 5);
  assert.deepEqual(m.sent.map((x) => x.notification.title), ["YAZ", "SUMMER", "SUMMER", "SUMMER", "SUMMER"]);
  assert.deepEqual(db.store[PUSH_DOC], { live: S });
  const again = await tick(db, m, NOW + 600_000);
  assert.deepEqual(again.pushed, [], "ikinci turda gitmez");
  assert.equal(m.sent.length, 5);
});

test("bildirim: notify'sız / başlamamış / 6 saatten eski etkinliğe gitmez; ops/event_push okunmaz", async () => {
  const db = fakeDb({ "config/app": { events: [ev("a", S - 7 * H, S + D, { notify: true }), ev("b", S + H, S + D * 2, { notify: true }),
    ev("c", S - 60, S - 1)], event: null } });
  const m = fakeMessaging();
  const r = await tick(db, m);
  assert.deepEqual(r.pushed, []);
  assert.equal(m.sent.length, 0);
  assert.ok(!(PUSH_DOC in db.store));
  assert.equal(db.stats.reads, 1 + 1, "config/app + (ayna değişti: işlem içi okuma), ops/event_push okunmadı");
});

test("bildirim: bir dil başarısızsa öbürleri gider ve işaretlenir; hepsi başarısızsa işaretlenmez, sonra yeniden denenir", async () => {
  const live = ev("live", S - 60, S + D, { notify: true });
  const db = fakeDb({ "config/app": { events: [live], event: live } });
  const partial = await quiet(() => tick(db, fakeMessaging({ failTopics: ["news_de"] })));
  assert.deepEqual(partial.pushed, ["live 4/5"]);
  assert.equal(db.store[PUSH_DOC].live, S);

  const db2 = fakeDb({ "config/app": { events: [live], event: live } });
  const failed = await quiet(() => tick(db2, fakeMessaging({ failTopics: ["*"] })));
  assert.deepEqual([failed.pushed, failed.failed], [[], 1]);
  assert.ok(!(PUSH_DOC in db2.store), "hiçbir dile gitmedi: işaretlenmedi");
  const m = fakeMessaging();
  const retry = await tick(db2, m, NOW + 600_000);
  assert.deepEqual(retry.pushed, ["live 5/5"], "sonraki tur yeniden dener");
  assert.equal(db2.store[PUSH_DOC].live, S + 600);
});

test("bildirim: eski işaretler korunur, 120 günden eskileri silinir; araçlı etkinlik metni", async () => {
  const a = ev("a", S - 60, S + D, { notify: true, car: { id: "ford_focus", owned_gems: 0, owned_crate: "" } });
  const db = fakeDb({ "config/app": { events: [a], event: a }, [PUSH_DOC]: { old_recent: S - 10 * D, old_stale: S - 200 * D } });
  const m = fakeMessaging();
  await tick(db, m);
  assert.deepEqual(db.store[PUSH_DOC], { old_recent: S - 10 * D, a: S });
  assert.equal(m.sent[0].notification.body, BODY.car.tr, "araçlı etkinlik metni");
  assert.deepEqual(m.sent[0].data, { kind: "event", id: "a" });
});
