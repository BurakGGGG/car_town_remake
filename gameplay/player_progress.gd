class_name PlayerProgress
extends Node
## Oyuncunun XP / seviye / gem durumu. Kalıcılık SaveManager'dadır (bu node yalnızca durumu tutar):
## kayıttan yükleme load_state(), yeni oyun reset() ile yapılır.
## PARA BURADA TUTULMAZ: tek kaynak EconomyManager ("economy" grubu) — bkz. gameplay/economy_manager.gd.
## HUD bu node'u "player_progress" grubundan bulur ve sinyallerine bağlanır:
## xp_changed → set_level + set_xp_ratio, gems_changed → set_gems.

## Seviye atlandı ve ödülü verildi (HUD bildirim plakası bunu gösterir).
signal level_reward(level: int, money: int, text: String)

signal gems_changed(gems: int)
signal xp_changed(level: int, xp: int, xp_to_next: int)
signal level_up(level: int)

@export var gems: int = 40
@export_range(1, 99) var level: int = 1
## Bu seviyede biriken XP.
@export var xp: int = 35
## 1 → 2 için gereken XP; her seviyede %25 artar.
@export var xp_base: int = 100

## SEVİYE ÖDÜLLERİ — Car Town prensibi: her seviye somut bir şey versin, belirli seviyeler
## yeni içerik AÇSIN. "text" yalnızca bildirim yazısıdır; gerçek kilit ilgili sistemdedir
## (arızalar RepairType.min_level, kasalar vehicles/crates.json min_level).
const LEVEL_REWARDS: Dictionary = {
	2: {"money": 500},
	3: {"money": 750},
	4: {"money": 1000},
	5: {"money": 1500, "text": "YENİ İŞ: BOYA İŞİ"},
	6: {"money": 2000},
	7: {"money": 2500},
	8: {"money": 3000, "text": "YENİ İŞ: DÖŞEME"},
	10: {"money": 4000, "text": "AİLE KASASI SHOWROOM'DA"},
	12: {"money": 5000, "text": "YENİ İŞ: FREN REVİZYONU"},
	14: {"money": 3500, "text": "SPOR KASASI SHOWROOM'DA"},
	15: {"money": 7500},
	20: {"money": 12000, "text": "PRESTİJ KASASI SHOWROOM'DA"},
}
## Tabloda olmayan seviyelerde verilen para.
const LEVEL_REWARD_STEP: int = 250
## Seviye gemi (kasa ekonomisi, docs/vehicle_crate_design_v2.md §3.2): her seviyede bu kadar,
## her 5. seviyede ek LEVEL_GEM_MILESTONE.
const LEVEL_GEMS: int = 5
const LEVEL_GEM_MILESTONE: int = 25

var _default_level: int = 1
var _default_xp: int = 0
var _default_gems: int = 0


func _ready() -> void:
	add_to_group("player_progress")
	_default_level = level
	_default_xp = xp
	_default_gems = gems


## Kayıttan yükleme: değerleri doğrulayıp uygular ve sinyalleri yayar (HUD kendiliğinden güncellenir).
func load_state(p_level: int, p_xp: int, p_gems: int) -> void:
	level = clampi(p_level, 1, 99)
	xp = maxi(p_xp, 0)
	gems = maxi(p_gems, 0)
	gems_changed.emit(gems)
	xp_changed.emit(level, xp, xp_to_next())


## Yeni oyun: sahnedeki başlangıç değerlerine döner.
func reset() -> void:
	load_state(_default_level, _default_xp, _default_gems)


func add_gems(amount: int) -> void:
	if amount == 0:
		return
	gems = maxi(gems + amount, 0)
	gems_changed.emit(gems)


func can_afford_gems(amount: int) -> bool:
	return amount <= 0 or gems >= amount


## Gem harcama (boya atölyesi): yeterliyse düşer ve true döner; yetersizse HİÇBİR ŞEY değişmez.
func spend_gems(amount: int) -> bool:
	if amount <= 0:
		return true
	if gems < amount:
		return false
	gems -= amount
	gems_changed.emit(gems)
	return true


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	while xp >= xp_to_next() and level < 99:
		xp -= xp_to_next()
		level += 1
		level_up.emit(level)
		_pay_level_reward(level)
	xp_changed.emit(level, xp, xp_to_next())


## Bu seviyenin ödülü: {"money": int, "gems": int, "text": String}.
static func reward_for(p_level: int) -> Dictionary:
	var entry: Dictionary = LEVEL_REWARDS.get(p_level, {})
	return {
		"money": int(entry.get("money", LEVEL_REWARD_STEP * p_level)),
		"gems": LEVEL_GEMS + (LEVEL_GEM_MILESTONE if p_level % 5 == 0 else 0),
		"text": Loc.t(String(entry.get("text", ""))) if entry.has("text") else "",
	}


## Seviye ödülünü öder (para tek kaynaktan: EconomyManager) ve bildirimi yayar.
func _pay_level_reward(p_level: int) -> void:
	var reward: Dictionary = reward_for(p_level)
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.add_money(int(reward["money"]))
	add_gems(int(reward["gems"]))
	level_reward.emit(p_level, int(reward["money"]), String(reward["text"]))


## Bir sonraki seviye için gereken toplam XP.
func xp_to_next() -> int:
	return int(round(xp_base * pow(1.25, level - 1)))


## 0.0 – 1.0: mevcut seviyedeki ilerleme (HUD şerit göstergesi).
func xp_ratio() -> float:
	return clampf(float(xp) / float(maxi(xp_to_next(), 1)), 0.0, 1.0)
