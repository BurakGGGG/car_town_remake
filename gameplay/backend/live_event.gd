class_name LiveEvent
## CANLI ETKİNLİK — modüller (2026-10-23, kullanıcı: "hafta sonu etkinliğini güncelleme atmadan yapabileyim; hepsini ekle,
## panelime de ekle"). Etkinlik Firestore config/app.event belgesindedir (yönetim paneli yazar, AppConfig okur); bu sınıf
## onu doğrular ve oyunun geri kalanına tek kapıdan verir. Belge (her modül isteğe bağlı, en az biri dolu olmalı):
##   id, title {dil}, text {dil}, start, end (unix sn)
##   money_mult, xp_mult      1–3: tamir ve yarış ödülü çarpanı (eski canlı etkinlik)
##   sale                     {crates, cars, decor, mods}: yüzde 0–SALE_MAX İNDİRİM (kasa gemi, GERİ AL ₺, dekor ₺ /
##                            elmas, modifiye ₺). En çok %50: GERİ AL'ınan araç %40'a satılır (SELL_RATIO), indirimle
##                            alıp hemen satmak kâr etmesin.
##   crate_boost              {crate, cars: [araç], mult 2–5}: ETKİNLİK KASASI — o kasada seçili araçların ağırlığı ×mult.
##                            Gösterilen oran yine GERÇEK orandır (CrateCatalog.odds bunu da hesaba katar).
##   missions                 [{id, metric, target, money, gems, xp, crate, decor}] en çok MISSION_MAX: ETKİNLİK GÖREVLERİ
##                            (MissionManager sayar; metrik MISSION_TEXTS'tekilerden biri)
##   rival                    {car, stage 0–5, name, paint, money, gems, xp, crate, decor}: ÖZEL RAKİP — pist doğrudan
##                            açılır (RaceManager.start_event_rival), özel ödül etkinlik başına bir kez
##   pack                     İÇERİK PAKETİ kimliği (config/app.packs'ten biri, LivePacks indirir): o paketin "event_only"
##                            eşyaları yalnızca etkinlik sürerken satılır
## Bozuk / bilinmeyen alan sessizce atlanır (panel de aynı sınırları uygular: firebase/admin/lib.mjs buildEvent).
## Saat: cihaz saati (AppConfig'in eski kuralıyla aynı; test_now testler için).

const SALE_KINDS: Array[StringName] = [&"crates", &"cars", &"decor", &"mods"]
const SALE_MAX: int = 50
const BOOST_MIN: float = 2.0
const BOOST_MAX: float = 5.0
const MULT_MAX: float = 3.0
const MISSION_MAX: int = 6
const RIVAL_STAGE_MAX: int = 5
const REWARD_MONEY_MAX: int = 5_000_000
const REWARD_GEMS_MAX: int = 1000
const REWARD_XP_MAX: int = 100_000
const TARGET_MAX: int = 1_000_000

## Etkinlik görevlerinin sayabileceği metrikler (MissionManager.count) ve metinleri. Metinler günlük / haftalık görevlerle
## aynı (çevirileri hazır); "%s" hedeftir.
const MISSION_TEXTS: Dictionary = {
	&"repairs": "%s TAMİR YAP",
	&"repair_money": "TAMİRDEN %s ₺ KAZAN",
	&"long_jobs": "%s UZUN İŞ TAMAMLA",
	&"races": "%s YARIŞA KATIL",
	&"race_wins": "%s YARIŞ KAZAN",
	&"event_rival_wins": "ETKİNLİK RAKİBİNİ %s KEZ YEN",
	&"crates_opened": "%s KASA AÇ",
	&"crates_bought": "%s KASA SİPARİŞ ET",
	&"decor_placed": "%s EŞYA YERLEŞTİR",
	&"decor_bought": "%s EŞYA SATIN AL",
	&"paints": "%s ARAÇ BOYA",
	&"mods_installed": "%s MODİFİYE TAK",
	&"junk_searches": "HURDALIKTA %s YIĞIN ARA",
	&"junk_parts": "HURDALIKTAN %s PARÇA TOPLA",
	&"friend_races": "%s ARKADAŞ YARIŞINA KATIL",
	&"friend_wins": "%s ARKADAŞ YARIŞI KAZAN",
	&"money_spent": "%s ₺ HARCA",
}

