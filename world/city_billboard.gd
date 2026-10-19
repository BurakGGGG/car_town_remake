class_name CityBillboard
extends Node3D
## ŞEHİR BILLBOARD'U — showroom meydanında (köşe totemi ile otopark arası), doğu-batı yoluna bakan reklam panosu
## (WorldDressing kurar, sahne düzenlenmez). Panoda havalı araç afişleri GÜNDE BİR değişir: yerel gece yarısında
## sıradaki afiş (gün numarası % afiş sayısı — her oyuncuda aynı gün aynı afiş).
##
## Afişler hazır FOTOĞRAF (assets/world/billboard/<id>.jpg — tools/billboard/ ile oyunun kendi araç modellerinden
## çizilip efektlenir): oyunda çizim yok, bellekte yalnızca o günün tek dokusu (arka planda yüklenir).
## Gövde tek köşe renkli mesh, pano gölgesiz malzeme (ışıklı reklam panosu gibi parlak), spot camları gölgesiz:
## toplam 3 çizim çağrısı, ışık kaynağı yok.
##
## Yüz güneye (yola) bakar: kamera parsele güneydoğudan baktığı için yüz her zaman görünür (kuzeye bakan bir yüz
## varsayılan görünümde hiç görünmezdi). Yükseklik köşe totemi kadar: varsayılan görünümde sağ üst HUD'a uzanmaz.

## Afiş sırası (gün numarasıyla döner). Yeni afiş: tools/billboard/ → buraya id eklenir.
const POSTERS: PackedStringArray = [
	"lambo_huracan", "ferrari_488_pista", "bugatti_chiron", "porsche_gt3", "audi_rs6", "ferrari_laferrari",
	"chevrolet_camaro", "mercedes_cls", "porsche_taycan", "togg_t10x", "bmw_e46", "bugatti_veyron", "bmw_e60",
	"honda_civic",
]
const POSTER_DIR: String = "res://assets/world/billboard/"
## Meydandaki yeri (parsel x ≈ 10,5 m, y ≈ 4,6 m) ve panonun ölçüsü (2:1, afiş 1024×512).
const SPOT: Vector3 = Vector3(2.90, 0.008, -0.88)
## Yola bakarken biraz doğuya (kameraya) dönük: yüz düz güneye bakınca 45°'lik kamerada fazla yan görünüyordu.
const YAW_DEGREES: float = 18.0
const PANEL: Vector2 = Vector2(1.30, 0.65)
const PANEL_BOTTOM: float = 0.40
const FRAME: float = 0.035
const DEPTH: float = 0.05
const LEG_SPAN: float = 0.86
const INK: Color = Color("2F3236")
const STEEL: Color = Color("6A6F76")
const AMBER: Color = Color("F5BE4C")
const BULB: Color = Color("FFF1C9")
## Gün değişimini bu aralıkla yoklar (sn).
const CHECK_EVERY: float = 30.0

var poster_id: String = ""
var _panel: MeshInstance3D
var _panel_material: StandardMaterial3D
var _loading: String = ""
var _check: float = 0.0


func _init() -> void:
	name = "CityBillboard"


func _ready() -> void:
	position = SPOT
	rotation_degrees.y = YAW_DEGREES
	_build()
	refresh()


func _process(delta: float) -> void:
	if _loading != "":
		_poll_load()
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		refresh()


## Bugünün afişini (değiştiyse) arka planda yükler.
func refresh() -> void:
	var wanted: String = poster_for(Time.get_unix_time_from_system(), _bias_minutes())
	if wanted == poster_id or wanted == _loading:
		return
	var path: String = POSTER_DIR + wanted + ".jpg"
	if not ResourceLoader.exists(path):
		push_warning("CityBillboard: afiş yok (%s)" % path)
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_loading = wanted


## Bu anın afişi: YEREL gün numarası (gece yarısı değişir) % afiş sayısı.
static func poster_for(unix_time: float, bias_minutes: int = 0) -> String:
	var day: int = floori((unix_time + float(bias_minutes) * 60.0) / 86400.0)
	return POSTERS[posmod(day, POSTERS.size())]


static func _bias_minutes() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


func _poll_load() -> void:
	var path: String = POSTER_DIR + _loading + ".jpg"
	match ResourceLoader.load_threaded_get_status(path):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			var texture: Texture2D = ResourceLoader.load_threaded_get(path) as Texture2D
			if texture:
				_panel_material.albedo_texture = texture   # eski doku bırakılır: bellekte tek afiş
				_panel_material.albedo_color = Color.WHITE
				poster_id = _loading
		_:
			push_warning("CityBillboard: afiş yüklenemedi (%s)" % path)
	_loading = ""


