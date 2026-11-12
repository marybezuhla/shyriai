# SPDX-License-Identifier: GPL-3.0-or-later
# Short safety cards.
extends Screen


func build() -> void:
	add_child(UI.label(tr("TAB_THEORY"), UI.DISPLAY, 600, "text", true))
	add_child(UI.label(tr("THEORY_INTRO"), UI.BODY, 500, "muted"))
	var list := UI.vbox(10)
	for t in Curriculum.THEORY:
		var text := UI.vbox(3)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UI.label(tr(t), UI.LEAD, 700))
		text.add_child(UI.label(tr(t + "_DESC"), UI.SMALL, 500, "muted"))
		var row := UI.hbox(12)
		row.add_child(text)
		row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
		var title := tr(t)
		var card: String = t
		list.add_child(UI.tappable(row, Pal.c("surface"), func(): app.open_theory(card), title))
	add_child(list)
