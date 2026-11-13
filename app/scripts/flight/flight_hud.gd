# SPDX-License-Identifier: GPL-3.0-or-later
# The top line of the flight screen: the lesson title with its progress bar, the flight numbers or
# the kids' counter, and "No signal" over late robot video. Kept apart from flight.gd so that file
# stays one topic; `f` is the flight screen.
class_name FlightHud
extends RefCounted


static func fit_top(f: Flight, top: HBoxContainer) -> void:
	var room := f.get_viewport_rect().size.x - 2.0 * Flight.SIDE - f._ins_x()
	var order := ["TIME", "VERT", "BATTERY", "LEAN", "WIND", "CLOSING", "SPEED", "HOME", "TARGET", "AIRSPEED", "ALT"]
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
## Which flight numbers a flight shows, most useful first.
static func stat_names(f: Flight) -> Array:
	var pro := f.mode == "pro"
	if f.task.target_info:
		return ["TARGET", "CLOSING", "SPEED", "TIME"] if pro else ["TARGET", "CLOSING", "TIME"]
	match f.machine:
		"ugv":
			return ["SPEED", "LEAN", "BATTERY", "TIME"] if pro else ["SPEED", "LEAN", "TIME"]
		"wing":
			return ["ALT", "AIRSPEED", "WIND", "BATTERY", "TIME"] if pro else ["ALT", "AIRSPEED", "WIND", "TIME"]
		"fpv":
			return ["ALT", "SPEED", "BATTERY", "TIME"] if pro else ["ALT", "SPEED", "TIME"]
	# The camera drone: in Adult mode the way home and the climb rate too.
	return ["ALT", "VERT", "HOME", "SPEED", "BATTERY", "TIME"] if pro else ["ALT", "TIME"]


## The speed tape: 0 to 20 m/s, the stall below V_STALL, a warning band just above it.
static func _draw_tape(f: Flight) -> void:
	var t: Control = f._tape
	var w := t.size.x
	var top := 20.0
	var stall := WingSim.V_STALL / top * w
	var warn := WingSim.V_STALL * 1.2 / top * w
	t.draw_rect(Rect2(0, 1, stall, 4), Pal.c("bad"))
	t.draw_rect(Rect2(stall, 1, warn - stall, 4), Pal.c("warn"))
	t.draw_rect(Rect2(warn, 1, w - warn, 4), Pal.c("ok"))
	var x := clampf(float((f.sim as WingSim).speed) / top, 0.0, 1.0) * w
	t.draw_rect(Rect2(x - 1.5, -1, 3, 8), Pal.c("text"))


## The robot's lean: how far from upright, and the colour of the danger when it can tip over.
static func lean_color(f: Flight) -> Color:
	var tip := float(f.sim.p.get("tip", 90.0))
	var lean := lean_deg(f)
	if tip >= 90.0:
		return Pal.c("text")
	return Pal.c("bad") if lean > tip * 0.85 else (Pal.c("warn") if lean > tip * 0.65 else Pal.c("text"))


static func lean_deg(f: Flight) -> float:
	var u := f.sim as UgvSim
	return rad_to_deg(acos(clampf(u.att.y.y, -1.0, 1.0))) if u else 0.0


static func _draw_lean(f: Flight) -> void:
	var g: Control = f._lean_gauge
	var c := g.size / 2.0
	var r := g.size.x / 2.0 - 1.0
	var col := lean_color(f)
	g.draw_arc(c, r, 0, TAU, 24, col, 1.5, true)
	var roll := f.sim.tilt.y
	var pitch := clampf(f.sim.tilt.x, -0.6, 0.6)
	var d := Vector2(cos(roll), sin(roll)) * (r - 2.0)
	var off := Vector2(0, -pitch / 0.6 * r * 0.5)
	g.draw_line(c + off - d, c + off + d, col, 2.0, true)


static func _draw_wind_arrow(f: Flight) -> void:
	var a: Control = f._wind_arrow
	var wind := f.sim.wind()
	if Vector2(wind.x, wind.z).length() < 0.2:
		a.draw_circle(a.size / 2.0, 2.5, Pal.c("text"))
		return
	var fwd := f.sim.forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	# Screen up is the plane's nose.
	var d := Vector2(wind.dot(right), -wind.dot(fwd)).normalized()
	var c := a.size / 2.0
	var tip := c + d * 7.0
	var side := Vector2(-d.y, d.x) * 4.5
	a.draw_line(c - d * 7.0, tip, Pal.c("text"), 2.0, true)
	a.draw_colored_polygon(PackedVector2Array([tip + d * 2.0, tip - d * 4.0 + side, tip - d * 4.0 - side]), Pal.c("text"))


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
		var names := stat_names(f)
		if f.practice:
			names.erase("TIME")  # practice has no clock
		for n in names:
			var s := UI.vbox(1)
			var head := UI.eyebrow(f.tr("STAT_" + n))
			head.autowrap_mode = TextServer.AUTOWRAP_OFF
			s.add_child(head)
			var v := UI.label("–", UI.LEAD, 800, "text", false, false)
			# As wide as a real reading from the start, so the top line is measured right.
			v.custom_minimum_size.x = v.get_theme_font("font").get_string_size("88,8 м/с", HORIZONTAL_ALIGNMENT_LEFT, -1, v.get_theme_font_size("font_size")).x
			f._stats[n] = v
			if n == "LEAN":
				# A little horizon beside the number: the robot's tilt, as on a real inclinometer.
				var lrow := UI.hbox(5)
				f._lean_gauge = Control.new()
				f._lean_gauge.custom_minimum_size = Vector2(22, 22)
				f._lean_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				f._lean_gauge.draw.connect(func(): _draw_lean(f))
				lrow.add_child(f._lean_gauge)
				lrow.add_child(v)
				s.add_child(lrow)
			elif n == "WIND":
				# An arrow beside the number: which way the wind blows, seen from above the plane,
				# nose up. A headwind points down at the plane.
				var row := UI.hbox(4)
				f._wind_arrow = Control.new()
				f._wind_arrow.custom_minimum_size = Vector2(16, 16)
				f._wind_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				f._wind_arrow.draw.connect(func(): _draw_wind_arrow(f))
				row.add_child(f._wind_arrow)
				row.add_child(v)
				s.add_child(row)
			else:
				s.add_child(v)
			if n == "AIRSPEED":
				# Under the air speed: red where the wing stalls, orange close to it.
				f._tape = Control.new()
				f._tape.custom_minimum_size = Vector2(v.custom_minimum_size.x, 6)
				f._tape.draw.connect(func(): _draw_tape(f))
				s.add_child(f._tape)
			stats.add_child(s)
		top.add_child(UI.panel(stats, glass, 16, 10))
