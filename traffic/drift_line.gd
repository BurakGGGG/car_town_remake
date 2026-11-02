class_name DriftLine
extends RefCounted
## DRIFT GÖSTERİSİNİN ÇİZGİSİ VE ZAMAN ÇİZELGESİ (DriftEvent kullanır). Fizik yok: rota önceden çizilir, iki aracın her
## 1/60 sn'lik pozu (konum, gövde yönü, kayma açısı, karşı direksiyon, yatış, tekerlek dönüşü, duman / cıyak yoğunluğu,
## motor devri / gaz) gösteri başlamadan HESAPLANIR; oynatma yalnızca okur. Böylece: öndeki aracın ekrana girdiği an
## bilinir (müziğin "drop"u ona denk getirilir), iki aracın birbirine / kaldırıma değmediği test edilebilir.
##
## ROTA: kavşaktan DÖNEN çizgi (şehirde tek kavşak var, yollar düz). Giriş yolunun ucundan gelir → düzlükte MANJI (sağa
## sola savrularak kayma) → virajdan önce dışa doğru ÇALIM (Scandinavian flick) → kavşakta büyük açılı dönüş → çıkış
## yolunda yine manji → yol ucunda kaybolur. Sağa ve sola dönüş için ayrı anahtar noktalar (yerel: a = giriş yönünde,
## b = sola; kavşak merkezi 0,0); dört giriş yönü bunların döndürülmesidir. Anahtar noktalar arası kübik Hermite.
##
## KAYMA (drift açısı β, gövdenin hareket yönünden sola dönüklüğü): yolun eğriliğinden (biraz ileriye bakarak) hedef
## açı, hedefe yaylı-sönümlü yaklaşma → geçişlerde gövde savrulur, hafif fazla döner, oturur (ağırlık aktarımı). Çizgiyi
## aracın ÖN AKSI izler (PIVOT): kuyruk dışa açılır, burun çizgide kalır — gerçek drift görüntüsü. Ön tekerler hareket
## yönüne bakar (karşı direksiyon). Gövde virajın dışına yatar, gazda arkaya oturur.
## TANDEM: arkadaki araç aynı çizgiden TANDEM_GAP geride gelir (virajda yaklaşır); kendi kayması kendi konumundan.

