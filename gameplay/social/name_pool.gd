class_name NamePool
extends RefCounted
## RASTGELE TAKMA AD HAVUZU (2026-11-01, kullanıcı kararı): ilk profilde "Usta1234" yerine oyun dilinde "sıfat + garaj
## nesnesi" (TurboSomun, RustyPiston, TuercaLoca, RostigerKolben, PistonFou). Bitişik, sayısız; her dilde 3000+ birleşim.
## Kelimeler name_pool.json'da (biçim orada anlatılır). Profil düzenlemedeki ZAR ve eski "Usta1234" oyuncusuna bir kez
## gösterilen öneri kartı (RenamePrompt) da buradan çeker. Her birleşimin takma ad kuralından geçtiği name_pool_test'te
## denetlenir; çalışırken yalnız uzunluk denenir (16 harften uzun birleşim yeniden çekilir).

const DATA_PATH: String = "res://gameplay/social/name_pool.json"
## Uzun birleşime denk gelince yeniden çekme sınırı (her dilde birleşimlerin %80'inden fazlası sığar).
const MAX_TRIES: int = 24

static var _data: Dictionary = {}


## Oyun dilinde (boşsa Loc.current()) rastgele takma ad.
static func random_name(lang: String = "", rng: RandomNumberGenerator = null) -> String:
	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()
	var entry: Dictionary = _entry(lang)
	var nouns: Array = entry.get("nouns", [])
	var modifiers: int = _modifier_count(entry)
	if nouns.is_empty() or modifiers == 0:
		return "Usta%d" % gen.randi_range(1000, 9999)   # veri okunamadı (olmamalı): eski biçim
	var name: String = ""
	for i: int in MAX_TRIES:
		name = compose(entry, gen.randi_range(0, modifiers - 1), gen.randi_range(0, nouns.size() - 1))
		if name.length() >= SocialNames.NAME_MIN and name.length() <= SocialNames.NAME_MAX:
			return name
	return name.substr(0, SocialNames.NAME_MAX)


## Aynı tohumdan hep aynı ad (geçersiz adlı başka oyuncu için kimliğinden türeyen yedek ad).
static func seeded_name(seed: int, lang: String = "") -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return random_name(lang, rng)


## Bir dilin bütün birleşimleri (uzunlar dahil; testler ve sayım için).
static func all_names(lang: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var entry: Dictionary = _entry(lang)
	var nouns: Array = entry.get("nouns", [])
	for m: int in _modifier_count(entry):
		for n: int in nouns.size():
			out.append(compose(entry, m, n))
	return out


static func languages() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key: String in _load():
		if not key.begins_with("_"):
			out.append(key)
	return out


## `modifier` sırası: önce pre (isimden önce, değişmez), sonra post (isimden sonra, cinsiyete göre [eril, dişil]),
## sonra adj (isimden önce, Almanca çekim: eril -er, dişil -e, nötr -es; "e" ile biten sıfatın e'si düşer: Leise → Leiser).
static func compose(entry: Dictionary, modifier: int, noun_index: int) -> String:
	var raw: Variant = (entry.get("nouns", []) as Array)[noun_index]
	var noun: String = String(raw[0]) if raw is Array else String(raw)
	var gender: String = String(raw[1]) if raw is Array and (raw as Array).size() > 1 else "m"
	var pre: Array = entry.get("pre", [])
	if modifier < pre.size():
		return String(pre[modifier]) + noun
	modifier -= pre.size()
	var post: Array = entry.get("post", [])
	if modifier < post.size():
		var forms: Array = post[modifier]
		return noun + String(forms[1] if gender == "f" else forms[0])
	modifier -= post.size()
	var adj: String = String((entry.get("adj", []) as Array)[modifier])
	var stem: String = adj.substr(0, adj.length() - 1) if adj.ends_with("e") else adj
	return stem + {"m": "er", "f": "e", "n": "es"}.get(gender, "er") + noun


static func _modifier_count(entry: Dictionary) -> int:
	return (entry.get("pre", []) as Array).size() + (entry.get("post", []) as Array).size() \
		+ (entry.get("adj", []) as Array).size()


static func _entry(lang: String) -> Dictionary:
	var data: Dictionary = _load()
	var key: String = lang if not lang.is_empty() else Loc.current()
	if not data.has(key):
		key = "en" if data.has("en") else "tr"
	return data.get(key, {})


static func _load() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data
