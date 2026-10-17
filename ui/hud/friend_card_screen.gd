class_name FriendCardScreen
extends Control
## ARKADAŞ KARTI: ARKADAŞLAR listesinde bir kişiye dokununca açılır (UiRouter MODAL &"friend_card"). Kişinin profil
## kartı + duruma göre işlemler:
##   öne çıkan (Emre / Elif)  → GARAJA GİT
##   arkadaş                  → GARAJA GİT · ŞİKAYET ET · ENGELLE · ÇIKAR
##   gelen istek              → KABUL · RET · ŞİKAYET ET · ENGELLE
##   giden istek              → GERİ AL
## ŞİKAYET ET önce nedeni sorar (FOTOĞRAF / TAKMA AD / GARAJ); ENGELLE ve ÇIKAR iki adımlıdır. Şikâyet ve engel
## Play'in kullanıcı içeriği kuralı için (kullanıcı kararı 2026-10-16: galeri / kamera fotoğrafı yüklenebiliyor).
## Mantık SocialManager'da; bu ekran yalnızca düğmeleri ona iletir.

signal closed
## Başka bir ekran istendi.
signal screen_requested(id: StringName)

enum Mode { FEATURED, FRIEND, INCOMING, OUTGOING }

const BUTTON_WIDTH: float = 124.0

var _social: SocialManager
var _card: ProfileCard
var _score: Label
var _score_plate: PlatePanel
var _actions: HBoxContainer
var _notice: Label
var _column: VBoxContainer
var _uid: String = ""
var _mode: Mode = Mode.FRIEND
var _confirm: StringName = &""   # &"block" / &"remove" / &"report" (ikinci adım bekleniyor)
var _closing: bool = false
## Açılış / kapanış sayacı: kapanış animasyonu sürerken yeniden açılırsa eski kapanış (gizle + closed) iptal olur.
var _gen: int = 0


func _ready() -> void:
	name = "FriendCardScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect_social.call_deferred()


## Gösterilecek kişi (router.open'dan önce). Bulunamazsa false.
func show_for(uid: String) -> bool:
	var entry: Dictionary = {}
	if FeaturedFriends.is_featured(uid):
		entry = FeaturedFriends.get_entry(uid)
		_mode = Mode.FEATURED
	elif _social:
		entry = _social.person(uid)
		_mode = Mode.FRIEND if _social.is_friend(uid) else (
			Mode.INCOMING if _index(_social.incoming, uid) >= 0 else Mode.OUTGOING)
	if entry.is_empty():
		return false
	_uid = uid
	_confirm = &""
	_notice.text = ""
	_card.show_person(entry)
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	var score: Vector2i = race.score_with(uid) if race else Vector2i.ZERO
	_score.text = Loc.t("SKOR   SEN %d  –  %d %s") % [score.x, score.y, Loc.upper(SaveSafe.s(entry.get("name", "")))]
	_score_plate.visible = score.x + score.y > 0
	_build_actions()
	return true


func open() -> void:
	_gen += 1
	_closing = false
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_gen += 1
	var gen: int = _gen
	PlateAnim.pop_out(self, _column, func() -> void:
		if gen != _gen:
			return
		hide()
		_closing = false
		closed.emit())


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)   # alt pano: altındaki liste belirgin kalmasın
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)
	_card = ProfileCard.new()
	_card.name = "Card"
	_column.add_child(_card)
	_score_plate = PlatePanel.new()
	_score_plate.name = "ScorePlate"
	_score_plate.theme_type_variation = &"HudCarPlate"
	_score_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_score = Label.new()
	_score.name = "Score"
	_score.theme_type_variation = &"HudInkValue"
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_plate.add_child(_score)
	_column.add_child(_score_plate)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override(&"separation", 6)
	_column.add_child(_actions)
	_notice = Label.new()
	_notice.theme_type_variation = &"HudInkCaption"
	_notice.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(ProfileCard.CARD_WIDTH, 0.0)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_notice)
	var close_button: PlateButton = _button(Loc.t("KAPAT"), close)
	close_button.name = "CloseButton"
	close_button.custom_minimum_size = Vector2(ProfileCard.CARD_WIDTH, 0.0)
	_column.add_child(close_button)


