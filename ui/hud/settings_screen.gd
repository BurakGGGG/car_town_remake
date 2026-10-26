class_name SettingsScreen
extends Control
## AYARLAR — tam ekran: üstte başlık çubuğu (GERİ · AYARLAR · sürüm), solda kategori menüsü, sağda seçili
## kategorinin içeriği. Kategoriler: DİL · GRAFİK VE PERFORMANS (kalite, pil tasarrufu, HUD boyutu) · SES VE
## BİLDİRİMLER (müzik, efekt, BİLDİRİMLER: yarış / hediye / duyuru — PushService) · HESAP VE GİZLİLİK · DESTEK VE HAKKINDA.
## Uzun tek sütun yerine kategori başına bir sayfa: telefonda (480 birim) hiçbir sayfa kaydırma gerektirmez,
## gerekirse içerik tut-çek kaydırılır (TouchScroll).
##
## Ekran TAMAMEN KODLA kurulur (.tscn yok); sağ üstteki dişli tabela açar (HUD, UiRouter "settings", PLACE:
## arka plan opak, oyun HUD'u gizli; hesap panosu bunun üstünde açılır). Mantık burada değil: ayarlar
## GameSettings'te ("settings" grubu, cihaza özel dosya), hesap LoginScreen'de, reklam gizlilik formu
## AdService'te. Bu ekran yalnızca gösterir.

signal opened
signal closed
## Başka bir pano isteniyor (&"account"): ekranı UiRouter açar.
signal screen_requested(id: StringName)

enum Page { LANGUAGE, GRAPHICS, AUDIO, ACCOUNT, ABOUT }

## Sürüm adı: export_presets.cfg "version/name" ile AYNI tutulmalı (dışa aktarımda proje ayarına girmiyor). Yalnızca
## editörde / masaüstünde gösterilir; dışa aktarılmış pakette sürüm AppInfo'dan gelir (version_label).
const VERSION: String = "1.1.2"
## "Dil" sözcüğü her dilin kendi yazımıyla (çevrilmez: language_title'da İngilizcesiyle yan yana durur).
const LANGUAGE_WORDS: Dictionary = {"tr": "DİL", "es": "IDIOMA", "de": "SPRACHE", "fr": "LANGUE"}
const VOLUME_STEP: float = 0.1
const NAV_WIDTH: float = 250.0
const MARGIN: int = 18
## Zemin: asfaltın koyu tonları (yukarıdan aşağı koyulaşır), oyunun yol dili.
const BACKDROP: Color = Color("2B2D30")
const BACKDROP_TOP: Color = Color("383B40")
const BACKDROP_BOTTOM: Color = Color("1E2023")

var _settings: GameSettings
var _ads: AdService
var _page: int = Page.LANGUAGE
var _nav_group: ButtonGroup = ButtonGroup.new()
var _nav_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _page_title: Label
var _page_caption: Label
var _content_scroll: ScrollContainer
var _root: VBoxContainer
var _close: PlateButton
var _language_buttons: Dictionary = {}
var _language_group: ButtonGroup = ButtonGroup.new()
var _quality_buttons: Array[PlateButton] = []
var _quality_group: ButtonGroup = ButtonGroup.new()
var _quality_note: Label
var _saver: PlateButton
var _analytics_toggle: PlateButton
var _crash_toggle: PlateButton
var _hud_buttons: Array[PlateButton] = []
var _hud_group: ButtonGroup = ButtonGroup.new()
var _music_label: Label
var _sfx_label: Label
var _mute: PlateButton
## BİLDİRİMLER (telefon bildirimi): bu cihazda olmuyorsa (PC / eklenti yok) satır gizli. Açıkken altında üç tür
## (YARIŞ / HEDİYE / DUYURU); hesaba bağlı ikisi misafirde kilitli.
var _push: PushService
var _push_row: HBoxContainer
var _push_rule: ColorRect
var _push_toggle: PlateButton
var _push_caption: Label
var _push_kinds: Dictionary = {}   # PushService türü → AÇIK / KAPALI düğmesi
var _privacy_options: PlateButton
var _privacy_row: Control
var _personal_ads: PlateButton
var _personal_ads_row: Control
var _closing: bool = false


