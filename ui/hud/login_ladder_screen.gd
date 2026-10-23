class_name LoginLadderScreen
extends Control
## GÜNLÜK GİRİŞ MERDİVENİ — tam ekran pano (UiRouter MODAL "login_ladder"; kurallar LoginLadder / GemRewards, tasarım
## docs/GIRIS_MERDIVENI.md). Günlük giriş ekranlarının yaygın desenleri (araştırma, 2026-10-23): bütün takvim baştan
## görünür ve ödüller büyüyerek gider; bugünün basamağı parlar, AL düğmesi nabız atar; alınan günler işaretli;
## 7. / 14. / 21. gün kilometre taşı (hafta dekoru), 28. gün KAHRAMAN ödül (dönen 3B "N. AY" dekoru, "mağazada yok");
## kaçırma kuralı açıkça yazılı; aldıktan sonra yarının ödülü ve geri sayım; ×2 ödüllü reklam yalnızca oyuncu basarsa.
##
## Yerleşim: solda AŞAĞIDAN YUKARI çıkan 4 basamak (her hafta bir basamak: 6 gün kartı + hafta dekoru, her basamak bir
## öncekinden sağa kayar), sağda ay ödülü kartı ve BUGÜN alanı; üstte başlık, ay / seri hapları ve 28 hücreli ilerleme.
## Günün ilk girişinde oyun SAKİNLEŞİNCE kendiliğinden açılır (request_auto; LevelUpScreen'in kuralı + ilk ders bitmiş),
## sağ üstteki GÜNLÜK GİRİŞ tabelası ve GÖREVLER › GÜNLÜK'ten de açılır. Kodla kurulur (Hud).

signal closed

const INDENT: float = 34.0          # basamak başına sağa kayma
const TILE: Vector2 = Vector2(50.0, 54.0)
const MILESTONE: Vector2 = Vector2(78.0, 54.0)
const SIDE_WIDTH: float = 244.0
const CHECK_SEC: float = 0.4
const CALM_SEC: float = 0.8
const SPIN: float = 0.5

## Arayüzü kodla süren testler / QA (CT_NO_TUTORIAL=1) ekranı kendiliğinden açmaz: panolar onların üstüne çıkmasın.
var auto_open: bool = not TutorialDirector.disabled_by_env()

var _hud: Hud
var _gem: GemRewards
var _column: VBoxContainer
var _rays: _Rays
var _month_pill: Label
var _streak_pill: Label
var _progress: _Progress
var _rows: Array[Dictionary] = []   # hafta → {"label": Label, "tiles": Array[_Tile]}
var _hero_title: Label
var _hero_slot: Control
var _hero_name: Label
var _hero_caption: Label
var _today_caption: Label
var _today_icon: _Icon
var _today_amount: Label
var _claim: PlateButton
var _double: AdOfferButton
var _tomorrow: Label
var _reward_popup: RewardPopup
var _thumbs: DecorThumbs
var _stage: SubViewportContainer
var _pivot: Node3D
var _closing: bool = false
var _t: float = 0.0
var _auto_pending: bool = false
var _calm: float = 0.0
var _timer: Timer


func _init(hud: Hud) -> void:
	_hud = hud
	name = "LoginLadderScreen"


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_timer = Timer.new()
	_timer.wait_time = CHECK_SEC
	_timer.timeout.connect(_tick)
	add_child(_timer)
	set_process(false)


func open() -> void:
	_gem = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	_auto_pending = false
	_closing = false
	_refresh()
	_build_hero_stage()
	show()
	PlateAnim.pop_in(self, _column)
	_rays.start()
	set_process(true)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_rays.stop()
	if _reward_popup.visible:
		_reward_popup.close()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		set_process(false)
		_free_hero_stage()
		_closing = false
		closed.emit())


