# SPDX-License-Identifier: GPL-3.0-or-later
# "Check yourself" under a theory card or a book chapter.
class_name Quiz
extends RefCounted


## "Check yourself": a few questions from this card. The options come in a fixed shuffled order, so
## a rebuild never moves them under the finger; a wrong pick shows the right one and why.
static func panel(card: String, picked: Dictionary, redraw: Callable) -> Control:
	var kids := Prefs.mode == "kids"
	var n: int = Curriculum.QUIZ["kids" if kids else "adult"]
	var col := UI.vbox(14)
	col.add_child(UI.eyebrow(_t("QUIZ")))
	var right := 0
	for i in range(1, n + 1):
		var q := "Q_%s%s_%d" % [card, "_KIDS" if kids else "", i]
		var box := UI.vbox(8)
		box.add_child(UI.label(_t(q), UI.LEAD, 700))
		var order := ["A", "B", "C"]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(q)
		for k in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp = order[k]
			order[k] = order[j]
			order[j] = tmp
		var chosen: String = picked.get(q, "")
		for o in order:
			var opt: String = o
			var is_right: bool = opt == "A"
			var shown := chosen != "" and (opt == chosen or is_right)
			var bg := Pal.c("surface2")
			if shown:
				bg = Pal.c("accent") if is_right else Pal.c("line")
			var row := UI.hbox(10)
			if shown:
				row.add_child(Glyph.make("check" if is_right else "cross", 18, Pal.c("on_accent" if is_right else "text")))
			var l := UI.label(_t(q + "_" + opt), UI.BODY, 600, "on_accent" if shown and is_right else "text")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var pick := func():
				if chosen == "":
					picked[q] = opt
					redraw.call()
			box.add_child(UI.tappable(row, bg, pick, _t(q + "_" + opt), 14, 12))
		if chosen != "":
			if chosen == "A":
				right += 1
				box.add_child(UI.label(_t("QUIZ_RIGHT") + " " + _t(q + "_WHY"), UI.SMALL, 600, "accent_text"))
			else:
				box.add_child(UI.label(_t("QUIZ_WRONG") + " " + _t(q + "_WHY"), UI.SMALL, 600, "muted"))
		col.add_child(box)
	if right == n:
		col.add_child(UI.label(_t("QUIZ_ALL"), UI.TEXT, 700, "accent_text"))
	return UI.panel(col, Pal.c("surface"), 22, 18)


static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
