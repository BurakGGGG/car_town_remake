// lib.mjs testi (internetsiz). Çalıştırma: cd firebase/admin && npm test
import test from "node:test";
import assert from "node:assert";
import { gzipSync } from "node:zlib";
import {
  PanelError, loadCatalog, buildInfo, buildMail, hasReward, mailId, buildConfig, buildNews, classifyQuery, unpackSave, texts, MAX_GEMS,
  statsFromSave, buildBan, banActive, moderatedName, groupReports, buildAdjust, buildRestore,
  buildPromo, buildEvent, buildSegment, matchSegment, buildLearning, buildPacks, buildEventDoc, SALE_MAX, MISSION_METRICS,
  buildAds, AD_KINDS, buildNewsPost, newsId, NEWS_ID_RE, newsImage, newsAction, newsTarget, decodeNewsImage, imageKind,
  bucketCandidates, isMissingBucket, storageUrl, NEWS_IMAGE_BYTES, buildNewsFeed, NEWS_FEED_DOC, NEWS_FEED_MAX,
} from "../lib.mjs";

const catalog = loadCatalog(new URL("../../../", import.meta.url));
const NOW = 1_760_000_000_000;

test("katalog: satılan kasalar, garaja konan eşyalar (kaplama / karo / hediye kasası yok)", () => {
  assert.ok(catalog.crates.some((c) => c.id === "city_crate"));
  assert.ok(!catalog.crates.some((c) => c.id === "welcome_crate"), "HOŞ GELDİN KUTUSU panelden verilmez");
  assert.ok(catalog.decor.some((d) => d.id === "tool_cabinet"));
  assert.ok(!catalog.decor.some((d) => d.id === "floor_tile"), "kaplama verilmez");
  assert.ok(catalog.crates.find((c) => c.id === "city_crate").pool.includes("ford_focus"), "kasanın havuzu (etkinlik kasası)");
  assert.ok(catalog.cars.some((c) => c.id === "ford_focus") && !catalog.cars.some((c) => c.id === "police_vito"),
    "rakip olabilecek araçlar: edinilemeyen polis yok");
  assert.ok("event_rival_wins" in catalog.metrics, "etkinlik görevi türleri");
});

test("sürüm: export_presets.cfg", () => {
  assert.deepEqual(buildInfo('x\nversion/code=10\nversion/name="1.0.9"\n'), { code: 10, name: "1.0.9" });
});

test("posta: sınırlar ve doğrulama", () => {
  const doc = buildMail({ title: { tr: " Hoş geldin ", en: "" }, text: "Hediye!", money: "1500", gems: 40,
    crates: { city_crate: 2 }, decor: { tool_cabinet: 1 }, expires_days: 7 }, catalog, NOW);
  assert.deepEqual(doc.title, { tr: "Hoş geldin" }, "boş dil yazılmaz, kırpılır");
  assert.deepEqual(doc.text, { tr: "Hediye!" }, "düz metin Türkçe sayılır");
  assert.equal(doc.money, 1500);
  assert.equal(doc.expires, doc.at + 7 * 86400);
  assert.equal(doc.notify, true);
  assert.equal(doc.from, "AUTO YARD");
  assert.throws(() => buildMail({ text: "x", gems: MAX_GEMS + 1 }, catalog, NOW), PanelError);
  assert.throws(() => buildMail({ text: "x", money: -1 }, catalog, NOW), PanelError);
  assert.throws(() => buildMail({ text: "x", money: 1.5 }, catalog, NOW), PanelError);
  assert.throws(() => buildMail({ text: "x", crates: { yok_kasa: 1 } }, catalog, NOW), /bilinmeyen/);
  assert.throws(() => buildMail({ text: "x", decor: { floor_tile: 1 } }, catalog, NOW), /bilinmeyen/);
  assert.throws(() => buildMail({ text: "x", crates: { city_crate: 99 } }, catalog, NOW), PanelError);
  assert.throws(() => buildMail({ gems: 5 }, catalog, NOW), /başlık ya da mesaj/, "ödüllü ama metinsiz posta");
  assert.throws(() => buildMail({}, catalog, NOW), PanelError);
  assert.throws(() => buildMail({ text: "x".repeat(501) }, catalog, NOW), /500/);
  assert.equal(buildMail({ text: "x", notify: false }, catalog, NOW).notify, false);
});

