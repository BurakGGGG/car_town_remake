class_name MailNotice
extends Control
## POSTA PENCERESİ — yönetim panelinden gelen hediye / mesaj (MailService). Oyun SAKİNKEN açılır (ekran, ders, kasa
## panosu, yükleme ekranı, uzaktan ayar penceresi yok; FounderRewardNotice ile aynı kural): POSTA tabelası, gönderen,
## başlık, mesaj ve ödül satırları. AL → ödül hesaba geçer, ödül penceresi açılır (paralar sayaçlara uçar); ödülsüz
## mesajda TAMAM. Birden çok posta sırayla gelir (eskisi önce). Hud kurar (_setup_gem_store). Ekran TAMAMEN KODLA kurulur.
## ARKADAŞ DAVETİ postaları (2026-10-23, MailService "ref_kind"): tabela DAVETLE GELDİN! / N. DAVET ÖDÜLÜ; davet edenin
## ya da sayılan arkadaşın avatarı, basamak ilerlemesi (ReferralDots) ve altta bir sonraki basamak. 10. basamaktaki
## efsanevi araç seçimi ödül penceresi kapanınca açılır (UiRouter &"legendary_pick"). DAVET ET sekmesinin AL'ı claim_now.

const PANEL_WIDTH: float = 420.0
const CHECK_SEC: float = 0.5
## Oyun bu kadar sakin kalınca açılır (açılışta bir şey gelip pencerenin altında kalmasın).
const CALM_SEC: float = 1.5

var _hud: Hud
var _mail: MailService
var _popup: RewardPopup
var _column: VBoxContainer
var _box: VBoxContainer
var _sign_title: Label
var _button: PlateButton
var _current: String = ""
var _calm: float = 0.0
var _timer: Timer
var _closing: bool = false
var _pick_after: bool = false   # alınan postada efsanevi araç seçimi vardı: ödül penceresinden sonra seçim ekranı


func _init(hud: Hud, mail: MailService) -> void:
	name = "MailNotice"
	_hud = hud
	_mail = mail


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya dokunuş gitmez
	_build()
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_mail.arrived.connect(_on_arrived)
	_on_arrived()


## Açık postanın kimliği (testler): boşsa pencere kapalı.
func current() -> String:
	return _current


## DAVET ET sekmesindeki AL: posta pencere beklemeden alınır, ödül penceresi açılır. Alındıysa true.
func claim_now(id: String) -> bool:
	if visible and _current == id:
		_on_take()
		return true
	var summary: Dictionary = _mail.claim(id)
	if summary.is_empty():
		return false
	_show_rewards(summary)
	return true


func _on_arrived() -> void:
	_calm = 0.0
	if not _mail.pending().is_empty():
		_timer.start()


func _tick() -> void:
	if visible or (_popup and _popup.visible):
		return
	if _mail.pending().is_empty():
		_timer.stop()
		return
	if not _is_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm < CALM_SEC:
		return
	_calm = 0.0
	_open(_mail.pending()[0])


func _is_calm() -> bool:
	var tree: SceneTree = get_tree()
	var tutorial: TutorialDirector = _hud.tutorial
	var config: AppConfig = AppConfig.of(tree)
	var gate: AppGate = config.get_node_or_null("AppGate") as AppGate if config else null
	return _hud.router.top().is_empty() and not (tutorial and tutorial.is_running()) \
		and not (_hud.crate_panel and _hud.crate_panel.visible) \
		and not (_hud.restoration_result and _hud.restoration_result.visible) \
		and not (_hud.level_up_screen and _hud.level_up_screen.visible) \
		and not (gate and (gate.blocker_kind() != &"" or gate.dialog_kind() != &"")) \
		and tree.root.get_node_or_null("LoadingScreen") == null


