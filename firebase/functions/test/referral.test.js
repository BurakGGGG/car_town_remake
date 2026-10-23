// referral.js testi (internetsiz): sahte Firestore. Çalıştırma: cd firebase/functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { readFileSync } = require("node:fs");
const path = require("node:path");
const { handleJoin, handleQualify, TIERS, WELCOME, QUALIFY_LEVEL, TEXT, tierMail } = require("../referral");

function fakeDb(initial = {}) {
  const store = JSON.parse(JSON.stringify(initial));
  const write = (p, v, merge) => { store[p] = merge ? { ...(store[p] || {}), ...v } : v; };
  const ref = (p) => ({
    path: p,
    async get() { return { exists: p in store, data: () => store[p] }; },
    async set(v, opts) { write(p, v, opts && opts.merge); },
  });
  return {
    store,
    doc: ref,
    async runTransaction(fn) {
      const writes = [];
      const t = {
        get: (r) => r.get(),
        set: (r, v, opts) => writes.push([r.path, v, !!(opts && opts.merge)]),
        update: (r, v) => writes.push([r.path, v, true]),
      };
      const out = await fn(t);
      for (const [p, v, merge] of writes) write(p, v, merge);
      return out;
    },
  };
}

const NOW = 1_800_000_000_000;
const NOW_S = NOW / 1000;
const DAY = 24 * 3600 * 1000;
const DEV = (c) => c.repeat(64);
const fresh = async () => NOW - DAY;   // dün açılmış hesap
const world = (over = {}) => ({
  "codes/ABC234": { uid: "alice" },
  "garages/g_alice": { name: "Usta Ali" },
  ...over,
});

async function join(db, uid, { code = "ABC234", dev = DEV("a"), src = "link", createdMs = fresh } = {}) {
  db.store[`users/${uid}/referral/ref_claim`] = { code, src, dev, at: NOW_S };
  return handleJoin({ db, uid, now: NOW, createdMs });
}

async function lvl3(db, uid) {
  db.store[`users/${uid}/referral/ref_lvl3`] = { at: NOW_S };
  return handleQualify({ db, uid, now: NOW });
}

test("geçerli davet: arkadaşlık, sayaç, hoş geldin postası, sonuç ok", async () => {
  const db = fakeDb(world());
  assert.equal(await join(db, "bob"), "ok");
  const claim = db.store["users/bob/referral/ref_claim"];
  assert.equal(claim.status, "ok");
  assert.equal(claim.referrer, "alice");
  assert.ok(db.store[`ref_devices/${DEV("a")}`]);
  assert.equal(db.store["referrals/r_alice"].joined, 1);
  assert.equal(db.store["referrals/r_alice/invited/f_bob"].state, "joined");
  assert.ok(db.store["users/alice/friends/f_bob"].since && db.store["users/bob/friends/f_alice"].since);
  const mail = db.store["users/bob/mail/ref_welcome"];
  assert.equal(mail.gems, WELCOME.gems);
  assert.equal(mail.money, WELCOME.money);
  assert.equal(mail.notify, false);
  assert.match(mail.text.tr, /Usta Ali seni/);
  assert.equal("users/alice/mail/ref_1" in db.store, false, "katılmak sayılmak değil: 3. seviye beklenir");
});

test("olay iki kez teslim edilirse ilk sonuç korunur, sayaç bir kez artar", async () => {
  const db = fakeDb(world());
  assert.equal(await join(db, "bob"), "ok");
  assert.equal(await handleJoin({ db, uid: "bob", now: NOW, createdMs: fresh }), "ok");
  assert.equal(db.store["referrals/r_alice"].joined, 1);
});