test("posta: araç hediyesi", () => {
  const doc = buildMail({ title: "Araç hediyesi", cars: { ford_focus: 3 } }, catalog, NOW);
  assert.deepEqual(doc.cars, { ford_focus: 1 }, "her araç bir adet");
  assert.ok(hasReward(doc), "araç ödül sayılır");
  assert.ok(!("cars" in buildMail({ text: "x" }, catalog, NOW)), "araçsız postada alan yok");
  assert.throws(() => buildMail({ text: "x", cars: { police_vito: 1 } }, catalog, NOW), /bilinmeyen/, "edinilemeyen araç verilmez");
  assert.throws(() => buildMail({ text: "x", cars: { yok_arac: 1 } }, catalog, NOW), /bilinmeyen/);
});

test("posta kimliği: tek / herkes", () => {
  assert.match(mailId("one", NOW, "a1b2c3d4"), /^m_[a-z0-9]+_a1b2c3$/);
  assert.match(mailId("all", NOW, "ZZ"), /^c_[a-z0-9]+_zz$/);
});

test("uzaktan ayar", () => {
  const doc = buildConfig({ min_code: 10, latest_code: 11, maintenance: true, maintenance_text: { tr: "Bakım" },
    notice: { id: "n_abc", text: { tr: "Etkinlik!" }, title: {} } }, NOW);
  assert.equal(doc.min_code, 10);
  assert.equal(doc.maintenance, true);
  assert.deepEqual(doc.notice, { id: "n_abc", title: {}, text: { tr: "Etkinlik!" }, until: 0 });
  assert.equal(buildConfig({ maintenance: "true" }, NOW).maintenance, false, "yalnız gerçek true bakımı açar");
  assert.equal(buildConfig({ notice: { id: "n1", text: {} } }, NOW).notice, undefined, "metinsiz duyuru yazılmaz");
  assert.throws(() => buildConfig({ min_code: 12, latest_code: 11 }, NOW), /küçük olamaz/);
  assert.throws(() => buildConfig({ notice: { id: "Büyük Harf", text: { tr: "x" } } }, NOW), /kimliği/);
});

test("duyuru: her dil konusuna, eksik dil İngilizce / Türkçe", () => {
  const msgs = buildNews({ title: { tr: "Etkinlik" }, body: { tr: "Çifte para!", en: "Double money!" } });
  assert.deepEqual(msgs.map((m) => m.topic), ["news_tr", "news_en", "news_es", "news_de", "news_fr"]);
  assert.equal(msgs[0].notification.body, "Çifte para!");
  assert.equal(msgs[3].notification.body, "Double money!", "de → en");
  assert.equal(msgs[1].notification.title, "Etkinlik", "başlık en yoksa tr");
  assert.deepEqual(msgs[0].data, { type: "news" });
  assert.throws(() => buildNews({ body: {} }), /boş/);
});

test("oyuncu arama türü", () => {
  assert.deepEqual(classifyQuery("abc234"), { kind: "code", value: "ABC234" });
  assert.deepEqual(classifyQuery(" Ali@Mail.com "), { kind: "email", value: "ali@mail.com" });
  assert.equal(classifyQuery("Xy9_abcDEF123").kind, "uid");
  assert.throws(() => classifyQuery("a b"), PanelError);
  assert.throws(() => classifyQuery("../x"), PanelError);
});

test("kayıt açma: sıkışık (oyunun CloudPack biçimi) ve düz", () => {
  const save = { economy: { money: 5 } };
  assert.deepEqual(unpackSave("gz1:" + gzipSync(JSON.stringify(save)).toString("base64")), save);
  assert.deepEqual(unpackSave(JSON.stringify(save)), save);
  assert.equal(unpackSave(""), null);
});

test("dil metni sınırı", () => {
  assert.deepEqual(texts({ tr: "a", xx: "b" }, 10, "t"), { tr: "a" }, "bilinmeyen dil atılır");
  assert.throws(() => texts({ en: "x".repeat(11) }, 10, "t"), /10/);
});

test("özet eski kayıttan (stats alanı yoksa)", () => {
  const save = { economy: { money: 25000.0 }, progress: { gems: 140, level: 7 }, vehicles: { owned: ["a", "b", "c"] } };
  assert.deepEqual(statsFromSave(save), { money: 25000, gems: 140, level: 7, cars: 3, build: null });
  assert.deepEqual(statsFromSave({}), { money: 0, gems: 0, level: 1, cars: 0, build: null });
  assert.equal(statsFromSave(null), null);
});

