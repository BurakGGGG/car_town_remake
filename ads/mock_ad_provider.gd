class_name MockAdProvider
extends AdProvider
## Masaüstü geliştirme ve testler için sahte sağlayıcı. Gerçek reklam göstermez.
## Testler davranışı bu alanlarla yönlendirir: start_ok, load_ok, earns.

var start_ok: bool = true
var load_ok: bool = true
## Reklam izlenince ödül hak edilsin mi? false = oyuncu erken kapattı.
var earns: bool = true
## Gösterim / yükleme sayıları (testler çift gösterimi yakalamak için okur).
var shows: int = 0
var loads: int = 0
var last_shown_slot: StringName = &""
## Gizlilik seçenekleri giriş noktası gerekli mi (testler / masaüstü önizleme için)?
var privacy_required: bool = false
var privacy_shows: int = 0

var _loaded: Dictionary = {}   # yuva → bool


func start(on_ready: Callable) -> void:
	on_ready.call_deferred(start_ok)


func load_rewarded(slot: StringName, _unit_id: String, on_result: Callable) -> void:
	loads += 1
	_loaded[slot] = load_ok
	on_result.call_deferred(load_ok)


func show_rewarded(slot: StringName, on_earned: Callable, on_finished: Callable) -> void:
	if not bool(_loaded.get(slot, false)):
		on_finished.call_deferred()
		return
	_loaded[slot] = false
	shows += 1
	last_shown_slot = slot
	if earns:
		on_earned.call_deferred()
	on_finished.call_deferred()


func has_rewarded(slot: StringName) -> bool:
	return bool(_loaded.get(slot, false))


func privacy_options_required() -> bool:
	return privacy_required


func show_privacy_options(on_done: Callable) -> void:
	privacy_shows += 1
	on_done.call_deferred()