## Testler: -1 değilse cihaz saati yerine bu unix zamanı.
static var test_now: int = -1


static func now() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


## Şu an süren etkinlik (normalize edilmiş) ya da boş. AppConfig kurulmamışsa (testler, ziyaret) boş.
static func current() -> Dictionary:
	var config: AppConfig = AppConfig.current()
	return config.active_event() if config else {}


static func active() -> bool:
	return not current().is_empty()


static func id() -> String:
	return SaveSafe.s(current().get("id", ""))


static func seconds_left() -> int:
	var e: Dictionary = current()
	return maxi(SaveSafe.i(e.get("end", 0)) - now(), 0) if not e.is_empty() else 0


# --- İndirim ----------------------------------------------------------------------------------

## Bu türün süren indirimi (yüzde, 0 = yok).
static func sale_percent(kind: StringName) -> int:
	var sale: Dictionary = current().get("sale", {})
	return SaveSafe.i(sale.get(kind, 0))


## İndirimli fiyat (yuvarlanır; ücretli bir şey indirimle bedava olmaz).
static func sale_price(kind: StringName, base: int) -> int:
	return apply_sale(base, sale_percent(kind))


static func apply_sale(base: int, percent: int) -> int:
	if percent <= 0 or base <= 0:
		return base
	return maxi(int(round(float(base) * float(100 - clampi(percent, 0, SALE_MAX)) / 100.0)), 1)


# --- Etkinlik kasası ----------------------------------------------------------------------------

## Kasanın şansı artırılmış araçları: araç → ağırlık çarpanı (boş = etkinlik kasası değil).
static func crate_boost(crate_id: StringName) -> Dictionary:
	var boost: Dictionary = current().get("crate_boost", {})
	if boost.is_empty() or boost.get("crate") != crate_id:
		return {}
	var out: Dictionary = {}
	for car: StringName in boost["cars"]:
		out[car] = float(boost["mult"])
	return out


# --- Görevler / rakip / paket -------------------------------------------------------------------

static func missions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(current().get("missions", []))
	return out


static func rival() -> Dictionary:
	return current().get("rival", {})


static func pack_id() -> String:
	return SaveSafe.s(current().get("pack", ""))


## Görev metni (hedefle): "12 TAMİR YAP".
static func mission_text(metric: StringName, target: int) -> String:
	var text: String = Loc.tn(String(MISSION_TEXTS.get(metric, "%s")), target)
	return text % Hud.format_thousands(target) if text.contains("%s") else text


# --- Doğrulama ----------------------------------------------------------------------------------

## config/app.event → normalize edilmiş etkinlik; süresi dışında, kimliksiz ya da hiçbir modülü dolu değilse boş.
static func normalize(raw: Variant, at: int) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var e: Dictionary = raw
	var event_id: String = SaveSafe.s(e.get("id", "")).strip_edges()
	var start: int = SaveSafe.i(e.get("start", 0))
	var end: int = SaveSafe.i(e.get("end", 0))
	if event_id.is_empty() or end <= at or start > at:
		return {}
	var out: Dictionary = {
		"id": event_id, "start": start, "end": end,
		"title": AppConfig.text_of(e.get("title")), "text": AppConfig.text_of(e.get("text")),
		"money_mult": clampf(SaveSafe.f(e.get("money_mult", 1.0)), 1.0, MULT_MAX),
		"xp_mult": clampf(SaveSafe.f(e.get("xp_mult", 1.0)), 1.0, MULT_MAX),
		"sale": _sale(e.get("sale")),
		"crate_boost": _boost(e.get("crate_boost")),
		"missions": _missions(e.get("missions")),
		"rival": _rival(e.get("rival")),
		"pack": SaveSafe.s(e.get("pack", "")).strip_edges(),
	}
	var any: bool = float(out["money_mult"]) > 1.0 or float(out["xp_mult"]) > 1.0 \
		or not (out["sale"] as Dictionary).is_empty() or not (out["crate_boost"] as Dictionary).is_empty() \
		or not (out["missions"] as Array).is_empty() or not (out["rival"] as Dictionary).is_empty() \
		or not String(out["pack"]).is_empty()
	return out if any else {}


