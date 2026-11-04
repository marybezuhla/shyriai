# SPDX-License-Identifier: GPL-3.0-or-later
# Lessons and missions of one vehicle.
extends Screen

var vehicle := "camera"
var tab := "learn"
var selected := -1


func build() -> void:
	var lessons := Curriculum.lessons(vehicle)
	var done := Prefs.passed_count(vehicle)
	if selected < 0:
		selected = mini(done, lessons.size() - 1)

	add_child(header(tr("VEH_" + vehicle.to_upper()),
		"%s · %s" % [tr("MODE_" + Prefs.mode.to_upper()), tr("LESSONS_OF") % [done, lessons.size()]]))

	add_child(UI.segmented([["learn", tr("TAB_LEARN")], ["missions", tr("TAB_MISSIONS")]], tab,
		func(t): tab = t; rebuild()))

	if tab == "learn":
		_build_lessons(lessons, done)
	else:
		_build_missions()


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
		text.add_child(UI.label(tr(lessons[i]), 15, 700, "text" if i <= done else "muted"))
		text.add_child(UI.label(tr(lessons[i] + "_NOTE"), 12, 500, "muted"))
		var row := UI.hbox(14)
		row.add_child(UI.spacer(0, 40 if i % 2 else 0))
		row.add_child(dot)
		row.add_child(text)
		var idx := i
		var t := UI.tappable(row, Color(0, 0, 0, 0), func(): selected = idx; rebuild(), tr(lessons[i]), 14, 2)
		path.add_row(t, dot)
	add_child(path)
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
	head.add_child(UI.label(tr(key), 18, 600, "text", true))
	head.add_child(UI.label(tr(key + "_GOAL"), 14, 500, "muted"))
	card.add_child(head)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for part in tr(key + "_PASS").split("|"):
		chips.add_child(UI.panel(UI.label(part.strip_edges(), 12, 700, "text", false, false), Pal.c("surface2"), 10, 7))
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
		text.add_child(UI.label(tr(m), 16, 700))
		text.add_child(UI.label(tr(m + "_DESC"), 13, 500, "muted"))
		var row := UI.hbox(12)
		row.add_child(text)
		var done: bool = m in Prefs.missions_done
		row.add_child(Glyph.make("check" if done else "chevron", 20, Pal.c("accent_text" if done else "muted")))
		var title := tr(m)
		var key: String = m
		list.add_child(UI.tappable(row, Pal.c("surface"), func(): app.start(vehicle, key), title))
	add_child(list)
