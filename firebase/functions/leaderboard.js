// HAFTALIK DRAG LİDER TABLOSU — saf mantık (index.js lbRun tetikleyicisine ve lbWeekly zamanlayıcısına bağlar;
// test/leaderboard.test.js sahte db / messaging ile sınar; yönetim paneli sabitleri admin/lib.mjs üzerinden aynen kullanır).
// Ayrıntı: docs/LIDER_TABLOSU.md.
//
// lb_runs/{wk}_{cls}_{uid}  oyuncunun o hafta o sınıftaki en iyi koşusu (yalnız sahibi yazar, firestore.rules doğrular)
// lb/{wk}_{cls}             DÜNYA özeti: {wk, cls, cc: "", count, hist, top, updated, paid?} (yalnız sunucu yazar, herkes okur)
// lb/{wk}_{cls}_{CC}        ÜLKE özeti (aynı biçim, cc = bayrak)
// lb_counted/{wk}_{cls}_{uid}  SUNUCUNUN DEFTERİ (istemciye kapalı): özetlere şu an hangi kaydın sayıldığı ({...satır, pushed}).
//   Özet her tetiklemede koşu belgesinin O ANKİ hâline eşitlenir (olayın taşıdığı eski kopyaya değil) ve defterle karşılaştırılır:
//   tetikleyici iki kez gelse (Cloud Functions en az bir kez teslim eder) ya da sırası karışsa da count / hist kaymaz. Reddedilen
//   kaydın silinmesi de defterden düşer (o kayıt hiç sayılmadıysa hiçbir şey eksilmez).
//   pushed: bu koşunun sahibinin bu hafta bu sınıfta GEÇTİĞİ için bildirim gönderilen arkadaşlar (çift başına haftada bir).
// users/{arkadaş}/lbnews/{wk}_{cls}_{uid}  "X seni geçti" haberi (OTO MANŞET; sahibi okur / siler)
// users/{uid}/mail/lb_{wk}_{cls}  haftalık ödül postası (mevcut posta biçimi; bildirimi mailPush gönderir)

const CLASSES = ["D", "C", "B", "A", "S"];
const TIERS = ["top3", "p10", "p50"];
const TOP_MAX = 50;
const TIME_MIN = 4;
const TIME_MAX = 30;
const BUCKETS_PER_SEC = 20;
const BATCH = 400;
// Ödül kademeleri (config/app.leaderboard.rewards yoksa). Kasa yalnız SATILAN kasalardan (vehicles/crates.json "crates").
const DEFAULT_REWARDS = { top3: { gems: 150, crate: "super_crate" }, p10: { gems: 50, crate: "sport_crate" }, p50: { gems: 15, crate: "" } };
const REWARD_GEMS_MAX = 1000;
// Zamanlayıcı her pazartesi ödenmemiş son iki haftaya bakar: bir tur kaçsa da (dağıtım / hata) ödül bir sonrakinde gider
const PAY_WEEKS_BACK = 2;
const PAY_SLACK = 20;
const ID_RE = /^([0-9]{1,6})_([DCBAS])_([A-Za-z0-9]{1,128})$/;
const CRATE_RE = /^[a-z0-9_]{0,40}$/;
const ENTRY_FIELDS = ["uid", "name", "av", "flag", "level", "car", "paint", "stage", "time", "at"];

/** Hile sınırı ({araç: en düşük kabul edilen sn}, tools/lb_limits.gd üretir) ve araç sınıfı ({araç: sınıf},
 *  test/gen_lb_classes.js üretir). Dosya yoksa boş: yalnız mutlak 4 sn tabanı geçerli. */
function loadJson(name) {
  try {
    return require(`./${name}`);
  } catch {
    return {};
  }
}
const LIMITS = loadJson("lb_limits.json");
const CAR_CLASSES = loadJson("lb_classes.json");

// --- Hafta (oyundaki Leaderboard.week_of ile aynı): Pazartesi 00:00 Türkiye (UTC+3, yaz saati yok) ---

