// lib.mjs testi (internetsiz). Çalıştırma: cd firebase/admin && npm test
import test from "node:test";
import assert from "node:assert";
import { gzipSync } from "node:zlib";
import {
  PanelError, loadCatalog, buildInfo, buildMail, mailId, buildConfig, buildNews, classifyQuery, unpackSave, texts, MAX_GEMS,
  statsFromSave, buildBan, banActive, moderatedName, groupReports, buildAdjust, buildRestore,
  buildPromo, buildEvent, buildSegment, matchSegment, buildLearning, buildPacks, buildEventDoc, SALE_MAX, MISSION_METRICS,
  buildAds, AD_KINDS,
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
