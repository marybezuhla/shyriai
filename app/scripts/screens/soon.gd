# SPDX-License-Identifier: GPL-3.0-or-later
# Honest placeholder for parts that are not built yet.
extends Screen

var title := ""


func build() -> void:
	add_child(header(title))
	var col := UI.vbox(10)
	col.add_child(UI.label(tr("SOON_TITLE"), 18, 600, "text", true))
	col.add_child(UI.label(tr("SOON_TEXT"), 14, 500, "muted"))
	add_child(UI.panel(col, Pal.c("surface"), 22, 18))