/** unix sn → hafta numarası. Unix 0 Perşembe: (gün + 3) / 7 haftayı pazartesi döndürür. */
function weekOf(unixS) {
  const day = Math.floor((unixS + 10800) / 86400);
  return Math.floor((day + 3) / 7);
}

/** Haftanın başladığı an (Pazartesi 00:00 TR) unix sn. */
function weekStart(wk) {
  return (wk * 7 - 3) * 86400 - 10800;
}

/** "2965_A_uid" → {wk, cls, uid}; geçersizse null. */
function parseId(id) {
  const m = ID_RE.exec(String(id || ""));
  return m ? { wk: Number(m[1]), cls: m[2], uid: m[3] } : null;
}

const bucketOf = (time) => String(Math.floor(time * BUCKETS_PER_SEC));
const summaryId = (wk, cls, cc = "") => (cc ? `${wk}_${cls}_${cc}` : `${wk}_${cls}`);
const str = (v, max) => (typeof v === "string" ? v.slice(0, max) : "");
const intOf = (v) => (Number.isFinite(Number(v)) ? Math.trunc(Number(v)) : 0);

/** Özete giren satır (koşu kaydı `run` HİÇBİR ZAMAN özete girmez: İZLE onu lb_runs'tan tek belge olarak okur). */
function entryOf(run, uid) {
  return {
    uid,
    name: str(run.name, 16),
    av: str(run.av, 40),
    flag: /^[A-Z]{2}$/.test(run.flag) ? run.flag : "",
    level: intOf(run.level),
    car: str(run.car, 40),
    paint: str(run.paint, 7),
    stage: intOf(run.stage),
    time: Number(run.time),
    at: intOf(run.at),
  };
}

/**
 * Koşu geçerli mi: "" ya da ret sebebi. Kural zaten biçimi denetler; burada yalnız sunucunun bildiği sınırlar:
 * kimlikle tutarlılık, 4–30 sn, aracın hile sınırı (lb_limits.json; listede olmayan araçta yalnız 4 sn tabanı) ve sınıf
 * (lb_classes.json; listede olmayan araçta denetlenmez).
 */
function checkRun(run, parsed, limits = LIMITS, classes = CAR_CLASSES) {
  if (!run || !parsed) return "missing";
  if (run.uid !== parsed.uid || run.wk !== parsed.wk || run.cls !== parsed.cls) return "id";
  const time = run.time;
  if (typeof time !== "number" || !Number.isFinite(time) || time < TIME_MIN || time > TIME_MAX) return "time";
  const car = String(run.car || "");
  if (Object.hasOwn(limits, car) && time < Number(limits[car])) return "limit";
  if (Object.hasOwn(classes, car) && classes[car] !== parsed.cls) return "class";
  return "";
}

/** Sıralama: süre, eşitlikte UID (Firestore sorgusunun belge adına göre sırasıyla aynı: {wk}_{cls}_ öneki ortak). */
const byTime = (a, b) => a.time - b.time || (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0);

const sameEntry = (a, b) => !!a && !!b && ENTRY_FIELDS.every((k) => a[k] === b[k]);

/** Defterdeki satır (pushed ve sunucu alanları çıkarılmış). */
function counted(marker) {
  if (!marker || typeof marker.time !== "number") return null;
  const out = {};
  for (const k of ENTRY_FIELDS) out[k] = marker[k];
  return out;
}

/** Özetin süre sırasına göre ilk TOP_MAX satırı için sorgu (dünya ya da ülke). */
function topQuery(db, wk, cls, cc) {
  let q = db.collection("lb_runs").where("wk", "==", wk).where("cls", "==", cls);
  if (cc) q = q.where("flag", "==", cc);
  // Yalnız satır alanları (+ doğrulama için wk / cls): koşu kaydı run okunmaz
  return q.orderBy("time").limit(TOP_MAX).select(...ENTRY_FIELDS, "wk", "cls");
}

/**
 * Tek özet belgesinin yeni hâli. sum: mevcut belge (yoksa null); prev / next: bu özette sayılan eski / yeni satır (yoksa null);
 * uid: değişen oyuncu. Dönüş: {doc, refill}: refill = top eksik kaldı, sorguyla yeniden doldurulmalı.
 */