test("yasak: doğrulama, süre, kalıcı", () => {
  const b = buildBan({ kind: "social", reason: "name", text: " Küfür ", days: 7 }, NOW);
  assert.equal(b.until, Math.floor(NOW / 1000) + 7 * 86400);
  assert.equal(b.text, "Küfür");
  assert.equal(buildBan({ kind: "full", reason: "cheat", days: 0 }, NOW).until, 0, "0 gün = kalıcı");
  assert.throws(() => buildBan({ kind: "ban", reason: "name" }, NOW), /tür/);
  assert.throws(() => buildBan({ kind: "social", reason: "__proto__" }, NOW), /sebep/);
  assert.throws(() => buildBan({ kind: "social", reason: "name", text: "x".repeat(201) }, NOW), /200/);
  assert.equal(banActive({ kind: "social", until: 0 }, NOW), true);
  assert.equal(banActive({ kind: "social", until: Math.floor(NOW / 1000) - 1 }, NOW), false);
  assert.equal(banActive(null, NOW), false);
});

test("sıfırlanan ad oyundaki biçimde", () => {
  assert.match(moderatedName(123456), /^Usta[0-9]{4}$/);
  assert.match(moderatedName(-5), /^Usta[0-9]{4}$/);
});

test("şikâyetler hedefe göre toplanır", () => {
  const img = "A".repeat(30);
  const groups = groupReports([
    { id: "x_alice1_bob222", data: { target: "bob222", reason: "photo", name: "Bob", img, at: 5 } },
    { id: "x_carol1_bob222", data: { target: "bob222", reason: "name", name: "Bobb", at: 9 } },
    { id: "x_alice1_dave33", data: { target: "dave33", reason: "garage", name: "Dave", at: 7 } },
    { id: "x_eve111_zz", data: { target: "../x", reason: "name", at: 1 } },
    { id: "x_eve111_mal999", data: { target: "mal999", reason: "photo", img: "<script>", at: 2 } },
  ]);
  assert.deepEqual(groups.map((g) => g.target), ["bob222", "dave33", "mal999"], "en çok şikâyet önce; geçersiz hedef atılır");
  assert.equal(groups[0].count, 2);
  assert.deepEqual(groups[0].reasons, { photo: 1, name: 1 });
  assert.equal(groups[0].name, "Bobb", "en yeni şikâyetteki ad");
  assert.equal(groups[0].img, img);
  assert.deepEqual(groups[0].reports.map((r) => r.reporter).sort(), ["alice1", "carol1"]);
  assert.equal(groups[2].img, "", "base64 olmayan görsel sayfaya girmez");
});

test("bakiye düzeltme: eksi dahil, sınırlı", () => {
  const d = buildAdjust({ money: -500, gems: 20, text: { tr: "Hile iadesi" } }, NOW);
  assert.deepEqual(d.adjust, { money: -500, gems: 20 });
  assert.deepEqual(d.text, { tr: "Hile iadesi" });
  assert.equal(d.notify, false, "düzeltme varsayılan bildirimsiz");
  assert.throws(() => buildAdjust({ money: 0, gems: 0 }, NOW), /miktar/);
  assert.throws(() => buildAdjust({ money: -MAX_GEMS * 10000 }, NOW), PanelError);
});

test("geri yükleme: geçmiş kaydı postaya", () => {
  const r = buildRestore({ save_json: "gz1:abc", updated_at: 77 }, NOW);
  assert.deepEqual(r.restore, { save_json: "gz1:abc", at: 77 });
  assert.equal(r.notify, true);
  assert.throws(() => buildRestore({}, NOW), /boş/);
});

test("kupon: kod biçimi, ödül şart", () => {
  const p = buildPromo({ code: " reels50 ", title: { tr: "Reels" }, gems: 50, max_uses: 100 }, catalog);
  assert.equal(p.code, "REELS50");
  assert.deepEqual(p.doc.reward, { money: 0, gems: 50, crates: {}, decor: {} });
  assert.equal(p.doc.max_uses, 100);
  assert.equal(p.doc.active, true);
  assert.throws(() => buildPromo({ code: "AB", gems: 5 }, catalog), /Kod/);
  assert.throws(() => buildPromo({ code: "BOS1", gems: 0 }, catalog), /ödülü yok/);
  assert.throws(() => buildPromo({ code: "COK1", gems: MAX_GEMS + 1 }, catalog), PanelError);
});

test("etkinlik: çarpan 1–3, zaman sırası, ×1 = etkinlik yok", () => {
  const e = buildEvent({ id: "hs1", title: { tr: "Hafta sonu" }, money_mult: 2, xp_mult: 1, start: 10, end: 20 });
  assert.deepEqual([e.money_mult, e.xp_mult, e.start, e.end], [2, 1, 10, 20]);
  assert.equal(buildEvent({ id: "x", money_mult: 1, xp_mult: 1, start: 1, end: 2 }), null);
  assert.throws(() => buildEvent({ id: "x", money_mult: 5, start: 1, end: 2 }), /1 ile 3/);
  assert.throws(() => buildEvent({ id: "x", money_mult: 2, start: 5, end: 5 }), /sonra/);
  assert.equal(buildConfig({ event: { id: "hs1", money_mult: 2, start: 1, end: 2 } }, NOW).event, undefined,
    "sürüm / bakım kaydı etkinliğe dokunmaz");
});

