# SPDX-License-Identifier: GPL-3.0-or-later
# The flight screen: the 3D world, the drone, two sticks, a thin status line and one hint.
extends Control

const STEP := 1.0 / 60.0
## The dark edge round gold marks, so they show on a bright sky or field.
const OUTLINE := Color("#2A1D3B")
const DEADZONE := 0.08

var app: Node  # main.gd
var vehicle := "camera"
## What is flown: the course's machine ("camera", "fpv" or "ugv").
var machine := "camera"
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
## Mode 1 puts the throttle on the right stick and forward/back on the left. Drones only: the robot's
## tracks and the kids' steering keep their own layout.
var _mode1 := false
var _thr := _left  # the stick whose up/down is the throttle
var _fwd := _right  # the stick whose up/down flies forward and back
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
## The survey camera's buttons, when the task is flown with a camera.
var _kit: PhotoKit
var _paused := false
var _finished := false
var _sticks := {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
var _sound := FlightSound.new()
## What the task had done a physics step ago, so each new ball, gate or step gets its blip.
var _last_progress := 0.0
var _last_counter := 0
## Bumps and hard landings so far: any of them costs the second and third sunflower.
var _touches := 0


func setup(app_: Node, vehicle_: String, task_key_: String) -> void:
	app = app_
	vehicle = vehicle_
	machine = Curriculum.machine(vehicle)
	task_key = task_key_
	mode = Prefs.mode
	# Kids always fly on a clear day; otherwise the world follows the app's look, or the time of day
	# chosen for free flight.
	look = "day" if mode == "kids" or Pal.current != "dusk" else "dusk"
	if task_key.begins_with("FREE_"):
		var t: String = Prefs.free["time"]
		if mode != "kids" or t in Prefs.FREE_TIMES_KIDS:
			look = t
	view = Prefs.view_for(mode, vehicle)
	_mode1 = Prefs.stick_mode == "1" and mode != "kids" and machine != "ugv"
	if _mode1:
		_thr = _right
		_fwd = _left


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	task = FlightTask.make(task_key, mode, flight_seed)
	if task.look != "":
		look = task.look
	world = FlightWorld.new()
	add_child(world)
	world.build(look, 7)
	task.world = world
	task.setup_world()
	if task.view_hint != "":
		view = task.view_hint

	sim = task.make_sim(machine)
	if task is PhotoTask:
		var vp := get_viewport_rect().size
		task.aspect = vp.x / maxf(vp.y, 1.0)

	if machine == "ugv":
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
	add_child(_sound)
	_sound.setup(machine, mode == "kids", Prefs.sound)
	_last_progress = task.progress
	_last_counter = task.counter
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
	_sound_events()
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
		task.fail_with("FAIL_BATTERY_UGV" if sim is UgvSim else "FAIL_BATTERY")
		_not_this_time()


func _process(delta: float) -> void:
	drone.sync(sim, delta)
	if not _paused and not _finished:
		_sound.motors(_motor_load(), _motors_running(), delta)
		_sound.no_link(not task.link_ok, delta)
	drone.body_visible(view != "fpv" and view != "drone")
	_place_camera(delta)
	if task is PhotoTask and task.report_open and _overlay == null and not _finished:
		_show_overlay(Report.card(self, task))
	world.show_beacon(task.marker, task.beacon)
	_update_hud()
	_marks.queue_redraw()


## How hard the motors work, 0..1: the FPV throttle itself, the camera drone's climb and speed, the
## robot's tracks.
func _motor_load() -> float:
	if sim is UgvSim:
		return 0.25 + 0.75 * clampf(maxf(absf(sim.tracks.x), absf(sim.tracks.y)), 0.0, 1.0)
	if sim is FpvSim:
		return sim.throttle01
	var h := Vector2(sim.vel.x, sim.vel.z).length() / 8.0
	return clampf(0.45 + 0.3 * _sticks["throttle"] + 0.25 * h, 0.2, 1.0)


func _motors_running() -> bool:
	if sim.crashed:
		return false
	if sim is UgvSim:
		return true
	return not sim.on_ground or _sticks["throttle"] > 0.05 or (sim is FpvSim and sim.throttle01 > 0.05)


## A blip for each step forward in the task (a ball taken, a gate flown: progress jumps in one step,
## while holding or approaching only creeps), a thud for each hard bump.
func _sound_events() -> void:
	var jumped := task.progress - _last_progress >= 0.04 or task.counter > _last_counter
	if jumped and not task.done:
		_sound.play("blip")
	_last_progress = task.progress
	_last_counter = task.counter
	for e in sim.events:
		if Rating.is_touch(e):
			_touches += 1
		if e["type"] in ["bump", "crash", "tipped"] and float(e["speed"]) > 1.0:
			_sound.play("thud")


var _joy_throttle := false


func _read_sticks() -> void:
	if autopilot.is_valid():
		_sticks = autopilot.call(sim, task)
		return
	if not _thr.spring_y:
		# Keys move the throttle stick on screen, step by step.
		var k := _keys(KEY_W, KEY_S)
		if k != 0.0:
			_thr.value.y = clampf(_thr.value.y + k * STEP * 0.9, -1.0, 1.0)
			_thr.queue_redraw()
	var t := _thr.value.y
	var y := _left.value.x
	var p := _fwd.value.y
	var r := _right.value.x
	# A gamepad or a radio in joystick mode. In Mode 1 its up/down axes swap like the screen sticks.
	var thr_axis := JOY_AXIS_RIGHT_Y if _mode1 else JOY_AXIS_LEFT_Y
	var fwd_axis := JOY_AXIS_LEFT_Y if _mode1 else JOY_AXIS_RIGHT_Y
	for dev in Input.get_connected_joypads():
		if _thr.spring_y:
			t = _bigger(t, -_axis(dev, thr_axis))
		elif not _thr.touched:
			# A gamepad or radio drives the throttle until the screen stick is touched, but only once
			# its stick has been moved: a self-centring gamepad would otherwise start at half throttle.
			var a := Input.get_joy_axis(dev, thr_axis)
			if absf(a) > 0.2:
				_joy_throttle = true
			if _joy_throttle:
				t = -a
		y = _bigger(y, _axis(dev, JOY_AXIS_LEFT_X))
		p = _bigger(p, -_axis(dev, fwd_axis))
		r = _bigger(r, _axis(dev, JOY_AXIS_RIGHT_X))
	# A keyboard: W/S up and down, A/D turn, arrows move.
	if _thr.spring_y:
		t = _bigger(t, _keys(KEY_W, KEY_S))
	y = _bigger(y, _keys(KEY_D, KEY_A))
	p = _bigger(p, _keys(KEY_UP, KEY_DOWN))
	r = _bigger(r, _keys(KEY_RIGHT, KEY_LEFT))
	if machine != "ugv":
		var e: float = Prefs.STICK_FEELS.get(Prefs.stick_feel, 0.0)
		y = _soft(y, e)
		p = _soft(p, e)
		r = _soft(r, e)
	_sticks = {"throttle": t, "yaw": y, "pitch": p, "roll": r}


## Expo: the same full deflection, but gentler near the centre, for fine moves. e = 0 changes nothing.
static func _soft(x: float, e: float) -> float:
	return (1.0 - e) * x + e * x * x * x


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
		# The drone's own camera on a steady gimbal: tilted down a little, or as far as the survey
		# camera is tilted. The shutter uses the very same pose.
		cam.position = Photo.camera_position(sim.pos, sim.yaw)
		cam.global_basis = Photo.camera_basis(sim.yaw, task.tilt if task is PhotoTask else "forward")
		cam.fov = Photo.FOV
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
	if not task.is_mission and not task.is_free:
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
	if task.is_free:
		# Free flight has no progress: the bar is not shown, and not kept either.
		bar_row.free()
		_bar_fill = null
		_bar_text = null
	else:
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
				row.add_child(Glyph.make("sunflower", 26, Pal.c("accent")))
			_counter = UI.label("0", 18, 700, "text", true, false)
			row.add_child(_counter)
			top.add_child(UI.panel(row, glass, 22, 10))
	else:
		var stats := UI.hbox(18)
		var names := ["ALT", "TIME"]
		if mode == "pro":
			names = ["ALT", "SPEED", "BATTERY", "TIME"]
		if machine == "ugv":
			names = ["SPEED", "BATTERY", "TIME"] if mode == "pro" else ["SPEED", "TIME"]
		elif machine == "fpv" and mode != "pro":
			names = ["ALT", "SPEED", "TIME"]
		if task.target_info:
			names = ["TARGET", "CLOSING", "SPEED", "TIME"] if mode == "pro" else ["TARGET", "CLOSING", "TIME"]
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
	if (task is PhotoTask and task.kit) or task.action != "":
		room -= 80.0  # the camera or action buttons beside the right stick
	var stick_px := int(clampf(room / 2.0, 104.0, 150.0 if mode == "kids" else 128.0))
	for s in [_left, _right]:
		s.kids = mode == "kids"
		s.custom_minimum_size = Vector2(stick_px, stick_px)
	# The FPV throttle stays where the thumb leaves it, like on a real radio, and starts at zero.
	if machine == "fpv" and mode != "kids":
		_thr.spring_y = false
		_thr.value.y = -1.0
	var left_label := "STICK_LEFT_FPV" if not _left.spring_y else "STICK_LEFT"
	var right_label := "STICK_RIGHT"
	if _mode1:
		left_label = "STICK_LEFT_M1"
		right_label = "STICK_RIGHT_FPV_M1" if machine == "fpv" else "STICK_RIGHT_M1"
	if sim is UgvSim:
		left_label = "STICK_TRACK_L" if sim.tank else "STICK_DRIVE"
		right_label = "STICK_TRACK_R" if sim.tank else "STICK_TURN"
	bottom.add_child(_stick_with_label(_left, tr(left_label)))
	_view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_view_box)
	if task is PhotoTask and task.kit:
		_kit = PhotoKit.new()
		_kit.build(task, mode == "kids", shutter)
		bottom.add_child(_kit)
	if task.action != "":
		var act := ActionButton.new()
		act.build(task, sim)
		bottom.add_child(act)
	bottom.add_child(_stick_with_label(_right, tr(right_label)))
	col.add_child(bottom)
	_build_view_toggle()


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
	var views := [["ugv", Curriculum.label("VIEW_DRONE")], ["chase", Curriculum.label("VIEW_BEHIND")], ["pilot", Curriculum.label("VIEW_PILOT")]] if machine == "ugv" \
		else [["fpv", Curriculum.label("VIEW_FPV")], ["chase", Curriculum.label("VIEW_CHASE")], ["pilot", Curriculum.label("VIEW_PILOT")]] if machine == "fpv" \
		else [["pilot", Curriculum.label("VIEW_PILOT")], ["chase", Curriculum.label("VIEW_CHASE")], ["drone", Curriculum.label("VIEW_DRONE")]]
	var seg := UI.segmented(views, view, set_view)
	seg.custom_minimum_size = Vector2(360, 0)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(seg)
	_view_box.add_child(center)


