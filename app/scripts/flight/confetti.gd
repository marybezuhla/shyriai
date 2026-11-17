# SPDX-License-Identifier: GPL-3.0-or-later
# A short shower of confetti over a passed lesson: toy-coloured bits that fall and spin for a moment,
# then go. It takes no touches.
class_name Confetti
extends Control

const LIFE := 1.8
const COUNT := 60

var _bits: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors := Pal.TOY.values()
	var w := get_viewport_rect().size.x
	for i in COUNT:
		_bits.append({
			"p": Vector2(rng.randf_range(0.0, w), rng.randf_range(-120.0, -10.0)),
			"v": Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(160.0, 320.0)),
			"a": rng.randf_range(0.0, TAU), "w": rng.randf_range(-6.0, 6.0),
			"c": colors[i % colors.size()], "s": rng.randf_range(5.0, 9.0),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	for b in _bits:
		b["p"] += b["v"] * delta
		b["a"] += b["w"] * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFE - _t) / 0.5, 0.0, 1.0)
	for b in _bits:
		draw_set_transform(b["p"], b["a"])
		var s: float = b["s"]
		draw_rect(Rect2(-s / 2.0, -s / 4.0, s, s / 2.0), Color(b["c"], fade))
	draw_set_transform(Vector2.ZERO)
