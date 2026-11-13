# SPDX-License-Identifier: GPL-3.0-or-later
# A radio or gamepad: which axis is each stick, turned round or not, how big the dead zone in the
# middle is, which buttons pause, change the view and arm, and a live check of all four sticks.
# Tap a row, then move that stick (or press that button) on the radio: it is learnt from the move.
extends Screen

const NAMES := {"throttle": "PAD_THROTTLE", "yaw": "PAD_YAW", "pitch": "PAD_PITCH", "roll": "PAD_ROLL"}
const BUTTON_NAMES := {"pause": "PAD_PAUSE", "view": "PAD_VIEW", "arm": "PAD_ARM"}

## What is being learnt now: "" or a stick or button name.
var _learning := ""
var _rest := {}
var _check: Control


func build() -> void:
	add_child(header(tr("PAD"), _device()))
	add_child(_axes_card())
	var dz := UI.vbox(8)
	dz.add_child(UI.label(tr("PAD_DEAD"), UI.TEXT, 700))
	dz.add_child(UI.segmented([
		["small", tr("PAD_DEAD_SMALL")], ["medium", tr("PAD_DEAD_MEDIUM")], ["large", tr("PAD_DEAD_LARGE")],
	], Prefs.pad_dead, func(v): Prefs.set_choice("pad_dead", v)))
	dz.add_child(UI.label(tr("PAD_DEAD_DESC"), UI.SMALL, 500, "muted"))
	add_child(UI.panel(dz, Pal.c("surface"), 18, 14))
	add_child(_buttons_card())
	add_child(_check_card())
	var reset := CenterContainer.new()
	reset.custom_minimum_size = Vector2(0, 48)
	reset.add_child(UI.label(tr("PAD_RESET"), UI.TEXT, 700, "text", false, false))
	add_child(UI.tappable(reset, Pal.c("surface2"), func(): _learning = ""; Prefs.reset_pad(), tr("PAD_RESET"), 16, 0))


func _device() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return tr("PAD_NONE")
	return tr("PAD_CONNECTED") % Input.get_joy_name(pads[0])


func _axes_card() -> Control:
	var col := UI.vbox(2)
	for st in Prefs.PAD_AXES:
		var m: Dictionary = Prefs.pad_axes.get(st, FlightInput.default_axis(st, Prefs.stick_mode == "1"))
		var what := tr("PAD_AXIS") % (int(m["a"]) + 1)
		if m["inv"]:
			what += " · " + tr("PAD_INVERTED")
		if _learning == st:
			what = tr("PAD_MOVE_" + ("UP" if st in ["throttle", "pitch"] else "RIGHT"))
		col.add_child(_row(tr(NAMES[st]), what, st))
	col.add_child(UI.label(tr("PAD_AXES_DESC"), UI.SMALL, 500, "muted"))
	return UI.panel(col, Pal.c("surface"), 18, 12)


func _buttons_card() -> Control:
	var col := UI.vbox(2)
	for act in Prefs.PAD_BUTTONS:
		var b := FlightInput.binding(act)
		var what := tr("PAD_BUTTON") % (int(b["b"]) + 1) if b.has("b") else tr("PAD_SWITCH") % (int(b["a"]) + 1)
		if _learning == act:
			what = tr("PAD_PRESS")
		col.add_child(_row(tr(BUTTON_NAMES[act]), what, act))
	return UI.panel(col, Pal.c("surface"), 18, 12)


func _row(title: String, value: String, id: String) -> Control:
	var row := UI.hbox(10)
	var t := UI.label(title, UI.TEXT, 600)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var on := _learning == id
	row.add_child(UI.panel(UI.label(value, UI.SMALL, 700, "on_accent" if on else "text", false, false),
		Pal.c("accent") if on else Pal.c("surface2"), 8, 6))
	return UI.tappable(row, Color(0, 0, 0, 0), func(): _learn(id), title + ": " + value, 10, 8)


func _learn(id: String) -> void:
	_learning = "" if _learning == id else id
	_rest = {}
	for dev in Input.get_connected_joypads():
		for a in JOY_AXIS_MAX:
			_rest[a] = Input.get_joy_axis(dev, a as JoyAxis)
	rebuild()


## Four bars: what each stick reads now, through the settings above.
func _check_card() -> Control:
	var col := UI.vbox(8)
	col.add_child(UI.label(tr("PAD_CHECK"), UI.TEXT, 700))
	_check = Control.new()
	_check.custom_minimum_size = Vector2(0, 4 * 26)
	_check.draw.connect(_draw_check)
	col.add_child(_check)
	return UI.panel(col, Pal.c("surface"), 18, 14)


func _draw_check() -> void:
	var w := _check.size.x
	var font := Pal.font(600)
	for i in Prefs.PAD_AXES.size():
		var st: String = Prefs.PAD_AXES[i]
		var v := 0.0
		for dev in Input.get_connected_joypads():
			v = FlightInput.stick(dev, st, Prefs.stick_mode == "1")
		var y := i * 26.0
		_check.draw_string(font, Vector2(0, y + 16), tr(NAMES[st]), HORIZONTAL_ALIGNMENT_LEFT, 120, UI.SMALL, Pal.c("muted"))
		var bar := Rect2(130, y + 8, w - 130, 8)
		_check.draw_rect(bar, Pal.c("surface2"))
		var mid := bar.position.x + bar.size.x / 2.0
		var x := mid + v * bar.size.x / 2.0
		_check.draw_rect(Rect2(minf(mid, x), bar.position.y, absf(x - mid), 8), Pal.c("accent"))
		_check.draw_line(Vector2(mid, y + 4), Vector2(mid, y + 20), Pal.c("line"), 1.0)


func _process(_delta: float) -> void:
	if _check:
		_check.queue_redraw()
	if _learning == "" or _learning in Prefs.PAD_BUTTONS and _learning != "arm":
		return
	# A stick (or the arm switch) is learnt from the axis that moved furthest from where it rested.
	for dev in Input.get_connected_joypads():
		for a in JOY_AXIS_MAX:
			var v := Input.get_joy_axis(dev, a as JoyAxis)
			if absf(v - float(_rest.get(a, 0.0))) > 0.6:
				var id := _learning
				_learning = ""
				if id == "arm":
					Prefs.set_pad_button("arm", {"a": a})
				else:
					Prefs.set_pad_axis(id, a, v < float(_rest.get(a, 0.0)))
				return


func _input(event: InputEvent) -> void:
	if _learning in Prefs.PAD_BUTTONS and event is InputEventJoypadButton and event.pressed:
		var id := _learning
		_learning = ""
		Prefs.set_pad_button(id, {"b": event.button_index})
		get_viewport().set_input_as_handled()
