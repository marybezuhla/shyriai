# SPDX-License-Identifier: GPL-3.0-or-later
# The flight screen: the 3D world, the drone, two sticks, a thin status line and one hint.
extends Control

const STEP := 1.0 / 60.0
## The dark edge round gold marks, so they show on a bright sky or field.
const OUTLINE := Color("#2A1D3B")
const DEADZONE := 0.08

var app: Node  # main.gd
var vehicle := "camera"
var task_key := "CAM_STICKS"
var mode := "simple"
var look := "dusk"
## Which world and task variant to build; tests and "Start over" keep it, a new attempt changes it.
var flight_seed := 7
## Tests set this to fly by themselves: func(sim, task) -> {"throttle", "yaw", "pitch", "roll"}.
var autopilot := Callable()

var sim: DroneSim
var task: FlightTask
var world: FlightWorld
var drone: Node3D  # DroneView or UgvView
## The robot's camera pose a moment ago, for late video: [pos, basis] per physics step.
var _cam_history: Array = []
var _shown_load := ""
var _nolink: Control
var _meter_fill: Panel
var cam := Camera3D.new()
var view := "pilot"

var _left := Stick.new()
var _right := Stick.new()
var _hud := Control.new()
var _marks := Control.new()
var _hint := Label.new()
var _hint_panel := PanelContainer.new()
var _bar_fill := Panel.new()
var _bar_text: Label
var _stats := {}
var _counter: Label
var _view_box := VBoxContainer.new()
var _overlay: Control
var _choice_box := CenterContainer.new()
var _choice_shown := {}
var _paused := false
var _finished := false
var _sticks := {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}


func setup(app_: Node, vehicle_: String, task_key_: String) -> void:
	app = app_
	vehicle = vehicle_
	task_key = task_key_
	mode = Prefs.mode
	# Kids always fly on a clear day; otherwise the world follows the app's look.
	look = "day" if mode == "kids" or Pal.current != "dusk" else "dusk"
	view = Prefs.view_for(mode, vehicle)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	task = FlightTask.make(task_key, mode, flight_seed)
	world = FlightWorld.new()
	add_child(world)
	world.build(look, 7)
	task.world = world
	task.setup_world()
	if task.view_hint != "":
		view = task.view_hint

	sim = task.make_sim(vehicle)

	if vehicle == "ugv":
		drone = UgvView.new()
		world.add_child(drone)
		drone.build(world.pal["drone"], world.pal["drone_front"], task.load_kind)
		_shown_load = task.load_kind
	else:
		drone = DroneView.new()
		world.add_child(drone)
		drone.build(world.pal["drone"], world.pal["drone_front"])
	drone.sync(sim, 0.0)

	cam.fov = 60.0
	cam.near = 0.1
	cam.far = 600.0
	world.add_child(cam)
	cam.current = true
	_place_camera(1.0)

	_build_hud()
	DisplayServer.screen_set_keep_on(true)


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)


# --- Every step -------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _paused or _finished:
		return
	_read_sticks()
	# No radio link: the robot gets no commands and stops by itself.
	_sticks = task.controls(_sticks)
	sim.step(STEP, _sticks["throttle"], _sticks["yaw"], _sticks["pitch"], _sticks["roll"])
	task.step(STEP, sim, _sticks)
	_cam_history.append([sim.pos, sim.orientation()])
	if _cam_history.size() > 90:
		_cam_history.pop_front()
	if task.done:
		_finish()
	elif task.failed:
		_not_this_time()
	elif sim.crashed:
		_crashed()
	elif sim.p.get("battery_s", 0.0) > 0.0 and sim.battery <= 0.0 and (sim.on_ground or sim is UgvSim):
		# The battery ran out and the drone has come down (or the robot has stopped): say so.
		task.fail_with("FAIL_BATTERY")
		_not_this_time()


func _process(delta: float) -> void:
	drone.sync(sim, delta)
	drone.body_visible(view != "fpv" and view != "drone")
	_place_camera(delta)
	world.show_beacon(task.marker, task.beacon)
	_update_hud()
	_marks.queue_redraw()


