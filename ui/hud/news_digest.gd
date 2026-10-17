class_name NewsDigest
extends RefCounted
## OTO MANŞET — açılış gazetesinin İÇERİĞİ (2026-10-17, kullanıcıyla soru-cevapla karar). Ham haberler (her biri bir
## kişiden ya da bir işten tek olay) TÜRÜNE GÖRE BİRLEŞTİRİLİR ("3 arkadaşın 5 parça gönderdi"), ağırlığa göre sıralanır,
## en çarpıcısı MANŞET olur, sonrakiler sütunlara, kalanlar alttaki KISA KISA şeridine iner: gazete hep tek sayfa.
## Metinler esprili magazin dilinde, her tür için dönüşümlü birkaç kalıp (sayı tohumu = gazetenin sayısı).
## Saf veri + metin: ekranı NewsScreen çizer. Ham haber: {"kind": <tür>, ...türün alanları}:
##   RACE_LOST / RACE_WON  people [kişi], count (yarış sayısı), car (yenen / yenilmeyen araç)
##   EARNINGS              money (toplam), jobs (ustanın tamiri), minutes (kasanın süresi, 8 sa sınırlı), full (kasa doldu),
##                         finished / finished_money / finished_xp (sen yokken biten yarım işler)
##   GIFT                  people, parts {parça: adet}
##   VISIT                 people, likes (beğenen sayısı)
##   FRIEND_NEW / FRIEND_REQUEST  people
##   ASK                   people, part (istediği parça)
##   PILES                 count (dolan yığın) · MOD_READY  car, category · MISSIONS  daily, weekly (bool)
## Kişi: {uid, name, av, frame, flag} (AvatarView / ProfileCard.avatar_for ile çizilir).

const RACE_LOST: StringName = &"race_lost"
const RACE_WON: StringName = &"race_won"
const EARNINGS: StringName = &"earnings"
const GIFT: StringName = &"gift"
const VISIT: StringName = &"visit"
const FRIEND_NEW: StringName = &"friend_new"
const FRIEND_REQUEST: StringName = &"friend_request"
const ASK: StringName = &"ask"
const PILES: StringName = &"piles"
const MOD_READY: StringName = &"mod_ready"
const MISSIONS: StringName = &"missions"

## Küçük işler sütuna çıkmaz, doğrudan KISA KISA şeridine iner (manşet olabilirler: gazetede başka haber yoksa).
const BRIEF_KINDS: Array[StringName] = [PILES, MOD_READY, MISSIONS]
## Pasif gelirin "büyük kazanç" sayıldığı süre (sınır: 8 saat — kullanıcı kararı "yarı hız, 8 saat").
const FULL_SHIFT_MINUTES: int = 480


## Gazeteyi dizer: {"headline": haber, "columns": [haber], "briefs": [haber]}. Haber yoksa boş sözlük.
## `columns` sütun sayısı (ekran genişliğine göre 2–4).
static func compose(raw: Array[Dictionary], columns: int) -> Dictionary:
	var items: Array[Dictionary] = merge(raw)
	if items.is_empty():
		return {}
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return weight(a) > weight(b))
	var out_columns: Array[Dictionary] = []
	var briefs: Array[Dictionary] = []
	for i: int in range(1, items.size()):
		var item: Dictionary = items[i]
		if out_columns.size() < columns and not BRIEF_KINDS.has(item["kind"]):
			out_columns.append(item)
		else:
			briefs.append(item)
	return {"headline": items[0], "columns": out_columns, "briefs": briefs}


## Aynı türdeki haberler tek habere toplanır (ilk geliş sırası korunur). Aynı kişi iki kez gelirse sayıları toplanır;
## kişiler sayısı çoktan aza dizilir, haberin aracı / parçası en çok sayılı kişininkidir.
static func merge(raw: Array[Dictionary]) -> Array[Dictionary]:
	var order: Array[StringName] = []
	var groups: Dictionary = {}
	for item: Dictionary in raw:
		var kind: StringName = StringName(item.get("kind", &""))
		if kind == &"":
			continue
		if not groups.has(kind):
			order.append(kind)
			groups[kind] = []
		(groups[kind] as Array).append(item)
	var out: Array[Dictionary] = []
	for kind: StringName in order:
		var merged: Dictionary = _merge_group(kind, groups[kind])
		if not merged.is_empty():
			out.append(merged)
	return out


