// email_code.js testi (internetsiz): sahte Firestore + sahte Auth + sahte e-posta. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const ec = require("../email_code");

function fakeDb(initial = {}) {
  const store = { ...initial };
  const write = (path, v, opts) => { store[path] = opts && opts.merge ? { ...(store[path] || {}), ...v } : { ...v }; };
  const ref = (path) => ({
    path,
    async get() { return { exists: path in store, data: () => ({ ...store[path] }) }; },
    async set(v, opts) { write(path, v, opts); },
  });
  return {
    store,
    doc: ref,
    async runTransaction(fn) {
      const writes = [];
      const t = { get: (r) => r.get(), set: (r, v, opts) => writes.push([r.path, v, opts]) };
      const out = await fn(t);   // hata atılırsa hiçbir şey yazılmaz
      for (const [p, v, opts] of writes) write(p, v, opts);
      return out;
    },
  };
}

function fakeAuth(users = {}) {
  let n = 0;
  return {
    users,   // uid -> {uid, email, emailVerified, disabled}
    async getUserByEmail(email) {
      const u = Object.values(users).find((x) => x.email === email);
      if (!u) throw Object.assign(new Error("no user"), { code: "auth/user-not-found" });
      return { ...u };
    },
    async createUser({ email, emailVerified }) {
      const uid = `e_${++n}`;
      users[uid] = { uid, email, emailVerified, disabled: false };
      return { uid };
    },
    async updateUser(uid, fields) { Object.assign(users[uid], fields); },
    async createCustomToken(uid) { return `token:${uid}`; },
  };
}

function fakeMail() {
  return { sent: [], fail: false, async send(msg) { if (this.fail) throw new Error("down"); this.sent.push(msg); } };
}

const T0 = Date.UTC(2026, 9, 18, 12, 0, 0);
const MIN = 60 * 1000;

async function rejects(promise, reason) {
  try {
    await promise;
  } catch (e) {
    assert.ok(e instanceof ec.CodeError, `CodeError bekleniyordu: ${e}`);
    assert.strictEqual(e.reason, reason);
    return e;
  }
  assert.fail(`${reason} bekleniyordu, istek kabul edildi`);
}

test("kod gider, doğru kod yeni hesap açar, ikinci kez kullanılamaz", async () => {
  const db = fakeDb(); const auth = fakeAuth(); const mail = fakeMail();
  const r = await ec.sendCode({ db, mail, email: "  Ali@Example.COM ", lang: "tr", ip: "1.2.3.4", now: T0, randomCode: () => "042137" });
  assert.strictEqual(r.resend_after, 60);
  assert.strictEqual(mail.sent.length, 1);
  assert.strictEqual(mail.sent[0].to, "ali@example.com");
  assert.match(mail.sent[0].subject, /042137/);
  assert.match(mail.sent[0].html, /042137/);
  assert.match(mail.sent[0].text, /10 dakika/);
  // kod düz metin saklanmaz
  const doc = db.store[`email_codes/${ec.sha256("ali@example.com")}`];
  assert.ok(doc && doc.hash && !JSON.stringify(doc).includes("042137"));
  const v = await ec.verifyCode({ db, auth, email: "ali@example.com", code: "042137", now: T0 + MIN });
  assert.deepStrictEqual(v, { token: "token:e_1", created: true });
  assert.strictEqual(auth.users.e_1.emailVerified, true);
  await rejects(ec.verifyCode({ db, auth, email: "ali@example.com", code: "042137", now: T0 + MIN }), "no_code");
});

test("AYNI E-POSTA = AYNI HESAP: Google / Facebook hesabının UID'si döner, e-postası doğrulanır", async () => {
  const auth = fakeAuth({ g_1: { uid: "g_1", email: "veli@gmail.com", emailVerified: true },
    f_2: { uid: "f_2", email: "ayse@example.com", emailVerified: false } });
  for (const [email, uid] of [["veli@gmail.com", "g_1"], ["AYSE@example.com", "f_2"]]) {
    const db = fakeDb(); const mail = fakeMail();
    await ec.sendCode({ db, mail, email, lang: "en", ip: "x", now: T0, randomCode: () => "111111" });
    const v = await ec.verifyCode({ db, auth, email, code: "111111", now: T0 });
    assert.deepStrictEqual(v, { token: `token:${uid}`, created: false });
  }
  assert.strictEqual(auth.users.f_2.emailVerified, true);
  assert.strictEqual(Object.keys(auth.users).length, 2);
});