var _joy_throttle := false


func _read_sticks() -> void:
	if autopilot.is_valid():
		_sticks = autopilot.call(sim, task)
		return
	if not _left.spring_y:
		# Keys move the throttle stick on screen, step by step.
		var k := _keys(KEY_W, KEY_S)
		if k != 0.0:
			_left.value.y = clampf(_left.value.y + k * STEP * 0.9, -1.0, 1.0)
			_left.queue_redraw()
	var t := _left.value.y
	var y := _left.value.x
	var p := _right.value.y
	var r := _right.value.x
	# A gamepad or a radio in joystick mode (Mode 2).
	for dev in Input.get_connected_joypads():
		if _left.spring_y:
			t = _bigger(t, -_axis(dev, JOY_AXIS_LEFT_Y))
		elif not _left.touched:
			# A gamepad or radio drives the throttle until the screen stick is touched, but only once
			# its stick has been moved: a self-centring gamepad would otherwise start at half throttle.
			var a := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
			if absf(a) > 0.2:
				_joy_throttle = true
			if _joy_throttle:
				t = -a
		y = _bigger(y, _axis(dev, JOY_AXIS_LEFT_X))
		p = _bigger(p, -_axis(dev, JOY_AXIS_RIGHT_Y))
		r = _bigger(r, _axis(dev, JOY_AXIS_RIGHT_X))
	# A keyboard: W/S up and down, A/D turn, arrows move.
	if _left.spring_y:
		t = _bigger(t, _keys(KEY_W, KEY_S))
	y = _bigger(y, _keys(KEY_D, KEY_A))
	p = _bigger(p, _keys(KEY_UP, KEY_DOWN))
	r = _bigger(r, _keys(KEY_RIGHT, KEY_LEFT))
	_sticks = {"throttle": t, "yaw": y, "pitch": p, "roll": r}


func _axis(dev: int, axis: JoyAxis) -> float:
	var v := Input.get_joy_axis(dev, axis)
	return 0.0 if absf(v) < DEADZONE else v


func _keys(plus: Key, minus: Key) -> float:
	return float(Input.is_physical_key_pressed(plus)) - float(Input.is_physical_key_pressed(minus))


func _bigger(a: float, b: float) -> float:
	return a if absf(a) >= absf(b) else b


# --- Camera -----------------------------------------------------------------

func _place_camera(delta: float) -> void:
	var target := sim.pos + Vector3(0, 0.15, 0)
	if view == "fpv":
		# The FPV camera is fixed to the drone, tilted up, so the horizon tilts with it.
		var up_tilt := 10.0 if sim is not FpvSim else (20.0 if mode == "simple" else 30.0)
		var b := sim.orientation()
		cam.global_basis = b * Basis(Vector3.RIGHT, deg_to_rad(up_tilt))
		cam.position = sim.pos + b * Vector3(0, 0.12, -0.45)
		cam.fov = 95.0
	elif view == "drone":
		# The drone's own camera on a steady gimbal, tilted down a little.
		cam.position = sim.pos + sim.forward() * 0.45 + Vector3(0, 0.2, 0)
		cam.rotation = Vector3(deg_to_rad(-25.0), sim.yaw, 0)
		cam.fov = 75.0
	elif view == "ugv":
		# The robot's own camera on its mast. Some tasks show its video late, as over a slow radio link.
		var pose: Array = [sim.pos, sim.orientation()]
		var back := int(round(task.video_delay / STEP))
		if back > 0 and _cam_history.size() > back:
			pose = _cam_history[_cam_history.size() - 1 - back]
		var b: Basis = pose[1]
		cam.global_basis = b * Basis(Vector3.RIGHT, deg_to_rad(-8.0))
		cam.position = pose[0] + b * Vector3(0, 1.2, -0.6)
		cam.fov = 80.0
	elif view == "chase":
		var back := -sim.forward() * 6.0 + Vector3(0, 2.6, 0)
		var want := target + back
		var g := sim.ground.call(want.x, want.z) as float
		want.y = maxf(want.y, g + 1.0)
		var k := 1.0 - exp(-delta * 4.0)
		cam.position = cam.position.lerp(want, k) if cam.position != Vector3.ZERO else want
		cam.fov = 62.0
		cam.look_at(target + sim.forward() * 2.0, Vector3.UP)
	else:
		# The pilot stands behind the pad and turns the head; far away, the view zooms in a little.
		cam.position = world.pilot
		var d := cam.position.distance_to(target)
		cam.fov = lerpf(cam.fov, clampf(70.0 - d * 0.9, 32.0, 62.0), 1.0 - exp(-delta * 2.0))
		# Straight overhead, looking up would need another "up": just keep the last view there.
		if d > 0.5 and Vector2(target.x - world.pilot.x, target.z - world.pilot.z).length() > 0.3:
			var look_at := target.lerp(world.pilot + (target - world.pilot) * 0.5, 0.15)
			cam.look_at(look_at, Vector3.UP)


