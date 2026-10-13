extends SceneTree
## PERFORMANS MODİFİYESİ — ÖLÇÜM RAPORU (docs/PERFORMANS_MODIFIYE_TASARIM.md). Oyunun modelini (PerformanceMods)
## kataloğun bütün araçlarında, bütün kategori × kademelerde kusursuz sürüşle ölçer: gösterilen 0-100, son hız,
## beygir, 300 m. Tasarım belgesindeki tablolar bunun çıktısıdır.
## Kullanım: godot-4 --headless --path . -s res://qa/mod_report.gd -- [tablo|kademe <araç>|json <yol>]

const STAGES: int = PerformanceMods.STAGES
const CATS: Array[StringName] = PerformanceMods.CATEGORIES


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "tablo"
	if mode == "kademe":
		_print_stages(StringName(args[1]))
		quit()
		return
	var rows: Array[Dictionary] = []
	for entry: Dictionary in CarCatalog.all():
		rows.append(_car_report(entry["id"]))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["stock"]["t300"] < b["stock"]["t300"])
	if mode == "json":
		var file: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
		file.store_string(JSON.stringify(rows, " "))
		file.close()
		print("yazıldı: ", args[1])
	else:
		_print_table(rows)
	quit()


## Bir aracın fabrika, kategori başına (kademe 1..5), full ve kombinasyon ölçümleri + fiyatlar.
func _car_report(id: StringName) -> Dictionary:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var perf: Dictionary = entry.get("performance", {})
	var out: Dictionary = {"id": String(id), "class": entry.get("class", "?"), "drive": perf.get("drivetrain", "?"),
		"profile": String(PerformanceMods.profile_of(id)), "real_0_100": float(perf.get("zero_100", 0.0)),
		"real_top": float(perf.get("top_speed", 0.0)), "hp": int(perf.get("hp", 0)), "price": int(entry.get("price", 0)),
		"stock": PerformanceMods.measure(id, {}), "cats": {}, "prices": {}}
	for cat: StringName in CATS:
		var stages: Array = []
		var prices: Array = []
		for s: int in range(1, STAGES + 1):
			stages.append(PerformanceMods.measure(id, {cat: s}))
			prices.append(PerformanceMods.price(id, cat, s))
		out["cats"][String(cat)] = stages
		out["prices"][String(cat)] = prices
	var full: Dictionary = {}
	for cat: StringName in CATS:
		full[cat] = STAGES
	out["full"] = PerformanceMods.measure(id, full)
	out["full_class"] = PerformanceMods.class_for(id, float(out["full"]["t300"]))
	var power: Dictionary = {&"motor": STAGES, &"turbo": STAGES, &"air": STAGES}
	out["power_only"] = PerformanceMods.measure(id, power)
	var power_tire: Dictionary = power.duplicate()
	power_tire[&"tire"] = STAGES
	out["power_tire"] = PerformanceMods.measure(id, power_tire)
	return out


func _pct(after: float, before: float) -> float:
	return (after / before - 1.0) * 100.0


func _print_table(rows: Array[Dictionary]) -> void:
	print("araç                   sn çkş  profil        0-100  300m | FULL 0-100 (%%)    300m(%%)  sınıf sonhız  güç | motor turbo hava şanz lastik gövde [300m %%, EFSANE] | güç→+lastik")
	for r: Dictionary in rows:
		var st: Dictionary = r["stock"]
		var fu: Dictionary = r["full"]
		var real: float = float(r["real_0_100"])
		var line: String = "%-22s %-2s %-4s %-12s %5.1f %6.2f | %5.2f (%5.1f) %6.2f(%5.1f) %-2s %+5.1f %+5.1f |" % [
			r["id"], r["class"], r["drive"], r["profile"], real, st["t300"],
			real * fu["tref"] / st["tref"], _pct(fu["tref"], st["tref"]), fu["t300"], _pct(fu["t300"], st["t300"]),
			r["full_class"], (fu["top"] - 1.0) * 100.0, (fu["power"] - 1.0) * 100.0]
		for cat: StringName in CATS:
			line += " %5.1f" % _pct(r["cats"][String(cat)][STAGES - 1]["t300"], st["t300"])
		line += " | %5.1f" % _pct(r["power_tire"]["t300"], r["power_only"]["t300"])
		print(line)


## Tek araç, kategori × kademe: gösterilecek 0-100 / son hız / beygir / 300 m / fiyat.
func _print_stages(id: StringName) -> void:
	var r: Dictionary = _car_report(id)
	var st: Dictionary = r["stock"]
	var real: float = float(r["real_0_100"])
	var top: float = float(r["real_top"])
	var hp: int = int(r["hp"])
	print("%s (%s, %s, %s): fabrika 0-100 %.1f · son hız %.0f · %d bg · 300 m %.2f" % [id, r["class"], r["drive"],
		r["profile"], real, top, hp, st["t300"]])
	for cat: StringName in CATS:
		var line: String = "  %-6s" % cat
		for s: int in STAGES:
			var m: Dictionary = r["cats"][String(cat)][s]
			line += " | %4.2f sn %3.0f km/s %3.0f bg %5.2f %6d ₺" % [real * m["tref"] / st["tref"], top * m["top"],
				hp * m["power"], m["t300"], r["prices"][String(cat)][s]]
		print(line)
	var fu: Dictionary = r["full"]
	print("  FULL   | %4.2f sn %3.0f km/s %3.0f bg %5.2f → %s" % [real * fu["tref"] / st["tref"], top * fu["top"],
		hp * fu["power"], fu["t300"], r["full_class"]])