test("etkinlik modülleri: indirim, kasa, görev, rakip, paket", () => {
  const packs = buildPacks([{ id: "kis_2026", url: "https://x.example/kis.pck", sha256: "A".repeat(64), size: 9000 }]);
  assert.equal(packs[0].sha256, "a".repeat(64), "özet küçük harfe");
  const e = buildEvent({ id: "k1", start: 1, end: 9, sale: { crates: 30, decor: 0 },
    crate_boost: { crate: "city_crate", cars: ["ford_focus", "ford_focus"], mult: 3 },
    missions: [{ metric: "repairs", target: 20, money: 5000, crate: "city_crate" }, { metric: "" }],
    rival: { car: "ford_focus", stage: 3, name: "Kral Rıza", paint: "#2255ff", gems: 30 }, pack: "kis_2026" }, catalog, packs);
  assert.deepEqual(e.sale, { crates: 30 }, "0 indirim yazılmaz");
  assert.deepEqual(e.crate_boost, { crate: "city_crate", cars: ["ford_focus"], mult: 3 });
  assert.equal(e.missions.length, 1, "türsüz satır atlanır");
  assert.equal(e.missions[0].id, "m1");
  assert.equal(e.rival.stage, 3);
  assert.equal(e.pack, "kis_2026");
  assert.equal(e.money_mult, 1, "çarpansız etkinlik de geçerli (oyun 1'i yok sayar)");
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, sale: { cars: SALE_MAX + 1 } }, catalog), /0 ile 50/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, crate_boost: { crate: "city_crate", cars: ["bugatti_veyron"], mult: 3 } }, catalog), /havuzunda/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, crate_boost: { crate: "city_crate", cars: ["ford_focus"], mult: 9 } }, catalog), /2 ile 5/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, missions: [{ metric: "uydurma", target: 1 }] }, catalog), /bilinmeyen/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, missions: Array.from({ length: 7 }, () => ({ metric: "repairs", target: 1 })) }, catalog), /en çok 6/i);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, rival: { car: "police_vito" } }, catalog), /edinilemeyen/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, rival: { car: "ford_focus", stage: 6 } }, catalog), /kademesi/);
  assert.throws(() => buildEvent({ id: "k", start: 1, end: 2, pack: "yok" }, catalog, packs), /paket listesinde yok/);
  assert.equal(buildEvent({ id: "k", start: 1, end: 2, sale: {}, missions: [] }, catalog), null, "modülsüz = etkinlik yok");
  assert.ok(Object.keys(MISSION_METRICS).length >= 15);
});

test("ödüllü reklam ayarı: varsayılanlar, sınırlar, bilinmeyen tür", () => {
  const d = buildAds({});
  assert.deepEqual(d, { total_cap: 20, free_gems: 5, free_gems_cooldown: 180, caps: {} }, "boş form = oyunun varsayılanı");
  const a = buildAds({ total_cap: 30, free_gems: 10, free_gems_cooldown: 60, caps: { free_gems: 8, junk_refill: 0 } });
  assert.equal(a.caps.free_gems, 8);
  assert.equal(a.caps.junk_refill, 0, "0 = teklif kapalı");
  assert.throws(() => buildAds({ free_gems: 0 }), /1 ile 50/);
  assert.throws(() => buildAds({ free_gems_cooldown: 4000 }), /0 ile 3600/);
  assert.throws(() => buildAds({ caps: { uydurma: 3 } }), /Bilinmeyen/);
  assert.equal(AD_KINDS.free_gems.cap, 5);
  assert.equal(Object.keys(AD_KINDS).length, 9, "oyundaki 9 teklif türü");
});