## GemRewards.ladder_ready: yeni giriş günü. Ekran oyun sakinleşince açılır (açılış akışları, ders, ödül pencereleri
## bitince).
func request_auto(_day: int = 0) -> void:
	if not auto_open:
		return
	_auto_pending = true
	_calm = 0.0
	_timer.start()


func _tick() -> void:
	if not _auto_pending or visible:
		_timer.stop()
		return
	var gem: GemRewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	if gem == null or not gem.can_claim():
		_auto_pending = false
		return
	if not _is_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm >= CALM_SEC:
		_auto_pending = false
		_timer.stop()
		_hud.router.open(&"login_ladder")


## LevelUpScreen'in sakinlik kuralı + yeni oyuncunun ilk dersi bitmiş olmalı (hoş geldin akışının ortasına çıkmasın) +
## bekleyen SEVİYE ATLADIN önce gösterilir.
func _is_calm() -> bool:
	var tutorial: TutorialDirector = _hud.tutorial
	if not _hud.visible or not _hud.router.top().is_empty() or (tutorial and tutorial.is_running()):
		return false
	var lessons: TutorialManager = get_tree().get_first_node_in_group("tutorial") as TutorialManager
	if lessons and not lessons.is_done(TutorialManager.BASICS):
		return false
	if (_hud.crate_panel and _hud.crate_panel.visible) or (_hud.restoration_result and _hud.restoration_result.visible):
		return false
	if _hud.level_up_screen and _hud.level_up_screen.is_pending():
		return false
	for child: Node in get_parent().get_children():
		if (child is RewardPopup or child is MailNotice) and (child as Control).visible:
			return false
	return get_tree().root.get_node_or_null("LoadingScreen") == null


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_pivot):
		_pivot.rotation.y = fmod(_pivot.rotation.y + delta * SPIN, TAU)
	var glow: float = 0.5 + 0.5 * sin(_t * 4.0)
	for row: Dictionary in _rows:
		for tile: _Tile in row["tiles"]:
			if tile.state == _Tile.TODAY:
				tile.glow = glow
	if _claim.visible:
		var pulse: float = 1.0 + 0.05 * maxf(sin(_t * 5.0), 0.0)
		_claim.pivot_offset = _claim.size * 0.5
		_claim.scale = Vector2(pulse, pulse)
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_update_tomorrow()


# --- Durum -------------------------------------------------------------------------------

func _refresh() -> void:
	if _gem == null:
		return
	var today: int = _gem.ladder_day()
	var claimable: bool = _gem.can_claim()
	var month: int = _gem.ladder_month()
	_month_pill.text = Loc.t("%d. AY") % month
	_streak_pill.text = Loc.t("SERİ %d GÜN") % maxi(_gem.streak(), 1)
	_progress.day = today
	_progress.done = today - (1 if claimable else 0)
	_progress.queue_redraw()
	for week: int in LoginLadder.WEEKS:
		var row: Dictionary = _rows[week]
		var decor: StringName = LoginLadder.decor_for(month, week + 1)
		var title: String = Loc.t("%d. HAFTA") % (week + 1)
		if week + 1 < LoginLadder.WEEKS and decor != &"":
			title += "  ·  " + Loc.t(String(GarageDecor.get_item(decor).get("title", "")))
		(row["label"] as Label).text = title
		var current: bool = (today - 1) / LoginLadder.WEEK == week
		(row["label"] as Label).add_theme_color_override(&"font_color", HudPalette.PLATE_SELECTED if current \
			else HudPalette.TEXT_LIGHT)
		for i: int in LoginLadder.WEEK:
			var day: int = week * LoginLadder.WEEK + i + 1
			var tile: _Tile = row["tiles"][i]
			tile.reward = _gem.ladder_reward(day)
			if day < today or (day == today and not claimable):
				tile.state = _Tile.CLAIMED
			elif day == today:
				tile.state = _Tile.TODAY
			else:
				tile.state = _Tile.FUTURE
			tile.glow = 0.0
			tile.set_thumb(_thumb_for(tile.reward["decor"]))
			tile.queue_redraw()
	# Ay ödülü (28. gün)
	var hero: Dictionary = _gem.ladder_reward(LoginLadder.DAYS)
	_hero_title.text = Loc.t("28. GÜN · %d. AY ÖDÜLÜ") % month
	var hero_decor: StringName = hero["decor"]
	_hero_name.text = Loc.t(String(GarageDecor.get_item(hero_decor).get("title", ""))) if hero_decor != &"" \
		else Loc.t("+%d GEM") % int(hero["gems"])
	var left: int = LoginLadder.DAYS - today + (1 if claimable else 0)
	_hero_caption.text = Loc.t("MAĞAZADA YOK") + "  ·  " + (Loc.t("%d GÜN KALDI") % left if left > 0 else Loc.t("KAZANDIN!"))
	# Bugün
	var now: Dictionary = _gem.ladder_reward(today)
	_today_caption.text = (Loc.t("BUGÜN · %d. GÜN") if claimable else Loc.t("ALINDI · %d. GÜN")) % today
	_set_reward_row(_today_icon, _today_amount, now)
	_claim.visible = claimable
	_claim.scale = Vector2.ONE
	var extra: Dictionary = _gem.ladder_double()
	_double.reward_text = _amount_text(extra) if not extra.is_empty() else ""
	_double.refresh()
	_tomorrow.visible = not claimable
	_update_tomorrow()


