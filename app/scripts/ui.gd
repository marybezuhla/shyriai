# SPDX-License-Identifier: GPL-3.0-or-later
# Small builders for the interface, so every screen looks like one family.
class_name UI
extends RefCounted

const GUTTER := 20
const RADIUS_CARD := 18
const RADIUS_PILL := 14


static func label(text: String, px: int, weight := 500, token := "text", display := false, wraps := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Pal.font(weight, display))
	l.add_theme_font_size_override("font_size", roundi(px * Pal.text_scale()))
	l.add_theme_color_override("font_color", Pal.c(token))
	if wraps:
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
static func tappable(content: Control, bg: Color, on_press: Callable, a11y_name := "", radius := RADIUS_CARD, pad := 14, outline := false) -> PanelContainer:
	var p := PanelContainer.new()
	# An outline marks the chosen option, so it stands out even where gold is pale on white.
	var edge := Pal.c("on_accent") if outline else Color.TRANSPARENT
	var normal := box(bg, radius, pad, edge, 2 if outline else 0)
	var pressed := box(bg.lerp(Pal.c("text"), 0.08), radius, pad, edge, 2 if outline else 0)
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
	# 52 design units stay at least 48 dp on a 360 dp phone (the layout is 390 wide).
	c.custom_minimum_size = Vector2(52, 52)
	c.add_child(Glyph.make(icon, 22, Pal.c("text")))
	return tappable(c, bg, on_press, a11y_name, 22, 0)


## Segmented choice, e.g. Kids / Simple / Adult.
static func segmented(options: Array, selected: String, on_pick: Callable) -> PanelContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for opt in options:
		var on: bool = opt[0] == selected
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(0, 52)
		var l := label(opt[1], 15, 700 if on else 600, "on_accent" if on else "text", false, false)
		# Three options share one row on a narrow phone: larger text would no longer fit, so it stays fixed.
		l.add_theme_font_size_override("font_size", 14)
		c.add_child(l)
		var id: String = opt[0]
		var t := tappable(c, Pal.c("accent") if on else Color(0, 0, 0, 0), func(): on_pick.call(id), opt[1], RADIUS_PILL, 0, on)
		var b: Button = t.get_child(1)
		b.toggle_mode = true
		b.set_pressed_no_signal(on)
		# Tapping the chosen option again changes nothing, so its button stays pressed too.
		b.toggled.connect(func(_p: bool): b.set_pressed_no_signal(on))
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


## A full-width row with an on/off switch and a line of explanation under the title.
static func switch_row(title: String, desc: String, on: bool, on_toggle: Callable) -> PanelContainer:
	var text := vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(label(title, 16, 700))
	text.add_child(label(desc, 13, 500, "muted"))
	var sw := Toggle.new()
	sw.on = on
	sw.custom_minimum_size = Vector2(48, 28)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := hbox(14)
	row.add_child(text)
	row.add_child(sw)
	var t := tappable(row, Pal.c("surface"), func(): on_toggle.call(not on), title)
	t.get_child(1).set("toggle_mode", true)
	t.get_child(1).set("button_pressed", on)
	return t


class Toggle extends Control:
	var on := false

	func _draw() -> void:
		var h := size.y
		var track := Pal.c("accent") if on else Pal.c("line")
		var r := Rect2(Vector2.ZERO, size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = track
		sb.set_corner_radius_all(int(h / 2.0))
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var knob := Pal.c("on_accent") if on else Pal.c("surface")
		var x := size.x - h / 2.0 if on else h / 2.0
		if not on:
			# A visible edge for the "off" track, which is otherwise pale against the card.
			var edge := StyleBoxFlat.new()
			edge.draw_center = false
			edge.border_color = Pal.c("faint")
			edge.set_border_width_all(2)
			edge.set_corner_radius_all(int(h / 2.0))
			edge.anti_aliasing = true
			draw_style_box(edge, r)
		draw_circle(Vector2(x, h / 2.0), h / 2.0 - 3.0, knob, true, -1.0, true)