func _update_hud() -> void:
	var hints: Dictionary = task.stick_hint if _overlay == null else {}
	var hl: Vector2 = hints.get("left", Vector2.ZERO)
	var hr: Vector2 = hints.get("right", Vector2.ZERO)
	if _mode1:
		# Tasks give hints in Mode 2; in Mode 1 the up/down halves change sticks.
		var l := Vector2(hl.x, hr.y)
		hr = Vector2(hr.x, hl.y)
		hl = l
	_left.hint = hl
	_right.hint = hr
	if machine == "ugv" and task.load_kind != _shown_load:
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
	if _bar_fill:
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
	if _stats.has("TARGET"):
		_stats["TARGET"].text = tr("UNIT_M") % FlightTask.num(task.target_dist, 0)
		_stats["CLOSING"].text = ("+" if task.closing >= 0.0 else "") + tr("UNIT_MS") % FlightTask.num(task.closing)
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


# --- Survey camera ----------------------------------------------------------

## The shutter and the picture it takes live in PhotoKit; the tests call these too.
func shutter() -> void:
	PhotoKit.shoot(self)


func _picture() -> Image:
	return await PhotoKit.picture(self)


func report_answer(i: int, option: String) -> void:
	task.answer(i, option)
	if task.report_open:
		_show_overlay(Report.card(self, task))
	else:
		_hide_overlay()


