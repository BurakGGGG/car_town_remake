class_name ModDyno
extends Control
## MODİFİYE — kategori ekranının DİNAMOMETRESİ: parçanın ne kadar faydalı olduğunu ÇİZER.
##   Değer çubukları (0-100, son hız, güç, 300 m): çubuğun solu fabrika, sağ ucu bu aracın FULL yapısı (30 parça).
##     koyu dolgu  = şu anki yapı
##     yeşil       = seçilen parçanın getireceği (önce → sonra)
##     kesik çizgi = bu kategori EFSANE'ye kadar giderse ulaşılacak yer (kategorinin potansiyeli)
##   Güç eğrisi (yalnız MOTOR / TURBO / HAVA AKIŞI): devir → beygir; şimdiki eğri mürekkep, takınca olacak yeşil.
## Mantık yok: ModWorkshop hazır sayıları set_data ile verir. Sabit boyutlu, kodla çizilir (TextureRect yok).

const ROW_HEIGHT: float = 31.0
const BAR_HEIGHT: float = 9.0
const CURVE_HEIGHT: float = 96.0
const LEGEND_HEIGHT: float = 16.0
const GAIN: Color = Color("3FA45F")
const GAIN_LIGHT: Color = Color("7ED89A")
const TRACK: Color = Color(0.184, 0.196, 0.212, 0.12)
const NOW: Color = Color("5A5E64")

## {"rows": [{label, now, after, delta, frac_now, frac_after, frac_cap}], "curve_now", "curve_after",
##  "peak_now", "peak_after", "peak_rpm_after", "accent": Color}
var data: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, ROW_HEIGHT * 4.0)


