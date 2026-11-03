# SPDX-License-Identifier: GPL-3.0-or-later
extends Screen


func build() -> void:
	add_child(header(tr("SETTINGS")))

	var look := UI.vbox(10)
	look.add_child(UI.eyebrow(tr("SET_THEME")))
	look.add_child(UI.segmented([
		["dusk", tr("THEME_DUSK")], ["day", tr("THEME_DAY")], ["system", tr("THEME_SYSTEM")],
	], Prefs.theme, func(t): Prefs.set_theme(t)))
	add_child(look)

	var lang := UI.vbox(10)
	lang.add_child(UI.eyebrow(tr("SET_LANGUAGE")))
	lang.add_child(UI.segmented([
		["system", tr("LANG_SYSTEM")], ["uk", "Українська"], ["en", "English"],
	], Prefs.language, func(l): Prefs.set_language(l)))
	add_child(lang)

	var row := UI.hbox(14)
	row.add_child(Glyph.make("info", 22, Pal.c("accent_text")))
	var t := UI.label(tr("ABOUT"), 16, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	add_child(UI.tappable(row, Pal.c("surface"), func(): app.open_about(), tr("ABOUT")))