test("paket listesi ve etkinlik belgesi (öbür alanlar korunur)", () => {
  assert.throws(() => buildPacks([{ id: "a", url: "http://x/a.pck", sha256: "a".repeat(64), size: 1 }]), /https/);
  assert.throws(() => buildPacks([{ id: "a", url: "https://x/a.pck", sha256: "abc", size: 1 }]), /sha256/);
  const one = { id: "a", url: "https://x/a.pck", sha256: "b".repeat(64), size: 10 };
  assert.throws(() => buildPacks([one, one]), /iki kez/);
  const current = { min_code: 11, maintenance: false, notice: { id: "n1", text: { tr: "x" } }, event: { id: "old", money_mult: 2 } };
  const doc = buildEventDoc({ event: { id: "e2", start: 1, end: 2, sale: { mods: 20 } }, packs: [one] }, catalog, current, NOW);
  assert.equal(doc.min_code, 11, "sürüm alanı korunur");
  assert.equal(doc.notice.id, "n1", "duyuru korunur");
  assert.deepEqual(doc.event.sale, { mods: 20 }, "eski etkinliğin alanı (money_mult 2) taşınmaz");
  assert.equal(doc.event.money_mult, 1);
  assert.equal(doc.packs.length, 1);
  const off = buildEventDoc({ event: null, packs: [] }, catalog, doc, NOW);
  assert.ok(!("event" in off) && !("packs" in off), "etkinlik bitir: alan silinir");
});

test("hedefli gönderim süzgeci", () => {
  const nowS = Math.floor(NOW / 1000);
  const seg = buildSegment({ level_min: "5", inactive_days: "7", lang: "en", level_max: "" });
  assert.equal(seg.level_max, null);
  const p = (level, daysAgo, lang, build) => ({ stats: { level, lang, build }, updated_at: nowS - daysAgo * 86400 });
  assert.equal(matchSegment(p(6, 10, "en", 10), seg, NOW), true);
  assert.equal(matchSegment(p(4, 10, "en", 10), seg, NOW), false, "seviye düşük");
  assert.equal(matchSegment(p(6, 2, "en", 10), seg, NOW), false, "yakında oynamış");
  assert.equal(matchSegment(p(6, 10, "tr", 10), seg, NOW), false, "dil başka");
  assert.equal(matchSegment({ updated_at: nowS - 30 * 86400 }, buildSegment({ inactive_days: 7 }), NOW), true, "stats'sız eski kayıt: yalnız zaman süzgeci");
  assert.equal(matchSegment({ updated_at: 1 }, buildSegment({ level_min: 1 }), NOW), false, "stats yoksa seviye uymaz");
  assert.equal(matchSegment(p(3, 1, "tr", 9), buildSegment({ build_max: 9 }), NOW), true);
  assert.throws(() => buildSegment({ level_min: 9, level_max: 3 }), /ters/);
  assert.throws(() => buildSegment({ lang: "xx" }), /dil/);
});

test("yarış öğrenmesi ayarı: varsayılan, sınırlar", () => {
  assert.deepEqual(buildLearning({}), { off: false, window: 300, weight: 20 });
  assert.deepEqual(buildLearning({ off: true, window: "600", weight: 50 }), { off: true, window: 600, weight: 50 });
  assert.equal(buildLearning({ off: "evet" }).off, false, "yalnız true kapatır");
  assert.throws(() => buildLearning({ window: 30 }), PanelError);
  assert.throws(() => buildLearning({ weight: 500 }), PanelError);
});

// --- HABERLER ------------------------------------------------------------------------------------------------------

const news = (over = {}) => ({ kind: "notice", title: { tr: "Yeni garajlar!" }, text: { tr: "Beş yeni depo açıldı." }, ...over });

test("haber: tam belge, varsayılanlar, tr zorunlu", () => {
  const d = buildNewsPost(news({ title: { tr: "  Yeni   garajlar! ", en: "New garages!", de: "" }, text: { tr: "Satır 1\r\nSatır 2" } }), NOW);
  assert.deepEqual(Object.keys(d), ["kind", "title", "text", "image", "action", "start", "end", "pinned", "code", "target", "notify",
    "pushed_at", "at"], "sözleşmedeki alanlar, başka alan yok");
  assert.deepEqual(d.title, { tr: "Yeni garajlar!", en: "New garages!" }, "başlık tek satır, boş dil yazılmaz");
  assert.equal(d.text.tr, "Satır 1\nSatır 2", "metinde satır sonu kalır (\\r\\n → \\n)");
  assert.deepEqual([d.image, d.action, d.start, d.end, d.pinned, d.code, d.notify, d.pushed_at], ["", { kind: "", url: "" }, 0, 0, false, 0, false, 0]);
  assert.deepEqual(d.target, { langs: [], min_level: 0, max_level: 0, min_code: 0, max_code: 0 });
  assert.equal(d.at, Math.floor(NOW / 1000));
  assert.throws(() => buildNewsPost(news({ title: { en: "Only English" } }), NOW), /Başlık: Türkçe metin zorunlu/);
  assert.throws(() => buildNewsPost(news({ text: { tr: "   " } }), NOW), /Metin: Türkçe metin zorunlu/);
  assert.throws(() => buildNewsPost(news({ kind: "promo" }), NOW), /Haber türü/);
  assert.throws(() => buildNewsPost(null, NOW), PanelError);
  assert.equal(buildNewsPost(news({ pinned: "true", notify: 1 }), NOW).pinned, false, "yalnız gerçek true");
});

