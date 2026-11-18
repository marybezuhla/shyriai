# SPDX-License-Identifier: GPL-3.0-or-later
# Kids mode: after 20 minutes of flying, before the next flight starts, a gentle reminder to rest
# the eyes. "Rest" goes back to the lessons; "5 more minutes" flies on and asks again later.
class_name BreakCard
extends ColorRect

## Seconds of flying before the reminder, and how much "5 more minutes" gives.
const AFTER := 1200.0
const MORE := 300.0

var on_rest: Callable
var on_more: Callable
var _col: VBoxContainer


func _fit() -> void:
	_col.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 48.0, 360.0), 0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := Pal.c("bg")
	dim.a = 0.97
	color = dim
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := UI.vbox(12)
	_col = col
	# The screen may still be turning from sideways to upright: fit the width again when it does.
	_fit()
	get_viewport().size_changed.connect(_fit)
	var sun := CenterContainer.new()
	sun.add_child(Glyph.make("sunflower", 56, Pal.c("accent_text")))
	col.add_child(sun)
	var t := UI.label(tr("BREAK_TITLE"), UI.TITLE_L, 600, "text", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var b := UI.label(tr("BREAK_TEXT"), UI.BODY, 500, "muted")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(b)
	col.add_child(UI.primary(tr("BREAK_REST"), func(): _go(on_rest)))
	col.add_child(UI.secondary(tr("BREAK_MORE"), func(): _go(on_more)))
	center.add_child(UI.panel(col, Pal.c("surface"), 24, 20))


## Back on the phone: the same as "Rest".
func rest() -> void:
	_go(on_rest)


func _go(action: Callable) -> void:
	queue_free()
	action.call()
