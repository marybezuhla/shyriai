# SPDX-License-Identifier: GPL-3.0-or-later
# First screen: who is flying, what to continue, which vehicle.
extends Screen

const VEHICLE_ICONS := {"camera": "camera", "fpv": "fpv", "ugv": "ugv"}


func build() -> void:
	# App name and settings
	var top := UI.hbox(10)
	top.add_child(Logo.make(36))
	var app_name := UI.label(tr("APP_NAME"), 20, 600, "text", true, false)
	app_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(app_name)
	top.add_child(UI.icon_button("gear", func(): app.guard(app.open_settings), tr("SETTINGS"), Pal.c("surface")))
	add_child(top)

	# Mode
	var mode_box := UI.vbox(12)
	mode_box.add_child(UI.label(tr("HOME_WHO"), 24, 600, "text", true))
	mode_box.add_child(UI.segmented([
		["kids", tr("MODE_KIDS")], ["simple", tr("MODE_SIMPLE")], ["pro", tr("MODE_PRO")],
	], Prefs.mode, _pick_mode))
	var desc := UI.label(tr("MODE_%s_DESC" % Prefs.mode.to_upper()), 14, 500, "muted")
	desc.custom_minimum_size = Vector2(0, 40)
	mode_box.add_child(desc)
	add_child(mode_box)

	add_child(_continue_card())

	# Vehicles
	var list := UI.vbox(10)
	list.add_child(UI.eyebrow(tr("HOME_WHAT")))
	for v in Curriculum.VEHICLES:
		list.add_child(_vehicle_card(v))
	add_child(list)


func _pick_mode(m: String) -> void:
	# Leaving Kids mode may need a grown-up.
	if Prefs.mode == "kids" and m != "kids":
		app.guard(func(): Prefs.set_mode(m))
	else:
		Prefs.set_mode(m)


func _continue_card() -> Control:
	# Continue where the pilot stopped; the camera drone is where everyone starts.
	var vehicle := "camera"
	for v in Curriculum.VEHICLES:
		if Prefs.passed_count(v) > Prefs.passed_count(vehicle):
			vehicle = v
	var lessons := Curriculum.lessons(vehicle)
	var done := Prefs.passed_count(vehicle)
	var idx := mini(done, lessons.size() - 1)

	var text := UI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.eyebrow(tr("HOME_CONTINUE") if done > 0 else tr("HOME_START"), "on_accent"))
	text.add_child(UI.label(tr("LESSON_N") % (idx + 1) + ". " + tr(lessons[idx]), 16, 600, "on_accent", true))
	text.add_child(UI.label("%s · %s" % [tr("VEH_" + vehicle.to_upper()), tr("LESSONS_OF") % [done, lessons.size()]], 13, 600, "on_accent"))

	var play := PanelContainer.new()
	play.add_theme_stylebox_override("panel", UI.box(Pal.c("on_accent"), 24, 0))
	var pc := CenterContainer.new()
	pc.custom_minimum_size = Vector2(48, 48)
	pc.add_child(Glyph.make("play", 20, Pal.c("accent")))
	play.add_child(pc)
	play.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := UI.hbox(14)
	row.add_child(text)
	row.add_child(play)
	return UI.tappable(row, Pal.c("accent"), func(): app.open_lessons(vehicle), tr("HOME_CONTINUE"), 20, 16)


func _vehicle_card(v: String) -> Control:
	var icon_bg := PanelContainer.new()
	icon_bg.add_theme_stylebox_override("panel", UI.box(Pal.c("surface2"), 16, 0))
	var ic := CenterContainer.new()
	ic.custom_minimum_size = Vector2(52, 52)
	ic.add_child(Glyph.make(VEHICLE_ICONS[v], 30, Pal.c("accent_text")))
	icon_bg.add_child(ic)

	var text := UI.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UI.label(tr("VEH_" + v.to_upper()), 16, 700))
	text.add_child(UI.label(tr("VEH_%s_DESC" % v.to_upper()), 13, 500, "muted"))

	var done := Prefs.passed_count(v)
	var count := UI.label("%d/%d" % [done, Curriculum.lessons(v).size()], 13, 700, "accent_text" if done > 0 else "muted", false, false)

	var row := UI.hbox(14)
	row.add_child(icon_bg)
	row.add_child(text)
	row.add_child(count)
	return UI.tappable(row, Pal.c("surface"), func(): app.open_lessons(v), tr("VEH_" + v.to_upper()))