static func _merge_group(kind: StringName, list: Array) -> Dictionary:
	var out: Dictionary = {"kind": kind, "people": [], "count": 0, "money": 0, "jobs": 0, "minutes": 0, "full": false,
		"finished": 0, "finished_money": 0, "finished_xp": 0,
		"parts": {}, "likes": 0, "mods": [], "daily": false, "weekly": false, "car": &"", "part": &""}
	var per_person: Dictionary = {}   # uid → [kişi, sayı, araç / parça]
	for item: Dictionary in list:
		var count: int = maxi(int(item.get("count", 1)), 1)
		out["count"] = int(out["count"]) + count
		out["money"] = int(out["money"]) + maxi(int(item.get("money", 0)), 0)
		out["jobs"] = int(out["jobs"]) + maxi(int(item.get("jobs", 0)), 0)
		out["minutes"] = maxi(int(out["minutes"]), int(item.get("minutes", 0)))
		out["full"] = bool(out["full"]) or bool(item.get("full", false))
		for key: String in ["finished", "finished_money", "finished_xp"]:
			out[key] = int(out[key]) + maxi(int(item.get(key, 0)), 0)
		out["likes"] = int(out["likes"]) + maxi(int(item.get("likes", 0)), 0)
		out["daily"] = bool(out["daily"]) or bool(item.get("daily", false))
		out["weekly"] = bool(out["weekly"]) or bool(item.get("weekly", false))
		var parts: Dictionary = item.get("parts", {}) if item.get("parts") is Dictionary else {}
		for part: Variant in parts:
			var id: StringName = StringName(part)
			out["parts"][id] = int((out["parts"] as Dictionary).get(id, 0)) + int(parts[part])
		if kind == MOD_READY:
			(out["mods"] as Array).append({"car": StringName(item.get("car", &"")), "category": StringName(item.get("category", &""))})
		if out["car"] == &"":
			out["car"] = StringName(item.get("car", &""))
		if out["part"] == &"":
			out["part"] = StringName(item.get("part", &""))
		for person: Variant in item.get("people", []):
			if not person is Dictionary:
				continue
			var uid: String = String((person as Dictionary).get("uid", ""))
			if per_person.has(uid):
				per_person[uid][1] = int(per_person[uid][1]) + count
			else:
				per_person[uid] = [person, count, StringName(item.get("car", &"")), StringName(item.get("part", &""))]
	if not per_person.is_empty():
		var ranked: Array = per_person.values()
		ranked.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
		var people: Array = []
		for entry: Array in ranked:
			var person: Dictionary = (entry[0] as Dictionary).duplicate()
			person["count"] = entry[1]
			person["car"] = entry[2]
			person["part"] = entry[3]
			people.append(person)
		out["people"] = people
		out["car"] = StringName(ranked[0][2]) if StringName(ranked[0][2]) != &"" else StringName(out["car"])
		out["part"] = StringName(ranked[0][3]) if StringName(ranked[0][3]) != &"" else StringName(out["part"])
	if kind == EARNINGS and int(out["money"]) <= 0:
		return {}
	return out


## Haberin çarpıcılığı (kullanıcı sırası: seni yenen arkadaş > büyük kazanç > hediye > ziyaret > biten işler).
static func weight(item: Dictionary) -> float:
	var count: int = int(item.get("count", 1))
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			return 100.0 + count
		EARNINGS:
			return 60.0 + 30.0 * clampf(float(item.get("minutes", 0)) / FULL_SHIFT_MINUTES, 0.0, 1.0)
		RACE_WON:
			return 56.0 + mini(count, 3)
		GIFT:
			return 50.0 + mini(_part_total(item), 4)
		VISIT:
			return 40.0 + mini(int(item.get("likes", 0)), 4) * 1.5
		FRIEND_NEW:
			return 38.0
		FRIEND_REQUEST:
			return 36.0
		ASK:
			return 30.0
		MOD_READY:
			return 26.0
		PILES:
			return 22.0
		MISSIONS:
			return 20.0
	return 0.0


