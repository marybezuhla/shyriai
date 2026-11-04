# SPDX-License-Identifier: GPL-3.0-or-later
# All missions, grouped by vehicle. Kids see their own stories.
extends Screen


func build() -> void:
	add_child(UI.label(tr("TAB_MISSIONS"), 24, 600, "text", true))
	add_child(UI.label(tr("MISSIONS_INTRO"), 14, 500, "muted"))
	for v in Curriculum.VEHICLES:
		var group := UI.vbox(10)
		group.add_child(UI.eyebrow(tr("VEH_" + v.to_upper())))
		for m in Curriculum.missions(v, Prefs.mode):
			var text := UI.vbox(3)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.add_child(UI.label(tr(m), 16, 700))
			text.add_child(UI.label(tr(m + "_DESC"), 13, 500, "muted"))
			var row := UI.hbox(12)
			row.add_child(text)
			var done: bool = m in Prefs.missions_done
			row.add_child(Glyph.make("check" if done else "chevron", 20, Pal.c("accent_text" if done else "muted")))
			var title := tr(m)
			var key: String = m
			var veh: String = v
			group.add_child(UI.tappable(row, Pal.c("surface"), func(): app.start(veh, key), title))
		add_child(group)
