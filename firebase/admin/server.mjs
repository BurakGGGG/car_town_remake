// AUTO YARD YÖNETİM PANELİ — YALNIZCA BU BİLGİSAYARDA çalışır (kullanıcı kararı 2026-10-21: internete açık yönetici kapısı
// yok; oyun ve site depoları herkese açık). http://127.0.0.1:4400 — başlarken terminale yazılan bağlantıyla açılır.
//
// Yetki: car-town-remake'in hizmet hesabı anahtarı (firebase/admin/service-account.json, git'e GİRMEZ; .gitignore). Panel
// varsayılan Google kimliğine (gcloud ADC) BİLEREK düşmez: bu makinede ADC başka bir projeye (unisec) bağlı; yanlış projeye
// yazmak sessiz olurdu. Anahtarın project_id'si car-town-remake değilse ya da dosya git'te izleniyorsa panel açılmaz.
//
// Güvenlik (yerel sunucu da saldırıya açıktır: tarayıcıdaki herhangi bir site localhost'a istek atabilir):
//   • yalnızca 127.0.0.1'de dinler; Host başlığı 127.0.0.1 / localhost değilse 403 (DNS rebinding)
//   • her açılışta yeni rastgele anahtar: API isteği x-admin-key başlığı ister (özel başlık → başka köken ön uçuşa takılır,
//     panel CORS izni vermez); bağlantıdaki anahtar #k= parçasında durur, sunucuya hiç gitmez
//   • Origin başlığı varsa panelin kendi kökeni olmalı; gövde en çok 64 KB JSON (haber kapağı yükleme: 2,2 MB, takvim 256 KB)
// Her gönderim admin_log koleksiyonuna yazılır (istemciye kapalı: firestore.rules "başka her yol kapalı").
//
// Başlatma: cd firebase/admin && npm install && npm start   (ayrıntı: README.md)
import http from "node:http";
import crypto from "node:crypto";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { createRequire } from "node:module";
import { getAuth } from "firebase-admin/auth";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import {
  PanelError, loadCatalog, buildInfo, buildMail, mailId, buildConfig, buildNews, classifyQuery, unpackSave, hasReward,
  statsFromSave, buildBan, banActive, moderatedName, groupReports, UID_PATTERN, BAN_REASONS, buildAdjust, buildRestore,
  buildPromo, PROMO_RE, buildSegment, matchSegment, buildLearning, buildEventsDoc, eventsOf, buildAds,
  buildNewsPost, newsId, NEWS_ID_RE, decodeNewsImage, STORAGE_OFF, bucketCandidates, isMissingBucket, storageUrl,
  buildNewsFeed, NEWS_FEED_DOC,
  lbQuery, lbRows, lbCuts, lbWeekLabel, lbParseId, lbRewardsFrom, buildLbRewards, LB_LIST_MAX, LB_FIELDS, LB_DEFAULT_REWARDS,
} from "./lib.mjs";

// Gecelik istatistiğin aynısı (functions/stats.js, saf mantık): panel anlık sayıları da onunla hesaplar
const { computeStats } = createRequire(import.meta.url)("../functions/stats.js");

// EMÜLATÖR (yalnız test: test/panel_e2e.mjs): FIRESTORE_EMULATOR_HOST tanımlıysa "demo-" projesi, anahtar istenmez, bildirim
// FCM'ye gitmez (_e2e_fcm koleksiyonuna yazılır). "demo-" projeleri ağa çıkmaz: canlı projeye dokunulamaz.
const EMULATOR = !!process.env.FIRESTORE_EMULATOR_HOST;
const PROJECT = EMULATOR ? "demo-cartown" : "car-town-remake";
const HOST = "127.0.0.1";
const PORT = Number(process.env.ADMIN_PORT || 4400);
const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = new URL("../../", import.meta.url);
const KEY = crypto.randomBytes(24).toString("base64url");
const BATCH = 400;
// İÇERİK PAKETLERİ: tools/live_pack/build_pack.sh buraya yazar (<kimlik>.pck + <kimlik>.json özet); panel Storage'a yükler.
const PACKS_DIR = resolve(HERE, "packs");
const BUCKET = "car-town-remake.firebasestorage.app";
const PACK_MAX = 64 * 1024 * 1024;

function die(message) {
  console.error("\n  PANEL AÇILMADI: " + message + "\n");
  process.exit(1);
}

// --- Yetki ---------------------------------------------------------------------------------

function loadServiceAccount() {
  const path = resolve(process.env.AUTOYARD_SA || resolve(HERE, "service-account.json"));
  if (!existsSync(path)) {
    die(`hizmet hesabı anahtarı yok (${path}).\n  Firebase konsolu → car-town-remake → Proje ayarları → Hizmet hesapları → ` +
      "Yeni özel anahtar oluştur; indirilen dosyayı firebase/admin/service-account.json olarak kaydet (README.md).");
  }
  let sa;
  try {
    sa = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    die("anahtar dosyası okunamadı (JSON değil)");
  }
  if (sa.project_id !== PROJECT) die(`anahtar "${sa.project_id}" projesine ait; yalnızca ${PROJECT} kabul edilir`);
  let tracked = false;
  try {
    execFileSync("git", ["ls-files", "--error-unmatch", path], { cwd: HERE, stdio: "ignore" });
    tracked = true;   // komut başarılı = dosya depoda
  } catch {
    // izlenmiyor (ya da git yok)
  }
  if (tracked) die("anahtar dosyası git'te İZLENİYOR. Depo herkese açık: dosyayı depodan çıkar (git rm --cached) ve anahtarı konsoldan iptal et.");
  return sa;
}

