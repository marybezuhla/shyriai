# SPDX-License-Identifier: GPL-3.0-or-later
# Tests of the drone physics and of every lesson: each lesson must be passable with the sticks alone,
# in every mode. CI fails if anything here fails. Not shipped in the APK.
extends Node

const Autopilot := preload("res://tests/autopilot.gd")
const DT := 1.0 / 60.0

var failures := 0


func _ready() -> void:
	test_hover_holds_with_gps()
	test_atti_drifts_with_wind()
	test_landing_assist()
	test_kids_never_crash()
	test_adult_crashes_into_a_house()
	test_battery_lands_by_itself()
	for mode in Prefs.MODES:
		await test_sticks_lesson(mode)
		await test_takeoff_lesson(mode)
		await test_hold_lesson(mode)
	for mode in Prefs.MODES:
		await test_course_lesson("CAM_NOSE_IN", mode)
		await test_course_lesson("CAM_SQUARE", mode)
		await test_landing_lesson(mode)
		await test_course_lesson("CAM_WIND", mode)
		await test_exam(mode)
	await test_exam_fails_on_a_bump()
	await test_nose_rule("CAM_NOSE_IN")
	await test_nose_rule("CAM_SQUARE")
	await test_kitten_mission()
	for mode in ["simple", "pro"]:
		await test_search_mission(mode)
		await test_survey_mission(mode)
	await test_survey_wrong_answers_fail()
	if failures == 0:
		print("SIM OK")
		get_tree().quit(0)
	else:
		print("SIM FAILED: %d" % failures)
		get_tree().quit(1)


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func run(sim: DroneSim, seconds: float, t: float, y: float, p: float, r: float) -> void:
	for i in int(seconds / DT):
		sim.step(DT, t, y, p, r)


# --- Physics ----------------------------------------------------------------

func test_hover_holds_with_gps() -> void:
	var sim := DroneSim.new("simple")
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	var start := sim.pos
	run(sim, 10.0, 0, 0, 0, 0)
	check(absf(sim.vel.y) < 0.05, "hover: climb stops when the stick is let go")
	check(Vector2(sim.pos.x - start.x, sim.pos.z - start.z).length() < 0.3, "hover: GPS holds the spot in wind")


func test_atti_drifts_with_wind() -> void:
	var sim := DroneSim.new("simple")
	sim.gps = false
	sim.set_wind(1.5, 0.0)
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	var start := sim.pos
	run(sim, 5.0, 0, 0, 0, 0)
	check(Vector2(sim.pos.x - start.x, sim.pos.z - start.z).length() > 3.0, "ATTI: the wind carries the drone")


func test_landing_assist() -> void:
	for mode in ["kids", "simple"]:
		var sim := DroneSim.new(mode)
		sim.place(Vector3.ZERO)
		run(sim, 3.0, 1.0, 0, 0, 0)
		var speed := -1.0
		for i in 900:
			sim.step(DT, -1.0, 0, 0, 0)
			for e in sim.events:
				if e["type"] == "landed":
					speed = e["speed"]
		check(speed >= 0.0 and speed <= 0.45, "%s: full stick down still lands softly (%.2f m/s)" % [mode, speed])


func test_kids_never_crash() -> void:
	var sim := DroneSim.new("kids")
	sim.obstacles = [{"box": AABB(Vector3(-3, 0, -12), Vector3(6, 6, 2))}]
	sim.place(Vector3.ZERO)
	run(sim, 1.5, 1.0, 0, 0, 0)
	run(sim, 8.0, 0, 0, 1.0, 0)
	check(not sim.crashed, "kids: flying into a wall bounces, never crashes")
	check(sim.pos.z > -9.7, "kids: the wall stops the drone")


func test_adult_crashes_into_a_house() -> void:
	var sim := DroneSim.new("pro")
	sim.obstacles = [{"box": AABB(Vector3(-3, 0, -30), Vector3(6, 6, 2))}]
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 1.0, 0, 0, 0)
	run(sim, 8.0, 0, 0, 1.0, 0)
	check(sim.crashed, "adult: full speed into a wall crashes")


func test_battery_lands_by_itself() -> void:
	var sim := DroneSim.new("pro")
	sim.p["battery_s"] = 5.0
	sim.place(Vector3.ZERO)
	run(sim, 2.0, 1.0, 0, 0, 0)
	run(sim, 20.0, 0.5, 0, 0, 0)
	check(sim.battery <= 0.0 and sim.on_ground, "adult: an empty battery brings the drone down")


# --- Lessons, flown with the sticks ---------------------------------------------

func _flight(key: String, mode: String) -> Array:
	var task := FlightTask.make(key, mode, 7)
	var world := FlightWorld.new()
	add_child(world)
	world.build("day", 7)
	task.world = world
	task.setup_world()
	var sim := DroneSim.new(mode, 11)
	sim.gps = task.gps
	if task.wind >= 0.0:
		sim.set_wind(task.wind, task.gust)
	sim.ground = world.height
	sim.obstacles = world.obstacles
	sim.place(task.start_position(), task.start_heading())
	return [task, sim, world]


