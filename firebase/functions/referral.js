// ARKADAŞ DAVETİ ÖDÜLÜ — saf mantık (index.js users/{uid}/referral/{ref_claim | ref_lvl3} tetikleyicilerine bağlar;
// test/referral.test.js sahte db ile sınar). Tasarım: docs/ARKADAS_DAVET.md.
//
// A arkadaş kodunu (codes/{KOD}) paylaşır. Yeni oyuncu B kodu Play yükleme kaynağından, linkten ya da elle alır:
//   1) B hesapla girince oyun users/{B}/referral/ref_claim = {code, src, dev, at} yazar (kural: bir kez) → handleJoin
//      doğrular: kod var, A ≠ B, B'nin hesabı JOIN_MAX_AGE_MS'den yeni, cihaz (dev = ANDROID_ID özeti) daha önce davetle
//      gelmemiş ve A'nın kendi cihazı değil (users/{A}/referral/ref_owner), A yasaklı değil. Geçerse tek işlemde:
//      ref_devices/{dev}, referrals/r_{A} (joined +1), referrals/r_{A}/invited/f_{B} (state joined), iki arkadaşlık belgesi
//      ve B'ye HOŞ GELDİN postası (users/{B}/mail/ref_welcome). Sonuç ref_claim'e yazılır: status + referrer.
//   2) B QUALIFY_LEVEL'a ulaşınca oyun users/{B}/referral/ref_lvl3 = {at} yazar → handleQualify tek işlemde: davet
//      "qualified", A'nın sayacı +1, sayaç TIERS içindeyse A'ya o basamağın postası (users/{A}/mail/ref_{n}).
//      ref_lvl3 katılmadan önce yazıldıysa (misafirken 3. seviyeyi geçti) katılma sonrası handleJoin sayar.
// Ödül posta ile gider: belge kimliği sabit (ref_welcome / ref_{n}), oyun alınan kimliği kayıtta tutar → iki kez verilmez.
// Sonuç durumları (ref_claim.status): ok · no_code · self · old_account · device_used · banned · already · invalid.
// Kimlikler / kodlar günlüğe yazılmaz (index.js yalnız durumu yazar).

const CODE_RE = /^[A-HJ-NP-Z2-9]{6}$/;
const UID_RE = /^[A-Za-z0-9_-]{1,128}$/;
const DEV_RE = /^[0-9a-f]{64}$/;
const SOURCES = ["play", "link", "code"];
/** Yalnız bu süreden yeni hesap davetle gelebilir (eski hesaplar birbirini "davet" edemesin). */
const JOIN_MAX_AGE_MS = 7 * 24 * 3600 * 1000;
/** Davet edilen bu seviyeye ulaşınca davet sayılır (oyunda ReferralRewards.QUALIFY_LEVEL ile aynı). */
const QUALIFY_LEVEL = 3;

// ÖDÜL MERDİVENİ — n. arkadaş TIERS[n-1]. Oyundaki ReferralRewards.TIERS ile AYNI olmalı (test/referral.test.js
// karşılaştırır). money_min: oyuncunun o anki aktif gelirinin dakikası (oyun hesaplar, LoginLadder.money_for);
// frame: yalnız davetle açılan profil çerçevesi; choice: oyuncu seçer (legendary_car: SÜPER KASA havuzundan).
const TIERS = [
  { gems: 50 },
  { money_min: 12 },
  { crates: { sport_crate: 1 } },
  { gems: 75 },
  { decor: { referral_neon: 1 }, frame: "inviter" },
  { money_min: 30 },
  { crates: { prestige_crate: 1 } },
  { gems: 120 },
  { money_min: 45 },
  { choice: "legendary_car", frame: "envoy" },
];
/** Davetle gelenin hoş geldin hediyesi (katılınca). */
const WELCOME = { gems: 50, money: 5000 };

