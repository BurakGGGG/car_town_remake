extends Control
## MOTOR SES LABORATUVARI (2026-11-02, kullanıcı: "bana bir ses yapıcı program yapsan ben yapsam daha iyi olur").
## Her aracın motor sesini burada tasarlarsın; oyun pişmiş bankayı (EngineBank) çalar. Laboratuvar oyunla AYNI sentezi
## (EngineSynth) ve AYNI oynatıcıyı (EngineVoice) kullanır: burada duyduğun, oyunda duyacağındır.
##
## Akış: soldan araç seç → sağdaki sürgülerle ayarla (her değişiklikte bütün devir katmanları iş parçacıklarında
## yeniden üretilir, ~0,2–0,5 sn) → ortada dinle (pedal / senaryolar / yanından geçiş) → KAYDET (ön ayar JSON) →
## PİŞİR (oyunun dosyası: res://vehicles/sound/banks/<id>.res). TÜMÜNÜ PİŞİR bütün araçları sırayla pişirir.
## Kısayollar: W basılı = gaz, Boşluk = vites, B = gaz patlat, M = marş, K = kontak kapat, Ctrl+Z / Ctrl+Y, Ctrl+S.
## Çalıştırma: tools/engine_lab.sh [-- <araç_id>] (ya da godot-4 --path . -s res://tools/engine_lab/engine_lab.gd).

const LabSim = preload("res://tools/engine_lab/lab_sim.gd")
const LabGauge = preload("res://tools/engine_lab/lab_gauge.gd")
const LabSpectrum = preload("res://tools/engine_lab/lab_spectrum.gd")

const BUS: StringName = &"EngineLab"
const REBUILD_DELAY: float = 0.12
const UNDO_GAP_MS: int = 700
const RECORD_DIR: String = "/home/burak/Projects/ct_shots/motor_sesleri/"
## Gruplar: yalnız içten yanmalıda / yalnız elektrikte görünenler.
const COMBUSTION_GROUPS: Array[String] = ["Ateşleme", "Manifold", "Egzoz", "Susturucu", "Emme", "Turbo", "Kompresör",
	"Mekanik", "Devir kesici", "Marş"]
const ELECTRIC_GROUPS: Array[String] = ["Elektrik"]
## Yanından geçiş: yol boyu (m), kamera yoldan uzaklığı (m).
const PASS_FROM: float = -75.0
const PASS_TO: float = 75.0
const PASS_SIDE: float = 7.0

var _ids: Array[StringName] = []
var _current: StringName = &""
var _preset: Dictionary = {}
var _saved: Dictionary = {}
var _bank: EngineBank
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _last_undo_ms: int = 0
var _last_undo_key: String = ""
var _slot_a: Dictionary = {}
var _playing_a: bool = false

# Arka plan üretimi (önizleme ya da pişirme)
var _task: int = -1
var _task_mode: String = ""
var _task_id: StringName = &""
var _task_preset: Dictionary = {}
var _task_jobs: Array = []
var _task_results: Array = []
var _task_started: int = 0
var _mutex: Mutex = Mutex.new()
var _rebuild_at: float = -1.0
var _bake_queue: Array[StringName] = []
var _bake_total: int = 0
var _clock: float = 0.0

# Ses
var _player: AudioStreamPlayer
var _voice: EngineVoice
var _player3d: AudioStreamPlayer3D
var _voice3d: EngineVoice
var _sim: RefCounted
var _key_pedal: bool = false
var _button_pedal: bool = false
var _recorder: AudioEffectRecord
var _record_button: Button
var _pass_index: int = -1
var _pass_x: float = 0.0

# Arayüz
var _syncing: bool = false
var _list: ItemList
var _search: LineEdit
var _title: Label
var _subtitle: Label
var _state_label: Label
var _progress: ProgressBar
var _info: Label
var _rows: Dictionary = {}
var _groups: Dictionary = {}
var _gauge: Control
var _spectrum: Control
var _mode_option: OptionButton
var _rpm_slider: HSlider
var _thr_slider: HSlider
var _auto_shift: CheckBox
var _template_option: OptionButton
var _ab_button: Button
var _volume: HSlider
var _confirm: ConfirmationDialog
var _pending_id: StringName = &""

# 3B önizleme
var _viewport: SubViewport
var _camera: Camera3D
var _car_pivot: Node3D
var _car: Node3D
var _orbit: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_setup_bus()
	EngineSynth.prepare()
	_sim = LabSim.new()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_build_ui()
	for entry: Dictionary in CarCatalog.all():
		_ids.append(StringName(entry["id"]))
	_fill_list()
	var first: StringName = &"tofas_sahin" if _ids.has(&"tofas_sahin") else _ids[0]
	var args: PackedStringArray = OS.get_cmdline_user_args()   # tools/engine_lab.sh -- <araç_id>
	if args.size() > 0 and _ids.has(StringName(args[0])):
		first = StringName(args[0])
	_load_car(first)
	_select_in_list(first)