func _update_tomorrow() -> void:
	if _gem == null or not _tomorrow.visible:
		return
	var next_day: int = _gem.ladder_day() % LoginLadder.DAYS + 1
	var next: Dictionary = _gem.ladder_reward(next_day, _gem.ladder_month() + (1 if next_day == 1 else 0))
	var now: int = _gem.now_unix()
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var left: int = maxi((_gem.day_key(now) + 1) * 86400 - bias - now, 0)
	_tomorrow.text = Loc.t("YARIN: %s  ·  %s") % [_amount_text(next) if next["decor"] == &"" else \
		Loc.t(String(GarageDecor.get_item(next["decor"]).get("title", ""))), "%02d:%02d:%02d" % [left / 3600, left / 60 % 60, left % 60]]


func _on_claim() -> void:
	if _gem == null:
		return
	var reward: Dictionary = _gem.claim_ladder()
	if reward.is_empty():
		return
	var summary: Dictionary = {"money": int(reward["money"]), "gems": int(reward["gems"]),
		"title": Loc.t("%d. GÜN ÖDÜLÜ") % int(reward["day"])}
	if reward["decor"] != &"":
		summary["title"] = Loc.t("AY ÖDÜLÜ!") if bool(reward["month_end"]) else Loc.t("HAFTA ÖDÜLÜ!")
		summary["items"] = [Loc.t(String(GarageDecor.get_item(reward["decor"]).get("title", ""))),
			Loc.t("GARAJI DÜZENLE'DE YERLEŞTİR")]
	_reward_popup.show_rewards(summary)
	_refresh()


func _on_double() -> void:
	if _gem == null:
		return
	var extra: Dictionary = _gem.double_ladder(false)
	if not extra.is_empty():
		_reward_popup.show_rewards({"money": int(extra["money"]), "gems": int(extra["gems"]),
			"title": Loc.t("GÜNLÜK GİRİŞ ×2")})
	_refresh()


func _set_reward_row(icon: _Icon, label: Label, reward: Dictionary) -> void:
	icon.kind = HudIcon.Kind.COIN if int(reward["money"]) > 0 else HudIcon.Kind.GEM
	icon.texture = null
	label.text = _amount_text(reward)
	if reward["decor"] != &"":
		icon.texture = _thumb_for(reward["decor"])
		label.text = "%s\n%s" % [Loc.t(String(GarageDecor.get_item(reward["decor"]).get("title", ""))), _amount_text(reward)]
	icon.queue_redraw()


