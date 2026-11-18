# SPDX-License-Identifier: GPL-3.0-or-later
# Line icons drawn as vectors, so they stay sharp on every screen. Drawn on a 24×24 grid.
class_name Glyph
extends Control

var icon := ""
var color := Color.WHITE
var stroke := 1.8

var _k := 1.0
var _o := Vector2.ZERO
var _w := 1.0


static func make(icon_: String, px: float, col: Color) -> Glyph:
	var g := Glyph.new()
	g.icon = icon_
	g.color = col
	g.custom_minimum_size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _k


func _line(pts: Array, closed := false) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(_p(p[0], p[1]))
	if closed:
		arr.append(arr[0])
	draw_polyline(arr, color, _w, true)


func _ring(x: float, y: float, r: float) -> void:
	draw_arc(_p(x, y), r * _k, 0, TAU, 40, color, _w, true)


func _draw() -> void:
	_k = minf(size.x, size.y) / 24.0
	_o = (size - Vector2(24, 24) * _k) / 2.0
	_w = stroke * _k
	match icon:
		"gear":
			_gear()
		"back":
			_line([[15, 5], [8, 12], [15, 19]])
		"chevron":
			_line([[9, 5], [16, 12], [9, 19]])
		"play":
			draw_colored_polygon(PackedVector2Array([_p(8, 5), _p(19.5, 12), _p(8, 19)]), color)
		"pause":
			draw_rect(Rect2(_p(7, 5), Vector2(3.5, 14) * _k), color)
			draw_rect(Rect2(_p(13.5, 5), Vector2(3.5, 14) * _k), color)
		"check":
			_line([[5, 12.5], [10, 17], [19, 7]])
		"cross":
			_line([[6, 6], [18, 18]])
			_line([[18, 6], [6, 18]])
		"intercept":
			_intercept()
		"photo":
			_photo()
		"tilt_forward", "tilt_angled", "tilt_down":
			_tilt()
		"sunflower":
			_sunflower()
		"sunflower_off":
			_sunflower_off()
		"lock":
			_line([[6, 11], [18, 11], [18, 20], [6, 20]], true)
			draw_arc(_p(12, 11), 4 * _k, PI, TAU, 24, color, _w, true)
		"camera":
			_camera()
		"fpv":
			# FPV goggles.
			_line([[3, 9], [21, 9], [21, 15], [15.5, 16.5], [13, 14.5], [11, 14.5], [8.5, 16.5], [3, 15]], true)
			_ring(8, 12, 1.8)
			_ring(16, 12, 1.8)
		"ugv":
			_ugv()
		"wing":
			# A small plane from above: body, wing, tail.
			_line([[12, 3], [12, 21]])
			_line([[3, 10], [21, 10], [21, 12.5], [3, 12.5]], true)
			_line([[8, 19], [16, 19]])
		"learn":
			_line([[2.5, 9.5], [12, 4.5], [21.5, 9.5], [12, 14.5]], true)
			_line([[6.5, 11.5], [6.5, 16], [12, 19], [17.5, 16], [17.5, 11.5]])
		"missions":
			_line([[5, 21], [5, 3.5]])
			_line([[5, 4], [17, 4], [14.5, 8], [17, 12], [5, 12]])
		"theory":
			_line([[3.5, 5], [11, 5], [11, 20], [3.5, 20]], true)
			_line([[13, 5], [20.5, 5], [20.5, 20], [13, 20]], true)
		"info":
			_ring(12, 12, 9)
			_line([[12, 11], [12, 17]])
			draw_circle(_p(12, 7.5), 1.2 * _k, color)
		"fox", "owl", "hedgehog", "hare", "stork", "bee":
			_animal()
		"kid", "grownup", "home", "power", "plus":
			_people_and_buttons()
		"radio", "battery", "cloud", "list":
			_book_things()
		"star", "flag_done", "medal":
			_badge_things()
		"link":
			_line([[14, 4], [20, 4], [20, 10]])
			_line([[20, 4], [11, 13]])
			_line([[17, 14], [17, 20], [4, 20], [4, 7], [10, 7]])


func _gear() -> void:
	_ring(12, 12, 3)
	_ring(12, 12, 6.5)
	for i in 8:
		var a := i * TAU / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(_p(12, 12) + d * 6.5 * _k, _p(12, 12) + d * 9.5 * _k, color, _w, true)


func _intercept() -> void:
	# A ball on the move, with speed lines: the course of catching a moving target.
	_ring(15, 12, 5)
	_line([[3, 8], [8, 8]])
	_line([[2, 12], [8, 12]])
	_line([[3, 16], [8, 16]])


