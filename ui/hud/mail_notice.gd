class_name MailNotice
extends Node
## POSTA ALMA — yönetim panelinden gelen hediye / mesaj (MailService). AL → ödül hesaba geçer, HEDİYEN GELDİ! ekranı açılır
## (GiftScreen: hediyenin resimli kartları, paralar sayaçlara uçar); efsanevi araç seçimi varsa ekran kapanınca seçim
## ekranı açılır (UiRouter &"legendary_pick"). 2026-10-25'ten beri posta kendi penceresinde KENDİLİĞİNDEN AÇILMAZ (kullanıcı kararı): HABERLER
## kutusunda bekler (tabelada rozet + "HEDİYEN VAR"); AL oradan (InboxScreen) ve DAVET ET sekmesinden gelir. Hud kurar.

var _hud: Hud
var _mail: MailService
var _screen: GiftScreen


func _init(hud: Hud, mail: MailService) -> void:
	name = "MailNotice"
	_hud = hud
	_mail = mail


## Bekleyen postayı alır; ödül varsa ödül penceresi açılır. Posta bekliyorduysa (ödüllü ya da değil) true.
func claim_now(id: String) -> bool:
	if not _mail.pending().any(func(mail: Dictionary) -> bool: return mail["id"] == id):
		return false
	var summary: Dictionary = _mail.claim(id)
	if not summary.is_empty():
		_show_rewards(summary)
	return true


## Hediye ekranı (tek kopya; açıkken gelen ikinci hediye sırada bekler).
func gift_screen() -> GiftScreen:
	return _screen


func _show_rewards(summary: Dictionary) -> void:
	if _screen == null:
		_screen = GiftScreen.new(_hud)
		_screen.finished.connect(func(car_choice: bool) -> void:
			if car_choice:
				_hud.router.open(&"legendary_pick"))
		_hud.get_node("Root").add_child(_screen)   # tam ekran; Root temayı taşır (açılınca en üste çıkar)
	_screen.show_gift(summary)