test("aynı anda iki çalışma: işlem içindeki sonuç denetimi ilkinin ok'unu ezmez", async () => {
  const db = fakeDb(world());
  db.store["users/bob/referral/ref_claim"] = { code: "ABC234", src: "link", dev: DEV("a"), at: NOW_S };
  // ikinci çalışma ilk denetimden geçtikten sonra (hesap yaşı okunurken) birincisi bitiriyor
  const racing = async () => {
    db.store["users/bob/referral/ref_claim"].status = "ok";
    db.store["users/bob/referral/ref_claim"].referrer = "alice";
    db.store[`ref_devices/${DEV("a")}`] = { at: NOW_S };
    return NOW - DAY;
  };
  assert.equal(await handleJoin({ db, uid: "bob", now: NOW, createdMs: racing }), "ok");
  assert.equal(db.store["users/bob/referral/ref_claim"].status, "ok");
  assert.equal("referrals/r_alice" in db.store, false, "ikinci çalışma hiçbir şey yazmadı");
});

test("reddedilenler: kod yok, kendi kodu, eski hesap, biçimsiz talep", async () => {
  const db = fakeDb(world({ "codes/SELF22": { uid: "bob" } }));
  assert.equal(await join(db, "u1", { code: "ZZZ999" }), "no_code");
  assert.equal(await join(db, "bob", { code: "SELF22" }), "self");
  assert.equal(await join(db, "u2", { createdMs: async () => NOW - 8 * DAY }), "old_account");
  assert.equal(await join(db, "u3", { createdMs: async () => 0 }), "old_account", "Auth'ta hesap yok");
  assert.equal(await join(db, "u4", { dev: "xyz" }), "invalid");
  assert.equal(await join(db, "u5", { src: "hack" }), "invalid");
  assert.equal(await join(db, "u6", { code: "abc234" }), "invalid");
  assert.equal("referrals/r_alice" in db.store, false);
});

test("bir cihaz bir davet: aynı telefonda ikinci hesap sayılmaz", async () => {
  const db = fakeDb(world());
  assert.equal(await join(db, "bob", { dev: DEV("b") }), "ok");
  assert.equal(await join(db, "bob2", { dev: DEV("b") }), "device_used");
  assert.equal(db.store["referrals/r_alice"].joined, 1);
  assert.equal("users/bob2/mail/ref_welcome" in db.store, false);
});

test("davet edenin kendi telefonu (ref_owner) sayılmaz", async () => {
  const db = fakeDb(world({ "users/alice/referral/ref_owner": { dev: DEV("c"), at: 1 } }));
  assert.equal(await join(db, "alt", { dev: DEV("c") }), "self");
  assert.equal(await join(db, "bob", { dev: DEV("d") }), "ok");
});

test("yasaklı davet eden: ödül yok; yasak bitmişse geçer", async () => {
  const db = fakeDb(world({ "moderation/m_alice": { ban: { kind: "social", until: 0 } } }));
  assert.equal(await join(db, "bob"), "banned");
  const db2 = fakeDb(world({ "moderation/m_alice": { ban: { kind: "full", until: NOW_S - 10 } } }));
  assert.equal(await join(db2, "bob"), "ok");
});

test("3. seviye: davet sayılır, 1. basamağın postası davet edene", async () => {
  const db = fakeDb(world({ "garages/g_bob": { name: "Bobo" } }));
  await join(db, "bob");
  assert.equal(await lvl3(db, "bob"), "ok");
  assert.equal(db.store["referrals/r_alice"].count, 1);
  assert.equal(db.store["referrals/r_alice/invited/f_bob"].state, "qualified");
  assert.equal(db.store["referrals/r_alice/invited/f_bob"].tier, 1);
  const mail = db.store["users/alice/mail/ref_1"];
  assert.equal(mail.gems, TIERS[0].gems);
  assert.match(mail.title.tr, /^Bobo katıldı! 1\. davet ödülün$/);
  assert.equal(mail.friend, "bob");
  assert.equal(mail.referral, "tier_1");
  assert.equal(db.store["users/bob/referral/ref_lvl3"].status, "ok");
  // yeniden teslim: ikinci kez sayılmaz
  delete db.store["users/bob/referral/ref_lvl3"].status;
  assert.equal(await handleQualify({ db, uid: "bob", now: NOW }), "ok");
  assert.equal(db.store["referrals/r_alice"].count, 1);
});

