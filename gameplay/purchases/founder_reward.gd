class_name FounderReward
extends RefCounted
## ÖN KAYIT ÖDÜLÜ — Google Play ön kayıt kampanyasının ödülü (kullanıcı kararı 2026-10-20):
## 10.000 ₺ + 100 elmas + TAŞTAKİ ALTIN ANAHTAR (satılmayan KURUCU eşyası, GarageDecor.is_exclusive).
##
## Play ödülü, PRODUCT_ID kimlikli uygulama içi ürünün "satın alması" olarak verir (sipariş no'su boş olabilir).
## Oyun açılışta query_purchases ile görür; PurchaseManager gem paketleriyle AYNI sözleşmeyle işler: ödül verilir
## → deftere yazılır → kayıt diske yazılır → Play'de tüketilir. Bir kayda bir kez verilir (defter + cihaz defteri).
## Play Console: AYNI KİMLİKLE yalnızca bu iş için bir uygulama içi ürün açılır ve ön kayıt ödülü olarak seçilir
## (ödül kampanya başlamadan tanımlanır, sonradan değiştirilemez).

const PRODUCT_ID: StringName = &"founder_reward"
const MONEY: int = 10000
const GEMS: int = 100
const DECOR: StringName = &"founder_wrench"


static func is_reward(product: StringName) -> bool:
	return product == PRODUCT_ID


## Ödülü hesaba geçirir. Eşya garajda boş bir yere kendiliğinden konur (yer yoksa depoda bekler, oyuncu
## düzenleyiciden koyar). `with_gems` false: elmas başka yoldan eklendi (PurchaseManager.carry_over).
## Dönüş: RewardPopup özeti {title, money, gems, crates: [eşya adı]}.
static func grant(tree: SceneTree, with_gems: bool = true) -> Dictionary:
	var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.add_money(MONEY)
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress and with_gems:
		progress.add_gems(GEMS)
	var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
	if decor and decor.grant_exclusive(DECOR):
		var view: GarageDecorView = tree.get_first_node_in_group("garage_decor_view") as GarageDecorView
		if view:
			view.place_free(DECOR)
	return {"title": Loc.t("ÖN KAYIT ÖDÜLÜ!"), "money": MONEY, "gems": GEMS,
		"crates": [Loc.t(String(GarageDecor.get_item(DECOR).get("title", DECOR)))]}
