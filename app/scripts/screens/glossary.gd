# SPDX-License-Identifier: GPL-3.0-or-later
# The words the lessons use, each with a line or two. Not in Kids mode: kids lessons avoid them.
extends Screen

const TERMS := [
	"THROTTLE", "YAW", "PITCH", "ROLL", "STICKMODE", "DEADZONE", "EXPO", "HOVER", "GIMBAL", "GPS",
	"RTH", "FAILSAFE", "LIPO", "ARM", "FPV", "MODES", "RATES", "LEAD",
	"AOA", "STALL", "SPIN", "CIRCUIT", "WINDSOCK", "GLIDE", "FLARE", "GOAROUND", "UGV",
]


func build() -> void:
	add_child(header(tr("GLOSSARY"), tr("GLOSSARY_DESC")))
	var list := UI.vbox(14)
	for t in TERMS:
		var item := UI.vbox(3)
		item.add_child(UI.label(tr("GL_%s_T" % t), UI.LEAD, 700))
		item.add_child(UI.label(tr("GL_" + t), UI.BODY, 500, "muted"))
		list.add_child(item)
	add_child(UI.panel(list, Pal.c("surface"), 22, 18))