func _connect_social() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social == null:
		return
	_social.notice.connect(func(text: String) -> void:
		if visible:
			_notice.text = text)
	_social.avatar_ready.connect(func(uid: String) -> void:
		if visible and uid == _uid:
			_card.show_person(_card.person()))


func _build_actions() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var busy: bool = _social != null and _social.is_busy()
	if _confirm == &"report":
		_actions.add_child(_button(Loc.t("FOTOĞRAF"), _report.bind("photo"), busy, true))
		_actions.add_child(_button(Loc.t("TAKMA AD"), _report.bind("name"), busy, true))
		_actions.add_child(_button(Loc.t("GARAJ"), _report.bind("garage"), busy, true))
		_actions.add_child(_button(Loc.t("VAZGEÇ"), _set_confirm.bind(&"")))
		_notice.text = Loc.t("Neyi şikâyet ediyorsun?")
		return
	match _mode:
		Mode.FEATURED:
			_actions.add_child(_button(Loc.t("GARAJA GİT"), _visit, busy, true))
		Mode.FRIEND:
			_actions.add_child(_button(Loc.t("GARAJA GİT"), _visit, busy, true))
			_actions.add_child(_button(Loc.t("ŞİKAYET ET"), _set_confirm.bind(&"report"), busy))
			_actions.add_child(_danger(Loc.t("ENGELLE"), &"block", busy))
			_actions.add_child(_danger(Loc.t("ÇIKAR"), &"remove", busy))
		Mode.INCOMING:
			_actions.add_child(_button(Loc.t("KABUL"), _answer.bind(true), busy, true))
			_actions.add_child(_button(Loc.t("RET"), _answer.bind(false), busy))
			_actions.add_child(_button(Loc.t("ŞİKAYET ET"), _set_confirm.bind(&"report"), busy))
			_actions.add_child(_danger(Loc.t("ENGELLE"), &"block", busy))
		Mode.OUTGOING:
			_actions.add_child(_button(Loc.t("GERİ AL"), _cancel_request, busy))


## Tehlikeli işlem: ilk basış EMİN MİSİN? sorar, ikincisi yapar.
func _danger(text: String, what: StringName, busy: bool) -> PlateButton:
	var asking: bool = _confirm == what
	var button: PlateButton = _button(Loc.t("EMİN MİSİN?") if asking else text, func() -> void:
		if _confirm != what:
			_set_confirm(what)
			return
		_confirm = &""
		if what == &"block":
			await _social.block(_uid)
		else:
			await _social.remove_friend(_uid)
		close(), busy)
	if asking:
		for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
			button.add_theme_color_override(color_name, HudPalette.DANGER)
	return button


func _answer(accept: bool) -> void:
	if accept:
		await _social.accept(_uid)
	else:
		await _social.reject(_uid)
	close()


func _cancel_request() -> void:
	await _social.cancel(_uid)
	close()


func _set_confirm(what: StringName) -> void:
	_confirm = what
	_notice.text = ""
	if what == &"block":
		_notice.text = Loc.t("Engellersen arkadaşlıktan çıkar, istekleri ve fotoğrafı sana görünmez.")
	_build_actions()


func _report(reason: String) -> void:
	_confirm = &""
	await _social.report(_uid, reason)
	_card.show_person(_card.person())   # şikâyet edilen fotoğraf artık gizli
	_build_actions()


func _visit() -> void:
	var uid: String = _uid
	close()
	if FeaturedFriends.is_featured(uid):
		if not FeaturedFriends.visit(get_tree(), uid) and _social:
			_social.notice.emit(Loc.t("Kayıt buluta yazılıyor, birazdan tekrar dene."))
	elif _social:
		_social.visit(uid)


func _button(text: String, callback: Callable, disabled: bool = false, accent: bool = false) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	button.highlight = accent
	button.bolts = false
	button.pressed.connect(callback)
	return button


static func _index(list: Array[Dictionary], uid: String) -> int:
	for i: int in list.size():
		if SaveSafe.s(list[i].get("uid", "")) == uid:
			return i
	return -1
