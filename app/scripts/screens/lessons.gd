# SPDX-License-Identifier: GPL-3.0-or-later
# Lessons and missions of one vehicle.
extends Screen

var vehicle := "camera"
var tab := "learn"
var selected := -1


func build() -> void:
	var lessons := Curriculum.lessons(vehicle, Prefs.mode)
	var done := Prefs.passed_count(vehicle)
	if selected < 0:
		selected = mini(done, lessons.size() - 1)

	add_child(header(Curriculum.label("VEH_" + vehicle.to_upper()),
		"%s · %s" % [tr("MODE_" + Prefs.mode.to_upper()), tr("LESSONS_OF") % [done, lessons.size()]]))

	add_child(UI.segmented([
		["learn", tr("TAB_LEARN")], ["missions", tr("TAB_MISSIONS")],
		["free", tr("TAB_FREE_UGV" if vehicle == "ugv" else "TAB_FREE")],
	], tab, func(t): tab = t; rebuild()))

	if tab == "learn":
		_build_lessons(lessons, done)
	elif tab == "missions":
		_build_missions()
	else:
		_build_free()


func _build_lessons(lessons: Array, done: int) -> void:
	var path := LessonPath.new()
	path.passed = done
	path.current = mini(done, lessons.size() - 1)
	for i in lessons.size():
		var state := "done" if i < done else ("next" if i == done else "locked")
		var dot := _dot(i, state)
		var text := UI.vbox(1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.add_child(UI.label(Curriculum.label(lessons[i]), 15, 700, "text" if i <= done else "muted"))
		text.add_child(UI.label(tr(Curriculum.text_key(lessons[i] + "_NOTE", Prefs.mode)), 13, 500, "muted"))
		if state == "done":
			text.add_child(_flowers(lessons[i], 16))
		var row := UI.hbox(14)
		row.add_child(UI.spacer(0, 40 if i % 2 else 0))
		row.add_child(dot)
		row.add_child(text)
		var idx := i
		var state_name: String = {"done": tr("A11Y_DONE"), "next": "", "locked": tr("A11Y_LOCKED")}[state]
		if state == "done":
			state_name += ", " + tr("A11Y_SUNFLOWERS") % _got(lessons[i])
		var name_: String = Curriculum.label(lessons[i]) + (", " + state_name if state_name != "" else "")
		var t := UI.tappable(row, Color(0, 0, 0, 0), func(): selected = idx; rebuild(), name_, 14, 2)
		path.add_row(t, dot)
	add_child(path)
	if Prefs.mode != "pro" and Curriculum.lessons(vehicle).any(func(k): return k in Curriculum.PRO_ONLY):
		add_child(UI.label(tr("LESSON_PRO_ONLY"), 13, 600, "muted"))
	add_child(_lesson_card(lessons, done))


func _dot(i: int, state: String) -> Control:
	var p := PanelContainer.new()
	var bg := Pal.c("accent") if state == "done" else Pal.c("bg")
	var border := Pal.c("accent") if state == "next" else Pal.c("line")
	p.add_theme_stylebox_override("panel", UI.box(bg, 22, 0, border, 0 if state == "done" else (3 if state == "next" else 2)))
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(44, 44)
	if state == "done":
		c.add_child(Glyph.make("check", 20, Pal.c("on_accent")))
	else:
		var n := UI.label(str(i + 1), 15, 800, "accent_text" if state == "next" else "faint", false, false)
		c.add_child(n)
	p.add_child(c)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _lesson_card(lessons: Array, done: int) -> Control:
	var key: String = lessons[selected]
	var card := UI.vbox(12)
	var head := UI.vbox(4)
	head.add_child(UI.eyebrow(tr("LESSON_N") % (selected + 1), "accent_text"))
	head.add_child(UI.label(Curriculum.label(key), 18, 600, "text", true))
	head.add_child(UI.label(tr(Curriculum.text_key(key + "_GOAL", Prefs.mode)), 14, 500, "muted"))
	card.add_child(head)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for part in tr(Curriculum.text_key(key + "_PASS", Prefs.mode)).split("|"):
		chips.add_child(UI.panel(UI.label(part.strip_edges(), 13, 700, "text", false, false), Pal.c("surface2"), 10, 7))
	card.add_child(chips)
	if selected <= done:
		card.add_child(UI.primary(tr("LESSON_START"), func(): app.start(vehicle, key), "play"))
	else:
		card.add_child(UI.label(tr("LESSON_LOCKED"), 13, 600, "muted"))
	return UI.panel(card, Pal.c("surface"), 22, 18)


func _build_missions() -> void:
	var list := UI.vbox(10)
	for m in Curriculum.missions(vehicle, Prefs.mode):
		var text := UI.vbox(3)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UI.label(Curriculum.label(m), 16, 700))
		text.add_child(UI.label(tr(m + "_DESC"), 13, 500, "muted"))
		if Prefs.mission_done(m):
			text.add_child(_flowers(m, 16))
		var row := UI.hbox(12)
		row.add_child(text)
		var done: bool = Prefs.mission_done(m)
		row.add_child(Glyph.make("check" if done else "chevron", 20, Pal.c("accent_text" if done else "muted")))
		var title := Curriculum.label(m)
		if Prefs.mission_done(m):
			title += ", " + tr("A11Y_SUNFLOWERS") % _got(m)
		var key: String = m
		list.add_child(UI.tappable(row, Pal.c("surface"), func(): app.start(vehicle, key), title))
	add_child(list)