func _make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 15
	return t


func _setup_bus() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, &"Master")
		var analyzer: AudioEffectSpectrumAnalyzer = AudioEffectSpectrumAnalyzer.new()
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(index, analyzer, 0)
		_recorder = AudioEffectRecord.new()
		AudioServer.add_bus_effect(index, _recorder, 1)


# --- Arayüz kurulumu ---------------------------------------------------------------------------------------------

func _build_ui() -> void:
	var bg: PanelContainer = PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("1B1E24")
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	bg.add_child(root)
	root.add_child(_build_top_bar())
	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	split.add_child(_build_car_list())
	var inner: HSplitContainer = HSplitContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(inner)
	inner.add_child(_build_center())
	inner.add_child(_build_params())
	var bottom: HBoxContainer = HBoxContainer.new()
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(260, 0)
	_progress.show_percentage = true
	_progress.visible = false
	bottom.add_child(_progress)
	_info = Label.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.clip_text = true
	_info.custom_minimum_size = Vector2(100, 0)
	_info.add_theme_color_override("font_color", Color("A8B0BE"))
	bottom.add_child(_info)
	root.add_child(bottom)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Bu aracın kaydedilmemiş değişiklikleri var. Kaydetmeden başka araca geçilsin mi?"
	_confirm.ok_button_text = "Geç (kaydetme)"
	_confirm.cancel_button_text = "Kal"
	_confirm.confirmed.connect(func() -> void: _load_car(_pending_id))
	_confirm.canceled.connect(func() -> void: _select_in_list(_current))
	add_child(_confirm)


func _build_top_bar() -> Control:
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var bar: HFlowContainer = HFlowContainer.new()   # dar ekranda düğmeler alt satıra iner
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.alignment = FlowContainer.ALIGNMENT_END
	var titles: VBoxContainer = VBoxContainer.new()
	titles.custom_minimum_size = Vector2(300, 0)
	titles.add_theme_constant_override("separation", 0)
	_title = Label.new()
	_title.clip_text = true
	_title.add_theme_font_size_override("font_size", 22)
	titles.add_child(_title)
	_subtitle = Label.new()
	_subtitle.clip_text = true
	_subtitle.add_theme_color_override("font_color", Color("A8B0BE"))
	titles.add_child(_subtitle)
	top.add_child(titles)
	top.add_child(bar)
	_state_label = Label.new()
	_state_label.add_theme_color_override("font_color", Color("F2C14E"))
	bar.add_child(_state_label)
	_template_option = OptionButton.new()
	_template_option.fit_to_longest_item = false
	_template_option.add_item("Şablondan başla…")
	for template_name: String in EnginePreset.TEMPLATES:
		_template_option.add_item(template_name)
	_template_option.tooltip_text = "Bir motor karakterinden yeniden başla (geri alınabilir). Araca özgü tohum korunur."
	_template_option.item_selected.connect(_on_template)
	bar.add_child(_template_option)
	bar.add_child(_button("Otomatik", "cars.json motor bilgisinden üretilen başlangıç ayarına dön (geri alınabilir).",
		_on_auto))
	bar.add_child(_button("Varyasyon", "Aynı ayarla başka bir 'kopya' motor: rastgele farkların tohumu değişir.",
		_on_variation))
	bar.add_child(_button("Geri al", "Ctrl+Z", _undo_step))
	bar.add_child(_button("Yinele", "Ctrl+Y", _redo_step))
	bar.add_child(VSeparator.new())
	bar.add_child(_button("A'ya al", "Şu anki sesi A yuvasına koy (başka araçla / eski ayarla kıyas için).", _on_take_a))
	_ab_button = _button("Dinlenen: B (şu an)", "A ile şu anki ses (B) arasında geçiş.", _on_toggle_ab)
	_ab_button.disabled = true
	bar.add_child(_ab_button)
	bar.add_child(VSeparator.new())
	_record_button = _button("● KAYIT", "Duyduğunu WAV'a kaydet (" + RECORD_DIR + ").", _on_record)
	bar.add_child(_record_button)
	bar.add_child(_button("Diskten geri yükle", "Kaydedilmiş (ya da otomatik) ayara dön.", _on_revert))
	bar.add_child(_button("Kaydı sil", "Bu aracın kayıtlı ön ayarını sil: araç otomatiğe döner.", _on_delete_custom))
	var save: Button = _button("KAYDET", "Ön ayarı res://vehicles/sound/presets/<id>.json olarak kaydet (Ctrl+S).", _on_save)
	save.add_theme_color_override("font_color", Color("8BC34A"))
	bar.add_child(save)
	var bake: Button = _button("PİŞİR", "Kaydet + oyunun ses dosyasını üret (res://vehicles/sound/banks/<id>.res).", _on_bake)
	bake.add_theme_color_override("font_color", Color("F2C14E"))
	bar.add_child(bake)
	bar.add_child(_button("TÜMÜNÜ PİŞİR", "Bütün araçların ses dosyalarını yeniden üret (kayıtlı ön ayar ya da otomatik).",
		_on_bake_all))
	return top


