class_name AdConfig
extends RefCounted
## REKLAM KİMLİKLERİ ve açma/kapama kuralı — tek yer.
##
## HESAP GÜVENLİĞİ: Google, gerçek reklam birimini geliştirme sırasında göstermeyi / tıklamayı
## hesap askıya alma sebebi sayar. Bu yüzden kimlik seçimi derleme türüne bağlı ve KOD İLE zorunlu:
##   debug derleme   → her zaman Google'ın TEST kimlikleri
##   release derleme → yalnızca gerçek kimlik; boşsa o yuva KAPALI (test reklamı yayına çıkmaz)
##
## Uygulama kimliği (ca-app-pub-…~…) kodda DEĞİL, Proje Ayarları → admob/general/android/app_id içindedir.

## Reklam YUVALARI: her yuvanın kendi AdMob birimi ve kendi önceden yüklenmiş reklamı vardır
## (AdMob raporlarında yarış / tamir ayrı görünür). Bir teklif türü AdPolicy.RULES'ta bir yuvaya bağlıdır.
const SLOT_RACE: StringName = &"race"
const SLOT_REPAIR: StringName = &"repair"

## Google'ın herkese açık test reklam birimleri (Android).
const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"

## GERÇEK ödüllü reklam birimleri (AdMob → AUTO YARD → Reklam birimleri).
const REAL_REWARDED: Dictionary = {
	SLOT_RACE: "ca-app-pub-7404501315536471/5366116477",     # odullu_yaris
	SLOT_REPAIR: "ca-app-pub-7404501315536471/4055980794",   # odullu_tamir
}


static func slots() -> Array[StringName]:
	return [SLOT_RACE, SLOT_REPAIR]


## Yuvanın ödüllü reklam birimi kimliği. Boş dönerse yuva kapalıdır.
static func rewarded_unit(slot: StringName) -> String:
	if OS.is_debug_build():
		return TEST_REWARDED
	return String(REAL_REWARDED.get(slot, ""))


## Bu derlemede, bu birim kimliği güvenle kullanılabilir mi? (test ↔ gerçek karışmasın)
static func unit_is_safe(unit_id: String) -> bool:
	if unit_id == "":
		return false
	var is_test: bool = unit_id.begins_with("ca-app-pub-3940256099942544/")
	return is_test == OS.is_debug_build()


## Herhangi bir yuva bu derlemede kullanılabilir mi? (hepsi boş/güvensizse reklam sistemi hiç kurulmaz)
static func any_slot_usable() -> bool:
	for slot: StringName in slots():
		if unit_is_safe(rewarded_unit(slot)):
			return true
	return false