function nextSummary(sum, { wk, cls, cc, uid, prev, next, nowS }) {
  const doc = { ...(sum || {}), wk, cls, cc };
  const hist = { ...(sum && sum.hist && typeof sum.hist === "object" ? sum.hist : {}) };
  let count = Math.max(0, intOf(sum && sum.count));
  if (prev) {
    const b = bucketOf(prev.time);
    const n = intOf(hist[b]) - 1;
    if (n > 0) hist[b] = n;
    else delete hist[b];
    count = Math.max(0, count - 1);
  }
  if (next) {
    const b = bucketOf(next.time);
    hist[b] = intOf(hist[b]) + 1;
    count += 1;
  }
  const oldTop = Array.isArray(sum && sum.top) ? sum.top : [];
  const wasIn = oldTop.some((e) => e && e.uid === uid);
  let top = oldTop.filter((e) => e && e.uid !== uid);
  if (next) top.push(next);
  top.sort(byTime);
  top = top.slice(0, TOP_MAX);
  // Oyuncu listedeydi ve kaydı kötüleşti / silindi: aradaki oyuncular bilinmiyor. Liste sayıdan kısaysa da (eski hata) sorgu.
  const worsened = wasIn && (!next || (prev && next.time > prev.time));
  const refill = top.length < Math.min(count, TOP_MAX) || (worsened && count > top.length);
  Object.assign(doc, { count, hist, top, updated: nowS });
  return { doc, refill };
}

/**
 * Koşu belgesinin şimdiki hâlini özetlere işler (TEK İŞLEM). Dönüş: {changed, prev, next}: prev / next = önceki ve şimdiki
 * sayılan satır. hint: olayın önceki / sonraki belgesindeki bayraklar (defter yokken hangi ülke özetinin temizleneceği).
 */
async function syncSummaries({ db, id, parsed, now, limits, classes, hintFlags = [] }) {
  const nowS = Math.floor(now / 1000);
  const { wk, cls, uid } = parsed;
  const runRef = db.doc(`lb_runs/${id}`);
  const markerRef = db.doc(`lb_counted/${id}`);
  return db.runTransaction(async (t) => {
    const [runSnap, markerSnap] = [await t.get(runRef), await t.get(markerRef)];
    const run = runSnap.exists ? runSnap.data() : null;
    const marker = markerSnap.exists ? markerSnap.data() || {} : null;
    const prev = counted(marker);
    const next = run && !checkRun(run, parsed, limits, classes) ? entryOf(run, uid) : null;
    if (sameEntry(prev, next)) return { changed: false, prev, next };
    // Etkilenen özetler: dünya + eski / yeni ülke; defter yoksa (hiç sayılmamış) olayın bayrakları: listeden düşürmek için
    const flags = new Set([prev && prev.flag, next && next.flag, ...(prev || next ? [] : hintFlags)].filter(Boolean));
    const scopes = ["", ...flags];
    const refs = scopes.map((cc) => db.doc(`lb/${summaryId(wk, cls, cc)}`));
    const snaps = [];
    for (const ref of refs) snaps.push(await t.get(ref));
    const writes = [];
    for (let i = 0; i < scopes.length; i++) {
      const cc = scopes[i];
      const sum = snaps[i].exists ? snaps[i].data() : null;
      const inPrev = prev && (cc === "" || prev.flag === cc) ? prev : null;
      const inNext = next && (cc === "" || next.flag === cc) ? next : null;
      if (!inPrev && !inNext) {
        // Hiç sayılmamış kayıt (reddedilmiş / defter silinmiş): yalnız listede kaldıysa düşer
        if (!sum || !Array.isArray(sum.top) || !sum.top.some((e) => e && e.uid === uid)) continue;
      }
      const { doc, refill } = nextSummary(sum, { wk, cls, cc, uid, prev: inPrev, next: inNext, nowS });
      if (refill) {
        const q = await t.get(topQuery(db, wk, cls, cc));
        const fresh = [];
        for (const d of q.docs) {
          const p = parseId(d.id);
          const data = d.data();
          if (!p || p.uid === uid || checkRun(data, p, limits, classes)) continue;
          fresh.push(entryOf(data, p.uid));
        }
        if (inNext) fresh.push(inNext);
        fresh.sort(byTime);
        doc.top = fresh.slice(0, TOP_MAX);
        if (q.docs.length < TOP_MAX) {
          // Sorgu bütün kayıtları getirdi: sayı ve kovalar kesin bilinir (eski bir kayma varsa burada düzelir)
          doc.count = fresh.length;
          doc.hist = {};
          for (const e of fresh) doc.hist[bucketOf(e.time)] = intOf(doc.hist[bucketOf(e.time)]) + 1;
        }
      }
      writes.push([refs[i], doc]);
    }
    for (const [ref, doc] of writes) t.set(ref, doc);
    if (next) t.set(markerRef, { ...next, wk, cls, pushed: Array.isArray(marker && marker.pushed) ? marker.pushed : [] });
    else if (marker) t.delete(markerRef);
    return { changed: !!(next || marker || writes.length), prev, next };
  });
}

