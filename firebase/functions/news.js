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
};

/** Bu yazma bildirim doğurur mu: belge var, gönderen kazandı ve yeni bir yarış (aynı belgenin başka alanı değişmedi). */
function shouldNotify(before, after) {
  if (!after || after.won !== true) return false;
  if (before && before.at === after.at) return false;
  return true;
}

/** Alıcının diline göre başlık + metin (bilinmeyen dil → İngilizce). Ad kuralla süzülmüş takma addır. */
function messageFor(lang, name, revenge) {
  const t = TEXT[lang] || TEXT.en;
  const safe = String(name || "").slice(0, 16);
  return { title: t.title, body: (revenge ? t.revenge : t.win).replace("{name}", safe) };
}

/**
 * Tek haber yazmasını işler. Dönüş: "skip" | "throttled" | "no-token" | "sent" | "stale".
 * db: Firestore (yönetici) benzeri {doc(path) → {get, set, delete}, runTransaction(fn)}; messaging: {send(msg)}.
 */
async function handleRaceNews({ db, messaging, recipient, sender, before, after, now }) {
  if (!shouldNotify(before, after) || !recipient || !sender || recipient === sender) return "skip";
  const logRef = db.doc(`push_log/l_${recipient}_${sender}`);
  const allowed = await db.runTransaction(async (t) => {
    const snap = await t.get(logRef);
    if (snap.exists && now - (snap.data().at || 0) < PAIR_INTERVAL_MS) return false;
    t.set(logRef, { at: now });
    return true;
  });
  if (!allowed) return "throttled";
  const tokenRef = db.doc(`push/p_${recipient}`);
  const tokenSnap = await tokenRef.get();
  if (!tokenSnap.exists) return "no-token";
  const { token, lang } = tokenSnap.data();
  if (!token) return "no-token";
  const text = messageFor(lang, after.name, after.revenge === true);
  try {
    await messaging.send({
      token,
      notification: { title: text.title, body: text.body },
      // Durum çubuğu ikonu: launcher'ın tek renkli sürümü (mipmap/icon_monochrome, export_presets adaptive_monochrome);
      // vermezsek renkli launcher ikonu beyaz kare görünür. Vurgu rengi HUD amberi.
      android: { priority: "high", notification: { tag: `race_${sender}`, icon: "icon_monochrome", color: "#F5BE4C" } },
      data: { type: "race", from: sender },
    });
    return "sent";
  } catch (e) {
    const code = e && e.code;
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      await tokenRef.delete();   // cihaz jetonu geçersiz (uygulama silindi / çıkış yapıldı)
      return "stale";
    }
    throw e;
  }
}

module.exports = { PAIR_INTERVAL_MS, shouldNotify, messageFor, handleRaceNews };