func _ready() -> void:
	name = "SettingsScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect.call_deferred()


func open() -> void:
	_refresh()
	if visible:
		return
	PlateAnim.pop_in(self, _root)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _root, func() -> void:
		hide()
		_closing = false
		closed.emit())


func _connect() -> void:
	_settings = get_tree().get_first_node_in_group("settings") as GameSettings
	_ads = get_tree().get_first_node_in_group("ads") as AdService
	_push = get_tree().get_first_node_in_group("push") as PushService
	if _settings:
		_settings.settings_changed.connect(_refresh)
	if _push:
		_push.changed.connect(_refresh)
	_refresh()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var shade: TextureRect = TextureRect.new()
	shade.name = "Shade"
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BACKDROP_TOP)
	gradient.set_color(1, BACKDROP_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 128
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	add_child(_LaneLines.new())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override(&"separation", 12)
	margin.add_child(_root)

	_build_header()
	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 14)
	_root.add_child(body)
	_build_nav(body)
	_build_content(body)
	_build_language()
	_build_graphics()
	_build_audio()
	_build_account()
	_build_about()
	_show_page(Page.LANGUAGE)


## Başlık çubuğu: solda GERİ, ortada AYARLAR tabelası, sağda sürüm (iki yan eşit genişlikte: tabela ortada kalır).
func _build_header() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(header)
	_close = _button("‹  " + Loc.t("GERİ"), &"HudPlateSmall")
	_close.custom_minimum_size = Vector2(NAV_WIDTH, 0.0)
	_close.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	header.add_child(_close)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(center)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	var title: Label = _label(&"HudSignTitle", Loc.t("AYARLAR"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	center.add_child(sign)
	var version: Label = _label(&"HudOutlined", "AUTO YARD  ·  v%s" % version_label())
	version.custom_minimum_size = Vector2(NAV_WIDTH, 0.0)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(version)


## Sol menü: kategori plakaları; seçili olan amber.
func _build_nav(body: HBoxContainer) -> void:
	var nav: VBoxContainer = VBoxContainer.new()
	nav.custom_minimum_size = Vector2(NAV_WIDTH, 0.0)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.add_theme_constant_override(&"separation", 8)
	body.add_child(nav)
	var entries: Array = [
		[Page.LANGUAGE, language_title()],
		[Page.GRAPHICS, Loc.t("GRAFİK VE PERFORMANS")],
		[Page.AUDIO, Loc.t("SES VE BİLDİRİMLER")],
		[Page.ACCOUNT, Loc.t("HESAP VE GİZLİLİK")],
		[Page.ABOUT, Loc.t("DESTEK VE HAKKINDA")],
	]
	for entry: Array in entries:
		var page: int = entry[0]
		var button: PlateButton = _button(String(entry[1]), &"HudPlateSmall")
		button.custom_minimum_size = Vector2(NAV_WIDTH, 52.0)
		button.toggle_mode = true
		button.button_group = _nav_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if page == Page.LANGUAGE:
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # İngilizcesiyle birlikte: her oyuncu bulur
		button.pressed.connect(func() -> void: _show_page(page))
		nav.add_child(button)
		_nav_buttons[page] = button


## Sağ: içerik plakası (sayfa başlığı + açıklama + kaydırılabilir sayfa).
func _build_content(body: HBoxContainer) -> void:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "ContentPanel"
	panel.theme_type_variation = &"HudCarPlate"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	_page_title = _label(&"HudSignTitle", "")
	box.add_child(_page_title)
	_page_caption = _caption("")
	box.add_child(_page_caption)
	box.add_child(_rule())
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "ContentScroll"
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_content_scroll)
	TouchScroll.attach(_content_scroll)
	var pages: VBoxContainer = VBoxContainer.new()
	pages.name = "Pages"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_scroll.add_child(pages)


func _new_page(page: int) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 10)
	_content_scroll.get_node("Pages").add_child(box)
	_pages[page] = box
	return box