const LANGS = ["tr", "en", "es", "de", "fr"];
const TEXT = {
  welcomeTitle: { tr: "Davet hediyen!", en: "Your invite gift!", es: "¡Tu regalo de invitación!",
    de: "Dein Einladungsgeschenk!", fr: "Ton cadeau d'invitation !" },
  welcomeNamed: { tr: "{name} seni Auto Yard'a çağırdı. Hoş geldin usta!", en: "{name} invited you to Auto Yard. Welcome!",
    es: "{name} te invitó a Auto Yard. ¡Bienvenido!", de: "{name} hat dich zu Auto Yard eingeladen. Willkommen!",
    fr: "{name} t'a invité sur Auto Yard. Bienvenue !" },
  welcomePlain: { tr: "Bir arkadaşın seni Auto Yard'a çağırdı. Hoş geldin usta!",
    en: "A friend invited you to Auto Yard. Welcome!", es: "Un amigo te invitó a Auto Yard. ¡Bienvenido!",
    de: "Ein Freund hat dich zu Auto Yard eingeladen. Willkommen!", fr: "Un ami t'a invité sur Auto Yard. Bienvenue !" },
  tierNamed: { tr: "{name} katıldı! {n}. davet ödülün", en: "{name} joined! Invite reward #{n}",
    es: "¡{name} se unió! Recompensa de invitación n.º {n}", de: "{name} ist dabei! {n}. Einladungsbelohnung",
    fr: "{name} a rejoint le jeu ! Récompense d'invitation n° {n}" },
  tierPlain: { tr: "{n}. davet ödülün geldi!", en: "Invite reward #{n} is here!",
    es: "¡Llegó tu recompensa de invitación n.º {n}!", de: "Deine {n}. Einladungsbelohnung ist da!",
    fr: "Ta récompense d'invitation n° {n} est arrivée !" },
  tierText: { tr: "Davet ettiğin arkadaşın oyuna katıldı ve 3. seviyeye ulaştı. Teşekkürler!",
    en: "The friend you invited joined the game and reached level 3. Thanks!",
    es: "El amigo que invitaste se unió al juego y llegó al nivel 3. ¡Gracias!",
    de: "Dein eingeladener Freund spielt jetzt mit und hat Level 3 erreicht. Danke!",
    fr: "L'ami que tu as invité a rejoint le jeu et atteint le niveau 3. Merci !" },
};

/** Dil sözlüğü: {name} / {n} yerleştirilir. Ad yoksa adsız metin. */
function texts(named, plain, name, n) {
  const out = {};
  for (const lang of LANGS) {
    const base = name ? named[lang] : plain[lang];
    out[lang] = base.replace("{name}", name || "").replace("{n}", String(n || ""));
  }
  return out;
}

/** Oyuncunun açık garajındaki takma adı (yoksa boş). */
async function nameOf(db, uid) {
  const snap = await db.doc(`garages/g_${uid}`).get();
  const name = snap.exists ? (snap.data() || {}).name : "";
  return typeof name === "string" && name.length <= 16 ? name.trim() : "";
}

function welcomeMail(inviterName, nowS) {
  return {
    title: { ...TEXT.welcomeTitle },
    text: texts(TEXT.welcomeNamed, TEXT.welcomePlain, inviterName, 0),
    from: "AUTO YARD",
    money: WELCOME.money,
    gems: WELCOME.gems,
    crates: {},
    decor: {},
    at: nowS,
    expires: 0,
    notify: false,   // oyuncu o an oyunda (talebi oyun yazdı)
    referral: "welcome",
  };
}