static func _amount_text(reward: Dictionary) -> String:
	if int(reward.get("money", 0)) > 0:
		return "+%s ₺" % Hud.format_thousands(int(reward["money"]))
	return Loc.t("+%d GEM") % int(reward.get("gems", 0))


func _thumb_for(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var texture: Texture2D = DecorThumbs.fitted(id)
	if texture == null:
		_thumbs.request(id)
	return texture


func _on_thumb_ready(_id: StringName) -> void:
	if visible:
		_refresh()


# --- Kurulum -----------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_thumbs = DecorThumbs.new()
	_thumbs.ready_for.connect(_on_thumb_ready)
	add_child(_thumbs)
	_rays = _Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rays)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	# Başlık
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override(&"separation", 10)
	_column.add_child(header)
	var title: Label = _label(&"HudOutlinedLarge", Loc.t("GÜNLÜK GİRİŞ"))
	title.add_theme_font_size_override(&"font_size", 24)
	header.add_child(title)
	var month_pill: PanelContainer = _pill(HudPalette.PLATE_SELECTED)
	_month_pill = month_pill.get_child(0) as Label
	_month_pill.add_theme_color_override(&"font_color", HudPalette.INK)
	header.add_child(month_pill)
	var streak_pill: PanelContainer = _pill(Color(0.08, 0.09, 0.1, 0.85))
	_streak_pill = streak_pill.get_child(0) as Label
	_streak_pill.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	header.add_child(streak_pill)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var rule: HBoxContainer = HBoxContainer.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.add_theme_constant_override(&"separation", 12)
	_column.add_child(rule)
	var rule_text: Label = _label(&"HudOutlined", Loc.t("Her gün bir basamak çık. Bir gün kaçırırsan merdiven 1. güne döner!"))
	rule_text.add_theme_font_size_override(&"font_size", 13)
	rule.add_child(rule_text)
	_progress = _Progress.new()
	_progress.custom_minimum_size = Vector2(0.0, 14.0)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.add_child(_progress)

	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 16)
	_column.add_child(body)
	body.add_child(_build_stairs())
	body.add_child(_build_side())

	_reward_popup = RewardPopup.new()   # son çocuk: panonun üstünde açılır
	_reward_popup.hud = _hud
	add_child(_reward_popup)


## Dört basamak: üstte 4. hafta (en sağda), altta 1. hafta (en solda) — yukarı çıkan merdiven.
func _build_stairs() -> Control:
	var stairs: VBoxContainer = VBoxContainer.new()
	stairs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stairs.add_theme_constant_override(&"separation", 4)
	_rows.resize(LoginLadder.WEEKS)
	for step: int in LoginLadder.WEEKS:
		var week: int = LoginLadder.WEEKS - 1 - step
		var holder: MarginContainer = MarginContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_theme_constant_override(&"margin_left", int(INDENT * week))
		holder.add_theme_constant_override(&"margin_right", int(INDENT * (LoginLadder.WEEKS - 1 - week)))
		stairs.add_child(holder)
		var block: VBoxContainer = VBoxContainer.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_theme_constant_override(&"separation", 2)
		holder.add_child(block)
		var label: Label = _label(&"HudOutlined", "")
		label.add_theme_font_size_override(&"font_size", 11)
		block.add_child(label)
		var tread: _Tread = _Tread.new()
		tread.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(tread)
		var tiles: Array[_Tile] = []
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 5)
		tread.add_child(row)
		for i: int in LoginLadder.WEEK:
			var tile: _Tile = _Tile.new()
			tile.milestone = i == LoginLadder.WEEK - 1
			tile.month_end = tile.milestone and week == LoginLadder.WEEKS - 1
			tile.custom_minimum_size = MILESTONE if tile.milestone else TILE
			row.add_child(tile)
			tiles.append(tile)
		_rows[week] = {"label": label, "tiles": tiles}
	return stairs


