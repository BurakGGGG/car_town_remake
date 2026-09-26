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
##   REPAIR_BAYS    satın alınmış tamir alanı sayısı            (durum)
##   GARAGE_RANK    garaj değeri rütbesi (1-10)                 (durum)
##   JOB_STARS      tüm arızalardan toplanan ustalık yıldızı    (durum)
## Ödül: "xp", "gems", "money" (hepsi isteğe bağlı).

enum Type { REPAIRS, REPAIR_MONEY, PAINTS, OWN_VEHICLES, UPGRADE_LEVEL, PLAYER_LEVEL, REPAIR_BAYS, GARAGE_RANK, JOB_STARS }

const ENTRIES: Array[Dictionary] = [
	# --- İLK 10 DAKİKA: döngüyü öğret ---
	{"id": &"first_customer", "title": "İLK MÜŞTERİ", "text": "Bir aracı tamir et ve parasını topla", "type": Type.REPAIRS, "target": 1, "xp": 20, "money": 300},
	{"id": &"apprentice", "title": "ÇIRAK", "text": "5 tamir tamamla", "type": Type.REPAIRS, "target": 5, "xp": 30, "money": 500},
	{"id": &"fast_hands", "title": "HIZLI ELLER", "text": "TAMİR HIZI'nı 2. seviyeye çıkar", "type": Type.UPGRADE_LEVEL, "upgrade": &"repair_speed", "target": 2, "xp": 40, "money": 750},
	# --- 10-40 DAKİKA: garajı büyüt, ikinci alanı aç ---
	{"id": &"first_earnings", "title": "İLK KAZANÇ", "text": "Tamirlerden 3.000 ₺ kazan", "type": Type.REPAIR_MONEY, "target": 3000, "xp": 40, "money": 1000},
	{"id": &"bigger_garage", "title": "BÜYÜK GARAJ", "text": "Garajı 2. seviyeye genişlet", "type": Type.UPGRADE_LEVEL, "upgrade": &"garage_level", "target": 2, "xp": 60, "gems": 10, "money": 2000},
	{"id": &"second_bay", "title": "İKİNCİ ALAN", "text": "2. tamir alanını satın al", "type": Type.REPAIR_BAYS, "target": 2, "xp": 70, "money": 2500},
	# --- 40-90 DAKİKA: ilk araç, boya, koleksiyon ---
	{"id": &"collector", "title": "KOLEKSİYONCU", "text": "2 araca sahip ol", "type": Type.OWN_VEHICLES, "target": 2, "xp": 80, "gems": 15, "money": 2500},
	{"id": &"first_paint", "title": "YENİ RENK", "text": "Garajda bir aracını boya", "type": Type.PAINTS, "target": 1, "xp": 50, "gems": 10, "money": 1000},
	{"id": &"journeyman", "title": "KALFA", "text": "25 tamir tamamla", "type": Type.REPAIRS, "target": 25, "xp": 90, "money": 1500},
	# --- 1,5-3 SAAT: üçüncü alan, garaj değeri ---
	{"id": &"garage_three", "title": "USTA GARAJI", "text": "Garajı 3. seviyeye genişlet", "type": Type.UPGRADE_LEVEL, "upgrade": &"garage_level", "target": 3, "xp": 120, "money": 4000},
	{"id": &"third_bay", "title": "ÜÇÜNCÜ ALAN", "text": "3. tamir alanını satın al", "type": Type.REPAIR_BAYS, "target": 3, "xp": 140, "gems": 15, "money": 5000},
	{"id": &"valuable", "title": "DEĞERLİ GARAJ", "text": "Garaj değerinde 3. rütbeye ulaş", "type": Type.GARAGE_RANK, "target": 3, "xp": 150, "gems": 20, "money": 5000},
	# --- UZUN VADE ---
	{"id": &"master", "title": "USTA", "text": "100 tamir tamamla", "type": Type.REPAIRS, "target": 100, "xp": 200, "money": 8000},
	{"id": &"fleet", "title": "FİLO", "text": "4 araca sahip ol", "type": Type.OWN_VEHICLES, "target": 4, "xp": 250, "gems": 25, "money": 10000},
	{"id": &"star_mechanic", "title": "YILDIZLI USTA", "text": "İşlerden toplam 4 ustalık yıldızı topla", "type": Type.JOB_STARS, "target": 4, "xp": 300, "gems": 30, "money": 15000},
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