/** n. basamağın postası (1 ≤ n ≤ TIERS.length). friend: sayılan arkadaşın UID'si (oyun penceresinde avatarı). */
function tierMail(n, friendName, nowS, friend = "") {
  const tier = TIERS[n - 1];
  return {
    title: texts(TEXT.tierNamed, TEXT.tierPlain, friendName, n),
    text: { ...TEXT.tierText },
    from: "AUTO YARD",
    money: 0,
    gems: tier.gems || 0,
    money_min: tier.money_min || 0,
    crates: { ...(tier.crates || {}) },
    decor: { ...(tier.decor || {}) },
    ...(tier.frame ? { frame: tier.frame } : {}),
    ...(tier.choice ? { choice: tier.choice } : {}),
    at: nowS,
    expires: 0,
    referral: `tier_${n}`,
    ...(friend ? { friend } : {}),
  };
}

/** Yönetim panelinin yasağı (moderation/m_{uid}.ban) şu an geçerli mi. */
function banned(doc, nowS) {
  const ban = doc && typeof doc.ban === "object" && doc.ban ? doc.ban : null;
  return !!ban && (ban.kind === "social" || ban.kind === "full") && (!ban.until || ban.until > nowS);
}

/**
 * Davet talebini işler. db: Firestore (yönetici) benzeri {doc(yol) → {get, set(v, opts)}, runTransaction(fn: t →
 * {get(ref), set(ref, v, opts), update(ref, v)})}; createdMs(uid): B'nin Auth hesabının oluşturulma anı (ms, yoksa 0).
 * Dönüş: status.
 */
async function handleJoin({ db, uid, now, createdMs }) {
  const nowS = Math.floor(now / 1000);
  if (!UID_RE.test(String(uid || ""))) return "skip";
  const claimRef = db.doc(`users/${uid}/referral/ref_claim`);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) return "skip";
  const claim = claimSnap.data() || {};
  // Olay iki kez teslim edilirse (tetikleyici en az bir kez çalışır) ilk sonuç korunur
  if (typeof claim.status === "string") return claim.status;
  const finish = async (status, extra = {}) => {
    await claimRef.set({ status, ...extra, done_at: nowS }, { merge: true });
    return status;
  };
  const code = String(claim.code || "");
  const dev = String(claim.dev || "");
  if (!CODE_RE.test(code) || !DEV_RE.test(dev) || !SOURCES.includes(claim.src)) return finish("invalid");
  const codeSnap = await db.doc(`codes/${code}`).get();
  const inviter = codeSnap.exists ? String((codeSnap.data() || {}).uid || "") : "";
  if (!UID_RE.test(inviter)) return finish("no_code");
  if (inviter === uid) return finish("self");
  const created = Number(await createdMs(uid)) || 0;
  if (!created || now - created > JOIN_MAX_AGE_MS) return finish("old_account");
  const mod = await db.doc(`moderation/m_${inviter}`).get();
  if (mod.exists && banned(mod.data(), nowS)) return finish("banned");
  const owner = await db.doc(`users/${inviter}/referral/ref_owner`).get();
  if (owner.exists && (owner.data() || {}).dev === dev) return finish("self");
  const inviterName = await nameOf(db, inviter);
  // Sonuç da işlemin içinde yazılır: aynı olay iki kez aynı anda çalışırsa ikincisi ilkinin "ok"unu "device_used" ile
  // ezmesin (işlem yeniden denenince talepteki sonucu görür ve dokunmaz)
  const status = await db.runTransaction(async (t) => {
    const devRef = db.doc(`ref_devices/${dev}`);
    const statsRef = db.doc(`referrals/r_${inviter}`);
    const entryRef = db.doc(`referrals/r_${inviter}/invited/f_${uid}`);
    const current = await t.get(claimRef);
    const [devSnap, statsSnap, entrySnap] = [await t.get(devRef), await t.get(statsRef), await t.get(entryRef)];
    const prior = current.exists ? (current.data() || {}).status : undefined;
    if (typeof prior === "string") return prior;
    const fail = devSnap.exists ? "device_used" : entrySnap.exists ? "already" : "";
    if (fail) {
      t.set(claimRef, { status: fail, done_at: nowS }, { merge: true });
      return fail;
    }
    const joined = statsSnap.exists && Number.isInteger((statsSnap.data() || {}).joined) ? statsSnap.data().joined : 0;
    t.set(devRef, { at: nowS });
    t.set(statsRef, { joined: joined + 1, at: nowS }, { merge: true });
    t.set(entryRef, { at: nowS, state: "joined", src: claim.src });
    // Otomatik arkadaşlık (kullanıcı kararı): kural istek / davet jetonu ister, yönetici yetkisi doğrudan yazar
    t.set(db.doc(`users/${inviter}/friends/f_${uid}`), { since: nowS });
    t.set(db.doc(`users/${uid}/friends/f_${inviter}`), { since: nowS });
    t.set(db.doc(`users/${uid}/mail/ref_welcome`), welcomeMail(inviterName, nowS));
    t.set(claimRef, { status: "ok", referrer: inviter, done_at: nowS }, { merge: true });
    return "ok";
  });
  if (status !== "ok") return status;
  // Seviye işareti katılmadan önce yazılmışsa (misafirken 3. seviyeyi geçti) davet şimdi sayılır
  const lvl = await db.doc(`users/${uid}/referral/ref_lvl3`).get();
  if (lvl.exists) await handleQualify({ db, uid, now });
  return "ok";
}

