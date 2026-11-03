# SPDX-License-Identifier: GPL-3.0-or-later
# The app frame: background, scrolling content, bottom tabs, and the screen stack (with Android Back).
extends Control

const TABS := [
	["learn", "learn", "TAB_LEARN", "res://scripts/screens/home.gd"],
	["missions", "missions", "TAB_MISSIONS", "res://scripts/screens/missions.gd"],
	["theory", "theory", "TAB_THEORY", "res://scripts/screens/theory.gd"],
]

var stack: Array[Screen] = []
var tab := "learn"

var _bg := ColorRect.new()
var _frame := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _pad := MarginContainer.new()
var _nav := PanelContainer.new()
var _bottom_inset := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.add_theme_constant_override("separation", 0)
	add_child(_frame)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_frame.add_child(_scroll)
	_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pad)
	_frame.add_child(_nav)

	Pal.changed.connect(_restyle)
	Prefs.changed.connect(_restyle)
	get_viewport().size_changed.connect(_apply_insets)
	_apply_insets()
	open_tab("learn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_input(event: InputEvent) -> void:
	# Escape on a keyboard or B on a gamepad also goes back.
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


# --- Navigation -------------------------------------------------------------

func open_tab(name_: String) -> void:
	for s in stack:
		s.queue_free()
	stack.clear()
	tab = name_
	for t in TABS:
		if t[0] == name_:
			stack.append(_make(t[3]))
	_show()


func open_lessons(vehicle: String) -> void:
	var s := _make("res://scripts/screens/lessons.gd")
	s.vehicle = vehicle
	_push(s)


func open_settings() -> void:
	_push(_make("res://scripts/screens/settings.gd"))


func open_about() -> void:
	_push(_make("res://scripts/screens/about.gd"))


func open_licenses() -> void:
	_push(_make("res://scripts/screens/licenses.gd"))


func open_soon(title: String) -> void:
	var s := _make("res://scripts/screens/soon.gd")
	s.title = title
	_push(s)


func back() -> void:
	if stack.size() > 1:
		stack.pop_back().queue_free()
		_show()
	elif tab != "learn":
		open_tab("learn")
	else:
		get_tree().quit()


func _make(path: String) -> Screen:
	var s: Screen = load(path).new()
	s.app = self
	return s


func _push(s: Screen) -> void:
	stack.append(s)
	_show()


func _show() -> void:
	for c in _pad.get_children():
		_pad.remove_child(c)
	var s: Screen = stack.back()
	_pad.add_child(s)
	_restyle()
	_scroll.scroll_vertical = 0


func _restyle() -> void:
	_bg.color = Pal.c("bg")
	if not stack.is_empty():
		stack.back().rebuild()
	_build_nav()


# --- Bottom tabs ------------------------------------------------------------

func _build_nav() -> void:
	for c in _nav.get_children():
		c.queue_free()
	_nav.visible = stack.size() == 1
	var style := UI.box(Pal.c("bg"), 0, 0)
	style.border_color = Pal.c("surface2")
	style.border_width_top = 1
	style.content_margin_top = 8
	style.content_margin_bottom = 10 + _bottom_inset
	style.content_margin_left = 12
	style.content_margin_right = 12
	_nav.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for t in TABS:
		var on: bool = t[0] == tab
		var token := "accent_text" if on else "muted"
		var col := UI.vbox(4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := CenterContainer.new()
		ic.add_child(Glyph.make(t[1], 24, Pal.c(token)))
		col.add_child(ic)
		var l := UI.label(tr(t[2]), 12, 700 if on else 600, token, false, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		col.custom_minimum_size = Vector2(0, 48)
		var id: String = t[0]
		var b := UI.tappable(col, Color(0, 0, 0, 0), func(): open_tab(id), tr(t[2]), 14, 4)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_nav.add_child(row)


# --- Phone cut-outs and system bars -----------------------------------------

func _apply_insets() -> void:
	var top := 16.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		if win.x > 0 and win.y > 0:
			var k := get_viewport_rect().size / win
			top = maxf(top, safe.position.y * k.y + 8)
			bottom = maxf(0.0, (win.y - safe.end.y) * k.y)
			left = maxf(0.0, safe.position.x * k.x)
			right = maxf(0.0, (win.x - safe.end.x) * k.x)
	_bottom_inset = bottom
	_pad.add_theme_constant_override("margin_left", UI.GUTTER + int(left))
	_pad.add_theme_constant_override("margin_right", UI.GUTTER + int(right))
	_pad.add_theme_constant_override("margin_top", int(top))
	_pad.add_theme_constant_override("margin_bottom", 24)
	if is_inside_tree() and not stack.is_empty():
		_build_nav()