test("seviye işareti katılmadan önce: bekler, katılınca sayılır", async () => {
  const db = fakeDb(world());
  db.store["users/bob/referral/ref_claim"] = { code: "ABC234", src: "play", dev: DEV("e"), at: NOW_S };
  assert.equal(await lvl3(db, "bob"), "wait");
  assert.equal(db.store["users/bob/referral/ref_lvl3"].status, undefined, "bekleyen işaretin sonucu yazılmaz");
  assert.equal(await handleJoin({ db, uid: "bob", now: NOW, createdMs: fresh }), "ok");
  assert.equal(db.store["referrals/r_alice"].count, 1);
  assert.ok(db.store["users/alice/mail/ref_1"]);
  assert.match(db.store["users/alice/mail/ref_1"].title.en, /^Invite reward #1 is here!$/, "adı olmayan arkadaş");
});

test("reddedilmiş davetin seviye işareti: no_claim", async () => {
  const db = fakeDb(world());
  await join(db, "bob", { code: "ZZZ999" });
  assert.equal(await lvl3(db, "bob"), "no_claim");
});

test("10 basamak: her arkadaşa kendi ödülü, 11. arkadaşta ödül yok", async () => {
  const db = fakeDb(world());
  for (let i = 1; i <= 11; i++) {
    const uid = `f${i}`;
    assert.equal(await join(db, uid, { dev: i.toString(16).padStart(64, "0") }), "ok");
    assert.equal(await lvl3(db, uid), "ok");
  }
  assert.equal(db.store["referrals/r_alice"].count, 11);
  assert.equal(db.store["referrals/r_alice"].joined, 11);
  for (let n = 1; n <= 10; n++) {
    const mail = db.store[`users/alice/mail/ref_${n}`];
    const tier = TIERS[n - 1];
    assert.equal(mail.gems, tier.gems || 0, `${n}. basamak elmas`);
    assert.equal(mail.money_min, tier.money_min || 0, `${n}. basamak gelir dakikası`);
    assert.deepEqual(mail.crates, tier.crates || {});
    assert.deepEqual(mail.decor, tier.decor || {});
    assert.equal(mail.frame, tier.frame);
    assert.equal(mail.choice, tier.choice);
  }
  assert.equal("users/alice/mail/ref_11" in db.store, false);
  assert.equal(db.store["referrals/r_alice/invited/f_f11"].tier, 0);
  assert.equal(db.store["users/alice/mail/ref_10"].choice, "legendary_car");
  assert.equal(db.store["users/alice/mail/ref_5"].frame, "inviter");
});

test("metinler beş dilde", () => {
  for (const [key, dict] of Object.entries(TEXT)) {
    for (const lang of ["tr", "en", "es", "de", "fr"]) assert.ok(dict[lang], `${key}.${lang}`);
  }
  const mail = tierMail(3, "", NOW_S);
  assert.equal(mail.title.de, "Deine 3. Einladungsbelohnung ist da!");
});

test("oyundaki tablo (ReferralRewards) sunucuyla aynı", () => {
  const gd = readFileSync(path.join(__dirname, "../../../gameplay/social/referral_rewards.gd"), "utf8");
  const block = gd.match(/const TIERS: Array\[Dictionary\] = (\[[\s\S]*?\n\])/);
  assert.ok(block, "TIERS bloğu bulunamadı");
  assert.deepEqual(JSON.parse(block[1]), TIERS);
  const num = (name) => Number(gd.match(new RegExp(`const ${name}: int = (\\d+)`))[1]);
  assert.equal(num("QUALIFY_LEVEL"), QUALIFY_LEVEL);
  assert.equal(num("WELCOME_GEMS"), WELCOME.gems);
  assert.equal(num("WELCOME_MONEY"), WELCOME.money);
});
