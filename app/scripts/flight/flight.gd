# SPDX-License-Identifier: GPL-3.0-or-later
# The flight screen: the 3D world, the drone, two sticks, a thin status line and one hint.
class_name Flight
extends Control

const STEP := 1.0 / 60.0
## Width of the progress and meter bars.
const BAR_W := 120.0
## Side margin of the HUD: clear of Android's back-swipe edge.
const SIDE := 28.0
## Widths of the view switch, full and as one cycling button.
const VIEW_FULL := 360.0
const VIEW_COMPACT := 150.0

var app: Node  # main.gd
var vehicle := "camera"
## What is flown: the course's machine ("camera", "fpv", "ugv" or "wing").
var machine := "camera"
var task_key := "CAM_STICKS"
var mode := "simple"
var look := "dusk"
## Which world and task variant to build; tests and "Start over" keep it, a new attempt changes it.
var flight_seed := 7
## Practice: the same task with no timer, no sunflowers and nothing saved.
var practice := false
## Tests set this to fly by themselves: func(sim, task) -> {"throttle", "yaw", "pitch", "roll"}.
var autopilot := Callable()

var sim: DroneSim
var task: FlightTask
var world: FlightWorld
var drone: Node3D  # DroneView, UgvView or WingView
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
## The plane's speed tape and wind arrow, when shown.
var _tape: Control
var _wind_arrow: Control
var _lean_gauge: Control
var _view_box := VBoxContainer.new()
var _overlay: Control
## The survey camera's buttons, when the task is flown with a camera.
var _kit: PhotoKit
var _paused := false
var _rebuild_queued := false
var _view_compact := false
var _view_icon := false
var _finished := false
var _sock: Node3D
## The camera drone's way home (not for kids); null for other machines.
var home: FlightHome
var _hint_warn := false
## A short message of the flight itself (a translation key), how long it stays, and if it warns.
var _alert := ""
var _alert_t := 0.0
var _alert_warn := false
var _arm_label: Label
## Nothing moves and no time counts until the pilot first moves a stick.
var _waiting := true
## Seconds with no step forward in the task.
var _stuck := 0.0
## Kids get help after this long with no step forward.
const KIDS_HELP_AFTER := 15.0
var _first_sticks := {}
var _sticks := {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
var _pad := FlightInput.new()
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
	# The plane needs room: a flat valley along the runway for take-offs and landings.
	world.airfield = machine == "wing"
	add_child(world)
	world.build(look, 7)
	task.world = world
	task.setup_world()
	if task.view_hint != "":
		view = task.view_hint

	sim = task.make_sim(machine)
	if machine == "camera" and mode != "kids" and not task.is_free:
		home = FlightHome.new()
	if sim is FpvSim and mode == "pro":
		sim.armed = false  # armed with a button, throttle down, as on a real drone
	if task is PhotoTask:
		var vp := get_viewport_rect().size
		task.aspect = vp.x / maxf(vp.y, 1.0)

	if machine == "ugv":
		drone = UgvView.new()
		world.add_child(drone)
		drone.build(world.pal["drone"], world.pal["drone_front"], task.load_kind)
		_shown_load = task.load_kind
	elif machine == "wing":
		drone = WingView.new()
		world.add_child(drone)
		drone.build(world.pal["drone"], world.pal["drone_front"])
		# A windsock beside the runway's near end, where the pilot can see it.
		var at := Vector3(WorldLand.RUNWAY_X + WorldLand.RUNWAY_W / 2.0 + 4.0, 0, WorldLand.RUNWAY_Z0 - 8.0)
		at.y = world.height(at.x, at.z)
		_sock = AirProps.add_windsock(world, at)
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
	# The photo report is a pause too: reading and answering must not cost
	# time or battery (the PAR times were measured without it).
	if task is PhotoTask and task.report_open:
		return
	_read_sticks()
	if autopilot.is_valid() and sim is FpvSim:
		sim.armed = true
	elif FlightBottom.arm_button(self):
		var sw := _pad.arm_switch()
		if sw != 0 and (sw > 0) != sim.armed:
			_toggle_arm()
	_alert_t = maxf(0.0, _alert_t - STEP)
	var pilot := _sticks
	# No radio link: the robot gets no commands and stops by itself.
	_sticks = task.controls(_sticks)
	if home and not _waiting:
		home.update(sim, task, STEP)
		home.take_back(pilot, task.link_ok)
		if home.active:
			_sticks = home.sticks(sim, world.pad)
	if _waiting and not _ready_to_go():
		task.step(0.0, sim, _sticks)  # sets the first hints; no time passes
	else:
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


## The flight starts with the first move of a stick, so reading the goal costs no time. Tests and
## free flight start at once.
func _ready_to_go() -> bool:
	if autopilot.is_valid() or task_key.begins_with("FREE_"):
		_waiting = false
		return true
	if _first_sticks.is_empty():
		_first_sticks = _sticks.duplicate()
		return false
	for k in _sticks:
		if absf(float(_sticks[k]) - float(_first_sticks[k])) > 0.12:
			_waiting = false
			return true
	return false


func kids_help() -> bool:
	return mode == "kids" and _stuck > KIDS_HELP_AFTER and task.marker != Vector3.INF


func _process(delta: float) -> void:
	drone.sync(sim, delta)
	if _sock:
		AirProps.blow_windsock(_sock, sim.wind())
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
	if sim is FpvSim or sim is WingSim:
		return sim.throttle01
	var h := Vector2(sim.vel.x, sim.vel.z).length() / 8.0
	return clampf(0.45 + 0.3 * _sticks["throttle"] + 0.25 * h, 0.2, 1.0)


func _motors_running() -> bool:
	if sim.crashed:
		return false
	if sim is UgvSim:
		return true
	if sim is WingSim:
		return sim.throttle01 > 0.02
	return not sim.on_ground or _sticks["throttle"] > 0.05 or (sim is FpvSim and sim.throttle01 > 0.05)


## A blip for each step forward in the task (a ball taken, a gate flown: progress jumps in one step,
## while holding or approaching only creeps), a thud for each hard bump.
func _sound_events() -> void:
	var jumped := task.progress - _last_progress >= 0.04 or task.counter > _last_counter
	if jumped and not task.done:
		_sound.play("blip")
	# Kids: a while with no step forward brings a gentle reminder of where to go.
	_stuck = 0.0 if task.progress != _last_progress or task.counter != _last_counter else _stuck + STEP
	_last_progress = task.progress
	_last_counter = task.counter
	for e in sim.events:
		if Rating.is_touch(e):
			_touches += 1
		if e["type"] in ["bump", "crash", "tipped"] and float(e["speed"]) > 1.0:
			_sound.play("thud")


func _read_sticks() -> void:
	_sticks = autopilot.call(sim, task) if autopilot.is_valid() else _pad.read(self)


# --- Camera -----------------------------------------------------------------

func _place_camera(delta: float) -> void:
	FlightCamera.place(self, delta)


func set_view(v: String) -> void:
	view = v
	Prefs.set_view(mode, vehicle, v)
	cam.position = Vector3.ZERO
	FlightBottom.build_view_toggle(self)


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	FlightHud.build_no_signal(self)
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
	# Wide enough at the sides that a thumb on a stick is not taken for Android's back swipe.
	m.add_theme_constant_override("margin_left", SIDE + int(ins["left"]))
	m.add_theme_constant_override("margin_right", SIDE + int(ins["right"]))
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

	top.add_child(UI.panel(FlightHud.build_chip(self), glass, 16, 10))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)

	FlightHud.build_counters(self, top, glass)
	col.add_child(top)
	FlightHud.fit_top(self, top)

	_build_hint(col)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)

	FlightBottom.build_bottom(self, col, ins)
	FlightBottom.build_view_toggle(self)
	if not get_viewport().size_changed.is_connected(_on_resize):
		get_viewport().size_changed.connect(_on_resize)