## Örnekleme: yol adımı (birim) ve zaman çizelgesi adımı (sn).
const STEP: float = 0.02
const DT: float = 1.0 / 60.0
## Kavşak merkezi (iki yolun orta çizgilerinin kesişimi) ve yol yarı genişliği.
const CENTER: Vector3 = Vector3(0.6, 0.0, 0.6)
const ROAD_HALF: float = 0.6
## Rota yol ucundan bu kadar uzakta başlar / biter (dünyanın kenarı ±11; doğma yeri sonra kameraya göre seçilir).
const REACH: float = 13.0
## Manji: yanal salınım dalga boyunun yarısı (birim) ve iki uç (b, yerel). Giriş ve çıkış yolunda.
const MANJI_HALF: float = 1.15
const MANJI_SWINGS: int = 6        # girişte bu kadar uç (virajdan ~7 birim önce başlar; daha uzakta düz gelir)
const MANJI_END: float = 8.0       # virajdan sonra bu kadar sürer
## Hız: düzlükte en çok, virajda yanal ivme sınırı (v² · κ), gaz / fren ivmesi (birim/sn²).
const TOP_SPEED: float = 1.55
const MIN_SPEED: float = 0.95
const LATERAL_GRIP: float = 1.25
const ACCEL: float = 1.1
const BRAKE: float = 2.2
## Kayma açısı: β_hedef = clamp(GAIN · κ(s + LOOK_AHEAD)); düzlükte en çok MANJI_MAX, virajda CORNER_MAX (rad).
const SLIP_GAIN: float = 1.05
const LOOK_AHEAD: float = 0.32
## Eğrilik yumuşatma yarıçapı (birim).
const CURVE_SMOOTH: float = 0.16
const MANJI_MAX: float = 0.47      # ~27°
const CORNER_MAX: float = 0.84     # ~48°
## Yay-sönüm (doğal frekans rad/sn, sönüm oranı): ~0,35 sn'de savrulur, az fazla döner.
const SLIP_FREQ: float = 8.5
const SLIP_DAMP: float = 0.58
## Ön aks gövde merkezinden bu kadar önde (birim; araç boyu ~0,6): çizgiyi o izler, kuyruk açılır.
const PIVOT: float = 0.15
## Karşı direksiyon (β'nın oranı) ve sınırı (derece); gövde yatışı / oturması.
const COUNTER_STEER: float = 0.9
const STEER_LIMIT: float = 40.0
const ROLL_GAIN: float = 0.05
const ROLL_LIMIT: float = 0.075
const PITCH_GAIN: float = 0.03
const PITCH_LIMIT: float = 0.04
## Arka tekerler patinajda: yol hızından bu kat hızlı döner.
const WHEEL_SPIN: float = 1.8
## Tandem: arkadaki aracın öndekine yol boyu uzaklığı (düzlük / viraj). Arkadaki kendi hız profiliyle sürer, aradaki
## mesafeyi yumuşak bir denetleyici tutar (TANDEM_PULL: mesafe farkı başına ek hız, 1/sn; hedef TANDEM_EASE ile kayar).
const TANDEM_GAP: float = 0.98
const TANDEM_GAP_CORNER: float = 0.8
const TANDEM_PULL: float = 2.2
const TANDEM_EASE: float = 2.5
## Gövde yunuslaması / yatışı ve yunuslamaya giren ivme yumuşatılır (1/sn): araç hopluyor gibi görünmesin.
const POSE_EASE: float = 7.0

## Rota: giriş yönü (dünya, birim vektör) ve dönüş (+1 sol, -1 sağ).
var entry_dir: Vector3 = Vector3.FORWARD
var turn: int = -1
## Yoğun çizgi: noktalar (y = 0), hareket yönü (yaw, atan2(x, z)), işaretli eğrilik (sola +), yol uzunluğu.
var points: PackedVector3Array = PackedVector3Array()
var headings: PackedFloat32Array = PackedFloat32Array()
var curvature: PackedFloat32Array = PackedFloat32Array()
var lengths: PackedFloat32Array = PackedFloat32Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var corner_weight: PackedFloat32Array = PackedFloat32Array()
## Virajın (kavşaktaki dönüşün) yol üzerindeki başı / sonu.
var corner_from: float = 0.0
var corner_to: float = 0.0
var length: float = 0.0


## Bir aracın zaman çizelgesi: her DT'de bir örnek.
class Track:
	var id: StringName = &""
	var start_s: float = 0.0
	var s: PackedFloat32Array = PackedFloat32Array()
	var position: PackedVector3Array = PackedVector3Array()   # gövde merkezi (y = 0)
	var yaw: PackedFloat32Array = PackedFloat32Array()        # gövde yönü
	var travel: PackedFloat32Array = PackedFloat32Array()     # hareket yönü
	var slip: PackedFloat32Array = PackedFloat32Array()       # β (rad, sola +)
	var slip_rate: PackedFloat32Array = PackedFloat32Array()
	var speed: PackedFloat32Array = PackedFloat32Array()
	var steer: PackedFloat32Array = PackedFloat32Array()      # derece, + sol
	var roll: PackedFloat32Array = PackedFloat32Array()
	var pitch: PackedFloat32Array = PackedFloat32Array()
	var front_spin: PackedFloat32Array = PackedFloat32Array() # birikimli derece
	var rear_spin: PackedFloat32Array = PackedFloat32Array()
	var intensity: PackedFloat32Array = PackedFloat32Array()  # duman / iz / cıyak (0–1)
	var throttle: PackedFloat32Array = PackedFloat32Array()
	var rpm: PackedFloat32Array = PackedFloat32Array()        # kırmızı çizginin oranı (0–1)

	func duration() -> float:
		return float(maxi(s.size() - 1, 0)) * DT

	## `t` anındaki örneğin kesirli sırası (0 … size-1).
	func index_at(t: float) -> float:
		return clampf(t / DT, 0.0, float(maxi(s.size() - 1, 0)))

	func sample_f(channel: PackedFloat32Array, t: float) -> float:
		var at: float = index_at(t)
		var i: int = int(at)
		var j: int = mini(i + 1, channel.size() - 1)
		return lerpf(channel[i], channel[j], at - float(i))

	func sample_angle(channel: PackedFloat32Array, t: float) -> float:
		var at: float = index_at(t)
		var i: int = int(at)
		var j: int = mini(i + 1, channel.size() - 1)
		return lerp_angle(channel[i], channel[j], at - float(i))

	func sample_position(t: float) -> Vector3:
		var at: float = index_at(t)
		var i: int = int(at)
		var j: int = mini(i + 1, position.size() - 1)
		return position[i].lerp(position[j], at - float(i))