func _show_page(page: int) -> void:
	_page = page
	for key: int in _pages:
		(_pages[key] as Control).visible = key == page
	# ButtonGroup set_pressed_no_signal ile ötekileri bırakmıyor: hepsi tek tek yazılır
	for key: int in _nav_buttons:
		(_nav_buttons[key] as PlateButton).set_pressed_no_signal(key == page)
		(_nav_buttons[key] as PlateButton).highlight = key == page
	match page:
		Page.LANGUAGE:
			_page_title.text = language_title()
			_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_page_caption.text = Loc.t("Dil değişince oyun yeni dille yeniden açılır; ilerlemen korunur.")
		Page.GRAPHICS:
			_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
			_page_title.text = Loc.t("GRAFİK VE PERFORMANS")
			_page_caption.text = Loc.t("Telefon ısınıyor ya da takılıyorsa kaliteyi düşür.")
		Page.AUDIO:
			_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
			_page_title.text = Loc.t("SES VE BİLDİRİMLER")
			_page_caption.text = Loc.t("Müzik, efekt sesleri ve telefon bildirimleri.")
		Page.ACCOUNT:
			_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
			_page_title.text = Loc.t("HESAP VE GİZLİLİK")
			_page_caption.text = Loc.t("Oyun hesabın, reklam tercihlerin ve yasal metinler.")
		Page.ABOUT:
			_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
			_page_title.text = Loc.t("DESTEK VE HAKKINDA")
			_page_caption.text = Loc.t("Bir sorun mu var? Bize yaz.")
	_content_scroll.scroll_vertical = 0


## Dil sayfasının adı: geçerli dilde + İngilizcesi ("SPRACHE · LANGUAGE"). Beş dil tek plakaya sığmaz; anlamadığı bir
## dile geçen oyuncu da İngilizce "LANGUAGE"ı tanır. İngilizcede yalnızca "LANGUAGE".
static func language_title() -> String:
	var own: String = String(LANGUAGE_WORDS.get(Loc.current(), ""))
	return "LANGUAGE" if own.is_empty() else own + " · LANGUAGE"


# --- Sayfalar ------------------------------------------------------------------------

func _build_language() -> void:
	var box: VBoxContainer = _new_page(Page.LANGUAGE)
	for lang: String in Loc.LANGUAGES:
		var button: PlateButton = _button(String(Loc.NAMES[lang]), &"HudPlateSmall")
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.toggle_mode = true
		button.button_group = _language_group
		button.pressed.connect(func() -> void:
			if _settings and _settings.effective_language() != lang:
				_settings.set_language(lang))
		box.add_child(button)
		_language_buttons[lang] = button


func _build_graphics() -> void:
	var box: VBoxContainer = _new_page(Page.GRAPHICS)
	box.add_child(_label(&"HudPlateTitle", Loc.t("KALİTE")))
	var row: HBoxContainer = _row(box)
	for quality: int in GameSettings.Quality.values():
		var button: PlateButton = _button(Loc.t(GameSettings.QUALITY_NAMES[quality]))
		button.toggle_mode = true
		button.button_group = _quality_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _settings:
				_settings.set_quality(quality))
		row.add_child(button)
		_quality_buttons.append(button)
	_quality_note = _caption("")
	box.add_child(_quality_note)
	box.add_child(_rule())
	_saver = _toggle_row(box, Loc.t("PİL TASARRUFU"), Loc.t("Kare hızı 30'a düşer: pil daha uzun gider, telefon daha az ısınır."))
	_saver.pressed.connect(func() -> void:
		if _settings:
			_settings.set_battery_saver(_saver.button_pressed))
	# HUD BOYUTU: beş kademe (%80 … %120); oyun ekranındaki düğme / sayaç / plakalar, panolar değil
	box.add_child(_rule())
	box.add_child(_label(&"HudPlateTitle", Loc.t("HUD BOYUTU")))
	var sizes: HBoxContainer = _row(box)
	for level: int in GameSettings.HUD_SCALES.size():
		var button: PlateButton = _button(Loc.percent(str(roundi(GameSettings.HUD_SCALES[level] * 100.0))))
		button.toggle_mode = true
		button.button_group = _hud_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _settings:
				_settings.set_hud_size(level))
		sizes.add_child(button)
		_hud_buttons.append(button)
	box.add_child(_caption(Loc.t("Oyun ekranındaki düğmelerin, sayaçların ve plakaların boyutu.")))