# --- Metinler -------------------------------------------------------------------------------------

## Bölüm etiketi (manşetin / sütunun üstündeki kırmızı küçük yazı).
static func section(item: Dictionary) -> String:
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			return Loc.t("SON DAKİKA")
		RACE_WON:
			return Loc.tc("SPOR", "gazete")   # araç sınıfı "SPOR" (DEPORTIVA) değil, gazetenin spor sayfası
		EARNINGS:
			return Loc.t("EKONOMİ")
		GIFT:
			return Loc.t("İYİ HABER")
		VISIT:
			return Loc.t("MAGAZİN")
		FRIEND_NEW, FRIEND_REQUEST:
			return Loc.t("MAHALLE")
		ASK:
			return Loc.t("YARDIM ÇAĞRISI")
		PILES:
			return Loc.t("HURDALIK")
		MOD_READY:
			return Loc.t("ATÖLYE")
		MISSIONS:
			return Loc.t("GÖREVLER")
	return ""


## Başlık (manşet ve sütun aynı kalıbı kullanır, manşet büyük yazılır). `seed` kalıbı seçer: aynı gazete her açılışta
## aynı görünür, ertesi sayıda başka kalıp gelir.
static func title(item: Dictionary, seed: int) -> String:
	var people: Array = item.get("people", [])
	var count: int = int(item.get("count", 1))
	var many: bool = people.size() > 1
	var who: String = _who(people)
	var first: String = _name(people[0] as Dictionary) if not people.is_empty() else ""
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			if many:
				return _pick(seed, [Loc.t("PİSTTE İSYAN: %s SENİ %d KEZ YENDİ") % [who, count],
					Loc.t("%s SANA KARŞI BİRLEŞTİ: %d YENİLGİ") % [who, count]])
			if count == 1:
				return _pick(seed, [Loc.t("ŞOK! %s SENİ YENDİ") % first, Loc.t("%s PİSTTE SENİ SOLLADI!") % first,
					Loc.t("SÜRPRİZ SONUÇ: %s KAZANDI!") % first])
			return _pick(seed, [Loc.t("%s DURDURULAMIYOR: %d GALİBİYET!") % [first, count],
				Loc.t("ŞOK! %s SENİ %d KEZ YENDİ") % [first, count], Loc.t("%s PİSTTE ESTİ GÜRLEDİ: %d ZAFER") % [first, count]])
		RACE_WON:
			var car: String = _car(item.get("car", &""))
			if many:
				return Loc.t("%s DÜŞÜRÜLEMEDİ: %d ZAFER") % [car, count]
			if count == 1:
				return _pick(seed, [Loc.t("%s YENİLMEZ ÇIKTI!") % car, Loc.t("%s DENEDİ, OLMADI!") % first])
			return _pick(seed, [Loc.t("GARAJIN GURURU %s: %d ZAFER") % [car, count], Loc.t("%s DENEDİ, OLMADI!") % first])
		EARNINGS:
			var money: String = money_text(int(item.get("money", 0)))
			return _pick(seed, [Loc.t("GARAJ PATRONSUZ DA ÇALIŞTI: %s") % money, Loc.t("KASA DOLDU TAŞTI: +%s") % money,
				Loc.t("TAMİRHANE DURMADI: %s KAZANÇ") % money])
		GIFT:
			if many:
				return _pick(seed, [Loc.t("HEDİYE YAĞMURU: %d PARÇA!") % _part_total(item), Loc.t("%s SANA HEDİYE YOLLADI") % who])
			return _pick(seed, [Loc.t("%s KESENİN AĞZINI AÇTI!") % first, Loc.t("CÖMERTLİK YARIŞI: %s HEDİYE YOLLADI") % first,
				Loc.t("HEDİYE PAKETİ GELDİ: %s") % parts_text(item.get("parts", {}))])
		VISIT:
			var likes: int = int(item.get("likes", 0))
			if likes > 0:
				if many:
					return Loc.tn("GARAJIN GÖZ DOLDURUYOR: %d BEĞENİ", likes) % likes
				return _pick(seed, [Loc.t("%s GARAJINA HAYRAN KALDI!") % first, Loc.tn("GARAJIN GÖZ DOLDURUYOR: %d BEĞENİ", likes) % likes])
			return _pick(seed, [Loc.t("MİSAFİR VAR: %s GARAJINI GEZDİ") % who, Loc.t("%s GARAJINA UĞRADI") % who])
		FRIEND_NEW:
			if many:
				return Loc.t("MAHALLE BÜYÜYOR: %d YENİ ARKADAŞ!") % people.size()
			return Loc.t("AİLE BÜYÜYOR: %s ARTIK ARKADAŞIN") % first
		FRIEND_REQUEST:
			if many:
				return Loc.t("KAPIDA %d ARKADAŞLIK İSTEĞİ VAR") % people.size()
			return Loc.t("%s SENİNLE ARKADAŞ OLMAK İSTİYOR") % first
		ASK:
			if many:
				return Loc.t("%d ARKADAŞIN PARÇA BEKLİYOR") % people.size()
			return Loc.t("%s YARDIM BEKLİYOR: 1 %s") % [first, _part(item.get("part", &""))]
		PILES:
			return Loc.t("HURDALIKTA BAYRAM: YIĞINLAR DOLDU!")
		MOD_READY:
			var mods: Array = item.get("mods", [])
			if mods.size() > 1:
				return Loc.t("ATÖLYEDE MESAİ BİTTİ: %d MODİFİYE HAZIR") % mods.size()
			return Loc.t("%s MODİFİYESİ HAZIR!") % _car(item.get("car", &""))
		MISSIONS:
			return Loc.t("YENİ GÖREVLER MASADA!")
	return ""