const sa = EMULATOR ? { client_email: "emülatör" } : loadServiceAccount();
initializeApp(EMULATOR ? { projectId: PROJECT } : { credential: cert(sa), projectId: PROJECT });
const db = getFirestore();
const auth = getAuth();
const fcm = EMULATOR ? {
  send: (msg) => db.collection("_e2e_fcm").add(msg),
  async sendEachForMulticast({ tokens, ...msg }) {
    for (const token of tokens) await db.collection("_e2e_fcm").add({ ...msg, token });
    return { successCount: tokens.length, failureCount: 0 };
  },
} : getMessaging();
const catalog = loadCatalog(REPO);

// FIREBASE STORAGE (haber kapağı). Kova adı keşfedilir: AUTOYARD_BUCKET ya da <proje>.firebasestorage.app, sonra
// <proje>.appspot.com; ilk başarılı yüklemenin kovası hatırlanır. Hiçbiri yoksa (Storage konsoldan açılmamış) STORAGE_OFF.
// EMÜLATÖR: Storage'a hiç gidilmez; kova yalnız _e2e_buckets/{ad} belgesi varsa "var" sayılır (test Storage'ı açmayı böyle
// taklit eder), yüklenen dosyanın yalnız özeti _e2e_storage'a yazılır.
const storage = EMULATOR ? {
  async save(bucket, path, data, opts) {
    if (!(await db.doc(`_e2e_buckets/${bucket}`).get()).exists) {
      throw Object.assign(new Error("The specified bucket does not exist."), { code: 404 });
    }
    await db.collection("_e2e_storage").add({ bucket, path, size: data.length, contentType: opts.metadata.contentType,
      token: opts.metadata.metadata.firebaseStorageDownloadTokens });
  },
} : { save: (bucket, path, data, opts) => getStorage().bucket(bucket).file(path).save(data, opts) };
let storageBucket = "";

// --- Yardımcılar -----------------------------------------------------------------------------

async function resolvePlayer(query) {
  const q = classifyQuery(query);
  if (q.kind === "code") {
    const snap = await db.doc(`codes/${q.value}`).get();
    if (!snap.exists) throw new PanelError(`"${q.value}" kodlu oyuncu yok`);
    return snap.data().uid;
  }
  if (q.kind === "email") {
    try {
      return (await auth.getUserByEmail(q.value)).uid;
    } catch {
      throw new PanelError(`"${q.value}" e-postalı hesap yok`);
    }
  }
  return q.value;
}

async function playerSummary(uid) {
  const [user, player, garage, push, mail, mod, note, reports] = await Promise.all([
    auth.getUser(uid).catch(() => null),
    db.doc(`players/${uid}`).get(),
    db.doc(`garages/g_${uid}`).get(),
    db.doc(`push/p_${uid}`).get(),
    db.collection(`users/${uid}/mail`).get(),
    db.doc(`moderation/m_${uid}`).get(),
    db.doc(`admin_notes/n_${uid}`).get(),
    db.collection("reports").where("target", "==", uid).count().get(),
  ]);
  if (!user && !player.exists) throw new PanelError("Bu UID'li hesap yok");
  const p = player.exists ? player.data() : {};
  const g = garage.exists ? garage.data() : {};
  // Eski sürümle yazılmış kayıtta stats yok: değerler kaydın kendisinden (açılamazsa boş kalır)
  let stats = p.stats || null;
  let statsFrom = stats ? "stats" : "";
  if (!stats && typeof p.save_json === "string") {
    try {
      stats = statsFromSave(unpackSave(p.save_json));
      statsFrom = stats ? "save" : "";
    } catch {
      stats = null;
    }
  }
  const t = push.exists ? push.data() : {};
  return {
    uid,
    email: user?.email || p.profile?.email || "",
    name: user?.displayName || p.profile?.display_name || "",
    providers: user ? user.providerData.map((x) => x.providerId) : [],
    disabled: !!user?.disabled,
    created: user?.metadata.creationTime || "",
    last_sign_in: user?.metadata.lastSignInTime || "",
    has_save: player.exists,
    stats,
    stats_from: statsFrom,
    save_updated_at: p.updated_at || 0,
    save_size: typeof p.save_json === "string" ? p.save_json.length : 0,
    garage: garage.exists ? { name: g.name, code: g.code, level: g.level, value: g.value } : null,
    push: push.exists ? { lang: t.lang, prefs: t.prefs || {}, at: t.at } : null,
    mail: mail.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => (b.at || 0) - (a.at || 0)),
    moderation: mod.exists ? { ...mod.data(), ban_active: banActive(mod.data().ban, Date.now()) } : null,
    note: note.exists ? note.data() : null,
    reports: reports.data().count,
  };
}

function checkUid(uid) {
  const s = String(uid || "");
  if (!UID_PATTERN.test(s)) throw new PanelError("Geçersiz UID");
  return s;
}

/** Hedefli gönderim: süzgece uyan hesapların UID'leri (bütün kayıtların özeti okunur: oyuncu sayısı kadar okuma). */
async function segmentUids(segment) {
  const seg = buildSegment(segment);
  const snap = await db.collection("players").select("stats", "updated_at").get();
  const now = Date.now();
  return snap.docs.filter((d) => matchSegment({ stats: d.get("stats"), updated_at: d.get("updated_at") }, seg, now)).map((d) => d.id);
}

/** Aynı postayı verilen hesaplara yazar (400'lük gruplar; aynı kimlik bir hesaba iki kez yazılmaz). */
async function fanOut(uids, id, doc) {
  for (let i = 0; i < uids.length; i += BATCH) {
    const batch = db.batch();
    for (const uid of uids.slice(i, i + BATCH)) batch.create(db.doc(`users/${uid}/mail/${id}`), doc);
    await batch.commit();
  }
}

/** Dosyayı Storage'a indirme anahtarıyla yazar, kullanılan kovayı döner. */
async function saveToStorage(path, data, { contentType, cacheControl, token }) {
  const names = storageBucket ? [storageBucket] : bucketCandidates(PROJECT, process.env.AUTOYARD_BUCKET);
  for (const name of names) {
    try {
      await storage.save(name, path, data, { resumable: false,
        metadata: { contentType, cacheControl, metadata: { firebaseStorageDownloadTokens: token } } });
      storageBucket = name;
      return name;
    } catch (e) {
      if (!isMissingBucket(e)) throw new PanelError(`Storage'a yüklenemedi (${String(e && e.message || e).slice(0, 200)})`);
    }
  }
  throw new PanelError(STORAGE_OFF);
}