test("haber: uzunluk sınırları (karakter = kod noktası)", () => {
  assert.equal(buildNewsPost(news({ title: { tr: "x".repeat(60) } }), NOW).title.tr.length, 60);
  assert.throws(() => buildNewsPost(news({ title: { tr: "x".repeat(61) } }), NOW), /Başlık \(tr\): en çok 60/);
  assert.throws(() => buildNewsPost(news({ title: { tr: "ok", fr: "x".repeat(61) } }), NOW), /\(fr\)/);
  assert.equal([...buildNewsPost(news({ text: { tr: "🏁".repeat(600) } }), NOW).text.tr].length, 600, "emoji tek karakter");
  assert.throws(() => buildNewsPost(news({ text: { tr: "x".repeat(601) } }), NOW), /600/);
});

test("haber: kapak adresi yalnız izinli sunuculardan", () => {
  const ok = "https://firebasestorage.googleapis.com/v0/b/car-town-remake.firebasestorage.app/o/news%2Fn_x_abc123.jpg?alt=media&token=1-2";
  assert.equal(newsImage(ok), ok);
  assert.equal(newsImage(" https://autoyard.online/haber/kis.webp "), "https://autoyard.online/haber/kis.webp");
  assert.equal(newsImage("https://storage.googleapis.com/b/x.png"), "https://storage.googleapis.com/b/x.png");
  assert.equal(newsImage(""), "");
  for (const bad of ["http://autoyard.online/x.jpg", "https://evil.com/x.jpg", "https://autoyard.online.evil.com/x.jpg",
    "https://autoyard.online@evil.com/x.jpg", "https://autoyard.online:8443/x.jpg", "https://www.autoyard.online/x.jpg",
    "https://autoyard.online", "https://autoyard.online/a b.jpg", "https://autoyard.online/\"onerror=", "javascript:alert(1)",
    "https://AUTOYARD.ONLINE/x.jpg", `https://autoyard.online/${"x".repeat(500)}`]) {
    assert.throws(() => newsImage(bad), PanelError, bad);
  }
  assert.equal(buildNewsPost(news({ image: ok }), NOW).image, ok);
});

test("haber: düğme türleri, adres yalnız bağlantıda", () => {
  for (const kind of ["", "market", "event", "quests", "showroom", "friends", "invite", "store"]) {
    assert.deepEqual(newsAction({ kind }), { kind, url: "" });
  }
  assert.deepEqual(newsAction(undefined), { kind: "", url: "" });
  assert.deepEqual(newsAction({ kind: "url", url: " https://www.instagram.com/autoyard?x=1 " }),
    { kind: "url", url: "https://www.instagram.com/autoyard?x=1" });
  assert.throws(() => newsAction({ kind: "garage" }), /bilinmeyen tür/);
  assert.throws(() => newsAction({ kind: "__proto__" }), /bilinmeyen tür/);
  assert.throws(() => newsAction({ kind: "market", url: "https://x.com" }), /yalnız Bağlantı/);
  assert.throws(() => newsAction({ kind: "url", url: "" }), /boş/);
  assert.throws(() => newsAction({ kind: "url", url: "http://x.com" }), /https/);
  assert.throws(() => newsAction({ kind: "url", url: "javascript:alert(1)" }), /https/);
  assert.throws(() => newsAction({ kind: "url", url: "https://user:pw@x.com/" }), /https/);
  assert.throws(() => newsAction({ kind: "url", url: "https://localhost/" }), /https/);
  assert.throws(() => newsAction({ kind: "url", url: `https://x.com/${"a".repeat(300)}` }), /300/);
});

test("haber: hedef aralıkları ve dilleri", () => {
  assert.deepEqual(newsTarget({ langs: ["fr", "tr", "tr"], min_level: "5", max_level: 10, min_code: 12 }),
    { langs: ["tr", "fr"], min_level: 5, max_level: 10, min_code: 12, max_code: 0 }, "dil sırası sabit, yinelenen atılır");
  assert.throws(() => newsTarget({ langs: ["it"] }), /Hedef dil/);
  assert.throws(() => newsTarget({ min_level: 10, max_level: 5 }), /seviye aralığı ters/);
  assert.throws(() => newsTarget({ min_code: 14, max_code: 12 }), /sürüm aralığı ters/);
  assert.throws(() => newsTarget({ min_level: -1 }), /0 ile/);
  assert.throws(() => newsTarget({ max_code: 1.5 }), /tam sayı/);
  assert.equal(newsTarget({ min_level: 5, max_level: 0 }).max_level, 0, "0 = sınır yok (ters sayılmaz)");
});

