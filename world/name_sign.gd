class_name NameSign
extends Node3D
## İSİM TABELASI — otoparkın / deponun duvarına oyuncunun yazdığı yazı, HARF HARF ayrı karolardan (kullanıcı isteği
## 2026-10-21: "insanlar duvara isim yazmak isteyebilir: garaj adı, kendi adları"). Her harf kendi karosunda durur,
## karolar ince bir rayın üstüne dizilir; rayın altında isteğe bağlı iki direk (çatı katında korkuluğun üstüne basar).
##
## Veri {"t": metin, "s": stil, "c": harf rengi} (CarGarageManager.sign_of). Metin kaydedilirken temizlenir (clean_text):
## takma adla aynı karakter kümesi ve küfür süzgeci (SocialNames), en çok MAX_CHARS. Gösterirken Loc.upper ile büyür.
## Ölçüler METRE (iç mekânın Blender metresi): kurulduğu düğümün ölçeği oyun birimine çevirir.
## Karolar ışık alır (araçlar gibi anahtar ışık + ortam), harfler ışıksız (Label3D) — pişmiş ortamda okunaklı kalsın.

const MAX_CHARS: int = 16
## Karonun eni / boyu, harf arası, kelime boşluğu (karo boyunun oranı).
const TILE_ASPECT: float = 0.8
const GAP: float = 0.1
const SPACE: float = 0.45
const DEPTH: float = 0.14
const FONT_SIZE: int = 96

## Stiller: karo rengi, ray rengi, varsayılan harf rengi, neon parıltısı, karolar hafif eğri mi (el yapımı).
const STYLES: Array[Dictionary] = [
	{"name": "KLASİK", "tile": Color("F3E8CF"), "rail": Color("3A3D41"), "ink": 2, "glow": false, "tilt": false},
	{"name": "NEON", "tile": Color("1E1B26"), "rail": Color("14121A"), "ink": 7, "glow": true, "tilt": false},
	{"name": "AHŞAP", "tile": Color("9A6434"), "rail": Color("4A3020"), "ink": 1, "glow": false, "tilt": true},
	{"name": "METAL", "tile": Color("9AA1AA"), "rail": Color("2F3236"), "ink": 2, "glow": false, "tilt": false},
]
## Harf renkleri (0 = stilin kendi rengi).
const COLORS: Array[Color] = [
	Color(0, 0, 0, 0), Color("FFF6E5"), Color("2F3236"), Color("D7342A"), Color("F5BE4C"),
	Color("3D9FC7"), Color("5DBB63"), Color("FF5FA2"), Color("F08A24"),
]

## ANA GARAJIN duvar eşyası (GarageDecor NAME_SIGN): sabit boyda koyu pano + üstünde karolar. Pano sabit olduğu için
## dekor ölçüsü (DecorBuilder._norm, ilk kurulumda bir kez) yazıdan bağımsızdır. Metre; DecorBuilder ölçekler.
const DECOR_BOARD: Vector2 = Vector2(5.0, 1.15)   # 2,6 × 0,62 m şehir kamerasından küçük bir levha gibi kalıyordu
const DECOR_MAX_WIDTH: float = 4.7
const DECOR_HEIGHT: float = 0.85
const BOARD_DEPTH: float = 0.05

static var _font: FontVariation


## Boş veri: yazı yok (tabela çizilmez).
static func empty_data() -> Dictionary:
	return {"t": "", "s": 0, "c": 0}


## Kayıttan / arkadaştan gelen veriyi sınırlar; geçersiz metin boşalır.
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return empty_data()
	var data: Dictionary = raw
	var text: String = clean_text(SaveSafe.s(data.get("t", "")))
	return {"t": text, "s": clampi(SaveSafe.i(data.get("s", 0)), 0, STYLES.size() - 1),
		"c": clampi(SaveSafe.i(data.get("c", 0)), 0, COLORS.size() - 1)}


## Metin temizliği: boşluklar sadeleşir, uzunsa kısalır; karakter kümesi / küfür süzgecinden geçmezse "".
static func clean_text(raw: String) -> String:
	var text: String = SocialNames.clean_name(raw)
	if text.length() > MAX_CHARS:
		text = text.substr(0, MAX_CHARS).strip_edges()
	return text if is_valid_text(text) else ""


static func is_valid_text(text: String) -> bool:
	return text.length() <= MAX_CHARS and SocialNames.is_valid_title(text)


static func style_name(style: int) -> String:
	return Loc.t(String(STYLES[clampi(style, 0, STYLES.size() - 1)]["name"]))


## Harfin görünen rengi (0 = stilin kendi rengi).
static func ink_of(data: Dictionary) -> Color:
	var style: Dictionary = STYLES[clampi(SaveSafe.i(data.get("s", 0)), 0, STYLES.size() - 1)]
	var index: int = clampi(SaveSafe.i(data.get("c", 0)), 0, COLORS.size() - 1)
	return COLORS[int(style["ink"]) if index == 0 else index]


