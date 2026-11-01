extends SceneTree
## RASTGELE TAKMA AD HAVUZU (2026-11-01): her dilde (TR/EN/ES/DE/FR) 3000+ birleşim, hepsi takma ad kuralından ve
## küfür süzgecinden geçer, oyun diline göre seçilir, tohumlu ad sabittir. Eski "Usta1234" oyuncusuna öneri kartı
## social_test §16'da (sahte Firebase).
##   tools/run_tests.sh name_pool_test

const MIN_COMBOS: int = 3000

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Havuz verisi ==")
	var langs: PackedStringArray = NamePool.languages()
	check(Array(langs).all(func(l: String) -> bool: return Loc.LANGUAGES.has(l)) and langs.size() == Loc.LANGUAGES.size(),
		"her oyun dilinin havuzu var: %s" % ", ".join(langs))
	for lang: String in langs:
		var usable: Dictionary = {}
		var invalid: PackedStringArray = PackedStringArray()
		for name: String in NamePool.all_names(lang):
			if name.length() > SocialNames.NAME_MAX:
				continue
			if not SocialNames.is_valid_name(name):
				invalid.append(name)
			usable[name] = true
		check(invalid.is_empty(), "[%s] her birleşim takma ad kuralından geçer%s" % [lang,
			"" if invalid.is_empty() else ": " + ", ".join(invalid.slice(0, 8))])
		check(usable.size() >= MIN_COMBOS, "[%s] %d farklı ad (en az %d)" % [lang, usable.size(), MIN_COMBOS])

	print("== Seçim ==")
	for lang: String in langs:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 42
		var pool: PackedStringArray = NamePool.all_names(lang)
		var ok: bool = true
		for i: int in 300:
			var name: String = NamePool.random_name(lang, rng)
			ok = ok and SocialNames.is_valid_name(name) and pool.has(name)
		check(ok, "[%s] 300 rastgele ad geçerli ve havuzdan (ör. %s)" % [lang, NamePool.random_name(lang, rng)])
	check(NamePool.seeded_name(123, "tr") == NamePool.seeded_name(123, "tr")
		and NamePool.seeded_name(123, "tr") != NamePool.seeded_name(124, "tr"), "tohumlu ad sabit, tohum değişince değişir")
	var before: String = Loc.current()
	Loc.use("de")
	check(NamePool.all_names("de").has(SocialNames.default_name()), "oyun dili Almanca: varsayılan ad Almanca havuzdan")
	Loc.use("fr")
	check(NamePool.all_names("fr").has(SocialNames.default_name()), "oyun dili Fransızca: varsayılan ad Fransızca havuzdan")
	Loc.use(before)
	var tr: Dictionary = {}
	for i: int in 40:
		tr[SocialNames.default_name()] = true
	check(tr.size() >= 36, "40 çekişte neredeyse hep farklı ad (%d farklı)" % tr.size())
	print("== Dil kuralları ==")
	var es: Dictionary = NamePool._load()["es"]
	check(NamePool.all_names("es").has("TuercaLoca") and NamePool.all_names("es").has("TornilloLoco"), "ES: sıfat ismin cinsiyetine uyar")
	check(NamePool.all_names("fr").has("BougieFolle") and NamePool.all_names("fr").has("PistonFou"), "FR: sıfat ismin cinsiyetine uyar")
	check(NamePool.all_names("de").has("RostigerKolben") and NamePool.all_names("de").has("RostigeBremse")
		and NamePool.all_names("de").has("RostigesLenkrad") and NamePool.all_names("de").has("LeiserMotor"),
		"DE: sıfat cinsiyete göre çekimli (-er / -e / -es; Leise → Leiser)")
	check(NamePool.all_names("tr").has("TurboSomun") and NamePool.all_names("tr").has("PaslıBuji"), "TR: onaylanan örnekler havuzda")
	check(not (es.get("pre", []) as Array).is_empty(), "ES: değişmez önekler (Turbo…) de var")
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