func _got(key: String) -> int:
	# Passes from before sunflowers existed still count as one.
	return maxi(1, int(Prefs.best_of(key).get("f", 1)))


## The sunflowers of a passed lesson or mission: earned ones in bloom, the rest as outlines.
func _flowers(key: String, px: int) -> Control:
	var row := UI.hbox(2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var got := _got(key)
	for i in Rating.MAX:
		row.add_child(Glyph.make("sunflower" if i < got else "sunflower_off", px, Pal.c("accent" if i < got else "line")))
	return row


## Free flight: no task, the pilot picks the conditions. Kids just fly, with no wind.
func _build_free() -> void:
	var col := UI.vbox(14)
	col.add_child(UI.label(tr("FREE_DESC_UGV" if vehicle == "ugv" else "FREE_DESC"), 14, 500, "muted"))
	if Prefs.mode != "kids":
		if vehicle != "ugv":
			col.add_child(UI.eyebrow(tr("FREE_WIND")))
			col.add_child(UI.segmented([
				["none", tr("FREE_WIND_NONE")], ["light", tr("FREE_WIND_LIGHT")], ["gusty", tr("FREE_WIND_GUSTY")],
			], Prefs.free["wind"], func(v): Prefs.set_free("wind", v)))
		col.add_child(UI.eyebrow(tr("FREE_TIME")))
		col.add_child(UI.segmented([["day", tr("FREE_TIME_DAY")], ["dusk", tr("FREE_TIME_DUSK")]],
			Prefs.free["time"], func(v): Prefs.set_free("time", v)))
		if vehicle == "fpv" and Prefs.mode == "pro":
			col.add_child(UI.eyebrow(tr("FREE_FPV_MODE")))
			col.add_child(UI.segmented([["angle", "Angle"], ["horizon", "Horizon"], ["acro", "Acro"]],
				Prefs.free["fpv"], func(v): Prefs.set_free("fpv", v)))
	col.add_child(UI.switch_row(tr("FREE_BALLS"), tr("FREE_BALLS_DESC"), Prefs.free["balls"],
		func(on): Prefs.set_free("balls", on)))
	var key := "FREE_" + vehicle.to_upper()
	col.add_child(UI.primary(tr("FREE_GO_UGV" if vehicle == "ugv" else "FREE_GO"), func(): app.start(vehicle, key), "play"))
	add_child(col)