func _build_audio() -> void:
	var box: VBoxContainer = _new_page(Page.AUDIO)
	_music_label = _volume_row(box, Loc.t("MÜZİK"), func(delta: float) -> void:
		if _settings:
			_settings.set_music_volume(_settings.music_volume + delta))
	_sfx_label = _volume_row(box, Loc.t("EFEKTLER"), func(delta: float) -> void:
		if _settings:
			_settings.set_sfx_volume(_settings.sfx_volume + delta))
	box.add_child(_rule())
	_mute = _toggle_row(box, Loc.t("TÜM SESLER KAPALI"), Loc.t("Müzik ve efektlerin hepsini susturur."))
	_mute.pressed.connect(func() -> void:
		if _settings:
			_settings.set_muted(_mute.button_pressed))
	_push_rule = _rule()
	box.add_child(_push_rule)
	_push_toggle = _toggle_row(box, Loc.t("BİLDİRİMLER"), " ")
	_push_toggle.name = "PushToggle"
	_push_row = _push_toggle.get_parent() as HBoxContainer
	_push_caption = _push_row.get_child(0).get_child(1) as Label   # _text_block: başlık, açıklama
	_push_toggle.pressed.connect(_on_push_toggled)
	for entry: Array in [[PushService.RACE, Loc.t("YARIŞ HABERLERİ"), "PushRace"], [PushService.GIFT, Loc.t("HEDİYELER"), "PushGift"],
			[PushService.NEWS, Loc.t("DUYURULAR"), "PushNews"]]:
		var kind: StringName = entry[0]
		var toggle: PlateButton = _toggle_row(box, entry[1], " ")
		toggle.name = entry[2]
		toggle.pressed.connect(func() -> void:
			if _push:
				await _push.set_pref(kind, toggle.button_pressed)
			_refresh())
		_push_kinds[kind] = toggle


func _build_account() -> void:
	var box: VBoxContainer = _new_page(Page.ACCOUNT)
	var account: PlateButton = _link_row(box, Loc.t("OYUN HESABI"), Loc.t("Giriş yap, çıkış yap ya da hesabını sil."), Loc.t("AÇ"))
	account.pressed.connect(func() -> void: screen_requested.emit(&"account"))
	_privacy_options = _link_row(box, Loc.t("REKLAM GİZLİLİK SEÇENEKLERİ"), Loc.t("Kişiselleştirilmiş reklam onayını değiştir."), Loc.t("AÇ"))
	_privacy_row = _privacy_options.get_parent()
	_privacy_options.pressed.connect(func() -> void:
		if _ads:
			_ads.show_privacy_options())
	# AppLovin: Google formu yok → kişiselleştirilmiş reklam AÇIK/KAPALI (AdPrivacy; AEA/BK/İsviçre'de varsayılan kapalı)
	_personal_ads = _toggle_row(box, Loc.t("KİŞİSELLEŞTİRİLMİŞ REKLAMLAR"), Loc.t("Kişiselleştirilmiş reklam onayını değiştir."))
	_personal_ads_row = _personal_ads.get_parent()
	_personal_ads.pressed.connect(func() -> void:
		if _ads:
			_ads.set_personalized_ads(_personal_ads.button_pressed))
	# Telemetry: Firebase Analytics / Crashlytics toplama anahtarları
	_analytics_toggle = _toggle_row(box, Loc.t("KULLANIM İSTATİSTİKLERİ"),
		Loc.t("Hangi ekranların ve özelliklerin ne kadar kullanıldığı sayılır. Oyunu geliştirmemize yardım eder."))
	_analytics_toggle.pressed.connect(func() -> void:
		if _settings:
			_settings.set_analytics_enabled(_analytics_toggle.button_pressed))
	_crash_toggle = _toggle_row(box, Loc.t("HATA RAPORLARI"),
		Loc.t("Oyun çökerse ya da bir hata olursa teknik ayrıntılar (cihaz modeli, hatanın yeri) bize gönderilir."))
	_crash_toggle.pressed.connect(func() -> void:
		if _settings:
			_settings.set_crash_reports_enabled(_crash_toggle.button_pressed))
	box.add_child(_rule())
	# Akış kabı: uzun dillerde (DE / FR) iki bağlantı yan yana sığmazsa alt alta iner, sayfayı genişletmez
	var links: HFlowContainer = HFlowContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.add_theme_constant_override(&"h_separation", 8)
	links.add_theme_constant_override(&"v_separation", 8)
	box.add_child(links)
	for entry: Array in [[Loc.t("GİZLİLİK POLİTİKASI"), Loc.site_url("privacy")], [Loc.t("KULLANIM ŞARTLARI"), Loc.site_url("terms")]]:
		var link: PlateButton = _button(String(entry[0]) + "  ↗")
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var url: String = entry[1]
		link.pressed.connect(func() -> void: OS.shell_open(url))
		links.add_child(link)