test("yanlış kod: kalan hak söylenir, 5. yanlışta kod yanar", async () => {
  const db = fakeDb(); const auth = fakeAuth(); const mail = fakeMail();
  await ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0, randomCode: () => "123456" });
  for (let i = 1; i <= 4; i++) {
    const e = await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "000000", now: T0 }), "wrong_code");
    assert.strictEqual(e.extra.attempts_left, 5 - i);
    assert.strictEqual(e.status, "invalid-argument");
  }
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "000000", now: T0 }), "too_many_attempts");
  // doğru kod da artık geçmez
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "123456", now: T0 }), "no_code");
  assert.strictEqual(Object.keys(auth.users).length, 0);
});

test("yanlış denemeler kodlar arasında saatlik sayılır: yeni kod istemek tahmin hakkını yenilemez", async () => {
  const db = fakeDb(); const auth = fakeAuth(); const mail = fakeMail();
  const send = (now, code) => ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now, randomCode: () => code });
  await send(T0, "111111");
  for (let i = 0; i < 3; i++) await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "000000", now: T0 + i }), "wrong_code");
  await send(T0 + 2 * MIN, "222222");   // yeni kod: kod başına hak 5 olsa da saatte 2 hak kaldı
  const e = await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "000000", now: T0 + 2 * MIN }), "wrong_code");
  assert.strictEqual(e.extra.attempts_left, 1);
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "000000", now: T0 + 2 * MIN }), "too_many_attempts");
  // saatlik hak bitti: yeni kod gönderilmez (e-posta gitmez), doğru kod da geçmez
  const busy = await rejects(send(T0 + 4 * MIN, "333333"), "too_many");
  assert.strictEqual(busy.extra.retry_after, 56 * 60);
  assert.strictEqual(mail.sent.length, 2);
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "222222", now: T0 + 4 * MIN }), "no_code");
  // bir saat sonra yanlışlar düşer: yeni kodla girilir
  await send(T0 + 61 * MIN, "444444");
  const v = await ec.verifyCode({ db, auth, email: "a@b.co", code: "444444", now: T0 + 61 * MIN });
  assert.strictEqual(typeof v.token, "string");
  assert.strictEqual(Object.keys(auth.users).length, 1);
});

test("dil alanına yerleşik nesne adı (__proto__, constructor) verilirse İngilizce e-posta gider", () => {
  for (const lang of ["__proto__", "constructor", "toString", 42, null, ["tr"]]) {
    const m = ec.mailFor(lang, "123456");
    assert.match(m.subject, /^Your Auto Yard sign-in code: 123456$/, String(lang));
  }
});

test("süresi dolan kod (10 dk) geçmez; yeni kod eskisini geçersiz kılar", async () => {
  const db = fakeDb(); const auth = fakeAuth(); const mail = fakeMail();
  await ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0, randomCode: () => "111111" });
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "111111", now: T0 + 10 * MIN + 1 }), "expired");
  await ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0 + 11 * MIN, randomCode: () => "222222" });
  await ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0 + 12 * MIN, randomCode: () => "333333" });
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "222222", now: T0 + 12 * MIN }), "wrong_code");
  const v = await ec.verifyCode({ db, auth, email: "a@b.co", code: "333333", now: T0 + 12 * MIN });
  assert.strictEqual(v.token, "token:e_1");
});