/**
 * Seviye işaretini işler (ref_lvl3). Davet katılmadıysa bekler (sonuç yazılmaz; katılınca handleJoin çağırır).
 * Dönüş: ok · wait · no_claim · skip.
 */
async function handleQualify({ db, uid, now }) {
  const nowS = Math.floor(now / 1000);
  if (!UID_RE.test(String(uid || ""))) return "skip";
  const lvlRef = db.doc(`users/${uid}/referral/ref_lvl3`);
  const lvlSnap = await lvlRef.get();
  if (!lvlSnap.exists) return "skip";
  if (typeof (lvlSnap.data() || {}).status === "string") return lvlSnap.data().status;
  const claimSnap = await db.doc(`users/${uid}/referral/ref_claim`).get();
  const claim = claimSnap.exists ? claimSnap.data() || {} : {};
  if (claim.status === undefined) return "wait";
  const inviter = String(claim.referrer || "");
  if (claim.status !== "ok" || !UID_RE.test(inviter)) {
    await lvlRef.set({ status: "no_claim", done_at: nowS }, { merge: true });
    return "no_claim";
  }
  const friendName = await nameOf(db, uid);
  const tier = await db.runTransaction(async (t) => {
    const statsRef = db.doc(`referrals/r_${inviter}`);
    const entryRef = db.doc(`referrals/r_${inviter}/invited/f_${uid}`);
    const [statsSnap, entrySnap] = [await t.get(statsRef), await t.get(entryRef)];
    if (!entrySnap.exists) return -1;
    const entry = entrySnap.data() || {};
    if (entry.state === "qualified") return Number(entry.tier) || 0;   // iki tetikleyici yarıştı: bir kez sayılır
    const count = (statsSnap.exists && Number.isInteger((statsSnap.data() || {}).count) ? statsSnap.data().count : 0) + 1;
    const n = count <= TIERS.length ? count : 0;   // 10'dan sonra ödül yok, sayaç artar
    t.update(entryRef, { state: "qualified", tier: n, q_at: nowS });
    t.set(statsRef, { count, at: nowS }, { merge: true });
    if (n > 0) t.set(db.doc(`users/${inviter}/mail/ref_${n}`), tierMail(n, friendName, nowS, uid));
    return n;
  });
  const status = tier < 0 ? "no_claim" : "ok";
  await lvlRef.set({ status, ...(tier > 0 ? { tier } : {}), done_at: nowS }, { merge: true });
  return status;
}

module.exports = {
  CODE_RE, DEV_RE, SOURCES, JOIN_MAX_AGE_MS, QUALIFY_LEVEL, TIERS, WELCOME, TEXT,
  welcomeMail, tierMail, handleJoin, handleQualify,
};
