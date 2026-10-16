class_name StreetMesh
extends RefCounted
## Şehir donatısı (trafik lambası, billboard) için KÖŞE RENKLİ tek gövde: kutular ve silindirler bir SurfaceTool'a
## eklenir, tek malzemeyle (vertex_color_use_as_albedo) çizilir — parça sayısından bağımsız TEK çizim çağrısı.
## Renkler sRGB verilir (malzeme albedo'su gibi); ışık alır, gölge düşürür.

var _st: SurfaceTool = SurfaceTool.new()
var _empty: bool = true


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## Eksen hizalı kutu: `xform` kutunun merkezini ve yönünü verir.
func box(size: Vector3, xform: Transform3D, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var faces: Array[Array] = [
		[Vector3.RIGHT, [Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)]],
		[Vector3.LEFT, [Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3.UP, [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)]],
		[Vector3.DOWN, [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
		[Vector3.BACK, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]],
		[Vector3.FORWARD, [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]],
	]
	for face: Array in faces:
		var corners: Array = face[1]
		_quad(xform * (corners[0] as Vector3), xform * (corners[1] as Vector3), xform * (corners[2] as Vector3),
			xform * (corners[3] as Vector3), (xform.basis * (face[0] as Vector3)).normalized(), color)


## Dik silindir (Y ekseni boyunca, `xform` merkezde); `cap` false ise kapaklar çizilmez.
func cylinder(radius: float, height: float, xform: Transform3D, color: Color, segments: int = 10, cap: bool = true) -> void:
	var h: float = height * 0.5
	for i: int in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var p0: Vector3 = Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1: Vector3 = Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var n: Vector3 = (xform.basis * Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))).normalized()
		_quad(xform * (p1 + Vector3(0.0, -h, 0.0)), xform * (p0 + Vector3(0.0, -h, 0.0)),
			xform * (p0 + Vector3(0.0, h, 0.0)), xform * (p1 + Vector3(0.0, h, 0.0)), n, color)
		if cap:
			var up: Vector3 = (xform.basis * Vector3.UP).normalized()
			_tri(xform * Vector3(0.0, h, 0.0), xform * (p1 + Vector3(0.0, h, 0.0)), xform * (p0 + Vector3(0.0, h, 0.0)), up, color)


## Yüzü `xform`un +Z yönüne bakan yassı disk (trafik lambası camı gibi).
func disc(radius: float, xform: Transform3D, color: Color, segments: int = 14) -> void:
	var n: Vector3 = (xform.basis * Vector3.BACK).normalized()
	for i: int in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		_tri(xform * Vector3.ZERO, xform * Vector3(cos(a0) * radius, sin(a0) * radius, 0.0),
			xform * Vector3(cos(a1) * radius, sin(a1) * radius, 0.0), n, color)


func is_empty() -> bool:
	return _empty


func commit() -> ArrayMesh:
	return _st.commit()


## Gövdenin malzemesi: köşe rengi albedo, mat.
static func material(unshaded: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## a-b-c-d saat yönünün tersine (normal tarafından bakınca); Godot ön yüzü saat yönünde ister → ters eklenir.
func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	_tri(a, b, c, normal, color)
	_tri(a, c, d, normal, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	_empty = false
	for p: Vector3 in [a, c, b]:
		_st.set_normal(normal)
		_st.set_color(color)
		_st.add_vertex(p)
