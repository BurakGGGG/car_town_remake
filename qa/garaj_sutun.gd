extends SceneTree
## GARAJ SOL SÜTUNU SIĞIYOR MU? İki oyun durumunda ölçer:
##   ERKEN — yeni kayıt: alanlar kilitli (fiyat gösterir), geliştirmeler iki satırlık YÜKSELT
##           düğmesi ve "ne alıyorum" satırı taşır → sütunun EN UZUN hâli
##   GEÇ   — geliştirmeler ve alanlar tamam (MAKSİMUM / AÇIK)
## Her durumda: gereken yükseklik, kullanılabilir alan, seçilen yoğunluk kademesi ve GARAJ DEĞERİ
## plakasının kaydırmadan görünüp görünmediği (plaka sütunun SONUNDA).
## Kullanım: godot-4 --path . --resolution 1152x648 -s res://qa/garaj_sutun.gd

var _f: int = 0
var _hud: Node
var _phase: int = 0
var _fails: int = 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn")
	elif _f == 60:
		_hud = current_scene.find_child("HUD", true, false)
		var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
		if save:
			save.new_game()
	elif _f == 80:
		_hud.get("router").call("open", &"garage")
	elif _f == 200:
		_measure("ERKEN")
		_hud.get("router").call("close_all")
		_max_out()
	elif _f == 240:
		_hud.get("router").call("open", &"garage")
	elif _f == 380:
		_measure("GEÇ")
		print("SONUÇ: %s" % ("HER İKİ DURUMDA SIĞIYOR" if _fails == 0 else "%d durumda SIĞMIYOR" % _fails))
		quit(0 if _fails == 0 else 1)
	return false


func _max_out() -> void:
	var eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	eco.set_money(5_000_000)
	var up: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	for id: StringName in [GarageUpgradeManager.GARAGE_ID, GarageUpgradeManager.SPEED_ID]:
		while up.can_buy(id):
			up.buy(id)
	var bays: RepairBayManager = get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		for i: int in bays.bay_count():
			if bays.can_purchase(i):
				bays.purchase(i)


func _measure(label: String) -> void:
	var col: Control = current_scene.find_child("InfoColumn", true, false) as Control
	var scroll: ScrollContainer = col.get_parent() as ScrollContainer
	var screen: Node = _hud.get("router").call("screen", &"garage")
	var value: Control = current_scene.find_child("GarageValueButton", true, false) as Control
	var wanted: float = col.get_combined_minimum_size().y
	var compact: bool = screen.get("_compact")
	var captions: Array = screen.get("_caption_labels")
	var captions_on: bool = captions.size() > 0 and (captions[0] as Label).visible
	var level: int = 0 if not compact else (1 if captions_on else 2)
	var clip: Rect2 = scroll.get_global_rect()
	var vr: Rect2 = value.get_global_rect()
	var shown: bool = value.is_visible_in_tree() and vr.end.y <= clip.end.y + 0.5
	var exit_btn: Control = current_scene.find_child("ExitButton", true, false) as Control
	var gap: float = exit_btn.get_global_rect().position.y - clip.end.y
	print("%-5s gereken=%3.0f  kaydırma=%3.0f  kademe=%d  GARAJ DEĞERİ %s (%3.0fx%2.0f)  ÇIK'a boşluk=%2.0f" % [
		label, wanted, clip.size.y, level, "GÖRÜNÜR" if shown else "KAYDIRMANIN ALTINDA",
		vr.size.x, vr.size.y, gap])
	if not shown or wanted > clip.size.y + 0.5 or gap < 0.0:
		_fails += 1
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/ui/")
	get_root().get_texture().get_image().save_png(
		"/home/burak/Projects/ct_shots/ui/garaj_%s.png" % ("erken" if label == "ERKEN" else "gec"))
