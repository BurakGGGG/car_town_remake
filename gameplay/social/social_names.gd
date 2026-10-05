class_name SocialNames
extends RefCounted
## Arkadaş kodu ve takma ad kuralları. Firestore kurallarıyla (firebase/firestore.rules) AYNI
## biçimler: kod ^[A-HJ-NP-Z2-9]{6}$, ad ^[A-Za-z0-9ÇĞİÖŞÜçğıöşü ._-]{3,16}$. Burada reddedilen bir
## değer sunucuya hiç gitmez; sunucu yine de kendi kontrolünü yapar.

## Karışan karakterler yok: I/1, O/0 (ekrandan okunup yazılan kod).
const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH: int = 6
const NAME_MIN: int = 3
const NAME_MAX: int = 16
const NAME_PATTERN: String = "^[A-Za-z0-9ÇĞİÖŞÜçğıöşü ._-]{3,16}$"

## Takma adda geçemeyecek kökler (küçük harfe ve Türkçe karakterleri sadeleştirilmiş biçime göre).
## Kısa ve masum kelimelerin içinde geçebilenler (ör. "sik" → "fisek" değil ama "basikal") yalnızca
## TAM KELİME olarak aranır; uzun kökler kelime içinde de aranır.
const BLOCKED_ROOTS: PackedStringArray = [
	"orospu", "siktir", "sikis", "sikik", "yarrak", "yarak", "amcik", "amina", "aminako", "anani",
	"gotveren", "pezevenk", "kahpe", "kaltak", "ibne", "puşt", "pust", "gavat", "serefsiz",
	"fuck", "shit", "bitch", "cunt", "dick", "nigger", "nigga", "whore", "slut", "puta", "mierda",
	"admin", "moderator", "autoyard",
]
const BLOCKED_WORDS: PackedStringArray = ["amk", "aq", "oc", "sik", "got", "mk", "piç", "pic", "ass", "sex", "seks"]


## Rastgele kod (6 karakter). Çakışırsa sunucu reddeder, çağıran yenisini dener.
static func random_code(rng: RandomNumberGenerator = null) -> String:
	var out: String = ""
	for i: int in CODE_LENGTH:
		var index: int = rng.randi_range(0, CODE_ALPHABET.length() - 1) if rng \
			else randi_range(0, CODE_ALPHABET.length() - 1)
		out += CODE_ALPHABET[index]
	return out


## Oyuncunun yazdığı kodu biçime sokar: büyük harf, boşluk / tire / "AY-" öneki atılır.
static func normalize_code(raw: String) -> String:
	var text: String = raw.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if text.begins_with("AY") and text.length() == CODE_LENGTH + 2:
		text = text.substr(2)
	return text


static func is_valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for c: String in code:
		if not CODE_ALPHABET.contains(c):
			return false
	return true


## Gösterim biçimi: "AY-7K2Q4M".
static func display_code(code: String) -> String:
	return "AY-" + code


## Baştaki / sondaki boşluklar atılır, aradaki çoklu boşluk teke iner.
static func clean_name(raw: String) -> String:
	var text: String = raw.strip_edges()
	while text.contains("  "):
		text = text.replace("  ", " ")
	return text


static func is_valid_name(name: String) -> bool:
	var regex: RegEx = RegEx.create_from_string(NAME_PATTERN)
	return regex.search(name) != null and not is_blocked(name)


## Uygunsuz ad mı? Türkçe harfler sadeleştirilir, ayraçlar atılır ("o.r.o.s.p.u" da yakalanır).
static func is_blocked(name: String) -> bool:
	var simple: String = _simplify(name)
	var joined: String = simple.replace(" ", "").replace(".", "").replace("_", "").replace("-", "")
	for root: String in BLOCKED_ROOTS:
		if joined.contains(_simplify(root)):
			return true
	for word: String in simple.replace(".", " ").replace("_", " ").replace("-", " ").split(" ", false):
		for blocked: String in BLOCKED_WORDS:
			if word == _simplify(blocked):
				return true
	return false


## Yeni profil için önerilen ad: "Usta" + 4 rakam.
static func default_name(rng: RandomNumberGenerator = null) -> String:
	var number: int = rng.randi_range(1000, 9999) if rng else randi_range(1000, 9999)
	return "Usta%d" % number


static func _simplify(text: String) -> String:
	var out: String = text.to_lower()
	for pair: Array in [["ç", "c"], ["ğ", "g"], ["ı", "i"], ["i̇", "i"], ["ö", "o"], ["ş", "s"], ["ü", "u"],
			["Ç", "c"], ["Ğ", "g"], ["İ", "i"], ["Ö", "o"], ["Ş", "s"], ["Ü", "u"]]:
		out = out.replace(pair[0], pair[1])
	return out