func _build_side() -> Control:
	var side: VBoxContainer = VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0.0)
	side.add_theme_constant_override(&"separation", 10)
	# Ay ödülü
	var hero: PlatePanel = PlatePanel.new()
	hero.theme_type_variation = &"HudCarPlate"
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(hero)
	var hero_box: VBoxContainer = VBoxContainer.new()
	hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_box.add_theme_constant_override(&"separation", 2)
	hero.add_child(hero_box)
	_hero_title = _label(&"HudInkCaption", "")
	_hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_title.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	hero_box.add_child(_hero_title)
	_hero_slot = Control.new()
	_hero_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_slot.custom_minimum_size = Vector2(0.0, 112.0)
	hero_box.add_child(_hero_slot)
	_rays.target = _hero_slot
	_hero_name = _label(&"HudInkValue", "")
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_name)
	_hero_caption = _label(&"HudInkCaption", "")
	_hero_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_caption)
	# Bugün
	var today: PlatePanel = PlatePanel.new()
	today.theme_type_variation = &"HudCarPlate"
	today.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(today)
	var today_box: VBoxContainer = VBoxContainer.new()
	today_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	today_box.add_theme_constant_override(&"separation", 6)
	today.add_child(today_box)
	_today_caption = _label(&"HudInkCaption", "")
	_today_caption.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	today_box.add_child(_today_caption)
	var reward_row: HBoxContainer = HBoxContainer.new()
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_row.add_theme_constant_override(&"separation", 8)
	today_box.add_child(reward_row)
	_today_icon = _Icon.new()
	_today_icon.custom_minimum_size = Vector2(40.0, 40.0)
	reward_row.add_child(_today_icon)
	_today_amount = _label(&"HudInkValue", "")
	_today_amount.add_theme_font_size_override(&"font_size", 18)
	_today_amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(_today_amount)
	_claim = PlateButton.new()
	_claim.theme_type_variation = &"HudPlateSmall"
	_claim.text = Loc.t("AL")
	_claim.highlight = true
	_claim.focus_mode = Control.FOCUS_NONE
	_claim.pressed.connect(_on_claim)
	today_box.add_child(_claim)
	_double = AdOfferButton.new(AdPolicy.DAILY_DOUBLE)
	_double.condition = func() -> bool: return visible and _gem != null and not _gem.ladder_double().is_empty()
	_double.rewarded.connect(_on_double)
	today_box.add_child(_double)
	_tomorrow = _label(&"HudInkCaption", "")
	_tomorrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	today_box.add_child(_tomorrow)
	return side


## Ay ödülünün dönen 3B önizlemesi (kendi dünyası; açılışta kurulur, kapanınca silinir). Ayın dekoru yoksa elmas.
func _build_hero_stage() -> void:
	_free_hero_stage()
	if _gem == null:
		return
	var decor: StringName = _gem.ladder_reward(LoginLadder.DAYS)["decor"]
	if decor == &"":
		var icon: _Icon = _Icon.new()
		icon.kind = HudIcon.Kind.GEM
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_hero_slot.add_child(icon)
		return
	_stage = SubViewportContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.stretch = true
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_slot.add_child(_stage)
	var viewport: SubViewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = GameSettings.subviewport_msaa(Viewport.MSAA_4X)
	_stage.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var env: Environment = Environment.new()   # ortamsız SubViewport ışığı dünyaya sızdırıyordu (Compatibility)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("D8CFBD")
	env.ambient_light_energy = 0.6
	camera.environment = env
	viewport.add_child(camera)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
	light.light_color = Color("FFF3E0")
	light.light_energy = 1.1
	viewport.add_child(light)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	var body: Node3D = DecorBuilder.build_placeable(decor)
	if body:
		_pivot.add_child(body)
	var size: Vector3 = DecorBuilder.local_size(decor)
	var extent: float = maxf((size.x + size.z) * 0.72, size.y * 1.15)
	camera.size = maxf(extent, 0.05) * 1.1
	var center: Vector3 = Vector3(0.0, size.y * 0.5, 0.0)
	camera.position = center + DecorThumbs.VIEW_DIR * 8.0
	camera.basis = Basis.looking_at(-DecorThumbs.VIEW_DIR, Vector3.UP)