// --- Arkadaş geçti -------------------------------------------------------------------------------------------------

const PUSH_TEXT = {
  tr: "{name} seni {cls} sınıfı haftalık tablosunda geçti! ({time} sn) 🏁",
  en: "{name} passed you on the class {cls} weekly board! ({time} s) 🏁",
  es: "¡{name} te superó en la tabla semanal de la clase {cls}! ({time} s) 🏁",
  de: "{name} hat dich in der Wochentabelle der Klasse {cls} überholt! ({time} s) 🏁",
  fr: "{name} t'a dépassé au classement hebdo de la classe {cls} ! ({time} s) 🏁",
};

/** Alıcının dilinde bildirim (bilinmeyen dil → İngilizce; news.js ile aynı seçim). Süre oyundaki gibi iki ondalık. */
function overtakeMessage(lang, name, cls, time) {
  const t = typeof lang === "string" && Object.hasOwn(PUSH_TEXT, lang) ? PUSH_TEXT[lang] : PUSH_TEXT.en;
  return { title: "AUTO YARD", body: t.replace("{name}", String(name || "").slice(0, 16)).replace("{cls}", cls)
    .replace("{time}", Number(time).toFixed(2)) };
}

/** Eski süreden hızlı olup yeni süreden yavaş kalan arkadaşlar (oldTime yoksa Infinity: tabloya yeni giren). */
function overtaken(friendRuns, oldTime, newTime) {
  return friendRuns.filter((r) => typeof r.time === "number" && r.time < oldTime && r.time > newTime);
}

/**
 * Kayıt iyileşince: arkadaş listesi (users/{uid}/friends, kimlik f_{diğer}) okunur, her arkadaşın bu haftanın bu sınıftaki
 * koşusu (lb_runs/{wk}_{cls}_{diğer}) okunur. Önceden öndeyken artık geride kalana lbnews yazılır (her geçişte güncellenir) ve
 * çift başına haftada BİR bildirim gider: gönderilenler koşunun defterinde (lb_counted.pushed); jetonu olmayan / YARIŞ
 * HABERLERİ'ni kapatmış / FCM'nin reddettiği alıcı hak tüketmez (news.js ile aynı ilke). Dönüş: {news, pushed}.
 */
