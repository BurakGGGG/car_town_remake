// mail.js testi (internetsiz): sahte Firestore + sahte messaging. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { handleMailCreated, messageFor, pick, TEXT } = require("../mail");

function fakeDb(initial = {}) {
  const store = { ...initial };
  return {
    store,
    doc: (path) => ({
      async get() { return { exists: path in store, data: () => store[path] }; },
      async delete() { delete store[path]; },
    }),
  };
}

function fakeMessaging(fail) {
  const sent = [];
  return {
    sent,
    async send(m) {
      for (const [k, v] of Object.entries(m.data || {})) {
        if (k === "from" || k.startsWith("google.") || typeof v !== "string") throw Object.assign(new Error(k), { code: "messaging/invalid-argument" });
      }
      if (fail) throw Object.assign(new Error("x"), { code: fail });
      sent.push(m);
    },
  };
}

test("jetonlu alıcıya hediye bildirimi gider (dilinde, posta başlığıyla)", async () => {
  const db = fakeDb({ "push/p_A": { token: "tokA", lang: "tr" } });
  const m = fakeMessaging();
  const r = await handleMailCreated({ db, messaging: m, uid: "A", mail: { title: { tr: "Açılış hediyesi", en: "Launch gift" }, gems: 50 } });
  assert.equal(r, "sent");
  assert.equal(m.sent[0].token, "tokA");
  assert.equal(m.sent[0].notification.body, "🎁 Açılış hediyesi! Almak için dokun");
  assert.equal(m.sent[0].android.notification.tag, "mail", "art arda postalar tek bildirimde birleşir");
  assert.deepEqual(m.sent[0].data, { type: "mail" });
});

test("başlıksız posta: genel metin; bilinmeyen dil İngilizce", () => {
  assert.equal(messageFor("tr", undefined).body, TEXT.tr.body);
  assert.equal(messageFor("xx", "").body, TEXT.en.body);
  assert.equal(messageFor("__proto__", "").body, TEXT.en.body, "yerleşik nesne anahtarı dil sayılmaz");
  assert.equal(messageFor("de", { en: "Weekend bonus" }).body, "🎁 Weekend bonus! Tippe, um es abzuholen", "dil yoksa en");
  assert.ok(messageFor("tr", "x".repeat(200)).body.length < 90, "uzun başlık kısaltılır");
});

test("pick: dil sözlüğü / düz metin / boş", () => {
  assert.equal(pick({ tr: "  Merhaba " }, "fr"), "Merhaba");
  assert.equal(pick("düz", "tr"), "düz");
  assert.equal(pick(null, "tr"), "");
  assert.equal(pick({ tr: 5 }, "tr"), "");
});

test("gitmeyen durumlar: notify false, jeton yok, HEDİYELER kapalı", async () => {
  const m = fakeMessaging();
  assert.equal(await handleMailCreated({ db: fakeDb({ "push/p_A": { token: "t" } }), messaging: m, uid: "A", mail: { notify: false } }), "skip");
  assert.equal(await handleMailCreated({ db: fakeDb(), messaging: m, uid: "A", mail: { gems: 1 } }), "no-token");
  const muted = fakeDb({ "push/p_A": { token: "t", lang: "en", prefs: { race: true, gift: false } } });
  assert.equal(await handleMailCreated({ db: muted, messaging: m, uid: "A", mail: { gems: 1 } }), "muted");
  assert.equal(m.sent.length, 0);
});

test("geçersiz jeton silinir; başka FCM hatası yükselir", async () => {
  const db = fakeDb({ "push/p_A": { token: "old", lang: "es" } });
  assert.equal(await handleMailCreated({ db, messaging: fakeMessaging("messaging/registration-token-not-registered"), uid: "A", mail: {} }), "stale");
  assert.equal("push/p_A" in db.store, false);
  const db2 = fakeDb({ "push/p_A": { token: "t" } });
  await assert.rejects(handleMailCreated({ db: db2, messaging: fakeMessaging("messaging/internal-error"), uid: "A", mail: {} }));
  assert.equal("push/p_A" in db2.store, true, "jeton korunur");
});