func _fly(task: FlightTask, sim: DroneSim, seconds: float, pick: Callable) -> bool:
	for i in int(seconds / DT):
		var s: Dictionary = pick.call(i * DT)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done:
			return true
		if sim.crashed or task.failed:
			return false
	return false


func test_sticks_lesson(mode: String) -> void:
	var f := _flight("CAM_STICKS", mode)
	var plan := func(t: float) -> Dictionary:
		var s := {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}
		if t < 2.5:
			s["throttle"] = 1.0
		elif t < 6.0:
			s["yaw"] = 1.0
		elif t < 9.0:
			s["pitch"] = 1.0
		elif t < 12.0:
			s["roll"] = 1.0
		return s
	check(_fly(f[0], f[1], 20.0, plan), "%s: lesson 1 (sticks) passes" % mode)
	f[2].queue_free()
	await get_tree().process_frame


func test_takeoff_lesson(mode: String) -> void:
	var f := _flight("CAM_TAKEOFF", mode)
	var ap := Autopilot.new()
	ap.target = f[2].pad
	ap.height = 2.0
	# Adult mode has no landing help, so the test pilot comes down gently.
	ap.descend = -0.12 if mode == "pro" else -0.6
	var task: FlightTask = f[0]
	var plan := func(_t: float) -> Dictionary:
		ap.land = task.hint == "HINT_TAKEOFF_LAND"
		return ap.sticks(f[1])
	var ok := _fly(task, f[1], 60.0, plan)
	check(ok, "%s: lesson 2 (take-off and landing) passes%s" % [mode, "" if ok else " — " + task.hint])
	f[2].queue_free()
	await get_tree().process_frame


func test_hold_lesson(mode: String) -> void:
	var f := _flight("CAM_HOLD", mode)
	var ap := Autopilot.new()
	ap.target = f[2].hold_mark
	ap.height = 3.0
	var ok := _fly(f[0], f[1], 90.0, func(_t): return ap.sticks(f[1]))
	check(ok, "%s: lesson 3 (hold in the wind) passes" % mode)
	f[2].queue_free()
	await get_tree().process_frame


## Flies any course lesson: to each sphere in turn, with the nose where the lesson wants it.
func _course_plan(task: FlightTask, sim: DroneSim, world: FlightWorld, ap) -> Callable:
	return func(_t: float) -> Dictionary:
		var t := task.course_world_target()
		if t != Vector3.INF:
			ap.target = t
			ap.height = task.cps[task.cp].y
		ap.face_travel = task.cp_facing == "travel"
		ap.face = world.pilot if task.cp_facing == "pilot" else Vector3.INF
		return ap.sticks(sim)


func test_course_lesson(key: String, mode: String) -> void:
	var f := _flight(key, mode)
	var ap := Autopilot.new()
	var ok := _fly(f[0], f[1], 150.0, _course_plan(f[0], f[1], f[2], ap))
	check(ok, "%s: %s passes%s" % [mode, key, "" if ok else " — " + f[0].hint])
	f[2].queue_free()
	await get_tree().process_frame


func _lander(task: FlightTask, sim: DroneSim, world: FlightWorld, ap, mode: String) -> Callable:
	ap.descend = -0.12 if mode == "pro" else -0.6
	return func(_t: float) -> Dictionary:
		var settled := FlightTask.flat_distance(sim.pos, world.pad) < 0.15 and Vector2(sim.vel.x, sim.vel.z).length() < 0.25
		ap.target = world.pad
		ap.height = 3.0
		ap.face = Vector3.INF
		ap.face_travel = false
		ap.land = settled or (ap.land and sim.altitude() < 2.9)
		return ap.sticks(sim)


func test_landing_lesson(mode: String) -> void:
	var f := _flight("CAM_LANDING", mode)
	var task: FlightTask = f[0]
	var ap := Autopilot.new()
	var land := _lander(task, f[1], f[2], ap, mode)
	var plan := func(t: float) -> Dictionary:
		if task._approach:
			ap.land = false
			ap.target = task.SIDES[task._round]
			ap.height = 3.0
			return ap.sticks(f[1])
		return land.call(t)
	var ok := _fly(task, f[1], 150.0, plan)
	check(ok, "%s: CAM_LANDING passes%s" % [mode, "" if ok else " — " + task.hint])
	f[2].queue_free()
	await get_tree().process_frame


