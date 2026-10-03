class_name GaragePanel
extends HBoxContainer
## GARAJ sekmesinin alt paneli: ana görünümde (dünya garajı) alt sekmelerin hemen üstünde durur.
## Garajın kendisiyle ilgili her şey burada: GENİŞLET (garaj seviyesi), TAMİR HIZI, DÜZENLE, DETAY
## (garaj değeri / rütbe) ve USTALIK. ARAÇLAR sekmesi (GarageScreen) yalnızca araçlara bakar.
## Mantık burada değil: seviye / ücret GarageUpgradeManager'dan, bakiye EconomyManager'dan, garaj
## değeri GarageValue'dan okunur; basışlar sinyal olarak HUD'a gider (satın alma plakasını,
## düzenleme / detay / ustalık ekranlarını HUD / UiRouter açar). TAMİR HIZI doğrudan satın alınır.

signal expand_requested
signal bay_requested(index: int)
signal edit_requested
signal value_requested
signal mastery_requested

var level_button: PlateButton
var speed_button: PlateButton
var bay_button: PlateButton
var edit_button: PlateButton
var value_button: PlateButton
var mastery_button: PlateButton

var _upgrades: GarageUpgradeManager
var _economy: EconomyManager
var _bays: RepairBayManager


func _ready() -> void:
	name = "GaragePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override(&"separation", 6)
	level_button = _make("LevelButton", HudIcon.Kind.GARAGE)
	speed_button = _make("SpeedButton", HudIcon.Kind.WRENCH)
	bay_button = _make("BayButton", HudIcon.Kind.NONE)
	edit_button = _make("EditButton", HudIcon.Kind.NONE)
	value_button = _make("ValueButton", HudIcon.Kind.NONE)
	mastery_button = _make("MasteryButton", HudIcon.Kind.NONE)
	edit_button.text = "DÜZENLE"
	mastery_button.text = "USTALIK"
	level_button.pressed.connect(func() -> void: expand_requested.emit())
	speed_button.pressed.connect(_on_speed_pressed)
	bay_button.pressed.connect(func() -> void:
		if _bays and _bays.unlocked_count() < _bays.bay_count():
			bay_requested.emit(_bays.unlocked_count()))
	edit_button.pressed.connect(func() -> void: edit_requested.emit())
	value_button.pressed.connect(func() -> void: value_requested.emit())
	mastery_button.pressed.connect(func() -> void: mastery_requested.emit())
	_connect.call_deferred()
	refresh()


func _make(node_name: String, icon: HudIcon.Kind) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlate"
	button.kind = icon
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(84.0, 0.0)
	add_child(button)
	return button


## Seviye, bakiye ya da garaj değeri değişince tazelenir (kare başına iş yok).
func _connect() -> void:
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	if _upgrades:
		_upgrades.levels_changed.connect(refresh)
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: refresh())
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor:
		decor.placement_changed.connect(refresh)
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership:
		ownership.ownership_changed.connect(refresh)
	_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if _bays:
		_bays.bays_changed.connect(refresh)
	refresh()


func _on_speed_pressed() -> void:
	if _upgrades:
		_upgrades.buy(GarageUpgradeManager.SPEED_ID)   # bakiye yetmezse hiçbir şey değişmez


func refresh() -> void:
	if level_button == null:
		return
	_write_upgrade(level_button, GarageUpgradeManager.GARAGE_ID, "GARAJ SV.%d", "GENİŞLET")
	_write_upgrade(speed_button, GarageUpgradeManager.SPEED_ID, "TAMİR HIZI %d/%d", "YÜKSELT")
	_write_bay()
	var value: int = GarageValue.compute(get_tree())
	value_button.text = "DETAY\n%d. RÜTBE" % GarageValue.rank(value)


## "BAŞLIK\nEYLEM ücret ₺"; maksimumda "MAKSİMUM", bakiye yetmezse düğme kapalı.
func _write_upgrade(button: PlateButton, id: StringName, title: String, action: String) -> void:
	if _upgrades == null:
		button.text = title.split(" ")[0]
		button.disabled = true
		return
	var upgrade: GarageUpgrade = _upgrades.get_upgrade(id)
	if upgrade == null:
		button.disabled = true
		return
	var head: String = title % [upgrade.current_level] if id == GarageUpgradeManager.GARAGE_ID \
			else title % [upgrade.current_level, upgrade.max_level]
	if upgrade.is_max():
		button.text = "%s\nMAKSİMUM" % head
		button.disabled = id == GarageUpgradeManager.SPEED_ID   # garaj düğmesi maksimumda da plakayı gösterir
		return
	var cost: int = upgrade.next_cost()
	button.text = "%s\n%s %s ₺" % [head, action, Hud.format_thousands(cost)]
	# TAMİR HIZI doğrudan satın alınır: bakiye yetmezse kapalı. GENİŞLET plaka açar (yetersiz bakiye
	# plakada yazar), o yüzden hep açık.
	button.disabled = id == GarageUpgradeManager.SPEED_ID and _economy != null and not _economy.can_afford(cost)


## TAMİR ALANI düğmesi: sıradaki alanın satın alma durumu. Basınca HUD satın alma plakasını açar.
func _write_bay() -> void:
	if _bays == null or _bays.unlocked_count() >= _bays.bay_count():
		bay_button.text = "TAMİR ALANI\nTÜMÜ AÇIK"
		bay_button.disabled = true
		return
	var next: int = _bays.unlocked_count()
	bay_button.disabled = false
	match _bays.status(next):
		RepairBayManager.Status.NEEDS_LEVEL:
			bay_button.text = "TAMİR ALANI %d\nGARAJ SV.%d" % [next + 1, _bays.required_level(next)]
		_:
			bay_button.text = "TAMİR ALANI %d\nAL %s ₺" % [next + 1, Hud.format_thousands(_bays.price(next))]
