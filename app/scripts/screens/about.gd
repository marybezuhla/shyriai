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

	add_child(_letter())
	add_child(_support())

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


# The author's letter, as in her other apps: how the idea came, the war, the support; her photo and name.
func _letter() -> Control:
	var v := UI.vbox(12)
	for i in range(1, 8):
		var p := UI.label(tr("LETTER_%d" % i), 15, 500)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(p)
	var sig := UI.label(tr("LETTER_SIGN"), 15, 600, "accent_text")
	sig.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sig)
	v.add_child(_photo(72))
	var who := UI.label(tr("AUTHOR_NAME"), 14, 600)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	return UI.panel(v, Pal.c("surface"))


# A small round photo: the picture is cut to the circle of its frame.
func _photo(px: int) -> Control:
	var frame := PanelContainer.new()
	var circle := StyleBoxFlat.new()
	circle.bg_color = Pal.c("surface")
	circle.set_corner_radius_all(px / 2)
	frame.add_theme_stylebox_override("panel", circle)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	frame.custom_minimum_size = Vector2(px, px)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pic := TextureRect.new()
	pic.texture = load("res://assets/author_photo.jpg")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(px, px)
	frame.add_child(pic)
	return frame


# Support Ukraine: official sites only. In Kids mode nothing opens the browser: the address is only shown.
func _support() -> Control:
	var v := UI.vbox(10)
	v.add_child(UI.eyebrow(tr("SUPPORT_TITLE")))
	v.add_child(UI.label(tr("SUPPORT_KIDS") if Prefs.mode == "kids" else tr("SUPPORT_NOTE"), 13, 500, "muted"))
	# Learning first (Brave1), then the state's own fundraising
	for group in [["SUPPORT_DEFENCE", ["BRAVE1", "UNITED24_DEFENCE", "NBU"]], ["SUPPORT_HUMANITARIAN", ["UNITED24_HUMANITARIAN", "REDCROSS"]]]:
		v.add_child(UI.label(tr(group[0]), 15, 700, "accent_text"))
		for org in group[1]:
			v.add_child(_cause(org))
	v.add_child(UI.label(tr("SUPPORT_ANY"), 13, 500, "muted"))
	return v


func _cause(key: String) -> Control:
	var base: String = key.trim_suffix("_DEFENCE").trim_suffix("_HUMANITARIAN")
	var url: String = tr("ORG_%s_URL" % base)
	var what: String = tr("ORG_%s" % key) if key != base else tr("ORG_%s_WHAT" % base)
	var col := UI.vbox(2)
	col.add_child(UI.label(tr("ORG_%s" % base), 15, 700))
	col.add_child(UI.label(what, 13, 500, "muted"))
	col.add_child(UI.label(url.trim_prefix("https://").get_slice("/", 0), 13, 700, "accent_text"))
	if Prefs.mode == "kids":
		return UI.panel(col, Pal.c("surface"))
	return UI.tappable(col, Pal.c("surface"), func(): OS.shell_open(url), tr("ORG_%s" % base))