func test_exam(mode: String) -> void:
	var f := _flight("CAM_EXAM", mode)
	var task: FlightTask = f[0]
	var ap := Autopilot.new()
	var course := _course_plan(task, f[1], f[2], ap)
	var land := _lander(task, f[1], f[2], ap, mode)
	var plan := func(t: float) -> Dictionary:
		match task._stage:
			0:
				ap.target = f[2].pad
				ap.height = 2.5
				return ap.sticks(f[1])
			3:
				return land.call(t)
		return course.call(t)
	var ok := _fly(task, f[1], 200.0, plan)
	check(ok, "%s: CAM_EXAM passes%s" % [mode, "" if ok else " — " + task.hint + " " + task.summary])
	f[2].queue_free()
	await get_tree().process_frame


## The same course flown without turning the nose as asked must not pass.
func test_nose_rule(key: String) -> void:
	var f := _flight(key, "simple")
	var task: FlightTask = f[0]
	f[1].yaw = wrapf(task.start_heading() + PI, -PI, PI)  # nose the other way round
	var ap := Autopilot.new()
	var course := _course_plan(task, f[1], f[2], ap)
	var plan := func(t: float) -> Dictionary:
		var s: Dictionary = course.call(t)
		s["yaw"] = 0.0  # never turns
		return s
	check(not _fly(task, f[1], 90.0, plan), "simple: %s does not pass with the nose the wrong way" % key)
	f[2].queue_free()
	await get_tree().process_frame


func test_exam_fails_on_a_bump() -> void:
	var f := _flight("CAM_EXAM", "simple")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	# Fly straight into the nearest house.
	var house: Vector3 = f[2].houses[2]["pos"]
	var ap := Autopilot.new()
	ap.target = house
	ap.height = 2.0
	_fly(task, sim, 60.0, func(_t): return ap.sticks(sim))
	check(task.failed and task.summary == "FAIL_EXAM_BUMP", "simple: the exam fails on touching a house")
	f[2].queue_free()
	await get_tree().process_frame


func test_search_mission(mode: String) -> void:
	var f := _flight("MIS_CAM_SEARCH", mode)
	var task: FlightTask = f[0]
	var ap := Autopilot.new()
	var land := _lander(task, f[1], f[2], ap, mode)
	var plan := func(t: float) -> Dictionary:
		if task.hint == "HINT_SEARCH_BACK" or task._found:
			# Climb back over the poplars before coming down.
			if FlightTask.flat_distance(f[1].pos, f[2].pad) > 3.0:
				ap.land = false
				ap.target = f[2].pad
				ap.height = 14.0
				return ap.sticks(f[1])
			return land.call(t)
		ap.target = task.person()
		ap.height = 14.0
		return ap.sticks(f[1])
	var ok := _fly(task, f[1], 240.0, plan)
	check(ok, "%s: the search mission passes%s" % [mode, "" if ok else " — " + task.hint])
	f[2].queue_free()
	await get_tree().process_frame


func test_survey_mission(mode: String) -> void:
	var f := _flight("MIS_CAM_SURVEY", mode)
	var task: FlightTask = f[0]
	var ap := Autopilot.new()
	ap.height = 9.0
	var plan := func(_t: float) -> Dictionary:
		if not task.choice.is_empty():
			task.choose("damaged" if task.truth(task._near) else "ok")
		if task.marker != Vector3.INF:
			ap.target = task.marker
		return ap.sticks(f[1])
	var ok := _fly(task, f[1], 300.0, plan)
	check(ok, "%s: the roof survey passes%s" % [mode, "" if ok else " — " + task.hint + " " + task.summary])
	f[2].queue_free()
	await get_tree().process_frame


func test_survey_wrong_answers_fail() -> void:
	var f := _flight("MIS_CAM_SURVEY", "simple")
	var task: FlightTask = f[0]
	var ap := Autopilot.new()
	ap.height = 9.0
	var plan := func(_t: float) -> Dictionary:
		if not task.choice.is_empty():
			task.choose("ok")  # says every roof is fine
		if task.marker != Vector3.INF:
			ap.target = task.marker
		return ap.sticks(f[1])
	_fly(task, f[1], 300.0, plan)
	check(task.failed and task.summary == "FAIL_SURVEY", "simple: calling damaged roofs intact does not pass")
	f[2].queue_free()
	await get_tree().process_frame


func test_kitten_mission() -> void:
	var f := _flight("MIS_CAM_KITTEN", "kids")
	var task: FlightTask = f[0]
	var world: FlightWorld = f[2]
	var ap := Autopilot.new()
	ap.height = 8.5
	var plan := func(_t: float) -> Dictionary:
		var sim: DroneSim = f[1]
		if task.hint == "HINT_KITTEN_FIND":
			ap.target = world.kitten
			ap.height = 8.5
		else:
			ap.target = world.pad
			ap.height = 8.5 if FlightTask.flat_distance(sim.pos, world.pad) > 2.0 else 1.5
		return ap.sticks(sim)
	check(_fly(task, f[1], 180.0, plan), "kids: the kitten mission passes (hint: %s)" % task.hint)
	world.queue_free()
	await get_tree().process_frame