## The screen turned, folded or unfolded (Android may also turn it only after the flight opened):
## build the HUD again for the new size, keeping the throttle where it was.
func _on_resize() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_hud.call_deferred()


func _rebuild_hud() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var thr_y := _thr.value.y
	var was_enabled := _left.enabled
	_hud.queue_free()
	_nolink.queue_free()
	_hud = Control.new()
	_marks = Control.new()
	_hint = Label.new()
	_hint_panel = PanelContainer.new()
	_bar_fill = Panel.new()
	_bar_text = null
	_meter_fill = null
	_counter = null
	_kit = null
	_stats = {}
	_tape = null
	_arm_label = null
	_wind_arrow = null
	_lean_gauge = null
	_view_box = VBoxContainer.new()
	_left = Stick.new()
	_right = Stick.new()
	_thr = _right if _mode1 else _left
	_fwd = _left if _mode1 else _right
	_build_hud()
	if not _thr.spring_y:
		_thr.value.y = thr_y
	_left.enabled = was_enabled
	_right.enabled = was_enabled
	if _overlay:
		move_child(_overlay, -1)  # the open card stays on top


## How tall the band of sticks along the bottom is, so marks can keep clear of it.
func stick_band() -> float:
	return _left.custom_minimum_size.y + 44.0


## The top line must fit the screen: drop the least needed numbers until it does.
func _ins_x() -> float:
	var ins: Dictionary = app.insets() if app else {}
	return float(ins.get("left", 0.0)) + float(ins.get("right", 0.0))