func _photo() -> void:
	# A camera: the course of aerial photography.
	_line([[3, 8], [8, 8], [9.5, 5.5], [14.5, 5.5], [16, 8], [21, 8], [21, 19], [3, 19]], true)
	_ring(12, 13.3, 3.6)


func _tilt() -> void:
	# A camera lens and where it looks: ahead, down at an angle, straight down.
	_ring(7, 8, 3.2)
	var ang: float = {"tilt_forward": 0.0, "tilt_angled": 55.0, "tilt_down": 90.0}[icon]
	var d := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)))
	var a := Vector2(7, 8) + d * 5.0
	var b := Vector2(7, 8) + d * 14.0
	_line([[a.x, a.y], [b.x, b.y]])
	var l := b - d * 4.0 + d.orthogonal() * 3.0
	var r := b - d * 4.0 - d.orthogonal() * 3.0
	_line([[l.x, l.y], [b.x, b.y], [r.x, r.y]])


func _sunflower() -> void:
	# The rating mark: gold petals round a brown middle. Not a star, on purpose.
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		draw_circle(_p(12, 12) + d * 6.6 * _k, 3.9 * _k, color, true, -1.0, true)
	draw_circle(_p(12, 12), 4.3 * _k, Pal.c("seed"), true, -1.0, true)


func _sunflower_off() -> void:
	# A sunflower still to earn: only its outline.
	for i in 8:
		var d := Vector2.from_angle(i * TAU / 8.0)
		draw_arc(_p(12, 12) + d * 7.2 * _k, 2.6 * _k, 0, TAU, 20, color, _w * 0.8, true)
	_ring(12, 12, 4.3)


func _camera() -> void:
	# Camera drone seen from above: four rotors around a body.
	for p in [[5, 5], [19, 5], [5, 19], [19, 19]]:
		_ring(p[0], p[1], 3)
	_line([[7.5, 7.5], [9.5, 9.5]])
	_line([[16.5, 7.5], [14.5, 9.5]])
	_line([[7.5, 16.5], [9.5, 14.5]])
	_line([[16.5, 16.5], [14.5, 14.5]])
	_line([[9.5, 9.5], [14.5, 9.5], [14.5, 14.5], [9.5, 14.5]], true)


func _ugv() -> void:
	# Ground robot on tracks.
	_line([[6, 9], [18, 9], [20, 13], [4, 13]], true)
	_line([[10, 9], [10, 6.5], [14, 6.5], [14, 9]])
	_line([[5, 14], [19, 14], [21, 17], [19, 20], [5, 20], [3, 17]], true)
	for x in [7, 12, 17]:
		_ring(x, 17, 1.1)


## The kids' pilots: six animal faces, drawn in the same line as every other icon.
func _animal() -> void:
	var eye := func(x: float, y: float): draw_circle(_p(x, y), 1.1 * _k, color)
	match icon:
		"fox":
			_line([[4, 5], [8.5, 8], [15.5, 8], [20, 5], [18.5, 13], [12, 20], [5.5, 13]], true)
			_line([[8, 14.5], [12, 17], [16, 14.5]])
			eye.call(9, 11.5)
			eye.call(15, 11.5)
		"owl":
			_line([[6, 5], [8, 8]])
			_line([[18, 5], [16, 8]])
			_ring(12, 13, 7.5)
			_ring(9, 12, 2.4)
			_ring(15, 12, 2.4)
			_line([[11, 15], [12, 17], [13, 15]])
		"hedgehog":
			_line([[3, 16], [5, 9], [8, 11], [9, 6], [12, 9], [14, 5], [16, 9], [19, 8], [19, 12], [22, 15]])
			_line([[22, 15], [20, 18], [5, 18], [3, 16]])
			eye.call(17.5, 13.5)
			draw_circle(_p(21.5, 15.5), 1.2 * _k, color)
		"hare":
			_line([[9, 10], [8, 2.5], [10.5, 3], [11, 10]])
			_line([[13, 10], [13.5, 3], [16, 2.5], [15, 10]])
			_ring(12, 15, 5.5)
			eye.call(10, 14.5)
			eye.call(14, 14.5)
			_line([[11, 17.5], [12, 18.5], [13, 17.5]])
		"stork":
			_ring(10, 9, 4)
			_line([[13.5, 8], [21.5, 11], [13.5, 10.5]])
			_line([[9, 13], [8, 21]])
			_line([[11, 13], [12, 21]])
			eye.call(10, 8)
		"bee":
			_line([[7, 8], [9, 4], [12, 7], [15, 4], [17, 8]])
			_ring(12, 14, 6)
			_line([[6.5, 12.5], [17.5, 12.5]])
			_line([[6.5, 15.5], [17.5, 15.5]])
			eye.call(10, 10.5)
			eye.call(14, 10.5)