async function notifyOvertaken({ db, messaging, id, parsed, entry, oldTime, now }) {
  const { wk, cls, uid } = parsed;
  const friendsSnap = await db.collection(`users/${uid}/friends`).get();
  const friends = friendsSnap.docs.map((d) => d.id).filter((fid) => fid.startsWith("f_")).map((fid) => fid.slice(2))
    .filter((f) => f && f !== uid && /^[A-Za-z0-9]{1,128}$/.test(f));
  if (!friends.length) return { news: 0, pushed: 0 };
  const runSnaps = await db.getAll(...friends.map((f) => db.doc(`lb_runs/${wk}_${cls}_${f}`)));
  const runs = [];
  runSnaps.forEach((s, i) => {
    if (s.exists) runs.push({ uid: friends[i], time: Number((s.data() || {}).time) });
  });
  const passed = overtaken(runs, oldTime, entry.time);
  if (!passed.length) return { news: 0, pushed: 0 };
  const nowS = Math.floor(now / 1000);
  await Promise.all(passed.map((f) => db.doc(`users/${f.uid}/lbnews/${wk}_${cls}_${uid}`).set({
    uid, name: entry.name, av: entry.av, car: entry.car, time: entry.time, my_time: f.time, cls, wk, at: nowS,
  })));
  // Bildirim: önce jeton / tercih (hak tüketmeyen durumlar), sonra defterde işlemle ayrılır
  const tokenSnaps = await db.getAll(...passed.map((f) => db.doc(`push/p_${f.uid}`)));
  const sendable = [];
  tokenSnaps.forEach((s, i) => {
    const { token, lang, prefs } = s.exists ? s.data() || {} : {};
    if (token && !(prefs && prefs.race === false)) sendable.push({ uid: passed[i].uid, token, lang });
  });
  if (!sendable.length) return { news: passed.length, pushed: 0 };
  const markerRef = db.doc(`lb_counted/${id}`);
  const reserved = await db.runTransaction(async (t) => {
    const snap = await t.get(markerRef);
    if (!snap.exists) return [];   // kayıt bu arada silindi
    const pushed = Array.isArray(snap.data().pushed) ? snap.data().pushed : [];
    const fresh = sendable.filter((s) => !pushed.includes(s.uid));
    if (fresh.length) t.update(markerRef, { pushed: [...pushed, ...fresh.map((s) => s.uid)] });
    return fresh;
  });
  let sent = 0;
  const failed = [];
  for (const r of reserved) {
    const text = overtakeMessage(r.lang, entry.name, cls, entry.time);
    try {
      await messaging.send({
        token: r.token,
        notification: text,
        android: { priority: "high", notification: { tag: `lb_${cls}`, icon: "icon_monochrome", color: "#F5BE4C" } },
        // FCM ayrılmış anahtarları ("from", "message_type", "google." / "gcm.") kullanma: news.js notu. Değerler metin.
        data: { type: "lb", wk: String(wk), cls, sender: uid },
      });
      sent++;
    } catch (e) {
      failed.push(r.uid);
      const code = e && e.code;
      if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
        await db.doc(`push/p_${r.uid}`).delete();
      } else {
        console.error(`lbRun push: ${code || ""} ${e && e.message ? e.message : e}`);
      }
    }
  }
  if (failed.length) {
    // Gitmeyen bildirim hak tüketmez: defterden geri alınır
    await db.runTransaction(async (t) => {
      const snap = await t.get(markerRef);
      if (!snap.exists) return;
      const pushed = Array.isArray(snap.data().pushed) ? snap.data().pushed : [];
      t.update(markerRef, { pushed: pushed.filter((p) => !failed.includes(p)) });
    });
  }
  return { news: passed.length, pushed: sent };
}

/**
 * lbRun: lb_runs/{id} yazıldı / silindi. Dönüş (günlük için): "skip" | "rejected:<sebep>" | "same" | "synced" | "improved …".
 * db: Firestore (yönetici) benzeri {doc, collection(...).where().orderBy().limit(), getAll, runTransaction(t: get(ref |
 * sorgu), set, update, delete)}; messaging: {send}; limits / classes: test için (varsayılan JSON dosyaları).
 */
async function handleRunWritten({ db, messaging, id, before, after, now, limits = LIMITS, classes = CAR_CLASSES }) {
  const parsed = parseId(id);
  if (!parsed) return "skip";
  if (after) {
    const reason = checkRun(after, parsed, limits, classes);
    if (reason) {
      // Hile sınırı / sınıf / biçim: belge silinir; silme olayı özeti defterden düzeltir (sayılmadıysa bir şey eksilmez)
      await db.doc(`lb_runs/${id}`).delete();
      console.log(`lbRun: reddedildi ${reason} ${id} araç=${String(after.car || "").slice(0, 40)} süre=${after.time}`
        + (reason === "limit" ? ` sınır=${limits[after.car]}` : ""));
      return `rejected:${reason}`;
    }
  }
  const hintFlags = [before && before.flag, after && after.flag].filter((f) => typeof f === "string" && /^[A-Z]{2}$/.test(f));
  const { changed, prev, next } = await syncSummaries({ db, id, parsed, now, limits, classes, hintFlags });
  if (!changed) return "same";
  if (!next || (prev && !(next.time < prev.time))) return "synced";
  const result = await notifyOvertaken({ db, messaging, id, parsed, entry: next, oldTime: prev ? prev.time : Infinity, now });
  return `improved news=${result.news} pushed=${result.pushed}`;
}