/**
 * Haber değişikliği + oyunun okuduğu yayın (config/news) TEK İŞLEMDE: koleksiyon işlem içinde okunur, fn değişikliği
 * işleme yazar ve `docs` haritasını günceller, yayın haritadan kurulur. Yayın koleksiyondan hiç sapmaz.
 */
async function mutateNews(fn) {
  return db.runTransaction(async (tx) => {
    const now = Date.now();
    const snap = await tx.get(db.collection("news"));
    const docs = new Map(snap.docs.map((d) => [d.id, d.data()]));
    const result = fn(tx, docs, now);
    const feed = buildNewsFeed([...docs].map(([id, d]) => ({ id, ...d })), now);
    tx.set(db.doc(NEWS_FEED_DOC), feed);
    return { ...result, feed };
  });
}

async function log(entry) {
  await db.collection("admin_log").add({ ...entry, at: FieldValue.serverTimestamp() });
}

// --- API ---------------------------------------------------------------------------------------

const routes = {
  "GET /api/info": async () => {
    const build = buildInfo(readFileSync(new URL("export_presets.cfg", REPO), "utf8"));
    const players = (await db.collection("players").count().get()).data().count;
    return { project: PROJECT, build, players, catalog };
  },

  "GET /api/config": async () => {
    const snap = await db.doc("config/app").get();
    return { config: snap.exists ? snap.data() : null };
  },

  "POST /api/config": async (body) => {
    const doc = buildConfig(body, Date.now());
    // Etkinlik takvimi (+ aynası), içerik paketleri, reklam ayarı ve lider tablosu ödülleri kendi sekmelerinden yazılır
    // (POST /api/events, /api/ads, /api/lb/rewards):
    // burada olduğu gibi korunur. İşlem: eventsTick aynayı aynı anda ilerletirse eski ayna geri yazılmaz.
    const ref = db.doc("config/app");
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      const old = current.exists ? current.data() : {};
      for (const k of ["events", "event", "packs", "ads", "leaderboard"]) if (old[k] !== undefined) doc[k] = old[k];
      tx.set(ref, doc);
    });
    await log({ kind: "config", min_code: doc.min_code, latest_code: doc.latest_code, maintenance: doc.maintenance,
      notice: doc.notice ? doc.notice.id : "" });
    return { config: doc };
  },

  // --- Etkinlik takvimi + içerik paketleri (config/app.events, aynası config/app.event, packs; öbür alanlara dokunulmaz) ---
  // Takvim hiç kaydedilmemişse eski tek etkinlik listede görünür (ilk kayıtta takvime geçer).
  "GET /api/events": async () => {
    const snap = await db.doc("config/app").get();
    const c = snap.exists ? snap.data() : {};
    return { events: eventsOf(c), packs: c.packs || [], mirror: c.event ? c.event.id : "", now: Math.floor(Date.now() / 1000) };
  },

  // Bütün liste birlikte yazılır (panel her ekle / düzenle / sil / kopyala işleminde listenin tamamını gönderir)
  "POST /api/events": async (body) => {
    const ref = db.doc("config/app");
    const doc = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const next = buildEventsDoc(body, catalog, snap.exists ? snap.data() : {}, Date.now());
      tx.set(ref, next);
      return next;
    });
    const modules = (e) => Object.keys(e).filter((k) => ["sale", "crate_boost", "missions", "rival", "pack", "car"].includes(k)
      || (k.endsWith("_mult") && e[k] > 1)).join(",");
    await log({ kind: "events", count: doc.events.length, mirror: doc.event ? doc.event.id : "",
      events: doc.events.map((e) => `${e.id}(${modules(e) || "-"}${e.car ? ":" + e.car.id : ""}${e.notify ? ":bildirim" : ""})`).join(" "),
      packs: (doc.packs || []).map((p) => p.id).join(",") });
    return { events: doc.events, packs: doc.packs || [], mirror: doc.event ? doc.event.id : "", now: Math.floor(Date.now() / 1000) };
  },

  // --- Ödüllü reklam ayarları (config/app.ads; öbür alanlara dokunulmaz) ---
  "GET /api/ads": async () => {
    const snap = await db.doc("config/app").get();
    return { ads: snap.exists ? snap.data().ads || null : null };
  },

  "POST /api/ads": async (body) => {
    const ref = db.doc("config/app");
    const ads = body.reset ? null : buildAds(body);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const doc = { ...(snap.exists ? snap.data() : {}) };
      delete doc.ads;
      if (ads) doc.ads = ads;
      doc.updated_at = Math.floor(Date.now() / 1000);
      tx.set(ref, doc);
    });
    await log({ kind: "ads", reset: !ads, total_cap: ads ? ads.total_cap : 0, free_gems: ads ? ads.free_gems : 0 });
    return { ads };
  },

  // --- Haftalık drag lider tablosu (docs/LIDER_TABLOSU.md; özetleri functions/leaderboard.js lbRun tutar) ---
  // İlk 100 doğrudan lb_runs'tan (süreye göre; ülke seçiliyse bayrağa göre süzülür) + o haftanın özeti. Okuma: en çok 101 belge.
  // Bileşik dizin gerekir (firebase/firestore.indexes.json: wk + cls + time, wk + cls + flag + time).
  "POST /api/lb/list": async (body) => {
    const nowS = Math.floor(Date.now() / 1000);
    const q = lbQuery(body, nowS);
    let query = db.collection("lb_runs").where("wk", "==", q.wk).where("cls", "==", q.cls);
    if (q.cc) query = query.where("flag", "==", q.cc);
    const [snap, sumSnap] = await Promise.all([
      query.orderBy("time").limit(LB_LIST_MAX).select(...LB_FIELDS).get(),
      db.doc(`lb/${q.wk}_${q.cls}${q.cc ? "_" + q.cc : ""}`).get(),
    ]);
    const sum = sumSnap.exists ? sumSnap.data() : null;
    return {
      ...q, label: lbWeekLabel(q.wk),
      weeks: [0, 1, 2, 3].map((i) => ({ wk: q.current - i, label: lbWeekLabel(q.current - i) })),
      rows: lbRows(snap.docs.map((d) => ({ id: d.id, data: d.data() })), catalog),
      summary: sum ? { count: sum.count || 0, updated: sum.updated || 0, paid: sum.paid === true, paid_at: sum.paid_at || 0,
        paid_count: sum.paid_count || 0, top: Array.isArray(sum.top) ? sum.top.length : 0, ...lbCuts(sum.count) } : null,
    };
  },

  // Kayıt silme (hile / şikâyet): lbRun silmeyi görür, özetleri (sayı, kovalar, ilk 50) düzeltir
  "POST /api/lb/delete": async (body) => {
    const id = String(body.id || "");
    const parsed = lbParseId(id);
    if (!parsed) throw new PanelError("Geçersiz kayıt kimliği");
    const ref = db.doc(`lb_runs/${id}`);
    const snap = await ref.get();
    if (!snap.exists) throw new PanelError("Kayıt bulunamadı (silinmiş olabilir)");
    const d = snap.data();
    await ref.delete();
    await log({ kind: "lb_delete", id, uid: parsed.uid, wk: parsed.wk, cls: parsed.cls, name: String(d.name || "").slice(0, 16),
      car: String(d.car || ""), time: Number(d.time) || 0, flag: String(d.flag || "") });
    return { ok: true };
  },

  // Ödül ayarı (config/app.leaderboard.rewards; öbür alanlara dokunulmaz). Kayıtlı değilse functions'ın varsayılanı geçerli.
  "GET /api/lb/rewards": async () => {
    const snap = await db.doc("config/app").get();
    const c = snap.exists ? snap.data() : {};
    return { rewards: lbRewardsFrom(c), custom: !!(c.leaderboard && c.leaderboard.rewards), defaults: LB_DEFAULT_REWARDS };
  },

  "POST /api/lb/rewards": async (body) => {
    const rewards = body.reset ? null : buildLbRewards(body.rewards, catalog);
    const ref = db.doc("config/app");
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const doc = { ...(snap.exists ? snap.data() : {}) };
      const board = { ...(doc.leaderboard && typeof doc.leaderboard === "object" ? doc.leaderboard : {}) };
      delete board.rewards;
      if (rewards) board.rewards = rewards;
      if (Object.keys(board).length) doc.leaderboard = board;
      else delete doc.leaderboard;
      doc.updated_at = Math.floor(Date.now() / 1000);
      tx.set(ref, doc);
    });
    await log({ kind: "lb_rewards", reset: !rewards, rewards: rewards || null });
    return { rewards: rewards || LB_DEFAULT_REWARDS, custom: !!rewards, defaults: LB_DEFAULT_REWARDS };
  },

  // Bilgisayardaki kurulmuş paketler (build_pack.sh çıktısı): özet dosyası + .pck birlikte olmalı
  "GET /api/packs/local": async () => {
    if (!existsSync(PACKS_DIR)) return { packs: [] };
    const out = [];
    for (const name of readdirSync(PACKS_DIR).filter((n) => n.endsWith(".json")).sort()) {
      try {
        const meta = JSON.parse(readFileSync(resolve(PACKS_DIR, name), "utf8"));
        if (existsSync(resolve(PACKS_DIR, `${meta.id}.pck`))) out.push(meta);
      } catch {
        // bozuk özet dosyası: listelenmez
      }
    }
    return { packs: out };
  },

  // Paketi Firebase Storage'a yükler (indirme anahtarlı herkese açık adres); listeye ekleme + yayın formdan yapılır
  "POST /api/packs/upload": async (body) => {
    const id = String(body.id || "");
    if (!/^[a-z0-9_]{1,40}$/.test(id)) throw new PanelError("Paket kimliği geçersiz");
    const file = resolve(PACKS_DIR, `${id}.pck`);
    if (!existsSync(file)) throw new PanelError(`firebase/admin/packs/${id}.pck yok: önce tools/live_pack/build_pack.sh ${id}`);
    const data = readFileSync(file);
    if (data.length > PACK_MAX) throw new PanelError("Paket 64 MB'tan büyük");
    const sha256 = crypto.createHash("sha256").update(data).digest("hex");
    if (EMULATOR) throw new PanelError("Emülatörde Storage yok: canlı panelden yükle");
    const bucket = getStorage().bucket(BUCKET);
    const dest = `live_packs/${id}-${sha256.slice(0, 12)}.pck`;
    const token = crypto.randomUUID();
    try {
      await bucket.file(dest).save(data, { resumable: false, metadata: { contentType: "application/octet-stream",
        cacheControl: "public, max-age=31536000, immutable", metadata: { firebaseStorageDownloadTokens: token } } });
    } catch (e) {
      throw new PanelError(`Storage'a yüklenemedi (${e.message}). Firebase konsolu → Storage açık mı? Değilse paketi ` +
        "kendi sitende barındırıp 'Adresten ekle'yi kullan.");
    }
    const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(dest)}?alt=media&token=${token}`;
    await log({ kind: "pack_upload", id, size: data.length });
    return { pack: { id, url, sha256, size: data.length } };
  },

  // Başka yerde barındırılan paket: panel indirir, özeti ve boyutu hesaplar (elle yazılan özet hatası olmasın)
  "POST /api/packs/inspect": async (body) => {
    const url = String(body.url || "").trim();
    if (!/^https:\/\/[^\s]+$/.test(url)) throw new PanelError("Adres https:// ile başlamalı");
    const res = await fetch(url, { redirect: "follow" });
    if (!res.ok) throw new PanelError(`Paket indirilemedi (HTTP ${res.status})`);
    const data = Buffer.from(await res.arrayBuffer());
    if (!data.length || data.length > PACK_MAX) throw new PanelError("Paket boş ya da 64 MB'tan büyük");
    return { sha256: crypto.createHash("sha256").update(data).digest("hex"), size: data.length };
  },

  // --- HABERLER (news/{id}; oyun oturumsuz listeler, bildirimi functions/news_feed.js gönderir) ---
  // Liste + oyundaki yayının özeti (config/news: hangi haberler, ne zaman yazıldı)
  "GET /api/news": async () => {
    const [snap, feedSnap] = await Promise.all([db.collection("news").get(), db.doc(NEWS_FEED_DOC).get()]);
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }))
      .sort((a, b) => (b.at || 0) - (a.at || 0) || (a.id < b.id ? 1 : -1));
    const feed = feedSnap.exists ? feedSnap.data() : null;
    return { items, now: Math.floor(Date.now() / 1000),
      feed: feed ? { at: feed.at || 0, ids: (feed.items || []).map((i) => i.id) } : null };
  },

  // Yeni haber (id yok) ya da düzenleme (id var olan haber): at / pushed_at korunur; yayın (config/news) aynı işlemde yenilenir
  "POST /api/news/save": async (body) => {
    const editId = body.id ? String(body.id) : "";
    if (editId && !NEWS_ID_RE.test(editId)) throw new PanelError("Geçersiz haber kimliği");
    if (!editId) {
      buildNewsPost(body.news, Date.now());   // doğrulama işlemden önce: hatalı formda koleksiyon okunmaz
      const id = newsId(Date.now(), crypto.randomBytes(3).toString("hex"));
      const r = await mutateNews((tx, docs, now) => {
        const doc = buildNewsPost(body.news, now);
        tx.create(db.doc(`news/${id}`), doc);
        docs.set(id, doc);
        return { doc };
      });
      await log({ kind: "news_create", id, news_kind: r.doc.kind, title: r.doc.title.tr, notify: r.doc.notify, start: r.doc.start,
        end: r.doc.end, pinned: r.doc.pinned, feed: r.feed.items.length });
      return { id, news: r.doc, feed: r.feed.items.length };
    }
    const r = await mutateNews((tx, docs, now) => {
      const current = docs.get(editId);
      if (!current) throw new PanelError("Haber bulunamadı (silinmiş olabilir)");
      const doc = buildNewsPost(body.news, now, current);
      tx.set(db.doc(`news/${editId}`), doc);
      docs.set(editId, doc);
      return { doc };
    });
    await log({ kind: "news_update", id: editId, news_kind: r.doc.kind, title: r.doc.title.tr, notify: r.doc.notify,
      bump: body.news && body.news.bump === true, feed: r.feed.items.length });
    return { id: editId, news: r.doc, feed: r.feed.items.length };
  },

  "POST /api/news/delete": async (body) => {
    const id = String(body.id || "");
    if (!NEWS_ID_RE.test(id)) throw new PanelError("Geçersiz haber kimliği");
    const r = await mutateNews((tx, docs) => {
      const current = docs.get(id);
      if (!current) throw new PanelError("Haber bulunamadı");
      tx.delete(db.doc(`news/${id}`));
      docs.delete(id);
      return { title: (current.title || {}).tr || "" };
    });
    await log({ kind: "news_delete", id, title: r.title, feed: r.feed.items.length });
    return { ok: true, feed: r.feed.items.length };
  },

  // YAYINI YENİLE: config/news koleksiyondan yeniden kurulur (biten haber zamanlayıcıyı beklemeden düşer; elle düzeltme sonrası)
  "POST /api/news/publish": async () => {
    const r = await mutateNews(() => ({}));
    await log({ kind: "news_publish", feed: r.feed.items.length });
    return { feed: r.feed.items.length, at: r.feed.at };
  },

  // Kapak resmi: base64 gövde (en çok 1,5 MB, JPEG / PNG / WebP baytlardan sınanır) → Storage news/… → indirme adresi.
  // Adres forma yazılır; haberi kaydetmek ayrı adımdır.
  "POST /api/news/upload": async (body) => {
    const img = decodeNewsImage(body.data);
    const id = String(body.id || "");
    const base = NEWS_ID_RE.test(id) ? id : `u_${Date.now().toString(36)}`;
    const path = `news/${base}_${crypto.randomBytes(3).toString("hex")}.${img.ext}`;
    const token = crypto.randomUUID();
    const bucket = await saveToStorage(path, img.buf, { contentType: img.contentType,
      cacheControl: "public, max-age=31536000, immutable", token });
    await log({ kind: "news_upload", path, size: img.buf.length, type: img.contentType });
    return { url: storageUrl(bucket, path, token), path, size: img.buf.length, contentType: img.contentType };
  },

  "POST /api/player": async (body) => playerSummary(await resolvePlayer(body.query)),

  "POST /api/player/save": async (body) => {
    const uid = await resolvePlayer(body.query);
    const snap = await db.doc(`players/${uid}`).get();
    if (!snap.exists) throw new PanelError("Bu oyuncunun bulut kaydı yok");
    return { uid, save: unpackSave(snap.data().save_json) };
  },

  "POST /api/mail/delete": async (body) => {
    const uid = String(body.uid || "");
    const id = String(body.id || "");
    if (!/^[A-Za-z0-9_-]{6,128}$/.test(uid) || !/^[a-z0-9_]{1,60}$/.test(id)) throw new PanelError("Geçersiz posta");
    await db.doc(`users/${uid}/mail/${id}`).delete();
    await log({ kind: "mail_delete", uid, id });
    return { ok: true };
  },

  // Tek oyuncuya (arkadaş kodu / e-posta / UID) ya da HERKESE (bütün bulut kayıtları). dry: yalnızca alıcı sayısı.
  "POST /api/mail/send": async (body) => {
    const doc = buildMail(body.mail || {}, catalog, Date.now());
    const now = Date.now();
    if (body.target === "all" || body.target === "segment") {
      const uids = body.target === "all" ? (await db.collection("players").listDocuments()).map((r) => r.id)
        : await segmentUids(body.segment);
      if (body.dry) return { count: uids.length };
      if (!uids.length) throw new PanelError("Süzgece uyan oyuncu yok");
      const id = mailId("all", now, crypto.randomBytes(4).toString("hex"));
      await fanOut(uids, id, doc);
      await log({ kind: body.target === "all" ? "mail_all" : "mail_segment", id, count: uids.length, reward: hasReward(doc),
        title: doc.title.tr || doc.title.en || "", money: doc.money, gems: doc.gems, crates: doc.crates, decor: doc.decor,
        segment: body.target === "segment" ? buildSegment(body.segment) : null });
      return { id, count: uids.length };
    }
    const uid = await resolvePlayer(body.query);
    const player = await db.doc(`players/${uid}`).get();
    if (!player.exists) throw new PanelError("Bu oyuncunun bulut kaydı yok (hiç giriş yapmamış ya da hesabı silinmiş)");
    if (body.dry) return { count: 1, uid };
    const id = mailId("one", now, crypto.randomBytes(4).toString("hex"));
    await db.doc(`users/${uid}/mail/${id}`).create(doc);
    await log({ kind: "mail_one", id, uid, reward: hasReward(doc), title: doc.title.tr || doc.title.en || "",
      money: doc.money, gems: doc.gems, crates: doc.crates, decor: doc.decor });
    return { id, uid, count: 1 };
  },

  // Duyuru bildirimi: her dilin konusuna (news_tr …). test_query verilirse YALNIZCA o oyuncunun telefonuna.
  "POST /api/news/send": async (body) => {
    const messages = buildNews(body);
    if (body.test_query) {
      const uid = await resolvePlayer(body.test_query);
      const push = await db.doc(`push/p_${uid}`).get();
      if (!push.exists || !push.data().token) throw new PanelError("Bu oyuncu bildirimleri açmamış (jeton yok)");
      const lang = push.data().lang || "tr";
      const msg = messages.find((m) => m.topic === `news_${lang}`) || messages[0];
      const { topic: _topic, ...rest } = msg;
      await fcm.send({ ...rest, token: push.data().token });
      return { sent: 1, test: true };
    }
    if (body.segment) {
      // Hedefli: süzgece uyan HESAPLARIN telefon jetonlarına (misafir konuyla alır, süzülemez), oyuncunun dilinde
      const uids = await segmentUids(body.segment);
      const refs = uids.map((uid) => db.doc(`push/p_${uid}`));
      const byLang = {};
      for (let i = 0; i < refs.length; i += 300) {
        for (const snap of await db.getAll(...refs.slice(i, i + 300))) {
          if (!snap.exists || !snap.data().token) continue;
          const lang = snap.data().lang || "tr";
          (byLang[lang] = byLang[lang] || []).push(snap.data().token);
        }
      }
      const tokens = Object.values(byLang).reduce((n, list) => n + list.length, 0);
      if (body.dry) return { players: uids.length, tokens };
      let sent = 0;
      for (const [lang, list] of Object.entries(byLang)) {
        const msg = messages.find((m) => m.topic === `news_${lang}`) || messages[0];
        const { topic: _t, ...rest } = msg;
        for (let i = 0; i < list.length; i += 500) sent += (await fcm.sendEachForMulticast({ ...rest, tokens: list.slice(i, i + 500) })).successCount;
      }
      await log({ kind: "news_segment", body: messages[0].notification.body, players: uids.length, sent, segment: buildSegment(body.segment) });
      return { sent, players: uids.length, tokens };
    }
    for (const msg of messages) await fcm.send(msg);
    await log({ kind: "news", title: messages[0].notification.title, body: messages[0].notification.body });
    return { sent: messages.length };
  },

  // --- Moderasyon (oyun: gameplay/backend/moderation_watch.gd; kural: firestore.rules activeBan) ---
  "POST /api/mod/ban": async (body) => {
    const uid = checkUid(body.uid);
    const ban = buildBan(body, Date.now());
    await db.doc(`moderation/m_${uid}`).set({ ban }, { merge: true });
    // Yasak süresince açık garaj ve fotoğraf görünmez (oyun yasak bitince yeniden yayınlar); tam yasakta bildirim de durur
    await db.doc(`garages/g_${uid}`).delete();
    await db.doc(`avatars/a_${uid}`).delete();
    if (ban.kind === "full") await db.doc(`push/p_${uid}`).delete();
    await log({ kind: "ban", uid, ban_kind: ban.kind, reason: ban.reason, until: ban.until, text: ban.text });
    return { ban };
  },

  "POST /api/mod/unban": async (body) => {
    const uid = checkUid(body.uid);
    await db.doc(`moderation/m_${uid}`).set({ ban: FieldValue.delete() }, { merge: true });
    await log({ kind: "unban", uid });
    return { ok: true };
  },

  // Adı sıfırla: açık garaj hemen yeni adla düzeltilir, oyun moderation.name'i kendi adı yapar (yeniden yazınca eskisine dönmez)
  "POST /api/mod/reset-name": async (body) => {
    const uid = checkUid(body.uid);
    const name = moderatedName(crypto.randomInt(0, 1_000_000));
    const garage = db.doc(`garages/g_${uid}`);
    const old = await garage.get();
    if (old.exists) await garage.update({ name });
    await db.doc(`moderation/m_${uid}`).set({ name, name_reset: Math.floor(Date.now() / 1000) }, { merge: true });
    await log({ kind: "reset_name", uid, old: old.exists ? old.data().name : "", name });
    return { name };
  },

  "POST /api/mod/reset-photo": async (body) => {
    const uid = checkUid(body.uid);
    await db.doc(`avatars/a_${uid}`).delete();
    const garage = db.doc(`garages/g_${uid}`);
    if ((await garage.get()).exists) await garage.update({ av: "" });
    await db.doc(`moderation/m_${uid}`).set({ photo_reset: Math.floor(Date.now() / 1000) }, { merge: true });
    await log({ kind: "reset_photo", uid });
    return { ok: true };
  },

  // --- Destek: kayıt geçmişi (oyun yazar: players/{uid}/history/h00..h23 + d0..d6), geri yükleme, bakiye düzeltme ---
  "POST /api/history": async (body) => {
    const uid = checkUid(body.uid);
    const snap = await db.collection(`players/${uid}/history`).get();
    const items = snap.docs.map((d) => {
      const data = d.data();
      let stats = data.stats || null;
      if (!stats) {
        try { stats = statsFromSave(unpackSave(data.save_json)); } catch { stats = null; }
      }
      return { slot: d.id, updated_at: data.updated_at || 0, stats, size: String(data.save_json || "").length };
    }).sort((a, b) => b.updated_at - a.updated_at);
    return { items };
  },

  // Seçilen geçmiş kaydı POSTA olarak gider: oyuncu AL deyince oyun o kayda döner (oyun açıkken de; çakışma penceresi yok)
  "POST /api/history/restore": async (body) => {
    const uid = checkUid(body.uid);
    const slot = String(body.slot || "");
    if (!/^(h([01][0-9]|2[0-3])|d[0-6])$/.test(slot)) throw new PanelError("Geçersiz dilim");
    const snap = await db.doc(`players/${uid}/history/${slot}`).get();
    if (!snap.exists) throw new PanelError("Bu dilimde kayıt yok");
    const doc = buildRestore(snap.data(), Date.now());
    const id = mailId("one", Date.now(), crypto.randomBytes(4).toString("hex"));
    await db.doc(`users/${uid}/mail/${id}`).create(doc);
    await log({ kind: "restore", uid, slot, save_at: snap.data().updated_at || 0, id });
    return { id };
  },

  "POST /api/adjust": async (body) => {
    const uid = checkUid(body.uid);
    if (!(await db.doc(`players/${uid}`).get()).exists) throw new PanelError("Bu oyuncunun bulut kaydı yok");
    const doc = buildAdjust(body, Date.now());
    const id = mailId("one", Date.now(), crypto.randomBytes(4).toString("hex"));
    await db.doc(`users/${uid}/mail/${id}`).create(doc);
    await log({ kind: "adjust", uid, id, money: doc.adjust.money, gems: doc.adjust.gems, text: doc.text.tr || doc.text.en || "" });
    return { id };
  },

  "POST /api/notes": async (body) => {
    const uid = checkUid(body.uid);
    const text = String(body.text || "").slice(0, 2000);
    await db.doc(`admin_notes/n_${uid}`).set({ text, updated_at: Math.floor(Date.now() / 1000) });
    return { ok: true };
  },

  // ŞİKÂYET KUYRUĞU: reports (oyun yazar, istemciye kapalı; cleanup.js 180 günde siler), hedefe göre toplanmış
  "GET /api/reports": async () => {
    const snap = await db.collection("reports").orderBy("at", "desc").limit(300).get();
    const groups = groupReports(snap.docs.map((d) => ({ id: d.id, data: d.data() })));
    const mods = groups.length ? await db.getAll(...groups.map((g) => db.doc(`moderation/m_${g.target}`))) : [];
    groups.forEach((g, i) => { g.banned = mods[i].exists && banActive(mods[i].data().ban, Date.now()); });
    // Şikâyetteki ad / fotoğrafı ŞİKÂYETÇİ yazar (uydurulabilir): karar hedefin güncel garaj adı ve fotoğrafıyla verilsin
    const garages = groups.length ? await db.getAll(...groups.map((g) => db.doc(`garages/g_${g.target}`))) : [];
    const avatars = groups.length ? await db.getAll(...groups.map((g) => db.doc(`avatars/a_${g.target}`))) : [];
    groups.forEach((g, i) => {
      g.now_name = garages[i].exists ? String(garages[i].get("name") || "").slice(0, 16) : "";
      const img = avatars[i].exists ? avatars[i].get("img") : "";
      g.now_img = typeof img === "string" && /^[A-Za-z0-9+/=]{20,40000}$/.test(img) ? img : "";
    });
    return { groups, reasons: BAN_REASONS };
  },

  "POST /api/reports/close": async (body) => {
    const target = checkUid(body.target);
    const snap = await db.collection("reports").where("target", "==", target).get();
    for (let i = 0; i < snap.docs.length; i += BATCH) {
      const batch = db.batch();
      for (const d of snap.docs.slice(i, i + BATCH)) batch.delete(d.ref);
      await batch.commit();
    }
    await log({ kind: "reports_closed", uid: target, count: snap.size, action: String(body.action || "").slice(0, 40) });
    return { closed: snap.size };
  },

  // --- Kupon kodları (functions/promo.js doğrular) ---
  "GET /api/promo": async () => {
    const snap = await db.collection("promo").get();
    return { codes: snap.docs.map((d) => ({ code: d.id, ...d.data() })).sort((a, b) => (b.created_at || 0) - (a.created_at || 0)) };
  },

  "POST /api/promo": async (body) => {
    const { code, doc } = buildPromo(body, catalog);
    const ref = db.doc(`promo/${code}`);
    const old = await ref.get();
    if (old.exists && body.create) throw new PanelError(`${code} zaten var`);
    // Kullanım sayacı yalnız sunucunundur: güncellemede korunur
    await ref.set({ ...doc, uses: old.exists ? old.data().uses || 0 : 0, created_at: old.exists ? old.data().created_at || 0
      : Math.floor(Date.now() / 1000) });
    await log({ kind: old.exists ? "promo_update" : "promo_create", code, reward: doc.reward, max_uses: doc.max_uses, until: doc.until });
    return { code };
  },

  "POST /api/promo/toggle": async (body) => {
    const code = String(body.code || "");
    if (!PROMO_RE.test(code)) throw new PanelError("Geçersiz kod");
    const ref = db.doc(`promo/${code}`);
    if (!(await ref.get()).exists) throw new PanelError("Kod yok");
    await ref.update({ active: body.active === true });
    await log({ kind: "promo_toggle", code, active: body.active === true });
    return { ok: true };
  },

  // --- İstatistik: anlık sayılar + son 30 gecenin kaydı (dailyStats) + dil / sürüm / seviye dağılımı ---
  "GET /api/stats": async () => {
    const live = await computeStats({ db, auth, now: Date.now() });
    const days = (await db.collection("stats_daily").orderBy("at", "desc").limit(30).get())
      .docs.map((d) => ({ day: d.id, ...d.data() })).reverse();
    const snap = await db.collection("players").select("stats").get();
    const langs = {};
    const levels = {};
    for (const d of snap.docs) {
      const st = d.get("stats") || {};
      const lang = st.lang || "?";
      langs[lang] = (langs[lang] || 0) + 1;
      const band = st.level ? `${Math.floor((st.level - 1) / 5) * 5 + 1}–${Math.floor((st.level - 1) / 5) * 5 + 5}` : "?";
      levels[band] = (levels[band] || 0) + 1;
    }
    return { live, days, langs, levels };
  },

  // --- Yarış öğrenmesi (docs/KOSU_ESLESTIRME.md Faz 2): gece tablosu (raceLearning) + panel ayarı + son 30 günün sayıları ---
  "GET /api/learning": async () => {
    const snap = await db.doc("config/race_learning").get();
    const days = (await db.collection("race_learning_daily").orderBy("day", "desc").limit(30).get())
      .docs.map((d) => ({ day: d.get("day"), events: d.get("events") || 0, players: d.get("players") || 0 })).reverse();
    return { doc: snap.exists ? snap.data() : null, days };
  },

  "POST /api/learning": async (body) => {
    const doc = buildLearning(body);
    await db.doc("config/race_learning").set(doc, { merge: true });
    await log({ kind: "learning", ...doc });
    return { doc };
  },

  "GET /api/log": async () => {
    const snap = await db.collection("admin_log").orderBy("at", "desc").limit(30).get();
    return { log: snap.docs.map((d) => ({ ...d.data(), at: d.data().at?.toDate?.().toISOString() || "" })) };
  },

  // Sürüm dağılımı: bütün kayıtların stats.build alanı (oyuncu sayısı kadar okuma).
  "GET /api/builds": async () => {
    const snap = await db.collection("players").select("stats.build").get();
    const builds = {};
    for (const d of snap.docs) {
      const b = String(d.get("stats.build") ?? "eski");
      builds[b] = (builds[b] || 0) + 1;
    }
    return { builds, total: snap.size };
  },
};

// --- HTTP ----------------------------------------------------------------------------------------

const PAGE = readFileSync(resolve(HERE, "public/index.html"), "utf8");
const ALLOWED_HOSTS = new Set([`${HOST}:${PORT}`, `localhost:${PORT}`]);
const ORIGINS = new Set([`http://${HOST}:${PORT}`, `http://localhost:${PORT}`]);

