# SPDX-License-Identifier: GPL-3.0-or-later
# Tests of the drone physics and of every lesson: each lesson must be passable with the sticks alone,
# in every mode. CI fails if anything here fails. Not shipped in the APK.
extends Node

const Autopilot := preload("res://tests/autopilot.gd")
const FpvAutopilot := preload("res://tests/fpv_autopilot.gd")
const UgvAutopilot := preload("res://tests/ugv_autopilot.gd")
const DT := 1.0 / 60.0

var failures := 0


func _ready() -> void:
	# A script error stops a test without quitting; never wait for the CI job's own time limit.
	get_tree().create_timer(540.0).timeout.connect(func(): printerr("SIM TIMEOUT"); get_tree().quit(1))
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
	test_ugv_physics()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("ugv", mode) + Curriculum.missions("ugv", mode):
			await test_ugv_task(key, mode)
	await test_ugv_rough_driving_fails()
	for mode in ["simple", "pro"]:
		await test_search_mission(mode)
	await test_shortcuts_closed()
	test_photo_rules()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("survey", mode) + Curriculum.missions("survey", mode):
			await test_survey_task(key, mode)
	await test_survey_mistakes()
	for mode in Prefs.MODES:
		for key in Curriculum.lessons("intercept", mode) + Curriculum.missions("intercept", mode):
			await test_intercept_task(key, mode)
	await test_target_gets_away()
	test_rating_rules()
	test_results_are_kept()
	test_saved_results_are_checked()
	await test_free_flight()
	# Missions change with every attempt: fly them with other layouts too.
	for seed_ in [1234, 9001]:
		_seed = seed_
		await test_kitten_mission()
		for mode in ["simple", "pro"]:
			await test_search_mission(mode)
			for key in ["MIS_CAM_SURVEY", "MIS_SRV_FIND", "MIS_SRV_COUNT"]:
				await test_survey_task(key, mode)
				await test_fpv_task("MIS_FPV_TREES", mode)
		for mode in ["simple", "pro"]:
			for key in ["MIS_INT_PATROL", "MIS_INT_FAST"]:
				await test_intercept_task(key, mode)
		for key in ["MIS_UGV_CARGO", "MIS_UGV_EVAC"]:
			await test_ugv_task(key, "simple")
	_seed = 7
	# Every lesson and mission the app offers was flown in every mode that offers it.
	for v in Curriculum.VEHICLES:
		for m in Prefs.MODES:
			for k in Curriculum.lessons(v, m) + Curriculum.missions(v, m):
				check(_flown.has(k + "/" + m), "%s %s was flown to a pass in the tests" % [m, k])
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


# --- Survey course -------------------------------------------------------------

func test_photo_rules() -> void:
	var pos := Vector3(0, 10, 0)
	var basis := Photo.camera_basis(0.0, "down")
	var below := Photo.look(pos, basis, 2.0, Vector3(0, 0, 0), 2.0)
	check(below["in_frame"] and (below["at"] as Vector2).length() < 0.01, "camera down: the point below is in the middle")
	check(not Photo.look(pos, Photo.camera_basis(0.0, "forward"), 2.0, Vector3(0, 0, 0), 2.0)["in_frame"],
		"camera ahead: the point below is not in the frame")
	check(not Photo.look(pos, basis, 2.0, Vector3(0, 20, 0), 2.0)["in_frame"], "nothing behind the camera")
	var far := Photo.look(pos, basis, 2.0, Vector3(0, 0, 0), 0.5)
	check(Photo.verdict(far, 0.0, 0.0, "down", {"min_size": 0.3}) == "PH_TOO_FAR", "a small thing far below: too far")
	check(Photo.verdict(below, 1.5, 0.0, "down", {}) == "PH_BLUR", "moving: smeared")
	check(Photo.verdict(below, 0.0, 1.0, "down", {}) == "PH_BLUR", "turning: smeared")
	check(Photo.verdict(below, 0.0, 0.0, "forward", {"tilts": ["down"]}) == "PH_TILT_DOWN", "wrong tilt says so")
	check(Photo.verdict(below, 0.0, 0.0, "down", {"tilts": ["down"], "min_size": 0.1}) == "", "a good picture")


