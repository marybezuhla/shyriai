# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's book: its chapters, the ones read with a tick.
extends Screen


func build() -> void:
	add_child(header(tr("BOOK"), tr("BOOK_READ_N") % [Book.read_count(), Book.CHAPTERS.size()]))
	var list := UI.vbox(10)
	for i in Book.CHAPTERS.size():
		list.add_child(chapter_card(app, i))
	add_child(list)


## A chapter's card: its icon, number and name, what it is about, and a tick once read.
static func chapter_card(main: Node, i: int) -> Control:
	var ch: Dictionary = Book.CHAPTERS[i]
	var id: String = ch["id"]
	var title := "%d · %s" % [i + 1, TranslationServer.translate("BOOK_%s_T" % id)]
	var icon := PanelContainer.new()
	icon.add_theme_stylebox_override("panel", UI.box(Pal.c("surface2"), 12, 8))
	icon.add_child(Glyph.make(ch["icon"], 24, Pal.c("accent_text")))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var text := UI.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, UI.LEAD, 700))
	text.add_child(UI.label(TranslationServer.translate("BOOK_%s_DESC" % id), UI.SMALL, 500, "muted"))
	var row := UI.hbox(12)
	row.add_child(icon)
	row.add_child(text)
	var read := Book.is_read(id)
	row.add_child(Glyph.make("check" if read else "chevron", 20, Pal.c("ok") if read else Pal.c("muted")))
	var a11y := title + (" · " + String(TranslationServer.translate("BOOK_IS_READ")) if read else "")
	return UI.tappable(row, Pal.c("surface"), func(): main.open_chapter(id, false), a11y)
