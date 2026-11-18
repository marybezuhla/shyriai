# SPDX-License-Identifier: GPL-3.0-or-later
# The kids' little book: a big picture and a sentence or two a page, dots instead of page numbers.
extends Screen

var page := 0


func build() -> void:
	var pages := Book.KIDS_PAGES.size()
	page = clampi(page, 0, pages - 1)
	add_child(header(tr("BOOK_KIDS")))
	var pic := HBoxContainer.new()
	pic.alignment = BoxContainer.ALIGNMENT_CENTER
	pic.add_theme_constant_override("separation", 18)
	pic.custom_minimum_size = Vector2(0, 170)
	for g in Book.KIDS_PAGES[page]:
		pic.add_child(Glyph.make(g, 96, Pal.c("text")))
	add_child(UI.panel(pic, Pal.TOY.values()[page % Pal.TOY.size()].lerp(Pal.c("surface"), 0.55), 26, 16))
	add_child(UI.label(tr("BOOK_KIDS_%d" % (page + 1)), UI.TITLE, 600))
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	for k in pages:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(12, 12)
		d.add_theme_stylebox_override("panel", UI.box(Pal.c("accent") if k <= page else Pal.c("line"), 6, 0))
		dots.add_child(d)
	add_child(dots)
	if page + 1 < pages:
		add_child(UI.primary(tr("BOOK_KIDS_NEXT"), func(): page += 1; rebuild()))
	else:
		add_child(UI.primary(tr("BOOK_KIDS_DONE"), func(): app.back()))
	if page > 0:
		add_child(UI.secondary(tr("BOOK_KIDS_BACK"), func(): page -= 1; rebuild()))