## Hover still at a point, set the camera, shoot. True if the picture was kept.
func _shoot_at(task: PhotoTask, sim: DroneSim, ap, target: Vector3, height: float, face: Vector3, tilt: String) -> bool:
	ap.target = target
	ap.height = height
	ap.face = face
	ap.land = false
	task.tilt = tilt
	var still := 0.0
	for i in int(60.0 / DT):
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if sim.crashed or task.failed:
			return false
		var here := FlightTask.flat_distance(sim.pos, target) < 0.4 and absf(sim.altitude() - height) < 0.4
		still = still + DT if here and sim.vel.length() < 0.2 and absf(task.turn) < 0.05 else 0.0
		if still > 1.0:
			return task.shoot(sim)["ok"]
	return false


## Fly home and land; the report then opens. True once it is open.
func _land_for_report(task: PhotoTask, sim: DroneSim, world: FlightWorld, ap) -> bool:
	ap.target = world.pad
	ap.face = Vector3.INF
	for i in int(60.0 / DT):
		ap.land = FlightTask.flat_distance(sim.pos, world.pad) < 1.0
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.report_open:
			return true
		if sim.crashed or task.failed:
			return false
	return false


func _answer_all(task: PhotoTask, right := true) -> void:
	for i in task.report.size():
		var item: Dictionary = task.report[i]
		var pick: String = item["answer"]
		if not right:
			for o in item["options"]:
				if o[0] != pick:
					pick = o[0]
					break
		task.answer(i, pick)