func set_view(v: String) -> void:
	view = v
	Prefs.set_view(mode, vehicle, v)
	cam.position = Vector3.ZERO
	_build_view_toggle()


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	# "No signal" over the robot's video while the radio link is down.
	var nl := ColorRect.new()
	nl.color = Color(0.16, 0.11, 0.23, 0.82)
	nl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl_center := CenterContainer.new()
	nl_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nl_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl_text := Label.new()
	nl_text.text = tr("NO_SIGNAL")
	nl_text.add_theme_font_override("font", Pal.font(600, true))
	nl_text.add_theme_font_size_override("font_size", 26)
	nl_text.add_theme_color_override("font_color", Color("#FFF0D5"))
	nl_center.add_child(nl_text)
	nl.add_child(nl_center)
	nl.visible = false
	add_child(nl)
	_nolink = nl

	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	_hud.add_child(_marks)

	var ins: Dictionary = app.insets() if app else {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 16 + int(ins["left"]))
	m.add_theme_constant_override("margin_right", 16 + int(ins["right"]))
	m.add_theme_constant_override("margin_top", 12 + int(ins["top"]))
	m.add_theme_constant_override("margin_bottom", 14 + int(ins["bottom"]))
	_hud.add_child(m)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)

	var glass := Pal.c("bg")
	glass.a = 0.78
	var top := UI.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UI.icon_button("pause", pause, tr("PAUSE"), glass))

	var chip := UI.vbox(6)
	var title := Curriculum.label(task_key)
	if not task.is_mission:
		title = tr("LESSON_N") % (Curriculum.lessons(vehicle, mode).find(task_key) + 1) + " · " + title
	chip.add_child(UI.label(title, 14, 700, "text", false, false))
	var bar_row := UI.hbox(8)
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(120, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
	_bar_fill.add_theme_stylebox_override("panel", UI.box(Pal.c("accent"), 3, 0))
	_bar_fill.size = Vector2(0, 6)
	bar.add_child(_bar_fill)
	bar_row.add_child(bar)
	if mode != "kids":
		_bar_text = UI.label("0 %", 12, 700, "muted", false, false)
		bar_row.add_child(_bar_text)
	chip.add_child(bar_row)
	# A second bar for how the load is doing, e.g. the casualty's comfort.
	if task.meter >= 0.0:
		var mrow := UI.hbox(8)
		var mbar := Panel.new()
		mbar.custom_minimum_size = Vector2(120, 6)
		mbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mbar.add_theme_stylebox_override("panel", UI.box(Pal.c("line"), 3, 0))
		_meter_fill = Panel.new()
		_meter_fill.add_theme_stylebox_override("panel", UI.box(Color("#7DBE6A"), 3, 0))
		_meter_fill.size = Vector2(120, 6)
		mbar.add_child(_meter_fill)
		mrow.add_child(mbar)
		var meter_text := UI.label(tr(task.meter_label), 12, 700, "muted", false, false)
		mrow.add_child(meter_text)
		chip.add_child(mrow)
	top.add_child(UI.panel(chip, glass, 16, 10))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)

	if mode == "kids":
		if task.counter_shown:
			var row := UI.hbox(8)
			# Sunflowers are what the kitten mission collects; other counts need no picture.
			if task.key == "MIS_CAM_KITTEN":
				var flower := _SunflowerIcon.new()
				flower.custom_minimum_size = Vector2(26, 26)
				row.add_child(flower)
			_counter = UI.label("0", 18, 700, "text", true, false)
			row.add_child(_counter)
			top.add_child(UI.panel(row, glass, 22, 10))
	else:
		var stats := UI.hbox(18)
		var names := ["ALT", "TIME"]
		if mode == "pro":
			names = ["ALT", "SPEED", "BATTERY", "TIME"]
		if vehicle == "ugv":
			names = ["SPEED", "BATTERY", "TIME"] if mode == "pro" else ["SPEED", "TIME"]
		elif vehicle == "fpv" and mode != "pro":
			names = ["ALT", "SPEED", "TIME"]
		for n in names:
			var s := UI.vbox(1)
			var head := UI.eyebrow(tr("STAT_" + n))
			head.autowrap_mode = TextServer.AUTOWRAP_OFF
			s.add_child(head)
			var v := UI.label("–", 16, 800, "text", false, false)
			_stats[n] = v
			s.add_child(v)
			stats.add_child(s)
		top.add_child(UI.panel(stats, glass, 16, 10))
	col.add_child(top)

	# One hint, in the middle under the top line.
	var hint_row := CenterContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", Pal.font(700))
	_hint.add_theme_font_size_override("font_size", 19 if mode == "kids" else 16)
	_hint.add_theme_color_override("font_color", Pal.c("bg"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_theme_stylebox_override("panel", UI.box(Pal.c("text"), 12, 9))
	_hint_panel.add_child(_hint)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(_hint_panel)
	col.add_child(hint_row)


	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)

	# Sticks and the view switch at the bottom.
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sticks as big as fit beside the camera switch (narrow phones in landscape get a little less).
	var room := get_viewport_rect().size.x - 32.0 - float(ins["left"]) - float(ins["right"]) - 344.0
	var stick_px := int(clampf(room / 2.0, 104.0, 150.0 if mode == "kids" else 128.0))
	for s in [_left, _right]:
		s.kids = mode == "kids"
		s.custom_minimum_size = Vector2(stick_px, stick_px)
	# The FPV throttle stays where the thumb leaves it, like on a real radio, and starts at zero.
	if vehicle == "fpv" and mode != "kids":
		_left.spring_y = false
		_left.value.y = -1.0
	var left_label := "STICK_LEFT_FPV" if not _left.spring_y else "STICK_LEFT"
	var right_label := "STICK_RIGHT"
	if sim is UgvSim:
		left_label = "STICK_TRACK_L" if sim.tank else "STICK_DRIVE"
		right_label = "STICK_TRACK_R" if sim.tank else "STICK_TURN"
	bottom.add_child(_stick_with_label(_left, tr(left_label)))
	_view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_view_box)
	bottom.add_child(_stick_with_label(_right, tr(right_label)))
	col.add_child(bottom)
	_build_view_toggle()

	# A question with buttons, e.g. "Is this roof damaged?", floats in the middle of the view.
	_choice_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_box.offset_top = 24
	_choice_box.offset_bottom = 24
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_choice_box)


