# SPDX-License-Identifier: GPL-3.0-or-later
# Tests of the drone physics and of every lesson: each lesson must be passable with the sticks alone,
# in every mode. CI fails if anything here fails. Not shipped in the APK.
extends Node

const Autopilot := preload("res://tests/autopilot.gd")
const FpvAutopilot := preload("res://tests/fpv_autopilot.gd")
const DT := 1.0 / 60.0

var failures := 0


func _ready() -> void:
	test_hover_holds_with_gps()
	test_atti_drifts_with_wind()
	test_landing_assist()
	test_kids_never_crash()
	test_adult_crashes_into_a_house()
	test_battery_lands_by_itself()
	test_fpv_physics()
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
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("fpv", mode):
			await test_fpv_task(key, mode)
	await test_fpv_task("MIS_FPV_HOOPS", "kids")
	await test_fpv_task("MIS_FPV_BALLOONS", "kids")
	for mode in ["simple", "pro"]:
		await test_fpv_task("MIS_FPV_RACE", mode)
		await test_fpv_task("MIS_FPV_TREES", mode)
	await test_trees_over_fails()
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


func test_fpv_physics() -> void:
	# Hover throttle holds the height; nothing else does.
	var sim := FpvSim.new("simple")
	sim.set_wind(0.0, 0.0)
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 0.6, 0, 0, 0)
	var h := sim.hover_throttle() * 2.0 - 1.0
	run(sim, 4.0, h, 0, 0, 0)
	check(absf(sim.vel.y) < 0.2 and not sim.on_ground, "FPV: hover throttle keeps it in the air")
	run(sim, 2.0, -1.0, 0, 0, 0)
	check(sim.vel.y < -1.0 or sim.on_ground, "FPV: no throttle and it falls")
	# Angle: the stick tilts it, letting go levels it.
	sim.place(Vector3.ZERO)
	run(sim, 1.0, 0.6, 0, 0, 0)
	run(sim, 1.0, h, 0, 1.0, 0)
	var leaned := sim.tilt_angles().x
	run(sim, 1.0, h, 0, 0, 0)
	check(leaned > deg_to_rad(25.0) and absf(sim.tilt_angles().x) < deg_to_rad(3.0), "FPV angle: tilts to the stick and levels when let go")
	# Acro: it keeps the turn it was given.
	var pro := FpvSim.new("pro")
	pro.set_wind(0.0, 0.0)
	pro.flight_mode = "acro"
	pro.place(Vector3.ZERO)
	run(pro, 0.8, 0.6, 0, 0, 0)
	run(pro, 0.15, pro.hover_throttle() * 2.0 - 1.0, 0, 0.5, 0)
	var before := pro.tilt_angles().x
	run(pro, 0.5, pro.hover_throttle() * 2.0 - 1.0, 0, 0, 0)
	# It turns on a little after the stick (the turn has momentum), then holds: it never levels.
	check(before > deg_to_rad(10.0) and pro.tilt_angles().x > before - deg_to_rad(1.0) and pro.tilt_angles().x < before + deg_to_rad(10.0),
		"FPV acro: the tilt stays after letting go")
	# Adult: a hard hit on the ground crashes.
	var c := FpvSim.new("pro")
	c.place(Vector3(0, 12, 0))
	c.on_ground = false
	run(c, 3.0, -1.0, 0, 0, 0)
	check(c.crashed, "FPV adult: falling from 12 m crashes")
	# The test pilot can fly each mode to a point.
	for fm in [["simple", "angle"], ["pro", "angle"], ["pro", "horizon"], ["pro", "acro"]]:
		var s2 := FpvSim.new(fm[0])
		s2.flight_mode = fm[1]
		s2.place(Vector3.ZERO)
		var ap := FpvAutopilot.new()
		ap.target = Vector3(-10, 0, -20)
		ap.height = 4.0
		for i in int(20.0 / DT):
			var st: Dictionary = ap.sticks(s2)
			s2.step(DT, st["throttle"], st["yaw"], st["pitch"], st["roll"])
		var off := Vector2(s2.pos.x + 10, s2.pos.z + 20).length()
		check(off < 2.0 and absf(s2.altitude() - 4.0) < 1.0 and not s2.crashed,
			"FPV %s %s: the test pilot reaches a point (%.1f m off)" % [fm[0], fm[1], off])


# --- Lessons, flown with the sticks ---------------------------------------------

func _flight(key: String, mode: String, vehicle := "camera") -> Array:
	var task := FlightTask.make(key, mode, 7)
	var world := FlightWorld.new()
	add_child(world)
	world.build("day", 7)
	task.world = world
	task.setup_world()
	var sim: DroneSim
	if vehicle == "fpv" and mode != "kids":
		var f := FpvSim.new(mode, 11)
		f.flight_mode = task.flight_mode
		sim = f
	else:
		sim = DroneSim.new(mode, 11)
		if vehicle == "fpv":
			sim.p["vmax"] = 4.0
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
		ap.land = task.hint_base == "HINT_TAKEOFF_LAND"
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
		if task.hint_base == "HINT_SEARCH_BACK" or task._found:
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
		if task.hint_base == "HINT_KITTEN_FIND":
			ap.target = world.kitten
			ap.height = 8.5
		else:
			ap.target = world.pad
			ap.height = 8.5 if FlightTask.flat_distance(sim.pos, world.pad) > 2.0 else 1.5
		return ap.sticks(sim)
	check(_fly(task, f[1], 180.0, plan), "kids: the kitten mission passes (hint: %s)" % task.hint)
	world.queue_free()
	await get_tree().process_frame


