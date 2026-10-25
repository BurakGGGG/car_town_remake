// AUTO YARD yönetim paneli — saf mantık (sunucu server.mjs bağlar; test/lib.test.mjs internetsiz sınar).
// Belgelerin biçimi oyundakiyle aynıdır:
//   config/app             gameplay/backend/app_config.gd (AppConfig); event modülleri ve packs gameplay/backend/live_event.gd /
//                          live_packs.gd (aynı sınırlar: SALE_MAX, BOOST, MISSION_MAX, RIVAL_STAGE_MAX, ödül sınırları)
//   users/{uid}/mail/{id}  gameplay/backend/mail_service.gd (MailService.normalize aynı sınırları uygular)
//   bildirim konusu        gameplay/social/push_service.gd (news_<dil>)
//   news/{id}              HABERLER (yalnız sunucu; bildirimi functions/news_feed.js gönderir)
//   config/news            oyunun okuduğu HABERLER yayını (buildNewsFeed: functions/news_feed.js ile AYNI kod)
//   config/app.events      etkinlik takvimi; config/app.event = eski sürümlerin aynası (mirrorEvent: functions/events_tick.js
//                          ile AYNI kod; zamanla ilerletmeyi eventsTick yapar)
import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import { createRequire } from "node:module";

export const LANGS = ["tr", "en", "es", "de", "fr"];
// Oyundaki MailService sınırları (istemci de sınırlar; panel yanlış yazılmış sıfırı baştan reddeder).
export const MAX_MONEY = 50_000_000;
export const MAX_GEMS = 50_000;
export const MAX_COUNT = 20;
export const MAX_TITLE = 80;
export const MAX_TEXT = 500;
const CODE_RE = /^[A-HJ-NP-Z2-9]{6}$/;
const UID_RE = /^[A-Za-z0-9_-]{6,128}$/;

export class PanelError extends Error {}

const int = (v, lo, hi, what) => {
  const n = v === "" || v === undefined || v === null ? 0 : Number(v);
  if (!Number.isInteger(n)) throw new PanelError(`${what}: tam sayı olmalı`);
  if (n < lo || n > hi) throw new PanelError(`${what}: ${lo} ile ${hi} arasında olmalı`);
  return n;
};

/** {tr, en, …} → boş olmayan dillerin kırpılmış metni (en çok `max` karakter). Hiç metin yoksa boş sözlük. */
export function texts(value, max, what) {
  const out = {};
  if (typeof value === "string") value = { tr: value };
  if (!value || typeof value !== "object") return out;
  for (const lang of LANGS) {
    const t = typeof value[lang] === "string" ? value[lang].trim() : "";
    if (!t) continue;
    if (t.length > max) throw new PanelError(`${what} (${lang}): en çok ${max} karakter`);
    out[lang] = t;
  }
  return out;
}

const empty = (o) => Object.keys(o).length === 0;

// --- Katalog (oyunun kendi JSON dosyaları) ---------------------------------------------

/** Satılan kasalar (HOŞ GELDİN KUTUSU gibi hediye kasaları değil: onların oyunda kendi akışı var) ve garaja konan dekor
 *  eşyaları (GarageDecor.is_placeable: kaplama / karo / duvar parçası değil). */
export function loadCatalog(root) {
  const crates = JSON.parse(readFileSync(new URL("vehicles/crates.json", root), "utf8"));
  const decor = JSON.parse(readFileSync(new URL("decor/decorations.json", root), "utf8"));
  const cars = JSON.parse(readFileSync(new URL("vehicles/cars.json", root), "utf8"));
  const crateList = (crates.crates || []).map((c) => ({ id: c.id, name: c.display_name || c.id, pool: c.pool || [] }));
  // Etkinlik rakibi olabilecek araçlar (CarCatalog.is_obtainable: polis gibi edinilemeyen hariç)
  const carList = (cars.cars || []).filter((c) => c && c.id && c.obtainable !== false)
    .map((c) => ({ id: c.id, name: c.display_name || c.id, class: c.class || "" }));
  const decorList = (decor.items || [])
    .filter((i) => i && i.id && !i.retired && placementOf(i) !== "surface" && placementOf(i) !== "tile" && placementOf(i) !== "edge")
    .map((i) => ({ id: i.id, name: i.title || i.id, kind: i.kind, exclusive: !!i.exclusive, gems: i.price_gems || 0 }));
  return { crates: crateList, decor: decorList, cars: carList, metrics: MISSION_METRICS, ad_kinds: AD_KINDS, ad_defaults: AD_DEFAULTS };
}

// GarageDecor.load_from ile aynı çıkarım.
function placementOf(item) {
  if (item.placement) return item.placement;
  const kind = String(item.kind || "");
  if (kind === "floor_pattern") return "tile";
  if (kind === "wall_piece") return "edge";
  if (kind.endsWith("_surface")) return "surface";
  return kind === "wall_item" ? "wall" : "floor";
}

/** export_presets.cfg'deki Android sürümü (panelde "son derleme" olarak gösterilir). */
export function buildInfo(text) {
  const code = /^version\/code=(\d+)/m.exec(text);
  const name = /^version\/name="([^"]*)"/m.exec(text);
  return { code: code ? Number(code[1]) : 0, name: name ? name[1] : "" };
}

// --- Posta -----------------------------------------------------------------------------

function itemMap(raw, allowed, what) {
  const out = {};
  for (const [id, count] of Object.entries(raw || {})) {
    if (!count) continue;
    if (!allowed.has(id)) throw new PanelError(`${what}: bilinmeyen kimlik "${id}"`);
    out[id] = int(count, 1, MAX_COUNT, `${what} ${id} adedi`);
  }
  return out;
}

/**
 * Panel formundan posta belgesi. input: {title, text: dil sözlüğü, from, money, gems, crates: {id: adet},
 * decor: {id: adet}, cars: {araç: 1}, expires_days, notify, image, action}. now: unix ms. Araç (2026-10-25) edinilebilir
 * araçlardan (katalog), her biri BİR adet; oyuncuda zaten varsa oyun satış değerini ₺ verir. Yalnız seçildiyse yazılır. image / action (HABERLER'le aynı biçim,
 * newsImage / newsAction) isteğe bağlıdır ve yalnız doluysa yazılır: ödülsüz posta = tek oyuncuya kişisel haber.
 */
export function buildMail(input, catalog, now) {
  const doc = {
    title: texts(input.title, MAX_TITLE, "Başlık"),
    text: texts(input.text, MAX_TEXT, "Mesaj"),
    from: String(input.from || "AUTO YARD").trim().slice(0, 24) || "AUTO YARD",
    money: int(input.money, 0, MAX_MONEY, "₺"),
    gems: int(input.gems, 0, MAX_GEMS, "Elmas"),
    crates: itemMap(input.crates, new Set(catalog.crates.map((c) => c.id)), "Kasa"),
    decor: itemMap(input.decor, new Set(catalog.decor.map((d) => d.id)), "Eşya"),
    at: Math.floor(now / 1000),
    expires: 0,
    notify: input.notify !== false,
  };
  const cars = Object.fromEntries(Object.keys(itemMap(input.cars, new Set(catalog.cars.map((c) => c.id)), "Araç"))
    .map((id) => [id, 1]));
  if (!empty(cars)) doc.cars = cars;
  const days = int(input.expires_days, 0, 365, "Geçerlilik (gün)");
  if (days > 0) doc.expires = doc.at + days * 86400;
  const image = newsImage(input.image);
  if (image) doc.image = image;
  const action = newsAction(input.action);
  if (action.kind) doc.action = action;
  if (empty(doc.title) && empty(doc.text) && !hasReward(doc)) throw new PanelError("Postada ne mesaj ne ödül var");
  if (empty(doc.title) && empty(doc.text)) throw new PanelError("Hediyeye en az bir başlık ya da mesaj yaz");
  return doc;
}