// --- Haftalık ödül ---------------------------------------------------------------------------------------------------

/** config/app.leaderboard.rewards → üç kademe {gems 0–1000, crate}; eksik / bozuk alan varsayılandan. */
function rewardsFrom(config) {
  const src = config && config.leaderboard && typeof config.leaderboard === "object" && config.leaderboard.rewards
    && typeof config.leaderboard.rewards === "object" ? config.leaderboard.rewards : {};
  const out = {};
  for (const tier of TIERS) {
    const r = src[tier] && typeof src[tier] === "object" ? src[tier] : {};
    const d = DEFAULT_REWARDS[tier];
    const gems = Number.isInteger(r.gems) && r.gems >= 0 && r.gems <= REWARD_GEMS_MAX ? r.gems : d.gems;
    const crate = typeof r.crate === "string" && CRATE_RE.test(r.crate) ? r.crate : d.crate;
    out[tier] = { gems, crate };
  }
  return out;
}

/** Sıra → kademe ("" = ödülsüz). count: tablodaki oyuncu sayısı. Oyuncu yalnız en iyi kademesini alır. */
function tierFor(rank, count) {
  if (rank < 1 || rank > Math.ceil(count * 0.5)) return "";
  if (rank <= 3) return "top3";
  if (rank <= Math.ceil(count * 0.1)) return "p10";
  return "p50";
}

const MAIL_TITLE = {
  tr: "HAFTALIK DRAG TABLOSU · {cls} SINIFI",
  en: "WEEKLY DRAG BOARD · CLASS {cls}",
  es: "TABLA SEMANAL DE DRAG · CLASE {cls}",
  de: "WÖCHENTLICHE DRAG-TABELLE · KLASSE {cls}",
  fr: "CLASSEMENT DRAG HEBDO · CLASSE {cls}",
};
const MAIL_TEXT = {
  top3: {
    tr: "Geçen haftayı {rank}. bitirdin! Ödülün burada.",
    en: "You finished last week in place {rank}! Your reward is here.",
    es: "¡Terminaste la semana pasada en el puesto {rank}! Aquí tienes tu premio.",
    de: "Du hast letzte Woche Platz {rank} belegt! Hier ist deine Belohnung.",
    fr: "Tu as fini la semaine dernière à la place {rank} ! Voici ta récompense.",
  },
  p10: {
    tr: "Geçen hafta İLK %10'dasın ({rank}. sıra)! Ödülün burada.",
    en: "You made the TOP 10% last week (place {rank})! Your reward is here.",
    es: "¡Quedaste en el TOP 10 % la semana pasada (puesto {rank})! Aquí tienes tu premio.",
    de: "Du warst letzte Woche in den TOP 10 % (Platz {rank})! Hier ist deine Belohnung.",
    fr: "Tu étais dans le TOP 10 % la semaine dernière (place {rank}) ! Voici ta récompense.",
  },
  p50: {
    tr: "Geçen hafta İLK %50'desin ({rank}. sıra)! Ödülün burada.",
    en: "You made the TOP 50% last week (place {rank})! Your reward is here.",
    es: "¡Quedaste en el TOP 50 % la semana pasada (puesto {rank})! Aquí tienes tu premio.",
    de: "Du warst letzte Woche in den TOP 50 % (Platz {rank})! Hier ist deine Belohnung.",
    fr: "Tu étais dans le TOP 50 % la semaine dernière (place {rank}) ! Voici ta récompense.",
  },
};

