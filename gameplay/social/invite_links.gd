class_name InviteLinks
extends Node
## DAVET LİNKİ ALICISI (2026-10-17). Arkadaşın gönderdiği link (https://autoyard.online/d/<jeton>) web
## sayfasında oyunu autoyard://davet/<jeton> ile açar (Android intent filtresi: addons/GodotFirebaseAndroid/
## export_plugin.gd). Bu düğüm açılışta ve oyun her öne geldiğinde etkinliğin intent verisine bakar — Godot'nun etkinliği
## (singleInstancePerTask) uygulama açıkken gelen yeni intent'i de getIntent()'e koyar —, jetonu ayıklar ve
## invite_opened yayar. Aynı jeton süreç boyunca bir kez işlenir. HUD kurar; ekranı InviteScreen gösterir.
## `pending`: gösterilmeyi bekleyen jeton. STATİK: Google girişi sahneyi yeniden kurar, davet kaybolmasın.
## Masaüstü / QA: `-- --davet=<jeton>`.

signal invite_opened(token: String)

const SCHEME: String = "autoyard://davet/"
const ARG: String = "--davet="

static var pending: String = ""
static var _handled: Dictionary = {}   # jeton → true


func _ready() -> void:
	name = "InviteLinks"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ARG):
			_receive(arg.trim_prefix(ARG))
	_check_intent.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_check_intent()


## Linkten ya da metinden jeton (geçersizse boş): autoyard://davet/X, https://…/d/X ya da çıplak jeton.
static func parse_token(text: String) -> String:
	var token: String = text.strip_edges()
	for prefix: String in [SCHEME, SocialManager.INVITE_URL] + SocialManager.LEGACY_INVITE_URLS:
		token = token.trim_prefix(prefix)
	token = token.get_slice("?", 0).get_slice("#", 0).trim_suffix("/").to_upper()
	return token if SocialNames.is_valid_token(token) else ""


## Davet ekranı işini bitirdi (eklendi / vazgeçildi): jeton artık beklemiyor.
static func clear_pending(token: String) -> void:
	if pending == token:
		pending = ""


func _check_intent() -> void:
	var data: String = _intent_data()
	if not data.is_empty():
		_receive(data)


func _receive(text: String) -> void:
	var token: String = parse_token(text)
	if token.is_empty() or _handled.has(token):
		return
	_handled[token] = true
	pending = token
	invite_opened.emit(token)


func _intent_data() -> String:
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return ""
	var activity: Object = Engine.get_singleton("AndroidRuntime").call("getActivity")
	if activity == null:
		return ""
	var intent: Object = activity.call("getIntent")
	if intent == null:
		return ""
	var data: Variant = intent.call("getDataString")
	return data if data is String else ""