# --- FPV -------------------------------------------------------------------------

## Where to aim for the next gate or hoop: line up in front of it, then fly straight through.
func _through(task: FlightTask, sim: DroneSim) -> Array:
	var g: Dictionary = task.rings[task.ring_i]
	var c: Vector3 = g["c"]
	var n: Vector3 = g["n"]
	var side := n.cross(Vector3.UP).normalized()
	var rel := sim.pos - c
	var along := rel.dot(n)
	var lat := absf(rel.dot(side))
	# The lining-up point (4 m in front) lies inside the corridor, so reaching it starts the run through.
	var aim: Vector3 = c + n * 4.0 if (along > -5.0 and lat < 0.8) else c - n * 4.0
	return [aim, c.y - task.world.height(c.x, c.z)]


## A safe line through the tree belt: in each row, the widest gap near the last one.
func _tree_line(task: FlightTask) -> Array[Vector3]:
	var rows := {}
	for t in task.trees:
		var z := snappedf(t["at"].z, 5.0)
		if not rows.has(z):
			rows[z] = []
		rows[z].append(t)
	var keys := rows.keys()
	keys.sort()
	keys.reverse()
	var out: Array[Vector3] = []
	var last_x := 0.0
	for z in keys:
		var best_x := 0.0
		var best := -INF
		var x := -9.0
		while x <= 9.0:
			var clear := INF
			for t in rows[z]:
				clear = minf(clear, absf(x - t["at"].x) - t["r"])
			var score := clear - absf(x - last_x) * 0.15
			if score > best:
				best = score
				best_x = x
			x += 0.25
		out.append(Vector3(best_x, 2.5, z))
		last_x = best_x
	return out


func test_fpv_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "fpv")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var kids := mode == "kids"
	var ap = Autopilot.new() if kids else FpvAutopilot.new()
	if not kids:
		ap.speed = 4.0 if mode == "simple" else 5.0
	var line: Array[Vector3] = []
	var leg := [0]  # in an array: a lambda keeps its own copy of a plain number
	if key == "MIS_FPV_TREES":
		var there := _tree_line(task)
		var back := there.duplicate()
		back.reverse()
		line.append_array(there)
		line.append(Vector3(0, 3, -38))
		line.append_array(back)
		line.append(Vector3(0, 3, -6))
		if not kids:
			ap.speed = 2.5 if mode == "simple" else 1.8
	var balloons_done := func() -> bool: return task.get("_popped") != null and task._popped.size() >= task.BALLOONS.size()
	var plan := func(_t: float) -> Dictionary:
		if not task.rings.is_empty() and task.ring_i < task.rings.size():
			var a := _through(task, sim)
			ap.target = a[0]
			ap.height = a[1]
		elif key == "MIS_FPV_BALLOONS":
			if not balloons_done.call():
				for i in task.BALLOONS.size():
					if i not in task._popped:
						var b: Vector3 = task.balloon_pos(i)
						ap.target = b
						ap.height = b.y - world.height(b.x, b.z)
						break
			else:
				ap.target = task._target + Vector3(0, 0, -0.5)
				ap.height = task._target.y - world.height(task._target.x, task._target.z)
		elif key == "MIS_FPV_TREES":
			var w := line[mini(leg[0], line.size() - 1)]
			if FlightTask.flat_distance(sim.pos, w) < 0.9:
				leg[0] += 1
			ap.target = Vector3(w.x, 0, w.z)
			ap.height = w.y
		elif key == "FPV_THROTTLE":
			ap.target = world.pad
			ap.height = 3.0
		else:
			var t := task.course_world_target()
			if t != Vector3.INF:
				ap.target = t
				ap.height = task.cps[task.cp].y
		return ap.sticks(sim)
	var ok := _fly(task, sim, 200.0, plan)
	check(ok, "%s: FPV %s passes%s" % [mode, key, "" if ok else " — %s %s crashed=%s" % [task.hint_base, task.summary, sim.crashed]])
	world.queue_free()
	await get_tree().process_frame


func test_trees_over_fails() -> void:
	var f := _flight("MIS_FPV_TREES", "simple", "fpv")
	var ap := FpvAutopilot.new()
	ap.target = Vector3(0, 0, -38)
	ap.height = 12.0
	_fly(f[0], f[1], 60.0, func(_t): return ap.sticks(f[1]))
	check(f[0].failed and f[0].summary == "FAIL_TREES_OVER", "simple: flying over the tree line does not count")
	f[2].queue_free()
	await get_tree().process_frame