test("gönderim sınırları: 60 sn bekleme, e-posta başına saatte 5, adres başına saatte 20", async () => {
  const db = fakeDb(); const mail = fakeMail();
  const send = (email, now, ip = "9.9.9.9") => ec.sendCode({ db, mail, email, lang: "tr", ip, now });
  await send("a@b.co", T0);
  const e = await rejects(send("a@b.co", T0 + 20 * 1000), "cooldown");
  assert.strictEqual(e.extra.retry_after, 40);
  assert.strictEqual(e.status, "resource-exhausted");
  for (let i = 1; i < 5; i++) await send("a@b.co", T0 + i * 2 * MIN);
  const busy = await rejects(send("a@b.co", T0 + 12 * MIN), "too_many");
  assert.strictEqual(busy.extra.retry_after, 48 * 60);
  await send("a@b.co", T0 + 61 * MIN);   // bir saat geçti: ilk gönderim düştü
  // adres sınırı: aynı adresten saatte 20 (62. dakikada son bir saatte kalanlar: 4, 6, 8 ve 61. dakika = 4 gönderim)
  for (let i = 0; i < 16; i++) await send(`u${i}@b.co`, T0 + 62 * MIN);
  await rejects(send("son@b.co", T0 + 62 * MIN), "too_many");
  await send("son@b.co", T0 + 62 * MIN, "8.8.8.8");   // başka adres etkilenmez
  assert.strictEqual(mail.sent.length, 23);
});

test("geçersiz girdi ve gönderilemeyen e-posta", async () => {
  const db = fakeDb(); const auth = fakeAuth(); const mail = fakeMail();
  for (const bad of ["", "ali", "ali@", "a b@c.de", "@b.co", "x".repeat(250) + "@b.co", null]) {
    await rejects(ec.sendCode({ db, mail, email: bad, lang: "tr", ip: "x", now: T0 }), "bad_email");
  }
  for (const bad of ["", "12345", "1234567", "abcdef", null]) {
    await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: bad, now: T0 }), "bad_code");
  }
  mail.fail = true;
  const e = await rejects(ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0, randomCode: () => "555555" }), "send_failed");
  assert.strictEqual(e.status, "internal");
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "555555", now: T0 }), "no_code");   // ulaşmayan kod geçmez
});

test("kapatılmış hesaba jeton verilmez", async () => {
  const db = fakeDb(); const mail = fakeMail();
  const auth = fakeAuth({ g_1: { uid: "g_1", email: "a@b.co", emailVerified: true, disabled: true } });
  await ec.sendCode({ db, mail, email: "a@b.co", lang: "tr", ip: "x", now: T0, randomCode: () => "777777" });
  await rejects(ec.verifyCode({ db, auth, email: "a@b.co", code: "777777", now: T0 }), "disabled");
});

test("e-posta metni: 5 dil, bilinmeyen dil İngilizce, Fransızcada noktalamadan önce bölünmez boşluk", () => {
  for (const lang of ["tr", "en", "es", "de", "fr"]) {
    const m = ec.mailFor(lang, "987654");
    assert.match(m.subject, /987654/);
    assert.match(m.text, /987654/);
    assert.match(m.html, /987654/);
  }
  assert.deepStrictEqual(ec.mailFor("xx", "1"), ec.mailFor("en", "1"));
  assert.ok(!/ [:;!?]/.test(ec.mailFor("fr", "1").text));
});

test("adres: X-Forwarded-For'un SON öğesi (Cloud Run'ın eklediği); istemcinin yazdığı ilk öğeler sayılmaz", () => {
  assert.strictEqual(ec.clientIp({ "x-forwarded-for": "9.9.9.9" }, "10.0.0.1"), "9.9.9.9");
  assert.strictEqual(ec.clientIp({ "x-forwarded-for": "1.1.1.1, 2.2.2.2,  9.9.9.9 " }, "10.0.0.1"), "9.9.9.9");
  // Her istekte uydurma bir ilk öğe yazmak adresi değiştirmez: sınır aynı adrese işler
  const a = ec.clientIp({ "x-forwarded-for": "203.0.113.1, 9.9.9.9" }, "");
  const b = ec.clientIp({ "x-forwarded-for": "203.0.113.2, 9.9.9.9" }, "");
  assert.strictEqual(a, b);
  assert.strictEqual(ec.clientIp({}, "10.0.0.1"), "10.0.0.1");
  assert.strictEqual(ec.clientIp({ "x-forwarded-for": " , " }, undefined), "");
});