/** Ödül postası (users/{uid}/mail/lb_{wk}_{cls}): panelin posta biçimi + oyunun kullanabileceği lb özeti. */
function rewardMail({ wk, cls, rank, count, tier, reward, nowS }) {
  const title = {};
  const text = {};
  for (const lang of Object.keys(MAIL_TITLE)) {
    title[lang] = MAIL_TITLE[lang].replace("{cls}", cls);
    text[lang] = MAIL_TEXT[tier][lang].replace("{rank}", String(rank));
  }
  return {
    title, text, from: "AUTO YARD",
    money: 0, gems: reward.gems, crates: reward.crate ? { [reward.crate]: 1 } : {}, decor: {},
    at: nowS, expires: 0, notify: true,
    lb: { wk, cls, rank, count, tier },
  };
}

/**
 * lbWeekly (Pazartesi 00:10 TR): geçen haftanın (ve kaçmış bir önceki haftanın) her sınıfı için DÜNYA özetine bakar; yoksa ya
 * da paid ise geçer. İlk ceil(count × 0.5) koşu süreye göre okunur, kademe tierFor ile; ödülü olan kademeye posta yazılır
 * (kimlik sabit: iki kez çalışsa da tek posta), sonda özete paid: true. db: {doc, collection, batch}. Dönüş: günlük özeti.
 */
async function payWeekly({ db, now, limits = LIMITS, classes = CAR_CLASSES }) {
  const nowS = Math.floor(now / 1000);
  const current = weekOf(nowS);
  const cfgSnap = await db.doc("config/app").get();
  const rewards = rewardsFrom(cfgSnap.exists ? cfgSnap.data() : {});
  const result = { week: current, paid: [], mails: 0 };
  for (let wk = current - PAY_WEEKS_BACK; wk < current; wk++) {
    for (const cls of CLASSES) {
      const ref = db.doc(`lb/${summaryId(wk, cls)}`);
      const snap = await ref.get();
      if (!snap.exists) continue;
      const sum = snap.data() || {};
      if (sum.paid === true) continue;
      const count = Math.max(0, intOf(sum.count));
      const limit = Math.ceil(count * 0.5);
      const mails = [];
      if (limit > 0) {
        // Biraz fazlası okunur: sınırı sonradan sıkılaşan (geçersiz) koşu atlanınca sıradaki ödülü alır
        const q = await db.collection("lb_runs").where("wk", "==", wk).where("cls", "==", cls).orderBy("time")
          .limit(limit + PAY_SLACK).select("uid", "wk", "cls", "time", "car").get();
        let rank = 0;
        for (const d of q.docs) {
          const p = parseId(d.id);
          if (!p || checkRun(d.data(), p, limits, classes)) continue;   // sınır sonradan sıkılaştıysa ödül yok, sıra kaymaz
          rank++;
          const tier = tierFor(rank, count);
          if (!tier) break;
          const reward = rewards[tier];
          if (!reward.gems && !reward.crate) continue;   // panelde bu kademe ödülsüz bırakıldı
          mails.push([p.uid, rewardMail({ wk, cls, rank, count, tier, reward, nowS })]);
        }
      }
      for (let i = 0; i < mails.length; i += BATCH) {
        const batch = db.batch();
        for (const [uid, mail] of mails.slice(i, i + BATCH)) batch.set(db.doc(`users/${uid}/mail/lb_${wk}_${cls}`), mail);
        await batch.commit();
      }
      await ref.update({ paid: true, paid_at: nowS, paid_count: mails.length });
      result.paid.push(`${wk}_${cls}:${mails.length}/${count}`);
      result.mails += mails.length;
    }
  }
  return result;
}

module.exports = {
  CLASSES, TIERS, TOP_MAX, TIME_MIN, TIME_MAX, DEFAULT_REWARDS, REWARD_GEMS_MAX, PAY_WEEKS_BACK, LIMITS, CAR_CLASSES,
  weekOf, weekStart, parseId, bucketOf, summaryId, entryOf, checkRun, nextSummary, syncSummaries, topQuery,
  overtakeMessage, overtaken, notifyOvertaken, handleRunWritten, rewardsFrom, tierFor, rewardMail, payWeekly,
};