func _build_car_list() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	_search = LineEdit.new()
	_search.placeholder_text = "Araç ara (ad, motor, kimlik)…"
	_search.text_changed.connect(func(_t: String) -> void: _fill_list())
	box.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	box.add_child(_list)
	var legend: Label = Label.new()
	legend.text = "● elle ayarlı   ○ otomatik   ✓ pişmiş"
	legend.add_theme_color_override("font_color", Color("8A93A3"))
	box.add_child(legend)
	return box


func _build_center() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(440, 0)
	box.add_child(_build_viewport())
	_gauge = LabGauge.new()
	box.add_child(_gauge)
	_spectrum = LabSpectrum.new()
	var bus_index: int = AudioServer.get_bus_index(BUS)
	_spectrum.set("analyzer", AudioServer.get_bus_effect_instance(bus_index, 0))
	box.add_child(_spectrum)
	# Senaryolar
	var flow: HFlowContainer = HFlowContainer.new()
	flow.add_child(_button("MARŞ (M)", "Marşa bas: çevirme, yakalama, rölantiye oturma.", _on_start))
	flow.add_child(_button("KONTAK KAPAT (K)", "Motoru durdur.", _on_stop))
	flow.add_child(_button("GAZ PATLAT (B)", "Boşta kısa gaz: devir fırlar ve düşer (patlama / blow-off burada).",
		func() -> void: _play_script(LabSim.blip())))
	flow.add_child(_button("ÜÇ POMPA", "Boşta üç kez gaz.", func() -> void: _play_script(LabSim.triple_blip())))
	flow.add_child(_button("DEVİR KESİCİ", "Boşta tam gaz, kırmızı çizgide kesici.",
		func() -> void: _play_script(LabSim.limiter_run())))
	flow.add_child(_button("KALKIŞ + VİTES", "Tam gazla kalkış ve vites atma (drag yarışı gibi).",
		func() -> void: _play_script(LabSim.launch())))
	flow.add_child(_button("ŞEHİR SÜRÜŞÜ", "Sakin hızlanma, erken vites, seyir, gaz kesme (trafik gibi).",
		func() -> void: _play_script(LabSim.cruise())))
	flow.add_child(_button("YANINDAN GEÇİŞ", "3B: araç önünden iki kez geçer (sabit hız, sonra tam gaz). Doppler ve uzaklık.",
		_on_pass))
	var gas: Button = _button("GAZ (basılı tut)", "Fareyle basılı tut = gaz (klavyede W).", func() -> void: pass)
	gas.button_down.connect(func() -> void: _button_pedal = true)
	gas.button_up.connect(func() -> void: _button_pedal = false)
	flow.add_child(gas)
	box.add_child(flow)
	# Kip ve sürgüler
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_child(_label("Kip"))
	_mode_option = OptionButton.new()
	_mode_option.fit_to_longest_item = false
	_mode_option.clip_text = true
	_mode_option.custom_minimum_size = Vector2(150, 0)
	_mode_option.add_item("Boşta (gaz pompala)")
	_mode_option.add_item("Vitesli sürüş")
	_mode_option.add_item("Elle (devir + gaz sürgüsü)")
	_mode_option.item_selected.connect(_on_mode)
	grid.add_child(_mode_option)
	_auto_shift = CheckBox.new()
	_auto_shift.text = "Otomatik vites"
	_auto_shift.button_pressed = true
	_auto_shift.toggled.connect(func(on: bool) -> void: _sim.set("auto_shift", on))
	grid.add_child(_auto_shift)
	grid.add_child(Control.new())
	grid.add_child(_label("Devir (elle)"))
	_rpm_slider = HSlider.new()
	_rpm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rpm_slider.value_changed.connect(func(v: float) -> void:
		_sim.set("manual_rpm", v)
		if not _syncing:
			_set_mode(LabSim.Mode.MANUAL))
	grid.add_child(_rpm_slider)
	grid.add_child(_label("Gaz (elle)"))
	_thr_slider = HSlider.new()
	_thr_slider.max_value = 1.0
	_thr_slider.step = 0.01
	_thr_slider.custom_minimum_size = Vector2(140, 0)
	_thr_slider.value_changed.connect(func(v: float) -> void:
		_sim.set("manual_throttle", v)
		if not _syncing:
			_set_mode(LabSim.Mode.MANUAL))
	grid.add_child(_thr_slider)
	grid.add_child(_label("Ses düzeyi"))
	_volume = HSlider.new()
	_volume.min_value = -40.0
	_volume.max_value = 6.0
	_volume.value = -6.0
	_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), v))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), _volume.value)
	grid.add_child(_volume)
	box.add_child(grid)
	var hint: Label = _label("W basılı: gaz · Boşluk: vites · B: gaz patlat · M: marş · K: kontak · Ctrl+S: kaydet · " +
		"Ctrl+Z / Ctrl+Y: geri al / yinele")
	hint.add_theme_color_override("font_color", Color("8A93A3"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box


func _build_viewport() -> Control:
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(0, 250)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.audio_listener_enable_3d = true
	holder.add_child(_viewport)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2A3140")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("B8C4D8")
	env.ambient_light_energy = 0.55
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 1.1
	_viewport.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(260.0, 60.0)
	ground.mesh = plane
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color("3B4048")
	ground.material_override = ground_mat
	_viewport.add_child(ground)
	var road: MeshInstance3D = MeshInstance3D.new()
	var strip: PlaneMesh = PlaneMesh.new()
	strip.size = Vector2(260.0, 7.0)
	road.mesh = strip
	var road_mat: StandardMaterial3D = StandardMaterial3D.new()
	road_mat.albedo_color = Color("24272C")
	road.material_override = road_mat
	road.position.y = 0.005
	_viewport.add_child(road)
	for i: int in 26:
		var dash: MeshInstance3D = MeshInstance3D.new()
		var dash_mesh: PlaneMesh = PlaneMesh.new()
		dash_mesh.size = Vector2(3.0, 0.15)
		dash.mesh = dash_mesh
		var dash_mat: StandardMaterial3D = StandardMaterial3D.new()
		dash_mat.albedo_color = Color("D8D8D0")
		dash.material_override = dash_mat
		dash.position = Vector3(-125.0 + float(i) * 10.0, 0.01, 0.0)
		_viewport.add_child(dash)
	_car_pivot = Node3D.new()
	_viewport.add_child(_car_pivot)
	_player3d = AudioStreamPlayer3D.new()
	_player3d.bus = BUS
	_player3d.unit_size = 7.0
	_player3d.max_distance = 220.0
	_player3d.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_player3d.position = Vector3(0.0, 0.5, 0.0)
	_car_pivot.add_child(_player3d)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	_viewport.add_child(_camera)
	_camera.current = true
	return holder


func _build_params() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var grid: GridContainer = null
	var group_name: String = ""
	for row: Array in EnginePreset.PARAMS:
		if row[1] != group_name:
			group_name = row[1]
			var header: Button = Button.new()
			header.text = "▾  " + group_name.to_upper()
			header.alignment = HORIZONTAL_ALIGNMENT_LEFT
			header.flat = true
			header.add_theme_color_override("font_color", Color("F2C14E"))
			box.add_child(header)
			grid = GridContainer.new()
			grid.columns = 4
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(grid)
			var body: GridContainer = grid
			var title: String = group_name
			header.pressed.connect(func() -> void:
				body.visible = not body.visible
				header.text = ("▾  " if body.visible else "▸  ") + title.to_upper())
			_groups[group_name] = [header, grid]
		_add_param_row(grid, row)
	return scroll


func _add_param_row(grid: GridContainer, row: Array) -> void:
	var key: String = row[0]
	var tip: String = "%s\n\n%s" % [row[2], row[8]]
	var name_label: Label = _label(row[2])
	name_label.tooltip_text = tip
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	name_label.custom_minimum_size = Vector2(150, 0)
	grid.add_child(name_label)
	var reset: Button = Button.new()
	reset.text = "↺"
	reset.flat = true
	reset.tooltip_text = "Kaydedilmiş değere dön"
	reset.pressed.connect(func() -> void: _set_param(key, _saved.get(key, EnginePreset.defaults()[key]), true))
	if EnginePreset.CHOICES.has(key):
		var option: OptionButton = OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.fit_to_longest_item = false
		option.clip_text = true
		option.custom_minimum_size = Vector2(90, 0)
		option.tooltip_text = tip
		for choice: Array in EnginePreset.CHOICES[key]:
			option.add_item(String(choice[1]))
		option.item_selected.connect(func(index: int) -> void:
			if not _syncing:
				_set_param(key, EnginePreset.CHOICES[key][index][0], false))
		grid.add_child(option)
		grid.add_child(Control.new())
		grid.add_child(reset)
		_rows[key] = {"option": option}
		return
	var slider: HSlider = HSlider.new()
	slider.min_value = float(row[3])
	slider.max_value = float(row[4])
	slider.step = float(row[6])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(90, 0)
	slider.tooltip_text = tip
	var spin: SpinBox = SpinBox.new()
	spin.min_value = slider.min_value
	spin.max_value = slider.max_value
	spin.step = slider.step
	spin.suffix = String(row[7])
	spin.custom_minimum_size = Vector2(110, 0)
	spin.tooltip_text = tip
	slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		_syncing = true
		spin.value = v
		_syncing = false
		_set_param(key, v, false))
	spin.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		_syncing = true
		slider.value = v
		_syncing = false
		_set_param(key, v, false))
	grid.add_child(slider)
	grid.add_child(spin)
	grid.add_child(reset)
	_rows[key] = {"slider": slider, "spin": spin, "label": name_label}