## Başlığın altındaki açıklama (manşette ve sütunda).
static func deck(item: Dictionary) -> String:
	var people: Array = item.get("people", [])
	var count: int = int(item.get("count", 1))
	var many: bool = people.size() > 1
	var first: String = _name(people[0] as Dictionary, false) if not people.is_empty() else ""
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			if many:
				return Loc.t("Toplam %d yarışta geride kaldın. En hızlısı %s oldu.") % [count, first]
			if count == 1:   # Türkçede "1 kez" kalıbı tuhaf: tekil ayrı cümle
				return Loc.t("%s ile senin aracını geride bıraktı. İntikam için ARKADAŞLAR'a uğra.") % _car(item.get("car", &""))
			return Loc.t("%s ile senin aracını %d kez geride bıraktı. İntikam için ARKADAŞLAR'a uğra.") \
				% [_car(item.get("car", &"")), count]
		RACE_WON:
			if many:
				return Loc.t("%s senin araçlarına meydan okudu, %d kez kaybettiler.") % [_who(people, false), count]
			if count == 1:
				return Loc.t("%s senin %s ile yarıştı ve kaybetti.") % [first, _car(item.get("car", &""))]
			return Loc.t("%s senin %s ile %d kez yarıştı, hepsinde kaybetti.") % [first, _car(item.get("car", &"")), count]
		EARNINGS:
			var lines: PackedStringArray = PackedStringArray()
			var jobs: int = int(item.get("jobs", 0))
			if jobs > 0:
				lines.append(Loc.tn("%s içinde %d araç tamir edildi.", jobs) % [duration_text(int(item.get("minutes", 0))), jobs])
			var done: int = int(item.get("finished", 0))
			if done > 0:
				var money: String = money_text(int(item.get("finished_money", 0)))
				var xp: int = int(item.get("finished_xp", 0))
				if done == 1:   # tekil ayrı cümle: "1 iş" / "the 1 job" doğal değil
					lines.append((Loc.t("Yarım bıraktığın iş de bitti (+%s, +%d XP).") if jobs > 0
						else Loc.t("Yarım bıraktığın iş bitti (+%s, +%d XP).")) % [money, xp])
				else:
					lines.append((Loc.t("Yarım bıraktığın %d iş de bitti (+%s, +%d XP).") if jobs > 0
						else Loc.t("Yarım bıraktığın %d iş bitti (+%s, +%d XP).")) % [done, money, xp])
			if bool(item.get("full", false)):
				lines.append(Loc.t("Garaj 8 saat sonra kepenk indirdi: sık uğra!"))
			return " ".join(lines)
		GIFT:
			if many:
				return Loc.t("%s sana toplam %s gönderdi.") % [_who(people, false), parts_text(item.get("parts", {}))]
			return Loc.t("%s sana %s gönderdi. Hurdalıkta işine yarayacak.") % [first, parts_text(item.get("parts", {}))]
		VISIT:
			var likes: int = int(item.get("likes", 0))
			if many:
				return Loc.t("%d arkadaşın garajını gezdi, %d tanesi beğendi.") % [people.size(), likes] if likes > 0 \
					else Loc.t("Garajını gezenler: %s. Dekorun konuşuluyor!") % _who(people, false)
			return Loc.t("%s garajını gezdi ve beğendi.") % first if likes > 0 \
				else Loc.t("%s garajını gezdi. Dekorun konuşuluyor!") % first
		FRIEND_NEW:
			return Loc.t("Yarışta karşına çıkabilir, garajını ziyaret edebilirsin.")
		FRIEND_REQUEST:
			return Loc.t("Kabul etmek için ARKADAŞLAR > İSTEKLER'e bak.")
		ASK:
			if many:
				var asks: PackedStringArray = PackedStringArray()
				for person: Variant in people:
					asks.append("%s: %s" % [_name(person as Dictionary, false), _part((person as Dictionary).get("part", &""))])
				return Loc.t("İstenenler: %s. ARKADAŞLAR'dan bedavaya gönderebilirsin.") % ", ".join(asks)
			return Loc.t("Hurdalık için %s istiyor. ARKADAŞLAR'dan bedavaya gönderebilirsin.") % _part(item.get("part", &""))
		PILES:
			return Loc.tn("%d yığın aranmayı bekliyor. Necati çayı demledi.", int(item.get("count", 1))) % int(item.get("count", 1))
		MOD_READY:
			return Loc.t("Atölyeden haber var: araç seni bekliyor.")
		MISSIONS:
			return Loc.t("Ödüller seni bekliyor, GÖREVLER'e göz at.")
	return ""