## Rotayı kurar: `entry` giriş yönü (dört ana yönden biri), `turn_side` +1 sol / -1 sağ.
static func build(entry: Vector3, turn_side: int) -> DriftLine:
	var line: DriftLine = DriftLine.new()
	line.entry_dir = Vector3(entry.x, 0.0, entry.z).normalized()
	line.turn = 1 if turn_side > 0 else -1
	line._build_path(line._keys())
	line._build_speeds()
	return line


## Yerel → dünya: a giriş yönünde, b sola.
func to_world(a: float, b: float) -> Vector3:
	var left: Vector3 = Vector3.UP.cross(entry_dir)
	return CENTER + entry_dir * a + left * b


## Çıkış yönü (dünya).
func exit_dir() -> Vector3:
	var left: Vector3 = Vector3.UP.cross(entry_dir)
	return left if turn > 0 else -left


## Anahtar noktalar (yerel a, b ve yön derecesi: 0 = giriş yönü, + sola). Önce uzaktan düz gelir, virajdan ~7 birim
## önce salınım başlar; çalımdan sonra dönüş; çıkışta salınım, sonra düz uzaklaşır.
func _keys() -> Array[Vector3]:
	var keys: Array[Vector3] = [Vector3(-REACH, -0.17, 0.0)]
	# Giriş manjisi: uçlar sırayla şeride yakın / yolun ortasına yakın; son uç (a = -3,5) ortada
	var manji: Array[Vector3] = []
	for k: int in MANJI_SWINGS:
		manji.push_front(Vector3(-3.5 - float(k) * MANJI_HALF, -0.04 if k % 2 == 0 else -0.17, 0.0))
	keys.append_array(manji)
	if turn < 0:
		# SAĞA DÖNÜŞ: virajın dışı sol. Şeride yaslanır, çalım: sola açılır, sonra büyük açıyla sağa (iç köşe a = b = -0,6)
		keys.append(Vector3(-2.45, -0.17, 0.0))
		keys.append(Vector3(-1.75, -0.08, 14.0))
		keys.append(Vector3(-1.15, 0.02, 2.0))
		keys.append(Vector3(-0.6, -0.12, -38.0))
		keys.append(Vector3(-0.26, -0.52, -80.0))
		keys.append(Vector3(-0.14, -1.0, -90.0))
		_exit_keys(keys, 1.0, -1.0)
	else:
		# SOLA DÖNÜŞ: virajın dışı sağ. Ortada kalır, çalım: sağa açılır, sonra geniş yayla sola (kavşağın ortasından)
		keys.append(Vector3(-2.45, -0.04, 0.0))
		keys.append(Vector3(-1.8, -0.07, -12.0))
		keys.append(Vector3(-1.2, -0.11, -2.0))
		keys.append(Vector3(-0.55, -0.04, 30.0))
		keys.append(Vector3(-0.05, 0.38, 70.0))
		keys.append(Vector3(0.1, 0.95, 90.0))
		_exit_keys(keys, 0.95, 1.0)
	return keys