func _stick_with_label(s: Stick, text: String) -> Control:
	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	if mode != "kids":
		# On a small glass pill, so the label reads over any part of the world.
		var l := UI.label(text, 12, 700, "text", false, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var glass := Pal.c("bg")
		glass.a = 0.78
		var pill := UI.panel(l, glass, 10, 4)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(pill)
	return v


func _build_view_toggle() -> void:
	for c in _view_box.get_children():
		c.queue_free()
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_box.add_child(fill)
	var views := [["ugv", Curriculum.label("VIEW_DRONE")], ["chase", Curriculum.label("VIEW_BEHIND")], ["pilot", Curriculum.label("VIEW_PILOT")]] if vehicle == "ugv" \
		else [["fpv", Curriculum.label("VIEW_FPV")], ["chase", Curriculum.label("VIEW_CHASE")], ["pilot", Curriculum.label("VIEW_PILOT")]] if vehicle == "fpv" \
		else [["pilot", Curriculum.label("VIEW_PILOT")], ["chase", Curriculum.label("VIEW_CHASE")], ["drone", Curriculum.label("VIEW_DRONE")]]
	var seg := UI.segmented(views, view, set_view)
	seg.custom_minimum_size = Vector2(360, 0)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(seg)
	_view_box.add_child(center)


func _update_choice() -> void:
	if task.choice == _choice_shown:
		return
	_choice_shown = task.choice.duplicate(true)
	for c in _choice_box.get_children():
		c.queue_free()
	if task.choice.is_empty():
		return
	var glass := Pal.c("bg")
	glass.a = 0.85
	var col := UI.vbox(10)
	var q := UI.label(tr(task.choice["prompt"]), 15, 700, "text", false, false)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(q)
	var row := UI.hbox(10)
	for opt in task.choice["options"]:
		var id: String = opt[0]
		var c := CenterContainer.new()
		c.custom_minimum_size = Vector2(150, 46)
		c.add_child(UI.label(tr(opt[1]), 15, 800, "on_accent", false, false))
		row.add_child(UI.tappable(c, Pal.c("accent"), func(): task.choose(id), tr(opt[1]), 14, 0))
	col.add_child(row)
	_choice_box.add_child(UI.panel(col, glass, 18, 12))


func _update_hud() -> void:
	var hints: Dictionary = task.stick_hint if _overlay == null else {}
	_left.hint = hints.get("left", Vector2.ZERO)
	_right.hint = hints.get("right", Vector2.ZERO)
	if vehicle == "ugv" and task.load_kind != _shown_load:
		_shown_load = task.load_kind
		drone.set_load(_shown_load)
	if _meter_fill:
		var m := clampf(task.meter / 100.0, 0.0, 1.0)
		_meter_fill.size = Vector2(120.0 * m, 6)
		# Darker shades on light looks, so the bar shows against its track.
		var light := Pal.c("bg").get_luminance() > 0.5
		var col: Color
		if m > 0.5:
			col = Color("#3E8E2F") if light else Color("#7DBE6A")
		elif m > 0.25:
			col = Color("#B85F10") if light else Color("#F29B50")
		else:
			col = Color("#B8324F") if light else Color("#E5708B")
		(_meter_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = col
	if _nolink:
		_nolink.visible = not task.link_ok and view == "ugv"
	_update_choice()
	_bar_fill.size = Vector2(120.0 * task.progress, 6)
	if _bar_text:
		_bar_text.text = "%d %%" % int(round(task.progress * 100.0))
	if task.hint != "":
		var text := tr(task.hint)
		if not task.hint_args.is_empty() and text.contains("%"):
			text = text % task.hint_args
		if text != _hint.text:
			_hint.text = text
			# Short hints sit on one line; long ones wrap at a comfortable width.
			var w := _hint.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint.get_theme_font_size("font_size")).x
			_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > 520.0 else TextServer.AUTOWRAP_OFF
			_hint.custom_minimum_size = Vector2(520, 0) if w > 520.0 else Vector2.ZERO
	_hint_panel.visible = task.hint != ""
	if _counter:
		_counter.text = "%d / %d" % [task.counter, task.counter_max]
	if _stats.has("ALT"):
		_stats["ALT"].text = tr("UNIT_M") % FlightTask.num(maxf(0.0, sim.altitude()))
	if _stats.has("SPEED"):
		_stats["SPEED"].text = tr("UNIT_MS") % FlightTask.num(Vector2(sim.vel.x, sim.vel.z).length())
	if _stats.has("BATTERY"):
		_stats["BATTERY"].text = "%d %%" % int(ceil(sim.battery * 100.0))
	if _stats.has("TIME"):
		var t := int(sim.time)
		_stats["TIME"].text = FlightTask.clock(t)


## Markers drawn over the 3D view: where to fly, and where the drone is when it is small.
func _draw_marks() -> void:
	var rect := _marks.get_rect()
	if task.marker != Vector3.INF:
		var behind := cam.is_position_behind(task.marker)
		var p := cam.unproject_position(task.marker)
		var inner := rect.grow(-40)
		if not behind and inner.has_point(p):
			_diamond(p, 9.0)
		else:
			# An arrow at the edge of the screen, pointing towards the target.
			var c := rect.size / 2.0
			var dir := (p - c)
			if behind:
				dir = -dir
			if dir.length() < 1.0:
				dir = Vector2.UP
			dir = dir.normalized()
			var t := minf(absf((inner.size.x / 2.0) / dir.x) if dir.x != 0.0 else INF, absf((inner.size.y / 2.0) / dir.y) if dir.y != 0.0 else INF)
			var tip := c + dir * t
			var side := Vector2(-dir.y, dir.x)
			var col := Pal.c("accent")
			var arrow := PackedVector2Array([tip + dir * 12, tip - dir * 6 + side * 11, tip - dir * 6 - side * 11])
			_marks.draw_colored_polygon(arrow, col)
			# A dark edge keeps the gold arrow visible against a bright sky.
			arrow.append(arrow[0])
			_marks.draw_polyline(arrow, OUTLINE, 2.0, true)
		if task.ring > 0.0:
			_ground_ring(task.marker, task.ring)
	# A thin ring round the drone when it is far and tiny.
	if view == "pilot" and not cam.is_position_behind(sim.pos):
		var d := cam.position.distance_to(sim.pos)
		if d > 14.0:
			var q := cam.unproject_position(sim.pos + Vector3(0, 0.1, 0))
			var col2 := Pal.c("text") if look == "dusk" else Color("#463161")
			col2.a = 0.7
			_marks.draw_arc(q, 16.0, 0, TAU, 32, col2, 2.0, true)


func _diamond(p: Vector2, r: float) -> void:
	var col := Pal.c("accent")
	_marks.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), col)
	_marks.draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)]), OUTLINE, 2.0, true)


