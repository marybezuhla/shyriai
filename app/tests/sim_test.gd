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
	await test_kitten_mission()
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
	var task := FlightTask.make(key, mode)
	var world := FlightWorld.new()
	add_child(world)
	world.build("day", task.is_mission, 7)
	task.world = world
	var sim := DroneSim.new(mode, 11)
	sim.gps = task.gps
	if task.wind >= 0.0:
		sim.set_wind(task.wind, task.gust)
	sim.ground = world.height
	sim.obstacles = world.obstacles
	sim.place(task.start_position(), 0.0)
	return [task, sim, world]


func _fly(task: FlightTask, sim: DroneSim, seconds: float, pick: Callable) -> bool:
	for i in int(seconds / DT):
		var s: Dictionary = pick.call(i * DT)
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.update(DT, sim, s)
		if task.done:
			return true
		if sim.crashed:
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