func _free_hero_stage() -> void:
	for child: Node in _hero_slot.get_children():
		child.queue_free()
	_stage = null
	_pivot = null


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _pill(fill: Color) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(12)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override(&"panel", box)
	var label: Label = _label(&"HudInkCaption", "")
	pill.add_child(label)
	return pill


# --- Parçalar ----------------------------------------------------------------------------

## Basamak kartı: gün numarası, ödül ikonu (elmas / para / dekor küçük resmi) ve miktar. Durum: alındı (soluk + yeşil
## onay), bugün (amber + nabız atan hale), ileride (krem). Hafta sonu kartı koyu zemin + amber kenar (kilometre taşı);
## 28. gün koyu zemin + kalın altın çerçeve (bugünün amber'iyle karışmasın).
class _Tile extends Control:
	enum { FUTURE, TODAY, CLAIMED }
	var state: int = FUTURE
	var reward: Dictionary = {}
	var milestone: bool = false
	var month_end: bool = false
	var glow: float = 0.0:
		set(value):
			glow = value
			queue_redraw()
	var _thumb: TextureRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb = TextureRect.new()
		_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_thumb.offset_top = 13.0
		_thumb.offset_bottom = -3.0
		_thumb.offset_left = 4.0
		_thumb.offset_right = -4.0
		add_child(_thumb)

	func set_thumb(texture: Texture2D) -> void:
		if _thumb:
			_thumb.texture = texture
			_thumb.modulate = Color(1, 1, 1, 0.55) if state == CLAIMED else Color.WHITE

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		var font: Font = get_theme_default_font()
		var dark: bool = milestone
		var fill: Color = HudPalette.PLATE
		var ink: Color = HudPalette.INK
		if dark:
			fill = Color("2F3236")
			ink = HudPalette.TEXT_LIGHT
		if state == CLAIMED:
			fill = fill.darkened(0.22)
			ink = Color(ink, 0.6)
		if state == TODAY:
			draw_rect(rect.grow(3.0 + 3.0 * glow), Color(HudPalette.PLATE_SELECTED, 0.35 + 0.35 * glow), true)
			fill = HudPalette.PLATE_SELECTED
			ink = HudPalette.INK
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(6)
		box.border_width_bottom = 3
		box.border_color = fill.darkened(0.3)
		if milestone:
			box.set_border_width_all(4 if month_end else 2)
			box.border_width_bottom = 5 if month_end else 3
			box.border_color = HudPalette.PLATE_SELECTED if state != TODAY else HudPalette.INK
		draw_style_box(box, rect)
		var day: int = int(reward.get("day", 0))
		draw_string(font, Vector2(5.0, 12.0), str(day), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10,
			HudPalette.PLATE_SELECTED if dark and state != TODAY else Color(ink, 0.75))
		if reward.get("decor", &"") == &"" or (_thumb and _thumb.texture == null):
			var kind: HudIcon.Kind = HudIcon.Kind.COIN if int(reward.get("money", 0)) > 0 else HudIcon.Kind.GEM
			if reward.get("decor", &"") != &"":
				kind = HudIcon.Kind.TROPHY if month_end else HudIcon.Kind.CHAIR
			var icon_color: Color = ink if kind in [HudIcon.Kind.TROPHY, HudIcon.Kind.CHAIR] else Color.WHITE
			HudIcon.draw_icon(self, kind, Vector2(size.x * 0.5, size.y * 0.47), 20.0, icon_color, fill)
			var text: String = _short(reward)
			var font_size: int = 11 if text.length() <= 5 else 9
			draw_string(font, Vector2(0.0, size.y - 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
		if state == CLAIMED:
			var c: Vector2 = Vector2(size.x - 9.0, 9.0)
			draw_circle(c, 8.0, Color("3E9B55"), true, -1.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-4.0, 0.0), c + Vector2(-1.0, 3.0), c + Vector2(4.0, -3.0)]),
				Color.WHITE, 2.0, true)

	static func _short(reward: Dictionary) -> String:
		var money: int = int(reward.get("money", 0))
		if money > 0:
			return Hud.format_thousands(money)
		return str(int(reward.get("gems", 0)))


