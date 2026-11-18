# SPDX-License-Identifier: GPL-3.0-or-later
# One theory card: a few short points. Kids mode shows its own simpler points.
extends Screen

var card := ""
## The answer picked for each question of "Check yourself", while this card is open.
var picked := {}


func build() -> void:
	add_child(header(tr(card)))
	var body_key := card + ("_KIDS" if Prefs.mode == "kids" else "_BODY")
	add_child(UI.panel(UI.points(tr(body_key)), Pal.c("surface"), 22, 18))
	var src_key := card + "_SOURCES"
	if tr(src_key) != src_key:
		var v := UI.vbox(6)
		v.add_child(UI.eyebrow(tr("SOURCES")))
		v.add_child(UI.label(tr(src_key), UI.SMALL, 500, "muted"))
		add_child(v)
	add_child(Quiz.panel(card, picked, rebuild))
