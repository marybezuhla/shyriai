# SPDX-License-Identifier: GPL-3.0-or-later
# The book's drawings, drawn in the app's colours so every look and text size suits them:
#   sticks  the two sticks of a Mode 2 (or Mode 1) radio and what each way does
#   lipo    a LiPo cell's voltage, from empty to full, with the marks a pilot watches
#   wing    a wing in the air and its angle of attack
class_name BookFigure
extends Control

var kind := ""


static func make(kind_: String) -> BookFigure:
	var f := BookFigure.new()
	f.kind = kind_
	f.custom_minimum_size = Vector2(0, {"sticks": 165.0, "lipo": 120.0, "wing": 170.0}.get(kind_, 0.0) * Pal.text_scale())
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.set("accessibility_name", f.tr("BOOK_FIG_" + kind_.to_upper()))
	return f


func _draw() -> void:
	match kind:
		"sticks":
			_sticks()
		"lipo":
			_lipo()
		"wing":
			_wing()


func _text(at: Vector2, s: String, w: float, token := "muted", px := UI.SMALL, weight := 600,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(Pal.font(weight), at, s, align, w, roundi(px * Pal.text_scale()), Pal.c(token))


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 3.0, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b + d * 4.0, b - d * 8.0 + n * 6.0, b - d * 8.0 - n * 6.0]), col)


func _sticks() -> void:
	var s := Pal.text_scale()
	var r := 44.0 * minf(s, 1.3)
	var m1 := Prefs.stick_mode == "1"
	var labels := ["BOOK_FIG_LEFT_M1", "BOOK_FIG_RIGHT_M1"] if m1 else ["BOOK_FIG_LEFT", "BOOK_FIG_RIGHT"]
	var top := 24.0 * s
	_text(Vector2(0, 16.0 * s), tr("BOOK_FIG_MODE") % ("1" if m1 else "2"), size.x, "text", UI.SMALL, 700)
	for i in 2:
		var c := Vector2(size.x * (0.27 + 0.46 * i), top + r + 8.0)
		draw_circle(c, r, Pal.c("surface2"))
		draw_arc(c, r, 0.0, TAU, 40, Pal.c("line"), 2.0, true)
		draw_line(c - Vector2(r - 8, 0), c + Vector2(r - 8, 0), Pal.c("line"), 1.5)
		draw_line(c - Vector2(0, r - 8), c + Vector2(0, r - 8), Pal.c("line"), 1.5)
		# Up and down: throttle on the left in Mode 2, on the right in Mode 1; sideways: turn or roll.
		var col := Pal.c("accent")
		_arrow(c, c - Vector2(0, r - 10), col)
		_arrow(c, c + Vector2(r - 10, 0), col)
		draw_circle(c, 10.0, Pal.c("accent"))
		_text(Vector2(c.x - 80.0, c.y + r + 24.0 * s), tr(labels[i]), 160.0, "text")


func _lipo() -> void:
	var s := Pal.text_scale()
	var x0 := 16.0
	var x1 := size.x - 16.0
	var y := 46.0 * s
	var at := func(v: float) -> float: return lerpf(x0, x1, (v - 3.3) / 0.9)
	draw_rect(Rect2(x0, y, x1 - x0, 14), Pal.c("surface2"))
	draw_rect(Rect2(x0, y, at.call(3.5) - x0, 14), Pal.c("bad"))
	draw_rect(Rect2(at.call(3.5), y, at.call(3.7) - at.call(3.5), 14), Pal.c("warn"))
	draw_rect(Rect2(at.call(3.7), y, x1 - at.call(3.7), 14), Pal.c("ok"))
	var marks := [[3.3, "BOOK_FIG_EMPTY"], [3.5, "BOOK_FIG_LAND"], [3.8, "BOOK_FIG_STORE"], [4.2, "BOOK_FIG_FULL"]]
	for k in marks.size():
		var x: float = at.call(marks[k][0])
		draw_line(Vector2(x, y - 6), Vector2(x, y + 20), Pal.c("text"), 2.0)
		var top := k % 2 == 0
		var label := FlightTask.num(marks[k][0]) + " " + tr("BOOK_FIG_V")
		# The end marks hug the edges, so the names between have room at the largest text.
		var w := 190.0
		var lx := clampf(x - w / 2.0, 0.0, size.x - w)
		var align := HORIZONTAL_ALIGNMENT_CENTER
		if k == 0:
			lx = x0 - 6.0
			align = HORIZONTAL_ALIGNMENT_LEFT
		elif k == 2:
			lx = x - 6.0  # beside "empty" on the top row: it reads from its mark rightwards
			align = HORIZONTAL_ALIGNMENT_LEFT
		elif k == marks.size() - 1:
			lx = x1 + 6.0 - w
			align = HORIZONTAL_ALIGNMENT_RIGHT
		_text(Vector2(lx, y - 12.0 if top else y + 40.0 * s), label, w, "text", UI.SMALL, 700, align)
		_text(Vector2(lx, y - 30.0 * s if top else y + 58.0 * s), tr(marks[k][1]), w, "muted", UI.SMALL, 600, align)


func _wing() -> void:
	var s := Pal.text_scale()
	var c := Vector2(size.x * 0.58, size.y * 0.55)
	var aoa := deg_to_rad(12.0)  # the nose up into the air (y grows downwards)
	var chord := minf(size.x * 0.6, 260.0)
	var dir := Vector2(cos(aoa), sin(aoa))
	var n := Vector2(-dir.y, dir.x)
	# A wing's cross-section: rounded nose, thin tail.
	var pts := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		var th := 0.12 * chord * (1.0 - t) * sqrt(t) * 2.2
		pts.append(c - dir * chord * 0.5 + dir * chord * t - n * th)
	for k in range(16, -1, -1):
		var t := k / 16.0
		var th := 0.03 * chord * (1.0 - t) * sqrt(t) * 2.2
		pts.append(c - dir * chord * 0.5 + dir * chord * t + n * th)
	draw_colored_polygon(pts, Pal.c("text"))
	# The air comes at it level; the angle between them is the angle of attack.
	var nose := c - dir * chord * 0.5
	_arrow(Vector2(12, nose.y), Vector2(nose.x - 18.0, nose.y), Pal.c("accent"))
	_text(Vector2(0, nose.y - 12.0), tr("BOOK_FIG_AIR"), maxf(nose.x - 18.0, 110.0), "accent_text")
	draw_line(nose, nose + Vector2(chord + 20.0, 0), Pal.c("line"), 1.5)
	var arc_r := chord * 0.32
	draw_arc(nose, arc_r, 0.0, aoa, 12, Pal.c("accent"), 2.5, true)
	# Under the wing, from its nose: clear of the drawing at any text size.
	var below := c.y + chord * 0.5 * sin(aoa) + 28.0 * s
	_text(Vector2(nose.x, below), tr("BOOK_FIG_AOA"), size.x - nose.x, "accent_text", UI.SMALL, 600, HORIZONTAL_ALIGNMENT_LEFT)
	# Lift stands square to the oncoming air: straight up, its name above it.
	var tip := Vector2(c.x, size.y * 0.22 + 6.0)
	_arrow(c, tip, Pal.c("ok"))
	var w := minf(size.x, 220.0 * s)
	_text(Vector2(clampf(tip.x - w / 2.0, 0.0, size.x - w), tip.y - 10.0), tr("BOOK_FIG_LIFT"), w, "ok")
