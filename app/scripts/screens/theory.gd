# SPDX-License-Identifier: GPL-3.0-or-later
# Theory: the pilot's book, the glossary and where to read on. Kids get their little book and their
# own short cards.
extends Screen


func build() -> void:
	add_child(UI.label(tr("TAB_THEORY"), UI.DISPLAY, 600, "text", true))
	var kids := Prefs.mode == "kids"
	add_child(UI.label(tr("THEORY_INTRO_KIDS" if kids else "THEORY_INTRO"), UI.BODY, 500, "muted"))
	var list := UI.vbox(10)
	if kids:
		list.add_child(_book_card(tr("BOOK_KIDS"), tr("BOOK_KIDS_DESC"), -1.0, func(): app.open_kids_book()))
		for t in Curriculum.THEORY:
			var card: String = t
			list.add_child(_card(tr(t), Curriculum.label(t + "_DESC"), func(): app.open_theory(card)))
	else:
		var total := Book.CHAPTERS.size()
		list.add_child(_book_card(tr("BOOK"), tr("BOOK_READ_N") % [Book.read_count(), total],
			float(Book.read_count()) / total, func(): app.open_book()))
		list.add_child(_card(tr("GLOSSARY"), tr("GLOSSARY_DESC"), func(): app.open_glossary()))
		var nxt := Book.next_unread()
		if nxt != "":
			list.add_child(UI.spacer(4))
			list.add_child(UI.eyebrow(tr("BOOK_READ_ON")))
			list.add_child(preload("res://scripts/screens/book_contents.gd").chapter_card(app, Book.index_of(nxt)))
	add_child(list)


## The book itself, larger and outlined, with how far the reading has got (share < 0: none).
func _book_card(title: String, desc: String, share: float, on_press: Callable) -> Control:
	var text := UI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, UI.TITLE_S, 700))
	text.add_child(UI.label(desc, UI.SMALL, 500, "muted"))
	if share >= 0.0:
		var bar := Panel.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", UI.box(Pal.c("accent"), 3, 0))
		bar.add_child(fill)
		bar.resized.connect(func(): fill.size = Vector2(bar.size.x * share, 6))
		text.add_child(bar)
	var row := UI.hbox(12)
	row.add_child(Glyph.make("theory", 30, Pal.c("accent_text")))
	row.add_child(text)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	return UI.tappable(row, Pal.c("surface"), on_press, title + ". " + desc, UI.RADIUS_CARD, 16, false, Pal.c("accent"))


func _card(title: String, desc: String, on_press: Callable) -> Control:
	var text := UI.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, UI.LEAD, 700))
	text.add_child(UI.label(desc, UI.SMALL, 500, "muted"))
	var row := UI.hbox(12)
	row.add_child(text)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	return UI.tappable(row, Pal.c("surface"), on_press, title)
