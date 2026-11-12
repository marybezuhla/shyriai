# SPDX-License-Identifier: GPL-3.0-or-later
# Grown-ups' lock: solve a multiplication to leave Kids mode or open settings.
# Stops children without a PIN that can be forgotten. A two-digit number keeps out a child
# who knows the times table; after three misses it waits a little, so guessing is slow.
class_name Gate
extends ColorRect

var on_pass: Callable
var _a := 0
var _b := 0
var _typed := ""
var _answer: Label
var _note: Label
var _rng := RandomNumberGenerator.new()
const MISSES_BEFORE_WAIT := 3
const WAIT_MS := 10000
## Static, so closing and reopening the lock does not skip the wait.
static var _misses := 0
static var _wait_until := 0


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
	col.add_child(UI.label(tr("GATE_TITLE"), UI.TITLE, 600, "text", true))
	col.add_child(UI.label(tr("GATE_TEXT"), UI.BODY, 500, "muted"))
	_answer = UI.label("", UI.DISPLAY_L, 600, "text", true, false)
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(UI.panel(_answer, Pal.c("surface2"), 16, 14))
	_note = UI.label("", UI.SMALL, 600, "accent_text")
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
		c.add_child(UI.label(text, UI.TITLE, 700, "on_accent" if is_ok else "text", false, false))
		var key: String = k
		var name_: String = tr("GATE_ERASE") if k == "⌫" else text
		var t := UI.tappable(c, Pal.c("accent") if is_ok else Pal.c("surface"), func(): _press(key), name_, 14, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	col.add_child(grid)

	var cancel := CenterContainer.new()
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.add_child(UI.label(tr("CANCEL"), UI.TEXT, 700, "muted", false, false))
	col.add_child(UI.tappable(cancel, Color(0, 0, 0, 0), close, tr("CANCEL"), 14, 0))
	center.add_child(col)
	_refresh()
	# A wait started before the lock was closed and reopened still runs.
	set_process(_wait_until > Time.get_ticks_msec())


func close() -> void:
	queue_free()


func _new_sum() -> void:
	_a = _rng.randi_range(12, 29)
	_b = _rng.randi_range(3, 9)
	_typed = ""


func _process(_delta: float) -> void:
	var left := _wait_until - Time.get_ticks_msec()
	if left <= 0:
		_wait_until = 0
		_note.text = ""
		set_process(false)
	else:
		_note.text = tr("GATE_WAIT") % ceili(left / 1000.0)


func _press(k: String) -> void:
	if _wait_until > Time.get_ticks_msec():
		return
	if k == "⌫":
		_typed = _typed.left(-1)
	elif k == "OK":
		if _typed.to_int() == _a * _b and _typed != "":
			var action := on_pass
			_misses = 0
			queue_free()
			if action.is_valid():
				action.call()
			return
		_note.text = tr("GATE_WRONG")
		_new_sum()
		_misses += 1
		if _misses % MISSES_BEFORE_WAIT == 0:
			_wait_until = Time.get_ticks_msec() + WAIT_MS
			set_process(true)
	elif _typed.length() < 3:
		_typed += k
	_refresh()


func _refresh() -> void:
	_answer.text = "%d × %d = %s" % [_a, _b, _typed if _typed != "" else "?"]