func test_survey_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "survey")
	var task: PhotoTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var ap := Autopilot.new()
	var ok := true
	match key:
		"SRV_TILT":
			ok = _shoot_at(task, sim, ap, task.MARK, 7.0, Vector3.INF, "down")
		"SRV_SHARP":
			for sgn in task.SIGNS:
				ok = ok and _shoot_at(task, sim, ap, sgn + Vector3(0, 0, 3.5), 2.2, sgn, "forward")
		"SRV_DETAIL":
			ok = _shoot_at(task, sim, ap, world.houses[task.HOUSE]["pos"], 9.0, Vector3.INF, "down")
			ok = ok and task.report_open
			_answer_all(task)
		"SRV_ORBIT":
			var tower: Vector3 = task.TOWER
			for k in 80:
				var a := k * TAU / 72.0
				ap.target = tower + Vector3(sin(a), 0, cos(a)) * 12.0
				ap.height = 12.0
				ap.face = task.tank()
				for i in int(0.6 / DT):
					var s: Dictionary = task.controls(ap.sticks(sim))
					sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
					task.step(DT, sim, s)
				if task.done:
					break
		"SRV_GRID":
			task.tilt = "down"
			ap.height = 15.0
			ap.max_speed = 4.0
			for j in task.N:
				for i in task.N:
					var col: int = i if j % 2 == 0 else task.N - 1 - i
					ap.target = task.cell_center(Vector2i(col, j))
					for n in int(12.0 / DT):
						var s: Dictionary = task.controls(ap.sticks(sim))
						sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
						task.step(DT, sim, s)
						if FlightTask.flat_distance(sim.pos, ap.target) < 1.0:
							break
		"SRV_KIDS_FLOWER", "SRV_KIDS_KITTEN", "SRV_KIDS_VAN", "MIS_SRV_ALBUM":
			for subj in task._list.duplicate():
				var at: Vector3 = subj["pos"]
				ok = ok and _shoot_at(task, sim, ap, at + Vector3(0, 0, 6.0), 5.0, at, task.tilt)
		"MIS_CAM_SURVEY":
			for i in world.houses.size():
				ok = ok and _shoot_at(task, sim, ap, world.houses[i]["pos"], 12.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
		"MIS_SRV_FIND":
			ok = _shoot_at(task, sim, ap, task.person(), 12.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
		"MIS_SRV_COUNT":
			ok = _shoot_at(task, sim, ap, task.camp(), 18.0, Vector3.INF, "down")
			ok = ok and _land_for_report(task, sim, world, ap)
			_answer_all(task)
	# One more step lets a task notice it is done.
	task.step(DT, sim, {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
	check(ok and task.done, "%s: %s passes with the camera" % [mode, key])
	if task.done:
		_passed(task, sim)
	world.queue_free()
	await get_tree().process_frame


## A smeared picture is refused, the wrong tilt is named, and a wrong report does not pass in Adult.
func test_survey_mistakes() -> void:
	var f := _flight("SRV_TILT", "pro", "survey")
	var task: PhotoTask = f[0]
	var sim: DroneSim = f[1]
	sim.pos = task.MARK + Vector3(0, 7, 0)
	sim.vel = Vector3(2, 0, 0)
	task.tilt = "down"
	check(not task.shoot(sim)["ok"] and task.hint_base == "PH_BLUR", "moving: the picture is smeared")
	sim.vel = Vector3.ZERO
	task.tilt = "forward"
	check(not task.shoot(sim)["ok"] and task.hint_base == "PH_TILT_DOWN", "camera ahead: told to turn it down")
	f[2].queue_free()
	for m in ["simple", "pro"]:
		f = _flight("MIS_SRV_COUNT", m, "survey")
		task = f[0]
		task.photos.append({"id": "camp", "image": null})
		task.report = [{"photo": 0, "prompt": "Q_COUNT", "answer": "6", "options": [["5", "5"], ["6", "6"], ["7", "7"]]}]
		task.report_open = true
		_answer_all(task, false)
		check(task.failed and task.wrong == [0], "%s: a wrong count does not pass, and is listed" % m)
		f[2].queue_free()
	f = _flight("MIS_CAM_SURVEY", "simple", "survey")
	task = f[0]
	for i in 6:
		task.photos.append({"id": str(i), "image": null})
	task.report = []
	for i in 6:
		task.report.append({"photo": i, "prompt": "Q_ROOF", "answer": "ok", "options": [["damaged", "x"], ["ok", "y"]]})
	task.report_open = true
	for i in 6:
		task.answer(i, "damaged" if i == 0 else "ok")
	check(task.done and task.wrong == [0], "simple: one misread roof still passes, and is listed")
	f[2].queue_free()
	await get_tree().process_frame


# --- Interception course ---------------------------------------------------------

## The test pilot flies to the lead point of the current target at its height, as a person should.
func test_intercept_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "intercept")
	var task: FlightTask = f[0]
	var sim: DroneSim = f[1]
	var world: FlightWorld = f[2]
	var fpv := sim is FpvSim
	var ap = FpvAutopilot.new() if fpv else Autopilot.new()
	if fpv:
		# Faster than every target, but slow enough to hold height in a hard turn.
		ap.speed = 18.0 if mode == "pro" else 7.0
	for i in int(200.0 / DT):
		var tg: Dictionary = task.current()
		if not tg.is_empty() and tg.has("now"):
			# Fly through the lead point, never brake for it: a point far beyond it, the same way.
			var aim: Vector3 = task.lead_point(sim, tg)
			var way := Vector3(aim.x - sim.pos.x, 0, aim.z - sim.pos.z)
			ap.target = sim.pos + way.normalized() * maxf(way.length(), 60.0) if way.length() > 0.01 else aim
			ap.height = maxf(1.0, aim.y - world.height(sim.pos.x, sim.pos.z))
		var s: Dictionary = task.controls(ap.sticks(sim))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done or task.failed or sim.crashed:
			break
	check(task.done, "%s: %s catches the target (%s)" % [mode, key, task.summary if task.failed else ("crashed" if sim.crashed else "")])
	if task.done:
		_passed(task, sim)
	world.queue_free()
	await get_tree().process_frame


## Not flying at all: a crossing target gets away, a circling one runs the clock out.
func test_target_gets_away() -> void:
	for key in ["INT_LEAD", "INT_TURN"]:
		var f := _flight(key, "simple", "intercept")
		var task: FlightTask = f[0]
		var sim: DroneSim = f[1]
		for i in int(80.0 / DT):
			sim.step(DT, -1.0, 0, 0, 0)
			task.step(DT, sim, {"throttle": -1.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
			if task.failed:
				break
		check(task.failed and task.summary == ("FAIL_INT_GONE" if key == "INT_LEAD" else "FAIL_INT_TIME"),
			"%s: standing still does not pass (%s)" % [key, task.summary])
		f[2].queue_free()
	await get_tree().process_frame


# --- Sunflowers, results, licences, free flight ------------------------------

func test_rating_rules() -> void:
	for k in FlightTask.FILES.keys():
		if not k.begins_with("FREE_"):
			check(Rating.PAR.has(k), "%s has a par time" % k)
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 10.0, 0) == 3, "quick and clean: three sunflowers")
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 25.0, 0) == 2, "clean but slow: two")
	check(Rating.sunflowers("CAM_TAKEOFF", "simple", 5.0, 1) == 1, "a touch: one, however quick")
	check(Rating.sunflowers("CAM_TAKEOFF", "kids", 25.0, 0) == 3, "kids get more time")
	check(Rating.is_touch({"type": "bump", "speed": 0.5}), "a bump is a touch")
	check(not Rating.is_touch({"type": "landed", "speed": 0.8}), "a soft landing is not")
	check(Rating.is_touch({"type": "landed", "speed": 2.5}), "a hard landing is")
	var tip := Rating.next_tip("CAM_TAKEOFF", "kids", 2)
	check(tip[1].is_empty() and not tr(tip[0]).contains("0"), "kids' tip has no numbers")
	check(Rating.next_tip("CAM_TAKEOFF", "pro", 3)[0] == "", "no tip at three")


func test_results_are_kept() -> void:
	Prefs.set_mode("simple")
	Prefs.record("CAM_HOLD", 2, 30.0)
	var before := Prefs.record("CAM_HOLD", 1, 20.0)
	var now := Prefs.best_of("CAM_HOLD")
	check(int(before["f"]) == 2 and int(now["f"]) == 2 and is_equal_approx(float(now["t"]), 20.0),
		"best sunflowers and best time are kept apart")
	Prefs.reset_progress()
	check(Prefs.best_of("CAM_HOLD").is_empty(), "starting over clears the results")
	Prefs.undo_reset()
	check(int(Prefs.best_of("CAM_HOLD").get("f", 0)) == 2, "undo brings them back")
	for i in Curriculum.lessons("ugv", "simple").size():
		Prefs.mark_passed("ugv", i)
	check(Prefs.licence_date("ugv") == Time.get_date_string_from_system(), "all lessons passed: a licence, dated today")
	check(Prefs.licence_date("fpv") == "", "no licence before the last lesson")
	Prefs.set_pilot_name("  Оля\nПетренко " + "я".repeat(60))
	check(not Prefs.pilot_name.contains("\n") and Prefs.pilot_name.length() <= Prefs.NAME_MAX, "the name is one short line")
	Prefs.erase_all()
	check(Prefs.pilot_name == "" and Prefs.best.is_empty() and Prefs.licences.is_empty(), "erase all clears name, results, licences")
	Prefs.undo_reset()
	check(Prefs.pilot_name != "", "undo after erase brings the name back")
	Prefs.erase_all()


## A broken or hand-edited file must not break the app or slip in odd values.
func test_saved_results_are_checked() -> void:
	Prefs._apply({
		"best": {"pro": {"CAM_TAKEOFF": {"f": 99, "t": 1.0e12}, "NOPE": {"f": 3, "t": 1.0},
			"CAM_HOLD": {"f": "three", "t": 5.0}}, "nobody": {}},
		"licences": {"pro": {"camera": "yesterday", "fpv": "2026-11-06", "plane": "2026-11-06"}},
		"pilot_name": 42, "free": {"wind": "hurricane", "balls": "yes", "time": "dusk"},
	})
	var r: Dictionary = Prefs.best.get("pro", {})
	check(r.size() == 1 and int(r["CAM_TAKEOFF"]["f"]) == 3 and float(r["CAM_TAKEOFF"]["t"]) <= Prefs.MAX_SECONDS,
		"saved results are clamped, unknown tasks dropped")
	check(Prefs.licences["pro"].keys() == ["fpv"], "only real dates for real vehicles")
	check(Prefs.pilot_name == "" and Prefs.free["wind"] == "none" and Prefs.free["balls"] == true
		and Prefs.free["time"] == "dusk", "odd values are ignored, good ones kept")
	Prefs.erase_all()


func test_free_flight() -> void:
	for v in Curriculum.VEHICLES:
		for m in Prefs.MODES:
			var key: String = "FREE_" + v.to_upper()
			var f := _flight(key, m, v)
			var task: FlightTask = f[0]
			var sim: DroneSim = f[1]
			var world: FlightWorld = f[2]
			check(task.is_free and task.counter_shown, "%s %s: free flight with balls" % [m, key])
			# Fly through every ball by placing the vehicle on it: each one counts once, and the
			# flight never ends by itself.
			var balls: Array = task._balls
			for b in balls:
				sim.pos = b
				task.step(DT, sim, {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0})
			check(task.counter == balls.size() and balls.size() == 10 and not task.done,
				"%s %s: all ten balls collected, still flying" % [m, key])
			world.queue_free()
			await get_tree().process_frame
	Prefs.set_free("wind", "gusty")
	check(_flight("FREE_CAMERA", "pro")[0].wind > 3.0, "the chosen wind blows")
	check(_flight("FREE_CAMERA", "kids")[0].wind == 0.0, "kids fly without wind")
	Prefs.erase_all()


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

## Which layout missions get (tests run several), and which tasks were flown in which mode.
var _seed := 7
var _flown := {}


func _flight(key: String, mode: String, vehicle := "camera") -> Array:
	var task := FlightTask.make(key, mode, _seed)
	var world := FlightWorld.new()
	add_child(world)
	world.build("day", 7)
	task.world = world
	task.setup_world()
	return [task, task.make_sim(vehicle), world]


func _passed(task: FlightTask, sim: DroneSim) -> void:
	_flown[task.key + "/" + task.mode] = true
	# The third sunflower must be in reach: the autopilot is well inside the par time.
	check(sim.time <= Rating.par(task.key, task.mode),
		"%s %s autopilot %.0f s within par %.0f s" % [task.mode, task.key, sim.time, Rating.par(task.key, task.mode)])


func _fly(task: FlightTask, sim: DroneSim, seconds: float, pick: Callable) -> bool:
	for i in int(seconds / DT):
		var s: Dictionary = task.controls(pick.call(i * DT))
		sim.step(DT, s["throttle"], s["yaw"], s["pitch"], s["roll"])
		task.step(DT, sim, s)
		if task.done:
			_passed(task, sim)
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
				ap.target = task.TARGET
				ap.height = 3.0
				ap.land = FlightTask.flat_distance(sim.pos, task.TARGET) < 0.2
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


# --- Ground robot ------------------------------------------------------------------

func test_ugv_physics() -> void:
	var sim := UgvSim.new("simple")
	sim.place(Vector3.ZERO)
	run(sim, 3.0, 1.0, 0, 1.0, 0)
	check(sim.pos.z < -6.0 and absf(sim.pos.x) < 0.1, "UGV: both tracks forward drives straight")
	var heading := sim.yaw
	run(sim, 1.0, 1.0, 0, -1.0, 0)
	check(absf(wrapf(sim.yaw - heading, -PI, PI)) > deg_to_rad(45.0), "UGV: tracks in opposite directions turn on the spot")
	run(sim, 2.0, 0, 0, 0, 0)
	check(sim.vel.length() < 0.05, "UGV: let go and it stops")
	var mud := UgvSim.new("simple")
	mud.grip = func(_x, _z): return 0.45
	mud.place(Vector3.ZERO)
	run(mud, 3.0, 1.0, 0, 1.0, 0)
	check(mud.pos.z > -4.0, "UGV: mud slows it down")
	var car := UgvSim.new("kids")
	car.place(Vector3.ZERO)
	run(car, 2.0, 1.0, 0, 0, 0)
	check(car.pos.z < -2.0, "UGV kids: left stick forward drives (car steering)")


func test_ugv_task(key: String, mode: String) -> void:
	var f := _flight(key, mode, "ugv")
	var task: FlightTask = f[0]
	var sim: UgvSim = f[1]
	var world: FlightWorld = f[2]
	var ap := UgvAutopilot.new()
	var gentle := task.meter >= 0.0 or key.contains("EVAC") or key == "MIS_UGV_VET"
	ap.gentle = gentle
	ap.top = 0.35 if gentle else 0.7
	if key == "MIS_UGV_CARGO":
		ap.top = 0.22
	var road: Array[Vector3] = []
	if task.get("road") != null:
		road.assign(task.road)
	var leg := [1]
	var back := [false]
	var plan := func(_t: float) -> Dictionary:
		if key == "UGV_PIVOT":
			match task._stage:
				0:
					ap.target = Vector3(0, 0, -12.8)
				1:
					ap.target = sim.pos + Vector3(0, 0, 6)  # turn round to face out
					ap.stop = false
				2:
					ap.target = Vector3(0, 0, 0)
			return ap.sticks(sim)
		if task.cps.size() > 0:
			var t := task.course_world_target()
			if t != Vector3.INF:
				ap.target = t
			return ap.sticks(sim)
		# Routes: follow the road there, then (when it brings something back) the road home.
		var going_back: bool = task.loaded and task.pickup != Vector3.INF
		var pts := road.duplicate()
		if going_back:
			pts.reverse()
			pts.append(task.dest)
		else:
			pts.append(task.dest if task.pickup == Vector3.INF else task.pickup)
		if going_back and not back[0]:
			leg[0] = 1
			back[0] = true
		var i := mini(leg[0], pts.size() - 1)
		ap.target = pts[i]
		if FlightTask.flat_distance(sim.pos, pts[i]) < 1.0 and i < pts.size() - 1:
			leg[0] += 1
		return ap.sticks(sim)
	var ok := _fly(task, sim, 300.0, plan)
	check(ok, "%s: UGV %s passes%s" % [mode, key, "" if ok else " — %s %s meter=%.0f crashed=%s" % [task.hint_base, task.summary, task.meter, sim.crashed]])
	world.queue_free()
	await get_tree().process_frame


func test_ugv_rough_driving_fails() -> void:
	var f := _flight("UGV_EVACUATION", "simple", "ugv")
	var task: FlightTask = f[0]
	var sim: UgvSim = f[1]
	# Full stick forward and back, again and again, once the casualty is aboard.
	var ap := UgvAutopilot.new()
	ap.top = 0.4
	var plan := func(t: float) -> Dictionary:
		if not task.loaded:
			ap.target = task.road[1] if FlightTask.flat_distance(sim.pos, task.road[1]) > 1.0 and t < 4.0 else task.pickup
			if FlightTask.flat_distance(sim.pos, task.road[1]) < 1.0 or t > 4.0:
				ap.target = task.road[2] if FlightTask.flat_distance(sim.pos, task.road[2]) > 1.0 and t < 12.0 else task.pickup
			return ap.sticks(sim)
		var k := 1.0 if int(t * 2.0) % 2 == 0 else -1.0
		return {"throttle": k, "yaw": 0.0, "pitch": k, "roll": 0.0}
	_fly(task, sim, 120.0, plan)
	check(task.failed and task.summary == "FAIL_JOLT_STRETCHER", "simple: jerky driving with a casualty does not pass (%s)" % task.summary)
	f[2].queue_free()
	await get_tree().process_frame



## Deep enough in the alley for the pivot lesson's "inside" point.
const END_IN := -12.4


## Each way round a lesson that the audit found is now closed.
func test_shortcuts_closed() -> void:
	# Flying round the end of the tree belt instead of through it.
	var f := _flight("MIS_FPV_TREES", "simple", "fpv")
	var ap := FpvAutopilot.new()
	var legs := [Vector3(-17, 0, -4), Vector3(-17, 0, -38), Vector3(0, 0, -38)]
	var leg := [0]
	var plan := func(_t: float) -> Dictionary:
		ap.target = legs[mini(leg[0], legs.size() - 1)]
		ap.height = 3.0
		if FlightTask.flat_distance(f[1].pos, ap.target) < 1.0:
			leg[0] += 1
		return ap.sticks(f[1])
	_fly(f[0], f[1], 80.0, plan)
	check(f[0].failed and f[0].summary == "FAIL_TREES_AROUND", "simple: going round the tree belt does not count")
	f[2].queue_free()
	await get_tree().process_frame

	# Turning on the pad and reversing into the alley: the task must not move on, and must say why.
	var g := _flight("UGV_PIVOT", "simple", "ugv")
	var u: UgvSim = g[1]
	u.place(Vector3.ZERO, PI)  # already turned round, facing the pilot
	check(u.forward().dot(Vector3(0, 0, 1)) > 0.99, "test setup: the robot faces out of the alley")
	var phase := [1]  # 1 reverse in, 2 drive out
	var told := [false]
	var reverse := func(_t: float) -> Dictionary:
		if g[0].hint_base == "HINT_PIVOT_FORWARD":
			told[0] = true
		if phase[0] == 1 and u.pos.z < END_IN:
			phase[0] = 2
		if phase[0] == 1:
			return {"throttle": -0.4, "yaw": 0.0, "pitch": -0.4, "roll": 0.0}
		if u.pos.z > 0.0:
			return {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}  # out: stop
		return {"throttle": 0.4, "yaw": 0.0, "pitch": 0.4, "roll": 0.0}
	var passed := _fly(g[0], u, 60.0, reverse)
	check(phase[0] == 2 and not g[0].failed, "simple: the robot really reversed into the alley and out without a bump (phase %d, %s, %s)" % [phase[0], u.pos, g[0].summary])
	check(not passed and g[0]._stage == 0 and told[0], "simple: reversing into the alley does not count, and the hint says to turn first")
	g[2].queue_free()
	await get_tree().process_frame

	# Driving up the sheer side of the ramp.
	var h := _flight("UGV_TERRAIN", "simple", "ugv")
	var hu: UgvSim = h[1]
	hu.place(Vector3(-4, 0, -14.45), -PI / 2.0)  # beside the ramp, facing it
	var side := func(_t: float) -> Dictionary:
		return {"throttle": 0.8, "yaw": 0.0, "pitch": 0.8, "roll": 0.0}
	_fly(h[0], hu, 5.0, side)
	check(hu.pos.y < 0.3, "simple: the robot cannot climb the sheer side of the ramp (%.2f m)" % hu.pos.y)
	h[2].queue_free()
	await get_tree().process_frame

	# Kids: bumping a barrel on the delivery does not fail it.
	var k := _flight("UGV_DELIVERY", "kids", "ugv")
	k[1].events.append({"type": "bump", "speed": 1.0})
	k[0].step(DT, k[1], {})
	check(not k[0].failed, "kids: a bump on the delivery is not a failure")
	k[2].queue_free()
	await get_tree().process_frame