export function hasReward(doc) {
  return doc.money > 0 || doc.gems > 0 || !empty(doc.crates) || !empty(doc.decor) || !empty(doc.cars || {});
}

/** Posta kimliği: tek oyuncuya m_<zaman>_<rastgele>, herkese c_<kampanya> (aynı kampanya bir oyuncuya iki kez yazılmaz). */
export function mailId(kind, now, rand) {
  const suffix = String(rand).replace(/[^a-z0-9]/gi, "").slice(0, 6).toLowerCase();
  return `${kind === "all" ? "c" : "m"}_${now.toString(36)}_${suffix}`;
}

// --- Uzaktan ayar (config/app) -----------------------------------------------------------

/** Panel formundan config/app. input: {min_code, latest_code, update_text, maintenance, maintenance_text,
 *  maintenance_until (unix sn), notice: {id, title, text, until}}. */
export function buildConfig(input, now) {
  const doc = {
    min_code: int(input.min_code, 0, 1_000_000, "En düşük sürüm kodu"),
    latest_code: int(input.latest_code, 0, 1_000_000, "Son sürüm kodu"),
    update_text: texts(input.update_text, MAX_TEXT, "Güncelleme metni"),
    maintenance: input.maintenance === true,
    maintenance_text: texts(input.maintenance_text, MAX_TEXT, "Bakım metni"),
    maintenance_until: int(input.maintenance_until, 0, 4_000_000_000, "Bakım bitişi"),
    updated_at: Math.floor(now / 1000),
  };
  if (doc.latest_code > 0 && doc.latest_code < doc.min_code) {
    throw new PanelError("Son sürüm kodu en düşük sürüm kodundan küçük olamaz");
  }
  const notice = input.notice || {};
  const noticeText = texts(notice.text, MAX_TEXT, "Duyuru metni");
  if (!empty(noticeText)) {
    const id = String(notice.id || "").trim();
    if (!/^[a-z0-9_]{1,40}$/.test(id)) throw new PanelError("Duyuru kimliği: küçük harf / rakam / _ (en çok 40)");
    doc.notice = {
      id,
      title: texts(notice.title, MAX_TITLE, "Duyuru başlığı"),
      text: noticeText,
      until: int(notice.until, 0, 4_000_000_000, "Duyuru bitişi"),
    };
  }
  return doc;
}

// --- Duyuru bildirimi (FCM konusu) --------------------------------------------------------

/** Her dil konusuna gidecek ileti: o dilde metin yoksa İngilizce, o da yoksa Türkçe. input: {title, body: dil sözlüğü}. */
export function buildNews(input) {
  const title = texts(input.title, 60, "Bildirim başlığı");
  const body = texts(input.body, 180, "Bildirim metni");
  const pick = (map, lang) => map[lang] || map.en || map.tr || "";
  if (!pick(body, "tr")) throw new PanelError("Bildirim metni boş");
  return LANGS.map((lang) => ({
    topic: `news_${lang}`,
    notification: { title: pick(title, lang) || "AUTO YARD", body: pick(body, lang) },
    android: { priority: "high", notification: { tag: "news", icon: "icon_monochrome", color: "#F5BE4C" } },
    data: { type: "news" },
  }));
}

// --- HABERLER (news/{id}; bildirimi functions/news_feed.js gönderir) ---------------------------------------------------
// Belge: {kind, title, text, image, action {kind, url}, start, end, pinned, code, target {langs, min_level, max_level,
// min_code, max_code}, notify, pushed_at, at}. Koleksiyon yalnız sunucunundur (panel yazar, istemci okuyamaz). Oyun tek belge
// okur: config/news = buildNewsFeed(haberler) = {items: bitmemiş haberlerin herkese açık alanları (en çok 40), at}. Panel
// her kaydet / sil işleminde yayını haberle aynı işlemde yazar; biten haberi newsPushScheduled (10 dk) yayından düşürür.

// Yayın kurucusu functions/news_feed.js'te (zamanlayıcı da kullanır): tek kaynak, panel aynısını çağırır
export const { buildNewsFeed, FEED_DOC: NEWS_FEED_DOC, FEED_MAX: NEWS_FEED_MAX } =
  createRequire(import.meta.url)("../functions/news_feed.js");