function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data: " +
      "https://firebasestorage.googleapis.com https://storage.googleapis.com https://autoyard.online; " +
      "connect-src 'self'; frame-ancestors 'none'; form-action 'none'; base-uri 'none'",
  });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

function keyOk(header) {
  const a = Buffer.from(String(header || ""));
  const b = Buffer.from(KEY);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// Gövde sınırı: 64 KB; haber kapağı yükleme (1,5 MB resim base64 ile ~2 MB) ve etkinlik takvimi (12 etkinlik × 5 dilde metin)
// için daha büyük
const BODY_MAX = 64 * 1024;
const BODY_MAX_BY_ROUTE = { "POST /api/news/upload": 2_200_000, "POST /api/events": 256 * 1024 };

async function readBody(req, limit = BODY_MAX) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > limit) throw new PanelError("İstek çok büyük");
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw new PanelError("Geçersiz JSON");
  }
}

const server = http.createServer(async (req, res) => {
  if (!ALLOWED_HOSTS.has(String(req.headers.host || ""))) return send(res, 403, { error: "host" });
  if (req.headers.origin && !ORIGINS.has(req.headers.origin)) return send(res, 403, { error: "origin" });
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  if (req.method === "GET" && url.pathname === "/") return send(res, 200, PAGE, "text/html; charset=utf-8");
  const routeKey = `${req.method} ${url.pathname}`;
  const route = routes[routeKey];
  if (!route) return send(res, 404, { error: "yok" });
  if (!keyOk(req.headers["x-admin-key"])) return send(res, 401, { error: "Panel anahtarı geçersiz: terminaldeki bağlantıyla aç" });
  if (req.method === "POST" && !String(req.headers["content-type"] || "").startsWith("application/json")) {
    return send(res, 415, { error: "json" });
  }
  try {
    const body = req.method === "POST" ? await readBody(req, BODY_MAX_BY_ROUTE[routeKey] || BODY_MAX) : {};
    send(res, 200, await route(body));
  } catch (e) {
    if (e instanceof PanelError) return send(res, 400, { error: e.message });
    console.error(e);
    send(res, 500, { error: String(e && e.message ? e.message : e).slice(0, 300) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`\n  AUTO YARD yönetim paneli (${PROJECT}, hizmet hesabı ${sa.client_email})`);
  console.log(`  Tarayıcıda aç:  http://${HOST}:${PORT}/#k=${KEY}`);
  console.log("  Kapatmak için Ctrl+C. Bağlantı her açılışta değişir.\n");
});
