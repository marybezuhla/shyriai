# SPDX-License-Identifier: GPL-3.0-or-later
# The top line of the flight screen: the lesson title with its progress bar, the flight numbers or
# the kids' counter, and "No signal" over late robot video. Kept apart from flight.gd so that file
# stays one topic; `f` is the flight screen.
class_name FlightHud
extends RefCounted


static func fit_top(f: Flight, top: HBoxContainer) -> void:
	var room := f.get_viewport_rect().size.x - 2.0 * Flight.SIDE - f._ins_x()
	var order := ["TIME", "BATTERY", "CLOSING", "SPEED", "TARGET", "ALT"]
	for n in order:
		if top.get_combined_minimum_size().x <= room:
			return
		if f._stats.has(n):
			var cell: Control = f._stats[n].get_parent()
			cell.get_parent().remove_child(cell)
			cell.queue_free()
			f._stats.erase(n)
	if f._stats.is_empty() and top.get_child_count() > 3:
		var panel := top.get_child(top.get_child_count() - 1)
		top.remove_child(panel)  # nothing left in the numbers panel
		panel.queue_free()
	# Still too wide (an unfolded phone held upright): the lesson title gets "…".
	var over := top.get_combined_minimum_size().x - room
	if over > 0.0:
		var title: Label = top.get_child(1).find_children("*", "Label", true, false)[0]
		var w := title.get_combined_minimum_size().x
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.clip_text = true
		title.custom_minimum_size.x = maxf(40.0, w - over)


static func build_no_signal(f: Flight) -> void:
	# "No signal" over the robot's video while the radio link is down.
	var nl := ColorRect.new()
	nl.color = Color(Pal.INK, 0.82)
	nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl_center := CenterContainer.new()
	nl_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl_text := Label.new()
	nl_text.text = f.tr("NO_SIGNAL")
	nl_text.add_theme_font_override("font", Pal.font(600, true))
	nl_text.add_theme_font_size_override("font_size", roundi(26 * Pal.text_scale()))
	nl_text.add_theme_color_override("font_color", Pal.CREAM)
	nl_center.add_child(nl_text)
	nl.add_child(nl_center)
	nl.visible = false
	f.add_child(nl)
	f._nolink = nl


## The title with its progress bar and, for loads, the comfort or cargo meter.
static func build_chip(f: Flight) -> Control:
	var chip := UI.vbox(6)
	var title := Curriculum.label(f.task_key)
	if not f.task.is_mission and not f.task.is_free and f.mode != "kids":
		title = f.tr("LESSON_N") % (Curriculum.lessons(f.vehicle, f.mode).find(f.task_key) + 1) + " · " + title
	chip.add_child(UI.label(title, UI.BODY, 700, "text", false, false))
	var bar_row := UI.hbox(8)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(Flight.BAR_W, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
	f._bar_fill.add_theme_stylebox_override("panel", UI.box(Pal.c("accent"), 3, 0))
	f._bar_fill.size = Vector2(0, 6)
	bar.add_child(f._bar_fill)
	bar_row.add_child(bar)
	if f.mode != "kids":
		f._bar_text = UI.label("0 %", UI.CAPTION, 700, "muted", false, false)
		bar_row.add_child(f._bar_text)
	if f.task.is_free:
		# Free flight has no progress: the bar is not shown, and not kept either.
		bar_row.free()
		f._bar_fill = null
		f._bar_text = null
	else:
		chip.add_child(bar_row)
	# A second bar for how the load is doing, e.g. the casualty's comfort.
	if f.task.meter >= 0.0:
		var mrow := UI.hbox(8)
		var mbar := Panel.new()
		mbar.custom_minimum_size = Vector2(Flight.BAR_W, 6)
		mbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mbar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
		f._meter_fill = Panel.new()
		f._meter_fill.add_theme_stylebox_override("panel", UI.box(Pal.c("ok"), 3, 0))
		f._meter_fill.size = Vector2(Flight.BAR_W, 6)
		mbar.add_child(f._meter_fill)
		mrow.add_child(mbar)
		var meter_text := UI.label(f.tr(Curriculum.text_key(f.task.meter_label, f.mode)), UI.CAPTION, 700, "muted", false, false)
		mrow.add_child(meter_text)
		chip.add_child(mrow)
	return chip


## Kids see a simple counter; everyone else sees the flight numbers.
static func build_counters(f: Flight, top: HBoxContainer, glass: Color) -> void:
	if f.mode == "kids":
		if f.task.counter_shown:
			var row := UI.hbox(8)
			# Sunflowers are what the kitten mission collects; other counts need no picture.
			if f.task.key == "MIS_CAM_KITTEN":
				row.add_child(Glyph.make("sunflower", 26, Pal.c("accent")))
			f._counter = UI.label("0", UI.TITLE_S, 700, "text", true, false)
			row.add_child(f._counter)
			top.add_child(UI.panel(row, glass, 22, 10))
	else:
		var stats := UI.hbox(18)
		var names := ["ALT", "TIME"]
		if f.mode == "pro":
			names = ["ALT", "SPEED", "BATTERY", "TIME"]
		if f.machine == "ugv":
			names = ["SPEED", "BATTERY", "TIME"] if f.mode == "pro" else ["SPEED", "TIME"]
		elif f.machine in ["fpv", "wing"] and f.mode != "pro":
			names = ["ALT", "SPEED", "TIME"]
		if f.task.target_info:
			names = ["TARGET", "CLOSING", "SPEED", "TIME"] if f.mode == "pro" else ["TARGET", "CLOSING", "TIME"]
		if f.practice:
			names.erase("TIME")  # f.practice has no clock
		for n in names:
			var s := UI.vbox(1)
			var head := UI.eyebrow(f.tr("STAT_" + n))
			head.autowrap_mode = TextServer.AUTOWRAP_OFF
			s.add_child(head)
			var v := UI.label("–", UI.LEAD, 800, "text", false, false)
			# As wide as a real reading from the start, so the top line is measured right.
			v.custom_minimum_size.x = v.get_theme_font("font").get_string_size("88,8 м/с", HORIZONTAL_ALIGNMENT_LEFT, -1, v.get_theme_font_size("font_size")).x
			f._stats[n] = v
			s.add_child(v)
			stats.add_child(s)
		top.add_child(UI.panel(stats, glass, 16, 10))
