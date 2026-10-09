class_name RaceProgressBar
extends Control
## DRAG İLERLEME ÇUBUĞU — ekranın üstünde ince bir pist şeridi: iki aracın GERÇEK ilerlemesi
## (0-1) ve sonunda damalı bitiş. Pistte araçlar arası fark kadraj için yumuşatılır; burada
## yumuşatma yok, kim öndeyse çubukta da öndedir (çekişme hissi).
## REKOR HAYALETİ: oyuncunun bu araçla en iyi koşusunun aynı andaki yeri (içi boş halka);
## önündeysen rekor temposundasın. -1 = rekor yok (çizilmez).
## Yalnızca çizim yapar; değerleri DragRaceScreen verir.

const TRACK_HEIGHT: float = 6.0
const DOT_RADIUS: float = 8.0
const FLAG_CELLS: int = 3

var player: float = 0.0:
	set(value):
		player = clampf(value, 0.0, 1.0)
		queue_redraw()
var rival: float = 0.0:
	set(value):
		rival = clampf(value, 0.0, 1.0)
		queue_redraw()
var ghost: float = -1.0:
	set(value):
		ghost = clampf(value, -1.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, 24.0)


func _draw() -> void:
	var flag_w: float = TRACK_HEIGHT * 2.0
	var left: float = DOT_RADIUS + 2.0
	var right: float = size.x - DOT_RADIUS - flag_w - 4.0
	var mid: float = size.y * 0.5
	# Pist: koyu kontur + koyu şerit + oyuncunun kat ettiği amber dolgu
	var track: Rect2 = Rect2(left, mid - TRACK_HEIGHT * 0.5, right - left, TRACK_HEIGHT)
	draw_rect(track.grow(2.0), HudPalette.TEXT_OUTLINE)
	draw_rect(track, HudPalette.LANE_TRACK)
	draw_rect(Rect2(track.position, Vector2(track.size.x * player, TRACK_HEIGHT)), HudPalette.LANE_PAINT)
	# Damalı bitiş
	var cell: float = (TRACK_HEIGHT + 4.0) / float(FLAG_CELLS)
	var flag_x: float = right + 3.0
	for row: int in FLAG_CELLS:
		for col: int in 2:
			var dark: bool = (row + col) % 2 == 0
			draw_rect(Rect2(flag_x + float(col) * cell * 1.2, mid - (TRACK_HEIGHT + 4.0) * 0.5 + float(row) * cell,
				cell * 1.2, cell), HudPalette.INK if dark else HudPalette.TEXT_LIGHT)
	# Hayalet: krem, içi boş halka (oyuncunun altında kalır)
	if ghost >= 0.0:
		var gx: float = lerpf(left, right, ghost)
		draw_arc(Vector2(gx, mid), DOT_RADIUS - 1.0, 0.0, TAU, 24, HudPalette.TEXT_OUTLINE, 4.0, true)
		draw_arc(Vector2(gx, mid), DOT_RADIUS - 1.0, 0.0, TAU, 24, HudPalette.TEXT_LIGHT, 2.0, true)
	# Rakip önce (oyuncu üstte kalsın): gri nokta; oyuncu amber, krem halkalı
	_dot(lerpf(left, right, rival), mid, HudPalette.INK_SOFT, HudPalette.TEXT_LIGHT)
	_dot(lerpf(left, right, player), mid, HudPalette.PLATE_SELECTED, HudPalette.INK)


func _dot(x: float, y: float, fill: Color, ring: Color) -> void:
	draw_circle(Vector2(x, y), DOT_RADIUS, ring)
	draw_circle(Vector2(x, y), DOT_RADIUS - 2.5, fill)
