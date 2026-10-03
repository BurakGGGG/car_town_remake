class_name EconomyManager
extends Node
## Oyundaki PARANIN TEK KAYNAĞI. Para başka hiçbir yerde ayrı bir değişkende tutulmaz:
## tamir maliyeti, tamir ödülü, ileride araç alımı / yükseltme / garaj genişletme hepsi buradan geçer.
## Sahnede World/Gameplay/EconomyManager olarak durur; onu arayanlar "economy" grubundan bulur
## (autoload yok — proje kuralı). HUD para göstergesi money_changed sinyaline bağlıdır.
##
## Kullanım:
##   var economy: EconomyManager = get_tree().get_first_node_in_group("economy")
##   if economy.spend_money(cost): ...        # yetersizse false, bakiye değişmez
##   economy.add_money(reward)                # kazanç
##   economy.can_afford(cost)                 # buton/kilit durumu için
##
## XP, seviye ve gem PlayerProgress'te kalır; bu node yalnızca para tutar.
## Kayıt sistemi geldiğinde tek yazılacak/okunacak alan money'dir.

## Para değişti (harcama, kazanç ya da doğrudan atama). HUD ve UI bunu dinler.
signal money_changed(money: int)
## Harcama denendi ama bakiye yetmedi (UI uyarısı için; şimdilik yalnızca bilgi).
signal purchase_failed(amount: int)
## Harcama yapıldı (başarılı spend_money; görev sayaçları dinler).
signal money_spent(amount: int)

## Oyuna başlarken verilen para.
@export var starting_money: int = 5000

var _money: int = 0


## Güncel bakiye (salt okunur; değiştirmek için add_money / spend_money / reset kullanılır).
var money: int:
	get: return _money


func _ready() -> void:
	add_to_group("economy")
	_money = maxi(starting_money, 0)
	money_changed.emit(_money)


## Kazanç ekler (negatif değer verilmez; harcama için spend_money kullanılır).
func add_money(amount: int) -> void:
	if amount <= 0:
		return
	_money += amount
	money_changed.emit(_money)


## Bakiye bu tutarı karşılıyor mu? (0 ve altı her zaman true — bedava işlem.)
func can_afford(amount: int) -> bool:
	return amount <= 0 or _money >= amount


## Harcama: yeterliyse düşer ve true döner. Yetersizse HİÇBİR ŞEY değişmez ve false döner;
## bakiye hiçbir koşulda negatife inmez.
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if _money < amount:
		purchase_failed.emit(amount)
		return false
	_money -= amount
	money_changed.emit(_money)
	money_spent.emit(amount)
	return true


## Bakiyeyi doğrudan ayarlar (kayıttan yükleme / test). Negatif değer 0'a çekilir.
func set_money(amount: int) -> void:
	var value: int = maxi(amount, 0)
	if value == _money:
		return
	_money = value
	money_changed.emit(_money)


## Yeni oyun: başlangıç parasına döner.
func reset() -> void:
	set_money(starting_money)
