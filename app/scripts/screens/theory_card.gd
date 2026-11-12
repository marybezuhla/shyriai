# SPDX-License-Identifier: GPL-3.0-or-later
# One theory card: a few short points. Kids mode shows its own simpler points.
extends Screen

var card := ""
## The answer picked for each question of "Check yourself", while this card is open.
var picked := {}


func build() -> void:
	add_child(header(tr(card)))
	var body_key := card + ("_KIDS" if Prefs.mode == "kids" else "_BODY")
	var list := UI.vbox(10)
	for point in tr(body_key).split("|"):
		var row := UI.hbox(12)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		dot.draw.connect(func(): dot.draw_circle(Vector2(5, 11), 4.0, Pal.c("accent"), true, -1.0, true))
		row.add_child(dot)
		var t := UI.label(point.strip_edges(), UI.TEXT, 500)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		list.add_child(row)
	add_child(UI.panel(list, Pal.c("surface"), 22, 18))
	var src_key := card + "_SOURCES"
	if tr(src_key) != src_key:
		var v := UI.vbox(6)
		v.add_child(UI.eyebrow(tr("SOURCES")))
		v.add_child(UI.label(tr(src_key), UI.SMALL, 500, "muted"))
		add_child(v)
	add_child(_quiz())


## "Check yourself": a few questions from this card. The options come in a fixed shuffled order, so
## a rebuild never moves them under the finger; a wrong pick shows the right one and why.
func _quiz() -> Control:
	var kids := Prefs.mode == "kids"
	var n: int = Curriculum.QUIZ["kids" if kids else "adult"]
	var col := UI.vbox(14)
	col.add_child(UI.eyebrow(tr("QUIZ")))
	var right := 0
	for i in range(1, n + 1):
		var q := "Q_%s%s_%d" % [card, "_KIDS" if kids else "", i]
		var box := UI.vbox(8)
		box.add_child(UI.label(tr(q), UI.LEAD, 700))
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
			var l := UI.label(tr(q + "_" + opt), UI.BODY, 600, "on_accent" if shown and is_right else "text")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var pick := func():
				if chosen == "":
					picked[q] = opt
					rebuild()
			box.add_child(UI.tappable(row, bg, pick, tr(q + "_" + opt), 14, 12))
		if chosen != "":
			if chosen == "A":
				right += 1
				box.add_child(UI.label(tr("QUIZ_RIGHT") + " " + tr(q + "_WHY"), UI.SMALL, 600, "accent_text"))
			else:
				box.add_child(UI.label(tr("QUIZ_WRONG") + " " + tr(q + "_WHY"), UI.SMALL, 600, "muted"))
		col.add_child(box)
	if right == n:
		col.add_child(UI.label(tr("QUIZ_ALL"), UI.TEXT, 700, "accent_text"))
	return UI.panel(col, Pal.c("surface"), 22, 18)

