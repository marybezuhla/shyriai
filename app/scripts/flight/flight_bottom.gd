# SPDX-License-Identifier: GPL-3.0-or-later
# The bottom of the flight screen: the two sticks with their names, the view switch, and the round
# buttons beside the right stick (the survey camera, a task's own action, Home, Arm). Kept apart
# from flight.gd so that file stays one topic; `f` is the flight screen.
class_name FlightBottom
extends RefCounted


static func build_bottom(f: Flight, col: VBoxContainer, ins: Dictionary) -> void:
	# Sticks and the view switch at the bottom.
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sticks as big as fit beside the view switch and any camera or action buttons. When the full
	# switch leaves too little room (narrow phones, the largest text), it becomes one button that
	# steps through the views.
	var room := f.get_viewport_rect().size.x - 2.0 * Flight.SIDE - float(ins["left"]) - float(ins["right"]) - 24.0
	if (f.task is PhotoTask and f.task.kit) or f.task.action != "" or home_button(f) or arm_button(f):
		room -= 96.0
	f._view_compact = (room - Flight.VIEW_FULL) / 2.0 < 104.0
	room -= Flight.VIEW_COMPACT if f._view_compact else Flight.VIEW_FULL
	# A square screen (an unfolded phone held upright) is narrower still: the button shows only
	# its icon.
	f._view_icon = f._view_compact and room / 2.0 < 92.0
	if f._view_icon:
		room += Flight.VIEW_COMPACT - 60.0
	var stick_px := int(clampf(room / 2.0, 80.0, 150.0 if f.mode == "kids" else 128.0))
	for s in [f._left, f._right]:
		s.kids = f.mode == "kids"
		s.custom_minimum_size = Vector2(stick_px, stick_px)
	# The FPV throttle stays where the thumb leaves it, like on a real radio, and starts at zero.
	if f.machine in ["fpv", "wing"] and f.mode != "kids":
		f._thr.spring_y = false
		# A plane that starts in the air has its motor already running at cruise.
		f._thr.value.y = f.sim.throttle01 * 2.0 - 1.0 if f.sim is WingSim else -1.0
	var left_label := "STICK_LEFT_FPV" if not f._left.spring_y and f.machine == "fpv" else "STICK_LEFT"
	var right_label := "STICK_RIGHT"
	if f.machine == "wing":
		left_label = "STICK_LEFT_WING"
		right_label = "STICK_RIGHT_WING"
	if f._mode1:
		left_label = "STICK_LEFT_WING_M1" if f.machine == "wing" else "STICK_LEFT_M1"
		right_label = {"fpv": "STICK_RIGHT_FPV_M1", "wing": "STICK_RIGHT_WING_M1"}.get(f.machine, "STICK_RIGHT_M1")
	if f.sim is UgvSim:
		left_label = "STICK_TRACK_L" if f.sim.tank else "STICK_DRIVE"
		right_label = "STICK_TRACK_R" if f.sim.tank else "STICK_TURN"
	bottom.add_child(stick_with_label(f, f._left, f.tr(left_label)))
	f._view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f._view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(f._view_box)
	if f.task is PhotoTask and f.task.kit:
		f._kit = PhotoKit.new()
		f._kit.build(f.task, f.mode == "kids", f.shutter)
		bottom.add_child(f._kit)
	if f.task.action != "":
		var act := ActionButton.new()
		act.build(f.task, f.sim)
		bottom.add_child(act)
	elif home_button(f):
		bottom.add_child(round_button(f, "home", "RTH", func(): f.home.start(f.sim)))
	elif arm_button(f):
		var b := round_button(f, "power", "ARM", f._toggle_arm)
		f._arm_label = b.find_children("*", "Label", true, false)[0]
		bottom.add_child(b)
	bottom.add_child(stick_with_label(f, f._right, f.tr(right_label)))
	col.add_child(bottom)