## Basamağın altındaki koyu "basamak yüzü" (merdiven hissi): kartlar üstünde, altta kalın gölge.
class _Tread extends MarginContainer:
	func _ready() -> void:
		for side: StringName in [&"margin_left", &"margin_right", &"margin_top"]:
			add_theme_constant_override(side, 5)
		add_theme_constant_override(&"margin_bottom", 10)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(rect.position + Vector2(0.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.35), true)
		var top: StyleBoxFlat = StyleBoxFlat.new()
		top.bg_color = Color("8A7E66")
		top.set_corner_radius_all(6)
		top.border_width_bottom = 6
		top.border_color = Color("5C5442")
		draw_style_box(top, rect)


## 28 hücreli ilerleme: alınan günler amber, bugün parlak, hafta sınırlarında boşluk, kilometre taşları büyük.
class _Progress extends Control:
	var day: int = 1
	var done: int = 0

	func _draw() -> void:
		var gap: float = 2.0
		var week_gap: float = 6.0
		var cell: float = (size.x - gap * 24.0 - week_gap * 3.0) / 28.0
		var x: float = 0.0
		for d: int in range(1, LoginLadder.DAYS + 1):
			var tall: bool = d % LoginLadder.WEEK == 0
			var h: float = size.y if tall else size.y * 0.6
			var color: Color = Color(1, 1, 1, 0.18)
			if d <= done:
				color = HudPalette.PLATE_SELECTED
			elif d == day:
				color = Color(HudPalette.PLATE_SELECTED, 0.55)
			draw_rect(Rect2(x, (size.y - h) * 0.5, cell, h), color, true)
			x += cell + (week_gap if d % LoginLadder.WEEK == 0 else gap)


## Ödül ikonu: dekor küçük resmi varsa o, yoksa HudIcon (elmas / para).
class _Icon extends Control:
	var kind: HudIcon.Kind = HudIcon.Kind.GEM
	var texture: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if texture:
			var s: Vector2 = texture.get_size()
			var k: float = minf(size.x / s.x, size.y / s.y)
			draw_texture_rect(texture, Rect2(size * 0.5 - s * k * 0.5, s * k), false)
			return
		HudIcon.draw_icon(self, kind, size * 0.5, minf(size.x, size.y) * 0.8, Color.WHITE, HudPalette.PLATE)


## Ay ödülünün arkasında yavaşça dönen altın hüzmeler (hedefin ortasından).
class _Rays extends Control:
	const RAYS: int = 16
	const SPEED: float = 0.25

	var target: Control
	var _angle: float = 0.0

	func start() -> void:
		set_process(true)

	func stop() -> void:
		set_process(false)

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		_angle = fmod(_angle + delta * SPEED, TAU)
		queue_redraw()

	func _draw() -> void:
		if target == null:
			return
		var center: Vector2 = target.get_global_rect().get_center() - get_global_rect().position
		var radius: float = target.size.length() * 0.9
		var step: float = TAU / float(RAYS)
		var ray_color: Color = Color(HudPalette.COIN, 0.08)
		for i: int in RAYS:
			var a: float = _angle + step * float(i)
			draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a) * radius,
				center + Vector2.from_angle(a + step * 0.45) * radius]), ray_color)