export const NEWS_KINDS = ["update", "event", "notice"];
export const NEWS_KIND_NAMES = { update: "GÜNCELLEME", event: "ETKİNLİK", notice: "DUYURU" };
// Haber / posta düğmesi: "" = düğme yok; url = https bağlantısı; ötekiler oyundaki ekranlar (store = Play Store sayfası)
export const NEWS_ACTIONS = ["", "market", "event", "quests", "showroom", "friends", "invite", "store", "url"];
export const NEWS_TITLE_MAX = 60;
export const NEWS_TEXT_MAX = 600;
export const NEWS_URL_MAX = 300;
export const NEWS_IMAGE_URL_MAX = 500;
// Kapak resmi yalnız bu adreslerden (oyun da aynı listeyle sınar): Firebase Storage ve oyunun sitesi
export const NEWS_IMAGE_HOSTS = ["firebasestorage.googleapis.com", "storage.googleapis.com", "autoyard.online"];
export const NEWS_IMAGE_BYTES = 1.5 * 1024 * 1024;
export const NEWS_ID_RE = /^n_[a-z0-9]{1,12}_[0-9a-f]{6}$/;
const LEVEL_MAX = 999;
const CODE_MAX = 1_000_000;
const TIME_MAX = 4_000_000_000;
// Adres: boşluk / tırnak / ters bölü yok (oyun ve panel sayfası adresi olduğu gibi kullanır)
const URL_CHARS = /^https:\/\/[^\s"'<>\\`]+$/;

/** Uzunluk karakter (kod noktası) olarak: oyundaki String.length ile aynı sayar (emoji 1). */
const chars = (s) => [...s].length;

/** {tr, en, …} haber metni: tr zorunlu, boş diller yazılmaz. Başlık tek satır (boşluklar teke iner), metinde satır sonu kalır. */
function newsTexts(value, max, what, singleLine) {
  const out = {};
  const src = value && typeof value === "object" ? value : {};
  for (const lang of LANGS) {
    let t = typeof src[lang] === "string" ? src[lang].replace(/\r\n?/g, "\n").trim() : "";
    if (singleLine) t = t.replace(/\s+/g, " ");
    if (!t) continue;
    if (chars(t) > max) throw new PanelError(`${what} (${lang}): en çok ${max} karakter`);
    out[lang] = t;
  }
  if (!out.tr) throw new PanelError(`${what}: Türkçe metin zorunlu`);
  return out;
}

/** Kapak resmi adresi: "" (oyun türe göre hazır kapak çizer) ya da izinli sunucudan https adresi. Posta da kullanır. */
export function newsImage(value) {
  const s = String(value ?? "").trim();
  if (!s) return "";
  if (s.length > NEWS_IMAGE_URL_MAX) throw new PanelError(`Kapak resmi adresi en çok ${NEWS_IMAGE_URL_MAX} karakter`);
  // Sunucu adı tam eşleşir ve hemen "/" gelir: kullanıcı@sunucu, :port, sahte alt alan adı geçmez
  const m = /^https:\/\/([^/]+)\//.exec(s);
  if (!m || !URL_CHARS.test(s) || !NEWS_IMAGE_HOSTS.includes(m[1])) {
    throw new PanelError(`Kapak resmi adresi https:// ile başlamalı ve yalnız ${NEWS_IMAGE_HOSTS.join(" / ")} olabilir`);
  }
  try {
    new URL(s);
  } catch {
    throw new PanelError("Kapak resmi adresi geçersiz");
  }
  return s;
}

/** Düğme: {kind, url}. url yalnız "url" türünde (https, en çok 300 karakter), öbür türlerde "". Posta da kullanır. */
export function newsAction(value) {
  const a = value && typeof value === "object" ? value : {};
  const kind = String(a.kind ?? "").trim();
  if (!NEWS_ACTIONS.includes(kind)) throw new PanelError(`Düğme: bilinmeyen tür "${kind}"`);
  const url = String(a.url ?? "").trim();
  if (kind !== "url") {
    if (url) throw new PanelError("Düğme adresi yalnız Bağlantı türünde yazılır");
    return { kind, url: "" };
  }
  if (!url) throw new PanelError("Bağlantı düğmesinin adresi boş");
  if (url.length > NEWS_URL_MAX) throw new PanelError(`Bağlantı adresi en çok ${NEWS_URL_MAX} karakter`);
  let parsed = null;
  try {
    parsed = URL_CHARS.test(url) ? new URL(url) : null;
  } catch {
    parsed = null;
  }
  if (!parsed || parsed.username || parsed.password || !parsed.hostname.includes(".")) {
    throw new PanelError("Bağlantı adresi https:// ile başlayan geçerli bir adres olmalı");
  }
  return { kind, url };
}

/** Hedef: {langs (boş = hepsi), min_level, max_level, min_code, max_code (0 = sınır yok)}. */
export function newsTarget(value) {
  const t = value && typeof value === "object" ? value : {};
  const raw = Array.isArray(t.langs) ? t.langs.map(String) : [];
  for (const l of raw) if (!LANGS.includes(l)) throw new PanelError(`Hedef dil geçersiz: "${l}"`);
  const target = {
    langs: LANGS.filter((l) => raw.includes(l)),
    min_level: int(t.min_level, 0, LEVEL_MAX, "Hedef seviye en az"),
    max_level: int(t.max_level, 0, LEVEL_MAX, "Hedef seviye en çok"),
    min_code: int(t.min_code, 0, CODE_MAX, "Hedef sürüm kodu en az"),
    max_code: int(t.max_code, 0, CODE_MAX, "Hedef sürüm kodu en çok"),
  };
  if (target.min_level && target.max_level && target.min_level > target.max_level) throw new PanelError("Hedef seviye aralığı ters");
  if (target.min_code && target.max_code && target.min_code > target.max_code) throw new PanelError("Hedef sürüm aralığı ters");
  return target;
}

/** Seviye / sürüm hedefi var mı (bildirim dil konusuna gider, bu hedefleri süzemez). */
export function newsTargeted(target) {
  return !!(target && (target.min_level || target.max_level || target.min_code || target.max_code));
}

/**
 * Panel formundan haber belgesi. input: {kind, title, text, image, action, start, end, pinned, code, target, notify, bump}.
 * now: unix ms. current: düzenlenen belgenin şimdiki hâli (yeni haberde null) — `at` korunur ("en üste taşı" = bump
 * işaretliyse şimdi olur), pushed_at korunur (gönderilmiş bildirim düzenlemeyle yeniden gitmez).
 */
export function buildNewsPost(input, now, current = null) {
  const src = input || {};
  const kind = String(src.kind || "");
  if (!NEWS_KINDS.includes(kind)) throw new PanelError("Haber türü: GÜNCELLEME, ETKİNLİK ya da DUYURU");
  const start = int(src.start, 0, TIME_MAX, "Başlangıç");
  const end = int(src.end, 0, TIME_MAX, "Bitiş");
  if (start && end && end <= start) throw new PanelError("Bitiş başlangıçtan sonra olmalı");
  const code = int(src.code, 0, CODE_MAX, "Sürüm kodu");
  if (kind === "update" && !code) throw new PanelError("GÜNCELLEME haberinde sürüm kodu gerekli (notlar hangi sürümün?)");
  if (kind !== "update" && code) throw new PanelError("Sürüm kodu yalnız GÜNCELLEME haberinde yazılır");
  const target = newsTarget(src.target);
  const notify = src.notify === true;
  if (notify && newsTargeted(target)) {
    throw new PanelError("Seviye / sürüm hedefli habere telefon bildirimi gönderilemez: bildirim dil konusuna gider, " +
      "hedef dışındaki oyunculara da ulaşırdı. Bildirimi kapat ya da hedefi yalnız dille sınırla.");
  }
  const nowS = Math.floor(now / 1000);
  return {
    kind,
    title: newsTexts(src.title, NEWS_TITLE_MAX, "Başlık", true),
    text: newsTexts(src.text, NEWS_TEXT_MAX, "Metin", false),
    image: newsImage(src.image),
    action: newsAction(src.action),
    start,
    end,
    pinned: src.pinned === true,
    code,
    target,
    notify,
    pushed_at: current ? Number(current.pushed_at) || 0 : 0,
    at: current && src.bump !== true && Number.isInteger(current.at) ? current.at : nowS,
  };
}

/** Haber kimliği: n_<zaman (ms, 36 tabanı)>_<6 onaltılık>. */
export function newsId(now, randHex) {
  const suffix = String(randHex).toLowerCase().replace(/[^0-9a-f]/g, "").padEnd(6, "0").slice(0, 6);
  return `n_${now.toString(36)}_${suffix}`;
}

/** Yüklenen resmin türü dosyanın ilk baytlarından (uzantıya / tarayıcının söylediğine güvenilmez). */
export function imageKind(buf) {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return { ext: "jpg", contentType: "image/jpeg" };
  if (buf.length >= 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return { ext: "png", contentType: "image/png" };
  }
  if (buf.length >= 12 && buf.toString("latin1", 0, 4) === "RIFF" && buf.toString("latin1", 8, 12) === "WEBP") {
    return { ext: "webp", contentType: "image/webp" };
  }
  return null;
}

/** Panelin gönderdiği base64 (isteğe bağlı data: önekiyle) → {buf, ext, contentType}; en çok 1,5 MB, JPEG / PNG / WebP. */
export function decodeNewsImage(data) {
  let s = typeof data === "string" ? data.trim() : "";
  const prefix = /^data:[a-z0-9/+.-]*;base64,/i.exec(s);
  if (prefix) s = s.slice(prefix[0].length);
  if (!s) throw new PanelError("Resim seçilmedi");
  if (s.length > Math.ceil(NEWS_IMAGE_BYTES / 3) * 4 + 4) throw new PanelError("Resim en çok 1,5 MB olmalı");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(s)) throw new PanelError("Resim verisi okunamadı (base64 değil)");
  const buf = Buffer.from(s, "base64");
  if (!buf.length) throw new PanelError("Resim boş");
  if (buf.length > NEWS_IMAGE_BYTES) throw new PanelError("Resim en çok 1,5 MB olmalı");
  const kind = imageKind(buf);
  if (!kind) throw new PanelError("Yalnız JPEG, PNG ya da WebP resim yüklenebilir");
  return { buf, ...kind };
}