func _build_about() -> void:
	var box: VBoxContainer = _new_page(Page.ABOUT)
	var support: PlateButton = _link_row(box, Loc.t("DESTEK / İLETİŞİM"), Loc.t("Sorununu ya da önerini web sitemizden ilet."), "↗")
	support.pressed.connect(func() -> void: OS.shell_open(Loc.site_url("contact")))
	# EĞİTİM: Rıza Usta'nın dersleri baştan (ödüller ikinci kez verilmez). Ayarlar kapanır, ilk ders başlar.
	var tutorial: PlateButton = _link_row(box, Loc.t("NASIL OYNANIR?"), Loc.t("Rıza Usta'nın derslerini baştan izle: tamir, yarış, araçlar, dekorasyon."), Loc.t("BAŞLAT"))
	tutorial.pressed.connect(func() -> void:
		var director: TutorialDirector = get_tree().get_first_node_in_group("tutorial_director") as TutorialDirector
		if director == null:
			return
		var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
		if router:
			router.close_all()
		director.restart())
	if Telemetry.test_crash_available():
		_build_test_crash(box)
	box.add_child(_rule())
	var info: Label = _caption(Loc.t("AUTO YARD  ·  SÜRÜM %s\n%s") % [version_label(), Loc.SITE_HOST])
	box.add_child(info)


## Crashlytics kurulum düğmesi (yalnız Android hata ayıklama sürümü; oyuncu görmez, metinler çevrilmez). İki dokunuş:
## ilki "EMİN MİSİN?" der, 3 sn içinde ikincisi oyunu çökertir.
func _build_test_crash(box: VBoxContainer) -> void:
	var crash: PlateButton = _link_row(box, "TEST ÇÖKMESİ", "Crashlytics kurulumu için oyunu bilerek çökertir. Sonra oyunu yeniden aç.", "ÇÖKERT")
	crash.pressed.connect(func() -> void:
		if crash.text != "ÇÖKERT":
			Telemetry.test_crash()
			return
		crash.text = Loc.t("EMİN MİSİN?")
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(crash):
				crash.text = "ÇÖKERT"))


# --- Yapı taşları ---------------------------------------------------------------------

