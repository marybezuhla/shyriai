# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's licences: one card for each vehicle whose lessons are all passed in this mode. Kids get a
# certificate instead, with no numbers. The name is optional and stays on this phone.
extends Screen

const ICONS := {"camera": "camera", "fpv": "fpv", "ugv": "ugv", "survey": "photo", "intercept": "intercept"}


func build() -> void:
	var kids := Prefs.mode == "kids"
	add_child(header(tr("CARDS_TITLE_KIDS" if kids else "CARDS_TITLE"), tr("MODE_" + Prefs.mode.to_upper())))

	var name_box := UI.vbox(6)
	name_box.add_child(UI.eyebrow(tr("CARD_NAME")))
	name_box.add_child(_name_field())
	name_box.add_child(UI.label(tr("CARD_NAME_DESC"), 13, 500, "muted"))
	add_child(name_box)

	for v in Curriculum.VEHICLES:
		var date := Prefs.licence_date(v)
		if date != "":
			add_child(_card(v, date, kids))


func _name_field() -> LineEdit:
	var e := LineEdit.new()
	e.text = Prefs.pilot_name
	e.max_length = Prefs.NAME_MAX
	e.placeholder_text = tr("CARD_NAME_HINT")
	e.custom_minimum_size = Vector2(0, 52)
	e.add_theme_font_override("font", Pal.font(600))
	e.add_theme_font_size_override("font_size", roundi(16 * Pal.text_scale()))
	e.add_theme_color_override("font_color", Pal.c("text"))
	e.add_theme_color_override("font_placeholder_color", Pal.c("faint"))
	e.add_theme_color_override("caret_color", Pal.c("text"))
	e.add_theme_stylebox_override("normal", UI.box(Pal.c("surface"), 14, 14, Pal.c("line"), 2))
	e.add_theme_stylebox_override("focus", UI.box(Pal.c("surface"), 14, 14, Pal.c("focus"), 2))
	e.set("accessibility_name", tr("CARD_NAME"))
	# Saved as typed; the cards below pick it up when the field is left.
	e.text_changed.connect(func(t): Prefs.set_pilot_name(t))
	# Deferred: focus is also lost while this screen is being rebuilt or closed
	# (Back), and rebuilding right inside that swallowed the tap.
	e.focus_exited.connect(_rebuild_later)
	e.text_submitted.connect(func(_t): e.release_focus())
	return e


func _rebuild_later() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		(func():
			if is_inside_tree() and not is_queued_for_deletion():
				rebuild()
		).call_deferred()


func _card(vehicle: String, date: String, kids: bool) -> Control:
	var col := UI.vbox(8)
	var top := UI.hbox(8)
	var brand := UI.eyebrow(tr("CARD_BRAND"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	top.add_child(Glyph.make(ICONS[vehicle], 26, Pal.c("accent_text")))
	col.add_child(top)
	col.add_child(UI.label(tr("CARD_KIDS" if kids else "CARD"), 22, 600, "text", true))
	col.add_child(UI.label(Curriculum.label("VEH_" + vehicle.to_upper()), 14, 600, "muted"))

	var who := UI.vbox(2)
	var shown := Prefs.pilot_name if Prefs.pilot_name != "" else " "
	who.add_child(UI.label(shown, 20, 600, "text", true))
	var line := Panel.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 1, 0))
	who.add_child(line)
	col.add_child(who)

	if kids:
		# No numbers for kids: the sunflowers and a few words say it.
		var flowers := UI.hbox(6)
		for i in Rating.MAX:
			flowers.add_child(Glyph.make("sunflower", 34, Pal.c("accent")))
		col.add_child(flowers)
		col.add_child(UI.label(tr("CARD_KIDS_FOR"), 14, 600, "text"))
	else:
		var facts := UI.hbox(12)
		var when := UI.vbox(2)
		when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		when.add_child(UI.label(tr("CARD_EXAM"), 12, 600, "muted"))
		when.add_child(UI.label(_date_text(date), 15, 700, "text", false, false))
		facts.add_child(when)
		var sf := Prefs.sunflowers_of(vehicle)
		var score := UI.vbox(2)
		score.add_child(UI.label(tr("CARD_SUNFLOWERS"), 12, 600, "muted"))
		var srow := UI.hbox(4)
		srow.add_child(Glyph.make("sunflower", 18, Pal.c("accent")))
		srow.add_child(UI.label(tr("CARD_OF") % [sf.x, sf.y], 15, 700, "text", false, false))
		score.add_child(srow)
		facts.add_child(score)
		col.add_child(facts)
		col.add_child(UI.label(tr("CARD_NOTE"), 12, 500, "muted"))

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Pal.c("surface"), 22, 18, Pal.c("accent_text"), 2))
	p.add_child(col)
	return p


## 2026-11-06 as "6 November 2026" / "6 листопада 2026".
func _date_text(date: String) -> String:
	var parts := date.split("-")
	return tr("DATE_FMT") % [int(parts[2]), tr("MONTH_%d" % int(parts[1])), parts[0]]
