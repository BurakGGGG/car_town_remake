class_name TutorialManager
extends Node
## EĞİTİM (Rıza Usta'nın ustalık dersleri) — yalnızca DURUM: hangi ders bitti. Dersleri oynatan,
## ekranı karartıp düğme gösteren taraf UI'dadır (ui/tutorial/tutorial_director.gd).
## GarageSystem kodla kurar (arkadaş garajı ziyaretinde kurulmaz), "tutorial" grubundan bulunur.
##
## Kayıt SaveManager'da "tutorial" bölümüdür ({"done": [ders id]}). Bölüm eski kayıtta yoktur: o
## oyuncu seviye 2'ye ulaşmışsa oyunu zaten biliyordur, bütün dersler bitmiş sayılır (kimseye
## ortasından eğitim dayatılmaz); seviye 1'deyse eğitim baştan başlar. Ders bitince ödül
## (yalnızca ₺, ekonomiyi oynatmayacak kadar küçük) DİREKTÖR tarafından verilir.

## Bir ders bitti / atlandı ya da durum yüklendi (direktör çalışan dersi buna göre bırakır).
signal changed

const BASICS: StringName = &"basics"
const RACE: StringName = &"race"
const VEHICLES: StringName = &"vehicles"
const DECOR: StringName = &"decor"
## Ders sırası yalnızca numara için (DERS 2/4): dersler oyunda koşulu oluşunca başlar.
const ALL: Array[StringName] = [BASICS, RACE, VEHICLES, DECOR]
## Ders bitince verilen ödül (₺). Atlanan ders ödül vermez.
const REWARD: Dictionary = {BASICS: 500, RACE: 750, VEHICLES: 750, DECOR: 1000}
## Eski kayıtta bu seviyeye ulaşmış oyuncu oyunu biliyor sayılır.
const LEGACY_LEVEL: int = 2

var _done: Array[StringName] = []


func _ready() -> void:
	add_to_group("tutorial")


func is_done(id: StringName) -> bool:
	return _done.has(id)


func all_done() -> bool:
	for id: StringName in ALL:
		if not _done.has(id):
			return false
	return true


func done_count() -> int:
	return _done.size()


## Ders tamamlandı ya da oyuncu atladı (ikisi de bir daha gösterilmez).
func mark_done(id: StringName) -> void:
	if _done.has(id) or not ALL.has(id):
		return
	_done.append(id)
	changed.emit()
	_request_save()


## EĞİTİMİ ATLA: bütün dersler bitmiş sayılır.
func skip_all() -> void:
	var any: bool = false
	for id: StringName in ALL:
		if not _done.has(id):
			_done.append(id)
			any = true
	if any:
		changed.emit()
		_request_save()


## AYARLAR → NASIL OYNANIR?: dersler baştan (ödüller yeniden verilmez, bkz. rewarded).
func restart() -> void:
	_done.clear()
	_replay = true
	changed.emit()
	_request_save()


## Baştan oynanan eğitimde ödül yok (aynı ders iki kez para vermesin). Bayrak kayıtta tutulur:
## oyunu kapatıp açmak ödülleri geri getirmez.
var _replay: bool = false


func rewarded() -> bool:
	return not _replay


# --- Kayıt ------------------------------------------------------------------------

func state() -> Dictionary:
	var done: Array = []
	for id: StringName in _done:
		done.append(String(id))
	return {"done": done, "replay": _replay}


## present = kayıtta "tutorial" bölümü var mı (yoksa eski kayıt: seviyeye göre karar verilir).
func load_state(data: Dictionary, present: bool) -> void:
	_done.clear()
	_replay = false
	if not present:
		var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
		if progress and progress.level >= LEGACY_LEVEL:
			_done = ALL.duplicate()
		changed.emit()
		return
	var raw: Variant = data.get("done", [])
	if raw is Array:
		for value: Variant in raw:
			var id: StringName = StringName(SaveSafe.s(value))
			if ALL.has(id) and not _done.has(id):
				_done.append(id)
	var replay: Variant = data.get("replay", false)
	_replay = replay is bool and replay   # bozuk değer ödülü kapatmasın / açmasın
	changed.emit()


func reset() -> void:
	_done.clear()
	_replay = false
	changed.emit()


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
