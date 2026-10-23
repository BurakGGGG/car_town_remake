// AUTO YARD yönetim paneli — saf mantık (sunucu server.mjs bağlar; test/lib.test.mjs internetsiz sınar).
// Belgelerin biçimi oyundakiyle aynıdır:
//   config/app             gameplay/backend/app_config.gd (AppConfig); event modülleri ve packs gameplay/backend/live_event.gd /
//                          live_packs.gd (aynı sınırlar: SALE_MAX, BOOST, MISSION_MAX, RIVAL_STAGE_MAX, ödül sınırları)
//   users/{uid}/mail/{id}  gameplay/backend/mail_service.gd (MailService.normalize aynı sınırları uygular)
//   bildirim konusu        gameplay/social/push_service.gd (news_<dil>)
import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

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
 * decor: {id: adet}, expires_days, notify}. now: unix ms.
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
  const days = int(input.expires_days, 0, 365, "Geçerlilik (gün)");
  if (days > 0) doc.expires = doc.at + days * 86400;
  if (empty(doc.title) && empty(doc.text) && !hasReward(doc)) throw new PanelError("Postada ne mesaj ne ödül var");
  if (empty(doc.title) && empty(doc.text)) throw new PanelError("Hediyeye en az bir başlık ya da mesaj yaz");
  return doc;
}

export function hasReward(doc) {
  return doc.money > 0 || doc.gems > 0 || !empty(doc.crates) || !empty(doc.decor);
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

// --- Canlı etkinlik (config/app.event) ve içerik paketleri (config/app.packs) ---------------

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
};

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
 * (en çok 6), rival {car, stage 0–5, name, paint, ödül}, pack (packs listesinden). Hiçbir modül yoksa null (etkinlik yok).
 * catalog verilmezse kimlikler katalogla sınanmaz (eski testler).
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
  if (empty(event)) return null;
  const start = int(input.start, 0, 4_000_000_000, "Etkinlik başlangıcı");
  const end = int(input.end, 1, 4_000_000_000, "Etkinlik bitişi");
  if (end <= start) throw new PanelError("Etkinlik bitişi başlangıçtan sonra olmalı");
  const id = String(input.id || "").trim();
  if (!ID_RE.test(id)) throw new PanelError("Etkinlik kimliği: küçük harf / rakam / _");
  return { id, title: texts(input.title, MAX_TITLE, "Etkinlik başlığı"), text: texts(input.text, MAX_TEXT, "Etkinlik metni"),
    start, end, money_mult: event.money_mult || 1, xp_mult: event.xp_mult || 1, ...event };
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

/** config/app'in etkinlik + paket kısmı (POST /api/event): mevcut belgenin öbür alanlarına dokunulmaz. */
export function buildEventDoc(input, catalog, current, now) {
  const packs = buildPacks(input.packs);
  const event = buildEvent(input.event, catalog, packs);
  const doc = { ...(current || {}) };
  delete doc.event;
  if (event) doc.event = event;
  if (packs.length) doc.packs = packs;
  else delete doc.packs;
  doc.updated_at = Math.floor(now / 1000);
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
