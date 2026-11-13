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
var _view_box := VBoxContainer.new()
var _overlay: Control
## The survey camera's buttons, when the task is flown with a camera.
var _kit: PhotoKit
var _paused := false
var _rebuild_queued := false
var _view_compact := false
var _view_icon := false
var _finished := false
## Nothing moves and no time counts until the pilot first moves a stick.
var _waiting := true
## Seconds with no step forward in the task.
var _stuck := 0.0
## Kids get help after this long with no step forward.
const KIDS_HELP_AFTER := 15.0
var _first_sticks := {}
var _sticks := {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
var _input := FlightInput.new()
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
	# No radio link: the robot gets no commands and stops by itself.
	_sticks = task.controls(_sticks)
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
	_sticks = autopilot.call(sim, task) if autopilot.is_valid() else _input.read(self)


# --- Camera -----------------------------------------------------------------

func _place_camera(delta: float) -> void:
	FlightCamera.place(self, delta)


func set_view(v: String) -> void:
	view = v
	Prefs.set_view(mode, vehicle, v)
	cam.position = Vector3.ZERO
	_build_view_toggle()


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

	_build_bottom(col, ins)
	_build_view_toggle()
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


func _build_bottom(col: VBoxContainer, ins: Dictionary) -> void:
	# Sticks and the view switch at the bottom.
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sticks as big as fit beside the view switch and any camera or action buttons. When the full
	# switch leaves too little room (narrow phones, the largest text), it becomes one button that
	# steps through the views.
	var room := get_viewport_rect().size.x - 2.0 * SIDE - float(ins["left"]) - float(ins["right"]) - 24.0
	if (task is PhotoTask and task.kit) or task.action != "":
		room -= 96.0
	_view_compact = (room - VIEW_FULL) / 2.0 < 104.0
	room -= VIEW_COMPACT if _view_compact else VIEW_FULL
	# A square screen (an unfolded phone held upright) is narrower still: the button shows only
	# its icon.
	_view_icon = _view_compact and room / 2.0 < 92.0
	if _view_icon:
		room += VIEW_COMPACT - 60.0
	var stick_px := int(clampf(room / 2.0, 80.0, 150.0 if mode == "kids" else 128.0))
	for s in [_left, _right]:
		s.kids = mode == "kids"
		s.custom_minimum_size = Vector2(stick_px, stick_px)
	# The FPV throttle stays where the thumb leaves it, like on a real radio, and starts at zero.
	if machine in ["fpv", "wing"] and mode != "kids":
		_thr.spring_y = false
		# A plane that starts in the air has its motor already running at cruise.
		_thr.value.y = sim.throttle01 * 2.0 - 1.0 if sim is WingSim else -1.0
	var left_label := "STICK_LEFT_FPV" if not _left.spring_y and machine == "fpv" else "STICK_LEFT"
	var right_label := "STICK_RIGHT"
	if machine == "wing":
		left_label = "STICK_LEFT_WING"
		right_label = "STICK_RIGHT_WING"
	if _mode1:
		left_label = "STICK_LEFT_WING_M1" if machine == "wing" else "STICK_LEFT_M1"
		right_label = {"fpv": "STICK_RIGHT_FPV_M1", "wing": "STICK_RIGHT_WING_M1"}.get(machine, "STICK_RIGHT_M1")
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


func _stick_with_label(s: Stick, text: String) -> Control:
	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	if mode != "kids":
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


func _build_view_toggle() -> void:
	for c in _view_box.get_children():
		c.queue_free()
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_box.add_child(fill)
	var views := [["ugv", Curriculum.label("VIEW_DRONE")], ["chase", Curriculum.label("VIEW_BEHIND")], ["pilot", Curriculum.label("VIEW_PILOT")]] if machine == "ugv" \
		else [["fpv", Curriculum.label("VIEW_FPV")], ["chase", Curriculum.label("VIEW_CHASE")], ["pilot", Curriculum.label("VIEW_PILOT")]] if machine == "fpv" \
		else [["chase", Curriculum.label("VIEW_CHASE_WING")], ["pilot", Curriculum.label("VIEW_PILOT")], ["fpv", Curriculum.label("VIEW_NOSE")]] if machine == "wing" \
		else [["pilot", Curriculum.label("VIEW_PILOT")], ["chase", Curriculum.label("VIEW_CHASE")], ["drone", Curriculum.label("VIEW_DRONE")]]
	var center := CenterContainer.new()
	if _view_compact:
		center.add_child(_view_cycle(views))
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view_box.add_child(center)
		return
	var seg := UI.segmented(views, view, set_view)
	seg.custom_minimum_size = Vector2(VIEW_FULL, 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(seg)
	_view_box.add_child(center)


## One button showing the view now; a tap moves on to the next one.
func _view_cycle(views: Array) -> Control:
	var i := 0
	for k in views.size():
		if views[k][0] == view:
			i = k
	var next: String = views[(i + 1) % views.size()][0]
	var row := UI.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Glyph.make("camera", 18, Pal.c("text")))
	if not _view_icon:
		row.add_child(UI.label(views[i][1], UI.SMALL, 700, "text", false, false))
	var glass := Pal.c("bg")
	glass.a = 0.78
	var t := UI.tappable(row, glass, func(): set_view(next), tr("A11Y_VIEW") % views[i][1], UI.RADIUS_PILL, 12)
	t.custom_minimum_size = Vector2(52 if _view_icon else VIEW_COMPACT, 52)
	return t


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