func set_data(value: Dictionary) -> void:
	data = value
	var rows: int = (data.get("rows", []) as Array).size()
	var curve: bool = data.has("curve_now")
	custom_minimum_size = Vector2(custom_minimum_size.x,
		ROW_HEIGHT * rows + LEGEND_HEIGHT + (CURVE_HEIGHT + 22.0 if curve else 0.0))
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var font: Font = get_theme_font(&"font", &"Label")
	var small: int = 10
	var big: int = 12
	var w: float = size.x
	var y: float = 0.0
	var accent: Color = data.get("accent", GAIN)
	for row: Dictionary in data.get("rows", []):
		# Satır: başlık · şimdi → sonra · fark
		draw_string(font, Vector2(0.0, y + 12.0), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, small,
			HudPalette.INK_SOFT)
		var delta: String = String(row.get("delta", ""))
		var value: String = String(row["now"]) if String(row["after"]) == String(row["now"]) \
			else "%s → %s" % [row["now"], row["after"]]
		var delta_width: float = font.get_string_size(delta, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x if delta != "" else 0.0
		draw_string(font, Vector2(0.0, y + 13.0), value, HORIZONTAL_ALIGNMENT_RIGHT, w - delta_width - 8.0, big,
			HudPalette.INK)
		if delta != "":
			var pill: Rect2 = Rect2(w - delta_width - 6.0, y + 1.0, delta_width + 6.0, 15.0)
			draw_rect(pill, GAIN if bool(row.get("better", true)) else HudPalette.DANGER)
			draw_string(font, Vector2(pill.position.x + 3.0, y + 12.5), delta, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				HudPalette.TEXT_LIGHT)
		# Çubuk
		var bar: Rect2 = Rect2(0.0, y + 19.0, w, BAR_HEIGHT)
		draw_rect(bar, TRACK)
		var now_x: float = w * clampf(float(row["frac_now"]), 0.0, 1.0)
		var after_x: float = w * clampf(float(row["frac_after"]), 0.0, 1.0)
		var cap_x: float = w * clampf(float(row.get("frac_cap", row["frac_after"])), 0.0, 1.0)
		if cap_x > after_x + 1.0:   # kategorinin potansiyeli: kesik çerçeve
			_dashed_box(Rect2(after_x, bar.position.y, cap_x - after_x, BAR_HEIGHT), Color(accent, 0.9))
		draw_rect(Rect2(0.0, bar.position.y, now_x, BAR_HEIGHT), NOW)
		if after_x > now_x + 0.5:
			draw_rect(Rect2(now_x, bar.position.y, after_x - now_x, BAR_HEIGHT), GAIN)
			draw_rect(Rect2(now_x, bar.position.y, after_x - now_x, 3.0), GAIN_LIGHT)
		y += ROW_HEIGHT
	_draw_legend(font, Vector2(0.0, y - 4.0), accent)
	y += LEGEND_HEIGHT
	if data.has("curve_now"):
		_draw_curve(font, Rect2(0.0, y + 4.0, w, CURVE_HEIGHT))


## Dinamometre: eksenler, şimdiki eğri, takınca olacak eğri (altı dolgulu) ve tepe gücü.
func _draw_curve(font: Font, area: Rect2) -> void:
	var now: PackedVector2Array = data["curve_now"]
	var after: PackedVector2Array = data.get("curve_after", now)
	if now.size() < 2:
		return
	var rpm_max: float = maxf(now[now.size() - 1].x, after[after.size() - 1].x)
	var rpm_min: float = minf(now[0].x, after[0].x)
	var hp_max: float = 0.0
	for p: Vector2 in now:
		hp_max = maxf(hp_max, p.y)
	for p: Vector2 in after:
		hp_max = maxf(hp_max, p.y)
	hp_max *= 1.12
	var plot: Rect2 = Rect2(area.position + Vector2(0.0, 14.0), area.size - Vector2(0.0, 28.0))
	draw_rect(plot, Color(HudPalette.INK, 0.05))
	for i: int in range(1, 4):   # yatay kılavuz çizgileri
		var gy: float = plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(HudPalette.INK, 0.08), 1.0)
	var to_screen: Callable = func(p: Vector2) -> Vector2:
		return Vector2(plot.position.x + plot.size.x * inverse_lerp(rpm_min, rpm_max, p.x),
			plot.end.y - plot.size.y * p.y / maxf(hp_max, 1.0))
	var after_line: PackedVector2Array = PackedVector2Array()
	var fill: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in after:
		var s: Vector2 = to_screen.call(p)
		after_line.append(s)
		fill.append(s)
	fill.append(Vector2(after_line[after_line.size() - 1].x, plot.end.y))
	fill.append(Vector2(after_line[0].x, plot.end.y))
	draw_colored_polygon(fill, Color(GAIN, 0.16))
	var now_line: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in now:
		now_line.append(to_screen.call(p))
	draw_polyline(now_line, Color(HudPalette.INK, 0.55), 2.0, true)
	draw_polyline(after_line, GAIN, 2.5, true)
	# Tepe noktası
	var peak_rpm: float = float(data.get("peak_rpm_after", 0.0))
	var peak: float = float(data.get("peak_after", 0.0))
	var dot: Vector2 = to_screen.call(Vector2(peak_rpm, peak))
	draw_circle(dot, 4.0, GAIN, true, -1.0, true)
	draw_circle(dot, 4.0, HudPalette.TEXT_LIGHT, false, 1.5, true)
	draw_string(font, Vector2(area.position.x, area.position.y + 10.0), Loc.t("GÜÇ EĞRİSİ"), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, HudPalette.INK_SOFT)
	var peak_text: String = Loc.t("%d bg @ %s d/dk") % [roundi(peak), Hud.format_thousands(roundi(peak_rpm / 100.0) * 100)]
	draw_string(font, Vector2(area.position.x, area.position.y + 10.0), peak_text, HORIZONTAL_ALIGNMENT_RIGHT,
		area.size.x, 10, GAIN.darkened(0.25))
	var mid: float = plot.position.x + plot.size.x * 0.5
	draw_line(Vector2(mid - 58.0, plot.end.y + 8.0), Vector2(mid - 46.0, plot.end.y + 8.0), Color(HudPalette.INK, 0.55), 2.0)
	draw_string(font, Vector2(mid - 43.0, plot.end.y + 12.0), Loc.t("şimdi"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HudPalette.INK_SOFT)
	draw_line(Vector2(mid + 2.0, plot.end.y + 8.0), Vector2(mid + 14.0, plot.end.y + 8.0), GAIN, 2.5)
	draw_string(font, Vector2(mid + 17.0, plot.end.y + 12.0), Loc.t("takınca"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HudPalette.INK_SOFT)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 12.0), Hud.format_thousands(roundi(rpm_min / 100.0) * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HudPalette.INK_SOFT)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 12.0), Loc.t("%s d/dk") % Hud.format_thousands(roundi(rpm_max / 100.0) * 100),
		HORIZONTAL_ALIGNMENT_RIGHT, plot.size.x, 9, HudPalette.INK_SOFT)


## Çubukların açıklaması: şimdi · kazanç · kategorinin EFSANE'ye kadar potansiyeli (sağ uç FULL yapı).
func _draw_legend(font: Font, at: Vector2, accent: Color) -> void:
	var x: float = at.x
	for item: Array in [[NOW, Loc.t("şimdi")], [GAIN, Loc.t("bu parça")], [accent, Loc.t("kategori EFSANE")]]:
		var swatch: Rect2 = Rect2(x, at.y + 4.0, 12.0, 7.0)
		if item[0] == accent:
			_dashed_box(swatch, accent)
		else:
			draw_rect(swatch, item[0])
		draw_string(font, Vector2(x + 16.0, at.y + 11.0), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			HudPalette.INK_SOFT)
		x += 16.0 + font.get_string_size(String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
	draw_string(font, Vector2(at.x, at.y + 11.0), Loc.t("sağ uç: FULL"), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 9,
		HudPalette.INK_SOFT)


func _dashed_box(rect: Rect2, color: Color) -> void:
	var dash: float = 4.0
	var x: float = rect.position.x
	while x < rect.end.x:
		var x2: float = minf(x + dash, rect.end.x)
		draw_line(Vector2(x, rect.position.y), Vector2(x2, rect.position.y), color, 1.5)
		draw_line(Vector2(x, rect.end.y), Vector2(x2, rect.end.y), color, 1.5)
		x += dash * 2.0
	draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), color, 1.5)
