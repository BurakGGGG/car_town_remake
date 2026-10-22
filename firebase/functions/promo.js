// KUPON KODU — saf mantık (index.js users/{uid}/redeem/{KOD} tetikleyicisine bağlar; test/promo.test.js sahte db ile sınar).
//
// Yönetim paneli promo/{KOD} = {title, reward: {money, gems, crates, decor}, max_uses (0 = sınırsız), uses, until (unix sn,
// 0 = süresiz), active} yazar (istemciye kapalı). Oyuncu kodu girer → oyun users/{uid}/redeem/{KOD} = {at} yazar (kural:
// sahibi, belge başına bir kez) → bu fonksiyon tek bir işlemde doğrular: kod var, açık, süresi dolmamış, bu hesap
// kullanmamış (promo/{KOD}/used/{uid}), kullanım sınırı dolmamış → used + uses+1 + ödül POSTASI (users/{uid}/mail/p_{kod}).
// Ödül böylece postanın güvenilir akışıyla gelir (iki kez alınamaz). Sonuç redeem belgesine yazılır, oyun oradan okur:
//   status: ok | not_found | inactive | expired | used_up | already | rate
// Yalnızca hesaplı oyuncu (misafirin UID'si yok). Kaba deneme sınırı: hesap başına saatte RATE_MAX kod.

const CODE_RE = /^[A-Z0-9]{4,16}$/;
const UID_RE = /^[A-Za-z0-9_-]{1,128}$/;
const RATE_MAX = 10;
const RATE_WINDOW_S = 60 * 60;

/** Kodun ödül postası (oyundaki MailService biçimi). */
function rewardMail(code, promo, nowS) {
  const r = promo.reward && typeof promo.reward === "object" ? promo.reward : {};
  const title = promo.title && typeof promo.title === "object" && Object.keys(promo.title).length
    ? promo.title : { tr: "Kupon ödülü", en: "Coupon reward" };
  return {
    title,
    text: { tr: `${code} kodunun ödülü.`, en: `Reward for code ${code}.` },
    from: "AUTO YARD",
    money: Number.isInteger(r.money) ? r.money : 0,
    gems: Number.isInteger(r.gems) ? r.gems : 0,
    crates: r.crates && typeof r.crates === "object" ? r.crates : {},
    decor: r.decor && typeof r.decor === "object" ? r.decor : {},
    at: nowS,
    expires: 0,
    notify: false,   // oyuncu o an oyunda: telefona ayrıca bildirim gerekmez
    promo: code,
  };
}

/**
 * Tek bir kod denemesini işler. db: Firestore (yönetici) benzeri {doc(yol) → {get, set(v, opts)}, collection(yol).where(alan,
 * ">", d).limit(n).get() → {size}, runTransaction(fn: t → {get(ref), set(ref, v), update(ref, v)})}. Dönüş: status.
 */
async function handleRedeem({ db, uid, code, now }) {
  const nowS = Math.floor(now / 1000);
  if (!UID_RE.test(String(uid || ""))) return "skip";
  const redeemRef = db.doc(`users/${uid}/redeem/${code}`);
  const finish = async (status, title) => {
    await redeemRef.set({ status, ...(title ? { title } : {}), done_at: nowS }, { merge: true });
    return status;
  };
  if (!CODE_RE.test(String(code || ""))) return finish("not_found");
  // Olay iki kez teslim edilirse (tetikleyici en az bir kez çalışır) ikinci çalışma ilk sonucu "already" ile ezmesin
  const prior = await redeemRef.get();
  if (prior.exists && typeof (prior.data() || {}).status === "string") return prior.data().status;
  // limit: saldırgan saatte binlerce kod belgesi yazarsa her tetikleme hepsini okumasın (okuma faturası ~n²)
  const recent = await db.collection(`users/${uid}/redeem`).where("at", ">", nowS - RATE_WINDOW_S).limit(RATE_MAX + 1).get();
  if (recent.size > RATE_MAX) return finish("rate");
  const promoRef = db.doc(`promo/${code}`);
  const usedRef = db.doc(`promo/${code}/used/${uid}`);
  const mailRef = db.doc(`users/${uid}/mail/p_${code.toLowerCase()}`);
  const result = await db.runTransaction(async (t) => {
    const promo = await t.get(promoRef);
    if (!promo.exists) return { status: "not_found" };
    const p = promo.data();
    if (p.active === false) return { status: "inactive" };
    if (p.until && p.until <= nowS) return { status: "expired" };
    const used = await t.get(usedRef);
    if (used.exists) return { status: "already" };
    const uses = Number.isInteger(p.uses) ? p.uses : 0;
    if (Number.isInteger(p.max_uses) && p.max_uses > 0 && uses >= p.max_uses) return { status: "used_up" };
    t.set(usedRef, { at: nowS });
    t.update(promoRef, { uses: uses + 1 });
    t.set(mailRef, rewardMail(code, p, nowS));
    return { status: "ok", title: p.title || null };
  });
  return finish(result.status, result.title);
}

module.exports = { CODE_RE, RATE_MAX, RATE_WINDOW_S, rewardMail, handleRedeem };