# --- Gövde ------------------------------------------------------------------------------------

func _build() -> void:
	var body: StreetMesh = StreetMesh.new()
	var bulbs: StreetMesh = StreetMesh.new()
	var top: float = PANEL_BOTTOM + PANEL.y
	var center_y: float = PANEL_BOTTOM + PANEL.y * 0.5
	var back_z: float = -DEPTH * 0.5
	# İki ayak: beton kaide + çelik direk (panonun arkasında)
	for side: float in [-1.0, 1.0]:
		var x: float = side * LEG_SPAN * 0.5
		body.box(Vector3(0.09, 0.04, 0.09), Transform3D(Basis(), Vector3(x, 0.02, back_z - 0.03)), Color("9A9488"))
		body.box(Vector3(0.045, center_y, 0.045), Transform3D(Basis(), Vector3(x, center_y * 0.5, back_z - 0.03)), STEEL)
		# Çapraz destek: direkten panonun arkasına
		body.box(Vector3(0.025, 0.025, 0.06), Transform3D(Basis(), Vector3(x, center_y, back_z - 0.01)), STEEL)
	# Arka levha + çerçeve (koyu), alt kenarda kehribar şerit
	body.box(Vector3(PANEL.x + FRAME * 2.0, PANEL.y + FRAME * 2.0, DEPTH), Transform3D(Basis(), Vector3(0.0, center_y, 0.0)), INK)
	body.box(Vector3(PANEL.x + FRAME * 2.0, 0.018, DEPTH + 0.004), Transform3D(Basis(), Vector3(0.0, PANEL_BOTTOM - FRAME + 0.009, 0.0)), AMBER)
	# Bakım yürüme yolu: panonun altında öne çıkan ızgara ve korkuluk
	body.box(Vector3(PANEL.x * 0.92, 0.012, 0.09), Transform3D(Basis(), Vector3(0.0, PANEL_BOTTOM - FRAME - 0.03, 0.05)), STEEL)
	body.box(Vector3(PANEL.x * 0.92, 0.008, 0.008), Transform3D(Basis(), Vector3(0.0, PANEL_BOTTOM - FRAME + 0.02, 0.092)), STEEL)
	for i: int in 7:
		var x: float = lerpf(-PANEL.x * 0.46, PANEL.x * 0.46, float(i) / 6.0)
		body.box(Vector3(0.006, 0.05, 0.006), Transform3D(Basis(), Vector3(x, PANEL_BOTTOM - FRAME - 0.005, 0.092)), STEEL)
	# Üstte üç spot: kol + lamba gövdesi, camı aşağı-öne bakar (gölgesiz parlak)
	for i: int in 3:
		var x: float = (float(i) - 1.0) * PANEL.x * 0.36
		body.box(Vector3(0.012, 0.012, 0.13), Transform3D(Basis(), Vector3(x, top + FRAME + 0.006, 0.05)), STEEL)
		var lamp: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)), Vector3(x, top + FRAME + 0.0, 0.12))
		body.box(Vector3(0.07, 0.03, 0.04), lamp, INK)
		bulbs.box(Vector3(0.058, 0.004, 0.03), lamp.translated_local(Vector3(0.0, -0.016, 0.0)), BULB)
	var frame: MeshInstance3D = MeshInstance3D.new()
	frame.name = "Frame"
	frame.mesh = body.commit()
	frame.material_override = StreetMesh.material()
	add_child(frame)
	var lights: MeshInstance3D = MeshInstance3D.new()
	lights.name = "Bulbs"
	lights.mesh = bulbs.commit()
	lights.material_override = StreetMesh.material(true)
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lights)
	# Pano: yola bakan yüz (+Z), afiş dokusu gölgesiz — ışıklı pano gibi kendi parlar
	_panel_material = StandardMaterial3D.new()
	_panel_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_panel_material.albedo_color = Color("1E2023")   # afiş yüklenene kadar sönük pano
	_panel_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var quad: QuadMesh = QuadMesh.new()
	quad.size = PANEL
	_panel = MeshInstance3D.new()
	_panel.name = "Poster"
	_panel.mesh = quad
	_panel.material_override = _panel_material
	_panel.position = Vector3(0.0, center_y, DEPTH * 0.5 + 0.002)
	_panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_panel)
