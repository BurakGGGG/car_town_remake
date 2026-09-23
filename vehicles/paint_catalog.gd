class_name PaintCatalog
## Boya atölyesindeki renkler — TEK KAYNAK (ad, renk, fiyat, para birimi burada; başka yerde yok).
## Standart renkler ₺ (EconomyManager), özel renkler gem (PlayerProgress) ile alınır.
## "FABRİKA" her aracın katalogdaki default_color'ıdır ve ücretsizdir (araca göre değişir).
## Satın alma VehicleOwnership.purchase_paint üzerinden yapılır; kayıtta renk hex olarak durur
## (id değil), böylece katalogdan bir renk kalksa bile oyuncunun aracı aynı renkte kalır.

enum Currency { MONEY, GEMS }

const FACTORY_ID: StringName = &"factory"

const ENTRIES: Array[Dictionary] = [
	{"id": &"white", "name": "BEYAZ", "color": Color("EDEDEA"), "price": 1500, "currency": Currency.MONEY},
	{"id": &"black", "name": "SİYAH", "color": Color("1D1F23"), "price": 1500, "currency": Currency.MONEY},
	{"id": &"silver", "name": "GÜMÜŞ", "color": Color("B7BBC1"), "price": 1500, "currency": Currency.MONEY},
	{"id": &"grey", "name": "FÜME", "color": Color("5F6368"), "price": 1500, "currency": Currency.MONEY},
	{"id": &"red", "name": "KIRMIZI", "color": Color("B3202A"), "price": 2000, "currency": Currency.MONEY},
	{"id": &"blue", "name": "MAVİ", "color": Color("1F4FA3"), "price": 2000, "currency": Currency.MONEY},
	{"id": &"navy", "name": "LACİVERT", "color": Color("1B2A4A"), "price": 2000, "currency": Currency.MONEY},
	{"id": &"green", "name": "YEŞİL", "color": Color("2E6B3A"), "price": 2000, "currency": Currency.MONEY},
	{"id": &"yellow", "name": "SARI", "color": Color("E8B923"), "price": 2500, "currency": Currency.MONEY},
	{"id": &"orange", "name": "TURUNCU", "color": Color("D9661F"), "price": 2500, "currency": Currency.MONEY},
	{"id": &"mint", "name": "NANE", "color": Color("7FD3B0"), "price": 15, "currency": Currency.GEMS},
	{"id": &"sky", "name": "BEBEK MAVİSİ", "color": Color("88C9F0"), "price": 15, "currency": Currency.GEMS},
	{"id": &"pink", "name": "PEMBE", "color": Color("E07AA8"), "price": 15, "currency": Currency.GEMS},
	{"id": &"purple", "name": "MOR", "color": Color("6A3FA0"), "price": 20, "currency": Currency.GEMS},
	{"id": &"copper", "name": "BAKIR", "color": Color("A8643A"), "price": 20, "currency": Currency.GEMS},
	{"id": &"taxi", "name": "TAKSİ SARISI", "color": Color("F5C518"), "price": 25, "currency": Currency.GEMS},
]


## Satın alınabilir renkler (fabrika rengi hariç).
static func all() -> Array[Dictionary]:
	return ENTRIES


static func get_entry(paint_id: StringName) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry["id"] == paint_id:
			return entry
	return {}


## Rengi katalogda karşılığı olan boyanın id'si (yoksa &"").
static func id_for_color(color: Color) -> StringName:
	for entry: Dictionary in ENTRIES:
		if (entry["color"] as Color).is_equal_approx(color):
			return entry["id"]
	return &""

