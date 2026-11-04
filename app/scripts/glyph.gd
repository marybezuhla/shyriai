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


static func make(name: String, px: float, col: Color) -> Glyph:
	var g := Glyph.new()
	g.icon = name
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
			_ring(12, 12, 3)
			_ring(12, 12, 6.5)
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				draw_line(_p(12, 12) + d * 6.5 * _k, _p(12, 12) + d * 9.5 * _k, color, _w, true)
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
		"lock":
			_line([[6, 11], [18, 11], [18, 20], [6, 20]], true)
			draw_arc(_p(12, 11), 4 * _k, PI, TAU, 24, color, _w, true)
		"camera":
			# Camera drone seen from above: four rotors around a body.
			for p in [[5, 5], [19, 5], [5, 19], [19, 19]]:
				_ring(p[0], p[1], 3)
			_line([[7.5, 7.5], [9.5, 9.5]])
			_line([[16.5, 7.5], [14.5, 9.5]])
			_line([[7.5, 16.5], [9.5, 14.5]])
			_line([[16.5, 16.5], [14.5, 14.5]])
			_line([[9.5, 9.5], [14.5, 9.5], [14.5, 14.5], [9.5, 14.5]], true)
		"fpv":
			# FPV goggles.
			_line([[3, 9], [21, 9], [21, 15], [15.5, 16.5], [13, 14.5], [11, 14.5], [8.5, 16.5], [3, 15]], true)
			_ring(8, 12, 1.8)
			_ring(16, 12, 1.8)
		"ugv":
			# Ground robot on tracks.
			_line([[6, 9], [18, 9], [20, 13], [4, 13]], true)
			_line([[10, 9], [10, 6.5], [14, 6.5], [14, 9]])
			_line([[5, 14], [19, 14], [21, 17], [19, 20], [5, 20], [3, 17]], true)
			for x in [7, 12, 17]:
				_ring(x, 17, 1.1)
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
		"link":
			_line([[14, 4], [20, 4], [20, 10]])
			_line([[20, 4], [11, 13]])
			_line([[17, 14], [17, 20], [4, 20], [4, 7], [10, 7]])
