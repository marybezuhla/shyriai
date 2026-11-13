# SPDX-License-Identifier: GPL-3.0-or-later
# Short safety cards.
extends Screen


func build() -> void:
	add_child(UI.label(tr("TAB_THEORY"), UI.DISPLAY, 600, "text", true))
	add_child(UI.label(tr("THEORY_INTRO"), UI.BODY, 500, "muted"))
	var list := UI.vbox(10)
	if Prefs.mode != "kids":
		list.add_child(_card(tr("GLOSSARY"), tr("GLOSSARY_DESC"), func(): app.open_glossary()))
	for t in Curriculum.THEORY:
		var card: String = t
		list.add_child(_card(tr(t), tr(t + "_DESC"), func(): app.open_theory(card)))
	add_child(list)


func _card(title: String, desc: String, on_press: Callable) -> Control:
	var text := UI.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, UI.LEAD, 700))
	text.add_child(UI.label(desc, UI.SMALL, 500, "muted"))
	var row := UI.hbox(12)
	row.add_child(text)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	return UI.tappable(row, Pal.c("surface"), on_press, title)