static func _sale(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for kind: StringName in SALE_KINDS:
		var p: int = clampi(SaveSafe.i((raw as Dictionary).get(String(kind), 0)), 0, SALE_MAX)
		if p > 0:
			out[kind] = p
	return out


static func _boost(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var crate: StringName = StringName(SaveSafe.s((raw as Dictionary).get("crate", "")))
	if not CrateCatalog.exists(crate) or CrateCatalog.is_gift(crate):
		return {}
	var pool: Array[StringName] = CrateCatalog.pool(crate)
	var cars: Array[StringName] = []
	var list: Variant = (raw as Dictionary).get("cars", [])
	for v: Variant in (list if list is Array else []):
		var car: StringName = StringName(SaveSafe.s(v))
		if pool.has(car) and not cars.has(car):
			cars.append(car)
	if cars.is_empty():
		return {}
	return {"crate": crate, "cars": cars,
		"mult": clampf(SaveSafe.f((raw as Dictionary).get("mult", BOOST_MIN)), BOOST_MIN, BOOST_MAX)}


static func _missions(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	var seen: Dictionary = {}
	for v: Variant in raw:
		if out.size() >= MISSION_MAX or not v is Dictionary:
			continue
		var m: Dictionary = v
		var mission_id: String = SaveSafe.s(m.get("id", "")).strip_edges()
		var metric: StringName = StringName(SaveSafe.s(m.get("metric", "")))
		var target: int = clampi(SaveSafe.i(m.get("target", 0)), 0, TARGET_MAX)
		if mission_id.is_empty() or seen.has(mission_id) or not MISSION_TEXTS.has(metric) or target <= 0:
			continue
		seen[mission_id] = true
		var mission: Dictionary = _reward(m)
		mission["id"] = mission_id
		mission["metric"] = metric
		mission["target"] = target
		out.append(mission)
	return out


static func _rival(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var r: Dictionary = raw
	var car: StringName = StringName(SaveSafe.s(r.get("car", "")))
	if not CarCatalog.is_obtainable(car):
		return {}   # polis gibi edinilemeyen araç yarışa çıkmaz (İNTİKAM'la aynı kural)
	var paint: String = SaveSafe.s(r.get("paint", "")).strip_edges()
	var out: Dictionary = _reward(r)
	out["car"] = car
	out["stage"] = clampi(SaveSafe.i(r.get("stage", 0)), 0, RIVAL_STAGE_MAX)
	out["name"] = AppConfig.text_of(r.get("name")).strip_edges().left(24)
	out["paint"] = paint if Color.html_is_valid(paint) else ""
	return out


## Ödül alanları: money, gems, xp, crate (mağaza kasası), decor (bir eşya kimliği; paketten gelebilir).
static func _reward(raw: Dictionary) -> Dictionary:
	var crate: StringName = StringName(SaveSafe.s(raw.get("crate", "")))
	return {
		"money": clampi(SaveSafe.i(raw.get("money", 0)), 0, REWARD_MONEY_MAX),
		"gems": clampi(SaveSafe.i(raw.get("gems", 0)), 0, REWARD_GEMS_MAX),
		"xp": clampi(SaveSafe.i(raw.get("xp", 0)), 0, REWARD_XP_MAX),
		"crate": crate if CrateCatalog.exists(crate) and not CrateCatalog.is_gift(crate) else &"",
		"decor": StringName(SaveSafe.s(raw.get("decor", "")).strip_edges()),
	}


## Ödülün oyuncuya görünen özeti: "+5.000 ₺  +20 GEM  +1 KASA".
static func reward_text(reward: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if SaveSafe.i(reward.get("money", 0)) > 0:
		parts.append("+%s ₺" % Hud.format_thousands(SaveSafe.i(reward["money"])))
	if SaveSafe.i(reward.get("gems", 0)) > 0:
		parts.append(Loc.t("+%d GEM") % SaveSafe.i(reward["gems"]))
	if SaveSafe.i(reward.get("xp", 0)) > 0:
		parts.append(Loc.t("+%d XP") % SaveSafe.i(reward["xp"]))
	if StringName(reward.get("crate", &"")) != &"":
		parts.append(Loc.t("+1 KASA"))
	var decor: StringName = StringName(reward.get("decor", &""))
	if decor != &"":
		var title: String = SaveSafe.s(GarageDecor.get_item(decor).get("title", ""))
		parts.append("+" + (Loc.t(title).to_upper() if not title.is_empty() else Loc.t("EŞYA")))
	return "  ".join(parts)
