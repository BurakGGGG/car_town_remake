extends SceneTree
## REELS KAPAK — 1080x1920 dikey görsel: oyundan alınmış geniş garaj / showroom karesi hafif bulanık ve solgun
## arka plan, üst üçte birde AUTO YARD logosu (assets/branding/autoyard_logo.png, şeffaf). Yazı eklenmez.
##   godot-4 --headless --path . --script qa/teaser/reels_kapak.gd -- <arka_plan.png> <çıktı.png>
## Arka plan: reels_galeri.gd "foto" kipi (oyun kamerası açısı, 1080x1920).
const LOGO: String = "res://assets/branding/autoyard_logo.png"
const W: int = 1080
const H: int = 1920
## Bulanıklık: arka plan bu kata küçültülüp geri büyütülür (yumuşak, hafif).
const BLUR_DIV: int = 4
## Solgunluk: parlaklık / kontrast / doygunluk + üstüne beyaz perde.
const BCS: Vector3 = Vector3(1.04, 0.9, 0.88)
const VEIL: float = 0.12
## Üst geçiş: logonun durduğu alan sakin olsun, haritanın uzak kenarı erisin (renk, tepede opaklık, bitiş oranı).
const TOP_FADE: Color = Color("#7fb35a")
const TOP_ALPHA: float = 0.7
const TOP_END: float = 0.42
## Logo: genişlik ve dikey merkez (kare yüksekliğinin oranı).
const LOGO_W: int = 940
const LOGO_Y: float = 0.2


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var bg: Image = Image.load_from_file(args[0])
	bg.convert(Image.FORMAT_RGBA8)
	bg.resize(W / BLUR_DIV, H / BLUR_DIV, Image.INTERPOLATE_LANCZOS)
	bg.resize(W, H, Image.INTERPOLATE_CUBIC)
	bg.adjust_bcs(BCS.x, BCS.y, BCS.z)
	var veil: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	veil.fill(Color(1.0, 1.0, 1.0, VEIL))
	bg.blend_rect(veil, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var fade: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y: int in roundi(H * TOP_END):
		var k: float = 1.0 - float(y) / (H * TOP_END)
		fade.fill_rect(Rect2i(0, y, W, 1), Color(TOP_FADE, TOP_ALPHA * k * k * (3.0 - 2.0 * k)))
	bg.blend_rect(fade, Rect2i(0, 0, W, H), Vector2i.ZERO)
	var logo: Image = (load(LOGO) as Texture2D).get_image()
	logo.decompress()
	logo.convert(Image.FORMAT_RGBA8)
	print("KAPAK logo ", logo.get_size(), " köşe alfa ", logo.get_pixel(0, 0).a)
	var lh: int = roundi(float(LOGO_W) * float(logo.get_height()) / float(logo.get_width()))
	logo.resize(LOGO_W, lh, Image.INTERPOLATE_LANCZOS)
	bg.blend_rect(logo, Rect2i(0, 0, LOGO_W, lh), Vector2i((W - LOGO_W) / 2, roundi(H * LOGO_Y) - lh / 2))
	bg.convert(Image.FORMAT_RGB8)
	bg.save_png(args[1])
	print("KAPAK yazıldı ", args[1])
	quit(0)
