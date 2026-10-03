class_name SaveSafe
extends RefCounted
## Kayıt okurken tür dönüşümleri. `int(null)` / `int([])` / `String({})` GDScript'te çalışma zamanı hatası
## verir ve yüklemeyi yarıda keser; bozuk / elle düzenlenmiş / yarım inmiş bir bulut kaydı oyunu
## açılışta çökertebilirdi. Geçerli veride sonuç int() / float() / String() ile birebir aynıdır;
## geçersizde güvenli varsayılan döner. Sınır ±1e15: dev değerler toplama taşmasına yol açmasın.

const LIMIT: float = 1.0e15


## int(v) yerine: sayı / bool / sayısal metin dışı → 0. NaN, sonsuz ve dev değerler → 0 / sınır.
static func i(v: Variant) -> int:
	match typeof(v):
		TYPE_INT:
			return clampi(v, -int(LIMIT), int(LIMIT))
		TYPE_FLOAT:
			if is_nan(v) or is_inf(v):
				return 0
			return int(clampf(v, -LIMIT, LIMIT))
		TYPE_BOOL:
			return 1 if v else 0
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = String(v).strip_edges()
			if s.is_valid_float():
				return i(s.to_float())
	return 0


## float(v) yerine.
static func f(v: Variant) -> float:
	match typeof(v):
		TYPE_INT:
			return clampf(float(v), -LIMIT, LIMIT)
		TYPE_FLOAT:
			if is_nan(v) or is_inf(v):
				return 0.0
			return clampf(v, -LIMIT, LIMIT)
		TYPE_BOOL:
			return 1.0 if v else 0.0
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = String(v).strip_edges()
			if s.is_valid_float():
				return f(s.to_float())
	return 0.0


## String(v) / str(v) yerine: metin / sayı → metin; null, dizi, sözlük → "".
static func s(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			return String(v)
		TYPE_INT, TYPE_FLOAT:
			return str(v)
	return ""


## bool(v) yerine: bool / sayı → doğruluk değeri; diğer (null, dizi, sözlük, metin) → false.
static func b(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
	return false