## Tabelayı kurar: genişliği en çok `max_width`, karo boyu `height` (sığmazsa küçülür). `posts` > 0 ise rayın altında
## bu uzunlukta iki direk. `board` verilirse ray yerine o boyda pano (ortası karoların ortasında). Kökün +Z yönü
## tabelanın yüzü. Önceki karolar silinir. Yazı boşsa yalnız pano (varsa) çizilir.
func build(data: Dictionary, max_width: float, height: float, posts: float = 0.0, board: Vector2 = Vector2.ZERO) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var style: Dictionary = STYLES[clampi(SaveSafe.i(data.get("s", 0)), 0, STYLES.size() - 1)]
	if board != Vector2.ZERO:
		var panel: MeshInstance3D = _box("Board", Vector3(board.x, board.y, BOARD_DEPTH), _shaded(style["rail"], 0.5))
		panel.position = Vector3(0.0, height * 0.5, -DEPTH * height * 0.5 - BOARD_DEPTH * 0.5)
		add_child(panel)
	var text: String = Loc.upper(SaveSafe.s(data.get("t", "")))
	if text.strip_edges().is_empty():
		return
	var ink: Color = ink_of(data)
	var chars: PackedStringArray = []
	var natural: float = 0.0
	for i: int in text.length():
		var ch: String = text[i]
		chars.append(ch)
		natural += (SPACE if ch == " " else TILE_ASPECT) + (GAP if i < text.length() - 1 else 0.0)
	var h: float = minf(height, max_width / maxf(natural, 0.01))
	var width: float = natural * h
	var tile_material: StandardMaterial3D = _shaded(style["tile"], 0.55)
	var rail_material: StandardMaterial3D = _shaded(style["rail"], 0.4)
	var lift: float = (height - h) * 0.5   # küçülen yazı panonun / yerin ortasında kalsın
	var d: float = DEPTH * height   # karo kalınlığı yazıdan bağımsız: dekor ölçüsü (derinlik) sabit kalsın
	if board == Vector2.ZERO:
		# Ray: karoların arkasında, ortalarından biraz aşağıda
		var rail: MeshInstance3D = _box("Rail", Vector3(width + h * 0.3, h * 0.22, d * 0.5), rail_material)
		rail.position = Vector3(0.0, lift + h * 0.42, -d * 0.5)
		add_child(rail)
	if posts > 0.0:
		for side: float in [-1.0, 1.0]:
			var top: float = lift + h * 0.4   # direk raya kadar (yazı küçülüp ortaya kalktıysa da)
			var post: MeshInstance3D = _box("Post", Vector3(h * 0.12, posts + top, h * 0.12), rail_material)
			post.position = Vector3(side * (width * 0.5 - h * 0.25), (top - posts) * 0.5, -d * 0.6)
			add_child(post)
	var x: float = -width * 0.5
	for i: int in chars.size():
		var ch: String = chars[i]
		var step: float = (SPACE if ch == " " else TILE_ASPECT) * h
		if ch != " ":
			var tile: Node3D = Node3D.new()
			tile.name = "Tile_%d" % i
			tile.position = Vector3(x + step * 0.5, lift + h * 0.5, 0.0)
			if bool(style["tilt"]):
				tile.rotation.z = deg_to_rad(float((i * 37 + 11) % 7 - 3) * 0.9)   # el yapımı: karolar hafif oynak
			var body: MeshInstance3D = _box("Body", Vector3(step, h, d), tile_material)
			tile.add_child(body)
			tile.add_child(_letter(ch, h, d, ink, bool(style["glow"])))
			add_child(tile)
		x += step + GAP * h


## Ana garaj duvar eşyası: verilen veriyle (yazı boşsa "GARAJIM") pano + karolar.
func build_decor(data: Dictionary) -> void:
	var shown: Dictionary = data.duplicate()
	if SaveSafe.s(shown.get("t", "")).strip_edges().is_empty():
		shown["t"] = Loc.t("GARAJIM")
	build(shown, DECOR_MAX_WIDTH, DECOR_HEIGHT, 0.0, DECOR_BOARD)


## Dekor gövdesindeki tabela (DecorBuilder adı "NameSign" koyar); yoksa null.
static func find_in(body: Node) -> NameSign:
	return body.find_child("NameSign", true, false) as NameSign if body else null


## Karo sayısı (boşluklar hariç) — test ve QA için.
func tile_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if String(child.name).begins_with("Tile_"):
			n += 1
	return n


func _letter(ch: String, h: float, d: float, ink: Color, glow: bool) -> Label3D:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_embolden = 0.9
	var label: Label3D = Label3D.new()
	label.name = "Letter"
	label.text = ch
	label.font = _font
	label.font_size = FONT_SIZE
	label.pixel_size = h * 0.78 / float(FONT_SIZE)   # büyük harf karonun ~%60'ı
	label.modulate = ink
	label.shaded = false
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, -h * 0.02, d * 0.5 + 0.004)
	if glow:
		label.outline_size = 22
		label.outline_modulate = Color(ink, 0.32)
	else:
		label.outline_size = 0
	return label


static func _shaded(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func _box(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
