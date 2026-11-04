# SPDX-License-Identifier: GPL-3.0-or-later
# The flight screen: the 3D world, the drone, two sticks, a thin status line and one hint.
extends Control

const STEP := 1.0 / 60.0
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
var drone: DroneView
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
	view = Prefs.view_for(mode)


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

	sim = DroneSim.new(mode, 11)
	sim.gps = task.gps
	if task.wind >= 0.0:
		sim.set_wind(task.wind, task.gust)
	sim.ground = world.height
	sim.obstacles = world.obstacles
	sim.place(task.start_position(), task.start_heading())

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
	sim.step(STEP, _sticks["throttle"], _sticks["yaw"], _sticks["pitch"], _sticks["roll"])
	task.step(STEP, sim, _sticks)
	if task.done:
		_finish()
	elif task.failed:
		_not_this_time()
	elif sim.crashed:
		_crashed()


func _process(delta: float) -> void:
	drone.sync(sim, delta)
	_place_camera(delta)
	world.show_beacon(task.marker, task.beacon)
	_update_hud()
	_marks.queue_redraw()


func _read_sticks() -> void:
	if autopilot.is_valid():
		_sticks = autopilot.call(sim, task)
		return
	var t := _left.value.y
	var y := _left.value.x
	var p := _right.value.y
	var r := _right.value.x
	# A gamepad or a radio in joystick mode (Mode 2).
	for dev in Input.get_connected_joypads():
		t = _bigger(t, -_axis(dev, JOY_AXIS_LEFT_Y))
		y = _bigger(y, _axis(dev, JOY_AXIS_LEFT_X))
		p = _bigger(p, -_axis(dev, JOY_AXIS_RIGHT_Y))
		r = _bigger(r, _axis(dev, JOY_AXIS_RIGHT_X))
	# A keyboard: W/S up and down, A/D turn, arrows move.
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
	if view == "drone":
		# The drone's own camera on a steady gimbal, tilted down a little.
		cam.position = sim.pos + sim.forward() * 0.45 + Vector3(0, 0.2, 0)
		cam.rotation = Vector3(deg_to_rad(-25.0), sim.yaw, 0)
		cam.fov = 75.0
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
		if d > 0.5:
			var look_at := target.lerp(world.pilot + (target - world.pilot) * 0.5, 0.15)
			cam.look_at(look_at, Vector3.UP)


func set_view(v: String) -> void:
	view = v
	Prefs.set_view(mode, v)
	cam.position = Vector3.ZERO
	_build_view_toggle()


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
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
	var title := tr(task_key)
	if not task.is_mission:
		title = tr("LESSON_N") % (Curriculum.lessons(vehicle).find(task_key) + 1) + " · " + title
	chip.add_child(UI.label(title, 13, 700, "text", false, false))
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
	top.add_child(UI.panel(chip, glass, 16, 10))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)

	if mode == "kids":
		if task.counter_max > 0 or task.is_mission:
			var row := UI.hbox(8)
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
		for n in names:
			var s := UI.vbox(1)
			var head := UI.eyebrow(tr("STAT_" + n))
			head.autowrap_mode = TextServer.AUTOWRAP_OFF
			s.add_child(head)
			var v := UI.label("–", 15, 800, "text", false, false)
			_stats[n] = v
			s.add_child(v)
			stats.add_child(s)
		top.add_child(UI.panel(stats, glass, 16, 10))
	col.add_child(top)

	# One hint, in the middle under the top line.
	var hint_row := CenterContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", Pal.font(700))
	_hint.add_theme_font_size_override("font_size", 17 if mode == "kids" else 14)
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
	var stick_px := 150 if mode == "kids" else 128
	for s in [_left, _right]:
		s.kids = mode == "kids"
		s.custom_minimum_size = Vector2(stick_px, stick_px)
	bottom.add_child(_stick_with_label(_left, tr("STICK_LEFT")))
	_view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_view_box)
	bottom.add_child(_stick_with_label(_right, tr("STICK_RIGHT")))
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
		var l := UI.label(text, 11, 700, "muted", false, false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v


func _build_view_toggle() -> void:
	for c in _view_box.get_children():
		c.queue_free()
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_box.add_child(fill)
	var seg := UI.segmented([["pilot", tr("VIEW_PILOT")], ["chase", tr("VIEW_CHASE")], ["drone", tr("VIEW_DRONE")]], view, set_view)
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
	_update_choice()
	_bar_fill.size = Vector2(120.0 * task.progress, 6)
	if _bar_text:
		_bar_text.text = "%d %%" % int(round(task.progress * 100.0))
	if task.hint != "":
		var text := tr(task.hint)
		if not task.hint_args.is_empty():
			text = text % task.hint_args
		if text != _hint.text:
			_hint.text = text
			# Short hints sit on one line; long ones wrap at a comfortable width.
			var w := _hint.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _hint.get_theme_font_size("font_size")).x
			_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if w > 480.0 else TextServer.AUTOWRAP_OFF
			_hint.custom_minimum_size = Vector2(480, 0) if w > 480.0 else Vector2.ZERO
	_hint_panel.visible = task.hint != ""
	if _counter:
		_counter.text = "%d / %d" % [task.counter, task.counter_max] if task.counter_max > 0 else "0"
	if _stats.has("ALT"):
		_stats["ALT"].text = tr("UNIT_M") % ("%.1f" % maxf(0.0, sim.altitude()))
	if _stats.has("SPEED"):
		_stats["SPEED"].text = tr("UNIT_MS") % ("%.1f" % Vector2(sim.vel.x, sim.vel.z).length())
	if _stats.has("BATTERY"):
		_stats["BATTERY"].text = "%d %%" % int(ceil(sim.battery * 100.0))
	if _stats.has("TIME"):
		var t := int(sim.time)
		_stats["TIME"].text = "%d:%02d" % [t / 60, t % 60]


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
			_marks.draw_colored_polygon(PackedVector2Array([tip + dir * 12, tip - dir * 6 + side * 11, tip - dir * 6 - side * 11]), col)
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
	_marks.draw_polyline(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)]), Color("#2A1D3B"), 1.5, true)


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
	col.a = 0.85
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


func restart() -> void:
	app.open_flight(vehicle, task_key)


func leave() -> void:
	app.close_flight()


## Android Back and Escape: pause first, then resume.
func on_back() -> void:
	if _finished:
		leave()
	elif _paused:
		resume()
	else:
		pause()


func _finish() -> void:
	_finished = true
	_left.release()
	_right.release()
	if task.is_mission:
		Prefs.mark_mission(task_key)
	else:
		Prefs.mark_passed(vehicle, Curriculum.lessons(vehicle).find(task_key))
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("PASSED_KIDS") if mode == "kids" else tr("PASSED"), 22, 600, "text", true))
	if task.summary != "":
		var s := tr(task.summary)
		if not task.summary_args.is_empty():
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
	_finished = true
	var col := UI.vbox(12)
	col.add_child(UI.label(tr("CRASHED"), 22, 600, "text", true))
	col.add_child(UI.label(tr("CRASHED_TEXT") % ("%.1f" % sim.crash_speed), 14, 500, "muted"))
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
	if not task.summary_args.is_empty():
		s = s % task.summary_args
	col.add_child(UI.label(s, 14, 500, "muted"))
	col.add_child(UI.primary(tr("AGAIN"), restart, "play"))
	col.add_child(_secondary(tr("EXIT"), leave))
	_show_overlay(col)


func _next_task() -> String:
	if task.is_mission:
		return ""
	var list := Curriculum.lessons(vehicle)
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
