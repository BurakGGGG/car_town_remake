class_name PlayerProgress
extends Node
## Oyuncunun XP / seviye / gem durumu. Kalıcılık SaveManager'dadır (bu node yalnızca durumu tutar):
## kayıttan yükleme load_state(), yeni oyun reset() ile yapılır.
## PARA BURADA TUTULMAZ: tek kaynak EconomyManager ("economy" grubu) — bkz. gameplay/economy_manager.gd.
## HUD bu node'u "player_progress" grubundan bulur ve sinyallerine bağlanır:
## xp_changed → set_level + set_xp_ratio, gems_changed → set_gems.

signal gems_changed(gems: int)
signal xp_changed(level: int, xp: int, xp_to_next: int)
signal level_up(level: int)

@export var gems: int = 40
@export_range(1, 99) var level: int = 1
## Bu seviyede biriken XP.
@export var xp: int = 35
## 1 → 2 için gereken XP; her seviyede %25 artar.
@export var xp_base: int = 100

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
	xp_changed.emit(level, xp, xp_to_next())


## Bir sonraki seviye için gereken toplam XP.
func xp_to_next() -> int:
	return int(round(xp_base * pow(1.25, level - 1)))


## 0.0 – 1.0: mevcut seviyedeki ilerleme (HUD şerit göstergesi).
func xp_ratio() -> float:
	return clampf(float(xp) / float(maxi(xp_to_next(), 1)), 0.0, 1.0)