func _button(text: String, tip: String, action: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(action)
	return b


func _label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	return l


# --- Araç listesi --------------------------------------------------------------------------------------------------

func _fill_list() -> void:
	var query: String = _search.text.strip_edges().to_lower() if _search else ""
	_list.clear()
	for id: StringName in _ids:
		var entry: Dictionary = CarCatalog.get_entry(id)
		var engine: String = String((entry.get("performance", {}) as Dictionary).get("engine", ""))
		var name_text: String = "%s %s" % [entry.get("brand", ""), entry.get("model", "")]
		var haystack: String = ("%s %s %s" % [name_text, engine, id]).to_lower()
		if query != "" and not haystack.contains(query):
			continue
		var mark: String = "● " if EnginePreset.has_custom(id) else "○ "
		var baked: String = "  ✓" if EngineBank.has_bank(id) else ""
		var index: int = _list.add_item("%s%s  ·  %s%s" % [mark, name_text, engine, baked])
		_list.set_item_metadata(index, id)
		_list.set_item_tooltip(index, "%s · %d · %s" % [id, int(entry.get("year", 0)), entry.get("category", "")])


func _select_in_list(id: StringName) -> void:
	for i: int in _list.item_count:
		if StringName(_list.get_item_metadata(i)) == id:
			_list.select(i)
			_list.ensure_current_is_visible()
			return
	_list.deselect_all()


func _on_list_selected(index: int) -> void:
	var id: StringName = StringName(_list.get_item_metadata(index))
	if id == _current:
		return
	if _is_dirty():
		_pending_id = id
		_confirm.popup_centered()
		return
	_load_car(id)


func _load_car(id: StringName) -> void:
	_current = id
	_preset = EnginePreset.for_vehicle(id)
	_saved = _preset.duplicate()
	_undo.clear()
	_redo.clear()
	_sync_ui()
	_load_model(id)
	_configure_sim()
	var entry: Dictionary = CarCatalog.get_entry(id)
	var engine: String = String((entry.get("performance", {}) as Dictionary).get("engine", ""))
	_title.text = "%s %s" % [entry.get("brand", ""), entry.get("model", "")]
	_subtitle.text = "%s  ·  %s  ·  %d  ·  %s" % [id, engine, int(entry.get("year", 0)), entry.get("category", "")]
	_schedule_rebuild(0.0)
	_refresh_state()
	_select_in_list(id)


func _configure_sim() -> void:
	var electric: bool = _preset["layout"] == "ev"
	_sim.call("configure", float(_preset["idle_rpm"]), float(_preset["redline_rpm"]), electric)
	_syncing = true
	_rpm_slider.min_value = 0.0 if electric else float(_preset["idle_rpm"])
	_rpm_slider.max_value = float(_preset["redline_rpm"])
	_rpm_slider.value = maxf(float(_preset["idle_rpm"]), _rpm_slider.min_value)
	_syncing = false


# --- Parametreler ----------------------------------------------------------------------------------------------

func _set_param(key: String, value: Variant, refresh_ui: bool) -> void:
	_push_undo(key)
	_preset[key] = value
	_preset = EnginePreset.sanitize(_preset)
	if refresh_ui or key == "layout":
		_sync_ui()
	if key in ["idle_rpm", "redline_rpm", "layout"]:
		_configure_sim()
	_schedule_rebuild(REBUILD_DELAY)
	_refresh_state()


func _sync_ui() -> void:
	_syncing = true
	for key: String in _rows:
		var row: Dictionary = _rows[key]
		if row.has("option"):
			var option: OptionButton = row["option"]
			var choices: Array = EnginePreset.CHOICES[key]
			for i: int in choices.size():
				if choices[i][0] == _preset[key]:
					option.select(i)
		else:
			(row["slider"] as HSlider).value = float(_preset[key])
			(row["spin"] as SpinBox).value = float(_preset[key])
			var changed: bool = not is_equal_approx(float(_preset[key]), float(_saved.get(key, _preset[key])))
			(row["label"] as Label).add_theme_color_override("font_color", Color("F2C14E") if changed else Color("E6E9EF"))
	var electric: bool = _preset["layout"] == "ev"
	for group_name: String in _groups:
		var hidden: bool = (electric and COMBUSTION_GROUPS.has(group_name)) or (not electric and ELECTRIC_GROUPS.has(group_name))
		for node: Control in _groups[group_name]:
			node.visible = not hidden
	_syncing = false


func _push_undo(key: String) -> void:
	var now: int = Time.get_ticks_msec()
	if key != _last_undo_key or now - _last_undo_ms > UNDO_GAP_MS:
		_undo.append(_preset.duplicate())
		if _undo.size() > 200:
			_undo.pop_front()
		_redo.clear()
	_last_undo_key = key
	_last_undo_ms = now


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(_preset.duplicate())
	_preset = _undo.pop_back()
	_last_undo_key = ""
	_after_bulk_change()


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(_preset.duplicate())
	_preset = _redo.pop_back()
	_last_undo_key = ""
	_after_bulk_change()


func _after_bulk_change() -> void:
	_sync_ui()
	_configure_sim()
	_schedule_rebuild(REBUILD_DELAY)
	_refresh_state()


func _on_template(index: int) -> void:
	if index <= 0:
		return
	var template_name: String = _template_option.get_item_text(index)
	_template_option.select(0)
	_push_undo("")
	_last_undo_key = ""
	var seed_value: int = _preset["seed"]
	_preset = EnginePreset.from_template(template_name)
	_preset["seed"] = seed_value
	_after_bulk_change()
	_info.text = "Şablon: " + template_name


func _on_auto() -> void:
	_push_undo("")
	_last_undo_key = ""
	_preset = EnginePreset.auto(_current)
	_after_bulk_change()
	_info.text = "Otomatik ayar (cars.json'dan)"


func _on_variation() -> void:
	_set_param("seed", randi() % 1000, true)


func _on_revert() -> void:
	_push_undo("")
	_last_undo_key = ""
	_preset = EnginePreset.for_vehicle(_current)
	_after_bulk_change()


func _on_delete_custom() -> void:
	EnginePreset.remove_custom(_current)
	_saved = EnginePreset.auto(_current)
	_preset = _saved.duplicate()
	_after_bulk_change()
	_fill_list()
	_select_in_list(_current)
	_info.text = "Kayıtlı ön ayar silindi: araç otomatik ayarda (pişmiş dosya değişmedi; PİŞİR ile güncelle)."


func _is_dirty() -> bool:
	for key: String in _preset:
		if str(_preset[key]) != str(_saved.get(key)):
			return true
	return false


func _refresh_state() -> void:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("elle ayarlı" if EnginePreset.has_custom(_current) else "otomatik")
	parts.append("pişmiş" if EngineBank.has_bank(_current) else "PİŞMEDİ")
	if _is_dirty():
		parts.append("KAYDEDİLMEDİ")
	_state_label.text = " · ".join(parts) + "   "


# --- Kaydet / pişir ------------------------------------------------------------------------------------------------

func _on_save() -> void:
	var err: Error = EnginePreset.save(_current, _preset)
	if err != OK:
		_info.text = "Kaydedilemedi: %s" % error_string(err)
		return
	_saved = _preset.duplicate()
	_sync_ui()
	_fill_list()
	_select_in_list(_current)
	_refresh_state()
	_info.text = "Kaydedildi: " + EnginePreset.preset_path(_current)


func _on_bake() -> void:
	if _is_dirty() or EnginePreset.has_custom(_current):
		_on_save()
	_queue_bake([_current])


func _on_bake_all() -> void:
	_queue_bake(_ids.duplicate())


func _queue_bake(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if not _bake_queue.has(id):
			_bake_queue.append(id)
	_bake_total = maxi(_bake_total, _bake_queue.size())
	_progress.visible = true
	_progress.value = 0.0


func _schedule_rebuild(delay: float) -> void:
	_rebuild_at = _clock + delay


func _start_task(mode: String, id: StringName, preset: Dictionary) -> void:
	_task_mode = mode
	_task_id = id
	_task_preset = EnginePreset.sanitize(preset)
	_task_jobs = EngineBank.jobs_for(_task_preset)
	_task_results = []
	_task_results.resize(_task_jobs.size())
	_task_started = Time.get_ticks_msec()
	_task = WorkerThreadPool.add_group_task(_run_job, _task_jobs.size(), -1, true, "Motor sesi")


## İş parçacığında: bir pişirme işi (katman / marş / patlama…).
func _run_job(index: int) -> void:
	var result: Variant = EngineBank.run_job(_task_preset, _task_jobs[index])
	_mutex.lock()
	_task_results[index] = result
	_mutex.unlock()


func _poll_task() -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_group_task_completed(_task):
			return
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
		_finish_task()
	if _rebuild_at >= 0.0 and _clock >= _rebuild_at:
		_rebuild_at = -1.0
		_start_task("preview", _current, _preset)
	elif not _bake_queue.is_empty():
		var id: StringName = _bake_queue.pop_front()
		_start_task("bake", id, EnginePreset.for_vehicle(id))   # diskteki (kayıtlı ya da otomatik) ayar


func _finish_task() -> void:
	var elapsed: int = Time.get_ticks_msec() - _task_started
	if _task_mode == "preview":
		if _task_id != _current:
			return
		_bank = EngineBank.assemble(_task_id, _task_preset, _task_jobs, _task_results, false)
		if not _playing_a:
			_apply_bank(_bank)
		_info.text = "Ses üretildi: %d katman × 2, %d ms" % [_bank.rpms.size(), elapsed]
		return
	var bank: EngineBank = EngineBank.assemble(_task_id, _task_preset, _task_jobs, _task_results, true)
	bank.custom = EnginePreset.has_custom(_task_id)
	var err: Error = bank.save_to_disk()
	var done: int = _bake_total - _bake_queue.size()
	_progress.value = 100.0 * float(done) / float(maxi(_bake_total, 1))
	_info.text = "Pişirildi (%d/%d): %s — %s" % [done, _bake_total, _task_id, "tamam" if err == OK else error_string(err)]
	if _bake_queue.is_empty():
		_progress.visible = false
		_bake_total = 0
		_fill_list()
		_select_in_list(_current)
		_refresh_state()
		_info.text += "   ·   Editörde dosya sistemi taranınca oyun yeni sesleri kullanır."


func _apply_bank(bank: EngineBank) -> void:
	if _voice == null:
		_voice = EngineVoice.new(_player, bank)
		_voice3d = EngineVoice.new(_player3d, bank)
	else:
		_voice.set_bank(bank)
		_voice3d.set_bank(bank)
	_gauge.set("layers", bank.rpms)
	_gauge.set("has_turbo", bank.whistle != null)


# --- A / B ----------------------------------------------------------------------------------------------------------

func _on_take_a() -> void:
	if _bank == null:
		return
	_slot_a = {"id": _current, "bank": _bank, "preset": _preset.duplicate()}
	_ab_button.disabled = false
	_info.text = "A yuvası: %s (şu anki ayar)" % _current


func _on_toggle_ab() -> void:
	if _slot_a.is_empty():
		return
	_playing_a = not _playing_a
	var bank: EngineBank = _slot_a["bank"] if _playing_a else _bank
	if bank:
		_apply_bank(bank)
		var preset: Dictionary = bank.preset
		_sim.call("configure", float(preset["idle_rpm"]), float(preset["redline_rpm"]), preset["layout"] == "ev")
	_ab_button.text = ("Dinlenen: A (%s)" % _slot_a["id"]) if _playing_a else "Dinlenen: B (şu an)"


# --- Dinleme ------------------------------------------------------------------------------------------------------

func _on_mode(index: int) -> void:
	_set_mode(index as LabSim.Mode)


func _set_mode(mode: LabSim.Mode) -> void:
	_sim.call("cancel_script")
	_sim.set("mode", mode)
	if mode == LabSim.Mode.GEARS:
		_sim.set("gear", 0)
		_sim.set("speed", 0.0)
	_syncing = true
	_mode_option.select(int(mode))
	_syncing = false


func _play_script(steps: Array) -> void:
	_end_pass()
	_sim.call("play", steps)
	_mode_option.select(int(_sim.get("mode")))


func _on_start() -> void:
	if _voice:
		_voice.start_engine()


func _on_stop() -> void:
	if _voice:
		_voice.stop_engine()
	if _voice3d:
		_voice3d.stop_engine()


func _on_pass() -> void:
	if _voice == null:
		return
	_voice.stop_all()
	_pass_index = 0
	_begin_pass()


func _begin_pass() -> void:
	_pass_x = PASS_FROM
	_sim.call("cancel_script")
	_sim.set("mode", LabSim.Mode.GEARS)
	_sim.set("auto_shift", true)
	if _pass_index == 0:
		_sim.set("gear", 2)
		_sim.set("speed", 16.0)
		_sim.set("pedal", 0.3)
	else:
		_sim.set("gear", 1)
		_sim.set("speed", 13.0)
		_sim.set("pedal", 1.0)


func _end_pass() -> void:
	if _pass_index < 0:
		return
	_pass_index = -1
	if _voice3d:
		_voice3d.stop_all()
	_sim.set("pedal", 0.0)
	_sim.set("mode", LabSim.Mode.FREE)
	_sim.set("auto_shift", _auto_shift.button_pressed)


func _on_record() -> void:
	if _recorder == null:
		return
	if _recorder.is_recording_active():
		_recorder.set_recording_active(false)
		var wav: AudioStreamWAV = _recorder.get_recording()
		DirAccess.make_dir_recursive_absolute(RECORD_DIR)
		var path: String = RECORD_DIR + "%s_kayit_%s.wav" % [_current, Time.get_datetime_string_from_system().replace(":", "-")]
		if wav:
			wav.save_to_wav(path)
		_record_button.text = "● KAYIT"
		_info.text = "Kaydedildi: " + path
	else:
		_recorder.set_recording_active(true)
		_record_button.text = "■ KAYDI BİTİR"


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null:
		return
	if key.keycode == KEY_W or key.keycode == KEY_UP:
		_key_pedal = key.pressed
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed:
		match key.keycode:
			KEY_Z:
				_undo_step()
			KEY_Y:
				_redo_step()
			KEY_S:
				_on_save()
		return
	match key.keycode:
		KEY_SPACE:
			_sim.call("shift_up")
		KEY_B:
			_play_script(LabSim.blip())
		KEY_M:
			_on_start()
		KEY_K:
			_on_stop()


func _process(delta: float) -> void:
	_clock += delta
	_poll_task()
	if _voice == null:
		return
	if not bool(_sim.call("is_scripted")) and _pass_index < 0:
		_sim.set("pedal", 1.0 if (_key_pedal or _button_pedal) else 0.0)
	_sim.call("step", delta)
	for event: String in _sim.get("events"):
		if event == "shift" and _active_voice():
			_active_voice().pop(0.8)
	(_sim.get("events") as Array).clear()
	var rpm: float = _sim.get("rpm")
	var throttle: float = _sim.get("throttle")
	var limiter: bool = _sim.get("limiter")
	if _pass_index >= 0:
		_voice3d.update(delta, rpm, throttle, limiter)
	else:
		_voice.update(delta, rpm, throttle, limiter)
	_update_gauge()
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if _pass_index < 0 or _car_pivot == null:
		return
	_pass_x += float(_sim.get("speed")) * delta
	_car_pivot.position = Vector3(_pass_x, 0.0, 0.0)
	if _pass_x > PASS_TO:
		_pass_index += 1
		if _pass_index >= 2:
			_end_pass()
			_car_pivot.position = Vector3.ZERO
		else:
			_begin_pass()


func _active_voice() -> EngineVoice:
	return _voice3d if _pass_index >= 0 else _voice


func _update_gauge() -> void:
	var voice: EngineVoice = _active_voice()
	_gauge.set("idle", float(_preset["idle_rpm"]))
	_gauge.set("red", float(_preset["redline_rpm"]))
	_gauge.set("rpm", float(_sim.get("rpm")))
	_gauge.set("throttle", float(_sim.get("throttle")))
	_gauge.set("boost", voice.boost if voice else 0.0)
	_gauge.set("limiter", bool(_sim.get("limiter")))
	var mode: int = int(_sim.get("mode"))
	_gauge.set("gear_text", str(int(_sim.get("gear")) + 1) if mode == LabSim.Mode.GEARS else "N")
	var status: String = ""
	if voice:
		status = "çalan akış: %d" % voice.active_streams()
		if voice.is_starting():
			status += "   ·   MARŞ"
		elif not voice.running:
			status += "   ·   KONTAK KAPALI (M ile marş)"
	_gauge.set("status", status)


# --- 3B ------------------------------------------------------------------------------------------------------------

func _load_model(id: StringName) -> void:
	if _car:
		_car.queue_free()
		_car = null
	var path: String = CarCatalog.scene_path(id)
	if path == "" or not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return
	_car = scene.instantiate() as Node3D
	_car_pivot.add_child(_car)
	var rig: CarRig = CarRig.for_node(_car)
	if rig:
		rig.apply(CarAppearance.get_for(path))
	var box: AABB = _model_aabb(_car)
	var length: float = float((CarCatalog.get_entry(id).get("real_dimensions", {}) as Dictionary).get("length_m", 4.5))
	var scale_value: float = length / maxf(maxf(box.size.z, box.size.x), 0.01)
	_car.scale = Vector3.ONE * scale_value
	_car.rotation.y = PI * 0.5   # model önü +Z → yolda +X yönünde gider
	var center: Vector3 = box.get_center() * scale_value
	_car.position = Vector3(-center.z, -box.position.y * scale_value, center.x)


func _model_aabb(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var inverse: Transform3D = root.global_transform.affine_inverse()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var b: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _update_camera(delta: float) -> void:
	if _pass_index >= 0:
		var eye: Vector3 = Vector3(0.0, 1.5, PASS_SIDE)
		_camera.position = eye
		_camera.look_at(Vector3(_pass_x * 0.85, 0.7, 0.0), Vector3.UP)
		return
	_orbit += delta * 0.18
	var radius: float = 8.5
	_camera.position = Vector3(sin(_orbit) * radius, 2.4, cos(_orbit) * radius)
	_camera.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