func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _caption(text: String) -> Label:
	var label: Label = _label(&"HudInkCaption", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(text: String, variation: StringName = &"HudPlateSmall") -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.text = text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	return button


func _row(parent: Container) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	parent.add_child(row)
	return row


## İnce ayırıcı çizgi (mürekkep, düşük opaklık).
func _rule() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(HudPalette.INK, 0.14)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Solda başlık + açıklama, sağda tek düğme.
func _text_block(row: HBoxContainer, title: String, caption: String) -> void:
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	texts.add_child(_label(&"HudPlateTitle", title))
	if caption != "":
		texts.add_child(_caption(caption))
	row.add_child(texts)


## Açık / kapalı satırı: düğme AÇIK iken amber.
func _toggle_row(parent: Container, title: String, caption: String) -> PlateButton:
	var row: HBoxContainer = _row(parent)
	_text_block(row, title, caption)
	var toggle: PlateButton = _button(Loc.tc("KAPALI", "ayar"))
	toggle.toggle_mode = true
	toggle.custom_minimum_size = Vector2(110.0, 0.0)
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.toggled.connect(func(on: bool) -> void: _paint_toggle(toggle, on))
	row.add_child(toggle)
	return toggle


func _paint_toggle(toggle: PlateButton, on: bool) -> void:
	toggle.text = Loc.tc("AÇIK", "ayar") if on else Loc.tc("KAPALI", "ayar")
	toggle.highlight = on


## Bağlantı / eylem satırı: düğme ekranı ya da web sayfasını açar.
func _link_row(parent: Container, title: String, caption: String, action: String) -> PlateButton:
	var row: HBoxContainer = _row(parent)
	_text_block(row, title, caption)
	var button: PlateButton = _button(action)
	button.custom_minimum_size = Vector2(110.0, 0.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	return button


## "MÜZİK   [−]  %80  [+]" — kaydırıcı yerine iki büyük düğme (parmakla rahat).
func _volume_row(parent: Container, title: String, change: Callable) -> Label:
	var row: HBoxContainer = _row(parent)
	var name_label: Label = _label(&"HudPlateTitle", title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var minus: PlateButton = _button("−")
	minus.custom_minimum_size = Vector2(64.0, 0.0)
	minus.pressed.connect(func() -> void: change.call(-VOLUME_STEP))
	row.add_child(minus)
	var value: Label = _label(&"HudPlateTitle", "")
	value.custom_minimum_size = Vector2(76.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	var plus: PlateButton = _button("+")
	plus.custom_minimum_size = Vector2(64.0, 0.0)
	plus.pressed.connect(func() -> void: change.call(VOLUME_STEP))
	row.add_child(plus)
	return value


# --- Durum -------------------------------------------------------------------------

func _refresh() -> void:
	if _settings == null or _music_label == null:
		return
	var current_language: String = _settings.effective_language()
	for lang: String in _language_buttons:
		var button: PlateButton = _language_buttons[lang]
		button.set_pressed_no_signal(lang == current_language)
		button.highlight = lang == current_language
	for quality: int in _quality_buttons.size():
		_quality_buttons[quality].set_pressed_no_signal(_settings.quality == quality)
		_quality_buttons[quality].highlight = _settings.quality == quality
	_quality_note.text = [
		Loc.t("3B çözünürlük %70: zayıf telefonlar için en akıcı seçenek."),
		Loc.t("Tam çözünürlük: çoğu telefon için önerilen."),
		Loc.t("Tam çözünürlük ve kenar yumuşatma: güçlü telefonlar için en net görüntü."),
	][_settings.quality]
	if not _settings.quality_chosen and OS.has_feature("mobile"):
		_quality_note.text += "  " + Loc.t("Telefonuna göre otomatik seçildi.")
	_saver.set_pressed_no_signal(_settings.battery_saver)
	_paint_toggle(_saver, _settings.battery_saver)
	_analytics_toggle.set_pressed_no_signal(_settings.analytics_enabled)
	_paint_toggle(_analytics_toggle, _settings.analytics_enabled)
	_crash_toggle.set_pressed_no_signal(_settings.crash_reports_enabled)
	_paint_toggle(_crash_toggle, _settings.crash_reports_enabled)
	for level: int in _hud_buttons.size():
		_hud_buttons[level].set_pressed_no_signal(_settings.hud_size == level)
		_hud_buttons[level].highlight = _settings.hud_size == level
	_music_label.text = Loc.percent(str(roundi(_settings.music_volume * 100.0)))
	_sfx_label.text = Loc.percent(str(roundi(_settings.sfx_volume * 100.0)))
	_mute.set_pressed_no_signal(_settings.muted)
	_paint_toggle(_mute, _settings.muted)
	_refresh_push()
	# Google: onay istenen bölgelerde giriş noktası ZORUNLU; gerekmiyorsa satır gösterilmez
	var required: bool = _ads != null and _ads.privacy_options_required()
	_privacy_options.visible = required
	_privacy_row.visible = required
	var toggle: bool = _ads != null and _ads.personalization_toggle()
	_personal_ads_row.visible = toggle
	if toggle:
		_personal_ads.set_pressed_no_signal(_ads.personalized_ads())
		_paint_toggle(_personal_ads, _ads.personalized_ads())


## BİLDİRİMLER satırı: açık / kapalı, son başarısız denemenin nedeni; açıkken türler (misafirde hesaba bağlı ikisi kilitli).
func _refresh_push() -> void:
	var reason: String = _push.unavailable_reason() if _push else "platform"
	_push_row.visible = reason != "platform"
	_push_rule.visible = _push_row.visible
	var on: bool = _push_row.visible and _push.is_enabled()
	for kind: StringName in _push_kinds:
		(_push_kinds[kind] as PlateButton).get_parent().visible = on
	if not _push_row.visible:
		return
	_push_toggle.set_pressed_no_signal(on)
	_paint_toggle(_push_toggle, on)
	_push_toggle.disabled = _push.is_busy()
	if not on and not _push.last_failure.is_empty():
		_push_caption.text = _push.last_failure
	else:
		_push_caption.text = Loc.t("Hediye gelince, bir arkadaşın seni yarışta yenince ve yeni etkinliklerde telefonuna haber gelir.")
	var account: bool = _push.has_account()
	var captions: Dictionary = {
		PushService.RACE: Loc.t("Bir arkadaşın seni yarışta yenince."),
		PushService.GIFT: Loc.t("Postana hediye gelince."),
		PushService.NEWS: Loc.t("Etkinlikler ve yeni sürümler."),
	}
	for kind: StringName in _push_kinds:
		var toggle: PlateButton = _push_kinds[kind]
		var needs_account: bool = kind != PushService.NEWS and not account
		var kind_on: bool = _push.pref(kind) and not needs_account
		toggle.set_pressed_no_signal(kind_on)
		_paint_toggle(toggle, kind_on)
		toggle.disabled = needs_account or _push.is_busy()
		var caption: Label = toggle.get_parent().get_child(0).get_child(1) as Label
		caption.text = Loc.t("Hesabınla giriş yapınca açılır.") if needs_account else captions[kind]


## Açmak telefonun bildirim iznini ister (Android 13+); sonuç PushService.changed ile satıra yansır.
func _on_push_toggled() -> void:
	if _push == null or _push.is_busy():
		return
	if _push.is_enabled():
		await _push.disable()
	else:
		await _push.enable()
	_refresh()


## Gösterilen sürüm: pakette "1.0.10 (11)" — sürüm kodu, pakete gömülen bilgiden (AppInfo); zorunlu güncelleme bu koda
## bakar, telefonda buradan doğrulanır. Editörde VERSION.
static func version_label() -> String:
	if AppInfo.is_dev_build():
		return VERSION
	return "%s (%d)" % [AppInfo.version_name(), AppInfo.version_code()]


## Zemindeki soluk şerit çizgileri (yol dili): altta kesikli amber çizgi.
class _LaneLines extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, 4.0), HudPalette.LANE_PAINT)
		var y: float = size.y - 10.0
		var x: float = 0.0
		while x < size.x:
			draw_rect(Rect2(x, y, 34.0, 4.0), Color(HudPalette.LANE_PAINT, 0.22))
			x += 58.0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
