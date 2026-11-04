# SPDX-License-Identifier: GPL-3.0-or-later
# One theory card: a few short points. Kids mode shows its own simpler points.
extends Screen

var card := ""


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
		var t := UI.label(point.strip_edges(), 15, 500)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		list.add_child(row)
	add_child(UI.panel(list, Pal.c("surface"), 22, 18))
	var src_key := card + "_SOURCES"
	if tr(src_key) != src_key:
		var v := UI.vbox(6)
		v.add_child(UI.eyebrow(tr("SOURCES")))
		v.add_child(UI.label(tr(src_key), 13, 500, "muted"))
		add_child(v)
