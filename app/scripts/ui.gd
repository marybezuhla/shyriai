# SPDX-License-Identifier: GPL-3.0-or-later
# Small builders for the interface, so every screen looks like one family.
class_name UI
extends RefCounted

const GUTTER := 20
const RADIUS_CARD := 18
const RADIUS_PILL := 14


static func label(text: String, px: int, weight := 500, token := "text", display := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Pal.font(weight, display))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", Pal.c(token))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A small uppercase label above a group, like "WHAT WE PILOT".
static func eyebrow(text: String, token := "muted") -> Label:
	var l := label(text.to_upper(), 12, 800, token)
	# Uppercase labels read better with a little air between letters.
	l.add_theme_font_override("font", Pal.font(800, false, 1))
	return l


static func box(bg: Color, radius := RADIUS_CARD, pad := 14, border := Color.TRANSPARENT, border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	return s


static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 0, w := 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel(content: Control, bg: Color, radius := RADIUS_CARD, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, pad))
	p.add_child(content)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A whole card that can be tapped. The card is drawn by a panel; an invisible button on top
## takes the touch, keyboard focus and the screen-reader name.
static func tappable(content: Control, bg: Color, on_press: Callable, a11y_name := "", radius := RADIUS_CARD, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var normal := box(bg, radius, pad)
	var pressed := box(bg.lerp(Pal.c("text"), 0.08), radius, pad)
	p.add_theme_stylebox_override("panel", normal)
	p.add_child(content)
	_ignore_mouse(content)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# PASS lets a finger drag on a card still scroll the list underneath.
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.tooltip_text = ""
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.draw_center = false
	focus.border_color = Pal.c("focus")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(radius)
	focus.anti_aliasing = true
	b.add_theme_stylebox_override("focus", focus)
	if a11y_name != "":
		b.set("accessibility_name", a11y_name)
	b.button_down.connect(func(): p.add_theme_stylebox_override("panel", pressed))
	b.button_up.connect(func(): p.add_theme_stylebox_override("panel", normal))
	b.pressed.connect(on_press)
	p.add_child(b)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## A round icon-only button, 44×44 so it is easy to hit.
static func icon_button(icon: String, on_press: Callable, a11y_name: String, bg: Color) -> PanelContainer:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(44, 44)
	c.add_child(Glyph.make(icon, 22, Pal.c("text")))
	return tappable(c, bg, on_press, a11y_name, 22, 0)


## Segmented choice, e.g. Kids / Simple / Adult.
static func segmented(options: Array, selected: String, on_pick: Callable) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for opt in options:
		var on: bool = opt[0] == selected
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, 44)
		c.add_child(label(opt[1], 15, 700 if on else 600, "on_accent" if on else "text", false, false))
		var id: String = opt[0]
		var t := tappable(c, Pal.c("accent") if on else Color(0, 0, 0, 0), func(): on_pick.call(id), opt[1], RADIUS_PILL, 0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
	var p := panel(row, Pal.c("surface"), 18, 5)
	return p


## The big gold button for the main action on a screen.
static func primary(text: String, on_press: Callable, icon := "") -> PanelContainer:
	var row := hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != "":
		row.add_child(Glyph.make(icon, 18, Pal.c("on_accent")))
	row.add_child(label(text, 16, 800, "on_accent", false, false))
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(0, 52)
	c.add_child(row)
	return tappable(c, Pal.c("accent"), on_press, text, 16, 0)


static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_mouse(ch)