// --- Firebase Storage (haber kapağı; içerik paketleri) -------------------------------------------------------------

export const STORAGE_OFF = "Firebase Storage açık değil: konsolda Storage › Başlayın'a bas (bir kez). " +
  "O zamana kadar kapak için 'Resim adresi' kullanılabilir.";

/** Denenecek kovalar: AUTOYARD_BUCKET verilmişse yalnız o; yoksa yeni varsayılan (.firebasestorage.app), sonra eski (.appspot.com). */
export function bucketCandidates(project, override) {
  const o = String(override || "").trim();
  return o ? [o] : [`${project}.firebasestorage.app`, `${project}.appspot.com`];
}

/** Yükleme hatası "kova yok" mu (Storage hiç açılmamış): öbür adayı dene, hepsi yoksa STORAGE_OFF. */
export function isMissingBucket(e) {
  return !!e && (e.code === 404 || /bucket does not exist/i.test(String(e.message || "")));
}

/** İndirme anahtarlı herkese açık adres (Storage güvenlik kurallarından bağımsız; anahtarı bilen indirir). */
export function storageUrl(bucket, path, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

// --- Oyuncu arama / kayıt ------------------------------------------------------------------

/** Arama metni → {kind: "code" | "email" | "uid", value}. */
export function classifyQuery(q) {
  const s = String(q || "").trim();
  if (CODE_RE.test(s.toUpperCase()) && s.length === 6) return { kind: "code", value: s.toUpperCase() };
  if (s.includes("@")) return { kind: "email", value: s.toLowerCase() };
  if (UID_RE.test(s)) return { kind: "uid", value: s };
  throw new PanelError("Arkadaş kodu (6 harf), e-posta ya da UID yaz");
}

/** Kayıt sözlüğünden özet (oyundaki CloudSaveManager.stats_of ile aynı). `stats` alanı yalnızca 2026-10-21 sonrası
 *  sürümün yazdığı kayıtta var; eski sürümle yazılmış kayıtta panel değerleri buradan hesaplar. build bilinmez (null). */
export function statsFromSave(save) {
  if (!save || typeof save !== "object") return null;
  const economy = save.economy && typeof save.economy === "object" ? save.economy : {};
  const progress = save.progress && typeof save.progress === "object" ? save.progress : {};
  const owned = save.vehicles && Array.isArray(save.vehicles.owned) ? save.vehicles.owned : [];
  const num = (v, d) => (Number.isFinite(Number(v)) ? Math.trunc(Number(v)) : d);
  return { money: num(economy.money, 0), gems: num(progress.gems, 0), level: Math.max(num(progress.level, 1), 1),
    cars: owned.length, build: null };
}

/** players.save_json → kayıt sözlüğü (CloudPack: "gz1:" + base64 gzip ya da eski düz JSON). */
export function unpackSave(text) {
  if (typeof text !== "string" || !text) return null;
  const plain = text.startsWith("gz1:") ? gunzipSync(Buffer.from(text.slice(4), "base64"), { maxOutputLength: 1 << 20 }).toString("utf8") : text;
  return JSON.parse(plain);
}

// --- Moderasyon ----------------------------------------------------------------------------

// Oyundaki ModerationWatch.REASONS ile aynı anahtarlar (oyuncuya kendi dilinde gösterilir).
export const BAN_REASONS = { name: "Uygunsuz takma ad", photo: "Uygunsuz profil fotoğrafı", cheat: "Hile",
  harassment: "Taciz ya da hakaret", spam: "Spam", other: "Kural ihlali" };
export const UID_PATTERN = UID_RE;

/** Panel formundan yasak: {kind: social | full, reason, text, days (0 = kalıcı)}. now: unix ms. */
export function buildBan(input, now) {
  const kind = String(input.kind || "");
  if (kind !== "social" && kind !== "full") throw new PanelError("Yasak türü: sosyal ya da tam");
  const reason = String(input.reason || "");
  if (!Object.hasOwn(BAN_REASONS, reason)) throw new PanelError("Geçersiz sebep");
  const text = String(input.text || "").trim();
  if (text.length > 200) throw new PanelError("Açıklama en çok 200 karakter");
  const days = int(input.days, 0, 3650, "Süre (gün)");
  const at = Math.floor(now / 1000);
  return { kind, reason, text, until: days > 0 ? at + days * 86400 : 0, at };
}

/** Yasak hâlâ geçerli mi (until 0 = kalıcı). */
export function banActive(ban, now) {
  return !!ban && (ban.kind === "social" || ban.kind === "full") && (!ban.until || ban.until * 1000 > now);
}

/** Adı sıfırlanan oyuncunun yeni adı: oyundaki SocialNames.default_name ile aynı biçim. */
export function moderatedName(rand) {
  return `Usta${1000 + (Math.abs(Math.trunc(rand)) % 9000)}`;
}

/** Şikâyetleri hedefe göre toplar: en çok şikâyet edilen / en yeni önce. docs: [{id, data}]. */
export function groupReports(docs) {
  const byTarget = new Map();
  for (const { id, data } of docs) {
    const target = String(data.target || "");
    if (!UID_RE.test(target)) continue;
    const g = byTarget.get(target) || { target, count: 0, reasons: {}, last_at: 0, name: "", img: "", reports: [] };
    g.count++;
    g.reasons[data.reason] = (g.reasons[data.reason] || 0) + 1;
    if ((data.at || 0) >= g.last_at) {
      g.last_at = data.at || 0;
      g.name = String(data.name || "").slice(0, 16);
    }
    // Yalnızca base64 karakterleri: sayfada data: adresine girer
    if (!g.img && typeof data.img === "string" && /^[A-Za-z0-9+/=]{20,40000}$/.test(data.img)) g.img = data.img;
    g.reports.push({ id, reporter: id.startsWith("x_") ? id.slice(2, id.length - target.length - 1) : "", reason: data.reason, at: data.at || 0 });
    byTarget.set(target, g);
  }
  return [...byTarget.values()].sort((a, b) => b.count - a.count || b.last_at - a.last_at);
}

// --- Destek: bakiye düzeltme / kayıt geri yükleme (posta olarak gider: oyun açıkken de güvenle uygulanır) ----------

/** Bakiye düzeltmesi postası: {money, gems} eksi de olabilir (oyun 0'ın altına indirmez), text: oyuncuya açıklama. */
export function buildAdjust(input, now) {
  const money = int(input.money, -MAX_MONEY, MAX_MONEY, "₺ düzeltmesi");
  const gems = int(input.gems, -MAX_GEMS, MAX_GEMS, "Elmas düzeltmesi");
  if (!money && !gems) throw new PanelError("Düzeltme miktarı yok");
  const text = texts(input.text, MAX_TEXT, "Açıklama");
  const at = Math.floor(now / 1000);
  return { title: { tr: "Hesap düzeltmesi", en: "Account adjustment" }, text, from: "AUTO YARD",
    adjust: { money, gems }, at, expires: 0, notify: input.notify === true };
}

/** Kayıt geri yükleme postası: geçmişteki sıkışık kayıt (oyun AL deyince o kayda döner, şimdiki kayıt cihazda yedeklenir). */
export function buildRestore(history, now) {
  if (!history || typeof history.save_json !== "string" || !history.save_json) throw new PanelError("Geçmiş kaydı boş");
  if (history.save_json.length > 200000) throw new PanelError("Kayıt çok büyük");
  const at = Math.floor(now / 1000);
  return { title: { tr: "Kaydın geri yüklendi", en: "Your save was restored" },
    text: { tr: "İstediğin gibi ilerlemeni önceki bir kayda döndürdük.", en: "As requested, we restored your progress to an earlier save." },
    from: "AUTO YARD", restore: { save_json: history.save_json, at: history.updated_at || 0 }, at, expires: 0, notify: true };
}

// --- Canlı oyun: kupon, etkinlik, hedefli gönderim ---------------------------------------------

export const PROMO_RE = /^[A-Z0-9]{4,16}$/;

/** Kupon kodu (functions/promo.js biçimi): {code, title, money, gems, crates, decor, max_uses (0 = sınırsız), until (unix sn,
 *  0 = süresiz), active}. Ödül postayla aynı sınırlarla doğrulanır. */
export function buildPromo(input, catalog) {
  const code = String(input.code || "").trim().toUpperCase();
  if (!PROMO_RE.test(code)) throw new PanelError("Kod: 4–16 büyük harf / rakam (ör. REELS50)");
  const mail = buildMail({ ...input, text: { tr: "kupon" } }, catalog, Date.now());
  if (!hasReward(mail)) throw new PanelError("Kuponun ödülü yok");
  return {
    code,
    doc: {
      title: texts(input.title, MAX_TITLE, "Başlık"),
      reward: { money: mail.money, gems: mail.gems, crates: mail.crates, decor: mail.decor },
      max_uses: int(input.max_uses, 0, 10_000_000, "Kullanım sınırı"),
      until: int(input.until, 0, 4_000_000_000, "Bitiş"),
      active: input.active !== false,
    },
  };
}

// --- Canlı etkinlik takvimi (config/app.events + eski sürümlerin aynası config/app.event) ve içerik paketleri (config/app.packs)

export const SALE_KINDS = ["crates", "cars", "decor", "mods"];
export const SALE_MAX = 50;
export const MISSION_MAX = 6;
export const RIVAL_STAGE_MAX = 5;
const BOOST_MIN = 2;
const BOOST_MAX = 5;
const REWARD_MAX = { money: 5_000_000, gems: 1000, xp: 100_000 };
const ID_RE = /^[a-z0-9_]{1,40}$/;
// Etkinlik görevinin sayabileceği metrikler → panelde görünen ad (oyundaki LiveEvent.MISSION_TEXTS ile aynı anahtarlar)
export const MISSION_METRICS = {
  repairs: "Tamir yap", repair_money: "Tamirden ₺ kazan", long_jobs: "Uzun iş tamamla", races: "Yarışa katıl",
  race_wins: "Yarış kazan", event_rival_wins: "Etkinlik rakibini yen", crates_opened: "Kasa aç", crates_bought: "Kasa sipariş et",
  decor_placed: "Eşya yerleştir", decor_bought: "Eşya satın al", paints: "Araç boya", mods_installed: "Modifiye tak",
  junk_searches: "Hurdalıkta yığın ara", junk_parts: "Hurdalıktan parça topla", friend_races: "Arkadaş yarışına katıl",
  friend_wins: "Arkadaş yarışı kazan", money_spent: "₺ harca",
  // 2026-10-26 etkinlik aracı / takvim: oyundaki metinle aynı (%s = hedef)
  event_car_wins: "ETKİNLİK ARACIYLA %s YARIŞ KAZAN", event_car_races: "ETKİNLİK ARACIYLA %s YARIŞA KATIL",
  garage_visits: "%s ARKADAŞ GARAJI ZİYARET ET",
};
// Yalnız etkinlik aracıyla sayılan görevler: etkinlikte araç (car) yoksa tamamlanamaz
const CAR_METRICS = ["event_car_wins", "event_car_races"];
export const EVENTS_MAX = 12;
export const REVEAL_DAYS_MAX = 14;
export const REVEAL_DAYS_DEFAULT = 3;
export const OWNED_GEMS_MAX = 1000;
// Kaydederken listeden düşen etkinlik: bitişinin üzerinden bu kadar geçmiş (panel bitenleri bir süre soluk gösterir)
export const EVENTS_KEEP_ENDED = 30 * 86400;

const num = (v, lo, hi, what) => {
  const n = v === "" || v === undefined || v === null ? lo : Number(v);
  if (!Number.isFinite(n) || n < lo || n > hi) throw new PanelError(`${what}: ${lo} ile ${hi} arasında olmalı`);
  return Math.round(n * 100) / 100;
};

/** Ödül alanları: ₺, elmas, XP, kasa (satılan kasa), eşya (oyunun ya da bir içerik paketinin eşya kimliği). */
function buildReward(src, catalog, what) {
  const crate = String(src.crate || "").trim();
  if (crate && catalog && !catalog.crates.some((c) => c.id === crate)) throw new PanelError(`${what}: bilinmeyen kasa "${crate}"`);
  const decor = String(src.decor || "").trim();
  if (decor && !ID_RE.test(decor)) throw new PanelError(`${what}: eşya kimliği küçük harf / rakam / _`);
  return {
    money: int(src.money, 0, REWARD_MAX.money, `${what} ₺`),
    gems: int(src.gems, 0, REWARD_MAX.gems, `${what} elmas`),
    xp: int(src.xp, 0, REWARD_MAX.xp, `${what} XP`),
    crate, decor,
  };
}

/** İçerik paketleri listesi: [{id, url (https), sha256, size}]; aynı kimlik iki kez olmaz. */
export function buildPacks(input) {
  const out = [];
  for (const p of Array.isArray(input) ? input : []) {
    const id = String(p && p.id || "").trim();
    const url = String(p && p.url || "").trim();
    const sha256 = String(p && p.sha256 || "").trim().toLowerCase();
    if (!ID_RE.test(id)) throw new PanelError("Paket kimliği: küçük harf / rakam / _ (en çok 40)");
    if (out.some((x) => x.id === id)) throw new PanelError(`Paket "${id}" iki kez listede`);
    if (!/^https:\/\/[^\s]+$/.test(url)) throw new PanelError(`Paket "${id}": adres https:// ile başlamalı`);
    if (!/^[0-9a-f]{64}$/.test(sha256)) throw new PanelError(`Paket "${id}": sha256 64 onaltılık karakter olmalı`);
    out.push({ id, url, sha256, size: int(p.size, 1, 64 * 1024 * 1024, `Paket "${id}" boyutu`) });
  }
  return out;
}

/**
 * Panel formundan canlı etkinlik (oyundaki LiveEvent.normalize ile aynı sınırlar). Modüller: money_mult / xp_mult (1–3),
 * sale {crates, cars, decor, mods: 0–50}, crate_boost {crate, cars (havuzdan), mult 2–5}, missions [{metric, target, ödül}]
 * (en çok 6), rival {car, stage 0–5, name, paint, ödül}, pack (packs listesinden), car {id, owned_gems 0–1000, owned_crate}
 * (ETKİNLİK ARACI: bütün görevleri bitiren kalıcı alır; en az bir görev şart; oyuncuda zaten varsa owned_gems / owned_crate
 * teselli ödülü). Hiçbir modül yoksa null (etkinlik yok). Ek alanlar: reveal_days (0–14, varsayılan 3; yalnız araçlı etkinlikte
 * yazılır: oyundaki takvim aracı başlangıçtan bu kadar gün önce gösterir), notify (yalnız true yazılır: başlayınca bildirim,
 * functions/events_tick.js). catalog verilmezse kimlikler katalogla sınanmaz (eski testler).
 */
export function buildEvent(input, catalog = null, packs = []) {
  if (!input) return null;
  const event = {};
  const moneyMult = Number(input.money_mult || 1);
  const xpMult = Number(input.xp_mult || 1);
  if (!(moneyMult >= 1 && moneyMult <= 3) || !(xpMult >= 1 && xpMult <= 3)) throw new PanelError("Çarpan 1 ile 3 arasında olmalı");
  if (moneyMult > 1) event.money_mult = Math.round(moneyMult * 100) / 100;
  if (xpMult > 1) event.xp_mult = Math.round(xpMult * 100) / 100;
  const sale = {};
  for (const kind of SALE_KINDS) {
    const p = int(input.sale && input.sale[kind], 0, SALE_MAX, `İndirim (${kind}) yüzdesi`);
    if (p > 0) sale[kind] = p;
  }
  if (!empty(sale)) event.sale = sale;
  const boost = input.crate_boost;
  if (boost && boost.crate) {
    const crate = catalog ? catalog.crates.find((c) => c.id === boost.crate) : { id: boost.crate, pool: null };
    if (!crate) throw new PanelError(`Etkinlik kasası: bilinmeyen kasa "${boost.crate}"`);
    const cars = [...new Set((boost.cars || []).map(String))];
    if (!cars.length) throw new PanelError("Etkinlik kasası: en az bir araç seç");
    for (const car of cars) {
      if (crate.pool && !crate.pool.includes(car)) throw new PanelError(`Etkinlik kasası: "${car}" bu kasanın havuzunda değil`);
    }
    event.crate_boost = { crate: crate.id, cars, mult: num(boost.mult, BOOST_MIN, BOOST_MAX, "Kasa şans çarpanı") };
  }
  const missions = [];
  for (const [i, m] of (Array.isArray(input.missions) ? input.missions : []).entries()) {
    if (!m || !m.metric) continue;
    if (!(m.metric in MISSION_METRICS)) throw new PanelError(`Görev ${i + 1}: bilinmeyen görev türü "${m.metric}"`);
    const id = String(m.id || `m${i + 1}`).trim();
    if (!ID_RE.test(id) || missions.some((x) => x.id === id)) throw new PanelError(`Görev ${i + 1}: kimlik geçersiz ya da yinelenmiş`);
    missions.push({ id, metric: m.metric, target: int(m.target, 1, 1_000_000, `Görev ${i + 1} hedefi`),
      ...buildReward(m, catalog, `Görev ${i + 1} ödülü`) });
  }
  if (missions.length > MISSION_MAX) throw new PanelError(`En çok ${MISSION_MAX} etkinlik görevi`);
  if (missions.length) event.missions = missions;
  const rival = input.rival;
  if (rival && rival.car) {
    if (catalog && !catalog.cars.some((c) => c.id === rival.car)) throw new PanelError(`Özel rakip: bilinmeyen ya da edinilemeyen araç "${rival.car}"`);
    const paint = String(rival.paint || "").trim();
    if (paint && !/^#[0-9a-fA-F]{6}$/.test(paint)) throw new PanelError("Özel rakip boyası #RRGGBB olmalı");
    const name = String(rival.name || "").trim();
    if (name.length > 24) throw new PanelError("Özel rakip adı en çok 24 karakter");
    event.rival = { car: rival.car, stage: int(rival.stage, 0, RIVAL_STAGE_MAX, "Özel rakip kademesi"), name, paint,
      ...buildReward(rival, catalog, "Özel rakip ödülü") };
  }
  const pack = String(input.pack || "").trim();
  if (pack) {
    if (!packs.some((p) => p.id === pack)) throw new PanelError(`İçerik paketi "${pack}" paket listesinde yok`);
    event.pack = pack;
  }
  const car = input.car && typeof input.car === "object" ? input.car : null;
  const carId = car ? String(car.id || "").trim() : "";
  if (carId) {
    if (catalog && !catalog.cars.some((c) => c.id === carId)) throw new PanelError(`Etkinlik aracı: bilinmeyen ya da edinilemeyen araç "${carId}"`);
    if (!ID_RE.test(carId)) throw new PanelError("Etkinlik aracı kimliği geçersiz");
    const ownedCrate = String(car.owned_crate || "").trim();
    if (ownedCrate && catalog && !catalog.crates.some((c) => c.id === ownedCrate)) {
      throw new PanelError(`Etkinlik aracı teselli kasası: bilinmeyen kasa "${ownedCrate}" (yalnız satılan kasalar)`);
    }
    if (ownedCrate && !ID_RE.test(ownedCrate)) throw new PanelError("Etkinlik aracı teselli kasası geçersiz");
    if (!missions.length) throw new PanelError("Etkinlik aracı için en az bir görev gerekli");
    event.car = { id: carId, owned_gems: int(car.owned_gems, 0, OWNED_GEMS_MAX, "Etkinlik aracı teselli elması"), owned_crate: ownedCrate };
  }
  const carMission = missions.findIndex((m) => CAR_METRICS.includes(m.metric));
  if (carMission >= 0 && !event.car) {
    throw new PanelError(`Görev ${carMission + 1}: "${MISSION_METRICS[missions[carMission].metric].replace("%s ", "")}" için etkinlik aracı seç (7)`);
  }
  if (empty(event)) return null;
  const start = int(input.start, 0, 4_000_000_000, "Etkinlik başlangıcı");
  const end = int(input.end, 1, 4_000_000_000, "Etkinlik bitişi");
  if (end <= start) throw new PanelError("Etkinlik bitişi başlangıçtan sonra olmalı");
  const id = String(input.id || "").trim();
  if (!ID_RE.test(id)) throw new PanelError("Etkinlik kimliği: küçük harf / rakam / _");
  const out = { id, title: texts(input.title, MAX_TITLE, "Etkinlik başlığı"), text: texts(input.text, MAX_TEXT, "Etkinlik metni"),
    start, end, money_mult: event.money_mult || 1, xp_mult: event.xp_mult || 1, ...event };
  if (event.car) {
    const reveal = input.reveal_days;
    out.reveal_days = reveal === undefined || reveal === null || reveal === ""
      ? REVEAL_DAYS_DEFAULT : int(reveal, 0, REVEAL_DAYS_MAX, "Takvimde araç gösterimi (gün)");
  }
  if (input.notify === true) out.notify = true;
  return out;
}

/** Hata iletisindeki saat: İstanbul saatiyle gg.aa.yyyy ss:dd. */
const clock = (sec) => new Date(sec * 1000).toLocaleString("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit", month: "2-digit",
  year: "numeric", hour: "2-digit", minute: "2-digit" });

/** Etkinliğin paneldeki adı (hata iletileri): Türkçe başlık, yoksa İngilizce, o da yoksa kimlik; when: tarih aralığı da. */
function eventName(e, when = false) {
  const t = e && e.title && typeof e.title === "object" ? e.title : {};
  const title = String(t.tr || t.en || "").trim();
  const id = String((e && e.id) || "").trim();
  const extra = [title ? id || "yeni" : "", when ? `${clock(e.start)} → ${clock(e.end)}` : ""].filter(Boolean).join(", ");
  return `"${title || id || "yeni etkinlik"}"` + (extra ? ` (${extra})` : "");
}

/**
 * Etkinlik takvimi (config/app.events): her öğe buildEvent ile doğrulanır (modülsüz öğe hata), bitişinin üzerinden 30 günden
 * fazla geçmiş olanlar düşer, kimlikler tekil, en çok 12, başlangıca göre sıralı, zaman pencereleri ÇAKIŞMAZ (oyun aynı anda tek
 * etkinlik gösterir; art arda gelmek — biri bitince öbürü başlar — serbest). nowS: unix sn.
 */
export function buildEvents(input, catalog, packs, nowS) {
  if (input !== undefined && input !== null && !Array.isArray(input)) throw new PanelError("Etkinlik listesi bir dizi olmalı");
  const out = [];
  for (const raw of input || []) {
    let e;
    try {
      e = buildEvent(raw, catalog, packs);
    } catch (err) {
      if (err instanceof PanelError) throw new PanelError(`Etkinlik ${eventName(raw)}: ${err.message}`);
      throw err;
    }
    if (!e) throw new PanelError(`Etkinlik ${eventName(raw)}: en az bir modül doldur (çarpan, indirim, kasa, görev, rakip, paket ya da araç)`);
    if (e.end < nowS - EVENTS_KEEP_ENDED) continue;
    const dup = out.find((x) => x.id === e.id);
    if (dup) throw new PanelError(`Etkinlik kimliği iki kez listede: ${e.id} (${eventName(dup)} ve ${eventName(e)})`);
    out.push(e);
  }
  if (out.length > EVENTS_MAX) throw new PanelError(`Takvimde en çok ${EVENTS_MAX} etkinlik olabilir (${out.length} var): biten ya da uzak etkinliği sil`);
  out.sort((a, b) => a.start - b.start || a.end - b.end || (a.id < b.id ? -1 : 1));
  for (let i = 1; i < out.length; i++) {
    const a = out[i - 1];
    const b = out[i];
    if (b.start < a.end) {
      throw new PanelError(`Etkinlikler çakışıyor: ${eventName(a, true)} ile ${eventName(b, true)}. Oyun aynı anda tek etkinlik ` +
        "gösterir: tarihleri ayır (biri bitince öbürü başlayabilir).");
    }
  }
  return out;
}

// --- Ödüllü reklam ayarları (config/app.ads; oyundaki AdPolicy.normalize_remote ile aynı sınırlar) -------------

// Teklif türü → panel adı ve oyundaki varsayılan günlük sınır (AdPolicy.RULES)
export const AD_KINDS = {
  free_gems: { label: "MARKET · ücretsiz elmas", cap: 5 },
  race_double: { label: "Yarış ödülü ×2", cap: 5 },
  offline_double: { label: "OTO MANŞET kazancı ×2", cap: 2 },
  daily_double: { label: "Günlük giriş elması ×2", cap: 1 },
  levelup_double: { label: "Seviye ödülü ×2", cap: 3 },
  repair_boost: { label: "Uzun tamiri kısalt", cap: 8 },
  time_skip: { label: "Modifiye / depo / iç yükseltme süresi yarıya", cap: 8 },
  mission_reroll: { label: "Günlük görevi değiştir", cap: 1 },
  junk_refill: { label: "Hurdalık yığınını doldur", cap: 2 },
  event_race: { label: "Etkinlik yarışı +1 hak", cap: 1 },
};
export const AD_DEFAULTS = { total_cap: 20, free_gems: 5, free_gems_cooldown: 180 };

/** Panel formundan reklam ayarı: total_cap 0–100, free_gems 1–50 (reklam başına elmas), free_gems_cooldown 0–3600 sn,
 *  caps {tür: 0–50} (0 = o teklif kapalı). Varsayılana eşit alanlar da yazılır (oyun hep panelin değerini kullanır). */
export function buildAds(input) {
  const src = input || {};
  const caps = {};
  for (const kind of Object.keys(AD_KINDS)) {
    const v = src.caps && src.caps[kind];
    if (v === undefined || v === null || v === "") continue;
    caps[kind] = int(v, 0, 50, `${AD_KINDS[kind].label} günlük sınırı`);
  }
  for (const kind of Object.keys(src.caps || {})) {
    if (!(kind in AD_KINDS)) throw new PanelError(`Bilinmeyen reklam türü "${kind}"`);
  }
  return {
    total_cap: int(src.total_cap ?? AD_DEFAULTS.total_cap, 0, 100, "Günlük toplam reklam sınırı"),
    free_gems: int(src.free_gems ?? AD_DEFAULTS.free_gems, 1, 50, "Reklam başına elmas"),
    free_gems_cooldown: int(src.free_gems_cooldown ?? AD_DEFAULTS.free_gems_cooldown, 0, 3600, "Ücretsiz elmas beklemesi (sn)"),
    caps,
  };
}

// Ayna kurucusu functions/events_tick.js'te (zamanlayıcı da kullanır): tek kaynak, panel aynısını çağırır
export const { mirrorEvent } = createRequire(import.meta.url)("../functions/events_tick.js");

/** Panelin göstereceği takvim: config/app.events; takvim hiç kaydedilmemişse eski tek etkinlik (config/app.event) listede. */
export function eventsOf(config) {
  const c = config || {};
  if (Array.isArray(c.events)) return c.events;
  return c.event && typeof c.event === "object" ? [c.event] : [];
}

/**
 * config/app'in takvim + paket kısmı (POST /api/events): input {events, packs}. events (buildEvents) ve eski sürümlerin aynası
 * event (mirrorEvent: süren, yoksa sıradaki, yoksa alan silinir) birlikte yazılır; boş takvim events: [] olarak kalır (eventsTick
 * takvimi yönetilen sayar). Mevcut belgenin öbür alanlarına (min_code, maintenance, notice, ads …) dokunulmaz. now: unix ms.
 */
export function buildEventsDoc(input, catalog, current, now) {
  const src = input || {};
  const nowS = Math.floor(now / 1000);
  const packs = buildPacks(src.packs);
  const events = buildEvents(src.events, catalog, packs, nowS);
  const doc = { ...(current || {}) };
  doc.events = events;
  const mirror = mirrorEvent(events, nowS);
  if (mirror) doc.event = mirror;
  else delete doc.event;
  if (packs.length) doc.packs = packs;
  else delete doc.packs;
  doc.updated_at = nowS;
  return doc;
}

/** Yarış öğrenmesi ayarı (config/race_learning, MERGE: gece fonksiyonunun tablosu korunur; oyundaki RaceLearning):
 *  off (öğrenme kapalı → başlangıç kuralı), window (yarış sonrası kalış penceresi sn, 60–1800), weight (genel tablonun
 *  önsel ağırlığı, yarış sayısı 1–200). docs/KOSU_ESLESTIRME.md Faz 2. */
export function buildLearning(input) {
  const src = input || {};
  return {
    off: src.off === true,
    window: int(src.window ?? 300, 60, 1800, "Kalış penceresi (sn)"),
    weight: int(src.weight ?? 20, 1, 200, "Genel tablo ağırlığı"),
  };
}

/** Hedefli gönderim süzgeci: {level_min, level_max, active_days (son N günde oynamış), inactive_days (N gündür oynamamış),
 *  build_max (bu sürüm kodu ve altı), lang}. Boş alan = süzme yok. */
export function buildSegment(input) {
  const f = input || {};
  const opt = (v, lo, hi, what) => (v === "" || v === undefined || v === null ? null : int(v, lo, hi, what));
  const seg = {
    level_min: opt(f.level_min, 1, 99, "En düşük seviye"),
    level_max: opt(f.level_max, 1, 99, "En yüksek seviye"),
    active_days: opt(f.active_days, 1, 3650, "Son kaç günde oynamış"),
    inactive_days: opt(f.inactive_days, 1, 3650, "Kaç gündür oynamamış"),
    build_max: opt(f.build_max, 0, 1_000_000, "En yüksek sürüm kodu"),
    lang: f.lang ? String(f.lang) : null,
  };
  if (seg.lang !== null && !LANGS.includes(seg.lang)) throw new PanelError("Geçersiz dil");
  if (seg.level_min !== null && seg.level_max !== null && seg.level_min > seg.level_max) throw new PanelError("Seviye aralığı ters");
  return seg;
}

/** Oyuncu süzgece uyuyor mu. p: {stats, updated_at}; stats yoksa (eski sürüm) seviye / dil / sürüm süzgeçleri uymaz sayılır. */
export function matchSegment(p, seg, now) {
  const s = p.stats || {};
  const nowS = Math.floor(now / 1000);
  const updated = Number(p.updated_at || 0);
  if (seg.level_min !== null && !(s.level >= seg.level_min)) return false;
  if (seg.level_max !== null && !(s.level <= seg.level_max)) return false;
  if (seg.active_days !== null && !(updated >= nowS - seg.active_days * 86400)) return false;
  if (seg.inactive_days !== null && !(updated < nowS - seg.inactive_days * 86400)) return false;
  if (seg.build_max !== null && !(Number.isInteger(s.build) && s.build <= seg.build_max)) return false;
  if (seg.lang !== null && s.lang !== seg.lang) return false;
  return true;
}

// --- Haftalık drag lider tablosu (docs/LIDER_TABLOSU.md; hafta hesabı, sınıflar, ödül varsayılanları ve hile sınırı
// functions/leaderboard.js ile AYNI kod: tek kaynak) ----------------------------------------------------------------------

export const {
  CLASSES: LB_CLASSES, TIERS: LB_TIERS, DEFAULT_REWARDS: LB_DEFAULT_REWARDS, REWARD_GEMS_MAX: LB_GEMS_MAX, LIMITS: LB_LIMITS,
  weekOf: lbWeekOf, weekStart: lbWeekStart, parseId: lbParseId, rewardsFrom: lbRewardsFrom,
} = createRequire(import.meta.url)("../functions/leaderboard.js");
export const LB_LIST_MAX = 100;
// Panel en çok bu kadar geriye bakar (eski haftalar lb_runs'ta durur; ödül pazartesi ödenir)
export const LB_WEEKS_BACK = 52;
export const LB_TIER_NAMES = { top3: "İLK 3", p10: "İLK %10", p50: "İLK %50" };
// Satırda okunan alanlar (koşu kaydı run listeye gelmez: İZLE için oyun okur)
export const LB_FIELDS = ["uid", "wk", "cls", "time", "car", "paint", "stage", "level", "name", "av", "flag", "at"];

/** Liste isteği: {wk (boş = bu hafta), cls, cc (boş = DÜNYA, yoksa iki harf ülke kodu)}. nowS: unix sn. */
export function lbQuery(input, nowS) {
  const src = input || {};
  const current = lbWeekOf(nowS);
  const wk = src.wk === undefined || src.wk === null || src.wk === "" ? current
    : int(src.wk, current - LB_WEEKS_BACK, current, "Hafta");
  const cls = String(src.cls || "").trim().toUpperCase();
  if (!LB_CLASSES.includes(cls)) throw new PanelError(`Sınıf: ${LB_CLASSES.join(", ")}`);
  const cc = String(src.cc || "").trim().toUpperCase();
  if (cc && !/^[A-Z]{2}$/.test(cc)) throw new PanelError("Ülke: iki harfli kod (TR, DE …) ya da boş (DÜNYA)");
  return { wk, cls, cc, current };
}

/** Haftanın tarih aralığı (İstanbul saati): "26.10.2026 – 01.11.2026". */
export function lbWeekLabel(wk) {
  const day = (sec) => new Date(sec * 1000).toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", day: "2-digit",
    month: "2-digit", year: "numeric" });
  const start = lbWeekStart(wk);
  return `${day(start)} – ${day(start + 6 * 86400)}`;
}