func _ground_ring(center: Vector3, radius: float) -> void:
	var pts := PackedVector2Array()
	var g := sim.ground.call(center.x, center.z) as float
	for i in 49:
		var a := i * TAU / 48.0
		var w := Vector3(center.x + cos(a) * radius, g + 0.05, center.z + sin(a) * radius)
		if cam.is_position_behind(w):
			return
		pts.append(cam.unproject_position(w))
	var col := Pal.c("accent")
	_marks.draw_polyline(pts, OUTLINE, 5.0, true)
	_marks.draw_polyline(pts, col, 3.0, true)


# --- Pause, passed, crashed --------------------------------------------------

func pause() -> void:
	if _finished:
		return
	_paused = true
	_left.release()
	_right.release()
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("PAUSE"), 20, 600, "text", true))
	col.add_child(UI.primary(tr("RESUME"), resume, "play"))
	col.add_child(_secondary(tr("RESTART"), restart))
	col.add_child(_secondary(tr("EXIT"), leave))
	_show_overlay(col)


func resume() -> void:
	_paused = false
	_hide_overlay()


## "Start over" keeps the same layout (the same house, the same field); "Again" after a result too.
func restart() -> void:
	app.open_flight(vehicle, task_key, flight_seed)


func leave() -> void:
	app.close_flight()