## The first-run figures and the flight buttons' icons.
func _people_and_buttons() -> void:
	match icon:
		"plus":
			_line([[12, 4], [12, 20]])
			_line([[4, 12], [20, 12]])
		"power":
			draw_arc(_p(12, 13), 7.5 * _k, -PI * 0.3, PI * 1.3, 32, color, _w, true)
			_line([[12, 3.5], [12, 12]])
		"home":
			_line([[3.5, 11.5], [12, 4], [20.5, 11.5]])
			_line([[6, 9.5], [6, 20], [18, 20], [18, 9.5]])
			_line([[10, 20], [10, 14.5], [14, 14.5], [14, 20]])
		"kid":
			# A child holding up a balloon on a string.
			_ring(10, 9, 2.6)
			_line([[10, 11.6], [10, 17]])
			_line([[10, 17], [7.5, 21]])
			_line([[10, 17], [12.5, 21]])
			_line([[10, 13.5], [6.5, 15.5]])
			_line([[10, 13.5], [16, 10.5]])
			_ring(18, 5.5, 2.5)
			_line([[18, 8], [16, 10.5]])
		"grownup":
			# A taller figure with both hands holding a radio.
			_ring(12, 5, 2.6)
			_line([[12, 7.6], [12, 15]])
			_line([[12, 15], [9, 21.5]])
			_line([[12, 15], [15, 21.5]])
			_line([[12, 10], [8.5, 12.5]])
			_line([[12, 10], [15.5, 12.5]])
			_line([[7, 12], [17, 12], [17, 15], [7, 15]], true)


## The book's own pictures: a radio, a battery, a rain cloud, a checklist.
func _book_things() -> void:
	match icon:
		"radio":
			# A radio with its two sticks and an antenna.
			_line([[3, 9], [21, 9], [21, 19], [3, 19]], true)
			_line([[18, 9], [20, 3]])
			_ring(8, 14, 2.6)
			_ring(16, 14, 2.6)
			draw_circle(_p(8, 14), 0.9 * _k, color)
			draw_circle(_p(16, 14), 0.9 * _k, color)
		"battery":
			_line([[4, 7], [19, 7], [19, 17], [4, 17]], true)
			_line([[19, 10], [21, 10], [21, 14], [19, 14]])
			_line([[7, 10], [7, 14]])
			_line([[10.5, 10], [10.5, 14]])
		"cloud":
			draw_arc(_p(8.5, 11), 3.5 * _k, PI * 0.5, PI * 1.5, 16, color, _w, true)
			draw_arc(_p(12.5, 8.5), 4.5 * _k, PI, TAU, 20, color, _w, true)
			draw_arc(_p(16.5, 11), 3.5 * _k, -PI * 0.5, PI * 0.5, 16, color, _w, true)
			_line([[8.5, 14.5], [16.5, 14.5]])
			for x in [8.5, 12.5, 16.5]:
				_line([[x, 17], [x - 1.5, 21]])
		"list":
			_line([[5, 3.5], [19, 3.5], [19, 20.5], [5, 20.5]], true)
			for y in [8.5, 12.5, 16.5]:
				_line([[8, y], [9.5, y + 1.3], [11.5, y - 1.2]])
				_line([[13.5, y], [16.5, y]])


## For the badges: a star, a finish flag and a medal.
func _badge_things() -> void:
	match icon:
		"star":
			var pts := []
			for i in 10:
				var r := 9.5 if i % 2 == 0 else 4.2
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append([12 + cos(a) * r, 12.5 + sin(a) * r])
			_line(pts, true)
		"flag_done":
			_line([[5, 21], [5, 3.5]])
			_line([[5, 4], [19, 4], [19, 13], [5, 13]], true)
			for i in 3:  # the chequers
				draw_rect(Rect2(_p(5 + i * 4.67, 4), Vector2(2.33, 4.5) * _k), color)
				draw_rect(Rect2(_p(7.33 + i * 4.67, 8.5), Vector2(2.33, 4.5) * _k), color)
		"medal":
			_line([[8, 3], [12, 10], [16, 3]])
			_ring(12, 15, 5.5)
			_line([[12, 12.5], [12, 17.5]])
