class_name QuestCatalog
## Görevler — TEK KAYNAK (başlık, açıklama, hedef, ödül burada; başka yerde yok).
## Sıralı bir zincirdir: QuestManager listedeki ilk ACTIVE_COUNT ödülü alınmamış görevi aktif tutar,
## biri alınınca sıradaki açılır. Sırayı / ödülü değiştirmek için yalnızca bu listeyi düzenle.
##
## Tür:
##   REPAIRS        PARA TOPLA ile biten tamir sayısı          (sayaç: görev aktifken sayar)
##   REPAIR_MONEY   tamirlerden kazanılan ₺                    (sayaç)
##   PAINTS         satın alınan boya sayısı                    (sayaç)
##   OWN_VEHICLES   sahip olunan araç sayısı                    (durum: her an mevcut değerden)
##   UPGRADE_LEVEL  "upgrade" id'li garaj geliştirmesinin seviyesi (durum)
##   PLAYER_LEVEL   oyuncu seviyesi                             (durum)
## Ödül: "xp", "gems", "money" (hepsi isteğe bağlı).

enum Type { REPAIRS, REPAIR_MONEY, PAINTS, OWN_VEHICLES, UPGRADE_LEVEL, PLAYER_LEVEL }

const ENTRIES: Array[Dictionary] = [
	{"id": &"first_customer", "title": "İLK MÜŞTERİ", "text": "Bir aracı tamir et ve parasını topla", "type": Type.REPAIRS, "target": 1, "xp": 20, "gems": 5},
	{"id": &"apprentice", "title": "ÇIRAK", "text": "3 tamir tamamla", "type": Type.REPAIRS, "target": 3, "xp": 30, "gems": 5},
	{"id": &"first_paint", "title": "YENİ RENK", "text": "Garajda bir aracını boya", "type": Type.PAINTS, "target": 1, "xp": 25, "gems": 5},
	{"id": &"fast_hands", "title": "HIZLI ELLER", "text": "TAMİR HIZI'nı 2. seviyeye çıkar", "type": Type.UPGRADE_LEVEL, "upgrade": &"repair_speed", "target": 2, "xp": 40, "gems": 10},
	{"id": &"first_earnings", "title": "İLK KAZANÇ", "text": "Tamirlerden 1.000 ₺ kazan", "type": Type.REPAIR_MONEY, "target": 1000, "xp": 40, "gems": 5},
	{"id": &"collector", "title": "KOLEKSİYONCU", "text": "2 araca sahip ol", "type": Type.OWN_VEHICLES, "target": 2, "xp": 50, "gems": 10},
	{"id": &"journeyman", "title": "KALFA", "text": "10 tamir tamamla", "type": Type.REPAIRS, "target": 10, "xp": 60, "gems": 10},
	{"id": &"wide_garage", "title": "GENİŞ GARAJ", "text": "TAMİR ALANI'nı 2. seviyeye çıkar", "type": Type.UPGRADE_LEVEL, "upgrade": &"repair_capacity", "target": 2, "xp": 60, "gems": 10},
	{"id": &"rising", "title": "YÜKSELEN USTA", "text": "5. seviyeye ulaş", "type": Type.PLAYER_LEVEL, "target": 5, "gems": 15, "money": 1000},
	{"id": &"master", "title": "USTA", "text": "25 tamir tamamla", "type": Type.REPAIRS, "target": 25, "xp": 100, "gems": 15},
	{"id": &"fleet", "title": "FİLO", "text": "3 araca sahip ol", "type": Type.OWN_VEHICLES, "target": 3, "xp": 100, "gems": 15},
	{"id": &"capital", "title": "SERMAYE", "text": "Tamirlerden 5.000 ₺ kazan", "type": Type.REPAIR_MONEY, "target": 5000, "xp": 120, "gems": 20},
]


static func all() -> Array[Dictionary]:
	return ENTRIES


static func get_entry(quest_id: StringName) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry["id"] == quest_id:
			return entry
	return {}


## Sayaç türü mü (ilerleme olaylardan birikir ve kaydedilir)? Değilse ilerleme oyunun durumundan okunur.
static func is_counter(type: int) -> bool:
	return type == Type.REPAIRS or type == Type.REPAIR_MONEY or type == Type.PAINTS