## KISA KISA şeridindeki tek satırlık hali.
static func brief(item: Dictionary) -> String:
	var people: Array = item.get("people", [])
	var count: int = int(item.get("count", 1))
	var who: String = _who(people)
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			return Loc.t("%s SENİ YENDİ") % who if count == 1 else Loc.t("%s SENİ %d KEZ YENDİ") % [who, count]
		RACE_WON:
			var car: String = _car(item.get("car", &""))
			return Loc.t("%s KAZANDI") % car if count == 1 else Loc.t("%s %d KEZ KAZANDI") % [car, count]
		EARNINGS:
			return Loc.t("GARAJ %s KAZANDI") % money_text(int(item.get("money", 0)))
		GIFT:
			return Loc.t("%s HEDİYE YOLLADI") % who
		VISIT:
			return Loc.t("%s GARAJINI GEZDİ") % who
		FRIEND_NEW:
			return Loc.t("%s ARKADAŞIN OLDU") % who
		FRIEND_REQUEST:
			if people.size() == 1:
				return Loc.t("%s ARKADAŞLIK İSTEĞİ GÖNDERDİ") % who
			return Loc.t("%d ARKADAŞLIK İSTEĞİ") % people.size()
		ASK:
			return Loc.t("%s PARÇA İSTİYOR") % who
		PILES:
			return Loc.t("HURDA YIĞINLARI DOLDU")
		MOD_READY:
			var mods: Array = item.get("mods", [])
			if mods.size() > 1:
				return Loc.t("%d MODİFİYE HAZIR") % mods.size()
			return Loc.t("%s MODİFİYESİ BİTTİ") % _car(item.get("car", &""))
		MISSIONS:
			if bool(item.get("weekly", false)) and not bool(item.get("daily", false)):
				return Loc.t("HAFTALIK GÖREVLER YENİLENDİ")
			return Loc.t("GÜNLÜK GÖREVLER YENİLENDİ")
	return ""