## Adult camera drones have a "Home" button beside the right stick.
static func home_button(f: Flight) -> bool:
	return f.home != null and f.mode == "pro" and not (f.task is PhotoTask and f.task.kit)


## Adult FPV drones are armed with a button beside the right stick.
static func arm_button(f: Flight) -> bool:
	return f.sim is FpvSim and f.mode == "pro" and f.task.action == ""


## A round button beside the right stick: an icon and a word.
static func round_button(f: Flight, icon: String, key: String, on_press: Callable) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UI.vbox(2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(76, 76)
	var ic := CenterContainer.new()
	ic.add_child(Glyph.make(icon, 26, Pal.c("on_accent")))
	col.add_child(ic)
	var l := UI.label(f.tr(key), UI.CAPTION, 800, "on_accent", false, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	box.add_child(UI.tappable(col, Pal.c("accent"), on_press, f.tr(key), 38, 0))
	return box


static func stick_with_label(f: Flight, s: Stick, text: String) -> Control:
	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	if f.mode != "kids":
		# On a small glass pill, so the label reads over any part of the world.
		var l := UI.label(text, UI.CAPTION, 700, "text", false, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Never wider than its stick: a long label would push the other stick off the screen.
		var w := l.get_minimum_size().x
		if w > s.custom_minimum_size.x - 16.0:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = s.custom_minimum_size.x - 16.0
		var glass := Pal.c("bg")
		glass.a = 0.78
		var pill := UI.panel(l, glass, 10, 4)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pill)
	return v


static func build_view_toggle(f: Flight) -> void:
	for c in f._view_box.get_children():
		c.queue_free()
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f._view_box.add_child(fill)
	var views := view_list(f)
	var center := CenterContainer.new()
	if f._view_compact:
		center.add_child(view_cycle(f, views))
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f._view_box.add_child(center)
		return
	var seg := UI.segmented(views, f.view, f.set_view)
	seg.custom_minimum_size = Vector2(Flight.VIEW_FULL, 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(seg)
	f._view_box.add_child(center)


## The views of this machine: [id, name].
static func view_list(f: Flight) -> Array:
	match f.machine:
		"ugv":
			return [["ugv", Curriculum.label("VIEW_DRONE")], ["chase", Curriculum.label("VIEW_BEHIND")], ["pilot", Curriculum.label("VIEW_PILOT")]]
		"fpv":
			return [["fpv", Curriculum.label("VIEW_FPV")], ["chase", Curriculum.label("VIEW_CHASE")], ["pilot", Curriculum.label("VIEW_PILOT")]]
		"wing":
			return [["chase", Curriculum.label("VIEW_CHASE_WING")], ["pilot", Curriculum.label("VIEW_PILOT")], ["fpv", Curriculum.label("VIEW_NOSE")]]
	return [["pilot", Curriculum.label("VIEW_PILOT")], ["chase", Curriculum.label("VIEW_CHASE")], ["drone", Curriculum.label("VIEW_DRONE")]]


static func next_view(f: Flight) -> void:
	var views := view_list(f)
	for k in views.size():
		if views[k][0] == f.view:
			f.set_view(views[(k + 1) % views.size()][0])
			return
	f.set_view(views[0][0])


## One button showing the view now; a tap moves on to the next one.
static func view_cycle(f: Flight, views: Array) -> Control:
	var i := 0
	for k in views.size():
		if views[k][0] == f.view:
			i = k
	var next: String = views[(i + 1) % views.size()][0]
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Glyph.make("camera", 18, Pal.c("text")))
	if not f._view_icon:
		row.add_child(UI.label(views[i][1], UI.SMALL, 700, "text", false, false))
	var glass := Pal.c("bg")
	glass.a = 0.78
	var t := UI.tappable(row, glass, func(): f.set_view(next), f.tr("A11Y_VIEW") % views[i][1], UI.RADIUS_PILL, 12)
	t.custom_minimum_size = Vector2(52 if f._view_icon else Flight.VIEW_COMPACT, 52)
	return t