## Android Back and Escape: pause first, then resume.
func on_back() -> void:
	# The first Back pauses; a second Back leaves, so "Back, Back" always gets out.
	if _finished or _paused:
		leave()
	else:
		pause()


func _finish() -> void:
	_finished = true
	_left.release()
	_right.release()
	if task.is_mission:
		Prefs.mark_mission(task_key)
	else:
		Prefs.mark_passed(vehicle, Curriculum.lessons(vehicle, mode).find(task_key))
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("PASSED_KIDS") if mode == "kids" else tr("PASSED"), 22, 600, "text", true))
	if task.summary != "":
		var s := tr(task.summary)
		if not task.summary_args.is_empty() and s.contains("%"):
			s = s % task.summary_args
		col.add_child(UI.label(s, 14, 500, "muted"))
	var next := _next_task()
	if next != "":
		col.add_child(UI.primary(tr("NEXT_LESSON"), func(): app.open_flight(vehicle, next), "play"))
	else:
		col.add_child(UI.primary(tr("DONE"), leave, "check"))
	col.add_child(_secondary(tr("AGAIN"), restart))
	if next != "":
		col.add_child(_secondary(tr("EXIT"), leave))
	_show_overlay(col)


func _crashed() -> void:
	if sim is UgvSim:
		_finished = true
		var c := UI.vbox(12)
		c.add_child(UI.label(tr("CRASHED_UGV"), 22, 600, "text", true))
		var tipped := false
		for e in sim.events:
			tipped = tipped or e["type"] == "tipped"
		var why := tr("CRASHED_UGV_TIP") if tipped else tr("CRASHED_UGV_HIT")
		c.add_child(UI.label(why % (FlightTask.num(sim.crash_speed, 0) if tipped else FlightTask.num(sim.crash_speed)), 14, 500, "muted"))
		c.add_child(UI.primary(tr("AGAIN"), restart, "play"))
		c.add_child(_secondary(tr("EXIT"), leave))
		_show_overlay(c)
		return
	_finished = true
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("CRASHED"), 22, 600, "text", true))
	col.add_child(UI.label(tr("CRASHED_TEXT") % FlightTask.num(sim.crash_speed), 14, 500, "muted"))
	col.add_child(UI.primary(tr("AGAIN"), restart, "play"))
	col.add_child(_secondary(tr("EXIT"), leave))
	_show_overlay(col)