## Fotoğraf altı yazısı (manşet fotoğrafı).
static func caption(item: Dictionary) -> String:
	var people: Array = item.get("people", [])
	var first: String = _name(people[0] as Dictionary) if not people.is_empty() else ""
	match StringName(item.get("kind", &"")):
		RACE_LOST:
			return Loc.t("Foto: %s · %s") % [first, _car(item.get("car", &""))]
		RACE_WON, MOD_READY:
			return Loc.t("Foto: garajının yıldızı %s") % _car(item.get("car", &""))
		EARNINGS:
			return Loc.t("Foto: kasanın bugünkü hali")
		GIFT:
			return Loc.t("Foto: kargo kapında")
		VISIT, FRIEND_NEW, FRIEND_REQUEST, ASK:
			return Loc.t("Foto: %s") % _who(people)
		PILES:
			return Loc.t("Foto: Necati'nin hurdalığı")
		MISSIONS:
			return Loc.t("Foto: görev panosu")
	return ""


## "1 CIVATA, 2 BUJİ".
static func parts_text(parts: Variant) -> String:
	var list: PackedStringArray = PackedStringArray()
	if parts is Dictionary:
		for part: Variant in parts:
			list.append("%d %s" % [int(parts[part]), _part(StringName(part))])
	return ", ".join(list)


## "40 dakika" · "6 saat" (90 dakikadan sonra saate yuvarlanır).
static func duration_text(minutes: int) -> String:
	if minutes < 90:
		return Loc.t("%d dakika") % maxi(minutes, 1)
	return Loc.t("%d saat") % roundi(float(minutes) / 60.0)


## "2.300 ₺" (bölünmez boşluk: ₺ satır başına tek düşmesin).
static func money_text(money: int) -> String:
	return "%s\u00A0₺" % Hud.format_thousands(money)


## Ay adları (gazetenin tarih satırı).
static func date_text(date: Dictionary) -> String:
	var months: Array[String] = [Loc.t("OCAK"), Loc.t("ŞUBAT"), Loc.t("MART"), Loc.t("NİSAN"), Loc.t("MAYIS"),
		Loc.t("HAZİRAN"), Loc.t("TEMMUZ"), Loc.t("AĞUSTOS"), Loc.t("EYLÜL"), Loc.t("EKİM"), Loc.t("KASIM"), Loc.t("ARALIK")]
	var month: int = clampi(int(date.get("month", 1)), 1, 12)
	# Gün-ay-yıl sırası dilden gelir (DE "17. OKTOBER 2026"): çevrilebilir biçim
	return Loc.t("%d %s %d") % [int(date.get("day", 1)), months[month - 1], int(date.get("year", 2026))]


static func _pick(seed: int, options: Array) -> String:
	return String(options[posmod(seed, options.size())])


## "ELİF" · "ELİF VE MERT" · "ELİF VE 2 ARKADAŞIN". `upper`: başlıkta büyük harf, açıklamada adın kendisi.
static func _who(people: Array, upper: bool = true) -> String:
	if people.is_empty():
		return ""
	var first: String = _name(people[0] as Dictionary, upper)
	if people.size() == 1:
		return first
	if people.size() == 2:
		return (Loc.t("%s VE %s") if upper else Loc.t("%s ve %s")) % [first, _name(people[1] as Dictionary, upper)]
	return (Loc.t("%s VE %d ARKADAŞIN") if upper else Loc.t("%s ve %d arkadaşın")) % [first, people.size() - 1]


static func _name(person: Dictionary, upper: bool = true) -> String:
	var name: String = String(person.get("name", "")).strip_edges()
	if name.is_empty():
		name = Loc.t("Bir arkadaşın")
	return Loc.upper(name) if upper else name


static func _car(car_id: Variant) -> String:
	var entry: Dictionary = CarCatalog.get_entry(StringName(car_id))
	var name: String = String(entry.get("display_name", "")) if not entry.is_empty() else ""
	return Loc.upper(name) if not name.is_empty() else Loc.t("ARACIN")


static func _part(part_id: Variant) -> String:
	return Loc.t(RestorationCatalog.part_name(StringName(part_id)))


static func _part_total(item: Dictionary) -> int:
	var total: int = 0
	var parts: Dictionary = item.get("parts", {}) if item.get("parts") is Dictionary else {}
	for part: Variant in parts:
		total += int(parts[part])
	return total
