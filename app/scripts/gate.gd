# SPDX-License-Identifier: GPL-3.0-or-later
# Grown-ups' lock: solve a small multiplication to leave Kids mode or open settings.
# Stops small children without a PIN that can be forgotten.
class_name Gate
extends ColorRect

var on_pass: Callable
var _a := 0
var _b := 0
var _typed := ""
var _answer: Label
var _note: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := Pal.c("bg")
	dim.a = 0.97
	color = dim
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	_new_sum()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var col := UI.vbox(14)
	col.custom_minimum_size = Vector2(300, 0)
	col.add_child(UI.label(tr("GATE_TITLE"), 20, 600, "text", true))
	col.add_child(UI.label(tr("GATE_TEXT"), 14, 500, "muted"))
	_answer = UI.label("", 30, 600, "text", true, false)
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(UI.panel(_answer, Pal.c("surface2"), 16, 14))
	_note = UI.label("", 13, 600, "accent_text")
	col.add_child(_note)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "OK"]:
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, 52)
		var is_ok: bool = k == "OK"
		var text: String = tr("GATE_OK") if is_ok else k
		c.add_child(UI.label(text, 20, 700, "on_accent" if is_ok else "text", false, false))
		var key: String = k
		var name_: String = tr("GATE_ERASE") if k == "⌫" else text
		var t := UI.tappable(c, Pal.c("accent") if is_ok else Pal.c("surface"), func(): _press(key), name_, 14, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	col.add_child(grid)

	var cancel := CenterContainer.new()
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.add_child(UI.label(tr("CANCEL"), 15, 700, "muted", false, false))
	col.add_child(UI.tappable(cancel, Color(0, 0, 0, 0), close, tr("CANCEL"), 14, 0))
	center.add_child(col)
	_refresh()


func close() -> void:
	queue_free()


func _new_sum() -> void:
	_a = _rng.randi_range(6, 9)
	_b = _rng.randi_range(4, 9)
	_typed = ""


func _press(k: String) -> void:
	if k == "⌫":
		_typed = _typed.left(-1)
	elif k == "OK":
		if _typed.to_int() == _a * _b and _typed != "":
			var action := on_pass
			queue_free()
			if action.is_valid():
				action.call()
			return
		_note.text = tr("GATE_WRONG")
		_new_sum()
	elif _typed.length() < 3:
		_typed += k
	_refresh()


func _refresh() -> void:
	_answer.text = "%d × %d = %s" % [_a, _b, _typed if _typed != "" else "?"]
