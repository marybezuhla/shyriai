# SPDX-License-Identifier: GPL-3.0-or-later
# An on-screen stick. Several fingers work at once: each stick follows the finger that touched it.
# It springs back to the centre when let go, like the sticks of a camera drone's remote.
class_name Stick
extends Control

var value := Vector2.ZERO  # x right, y UP, each -1..1
var kids := false
## False for an FPV throttle: up and down stay where the thumb leaves them, and moving the thumb
## moves the stick from there (it does not jump to where the thumb lands).
var spring_y := true
var touched := false
## Off while a card (pause, results) covers the screen.
var enabled := true
## Which way to push, shown as a ghost knob sliding there (x right, y up). ZERO = no hint.
var hint := Vector2.ZERO

var _finger := -1
var _start_local := Vector2.ZERO
var _start_y := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not enabled:
		return
	if event is InputEventScreenTouch:
		var local := _local(event.position)
		if event.pressed and _finger == -1 and _hit(local):
			_finger = event.index
			touched = true
			_start_local = local
			_start_y = value.y
			_set_from(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			release()
	elif event is InputEventScreenDrag and event.index == _finger:
		_set_from(_local(event.position))
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if hint != Vector2.ZERO:
		queue_redraw()


func release() -> void:
	_finger = -1
	value.x = 0.0
	if spring_y:
		value.y = 0.0
	queue_redraw()


func _local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p


func _radius() -> float:
	return minf(size.x, size.y) / 2.0


func _hit(local: Vector2) -> bool:
	# A generous area: a bit beyond the drawn ring still counts.
	return local.distance_to(size / 2.0) <= _radius() * 1.35


func _set_from(local: Vector2) -> void:
	var travel := _radius() - _knob_radius()
	var d := (local - size / 2.0) / maxf(travel, 1.0)
	if spring_y:
		if d.length() > 1.0:
			d = d.normalized()
		value = Vector2(d.x, -d.y)
	else:
		value.x = clampf(d.x, -1.0, 1.0)
		value.y = clampf(_start_y - (local.y - _start_local.y) / maxf(travel, 1.0), -1.0, 1.0)
	queue_redraw()


func _knob_radius() -> float:
	return _radius() * (0.36 if kids else 0.34)


func _draw() -> void:
	var c := size / 2.0
	var r := _radius()
	var line := Pal.c("text")
	# A dark see-through base, so the stick reads over a bright field as well as at dusk.
	draw_circle(c, r, Color(Pal.INK, 0.32), true, -1.0, true)
	var fill := line
	fill.a = 0.08
	draw_circle(c, r, fill, true, -1.0, true)
	line.a = 0.35
	draw_arc(c, r - 1, 0, TAU, 64, line, 2.0, true)
	var cross := Pal.c("text")
	cross.a = 0.18
	draw_line(c + Vector2(0, -r + 10), c + Vector2(0, r - 10), cross, 1.0, true)
	draw_line(c + Vector2(-r + 10, 0), c + Vector2(r - 10, 0), cross, 1.0, true)
	if kids:
		# Little arrows show which way the stick goes.
		var a := Pal.c("text")
		a.a = 0.45
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = c + dir * (r - 8)
			var side: Vector2 = Vector2(-dir.y, dir.x) * 7
			var back: Vector2 = tip - dir * 8
			draw_polyline(PackedVector2Array([back + side, tip, back - side]), a, 3.0, true)
	var travel := r - _knob_radius()
	if hint != Vector2.ZERO and _finger == -1:
		# A ghost knob glides from the middle the way to push, again and again.
		var phase := fmod(Time.get_ticks_msec() / 1000.0, 1.6) / 1.6
		var g := c + Vector2(hint.x, -hint.y).normalized() * travel * ease(minf(phase * 1.4, 1.0), 0.5)
		var ghost := Pal.c("accent")
		ghost.a = 0.55 * (1.0 - phase)
		draw_circle(g, _knob_radius(), ghost, true, -1.0, true)
		draw_arc(g, _knob_radius(), 0, TAU, 40, Color(Pal.INK, 0.6 * (1.0 - phase)), 2.0, true)
	var k := c + Vector2(value.x, -value.y) * travel
	var halo := Pal.c("accent")
	halo.a = 0.2
	draw_circle(k, _knob_radius() + 6, halo, true, -1.0, true)
	draw_circle(k, _knob_radius(), Pal.c("accent"), true, -1.0, true)
	draw_arc(k, _knob_radius(), 0, TAU, 40, Pal.INK, 2.0, true)
	if kids:
		draw_arc(k, _knob_radius() - 1.5, 0, TAU, 40, Pal.c("on_accent"), 3.0, true)
