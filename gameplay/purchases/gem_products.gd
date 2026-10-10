class_name GemProducts
extends RefCounted
## GEM PAKETLERİ — gerçek parayla satılan ürünlerin TEK listesi (Google Play "tek seferlik ürün",
## hepsi TÜKETİLEBİLİR). Ürün kimlikleri Play Console'daki kimliklerle BİREBİR aynı olmalı; bir kez
## yayınlanan kimlik değiştirilmez (yeni paket = yeni kimlik). Fiyat burada YOKTUR: oyuncunun para
## biriminde Play'den okunur (PurchaseManager.price_text). `usd` yalnızca konsolda girilecek taban
## fiyatın notudur, oyunda gösterilmez.
##
## Tasarım: docs/ELMAS_EKONOMISI.md. Düzenli oyuncu günde ~30–37 gem kazanır (tools/economy/crate_sim.py).

const STARTER: StringName = &"starter_pack"

## id, gems, bonus (büyük pakette gem başına indirim, vitrin etiketi %), once (yalnızca bir kez alınır), usd,
## name (vitrin adı, Türkçe anahtar), art (GemPackArt.Kind: kart çizimi), best (en iyi değer etiketi)
const PRODUCTS: Array[Dictionary] = [
	{"id": &"starter_pack", "gems": 400, "bonus": 0, "once": true, "usd": 1.99, "name": "BAŞLANGIÇ PAKETİ", "art": GemPackArt.Kind.STARTER},
	{"id": &"gems_pack_1", "gems": 100, "bonus": 0, "once": false, "usd": 0.99, "name": "BİR AVUÇ GEM", "art": GemPackArt.Kind.HANDFUL},
	{"id": &"gems_pack_2", "gems": 550, "bonus": 10, "once": false, "usd": 4.99, "name": "GEM KESESİ", "art": GemPackArt.Kind.POUCH},
	{"id": &"gems_pack_3", "gems": 1200, "bonus": 20, "once": false, "usd": 9.99, "name": "GEM SANDIĞI", "art": GemPackArt.Kind.CHEST},
	{"id": &"gems_pack_4", "gems": 2600, "bonus": 30, "once": false, "usd": 19.99, "name": "GEM HAZİNESİ", "art": GemPackArt.Kind.VAULT, "best": true},
]


static func ids() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for entry: Dictionary in PRODUCTS:
		out.append(String(entry["id"]))
	return out


static func get_entry(id: StringName) -> Dictionary:
	for entry: Dictionary in PRODUCTS:
		if entry["id"] == id:
			return entry
	return {}


static func gems_of(id: StringName) -> int:
	return int(get_entry(id).get("gems", 0))


static func is_once(id: StringName) -> bool:
	return bool(get_entry(id).get("once", false))