## Çıkış yolu anahtar noktaları: çıkış yönünde (b ekseni) ilerler, yanal salınım a ekseninde. `own`: çıkış şeridinin
## yanı (sağa dönüşte −a, sola dönüşte +a); salınım yolun ortası çevresinde, şerit yanına biraz yakın.
func _exit_keys(keys: Array[Vector3], from_b: float, sign_b: float) -> void:
	var heading: float = 90.0 * sign_b
	var own: float = sign_b
	var b: float = from_b + MANJI_HALF
	var wide: bool = true
	while b < from_b + MANJI_END:
		keys.append(Vector3((0.08 if wide else -0.05) * own, b * sign_b, heading))
		wide = not wide
		b += MANJI_HALF
	keys.append(Vector3(0.12 * own, (b + MANJI_HALF) * sign_b, heading))
	keys.append(Vector3(0.2 * own, REACH * sign_b, heading))


## Anahtar noktalardan yoğun çizgi (Hermite; teğet boyu kiriş × 0,5 · 1,0), eğrilik ve viraj ağırlığı.
func _build_path(keys: Array[Vector3]) -> void:
	points.clear()
	for k: int in keys.size() - 1:
		var p0: Vector3 = to_world(keys[k].x, keys[k].y)
		var p1: Vector3 = to_world(keys[k + 1].x, keys[k + 1].y)
		var chord: float = p0.distance_to(p1)
		var m0: Vector3 = _dir_world(keys[k].z) * chord
		var m1: Vector3 = _dir_world(keys[k + 1].z) * chord
		var steps: int = maxi(int(ceil(chord / (STEP * 0.5))), 2)
		for i: int in steps:
			var t: float = float(i) / float(steps)
			points.append(_hermite(p0, m0, p1, m1, t))
	points.append(to_world(keys[keys.size() - 1].x, keys[keys.size() - 1].y))
	_resample()
	var n: int = points.size()
	headings.resize(n)
	curvature.resize(n)
	for i: int in n:
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, n - 1)]
		headings[i] = atan2(b.x - a.x, b.z - a.z)
	for i: int in n:
		var i0: int = maxi(i - 3, 0)
		var i1: int = mini(i + 3, n - 1)
		var ds: float = lengths[i1] - lengths[i0]
		curvature[i] = angle_difference(headings[i0], headings[i1]) / ds if ds > 0.0001 else 0.0
	# Eğrilik yumuşatılır (iki kez kutu süzgeç, ±CURVE_SMOOTH): Hermite parçalarının eklemlerindeki dalgalanma kaymayı
	# virajın ortasında boşaltıp yeniden dolduruyordu (araç virajda "tökezliyordu")
	for pass_i: int in 2:
		curvature = _box(curvature, int(CURVE_SMOOTH / STEP))
	# Viraj: kavşak merkezine 1,1'den yakın kısım; ağırlık eğrilik büyüklüğünden (tandem yaklaşır, kayma sınırı büyür)
	corner_from = -1.0
	corner_weight.resize(n)
	for i: int in n:
		var near: bool = TrafficVehicle._flat(points[i] - CENTER).length() < 1.1
		if near and corner_from < 0.0:
			corner_from = lengths[i]
		if near:
			corner_to = lengths[i]
		corner_weight[i] = smoothstep(0.55, 0.95, absf(curvature[i])) if near else 0.0
	# Ağırlık yumuşak yayılır (savruluş öncesi / sonrası da biraz): iki kez kutu süzgeç, sonra tepe yeniden 1'e. Eskiden
	# basamaklı (3 örnekte bir) en büyük değer süzgeciydi: arkadaki aracın tandem mesafesi kare kare sıçrıyordu
	for pass_i: int in 2:
		corner_weight = _box(corner_weight, int(0.3 / STEP))
	var peak: float = 0.0
	for i: int in n:
		peak = maxf(peak, corner_weight[i])
	if peak > 0.001:
		for i: int in n:
			corner_weight[i] = minf(corner_weight[i] / peak, 1.0)


