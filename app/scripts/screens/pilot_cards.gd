# SPDX-License-Identifier: GPL-3.0-or-later
# The pilot's licences: one card for each vehicle whose lessons are all passed in this mode. Kids get a
# certificate instead, with no numbers. The name is optional and stays on this phone.
extends Screen


func build() -> void:
	var kids := Prefs.mode == "kids"
	add_child(header(tr("CARDS_TITLE_KIDS" if kids else "CARDS_TITLE"), tr("MODE_" + Prefs.mode.to_upper())))

	var name_box := UI.vbox(6)
	name_box.add_child(UI.eyebrow(tr("CARD_NAME")))
	name_box.add_child(_name_field())
	name_box.add_child(UI.label(tr("CARD_NAME_DESC"), UI.SMALL, 500, "muted"))
	add_child(name_box)

	for v in Curriculum.VEHICLES:
		var date := Prefs.licence_date(v)
		if date != "":
			var card := _card(v, date, kids)
			add_child(card)
			add_child(UI.secondary(tr("CARD_BIG"), func(): _show_big(v, date, kids)))

	add_child(UI.eyebrow(tr("RECORDS")))
	var any := false
	for v in Curriculum.VEHICLES:
		var r := _records(v, kids)
		if r:
			add_child(r)
			any = true
	if not any:
		add_child(UI.label(tr("RECORDS_NONE"), UI.BODY, 500, "muted"))


## The best result of every lesson and mission of a vehicle in this mode: sunflowers, and for
## grown-ups the time. Null if nothing is flown yet.
func _records(v: String, kids: bool) -> Control:
	var keys: Array = Curriculum.lessons(v, Prefs.mode) + Curriculum.missions(v, Prefs.mode)
	if keys.all(func(k): return Prefs.best_of(k).is_empty()):
		return null
	var col := UI.vbox(8)
	col.add_child(UI.label(Curriculum.label("VEH_" + v.to_upper()), UI.LEAD, 700))
	for k in keys:
		var b := Prefs.best_of(k)
		var row := UI.hbox(6)
		var name_ := UI.label(Curriculum.label(k), UI.SMALL, 600, "text" if not b.is_empty() else "faint")
		name_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_)
		if b.is_empty():
			row.add_child(UI.label(tr("RECORDS_NOT_YET"), UI.SMALL, 500, "faint", false, false))
		else:
			for i in int(b["f"]):
				row.add_child(Glyph.make("sunflower", 16, Pal.c("accent")))
			if not kids:
				row.add_child(UI.label(FlightTask.clock(float(b["t"])), UI.SMALL, 700, "text", false, false))
		col.add_child(row)
	return UI.panel(col, Pal.c("surface"), 18, 14)


## The card on the whole screen, big, for a screenshot with the phone's own buttons. Nothing is
## saved or shared by the app. A tap anywhere closes it.
func _show_big(v: String, date: String, kids: bool) -> void:
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Pal.c("bg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := UI.vbox(14)
	var card := _card(v, date, kids)
	card.custom_minimum_size = Vector2(minf(get_viewport_rect().size.x - 40.0, 520.0), 0)
	col.add_child(card)
	var hint := UI.label(tr("CARD_BIG_HINT"), UI.SMALL, 500, "muted")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = card.custom_minimum_size
	col.add_child(hint)
	center.add_child(col)
	cover.add_child(center)
	var close := Button.new()
	close.flat = true
	close.set_anchors_preset(Control.PRESET_FULL_RECT)
	close.set("accessibility_name", tr("CLOSE"))
	cover.add_child(close)
	# Over everything, and gone with this screen.
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(cover)
	close.pressed.connect(layer.queue_free)
	add_child(layer)


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
	top.add_child(Glyph.make(Curriculum.ICONS[vehicle], 26, Pal.c("accent_text")))
	col.add_child(top)
	col.add_child(UI.label(tr("CARD_KIDS" if kids else "CARD"), UI.TITLE_L, 600, "text", true))
	col.add_child(UI.label(Curriculum.label("VEH_" + vehicle.to_upper()), UI.BODY, 600, "muted"))

	var who := UI.vbox(2)
	var shown := Prefs.pilot_name if Prefs.pilot_name != "" else " "
	who.add_child(UI.label(shown, UI.TITLE, 600, "text", true))
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
		col.add_child(UI.label(tr("CARD_KIDS_FOR"), UI.BODY, 600, "text"))
	else:
		# Side by side, or one under the other with larger text so no word breaks.
		var facts: BoxContainer = UI.vbox(8) if Pal.text_scale() > 1.15 else UI.hbox(12)
		var when := UI.vbox(2)
		when.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		when.add_child(UI.label(tr("CARD_EXAM"), UI.CAPTION, 600, "muted"))
		when.add_child(UI.label(_date_text(date), UI.TEXT, 700, "text", false, false))
		facts.add_child(when)
		var sf := Prefs.sunflowers_of(vehicle)
		var score := UI.vbox(2)
		score.add_child(UI.label(tr("CARD_SUNFLOWERS"), UI.CAPTION, 600, "muted"))
		var srow := UI.hbox(4)
		srow.add_child(Glyph.make("sunflower", 18, Pal.c("accent")))
		srow.add_child(UI.label(tr("CARD_OF") % [sf.x, sf.y], UI.TEXT, 700, "text", false, false))
		score.add_child(srow)
		facts.add_child(score)
		col.add_child(facts)
		col.add_child(UI.label(tr("CARD_NOTE"), UI.CAPTION, 500, "muted"))

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Pal.c("surface"), 22, 18, Pal.c("accent_text"), 2))
	p.add_child(col)
	return p


## 2026-11-06 as "6 November 2026" / "6 листопада 2026".
func _date_text(date: String) -> String:
	var parts := date.split("-")
	return tr("DATE_FMT") % [int(parts[2]), tr("MONTH_%d" % int(parts[1])), parts[0]]
