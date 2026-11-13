# SPDX-License-Identifier: GPL-3.0-or-later
# Shown once, on the very first start: who will play. A child gets Kids mode with the grown-ups'
# lock on, a grown-up gets Simple mode; settings can change either later.
extends Screen


func build() -> void:
	var head := UI.vbox(8)
	head.add_child(UI.spacer(24))
	var logo := CenterContainer.new()
	logo.add_child(Logo.make(64))
	head.add_child(logo)
	var name_ := UI.label(tr("APP_NAME"), UI.DISPLAY, 600, "text", true, false)
	name_.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(name_)
	var tag := UI.label(tr("WELCOME_TAG"), UI.BODY, 500, "muted")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(tag)
	add_child(head)

	var ask := UI.label(tr("WELCOME_WHO"), UI.TITLE_L, 600, "text", true)
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ask)
	add_child(_choice("kid", "WELCOME_CHILD", true))
	add_child(_choice("grownup", "WELCOME_ADULT", false))


func _choice(icon: String, key: String, child: bool) -> Control:
	var ic := PanelContainer.new()
	ic.add_theme_stylebox_override("panel", UI.box(Pal.c("surface2"), 16, 0))
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(60, 60)
	cc.add_child(Glyph.make(icon, 38, Pal.c("accent_text")))
	ic.add_child(cc)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := UI.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UI.label(tr(key), UI.TITLE_S, 600, "text", true))
	text.add_child(UI.label(tr(key + "_DESC"), UI.BODY, 500, "muted"))
	var row := UI.hbox(14)
	row.add_child(ic)
	row.add_child(text)
	return UI.tappable(row, Pal.c("surface"), func(): app.welcome(child), tr(key), 22, 16, true)
