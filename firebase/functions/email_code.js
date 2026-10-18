// E-POSTA KODUYLA GİRİŞ — saf mantık (index.js iki callable'a bağlar; test/email_code.test.js sahte db / auth / mail ile,
// test/email_e2e.mjs emülatörde sınar).
//
// Akış (2026-10-18): oyun emailCodeSend({email, lang}) → 6 haneli kod oyuncunun e-postasına gider (10 dk geçerli);
// emailCodeVerify({email, code}) → kod doğruysa Firebase ÖZEL JETONU döner, oyun signInWithCustomToken ile girer.
// AYNI E-POSTA = AYNI HESAP (kullanıcı kararı 2026-10-17): e-posta bir Google / Facebook hesabında kayıtlıysa o UID'nin
// jetonu verilir (ilerleme o hesaptadır); yoksa bu e-postayla yeni hesap açılır (e-postası doğrulanmış, giriş yolu yok).
// Kod e-postanın sahibi olduğunu kanıtladığı için hesabın e-postası "doğrulandı" işaretlenir: Firebase sonra aynı
// e-postalı Google girişini aynı hesaba bağlar, hesabın öteki yollarını SİLMEZ.
//
// Belgeler (istemciye kapalı — firestore.rules "başka her yol kapalı"; yalnız bu fonksiyon yönetici yetkisiyle yazar):
//   email_codes/{sha256(e-posta)}  {salt, hash, code_at, attempts, sends: [ms], at}  kod düz metin SAKLANMAZ
//   email_ips/{sha256(ip)}          {sends: [ms], at}                                 bir adresten kod bombası olmasın
// `at` = son gönderim (ms); cleanup.js ikisini de 1 saat sonra siler (gizlilik metni: "en geç 1 saat").

const crypto = require("node:crypto");

const CODE_TTL_MS = 10 * 60 * 1000;
const RESEND_MS = 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const MAX_SENDS_PER_HOUR = 5;
const MAX_IP_SENDS_PER_HOUR = 20;
const MAX_ATTEMPTS = 5;
const MAX_EMAIL_LENGTH = 254;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const MAIL = {
  tr: { subject: "Auto Yard giriş kodun: {code}", title: "Giriş kodun",
    body: "Auto Yard'a girmek için bu kodu oyuna yaz. Kod 10 dakika geçerli.",
    ignore: "Bu kodu sen istemediysen bu e-postayı yok sayabilirsin; hesabına kimse giremez." },
  en: { subject: "Your Auto Yard sign-in code: {code}", title: "Your sign-in code",
    body: "Enter this code in the game to sign in to Auto Yard. The code is valid for 10 minutes.",
    ignore: "If you didn't request this code, you can ignore this email; nobody can access your account." },
  es: { subject: "Tu código para entrar en Auto Yard: {code}", title: "Tu código de acceso",
    body: "Escribe este código en el juego para entrar en Auto Yard. El código es válido durante 10 minutos.",
    ignore: "Si no pediste este código, puedes ignorar este correo; nadie puede entrar en tu cuenta." },
  de: { subject: "Dein Anmeldecode für Auto Yard: {code}", title: "Dein Anmeldecode",
    body: "Gib diesen Code im Spiel ein, um dich bei Auto Yard anzumelden. Der Code ist 10 Minuten gültig.",
    ignore: "Wenn du diesen Code nicht angefordert hast, kannst du diese E-Mail ignorieren; niemand kann auf dein Konto zugreifen." },
  fr: { subject: "Ton code de connexion Auto Yard : {code}", title: "Ton code de connexion",
    body: "Saisis ce code dans le jeu pour te connecter à Auto Yard. Le code est valable 10 minutes.",
    ignore: "Si tu n'as pas demandé ce code, tu peux ignorer cet e-mail ; personne ne peut accéder à ton compte." },
};