test("haber: başlangıç < bitiş, sürüm kodu yalnız GÜNCELLEME'de", () => {
  assert.deepEqual([buildNewsPost(news({ start: 100, end: 200 }), NOW).start, buildNewsPost(news({ end: 200 }), NOW).end], [100, 200]);
  assert.throws(() => buildNewsPost(news({ start: 200, end: 200 }), NOW), /sonra/);
  assert.throws(() => buildNewsPost(news({ start: 300, end: 200 }), NOW), /sonra/);
  assert.equal(buildNewsPost(news({ start: 300 }), NOW).end, 0, "yalnız başlangıç: süresiz");
  assert.equal(buildNewsPost(news({ kind: "update", code: 12 }), NOW).code, 12);
  assert.throws(() => buildNewsPost(news({ kind: "update" }), NOW), /sürüm kodu gerekli/);
  assert.throws(() => buildNewsPost(news({ kind: "event", code: 12 }), NOW), /yalnız GÜNCELLEME/);
  assert.throws(() => buildNewsPost(news({ start: -5 }), NOW), PanelError);
});

test("haber: bildirim seviye / sürüm hedefiyle birlikte olmaz (konu bildirimi süzemez)", () => {
  assert.equal(buildNewsPost(news({ notify: true, target: { langs: ["de"] } }), NOW).notify, true, "dil hedefi olur");
  assert.throws(() => buildNewsPost(news({ notify: true, target: { min_level: 5 } }), NOW), /bildirimi gönderilemez/);
  assert.throws(() => buildNewsPost(news({ notify: true, target: { max_code: 20 } }), NOW), /bildirimi gönderilemez/);
  assert.equal(buildNewsPost(news({ notify: false, target: { min_level: 5 } }), NOW).target.min_level, 5);
});

test("haber düzenleme: at korunur (en üste taşı = şimdi), pushed_at korunur", () => {
  const current = { ...buildNewsPost(news({ notify: true }), NOW - 86_400_000), pushed_at: 1234 };
  const edited = buildNewsPost(news({ title: { tr: "Düzeltildi" }, notify: true }), NOW, current);
  assert.equal(edited.at, current.at, "zaman değişmez");
  assert.equal(edited.pushed_at, 1234, "gönderilmiş bildirim yeniden gitmez");
  assert.equal(edited.title.tr, "Düzeltildi");
  assert.equal(buildNewsPost(news({ bump: true }), NOW, current).at, Math.floor(NOW / 1000), "en üste taşı");
  assert.equal(buildNewsPost(news({ pushed_at: 99, at: 5 }), NOW).pushed_at, 0, "yeni haberde formdan pushed_at / at alınmaz");
  assert.equal(buildNewsPost(news({ pushed_at: 99, at: 5 }), NOW).at, Math.floor(NOW / 1000));
});

test("haber kimliği", () => {
  const id = newsId(NOW, "A1B2C3D4");
  assert.match(id, /^n_[a-z0-9]+_a1b2c3$/);
  assert.ok(NEWS_ID_RE.test(id));
  assert.ok(!NEWS_ID_RE.test("n_x_zzzzzz") && !NEWS_ID_RE.test("../n_x_abcdef") && !NEWS_ID_RE.test("m_x_abcdef"));
});

test("posta: isteğe bağlı resim + düğme (tek oyuncuya haber)", () => {
  const plain = buildMail({ text: "Selam" }, catalog, NOW);
  assert.ok(!("image" in plain) && !("action" in plain), "boşsa alan yazılmaz (eski posta biçimi aynen)");
  const m = buildMail({ title: { tr: "Sana özel" }, text: "Garajın çok güzel!", image: "https://autoyard.online/x.jpg",
    action: { kind: "showroom" } }, catalog, NOW);
  assert.equal(m.image, "https://autoyard.online/x.jpg");
  assert.deepEqual(m.action, { kind: "showroom", url: "" });
  assert.ok(!("action" in buildMail({ text: "x", action: { kind: "" } }, catalog, NOW)), "düğme yok = alan yok");
  assert.throws(() => buildMail({ text: "x", image: "https://evil.com/x.jpg" }, catalog, NOW), /Kapak resmi/);
  assert.throws(() => buildMail({ text: "x", action: { kind: "url", url: "http://x.com" } }, catalog, NOW), /https/);
  assert.throws(() => buildMail({ text: "x", action: { kind: "hack" } }, catalog, NOW), /bilinmeyen tür/);
});