func _build_hint(col: VBoxContainer) -> void:
	# One hint, in the middle under the top line.
	var hint_row := CenterContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", Pal.font(700))
	# The reader's text size reaches the flight too: the hint is what they must read.
	_hint.add_theme_font_size_override("font_size", roundi((19 if mode == "kids" else 16) * Pal.text_scale()))
	_hint.add_theme_color_override("font_color", Pal.c("bg"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_theme_stylebox_override("panel", UI.box(Pal.c("text"), 12, 9))
	_hint_panel.add_child(_hint)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(_hint_panel)
	col.add_child(hint_row)


func _toggle_arm() -> void:
	var f := sim as FpvSim
	if f.armed:
		if f.on_ground:
			f.armed = false
		return
	if _thr.value.y > -0.9:
		alert("HINT_ARM_THROTTLE", true)
		return
	f.armed = true
	alert("HINT_ARMED", false)


## A radio's or gamepad's own buttons: pause, the next view, arm.
func _input(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	match FlightInput.button_action(event):
		"pause":
			if _paused:
				resume()
			elif not _finished:
				pause()
		"view":
			if not _paused and not _finished:
				FlightBottom.next_view(self)
		"arm":
			if FlightBottom.arm_button(self) and not _paused:
				_toggle_arm()


func alert(key: String, warn: bool, seconds := 3.0) -> void:
	_alert = key
	_alert_t = seconds
	_alert_warn = warn


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
		_meter_fill.size = Vector2(BAR_W * m, 6)
		var col := "ok" if m > 0.5 else ("warn" if m > 0.25 else "bad")
		(_meter_fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Pal.c(col)
	if _nolink:
		_nolink.visible = not task.link_ok and view == "ugv"
	if _bar_fill:
		_bar_fill.size = Vector2(BAR_W * task.progress, 6)
	if _bar_text:
		_bar_text.text = "%d %%" % int(round(task.progress * 100.0))
	var ready := "HINT_PRACTICE" if practice else Curriculum.text_key("HINT_READY", mode)
	var hint_key := ready if _waiting and (task.hint == "" or practice) else task.hint
	if kids_help():
		hint_key = "HINT_KIDS_HELP"
	var warn := false
	if sim is FpvSim and not sim.armed:
		hint_key = "HINT_ARM"
	if home and home.alert != "":
		hint_key = home.alert
		warn = home.alert_warn
	if _alert_t > 0.0:
		hint_key = _alert
		warn = _alert_warn
	if _arm_label:
		_arm_label.get_parent().get_parent().visible = not sim.armed or sim.on_ground
		_arm_label.text = tr("DISARM" if sim.armed else "ARM")
	if warn != _hint_warn:
		_hint_warn = warn
		_hint_panel.add_theme_stylebox_override("panel", UI.box(Pal.c("warn" if warn else "text"), 12, 9))
	if hint_key != "":
		var text := tr(hint_key)
		if not task.hint_args.is_empty() and text.contains("%"):
			text = text % task.hint_args
		if text != _hint.text:
			_hint.text = text
			# Short hints sit on one line; long ones wrap at a comfortable width.
			var w := _hint.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint.get_theme_font_size("font_size")).x
			var wrap := minf(520.0, get_viewport_rect().size.x - 2.0 * SIDE - _ins_x() - 24.0)
			_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > wrap else TextServer.AUTOWRAP_OFF
			_hint.custom_minimum_size = Vector2(wrap, 0) if w > wrap else Vector2.ZERO
	_hint_panel.visible = hint_key != ""
	if _counter:
		_counter.text = "%d / %d" % [task.counter, task.counter_max]
	if _stats.has("ALT"):
		_stats["ALT"].text = tr("UNIT_M") % FlightTask.num(maxf(0.0, sim.altitude()))
	if _stats.has("SPEED"):
		_stats["SPEED"].text = tr("UNIT_MS") % FlightTask.num(Vector2(sim.vel.x, sim.vel.z).length())
	if _stats.has("AIRSPEED"):
		_stats["AIRSPEED"].text = tr("UNIT_MS") % FlightTask.num((sim as WingSim).speed)
		_stats["AIRSPEED"].add_theme_color_override("font_color", Pal.c("warn") if (sim as WingSim).stall_warn else Pal.c("text"))
		_tape.queue_redraw()
	if _stats.has("WIND"):
		_stats["WIND"].text = tr("UNIT_MS") % FlightTask.num(Vector2(sim.wind().x, sim.wind().z).length())
		_wind_arrow.queue_redraw()
	if _stats.has("LEAN"):
		var lean := FlightHud.lean_deg(self)
		var tip := float(sim.p.get("tip", 90.0))
		_stats["LEAN"].text = "%d°" % roundi(lean) + (" / %d°" % roundi(tip) if tip < 90.0 else "")
		_stats["LEAN"].add_theme_color_override("font_color", FlightHud.lean_color(self))
		_lean_gauge.queue_redraw()
	if _stats.has("VERT"):
		var vy := sim.vel.y
		_stats["VERT"].text = ("+" if vy >= 0.05 else "") + tr("UNIT_MS") % FlightTask.num(vy)
	if _stats.has("HOME"):
		_stats["HOME"].text = tr("UNIT_M") % FlightTask.num(FlightTask.flat_distance(sim.pos, world.pad), 0)
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
	FlightMarks.draw(self)


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
	app.open_flight(vehicle, task_key, flight_seed, practice)


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
	if practice:
		_show_overlay(FlightCards.practice_done(self))
		return
	if app:
		app.fails.erase(task_key)
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
	_show_overlay(FlightCards.crashed(self, _fail_streak()))


func _not_this_time() -> void:
	_finished = true
	_sound.stop_motors()
	_sound.play("fail")
	_show_overlay(FlightCards.not_this_time(self, _fail_streak()))


## Tries in a row that did not pass, this one included. Practice tries do not count.
func _fail_streak() -> int:
	if app == null or practice:
		return 0
	app.fails[task_key] = int(app.fails.get(task_key, 0)) + 1
	return app.fails[task_key]


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