/** Oyuncuya gösterilecek nedenle birlikte reddedilen istek; index.js HttpsError'a çevirir (details.reason). */
class CodeError extends Error {
  constructor(status, reason, extra = {}) {
    super(reason);
    this.status = status;   // HttpsError kodu: invalid-argument, resource-exhausted, failed-precondition, internal
    this.reason = reason;
    this.extra = extra;
  }
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function isValidEmail(email) {
  return email.length <= MAX_EMAIL_LENGTH && EMAIL_RE.test(email);
}

/**
 * İsteği yapan adres (yalnızca gönderim sınırı için; özeti saklanır). X-Forwarded-For'un SON öğesi: Cloud Run'ın
 * ön ucu bağlanan adresi listenin sonuna ekler. İlk öğeler istemcinin kendi yazdığı başlıktan gelir: ilk öğe
 * alınsaydı her istekte başka bir uydurma adres yazılarak adres başına sınır (saatte 20) hiç dolmazdı.
 */
function clientIp(headers, fallback) {
  const parts = String((headers && headers["x-forwarded-for"]) || "").split(",").map((s) => s.trim()).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : String(fallback || "");
}

const sha256 = (text) => crypto.createHash("sha256").update(text).digest("hex");
const codeHash = (salt, code) => sha256(salt + ":" + code);

/** Alıcının diline göre konu + düz metin + HTML (bilinmeyen dil → İngilizce). */
function mailFor(lang, code) {
  const t = MAIL[lang] || MAIL.en;
  const subject = t.subject.replace("{code}", code);
  const text = `${t.title}: ${code}\n\n${t.body}\n\n${t.ignore}\n\nAuto Yard · https://autoyard.online`;
  const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1f2a44">`
    + `<p style="font-size:13px;font-weight:bold;letter-spacing:2px;color:#f28b1e;margin:0 0 16px">AUTO YARD</p>`
    + `<p style="font-size:16px;margin:0 0 8px">${t.title}</p>`
    + `<p style="font-size:36px;font-weight:bold;letter-spacing:8px;margin:0 0 16px">${code}</p>`
    + `<p style="font-size:14px;line-height:1.5;margin:0 0 12px">${t.body}</p>`
    + `<p style="font-size:12px;line-height:1.5;color:#6b7280;margin:0">${t.ignore}</p>`
    + `</div>`;
  return { subject, text, html };
}

/** Son bir saatteki gönderimler (eski kayıtlar düşer). */
const recent = (sends, now) => (Array.isArray(sends) ? sends : []).filter((t) => typeof t === "number" && now - t < HOUR_MS);

/**
 * Kod üretir, kaydeder (tuzlu özet), e-postayla yollar. Dönüş: {resend_after: sn}.
 * db: Firestore (yönetici) benzeri {doc(path), runTransaction(fn)}; mail: {send({to, subject, text, html})};
 * randomCode: test için sabit kod (varsayılan crypto.randomInt).
 */
async function sendCode({ db, mail, email, lang, ip, now, randomCode }) {
  email = normalizeEmail(email);
  if (!isValidEmail(email)) throw new CodeError("invalid-argument", "bad_email");
  const code = randomCode ? randomCode() : String(crypto.randomInt(0, 1000000)).padStart(6, "0");
  const salt = crypto.randomBytes(16).toString("hex");
  const codeRef = db.doc(`email_codes/${sha256(email)}`);
  const ipRef = db.doc(`email_ips/${sha256(String(ip || "?"))}`);
  await db.runTransaction(async (t) => {
    const [codeSnap, ipSnap] = [await t.get(codeRef), await t.get(ipRef)];
    const prev = codeSnap.exists ? codeSnap.data() : {};
    const sends = recent(prev.sends, now);
    const ipSends = recent(ipSnap.exists ? ipSnap.data().sends : [], now);
    const last = sends.length ? Math.max(...sends) : 0;
    if (last && now - last < RESEND_MS) {
      throw new CodeError("resource-exhausted", "cooldown", { retry_after: Math.ceil((RESEND_MS - (now - last)) / 1000) });
    }
    if (sends.length >= MAX_SENDS_PER_HOUR || ipSends.length >= MAX_IP_SENDS_PER_HOUR) {
      const oldest = Math.min(...(sends.length >= MAX_SENDS_PER_HOUR ? sends : ipSends));
      throw new CodeError("resource-exhausted", "too_many", { retry_after: Math.ceil((oldest + HOUR_MS - now) / 1000) });
    }
    t.set(codeRef, { salt, hash: codeHash(salt, code), code_at: now, attempts: 0, sends: [...sends, now], at: now });
    t.set(ipRef, { sends: [...ipSends, now], at: now });
  });
  try {
    await mail.send({ to: email, ...mailFor(lang, code) });
  } catch (e) {
    console.error(`emailCodeSend: e-posta gönderilemedi: ${e.message}`);
    await codeRef.set({ salt: "", hash: "" }, { merge: true });   // ulaşmayan kod geçerli kalmasın
    throw new CodeError("internal", "send_failed");
  }
  return { resend_after: RESEND_MS / 1000 };
}

/**
 * Kodu doğrular (tek kullanımlık, 10 dk, 5 deneme), e-postanın hesabını bulur ya da açar, özel jeton üretir.
 * Dönüş: {token, created}. auth: firebase-admin Auth benzeri {getUserByEmail, createUser, updateUser, createCustomToken}.
 */
async function verifyCode({ db, auth, email, code, now }) {
  email = normalizeEmail(email);
  code = String(code || "").trim();
  if (!isValidEmail(email)) throw new CodeError("invalid-argument", "bad_email");
  if (!/^\d{6}$/.test(code)) throw new CodeError("invalid-argument", "bad_code");
  const codeRef = db.doc(`email_codes/${sha256(email)}`);
  const verdict = await db.runTransaction(async (t) => {
    const snap = await t.get(codeRef);
    const doc = snap.exists ? snap.data() : {};
    if (!doc.hash) return { reason: "no_code" };
    const spent = { salt: "", hash: "", attempts: 0 };
    if (now - (doc.code_at || 0) > CODE_TTL_MS) {
      t.set(codeRef, spent, { merge: true });
      return { reason: "expired" };
    }
    const given = Buffer.from(codeHash(doc.salt, code), "hex");
    const stored = Buffer.from(String(doc.hash), "hex");
    if (given.length === stored.length && crypto.timingSafeEqual(given, stored)) {
      t.set(codeRef, spent, { merge: true });   // tek kullanımlık
      return { ok: true };
    }
    const attempts = (doc.attempts || 0) + 1;
    if (attempts >= MAX_ATTEMPTS) {
      t.set(codeRef, spent, { merge: true });
      return { reason: "too_many_attempts" };
    }
    t.set(codeRef, { attempts }, { merge: true });
    return { reason: "wrong_code", attempts_left: MAX_ATTEMPTS - attempts };
  });
  if (!verdict.ok) {
    const { reason, ...extra } = verdict;
    throw new CodeError(reason === "wrong_code" ? "invalid-argument" : "failed-precondition", reason, extra);
  }
  const { uid, created } = await userForEmail(auth, email);
  return { token: await auth.createCustomToken(uid), created };
}

/** E-postanın hesabı (Google / Facebook / önceki kodla açılmış); yoksa yeni hesap. Kapatılmış hesaba jeton verilmez. */
async function userForEmail(auth, email) {
  let user = null;
  try {
    user = await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
  }
  if (!user) {
    try {
      return { uid: (await auth.createUser({ email, emailVerified: true })).uid, created: true };
    } catch (e) {
      if (e.code !== "auth/email-already-exists") throw e;
      user = await auth.getUserByEmail(email);   // aynı anda iki doğrulama
    }
  }
  if (user.disabled) throw new CodeError("permission-denied", "disabled");
  if (!user.emailVerified) await auth.updateUser(user.uid, { emailVerified: true });
  return { uid: user.uid, created: false };
}

module.exports = {
  CODE_TTL_MS, RESEND_MS, HOUR_MS, MAX_SENDS_PER_HOUR, MAX_IP_SENDS_PER_HOUR, MAX_ATTEMPTS,
  CodeError, normalizeEmail, isValidEmail, mailFor, sendCode, verifyCode, sha256, clientIp,
};