## Kutu süzgeç (yarıçap `r` örnek; uçlarda pencere kısalır).
static func _box(values: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var n: int = values.size()
	var prefix: PackedFloat64Array = PackedFloat64Array()
	prefix.resize(n + 1)
	prefix[0] = 0.0
	for i: int in n:
		prefix[i + 1] = prefix[i] + values[i]
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i: int in n:
		var a: int = maxi(i - r, 0)
		var b: int = mini(i + r, n - 1)
		out[i] = float((prefix[b + 1] - prefix[a]) / float(b - a + 1))
	return out


## Çizgiyi eşit STEP aralıkla yeniden örnekler (lengths de dolar).
func _resample() -> void:
	var raw: PackedVector3Array = points
	var out: PackedVector3Array = PackedVector3Array([raw[0]])
	var carry: float = 0.0
	for i: int in range(1, raw.size()):
		var a: Vector3 = raw[i - 1]
		var b: Vector3 = raw[i]
		var seg: float = a.distance_to(b)
		var at: float = STEP - carry
		while at <= seg:
			out.append(a.lerp(b, at / seg))
			at += STEP
		carry = seg - (at - STEP)
	points = out
	lengths.resize(points.size())
	for i: int in points.size():
		lengths[i] = float(i) * STEP
	length = lengths[lengths.size() - 1]


func _dir_world(degrees: float) -> Vector3:
	var left: Vector3 = Vector3.UP.cross(entry_dir)
	var r: float = deg_to_rad(degrees)
	return entry_dir * cos(r) + left * sin(r)


static func _hermite(p0: Vector3, m0: Vector3, p1: Vector3, m1: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return p0 * (2.0 * t3 - 3.0 * t2 + 1.0) + m0 * (t3 - 2.0 * t2 + t) + p1 * (-2.0 * t3 + 3.0 * t2) + m1 * (t3 - t2)


## Hız profili: yanal tutuşa göre üst sınır, sonra ileri (gaz) ve geri (fren) geçişle ivme sınırı.
func _build_speeds() -> void:
	var n: int = points.size()
	speeds.resize(n)
	for i: int in n:
		var k: float = 0.0
		for j: int in range(maxi(i - 8, 0), mini(i + 8, n - 1) + 1, 2):
			k = maxf(k, absf(curvature[j]))
		speeds[i] = clampf(sqrt(LATERAL_GRIP / maxf(k, 0.001)), MIN_SPEED, TOP_SPEED)
	for i: int in range(1, n):
		speeds[i] = minf(speeds[i], sqrt(speeds[i - 1] * speeds[i - 1] + 2.0 * ACCEL * STEP))
	for i: int in range(n - 2, -1, -1):
		speeds[i] = minf(speeds[i], sqrt(speeds[i + 1] * speeds[i + 1] + 2.0 * BRAKE * STEP))


## Yol üzerinde `s`'teki kesirli sıra.
func _at(s: float) -> float:
	return clampf(s / STEP, 0.0, float(points.size() - 1))


func point_at(s: float) -> Vector3:
	var at: float = _at(s)
	var i: int = int(at)
	var j: int = mini(i + 1, points.size() - 1)
	return points[i].lerp(points[j], at - float(i))


func heading_at(s: float) -> float:
	var at: float = _at(s)
	var i: int = int(at)
	var j: int = mini(i + 1, points.size() - 1)
	return lerp_angle(headings[i], headings[j], at - float(i))


func _channel(channel: PackedFloat32Array, s: float) -> float:
	var at: float = _at(s)
	var i: int = int(at)
	var j: int = mini(i + 1, channel.size() - 1)
	return lerpf(channel[i], channel[j], at - float(i))


func curvature_at(s: float) -> float:
	return _channel(curvature, s)


func speed_at(s: float) -> float:
	return _channel(speeds, s)


func corner_at(s: float) -> float:
	return _channel(corner_weight, s)


## Öndeki aracın çizelgesi: `start_s`'ten başlar, çizginin sonuna (ya da `max_time`) kadar.
func lead_track(id: StringName, start_s: float, max_time: float = 40.0) -> Track:
	var s_list: PackedFloat32Array = PackedFloat32Array()
	var s: float = start_s
	var t: float = 0.0
	while s < length - 0.01 and t <= max_time:
		s_list.append(s)
		s += speed_at(s) * DT
		t += DT
	return _track(id, s_list)


## Arkadaki aracın çizelgesi: kendi hız profiliyle sürer; öndekiyle arasındaki yol mesafesi TANDEM_GAP'e (virajda
## TANDEM_GAP_CORNER'a) yumuşakça çekilir. Öndeki bittiğinde de çizginin sonuna kadar sürer.
func follow_track(id: StringName, lead: Track) -> Track:
	var s_list: PackedFloat32Array = PackedFloat32Array()
	if lead.s.is_empty():
		return _track(id, s_list)
	var s: float = maxf(lead.s[0] - TANDEM_GAP, 0.0)
	var goal: float = TANDEM_GAP
	var ease: float = 1.0 - exp(-TANDEM_EASE * DT)
	for i: int in lead.s.size():
		s_list.append(s)
		goal = lerpf(goal, lerpf(TANDEM_GAP, TANDEM_GAP_CORNER, corner_at(lead.s[i])), ease)
		var own: float = speed_at(s)
		var v: float = clampf(own + TANDEM_PULL * (lead.s[i] - s - goal), own * 0.7, own * 1.35)
		s = minf(s + v * DT, lead.s[i] - 0.5)
	while s < length - 0.01 and s_list.size() < 6000:
		s_list.append(s)
		s += speed_at(s) * DT
	return _track(id, s_list)


## Yol konumları dizisinden poz çizelgesi: kayma yayı, karşı direksiyon, yatış, tekerlek, yoğunluk, motor.
func _track(id: StringName, s_list: PackedFloat32Array) -> Track:
	var track: Track = Track.new()
	track.id = id
	track.s = s_list
	track.start_s = s_list[0] if not s_list.is_empty() else 0.0
	var beta: float = 0.0
	var beta_v: float = 0.0
	var eased_speed: float = speed_at(track.start_s)
	var last_speed: float = eased_speed
	var roll: float = 0.0
	var pitch: float = 0.0
	var pose_ease: float = 1.0 - exp(-POSE_EASE * DT)
	var front: float = 0.0
	var rear: float = 0.0
	var throttle: float = 0.9
	var rpm: float = 0.82
	var limiter_time: float = 0.0
	var radius: float = TrafficVehicle.WHEEL_RADIUS * 0.6
	for i: int in s_list.size():
		var s: float = s_list[i]
		var v: float = (s_list[i] - s_list[i - 1]) / DT if i > 0 else speed_at(s)
		var k_ahead: float = curvature_at(s + LOOK_AHEAD)
		var limit: float = lerpf(MANJI_MAX, CORNER_MAX, corner_at(s))
		var target: float = clampf(SLIP_GAIN * k_ahead, -limit, limit) * smoothstep(0.35, 0.9, v)
		beta_v += (SLIP_FREQ * SLIP_FREQ * (target - beta) - 2.0 * SLIP_DAMP * SLIP_FREQ * beta_v) * DT
		beta += beta_v * DT
		var travel: float = heading_at(s)
		var yaw: float = travel + beta
		var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
		var center: Vector3 = point_at(s) - forward * PIVOT
		eased_speed = lerpf(eased_speed, v, pose_ease)
		var accel: float = (eased_speed - last_speed) / DT
		last_speed = eased_speed
		var lateral: float = v * v * curvature_at(s)
		front += rad_to_deg(v * DT / radius)
		var slide: float = smoothstep(0.1, 0.5, absf(beta)) * smoothstep(0.35, 0.85, v)
		rear += rad_to_deg(v * DT / radius) * lerpf(1.0, WHEEL_SPIN, slide)
		# Gaz: kayarken tam; geçişte (kayma hızla yön değiştirirken) yarıya iner, çalımda kesilip yeniden basılır
		var flick: float = clampf(absf(beta_v) / 3.2, 0.0, 1.0)
		var throttle_goal: float = lerpf(1.0, 0.35, flick) if slide > 0.05 else 0.85
		throttle = lerpf(throttle, throttle_goal, 1.0 - exp(-14.0 * DT))
		var rpm_goal: float = lerpf(0.74, 0.97, throttle) + 0.025 * sin(float(i) * DT * 41.0) * slide
		rpm = lerpf(rpm, rpm_goal, 1.0 - exp(-(10.0 if rpm_goal > rpm else 6.0) * DT))
		limiter_time = limiter_time + DT if rpm > 0.955 else 0.0
		track.position.append(Vector3(center.x, 0.0, center.z))
		track.yaw.append(yaw)
		track.travel.append(travel)
		track.slip.append(beta)
		track.slip_rate.append(beta_v)
		track.speed.append(v)
		track.steer.append(clampf(rad_to_deg(-beta) * COUNTER_STEER, -STEER_LIMIT, STEER_LIMIT))
		roll = lerpf(roll, clampf(lateral * ROLL_GAIN, -ROLL_LIMIT, ROLL_LIMIT), pose_ease)
		pitch = lerpf(pitch, clampf(-accel * PITCH_GAIN - 0.012 * throttle * slide, -PITCH_LIMIT, PITCH_LIMIT), pose_ease)
		track.roll.append(roll)
		track.pitch.append(pitch)
		track.front_spin.append(front)
		track.rear_spin.append(rear)
		track.intensity.append(slide)
		track.throttle.append(throttle)
		track.rpm.append(minf(rpm, 1.0) if limiter_time < 0.35 else 1.0)
	return track


## Bir dikdörtgen gövdenin (merkez, yön, yarı boy, yarı en) dört köşesi (y = 0).
static func corners(center: Vector3, yaw: float, half_length: float, half_width: float) -> PackedVector3Array:
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var left: Vector3 = Vector3.UP.cross(forward)
	var out: PackedVector3Array = PackedVector3Array()
	for f: float in [1.0, -1.0]:
		for l: float in [1.0, -1.0]:
			out.append(center + forward * half_length * f + left * half_width * l)
	return out


## İki eşit dikdörtgen gövdenin (merkez, yön) yaklaşık arası: bir gövdenin köşelerinin öbür kutuya en kısa uzaklığı
## (iki yönde); negatif = iç içe. Test / QA için.
static func box_gap(c1: Vector3, yaw1: float, c2: Vector3, yaw2: float, half_length: float, half_width: float) -> float:
	var best: float = INF
	for pair: Array in [[c1, yaw1, c2, yaw2], [c2, yaw2, c1, yaw1]]:
		var center: Vector3 = pair[2]
		var forward: Vector3 = Vector3(sin(float(pair[3])), 0.0, cos(float(pair[3])))
		var left: Vector3 = Vector3.UP.cross(forward)
		for c: Vector3 in corners(pair[0], pair[1], half_length, half_width):
			var rel: Vector3 = c - center
			var dx: float = absf(rel.dot(forward)) - half_length
			var dz: float = absf(rel.dot(left)) - half_width
			best = minf(best, Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length() + minf(maxf(dx, dz), 0.0))
	return best


## Nokta yolda mı (iki yolun "artı" biçimli alanı; kaldırım payı `margin`)?
static func on_road(point: Vector3, margin: float = 0.0) -> bool:
	var dx: float = absf(point.x - CENTER.x)
	var dz: float = absf(point.z - CENTER.z)
	return dx <= ROAD_HALF - margin or dz <= ROAD_HALF - margin