# --- Pause, passed, crashed --------------------------------------------------

func pause() -> void:
	if _finished:
		return
	_paused = true
	_sound.hush(true)
	_show_overlay(FlightCards.pause(self))


func resume() -> void:
	_paused = false
	_sound.hush(false)
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
	_sound.stop_motors()
	_sound.play("chime")
	if task.is_mission:
		Prefs.mark_mission(task_key)
	else:
		Prefs.mark_passed(vehicle, Curriculum.lessons(vehicle, mode).find(task_key))
	var got := Rating.sunflowers(task_key, mode, sim.time, _touches)
	var before := Prefs.record(task_key, got, sim.time)
	_show_overlay(FlightCards.passed(self, got, before, _next_task()))


func _crashed() -> void:
	_finished = true
	_sound.stop_motors()
	_sound.play("thud")
	_show_overlay(FlightCards.crashed(self))


func _not_this_time() -> void:
	_finished = true
	_sound.stop_motors()
	_sound.play("fail")
	_show_overlay(FlightCards.not_this_time(self))


func _next_task() -> String:
	if task.is_mission:
		return ""
	var list := Curriculum.lessons(vehicle, mode)
	var i := list.find(task_key)
	if i >= 0 and i + 1 < list.size() and FlightTask.implemented(list[i + 1]):
		return list[i + 1]
	return ""


func _show_overlay(content: Control) -> void:
	_hide_overlay()
	# Touches behind a card must not move the sticks.
	for st in [_left, _right]:
		st.release()
		st.enabled = false
	_overlay = FlightCards.overlay(content, get_viewport_rect().size.y)
	add_child(_overlay)


func _hide_overlay() -> void:
	_left.enabled = true
	_right.enabled = true
	if _overlay:
		_overlay.queue_free()
		_overlay = null