func _open(mail: Dictionary) -> void:
	_current = SaveSafe.s(mail["id"])
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var ref_kind: String = SaveSafe.s(mail.get("ref_kind", ""))
	_sign_title.text = Loc.t("POSTA")
	if not ref_kind.is_empty():
		_referral_head(mail, ref_kind)
	else:
		var from: String = SaveSafe.s(mail.get("from", ""))
		var sender: Label = _label(&"HudInkCaption", Loc.t("%s gönderdi") % (from if not from.is_empty() else "AUTO YARD"))
		sender.modulate.a = 0.7
		_box.add_child(sender)
		var title: String = SaveSafe.s(mail.get("title", ""))
		if not title.is_empty():
			var head: Label = _label(&"HudPlateTitle", title)
			head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			head.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
			_box.add_child(head)
		var text: String = SaveSafe.s(mail.get("text", ""))
		if not text.is_empty():
			_box.add_child(_wrapped(text))
	var rewards: VBoxContainer = VBoxContainer.new()
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.add_theme_constant_override(&"separation", 2)
	if int(mail["money"]) > 0:
		rewards.add_child(_reward_row(HudIcon.Kind.COIN, "+%s ₺" % Hud.format_thousands(int(mail["money"])), HudPalette.COIN_DARK))
	if int(mail["money_min"]) > 0:   # davet ödülü: aktif gelirin dakikası, alındığı andaki tutar
		var income: int = MailService.income_money(get_tree(), int(mail["money_min"]))
		rewards.add_child(_reward_row(HudIcon.Kind.COIN, "+%s ₺" % Hud.format_thousands(income), HudPalette.COIN_DARK))
	if int(mail["gems"]) > 0:
		rewards.add_child(_reward_row(HudIcon.Kind.GEM, Loc.t("+%d GEM") % int(mail["gems"]), HudPalette.GEM_DARK))
	if not String(mail["frame"]).is_empty():
		rewards.add_child(_reward_row(HudIcon.Kind.HELMET, MailService.frame_name(mail["frame"]), HudPalette.INK))
	if not String(mail["choice"]).is_empty():
		rewards.add_child(_reward_row(HudIcon.Kind.CAR, Loc.t("EFSANEVİ ARAÇ SEÇİMİ"), HudPalette.INK))
	var crates: Dictionary = mail["crates"]
	for crate_id: StringName in crates:
		var count: int = int(crates[crate_id])
		var name_text: String = MailService.crate_name(crate_id)
		rewards.add_child(_reward_row(HudIcon.Kind.BOX, name_text if count == 1 else "%s ×%d" % [name_text, count], HudPalette.INK))
	var decor: Dictionary = mail["decor"]
	for item: StringName in decor:
		var count: int = int(decor[item])
		var name_text: String = MailService.decor_name(item)
		rewards.add_child(_reward_row(HudIcon.Kind.CHAIR, name_text if count == 1 else "%s ×%d" % [name_text, count], HudPalette.INK))
	# Bakiye düzeltmesi: artı yeşil değil kendi renginde, eksi kırmızı ve "−" ile
	var adjust: Dictionary = mail["adjust"]
	var adjust_money: int = int(adjust.get("money", 0))
	var adjust_gems: int = int(adjust.get("gems", 0))
	if adjust_money != 0:
		rewards.add_child(_reward_row(HudIcon.Kind.COIN, "%s%s ₺" % ["+" if adjust_money > 0 else "−", Hud.format_thousands(absi(adjust_money))],
			HudPalette.COIN_DARK if adjust_money > 0 else HudPalette.DANGER))
	if adjust_gems != 0:
		rewards.add_child(_reward_row(HudIcon.Kind.GEM, ("+" if adjust_gems > 0 else "−") + Loc.t("%d GEM") % absi(adjust_gems),
			HudPalette.GEM_DARK if adjust_gems > 0 else HudPalette.DANGER))
	var restore: Dictionary = mail["restore"]
	if not restore.is_empty():
		var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var t: Dictionary = Time.get_datetime_dict_from_unix_time(int(restore.get("at", 0)) + bias)
		rewards.add_child(_reward_row(HudIcon.Kind.UNDO, Loc.t("Kayıt: %s") % ("%s %02d:%02d" % [NewsDigest.date_text(t), int(t["hour"]), int(t["minute"])]),
			HudPalette.INK))
		var hint: Label = _wrapped(Loc.t("Dokununca oyunun bu kayda döner; şimdiki kaydın telefonunda yedeklenir."))
		hint.modulate.a = 0.7
		rewards.add_child(hint)
	if rewards.get_child_count() > 0:
		_box.add_child(HSeparator.new())
		_box.add_child(rewards)
	if not ref_kind.is_empty():
		_referral_foot(mail, ref_kind)
	var gift: bool = MailService.has_reward(mail)
	_button.text = Loc.t("KAYDI GERİ YÜKLE") if not restore.is_empty() else (Loc.t("AL") if gift else Loc.t("TAMAM"))
	_button.disabled = false
	_closing = false
	modulate.a = 0.0
	show()
	await get_tree().process_frame   # sütunun boyu belli olsun: pano ortasından büyüsün
	PlateAnim.pop_in(self, _column)


func _on_take() -> void:
	if _current.is_empty() or _closing:
		return
	_button.disabled = true
	var summary: Dictionary = _mail.claim(_current)
	_current = ""
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		if not summary.is_empty():
			_show_rewards(summary)
		elif not _mail.pending().is_empty():
			_timer.start())


