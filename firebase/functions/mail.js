// POSTA BİLDİRİMİ — saf mantık (index.js tetikleyiciye bağlar; test/mail.test.js sahte db / messaging ile sınar).
//
// Yönetim paneli (firebase/admin) users/{uid}/mail/{id} belgesini yazınca alıcının telefonuna "Garajına hediye geldi!"
// bildirimi gider. Postanın kendisini oyun açılınca MailService okur; bildirim yalnızca haber verir. Gitmez:
//   • belgede notify: false (panel "bildirim gönderme" dedi)
//   • alıcının jetonu yok (bildirimleri açmamış) ya da prefs.gift false (AYARLAR → HEDİYELER kapalı)
// Aynı oyuncuya art arda gelen postalar telefonda tek bildirimde birleşir (tag "mail": yenisi eskisinin yerine geçer).
// Geçersiz jeton silinir (news.js ile aynı).

const TEXT = {
  tr: { title: "AUTO YARD", body: "🎁 Garajına hediye geldi! Almak için dokun", named: "🎁 {title} Almak için dokun" },
  en: { title: "AUTO YARD", body: "🎁 A gift arrived at your garage! Tap to claim it", named: "🎁 {title} Tap to claim it" },
  es: { title: "AUTO YARD", body: "🎁 ¡Llegó un regalo a tu taller! Toca para recogerlo", named: "🎁 {title} Toca para recogerlo" },
  de: { title: "AUTO YARD", body: "🎁 Ein Geschenk ist in deiner Garage angekommen! Tippe, um es abzuholen",
    named: "🎁 {title} Tippe, um es abzuholen" },
  fr: { title: "AUTO YARD", body: "🎁 Un cadeau est arrivé dans ton garage ! Touche pour le récupérer",
    named: "🎁 {title} Touche pour le récupérer" },
};

/** Dil sözlüğünden (ya da düz metinden) alıcının dilindeki metin; yoksa en, o da yoksa tr. */
function pick(value, lang) {
  if (typeof value === "string") return value;
  if (!value || typeof value !== "object") return "";
  for (const l of [lang, "en", "tr"]) {
    if (typeof l === "string" && Object.hasOwn(value, l) && typeof value[l] === "string" && value[l].trim()) return value[l].trim();
  }
  return "";
}

/** Alıcının diline göre başlık + metin. Postanın başlığı varsa metne girer (en çok 60 karakter, sonuna nokta). */
function messageFor(lang, mailTitle) {
  const t = typeof lang === "string" && Object.hasOwn(TEXT, lang) ? TEXT[lang] : TEXT.en;
  let title = pick(mailTitle, lang).replace(/\s+/g, " ").slice(0, 60);
  if (!title) return { title: t.title, body: t.body };
  if (!/[.!?…]$/.test(title)) title += "!";
  return { title: t.title, body: t.named.replace("{title}", title) };
}

/**
 * Yeni posta belgesini işler. Dönüş: "skip" | "no-token" | "muted" | "sent" | "stale".
 * db: Firestore (yönetici) benzeri {doc(path) → {get, delete}}; messaging: {send(msg)}.
 */
async function handleMailCreated({ db, messaging, uid, mail }) {
  if (!uid || !mail || mail.notify === false) return "skip";
  const tokenRef = db.doc(`push/p_${uid}`);
  const tokenSnap = await tokenRef.get();
  const { token, lang, prefs } = tokenSnap.exists ? tokenSnap.data() : {};
  if (!token) return "no-token";
  if (prefs && prefs.gift === false) return "muted";
  const text = messageFor(lang, mail.title);
  try {
    await messaging.send({
      token,
      notification: { title: text.title, body: text.body },
      android: { priority: "high", notification: { tag: "mail", icon: "icon_monochrome", color: "#F5BE4C" } },
      data: { type: "mail" },   // FCM ayrılmış anahtarları ("from" …) kullanma: news.js notu
    });
    return "sent";
  } catch (e) {
    const code = e && e.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      await tokenRef.delete();
      return "stale";
    }
    throw e;
  }
}

module.exports = { TEXT, pick, messageFor, handleMailCreated };
