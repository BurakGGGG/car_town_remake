// YARIŞ HABERİ BİLDİRİMİ — saf mantık (index.js tetikleyiciye bağlar; test/news.test.js sahte db / messaging ile sınar).
//
// Bir arkadaş users/{alıcı}/races/e_{gönderen} haberini yazınca (oyun: SocialManager._on_friend_race_finished) alıcının
// telefonuna bildirim gider — YALNIZCA gönderen kazandıysa ("A, B'nin aracını yendi"). Kullanıcı kuralı (2026-10-17):
// aynı gönderen → aynı alıcı çiftine 6 saatte EN ÇOK BİR bildirim. A→B (gider) · A→B tekrar (gitmez) · A→C (gider) ·
// C→B (gider). Sınır sunucuda (push_log/l_{alıcı}_{gönderen}, istemciye kapalı): uygulamayı değiştiren aşamaz.
// Cihaz jetonu ve dil: push/p_{alıcı} = {token, lang, at} (oyun ARKADAŞLAR → YARIŞ BİLDİRİMLERİ: AÇ ile yazar).

const PAIR_INTERVAL_MS = 6 * 60 * 60 * 1000;

const TEXT = {
  tr: { title: "AUTO YARD", win: "{name} yarışta aracını yendi! İntikam almak için dokun 🏁",
    revenge: "{name} intikamını aldı, aracını yendi! Rövanş için dokun 🏁" },
  en: { title: "AUTO YARD", win: "{name} beat your car in a race! Tap to get revenge 🏁",
    revenge: "{name} took revenge and beat your car! Tap for a rematch 🏁" },
  es: { title: "AUTO YARD", win: "¡{name} le ganó a tu coche en una carrera! Toca para vengarte 🏁",
    revenge: "¡{name} se vengó y le ganó a tu coche! Toca para la revancha 🏁" },
  de: { title: "AUTO YARD", win: "{name} hat dein Auto im Rennen geschlagen! Tippe für deine Rache 🏁",
    revenge: "{name} hat sich gerächt und dein Auto geschlagen! Tippe für die Revanche 🏁" },
  fr: { title: "AUTO YARD", win: "{name} a battu ta voiture en course\u00a0! Touche pour te venger 🏁",
    revenge: "{name} a pris sa revanche et battu ta voiture\u00a0! Touche pour une nouvelle manche 🏁" },
};

/** Bu yazma bildirim doğurur mu: belge var, gönderen kazandı ve yeni bir yarış (aynı belgenin başka alanı değişmedi). */
function shouldNotify(before, after) {
  if (!after || after.won !== true) return false;
  if (before && before.at === after.at) return false;
  return true;
}

/** Alıcının diline göre başlık + metin (bilinmeyen dil → İngilizce). Ad kuralla süzülmüş takma addır. */
function messageFor(lang, name, revenge) {
  const t = typeof lang === "string" && Object.hasOwn(TEXT, lang) ? TEXT[lang] : TEXT.en;   // "__proto__" yerleşik nesneyi döndürmesin
  const safe = String(name || "").slice(0, 16);
  return { title: t.title, body: (revenge ? t.revenge : t.win).replace("{name}", safe) };
}

/**
 * Tek haber yazmasını işler. Dönüş: "skip" | "throttled" | "no-token" | "sent" | "stale".
 * db: Firestore (yönetici) benzeri {doc(path) → {get, set, delete}, runTransaction(fn)}; messaging: {send(msg)}.
 * 6 saatlik hak YALNIZCA gönderilen bildirimle tükenir (2026-10-17 düzeltmesi): jetonu olmayan alıcı (bildirimi henüz
 * açmamış) ya da FCM'nin reddettiği gönderim hakkı yemez — yoksa oyuncu bildirimi açtıktan sonraki ilk yenilgiyi kaçırır.
 */
async function handleRaceNews({ db, messaging, recipient, sender, before, after, now }) {
  if (!shouldNotify(before, after) || !recipient || !sender || recipient === sender) return "skip";
  const tokenRef = db.doc(`push/p_${recipient}`);
  const tokenSnap = await tokenRef.get();
  const { token, lang } = tokenSnap.exists ? tokenSnap.data() : {};
  if (!token) return "no-token";
  const logRef = db.doc(`push_log/l_${recipient}_${sender}`);
  const reserved = await db.runTransaction(async (t) => {
    const snap = await t.get(logRef);
    if (snap.exists && now - (snap.data().at || 0) < PAIR_INTERVAL_MS) return null;
    t.set(logRef, { at: now });
    return { previous: snap.exists ? snap.data() : null };
  });
  if (!reserved) return "throttled";
  const text = messageFor(lang, after.name, after.revenge === true);
  try {
    await messaging.send({
      token,
      notification: { title: text.title, body: text.body },
      // Durum çubuğu ikonu: launcher'ın tek renkli sürümü (mipmap/icon_monochrome, export_presets adaptive_monochrome);
      // vermezsek renkli launcher ikonu beyaz kare görünür. Vurgu rengi HUD amberi.
      android: { priority: "high", notification: { tag: `race_${sender}`, icon: "icon_monochrome", color: "#F5BE4C" } },
      // Anahtar adlarına dikkat: FCM "from", "message_type", "google." / "gcm." ile başlayanları REDDEDER
      // ("Invalid data payload key: from" — 2026-10-17'de bildirimler bu yüzden hiç gitmedi).
      data: { type: "race", sender },
    });
    return "sent";
  } catch (e) {
    // Gitmeyen bildirim hakkı tüketmez: çift kaydı eski hâline döner.
    await (reserved.previous ? logRef.set(reserved.previous) : logRef.delete());
    const code = e && e.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      await tokenRef.delete();   // cihaz jetonu geçersiz (uygulama silindi / çıkış yapıldı)
      return "stale";
    }
    throw e;
  }
}

module.exports = { PAIR_INTERVAL_MS, shouldNotify, messageFor, handleRaceNews };
