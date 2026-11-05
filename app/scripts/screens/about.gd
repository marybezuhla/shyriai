# SPDX-License-Identifier: GPL-3.0-or-later
# Name, version, licence, source code and the authors of everything inside. Required by the GPL.
extends Screen

const SOURCE_URL := "https://github.com/marybezuhla/shyriai"


func build() -> void:
	add_child(header(tr("ABOUT")))

	var top := UI.hbox(14)
	top.add_child(Logo.make(64))
	var names := UI.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UI.label(tr("APP_NAME"), 22, 600, "text", true))
	names.add_child(UI.label(tr("ABOUT_VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 13, 600, "muted"))
	top.add_child(names)
	add_child(top)

	add_child(UI.label(tr("ABOUT_WHAT"), 15, 500))
	add_child(UI.label(tr("ABOUT_COPYRIGHT"), 13, 600, "muted"))

	add_child(_section(tr("ABOUT_LICENSE_T"), tr("ABOUT_LICENSE")))
	var src := UI.vbox(6)
	src.add_child(UI.eyebrow(tr("ABOUT_SOURCE_T")))
	var link_row := UI.hbox(10)
	var url := UI.label(SOURCE_URL.trim_prefix("https://"), 15, 700, "accent_text")
	url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link_row.add_child(url)
	link_row.add_child(Glyph.make("link", 18, Pal.c("accent_text")))
	if Prefs.mode == "kids":
		# In Kids mode the address is only shown: nothing here opens the web browser.
		link_row.get_child(1).queue_free()
		src.add_child(UI.panel(link_row, Pal.c("surface")))
	else:
		src.add_child(UI.tappable(link_row, Pal.c("surface"), func(): OS.shell_open(SOURCE_URL), tr("ABOUT_SOURCE_T")))
	add_child(src)
	add_child(_section(tr("ABOUT_MADE_T"), tr("ABOUT_MADE")))
	add_child(_section(tr("ABOUT_PARTS_T"), tr("ABOUT_PARTS")))

	var row := UI.hbox(12)
	var t := UI.label(tr("ABOUT_FULL_LICENSES"), 15, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(Glyph.make("chevron", 20, Pal.c("muted")))
	add_child(UI.tappable(row, Pal.c("surface"), func(): app.open_licenses(), tr("ABOUT_FULL_LICENSES")))


func _section(title: String, body: String) -> Control:
	var v := UI.vbox(6)
	v.add_child(UI.eyebrow(title))
	v.add_child(UI.label(body, 14, 500, "muted"))
	return v