func _show_rewards(summary: Dictionary) -> void:
	_pick_after = _pick_after or summary.has("choice")
	if _popup == null:
		_popup = RewardPopup.new()
		_popup.hud = _hud
		_popup.closed.connect(func() -> void:
			if _pick_after:
				_pick_after = false
				_hud.router.open(&"legendary_pick")
			elif not _mail.pending().is_empty():
				_timer.start())
		_hud.get_node("Root").add_child(_popup)   # tam ekran; Root temayı taşır (CanvasLayer'ın altında plaka temasızdı)
	_popup.show_rewards(summary)


## Davet postasının üstü: tabela, avatar (davet eden / sayılan arkadaş), başlık, metin, basamak ilerlemesi.
func _referral_head(mail: Dictionary, ref_kind: String) -> void:
	var tier: int = int(mail.get("ref_tier", 0))
	_sign_title.text = Loc.t("DAVETLE GELDİN!") if ref_kind == "welcome" else Loc.t("%d. DAVET ÖDÜLÜ") % tier
	var person: Dictionary = _person(_referral_uid(mail, ref_kind))
	var avatar: AvatarView = AvatarView.new()
	avatar.custom_minimum_size = Vector2(84.0, 84.0)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), person)
	avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(person.get("frame", "")),
		SaveSafe.s(person.get("flag", "")))
	_box.add_child(avatar)
	var title: String = SaveSafe.s(mail.get("title", ""))
	if not title.is_empty():
		var head: Label = _label(&"HudPlateTitle", title)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
		_box.add_child(head)
	var text: String = SaveSafe.s(mail.get("text", ""))
	if not text.is_empty():
		var body: Label = _wrapped(text)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(body)
	if ref_kind == "tier":
		var dots: ReferralDots = ReferralDots.new()
		dots.name = "ReferralDots"
		dots.reached = tier
		dots.current = tier
		dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.add_child(dots)


## Davet postasının altı: hoş geldin → davet edenin de ödül alacağı; basamak → sıradaki basamağın ödülü.
func _referral_foot(mail: Dictionary, ref_kind: String) -> void:
	var line: String = ""
	if ref_kind == "welcome":
		var name: String = SaveSafe.s(_person(_referral_uid(mail, ref_kind)).get("name", ""))
		line = Loc.t("%d. seviyeye ulaştığında %s davet ödülünü kazanacak.") % [ReferralRewards.QUALIFY_LEVEL, name] \
			if not name.is_empty() else Loc.t("%d. seviyeye ulaştığında seni çağıran arkadaşın da ödül kazanacak.") \
			% ReferralRewards.QUALIFY_LEVEL
	else:
		var next: int = int(mail.get("ref_tier", 0)) + 1
		line = Loc.t("Sıradaki: %d. arkadaşta %s") % [next, ReferralRewards.label(next, get_tree())] \
			if next <= ReferralRewards.max_tier() else Loc.t("Davet merdivenini tamamladın! Teşekkürler usta.")
	var foot: Label = _wrapped(line)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.modulate.a = 0.8
	_box.add_child(foot)


func _referral_uid(mail: Dictionary, ref_kind: String) -> String:
	if ref_kind == "tier":
		return SaveSafe.s(mail.get("friend", ""))
	var referral: ReferralManager = get_tree().get_first_node_in_group("referral") as ReferralManager
	return referral.referrer if referral else ""


## Arkadaş listesindeki kişi (ad, avatar, çerçeve); yoksa boş (varsayılan kask).
func _person(uid: String) -> Dictionary:
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or uid.is_empty():
		return {}
	for entry: Dictionary in social.friends:
		if SaveSafe.s(entry.get("uid", "")) == uid:
			return entry
	return {}


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sign_title = _label(&"HudSignTitle", Loc.t("POSTA"))
	_sign_title.name = "SignTitle"
	_sign_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_sign_title)
	_column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override(&"separation", 6)
	info.add_child(_box)
	_column.add_child(info)

	_button = PlateButton.new()
	_button.name = "TakeButton"
	_button.theme_type_variation = &"HudPlate"
	_button.kind = HudIcon.Kind.CHECK
	_button.highlight = true
	_button.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_take)
	_column.add_child(_button)


func _reward_row(kind: HudIcon.Kind, text: String, color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 24.0
	icon.custom_minimum_size = Vector2(28.0, 28.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label: Label = _label(&"HudPlateTitle", text)
	label.add_theme_color_override(&"font_color", color)
	row.add_child(label)
	return row


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String) -> Label:
	var label: Label = _label(&"HudInkCaption", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	return label