test("kapak yükleme: tür baytlardan, en çok 1,5 MB", () => {
  const jpg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
  const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]);
  const webp = Buffer.concat([Buffer.from("RIFF"), Buffer.from([1, 2, 3, 4]), Buffer.from("WEBPVP8 ")]);
  assert.deepEqual(imageKind(jpg), { ext: "jpg", contentType: "image/jpeg" });
  assert.equal(imageKind(png).ext, "png");
  assert.equal(imageKind(webp).ext, "webp");
  assert.equal(imageKind(Buffer.from("GIF89a....")), null, "GIF yok");
  assert.equal(imageKind(Buffer.from("<svg xmlns=")), null, "SVG yok");
  const d = decodeNewsImage("data:image/png;base64," + png.toString("base64"));
  assert.equal(d.contentType, "image/png");
  assert.ok(d.buf.equals(png));
  assert.equal(decodeNewsImage(jpg.toString("base64")).ext, "jpg", "öneksiz base64 de olur");
  assert.throws(() => decodeNewsImage(Buffer.from("GIF89a....").toString("base64")), /JPEG, PNG ya da WebP/);
  assert.throws(() => decodeNewsImage("data:image/jpeg;base64,"), /seçilmedi/);
  assert.throws(() => decodeNewsImage("bu base64 değil!"), /base64/);
  assert.throws(() => decodeNewsImage(undefined), /seçilmedi/);
  const big = Buffer.concat([jpg, Buffer.alloc(NEWS_IMAGE_BYTES)]);
  assert.throws(() => decodeNewsImage(big.toString("base64")), /1,5 MB/);
  const max = Buffer.concat([jpg, Buffer.alloc(NEWS_IMAGE_BYTES - jpg.length)]);
  assert.equal(decodeNewsImage(max.toString("base64")).buf.length, NEWS_IMAGE_BYTES, "tam 1,5 MB olur");
});

test("Storage: kova adayları, kova yok hatası, indirme adresi", () => {
  assert.deepEqual(bucketCandidates("car-town-remake"), ["car-town-remake.firebasestorage.app", "car-town-remake.appspot.com"]);
  assert.deepEqual(bucketCandidates("p", " ozel-kova "), ["ozel-kova"]);
  assert.equal(isMissingBucket({ code: 404, message: "The specified bucket does not exist." }), true);
  assert.equal(isMissingBucket(new Error("The specified bucket does not exist.")), true);
  assert.equal(isMissingBucket({ code: 403, message: "Permission denied" }), false);
  assert.equal(isMissingBucket(null), false);
  assert.equal(storageUrl("b.firebasestorage.app", "news/n_x_abc123_ff00aa.jpg", "tok-1"),
    "https://firebasestorage.googleapis.com/v0/b/b.firebasestorage.app/o/news%2Fn_x_abc123_ff00aa.jpg?alt=media&token=tok-1");
  assert.equal(newsImage(storageUrl("b.firebasestorage.app", "news/a.jpg", "t")).length > 0, true, "yüklenen adres haberde geçerli");
});

test("yayın belgesi (config/news): panelin haberinden, herkese açık alanlar, bitenler atılır, en çok 40", () => {
  assert.equal(NEWS_FEED_DOC, "config/news");
  const nowS = Math.floor(NOW / 1000);
  const a = { id: "n_a_000001", ...buildNewsPost(news({ notify: true }), NOW - 5000) };
  const future = { id: "n_b_000002", ...buildNewsPost(news({ start: nowS + 3600 }), NOW - 3000) };
  const ended = { id: "n_c_000003", ...buildNewsPost(news({ start: nowS - 100, end: nowS - 1 }), NOW - 1000) };
  const feed = buildNewsFeed([a, future, ended], NOW);
  assert.deepEqual(feed.items.map((i) => i.id), ["n_b_000002", "n_a_000001"], "yeniden eskiye; başlamamış kalır, biten düşer");
  assert.equal(feed.at, nowS);
  const { id: _id, notify: _n, pushed_at: _p, ...pub } = a;
  assert.deepEqual(feed.items[1], { id: "n_a_000001", ...pub }, "haberin herkese açık alanları aynen");
  assert.ok(!("notify" in feed.items[1]) && !("pushed_at" in feed.items[1]));
  const many = Array.from({ length: 50 }, (_, i) => ({ id: `n_${i}_abcdef`, ...buildNewsPost(news(), NOW - i * 1000) }));
  assert.equal(buildNewsFeed(many, NOW).items.length, NEWS_FEED_MAX);
});