func _not_this_time() -> void:
	_finished = true
	_left.release()
	_right.release()
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("NOT_THIS_TIME"), 22, 600, "text", true))
	var s := tr(task.summary)
	if not task.summary_args.is_empty() and s.contains("%"):
		s = s % task.summary_args
	col.add_child(UI.label(s, 14, 500, "muted"))
	col.add_child(UI.primary(tr("AGAIN"), restart, "play"))
	col.add_child(_secondary(tr("EXIT"), leave))
	_show_overlay(col)


func _next_task() -> String:
	if task.is_mission:
		return ""
	var list := Curriculum.lessons(vehicle, mode)
	var i := list.find(task_key)
	if i >= 0 and i + 1 < list.size() and FlightTask.implemented(list[i + 1]):
		return list[i + 1]
	return ""


func _secondary(text: String, on_press: Callable) -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(0, 48)
	c.add_child(UI.label(text, 15, 700, "text", false, false))
	return UI.tappable(c, Pal.c("surface2"), on_press, text, 16, 0)


func _show_overlay(content: Control) -> void:
	_hide_overlay()
	# Touches behind a card must not move the sticks.
	for st in [_left, _right]:
		st.release()
		st.enabled = false
	_overlay = ColorRect.new()
	var dim := Pal.c("bg")
	dim.a = 0.55
	(_overlay as ColorRect).color = dim
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := UI.panel(content, Pal.c("surface"), 22, 20)
	card.custom_minimum_size = Vector2(320, 0)
	center.add_child(card)
	add_child(_overlay)


func _hide_overlay() -> void:
	_left.enabled = true
	_right.enabled = true
	if _overlay:
		_overlay.queue_free()
		_overlay = null


## A tiny sunflower for the kids' counter.
class _SunflowerIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		for i in 8:
			var a := i * TAU / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_circle(c + d * r * 0.55, r * 0.33, Color("#FFC321"), true, -1.0, true)
		draw_circle(c, r * 0.36, Color("#6B4A2E"), true, -1.0, true)
