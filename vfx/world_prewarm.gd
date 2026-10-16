class_name WorldPrewarm
## DÜNYA EFEKTLERİNİN ÖN ISITMASI — ilk tamirdeki takılmayı önler (2026-10-11, qa/repair_hitch.gd).
##
## Ölçüldü (masaüstü): ilk TAMİRE AL'dan sonraki ilk kare 29 ms (sonrakilerde 15), ilk kıvılcım vuruşu
## 27 ms. İkisi de İLK KULLANIM maliyeti: oturumdaki ilk yazılı araç balonu ("TAMİR" — yoldaki müşteri
## balonları yalnızca ikon) ve tamir efekti malzemeleri ilk kez çizilirken shader derleniyor. Telefonda
## bu 5-10 kat; yeni oyuncunun İLK yaptığı iş tamir.
##
## Çözüm: oyun açılırken aynı düğümler (yazılı balon, kıvılcım / duman yayıcıları, bitiş halkası, para)
## kameranın baktığı yerin ZEMİN ALTINDA birkaç kare çizilip silinir (parçacıklar zeminin hemen üstünde,
## neredeyse saydam). Balonun yazısı derinlik testsiz çizildiği için neredeyse saydam basılır.
## SONUÇ (qa/repair_hitch.gd): yazılı balonun ilk kare takılması kalktı (29 → 14 ms). İlk kıvılcım vuruşunda
## ~5-10 ms'lik küçük bir ilk-kullanım maliyeti KALDI — birebir aynı yayıcıyı ısıtmak onu gidermedi (kaynağı
## bulunamadı, birkaç küçük kalemin toplamı: kıvılcım kapalıyken de 22 ms'lik kare ölçüldü).

const FRAMES: int = 8
const DEPTH: float = 0.6   # zeminin bu kadar altında


static func run(tree: SceneTree) -> void:
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	var scene: Node = tree.current_scene
	if camera == null or scene == null:
		return
	# Kameranın baktığı zemin noktası (y = 0 düzlemi)
	var forward: Vector3 = -camera.global_basis.z
	var focus: Vector3 = camera.global_position
	if absf(forward.y) > 0.01:
		focus = camera.global_position + forward * (-camera.global_position.y / forward.y)
	var root: Node3D = Node3D.new()
	root.name = "WorldPrewarm"
	scene.add_child(root)
	root.global_position = focus - Vector3(0.0, DEPTH, 0.0)

	var bubble: CarBubble = CarBubble.new()
	root.add_child(bubble)
	bubble.show_text(Loc.t("TAMİR"), CarBubble.GLYPH_WRENCH)
	var label: Label3D = bubble.get_node_or_null(^"Text") as Label3D
	if label:
		label.modulate.a = 0.02
	for emitter: CPUParticles3D in [RepairFx.make_sparks(), RepairFx.make_smoke()]:
		emitter.color_ramp = CrateRevealFx.fade_ramp(Color(1, 1, 1, 0.01), 0.3)
		emitter.position = Vector3(0.0, DEPTH + 0.05, 0.0)
		root.add_child(emitter)
		emitter.restart()
	var ring: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	ring.material_override = CrateRevealFx.additive(CrateRevealFx.ring_texture())
	root.add_child(ring)
	var coin: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 0.01
	coin.mesh = cylinder
	coin.material_override = RepairFx.gold_material()
	root.add_child(coin)
	for node: Node3D in PoliceLights.prewarm_nodes():   # ilk polis aracı trafiğe girerken shader derlenmesin
		root.add_child(node)
	for i: int in FRAMES:
		await tree.process_frame
	if is_instance_valid(root):
		root.queue_free()