/**
 * Sorgu sonucundan (süreye göre) panel satırları: sıra, kısa UID, aracın katalog adı, hile sınırı (sınırın %2 yakınındaki
 * süre "near": incelemeye değer). docs: [{id, data}]; limits: {araç: sn}.
 */
export function lbRows(docs, catalog, limits = LB_LIMITS) {
  const names = new Map((catalog && catalog.cars ? catalog.cars : []).map((c) => [c.id, c.name]));
  return (docs || []).map(({ id, data }, i) => {
    const d = data || {};
    const parsed = lbParseId(id);
    const uid = parsed ? parsed.uid : String(d.uid || "");
    const car = String(d.car || "");
    const limit = Object.hasOwn(limits, car) ? Number(limits[car]) : 0;
    const time = Number(d.time) || 0;
    return {
      rank: i + 1, id, uid, uid_short: uid.slice(0, 8), name: String(d.name || "").slice(0, 16), flag: String(d.flag || ""),
      av: String(d.av || ""), car, car_name: names.get(car) || car, paint: String(d.paint || ""), stage: Number(d.stage) || 0,
      level: Number(d.level) || 0, time, at: Number(d.at) || 0, limit, near: limit > 0 && time < limit * 1.02,
    };
  });
}

/** Ödül kademelerinin sıra kesimi (functions/leaderboard.js tierFor ile aynı): İLK %10 ve İLK %50 kaçıncı sıraya kadar. */
export function lbCuts(count) {
  const n = Math.max(0, Math.trunc(Number(count) || 0));
  return { n10: Math.ceil(n * 0.1), n50: Math.ceil(n * 0.5) };
}

/** Panel formundan config/app.leaderboard.rewards: {top3, p10, p50: {gems 0–1000, crate: "" ya da satılan kasa}}. */
export function buildLbRewards(input, catalog) {
  const src = input && typeof input === "object" ? input : {};
  const crates = new Set((catalog && catalog.crates ? catalog.crates : []).map((c) => c.id));
  const out = {};
  for (const tier of LB_TIERS) {
    const r = src[tier] && typeof src[tier] === "object" ? src[tier] : {};
    const crate = String(r.crate ?? "").trim();
    if (crate && !crates.has(crate)) throw new PanelError(`${LB_TIER_NAMES[tier]}: bilinmeyen kasa "${crate}" (yalnız satılan kasalar)`);
    out[tier] = { gems: int(r.gems, 0, LB_GEMS_MAX, `${LB_TIER_NAMES[tier]} elması`), crate };
  }
  for (const k of Object.keys(src)) if (!LB_TIERS.includes(k)) throw new PanelError(`Bilinmeyen ödül kademesi "${k}"`);
  return out;
}
